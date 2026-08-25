extends HBoxContainer
class_name InputPrompt

const InputGlyphScript = preload("res://scripts/input_glyph.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

var action_name: StringName = InputRouterScript.ACTION_ACCEPT
var label_text: String = "Select"
var _glyph
var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_glyph = InputGlyphScript.new()
	add_child(_glyph)
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(_label, UiTypography.ROLE_BODY)
	_label.add_theme_color_override("font_color", Color("f3e5c5"))
	_label.add_theme_color_override("font_outline_color", Color("100b0c"))
	_label.add_theme_constant_override("outline_size", 2)
	add_child(_label)
	# Re-resolve after the label enters the target viewport. Handheld prompts are
	# commonly constructed off-tree, where their physical output size is unknown.
	UiTypography.set_label_size(_label, UiTypography.SIZE_BODY)
	_connect_router()
	_refresh()

func configure(next_action_name: StringName, next_label_text: String) -> void:
	action_name = next_action_name
	label_text = next_label_text
	if is_node_ready():
		_refresh()

func _connect_router() -> void:
	var router: Node = get_node_or_null("/root/InputRouter")
	if router == null:
		return
	if router.has_signal("controller_family_changed") and not router.controller_family_changed.is_connected(_on_controller_family_changed):
		router.controller_family_changed.connect(_on_controller_family_changed)

func _on_controller_family_changed(_family: String) -> void:
	_refresh()

func _refresh() -> void:
	if _glyph == null or _label == null:
		return
	var family: String = InputRouterScript.FAMILY_XBOX
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null and router.has_method("controller_family"):
		family = str(router.call("controller_family"))
	_glyph.configure(action_name, family)
	_label.text = label_text
