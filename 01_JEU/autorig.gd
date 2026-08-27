extends RefCounted
class_name AutoRig

const PROFILE_ID := "ragdoll_brawl_humanoid_v1"

# ============================================================
#  Rigging automatique d'un maillage humain statique.
#
#  Les modeles generes par IA (Tripo, Hunyuan3D...) sortent sans
#  squelette : ce sont des statues. Ici on reconstruit
#    1. des reperes anatomiques mesures sur le maillage lui-meme
#    2. un squelette humanoide
#    3. des poids de deformation par distance aux os
#  ce qui rend le modele animable par le systeme de poses du jeu.
#
#  Hypotheses : personnage debout, droit, axe Y vers le haut,
#  bras le long du corps ou legerement ecartes.
# ============================================================

# Hauteurs des reperes, en fraction de la taille totale.
const Y_SHOULDER := 0.820
const Y_CHEST    := 0.720
const Y_HIP      := 0.530
const Y_ELBOW    := 0.630
const Y_WRIST    := 0.470
const Y_KNEE     := 0.285
const Y_ANKLE    := 0.050
const Y_NECK     := 0.860
const Y_HEADTOP  := 1.000

# Os : nom -> [parent, point de depart, point d'arrivee]
const B_HIPS := 0
const B_SPINE := 1
const B_HEAD := 2
const B_UARM_L := 3
const B_LARM_L := 4
const B_UARM_R := 5
const B_LARM_R := 6
const B_ULEG_L := 7
const B_LLEG_L := 8
const B_ULEG_R := 9
const B_LLEG_R := 10
const B_FOOT_L := 11
const B_FOOT_R := 12

const BONE_NAMES := ["Hips", "Spine", "Head",
	"UpperArm_L", "LowerArm_L", "UpperArm_R", "LowerArm_R",
	"UpperLeg_L", "LowerLeg_L", "UpperLeg_R", "LowerLeg_R",
	"Foot_L", "Foot_R"]
const BONE_PARENT := [-1, B_HIPS, B_SPINE,
	B_SPINE, B_UARM_L, B_SPINE, B_UARM_R,
	B_HIPS, B_ULEG_L, B_HIPS, B_ULEG_R,
	B_LLEG_L, B_LLEG_R]

# Rayon d'influence de chaque os, en fraction de la taille.
# Les bras sont volontairement tres serres : quand ils pendent le long du
# corps, leur poignet arrive a hauteur du bassin et ils happeraient sinon
# les sommets du short.
const BONE_REACH := [0.155, 0.165, 0.150, 0.056, 0.048, 0.056, 0.048,
	0.095, 0.078, 0.095, 0.078, 0.072, 0.072]


# ------------------------------------------------------------
#  Mesure des reperes sur le maillage
# ------------------------------------------------------------
static func _slice_x(verts: PackedVector3Array, y: float, band: float,
		positive_side: bool, outer_only: bool) -> Array:
	# Renvoie [centre_x, centre_z, max_abs_x, nb] des sommets de la tranche
	var xs := 0.0
	var zs := 0.0
	var n := 0
	var mx := 0.0
	for v in verts:
		if absf(v.y - y) > band:
			continue
		if positive_side and v.x < 0.0:
			continue
		if not positive_side and v.x > 0.0:
			continue
		mx = maxf(mx, absf(v.x))
	if mx <= 0.0:
		return [0.0, 0.0, 0.0, 0]
	var thr := mx * 0.55 if outer_only else 0.0
	for v in verts:
		if absf(v.y - y) > band:
			continue
		if positive_side and v.x < 0.0:
			continue
		if not positive_side and v.x > 0.0:
			continue
		if absf(v.x) < thr:
			continue
		xs += v.x
		zs += v.z
		n += 1
	if n == 0:
		return [0.0, 0.0, mx, 0]
	return [xs / n, zs / n, mx, n]


static func landmarks(verts: PackedVector3Array, aabb: AABB) -> Dictionary:
	var h: float = maxf(aabb.size.y, 0.0001)
	var y0 := aabb.position.y
	var band := h * 0.012

	var f := func(fy: float, pos: bool, outer: bool) -> Array:
		return _slice_x(verts, y0 + fy * h, band, pos, outer)

	# bras : on prend le lobe exterieur de la tranche (au-dela du torse)
	var sh_r: Array = f.call(Y_SHOULDER, true, true)
	var sh_l: Array = f.call(Y_SHOULDER, false, true)
	var el_r: Array = f.call(Y_ELBOW, true, true)
	var el_l: Array = f.call(Y_ELBOW, false, true)
	var wr_r: Array = f.call(Y_WRIST, true, true)
	var wr_l: Array = f.call(Y_WRIST, false, true)
	# jambes : chaque cote entier
	var kn_r: Array = f.call(Y_KNEE, true, false)
	var kn_l: Array = f.call(Y_KNEE, false, false)
	var an_r: Array = f.call(Y_ANKLE, true, false)
	var an_l: Array = f.call(Y_ANKLE, false, false)
	var hip_c: Array = f.call(Y_HIP, true, false)

	var cx := aabb.get_center().x
	var cz := aabb.get_center().z
	var p := func(fy: float, s: Array) -> Vector3:
		var px: float = s[0] if int(s[3]) > 0 else cx
		var pz: float = s[1] if int(s[3]) > 0 else cz
		return Vector3(px, y0 + fy * h, pz)

	var ankle_l: Vector3 = p.call(Y_ANKLE, an_l)
	var ankle_r: Vector3 = p.call(Y_ANKLE, an_r)
	# Les statues importees regardent +Z. Une articulation de pied distincte
	# permet de garder la plante au sol quand le mollet s'incline.
	var toe_y := y0 + h * 0.018
	var foot_len := h * 0.105
	return {
		"h": h,
		"hips": Vector3(cx, y0 + Y_HIP * h, cz),
		"chest": Vector3(cx, y0 + Y_CHEST * h, cz),
		"neck": Vector3(cx, y0 + Y_NECK * h, cz),
		"headtop": Vector3(cx, y0 + Y_HEADTOP * h, cz),
		"sh_l": p.call(Y_SHOULDER, sh_l) * Vector3(0.82, 1, 1) + Vector3(cx * 0.18, 0, 0),
		"sh_r": p.call(Y_SHOULDER, sh_r) * Vector3(0.82, 1, 1) + Vector3(cx * 0.18, 0, 0),
		"el_l": p.call(Y_ELBOW, el_l),
		"el_r": p.call(Y_ELBOW, el_r),
		"wr_l": p.call(Y_WRIST, wr_l),
		"wr_r": p.call(Y_WRIST, wr_r),
		"hip_l": Vector3(-absf(kn_l[0]) * 0.72 + cx, y0 + Y_HIP * h, cz),
		"hip_r": Vector3(absf(kn_r[0]) * 0.72 + cx, y0 + Y_HIP * h, cz),
		"kn_l": p.call(Y_KNEE, kn_l),
		"kn_r": p.call(Y_KNEE, kn_r),
		"an_l": ankle_l,
		"an_r": ankle_r,
		"toe_l": Vector3(ankle_l.x, toe_y, ankle_l.z + foot_len),
		"toe_r": Vector3(ankle_r.x, toe_y, ankle_r.z + foot_len),
		"hip_w": hip_c[2],
	}


# ------------------------------------------------------------
#  Segments d'os (repos)
# ------------------------------------------------------------
static func bone_segments(lm: Dictionary) -> Array:
	var seg := []
	seg.resize(BONE_NAMES.size())
	seg[B_HIPS] = [lm["hips"], lm["chest"]]
	seg[B_SPINE] = [lm["chest"], lm["neck"]]
	seg[B_HEAD] = [lm["neck"], lm["headtop"]]
	seg[B_UARM_L] = [lm["sh_l"], lm["el_l"]]
	seg[B_UARM_R] = [lm["sh_r"], lm["el_r"]]
	# l'avant-bras est prolonge au-dela du poignet pour englober la main,
	# sinon les doigts restent hors de portee et s'etirent en pointes
	seg[B_LARM_L] = [lm["el_l"], lm["el_l"] + (lm["wr_l"] - lm["el_l"]) * 1.45]
	seg[B_LARM_R] = [lm["el_r"], lm["el_r"] + (lm["wr_r"] - lm["el_r"]) * 1.45]
	seg[B_ULEG_L] = [lm["hip_l"], lm["kn_l"]]
	seg[B_LLEG_L] = [lm["kn_l"], lm["an_l"]]
	seg[B_ULEG_R] = [lm["hip_r"], lm["kn_r"]]
	seg[B_LLEG_R] = [lm["kn_r"], lm["an_r"]]
	seg[B_FOOT_L] = [lm["an_l"], lm["toe_l"]]
	seg[B_FOOT_R] = [lm["an_r"], lm["toe_r"]]
	return seg


static func _dist_to_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ------------------------------------------------------------
#  Construction du maillage deformable
# ------------------------------------------------------------
static func build(mesh: Mesh, aabb: AABB) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lm := landmarks(verts, aabb)
	var seg := bone_segments(lm)
	var h: float = lm["h"]

	var nb := BONE_NAMES.size()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)

	var d := PackedFloat32Array()
	d.resize(nb)
	for i in verts.size():
		var v := verts[i]
		for b in nb:
			var s: Array = seg[b]
			var dist := _dist_to_seg(v, s[0], s[1])
			var reach: float = float(BONE_REACH[b]) * h
			# poids en cloche : fort pres de l'os, nul au-dela de sa portee
			var w: float = maxf(0.0, 1.0 - dist / reach)
			d[b] = w * w * w
		# on garde les 4 os les plus influents
		var idx := [0, 0, 0, 0]
		var val := [0.0, 0.0, 0.0, 0.0]
		for b in nb:
			var w: float = d[b]
			for k in 4:
				if w > val[k]:
					for j in range(3, k, -1):
						val[j] = val[j - 1]
						idx[j] = idx[j - 1]
					val[k] = w
					idx[k] = b
					break
		var sum: float = val[0] + val[1] + val[2] + val[3]
		if sum <= 0.0:
			# Sommet hors de portee de tout os : on prend le plus proche en
			# distance RELATIVE a sa portee, sinon un os fin mais proche
			# l'emporterait toujours sur le tronc auquel il appartient.
			var best := 0
			var bestd := INF
			for b in nb:
				var s2: Array = seg[b]
				var dd := _dist_to_seg(v, s2[0], s2[1]) / (float(BONE_REACH[b]) * h)
				if dd < bestd:
					bestd = dd
					best = b
			idx = [best, 0, 0, 0]
			val = [1.0, 0.0, 0.0, 0.0]
			sum = 1.0
		for k in 4:
			bones[i * 4 + k] = idx[k]
			weights[i * 4 + k] = val[k] / sum

	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights

	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := mesh.surface_get_material(0)
	if mat:
		out.surface_set_material(0, mat)
	return {"mesh": out, "landmarks": lm, "segments": seg, "profile_id": PROFILE_ID}


# Cree le Skeleton3D au repos correspondant aux segments
static func make_skeleton(seg: Array) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.set_meta("canonical_rig_id", PROFILE_ID)
	for b in BONE_NAMES.size():
		sk.add_bone(BONE_NAMES[b])
	for b in BONE_NAMES.size():
		sk.set_bone_parent(b, BONE_PARENT[b])
	for b in BONE_NAMES.size():
		var s: Array = seg[b]
		var origin: Vector3 = s[0]
		var rest := Transform3D(_basis_from_dir(s[1] - origin), origin)
		var parent: int = BONE_PARENT[b]
		if parent >= 0:
			var ps: Array = seg[parent]
			var prest := Transform3D(_basis_from_dir(ps[1] - ps[0]), ps[0])
			rest = prest.affine_inverse() * rest
		sk.set_bone_rest(b, rest)
		sk.set_bone_pose_position(b, rest.origin)
		sk.set_bone_pose_rotation(b, rest.basis.get_rotation_quaternion())
	return sk


static func _basis_from_dir(dir: Vector3) -> Basis:
	# aligne +Y sur `dir`
	var l := dir.length()
	if l < 0.000001:
		return Basis()
	var y := dir / l
	var ref := Vector3(0, 0, 1)
	if absf(y.dot(ref)) > 0.98:
		ref = Vector3(1, 0, 0)
	var x := ref.cross(y).normalized()
	return Basis(x, y, x.cross(y))
