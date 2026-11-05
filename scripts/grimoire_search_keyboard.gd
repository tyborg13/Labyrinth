extends Node
## Steam's floating keyboard delivers OS keystrokes to the focused LineEdit.
## Its API has no text-result payload or length argument; the field owns both.
const Router = preload("res://scripts/input_router.gd")

var _field: LineEdit

static func attach(field: LineEdit) -> void:
	var keyboard := new()
	keyboard.name = "GrimoireSearchKeyboard"
	field.add_child(keyboard)

func _ready() -> void:
	_field = get_parent() as LineEdit
	_field.focus_entered.connect(request_keyboard)
	_field.gui_input.connect(_on_gui_input)
	_field.focus_exited.connect(_dismiss_keyboard)
	_field.visibility_changed.connect(_on_visibility_changed)

func request_keyboard() -> bool:
	var router: Node = get_node_or_null("/root/InputRouter")
	var service: Node = get_node_or_null("/root/SteamService")
	if router == null or not bool(router.call("using_controller")) or service == null:
		return false
	if not _field.has_focus() or not _field.is_visible_in_tree():
		return false
	# Steam expects pixels relative to the game window, including canvas stretch
	# and the player's UI scale, without the desktop window's screen position.
	var transform: Transform2D = _field.get_viewport().get_final_transform() * _field.get_global_transform_with_canvas()
	var rect: Rect2 = transform * Rect2(Vector2.ZERO, _field.size)
	return bool(service.call("show_floating_gamepad_text_input", Rect2i(rect.position.floor(), rect.end.ceil() - rect.position.floor())))

func _on_gui_input(event: InputEvent) -> void:
	if Router.is_controller_event(event) and event.is_action_pressed(Router.ACTION_ACCEPT):
		if request_keyboard(): _field.accept_event()

func _on_visibility_changed() -> void:
	if not _field.is_visible_in_tree(): _dismiss_keyboard()

func _dismiss_keyboard() -> void:
	var service: Node = get_node_or_null("/root/SteamService")
	if service != null: service.call("dismiss_floating_gamepad_text_input")

func _exit_tree() -> void:
	_dismiss_keyboard()
