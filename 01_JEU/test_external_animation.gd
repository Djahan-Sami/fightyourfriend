extends Node

# Verification automatique du trajet Blender -> GLB -> jeu.

var _fails := 0


func _ready() -> void:
	AttackLibrary.reload()
	var info := AttackLibrary.clip_info("jab")
	_check("le manifeste retrouve jab.glb", not info.is_empty())
	if info.is_empty():
		_finish()
		return

	var clip := ExternalMotionClip.new()
	add_child(clip)
	_check("le squelette et l'animation GLB sont lisibles", clip.load_clip(info))
	if not clip.valid:
		_finish()
		return

	var guard := clip.sample(0.0)
	var impact := clip.sample(0.4)
	_check("la pose de garde contient les quatre membres",
		guard.has("arm_l") and guard.has("arm_r") and
		guard.has("leg_l") and guard.has("leg_r"))
	if guard.has("arm_l") and impact.has("arm_l"):
		var hand_guard: Vector3 = guard["arm_l"][1]
		var hand_impact: Vector3 = impact["arm_l"][1]
		var motion := hand_guard.distance_to(hand_impact)
		print("Mouvement du bras pendant le jab : %.3f" % motion)
		_check("le jab produit un mouvement nettement visible", motion > 0.12)
		_check("le poing part vers l'avant du combattant", hand_impact.x > hand_guard.x + 0.08)
	_check("la duree exportee est exploitable", clip.length > 0.12)
	_finish()


func _check(label: String, condition: bool) -> void:
	if condition:
		print("  ok   : ", label)
	else:
		print("  ECHEC: ", label)
		_fails += 1


func _finish() -> void:
	print("RESULTAT EXTERNE : ", "OK" if _fails == 0 else "%d ECHEC(S)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
