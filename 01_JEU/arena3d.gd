extends Node3D
class_name Arena3D

# ============================================================
#  Scene principale : monde 3D eclaire + simulation 2D existante.
#  La simulation (arena.gd / fighter.gd) est inchangee ; elle
#  fournit les positions et les poses, ce noeud fait le rendu.
# ============================================================

const S := Fighter3D.S
const W := 1280.0
const GROUND_SIM_Y := 590.0
const WALL_L := 90.0
const WALL_R := 1190.0

const CAM_FOV := 42.0
const CAM_MIN_W := 12.0     # garde un plan assez large, meme au corps-a-corps
const CAM_MAX_W := 23.0     # ... et quand ils sont aux deux bouts
const CAM_MARGIN := 3.2
const CAM_BODY_TOP := 3.7   # hauteur maximale du corps au-dessus de son origine
const CAM_BODY_BOTTOM := 0.35
const CAM_VERTICAL_MARGIN := 1.2

var arena: Arena
var rigs: Array[Node3D] = []
var cam: Camera3D


func _ready() -> void:
	_build_world()

	arena = load("res://arena.tscn").instantiate()
	arena.draw_world = false                      # le decor vient de la 3D
	add_child(arena)
	await get_tree().process_frame

	for i in arena.fighters.size():
		_make_rig(i)
	arena.rigs_ready(self)
	if GameSettings.consume_workshop_request():
		arena.workshop.return_to_menu_on_close = true
		arena.workshop.show_workshop()


# Cree le rendu du combattant : modele 3D importe si disponible,
# sinon le pantin en capsules.
func _make_rig(i: int) -> void:
	var f: Fighter = arena.fighters[i]
	if i < rigs.size() and is_instance_valid(rigs[i]):
		rigs[i].queue_free()

	var paths: Array[String] = [arena.model_path(i)]
	var legacy_path := arena.legacy_model_path(i)
	if legacy_path != "" and not legacy_path in paths:
		paths.append(legacy_path)
	for path in paths:
		if path == "":
			continue
		var t0 := Time.get_ticks_msec()
		var rig := FighterRig.load_model(path, f)
		if rig != null:
			add_child(rig)
			_set_rig(i, rig)
			print("modele riggé en %d ms : %s" % [Time.get_ticks_msec() - t0, path.get_file()])
			return
		push_warning("modele illisible : %s" % path)

	var puppet := Fighter3D.new()
	add_child(puppet)
	puppet.setup(f)
	_set_rig(i, puppet)


func _set_rig(i: int, node: Node3D) -> void:
	while rigs.size() <= i:
		rigs.append(null)
	rigs[i] = node


func reload_model(i: int) -> void:
	_make_rig(i)


func _process(delta: float) -> void:
	if arena == null or arena.fighters.size() < 2 or cam == null:
		return
	var a := Fighter3D.sim_to_world(arena.fighters[0].global_position)
	var b := Fighter3D.sim_to_world(arena.fighters[1].global_position)

	# On cadre pour contenir les deux combattants. La largeur minimale evite
	# les gros plans qui faisaient sortir un sauteur de l'ecran.
	var sep := absf(a.x - b.x)
	var want_w: float = clampf(sep + CAM_MARGIN * 2.0, CAM_MIN_W, CAM_MAX_W)
	var vp := get_viewport().get_visible_rect().size
	var aspect: float = maxf(vp.x / maxf(vp.y, 1.0), 0.1)

	# Le zoom tient aussi compte de la hauteur : si un seul combattant saute,
	# le sol et le sommet des deux silhouettes restent dans le cadre.
	var frame_bottom := minf(a.y, b.y) - CAM_BODY_BOTTOM
	var frame_top := maxf(a.y, b.y) + CAM_BODY_TOP
	var needed_height := frame_top - frame_bottom + CAM_VERTICAL_MARGIN * 2.0
	want_w = clampf(maxf(want_w, needed_height * aspect), CAM_MIN_W, CAM_MAX_W)
	var dist: float = (want_w / aspect) * 0.5 / tan(deg_to_rad(CAM_FOV) * 0.5)

	# on ne depasse pas les murs
	var half_arena := (WALL_R - WALL_L) * 0.5 * S
	var limit: float = maxf(0.0, half_arena - want_w * 0.5)
	var mid_x: float = clampf((a.x + b.x) * 0.5, -limit, limit)
	var frame_center_y := (frame_bottom + frame_top) * 0.5
	var target := Vector3(mid_x, clampf(frame_center_y, 1.45, 6.5), dist)

	var k: float = 1.0 - exp(-5.0 * delta)
	cam.position = cam.position.lerp(target, k)

	# la secousse d'impact porte sur la camera 3D (pas sur l'interface)
	var sh: float = arena.shake_amt * 0.010
	if sh > 0.0001:
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * sh


func _build_world() -> void:
	var stage_data := _load_stage_skin()
	var stage_texture: Texture2D = stage_data.get("texture", null) as Texture2D
	var stage_floor_texture: Texture2D = stage_data.get("floor_texture", null) as Texture2D
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.062, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Lumiere neutre et symetrique : un skin ne doit pas changer de luminosite
	# selon qu'il est attribue au combattant bleu ou au combattant rouge.
	# Couleur et puissance historiques conservees pour ne pas changer l'aspect
	# de djo, lulu et des autres skins existants.
	env.ambient_light_color = Color(0.42, 0.48, 0.72)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.08, 0.14)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	cam = Camera3D.new()
	cam.fov = CAM_FOV
	cam.position = Vector3(0.0, 1.5, 9.0)
	cam.rotation_degrees = Vector3(-5.0, 0, 0)
	add_child(cam)
	cam.make_current()

	# Eclairage aligne avec la camera : sa direction n'a aucune composante
	# gauche/droite. Une symetrie du modele sur X recoit donc exactement la meme
	# lumiere, tout en conservant le relief et les materiaux originaux du skin.
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.95, 0.87)
	key.light_energy = 1.50
	key.rotation_degrees = Vector3(-48.0, 0.0, 0.0)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 40.0
	add_child(key)

	# Remplissage doux depuis le haut, lui aussi sans biais gauche/droite.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.52, 0.66, 1.0)
	fill.light_energy = 0.72
	fill.rotation_degrees = Vector3(-22.0, 180.0, 0.0)
	add_child(fill)

	# sol
	# le sol passe sous la camera pour remplir le bas de l'ecran, mais
	# reste sombre : sinon il ecrase toute la composition
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 90)
	floor_mi.position = Vector3(0, 0, -14.0)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	if stage_floor_texture:
		fm.albedo_texture = stage_floor_texture
		fm.albedo_color = Color(0.30, 0.32, 0.38)
		fm.uv1_scale = Vector3(24.0, 18.0, 1.0)
		fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		fm.albedo_color = Color(0.075, 0.080, 0.115)
	fm.roughness = 0.92
	fm.metallic = 0.0
	floor_mi.material_override = fm
	add_child(floor_mi)

	# tapis de combat, legerement plus clair
	var mat_mi := MeshInstance3D.new()
	var mplane := PlaneMesh.new()
	mplane.size = Vector2((WALL_R - WALL_L) * S, 22.0)
	mat_mi.mesh = mplane
	mat_mi.position = Vector3(0, 0.004, 5.0)
	var mm := StandardMaterial3D.new()
	if stage_floor_texture:
		mm.albedo_texture = stage_floor_texture
		mm.albedo_color = Color(0.45, 0.48, 0.56)
		# Repetition proportionnelle aux dimensions du tapis : les dalles ne sont
		# pas etirees et le revetement reste bien attache au sol 3D.
		mm.uv1_scale = Vector3(3.0, 7.7, 1.0)
		mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		mm.albedo_color = Color(0.155, 0.165, 0.235)
	mm.roughness = 0.82
	mat_mi.material_override = mm
	add_child(mat_mi)

	_wall(Vector3(((WALL_L - 640.0) * S) - 0.35, 0.0, 0.0))
	_wall(Vector3(((WALL_R - 640.0) * S) + 0.35, 0.0, 0.0))

	# Fond de l'arene : image choisie dans le menu, ou panneau classique.
	var back := MeshInstance3D.new()
	var bm := StandardMaterial3D.new()
	if stage_texture:
		var backdrop := QuadMesh.new()
		var image_ratio := float(stage_texture.get_width()) / maxf(stage_texture.get_height(), 1.0)
		backdrop.size = Vector2(19.0 * image_ratio, 19.0)
		back.mesh = backdrop
		back.position = Vector3(0, 6.25, -6.5)
		bm.albedo_texture = stage_texture
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		bm.disable_fog = true
		bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		var bq := BoxMesh.new()
		bq.size = Vector3(60, 18, 0.5)
		back.mesh = bq
		back.position = Vector3(0, 6.0, -6.5)
		bm.albedo_color = Color(0.085, 0.095, 0.15)
		bm.roughness = 0.95
	back.material_override = bm
	add_child(back)


func _load_stage_skin() -> Dictionary:
	var background_path := GameSettings.selected_stage_path()
	var floor_path := GameSettings.selected_stage_floor_path()
	if background_path == "" or floor_path == "":
		return {}
	var image := _load_stage_image(background_path)
	var floor_image := _load_stage_image(floor_path)
	if image == null or floor_image == null:
		return {}
	return {
		"texture": ImageTexture.create_from_image(image),
		"floor_texture": ImageTexture.create_from_image(floor_image),
	}


func _load_stage_image(path: String) -> Image:
	var image := Image.new()
	var error := image.load(path)
	if error != OK or image.is_empty():
		push_warning("Image de terrain illisible : %s" % path)
		return null
	# Limite raisonnable pour eviter qu'une photo enorme ralentisse le jeu.
	if image.get_width() > 4096 or image.get_height() > 4096:
		var ratio := minf(4096.0 / image.get_width(), 4096.0 / image.get_height())
		image.resize(
			maxi(1, roundi(image.get_width() * ratio)),
			maxi(1, roundi(image.get_height() * ratio)),
			Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	return image


func _wall(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 2.2, 6.0)
	mi.mesh = box
	mi.position = at + Vector3(0, 1.1, 0.2)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.14, 0.20)
	m.roughness = 0.85
	mi.material_override = m
	add_child(mi)


# Projette un point de la simulation 2D vers l'ecran, pour que les
# effets dessines en 2D restent colles aux corps 3D.
func project(sim: Vector2) -> Vector2:
	if cam == null:
		return sim
	return cam.unproject_position(Fighter3D.sim_to_world(sim))


# Convertit un clic ecran vers le plan 2D du combat (profondeur Z = 0).
func unproject(screen: Vector2) -> Vector2:
	if cam == null:
		return screen
	var origin := cam.project_ray_origin(screen)
	var direction := cam.project_ray_normal(screen)
	if absf(direction.z) < 0.00001:
		return screen
	var distance := -origin.z / direction.z
	var world := origin + direction * distance
	return Vector2(world.x / S + W * 0.5, GROUND_SIM_Y - world.y / S)


func refresh_looks() -> void:
	for r in rigs:
		if is_instance_valid(r) and r.has_method("refresh_look"):
			r.refresh_look()
