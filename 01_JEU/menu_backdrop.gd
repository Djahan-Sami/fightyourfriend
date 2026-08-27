extends Control
class_name MenuBackdrop


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Ciel bleu-violet lumineux.
	var bands := 32
	for index in bands:
		var amount := float(index) / float(bands - 1)
		var color := Color(0.08, 0.16, 0.38).lerp(Color(0.30, 0.36, 0.62), amount)
		draw_rect(Rect2(0.0, viewport_size.y * amount,
			viewport_size.x, viewport_size.y / float(bands) + 2.0), color)

	var halo_center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.38)
	for index in range(9, 0, -1):
		var radius := viewport_size.y * (0.10 + float(index) * 0.055)
		var alpha := 0.012 + float(10 - index) * 0.008
		draw_circle(halo_center, radius, Color(0.42, 0.76, 1.0, alpha))
	for radius in [170.0, 245.0, 330.0]:
		draw_arc(halo_center, radius, 0.0, TAU, 96,
			Color(0.62, 0.82, 1.0, 0.12), 2.0, true)

	# Sol d'arene : plus clair que le jeu, mais assez calme pour garder le texte lisible.
	var horizon := viewport_size.y * 0.73
	var floor_bands := 10
	for index in floor_bands:
		var amount := float(index) / float(floor_bands - 1)
		var floor_color := Color(0.25, 0.30, 0.51).lerp(Color(0.14, 0.18, 0.34), amount)
		draw_rect(Rect2(0.0, horizon + (viewport_size.y - horizon) * amount,
			viewport_size.x, (viewport_size.y - horizon) / float(floor_bands) + 2.0),
			floor_color)
	draw_line(Vector2(0.0, horizon), Vector2(viewport_size.x, horizon),
		Color(0.62, 0.80, 1.0, 0.42), 2.0, true)
	for index in 11:
		var bottom_x := viewport_size.x * float(index) / 10.0
		draw_line(halo_center + Vector2(0.0, horizon - halo_center.y),
			Vector2(bottom_x, viewport_size.y), Color(0.55, 0.68, 0.92, 0.10), 1.0, true)
