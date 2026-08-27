extends RefCounted
class_name Photo

# ============================================================
#  Traitement des photos importees :
#    - mise a l'echelle raisonnable
#    - reperage du visage (teinte de peau) pour un recadrage automatique
#    - couleur de tenue echantillonnee sous le visage
#
#  Godot n'a pas de detection de visage ; on utilise une regle de teinte
#  de peau classique (Kovac) + recherche du plus gros amas. Ca suffit
#  largement pour des portraits et des selfies.
# ============================================================

const MAX_SIDE     := 512    # on ne garde pas des photos de 4000 px en memoire
const ANALYSE_SIDE := 180    # resolution de travail pour la detection


static func prepare(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var s := img.get_size()
	var m: int = maxi(s.x, s.y)
	if m > MAX_SIDE:
		var k := float(MAX_SIDE) / float(m)
		img.resize(maxi(1, int(s.x * k)), maxi(1, int(s.y * k)), Image.INTERPOLATE_LANCZOS)
	return img


static func _is_skin(c: Color) -> bool:
	var r := c.r * 255.0
	var g := c.g * 255.0
	var b := c.b * 255.0
	var mx: float = maxf(r, maxf(g, b))
	var mn: float = minf(r, minf(g, b))
	return r > 95.0 and g > 40.0 and b > 20.0 \
		and (mx - mn) > 15.0 and absf(r - g) > 15.0 and r > g and r > b


# Renvoie un carre de recadrage (en pixels de `img`) centre sur le visage.
# Retombe sur un cadrage haut-centre si aucune peau n'est trouvee.
static func find_face(img: Image) -> Rect2:
	var s := img.get_size()
	var small := Image.new()
	small.copy_from(img)
	var k: float = float(ANALYSE_SIDE) / float(maxi(s.x, s.y))
	if k < 1.0:
		small.resize(maxi(1, int(s.x * k)), maxi(1, int(s.y * k)), Image.INTERPOLATE_BILINEAR)
	var w := small.get_width()
	var h := small.get_height()

	var rows := PackedInt32Array()
	rows.resize(h)
	var cols := PackedInt32Array()
	cols.resize(w)
	var total := 0
	for y in h:
		for x in w:
			if _is_skin(small.get_pixel(x, y)):
				rows[y] += 1
				cols[x] += 1
				total += 1

	if total < int(0.004 * float(w * h)):
		return _fallback(s)

	# bande verticale : on garde le premier amas significatif en partant du haut
	# (sur une photo en pied, le visage est au-dessus des mains et des bras)
	var row_peak := 0
	for y in h:
		row_peak = maxi(row_peak, rows[y])
	var row_thr: int = maxi(1, int(float(row_peak) * 0.35))
	var y0 := -1
	var y1 := -1
	for y in h:
		if rows[y] >= row_thr:
			if y0 < 0:
				y0 = y
			y1 = y
		elif y0 >= 0 and (y - y1) > int(0.06 * float(h)) + 2:
			break        # trou net sous le visage (le cou) -> on s'arrete

	if y0 < 0:
		return _fallback(s)

	# bande horizontale, mesuree uniquement dans les lignes du visage
	var cols2 := PackedInt32Array()
	cols2.resize(w)
	for y in range(y0, y1 + 1):
		for x in w:
			if _is_skin(small.get_pixel(x, y)):
				cols2[x] += 1
	var col_peak := 0
	for x in w:
		col_peak = maxi(col_peak, cols2[x])
	var col_thr: int = maxi(1, int(float(col_peak) * 0.30))
	var x0 := -1
	var x1 := -1
	for x in w:
		if cols2[x] >= col_thr:
			if x0 < 0:
				x0 = x
			x1 = x
	if x0 < 0:
		return _fallback(s)

	# carre englobant, elargi pour attraper cheveux et menton
	var inv := 1.0 / maxf(k, 0.0001)
	var cx := (float(x0 + x1) * 0.5) * inv
	var cy := (float(y0 + y1) * 0.5) * inv
	var fw := float(x1 - x0 + 1) * inv
	var fh := float(y1 - y0 + 1) * inv
	var side: float = maxf(fw, fh) * 1.75
	cy -= side * 0.10          # un peu de marge au-dessus pour les cheveux
	return _clamp_square(Rect2(cx - side * 0.5, cy - side * 0.5, side, side), s)


static func _fallback(s: Vector2i) -> Rect2:
	var side := float(mini(s.x, s.y))
	return _clamp_square(
		Rect2(float(s.x) * 0.5 - side * 0.5, float(s.y) * 0.28 - side * 0.5, side, side), s)


static func _clamp_square(r: Rect2, s: Vector2i) -> Rect2:
	var side: float = clampf(r.size.x, 24.0, float(mini(s.x, s.y)))
	var x: float = clampf(r.position.x, 0.0, float(s.x) - side)
	var y: float = clampf(r.position.y, 0.0, float(s.y) - side)
	return Rect2(x, y, side, side)


static func clamp_square(r: Rect2, s: Vector2i) -> Rect2:
	return _clamp_square(r, s)


# Couleur dominante de la tenue : on echantillonne sous le visage
# en ignorant la peau et les pixels trop sombres ou delaves.
static func outfit_color(img: Image, face: Rect2) -> Color:
	var s := img.get_size()
	var y_from: int = clampi(int(face.position.y + face.size.y * 1.15), 0, s.y - 1)
	var y_to: int = clampi(int(face.position.y + face.size.y * 2.6), 0, s.y - 1)
	if y_to <= y_from:
		y_from = clampi(int(float(s.y) * 0.6), 0, s.y - 1)
		y_to = s.y - 1
	var acc := Vector3.ZERO
	var n := 0
	var step: int = maxi(1, int(float(s.x) / 60.0))
	for y in range(y_from, y_to + 1, step):
		for x in range(0, s.x, step):
			var c := img.get_pixel(x, y)
			if _is_skin(c):
				continue
			var v: float = maxf(c.r, maxf(c.g, c.b))
			if v < 0.10:
				continue
			acc += Vector3(c.r, c.g, c.b)
			n += 1
	if n < 12:
		return Color(0.5, 0.5, 0.55)
	var c := Color(acc.x / n, acc.y / n, acc.z / n)
	# on relance un peu la saturation, les moyennes tirent vers le gris
	var hsv_s: float = clampf(c.s * 1.5, 0.0, 1.0)
	var hsv_v: float = clampf(maxf(c.v, 0.35), 0.0, 1.0)
	return Color.from_hsv(c.h, hsv_s, hsv_v)
