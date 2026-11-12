extends SceneTree
## Isolate native invalidations from the turn-order tooltip writer.
const Tooltip = preload("res://scripts/ui_tooltip_control.gd")
const FIXTURE_SIZE := Vector2(100, 80)
const SETTLE_FRAMES: int = 3
var _draws: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var control := Tooltip.new()
	root.add_child(control)
	control.size = FIXTURE_SIZE
	control.draw.connect(func() -> void: _draws += 1)
	await _settle()
	for field: String in ["size", "custom_minimum_size", "clip_contents", "mouse_filter",
		"mouse_default_cursor_shape", "tooltip_text", "scale", "modulate", "pivot_offset", "rotation", "position"]:
		var value: Variant = control.get(field)
		_draws = 0
		control.set(field, value)
		await _settle()
		print("PERF110 TRIGGER: %s same_assignment_draws=%d" % [field, _draws])
	control.free()
	quit()

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame
