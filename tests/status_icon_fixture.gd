extends RefCounted

## Proof-only inventory and geometry, shared by the exhaustive suite and sheet.
const Plates = preload("res://scripts/board_status_plates.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const ICON_KEYS: PackedStringArray = ["freeze", "petrify", "shock", "immobilize", "chilled", "bleed", "expose", "truesight", "frost_armor", "retaliate", "quicken", "next_attack", "anchored", "skate", "fireproof", "reflect", "flying", "charge", "burrow", "burst", "wind", "ranged", "block", "stoneskin"]
const KINDS: PackedStringArray = ["full", "compact", "plate"]
const FIXTURE_FRAME := Rect2(100, 100, 140, 24)
const FIXTURE_LABEL: String = "3"
const CONTROL_WORDS: Dictionary = {"freeze": "Frozen", "petrify": "Petrified", "shock": "Shocked", "immobilize": "Immobilized", "chilled": "Chilled"}
const VULNERABLE_ICONS: PackedStringArray = ["chilled", "bleed", "expose"]
const TRAIT_ICONS: PackedStringArray = ["reflect", "flying", "charge", "burrow", "burst", "wind"]

class Recorder extends RefCounted:
	var textures: Array[Dictionary]
	func draw_style_box(_style: StyleBox, _rect: Rect2) -> void: pass
	func draw_line(_a: Vector2, _b: Vector2, _color: Color, _width: float, _aa: bool) -> void: pass
	func draw_texture_rect_region(texture: Texture2D, rect: Rect2, source: Rect2, color: Color) -> void:
		textures.append({"texture": texture, "rect": rect, "source": source, "color": color})
	func draw_string_outline(_font: Font, _pos: Vector2, _text: String, _align: int, _width: float, _size: int, _outline: int, _color: Color) -> void: pass
	func draw_string(_font: Font, _pos: Vector2, _text: String, _align: int, _width: float, _size: int, _color: Color) -> void: pass
	func _register_tooltip(_rect: Rect2, _tooltip: String) -> void: pass

static func entry(icon: String, kind: String) -> Dictionary:
	if kind == "plate":
		var defense: Dictionary = {"stoneskin" if icon == "stoneskin" else "block": int(FIXTURE_LABEL)}
		var result: Dictionary = Plates.defense_entries(defense, FIXTURE_FRAME)[0].duplicate()
		result["icon"] = icon
		result["tooltip"] = Icons.tooltip(icon)
		return result
	var badges: Array[Dictionary]
	var kind_class: String = "vulnerable" if VULNERABLE_ICONS.has(icon) else "control" if CONTROL_WORDS.has(icon) else "trait" if TRAIT_ICONS.has(icon) else "buff"
	badges.append({"icon": icon, "status_class": kind_class, "status_word": str(CONTROL_WORDS.get(icon, "")), "count": int(FIXTURE_LABEL)})
	var ordered: Array[Dictionary] = Plates.ordered_badges(badges)
	if kind == "compact": ordered[0]["label"] = ""
	return Plates.status_entries(ordered, FIXTURE_FRAME, true)[0]

static func visible_from_draw(draw: Dictionary, bounds: Rect2) -> Rect2:
	var rect: Rect2 = draw["rect"]
	var source: Rect2 = draw["source"]
	var scale: Vector2 = rect.size / source.size
	return Rect2(rect.position + (bounds.position - source.position) * scale, bounds.size * scale)

# Exact pre-sb-03 icon placement. Only the proof proxy calls this; production
# plate/pill drawing still supplies the frame, text and colors for both sheets.
static func legacy_rect(value: Dictionary, source: Rect2) -> Rect2:
	var plate: bool = bool(value.get("defense_plate", false))
	var side: float = 20.0 if plate else 18.0
	var rect: Rect2 = value["rect"]
	var slot := Rect2(rect.position + Vector2(4.0 if plate else 3.0, 2.0), Vector2.ONE * side)
	var size: Vector2 = source.size * (side / maxf(source.size.x, source.size.y))
	return Rect2(slot.get_center() - size * 0.5, size)
