extends Node2D

# Outil de debug : declenche un vrai coup dans la vraie arene et
# photographie l'impact, puis quelques instants plus tard.

var arena: Arena
var f1: Fighter
var f2: Fighter


func _ready() -> void:
	arena = load("res://arena.tscn").instantiate()
	add_child(arena)
	for i in 6:
		await get_tree().physics_frame

	f1 = arena.fighters[0]
	f2 = arena.fighters[1]
	arena.phase = Arena.Phase.FIGHT
	arena.banner = ""
	arena.phase_t = 99.0
	for f in arena.fighters:
		f.frozen = false

	f1.global_position = Vector2(560, 590)
	f2.global_position = Vector2(632, 590)
	await get_tree().physics_frame

	f1.facing = 1.0
	f1._start_move("high_kick")

	# on attend l'impact
	for i in 60:
		await get_tree().physics_frame
		if f2.hp < Fighter.MAX_HP:
			break

	await _shot("user://impact_a.png", 2)
	await _shot("user://impact_b.png", 14)
	get_tree().quit()


func _shot(path: String, frames: int) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved: ", ProjectSettings.globalize_path(path))
