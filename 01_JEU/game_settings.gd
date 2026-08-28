extends RefCounted
class_name GameSettings

const PATH := "user://game_settings.json"
const SKINS_FOLDER := "03_SKINS_PERSONNAGES"
const STAGES_FOLDER := "04_SKINS_TERRAINS"
const DEFAULT_RESET_KEY := KEY_BACKSPACE
const DEFAULT_PAUSE_KEY := KEY_ESCAPE
const ACTIONS := ["left", "right", "up", "down", "jump", "punch", "kick", "grab"]
const PAD_ACTIONS := ["jump", "punch", "kick", "grab"]
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
const DEFAULT_PAD_BINDINGS := [
	{
		"jump": {"type": "button", "index": JOY_BUTTON_A},
		"punch": {"type": "button", "index": JOY_BUTTON_X},
		"kick": {"type": "button", "index": JOY_BUTTON_B},
		"grab": {"type": "button", "index": JOY_BUTTON_Y},
	},
	{
		"jump": {"type": "button", "index": JOY_BUTTON_A},
		"punch": {"type": "button", "index": JOY_BUTTON_X},
		"kick": {"type": "button", "index": JOY_BUTTON_B},
		"grab": {"type": "button", "index": JOY_BUTTON_Y},
	},
]
const DEFAULT_PAD_RESET := {"type": "button", "index": JOY_BUTTON_BACK}
const DEFAULT_PAD_PAUSE := {"type": "button", "index": JOY_BUTTON_START}
const DEFAULT_SINGLE_CONTROLLER_PLAYER := 0
const DEFAULT_STICK_DEADZONE := 0.18
const DEFAULT_STICK_SENSITIVITY := 1.0

static var _loaded := false
static var _keys: Array[Dictionary] = []
static var _reset_key := DEFAULT_RESET_KEY
static var _pause_key := DEFAULT_PAUSE_KEY
static var _pad_bindings: Array[Dictionary] = []
static var _pad_reset: Dictionary = DEFAULT_PAD_RESET.duplicate(true)
static var _pad_pause: Dictionary = DEFAULT_PAD_PAUSE.duplicate(true)
static var _single_controller_player := DEFAULT_SINGLE_CONTROLLER_PLAYER
static var _stick_deadzone := DEFAULT_STICK_DEADZONE
static var _stick_sensitivity := DEFAULT_STICK_SENSITIVITY
static var _skins: Array[String] = ["", ""]
static var _stage := ""
static var _workshop_requested := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_keys = [DEFAULT_KEYS[0].duplicate(true), DEFAULT_KEYS[1].duplicate(true)]
	_reset_key = DEFAULT_RESET_KEY
	_pause_key = DEFAULT_PAUSE_KEY
	_pad_bindings = [
		DEFAULT_PAD_BINDINGS[0].duplicate(true),
		DEFAULT_PAD_BINDINGS[1].duplicate(true),
	]
	_pad_reset = DEFAULT_PAD_RESET.duplicate(true)
	_pad_pause = DEFAULT_PAD_PAUSE.duplicate(true)
	_single_controller_player = DEFAULT_SINGLE_CONTROLLER_PLAYER
	_stick_deadzone = DEFAULT_STICK_DEADZONE
	_stick_sensitivity = DEFAULT_STICK_SENSITIVITY
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
	var pause_value = parsed.get("pause_key", DEFAULT_PAUSE_KEY)
	if pause_value is float or pause_value is int:
		_pause_key = int(pause_value)
	var controls = parsed.get("controls", [])
	if controls is Array:
		for player in mini(2, controls.size()):
			if not (controls[player] is Dictionary):
				continue
			for action in ACTIONS:
				var value = controls[player].get(action, _keys[player][action])
				if value is float or value is int:
					_keys[player][action] = int(value)
	var controller_controls = parsed.get("controller_controls", [])
	if controller_controls is Array:
		for player in mini(2, controller_controls.size()):
			if not (controller_controls[player] is Dictionary):
				continue
			for action in PAD_ACTIONS:
				_pad_bindings[player][action] = _valid_pad_binding(
					controller_controls[player].get(action, {}),
					_pad_bindings[player][action])
	_pad_reset = _valid_pad_binding(parsed.get("controller_reset", {}), _pad_reset, false)
	_pad_pause = _valid_pad_binding(parsed.get("controller_pause", {}), _pad_pause, false)
	var controller_player_value = parsed.get(
		"single_controller_player", DEFAULT_SINGLE_CONTROLLER_PLAYER)
	if controller_player_value is int or controller_player_value is float:
		_single_controller_player = clampi(int(controller_player_value), 0, 1)
	var deadzone_value = parsed.get("stick_deadzone", DEFAULT_STICK_DEADZONE)
	if deadzone_value is int or deadzone_value is float:
		_stick_deadzone = clampf(float(deadzone_value), 0.05, 0.40)
	var sensitivity_value = parsed.get("stick_sensitivity", DEFAULT_STICK_SENSITIVITY)
	if sensitivity_value is int or sensitivity_value is float:
		_stick_sensitivity = clampf(float(sensitivity_value), 0.60, 1.50)
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
		"version": 6,
		"controls": _keys,
		"reset_key": _reset_key,
		"pause_key": _pause_key,
		"controller_controls": _pad_bindings,
		"controller_reset": _pad_reset,
		"controller_pause": _pad_pause,
		"single_controller_player": _single_controller_player,
		"stick_deadzone": _stick_deadzone,
		"stick_sensitivity": _stick_sensitivity,
		"skins": _skins,
		"stage": _stage,
	}, "  "))
	file.close()
	return true


static func reset_controls() -> void:
	_ensure()
	_keys = [DEFAULT_KEYS[0].duplicate(true), DEFAULT_KEYS[1].duplicate(true)]
	_reset_key = DEFAULT_RESET_KEY
	_pause_key = DEFAULT_PAUSE_KEY
	_pad_bindings = [
		DEFAULT_PAD_BINDINGS[0].duplicate(true),
		DEFAULT_PAD_BINDINGS[1].duplicate(true),
	]
	_pad_reset = DEFAULT_PAD_RESET.duplicate(true)
	_pad_pause = DEFAULT_PAD_PAUSE.duplicate(true)
	_single_controller_player = DEFAULT_SINGLE_CONTROLLER_PLAYER
	_stick_deadzone = DEFAULT_STICK_DEADZONE
	_stick_sensitivity = DEFAULT_STICK_SENSITIVITY
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
	if _pause_key == keycode:
		_pause_key = previous
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
	if _pause_key == keycode:
		_pause_key = previous
	_reset_key = keycode
	save()
	apply_input_map()


static func pause_key() -> int:
	_ensure()
	return _pause_key


static func pause_key_name() -> String:
	var result := OS.get_keycode_string(pause_key())
	return result if result != "" else "Touche inconnue"


static func assign_pause_key(keycode: int) -> void:
	_ensure()
	if keycode == 0:
		return
	var previous := _pause_key
	for player in 2:
		for action in ACTIONS:
			if int(_keys[player][action]) == keycode:
				_keys[player][action] = previous
	if _reset_key == keycode:
		_reset_key = previous
	_pause_key = keycode
	save()
	apply_input_map()


static func controller_binding(player: int, action: String) -> Dictionary:
	_ensure()
	player = clampi(player, 0, 1)
	if not action in PAD_ACTIONS:
		return {}
	return _pad_bindings[player][action].duplicate(true)


static func controller_binding_name(player: int, action: String) -> String:
	return pad_binding_name(controller_binding(player, action))


static func controller_reset_binding() -> Dictionary:
	_ensure()
	return _pad_reset.duplicate(true)


static func controller_pause_binding() -> Dictionary:
	_ensure()
	return _pad_pause.duplicate(true)


static func controller_reset_name() -> String:
	return pad_binding_name(controller_reset_binding())


static func controller_pause_name() -> String:
	return pad_binding_name(controller_pause_binding())


static func single_controller_player() -> int:
	_ensure()
	return _single_controller_player


static func set_single_controller_player(player: int) -> bool:
	_ensure()
	_single_controller_player = clampi(player, 0, 1)
	return save()


static func stick_deadzone() -> float:
	_ensure()
	return _stick_deadzone


static func set_stick_deadzone(value: float) -> bool:
	_ensure()
	_stick_deadzone = clampf(value, 0.05, 0.40)
	return save()


static func stick_sensitivity() -> float:
	_ensure()
	return _stick_sensitivity


static func set_stick_sensitivity(value: float) -> bool:
	_ensure()
	_stick_sensitivity = clampf(value, 0.60, 1.50)
	return save()


static func assign_controller_binding(player: int, action: String, binding: Dictionary) -> bool:
	_ensure()
	player = clampi(player, 0, 1)
	if not action in PAD_ACTIONS:
		return false
	var checked := _valid_pad_binding(binding, {}, true)
	if checked.is_empty() or _same_pad_binding(checked, _pad_reset) \
	or _same_pad_binding(checked, _pad_pause):
		return false
	var previous: Dictionary = _pad_bindings[player][action].duplicate(true)
	# Sur une meme manette, un bouton ne lance jamais deux actions. Comme pour
	# le clavier, les deux affectations sont echangees.
	for other_action in PAD_ACTIONS:
		if other_action != action \
		and _same_pad_binding(_pad_bindings[player][other_action], checked):
			_pad_bindings[player][other_action] = previous
	_pad_bindings[player][action] = checked
	var saved := save()
	apply_input_map()
	return saved


static func assign_controller_reset(binding: Dictionary) -> bool:
	return _assign_controller_global("reset", binding)


static func assign_controller_pause(binding: Dictionary) -> bool:
	return _assign_controller_global("pause", binding)


static func _assign_controller_global(which: String, binding: Dictionary) -> bool:
	_ensure()
	var checked := _valid_pad_binding(binding, {}, false)
	if checked.is_empty():
		return false
	var other := _pad_pause if which == "reset" else _pad_reset
	if _same_pad_binding(checked, other):
		return false
	# Pause et recommencer sont globaux : on refuse un bouton de combat afin
	# qu'aucun joueur ne puisse relancer la partie en donnant un coup.
	for player in 2:
		for action in PAD_ACTIONS:
			if _same_pad_binding(_pad_bindings[player][action], checked):
				return false
	if which == "reset":
		_pad_reset = checked
	else:
		_pad_pause = checked
	var saved := save()
	apply_input_map()
	return saved


static func pad_binding_from_button(button_index: int) -> Dictionary:
	return _valid_pad_binding({"type": "button", "index": button_index}, {})


static func pad_binding_from_trigger(axis: int) -> Dictionary:
	if axis not in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		return {}
	return {"type": "axis", "index": axis, "value": 1.0}


static func pad_event(binding: Dictionary, device: int) -> InputEvent:
	var checked := _valid_pad_binding(binding, {})
	if checked.is_empty():
		return null
	if checked["type"] == "axis":
		var motion := InputEventJoypadMotion.new()
		motion.device = device
		motion.axis = int(checked["index"])
		motion.axis_value = float(checked.get("value", 1.0))
		return motion
	var button := InputEventJoypadButton.new()
	button.device = device
	button.button_index = int(checked["index"])
	return button


static func pad_binding_name(binding: Dictionary) -> String:
	var checked := _valid_pad_binding(binding, {})
	if checked.is_empty():
		return "Non defini"
	var index := int(checked["index"])
	if checked["type"] == "axis":
		return "Gachette LT" if index == JOY_AXIS_TRIGGER_LEFT else "Gachette RT"
	var names := {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "Retour / Select", JOY_BUTTON_GUIDE: "Guide",
		JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "Stick gauche",
		JOY_BUTTON_RIGHT_STICK: "Stick droit", JOY_BUTTON_LEFT_SHOULDER: "LB / L1",
		JOY_BUTTON_RIGHT_SHOULDER: "RB / R1", JOY_BUTTON_DPAD_UP: "Croix haut",
		JOY_BUTTON_DPAD_DOWN: "Croix bas", JOY_BUTTON_DPAD_LEFT: "Croix gauche",
		JOY_BUTTON_DPAD_RIGHT: "Croix droite", JOY_BUTTON_MISC1: "Bouton partage",
		JOY_BUTTON_PADDLE1: "Palette 1", JOY_BUTTON_PADDLE2: "Palette 2",
		JOY_BUTTON_PADDLE3: "Palette 3", JOY_BUTTON_PADDLE4: "Palette 4",
		JOY_BUTTON_TOUCHPAD: "Pave tactile",
	}
	return str(names.get(index, "Bouton %d" % index))


static func _valid_pad_binding(value, fallback: Dictionary,
		allow_axis := true) -> Dictionary:
	if not (value is Dictionary):
		return fallback.duplicate(true)
	var kind := str(value.get("type", ""))
	var raw_index = value.get("index", -1)
	if not (raw_index is int or raw_index is float):
		return fallback.duplicate(true)
	var index := int(raw_index)
	if kind == "button" and index >= 0 and index < 64:
		return {"type": "button", "index": index}
	if allow_axis and kind == "axis" \
	and index in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		return {"type": "axis", "index": index, "value": 1.0}
	return fallback.duplicate(true)


static func _same_pad_binding(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and not b.is_empty() \
		and str(a.get("type", "")) == str(b.get("type", "")) \
		and int(a.get("index", -1)) == int(b.get("index", -2))


static func apply_input_map() -> void:
	_ensure()
	for global_action in ["reset", "pause"]:
		if not InputMap.has_action(global_action):
			InputMap.add_action(global_action)
		InputMap.action_erase_events(global_action)
	var reset_event := InputEventKey.new()
	reset_event.keycode = reset_key()
	InputMap.action_add_event("reset", reset_event)
	var pause_event := InputEventKey.new()
	pause_event.keycode = pause_key()
	InputMap.action_add_event("pause", pause_event)
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
