extends CanvasLayer
class_name AttackWorkshop

const FPS := 60.0
const MOVE_LABELS := {
	"jab": "Jab", "hook": "Crochet tete", "body_hook": "Crochet au corps",
	"uppercut": "Uppercut", "spinning_backfist": "Poing retourne",
	"middle_kick": "Middle kick", "front_kick": "Chasse", "spinning_kick": "Pied retourne",
	"high_kick": "High kick", "sweep": "Balayage",
	"air_punch": "Air : poing neutre", "air_cross": "Air : poing avant",
	"air_backfist": "Air : poing arriere", "air_upper": "Air : poing haut",
	"air_hammer": "Air : poing bas", "air_kick": "Air : pied neutre",
	"air_side_kick": "Air : pied avant", "air_roundhouse": "Air : pied arriere",
	"air_rising_kick": "Air : pied haut", "dive_kick": "Air : pied bas",
}

var arena: Arena
var root: Control
var move_select: OptionButton
var context_select: OptionButton
var button_select: OptionButton
var direction_select: OptionButton
var animation_select: OptionButton
var support_select: OptionButton
var reverse_depth: CheckButton
var file_label: Label
var status_label: Label
var fields: Dictionary = {}
var file_dialog: FileDialog
var _moves: Array[String] = []
var _pending_animation_file := ""

# Editeur visuel de hitbox
var visual_root: Control
var hitbox_canvas: HitboxEditorCanvas
var visual_move_select: OptionButton
var visual_shape_select: OptionButton
var visual_box_x_spin: SpinBox
var visual_box_y_spin: SpinBox
var visual_width_spin: SpinBox
var visual_height_spin: SpinBox
var visual_rotation_spin: SpinBox
var visual_values: Label
var visual_status: Label
var preview_button: Button
var hitbox_visibility: CheckButton
var settings_tabs: TabContainer
var combat_fields: Dictionary = {}
var hurtbox_context_select: OptionButton
var hurtbox_fields: Dictionary = {}
var _updating_hurtbox_fields := false
var _preview_attacker: Fighter
var _preview_opponent: Fighter
var _preview_rigs: Array[Node3D] = []
var _hidden_rigs: Array[Node3D] = []
var _edit_box := Vector2.ZERO
var _edit_shape := "circle"
var _edit_size := Vector2(20.0, 20.0)
var _edit_rotation := 0.0
var _saved_box := Vector2.ZERO
var _saved_shape := "circle"
var _saved_size := Vector2(20.0, 20.0)
var _saved_rotation := 0.0
var _updating_size_controls := false
var _updating_combat_fields := false
var _dragging_hitbox := false
var _preview_playing := false
var _preview_progress := 0.0
var _saved_camera_position := Vector3.ZERO
var _saved_camera_v_offset := 0.0
var _camera_was_saved := false
var return_to_menu_on_close := false


func setup(owner_arena: Arena) -> void:
	arena = owner_arena
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_workshop()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_open():
			if visual_root != null and visual_root.visible:
				_hide_hitbox_editor()
			else:
				hide_workshop()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := MenuBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var veil := ColorRect.new()
	veil.color = Color(0.04, 0.07, 0.16, 0.28)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1080, 640)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.105, 0.15, 0.27, 0.97)
	panel_style.border_color = Color(0.43, 0.73, 1.0, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 7)
	margin.add_child(main)

	var title := Label.new()
	title.text = "ATELIER DES COUPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.28))
	main.add_child(title)

	var help := Label.new()
	help.text = "Choisis une attaque, associe sa commande, puis ajuste son animation et ses reglages."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92))
	main.add_child(help)

	var move_card := _card_box(main, "ATTAQUE SELECTIONNEE", Color(0.48, 0.76, 1.0))
	move_select = _option_row(move_card, "Coup a modifier")
	for move_name in Fighter.MOVES.keys():
		_moves.append(str(move_name))
	_moves.sort_custom(func(a: String, b: String): return str(MOVE_LABELS.get(a, a)) < str(MOVE_LABELS.get(b, b)))
	for move_name in _moves:
		move_select.add_item(str(MOVE_LABELS.get(move_name, move_name)))
	# Aucun mouvement n'est mis artificiellement en avant. Si un coup personnel
	# existe deja, l'atelier ouvre simplement le premier trouve.
	for index in _moves.size():
		if AttackLibrary.has_custom_move(_moves[index]):
			move_select.select(index)
			break
	move_select.item_selected.connect(func(_i): _load_selected())

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content)
	var left := _card_box(content, "COMMANDE ET ANIMATION", Color(0.47, 0.75, 1.0))
	left.custom_minimum_size.x = 505
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_separator(left, "COMMANDE DANS LE JEU")
	var command_grid := GridContainer.new()
	command_grid.columns = 2
	command_grid.add_theme_constant_override("h_separation", 12)
	command_grid.add_theme_constant_override("v_separation", 7)
	left.add_child(command_grid)
	context_select = _small_option(command_grid, "Situation", [["Au sol", "ground"], ["En l'air", "air"]])
	button_select = _small_option(command_grid, "Bouton", [["Poing", "punch"], ["Pied", "kick"]])
	direction_select = _small_option(command_grid, "Direction", [
		["Neutre", "neutral"], ["Avant", "forward"], ["Arriere", "back"], ["Haut", "up"], ["Bas", "down"]])

	_add_separator(left, "FICHIER D'ANIMATION")
	var animation_row := HBoxContainer.new()
	animation_row.add_theme_constant_override("separation", 10)
	left.add_child(animation_row)
	var import_button := _styled_button("CHOISIR UN FICHIER GLB", "secondary")
	import_button.pressed.connect(_choose_file)
	animation_row.add_child(import_button)
	file_label = Label.new()
	file_label.text = "Aucune animation importee"
	file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	animation_row.add_child(file_label)
	animation_select = OptionButton.new()
	animation_select.custom_minimum_size.x = 200
	_style_option(animation_select)
	left.add_child(animation_select)

	var anim_options := HBoxContainer.new()
	anim_options.add_theme_constant_override("separation", 8)
	left.add_child(anim_options)
	var support_label := Label.new()
	support_label.text = "Pied d'appui :"
	anim_options.add_child(support_label)
	support_select = OptionButton.new()
	for entry in [["Automatique", "auto"], ["Les deux", "both"], ["Avant", "front"],
			["Arriere", "back"], ["Rouge", "left"], ["Bleu", "right"], ["Aucun (attaque aerienne)", "none"]]:
		support_select.add_item(entry[0])
		support_select.set_item_metadata(support_select.item_count - 1, entry[1])
	_style_option(support_select)
	anim_options.add_child(support_select)
	reverse_depth = CheckButton.new()
	reverse_depth.text = "Inverser avant/arriere"
	reverse_depth.tooltip_text = "A utiliser seulement si le coup part dans le mauvais sens apres l'import."
	anim_options.add_child(reverse_depth)

	var right := _card_box(content, "REGLAGES DE COMBAT", Color(1.0, 0.63, 0.25))
	right.custom_minimum_size.x = 535
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var timing_note := Label.new()
	timing_note.text = "Durees exprimees en images a 60 FPS"
	timing_note.add_theme_color_override("font_color", Color(0.70, 0.80, 0.96))
	right.add_child(timing_note)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 9)
	right.add_child(grid)
	fields["startup"] = _spin(grid, "Preparation", 1, 90, 1, " images")
	fields["active"] = _spin(grid, "Impact actif", 1, 30, 1, " images")
	fields["recover"] = _spin(grid, "Retour en garde", 1, 120, 1, " images")
	fields["dmg"] = _spin(grid, "Degats", 1, 50, 0.5, "")
	fields["radius"] = _spin(grid, "Taille de la zone", 5, 80, 1, "")
	fields["hitstun"] = _spin(grid, "Etourdissement", 1, 90, 1, " images")
	fields["box_x"] = _spin(grid, "Impact avant", -100, 120, 1, "")
	fields["box_y"] = _spin(grid, "Impact hauteur", -130, 20, 1, "")
	fields["kb_x"] = _spin(grid, "Projection X", -900, 900, 10, "")
	fields["kb_y"] = _spin(grid, "Projection Y", -900, 900, 10, "")

	var visual_button := _styled_button("OUVRIR L'EDITEUR VISUEL DE HITBOX", "accent")
	visual_button.custom_minimum_size.y = 48
	visual_button.add_theme_font_size_override("font_size", 18)
	visual_button.pressed.connect(_show_hitbox_editor)
	main.add_child(visual_button)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	main.add_child(footer)
	var folder_button := _styled_button("OUVRIR LE DOSSIER", "secondary")
	folder_button.pressed.connect(_open_folder)
	footer.add_child(folder_button)
	var reset_button := _styled_button("RETABLIR CE COUP", "danger")
	reset_button.pressed.connect(_reset_selected)
	footer.add_child(reset_button)
	var footer_space := Control.new()
	footer_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_space)
	var close_button := _styled_button("FERMER", "secondary")
	close_button.pressed.connect(hide_workshop)
	footer.add_child(close_button)
	var save_button := _styled_button("ENREGISTRER", "success")
	save_button.pressed.connect(_save_selected)
	footer.add_child(save_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.y = 20
	status_label.add_theme_color_override("font_color", Color(0.58, 1.0, 0.72))
	main.add_child(status_label)

	file_dialog = FileDialog.new()
	file_dialog.title = "Choisir une animation GLB"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.glb ; Animation 3D GLB", "*.gltf ; Animation 3D GLTF"])
	file_dialog.use_native_dialog = true
	file_dialog.file_selected.connect(_import_file)
	add_child(file_dialog)
	_build_hitbox_ui()

	_load_selected()


func _build_hitbox_ui_legacy() -> void:
	visual_root = Control.new()
	visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual_root.visible = false
	add_child(visual_root)

	hitbox_canvas = HitboxEditorCanvas.new()
	hitbox_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hitbox_canvas.setup(self)
	visual_root.add_child(hitbox_canvas)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -430.0
	panel.offset_right = -20.0
	panel.offset_top = -335.0
	panel.offset_bottom = 335.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.16, 0.29, 0.97)
	style.border_color = Color(0.43, 0.74, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	visual_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "EDITEUR DE HITBOX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(1.0, 0.79, 0.27))
	column.add_child(title)

	var selection_card := _card_box(column, "COUP ET FORME", Color(0.49, 0.78, 1.0))
	visual_move_select = OptionButton.new()
	_style_option(visual_move_select)
	for move_name in _moves:
		visual_move_select.add_item(str(MOVE_LABELS.get(move_name, move_name)))
	visual_move_select.item_selected.connect(_visual_move_changed)
	selection_card.add_child(visual_move_select)

	var shape_row := HBoxContainer.new()
	shape_row.add_theme_constant_override("separation", 10)
	selection_card.add_child(shape_row)
	var shape_label := Label.new()
	shape_label.text = "Forme de la zone"
	shape_label.custom_minimum_size.x = 145
	shape_row.add_child(shape_label)
	visual_shape_select = OptionButton.new()
	visual_shape_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option(visual_shape_select)
	visual_shape_select.add_item("Cercle")
	visual_shape_select.set_item_metadata(0, "circle")
	visual_shape_select.add_item("Ellipse")
	visual_shape_select.set_item_metadata(1, "ellipse")
	visual_shape_select.item_selected.connect(_visual_shape_changed)
	shape_row.add_child(visual_shape_select)

	var help_card := _card_box(column, "COMMENT L'UTILISER", Color(0.74, 0.84, 1.0))
	var help := Label.new()
	help.text = "Glisse le rouge. Molette : taille. Maj + molette : hauteur.\nBleu : corps adverse."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0))
	help_card.add_child(help)

	var size_card := _card_box(column, "POSITION ET DIMENSIONS", Color(1.0, 0.66, 0.28))
	visual_values = Label.new()
	visual_values.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_values.add_theme_font_size_override("font_size", 15)
	visual_values.add_theme_color_override("font_color", Color(1.0, 0.84, 0.39))
	size_card.add_child(visual_values)

	var size_grid := GridContainer.new()
	size_grid.columns = 4
	size_grid.add_theme_constant_override("h_separation", 8)
	size_card.add_child(size_grid)
	var width_label := Label.new()
	width_label.text = "Largeur"
	size_grid.add_child(width_label)
	visual_width_spin = SpinBox.new()
	visual_width_spin.min_value = 10.0
	visual_width_spin.max_value = 200.0
	visual_width_spin.step = 2.0
	visual_width_spin.custom_minimum_size.x = 80
	_style_spin(visual_width_spin)
	visual_width_spin.value_changed.connect(_visual_width_changed)
	size_grid.add_child(visual_width_spin)
	var height_label := Label.new()
	height_label.text = "Hauteur"
	size_grid.add_child(height_label)
	visual_height_spin = SpinBox.new()
	visual_height_spin.min_value = 10.0
	visual_height_spin.max_value = 200.0
	visual_height_spin.step = 2.0
	visual_height_spin.custom_minimum_size.x = 80
	_style_spin(visual_height_spin)
	visual_height_spin.value_changed.connect(_visual_height_changed)
	size_grid.add_child(visual_height_spin)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 8)
	column.add_child(preview_row)
	preview_button = _styled_button("PLAY AU RALENTI", "accent")
	preview_button.custom_minimum_size.y = 36
	preview_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_button.pressed.connect(_toggle_hitbox_preview)
	preview_row.add_child(preview_button)
	var impact_button := _styled_button("POSE D'IMPACT", "secondary")
	impact_button.custom_minimum_size.y = 36
	impact_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impact_button.pressed.connect(_show_impact_pose)
	preview_row.add_child(impact_button)
	var undo_button := _styled_button("ANNULER LES MODIFICATIONS NON ENREGISTREES", "danger")
	undo_button.custom_minimum_size.y = 36
	undo_button.pressed.connect(_reset_hitbox_edit)
	column.add_child(undo_button)

	visual_status = Label.new()
	visual_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visual_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.68))
	column.add_child(visual_status)

	var save := _styled_button("ENREGISTRER CETTE HITBOX", "success")
	save.custom_minimum_size.y = 44
	save.add_theme_font_size_override("font_size", 17)
	save.pressed.connect(_save_visual_hitbox)
	column.add_child(save)
	var back := _styled_button("RETOUR AUX REGLAGES DU COUP", "secondary")
	back.custom_minimum_size.y = 36
	back.pressed.connect(_hide_hitbox_editor)
	column.add_child(back)


func _build_hitbox_ui() -> void:
	visual_root = Control.new()
	visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual_root.visible = false
	add_child(visual_root)

	hitbox_canvas = HitboxEditorCanvas.new()
	hitbox_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hitbox_canvas.setup(self)
	visual_root.add_child(hitbox_canvas)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470.0
	panel.offset_right = -18.0
	panel.offset_top = -342.0
	panel.offset_bottom = 342.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.105, 0.16, 0.29, 0.98)
	panel_style.border_color = Color(0.43, 0.74, 1.0, 0.96)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	visual_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "ATELIER DU COUP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(1.0, 0.79, 0.27))
	column.add_child(title)

	visual_move_select = OptionButton.new()
	_style_option(visual_move_select)
	for move_name in _moves:
		visual_move_select.add_item(str(MOVE_LABELS.get(move_name, move_name)))
	visual_move_select.item_selected.connect(_visual_move_changed)
	column.add_child(visual_move_select)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 8)
	column.add_child(preview_row)
	preview_button = _styled_button("PLAY AU RALENTI", "accent")
	preview_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_button.custom_minimum_size.y = 38
	preview_button.pressed.connect(_toggle_hitbox_preview)
	preview_row.add_child(preview_button)
	var impact_button := _styled_button("POSE D'IMPACT", "secondary")
	impact_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impact_button.custom_minimum_size.y = 38
	impact_button.pressed.connect(_show_impact_pose)
	preview_row.add_child(impact_button)
	hitbox_visibility = CheckButton.new()
	hitbox_visibility.text = "AFFICHER LES HITBOX"
	hitbox_visibility.button_pressed = true
	hitbox_visibility.toggled.connect(_hitbox_visibility_changed)
	column.add_child(hitbox_visibility)

	settings_tabs = TabContainer.new()
	settings_tabs.custom_minimum_size.y = 380
	settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_tabs.add_theme_font_size_override("font_size", 16)
	var tab_panel := StyleBoxFlat.new()
	tab_panel.bg_color = Color(0.12, 0.19, 0.34, 0.96)
	tab_panel.border_color = Color(0.34, 0.58, 0.92, 0.65)
	tab_panel.set_border_width_all(1)
	tab_panel.set_corner_radius_all(8)
	settings_tabs.add_theme_stylebox_override("panel", tab_panel)
	settings_tabs.tab_changed.connect(_settings_tab_changed)
	column.add_child(settings_tabs)

	var hitbox_tab := VBoxContainer.new()
	hitbox_tab.name = "HITBOX"
	hitbox_tab.add_theme_constant_override("separation", 6)
	settings_tabs.add_child(hitbox_tab)
	var hitbox_margin := MarginContainer.new()
	hitbox_margin.add_theme_constant_override("margin_left", 12)
	hitbox_margin.add_theme_constant_override("margin_right", 12)
	hitbox_margin.add_theme_constant_override("margin_top", 10)
	hitbox_margin.add_theme_constant_override("margin_bottom", 10)
	hitbox_tab.add_child(hitbox_margin)
	var hitbox_content := VBoxContainer.new()
	hitbox_content.add_theme_constant_override("separation", 6)
	hitbox_margin.add_child(hitbox_content)

	var shape_row := HBoxContainer.new()
	shape_row.add_theme_constant_override("separation", 10)
	hitbox_content.add_child(shape_row)
	var shape_label := Label.new()
	shape_label.text = "Forme"
	shape_label.custom_minimum_size.x = 110
	shape_row.add_child(shape_label)
	visual_shape_select = OptionButton.new()
	visual_shape_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option(visual_shape_select)
	visual_shape_select.add_item("Cercle")
	visual_shape_select.set_item_metadata(0, "circle")
	visual_shape_select.add_item("Ellipse")
	visual_shape_select.set_item_metadata(1, "ellipse")
	visual_shape_select.item_selected.connect(_visual_shape_changed)
	shape_row.add_child(visual_shape_select)

	var help := Label.new()
	help.text = "Glisse la zone rouge directement dans l'apercu.\nMolette : taille. Maj : hauteur. Ctrl : rotation."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	hitbox_content.add_child(help)
	visual_values = Label.new()
	visual_values.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_values.add_theme_color_override("font_color", Color(1.0, 0.83, 0.35))
	hitbox_content.add_child(visual_values)

	var position_grid := GridContainer.new()
	position_grid.columns = 4
	position_grid.add_theme_constant_override("h_separation", 8)
	hitbox_content.add_child(position_grid)
	var forward_label := Label.new()
	forward_label.text = "Avant"
	position_grid.add_child(forward_label)
	visual_box_x_spin = SpinBox.new()
	visual_box_x_spin.min_value = -500.0
	visual_box_x_spin.max_value = 500.0
	visual_box_x_spin.step = 2.0
	visual_box_x_spin.custom_minimum_size.x = 80
	_style_spin(visual_box_x_spin)
	visual_box_x_spin.custom_minimum_size.y = 30
	visual_box_x_spin.value_changed.connect(_visual_box_x_changed)
	position_grid.add_child(visual_box_x_spin)
	var vertical_label := Label.new()
	vertical_label.text = "Hauteur"
	position_grid.add_child(vertical_label)
	visual_box_y_spin = SpinBox.new()
	visual_box_y_spin.min_value = -500.0
	visual_box_y_spin.max_value = 300.0
	visual_box_y_spin.step = 2.0
	visual_box_y_spin.custom_minimum_size.x = 80
	_style_spin(visual_box_y_spin)
	visual_box_y_spin.custom_minimum_size.y = 30
	visual_box_y_spin.value_changed.connect(_visual_box_y_changed)
	position_grid.add_child(visual_box_y_spin)

	var size_grid := GridContainer.new()
	size_grid.columns = 4
	size_grid.add_theme_constant_override("h_separation", 8)
	hitbox_content.add_child(size_grid)
	var width_label := Label.new()
	width_label.text = "Largeur"
	size_grid.add_child(width_label)
	visual_width_spin = SpinBox.new()
	visual_width_spin.min_value = 10.0
	visual_width_spin.max_value = 200.0
	visual_width_spin.step = 2.0
	visual_width_spin.custom_minimum_size.x = 80
	_style_spin(visual_width_spin)
	visual_width_spin.custom_minimum_size.y = 30
	visual_width_spin.value_changed.connect(_visual_width_changed)
	size_grid.add_child(visual_width_spin)
	var height_label := Label.new()
	height_label.text = "Hauteur"
	size_grid.add_child(height_label)
	visual_height_spin = SpinBox.new()
	visual_height_spin.min_value = 10.0
	visual_height_spin.max_value = 200.0
	visual_height_spin.step = 2.0
	visual_height_spin.custom_minimum_size.x = 80
	_style_spin(visual_height_spin)
	visual_height_spin.custom_minimum_size.y = 30
	visual_height_spin.value_changed.connect(_visual_height_changed)
	size_grid.add_child(visual_height_spin)

	var rotation_row := HBoxContainer.new()
	rotation_row.add_theme_constant_override("separation", 8)
	hitbox_content.add_child(rotation_row)
	var rotation_label := Label.new()
	rotation_label.text = "Rotation de l'ellipse"
	rotation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotation_row.add_child(rotation_label)
	visual_rotation_spin = SpinBox.new()
	visual_rotation_spin.min_value = -180.0
	visual_rotation_spin.max_value = 180.0
	visual_rotation_spin.step = 5.0
	visual_rotation_spin.suffix = " deg"
	visual_rotation_spin.custom_minimum_size.x = 125
	_style_spin(visual_rotation_spin)
	visual_rotation_spin.custom_minimum_size.y = 30
	visual_rotation_spin.value_changed.connect(_visual_rotation_changed)
	rotation_row.add_child(visual_rotation_spin)
	var hitbox_spacer := Control.new()
	hitbox_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hitbox_content.add_child(hitbox_spacer)
	var reset_hitbox := _styled_button("ANNULER LES MODIFICATIONS", "danger")
	reset_hitbox.pressed.connect(_reset_hitbox_edit)
	hitbox_content.add_child(reset_hitbox)
	var save_hitbox := _styled_button("ENREGISTRER LA HITBOX", "success")
	save_hitbox.pressed.connect(_save_visual_hitbox)
	hitbox_content.add_child(save_hitbox)

	var received_tab := VBoxContainer.new()
	received_tab.name = "ZONES RECUES"
	received_tab.add_theme_constant_override("separation", 6)
	settings_tabs.add_child(received_tab)
	var received_scroll := ScrollContainer.new()
	received_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	received_tab.add_child(received_scroll)
	var received_margin := MarginContainer.new()
	received_margin.add_theme_constant_override("margin_left", 12)
	received_margin.add_theme_constant_override("margin_right", 12)
	received_margin.add_theme_constant_override("margin_top", 10)
	received_margin.add_theme_constant_override("margin_bottom", 10)
	received_scroll.add_child(received_margin)
	var received_content := VBoxContainer.new()
	received_content.add_theme_constant_override("separation", 7)
	received_margin.add_child(received_content)
	var received_note := Label.new()
	received_note.text = "Regle les zones qui peuvent etre touchees. Le squelette reste la base."
	received_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	received_note.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	received_content.add_child(received_note)
	hurtbox_context_select = OptionButton.new()
	_style_option(hurtbox_context_select)
	for item in [
		["Position vulnerable", "neutral"], ["Garde", "guard"],
		["Accroupi", "crouch"], ["Pendant ce coup", "move"]]:
		hurtbox_context_select.add_item(item[0])
		hurtbox_context_select.set_item_metadata(hurtbox_context_select.item_count - 1, item[1])
	hurtbox_context_select.item_selected.connect(_hurtbox_context_changed)
	received_content.add_child(hurtbox_context_select)
	var received_grid := GridContainer.new()
	received_grid.columns = 2
	received_grid.add_theme_constant_override("h_separation", 12)
	received_grid.add_theme_constant_override("v_separation", 3)
	received_content.add_child(received_grid)
	hurtbox_fields["head_radius"] = _spin(received_grid, "Tete : taille", 4, 32, 1, "")
	hurtbox_fields["head_x"] = _spin(received_grid, "Tete : avant / arriere", -40, 40, 1, "")
	hurtbox_fields["head_y"] = _spin(received_grid, "Tete : hauteur", -50, 50, 1, "")
	hurtbox_fields["torso_radius"] = _spin(received_grid, "Torse : largeur", 4, 28, 1, "")
	hurtbox_fields["torso_length"] = _spin(received_grid, "Torse : longueur", 35, 180, 5, " %")
	hurtbox_fields["torso_x"] = _spin(received_grid, "Torse : avant / arriere", -40, 40, 1, "")
	hurtbox_fields["torso_y"] = _spin(received_grid, "Torse : hauteur", -50, 50, 1, "")
	hurtbox_fields["arms_scale"] = _spin(received_grid, "Bras : epaisseur", 25, 200, 5, " %")
	hurtbox_fields["legs_scale"] = _spin(received_grid, "Jambes : epaisseur", 25, 200, 5, " %")
	for field in hurtbox_fields.values():
		field.custom_minimum_size.y = 27
		field.value_changed.connect(_hurtbox_field_changed)
	var received_spacer := Control.new()
	received_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	received_content.add_child(received_spacer)
	var reset_received := _styled_button("REVENIR AUX ZONES AUTOMATIQUES", "danger")
	reset_received.pressed.connect(_reset_hurtbox_profile)
	received_content.add_child(reset_received)
	var save_received := _styled_button("ENREGISTRER LES ZONES RECUES", "success")
	save_received.pressed.connect(_save_hurtbox_profile)
	received_content.add_child(save_received)

	var combat_tab := VBoxContainer.new()
	combat_tab.name = "AUTRES REGLAGES"
	combat_tab.add_theme_constant_override("separation", 8)
	settings_tabs.add_child(combat_tab)
	var combat_margin := MarginContainer.new()
	combat_margin.add_theme_constant_override("margin_left", 12)
	combat_margin.add_theme_constant_override("margin_right", 12)
	combat_margin.add_theme_constant_override("margin_top", 8)
	combat_margin.add_theme_constant_override("margin_bottom", 8)
	combat_tab.add_child(combat_margin)
	var combat_content := VBoxContainer.new()
	combat_content.add_theme_constant_override("separation", 6)
	combat_margin.add_child(combat_content)
	var timing_note := Label.new()
	timing_note.text = "Timings en images (60 FPS). PLAY utilise les valeurs affichees."
	timing_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timing_note.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	combat_content.add_child(timing_note)
	var combat_grid := GridContainer.new()
	combat_grid.columns = 2
	combat_grid.add_theme_constant_override("h_separation", 12)
	combat_grid.add_theme_constant_override("v_separation", 4)
	combat_content.add_child(combat_grid)
	combat_fields["startup"] = _spin(combat_grid, "Preparation", 1, 90, 1, " images")
	combat_fields["active"] = _spin(combat_grid, "Impact actif", 1, 60, 1, " images")
	combat_fields["recover"] = _spin(combat_grid, "Retour en garde", 1, 120, 1, " images")
	combat_fields["dmg"] = _spin(combat_grid, "Degats", 1, 50, 0.5, "")
	combat_fields["hitstun"] = _spin(combat_grid, "Etourdissement", 1, 90, 1, " images")
	combat_fields["kb_x"] = _spin(combat_grid, "Projection X", -900, 900, 10, "")
	combat_fields["kb_y"] = _spin(combat_grid, "Projection Y", -900, 900, 10, "")
	for field in combat_fields.values():
		field.custom_minimum_size.y = 30
		field.value_changed.connect(_visual_combat_changed)
	var combat_spacer := Control.new()
	combat_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_content.add_child(combat_spacer)
	var save_combat := _styled_button("ENREGISTRER LES REGLAGES", "success")
	save_combat.pressed.connect(_save_visual_combat)
	combat_content.add_child(save_combat)

	visual_status = Label.new()
	visual_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_status.custom_minimum_size.y = 20
	visual_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visual_status.add_theme_color_override("font_color", Color(0.58, 1.0, 0.72))
	column.add_child(visual_status)
	var close := _styled_button("FERMER L'ATELIER", "secondary")
	close.custom_minimum_size.y = 36
	close.pressed.connect(hide_workshop)
	column.add_child(close)


func _card_box(parent: Container, title_text: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.20, 0.35, 0.94)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", accent)
	column.add_child(title)
	return column


func _styled_button(text: String, kind := "secondary") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var base := Color(0.19, 0.31, 0.53)
	var border := Color(0.43, 0.70, 1.0)
	match kind:
		"accent":
			base = Color(0.78, 0.43, 0.09)
			border = Color(1.0, 0.79, 0.28)
		"success":
			base = Color(0.12, 0.50, 0.34)
			border = Color(0.38, 0.95, 0.64)
		"danger":
			base = Color(0.52, 0.18, 0.22)
			border = Color(1.0, 0.43, 0.47)
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_color = border
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = base.lightened(0.18)
	hover.border_color = border.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _style_option(option: OptionButton) -> void:
	option.custom_minimum_size.y = 36
	option.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.16, 0.29)
	normal.border_color = Color(0.34, 0.56, 0.88, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	option.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.17, 0.27, 0.47)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", hover)


func _style_spin(spin: SpinBox) -> void:
	spin.custom_minimum_size.y = 34
	var line := spin.get_line_edit()
	line.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.16, 0.29)
	style.border_color = Color(0.30, 0.50, 0.82, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	line.add_theme_stylebox_override("normal", style)
	line.add_theme_stylebox_override("focus", style)


func _option_row(parent: Control, text: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option(option)
	row.add_child(option)
	return option


func _small_option(parent: GridContainer, text: String, entries: Array) -> OptionButton:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in entries:
		option.add_item(entry[0])
		option.set_item_metadata(option.item_count - 1, entry[1])
	_style_option(option)
	parent.add_child(option)
	return option


func _spin(parent: GridContainer, text: String, minimum: float, maximum: float,
		step: float, suffix: String) -> SpinBox:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.suffix = suffix
	spin.custom_minimum_size.x = 110
	_style_spin(spin)
	parent.add_child(spin)
	return spin


func _add_separator(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.50, 0.68, 1.0))
	parent.add_child(label)


func _add_button(parent: Container, text: String, callback: Callable,
		primary := false) -> void:
	var button := _styled_button(text, "accent" if primary else "secondary")
	button.pressed.connect(callback)
	parent.add_child(button)


func toggle() -> void:
	if is_open():
		hide_workshop()
	else:
		show_workshop()


func show_workshop() -> void:
	AttackLibrary.reload()
	_load_selected()
	root.visible = false
	visual_root.visible = true
	get_tree().paused = true
	visual_status.text = ""
	hitbox_visibility.button_pressed = true
	var move_name := _selected_move()
	visual_move_select.select(maxi(0, _moves.find(move_name)))
	if AttackLibrary.clip_info(move_name).is_empty():
		visual_status.text = "Ce coup n'a pas encore d'animation exportee."
	else:
		_spawn_hitbox_preview(move_name)


func hide_workshop() -> void:
	_cleanup_hitbox_preview()
	if root:
		root.visible = false
	if visual_root:
		visual_root.visible = false
	if is_inside_tree():
		get_tree().paused = false
		if return_to_menu_on_close:
			return_to_menu_on_close = false
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file("res://main_menu.tscn")


func is_open() -> bool:
	return (root != null and root.visible) or (visual_root != null and visual_root.visible)


func _process(delta: float) -> void:
	if visual_root == null or not visual_root.visible or not _preview_playing \
	or not is_instance_valid(_preview_attacker):
		return
	var total := maxf(float(_preview_attacker._move.get("startup", 0.1)) \
		+ float(_preview_attacker._move.get("active", 0.1)) \
		+ float(_preview_attacker._move.get("recover", 0.1)), 0.01)
	_preview_progress += delta * 0.25 / total
	if _preview_progress > 1.0:
		_preview_progress = 0.0
	_set_preview_progress(_preview_progress)


func _show_hitbox_editor() -> void:
	var move_name := _selected_move()
	if AttackLibrary.clip_info(move_name).is_empty():
		status_label.text = "Exporte d'abord l'animation de ce coup."
		return
	root.visible = false
	visual_root.visible = true
	visual_status.text = ""
	visual_move_select.select(maxi(0, _moves.find(move_name)))
	_spawn_hitbox_preview(move_name)


func _hide_hitbox_editor() -> void:
	hide_workshop()


func _visual_move_changed(index: int) -> void:
	if index < 0 or index >= _moves.size():
		return
	move_select.select(index)
	_load_selected()
	var move_name := _moves[index]
	if AttackLibrary.clip_info(move_name).is_empty():
		visual_status.text = "Ce coup n'a pas encore ete exporte."
		_cleanup_hitbox_preview()
		return
	visual_status.text = ""
	_spawn_hitbox_preview(move_name)


func _spawn_hitbox_preview(move_name: String) -> void:
	_cleanup_hitbox_preview()
	for node in (arena._view.rigs if arena._view != null else []):
		if is_instance_valid(node):
			node.visible = false
			_hidden_rigs.append(node)

	_preview_attacker = Fighter.new()
	_preview_opponent = Fighter.new()
	_preview_attacker.setup(0, Vector2(500.0, Arena.GROUND_Y), Arena.C_P1, Arena.C_P1_D)
	_preview_opponent.setup(1, Vector2(610.0, Arena.GROUND_Y), Arena.C_P2, Arena.C_P2_D)
	arena.add_child(_preview_attacker)
	arena.add_child(_preview_opponent)
	_preview_attacker.process_mode = Node.PROCESS_MODE_DISABLED
	_preview_opponent.process_mode = Node.PROCESS_MODE_DISABLED
	_preview_attacker.opponent = _preview_opponent
	_preview_opponent.opponent = _preview_attacker
	_preview_attacker.facing = 1.0
	_preview_opponent.facing = -1.0
	_preview_attacker.frozen = true
	_preview_opponent.frozen = true

	if move_name in Fighter.AIR_MOVE_NAMES:
		_preview_attacker.global_position = Vector2(500.0, Arena.GROUND_Y - 125.0)
		_preview_opponent.global_position = Vector2(610.0, Arena.GROUND_Y - 65.0)
	else:
		_preview_attacker.global_position = Vector2(500.0, Arena.GROUND_Y)
		_preview_opponent.global_position = Vector2(610.0, Arena.GROUND_Y)

	# Le combat normal cadre les vrais combattants. Pendant que le jeu est en
	# pause, on place donc explicitement la camera sur les deux mannequins de
	# l'atelier, avec assez de hauteur pour les attaques aeriennes.
	if arena._view != null and arena._view.cam != null:
		_saved_camera_position = arena._view.cam.position
		_saved_camera_v_offset = arena._view.cam.v_offset
		_camera_was_saved = true
		var air_preview := move_name in Fighter.AIR_MOVE_NAMES
		arena._view.cam.position = Vector3(
			0.15,
			6.90 if air_preview else 2.65,
			13.2 if air_preview else 9.5
		)
		arena._view.cam.v_offset = 0.85 if air_preview else 0.0
	arena.workshop_preview_ui = true
	arena.queue_redraw()

	_make_preview_rig(_preview_attacker, 0)
	_make_preview_rig(_preview_opponent, 1)
	_configure_preview_move(move_name)


func _make_preview_rig(fighter: Fighter, side: int) -> void:
	if arena._view == null:
		fighter.draw_2d = true
		return
	var result: Node3D = null
	var path := arena.model_path(side)
	if path != "":
		result = FighterRig.load_model(path, fighter)
	if result == null:
		var legacy_path := arena.legacy_model_path(side)
		if legacy_path != "" and legacy_path != path:
			result = FighterRig.load_model(legacy_path, fighter)
	if result == null:
		var puppet := Fighter3D.new()
		puppet.setup(fighter)
		result = puppet
	arena._view.add_child(result)
	result.process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_rigs.append(result)


func _configure_preview_move(move_name: String) -> void:
	if not is_instance_valid(_preview_attacker):
		return
	var info := AttackLibrary.clip_info(move_name)
	var current := AttackLibrary.apply_to_move(move_name, Fighter.MOVES[move_name])
	_preview_attacker._move = current
	_preview_attacker.move_name = move_name
	_preview_attacker._external_clip_info = info
	_preview_attacker._attack_start_pose = _preview_attacker._copy_pose(Fighter.POSES["idle"])
	_preview_attacker._pose_target = str(current.get("pose", "idle"))
	_preview_attacker.state = Fighter.State.ATTACK
	_preview_attacker._hit_done = false
	_preview_attacker._active_just_started = false
	_preview_playing = false
	preview_button.text = "PLAY AU RALENTI"

	var total := float(current["startup"]) + float(current["active"]) + float(current["recover"])
	_preview_progress = float(current["startup"]) / maxf(total, 0.001)
	_set_preview_progress(_preview_progress)
	_preview_attacker._sync_hitbox_to_contact()
	var point: Vector2 = _preview_attacker.hitbox_shape.position
	if bool(current.get("hitbox_authored", false)):
		_edit_box = current["box"]
	else:
		_edit_box = Vector2(point.x * _preview_attacker.facing, point.y)
	_edit_shape = str(current.get("hitbox_shape", "circle"))
	_edit_rotation = wrapf(float(current.get("hitbox_rotation", 0.0)), -180.0, 180.0)
	var base_radius := float(current["radius"])
	_edit_size = Vector2(
		float(current.get("radius_x", base_radius)),
		float(current.get("radius_y", base_radius))
	)
	if _edit_shape != "ellipse":
		_edit_shape = "circle"
		_edit_size.y = _edit_size.x
		_edit_rotation = 0.0
	_saved_box = _edit_box
	_saved_shape = _edit_shape
	_saved_size = _edit_size
	_saved_rotation = _edit_rotation
	visual_shape_select.select(1 if _edit_shape == "ellipse" else 0)
	_load_visual_combat(current)
	_update_visual_values()
	_load_hurtbox_profile()


func _hurtbox_context() -> String:
	if hurtbox_context_select == null or hurtbox_context_select.item_count == 0:
		return "neutral"
	return str(hurtbox_context_select.get_selected_metadata())


func _hurtbox_preview_subject() -> Fighter:
	return _preview_attacker if _hurtbox_context() == "move" else _preview_opponent


func _default_hurtbox_profile() -> Dictionary:
	return {
		"head_radius": 14.0, "head_x": 0.0, "head_y": 0.0,
		"torso_radius": 12.0, "torso_length": 1.0,
		"torso_x": 0.0, "torso_y": 0.0,
		"arms_scale": 1.0, "legs_scale": 1.0,
	}


func _current_hurtbox_profile_from_fields() -> Dictionary:
	return {
		"head_radius": float(hurtbox_fields["head_radius"].value),
		"head_x": float(hurtbox_fields["head_x"].value),
		"head_y": float(hurtbox_fields["head_y"].value),
		"torso_radius": float(hurtbox_fields["torso_radius"].value),
		"torso_length": float(hurtbox_fields["torso_length"].value) / 100.0,
		"torso_x": float(hurtbox_fields["torso_x"].value),
		"torso_y": float(hurtbox_fields["torso_y"].value),
		"arms_scale": float(hurtbox_fields["arms_scale"].value) / 100.0,
		"legs_scale": float(hurtbox_fields["legs_scale"].value) / 100.0,
	}


func _load_hurtbox_profile() -> void:
	if hurtbox_fields.is_empty() or not is_instance_valid(_preview_attacker) \
	or not is_instance_valid(_preview_opponent):
		return
	var context := _hurtbox_context()
	var move_name := _preview_attacker.move_name
	var profile := _default_hurtbox_profile()
	profile.merge(AttackLibrary.hurtbox_profile(context, move_name), true)
	_updating_hurtbox_fields = true
	hurtbox_fields["head_radius"].value = float(profile["head_radius"])
	hurtbox_fields["head_x"].value = float(profile["head_x"])
	hurtbox_fields["head_y"].value = float(profile["head_y"])
	hurtbox_fields["torso_radius"].value = float(profile["torso_radius"])
	hurtbox_fields["torso_length"].value = float(profile["torso_length"]) * 100.0
	hurtbox_fields["torso_x"].value = float(profile["torso_x"])
	hurtbox_fields["torso_y"].value = float(profile["torso_y"])
	hurtbox_fields["arms_scale"].value = float(profile["arms_scale"]) * 100.0
	hurtbox_fields["legs_scale"].value = float(profile["legs_scale"]) * 100.0
	_updating_hurtbox_fields = false
	_apply_hurtbox_profile_preview()


func _apply_hurtbox_profile_preview() -> void:
	if hurtbox_fields.is_empty():
		return
	var subject := _hurtbox_preview_subject()
	if not is_instance_valid(subject):
		return
	if is_instance_valid(_preview_attacker):
		_preview_attacker.hurtbox_profile_override = {}
	if is_instance_valid(_preview_opponent):
		_preview_opponent.hurtbox_profile_override = {}
	var context := _hurtbox_context()
	if subject == _preview_opponent:
		match context:
			"guard":
				subject.state = Fighter.State.BLOCK
				subject._pose = subject._copy_pose(Fighter.POSES["block"])
			"crouch":
				subject.state = Fighter.State.CROUCH
				subject._pose = subject._copy_pose(Fighter.POSES["crouch"])
			_:
				subject.state = Fighter.State.IDLE
				subject._pose = subject._copy_pose(Fighter.POSES["idle"])
	subject.hurtbox_profile_override = _current_hurtbox_profile_from_fields()
	subject._sync_hurtboxes()
	if hitbox_canvas:
		hitbox_canvas.queue_redraw()


func _hurtbox_context_changed(_index: int) -> void:
	_load_hurtbox_profile()


func _hurtbox_field_changed(_value: float) -> void:
	if _updating_hurtbox_fields:
		return
	visual_status.text = ""
	_apply_hurtbox_profile_preview()


func _save_hurtbox_profile() -> void:
	if not is_instance_valid(_preview_attacker):
		return
	var context := _hurtbox_context()
	var profile := _current_hurtbox_profile_from_fields()
	if AttackLibrary.save_hurtbox_profile(context, profile, _preview_attacker.move_name):
		visual_status.text = "Zones recues enregistrees pour ce contexte."
	else:
		visual_status.text = "Impossible d'enregistrer les zones recues."


func _reset_hurtbox_profile() -> void:
	if not is_instance_valid(_preview_attacker):
		return
	AttackLibrary.reset_hurtbox_profile(_hurtbox_context(), _preview_attacker.move_name)
	_load_hurtbox_profile()
	visual_status.text = "Zones automatiques retablies pour ce contexte."


func _settings_tab_changed(_tab: int) -> void:
	if _is_received_tab():
		_apply_hurtbox_profile_preview()
	elif is_instance_valid(_preview_opponent):
		_preview_opponent.hurtbox_profile_override = {}
		_preview_opponent.state = Fighter.State.IDLE
		_preview_opponent._pose = _preview_opponent._copy_pose(Fighter.POSES["idle"])
		_preview_opponent._sync_hurtboxes()
		if is_instance_valid(_preview_attacker):
			_preview_attacker.hurtbox_profile_override = {}
	if hitbox_canvas:
		hitbox_canvas.queue_redraw()


func _is_received_tab() -> bool:
	return settings_tabs != null and settings_tabs.current_tab >= 0 \
		and settings_tabs.get_tab_control(settings_tabs.current_tab).name == "ZONES RECUES"


func _load_visual_combat(current: Dictionary) -> void:
	if combat_fields.is_empty():
		return
	_updating_combat_fields = true
	combat_fields["startup"].value = round(float(current["startup"]) * FPS)
	combat_fields["active"].value = round(float(current["active"]) * FPS)
	combat_fields["recover"].value = round(float(current["recover"]) * FPS)
	combat_fields["dmg"].value = float(current["dmg"])
	combat_fields["hitstun"].value = round(float(current["hitstun"]) * FPS)
	var kb: Vector2 = current["kb"]
	combat_fields["kb_x"].value = kb.x
	combat_fields["kb_y"].value = kb.y
	_updating_combat_fields = false


func _visual_combat_changed(_value: float) -> void:
	if _updating_combat_fields:
		return
	visual_status.text = ""
	_apply_visual_combat_to_preview()


func _apply_visual_combat_to_preview() -> void:
	if not is_instance_valid(_preview_attacker) or combat_fields.is_empty():
		return
	_preview_attacker._move["startup"] = float(combat_fields["startup"].value) / FPS
	_preview_attacker._move["active"] = float(combat_fields["active"].value) / FPS
	_preview_attacker._move["recover"] = float(combat_fields["recover"].value) / FPS
	_preview_attacker._move["dmg"] = float(combat_fields["dmg"].value)
	_preview_attacker._move["hitstun"] = float(combat_fields["hitstun"].value) / FPS
	_preview_attacker._move["kb"] = Vector2(
		float(combat_fields["kb_x"].value), float(combat_fields["kb_y"].value))


func _save_visual_combat() -> void:
	if not is_instance_valid(_preview_attacker):
		return
	var move_name := _preview_attacker.move_name
	var settings := AttackLibrary.move_override(move_name)
	settings["startup"] = float(combat_fields["startup"].value) / FPS
	settings["active"] = float(combat_fields["active"].value) / FPS
	settings["recover"] = float(combat_fields["recover"].value) / FPS
	settings["dmg"] = float(combat_fields["dmg"].value)
	settings["hitstun"] = float(combat_fields["hitstun"].value) / FPS
	settings["kb"] = [float(combat_fields["kb_x"].value),
		float(combat_fields["kb_y"].value)]
	if not AttackLibrary.save_move(move_name, settings):
		visual_status.text = "Impossible d'enregistrer les reglages."
		return
	_preview_attacker._move = AttackLibrary.apply_to_move(move_name, Fighter.MOVES[move_name])
	_load_selected()
	visual_status.text = "Reglages de combat enregistres. L'animation et la hitbox sont intactes."


func _set_preview_progress(progress: float) -> void:
	if not is_instance_valid(_preview_attacker) or _preview_attacker._move.is_empty():
		return
	var startup := float(_preview_attacker._move["startup"])
	var active := float(_preview_attacker._move["active"])
	var recover := float(_preview_attacker._move["recover"])
	var total := maxf(startup + active + recover, 0.001)
	var elapsed := clampf(progress, 0.0, 1.0) * total
	if elapsed < startup:
		_preview_attacker._phase = 0
		_preview_attacker._t = startup - elapsed
	elif elapsed < startup + active:
		_preview_attacker._phase = 1
		_preview_attacker._t = startup + active - elapsed
	else:
		_preview_attacker._phase = 2
		_preview_attacker._t = total - elapsed
	_preview_attacker._animate(0.0)
	_preview_attacker._sync_hurtboxes()
	_preview_opponent._sync_hurtboxes()


func _toggle_hitbox_preview() -> void:
	_apply_visual_combat_to_preview()
	_preview_playing = not _preview_playing
	if _preview_playing:
		_preview_progress = 0.0
		preview_button.text = "PAUSE"
	else:
		preview_button.text = "REPRENDRE"


func _show_impact_pose() -> void:
	if not is_instance_valid(_preview_attacker):
		return
	_apply_visual_combat_to_preview()
	_preview_playing = false
	preview_button.text = "PLAY AU RALENTI"
	var current := _preview_attacker._move
	var total := float(current["startup"]) + float(current["active"]) + float(current["recover"])
	_preview_progress = float(current["startup"]) / maxf(total, 0.001)
	_set_preview_progress(_preview_progress)


func _reset_hitbox_edit() -> void:
	_edit_box = _saved_box
	_edit_shape = _saved_shape
	_edit_size = _saved_size
	_edit_rotation = _saved_rotation
	visual_shape_select.select(1 if _edit_shape == "ellipse" else 0)
	visual_status.text = "Les valeurs enregistrees ont ete restaurees."
	_update_visual_values()


func _save_visual_hitbox() -> void:
	if not is_instance_valid(_preview_attacker):
		return
	var move_name := _preview_attacker.move_name
	var settings := AttackLibrary.move_override(move_name)
	settings["box"] = [_edit_box.x, _edit_box.y]
	settings["hitbox_shape"] = _edit_shape
	settings["radius_x"] = _edit_size.x
	settings["radius_y"] = _edit_size.y
	settings["hitbox_rotation"] = _edit_rotation if _edit_shape == "ellipse" else 0.0
	settings["radius"] = _edit_size.x if _edit_shape == "circle" else maxf(_edit_size.x, _edit_size.y)
	settings["hitbox_authored"] = true
	if not AttackLibrary.save_move(move_name, settings):
		visual_status.text = "Impossible d'enregistrer la hitbox."
		return
	_saved_box = _edit_box
	_saved_shape = _edit_shape
	_saved_size = _edit_size
	_saved_rotation = _edit_rotation
	_preview_attacker._move = AttackLibrary.apply_to_move(move_name, Fighter.MOVES[move_name])
	visual_status.text = "Hitbox de %s enregistree. Rien d'autre n'a change." \
		% MOVE_LABELS.get(move_name, move_name)
	_update_visual_values()


func _cleanup_hitbox_preview() -> void:
	_preview_playing = false
	_dragging_hitbox = false
	if arena != null:
		arena.workshop_preview_ui = false
		arena.queue_redraw()
	if _camera_was_saved and arena != null and arena._view != null \
	and arena._view.cam != null:
		arena._view.cam.position = _saved_camera_position
		arena._view.cam.v_offset = _saved_camera_v_offset
	_camera_was_saved = false
	for rig in _preview_rigs:
		if is_instance_valid(rig):
			rig.visible = false
			rig.queue_free()
	_preview_rigs.clear()
	for rig in _hidden_rigs:
		if is_instance_valid(rig):
			rig.visible = true
	_hidden_rigs.clear()
	if is_instance_valid(_preview_attacker):
		_preview_attacker.queue_free()
	if is_instance_valid(_preview_opponent):
		_preview_opponent.queue_free()
	_preview_attacker = null
	_preview_opponent = null


func _project_sim(point: Vector2) -> Vector2:
	if arena._view != null and arena._view.has_method("project"):
		return arena._view.project(point)
	return point


func _screen_to_sim(point: Vector2) -> Vector2:
	if arena._view != null and arena._view.has_method("unproject"):
		return arena._view.unproject(point)
	return point


func _screen_scale_at(point: Vector2) -> float:
	var a := _project_sim(point)
	var b := _project_sim(point + Vector2(20.0, 0.0))
	return clampf(a.distance_to(b) / 20.0, 0.2, 4.0)


func _hitbox_sim_position() -> Vector2:
	if not is_instance_valid(_preview_attacker):
		return Vector2.ZERO
	return _preview_attacker.global_position \
		+ Vector2(_edit_box.x * _preview_attacker.facing, _edit_box.y)


func _hitbox_visibility_changed(_visible: bool) -> void:
	if hitbox_canvas:
		hitbox_canvas.queue_redraw()


func draw_hitbox_overlay(canvas: Control) -> void:
	if hitbox_visibility != null and not hitbox_visibility.button_pressed:
		return
	if not is_instance_valid(_preview_attacker) or not is_instance_valid(_preview_opponent):
		return
	var received_preview := _is_received_tab()
	var hurt_subject := _hurtbox_preview_subject() if received_preview else _preview_opponent
	_draw_preview_hurtboxes(canvas, hurt_subject,
		Color(0.18, 1.0, 0.56) if received_preview else Color(0.25, 0.68, 1.0))
	var sim_center := _hitbox_sim_position()
	var center := _project_sim(sim_center)
	var active := _preview_attacker._phase == 1
	var fill := Color(1.0, 0.08, 0.05, 0.26 if active else 0.09)
	var edge := Color(1.0, 0.25, 0.18, 0.98 if active else 0.50)
	var polygon := _hitbox_screen_polygon(sim_center)
	canvas.draw_colored_polygon(polygon, fill)
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	canvas.draw_polyline(outline, edge, 3.0, true)
	canvas.draw_line(center - Vector2(8, 0), center + Vector2(8, 0), edge, 2.0, true)
	canvas.draw_line(center - Vector2(0, 8), center + Vector2(0, 8), edge, 2.0, true)


func _hitbox_screen_polygon(sim_center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var size := _edit_size
	if _edit_shape == "circle":
		size.y = size.x
	var rotation := 0.0
	if _edit_shape == "ellipse" and is_instance_valid(_preview_attacker):
		rotation = deg_to_rad(_edit_rotation) * _preview_attacker.facing
	for index in 64:
		var angle := TAU * float(index) / 64.0
		var local_point := Vector2(cos(angle) * size.x, sin(angle) * size.y).rotated(rotation)
		points.append(_project_sim(sim_center + local_point))
	return points


func _draw_preview_hurtboxes(canvas: Control, fighter: Fighter, color: Color) -> void:
	if not is_instance_valid(fighter):
		return
	fighter._sync_hurtboxes()
	var shapes: Array[CollisionShape2D] = [fighter.hurt_shape]
	for limb in fighter.hurt_limb_shapes:
		shapes.append(limb)
	for shape_node in shapes:
		_draw_hurt_capsule(canvas, fighter, shape_node, color)
	var head_node := fighter.hurt_head_shape
	var head_shape := head_node.shape as CircleShape2D
	if head_shape != null:
		var sim := fighter.global_position + head_node.position
		var screen := _project_sim(sim)
		var radius := head_shape.radius * _screen_scale_at(sim)
		canvas.draw_circle(screen, radius, Color(color.r, color.g, color.b, 0.18))
		canvas.draw_arc(screen, radius, 0.0, TAU, 40,
			Color(color.r, color.g, color.b, 0.82), 2.0, true)


func _draw_hurt_capsule(canvas: Control, fighter: Fighter,
		node: CollisionShape2D, color: Color) -> void:
	var capsule := node.shape as CapsuleShape2D
	if capsule == null:
		return
	var center := fighter.global_position + node.position
	var half_segment := maxf(0.0, capsule.height * 0.5 - capsule.radius)
	var direction := Vector2.UP.rotated(node.rotation)
	var sim_a := center - direction * half_segment
	var sim_b := center + direction * half_segment
	var a := _project_sim(sim_a)
	var b := _project_sim(sim_b)
	var radius := capsule.radius * _screen_scale_at(center)
	var fill := Color(color.r, color.g, color.b, 0.20)
	canvas.draw_line(a, b, fill, radius * 2.0, true)
	canvas.draw_circle(a, radius, fill)
	canvas.draw_circle(b, radius, fill)
	var edge := Color(color.r, color.g, color.b, 0.68)
	canvas.draw_arc(a, radius, 0.0, TAU, 32, edge, 1.5, true)
	canvas.draw_arc(b, radius, 0.0, TAU, 32, edge, 1.5, true)


func handle_hitbox_input(event: InputEvent) -> void:
	if hitbox_visibility != null and not hitbox_visibility.button_pressed:
		return
	if not is_instance_valid(_preview_attacker):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging_hitbox = Geometry2D.is_point_in_polygon(
					event.position, _hitbox_screen_polygon(_hitbox_sim_position()))
			else:
				_dragging_hitbox = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if event.ctrl_pressed and _edit_shape == "ellipse":
				_rotate_hitbox(5.0)
			else:
				_resize_hitbox(2.0, event.shift_pressed)
			_update_visual_values()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.ctrl_pressed and _edit_shape == "ellipse":
				_rotate_hitbox(-5.0)
			else:
				_resize_hitbox(-2.0, event.shift_pressed)
			_update_visual_values()
	elif event is InputEventMouseMotion and _dragging_hitbox:
		var sim := _screen_to_sim(event.position)
		var local := sim - _preview_attacker.global_position
		_edit_box = Vector2(local.x * _preview_attacker.facing, local.y)
		_edit_box.x = clampf(_edit_box.x, -500.0, 500.0)
		_edit_box.y = clampf(_edit_box.y, -500.0, 300.0)
		visual_status.text = ""
		_update_visual_values()
	get_viewport().set_input_as_handled()


func _update_visual_values() -> void:
	if visual_values == null:
		return
	visual_values.text = "Position avant : %.0f     Hauteur : %.0f" % [_edit_box.x, _edit_box.y]
	if _edit_shape == "ellipse":
		visual_values.text += "     Angle : %.0f deg" % _edit_rotation
	_updating_size_controls = true
	visual_box_x_spin.value = _edit_box.x
	visual_box_y_spin.value = _edit_box.y
	visual_width_spin.value = _edit_size.x * 2.0
	visual_height_spin.value = _edit_size.y * 2.0
	visual_rotation_spin.value = _edit_rotation
	_updating_size_controls = false
	visual_rotation_spin.editable = _edit_shape == "ellipse"
	visual_rotation_spin.modulate = Color.WHITE if _edit_shape == "ellipse" else Color(0.58, 0.62, 0.70)


func _visual_shape_changed(index: int) -> void:
	_edit_shape = str(visual_shape_select.get_item_metadata(index))
	if _edit_shape == "circle":
		_edit_size.y = _edit_size.x
		_edit_rotation = 0.0
	visual_status.text = ""
	_update_visual_values()


func _visual_width_changed(value: float) -> void:
	if _updating_size_controls:
		return
	_edit_size.x = clampf(value * 0.5, 5.0, 100.0)
	if _edit_shape == "circle":
		_edit_size.y = _edit_size.x
	_update_visual_values()


func _visual_box_x_changed(value: float) -> void:
	if _updating_size_controls:
		return
	_edit_box.x = clampf(value, -500.0, 500.0)
	visual_status.text = ""
	_update_visual_values()


func _visual_box_y_changed(value: float) -> void:
	if _updating_size_controls:
		return
	_edit_box.y = clampf(value, -500.0, 300.0)
	visual_status.text = ""
	_update_visual_values()


func _visual_height_changed(value: float) -> void:
	if _updating_size_controls:
		return
	_edit_size.y = clampf(value * 0.5, 5.0, 100.0)
	if _edit_shape == "circle":
		_edit_size.x = _edit_size.y
	_update_visual_values()


func _visual_rotation_changed(value: float) -> void:
	if _updating_size_controls or _edit_shape != "ellipse":
		return
	_edit_rotation = wrapf(value, -180.0, 180.0)
	visual_status.text = ""
	_update_visual_values()


func _resize_hitbox(amount: float, height_only: bool) -> void:
	if height_only and _edit_shape == "ellipse":
		_edit_size.y = clampf(_edit_size.y + amount, 5.0, 100.0)
	else:
		_edit_size.x = clampf(_edit_size.x + amount, 5.0, 100.0)
		if _edit_shape == "circle":
			_edit_size.y = _edit_size.x
		else:
			_edit_size.y = clampf(_edit_size.y + amount, 5.0, 100.0)


func _rotate_hitbox(amount: float) -> void:
	_edit_rotation = wrapf(_edit_rotation + amount, -180.0, 180.0)


func _selected_move() -> String:
	if move_select == null or _moves.is_empty():
		return ""
	return _moves[clampi(move_select.selected, 0, _moves.size() - 1)]


func _load_selected() -> void:
	if move_select == null or _moves.is_empty():
		return
	var move_name := _selected_move()
	var defaults: Dictionary = Fighter.MOVES[move_name]
	var custom := AttackLibrary.move_override(move_name)
	var current := AttackLibrary.apply_to_move(move_name, defaults)
	fields["startup"].value = round(float(current["startup"]) * FPS)
	fields["active"].value = round(float(current["active"]) * FPS)
	fields["recover"].value = round(float(current["recover"]) * FPS)
	fields["dmg"].value = float(current["dmg"])
	fields["radius"].value = float(current["radius"])
	fields["hitstun"].value = round(float(current["hitstun"]) * FPS)
	var box: Vector2 = current["box"]
	var kb: Vector2 = current["kb"]
	fields["box_x"].value = box.x
	fields["box_y"].value = box.y
	fields["kb_x"].value = kb.x
	fields["kb_y"].value = kb.y

	var slot := AttackLibrary.slot_for_move(move_name).split("/")
	if slot.size() == 3:
		_select_metadata(context_select, slot[0])
		_select_metadata(button_select, slot[1])
		_select_metadata(direction_select, slot[2])

	_pending_animation_file = str(custom.get("animation_file", ""))
	file_label.text = _pending_animation_file.get_file() if _pending_animation_file != "" \
		else "Aucune animation importee : cette commande reste inactive"
	_refresh_animation_names(str(custom.get("animation", move_name)))
	_select_metadata(support_select, str(custom.get("support", "auto")))
	reverse_depth.button_pressed = float(custom.get("source_forward", 1.0)) < 0.0
	status_label.text = ""


func _save_selected() -> void:
	var move_name := _selected_move()
	var defaults: Dictionary = Fighter.MOVES[move_name]
	# On part des donnees existantes afin qu'un reglage numerique ne supprime
	# jamais la courbe de deplacement, l'identite du rig ou une hitbox visuelle.
	var settings := AttackLibrary.move_override(move_name)
	settings["startup"] = float(fields["startup"].value) / FPS
	settings["active"] = float(fields["active"].value) / FPS
	settings["recover"] = float(fields["recover"].value) / FPS
	settings["dmg"] = float(fields["dmg"].value)
	settings["radius"] = float(fields["radius"].value)
	settings["hitstun"] = float(fields["hitstun"].value) / FPS
	settings["blockstun"] = float(defaults["blockstun"])
	settings["box"] = [float(fields["box_x"].value), float(fields["box_y"].value)]
	settings["kb"] = [float(fields["kb_x"].value), float(fields["kb_y"].value)]
	settings["support"] = str(support_select.get_selected_metadata())
	settings["source_forward"] = -1.0 if reverse_depth.button_pressed else 1.0
	if _pending_animation_file != "" and animation_select.item_count > 0:
		settings["animation_file"] = _pending_animation_file
		settings["animation"] = str(animation_select.get_item_text(animation_select.selected))
	AttackLibrary.save_move(move_name, settings)
	AttackLibrary.assign_slot(move_name, str(context_select.get_selected_metadata()),
		str(button_select.get_selected_metadata()), str(direction_select.get_selected_metadata()))
	status_label.text = "Coup enregistre. Fermez l'atelier pour le tester immediatement."


func _reset_selected() -> void:
	AttackLibrary.reset_move(_selected_move())
	_pending_animation_file = ""
	_load_selected()
	status_label.text = "Les reglages d'origine ont ete retablis."


func _choose_file() -> void:
	file_dialog.popup_centered_ratio(0.82)


func _import_file(path: String) -> void:
	var copied := AttackLibrary.import_clip(_selected_move(), path)
	if copied == "":
		status_label.text = "Le fichier n'a pas pu etre lu."
		return
	_pending_animation_file = copied
	file_label.text = path.get_file()
	_refresh_animation_names(_selected_move())
	status_label.text = "Animation importee. Choisissez son nom puis cliquez sur Enregistrer."


func _refresh_animation_names(preferred: String) -> void:
	animation_select.clear()
	if _pending_animation_file == "":
		animation_select.add_item("Aucune")
		animation_select.disabled = true
		return
	var full_path := ProjectSettings.globalize_path(_pending_animation_file) \
		if _pending_animation_file.begins_with("user://") else _pending_animation_file
	var names := AttackLibrary.list_animations(full_path)
	for name in names:
		animation_select.add_item(name)
	animation_select.disabled = names.is_empty()
	if names.is_empty():
		animation_select.add_item("Aucune animation trouvee")
		status_label.text = "Ce GLB contient un modele, mais aucune animation exploitable."
		return
	for i in animation_select.item_count:
		if animation_select.get_item_text(i) == preferred:
			animation_select.select(i)
			break


func _select_metadata(option: OptionButton, value: String) -> void:
	for i in option.item_count:
		if str(option.get_item_metadata(i)) == value:
			option.select(i)
			return


func _open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(AttackLibrary.DIR)
	OS.shell_open(ProjectSettings.globalize_path(AttackLibrary.DIR))
