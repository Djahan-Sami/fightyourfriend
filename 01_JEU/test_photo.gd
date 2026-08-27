extends Node2D

# Verifie le recadrage automatique du visage sur des photos synthetiques
# (portrait centre, visage decale, photo en pied, image sans peau).
#   godot --headless --path . res://test_photo.tscn

var _fails := 0


func _ready() -> void:
	_run()
	print("")
	print("RESULTAT : ", "OK" if _fails == 0 else "%d ECHEC(S)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if cond:
		print("  ok   : ", label)
	else:
		print("  ECHEC: ", label)
		_fails += 1


# Fabrique une fausse photo : fond, un disque "peau" (le visage) et
# un bloc de vetement en dessous.
func _fake(w: int, h: int, face_c: Vector2, face_r: float,
		shirt: Color, bg: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	# vetement : sous le visage
	for y in range(int(face_c.y + face_r * 1.3), h):
		for x in w:
			img.set_pixel(x, y, shirt)
	# visage (teinte de peau claire, dans la plage detectee)
	var skin := Color(0.87, 0.68, 0.56)
	for y in h:
		for x in w:
			if Vector2(x, y).distance_to(face_c) <= face_r:
				img.set_pixel(x, y, skin)
	return img


func _dist_ratio(crop: Rect2, face_c: Vector2, face_r: float) -> float:
	# ecart entre le centre du recadrage et le vrai visage, en rayons de visage
	return crop.get_center().distance_to(face_c) / face_r


func _run() -> void:
	print("A. portrait centre")
	var c := Vector2(150, 130)
	var img := _fake(300, 400, c, 55.0, Color(0.15, 0.25, 0.55), Color(0.8, 0.8, 0.78))
	img = Photo.prepare(img)
	var k := float(img.get_width()) / 300.0        # prepare() a pu redimensionner
	var crop := Photo.find_face(img)
	var err := _dist_ratio(crop, c * k, 55.0 * k)
	print("     centre trouve %s / attendu %s  (ecart %.2f rayon)" %
		[crop.get_center().round(), (c * k).round(), err])
	_check("le recadrage tombe sur le visage", err < 0.75)
	_check("le recadrage englobe le visage", crop.size.x >= 55.0 * k * 1.6)

	print("B. visage decale en haut a gauche")
	var c2 := Vector2(90, 90)
	var img2 := Photo.prepare(_fake(400, 500, c2, 45.0,
		Color(0.6, 0.15, 0.15), Color(0.75, 0.78, 0.8)))
	var k2 := float(img2.get_width()) / 400.0
	var crop2 := Photo.find_face(img2)
	var err2 := _dist_ratio(crop2, c2 * k2, 45.0 * k2)
	print("     ecart %.2f rayon" % err2)
	_check("le visage decale est bien trouve", err2 < 0.75)

	print("C. photo en pied (visage petit, en haut)")
	var c3 := Vector2(200, 70)
	var img3 := Photo.prepare(_fake(400, 900, c3, 34.0,
		Color(0.2, 0.2, 0.24), Color(0.7, 0.72, 0.7)))
	var k3 := float(img3.get_width()) / 400.0
	var crop3 := Photo.find_face(img3)
	var err3 := _dist_ratio(crop3, c3 * k3, 34.0 * k3)
	print("     ecart %.2f rayon,  cote du cadre %.0f px" % [err3, crop3.size.x])
	_check("le visage en pied est trouve", err3 < 0.9)
	_check("le cadre serre le visage, pas tout le corps",
		crop3.size.x < 34.0 * k3 * 4.0)

	print("D. image sans peau : repli sans planter")
	var img4 := Image.create(300, 300, false, Image.FORMAT_RGBA8)
	img4.fill(Color(0.1, 0.4, 0.2))
	img4 = Photo.prepare(img4)
	var crop4 := Photo.find_face(img4)
	_check("un cadre valide est quand meme renvoye",
		crop4.size.x > 0.0 and crop4.position.x >= 0.0 and crop4.position.y >= 0.0)
	_check("le cadre reste dans l'image",
		crop4.position.x + crop4.size.x <= float(img4.get_width()) + 0.01
		and crop4.position.y + crop4.size.y <= float(img4.get_height()) + 0.01)

	print("E. couleur de tenue")
	var shirt := Color(0.15, 0.25, 0.55)
	var img5 := Photo.prepare(_fake(300, 400, Vector2(150, 120), 50.0,
		shirt, Color(0.8, 0.8, 0.78)))
	var oc := Photo.outfit_color(img5, Photo.find_face(img5))
	print("     tenue detectee %s / reelle %s" % [oc, shirt])
	_check("la teinte de tenue est plutot bleue", oc.b > oc.r)

	print("F. grosse photo redimensionnee")
	var big := Image.create(2400, 1800, false, Image.FORMAT_RGBA8)
	big.fill(Color(0.5, 0.5, 0.5))
	big = Photo.prepare(big)
	print("     %d x %d" % [big.get_width(), big.get_height()])
	_check("ramenee sous %d px" % Photo.MAX_SIDE,
		maxi(big.get_width(), big.get_height()) <= Photo.MAX_SIDE)
