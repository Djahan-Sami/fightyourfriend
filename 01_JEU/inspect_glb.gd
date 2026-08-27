extends Node3D

# Outil de debug : charge un .glb a l'execution, decrit sa structure
# et le photographie de face et de profil.

var cam: Camera3D
var model: Node3D


func _ready() -> void:
	get_window().size = Vector2i(900, 900)
	_light()
	var skins := GameSettings.available_skins()
	if skins.is_empty():
		print("Aucun modele GLB ou GLTF dans 03_SKINS_PERSONNAGES.")
		get_tree().quit(1)
		return

	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var model_path := str(skins[0]["path"])
	var err := doc.append_from_file(model_path, st)
	if err != OK:
		print("ECHEC de chargement : ", err)
		get_tree().quit(1)
		return
	model = doc.generate_scene(st)
	add_child(model)

	print("=== ARBRE ===")
	_dump(model, 0)

	var aabb := _aabb(model)
	print("=== GEOMETRIE ===")
	print("  AABB position : ", aabb.position)
	print("  AABB taille   : ", aabb.size)
	print("  hauteur/largeur/profondeur : %.3f / %.3f / %.3f"
		% [aabb.size.y, aabb.size.x, aabb.size.z])
	var ratio := aabb.size.x / maxf(aabb.size.y, 0.0001)
	print("  ratio largeur/hauteur : %.2f  (T-pose ~0.9-1.1, bras le long du corps ~0.25-0.4)" % ratio)
	print("  squelette trouve : ", _find_skeleton(model) != null)
	print("  sommets : ", _verts(model))

	# recentre et cadre le modele
	var h: float = maxf(aabb.size.y, 0.001)
	model.position = -aabb.get_center()
	var d := h * 1.9

	await _shot(Vector3(0, 0, d), "user://glb_face.png")
	await _shot(Vector3(d, 0, 0), "user://glb_profil.png")
	await _shot(Vector3(d * 0.7, h * 0.25, d * 0.7), "user://glb_trois_quarts.png")
	get_tree().quit()


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
	l.rotation_degrees = Vector3(-40, -35, 0)
	l.light_energy = 1.6
	add_child(l)

	cam = Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.make_current()


func _shot(at: Vector3, path: String) -> void:
	cam.position = at
	cam.look_at(Vector3.ZERO, Vector3.UP)
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", ProjectSettings.globalize_path(path))


func _dump(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var extra := ""
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		extra = " [mesh surfaces=%d]" % mi.mesh.get_surface_count() if mi.mesh else " [pas de mesh]"
	elif n is Skeleton3D:
		extra = " [OS: %d]" % (n as Skeleton3D).get_bone_count()
	print(pad, n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		_dump(c, depth + 1)


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(n):
		var b: AABB = mi.global_transform * mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func _verts(n: Node) -> int:
	var total := 0
	for mi in _meshes(n):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			total += mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size()
	return total


func _meshes(n: Node, acc: Array = []) -> Array:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_meshes(c, acc)
	return acc
