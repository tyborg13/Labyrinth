extends Node2D

## Retained, input-transparent border. Only geometry changes rebuild its quad;
## pulse changes self_modulate, never the board's drawing commands.
const BORDER_WIDTH: float = 4.0
const CORE_WHITE_MIX: float = 0.55
const EDGE_WIDTH: float = 2.0
const EDGE_BRIGHTNESS: float = 0.45
const RAISE: float = 3.0
const DROP_RIM_WIDTH: float = 3.0
const DROP_RIM_ALPHA: float = 0.5
const GLOW_WIDTH: float = 16.0
const GLOW_ALPHA: float = 0.55
const INNER_WASH_ALPHA: float = 0.14
const PULSE_SECONDS: float = 1.4
const PULSE_MIN: float = 0.85
const INVALID_ALPHA: float = 0.7
const ShaderSource = preload("res://scripts/targeted_tile_highlight.gdshader")

var tile := Vector2i(-1, -1)
var tone: String = "invalid"
var tone_color: Color
var _context: Dictionary = {}
var _half_tile := Vector2.ZERO
var _zoom: float = 1.0
var _reduced_motion: bool = false

func _init() -> void:
	name = "TargetedTileHighlight"
	# A floor decal in the board's ordinary relative-Z painter order. The owner
	# reserves its sibling slot after action-floor and before every scene tile.
	visible = false
	set_process(false)
	var ink := ShaderMaterial.new()
	ink.shader = ShaderSource
	ink.set_shader_parameter("border_width", BORDER_WIDTH)
	ink.set_shader_parameter("core_white_mix", CORE_WHITE_MIX)
	ink.set_shader_parameter("edge_width", EDGE_WIDTH)
	ink.set_shader_parameter("edge_brightness", EDGE_BRIGHTNESS)
	ink.set_shader_parameter("raise_height", RAISE)
	ink.set_shader_parameter("drop_rim_width", DROP_RIM_WIDTH)
	ink.set_shader_parameter("drop_rim_alpha", DROP_RIM_ALPHA)
	ink.set_shader_parameter("glow_width", GLOW_WIDTH)
	ink.set_shader_parameter("glow_alpha", GLOW_ALPHA)
	ink.set_shader_parameter("inner_wash_alpha", INNER_WASH_ALPHA)
	material = ink

func set_context(context: Dictionary) -> void:
	_context = context
	_reduced_motion = bool(context.get("reduced_motion", false))
	set_process(bool(context.get("active", false)) and not _reduced_motion)
	_update_pulse()

func present(board: Control, next_tile: Vector2i) -> void:
	tile = next_tile
	visible = bool(_context.get("active", false)) and tile.x >= 0 and bool(board.call("_tile_in_grid", board.combat_state.get("grid", []), tile))
	if not visible: return
	var valid: bool = (_context.get("targets", []) as Array).has(tile)
	var shortcut: bool = (_context.get("shortcuts", {}) as Dictionary).has(tile)
	tone = "invalid"
	if valid or shortcut:
		tone = "valid"
		if shortcut or bool(_context.get("attack", false)) or (_context.get("enemy_tiles", {}) as Dictionary).has(tile):
			tone = "attack"
		elif bool(_context.get("move", false)):
			tone = "move"
	tone_color = (_context["colors"] as Dictionary)[tone]
	if tone == "invalid": tone_color.a *= INVALID_ALPHA
	modulate = tone_color
	position = board.call("world_position_for_tile", tile)
	var half_tile: Vector2 = Vector2(board.call("_tile_width"), board.call("_tile_height")) * 0.5
	var zoom: float = board.get("_navigation_zoom")
	if half_tile != _half_tile or not is_equal_approx(zoom, _zoom):
		_half_tile = half_tile
		_zoom = zoom
		(material as ShaderMaterial).set_shader_parameter("half_tile", _half_tile)
		(material as ShaderMaterial).set_shader_parameter("zoom", _zoom)
		queue_redraw()

func _process(_delta: float) -> void:
	_update_pulse()

func _update_pulse() -> void:
	var seconds: float = preload("res://scripts/presentation_clock.gd").ticks_msec() / 1000.0
	self_modulate.a = pulse_alpha_at(seconds, _reduced_motion)

static func pulse_alpha_at(seconds: float, reduced_motion: bool) -> float:
	return 1.0 if reduced_motion else (1.0 + PULSE_MIN) * 0.5 - (1.0 - PULSE_MIN) * 0.5 * cos(TAU * seconds / PULSE_SECONDS)

func _draw() -> void:
	var pad: float = (GLOW_WIDTH + EDGE_WIDTH + BORDER_WIDTH * 0.5 + RAISE) * _zoom
	var extent: Vector2 = _half_tile + Vector2.ONE * pad
	draw_rect(Rect2(-extent, extent * 2.0), Color.WHITE)
