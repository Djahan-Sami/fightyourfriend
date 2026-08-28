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
const STAGE_WIDTH := (WALL_R - WALL_L) * S
const STAGE_DEPTH := 14.5

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
	env.background_color = Color(0.025, 0.032, 0.060)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Lumiere neutre et symetrique : un skin ne doit pas changer de luminosite
	# selon qu'il est attribue au combattant bleu ou au combattant rouge.
	# Couleur et puissance historiques conservees pour ne pas changer l'aspect
	# de djo, lulu et des autres skins existants.
	env.ambient_light_color = Color(0.42, 0.48, 0.72)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.08, 0.14)
	env.fog_density = 0.008
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.04
	env.adjustment_contrast = 1.06
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

	_build_fighting_floor(stage_floor_texture)

	_wall(Vector3(((WALL_L - 640.0) * S) - 0.35, 0.0, 0.0))
	_wall(Vector3(((WALL_R - 640.0) * S) + 0.35, 0.0, 0.0))
	_build_stage_frame(stage_texture == null)

	# Fond de l'arene : image choisie dans le menu, ou panneau classique.
	var back := MeshInstance3D.new()
	var bm := StandardMaterial3D.new()
	if stage_texture:
		var backdrop := QuadMesh.new()
		var image_ratio := float(stage_texture.get_width()) / maxf(stage_texture.get_height(), 1.0)
		backdrop.size = Vector2(16.0 * image_ratio, 16.0)
		back.mesh = backdrop
		# Le bas de l'image (la rambarde) arrive au niveau du vrai sol 3D. Les
		# images de terrain ne simulent donc plus une seconde surface jouable.
		back.position = Vector3(0, 8.0, -7.2)
		bm.albedo_texture = stage_texture
		bm.albedo_color = Color(0.82, 0.86, 0.96)
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		bm.disable_fog = true
		bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		var bq := BoxMesh.new()
		bq.size = Vector3(60, 18, 0.5)
		back.mesh = bq
		back.position = Vector3(0, 6.0, -7.2)
		bm.albedo_color = Color(0.055, 0.070, 0.125)
		bm.roughness = 0.95
	back.material_override = bm
	add_child(back)


func _build_fighting_floor(stage_floor_texture: Texture2D) -> void:
	# Un grand plan bouche toujours le bas de l'ecran, meme lorsque la camera
	# recule. Le plateau plus epais en son centre donne ensuite un vrai volume a
	# la zone sur laquelle les combattants posent les pieds.
	var outer := MeshInstance3D.new()
	var outer_plane := PlaneMesh.new()
	outer_plane.size = Vector2(120.0, 90.0)
	outer.mesh = outer_plane
	outer.position = Vector3(0, -0.025, -14.0)
	var outer_mat := StandardMaterial3D.new()
	if stage_floor_texture:
		outer_mat.albedo_texture = stage_floor_texture
		outer_mat.albedo_color = Color(0.055, 0.065, 0.085)
		outer_mat.uv1_scale = Vector3(30.0, 22.5, 1.0)
		outer_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		outer_mat.albedo_color = Color(0.045, 0.052, 0.083)
	outer_mat.roughness = 0.96
	outer.material_override = outer_mat
	add_child(outer)

	var platform_mat := _stage_material(Color(0.060, 0.069, 0.105), 0.80, 0.10)
	_add_stage_box(Vector3(STAGE_WIDTH + 0.9, 0.30, STAGE_DEPTH + 0.7),
		Vector3(0, -0.17, 1.15), platform_mat)

	var surface := MeshInstance3D.new()
	var surface_plane := PlaneMesh.new()
	surface_plane.size = Vector2(STAGE_WIDTH, STAGE_DEPTH)
	surface.mesh = surface_plane
	surface.position = Vector3(0, 0.008, 1.15)
	var surface_mat := StandardMaterial3D.new()
	if stage_floor_texture:
		surface_mat.albedo_texture = stage_floor_texture
		# La texture reste lisible, mais assez sombre pour que les pantalons clairs
		# et les effets d'impact ne disparaissent pas dans le revetement.
		surface_mat.albedo_color = Color(0.11, 0.13, 0.18)
		surface_mat.uv1_scale = Vector3(6.1, 4.75, 1.0)
		surface_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		surface_mat.albedo_color = Color(0.125, 0.145, 0.215)
	surface_mat.roughness = 0.76
	surface_mat.metallic = 0.08
	surface.material_override = surface_mat
	add_child(surface)

	# Joints geometriques tres fins : ils restent nets meme lorsqu'une texture
	# est vue de biais et donnent au sol son volume sans dessiner un ring sportif.
	var seam_mat := _stage_material(Color(0.045, 0.055, 0.075), 0.92, 0.0)
	for ix in range(-5, 6):
		_add_stage_box(Vector3(0.014, 0.007, STAGE_DEPTH - 0.18),
			Vector3(float(ix) * 1.55, 0.018, 1.15), seam_mat)
	for iz in range(-5, 7):
		_add_stage_box(Vector3(STAGE_WIDTH - 0.18, 0.007, 0.014),
			Vector3(0, 0.018, 1.15 + float(iz) * 1.2), seam_mat)

	# Cadre bas : il se voit surtout au premier plan et explique visuellement ou
	# finit le plateau sans ajouter de mur invisible au milieu de l'image.
	var trim_mat := _stage_material(Color(0.19, 0.22, 0.31), 0.55, 0.35)
	_add_stage_box(Vector3(STAGE_WIDTH + 0.5, 0.075, 0.18),
		Vector3(0, 0.035, 1.15 + STAGE_DEPTH * 0.5), trim_mat)
	_add_stage_box(Vector3(STAGE_WIDTH + 0.5, 0.075, 0.18),
		Vector3(0, 0.035, 1.15 - STAGE_DEPTH * 0.5), trim_mat)
	_add_stage_box(Vector3(0.18, 0.075, STAGE_DEPTH),
		Vector3(-STAGE_WIDTH * 0.5, 0.035, 1.15), trim_mat)
	_add_stage_box(Vector3(0.18, 0.075, STAGE_DEPTH),
		Vector3(STAGE_WIDTH * 0.5, 0.035, 1.15), trim_mat)

func _build_stage_frame(add_railing: bool) -> void:
	var frame_mat := _stage_material(Color(0.075, 0.082, 0.12), 0.70, 0.38)
	var metal_mat := _stage_material(Color(0.17, 0.18, 0.22), 0.42, 0.72)
	var glow_mat := _stage_material(Color(0.42, 0.20, 0.07), 0.38, 0.10,
		Color(1.0, 0.34, 0.055), 1.65)
	var rear_z := 1.15 - STAGE_DEPTH * 0.5

	# Le seuil arriere raccorde le plan de jeu au decor vertical.
	_add_stage_box(Vector3(STAGE_WIDTH + 0.8, 0.26, 0.42),
		Vector3(0, 0.11, rear_z), frame_mat)
	for side in [-1.0, 1.0]:
		var x: float = side * (STAGE_WIDTH * 0.5 + 0.22)
		_add_stage_box(Vector3(0.34, 2.55, 0.72), Vector3(x, 1.22, rear_z), frame_mat)

	# Meme avec un decor image, deux sources tres douces raccordent ses lampes au
	# vrai sol. Elles restent strictement symetriques entre les deux joueurs.
	for x in [-4.4, 4.4]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 1.25, rear_z + 1.1)
		lamp.light_color = Color(1.0, 0.58, 0.29)
		lamp.light_energy = 0.72 if add_railing else 0.34
		lamp.omni_range = 5.8
		lamp.shadow_enabled = false
		add_child(lamp)

	if not add_railing:
		return
	# L'arene classique n'a pas d'eclairage peint dans une image. On lui ajoute
	# donc les petites sources visibles qui correspondent aux lumieres ci-dessus.
	for x in [-6.8, -3.4, 0.0, 3.4, 6.8]:
		_add_stage_box(Vector3(0.42, 0.15, 0.20), Vector3(x, 0.16, rear_z + 0.12), glow_mat)

	# L'arene classique n'a pas d'image : une rambarde simple lui donne tout de
	# meme une profondeur et une silhouette de vrai lieu de combat.
	for x in range(-8, 9, 2):
		_add_stage_box(Vector3(0.10, 1.05, 0.10), Vector3(float(x), 0.72, rear_z - 0.03), metal_mat)
	for y in [0.54, 0.92, 1.28]:
		_add_stage_box(Vector3(STAGE_WIDTH - 0.25, 0.075, 0.075),
			Vector3(0, y, rear_z - 0.03), metal_mat)


func _stage_material(color: Color, roughness: float, metallic: float,
		emission := Color(0, 0, 0, 1), emission_energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func _add_stage_box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = at
	instance.material_override = material
	add_child(instance)
	return instance


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
