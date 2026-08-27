extends Control
class_name HitboxEditorCanvas

var workshop: AttackWorkshop


func setup(owner_workshop: AttackWorkshop) -> void:
	workshop = owner_workshop
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(workshop):
		workshop.draw_hitbox_overlay(self)


func _gui_input(event: InputEvent) -> void:
	if is_instance_valid(workshop):
		workshop.handle_hitbox_input(event)
