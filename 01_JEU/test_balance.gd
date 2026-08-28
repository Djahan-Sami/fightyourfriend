extends Node2D

const GROUND_Y := 590.0

var _fails := 0
var f1: Fighter
var f2: Fighter
var resolver: Arena


func _ready() -> void:
	for i in 2:
		for action in ["left", "right", "up", "down", "jump", "punch", "kick", "grab"]:
			var input_name := "p%d_%s" % [i + 1, action]
			if not InputMap.has_action(input_name):
				InputMap.add_action(input_name)
	_build_ground()
	_spawn()
	for i in 5:
		await get_tree().physics_frame
	await _test_down_and_wakeup()
	await _test_guard_break_protection()
	_test_combo_scaling()
	_test_simultaneous_strikes()
	print("")
	print("RESULTAT EQUILIBRAGE : ", "OK" if _fails == 0 else "%d ECHEC(S)" % _fails)
	Engine.time_scale = 1.0
	Arena._inst = null
	resolver.free()
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("  ok   : ", label)
	else:
		print("  ECHEC: ", label)
		_fails += 1


func _build_ground() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 400)
	shape.shape = rect
	shape.position = Vector2(640, GROUND_Y + 200)
	body.add_child(shape)
	add_child(body)


func _spawn() -> void:
	f1 = Fighter.new()
	f1.setup(0, Vector2(500, GROUND_Y), Color.BLUE, Color.DARK_BLUE)
	add_child(f1)
	f2 = Fighter.new()
	f2.setup(1, Vector2(570, GROUND_Y), Color.RED, Color.DARK_RED)
	add_child(f2)
	f1.opponent = f2
	f2.opponent = f1
	resolver = Arena.new()
	Arena._inst = resolver


func _reset_fighters() -> void:
	Engine.time_scale = 1.0
	Arena._inst = null
	f1.reset_round()
	f2.reset_round()
	f1.global_position = Vector2(500, GROUND_Y)
	f2.global_position = Vector2(570, GROUND_Y)
	f1.facing = 1.0
	f2.facing = -1.0


func _test_down_and_wakeup() -> void:
	print("A. chute, sol et relevee")
	_reset_fighters()
	f2.on_hit(Fighter.MOVES["sweep"], 1.0, 0.0, Vector2.INF,
		false, "kick", "sweep")
	for i in 120:
		if f2.state == Fighter.State.DOWN:
			break
		await get_tree().physics_frame
	_check("la balayette conduit a un vrai etat au sol", f2.state == Fighter.State.DOWN)
	var hp_down := f2.hp
	for i in 8:
		f2.on_hit(Fighter.MOVES["jab"], 1.0, 0.0, Vector2.INF,
			false, "punch", "jab")
	_check("aucune frappe ne touche au sol", is_equal_approx(f2.hp, hp_down))
	_check("une saisie ne prend pas un adversaire au sol", not f2._can_be_grabbed())

	# Le bouton presse pendant la chute doit partir des la fin de la relevee.
	f2._buf = "punch"
	f2._buf_t = Fighter.BUFFER_TIME
	var attacked_on_wakeup := false
	for i in 120:
		await get_tree().physics_frame
		if f2.state == Fighter.State.ATTACK:
			attacked_on_wakeup = true
			break
	_check("le dernier ordre est conserve pendant la relevee", attacked_on_wakeup)

	print("B. anti-spam pendant toute la phase protegee")
	_reset_fighters()
	f2.on_hit(Fighter.MOVES["spinning_kick"], 1.0, 0.0, Vector2.INF,
		false, "kick", "spinning_kick")
	for i in 150:
		if f2.state == Fighter.State.DOWN:
			break
		await get_tree().physics_frame
	var protected_hp := f2.hp
	var protected_frames := 0
	for i in 120:
		if f2.state not in [Fighter.State.DOWN, Fighter.State.GETUP]:
			break
		f2.on_hit(Fighter.MOVES["middle_kick"], 1.0, 0.0, Vector2.INF,
			false, "kick", "middle_kick")
		protected_frames += 1
		await get_tree().physics_frame
	_check("le spam ne rajoute aucun degat au sol ou pendant la relevee",
		protected_frames > 20 and is_equal_approx(f2.hp, protected_hp))
	print("     (frames protegees: %d, vie: %.2f -> %.2f, etat: %s)" %
		[protected_frames, protected_hp, f2.hp, Fighter.State.keys()[f2.state]])


func _test_guard_break_protection() -> void:
	print("C. garde brisee")
	_reset_fighters()
	f2.state = Fighter.State.BLOCK
	f2.block_energy = 0.0
	f2._tick_block(1.0 / 60.0)
	_check("la garde brisee ouvre une fenetre de punition", f2.state == Fighter.State.HURT)
	f2.on_hit(Fighter.MOVES["jab"], 1.0, 0.0, Vector2.INF,
		false, "punch", "jab")
	_check("la premiere punition met fin a la boucle par une chute", f2._knockdown)


func _test_combo_scaling() -> void:
	print("D. combos et repetition")
	_reset_fighters()
	var move := Fighter.MOVES["body_hook"].duplicate(true)
	move["dmg"] = 10.0
	move["kb"] = Vector2.ZERO
	move["hitstun"] = 1.0
	move["box"] = Vector2(40, -50)
	var hp_before := f2.hp
	f2.on_hit(move, 1.0, 0.0, Vector2.INF, false, "punch", "a")
	f2.on_hit(move, 1.0, 0.0, Vector2.INF, false, "punch", "b")
	f2.on_hit(move, 1.0, 0.0, Vector2.INF, false, "punch", "c")
	_check("les degats diminuent au fil du combo",
		is_equal_approx(hp_before - f2.hp, 25.5))

	_reset_fighters()
	for i in 3:
		f2.on_hit(move, 1.0, 0.0, Vector2.INF, false, "punch", "repeat")
	_check("la troisieme repetition identique force une chute", f2._knockdown)


func _arm_for_exchange(fighter: Fighter, move_name_: String) -> void:
	fighter._move = AttackLibrary.apply_to_move(move_name_, Fighter.MOVES[move_name_])
	fighter.move_name = move_name_
	fighter.state = Fighter.State.ATTACK
	fighter._phase = 1
	fighter._hit_done = true
	fighter.hitbox.monitoring = true


func _test_simultaneous_strikes() -> void:
	print("E. coups simultanes")
	_reset_fighters()
	Arena._inst = resolver
	_arm_for_exchange(f1, "jab")
	_arm_for_exchange(f2, "jab")
	resolver._pending_strikes = [
		{"attacker": f1, "defender": f2},
		{"attacker": f2, "defender": f1},
	]
	resolver._resolve_pending_strikes()
	_check("deux coups de meme force s'annulent", f1.hp == Fighter.MAX_HP \
		and f2.hp == Fighter.MAX_HP and f1._phase == 2 and f2._phase == 2)

	_reset_fighters()
	_arm_for_exchange(f1, "jab")
	_arm_for_exchange(f2, "front_kick")
	resolver._pending_strikes = [
		{"attacker": f1, "defender": f2},
		{"attacker": f2, "defender": f1},
	]
	resolver._resolve_pending_strikes()
	_check("le coup aux plus gros degats remporte l'echange",
		f1.hp < Fighter.MAX_HP and f2.hp == Fighter.MAX_HP)

	_reset_fighters()
	_arm_for_exchange(f1, "jab")
	_arm_for_exchange(f2, "jab")
	resolver._pending_strikes = [
		{"attacker": f2, "defender": f1},
		{"attacker": f1, "defender": f2},
	]
	resolver._resolve_pending_strikes()
	_check("le resultat ne depend plus de l'ordre J1/J2",
		f1.hp == Fighter.MAX_HP and f2.hp == Fighter.MAX_HP)
