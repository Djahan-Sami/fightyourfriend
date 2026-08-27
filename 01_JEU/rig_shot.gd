extends Node3D

# Outil de debug : rigge le modele et le photographie
#   1. avec les os affiches sur le modele
#   2. deforme dans plusieurs poses, pour juger la qualite des poids

var cam: Camera3D
var sk: Skeleton3D
var mi: MeshInstance3D
var seg: Array
var lm: Dictionary


func _ready() -> void:
	get_window().size = Vector2i(1000, 900)
	_light()
	var skins := GameSettings.available_skins()
	if skins.is_empty():
		print("Aucun modele GLB ou GLTF dans 03_SKINS_PERSONNAGES.")
		get_tree().quit(1)
		return

	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var model_path := str(skins[0]["path"])
	if doc.append_from_file(model_path, st) != OK:
		print("chargement impossible")
		get_tree().quit(1)
		return
	var src := doc.generate_scene(st)
	var src_mi: MeshInstance3D = _first_mesh(src)
	var aabb: AABB = src_mi.get_aabb()

	var t0 := Time.get_ticks_msec()
	var r := AutoRig.build(src_mi.mesh, aabb)
	print("rigging calcule en %d ms" % (Time.get_ticks_msec() - t0))
	seg = r["segments"]
	lm = r["landmarks"]

	sk = AutoRig.make_skeleton(seg)
	add_child(sk)
	mi = MeshInstance3D.new()
	mi.mesh = r["mesh"]
	mi.skeleton = NodePath("..")
	sk.add_child(mi)
	mi.skin = sk.create_skin_from_rest_transforms()

	print("=== REPERES (fraction de la taille) ===")
	var h: float = lm["h"]
	for k in ["hips", "chest", "neck", "sh_r", "el_r", "wr_r", "hip_r", "kn_r", "an_r"]:
		var p: Vector3 = lm[k]
		print("  %-8s x=%+.3f y=%.3f (%.2f h)" % [k, p.x, p.y, p.y / h])

	_draw_bones()
	await _shot(Vector3(0, lm["h"] * 0.5, lm["h"] * 1.7), "user://rig_os.png")

	# poses de test : bras leve, coude plie, genou plie
	_bone_zrot(AutoRig.B_UARM_R, -1.15)
	_bone_zrot(AutoRig.B_LARM_R, -1.30)
	_bone_zrot(AutoRig.B_UARM_L, 0.55)
	_bone_zrot(AutoRig.B_ULEG_R, 0.95)
	_bone_zrot(AutoRig.B_LLEG_R, -1.35)
	_bone_zrot(AutoRig.B_SPINE, 0.18)
	await _shot(Vector3(0, lm["h"] * 0.5, lm["h"] * 1.7), "user://rig_pose.png")
	get_tree().quit()


func _bone_zrot(b: int, ang: float) -> void:
	var rest := sk.get_bone_rest(b)
	sk.set_bone_pose_rotation(b, rest.basis.get_rotation_quaternion()
		* Quaternion(Vector3(0, 0, 1), ang))


func _draw_bones() -> void:
	for b in seg.size():
		var s: Array = seg[b]
		var im := ImmediateMesh.new()
		var node := MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.25, 0.15)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		im.surface_begin(Mesh.PRIMITIVE_LINES, m)
		im.surface_add_vertex(s[0])
		im.surface_add_vertex(s[1])
		im.surface_end()
		node.mesh = im
		add_child(node)


func _light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.8)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-38, -32, 0)
	l.light_energy = 1.6
	add_child(l)
	cam = Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.make_current()


func _shot(at: Vector3, path: String) -> void:
	cam.position = at
	cam.look_at(Vector3(0, lm["h"] * 0.5, 0), Vector3.UP)
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", ProjectSettings.globalize_path(path))


func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null
