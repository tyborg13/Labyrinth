extends Node2D
## Separate blend state from the board's mix art-treatment shader. Retained
## effects redraws submit immutable progress-derived triangles to this child.
const Trail = preload("res://scripts/strike_trail_fx.gd")
var _batches: Array[Dictionary]
# Submission/draw revisions let probes distinguish queued geometry from a
# real renderer draw without treating headless batch counts as visual proof.
var submission_revision: int = 0
var drawn_submission_revision: int = -1
var draw_count: int = 0
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
	submission_revision += 1
	_batches = batches
	queue_redraw()

func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	Trail.draw(self, _batches)
	drawn_submission_revision = submission_revision
	draw_count += 1
	if is_instance_valid(instrumentation_owner):
		instrumentation_owner.call("_record_render_section_time", instrumentation_section, started)
