extends Node3D
class_name Fighter3D

# ============================================================
#  Corps 3D pilote par le Fighter 2D.
#  La simulation (etats, frames, hitboxes) reste en 2D ; ce noeud
#  ne fait que lire le squelette et placer des volumes eclaires.
# ============================================================

const S := 0.02          # pixels de la simulation -> unites 3D
const DEPTH_ARM := 0.17  # ecart en profondeur entre membre avant et arriere
const DEPTH_LEG := 0.12
const GROUND_SIM_Y := 590.0
const CENTER_SIM_X := 640.0

var src: Fighter
var _mat_main: StandardMaterial3D
var _mat_dark: StandardMaterial3D
var _mat_skin: StandardMaterial3D
var _mat_glove: StandardMaterial3D
var _mat_boot: StandardMaterial3D
var _mat_head: StandardMaterial3D

var _parts := {}
var _head: MeshInstance3D
var _pivot: Node3D


static func sim_to_world(p: Vector2) -> Vector3:
	return Vector3((p.x - CENTER_SIM_X) * S, (GROUND_SIM_Y - p.y) * S, 0.0)


func setup(f: Fighter) -> void:
	src = f
	src.draw_2d = false
	src.head_sprite.visible = false

	_mat_main = _mat(f.col_main, 0.55)
	_mat_dark = _mat(f.col_dark.darkened(0.10), 0.62)
	_mat_skin = _mat(Fighter.COL_SKIN, 0.70)
	_mat_glove = _mat(f.col_main.lightened(0.42), 0.45)
	_mat_boot = _mat(f.col_dark.darkened(0.32), 0.50)

	_pivot = Node3D.new()          # sert au tournoiement des projections
	add_child(_pivot)

	# torse et bassin : des volumes rectangulaires, pas des capsules —
	# un buste est large et plat, une capsule donnerait un bonhomme de neige
	_add("torso", _mat_main, true)
	_add("pelvis", _mat_main, true)
	# membres arriere (plus sombres = profondeur)
	_add("arm_b_up", _mat_dark); _add("arm_b_lo", _mat_dark); _add("glove_b", _mat_glove)
	_add("leg_b_up", _mat_dark); _add("leg_b_lo", _mat_dark); _add("boot_b", _mat_boot, true)
	# membres avant
	_add("arm_f_up", _mat_main); _add("arm_f_lo", _mat_main); _add("glove_f", _mat_glove)
	_add("leg_f_up", _mat_main); _add("leg_f_lo", _mat_main); _add("boot_f", _mat_boot, true)
	_add("neck", _mat_skin)
	_add("sh_b", _mat_dark); _add("sh_f", _mat_main)
	_add("knee_b", _mat_dark); _add("knee_f", _mat_main)

	_head = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = Fighter.HEAD_R * S
	sph.height = Fighter.HEAD_R * S * 2.0
	sph.radial_segments = 24
	sph.rings = 14
	_head.mesh = sph
	_mat_head = _mat(Fighter.COL_SKIN, 0.65)
	_head.material_override = _mat_head
	_pivot.add_child(_head)

	refresh_look()


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	m.metallic_specular = 0.35
	return m


func _add(key: String, mat: StandardMaterial3D, boxy := false) -> void:
	var mi := MeshInstance3D.new()
	if boxy:
		mi.mesh = BoxMesh.new()
	else:
		var cap := CapsuleMesh.new()
		cap.radial_segments = 14
		cap.rings = 6
		mi.mesh = cap
	mi.material_override = mat
	_pivot.add_child(mi)
	_parts[key] = mi


# Recharge couleurs et visage depuis le Fighter (apres import d'une photo)
func refresh_look() -> void:
	_mat_main.albedo_color = src.col_main
	_mat_dark.albedo_color = src.col_dark.darkened(0.10)
	_mat_glove.albedo_color = src.col_main.lightened(0.42)
	_mat_boot.albedo_color = src.col_dark.darkened(0.32)

	var img := src.head_image()
	var sph := _head.mesh as SphereMesh
	var r: float = src.head_radius() * S
	sph.radius = r
	sph.height = r * 2.0
	if img != null:
		_mat_head.albedo_texture = ImageTexture.create_from_image(img)
		_mat_head.albedo_color = Color.WHITE
		_mat_head.uv1_scale = Vector3(1.0, 1.0, 1.0)
	else:
		_mat_head.albedo_texture = null
		_mat_head.albedo_color = Fighter.COL_SKIN


func _process(_delta: float) -> void:
	if not is_instance_valid(src):
		return
	var sk := src.skeleton()
	global_position = sim_to_world(src.global_position)

	# Les attaques qui tournent sur leurs appuis pivotent autour du pied arriere.
	# Les chutes et projections continuent, elles, a tourner autour du bassin.
	var hip_l := _v(sk["hip"])
	var pivot_l := hip_l
	if src.state == Fighter.State.ATTACK and src.is_on_floor() \
	and (src._is_kick() or src.move_name == "spinning_backfist"):
		pivot_l = _v(sk["leg_b"][1])
	_pivot.position = pivot_l
	_pivot.rotation = Vector3(0, float(sk.get("turn_y", 0.0)),
		-float(sk["spin"]) + float(sk.get("root_roll", 0.0)) * float(sk["facing"]))
	var off := -pivot_l

	var hip: Vector3 = _v(sk["hip"]) + off
	var sh: Vector3 = _v(sk["sh"]) + off
	var head: Vector3 = _v(sk["head"]) + off
	var hip_twist: float = float(sk.get("hip_twist", 0.0))
	var chest_twist: float = float(sk.get("chest_twist", 0.0))

	var seg := (sh - hip)
	_box("torso", hip + seg * 0.16, sh + seg * 0.04, 0.56, 0.32, chest_twist)
	_box("pelvis", hip - seg * 0.10, hip + seg * 0.20, 0.46, 0.30, hip_twist)
	_cap("neck", sh, sh + seg.normalized() * 0.13, 0.088)

	# Les membres sont ecartes en profondeur : en vue de cote, sans cet
	# ecart ils seraient tous dans le plan du buste et donc invisibles.
	_limb("arm_b", sh, sk["arm_b"], off, -DEPTH_ARM,
		0.082, 0.068, "glove_b", 0.105, "sh_b", 0.125, "knee_b")
	_limb("arm_f", sh, sk["arm_f"], off, DEPTH_ARM,
		0.088, 0.072, "glove_f", 0.112, "sh_f", 0.132, "knee_f")
	_limb2("leg_b", hip, sk["leg_b"], off, -DEPTH_LEG, 0.112, 0.090, "boot_b")
	_limb2("leg_f", hip, sk["leg_f"], off, DEPTH_LEG, 0.118, 0.095, "boot_f")

	_head.position = head
	_head.rotation = Vector3(0, chest_twist * 0.20, -float(sk["lean"]))
	# le visage regarde l'adversaire
	if float(sk["facing"]) < 0.0:
		_head.rotate_y(PI)

	_flash(float(sk["flash"]))


func _v(p: Vector2) -> Vector3:
	return Vector3(p.x * S, -p.y * S, 0.0)


func _limb(key: String, origin: Vector3, joints: Array, off: Vector3, z: float,
		r1: float, r2: float, cap_key: String, cap_r: float,
		shoulder_key: String, sh_r: float, elbow_key: String) -> void:
	var dz := Vector3(0, 0, z)
	var root: Vector3 = origin + dz
	var mid: Vector3 = _v(joints[0]) + off + dz
	var end: Vector3 = _v(joints[1]) + off + dz
	_cap(key + "_up", root, mid, r1)
	_cap(key + "_lo", mid, end, r2)
	_ball(shoulder_key, root, sh_r)
	_ball(elbow_key, mid, r2 * 1.05)
	_ball(cap_key, end, cap_r)


func _limb2(key: String, origin: Vector3, joints: Array, off: Vector3, z: float,
		r1: float, r2: float, boot_key: String) -> void:
	var dz := Vector3(0, 0, z)
	var root: Vector3 = origin + dz
	var mid: Vector3 = _v(joints[0]) + off + dz
	var end: Vector3 = _v(joints[1]) + off + dz
	_cap(key + "_up", root, mid, r1)
	_cap(key + "_lo", mid, end, r2)
	# pied : semelle orientee vers l'avant
	var fwd := Vector3(src.facing, 0.0, 0.0) * 0.13
	_box(boot_key, end - fwd * 0.30, end + fwd, r2 * 1.9, r2 * 2.1)


func _cap(key: String, a: Vector3, b: Vector3, radius: float) -> void:
	var mi: MeshInstance3D = _parts[key]
	var d := b - a
	var l := d.length()
	if l < 0.0005:
		mi.visible = false
		return
	mi.visible = true
	mi.position = (a + b) * 0.5
	mi.basis = _basis_up(d / l)
	var cap := mi.mesh as CapsuleMesh
	cap.radius = radius
	cap.height = maxf(l + radius * 2.0, radius * 2.0 + 0.001)


func _box(key: String, a: Vector3, b: Vector3, width: float, depth: float,
		twist := 0.0) -> void:
	var mi: MeshInstance3D = _parts[key]
	var d := b - a
	var l := d.length()
	if l < 0.0005:
		mi.visible = false
		return
	mi.visible = true
	mi.position = (a + b) * 0.5
	mi.basis = Basis(d / l, twist) * _basis_up(d / l)
	(mi.mesh as BoxMesh).size = Vector3(width, l, depth)


func _ball(key: String, at: Vector3, radius: float) -> void:
	var mi: MeshInstance3D = _parts[key]
	mi.visible = true
	mi.position = at
	mi.basis = Basis()
	var cap := mi.mesh as CapsuleMesh
	cap.radius = radius
	cap.height = radius * 2.0 + 0.001


static func _basis_up(up: Vector3) -> Basis:
	# aligne l'axe +Y de la capsule sur `up`
	var x := Vector3(0, 0, 1).cross(up)
	if x.length_squared() < 0.000001:
		x = Vector3(1, 0, 0)
	x = x.normalized()
	return Basis(x, up, x.cross(up))


func _flash(amount: float) -> void:
	var e: float = clampf(amount, 0.0, 1.0)
	for m in [_mat_main, _mat_dark, _mat_glove, _mat_boot, _mat_skin, _mat_head]:
		m.emission_enabled = e > 0.01
		m.emission = Color.WHITE
		m.emission_energy_multiplier = e * 1.6
