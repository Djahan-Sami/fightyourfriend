extends Node

var _fails := 0


func _ready() -> void:
	var arena: Arena = load("res://arena.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame

	_check("les animations du projet sont la source de travail",
		AttackLibrary.storage_dir() == "res://default_attacks")
	_check("le manifeste des animations est versionne",
		AttackLibrary.manifest_path() == "res://default_attacks/attack_manifest.json")
	var backup_path := AttackLibrary.create_backup()
	_check("une copie complete des animations peut etre creee",
		backup_path != "" and FileAccess.file_exists(
			backup_path.path_join("attack_manifest.json")))
	_check("l'affichage conserve le cadrage 16/9",
		str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep")
	_check("l'ancien ecran cache de l'atelier n'est plus construit",
		arena.workshop.root == arena.workshop.visual_root \
		and arena.workshop.file_dialog == null)

	arena._show_end_menu(2)
	_check("le menu de fin apparait apres le match", arena._end_overlay.visible)
	_check("le gagnant est indique", arena._end_title.text == "JOUEUR 2 GAGNE")
	arena._restart_match()
	_check("Revanche relance un match a zero",
		not arena._end_overlay.visible and arena.rounds == [0, 0] \
		and arena.phase == Arena.Phase.INTRO)
	_check("la zone morte elimine la derive du stick",
		Fighter.shape_stick_axis(0.12, 0.18, 1.0) == 0.0)
	_check("le stick conserve un deplacement analogique progressif",
		Fighter.shape_stick_axis(0.50, 0.18, 1.0) > 0.0 \
		and Fighter.shape_stick_axis(0.50, 0.18, 1.0) < 1.0 \
		and is_equal_approx(Fighter.shape_stick_axis(1.0, 0.18, 1.0), 1.0))
	_check("la sensibilite augmente la reponse sans changer la vitesse maximale",
		Fighter.shape_stick_axis(0.50, 0.18, 1.50) \
		> Fighter.shape_stick_axis(0.50, 0.18, 0.60) \
		and is_equal_approx(Fighter.shape_stick_axis(1.0, 0.18, 1.50), 1.0))
	var pad_event := GameSettings.pad_event(
		GameSettings.controller_binding(0, "punch"), 7)
	_check("les boutons de combat enregistres sont convertis pour la bonne manette",
		pad_event != null and pad_event.device == 7)
	_check("pause et recommencer ont des boutons de manette distincts",
		GameSettings.controller_pause_binding() != GameSettings.controller_reset_binding())
	var settings_saved := GameSettings.save()
	var settings_file := FileAccess.open(GameSettings.PATH, FileAccess.READ)
	var settings_data = JSON.parse_string(settings_file.get_as_text()) \
		if settings_file != null else {}
	if settings_file:
		settings_file.close()
	_check("le profil clavier et manette est sauvegarde",
		settings_saved and settings_data is Dictionary \
		and settings_data.has("controller_controls") \
		and settings_data.has("controller_reset") \
		and settings_data.has("controller_pause") \
		and settings_data.has("single_controller_player") \
		and settings_data.has("stick_deadzone") \
		and settings_data.has("stick_sensitivity"))

	Arena._inst = null
	arena.free()
	var menu := MainMenu.new()
	add_child(menu)
	await get_tree().process_frame
	menu._show_controls()
	await get_tree().process_frame
	_check("l'ecran des commandes affiche clavier et manette pour les deux joueurs",
		menu._key_buttons.size() == 16 and menu._pad_buttons.size() == 16)
	_check("le stick et la croix restent ensemble pour se deplacer",
		(menu._pad_buttons[menu._key_id(0, "left")] as Button).disabled \
		and not (menu._pad_buttons[menu._key_id(0, "punch")] as Button).disabled)
	_check("pause et recommencer sont configurables sur les deux appareils",
		menu._reset_button != null and menu._pause_key_button != null \
		and menu._pad_reset_button != null and menu._pad_pause_button != null)
	menu._show_controller_settings()
	await get_tree().process_frame
	_check("une manette unique peut etre affectee a J1 ou J2",
		menu._controller_page.visible \
		and menu._controller_player_select.item_count == 2 \
		and GameSettings.single_controller_player() in [0, 1])
	_check("la zone morte et la sensibilite ont leur reglage et leur apercu",
		menu._deadzone_slider != null and menu._sensitivity_slider != null \
		and menu._stick_preview != null)
	var controller_panel := menu._controller_page.get_child(0) as Control
	_check("l'ecran des reglages tient dans une fenetre 1280 x 720",
		controller_panel != null and controller_panel.size.x <= 1280.0 \
		and controller_panel.size.y <= 720.0)
	menu.free()

	print("")
	print("RESULTAT INTERFACE : ", "OK" if _fails == 0 else "%d ECHEC(S)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("  ok   : ", label)
	else:
		print("  ECHEC: ", label)
		_fails += 1
