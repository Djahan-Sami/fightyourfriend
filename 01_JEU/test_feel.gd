extends Node2D

# Mesure la reactivite : duree reelle des coups et fiabilite du buffer d'entrees.
#   godot --headless --path . res://test_feel.tscn

const GROUND_Y := 590.0
const STEP := 1.0 / 60.0

var _fails := 0
var f1: Fighter
var f2: Fighter


func _ready() -> void:
	for i in 2:
		for a in ["left", "right", "up", "down", "jump", "punch", "kick", "grab"]:
			var act := "p%d_%s" % [i + 1, a]
			if not InputMap.has_action(act):
				InputMap.add_action(act)
	_build_ground()
	await get_tree().physics_frame
	await _spawn()
	await _run()
	print("")
	print("RESULTAT : ", "OK" if _fails == 0 else "%d ECHEC(S)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _build_ground() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(4000, 400)
	cs.shape = r
	cs.position = Vector2(640, GROUND_Y + 200.0)
	body.add_child(cs)
	add_child(body)


func _spawn() -> void:
	f1 = Fighter.new()
	f1.setup(0, Vector2(300, GROUND_Y), Color.BLUE, Color.DARK_BLUE)
	add_child(f1)
	f2 = Fighter.new()
	f2.setup(1, Vector2(900, GROUND_Y), Color.RED, Color.DARK_RED)   # hors de portee
	add_child(f2)
	f1.opponent = f2
	f2.opponent = f1
	for i in 5:
		await get_tree().physics_frame


# IDLE seul ne suffit pas : au repos le combattant leve automatiquement
# sa garde et passe en BLOCK. On attend un etat "ou l'on peut agir".
func _wait_ready() -> bool:
	for i in 200:
		if f1.state in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.BLOCK]:
			return true
		await get_tree().physics_frame
	return false


func _check(label: String, cond: bool) -> void:
	if cond:
		print("  ok   : ", label)
	else:
		print("  ECHEC: ", label)
		_fails += 1


func _measure(move: String) -> int:
	await _wait_ready()
	f1._start_move(move)
	var n := 0
	while f1.state == Fighter.State.ATTACK and n < 200:
		await get_tree().physics_frame
		n += 1
	return n


func _run() -> void:
	print("A. duree totale des coups (frames a 60 Hz, dans le vide)")
	var budget := {
		"jab": 16, "hook": 29, "body_hook": 31, "uppercut": 35,
		"spinning_backfist": 38, "middle_kick": 27, "front_kick": 34,
		"spinning_kick": 40, "high_kick": 31, "sweep": 35, "air_punch": 21,
	}
	for m in budget.keys():
		var n := await _measure(m)
		var mv: Dictionary = Fighter.MOVES[m]
		var theo := (float(mv["startup"]) + float(mv["active"]) + float(mv["recover"])) / STEP
		print("     %-10s %2d frames (%3.0f ms)   theorique %.1f   surcout %+.1f" %
			[m, n, n * STEP * 1000.0, theo, n - theo])
		_check("%s tient dans %d frames" % [m, budget[m]], n <= int(budget[m]))
		_check("%s ne gaspille pas de frame" % m, float(n) - theo < 2.0)

	print("B. le buffer ne perd pas un appui fait pendant la recuperation")
	await _wait_ready()
	f1._start_move("middle_kick")          # gros coup = longue recuperation
	for i in 60:
		if f1._phase >= 2:
			break
		await get_tree().physics_frame
	# on appuie au milieu de la recuperation (cas realiste d'un joueur
	# qui enchaine, pas d'un appui 200 ms trop tot)
	for i in 4:
		await get_tree().physics_frame
	var was := f1.move_name
	Input.action_press("p1_punch")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("p1_punch")
	_check("l'appui est memorise ou deja consomme",
		f1._buf == "punch" or (f1.state == Fighter.State.ATTACK and f1.move_name != was))

	var relance := -1
	for i in 40:
		if f1.state == Fighter.State.ATTACK and f1.move_name != was:
			relance = i
			break
		await get_tree().physics_frame
	_check("le coup suivant part tout seul", relance >= 0)
	print("     (parti %d frames apres l'appui)" % maxi(relance, 0))

	print("C. un appui trop ancien ne doit PAS ressortir")
	await _wait_ready()
	f1._buf = "punch"
	f1._buf_t = 0.001                      # quasi expire
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("le buffer expire bien", f1._buf == "" and f1.state != Fighter.State.ATTACK)

	print("D. la garde se leve vite")
	_check("garde sous 0.12 s", Fighter.BLOCK_RAISE <= 0.12)
	print("     (BLOCK_RAISE = %.2f s, buffer = %.2f s)" % [Fighter.BLOCK_RAISE, Fighter.BUFFER_TIME])

	print("E. les pieds annulent le deplacement du corps pendant l'appui")
	var foot_contact_a: Vector2 = f1._gait_foot(0.0, 1.0, 48.0, 5.5)
	var foot_contact_b: Vector2 = f1._gait_foot(0.5, 1.0, 48.0, 5.5)
	_check("pied avant plante sur une longueur de pas",
		absf(foot_contact_a.x - (48.0 + foot_contact_b.x)) < 0.01)
	var back_contact_a: Vector2 = f1._gait_foot(0.0, -1.0, 40.0, 4.0)
	var back_contact_b: Vector2 = f1._gait_foot(0.5, -1.0, 40.0, 4.0)
	_check("pied plante aussi en recul",
		absf(back_contact_a.x - (-40.0 + back_contact_b.x)) < 0.01)
	var gait := CombatMotion.sample_gait(0.0, 1.0)
	_check("les cuisses partent en opposition",
		float(gait["leg_f"][0].x) * float(gait["leg_b"][0].x) < 0.0)
	var retreat_gait := CombatMotion.sample_gait(0.25, -1.0)
	_check("le recul ne retourne pas le squelette des jambes",
		float(retreat_gait["weight"]) < 0.01)

	print("F. les variantes aeriennes sont toutes presentes")
	for move in ["air_punch", "air_upper", "air_hammer", "air_cross", "air_backfist",
		"air_kick", "air_rising_kick", "dive_kick", "air_side_kick", "air_roundhouse"]:
		_check("%s disponible" % move, Fighter.MOVES.has(move))
	f1.global_position.y = GROUND_Y - 120.0
	f1.velocity = Vector2.ZERO
	f1.state = Fighter.State.AIR
	await get_tree().physics_frame
	var air_cases := {
		"up": ["air_upper", "air_rising_kick"],
		"down": ["air_hammer", "dive_kick"],
		"right": ["air_cross", "air_side_kick"],
		"left": ["air_backfist", "air_roundhouse"],
	}
	for dir_name in air_cases:
		Input.action_press("p1_" + dir_name)
		_check("air %s + poing" % dir_name, f1._pick("punch") == air_cases[dir_name][0])
		_check("air %s + pied" % dir_name, f1._pick("kick") == air_cases[dir_name][1])
		Input.action_release("p1_" + dir_name)
	_check("air neutre + poing", f1._pick("punch") == "air_punch")
	_check("air neutre + pied", f1._pick("kick") == "air_kick")
	f1.global_position.y = GROUND_Y
	f1.state = Fighter.State.IDLE
	for i in 3:
		await get_tree().physics_frame

	print("G. la collision suit la pose de contact")
	await _wait_ready()
	f1._start_move("hook")
	for i in 30:
		if f1._phase == 1:
			break
		await get_tree().physics_frame
	await get_tree().physics_frame
	_check("le crochet est a hauteur de tete", f1.hitbox_shape.position.y < -70.0)
	_check("la pose de contact est atteinte pendant les frames actives",
		absf(float(f1._pose["arm_f"][0]) - float(Fighter.POSES["hook"]["arm_f"][0])) < 0.05)
	var hook_motion := CombatMotion.sample_attack("hook", 0.36)
	_check("le crochet conserve un coude proche de 90 degres",
		absf((hook_motion["arm_f"][0] as Vector3).dot(hook_motion["arm_f"][1])) < 0.35)
	for captured_move in ["jab", "hook", "body_hook", "uppercut", "front_kick",
			"middle_kick", "high_kick"]:
		var captured := CombatMotion.sample_attack(captured_move, 0.35)
		_check("%s possede une trajectoire corporelle" % captured_move,
			captured.has("arm_f") and float(captured["weight"]) > 0.80)
	var spin_motion := CombatMotion.sample_attack("spinning_kick", 0.42)
	_check("le coup retourne incline le buste sans posture de danseuse",
		float(spin_motion["roll"]) > 0.28 and float(spin_motion["roll"]) < 0.42)

	print("H. garde, block-stun et reaction localisee")
	while f1.state == Fighter.State.ATTACK:
		await get_tree().physics_frame
	f1.global_position = Vector2(500, GROUND_Y)
	f2.global_position = Vector2(560, GROUND_Y)
	f1.facing = 1.0
	f2.facing = -1.0
	f2.state = Fighter.State.BLOCK
	f2.block_energy = 1.0
	var hp_before_block := f2.hp
	var x_before_block := f2.global_position.x
	f1._start_move("jab")
	for i in 40:
		if f2._block_stun > 0.0:
			break
		await get_tree().physics_frame
	_check("le defenseur recoit son block-stun", f2._block_stun > 0.0)
	_check("la garde ne prend que des degats reduits", f2.hp < hp_before_block and f2.hp > hp_before_block - 3.0)
	_check("la garde absorbe le coup sans faire reculer le defenseur",
		absf(f2.global_position.x - x_before_block) < 0.01)
	while f1.state == Fighter.State.ATTACK:
		await get_tree().physics_frame
	# On replace les deux combattants pour isoler la reaction du crochet.
	f1.global_position = Vector2(500, GROUND_Y)
	f2.global_position = Vector2(560, GROUND_Y)
	f1.velocity = Vector2.ZERO
	f2.velocity = Vector2.ZERO
	f2.state = Fighter.State.IDLE
	f2._block_stun = 0.0
	f2.frozen = true
	var hp_before_hit := f2.hp
	f1._start_move("hook")
	for i in 50:
		if f2.hp < hp_before_hit:
			break
		await get_tree().physics_frame
	_check("le crochet atteint bien la cible", f2.hp < hp_before_hit)
	_check("un coup haut declenche la reaction de tete", f2._hurt_pose_name == "hurt_head")
	f2.frozen = false
