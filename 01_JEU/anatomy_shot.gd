extends Node3D

# Regression visuelle des trois temps d'un coup : arme, impact, retour.

var world: Arena3D


func _ready() -> void:
	world = load("res://arena3d.tscn").instantiate()
	add_child(world)
	for i in 12:
		await get_tree().physics_frame

	var arena := world.arena
	arena.phase = Arena.Phase.FIGHT
	arena.banner = ""
	arena.phase_t = 99.0
	arena.toast = ""
	for f in arena.fighters:
		f.frozen = false
	arena.fighters[0].global_position = Vector2(500, 590)
	arena.fighters[1].global_position = Vector2(820, 590)
	for i in 3:
		await get_tree().physics_frame

	var fighter: Fighter = arena.fighters[0]
	fighter.facing = 1.0
	fighter._start_move("high_kick")
	for i in 2:
		await get_tree().physics_frame
	await _shot("user://kick_windup.png")
	while fighter.state == Fighter.State.ATTACK and fighter._phase < 1:
		await get_tree().physics_frame
	await _shot("user://kick_impact.png")
	while fighter.state == Fighter.State.ATTACK and fighter._phase < 2:
		await get_tree().physics_frame
	for i in 2:
		await get_tree().physics_frame
	await _shot("user://kick_recovery.png")
	while fighter.state == Fighter.State.ATTACK:
		await get_tree().physics_frame
	for i in 8:
		await get_tree().physics_frame

	fighter._start_move("jab")
	await get_tree().physics_frame
	await _shot("user://jab_windup.png")
	while fighter.state == Fighter.State.ATTACK and fighter._phase < 1:
		await get_tree().physics_frame
	await _shot("user://jab_impact.png")
	while fighter.state == Fighter.State.ATTACK and fighter._phase < 2:
		await get_tree().physics_frame
	for i in 2:
		await get_tree().physics_frame
	await _shot("user://jab_recovery.png")
	while fighter.state == Fighter.State.ATTACK:
		await get_tree().physics_frame
	# Marche reelle : le personnage avance pendant que la pose est echantillonnee.
	# Un test immobile ne peut pas reveler le patinage des pieds.
	fighter.set_physics_process(false)
	fighter.state = Fighter.State.WALK
	fighter.velocity.x = Fighter.FORWARD_SPEED
	for i in 12:
		fighter.global_position.x += fighter.velocity.x / 60.0
		fighter._animate(1.0 / 60.0)
		await get_tree().physics_frame
	await _shot("user://walk_stride_a.png")
	for i in 12:
		fighter.global_position.x += fighter.velocity.x / 60.0
		fighter._animate(1.0 / 60.0)
		await get_tree().physics_frame
	await _shot("user://walk_stride_b.png")

	# Controle des vraies phases en jeu pour les coups dont la trajectoire
	# compte davantage que la seule silhouette finale.
	fighter.frozen = false
	fighter.state = Fighter.State.IDLE
	fighter.velocity = Vector2.ZERO
	fighter.set_physics_process(true)
	for phase_move in ["hook", "body_hook", "spinning_kick"]:
		fighter._start_move(phase_move)
		for i in 3:
			await get_tree().physics_frame
		await _shot("user://motion_%s_windup.png" % phase_move)
		while fighter.state == Fighter.State.ATTACK and fighter._phase < 1:
			await get_tree().physics_frame
		await get_tree().physics_frame
		await _shot("user://motion_%s_impact.png" % phase_move)
		while fighter.state == Fighter.State.ATTACK and fighter._phase < 2:
			await get_tree().physics_frame
		for i in 2:
			await get_tree().physics_frame
		await _shot("user://motion_%s_recovery.png" % phase_move)
		while fighter.state == Fighter.State.ATTACK:
			await get_tree().physics_frame
		for i in 4:
			await get_tree().physics_frame
	fighter.frozen = true

	# Galerie des dix coups au sol actuellement accessibles.
	fighter.set_physics_process(false)
	var victim: Fighter = arena.fighters[1]
	victim.set_physics_process(false)
	fighter.frozen = true
	fighter.global_position.y = 590.0
	var ground_moves := ["jab", "hook", "spinning_backfist", "uppercut", "body_hook",
		"middle_kick", "front_kick", "spinning_kick", "sweep", "high_kick"]
	for move_name in ground_moves:
		fighter.move_name = move_name
		fighter._move = Fighter.MOVES[move_name]
		fighter._pose = fighter._copy_pose(Fighter.POSES[fighter._move["pose"]])
		fighter._body_twist = fighter._attack_twist(1.0)
		fighter._turn_y = 3.45 if move_name in ["spinning_backfist", "spinning_kick"] \
			else fighter._attack_yaw_amount() * fighter.facing
		await _shot("user://ground_%s.png" % move_name)

	# Galerie des quatre projections au point culminant de leur preparation.
	for dir_name in ["down", "back", "front", "up"]:
		fighter.global_position = Vector2(500, 590)
		fighter._spin = 0.0
		fighter._turn_y = 0.0
		fighter._pose = fighter._copy_pose(Fighter.POSES[Fighter.THROWS[dir_name]["pose"]])
		victim._pose = victim._copy_pose(Fighter.POSES["hurt"])
		victim.global_position = Vector2(542, 590)
		victim._spin = 0.0
		fighter._grab_victim = victim
		fighter._throw_dir = dir_name
		fighter._t = 0.0
		fighter._choreograph_throw()
		await _shot("user://throw_%s.png" % dir_name)
	get_tree().quit()


func _shot(path: String) -> void:
	for i in 2:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", ProjectSettings.globalize_path(path))
