extends Node2D
## Separate blend state from the board's mix art-treatment shader. Retained
## effects redraws submit immutable progress-derived triangles to this child.
const Trail = preload("res://scripts/strike_trail_fx.gd")
var _batches: Array[Dictionary]
var instrumentation_owner: Control
var instrumentation_section: String = "effect_overlay"

func _init() -> void:
	name = "StrikeTrailLight"
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	use_parent_material = false
	# Composite before status/floating text drawn by the effects parent.
	show_behind_parent = true

func submit(batches: Array[Dictionary]) -> void:
	_batches = batches
	queue_redraw()

func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	Trail.draw(self, _batches)
	if is_instance_valid(instrumentation_owner):
		instrumentation_owner.call("_record_render_section_time", instrumentation_section, started)
