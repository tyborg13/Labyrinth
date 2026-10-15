extends "res://scripts/combat_board_view.gd"

# Debug proof layout only; tokens use the production intent-row renderer/sizes.
const Suite = preload("res://tests/suites/fix_03_suite.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const ROW_ORIGIN := Vector2(520, 120)
const ROW_STEP: float = 88.0
const LABEL_X: float = 80.0
var drawn_icons: Array[Dictionary]
var _proof_case: String = ""

func _ready() -> void:
	for entry: Dictionary in Suite.token_cases():
		for token: Dictionary in entry["tokens"]:
			var key: String = str(token.get("icon", ""))
			if not key.is_empty():
				_keyword_icon_textures[key] = ActionIcons.icon_texture(key)
	queue_redraw()

func _draw() -> void:
	drawn_icons.clear()
	_tooltip_regions.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK_0)
	var cases: Array[Dictionary] = Suite.token_cases()
	for index: int in range(cases.size()):
		var entry: Dictionary = cases[index]
		_proof_case = entry["name"]
		var origin: Vector2 = ROW_ORIGIN + Vector2(0, ROW_STEP * index)
		draw_string(UiTypography.ui_font(), Vector2(LABEL_X, origin.y + INTENT_POPUP_ROW_FONT_SIZE), _proof_case, HORIZONTAL_ALIGNMENT_LEFT, -1, INTENT_POPUP_ROW_FONT_SIZE, Palette.TEXT)
		_draw_token_row(entry["tokens"], origin, INTENT_POPUP_ICON_SIZE, INTENT_POPUP_ROW_FONT_SIZE, Palette.TEXT, UiTypography.ui_font(), true)

func _draw_keyword_icon(icon_key: String, rect: Rect2, tooltip: String = "", tint: Color = Color.WHITE, embossed: bool = false) -> void:
	drawn_icons.append({"case": _proof_case, "icon": icon_key, "rect": rect, "loaded": _keyword_icon_textures.get(icon_key) != null})
	super._draw_keyword_icon(icon_key, rect, tooltip, tint, embossed)
