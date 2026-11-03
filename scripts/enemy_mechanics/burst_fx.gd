extends RefCounted

const Fx = preload("res://scripts/elemental_spell_fx.gd")
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const GLOW_RISE_SECONDS: float = 0.06
const GLOW_SECONDS: float = 0.30
const RIBBON_SECONDS: float = 0.28
const GLOW_PEAK_ALPHA: float = 0.55
# Director feedback 1: approved ribbon, smoke and glow values.
const RIBBON_WIDTH_RATIO: float = 0.07
const RIBBON_ALPHA: float = 0.85
const SMOKE_SIZE_RATIO: float = 0.22
const SMOKE_ALPHA: float = 0.55
const SMOKE_SECONDS: float = 0.30
const GLOW_CORNER_ALPHA: float = 0.12
static var _ribbon_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

static func feedback_duration(presentation: Dictionary, authored: float) -> float:
	# Empty generic status feedback lasts only 0.18 s. A burst with no victims
	# must still finish its specified ribbons/glow before this source clears.
	return maxf(authored, GLOW_SECONDS) if presentation.has("en01_burst") else authored

static func glow_alpha(elapsed: float) -> float:
	if elapsed < 0.0 or elapsed >= GLOW_SECONDS: return 0.0
	if elapsed <= GLOW_RISE_SECONDS: return GLOW_PEAK_ALPHA * elapsed / GLOW_RISE_SECONDS
	return GLOW_PEAK_ALPHA * (GLOW_SECONDS - elapsed) / (GLOW_SECONDS - GLOW_RISE_SECONDS)

static func draw(view: Control, effect: Dictionary) -> void:
	var elapsed: float = float(effect["elapsed"])
	var origin: Vector2 = view._tile_center(effect["tile"])
	for tile: Vector2i in effect.get("tiles", []):
		if not view._board_tile_is_visible_to_player(tile): continue
		flame(view, origin, view._tile_center(tile), view._tile_width(), elapsed)
	smoke(view, origin, view._tile_width(), elapsed)

static func flame(canvas: CanvasItem, origin: Vector2, target: Vector2, size: float, elapsed: float) -> void:
	if elapsed < 0.0 or elapsed >= RIBBON_SECONDS: return
	if Pixel.route(canvas, "fire", flame, [origin, target, size, elapsed]): return
	var t: float = elapsed / RIBBON_SECONDS
	_ribbon_points[0] = origin
	_ribbon_points[1] = origin.lerp(target, t * 0.5)
	_ribbon_points[2] = origin.lerp(target, t)
	Fx._ribbon(canvas, _ribbon_points, size * RIBBON_WIDTH_RATIO, Color(Fx.color_for("fire"), RIBBON_ALPHA * (1.0 - t)), false)

static func smoke(canvas: CanvasItem, origin: Vector2, size: float, elapsed: float) -> void:
	if elapsed < 0.0 or elapsed >= SMOKE_SECONDS: return
	if Pixel.route(canvas, "fire", smoke, [origin, size, elapsed]): return
	Fx._puff(canvas, origin, Vector2.ONE * size * SMOKE_SIZE_RATIO, 0.0, Color(Pixel.ramp_for("fire")[0], SMOKE_ALPHA * (1.0 - elapsed / SMOKE_SECONDS)), 0)

# Feedback clocks own time; drawing never reads a live clock or allocates an
# event journal. Used by both the traced and legacy dissolve playback paths.
static func decorate(presentation: Dictionary, elapsed: float) -> void:
	if presentation.has("en01_burst"):
		var effect: Dictionary = (presentation["en01_burst"] as Dictionary).duplicate(false)
		effect["elapsed"] = elapsed
		var effects: Array[Dictionary]
		if elapsed < GLOW_SECONDS: effects.append(effect)
		presentation["burst_effects"] = effects
