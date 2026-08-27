extends Node3D

# Capture courte du vrai rig utilisant une animation exportee depuis Blender.

const STEP := 1.0 / 60.0


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var world: Arena3D = load("res://arena3d.tscn").instantiate()
	add_child(world)
	for i in 12:
		await get_tree().physics_frame

	var arena := world.arena
	arena.phase = Arena.Phase.FIGHT
	arena.banner = ""
	arena.phase_t = 99.0
	arena.toast = ""
	var fighter: Fighter = arena.fighters[0]
	var victim: Fighter = arena.fighters[1]
	fighter.set_physics_process(false)
	victim.set_physics_process(false)
	fighter.frozen = true
	victim.frozen = true
	fighter.global_position = Vector2(470, 590)
	victim.global_position = Vector2(860, 590)
	fighter.facing = 1.0
	victim.facing = -1.0

	fighter._start_move("jab")
	for i in 5:
		fighter._tick_attack(STEP)
		fighter._animate(STEP)
		await RenderingServer.frame_post_draw
	await _shot("user://external_jab_review.png")

	arena.workshop.show_workshop()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await _shot("user://workshop_review.png")
	get_tree().paused = false
	get_tree().quit()


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", ProjectSettings.globalize_path(path))
