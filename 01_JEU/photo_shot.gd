extends Node2D

# Outil de debug : colle deux faux portraits sur les combattants et
# photographie l'arene, pour juger le rendu des visages importes.

var arena: Arena


func _ready() -> void:
	arena = load("res://arena.tscn").instantiate()
	add_child(arena)
	for i in 6:
		await get_tree().physics_frame

	arena.phase = Arena.Phase.FIGHT
	arena.banner = ""
	arena.phase_t = 99.0
	for f in arena.fighters:
		f.frozen = false

	arena.fighters[0].set_head_photo(
		_portrait(Color(0.88, 0.70, 0.56), Color(0.16, 0.14, 0.12), Color(0.16, 0.28, 0.60)),
		"alex")
	arena.fighters[1].set_head_photo(
		_portrait(Color(0.72, 0.53, 0.40), Color(0.32, 0.20, 0.10), Color(0.62, 0.18, 0.20)),
		"sam")

	arena.fighters[0].global_position = Vector2(520, 590)
	arena.fighters[1].global_position = Vector2(700, 590)
	arena.toast = ""
	arena.toast_t = 0.0
	await get_tree().physics_frame

	for i in 4:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://photo_shot.png")
	print("saved: ", ProjectSettings.globalize_path("user://photo_shot.png"))
	get_tree().quit()


# Faux portrait : buste, cou, visage ovale, cheveux, yeux, bouche.
func _portrait(skin: Color, hair: Color, shirt: Color) -> Image:
	var w := 300
	var h := 400
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.78, 0.80, 0.82))
	var fc := Vector2(150, 150)
	var fr := 62.0

	for y in h:
		for x in w:
			var p := Vector2(x, y)
			# buste
			if y > 268 and absf(x - 150) < 108:
				img.set_pixel(x, y, shirt)
			# cou
			if y > 200 and y <= 280 and absf(x - 150) < 26:
				img.set_pixel(x, y, skin.darkened(0.12))
			# cheveux : calotte
			if p.distance_to(fc + Vector2(0, -12)) <= fr + 8.0 and y < fc.y + 6.0:
				img.set_pixel(x, y, hair)
			# visage : ovale
			var d := Vector2((p.x - fc.x) / fr, (p.y - fc.y) / (fr * 1.22))
			if d.length() <= 1.0 and y > fc.y - fr * 0.72:
				img.set_pixel(x, y, skin)

	# yeux + bouche
	for e in [Vector2(128, 148), Vector2(172, 148)]:
		for y in range(int(e.y) - 5, int(e.y) + 6):
			for x in range(int(e.x) - 8, int(e.x) + 9):
				if Vector2(x, y).distance_to(e) < 6.0:
					img.set_pixel(x, y, Color(0.98, 0.98, 0.98))
				if Vector2(x, y).distance_to(e) < 3.0:
					img.set_pixel(x, y, Color(0.12, 0.14, 0.20))
	for y in range(186, 194):
		for x in range(134, 167):
			img.set_pixel(x, y, Color(0.62, 0.30, 0.30))
	return img
