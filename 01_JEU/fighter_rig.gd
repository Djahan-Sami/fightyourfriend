extends Node3D
class_name FighterRig

# ============================================================
#  Combattant rendu avec un vrai modele 3D riggé automatiquement.
#  Remplace les pantins en capsules quand un .glb est disponible.
#
#  Le modele est pivote de 90° au chargement : son axe gauche-droite
#  devient la PROFONDEUR, ce qui donne un personnage de profil dont
#  les membres avant/arriere sont naturellement separes.
# ============================================================

const S := Fighter3D.S
const TARGET_H := 2.34        # taille du combattant en unites 3D

var src: Fighter
var sk: Skeleton3D
var mi: MeshInstance3D
var holder: Node3D
var _glove_mat: StandardMaterial3D
var _body_standard: BaseMaterial3D
var _body_uses_mirror := false
var _body_base_emission_enabled := false
var _body_base_emission := Color.BLACK
var _body_base_emission_texture: Texture2D
var _body_base_emission_energy := 1.0
var _glove_l: MeshInstance3D
var _glove_r: MeshInstance3D

var _seg: Array = []          # segments d'os au repos (espace modele)
var _len := PackedFloat32Array()
var _lm: Dictionary
var _k := 1.0                 # echelle modele -> monde
var _hip_rest := 0.0
var _ground_ankle_y := 0.0
var _locked_move := ""
var _support_anchor := Vector3.ZERO
var _external_player: ExternalMotionClip
var _external_key := ""


static func load_model(path: String, f: Fighter) -> FighterRig:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		return null
	var scene := doc.generate_scene(st)
	if scene == null:
		return null
	var src_mi := _first_mesh(scene)
	if src_mi == null or src_mi.mesh == null:
		return null

	var rig := FighterRig.new()
	rig._build(src_mi.mesh, src_mi.get_aabb(), f)
	scene.queue_free()
	return rig


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null


func _build(mesh: Mesh, aabb: AABB, f: Fighter) -> void:
	src = f
	src.draw_2d = false
	src.head_sprite.visible = false

	var rig := AutoRig.build(mesh, aabb)
	if str(rig.get("profile_id", "")) != AutoRig.PROFILE_ID:
		return
	_lm = rig["landmarks"]
	var seg0: Array = rig["segments"]

	# pivot de 90° : lateral -> profondeur, avant du modele -> +X
	var rot := Basis(Vector3(0, 1, 0), PI * 0.5)
	var rmesh: ArrayMesh = rig["mesh"]
	var arrays := rmesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vs.size():
		vs[i] = rot * vs[i]
	arrays[Mesh.ARRAY_VERTEX] = vs
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in ns.size():
			ns[i] = rot * ns[i]
		arrays[Mesh.ARRAY_NORMAL] = ns
	var final_mesh := ArrayMesh.new()
	final_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := rmesh.surface_get_material(0)
	if mat:
		# Le materiau importe reste la reference : texture, normal map et relief ne
		# sont pas remplaces par un rendu simplifie.
		var mirrored_mat := mat.duplicate()
		if mirrored_mat is BaseMaterial3D:
			_body_standard = mirrored_mat
			_body_standard.cull_mode = BaseMaterial3D.CULL_BACK
			_body_base_emission_enabled = _body_standard.emission_enabled
			_body_base_emission = _body_standard.emission
			_body_base_emission_texture = _body_standard.emission_texture
			_body_base_emission_energy = _body_standard.emission_energy_multiplier
			final_mesh.surface_set_material(0, _body_standard)

	_seg = []
	for s in seg0:
		_seg.append([rot * (s[0] as Vector3), rot * (s[1] as Vector3)])

	_len.resize(_seg.size())
	for b in _seg.size():
		_len[b] = (_seg[b][1] - _seg[b][0]).length()

	var h: float = _lm["h"]
	_k = TARGET_H / maxf(h, 0.0001)
	_hip_rest = (_seg[AutoRig.B_HIPS][0] as Vector3).y
	# Le niveau du tapis est celui des chevilles dans la pose de repos du
	# modele. Les semelles du maillage se trouvent juste en dessous. Conserver
	# cette valeur permet de resoudre les jambes vers un sol reel, plutot que
	# d'esperer qu'une combinaison d'angles y arrive par hasard.
	_ground_ankle_y = minf(
		(_seg[AutoRig.B_FOOT_L][0] as Vector3).y,
		(_seg[AutoRig.B_FOOT_R][0] as Vector3).y)

	holder = Node3D.new()
	holder.scale = Vector3(_k, _k, _k)
	add_child(holder)

	sk = AutoRig.make_skeleton(_seg)
	holder.add_child(sk)
	mi = MeshInstance3D.new()
	mi.mesh = final_mesh
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = sk.create_skin_from_rest_transforms()
	_glove_l = _add_boxing_glove(h)
	_glove_r = _add_boxing_glove(h)
	_external_player = ExternalMotionClip.new()
	add_child(_external_player)


func refresh_look() -> void:
	if _glove_mat:
		_glove_mat.albedo_color = src.col_main.lightened(0.18)


func _add_boxing_glove(model_h: float) -> MeshInstance3D:
	# Le modele statique a les doigts ouverts. Ce volume recouvre la main et
	# donne une lecture de poing ferme, sans exiger un morph absent du fichier.
	if _glove_mat == null:
		_glove_mat = StandardMaterial3D.new()
		_glove_mat.albedo_color = src.col_main.lightened(0.18)
		_glove_mat.roughness = 0.48
		_glove_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glove := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = model_h * 0.030
	shape.height = model_h * 0.068
	shape.radial_segments = 12
	shape.rings = 6
	glove.mesh = shape
	glove.material_override = _glove_mat
	holder.add_child(glove)
	return glove


func _place_glove(glove: MeshInstance3D, g: Array, lower_arm: int) -> void:
	var forearm: Transform3D = g[lower_arm]
	glove.position = forearm.origin + forearm.basis.y.normalized() * _len[lower_arm] * 0.82


# ------------------------------------------------------------
#  Animation : on lit le squelette 2D et on oriente les os
# ------------------------------------------------------------
func _process(_delta: float) -> void:
	if not is_instance_valid(src) or sk == null:
		return
	var d := src.skeleton()
	global_position = Fighter3D.sim_to_world(src.global_position)

	var facing: float = d["facing"]
	# Une echelle X negative retourne l'ordre des faces. Garder le meme mode de
	# culling obligeait Godot a afficher le revers du skin rouge, donc des
	# normales eclairees a l'envers. On conserve les faces anatomiquement
	# exterieures en inversant le culling avec la direction du combattant.
	var cull := BaseMaterial3D.CULL_FRONT if facing < 0.0 else BaseMaterial3D.CULL_BACK
	var wants_mirror := facing < 0.0
	if wants_mirror != _body_uses_mirror and _body_standard:
		_body_uses_mirror = wants_mirror
		if wants_mirror:
			# Godot assombrit le maillage skinné lorsque sa symetrie utilise une
			# echelle negative. Une tres faible reprise de la texture compense cette
			# perte sans aplatir le materiau ni modifier le fichier GLB.
			_body_standard.emission = Color.WHITE
			_body_standard.emission_texture = _body_standard.albedo_texture
			_body_standard.emission_energy_multiplier = 0.08
			_body_standard.emission_enabled = true
		else:
			_body_standard.emission = _body_base_emission
			_body_standard.emission_texture = _body_base_emission_texture
			_body_standard.emission_energy_multiplier = _body_base_emission_energy
			_body_standard.emission_enabled = _body_base_emission_enabled
	if _glove_mat:
		_glove_mat.cull_mode = cull
	var motion: Dictionary = d.get("motion", {})
	var external_motion: Dictionary = {}
	var clip_info: Dictionary = {}
	var clip_progress := 0.0
	if src.state == Fighter.State.ATTACK:
		clip_info = d.get("external_clip", {})
		clip_progress = float(d.get("attack_progress", 0.0))
	# La garde personnalisee correspond a la protection reelle du gameplay.
	# L'etat IDLE est la courte phase vulnerable avant que la garde se leve.
	elif src.state == Fighter.State.BLOCK:
		clip_info = d.get("external_guard", {})
	elif src.state == Fighter.State.IDLE:
		clip_info = d.get("external_neutral", {})
	elif src.state == Fighter.State.WALK:
		# Pendant le deplacement, seules les chaines des bras de la position
		# vulnerable sont reutilisees. Les jambes gardent leur cycle avec appuis.
		clip_info = d.get("external_neutral", {})
	elif src.state == Fighter.State.CROUCH:
		clip_info = d.get("external_crouch", {})
	if not clip_info.is_empty():
		var wanted_key := "%s|%s" % [clip_info.get("file", ""), clip_info.get("animation", "")]
		if wanted_key != _external_key:
			_external_key = wanted_key
			if not _external_player.load_clip(clip_info):
				push_warning("Animation externe illisible : %s" % wanted_key)
		if _external_player.valid:
			external_motion = _external_player.sample(clip_progress)
	var using_walk_neutral_arms := src.state == Fighter.State.WALK \
		and not external_motion.is_empty()
	var using_external := not external_motion.is_empty() and not using_walk_neutral_arms
	if using_external:
		motion = external_motion
	# Les adversaires sont de vraies images miroir : le second modele n'est plus
	# simplement retourne de 180 degres. Le meme cote anatomique reste visible
	# au premier plan et les couleurs gauche/droite restent coherentes.
	var extra_turn := 0.0 if using_external else float(d.get("turn_y", 0.0))
	var root_roll := 0.0 if using_external else float(d.get("root_roll", 0.0)) * facing
	# Le premier combattant conserve le meme cote du torse que la vue PROFIL DU
	# JEU dans Blender. Seul l'axe horizontal est miroite pour son adversaire.
	holder.scale = Vector3(_k * facing, _k, _k)
	holder.rotation = Vector3(0, extra_turn, 0)
	# Petit transfert visuel du bassin. La collision reste au centre logique du
	# combattant ; seuls quelques pixels de compression/propulsion sont ajoutes.
	var root_shift := Vector3(float(motion.get("advance", 0.0)) * S * facing, 0.0, 0.0)
	holder.position = root_shift

	var hip2: Vector2 = d["hip"]
	var sh2: Vector2 = d["sh"]
	var hip_twist: float = float(external_motion.get("hip_twist", d.get("hip_twist", 0.0)))
	var chest_twist: float = float(external_motion.get("chest_twist", d.get("chest_twist", 0.0)))

	# hauteur du bassin : on part de celle du modele et on applique
	# seulement l'accroupissement relatif du systeme de poses
	var drop_px: float = hip2.y - Fighter.HIP_Y
	var hip_y: float = _hip_rest - drop_px * S / _k
	var hip_o := Vector3(0.0, hip_y, 0.0)
	if using_external:
		var root_delta := external_motion.get("root_delta", Vector3.ZERO) as Vector3
		var root_curve = clip_info.get("root_motion_curve", [])
		if root_curve is Array and root_curve.size() >= 2:
			# Le Fighter2D applique deja ce X a sa vraie collision. Le conserver
			# aussi dans le squelette doublerait visuellement le deplacement.
			root_delta.x = 0.0
		hip_o += root_delta * float(_lm["h"])

	var torso: Vector3 = external_motion.get("hips_dir", _dir3(sh2 - hip2, facing))
	# L'inclinaison spectaculaire d'un kick doit partir de la taille et non
	# faire pivoter tout le modele autour du pied. On garde donc les appuis
	# stables et on plie la ligne bassin-cage dans le plan visible camera.
	var local_roll := root_roll * cos(extra_turn)
	torso = (Basis(Vector3.FORWARD, local_roll) * torso).normalized()
	var g := []
	g.resize(_seg.size())

	g[AutoRig.B_HIPS] = _xform(hip_o, torso, AutoRig.B_HIPS, hip_twist)
	var chest: Vector3 = hip_o + torso * _len[AutoRig.B_HIPS]
	var spine_dir: Vector3 = external_motion.get("spine_dir", torso)
	g[AutoRig.B_SPINE] = _xform(chest, spine_dir, AutoRig.B_SPINE, chest_twist)
	var neck: Vector3 = chest + spine_dir * _len[AutoRig.B_SPINE]
	# La tete contre-rotative garde les yeux sur l'adversaire.
	var head_dir: Vector3 = external_motion.get("head_dir", torso)
	g[AutoRig.B_HEAD] = _xform(neck, head_dir, AutoRig.B_HEAD,
		chest_twist if using_external else chest_twist * 0.20)

	# Apres le pivot d'import, le cote gauche du modele est au premier plan.
	# Cette convention reste identique pour les bras et les jambes.
	var near_arm := AutoRig.B_UARM_L
	var far_arm := AutoRig.B_UARM_R
	if using_external or using_walk_neutral_arms:
		# Le rig Blender nomme les cotes selon l'anatomie du pantin, tandis que
		# l'auto-rig des skins les deduit de l'axe X du maillage source. Ces deux
		# conventions sont opposees. On croise donc uniquement les membres : le
		# torse garde son bon profil et la pose projetee reste celle de Blender.
		_chain_external(g, AutoRig.B_UARM_L,
			_rest_root(AutoRig.B_UARM_L, hip_o, torso, chest_twist), external_motion["arm_r"])
		_chain_external(g, AutoRig.B_UARM_R,
			_rest_root(AutoRig.B_UARM_R, hip_o, torso, chest_twist), external_motion["arm_l"])
	else:
		_chain_limb(g, far_arm, _rest_root(far_arm, hip_o, torso, chest_twist), d["sh"], d["arm_b"], facing)
		var hook_arc: float = float(d.get("hook_arc", 0.0))
		if src.move_name in ["hook", "body_hook"]:
			_chain_hook(g, near_arm, _rest_root(near_arm, hip_o, torso, chest_twist),
				d["sh"], d["arm_f"], facing, hook_arc, src.move_name == "body_hook")
		else:
			_chain_limb(g, near_arm, _rest_root(near_arm, hip_o, torso, chest_twist), d["sh"], d["arm_f"], facing)

	var near_leg := AutoRig.B_ULEG_L
	var far_leg := AutoRig.B_ULEG_R
	if using_external:
		_chain_external_leg(g, AutoRig.B_ULEG_L,
			_rest_root(AutoRig.B_ULEG_L, hip_o, torso, hip_twist), external_motion["leg_r"],
			external_motion["foot_r"])
		_chain_external_leg(g, AutoRig.B_ULEG_R,
			_rest_root(AutoRig.B_ULEG_R, hip_o, torso, hip_twist), external_motion["leg_l"],
			external_motion["foot_l"])
	else:
		_chain_leg(g, far_leg, _rest_root(far_leg, hip_o, torso, hip_twist), d["hip"], d["leg_b"], facing, false)
		_chain_leg(g, near_leg, _rest_root(near_leg, hip_o, torso, hip_twist), d["hip"], d["leg_f"], facing, src._is_kick())

	# Les clips signatures et la locomotion de reference remplacent les seules
	# articulations concernees. Le reste du corps conserve la pose de combat,
	# ce qui permet notamment de courir sans abandonner la garde.
	var motion_weight := float(motion.get("weight", 0.0))
	if motion_weight > 0.0001 and not using_external:
		# Le crochet est resout a partir de la cible du poing et d'un coude a
		# angle droit. Une capture brute de bras ne doit pas ecraser ce geste.
		var procedural_hook := src.move_name in ["hook", "body_hook"]
		if motion.has("arm_b") and not procedural_hook:
			_override_chain(g, far_arm, motion["arm_b"], motion_weight)
		if motion.has("arm_f") and not procedural_hook:
			_override_chain(g, near_arm, motion["arm_f"], motion_weight)
		if motion.has("leg_b"):
			_override_leg_chain(g, far_leg, motion["leg_b"], motion_weight, false)
		if motion.has("leg_f"):
			_override_leg_chain(g, near_leg, motion["leg_f"], motion_weight,
				src.state == Fighter.State.ATTACK and src._is_kick())

	# Contact au tapis. La pose choisit l'intention (stance, accroupissement,
	# frappe), puis cette passe place exactement la cheville d'appui au niveau
	# du sol et reconstruit hanche-genou-cheville. Le genou utilise toujours
	# +X comme direction de flexion anatomique.
	var grounded := src.is_on_floor() or src.global_position.y >= Fighter3D.GROUND_SIM_Y - 1.0
	if grounded and using_external:
		_ground_external(g, str(external_motion.get("support", "auto")), near_leg, far_leg)
	elif grounded:
		var leg_total := _len[near_leg] + _len[near_leg + 1]
		var stance := leg_total * 0.22
		var near_root: Vector3 = (g[near_leg] as Transform3D).origin
		var far_root: Vector3 = (g[far_leg] as Transform3D).origin
		if src.state == Fighter.State.WALK:
			# Un seul pied est en phase d'appui ; l'autre conserve sa trajectoire
			# de retour et passe reellement devant son partenaire.
			var front_support := fposmod(src._walk_cycle, 1.0) < 0.5
			if front_support:
				_plant_leg(g, near_leg, near_root,
					Vector3(near_root.x + stance, _ground_ankle_y, near_root.z))
			else:
				_plant_leg(g, far_leg, far_root,
					Vector3(far_root.x - stance, _ground_ankle_y, far_root.z))
		elif src.state == Fighter.State.ATTACK and src._is_kick():
			# La jambe arriere est l'appui de tous les kicks au sol.
			var support_width := stance * (2.30 if src.move_name == "spinning_kick" else 1.65)
			_plant_leg(g, far_leg, far_root,
				Vector3(far_root.x - support_width, _ground_ankle_y, far_root.z))
		else:
			_plant_leg(g, far_leg, far_root,
				Vector3(far_root.x - stance, _ground_ankle_y, far_root.z))
			_plant_leg(g, near_leg, near_root,
				Vector3(near_root.x + stance, _ground_ankle_y, near_root.z))

	# Les rotations de coups de pied et de poing retournes pivotent autour du
	# pied d'appui, pas autour du bassin. La compensation garde cet appui au
	# meme endroit pendant que tout le modele tourne.
	var lock_support := not using_external and src.state == Fighter.State.ATTACK and grounded \
		and (src._is_kick() or src.move_name == "spinning_backfist")
	if lock_support:
		var support_foot := AutoRig.B_FOOT_L if far_leg == AutoRig.B_ULEG_L else AutoRig.B_FOOT_R
		var current_support: Vector3 = (g[support_foot] as Transform3D).origin
		if _locked_move != src.move_name:
			_locked_move = src.move_name
			_support_anchor = current_support
		var mirror_basis := Basis.from_scale(Vector3(_k * facing, _k, _k))
		var base_basis := mirror_basis
		var full_basis := Basis(Vector3.UP, extra_turn) * mirror_basis
		holder.position = base_basis * _support_anchor - full_basis * current_support + root_shift
	else:
		_locked_move = ""

	_place_glove(_glove_l, g, AutoRig.B_LARM_L)
	_place_glove(_glove_r, g, AutoRig.B_LARM_R)

	# transformations globales -> poses locales
	for b in _seg.size():
		var parent: int = AutoRig.BONE_PARENT[b]
		var local: Transform3D = g[b] if parent < 0 else (g[parent] as Transform3D).affine_inverse() * (g[b] as Transform3D)
		sk.set_bone_pose_position(b, local.origin)
		sk.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())

	rotation = Vector3.ZERO if using_external else Vector3(0, 0, -float(d["spin"]))


func _rest_root(bone: int, hip_o: Vector3, torso: Vector3, twist: float) -> Vector3:
	# racine du membre : decalage lateral du repos, porte par le buste
	var rest_root: Vector3 = _seg[bone][0]
	var lateral := Vector3(0.0, 0.0, rest_root.z)
	lateral = Basis(torso, twist) * lateral
	var along: float = rest_root.y - _hip_rest
	return hip_o + torso * along + lateral


func _chain_limb(g: Array, upper: int, root: Vector3, origin2: Vector2,
		joints: Array, facing: float) -> void:
	var lower := upper + 1
	var mid2: Vector2 = joints[0]
	var end2: Vector2 = joints[1]
	var d1 := _dir3(mid2 - origin2, facing)
	var d2 := _dir3(end2 - mid2, facing)
	g[upper] = _xform(root, d1, upper)
	g[lower] = _xform(root + d1 * _len[upper], d2, lower)


func _chain_external(g: Array, upper: int, root: Vector3, directions: Array) -> void:
	var lower := upper + 1
	var d1: Vector3 = directions[0]
	var d2: Vector3 = directions[1]
	g[upper] = _xform(root, d1, upper)
	g[lower] = _xform(root + d1 * _len[upper], d2, lower)


func _chain_external_leg(g: Array, upper: int, root: Vector3, directions: Array,
		foot_direction: Vector3) -> void:
	_chain_external(g, upper, root, directions)
	var lower := upper + 1
	var foot := AutoRig.B_FOOT_L if upper == AutoRig.B_ULEG_L else AutoRig.B_FOOT_R
	var knee: Vector3 = (g[lower] as Transform3D).origin
	var ankle := knee + (directions[1] as Vector3) * _len[lower]
	g[foot] = _xform(ankle, foot_direction, foot)


func _ground_external(g: Array, support: String, near_leg: int, far_leg: int) -> void:
	if support == "none":
		return
	if support == "auto":
		support = "back" if src._is_kick() else "both"
	var foot_l: Vector3 = (g[AutoRig.B_FOOT_L] as Transform3D).origin
	var foot_r: Vector3 = (g[AutoRig.B_FOOT_R] as Transform3D).origin
	var wanted_y := minf(foot_l.y, foot_r.y)
	match support:
		"left": wanted_y = foot_l.y
		"right": wanted_y = foot_r.y
		"front":
			var front_foot := AutoRig.B_FOOT_L if near_leg == AutoRig.B_ULEG_L else AutoRig.B_FOOT_R
			wanted_y = (g[front_foot] as Transform3D).origin.y
		"back":
			var back_foot := AutoRig.B_FOOT_L if far_leg == AutoRig.B_ULEG_L else AutoRig.B_FOOT_R
			wanted_y = (g[back_foot] as Transform3D).origin.y
	var offset := _ground_ankle_y - wanted_y
	for i in g.size():
		var tr: Transform3D = g[i]
		tr.origin.y += offset
		g[i] = tr


func _override_chain(g: Array, upper: int, desired: Array, weight: float) -> void:
	var lower := upper + 1
	var root: Vector3 = (g[upper] as Transform3D).origin
	var base_d1: Vector3 = (g[upper] as Transform3D).basis.y.normalized()
	var base_d2: Vector3 = (g[lower] as Transform3D).basis.y.normalized()
	var d1 := base_d1.lerp(desired[0], weight).normalized()
	var d2 := base_d2.lerp(desired[1], weight).normalized()
	g[upper] = _xform(root, d1, upper)
	g[lower] = _xform(root + d1 * _len[upper], d2, lower)


func _override_leg_chain(g: Array, upper: int, desired: Array, weight: float,
		striking: bool) -> void:
	_override_chain(g, upper, desired, weight)
	var lower := upper + 1
	var foot := AutoRig.B_FOOT_L if upper == AutoRig.B_ULEG_L else AutoRig.B_FOOT_R
	var knee: Vector3 = (g[lower] as Transform3D).origin
	var shin_dir: Vector3 = (g[lower] as Transform3D).basis.y.normalized()
	var ankle := knee + shin_dir * _len[lower]
	var foot_dir := (shin_dir * 0.82 + Vector3.RIGHT * 0.18).normalized() \
		if striking else Vector3.RIGHT
	g[foot] = _xform(ankle, foot_dir, foot)


func _chain_hook(g: Array, upper: int, root: Vector3, origin2: Vector2,
		joints: Array, facing: float, amount: float, to_body: bool) -> void:
	# Le poing suit une cible claire : tempe pour le crochet haut, abdomen pour
	# le crochet bas. Le gant traverse aussi vers l'epaule opposee en profondeur :
	# la portee visible reste courte et le coup ne peut plus se lire comme un jab.
	var lower := upper + 1
	var base_d1 := _dir3((joints[0] as Vector2) - origin2, facing)
	var base_d2 := _dir3((joints[1] as Vector2) - (joints[0] as Vector2), facing)
	var total := _len[upper] + _len[lower]
	# Les deux directions sont specifiees dans l'espace de la camera, puis
	# reconverties dans l'espace du modele. La silhouette reste donc lisible
	# meme quand le torse a deja pivote : coude devant, gant replie vers soi.
	var world_to_local := Basis(Vector3.UP, -holder.rotation.y)
	var hook_d1_world := Vector3(0.78 * facing, -0.40, 0.48)
	var hook_d2_world := Vector3(0.625 * facing, 0.50, -0.60)
	if to_body:
		hook_d1_world = Vector3(0.78 * facing, -0.55, 0.30)
		hook_d2_world = Vector3(0.10 * facing, -0.36, -0.928)
	var hook_d1 := (world_to_local * hook_d1_world).normalized()
	var hook_d2 := (world_to_local * hook_d2_world).normalized()
	# Une petite protraction remplace la clavicule absente du rig automatique.
	root += world_to_local * Vector3(total * 0.05 * facing * amount, 0.0, 0.0)
	var d1 := base_d1.lerp(hook_d1, amount).normalized()
	var d2 := base_d2.lerp(hook_d2, amount).normalized()
	g[upper] = _xform(root, d1, upper)
	g[lower] = _xform(root + d1 * _len[upper], d2, lower)


func _plant_leg(g: Array, upper: int, root: Vector3, wanted: Vector3) -> void:
	var lower := upper + 1
	var foot := AutoRig.B_FOOT_L if upper == AutoRig.B_ULEG_L else AutoRig.B_FOOT_R
	var total := _len[upper] + _len[lower]
	# Si le bassin est haut, on rapproche horizontalement le pied juste assez
	# pour atteindre le tapis sans etirer la jambe au-dela de sa longueur.
	var dy := wanted.y - root.y
	var horizontal_max := sqrt(maxf(pow(total * 0.998, 2.0) - dy * dy, 0.0))
	var dx := clampf(wanted.x - root.x, -horizontal_max, horizontal_max)
	var target := Vector3(root.x + dx, wanted.y, wanted.z)
	var solved := _two_bone_directions(root, target,
		_len[upper], _len[lower], Vector3.RIGHT)
	var d1: Vector3 = solved[0]
	var d2: Vector3 = solved[1]
	var knee := root + d1 * _len[upper]
	g[upper] = _xform(root, d1, upper)
	g[lower] = _xform(knee, d2, lower)
	g[foot] = _xform(target, Vector3.RIGHT, foot)


func _two_bone_directions(root: Vector3, target: Vector3, l1: float, l2: float,
		bend_hint: Vector3) -> Array:
	var to_target := target - root
	var raw_dist := maxf(to_target.length(), 0.0001)
	var dist := clampf(raw_dist, absf(l1 - l2) + 0.0001, l1 + l2 - 0.0001)
	var aim := to_target / raw_dist
	var along := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var height := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var bend := bend_hint - aim * bend_hint.dot(aim)
	if bend.length_squared() < 0.000001:
		bend = Vector3.FORWARD - aim * Vector3.FORWARD.dot(aim)
	bend = bend.normalized()
	var knee := root + aim * along + bend * height
	var d1 := (knee - root).normalized()
	var d2 := (target - knee).normalized()
	return [d1, d2]


func _chain_leg(g: Array, upper: int, root: Vector3, origin2: Vector2,
		joints: Array, facing: float, striking: bool) -> void:
	var lower := upper + 1
	var foot := AutoRig.B_FOOT_L if upper == AutoRig.B_ULEG_L else AutoRig.B_FOOT_R
	var mid2: Vector2 = joints[0]
	var end2: Vector2 = joints[1]
	var d1 := _dir3(mid2 - origin2, facing)
	var d2 := _dir3(end2 - mid2, facing)
	g[upper] = _xform(root, d1, upper)
	var knee := root + d1 * _len[upper]
	g[lower] = _xform(knee, d2, lower)

	# En appui, la plante reste parallele au sol au lieu de tourner avec le
	# tibia. Pendant un coup de pied, elle prolonge naturellement la frappe.
	var foot_dir := Vector3(1, 0, 0)
	if striking:
		if src.move_name == "spinning_kick":
			# Back kick : cheville armee, orteils releves, impact par le talon.
			# L'ancienne continuation du tibia donnait un pied pointe de danseuse.
			foot_dir = Vector3.UP
		else:
			foot_dir = (d2 * 0.78 + Vector3(1, 0, 0) * 0.22).normalized()
	g[foot] = _xform(knee + d2 * _len[lower], foot_dir, foot)


func _dir3(v2: Vector2, facing: float) -> Vector3:
	# 2D (y vers le bas) -> 3D (y vers le haut) ; on annule la rotation
	# du support quand le personnage regarde a gauche
	var d := Vector3(v2.x, -v2.y, 0.0)
	if d.length_squared() < 0.000001:
		return Vector3(0, -1, 0)
	d = d.normalized()
	if facing < 0.0:
		d.x = -d.x
	return d


func _xform(origin: Vector3, dir: Vector3, bone: int, twist := 0.0) -> Transform3D:
	var axis := dir.normalized()
	var basis := Basis(axis, twist) * AutoRig._basis_from_dir(dir)
	return Transform3D(basis, origin)
