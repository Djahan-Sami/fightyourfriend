extends Node3D

# Outil de debug : photographie l'arene 3D, au repos puis en plein coup.

var world: Arena3D


func _ready() -> void:
	world = load("res://arena3d.tscn").instantiate()
	add_child(world)
	for i in 12:
		await get_tree().physics_frame

	var a := world.arena
	a.phase = Arena.Phase.FIGHT
	a.banner = ""
	a.phase_t = 99.0
	a.toast = ""
	a.toast_t = 0.0
	for f in a.fighters:
		f.frozen = false

	a.fighters[0].global_position = Vector2(560, 590)
	a.fighters[1].global_position = Vector2(632, 590)   # a portee de coup
	for i in 3:
		await get_tree().physics_frame
	await _shot("user://3d_idle.png", 3)

	a.fighters[0].facing = 1.0
	a.fighters[0]._start_move("high_kick")
	for i in 60:
		await get_tree().physics_frame
		if a.fighters[1].hp < Fighter.MAX_HP:
			break
	await _shot("user://3d_hit.png", 2)
	await _shot("user://3d_hit2.png", 12)

	# mesure de performance : combat en cours, deux modeles rigges
	Engine.time_scale = 1.0
	for i in 20:
		await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	var n := 180
	for i in n:
		await RenderingServer.frame_post_draw
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	print("PERF : %.2f ms/frame  (%.0f i/s)" % [ms, 1000.0 / maxf(ms, 0.001)])
	get_tree().quit()


func _shot(path: String, frames: int) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", ProjectSettings.globalize_path(path))
