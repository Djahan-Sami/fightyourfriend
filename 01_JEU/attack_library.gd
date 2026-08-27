extends RefCounted
class_name AttackLibrary

# Donnees de combat modifiables sans toucher au code. Les animations sont
# conservees dans user://attacks et les reglages dans attack_manifest.json.

const DIR := "user://attacks"
const MANIFEST := DIR + "/attack_manifest.json"
const BUNDLED_DIR := "res://default_attacks"
const CANONICAL_RIG_ID := "ragdoll_brawl_humanoid_v1"
const CANONICAL_RIG_VERSION := 1

const DEFAULT_SLOTS := {
	"ground/punch/neutral": "jab",
	"ground/punch/forward": "hook",
	"ground/punch/back": "spinning_backfist",
	"ground/punch/up": "uppercut",
	"ground/punch/down": "body_hook",
	"ground/kick/neutral": "middle_kick",
	"ground/kick/forward": "front_kick",
	"ground/kick/back": "spinning_kick",
	"ground/kick/up": "high_kick",
	"ground/kick/down": "sweep",
	"air/punch/neutral": "air_punch",
	"air/punch/forward": "air_cross",
	"air/punch/back": "air_backfist",
	"air/punch/up": "air_upper",
	"air/punch/down": "air_hammer",
	"air/kick/neutral": "air_kick",
	"air/kick/forward": "air_side_kick",
	"air/kick/back": "air_roundhouse",
	"air/kick/up": "air_rising_kick",
	"air/kick/down": "dive_kick",
}

static var _loaded := false
static var _data: Dictionary = {}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {
		"version": 3,
		"rig": {"id": CANONICAL_RIG_ID, "version": CANONICAL_RIG_VERSION},
		"slots": DEFAULT_SLOTS.duplicate(true),
		"moves": {},
		"guard": {},
		"neutral": {},
		"crouch": {},
		"hurtboxes": {"neutral": {}, "guard": {}, "crouch": {}, "moves": {}},
	}
	DirAccess.make_dir_recursive_absolute(DIR)
	if not FileAccess.file_exists(MANIFEST):
		# Une nouvelle installation recoit les animations publiees avec le jeu.
		# Les donnees d'un joueur existant ne sont jamais ecrasees.
		if not _install_bundled_defaults():
			_save()
			return
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	if parsed.get("slots") is Dictionary:
		for slot in parsed["slots"]:
			_data["slots"][slot] = str(parsed["slots"][slot])
	if parsed.get("moves") is Dictionary:
		_data["moves"] = parsed["moves"]
	if parsed.get("guard") is Dictionary:
		_data["guard"] = parsed["guard"]
	if parsed.get("neutral") is Dictionary:
		_data["neutral"] = parsed["neutral"]
	if parsed.get("crouch") is Dictionary:
		_data["crouch"] = parsed["crouch"]
	if parsed.get("hurtboxes") is Dictionary:
		var loaded_hurtboxes: Dictionary = parsed["hurtboxes"].duplicate(true)
		for context in ["neutral", "guard", "crouch"]:
			if not (loaded_hurtboxes.get(context) is Dictionary):
				loaded_hurtboxes[context] = {}
		if not (loaded_hurtboxes.get("moves") is Dictionary):
			loaded_hurtboxes["moves"] = {}
		_data["hurtboxes"] = loaded_hurtboxes
	# Les anciens manifestes restent lisibles. Le prochain export Blender les
	# convertira au format du squelette commun.
	if parsed.get("rig") is Dictionary:
		_data["rig"] = parsed["rig"]


static func _install_bundled_defaults() -> bool:
	var bundled := DirAccess.open(BUNDLED_DIR)
	if bundled == null:
		return false
	bundled.list_dir_begin()
	var file_name := bundled.get_next()
	while file_name != "":
		if not bundled.current_is_dir() and (file_name.get_extension().to_lower() == "glb"
		or file_name == "attack_manifest.json"):
			var source_path := BUNDLED_DIR.path_join(file_name)
			var target_path := DIR.path_join(file_name)
			var source := FileAccess.open(source_path, FileAccess.READ)
			if source:
				var target := FileAccess.open(target_path, FileAccess.WRITE)
				if target:
					target.store_buffer(source.get_buffer(source.get_length()))
					target.close()
				source.close()
		file_name = bundled.get_next()
	bundled.list_dir_end()
	return FileAccess.file_exists(MANIFEST)


static func _save() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_data, "  "))
	file.close()
	return true


static func reload() -> void:
	_loaded = false
	_data = {}
	_ensure()


static func manifest_path() -> String:
	_ensure()
	return MANIFEST


static func slot_key(context: String, button: String, direction: String) -> String:
	return "%s/%s/%s" % [context, button, direction]


static func move_for(context: String, button: String, direction: String,
		fallback: String) -> String:
	_ensure()
	return str(_data["slots"].get(slot_key(context, button, direction), fallback))


static func slot_for_move(move_name: String) -> String:
	_ensure()
	for slot in _data["slots"]:
		if str(_data["slots"][slot]) == move_name:
			return str(slot)
	return ""


static func assign_slot(move_name: String, context: String, button: String,
		direction: String) -> bool:
	_ensure()
	var wanted := slot_key(context, button, direction)
	var old_slot := ""
	for slot in _data["slots"].keys():
		if str(_data["slots"][slot]) == move_name:
			old_slot = str(slot)
			break
	# L'affectation fonctionne comme un echange : aucune commande ne devient
	# vide et aucun coup ne disparait accidentellement du clavier.
	if old_slot != "" and old_slot != wanted:
		_data["slots"][old_slot] = str(_data["slots"].get(wanted, ""))
	_data["slots"][wanted] = move_name
	return _save()


static func move_override(move_name: String) -> Dictionary:
	_ensure()
	var value = _data["moves"].get(move_name, {})
	return value.duplicate(true) if value is Dictionary else {}


static func save_move(move_name: String, settings: Dictionary) -> bool:
	_ensure()
	_data["moves"][move_name] = settings.duplicate(true)
	return _save()


static func reset_move(move_name: String) -> bool:
	_ensure()
	_data["moves"].erase(move_name)
	return _save()


static func apply_to_move(move_name: String, defaults: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	var custom := move_override(move_name)
	for key in custom:
		if key in ["animation_file", "animation", "support", "source_forward"]:
			continue
		var value = custom[key]
		if key in ["box", "kb"] and value is Array and value.size() >= 2:
			result[key] = Vector2(float(value[0]), float(value[1]))
		elif key == "hitbox_authored":
			result[key] = bool(value)
		elif key == "hitbox_shape" and str(value) in ["circle", "ellipse"]:
			result[key] = str(value)
		elif key in ["radius_x", "radius_y", "hitbox_rotation"]:
			result[key] = float(value)
		elif key in result:
			result[key] = value
	return result


static func clip_info(move_name: String) -> Dictionary:
	var custom := move_override(move_name)
	var rig_id := str(custom.get("rig_id", ""))
	if rig_id != "" and rig_id != CANONICAL_RIG_ID:
		return {}
	var file := str(custom.get("animation_file", ""))
	if file == "":
		return {}
	if file.begins_with("user://"):
		file = ProjectSettings.globalize_path(file)
	if not FileAccess.file_exists(file):
		return {}
	return {
		"file": file,
		"animation": str(custom.get("animation", move_name)),
		"support": str(custom.get("support", "auto")),
		"source_forward": float(custom.get("source_forward", 1.0)),
		"root_motion_curve": custom.get("root_motion_curve", []).duplicate(true),
		"rig_id": rig_id,
	}


static func has_custom_move(move_name: String) -> bool:
	# Un emplacement de commande n'est pas un coup jouable. Le coup existe
	# seulement lorsque l'animateur a exporte un vrai fichier pour celui-ci.
	return not clip_info(move_name).is_empty()


static func guard_clip_info() -> Dictionary:
	_ensure()
	var custom = _data.get("guard", {})
	if not (custom is Dictionary):
		return {}
	var rig_id := str(custom.get("rig_id", ""))
	if rig_id != "" and rig_id != CANONICAL_RIG_ID:
		return {}
	var file := str(custom.get("animation_file", ""))
	if file == "":
		return {}
	if file.begins_with("user://"):
		file = ProjectSettings.globalize_path(file)
	if not FileAccess.file_exists(file):
		return {}
	return {
		"file": file,
		"animation": str(custom.get("animation", "GARDE")),
		"support": str(custom.get("support", "both")),
		"source_forward": float(custom.get("source_forward", 1.0)),
		"rig_id": rig_id,
	}


static func has_custom_guard() -> bool:
	return not guard_clip_info().is_empty()


static func neutral_clip_info() -> Dictionary:
	_ensure()
	var custom = _data.get("neutral", {})
	if not (custom is Dictionary):
		return {}
	var rig_id := str(custom.get("rig_id", ""))
	if rig_id != "" and rig_id != CANONICAL_RIG_ID:
		return {}
	var file := str(custom.get("animation_file", ""))
	if file == "":
		return {}
	if file.begins_with("user://"):
		file = ProjectSettings.globalize_path(file)
	if not FileAccess.file_exists(file):
		return {}
	return {
		"file": file,
		"animation": str(custom.get("animation", "NEUTRE")),
		"support": str(custom.get("support", "both")),
		"source_forward": float(custom.get("source_forward", 1.0)),
		"rig_id": rig_id,
	}


static func has_custom_neutral() -> bool:
	return not neutral_clip_info().is_empty()


static func crouch_clip_info() -> Dictionary:
	_ensure()
	var custom = _data.get("crouch", {})
	if not (custom is Dictionary):
		return {}
	var rig_id := str(custom.get("rig_id", ""))
	if rig_id != "" and rig_id != CANONICAL_RIG_ID:
		return {}
	var file := str(custom.get("animation_file", ""))
	if file == "":
		return {}
	if file.begins_with("user://"):
		file = ProjectSettings.globalize_path(file)
	if not FileAccess.file_exists(file):
		return {}
	return {
		"file": file,
		"animation": str(custom.get("animation", "ACCROUPI")),
		"support": str(custom.get("support", "both")),
		"source_forward": float(custom.get("source_forward", 1.0)),
		"rig_id": rig_id,
	}


static func has_custom_crouch() -> bool:
	return not crouch_clip_info().is_empty()


static func hurtbox_profile(context: String, move_name: String = "") -> Dictionary:
	_ensure()
	var profiles = _data.get("hurtboxes", {})
	if not (profiles is Dictionary):
		return {}
	var value = profiles.get(context, {})
	if context == "move":
		var moves = profiles.get("moves", {})
		value = moves.get(move_name, {}) if moves is Dictionary else {}
	return value.duplicate(true) if value is Dictionary else {}


static func save_hurtbox_profile(context: String, profile: Dictionary,
		move_name: String = "") -> bool:
	_ensure()
	if not (_data.get("hurtboxes") is Dictionary):
		_data["hurtboxes"] = {"neutral": {}, "guard": {}, "crouch": {}, "moves": {}}
	if context == "move":
		if not (_data["hurtboxes"].get("moves") is Dictionary):
			_data["hurtboxes"]["moves"] = {}
		_data["hurtboxes"]["moves"][move_name] = profile.duplicate(true)
	elif context in ["neutral", "guard", "crouch"]:
		_data["hurtboxes"][context] = profile.duplicate(true)
	else:
		return false
	return _save()


static func reset_hurtbox_profile(context: String, move_name: String = "") -> bool:
	_ensure()
	if not (_data.get("hurtboxes") is Dictionary):
		return true
	if context == "move":
		var moves = _data["hurtboxes"].get("moves", {})
		if moves is Dictionary:
			moves.erase(move_name)
	elif context in ["neutral", "guard", "crouch"]:
		_data["hurtboxes"][context] = {}
	else:
		return false
	return _save()


static func import_clip(move_name: String, source_path: String) -> String:
	_ensure()
	var src := FileAccess.open(source_path, FileAccess.READ)
	if src == null:
		return ""
	var dst_path := "%s/%s.glb" % [DIR, move_name]
	var dst := FileAccess.open(dst_path, FileAccess.WRITE)
	if dst == null:
		src.close()
		return ""
	dst.store_buffer(src.get_buffer(src.get_length()))
	dst.close()
	src.close()
	return dst_path


static func list_animations(path: String) -> PackedStringArray:
	var names := PackedStringArray()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return names
	var scene := doc.generate_scene(state)
	if scene == null:
		return names
	var player := _find_animation_player(scene)
	if player:
		for name in player.get_animation_list():
			if str(name) not in ["RESET", "reset"]:
				names.append(str(name))
	scene.free()
	return names


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
