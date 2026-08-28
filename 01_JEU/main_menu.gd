extends Control
class_name MainMenu


class StickPreview:
	extends Control
	var raw_value := 0.0
	var shaped_value := 0.0

	func update_values(raw: float, shaped: float) -> void:
		raw_value = clampf(raw, -1.0, 1.0)
		shaped_value = clampf(shaped, -1.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var left := 24.0
		var right := maxf(left + 1.0, size.x - 24.0)
		var y := size.y * 0.5
		draw_line(Vector2(left, y), Vector2(right, y), Color(0.43, 0.54, 0.73), 6.0)
		var center := (left + right) * 0.5
		draw_line(Vector2(center, y - 15.0), Vector2(center, y + 15.0),
			Color(0.82, 0.88, 1.0), 2.0)
		var raw_x := lerpf(left, right, (raw_value + 1.0) * 0.5)
		var shaped_x := lerpf(left, right, (shaped_value + 1.0) * 0.5)
		draw_circle(Vector2(raw_x, y), 6.0, Color(0.58, 0.67, 0.82))
		draw_circle(Vector2(shaped_x, y), 10.0, Color(1.0, 0.72, 0.22))


var _main_page: Control
var _controls_page: Control
var _controller_page: Control
var _skins_page: Control
var _stages_page: Control
var _main_status: Label
var _capture_status: Label
var _skins_status: Label
var _stages_status: Label
var _key_buttons: Dictionary = {}
var _pad_buttons: Dictionary = {}
var _skin_selects: Array[OptionButton] = []
var _skin_entries: Array[Dictionary] = []
var _stage_select: OptionButton
var _stage_entries: Array[Dictionary] = []
var _reset_button: Button
var _pause_key_button: Button
var _pad_reset_button: Button
var _pad_pause_button: Button
var _controller_player_select: OptionButton
var _controller_status: Label
var _deadzone_slider: HSlider
var _sensitivity_slider: HSlider
var _deadzone_value: Label
var _sensitivity_value: Label
var _stick_preview: StickPreview
var _stick_live_label: Label
var _capture_player := -1
var _capture_action := ""
var _capture_kind := ""
var _capture_focus_button: Button
var _last_hover_sound_ms := 0


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameSettings.apply_input_map()
	_build_background()
	_build_main_page()
	_build_controls_page()
	_build_controller_page()
	_build_skins_page()
	_build_stages_page()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
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
	title.text = "FIGHT YOUR FRIEND"
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
	var column := _panel(Vector2(1120, 700))
	_controls_page = column.get_parent().get_parent().get_parent()
	var title := Label.new()
	title.text = "CONFIGURATION DES TOUCHES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	column.add_child(title)
	var instruction := Label.new()
	instruction.text = "Clique sur une case CLAVIER ou MANETTE, puis appuie sur la nouvelle touche. Le stick gauche et la croix directionnelle fonctionnent toujours ensemble. Chaque changement est sauvegarde automatiquement."
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
		var header := HBoxContainer.new()
		player_column.add_child(header)
		var empty := Label.new()
		empty.custom_minimum_size.x = 102
		header.add_child(empty)
		for heading in ["CLAVIER", "MANETTE"]:
			var heading_label := Label.new()
			heading_label.text = heading
			heading_label.custom_minimum_size.x = 150
			heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			heading_label.add_theme_font_size_override("font_size", 12)
			heading_label.add_theme_color_override("font_color", Color(0.60, 0.72, 0.94))
			header.add_child(heading_label)
		for action in GameSettings.ACTIONS:
			var row := HBoxContainer.new()
			player_column.add_child(row)
			var label := Label.new()
			label.text = str(GameSettings.ACTION_LABELS[action])
			label.custom_minimum_size.x = 102
			row.add_child(label)
			var button := _menu_button("", 15)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(150, 34)
			button.pressed.connect(_start_capture.bind(player, action))
			row.add_child(button)
			_key_buttons[_key_id(player, action)] = button
			var pad_button := _menu_button("", 14)
			pad_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pad_button.custom_minimum_size = Vector2(150, 34)
			if action in GameSettings.PAD_ACTIONS:
				pad_button.pressed.connect(_start_pad_capture.bind(player, action))
			else:
				pad_button.disabled = true
				pad_button.tooltip_text = "Le stick gauche et la croix sont tous les deux actifs."
			row.add_child(pad_button)
			_pad_buttons[_key_id(player, action)] = pad_button
	var general := GridContainer.new()
	general.columns = 3
	general.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	general.add_theme_constant_override("h_separation", 12)
	general.add_theme_constant_override("v_separation", 5)
	column.add_child(general)
	for heading in ["COMMANDES GENERALES", "CLAVIER", "MANETTE"]:
		var heading_label := Label.new()
		heading_label.text = heading
		heading_label.custom_minimum_size.x = 220
		heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading_label.add_theme_font_size_override("font_size", 12)
		heading_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
		general.add_child(heading_label)
	_add_general_control_row(general, "RECOMMENCER", "reset")
	_add_general_control_row(general, "PAUSE", "pause")
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
	var controller_settings := _menu_button("REGLAGES DU STICK")
	controller_settings.pressed.connect(_show_controller_settings)
	bottom.add_child(controller_settings)
	var back := _menu_button("RETOUR")
	back.pressed.connect(_show_main)
	bottom.add_child(back)
	_refresh_key_buttons()


func _add_general_control_row(grid: GridContainer, label_text: String, action: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(label)
	var keyboard_button := _menu_button("", 14)
	keyboard_button.custom_minimum_size = Vector2(220, 34)
	keyboard_button.pressed.connect(_start_global_capture.bind("keyboard", action))
	grid.add_child(keyboard_button)
	var pad_button := _menu_button("", 14)
	pad_button.custom_minimum_size = Vector2(220, 34)
	pad_button.pressed.connect(_start_global_capture.bind("controller", action))
	grid.add_child(pad_button)
	if action == "reset":
		_reset_button = keyboard_button
		_pad_reset_button = pad_button
	else:
		_pause_key_button = keyboard_button
		_pad_pause_button = pad_button


func _build_controller_page() -> void:
	var column := _panel(Vector2(820, 620))
	_controller_page = column.get_parent().get_parent().get_parent()
	var title := Label.new()
	title.text = "REGLAGES DE LA MANETTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	column.add_child(title)
	var explanation := Label.new()
	explanation.text = "Ces reglages sont communs aux deux manettes et sauvegardes automatiquement. Ils ne changent pas la vitesse maximale des combattants."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96))
	column.add_child(explanation)
	_add_section(column, "AFFECTATION")
	var assignment_row := HBoxContainer.new()
	assignment_row.alignment = BoxContainer.ALIGNMENT_CENTER
	assignment_row.add_theme_constant_override("separation", 14)
	column.add_child(assignment_row)
	var assignment_label := Label.new()
	assignment_label.text = "SI UNE SEULE MANETTE EST BRANCHEE :"
	assignment_label.custom_minimum_size.x = 350
	assignment_row.add_child(assignment_label)
	_controller_player_select = OptionButton.new()
	_controller_player_select.custom_minimum_size = Vector2(250, 44)
	_controller_player_select.add_item("ELLE CONTROLE LE JOUEUR 1")
	_controller_player_select.add_item("ELLE CONTROLE LE JOUEUR 2")
	_style_option(_controller_player_select)
	_controller_player_select.item_selected.connect(_controller_player_selected)
	assignment_row.add_child(_controller_player_select)
	_controller_status = Label.new()
	_controller_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controller_status.custom_minimum_size.y = 26
	_controller_status.add_theme_color_override("font_color", Color(0.54, 0.76, 1.0))
	column.add_child(_controller_status)
	_add_section(column, "COMPORTEMENT DU STICK GAUCHE")
	var settings_grid := GridContainer.new()
	settings_grid.columns = 3
	settings_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_grid.add_theme_constant_override("h_separation", 16)
	settings_grid.add_theme_constant_override("v_separation", 14)
	column.add_child(settings_grid)
	_deadzone_slider = _add_stick_slider(settings_grid, "ZONE MORTE", 0.05, 0.40, 0.01)
	_deadzone_value = settings_grid.get_child(settings_grid.get_child_count() - 1) as Label
	_sensitivity_slider = _add_stick_slider(settings_grid, "SENSIBILITE", 0.60, 1.50, 0.05)
	_sensitivity_value = settings_grid.get_child(settings_grid.get_child_count() - 1) as Label
	_deadzone_slider.value_changed.connect(_deadzone_changed)
	_sensitivity_slider.value_changed.connect(_sensitivity_changed)
	_stick_preview = StickPreview.new()
	_stick_preview.custom_minimum_size = Vector2(650, 58)
	_stick_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stick_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stick_preview)
	_stick_live_label = Label.new()
	_stick_live_label.text = "Branche une manette et bouge le stick pour tester."
	_stick_live_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stick_live_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.94))
	column.add_child(_stick_live_label)
	var legend := Label.new()
	legend.text = "Point gris : position physique du stick    Point jaune : mouvement transmis au combattant"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color(0.62, 0.70, 0.86))
	column.add_child(legend)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	column.add_child(bottom)
	var defaults := _menu_button("VALEURS CONSEILLEES")
	defaults.pressed.connect(_reset_stick_settings)
	bottom.add_child(defaults)
	var back := _menu_button("RETOUR AUX TOUCHES")
	back.pressed.connect(_show_controls)
	bottom.add_child(back)
	_refresh_controller_settings()


func _add_stick_slider(grid: GridContainer, label_text: String, minimum: float,
		maximum: float, step: float) -> HSlider:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 170
	grid.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(370, 34)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 95
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	grid.add_child(value_label)
	return slider


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
	button.mouse_entered.connect(_play_ui_hover)
	button.focus_entered.connect(_play_ui_hover)
	button.pressed.connect(_play_ui_confirm)
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
	option.mouse_entered.connect(_play_ui_hover)
	option.focus_entered.connect(_play_ui_hover)
	option.item_selected.connect(func(_index: int): _play_ui_confirm())


func _play_ui_hover() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_sound_ms < 70:
		return
	_last_hover_sound_ms = now
	SFX.play_global("ui_hover", -15.0)


func _play_ui_confirm() -> void:
	SFX.play_global("ui_confirm", -11.0)


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
	_capture_kind = ""
	if _main_page:
		_main_page.visible = true
	if _controls_page:
		_controls_page.visible = false
	if _controller_page:
		_controller_page.visible = false
	if _skins_page:
		_skins_page.visible = false
	if _stages_page:
		_stages_page.visible = false
	_refresh_key_buttons()


func _show_controls() -> void:
	_main_page.visible = false
	_controls_page.visible = true
	_controller_page.visible = false
	_skins_page.visible = false
	_stages_page.visible = false
	_capture_status.text = ""
	_refresh_key_buttons()
	var first_button := _key_buttons.get(_key_id(0, "left")) as Button
	if first_button:
		first_button.call_deferred("grab_focus")


func _show_skins() -> void:
	_main_page.visible = false
	_controls_page.visible = false
	_controller_page.visible = false
	_skins_page.visible = true
	_stages_page.visible = false
	_refresh_skin_choices()


func _show_stages() -> void:
	_main_page.visible = false
	_controls_page.visible = false
	_controller_page.visible = false
	_skins_page.visible = false
	_stages_page.visible = true
	_refresh_stage_choices()


func _show_controller_settings() -> void:
	_main_page.visible = false
	_controls_page.visible = false
	_controller_page.visible = true
	_skins_page.visible = false
	_stages_page.visible = false
	_refresh_controller_settings()
	_controller_player_select.call_deferred("grab_focus")


func _refresh_controller_settings() -> void:
	if _controller_player_select == null:
		return
	_controller_player_select.select(GameSettings.single_controller_player())
	_deadzone_slider.set_value_no_signal(GameSettings.stick_deadzone())
	_sensitivity_slider.set_value_no_signal(GameSettings.stick_sensitivity())
	_update_stick_setting_labels()
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_controller_status.text = "Aucune manette detectee pour le moment. Tu peux la brancher sans relancer le jeu."
		_controller_status.add_theme_color_override("font_color", Color(1.0, 0.62, 0.36))
	elif pads.size() == 1:
		_controller_status.text = "%s detectee — elle controlera le joueur %d." % [
			Input.get_joy_name(pads[0]), GameSettings.single_controller_player() + 1,
		]
		_controller_status.add_theme_color_override("font_color", Color(0.48, 0.90, 0.62))
	else:
		_controller_status.text = "%d manettes detectees — la premiere controle J1 et la deuxieme J2." % pads.size()
		_controller_status.add_theme_color_override("font_color", Color(0.48, 0.90, 0.62))


func _controller_player_selected(index: int) -> void:
	GameSettings.set_single_controller_player(index)
	_refresh_controller_settings()


func _deadzone_changed(value: float) -> void:
	GameSettings.set_stick_deadzone(value)
	_update_stick_setting_labels()


func _sensitivity_changed(value: float) -> void:
	GameSettings.set_stick_sensitivity(value)
	_update_stick_setting_labels()


func _update_stick_setting_labels() -> void:
	if _deadzone_value:
		_deadzone_value.text = "%d %%" % roundi(GameSettings.stick_deadzone() * 100.0)
	if _sensitivity_value:
		_sensitivity_value.text = "%d %%" % roundi(GameSettings.stick_sensitivity() * 100.0)


func _reset_stick_settings() -> void:
	GameSettings.set_stick_deadzone(GameSettings.DEFAULT_STICK_DEADZONE)
	GameSettings.set_stick_sensitivity(GameSettings.DEFAULT_STICK_SENSITIVITY)
	_refresh_controller_settings()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controller_settings()


func _process(_delta: float) -> void:
	if _controller_page == null or not _controller_page.visible or _stick_preview == null:
		return
	var pads := Input.get_connected_joypads()
	var raw := Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_X) if not pads.is_empty() else 0.0
	var shaped := Fighter.shape_stick_axis(raw)
	_stick_preview.update_values(raw, shaped)
	if pads.is_empty():
		_stick_live_label.text = "Branche une manette et bouge le stick pour tester."
	else:
		_stick_live_label.text = "Stick horizontal : %+.2f    Mouvement obtenu : %+.2f" % [raw, shaped]


func _start_capture(player: int, action: String) -> void:
	_capture_focus_button = get_viewport().gui_get_focus_owner() as Button
	_capture_kind = "keyboard"
	_capture_player = player
	_capture_action = action
	_capture_status.text = "Appuie maintenant sur la touche pour : Joueur %d - %s\nEchap pour annuler." % [
		player + 1, GameSettings.ACTION_LABELS[action],
	]
	get_viewport().gui_release_focus()


func _start_pad_capture(player: int, action: String) -> void:
	_capture_focus_button = get_viewport().gui_get_focus_owner() as Button
	_capture_kind = "controller"
	_capture_player = player
	_capture_action = action
	_capture_status.text = "Appuie sur un bouton de manette pour : Joueur %d - %s\nLes gachettes LT et RT sont aussi acceptees. Echap pour annuler." % [
		player + 1, GameSettings.ACTION_LABELS[action],
	]
	get_viewport().gui_release_focus()


func _start_global_capture(kind: String, action: String) -> void:
	_capture_focus_button = get_viewport().gui_get_focus_owner() as Button
	_capture_kind = kind
	_capture_player = -2
	_capture_action = action
	var device_name := "touche du clavier" if kind == "keyboard" else "bouton de manette"
	var action_name := "recommencer la partie" if action == "reset" else "mettre en pause"
	_capture_status.text = "Appuie maintenant sur la %s pour %s.\nEchap pour annuler." % [
		device_name, action_name,
	]
	get_viewport().gui_release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _capture_kind != "":
		if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode == KEY_ESCAPE:
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return
		if _capture_kind == "keyboard":
			_capture_keyboard_event(event)
		else:
			_capture_controller_event(event)
		return
	if event is InputEventKey and event.pressed and not event.echo \
	and (_controls_page.visible or _controller_page.visible \
		or _skins_page.visible or _stages_page.visible) \
	and event.keycode == KEY_ESCAPE:
		if _controller_page.visible:
			_show_controls()
		else:
			_show_main()
		get_viewport().set_input_as_handled()


func _capture_keyboard_event(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code := int(event.keycode)
	if code == KEY_F10:
		_capture_status.text = "Cette touche est reservee au jeu. Choisis-en une autre, ou Echap pour annuler."
		get_viewport().set_input_as_handled()
		return
	if _capture_player >= 0:
		GameSettings.assign_key(_capture_player, _capture_action, code)
	elif _capture_action == "reset":
		GameSettings.assign_reset_key(code)
	else:
		GameSettings.assign_pause_key(code)
	_finish_capture("Touche clavier enregistree et sauvegardee.")
	get_viewport().set_input_as_handled()


func _capture_controller_event(event: InputEvent) -> void:
	var binding: Dictionary = {}
	if event is InputEventJoypadButton and event.pressed:
		binding = GameSettings.pad_binding_from_button(event.button_index)
	elif event is InputEventJoypadMotion \
	and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] \
	and event.axis_value >= 0.72:
		binding = GameSettings.pad_binding_from_trigger(event.axis)
	if binding.is_empty():
		return
	var accepted := false
	if _capture_player >= 0:
		accepted = GameSettings.assign_controller_binding(
			_capture_player, _capture_action, binding)
	elif _capture_action == "reset":
		accepted = GameSettings.assign_controller_reset(binding)
	else:
		accepted = GameSettings.assign_controller_pause(binding)
	if not accepted:
		_capture_status.text = "Ce bouton est deja reserve a une autre commande. Choisis-en un autre, ou Echap pour annuler."
		get_viewport().set_input_as_handled()
		return
	_finish_capture("Bouton de manette enregistre et sauvegarde.")
	get_viewport().set_input_as_handled()


func _cancel_capture() -> void:
	_capture_kind = ""
	_capture_player = -1
	_capture_action = ""
	_capture_status.text = "Modification annulee."
	_restore_capture_focus()


func _finish_capture(message: String) -> void:
	_capture_kind = ""
	_capture_player = -1
	_capture_action = ""
	_capture_status.text = message
	_refresh_key_buttons()
	_restore_capture_focus()


func _restore_capture_focus() -> void:
	if is_instance_valid(_capture_focus_button):
		_capture_focus_button.call_deferred("grab_focus")
	_capture_focus_button = null


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
			var pad_button: Button = _pad_buttons.get(_key_id(player, action))
			if pad_button:
				pad_button.text = GameSettings.controller_binding_name(player, action) \
					if action in GameSettings.PAD_ACTIONS else "Stick + croix"
	if _reset_button:
		_reset_button.text = GameSettings.reset_key_name()
	if _pause_key_button:
		_pause_key_button.text = GameSettings.pause_key_name()
	if _pad_reset_button:
		_pad_reset_button.text = GameSettings.controller_reset_name()
	if _pad_pause_button:
		_pad_pause_button.text = GameSettings.controller_pause_name()


func _key_id(player: int, action: String) -> String:
	return "%d:%s" % [player, action]
