extends Label

## pol-52: the PASS face's "P" key mark, built like the Details "I" hint
## (combat_hud_intents.gd IntentKey): UI font at 15, TEXT_3, 6 px after the
## word, keyboard/mouse only. PASS keeps its centred word, so the mark sits
## beside it rather than re-centring the pair. It takes the button art's tint,
## so it dims with the greyed-out button, and hides when the face shows a card
## cost instead of the word PASS.

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const GAP: float = 6.0

var word: Label
var art: CanvasItem

func _init() -> void:
	name = "PassKeyHint"
	text = "P"
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	add_theme_font_override("font", Typography.ui_font())
	Typography.set_label_size(self, 15)
	add_theme_color_override("font_color", Palette.TEXT_3)

func _ready() -> void:
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null:
		router.modality_changed.connect(_on_modality_changed)
	refresh()

func _on_modality_changed(_modality: String) -> void:
	refresh()

func refresh() -> void:
	if word == null or art == null: return
	var router: Node = get_node_or_null("/root/InputRouter") if is_inside_tree() else null
	visible = word.text == "PASS" and (router == null or str(router.call("modality")) == InputRouter.MODALITY_POINTER)
	modulate = art.modulate
	var word_width: float = word.get_theme_font("font").get_string_size(word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, word.get_theme_font_size("font_size")).x
	size = Vector2(get_minimum_size().x, word.size.y)
	position = Vector2(word.position.x + (word.size.x + word_width) * 0.5 + GAP, word.position.y)
