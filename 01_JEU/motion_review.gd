extends Node3D

# Regression visuelle en mouvement. Cette scene enregistre a 60 i/s l'avance,
# le recul et les dix coups au sol avec les vrais rigs importes.

const FPS := 60.0
const STEP := 1.0 / FPS

var world: Arena3D
var fighter: Fighter
var frame := 0
var output_dir := ""


func _ready() -> void:
	var focus := "--focus" in OS.get_cmdline_user_args()
	output_dir = ProjectSettings.globalize_path("user://motion_focus" if focus else "user://motion_review")
	DirAccess.make_dir_recursive_absolute(output_dir)
	world = load("res://arena3d.tscn").instantiate()
	add_child(world)
	for i in 12:
		await get_tree().physics_frame
	var arena := world.arena
	arena.phase = Arena.Phase.FIGHT
	arena.banner = ""
	arena.phase_t = 99.0
	arena.toast = ""
	fighter = arena.fighters[0]
	var victim: Fighter = arena.fighters[1]
	fighter.set_physics_process(false)
	victim.set_physics_process(false)
	fighter.frozen = true
	victim.frozen = true
	fighter.global_position = Vector2(500 if focus else 430, 590)
	victim.global_position = Vector2(760 if focus else 940, 590)
	fighter.facing = 1.0
	victim.facing = -1.0

	await _hold(10)
	if not focus:
		await _record_walk(52, 1.0)
		await _hold(10)
		await _record_walk(44, -1.0)
		await _hold(10)
	var moves := ["hook", "body_hook", "spinning_kick"] if focus else [
		"jab", "hook", "body_hook", "uppercut", "spinning_backfist",
		"middle_kick", "front_kick", "spinning_kick", "sweep", "high_kick"]
	for move_name in moves:
		await _record_move(move_name)
		await _hold(14)
	print("motion review: ", output_dir)
	get_tree().quit()


func _record_walk(count: int, direction: float) -> void:
	fighter.state = Fighter.State.WALK
	fighter.velocity.x = (Fighter.FORWARD_SPEED if direction > 0.0 else -Fighter.BACK_SPEED)
	for i in count:
		fighter.global_position.x += fighter.velocity.x * STEP
		fighter._animate(STEP)
		await _shot()
	fighter.state = Fighter.State.IDLE
	fighter.velocity = Vector2.ZERO
	fighter._animate(STEP)


func _record_move(move_name: String) -> void:
	fighter.state = Fighter.State.IDLE
	fighter.velocity = Vector2.ZERO
	fighter._animate(STEP)
	fighter._start_move(move_name)
	var safety := 0
	while fighter.state == Fighter.State.ATTACK and safety < 180:
		fighter._tick_attack(STEP)
		fighter._animate(STEP)
		await _shot()
		safety += 1


func _hold(count: int) -> void:
	for i in count:
		fighter._animate(STEP)
		await _shot()


func _shot() -> void:
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join("frame_%04d.png" % frame)
	get_viewport().get_texture().get_image().save_png(path)
	frame += 1
