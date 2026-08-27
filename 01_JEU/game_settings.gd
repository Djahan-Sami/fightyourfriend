extends RefCounted
class_name GameSettings

const PATH := "user://game_settings.json"
const SKINS_FOLDER := "03_SKINS_PERSONNAGES"
const STAGES_FOLDER := "04_SKINS_TERRAINS"
const DEFAULT_RESET_KEY := KEY_BACKSPACE
const ACTIONS := ["left", "right", "up", "down", "jump", "punch", "kick", "grab"]
const ACTION_LABELS := {
	"left": "Gauche", "right": "Droite", "up": "Haut", "down": "Bas",
	"jump": "Saut", "punch": "Poing", "kick": "Pied", "grab": "Saisie",
}
const DEFAULT_KEYS := [
	{
		"left": KEY_Q, "right": KEY_D, "up": KEY_Z, "down": KEY_S,
		"jump": KEY_SPACE, "punch": KEY_F, "kick": KEY_G, "grab": KEY_E,
	},
	{
		"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
		"jump": KEY_KP_0, "punch": KEY_KP_1, "kick": KEY_KP_2, "grab": KEY_KP_3,
	},
]

static var _loaded := false
static var _keys: Array[Dictionary] = []
static var _reset_key := DEFAULT_RESET_KEY
static var _skins: Array[String] = ["", ""]
static var _stage := ""
static var _workshop_requested := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_keys = [DEFAULT_KEYS[0].duplicate(true), DEFAULT_KEYS[1].duplicate(true)]
	_reset_key = DEFAULT_RESET_KEY
	_skins = ["", ""]
	_stage = ""
	ensure_skin_directory()
	stage_directory_absolute()
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var reset_value = parsed.get("reset_key", DEFAULT_RESET_KEY)
	if reset_value is float or reset_value is int:
		_reset_key = int(reset_value)
	var controls = parsed.get("controls", [])
	if controls is Array:
		for player in mini(2, controls.size()):
			if not (controls[player] is Dictionary):
				continue
			for action in ACTIONS:
				var value = controls[player].get(action, _keys[player][action])
				if value is float or value is int:
					_keys[player][action] = int(value)
	var skins = parsed.get("skins", [])
	if skins is Array:
		for player in mini(2, skins.size()):
			var file_name := str(skins[player]).get_file()
			if file_name == str(skins[player]) and _is_skin_file(file_name):
				_skins[player] = file_name
	var stage_name := str(parsed.get("stage", "")).get_file()
	if stage_name == str(parsed.get("stage", "")) and _is_stage_file(stage_name):
		_stage = stage_name


static func save() -> bool:
	_ensure()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"version": 4,
		"controls": _keys,
		"reset_key": _reset_key,
		"skins": _skins,
		"stage": _stage,
	}, "  "))
	file.close()
	return true


static func reset_controls() -> void:
	_ensure()
	_keys = [DEFAULT_KEYS[0].duplicate(true), DEFAULT_KEYS[1].duplicate(true)]
	_reset_key = DEFAULT_RESET_KEY
	save()
	apply_input_map()


static func ensure_skin_directory() -> void:
	DirAccess.make_dir_recursive_absolute(skin_directory_absolute())


static func skin_directory_absolute() -> String:
	return shared_root_absolute().path_join(SKINS_FOLDER)


static func stage_directory_absolute() -> String:
	var path := shared_root_absolute().path_join(STAGES_FOLDER)
	DirAccess.make_dir_recursive_absolute(path)
	return path


static func shared_root_absolute() -> String:
	var project_root := ProjectSettings.globalize_path("res://").simplify_path()
	# Le projet Godot vit dans 01_JEU, tandis que les contenus modifiables
	# restent visibles juste a cote. Ce repli garde aussi les tests autonomes.
	return project_root.get_base_dir() if project_root.get_file() == "01_JEU" else project_root


static func available_skins() -> Array[Dictionary]:
	ensure_skin_directory()
	var result: Array[Dictionary] = []
	var skins_dir := skin_directory_absolute()
	var directory := DirAccess.open(skins_dir)
	if directory == null:
		return result
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and _is_skin_file(file_name):
			result.append({
				"file": file_name,
				"label": file_name.get_basename().replace("_", " ").capitalize(),
				"path": skins_dir.path_join(file_name),
			})
		file_name = directory.get_next()
	directory.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["label"]).naturalnocasecmp_to(str(b["label"])) < 0)
	return result


static func selected_skin(player: int) -> String:
	_ensure()
	return _skins[clampi(player, 0, 1)]


static func selected_skin_path(player: int) -> String:
	var file_name := selected_skin(player)
	if file_name == "":
		return ""
	var path := skin_directory_absolute().path_join(file_name)
	return path if FileAccess.file_exists(path) else ""


static func assign_skin(player: int, file_name: String) -> bool:
	_ensure()
	player = clampi(player, 0, 1)
	file_name = file_name.get_file()
	if file_name != "" and (not _is_skin_file(file_name)
	or not FileAccess.file_exists(skin_directory_absolute().path_join(file_name))):
		return false
	_skins[player] = file_name
	return save()


static func _is_skin_file(file_name: String) -> bool:
	return file_name.get_extension().to_lower() in ["glb", "gltf"]


static func available_stages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stages_dir := stage_directory_absolute()
	var directory := DirAccess.open(stages_dir)
	if directory == null:
		return result
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and _is_stage_file(file_name) \
		and _stage_floor_path_for(file_name) != "":
			result.append({
				"file": file_name,
				"label": file_name.get_basename().replace("_", " ").capitalize(),
				"path": stages_dir.path_join(file_name),
			})
		file_name = directory.get_next()
	directory.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["label"]).naturalnocasecmp_to(str(b["label"])) < 0)
	return result


static func selected_stage() -> String:
	_ensure()
	return _stage


static func selected_stage_path() -> String:
	var file_name := selected_stage()
	if file_name == "":
		return ""
	var path := stage_directory_absolute().path_join(file_name)
	return path if FileAccess.file_exists(path) and _stage_floor_path_for(file_name) != "" else ""


static func selected_stage_floor_path() -> String:
	return _stage_floor_path_for(selected_stage())


static func assign_stage(file_name: String) -> bool:
	_ensure()
	file_name = file_name.get_file()
	if file_name != "" and (not _is_stage_file(file_name)
	or not FileAccess.file_exists(stage_directory_absolute().path_join(file_name))
	or _stage_floor_path_for(file_name) == ""):
		return false
	_stage = file_name
	return save()


static func _is_stage_file(file_name: String) -> bool:
	if file_name == "":
		return true
	return file_name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] \
		and not file_name.get_basename().to_lower().ends_with("_sol")


static func _stage_floor_path_for(background_file: String) -> String:
	if background_file == "":
		return ""
	var base := background_file.get_basename()
	var directory := stage_directory_absolute()
	for extension in ["png", "jpg", "jpeg", "webp"]:
		var candidate := directory.path_join("%s_sol.%s" % [base, extension])
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


static func key_for(player: int, action: String) -> int:
	_ensure()
	return int(_keys[clampi(player, 0, 1)].get(action, 0))


static func key_name(player: int, action: String) -> String:
	var result := OS.get_keycode_string(key_for(player, action))
	return result if result != "" else "Touche inconnue"


static func assign_key(player: int, action: String, keycode: int) -> void:
	_ensure()
	player = clampi(player, 0, 1)
	if not action in ACTIONS or keycode == 0:
		return
	var previous := int(_keys[player][action])
	# Une touche ne commande jamais deux actions : si elle est deja prise,
	# les deux affectations sont echangees automatiquement.
	for other_player in 2:
		for other_action in ACTIONS:
			if other_player == player and other_action == action:
				continue
			if int(_keys[other_player][other_action]) == keycode:
				_keys[other_player][other_action] = previous
	if _reset_key == keycode:
		_reset_key = previous
	_keys[player][action] = keycode
	save()
	apply_input_map()


static func reset_key() -> int:
	_ensure()
	return _reset_key


static func reset_key_name() -> String:
	var result := OS.get_keycode_string(reset_key())
	return result if result != "" else "Touche inconnue"


static func assign_reset_key(keycode: int) -> void:
	_ensure()
	if keycode == 0:
		return
	var previous := _reset_key
	for player in 2:
		for action in ACTIONS:
			if int(_keys[player][action]) == keycode:
				_keys[player][action] = previous
	_reset_key = keycode
	save()
	apply_input_map()


static func apply_input_map() -> void:
	_ensure()
	if not InputMap.has_action("reset"):
		InputMap.add_action("reset")
	InputMap.action_erase_events("reset")
	var reset_event := InputEventKey.new()
	reset_event.keycode = reset_key()
	InputMap.action_add_event("reset", reset_event)
	for player in 2:
		for action in ACTIONS:
			var action_name := "p%d_%s" % [player + 1, action]
			if not InputMap.has_action(action_name):
				InputMap.add_action(action_name)
			InputMap.action_erase_events(action_name)
			var key_event := InputEventKey.new()
			key_event.keycode = key_for(player, action)
			InputMap.action_add_event(action_name, key_event)


static func short_summary(player: int) -> String:
	return "%s/%s/%s/%s  Saut %s  Poing %s  Pied %s  Saisie %s" % [
		key_name(player, "up"), key_name(player, "left"), key_name(player, "down"),
		key_name(player, "right"), key_name(player, "jump"), key_name(player, "punch"),
		key_name(player, "kick"), key_name(player, "grab"),
	]


static func request_workshop() -> void:
	_workshop_requested = true


static func consume_workshop_request() -> bool:
	var result := _workshop_requested
	_workshop_requested = false
	return result
