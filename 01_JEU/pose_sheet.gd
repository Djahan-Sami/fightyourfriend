extends Node2D

# Outil de debug : rend toutes les poses avec le VRAI code de dessin de Fighter,
# puis sauvegarde un PNG. L'adversaire est cense etre a DROITE (facing = +1).

const COLS := 6
const DX := 210.0
const DY := 230.0
const ORIGIN := Vector2(120.0, 190.0)

var _names: Array = []


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	# les Fighter interrogent leurs actions des _process : sans ca, erreurs en boucle
	for i in 2:
		for a in ["left", "right", "up", "down", "jump", "punch", "kick", "grab"]:
			var act := "p%d_%s" % [i + 1, a]
			if not InputMap.has_action(act):
				InputMap.add_action(act)
	_names = Fighter.POSES.keys()
	for i in _names.size():
		var f := Fighter.new()
		f.setup(0, Vector2.ZERO, Color(0.32, 0.55, 0.95), Color(0.20, 0.36, 0.68))
		add_child(f)
		f.set_physics_process(false)
		f.position = ORIGIN + Vector2(float(i % COLS) * DX, float(i / COLS) * DY)
		f.facing = 1.0
		f._pose = f._copy_pose(Fighter.POSES[_names[i]])
		f.queue_redraw()
	_shoot.call_deferred()


func _shoot() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://pose_sheet.png")
	print("saved: ", ProjectSettings.globalize_path("user://pose_sheet.png"))
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.09, 0.10, 0.14))
	var font := ThemeDB.fallback_font
	for i in _names.size():
		var p := ORIGIN + Vector2(float(i % COLS) * DX, float(i / COLS) * DY)
		# repere : sol + fleche "vers l'adversaire"
		draw_line(p + Vector2(-70, 2), p + Vector2(70, 2), Color(1, 1, 1, 0.18), 2.0)
		draw_line(p + Vector2(52, -150), p + Vector2(72, -150), Color(0.4, 1.0, 0.5, 0.5), 2.0)
		draw_line(p + Vector2(72, -150), p + Vector2(66, -155), Color(0.4, 1.0, 0.5, 0.5), 2.0)
		draw_line(p + Vector2(72, -150), p + Vector2(66, -145), Color(0.4, 1.0, 0.5, 0.5), 2.0)
		draw_string(font, p + Vector2(-70, 26), str(_names[i]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
