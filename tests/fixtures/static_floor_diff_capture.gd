extends RefCounted

const Clock = preload("res://tests/fixtures/static_floor_proof_clock.gd")
const Dump = preload("res://tests/fixtures/static_floor_diff_dump.gd")
const ShaderTime = preload("res://tests/fixtures/static_floor_shader_time.gd")
const CaptureIO = preload("res://tests/fixtures/static_floor_capture_io.gd")
const SETTLE_FRAMES: int = 3
const TIME_EVIDENCE_SECONDS: float = 0.25
const FIXTURE_INPUTS: Array = ["_tile_textures", "_floor_texture_variants", "_element_overlay_texture_variants", "_prop_textures", "_pillar_torch_light_texture", "_floor_variant_by_tile", "_moss_tiles_by_surface", "_static_render_cache_enabled", "_navigation_zoom", "_navigation_pan", "_navigation_uses_default_zoom", "_hover_tile", "_controller_focus_tile"]

static func fresh_view(tree: SceneTree, source: Control, pin_shader_time: bool = true) -> SubViewport:
	var view := SubViewport.new()
	view.size = source.get_viewport().size
	view.disable_3d = true
	view.msaa_2d = source.get_viewport().msaa_2d
	view.canvas_item_default_texture_filter = source.get_viewport().canvas_item_default_texture_filter
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(view)
	var fresh: Control = source.get_script().new()
	view.add_child(fresh)
	fresh.size = source.size
	fresh.set_process(false)
	fresh.set_art_treatment_enabled(source._art_treatment_enabled)
	fresh.set_art_treatment_preset(source._art_treatment.preset)
	fresh._idle_elapsed = Clock.BOARD_SECONDS
	fresh.set_combat_state(source.combat_state.duplicate(true), source.move_tiles.duplicate(), source.attack_tiles.duplicate(), source.selected_tile, source.status_label, source.status_detail, source.exit_tiles.duplicate(true), source.exit_icon_ids.duplicate(true), source.presentation.duplicate(true))
	# Only explicit fixture inputs are copied. Retained layers, health ghosts,
	# submitted commands, geometry caches and rendered textures stay independent.
	for field: String in FIXTURE_INPUTS:
		var value: Variant = source.get(field)
		fresh.set(field, value.duplicate(true) if value is Dictionary else value)
	fresh._sync_dynamic_render_assets()
	# The explicit navigation fixture inputs were assigned after set_combat_state.
	# Use the complete production transform route, including HUD and obstruction
	# geometry, rather than resyncing layer fields against stale derived positions.
	fresh._navigation_transform_changed(false)
	Clock.freeze(fresh)
	if pin_shader_time: ShaderTime.pin_tree(fresh)
	fresh._queue_dynamic_redraw()
	return view

static func record(tree: SceneTree, dump: RefCounted, actual: Control, reference: Control, restored: Image, original: Image, case_id: int, label: String, io: RefCounted = null, output: String = Dump.OUTPUT, emit_paths: bool = true) -> Dictionary:
	# The caller reads both failing images before entering this coroutine. Never
	# replace those snapshots with frames captured after fresh-board setup.
	var source_frame: int = Engine.get_process_frames()
	if io == null: io = CaptureIO.new()
	var bounds: Rect2 = actual.rendered_visual_bounds().merge(reference.rendered_visual_bounds())
	var metadata: Dictionary = {"readback": io.tag(), "source_frame": source_frame, "presentation": actual.presentation.duplicate(true), "original_actors": actor_clocks(reference), "restored_actors": actor_clocks(actual), "restored_geometry": geometry(actual), "original_geometry": geometry(reference), "cached_floor_equal": Clock.pixels_equal(io.image(actual._static_render_cache_viewport), io.image(reference._static_render_cache_viewport)), "fresh_fixture_inputs": FIXTURE_INPUTS, "shader_time": {"restored": ShaderTime.pin_tree(actual), "original": ShaderTime.pin_tree(reference)}}
	var view: SubViewport = fresh_view(tree, actual)
	var fresh: Control = view.get_child(0)
	# This separate board retains original, unmodified shaders. Disable its floor
	# cache before either capture so baking cannot hide TIME inside a floor shader.
	var raw_view: SubViewport = fresh_view(tree, actual, false)
	var raw: Control = raw_view.get_child(0)
	raw.set_meta("bug_01_raw_time_probe", true)
	raw.set_static_render_cache_enabled(false)
	raw._queue_dynamic_redraw()
	for _frame: int in range(SETTLE_FRAMES):
		await io.frame(tree)
	bounds = bounds.merge(fresh.rendered_visual_bounds())
	bounds = bounds.merge(raw.rendered_visual_bounds())
	metadata["fresh_frame"] = Engine.get_process_frames()
	metadata["fresh_actors"] = actor_clocks(fresh)
	metadata["fresh_presentation_equal"] = fresh.presentation == actual.presentation
	metadata["fresh_lighting_equal"] = fresh._art_treatment._parameters == actual._art_treatment._parameters
	metadata["fresh_geometry"] = geometry(fresh)
	metadata["fresh_geometry_equal"] = geometry(fresh) == geometry(actual)
	metadata["shader_time"]["fresh"] = ShaderTime.pin_tree(fresh)
	metadata["shader_time"]["raw_probe"] = ShaderTime.inspect_tree(raw)
	var raw_shaders_unmodified: bool = true
	for material: Dictionary in metadata["shader_time"]["raw_probe"]["materials"]:
		if material["pinned"]: raw_shaders_unmodified = false
	var fresh_image: Image = io.image(view)
	var raw_before: Image = io.image(raw_view)
	var pinned_before: Image = io.image(actual.get_viewport())
	var presentation_before: Dictionary = raw.presentation.duplicate(true)
	var state_before: Dictionary = raw.combat_state.duplicate(true)
	var raw_actors_before: Array[Dictionary] = actor_clocks(raw)
	var pinned_actors_before: Array[Dictionary] = actor_clocks(actual)
	var before_frame: int = Engine.get_process_frames()
	var before_usec: int = Time.get_ticks_usec()
	await io.wait_seconds(tree, TIME_EVIDENCE_SECONDS)
	await io.frame(tree)
	var elapsed: float = float(Time.get_ticks_usec() - before_usec) / 1000000.0
	var raw_after: Image = io.image(raw_view)
	var pinned_after: Image = io.image(actual.get_viewport())
	var raw_actors_after: Array[Dictionary] = actor_clocks(raw)
	var pinned_actors_after: Array[Dictionary] = actor_clocks(actual)
	metadata["time_independence"] = {"requested_seconds": TIME_EVIDENCE_SECONDS, "wall_seconds": elapsed, "before_frame": before_frame, "after_frame": Engine.get_process_frames(), "raw_probe": "fresh production board, original shaders, floor cache disabled before both captures", "state_unchanged": raw.combat_state == state_before and raw.presentation == presentation_before, "raw_shaders_unmodified": raw_shaders_unmodified, "raw_shader_audit_unchanged": ShaderTime.inspect_tree(raw) == metadata["shader_time"]["raw_probe"], "raw_actors_before": raw_actors_before, "raw_actors_after": raw_actors_after, "raw_actors_unchanged": raw_actors_before == raw_actors_after, "pinned_actors_before": pinned_actors_before, "pinned_actors_after": pinned_actors_after, "pinned_actors_unchanged": pinned_actors_before == pinned_actors_after}
	var extra_images: Dictionary = {"time_raw_before": raw_before, "time_raw_after": raw_after, "time_pinned_before": pinned_before, "time_pinned_after": pinned_after}
	var extra_pairs: Dictionary = {"time_raw_0_25s": Dump.compare(raw_before, raw_after), "time_pinned_0_25s": Dump.compare(pinned_before, pinned_after)}
	var result: Dictionary = dump.write_case(case_id, label, original, restored, fresh_image, bounds, metadata, output, emit_paths, extra_images, extra_pairs)
	if not raw_shaders_unmodified: result["errors"].append("BUG_01_RAW_TIME_PROBE_INVALID: original shaders were already pinned")
	raw_view.free()
	view.free()
	return result

# Both board versions expose these fields; the frozen reference intentionally
# does not implement the current board's _resolved_board_geometry_inputs().
static func geometry(board: Control) -> Dictionary:
	return {"size": board.size, "width": board.get("_board_layout_cache_tile_width"), "origin": board.get("_board_layout_cache_origin"), "tiles": (board.get("_board_layout_cache_tiles") as Array).duplicate(), "extents": (board.get("_board_layout_cache_extents") as Dictionary).duplicate(), "zoom": board.get("_navigation_zoom"), "pan": board.get("_navigation_pan"), "offset": board.get("_board_layout_cache_visual_top_offset"), "canvas_transform": board.get_global_transform_with_canvas(), "viewport_transform": board.get_viewport().get_stretch_transform()}

static func actor_clocks(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if node.get("_idle_seconds") != null and node.has_method("snapshot"):
		result.append({"node": str(node.name), "idle_seconds": node.get("_idle_seconds"), "snapshot": node.call("snapshot")})
	for child: Node in node.get_children():
		result.append_array(actor_clocks(child))
	return result
