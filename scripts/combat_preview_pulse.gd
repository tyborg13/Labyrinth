extends RefCounted

## The shipped damage-preview alpha is the one forecast clock on every HUD.
const Clock = preload("res://scripts/presentation_clock.gd")
const REDUCED_MOTION_TIME_SECONDS: float = 0.0
const NODE_NAME: String = "CombatPreviewPulse"

static func alpha(source: Dictionary, lethal: bool = false) -> float:
	var seconds: float = float(source.get("damage_preview_time_seconds", float(Clock.ticks_msec()) / 1000.0))
	if bool(source.get("reduced_motion", false)): seconds = REDUCED_MOTION_TIME_SECONDS
	var pulse: float = 0.55 + 0.45 * sin(seconds * 10.0)
	return 0.62 + pulse * 0.26 if lethal else 0.52 + pulse * 0.22

static func bind(target: CanvasItem, source: Dictionary, active: bool) -> void:
	var ticker: Node = target.get_node_or_null(NODE_NAME)
	if ticker == null:
		if not active: return
		ticker = CanvasPulse.new()
		ticker.name = NODE_NAME
		target.add_child(ticker)
	ticker.configure(source, active, alpha)

class CanvasPulse:
	extends Node
	var _source: Dictionary = {}
	var _base_alpha: float = 1.0
	var _active: bool = false
	var _sample: Callable

	func configure(source: Dictionary, active: bool, sample: Callable) -> void:
		if active and not _active: _base_alpha = (get_parent() as CanvasItem).modulate.a
		_source = source
		_active = active
		_sample = sample
		set_process(active and not bool(source.get("reduced_motion", false)) and not source.has("damage_preview_time_seconds"))
		_apply()

	func _process(_delta: float) -> void:
		_apply()

	func _apply() -> void:
		var target: CanvasItem = get_parent() as CanvasItem
		var tint: Color = target.modulate
		tint.a = _base_alpha * float(_sample.call(_source)) if _active else _base_alpha
		target.modulate = tint
