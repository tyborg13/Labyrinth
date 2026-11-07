extends Node

## Owns device-specific copy without rewriting authored source data. A binding
## lives under its label, so router connections retire with the visible surface.
const Router = preload("res://scripts/input_router.gd")
const Prompt = preload("res://scripts/input_prompt.gd")

# The existing glyph system has Deck and Xbox families only. Keep its fallback
# until the design owner supplies the PlayStation family in that shared system.
const TODO_DESIGN_PLAYSTATION_GLYPHS: String = ""
const FIRST_CARD_PREVIEW: Dictionary = {
	"pointer_text": "For this first card, click to preview it.",
	"controller_text": "For this first card, select to preview it.",
}
const GRIMOIRE_PARAGRAPHS: Array[Dictionary] = Array([
	{
		"pointer_text": "Hover relic badges in the top HUD for their current text.",
		"controller_text": "Focus relic badges in the top HUD for their current text.",
	},
	{
		"pointer_text": "Each enemy can be delayed by at most 6 per player turn. Hover a Stagger target to preview its new place in the turn order.",
		"controller_text": "Each enemy can be delayed by at most 6 per player turn. Focus a Stagger target to preview its new place in the turn order.",
	},
], TYPE_DICTIONARY, "", null)

var _label: Control
var _property: StringName = &"text"
var _wording: Dictionary = {}
var _prompt

static func bind_label(label: Control, wording: Dictionary) -> void:
	_bind_property(label, wording, &"text")

static func bind_tooltip(control: Control, wording: Dictionary) -> void:
	_bind_property(control, wording, &"tooltip_text")

static func _bind_property(label: Control, wording: Dictionary, property: StringName) -> void:
	var binding: Node = label.get_node_or_null("InputWording")
	if binding == null:
		binding = load("res://scripts/input_wording.gd").new()
		binding.name = "InputWording"
		binding._label = label
		binding._property = property
		label.add_child(binding)
	binding._property = property
	binding.set_wording(wording)

static func bind_tooltip_panel(source: Control, panel: Control) -> Control:
	var binding: Node = source.get_node_or_null("InputWording")
	if panel == null or binding == null or binding._property != &"tooltip_text": return panel
	# UiTooltipPanel separates the first line (title) from the plain body. Bind
	# that existing body label so an already open tooltip follows input changes
	# without replacing its surface, typography or current position.
	var body_wording: Dictionary = {}
	for key: String in ["pointer_text", "controller_text"]:
		var lines: PackedStringArray = str(binding._wording.get(key, "")).split("\n", false)
		var body: PackedStringArray = PackedStringArray()
		for index: int in range(1, lines.size()):
			var line: String = lines[index].strip_edges()
			if not line.is_empty(): body.append(line)
		body_wording[key] = "\n".join(body)
	for label: Node in panel.find_children("*", "Label", true, false):
		if label.text in body_wording.values():
			bind_label(label, body_wording)
	return panel

static func bind_dialogue(label: Label) -> void:
	bind_label(label, {})
	var binding: Node = label.get_node("InputWording")
	binding._prompt = Prompt.new()
	binding._prompt.name = "DialogueInputPrompt"
	binding._prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.get_parent().add_child(binding._prompt)
	# Reuse the hint's current eyebrow font, size, ink and outline, while the
	# glyph itself remains the shared InputPrompt's active-family glyph.
	var prompt_label: Label = binding._prompt._label
	prompt_label.add_theme_font_override("font", label.get_theme_font("font"))
	prompt_label.add_theme_font_size_override("font_size", label.get_theme_font_size("font_size"))
	for color_name: String in ["font_color", "font_outline_color"]:
		prompt_label.add_theme_color_override(color_name, label.get_theme_color(color_name))
	prompt_label.add_theme_constant_override("outline_size", label.get_theme_constant("outline_size"))
	# The eyebrow style renders in caps; keep the controller verb in that casing.
	prompt_label.uppercase = label.uppercase
	binding._refresh()

static func grimoire_body(entry: Dictionary, controller: bool) -> String:
	var paragraphs: Array[String]
	for paragraph_var: Variant in entry.get("body", []):
		var paragraph: String = str(paragraph_var).strip_edges()
		if paragraph.is_empty(): continue
		for wording: Dictionary in GRIMOIRE_PARAGRAPHS:
			if paragraph == wording["pointer_text"]:
				paragraph = str(wording["controller_text"] if controller else wording["pointer_text"])
				break
		paragraphs.append(paragraph)
	return "\n\n".join(paragraphs)

func _ready() -> void:
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null:
		router.modality_changed.connect(_on_modality_changed)
	_refresh()

func set_wording(wording: Dictionary) -> void:
	_wording = wording.duplicate()
	_refresh()

func _on_modality_changed(_modality: String) -> void:
	_refresh()

func _refresh() -> void:
	if _label == null: return
	if not is_inside_tree():
		_label.set(_property, str(_wording.get("pointer_text", "")))
		return
	var router: Node = get_node_or_null("/root/InputRouter")
	var controller: bool = router != null and router.using_controller()
	var pointer_text: String = str(_wording.get("pointer_text", ""))
	var controller_text: String = str(_wording.get("controller_text", pointer_text))
	if _prompt != null:
		_label.set("text", pointer_text)
		# Empty hints still own the original expanding spacer beside choices.
		_label.visible = not controller or controller_text.is_empty()
		_prompt.visible = controller and not controller_text.is_empty()
		_prompt.configure(Router.ACTION_ACCEPT, controller_text)
	else:
		_label.set(_property, controller_text if controller else pointer_text)
