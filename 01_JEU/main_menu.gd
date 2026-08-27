extends Control
class_name MainMenu

var _main_page: Control
var _controls_page: Control
var _skins_page: Control
var _stages_page: Control
var _main_status: Label
var _capture_status: Label
var _skins_status: Label
var _stages_status: Label
var _key_buttons: Dictionary = {}
var _skin_selects: Array[OptionButton] = []
var _skin_entries: Array[Dictionary] = []
var _stage_select: OptionButton
var _stage_entries: Array[Dictionary] = []
var _reset_button: Button
var _capture_player := -1
var _capture_action := ""


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameSettings.apply_input_map()
	_build_background()
	_build_main_page()
	_build_controls_page()
	_build_skins_page()
	_build_stages_page()
	_show_main()


func _build_background() -> void:
	var background := MenuBackdrop.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)


func _panel(size: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.18, 0.32, 0.94)
	style.border_color = Color(0.42, 0.72, 1.0, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	return column


func _build_main_page() -> void:
	var column := _panel(Vector2(650, 650))
	_main_page = column.get_parent().get_parent().get_parent()
	var title := Label.new()
	title.text = "RAGDOLL BRAWL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.77, 0.25))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "JEU DE COMBAT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.72, 0.95))
	column.add_child(subtitle)
	_add_spacer(column, 12)
	var play := _menu_button("JOUER", 25)
	play.custom_minimum_size.y = 62
	play.pressed.connect(_play)
	column.add_child(play)
	var controls := _menu_button("CONFIGURER LES TOUCHES")
	controls.pressed.connect(_show_controls)
	column.add_child(controls)
	var workshop := _menu_button("ATELIER DES COUPS ET HITBOX")
	workshop.pressed.connect(_open_workshop)
	column.add_child(workshop)
	_add_section(column, "PERSONNALISATION")
	var models := _menu_button("CHOISIR LES SKINS 3D")
	models.pressed.connect(_show_skins)
	column.add_child(models)
	var stages := _menu_button("CHOISIR LE TERRAIN")
	stages.pressed.connect(_show_stages)
	column.add_child(stages)
	_main_status = Label.new()
	_main_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_status.custom_minimum_size.y = 42
	_main_status.add_theme_color_override("font_color", Color(0.74, 0.82, 1.0))
	column.add_child(_main_status)
	var quit := _menu_button("QUITTER")
	quit.pressed.connect(func(): get_tree().quit())
	column.add_child(quit)


func _build_controls_page() -> void:
	var column := _panel(Vector2(1060, 670))
	_controls_page = column.get_parent().get_parent().get_parent()
	var title := Label.new()
	title.text = "CONFIGURATION DES TOUCHES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	column.add_child(title)
	var instruction := Label.new()
	instruction.text = "Clique sur une commande, puis appuie sur la nouvelle touche. Si elle est deja utilisee, les deux touches seront echangees."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96))
	column.add_child(instruction)
	var players := HBoxContainer.new()
	players.add_theme_constant_override("separation", 42)
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(players)
	for player in 2:
		var player_column := VBoxContainer.new()
		player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_column.add_theme_constant_override("separation", 5)
		players.add_child(player_column)
		var player_title := Label.new()
		player_title.text = "JOUEUR %d" % (player + 1)
		player_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_title.add_theme_font_size_override("font_size", 22)
		player_title.add_theme_color_override("font_color",
			Color(0.38, 0.66, 1.0) if player == 0 else Color(1.0, 0.36, 0.34))
		player_column.add_child(player_title)
		for action in GameSettings.ACTIONS:
			var row := HBoxContainer.new()
			player_column.add_child(row)
			var label := Label.new()
			label.text = str(GameSettings.ACTION_LABELS[action])
			label.custom_minimum_size.x = 150
			row.add_child(label)
			var button := _menu_button("", 15)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 37
			button.pressed.connect(_start_capture.bind(player, action))
			row.add_child(button)
			_key_buttons[_key_id(player, action)] = button
	var general := HBoxContainer.new()
	general.alignment = BoxContainer.ALIGNMENT_CENTER
	general.add_theme_constant_override("separation", 12)
	column.add_child(general)
	var general_label := Label.new()
	general_label.text = "RECOMMENCER LA PARTIE"
	general_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	general.add_child(general_label)
	_reset_button = _menu_button("", 15)
	_reset_button.custom_minimum_size.x = 240
	_reset_button.pressed.connect(_start_reset_capture)
	general.add_child(_reset_button)
	_capture_status = Label.new()
	_capture_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_status.custom_minimum_size.y = 28
	_capture_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	column.add_child(_capture_status)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	column.add_child(bottom)
	var reset := _menu_button("TOUCHES PAR DEFAUT")
	reset.pressed.connect(_reset_controls)
	bottom.add_child(reset)
	var back := _menu_button("RETOUR")
	back.pressed.connect(_show_main)
	bottom.add_child(back)
	_refresh_key_buttons()


func _build_skins_page() -> void:
	var column := _panel(Vector2(900, 610))
	_skins_page = column.get_parent().get_parent().get_parent()
	var title := Label.new()
	title.text = "SKINS DES COMBATTANTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	column.add_child(title)
	var instruction := Label.new()
	instruction.text = "Place tes modeles .glb ou .gltf dans le dossier, puis actualise la liste. Le jeu les adapte automatiquement au squelette des combattants."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", Color(0.78, 0.85, 0.98))
	column.add_child(instruction)
	var folder_path := Label.new()
	folder_path.text = GameSettings.skin_directory_absolute()
	folder_path.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	folder_path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	folder_path.tooltip_text = GameSettings.skin_directory_absolute()
	folder_path.add_theme_color_override("font_color", Color(0.53, 0.73, 1.0))
	column.add_child(folder_path)
	var folder_row := HBoxContainer.new()
	folder_row.alignment = BoxContainer.ALIGNMENT_CENTER
	folder_row.add_theme_constant_override("separation", 12)
	column.add_child(folder_row)
	var open_folder := _menu_button("OUVRIR LE DOSSIER DES SKINS", 15)
	open_folder.pressed.connect(_open_skins_folder)
	folder_row.add_child(open_folder)
	var refresh := _menu_button("ACTUALISER LA LISTE", 15)
	refresh.pressed.connect(_refresh_skin_choices)
	folder_row.add_child(refresh)
	var players := HBoxContainer.new()
	players.add_theme_constant_override("separation", 24)
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(players)
	for player in 2:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.11, 0.17, 0.31, 0.94)
		card_style.border_color = Color(0.30, 0.58, 1.0, 0.82) \
			if player == 0 else Color(1.0, 0.34, 0.32, 0.82)
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(10)
		card.add_theme_stylebox_override("panel", card_style)
		players.add_child(card)
		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 18)
		card_margin.add_theme_constant_override("margin_right", 18)
		card_margin.add_theme_constant_override("margin_top", 18)
		card_margin.add_theme_constant_override("margin_bottom", 18)
		card.add_child(card_margin)
		var player_column := VBoxContainer.new()
		player_column.add_theme_constant_override("separation", 12)
		card_margin.add_child(player_column)
		var player_title := Label.new()
		player_title.text = "COMBATTANT BLEU" if player == 0 else "COMBATTANT ROUGE"
		player_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_title.add_theme_font_size_override("font_size", 21)
		player_title.add_theme_color_override("font_color",
			Color(0.43, 0.70, 1.0) if player == 0 else Color(1.0, 0.43, 0.40))
		player_column.add_child(player_title)
		var choice := OptionButton.new()
		choice.custom_minimum_size.y = 48
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_option(choice)
		choice.item_selected.connect(_skin_selected.bind(player))
		player_column.add_child(choice)
		_skin_selects.append(choice)
		var note := Label.new()
		note.text = "Ce choix sera utilise au prochain combat."
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", Color(0.68, 0.76, 0.91))
		player_column.add_child(note)
	_skins_status = Label.new()
	_skins_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skins_status.custom_minimum_size.y = 28
	_skins_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skins_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	column.add_child(_skins_status)
	var back := _menu_button("RETOUR")
	back.pressed.connect(_show_main)
	column.add_child(back)
	_refresh_skin_choices()


func _build_stages_page() -> void:
	var column := _panel(Vector2(850, 520))
	_stages_page = column.get_parent().get_parent().get_parent()
	var title := Label.new()
	title.text = "SKINS DE L'ARENE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	column.add_child(title)
	var instruction := Label.new()
	instruction.text = "Chaque terrain utilise deux images : Nom.png pour le decor et Nom_sol.png pour le vrai revetement sous les pieds."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", Color(0.78, 0.85, 0.98))
	column.add_child(instruction)
	var folder_path := Label.new()
	folder_path.text = GameSettings.stage_directory_absolute()
	folder_path.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	folder_path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	folder_path.tooltip_text = GameSettings.stage_directory_absolute()
	folder_path.add_theme_color_override("font_color", Color(0.53, 0.73, 1.0))
	column.add_child(folder_path)
	var folder_row := HBoxContainer.new()
	folder_row.alignment = BoxContainer.ALIGNMENT_CENTER
	folder_row.add_theme_constant_override("separation", 12)
	column.add_child(folder_row)
	var open_folder := _menu_button("OUVRIR LE DOSSIER", 15)
	open_folder.pressed.connect(_open_stages_folder)
	folder_row.add_child(open_folder)
	var refresh := _menu_button("ACTUALISER LA LISTE", 15)
	refresh.pressed.connect(_refresh_stage_choices)
	folder_row.add_child(refresh)
	var choice_label := Label.new()
	choice_label.text = "TERRAIN UTILISE"
	choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_label.add_theme_font_size_override("font_size", 18)
	choice_label.add_theme_color_override("font_color", Color(0.58, 0.76, 1.0))
	column.add_child(choice_label)
	_stage_select = OptionButton.new()
	_stage_select.custom_minimum_size.y = 54
	_stage_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option(_stage_select)
	_stage_select.item_selected.connect(_stage_selected)
	column.add_child(_stage_select)
	_stages_status = Label.new()
	_stages_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stages_status.custom_minimum_size.y = 42
	_stages_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stages_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	column.add_child(_stages_status)
	var back := _menu_button("RETOUR")
	back.pressed.connect(_show_main)
	column.add_child(back)
	_refresh_stage_choices()


func _menu_button(text: String, font_size := 17) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.25, 0.44, 0.98)
	normal.border_color = Color(0.34, 0.56, 0.91, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.24, 0.39, 0.66, 1.0)
	hover.border_color = Color(0.58, 0.80, 1.0, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.20, 0.38, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	if text == "JOUER":
		normal.bg_color = Color(0.82, 0.48, 0.10, 1.0)
		normal.border_color = Color(1.0, 0.82, 0.36, 1.0)
		hover.bg_color = Color(0.96, 0.61, 0.16, 1.0)
		pressed.bg_color = Color(0.70, 0.36, 0.07, 1.0)
	return button


func _style_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size", 17)
	option.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.25, 0.44, 0.98)
	normal.border_color = Color(0.36, 0.62, 0.96, 0.82)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	option.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.23, 0.38, 0.64, 1.0)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", hover)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.45, 0.65, 1.0))
	parent.add_child(label)


func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)


func _play() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://arena3d.tscn")


func _open_workshop() -> void:
	GameSettings.request_workshop()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://arena3d.tscn")


func _future_message(message: String) -> void:
	_main_status.text = message


func _open_stages_folder() -> void:
	var folder := GameSettings.stage_directory_absolute().replace("\\", "/")
	var result := OS.shell_open(folder)
	if result == OK:
		_stages_status.text = "Dossier ouvert. Ajoute le decor et son fichier _sol, puis actualise la liste."
	else:
		_stages_status.text = "Impossible d'ouvrir le dossier automatiquement : %s" % folder


func _open_skins_folder() -> void:
	var folder := GameSettings.skin_directory_absolute().replace("\\", "/")
	var result := OS.shell_open(folder)
	if result == OK:
		_skins_status.text = "Dossier ouvert. Ajoute tes fichiers, puis clique sur ACTUALISER LA LISTE."
	else:
		_skins_status.text = "Impossible d'ouvrir le dossier automatiquement : %s" % folder


func _refresh_skin_choices() -> void:
	_skin_entries = GameSettings.available_skins()
	for player in mini(2, _skin_selects.size()):
		var choice := _skin_selects[player]
		choice.clear()
		choice.add_item("MODELE ACTUEL / PAR DEFAUT")
		choice.set_item_metadata(0, "")
		var wanted := GameSettings.selected_skin(player)
		var selected_index := 0
		for entry in _skin_entries:
			choice.add_item(str(entry["label"]))
			var index := choice.item_count - 1
			choice.set_item_metadata(index, str(entry["file"]))
			choice.set_item_tooltip(index, str(entry["file"]))
			if str(entry["file"]) == wanted:
				selected_index = index
		choice.select(selected_index)
	if _skins_status:
		if _skin_entries.is_empty():
			_skins_status.text = "Le dossier est vide. Ajoute un fichier .glb ou .gltf."
		else:
			_skins_status.text = "%d skin%s disponible%s." % [
				_skin_entries.size(), "s" if _skin_entries.size() > 1 else "",
				"s" if _skin_entries.size() > 1 else "",
			]


func _skin_selected(index: int, player: int) -> void:
	if player < 0 or player >= _skin_selects.size():
		return
	var choice := _skin_selects[player]
	var file_name := str(choice.get_item_metadata(index))
	if GameSettings.assign_skin(player, file_name):
		var label := "le modele actuel" if file_name == "" else file_name.get_basename()
		_skins_status.text = "Combattant %s : %s." % [
			"bleu" if player == 0 else "rouge", label,
		]
	else:
		_skins_status.text = "Ce skin n'est plus disponible. Actualise la liste."


func _refresh_stage_choices() -> void:
	if _stage_select == null:
		return
	_stage_entries = GameSettings.available_stages()
	_stage_select.clear()
	_stage_select.add_item("ARENE CLASSIQUE")
	_stage_select.set_item_metadata(0, "")
	var wanted := GameSettings.selected_stage()
	var selected_index := 0
	for entry in _stage_entries:
		_stage_select.add_item(str(entry["label"]))
		var index := _stage_select.item_count - 1
		_stage_select.set_item_metadata(index, str(entry["file"]))
		_stage_select.set_item_tooltip(index, str(entry["file"]))
		if str(entry["file"]) == wanted:
			selected_index = index
	_stage_select.select(selected_index)
	if _stages_status:
		if _stage_entries.is_empty():
			_stages_status.text = "Aucun terrain complet. Il faut une paire Nom.png + Nom_sol.png."
		else:
			_stages_status.text = "%d terrain%s disponible%s. Le changement sera visible au prochain combat." % [
				_stage_entries.size(), "s" if _stage_entries.size() > 1 else "",
				"s" if _stage_entries.size() > 1 else "",
			]


func _stage_selected(index: int) -> void:
	if _stage_select == null or index < 0 or index >= _stage_select.item_count:
		return
	var file_name := str(_stage_select.get_item_metadata(index))
	if GameSettings.assign_stage(file_name):
		var label := "l'arene classique" if file_name == "" else file_name.get_basename().replace("_", " ")
		_stages_status.text = "Terrain selectionne : %s. Lance un combat pour le voir." % label
	else:
		_stages_status.text = "Terrain incomplet : verifie le decor et son image _sol, puis actualise."


func _show_main() -> void:
	_capture_player = -1
	_capture_action = ""
	if _main_page:
		_main_page.visible = true
	if _controls_page:
		_controls_page.visible = false
	if _skins_page:
		_skins_page.visible = false
	if _stages_page:
		_stages_page.visible = false
	_refresh_key_buttons()


func _show_controls() -> void:
	_main_page.visible = false
	_controls_page.visible = true
	_skins_page.visible = false
	_stages_page.visible = false
	_capture_status.text = ""
	_refresh_key_buttons()


func _show_skins() -> void:
	_main_page.visible = false
	_controls_page.visible = false
	_skins_page.visible = true
	_stages_page.visible = false
	_refresh_skin_choices()


func _show_stages() -> void:
	_main_page.visible = false
	_controls_page.visible = false
	_skins_page.visible = false
	_stages_page.visible = true
	_refresh_stage_choices()


func _start_capture(player: int, action: String) -> void:
	_capture_player = player
	_capture_action = action
	_capture_status.text = "Appuie maintenant sur la touche pour : Joueur %d - %s\nEchap pour annuler." % [
		player + 1, GameSettings.ACTION_LABELS[action],
	]
	get_viewport().gui_release_focus()


func _start_reset_capture() -> void:
	_capture_player = 2
	_capture_action = "reset"
	_capture_status.text = "Appuie maintenant sur la touche pour recommencer la partie.\nEchap pour annuler."
	get_viewport().gui_release_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _capture_player >= 0:
		if event.keycode == KEY_ESCAPE:
			_capture_player = -1
			_capture_action = ""
			_capture_status.text = "Modification annulee."
			get_viewport().set_input_as_handled()
			return
		var code := int(event.keycode)
		if code == KEY_F10:
			_capture_status.text = "Cette touche est reservee au jeu. Choisis-en une autre, ou Echap pour annuler."
			get_viewport().set_input_as_handled()
			return
		if _capture_player == 2:
			GameSettings.assign_reset_key(code)
		else:
			GameSettings.assign_key(_capture_player, _capture_action, code)
		_capture_player = -1
		_capture_action = ""
		_capture_status.text = "Touche enregistree."
		_refresh_key_buttons()
		get_viewport().set_input_as_handled()
	elif (_controls_page.visible or _skins_page.visible or _stages_page.visible) and event.keycode == KEY_ESCAPE:
		_show_main()
		get_viewport().set_input_as_handled()


func _reset_controls() -> void:
	GameSettings.reset_controls()
	_capture_status.text = "Les touches par defaut ont ete restaurees."
	_refresh_key_buttons()


func _refresh_key_buttons() -> void:
	for player in 2:
		for action in GameSettings.ACTIONS:
			var button: Button = _key_buttons.get(_key_id(player, action))
			if button:
				button.text = GameSettings.key_name(player, action)
	if _reset_button:
		_reset_button.text = GameSettings.reset_key_name()


func _key_id(player: int, action: String) -> String:
	return "%d:%s" % [player, action]
