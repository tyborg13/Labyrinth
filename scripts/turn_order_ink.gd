extends RefCounted

# Painted initiative rail. Each actor sits on its own hand-painted brush stroke
# (variant and tilt fixed per actor so the column never looks stamped out), its
# sprite portrait is cut into a slanted, slightly ragged window, and its time is
# painted straight onto the stroke. The active actor gets the gold hero
# stroke; allies and enemies read as teal and crimson ink.

const AssetLoader = preload("res://scripts/asset_loader.gd")
const Palette = preload("res://scripts/ui_palette.gd")

const BRUSH_DIR: String = "res://assets/art/ui/turn_order_ink/"
const QUEUE_BRUSHES: Array[String] = ["brush_a.png", "brush_b.png", "brush_c.png", "brush_d.png"]
const HERO_BRUSH: String = "brush_hero.png"

# Muted, darker inks sit with the bronze, oxblood and near-black of the HUD
# while staying clearly visible behind each portrait.
const ACTIVE_INK := Color(0.70, 0.49, 0.22, 0.95)
const ALLY_INK := Color(0.13, 0.30, 0.32, 0.90)
const ENEMY_INK := Color(0.40, 0.10, 0.09, 0.90)
const PROJECTED_ALPHA: float = 0.72

# The stroke bleeds past the portrait: generously to the left where the time
# is painted, a little on the other sides so the frayed ends stay visible.
const BLEED_LEFT: float = 40.0
const BLEED_RIGHT: float = 10.0
const BLEED_Y: float = 12.0
const SKEW_RATIO: float = 0.14
const BAND_STRETCH: float = 1.25
const BAND_CENTER_RATIO: float = 0.60

static func brush_texture(active: bool, actor_key: String) -> Texture2D:
	var file: String = HERO_BRUSH if active else QUEUE_BRUSHES[_hash(actor_key) % QUEUE_BRUSHES.size()]
	return AssetLoader.load_texture(BRUSH_DIR + file)

static func ink_color(team: String, active: bool, projected: bool) -> Color:
	var ink: Color = ACTIVE_INK if active else (ALLY_INK if team == "player" else ENEMY_INK)
	if projected and not active:
		ink.a *= PROJECTED_ALPHA
	return ink

# The stroke keeps (roughly) its painted proportions as a band behind the lower
# portrait, so the head rises above the paint and bristles are never smeared.
static func brush_rect(slot_size: Vector2, texture: Texture2D) -> Rect2:
	var width: float = slot_size.x + BLEED_LEFT + BLEED_RIGHT
	var aspect: float = 3.0
	if texture != null and texture.get_height() > 0:
		aspect = float(texture.get_width()) / float(texture.get_height())
	var height: float = clampf(width / aspect * BAND_STRETCH, slot_size.y * 0.55, slot_size.y + BLEED_Y * 2.0)
	var center_y: float = slot_size.y * BAND_CENTER_RATIO
	return Rect2(Vector2(-BLEED_LEFT, center_y - height * 0.5), Vector2(width, height))

# A small, per-actor tilt and mirror keep neighbouring strokes from matching.
static func brush_tilt_degrees(actor_key: String, active: bool) -> float:
	if active:
		return -3.0
	return [-4.0, 2.5, -1.5, 3.5][(_hash(actor_key) >> 3) % 4]

static func brush_flipped(actor_key: String, active: bool) -> bool:
	return not active and ((_hash(actor_key) >> 5) % 2) == 1

static func _hash(text: String) -> int:
	return absi(hash(text))


# Slanted portrait window. With clip_children the drawn polygon is the mask:
# only the portrait inside it is visible, and the mask itself is never shown.
class PortraitMask:
	extends Control

	var skew: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 4.0 or size.y < 4.0:
			return
		draw_colored_polygon(window_points(size, skew), Color.WHITE)

	static func window_points(area: Vector2, skew_ratio: float) -> PackedVector2Array:
		# Slanted left and right edges with a few deterministic nicks so the cut
		# reads as painted rather than machined.
		var shift: float = area.x * skew_ratio
		var points := PackedVector2Array()
		var steps: int = 6
		for index: int in range(steps + 1):
			var t: float = float(index) / float(steps)
			var jitter: float = sin(t * 37.0 + 1.3) * 1.2
			points.append(Vector2(lerpf(shift, 0.0, t) + jitter, area.y * t))
		for index: int in range(steps, -1, -1):
			var t: float = float(index) / float(steps)
			var jitter: float = cos(t * 29.0 + 0.7) * 1.2
			points.append(Vector2(lerpf(area.x, area.x - shift, t) + jitter, area.y * t))
		return points


# A single painted highlight down the portrait's slanted leading edge.
class SlashEdge:
	extends Control

	var skew: float = 0.0
	var color: Color = Color(1.0, 1.0, 1.0, 0.5)
	var width: float = 2.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 4.0 or size.y < 4.0:
			return
		var shift: float = size.x * skew
		var top := Vector2(shift, 0.0)
		var bottom := Vector2(0.0, size.y)
		# Taper the stroke: full weight in the middle, fading at both ends.
		var segments: int = 10
		for index: int in range(segments):
			var a: float = float(index) / float(segments)
			var b: float = float(index + 1) / float(segments)
			var fade: float = sin(((a + b) * 0.5) * PI)
			draw_line(top.lerp(bottom, a), top.lerp(bottom, b), Color(color, color.a * fade), width * (0.5 + fade * 0.5), true)
