extends Node2D
class_name Arena

# ============================================================
#  Arene 1v1 avec barres de vie et manches.
#  Aucun menu, aucune sauvegarde.
# ============================================================

const W := 1280.0
const H := 720.0
const GROUND_Y := 590.0
const WALL_L := 90.0
const WALL_R := 1190.0
const ROUNDS_TO_WIN := 2

# ---- Palette ----
const C_BG_TOP   := Color(0.055, 0.063, 0.098)
const C_BG_BOT   := Color(0.105, 0.086, 0.137)
const C_GROUND   := Color(0.153, 0.157, 0.216)
const C_GROUND_T := Color(0.243, 0.251, 0.333)
const C_P1       := Color(0.322, 0.549, 0.949)
const C_P1_D     := Color(0.196, 0.353, 0.667)
const C_P2       := Color(0.937, 0.361, 0.373)
const C_P2_D     := Color(0.667, 0.220, 0.243)

enum Phase { INTRO, FIGHT, KO, MATCH_END }

static var _inst: Node2D = null

var fighters: Array[Fighter] = []
var rounds := [0, 0]
var display_hp := [120.0, 120.0]
var phase: Phase = Phase.INTRO
var phase_t := 0.0
var round_no := 1
var banner := ""
var workshop_preview_ui := false
var shake_amt := 0.0
var sparks: Array = []
var cam: Camera2D
var pad_of := [-1, -1]
var _hitstop_end_ms := 0
var _sfx: AudioStreamPlayer
var _dragging := -1
var toast := ""
var toast_t := 0.0
var draw_world := true       # false quand le decor est rendu en 3D
var _view: Node = null       # Arena3D, pour projeter les effets a l'ecran
var workshop: AttackWorkshop


# ------------------------------------------------------------
#  API statique utilisee par les combattants
# ------------------------------------------------------------
static func shake(amount: float) -> void:
	if _inst:
		_inst.shake_amt = minf(22.0, _inst.shake_amt + amount)


static func spark(pos: Vector2, color: Color, scale: float) -> void:
	if _inst:
		_inst.sparks.append({"k": "ring", "pos": pos, "col": color, "t": 0.0,
			"life": 0.28, "r": 12.0 + 16.0 * scale, "w": 3.5})


# Impact complet : onde de choc + eclats projetes + traits de vitesse.
# `dir` = direction du coup, `power` ~ 0.4 (jab) a 2.0 (projection ecrasee).
static func impact(pos: Vector2, dir: Vector2, color: Color, power: float) -> void:
	if not _inst:
		return
	var fx: Array = _inst.sparks
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT

	# double onde de choc
	fx.append({"k": "ring", "pos": pos, "col": Color(1, 1, 1, 1), "t": 0.0,
		"life": 0.16 + 0.05 * power, "r": 16.0 + 30.0 * power, "w": 4.5})
	fx.append({"k": "ring", "pos": pos, "col": color, "t": 0.0,
		"life": 0.26 + 0.08 * power, "r": 22.0 + 32.0 * power, "w": 3.0})

	# eclats projetes, concentres dans la direction du coup
	for i in int(7.0 + 11.0 * power):
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(90.0, 330.0) * (0.55 + power * 0.7)
		v += d * 210.0 * power
		fx.append({"k": "shard", "pos": pos, "vel": v, "t": 0.0,
			"life": randf_range(0.22, 0.52), "col": color,
			"size": randf_range(2.2, 5.4) * (0.7 + power * 0.4)})

	# traits de vitesse dans l'axe du coup
	for i in int(2.0 + 4.0 * power):
		var spread := randf_range(-0.5, 0.5)
		var dd := d.rotated(spread)
		var off := dd * randf_range(14.0, 40.0) + dd.orthogonal() * randf_range(-22.0, 22.0)
		fx.append({"k": "streak", "pos": pos + off, "dir": dd, "t": 0.0,
			"life": randf_range(0.10, 0.20), "col": color,
			"len": randf_range(16.0, 38.0) * (0.6 + power * 0.5)})


static func dust(pos: Vector2, power: float) -> void:
	if not _inst:
		return
	for i in int(4.0 + 6.0 * power):
		var a := randf_range(-PI, 0.0)
		var v := Vector2(cos(a), sin(a) * 0.45) * randf_range(50.0, 190.0) * (0.6 + power)
		_inst.sparks.append({"k": "shard", "pos": pos, "vel": v, "t": 0.0,
			"life": randf_range(0.25, 0.5), "col": Color(0.72, 0.74, 0.82),
			"size": randf_range(2.5, 6.0) * (0.7 + power * 0.4)})


static func hitstop(ms: int) -> void:
	if not _inst:
		return
	var now := Time.get_ticks_msec()
	_inst._hitstop_end_ms = maxi(_inst._hitstop_end_ms, now + ms)
	Engine.time_scale = 0.04


func _ready() -> void:
	_inst = self
	Engine.time_scale = 1.0
	cam = Camera2D.new()
	cam.position = Vector2(W * 0.5, H * 0.5)
	add_child(cam)
	cam.make_current()

	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)

	_build_walls()
	_spawn()
	_register_inputs()
	_start_round(1)
	Input.joy_connection_changed.connect(func(_d, _c): _register_inputs())
	get_window().files_dropped.connect(_on_files_dropped)
	_load_saved_photos()
	workshop = AttackWorkshop.new()
	add_child(workshop)
	workshop.setup(self)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for cfg in [
		[Vector2(W * 0.5, GROUND_Y + 200.0), Vector2(W * 2.0, 400.0)],   # sol
		[Vector2(WALL_L - 40.0, 300.0), Vector2(80.0, 900.0)],           # mur gauche
		[Vector2(WALL_R + 40.0, 300.0), Vector2(80.0, 900.0)],           # mur droit
	]:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = cfg[1]
		cs.shape = r
		cs.position = cfg[0]
		body.add_child(cs)
	add_child(body)


func _spawn() -> void:
	var f1 := Fighter.new()
	f1.setup(0, Vector2(460, GROUND_Y), C_P1, C_P1_D)
	add_child(f1)
	var f2 := Fighter.new()
	f2.setup(1, Vector2(820, GROUND_Y), C_P2, C_P2_D)
	add_child(f2)
	f1.opponent = f2
	f2.opponent = f1
	fighters = [f1, f2]
	f1.ko.connect(func(): _on_ko(0))
	f2.ko.connect(func(): _on_ko(1))


# ------------------------------------------------------------
#  Manches
# ------------------------------------------------------------
func _start_round(n: int) -> void:
	round_no = n
	phase = Phase.INTRO
	phase_t = 1.4
	banner = "MANCHE %d" % n
	for f in fighters:
		f.reset_round()
		f.frozen = true
	SFX.play(_sfx, "gong", -6.0)


func _on_ko(loser: int) -> void:
	if phase != Phase.FIGHT:
		return
	rounds[1 - loser] += 1
	phase = Phase.KO
	phase_t = 2.0
	banner = "K.O."
	for f in fighters:
		f.frozen = (f.state != Fighter.State.KO)


func _process(delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		Engine.time_scale = 1.0

	phase_t -= delta
	toast_t = maxf(0.0, toast_t - delta)
	shake_amt = maxf(0.0, shake_amt - delta * 30.0)
	# en 3D la secousse est portee par la camera 3D, pas par l'interface
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt \
		if draw_world else Vector2.ZERO

	for i in 2:
		display_hp[i] = move_toward(display_hp[i], fighters[i].hp, 70.0 * delta)

	for s in sparks:
		s["t"] += delta
		if s["k"] == "shard":
			s["vel"] = s["vel"] * (1.0 - minf(1.0, 3.4 * delta))   # frottement
			s["vel"].y += 900.0 * delta                            # gravite
			s["pos"] += s["vel"] * delta
	sparks = sparks.filter(func(s): return s["t"] < s["life"])

	match phase:
		Phase.INTRO:
			if phase_t <= 0.0:
				phase = Phase.FIGHT
				banner = "COMBAT !"
				phase_t = 0.6
				for f in fighters:
					f.frozen = false
		Phase.FIGHT:
			if phase_t <= 0.0:
				banner = ""
		Phase.KO:
			if phase_t <= 0.0:
				if rounds[0] >= ROUNDS_TO_WIN or rounds[1] >= ROUNDS_TO_WIN:
					phase = Phase.MATCH_END
					banner = "JOUEUR %d GAGNE" % (1 if rounds[0] > rounds[1] else 2)
					phase_t = 3.0
				else:
					_start_round(round_no + 1)
		Phase.MATCH_END:
			if phase_t <= 0.0:
				rounds = [0, 0]
				_start_round(1)

	if Input.is_action_just_pressed("reset"):
		rounds = [0, 0]
		_start_round(1)

	queue_redraw()


# ------------------------------------------------------------
#  Rendu : decor + interface, tout dessine
# ------------------------------------------------------------
func _draw() -> void:
	if draw_world:
		# fond degrade
		var steps := 24
		for i in steps:
			var t := float(i) / float(steps - 1)
			draw_rect(Rect2(0, H * float(i) / steps, W, H / steps + 1.0),
				C_BG_TOP.lerp(C_BG_BOT, t))

		# halo derriere l'arene
		draw_circle(Vector2(W * 0.5, GROUND_Y - 120.0), 330.0, Color(0.35, 0.42, 0.85, 0.055))
		draw_circle(Vector2(W * 0.5, GROUND_Y - 90.0), 210.0, Color(0.45, 0.52, 0.95, 0.045))

		# murs lateraux
		draw_rect(Rect2(0, 0, WALL_L, H), Color(0.04, 0.045, 0.075, 0.75))
		draw_rect(Rect2(WALL_R, 0, W - WALL_R, H), Color(0.04, 0.045, 0.075, 0.75))

		# sol
		draw_rect(Rect2(0, GROUND_Y, W, H - GROUND_Y), C_GROUND)
		draw_rect(Rect2(WALL_L, GROUND_Y, WALL_R - WALL_L, 4.0), C_GROUND_T)
		for x in range(int(WALL_L), int(WALL_R), 64):
			draw_line(Vector2(x, GROUND_Y + 4), Vector2(x, H), Color(1, 1, 1, 0.022), 2.0)

	# effets d'impact (projetes a l'ecran quand le rendu est en 3D)
	var scale_fx := 1.0 if draw_world else _fx_scale()
	for s in sparks:
		var k: float = s["t"] / s["life"]
		var fade := 1.0 - k
		var c: Color = s["col"]
		var at := _proj(s["pos"])
		match s["k"]:
			"ring":
				c.a = fade * 0.85
				draw_arc(at, float(s["r"]) * (0.30 + k * 1.15) * scale_fx, 0, TAU, 24, c,
					float(s["w"]) * fade, true)
			"shard":
				c.a = fade * 0.95
				var sz: float = float(s["size"]) * (0.35 + fade * 0.75) * scale_fx
				var v: Vector2 = s["vel"]
				# l'eclat s'etire dans le sens de sa vitesse
				var stretch := v.normalized() * sz * 1.9 if v.length() > 40.0 else Vector2.ZERO
				draw_line(at - stretch, at + stretch, c, sz, true)
				draw_circle(at, sz * 0.55, c)
			"streak":
				c.a = fade * 0.7
				var dd: Vector2 = s["dir"]
				var l: float = float(s["len"]) * (0.4 + fade * 0.9) * scale_fx
				draw_line(at, at + dd * l, c, 2.5 * fade + 0.6, true)

	_draw_ui()


func rigs_ready(view: Node) -> void:
	_view = view
	_refresh_view()


func _refresh_view() -> void:
	if _view != null and _view.has_method("refresh_looks"):
		_view.refresh_looks()


func _proj(p: Vector2) -> Vector2:
	if _view == null:
		return p
	return _view.project(p)


func _fx_scale() -> float:
	# combien de pixels ecran vaut un pixel de simulation, une fois projete
	var a := _proj(Vector2(0.0, GROUND_Y))
	var b := _proj(Vector2(100.0, GROUND_Y))
	return clampf(absf(b.x - a.x) / 100.0, 0.2, 4.0)


func _draw_ui() -> void:
	if workshop_preview_ui:
		return
	var font := ThemeDB.fallback_font
	for i in 2:
		var right := i == 1
		var bw := 440.0
		var x := 60.0 if not right else W - 60.0 - bw
		var y := 46.0
		var col: Color = C_P1 if i == 0 else C_P2

		# cadre
		draw_rect(Rect2(x - 3, y - 3, bw + 6, 28), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(x, y, bw, 22), Color(1, 1, 1, 0.08))

		var ratio_now: float = fighters[i].hp / Fighter.MAX_HP
		var ratio_disp: float = display_hp[i] / Fighter.MAX_HP

		# barre blanche retardee (degats recents)
		if not right:
			draw_rect(Rect2(x, y, bw * ratio_disp, 22), Color(1, 0.95, 0.95, 0.55))
			draw_rect(Rect2(x, y, bw * ratio_now, 22), col)
		else:
			draw_rect(Rect2(x + bw * (1.0 - ratio_disp), y, bw * ratio_disp, 22), Color(1, 0.95, 0.95, 0.55))
			draw_rect(Rect2(x + bw * (1.0 - ratio_now), y, bw * ratio_now, 22), col)

		# jauge de garde
		var gy := y + 26.0
		var ge: float = fighters[i].block_energy
		var gw := bw * 0.5
		var gx := x if not right else x + bw - gw
		draw_rect(Rect2(gx, gy, gw, 6), Color(1, 1, 1, 0.07))
		if not right:
			draw_rect(Rect2(gx, gy, gw * ge, 6), Color(0.55, 0.85, 1.0, 0.75))
		else:
			draw_rect(Rect2(gx + gw * (1.0 - ge), gy, gw * ge, 6), Color(0.55, 0.85, 1.0, 0.75))

		# nom + manches gagnees
		var label: String = fighters[i].display_name if fighters[i].display_name != "" \
			else "JOUEUR %d" % (i + 1)
		if label.length() > 16:
			label = label.substr(0, 16)      # noms de fichiers a rallonge
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(x if not right else x + bw - tw, y - 10), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.65))
		for r in ROUNDS_TO_WIN:
			var px := (x + bw - 14.0 - r * 22.0) if not right else (x + 14.0 + r * 22.0)
			var filled: bool = r < rounds[i]
			draw_circle(Vector2(px, y - 16.0), 6.0, col if filled else Color(1, 1, 1, 0.15))

	# banniere centrale
	if banner != "":
		var size := 62 if banner == "K.O." else 40
		var tw := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := Vector2(W * 0.5 - tw * 0.5, 250.0)
		draw_string(font, pos + Vector2(3, 3), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.55))
		draw_string(font, pos, banner, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.96, 0.88))

	# rappel des touches
	var hint := "F10 : ATELIER DES COUPS        %s : RESET        ECHAP : MENU" \
		% GameSettings.reset_key_name()
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(W * 0.5 - hw * 0.5, H - 38.0), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.30))

	var hint2 := "J1 : %s        J2 : %s" % [GameSettings.short_summary(0), GameSettings.short_summary(1)]
	var hw2 := font.get_string_size(hint2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(W * 0.5 - hw2 * 0.5, H - 18.0), hint2,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.92, 0.72, 0.38))

	# invite d'import, tant qu'un cote n'a pas de visage
	for i in 2:
		if fighters[i].has_photo():
			continue
		var call_ := "Glissez une photo ici"
		var cw := font.get_string_size(call_, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var cx := W * 0.25 if i == 0 else W * 0.75
		var pulse := 0.34 + 0.16 * sin(float(Time.get_ticks_msec()) * 0.004)
		draw_string(font, Vector2(cx - cw * 0.5, 150.0), call_,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, pulse))

	# message temporaire (import, aide au recadrage)
	if toast_t > 0.0:
		var a: float = clampf(toast_t, 0.0, 1.0) * 0.9
		var tw2 := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_rect(Rect2(W * 0.5 - tw2 * 0.5 - 14.0, 96.0, tw2 + 28.0, 30.0),
			Color(0.05, 0.06, 0.09, 0.8 * a))
		draw_string(font, Vector2(W * 0.5 - tw2 * 0.5, 117.0), toast,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.82, a))

	var pads := "J1 : %s     J2 : %s" % [
		"manette" if pad_of[0] >= 0 else "clavier",
		"manette" if pad_of[1] >= 0 else "clavier"]
	var pw := font.get_string_size(pads, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(W * 0.5 - pw * 0.5, 40.0), pads,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.35))


# ------------------------------------------------------------
#  Entrees
# ------------------------------------------------------------
const ACTIONS := ["left", "right", "up", "down", "jump", "punch", "kick", "grab"]
const PAD_DEADZONE := 0.35


func _register_inputs() -> void:
	GameSettings.apply_input_map()
	for d in Input.get_connected_joypads():
		InputMap.action_add_event("reset", _btn(d, JOY_BUTTON_START))

	var pads := Input.get_connected_joypads()
	for i in 2:
		pad_of[i] = pads[i] if i < pads.size() else -1
		if i < fighters.size():
			fighters[i].pad_device = pad_of[i]
		for a in ACTIONS:
			var action := "p%d_%s" % [i + 1, a]
			InputMap.action_set_deadzone(action, PAD_DEADZONE)
			if pad_of[i] >= 0:
				for ev in _pad_events(a, pad_of[i]):
					InputMap.action_add_event(action, ev)


func _pad_events(a: String, dev: int) -> Array:
	match a:
		"left":  return [_axis(dev, JOY_AXIS_LEFT_X, -1.0), _btn(dev, JOY_BUTTON_DPAD_LEFT)]
		"right": return [_axis(dev, JOY_AXIS_LEFT_X, 1.0), _btn(dev, JOY_BUTTON_DPAD_RIGHT)]
		"up":    return [_axis(dev, JOY_AXIS_LEFT_Y, -1.0), _btn(dev, JOY_BUTTON_DPAD_UP)]
		"down":  return [_axis(dev, JOY_AXIS_LEFT_Y, 1.0), _btn(dev, JOY_BUTTON_DPAD_DOWN)]
		"jump":  return [_btn(dev, JOY_BUTTON_A)]
		"punch": return [_btn(dev, JOY_BUTTON_X)]
		"kick":  return [_btn(dev, JOY_BUTTON_B)]
		"grab":  return [_btn(dev, JOY_BUTTON_RIGHT_SHOULDER), _btn(dev, JOY_BUTTON_Y)]
	return []


func _btn(dev: int, button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = button
	return e


func _axis(dev: int, axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = dev
	e.axis = axis
	e.axis_value = value
	return e


# ------------------------------------------------------------
#  Photos des joueurs
# ------------------------------------------------------------
const SAVE_DIR := "user://visages"


func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	var mx := get_viewport().get_mouse_position().x
	var who := 0 if mx < get_viewport_rect().size.x * 0.5 else 1
	var ext := files[0].get_extension().to_lower()
	if ext in ["glb", "gltf"]:
		_load_model_into(who, files[0])
	else:
		_load_photo_into(who, files[0])


# ---- modeles 3D ----
func model_path(who: int) -> String:
	var selected := GameSettings.selected_skin_path(who)
	if selected != "":
		return selected
	# Compatibilite avec les deux modeles utilises avant l'ajout de la
	# bibliotheque de skins. Ils restent disponibles sous "Modele actuel".
	return legacy_model_path(who)


func legacy_model_path(who: int) -> String:
	var p := "%s/model%d.glb" % [SAVE_DIR, who + 1]
	return p if FileAccess.file_exists(p) else ""


func _load_model_into(who: int, path: String) -> void:
	var src := FileAccess.open(path, FileAccess.READ)
	if src == null:
		toast = "Modele illisible : %s" % path.get_file()
		toast_t = 3.0
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dst := FileAccess.open("%s/model%d.glb" % [SAVE_DIR, who + 1], FileAccess.WRITE)
	if dst == null:
		toast = "Copie impossible"
		toast_t = 3.0
		return
	dst.store_buffer(src.get_buffer(src.get_length()))
	dst.close()
	src.close()
	fighters[who].display_name = path.get_file().get_basename().to_upper()
	toast = "Modele 3D charge pour le joueur %d — rigging automatique..." % (who + 1)
	toast_t = 4.0
	if _view != null and _view.has_method("reload_model"):
		_view.reload_model(who)


func clear_model(who: int) -> void:
	DirAccess.remove_absolute("%s/model%d.glb" % [SAVE_DIR, who + 1])
	if _view != null and _view.has_method("reload_model"):
		_view.reload_model(who)


func _load_photo_into(who: int, path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		toast = "Image illisible : %s" % path.get_file()
		toast_t = 3.0
		return
	fighters[who].set_head_photo(img, path.get_file().get_basename())
	_refresh_view()
	_save_photo(who)
	toast = "%s : molette = zoom, clic-glisser = recadrer, C = recentrer, SUPPR = retirer" \
		% fighters[who].display_name
	toast_t = 6.0


func _save_photo(who: int) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := fighters[who]
	if not f.has_photo():
		return
	f._head_img.save_png("%s/p%d.png" % [SAVE_DIR, who + 1])
	var cfg := FileAccess.open("%s/p%d.json" % [SAVE_DIR, who + 1], FileAccess.WRITE)
	if cfg:
		cfg.store_string(JSON.stringify(f.head_state()))
		cfg.close()


func _load_saved_photos() -> void:
	for who in 2:
		var png := "%s/p%d.png" % [SAVE_DIR, who + 1]
		if not FileAccess.file_exists(png):
			continue
		var img := Image.load_from_file(png)
		if img == null:
			continue
		fighters[who].set_head_photo(img)
		var cfg := FileAccess.open("%s/p%d.json" % [SAVE_DIR, who + 1], FileAccess.READ)
		if cfg:
			var d = JSON.parse_string(cfg.get_as_text())
			cfg.close()
			if d is Dictionary:
				fighters[who].restore_head_state(d)


func _clear_photo(who: int) -> void:
	fighters[who].clear_photo()
	DirAccess.remove_absolute("%s/p%d.png" % [SAVE_DIR, who + 1])
	DirAccess.remove_absolute("%s/p%d.json" % [SAVE_DIR, who + 1])
	toast = "Photo du joueur %d retiree" % (who + 1)
	toast_t = 2.0


func _side_under_mouse() -> int:
	return 0 if get_viewport().get_mouse_position().x < get_viewport_rect().size.x * 0.5 else 1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
	and event.keycode == KEY_ESCAPE \
	and (workshop == null or not workshop.is_open()):
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().change_scene_to_file("res://main_menu.tscn")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var who := _side_under_mouse()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				fighters[who].zoom_head(0.90)      # zoomer = reduire la fenetre
				_refresh_view()
			MOUSE_BUTTON_WHEEL_DOWN:
				fighters[who].zoom_head(1.11)
				_refresh_view()
			MOUSE_BUTTON_LEFT:
				_dragging = who
	elif event is InputEventMouseButton and not event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		if _dragging >= 0:
			_save_photo(_dragging)
		_dragging = -1
	elif event is InputEventMouseMotion and _dragging >= 0:
		fighters[_dragging].pan_head(event.relative)
		_refresh_view()
	elif event is InputEventKey and event.pressed and not event.echo:
		var who := _side_under_mouse()
		if event.keycode == KEY_C:
			fighters[who].recenter_head()
			_refresh_view()
			_save_photo(who)
		elif event.keycode == KEY_DELETE:
			_clear_photo(who)
			_refresh_view()
