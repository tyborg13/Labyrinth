extends RefCounted

# The frozen renderer predates current elemental art. Keep its complete-pixel
# baseline only for cases whose definition is an unchanged resubmission.
const ORIGINAL_UNCHANGED: Array = ["empty", "same floor resubmitted 0", "same floor resubmitted 1", "same floor resubmitted 2", "retained after instrumentation reset"]

static func original_baseline_valid(label: String) -> bool:
	return label in ORIGINAL_UNCHANGED

static func run(actual: Control, fresh: Control, expect: Callable, label: String) -> void:
	actual._ensure_board_layout_cache()
	fresh._ensure_board_layout_cache()
	expect.call(actual._resolved_board_geometry_inputs() == fresh._resolved_board_geometry_inputs(), label + ": fresh board must independently resolve identical geometry")
	expect.call(actual._hud_health_rects_cache == fresh._hud_health_rects_cache, label + ": fresh HUD must use current navigation geometry")
	expect.call(actual._foreground_obstruction_entries_cache == fresh._foreground_obstruction_entries_cache, label + ": fresh obstruction entries must use current navigation geometry")
	expect.call(not actual.health_ghost_tracker.is_active() and not fresh.health_ghost_tracker.is_active(), label + ": HP ghost and healing transients must be settled")
	if actual._static_render_cache_enabled:
		expect.call(actual._static_render_cache_inputs == fresh._static_render_cache_inputs, label + ": fresh floor must independently resolve identical complete inputs")
		var layer: Control = actual._static_render_cache_layer
		expect.call(layer._board_layout_cache_origin == actual._board_layout_cache_origin and layer._board_layout_cache_tile_width == actual._board_layout_cache_tile_width, label + ": retained floor geometry must match current board geometry")
