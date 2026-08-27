extends Node2D

# Test d'integration du grab / projection. Se lance en headless :
#   godot --headless --path . res://test_grab.tscn

const GROUND_Y := 590.0

var _fails := 0
var f1: Fighter
var f2: Fighter


func _ready() -> void:
	_register_actions()
	_build_ground()
	await get_tree().physics_frame
	await _run()
	print("")
	print("RESULTAT : ", "OK" if _fails == 0 else "%d ECHEC(S)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _register_actions() -> void:
	for i in 2:
		for a in ["left", "right", "up", "down", "jump", "punch", "kick", "grab"]:
			var action := "p%d_%s" % [i + 1, a]
			if not InputMap.has_action(action):
				InputMap.add_action(action)


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
	if is_instance_valid(f1):
		f1.queue_free()
		f2.queue_free()
		await get_tree().physics_frame
	f1 = Fighter.new()
	f1.setup(0, Vector2(400, GROUND_Y), Color.BLUE, Color.DARK_BLUE)
	add_child(f1)
	f2 = Fighter.new()
	f2.setup(1, Vector2(444, GROUND_Y), Color.RED, Color.DARK_RED)
	add_child(f2)
	f1.opponent = f2
	f2.opponent = f1
	for i in 4:
		await get_tree().physics_frame


func _steps(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _capture_release() -> Vector2:
	# Rend la vitesse de la victime a l'instant precis ou elle est lachee
	# (la gravite l'aurait deja effacee quelques frames plus tard).
	for i in 30:
		await get_tree().physics_frame
		if f2.state != Fighter.State.GRABBED:
			return f2.velocity
	return Vector2.ZERO


func _check(label: String, cond: bool) -> void:
	if cond:
		print("  ok   : ", label)
	else:
		print("  ECHEC: ", label)
		_fails += 1


func _grab_until_hold() -> void:
	f1._start_grab()
	for i in 30:
		await get_tree().physics_frame
		if f1.state == Fighter.State.GRABBING:
			return


func _run() -> void:
	# ---- A : la saisie accroche bien l'adversaire ----
	print("A. saisie")
	await _spawn()
	await _grab_until_hold()
	_check("le saisisseur passe en GRABBING", f1.state == Fighter.State.GRABBING)
	_check("la victime passe en GRABBED", f2.state == Fighter.State.GRABBED)
	_check("le lien victime->saisisseur est pose", f2._grabbed_by == f1)

	# ---- B : projection avant ----
	print("B. projection avant")
	var hp_before := f2.hp
	Input.action_press("p1_punch")
	await _steps(2)
	_check("l'elan de projection demarre", f1._throw_pending)
	Input.action_release("p1_punch")
	await _steps(20)
	_check("la victime est relachee", f2.state != Fighter.State.GRABBED)
	_check("la victime encaisse les degats", f2.hp < hp_before)
	_check("la victime est projetee vers l'avant", f2.velocity.x > 0.0)
	_check("le saisisseur ne tient plus personne", f1._grab_victim == null)
	_check("l'elan est retombe", not f1._throw_pending)

	# ---- C : le saisisseur frappe pendant la prise -> il doit lacher ----
	print("C. saisisseur touche pendant la prise")
	await _spawn()
	await _grab_until_hold()
	f1._enter_hurt(0.30, Vector2(-200, -150))
	await _steps(2)
	_check("la victime est liberee", f2.state != Fighter.State.GRABBED)
	_check("la victime n'a plus de saisisseur", f2._grabbed_by == null)
	_check("le saisisseur ne tient plus personne", f1._grab_victim == null)

	# ---- D : regression, un elan interrompu ne doit pas fuiter ----
	print("D. elan interrompu (anti-regression)")
	await _spawn()
	await _grab_until_hold()
	f1._throw_pending = true          # elan en cours...
	f1._enter_hurt(0.30, Vector2(-200, -150))   # ...interrompu par un coup
	await _steps(30)
	_check("l'elan est annule", not f1._throw_pending)
	f1._start_grab()
	_check("une nouvelle saisie repart sans elan", not f1._throw_pending)

	# ---- E : echappement en martelant les touches ----
	print("E. echappement de la victime")
	await _spawn()
	await _grab_until_hold()
	var taps := 0
	while f2.state == Fighter.State.GRABBED and taps < 12:
		await _tap("p2_punch")
		taps += 1
	print("     (libere apres %d appuis)" % taps)
	_check("la victime se libere en martelant", f2.state != Fighter.State.GRABBED)
	_check("le saisisseur est puni (HURT)", f1.state == Fighter.State.HURT)
	_check("le saisisseur ne tient plus personne", f1._grab_victim == null)
	_check("l'elan du saisisseur est propre", not f1._throw_pending)

	# ---- F : projection arriere (tenir la direction opposee) ----
	print("F. projection arriere")
	await _spawn()
	await _grab_until_hold()
	_check("le saisisseur regarde vers la droite", f1.facing > 0.0)
	Input.action_press("p1_left")        # direction opposee a l'adversaire
	var v_back := await _capture_release()
	Input.action_release("p1_left")
	print("     (vitesse au lacher : %.0f, %.0f)" % [v_back.x, v_back.y])
	_check("la victime part vers l'arriere", v_back.x < 0.0)
	_check("les deux ont echange de cote", f2.global_position.x < f1.global_position.x)

	# ---- G : projection avant declenchee par la direction ----
	print("G. projection avant (direction avant)")
	await _spawn()
	await _grab_until_hold()
	Input.action_press("p1_right")
	var v_fwd := await _capture_release()
	Input.action_release("p1_right")
	print("     (vitesse au lacher : %.0f, %.0f)" % [v_fwd.x, v_fwd.y])
	_check("la victime part vers l'avant", v_fwd.x > 0.0)

	# ---- H : projection haute ----
	print("H. projection haute")
	await _spawn()
	await _grab_until_hold()
	Input.action_press("p1_up")
	var v_up := await _capture_release()
	Input.action_release("p1_up")
	print("     (vitesse au lacher : %.0f, %.0f)" % [v_up.x, v_up.y])
	_check("la victime part vers le haut", v_up.y < -600.0)

	# ---- I : ecrasement au sol ----
	print("I. ecrasement vers le bas")
	await _spawn()
	await _grab_until_hold()
	var hp_avant_slam := f2.hp
	Input.action_press("p1_down")
	var v_dn := await _capture_release()
	Input.action_release("p1_down")
	print("     (vitesse au lacher : %.0f, %.0f)" % [v_dn.x, v_dn.y])
	_check("la victime est projetee vers le bas", v_dn.y > 300.0)
	_check("l'ecrasement fait plus mal qu'une projection simple",
		(hp_avant_slam - f2.hp) > Fighter.THROW_DAMAGE)

	# ---- J : les 4 directions sont bien distinctes ----
	print("J. les 4 directions donnent 4 trajectoires")
	_check("avant != arriere", signf(v_fwd.x) != signf(v_back.x))
	_check("haut != bas", signf(v_up.y) != signf(v_dn.y))
