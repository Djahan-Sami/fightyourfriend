extends Node3D
class_name ExternalMotionClip

# Lit une animation humanoide GLB et la transforme en directions anatomiques.
# Cette methode accepte aussi bien le rig du modele Blender livre avec le jeu
# que les noms de bones Mixamo les plus courants.

const CANONICAL_RIG_ID := "ragdoll_brawl_humanoid_v1"

const CANDIDATES := {
	"hips": ["hips", "pelvis", "bassin", "root"],
	"chest": ["upperchest", "spine2", "chest", "torse", "spine1", "spine"],
	"neck": ["neck", "neck1"],
	"head": ["head", "tete"],
	"upper_arm_l": ["upperarml", "leftarm", "armupperl", "uparml"],
	"lower_arm_l": ["lowerarml", "leftforearm", "forearml", "armlowerl"],
	"hand_l": ["handl", "lefthand", "wristl"],
	"upper_arm_r": ["upperarmr", "rightarm", "armupperr", "uparmr"],
	"lower_arm_r": ["lowerarmr", "rightforearm", "forearmr", "armlowerr"],
	"hand_r": ["handr", "righthand", "wristr"],
	"upper_leg_l": ["upperlegl", "leftupleg", "thighl", "leftthigh"],
	"lower_leg_l": ["lowerlegl", "leftleg", "shinl", "calfl"],
	"foot_l": ["footl", "leftfoot", "anklel"],
	"toe_l": ["toel", "lefttoebase", "lefttoe", "toebasel"],
	"upper_leg_r": ["upperlegr", "rightupleg", "thighr", "rightthigh"],
	"lower_leg_r": ["lowerlegr", "rightleg", "shinr", "calfr"],
	"foot_r": ["footr", "rightfoot", "ankler"],
	"toe_r": ["toer", "righttoebase", "righttoe", "toebaser"],
}

var clip_path := ""
var animation_name := ""
var support := "auto"
var forward_sign := 1.0
var rig_id := ""
var length := 0.0
var valid := false

var _scene: Node
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _forward := Vector3.FORWARD
var _first_hips := Vector3.ZERO
var _source_height := 1.0


func load_clip(info: Dictionary) -> bool:
	clear_clip()
	clip_path = str(info.get("file", ""))
	animation_name = str(info.get("animation", ""))
	support = str(info.get("support", "auto"))
	forward_sign = float(info.get("source_forward", 1.0))
	rig_id = str(info.get("rig_id", ""))
	if rig_id != "" and rig_id != CANONICAL_RIG_ID:
		return false
	if clip_path == "" or not FileAccess.file_exists(clip_path):
		return false

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(clip_path, state) != OK:
		return false
	_scene = doc.generate_scene(state)
	if _scene == null:
		return false
	add_child(_scene)
	_hide_meshes(_scene)
	_player = _find_player(_scene)
	_skeleton = _find_skeleton(_scene)
	if _player == null or _skeleton == null:
		clear_clip()
		return false

	if not _player.has_animation(animation_name):
		var choices := _player.get_animation_list()
		for choice in choices:
			if str(choice).to_lower() not in ["reset", "rest"]:
				animation_name = str(choice)
				break
	if not _player.has_animation(animation_name):
		clear_clip()
		return false

	_build_bone_map()
	if not _has_required_bones():
		clear_clip()
		return false
	_calibrate_axes()
	var anim := _player.get_animation(animation_name)
	length = maxf(float(anim.length), 0.001)
	_sample_time(0.0)
	_first_hips = _pos("hips")
	_source_height = maxf((_rest_pos("head") - _rest_pos("hips")).length(), 0.001)
	valid = true
	return true


func clear_clip() -> void:
	valid = false
	_bones = {}
	_player = null
	_skeleton = null
	if is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null


func sample(progress: float) -> Dictionary:
	if not valid:
		return {}
	_sample_time(clampf(progress, 0.0, 1.0) * length)

	var hips := _pos("hips")
	var chest := _pos("chest")
	var neck := _pos("neck") if _bones.has("neck") else _pos("head")
	var head := _pos("head")
	var arm_l := _limb("upper_arm_l", "lower_arm_l", "hand_l")
	var arm_r := _limb("upper_arm_r", "lower_arm_r", "hand_r")
	var leg_l := _limb("upper_leg_l", "lower_leg_l", "foot_l")
	var leg_r := _limb("upper_leg_r", "lower_leg_r", "foot_r")
	var shoulder_side := _canon(_pos("upper_arm_r") - _pos("upper_arm_l")).normalized()
	var hip_side := _canon(_pos("upper_leg_r") - _pos("upper_leg_l")).normalized()
	var root_delta := _canon(hips - _first_hips) / _source_height

	return {
		"external": true,
		"weight": 1.0,
		"hips_dir": _canon(chest - hips).normalized(),
		"spine_dir": _canon(neck - chest).normalized(),
		"head_dir": _canon(head - neck).normalized() if head.distance_to(neck) > 0.0001 \
			else _canon(head - chest).normalized(),
		"arm_l": arm_l,
		"arm_r": arm_r,
		"leg_l": leg_l,
		"leg_r": leg_r,
		"foot_l": _foot_dir("foot_l", "toe_l", leg_l[1]),
		"foot_r": _foot_dir("foot_r", "toe_r", leg_r[1]),
		"hip_twist": atan2(hip_side.x, hip_side.z),
		"chest_twist": atan2(shoulder_side.x, shoulder_side.z),
		"root_delta": root_delta,
		"support": support,
	}


func _limb(a: String, b: String, c: String) -> Array:
	return [
		_canon(_pos(b) - _pos(a)).normalized(),
		_canon(_pos(c) - _pos(b)).normalized(),
	]


func _foot_dir(ankle: String, toe: String, fallback: Vector3) -> Vector3:
	if _bones.has(toe):
		var d := _canon(_pos(toe) - _pos(ankle))
		if d.length_squared() > 0.00001:
			return d.normalized()
	return (Vector3.RIGHT * 0.72 + fallback * 0.28).normalized()


func _sample_time(seconds: float) -> void:
	_player.play(animation_name)
	_player.seek(seconds, true)
	_player.advance(0.0)
	if _skeleton.has_method("force_update_all_bone_transforms"):
		_skeleton.force_update_all_bone_transforms()


func _build_bone_map() -> void:
	var normalized := {}
	for i in _skeleton.get_bone_count():
		normalized[i] = _normalize(_skeleton.get_bone_name(i))
	for role in CANDIDATES:
		var found := -1
		for candidate in CANDIDATES[role]:
			for i in normalized:
				var bone_name: String = normalized[i]
				if bone_name == candidate or bone_name.ends_with(candidate):
					found = int(i)
					break
			if found >= 0:
				break
		if found >= 0:
			_bones[role] = found


func _has_required_bones() -> bool:
	for role in ["hips", "chest", "head",
			"upper_arm_l", "lower_arm_l", "hand_l",
			"upper_arm_r", "lower_arm_r", "hand_r",
			"upper_leg_l", "lower_leg_l", "foot_l",
			"upper_leg_r", "lower_leg_r", "foot_r"]:
		if not _bones.has(role):
			push_warning("Animation externe : os absent %s dans %s" % [role, clip_path])
			return false
	return true


func _calibrate_axes() -> void:
	var left := _rest_pos("upper_arm_l")
	var right := _rest_pos("upper_arm_r")
	_right = (right - left).normalized()
	_up = (_rest_pos("head") - _rest_pos("hips")).normalized()
	_right = (_right - _up * _right.dot(_up)).normalized()
	_forward = _right.cross(_up).normalized() * forward_sign


func _canon(vector: Vector3) -> Vector3:
	# X = avant du combattant, Y = haut, Z = droite anatomique.
	return Vector3(vector.dot(_forward), vector.dot(_up), vector.dot(_right))


func _pos(role: String) -> Vector3:
	return _skeleton.get_bone_global_pose(int(_bones[role])).origin


func _rest_pos(role: String) -> Vector3:
	return _skeleton.get_bone_global_rest(int(_bones[role])).origin


func _normalize(value: String) -> String:
	var out := value.to_lower()
	for token in ["mixamorig", "def", "org", "mch", "bone", ":", "_", ".", "-", " "]:
		out = out.replace(token, "")
	return out


func _hide_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visible = false
	for child in node.get_children():
		_hide_meshes(child)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
