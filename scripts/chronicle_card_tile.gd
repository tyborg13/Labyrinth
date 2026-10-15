extends "res://scripts/ui_socket.gd"

# Chronicle's portrait socket keeps the existing square gear/relic material.
# UiSocket supplies the count pill and interaction styling; its round painted
# ring is hidden because this surface has the director's 48 x 64 silhouette.
const Elements = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const TILE_SIZE := Vector2(48, 64)
const TILE_GAP: int = 8
const MAX_ROWS: int = 2
const SOCKET_EDGE: float = 1.0
const ELEMENT_EDGE: float = 2.0
const BADGE_OVERLAP: float = 4.0
const BADGE_FONT_SIZE: int = 14
const TODO_DESIGN_MISSING_CARD_DEFINITION: String = "TODO_DESIGN_MISSING_CARD_DEFINITION"

var card_id: String = ""
var card_definition: Dictionary = {}
var count: int = 1
var remaining: Array = []
var tooltip_builder: Callable
var socket_ink: Color = Palette.INK_1
var socket_edge: Color = Palette.GOLD_DIM
var element_accent: Color = Elements.accent(Elements.NONE)
var _art := TextureRect.new()
var _edge := Control.new()
var _overflow := Label.new()

func _init() -> void:
	super._init()
	_art.name = "CardArt"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_edge.name = "ElementEdge"
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.draw.connect(_draw_element_edge)
	add_child(_edge)
	_overflow.name = "OverflowCount"
	_overflow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overflow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overflow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overflow.add_theme_font_override("font", Typography.text_font())
	_overflow.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	_overflow.add_theme_color_override("font_color", Palette.TEXT)
	_overflow.hide()
	add_child(_overflow)
	move_child(_badge, -1)
	mouse_default_cursor_shape = Control.CURSOR_HELP

func configure(id: String, copies: int, definition: Dictionary) -> void:
	card_id = id
	count = copies
	card_definition = definition.duplicate(true)
	if card_definition.is_empty():
		card_definition = {"name": id, "description": TODO_DESIGN_MISSING_CARD_DEFINITION}
	remaining.clear()
	_overflow.hide()
	element_accent = Elements.accent(GameData.card_element_from_def(card_definition))
	_art.texture = AssetLoader.load_texture(str(card_definition.get("art_path", "")))
	setup(null, str(card_definition.get("name", id)), "×%d" % count if count >= 2 else "")

func configure_overflow(entries: Array) -> void:
	card_id = ""
	remaining = entries.duplicate(true)
	_overflow.text = "+%d" % remaining.size()
	_overflow.show()
	setup(null, _overflow.text)

func _layout() -> void:
	super._layout()
	custom_minimum_size = TILE_SIZE
	_ring.hide()
	_icon.hide()
	_badge.add_theme_font_override("font", Typography.text_font())
	_badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	_badge.size = _badge.get_minimum_size()
	_badge.position = TILE_SIZE - _badge.size + Vector2.ONE * BADGE_OVERLAP
	if _art != null:
		_art.position = Vector2.ONE * (SOCKET_EDGE + ELEMENT_EDGE)
		_art.size = TILE_SIZE - _art.position * 2
	if _edge != null:
		_edge.size = TILE_SIZE
		_edge.queue_redraw()
	if _overflow != null:
		_overflow.size = TILE_SIZE

func _draw() -> void:
	var border: Color = Palette.GOLD if has_focus() or is_hovered() else socket_edge
	Surface.draw_plate(self, Rect2(Vector2.ZERO, size), socket_ink, socket_ink, 0, border)

func _draw_element_edge() -> void:
	if card_id.is_empty():
		return
	var rect := Rect2(Vector2.ONE * SOCKET_EDGE, TILE_SIZE - Vector2.ONE * SOCKET_EDGE * 2)
	_edge.draw_rect(Rect2(rect.position, Vector2(rect.size.x, ELEMENT_EDGE)), element_accent)
	_edge.draw_rect(Rect2(rect.position.x, rect.end.y - ELEMENT_EDGE, rect.size.x, ELEMENT_EDGE), element_accent)
	_edge.draw_rect(Rect2(rect.position, Vector2(ELEMENT_EDGE, rect.size.y)), element_accent)
	_edge.draw_rect(Rect2(rect.end.x - ELEMENT_EDGE, rect.position.y, ELEMENT_EDGE, rect.size.y), element_accent)

func _make_custom_tooltip(_for_text: String) -> Object:
	if not remaining.is_empty():
		var lines := PackedStringArray()
		for entry: Dictionary in remaining:
			lines.append("%s ×%d" % [entry["name"], entry["count"]])
		return Tooltip.make_lines("", lines)
	return tooltip_builder.call(card_id) if tooltip_builder.is_valid() else null

static func grouped_deck(deck: Array, definitions: Dictionary = {}) -> Array[Dictionary]:
	var groups: Array[Dictionary]
	var indices: Dictionary = {}
	for pair: Array in deck:
		var id: String = str(pair[0])
		if indices.has(id):
			groups[int(indices[id])]["count"] += int(pair[1])
		else:
			var definition: Dictionary = definitions.get(id, GameData.card_def(id))
			indices[id] = groups.size()
			groups.append({"id": id, "count": int(pair[1]), "name": str(definition.get("name", id)), "definition": definition})
	return groups

static func columns_for_width(width: float) -> int:
	return maxi(1, floori((width + TILE_GAP) / (TILE_SIZE.x + TILE_GAP)))

static func shown_count(distinct_count: int, columns: int) -> int:
	var capacity: int = columns * MAX_ROWS
	return distinct_count if distinct_count <= capacity else capacity - 1
