extends Node2D

# Outil de debug : joue une saisie -> projection, echantillonne la sequence,
# puis redessine chaque instant cote a cote en une seule image.

const GROUND_Y := 560.0
const SAMPLES := 9
const EVERY := 4          # une image toutes les 4 frames physiques
const DX := 138.0
const GHOST_SCALE := 0.62

var f1: Fighter
var f2: Fighter
var _shots: Array = []


func _ready() -> void:
	get_window().size = Vector2i(1280, 460)
	for i in 2:
		for a in ["left", "right", "up", "down", "jump", "punch", "kick", "grab"]:
			var act := "p%d_%s" % [i + 1, a]
			if not InputMap.has_action(act):
				InputMap.add_action(act)
	_build_ground()
	await get_tree().physics_frame
	await _play()
	await _render_strip()


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


func _snap() -> void:
	var frame := []
	for f in [f1, f2]:
		frame.append({
			"pos": f.global_position,
			"pose": f._copy_pose(f._pose),
			"facing": f.facing,
			"spin": f._spin,
			"main": f.col_main,
			"dark": f.col_dark,
		})
	_shots.append(frame)


func _play() -> void:
	f1 = Fighter.new()
	f1.setup(0, Vector2(400, GROUND_Y), Color(0.32, 0.55, 0.95), Color(0.20, 0.36, 0.68))
	add_child(f1)
	f2 = Fighter.new()
	f2.setup(1, Vector2(444, GROUND_Y), Color(0.94, 0.36, 0.37), Color(0.67, 0.22, 0.24))
	add_child(f2)
	f1.opponent = f2
	f2.opponent = f1
	for i in 4:
		await get_tree().physics_frame

	f1._start_grab()
	for i in 40:
		await get_tree().physics_frame
		if f1.state == Fighter.State.GRABBING:
			break

	_snap()                                  # instant de la saisie
	Input.action_press("p1_punch")
	await get_tree().physics_frame
	Input.action_release("p1_punch")

	while _shots.size() < SAMPLES:
		for i in EVERY:
			await get_tree().physics_frame
		_snap()

	f1.queue_free()
	f2.queue_free()
	await get_tree().physics_frame


func _render_strip() -> void:
	for i in _shots.size():
		var frame: Array = _shots[i]
		var base_x: float = 70.0 + float(i) * DX
		# on garde l'ecart reel entre les deux corps, juste reduit a l'echelle
		var ref_x: float = frame[0]["pos"].x
		for s in frame:
			var g := Fighter.new()
			g.setup(0, Vector2.ZERO, s["main"], s["dark"])
			add_child(g)
			g.set_physics_process(false)
			g.scale = Vector2(GHOST_SCALE, GHOST_SCALE)
			g.position = Vector2(
				base_x + (s["pos"].x - ref_x) * GHOST_SCALE,
				380.0 + (s["pos"].y - GROUND_Y) * GHOST_SCALE)
			g.facing = s["facing"]
			g._pose = s["pose"]
			g._spin = s["spin"]
			g.queue_redraw()
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://throw_strip.png")
	print("saved: ", ProjectSettings.globalize_path("user://throw_strip.png"))
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 460), Color(0.09, 0.10, 0.14))
	draw_line(Vector2(0, 382), Vector2(1280, 382), Color(1, 1, 1, 0.18), 2.0)
	var font := ThemeDB.fallback_font
	for i in _shots.size():
		draw_string(font, Vector2(70.0 + float(i) * DX - 20.0, 420.0),
			"t+%d" % (i * EVERY), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))
