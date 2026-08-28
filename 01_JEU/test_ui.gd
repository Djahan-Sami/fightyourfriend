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

	print("")
	print("RESULTAT INTERFACE : ", "OK" if _fails == 0 else "%d ECHEC(S)" % _fails)
	Arena._inst = null
	arena.free()
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("  ok   : ", label)
	else:
		print("  ECHEC: ", label)
		_fails += 1
