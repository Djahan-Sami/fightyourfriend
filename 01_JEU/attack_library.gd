extends RefCounted
class_name AttackLibrary

# Donnees de combat modifiables sans toucher au code. Pendant le developpement,
# animations et reglages vivent dans le projet afin d'etre suivis par GitHub.
# Une version Windows exportee utilise sa copie locale, car son PCK est en lecture
# seule, et recoit automatiquement les animations publiees avec le jeu.

const USER_DIR := "user://attacks"
const BUNDLED_DIR := "res://default_attacks"
const BACKUP_FOLDER := "animations"
const CANONICAL_RIG_ID := "ragdoll_brawl_humanoid_v1"
const CANONICAL_RIG_VERSION := 1
const BALANCE_VERSION := 2

# Reglage de combat uniquement : aucune pose, duree, trajectoire, hitbox ou
# impulsion creee dans l'atelier n'est modifiee par cette migration.
const BALANCE_V1 := {
	"jab": {"hitstun": 0.1833},
	"uppercut": {"dmg": 18.0},
	"hook": {"hitstun": 0.3333},
	"spinning_backfist": {"dmg": 22.0},
	"air_hammer": {"dmg": 14.0},
	"middle_kick": {"dmg": 10.0, "hitstun": 0.3},
	"high_kick": {"dmg": 14.0, "hitstun": 0.4},
	"sweep": {"dmg": 8.0, "hitstun": 0.35},
	"front_kick": {"dmg": 18.0},
	"air_rising_kick": {"dmg": 15.0},
	"dive_kick": {"dmg": 15.0},
	"air_roundhouse": {"dmg": 12.0, "hitstun": 0.3167},
}

const BALANCE_V2 := {
	"uppercut": {"startup": 0.2167},
	"spinning_backfist": {"dmg": 18.0},
	"air_cross": {"startup": 0.1667, "recover": 0.2},
	"middle_kick": {"startup": 0.1333},
	"high_kick": {"startup": 0.15},
	"sweep": {"startup": 0.1667},
	"front_kick": {"recover": 0.25},
	"air_rising_kick": {"startup": 0.2833},
	"air_side_kick": {"startup": 0.1833, "recover": 0.2333},
	"air_roundhouse": {"startup": 0.15},
}

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


static func uses_project_storage() -> bool:
	return OS.has_feature("editor") and DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(BUNDLED_DIR))


static func storage_dir() -> String:
	return BUNDLED_DIR if uses_project_storage() else USER_DIR


static func _manifest_file() -> String:
	return storage_dir().path_join("attack_manifest.json")


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {
		"version": 3,
		"balance_version": 0,
		"rig": {"id": CANONICAL_RIG_ID, "version": CANONICAL_RIG_VERSION},
		"slots": DEFAULT_SLOTS.duplicate(true),
		"moves": {},
		"guard": {},
		"neutral": {},
		"crouch": {},
		"hurtboxes": {"neutral": {}, "guard": {}, "crouch": {}, "moves": {}},
	}
	var active_dir := storage_dir()
	if active_dir == USER_DIR:
		DirAccess.make_dir_recursive_absolute(active_dir)
	var active_manifest := _manifest_file()
	if not FileAccess.file_exists(active_manifest):
		# Une nouvelle installation recoit les animations publiees avec le jeu.
		# Les donnees d'un joueur existant ne sont jamais ecrasees.
		if active_dir == USER_DIR and not _install_bundled_defaults():
			_save()
			return
	var file := FileAccess.open(active_manifest, FileAccess.READ)
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
	_data["balance_version"] = int(parsed.get("balance_version", 0))
	if int(_data["balance_version"]) < BALANCE_VERSION:
		_apply_balance_migration(int(_data["balance_version"]))


static func _apply_balance_values(values: Dictionary) -> void:
	for move_name in values:
		var settings = _data["moves"].get(move_name, {})
		if not (settings is Dictionary):
			settings = {}
		for key in values[move_name]:
			settings[key] = values[move_name][key]
		_data["moves"][move_name] = settings


static func _apply_balance_migration(from_version: int) -> void:
	if from_version < 1:
		_apply_balance_values(BALANCE_V1)
	if from_version < 2:
		_apply_balance_values(BALANCE_V2)
	_data["balance_version"] = BALANCE_VERSION
	_save()


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
			var target_path := USER_DIR.path_join(file_name)
			var source := FileAccess.open(source_path, FileAccess.READ)
			if source:
				var target := FileAccess.open(target_path, FileAccess.WRITE)
				if target:
					target.store_buffer(source.get_buffer(source.get_length()))
					target.close()
				source.close()
		file_name = bundled.get_next()
	bundled.list_dir_end()
	return FileAccess.file_exists(USER_DIR.path_join("attack_manifest.json"))


static func _normalize_animation_paths_for_storage() -> void:
	var active_dir := storage_dir()
	for context in ["guard", "neutral", "crouch"]:
		var entry = _data.get(context, {})
		if entry is Dictionary and str(entry.get("animation_file", "")) != "":
			entry["animation_file"] = active_dir.path_join(
				str(entry["animation_file"]).get_file())
	var moves = _data.get("moves", {})
	if moves is Dictionary:
		for move_name in moves:
			var move = moves[move_name]
			if move is Dictionary and str(move.get("animation_file", "")) != "":
				move["animation_file"] = active_dir.path_join(
					str(move["animation_file"]).get_file())


static func _save() -> bool:
	var active_dir := storage_dir()
	if active_dir == USER_DIR:
		DirAccess.make_dir_recursive_absolute(active_dir)
	_normalize_animation_paths_for_storage()
	var file := FileAccess.open(_manifest_file(), FileAccess.WRITE)
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
	return _manifest_file()


static func storage_absolute_path() -> String:
	return ProjectSettings.globalize_path(storage_dir())


static func _resolve_animation_file(file: String) -> String:
	if file == "":
		return ""
	# Les anciens manifestes utilisaient user://. En mode projet, le fichier du
	# depot portant le meme nom devient la source de verite sans casser les
	# anciennes installations.
	var active_copy := storage_dir().path_join(file.get_file())
	if FileAccess.file_exists(active_copy):
		return ProjectSettings.globalize_path(active_copy)
	if (file.begins_with("user://") or file.begins_with("res://")) \
	and FileAccess.file_exists(file):
		return ProjectSettings.globalize_path(file)
	return file if FileAccess.file_exists(file) else ""


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
	var file := _resolve_animation_file(str(custom.get("animation_file", "")))
	if file == "":
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
	var file := _resolve_animation_file(str(custom.get("animation_file", "")))
	if file == "":
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
	var file := _resolve_animation_file(str(custom.get("animation_file", "")))
	if file == "":
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
	var file := _resolve_animation_file(str(custom.get("animation_file", "")))
	if file == "":
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
	var dst_path := "%s/%s.glb" % [storage_dir(), move_name]
	var dst := FileAccess.open(dst_path, FileAccess.WRITE)
	if dst == null:
		src.close()
		return ""
	dst.store_buffer(src.get_buffer(src.get_length()))
	dst.close()
	src.close()
	return dst_path


static func _backup_root() -> String:
	var project_parent := ProjectSettings.globalize_path("res://..").simplify_path()
	return project_parent.path_join("05_SAUVEGARDES")


static func _copy_file(source_path: String, target_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		source.close()
		return false
	target.store_buffer(source.get_buffer(source.get_length()))
	target.close()
	source.close()
	return true


static func create_backup() -> String:
	_ensure()
	var now := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		now.year, now.month, now.day, now.hour, now.minute, now.second]
	var destination := _backup_root().path_join("%s_%s" % [BACKUP_FOLDER, stamp])
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		return ""
	var source_dir := DirAccess.open(storage_dir())
	if source_dir == null:
		return ""
	var copied := 0
	source_dir.list_dir_begin()
	var file_name := source_dir.get_next()
	while file_name != "":
		if not source_dir.current_is_dir() and (file_name.get_extension().to_lower() == "glb" \
		or file_name == "attack_manifest.json"):
			if _copy_file(storage_dir().path_join(file_name), destination.path_join(file_name)):
				copied += 1
		file_name = source_dir.get_next()
	source_dir.list_dir_end()
	return destination if copied > 0 else ""


static func latest_backup() -> String:
	var root_path := _backup_root()
	var root_dir := DirAccess.open(root_path)
	if root_dir == null:
		return ""
	var latest := ""
	root_dir.list_dir_begin()
	var entry := root_dir.get_next()
	while entry != "":
		if root_dir.current_is_dir() and entry.begins_with(BACKUP_FOLDER + "_") \
		and entry > latest:
			latest = entry
		entry = root_dir.get_next()
	root_dir.list_dir_end()
	return root_path.path_join(latest) if latest != "" else ""


static func restore_latest_backup() -> String:
	var source_path := latest_backup()
	if source_path == "":
		return ""
	var source_dir := DirAccess.open(source_path)
	if source_dir == null:
		return ""
	if storage_dir() == USER_DIR:
		DirAccess.make_dir_recursive_absolute(USER_DIR)
	var copied := 0
	source_dir.list_dir_begin()
	var file_name := source_dir.get_next()
	while file_name != "":
		if not source_dir.current_is_dir() and (file_name.get_extension().to_lower() == "glb" \
		or file_name == "attack_manifest.json"):
			if _copy_file(source_path.path_join(file_name), storage_dir().path_join(file_name)):
				copied += 1
		file_name = source_dir.get_next()
	source_dir.list_dir_end()
	if copied == 0:
		return ""
	reload()
	return source_path


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
