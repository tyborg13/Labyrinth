extends Node

var host: Node

func _input(event: InputEvent) -> void:
	if not is_instance_valid(host):
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index <= MOUSE_BUTTON_MIDDLE
	if clicked or event.is_action_pressed("ui_cancel"):
		host.call("_clear_controller_loadout_tooltip")
		set_process_input(false)
		get_viewport().set_input_as_handled()
