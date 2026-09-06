extends "res://tests/board_surface_dense_probe.gd"

const Art = preload("res://scripts/board_surface_presentation.gd")
const IceLayer = preload("res://scripts/board_surface_ice_layer.gd")

class ObservedIce extends IceLayer:
	var draw_count: int = 0
	var drawn_width: float = -1.0
	var drawn_seed: int = -1
	func _draw() -> void:
		super._draw()
		draw_count += 1
		drawn_width = _width
		drawn_seed = _seed

func _capture(name: String, _settle_frames: int = 8) -> void:
	if name != "01_mixed_ground": return
	_seed_dense_ground()
	scene.call("_refresh_ui")
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var board: Control = scene.get("board_view") as Control
	var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	shown["ambient_time_seconds"] = 12.0
	board.set("_idle_elapsed", 2.0)
	# Let deferred native layout and card hand preparation finish before freezing.
	await _show(board, state, shown)
	await _show(board, state, shown)
	var comparisons: Array[Dictionary]
	for reduced: bool in [false, true]:
		shown["reduced_motion"] = reduced
		for phase: float in [12.0, 12.73]:
			shown["ambient_time_seconds"] = phase
			var reference: Image
			for cached: bool in [false, true]:
				Art.retained_cache_enabled = cached
				# Compare the actual next rendered frame, including uniform-only
				# particles; extra settling must not hide stale presentation.
				await _show(board, state, shown, 1)
				var screenshot: Image = view.get_texture().get_image()
				var image_name: String = "cache_%s_%s_%s.png" % ["reduced" if reduced else "normal", str(phase).replace(".", "_"), "cached" if cached else "reference"]
				assert(screenshot.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(image_name))) == OK)
				if not cached:
					reference = screenshot
				else:
					comparisons.append({"reduced_motion": reduced, "phase": phase, "difference": _difference(reference, screenshot)})
	Art.retained_cache_enabled = true
	# Reduced motion pins the phase. Geometry changes must still refresh both
	# the retained plates and their independently drawn reflective shimmer.
	var resized_ice := ObservedIce.new()
	view.add_child(resized_ice)
	resized_ice.configure(Vector2(150, 150), 100.0, 1009, 0.37)
	await RenderingServer.frame_post_draw
	var initial_draws: int = resized_ice.draw_count
	resized_ice.configure(Vector2(150, 150), 130.0, 1009, 0.37)
	await RenderingServer.frame_post_draw
	assert(resized_ice.draw_count > initial_draws and resized_ice.drawn_width == 130.0, "Pinned-phase Ice width changes must redraw reflected glints")
	var resized_draws: int = resized_ice.draw_count
	resized_ice.configure(Vector2(150, 150), 130.0, 2018, 0.37)
	await RenderingServer.frame_post_draw
	assert(resized_ice.draw_count > resized_draws and resized_ice.drawn_seed == 2018, "Pinned-phase Ice seed changes must redraw reflected glints")
	resized_ice.queue_free()
	await RenderingServer.frame_post_draw
	shown["reduced_motion"] = false
	# Procedural tongues must also reach the same frame as retained particles.
	for frame: int in range(4):
		shown["ambient_time_seconds"] = 14.0 + float(frame) / 60.0
		board.call("set_combat_state", state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, shown.duplicate(true))
		board.call("_queue_dynamic_redraw")
		await RenderingServer.frame_post_draw
		for tile_layer: Node in (board.get("_scene_render_layers_by_tile") as Dictionary).values():
			var fire: Node2D = tile_layer.get("_surface_fire_layer") as Node2D
			if fire == null or not fire.visible: continue
			for pocket: Dictionary in fire.get("_pockets"):
				var tongue: Node = pocket["tongue"]
				assert(float(tongue.get("_drawn_phase")) == float(fire.get("_phase")), "Retained tongue and particles must present the same phase in one rendered frame")
	var original: Dictionary = state.duplicate(true)
	var node_samples: Array[int]
	for cycle: int in range(12):
		var changed: Dictionary = original.duplicate(true)
		changed["surfaces"] = {}
		Ground.place(changed, Vector2i(3, 3), "ice")
		Ground.place(changed, Vector2i(3, 3), "rubble")
		await _show(board, changed, shown)
		var layer: Node = (board.get("_scene_render_layers_by_tile") as Dictionary)[Vector2i(3, 3)]
		assert((layer.get("_surface_rubble_layer") as CanvasItem).visible)
		assert((layer.get("_surface_ice_layer") as CanvasItem).visible)
		changed = changed.duplicate(true)
		Ground.remove(changed, Vector2i(3, 3), "rubble", "proof_consumption")
		Ground.place(changed, Vector2i(3, 3), "fire")
		await _show(board, changed, shown)
		assert(not (layer.get("_surface_rubble_layer") as CanvasItem).visible, "Consumed Rubble must disappear from the retained cache")
		assert(not (layer.get("_surface_ice_layer") as CanvasItem).visible, "Replaced Ice must disappear from the retained cache")
		assert((layer.get("_surface_fire_layer") as CanvasItem).visible)
		assert((layer.get("_surface_electric_layer") as CanvasItem).visible, "Stormcoal Fire retains its conductive electrical treatment")
		Ground.place(changed, Vector2i(3, 3), "electrified")
		await _show(board, changed, shown)
		assert(not (layer.get("_surface_fire_layer") as CanvasItem).visible)
		assert((layer.get("_surface_electric_layer") as CanvasItem).visible)
		Ground.remove(changed, Vector2i(3, 3), "electrified", "proof_discharge")
		await _show(board, changed, shown)
		assert(not (layer.get("_surface_electric_layer") as CanvasItem).visible, "Discharge removes retained Electricity on the same state refresh")
		changed = changed.duplicate(true)
		Ground.place(changed, Vector2i(3, 3), "ice")
		Ground.place(changed, Vector2i(3, 3), "rubble")
		var hidden: Dictionary = shown.duplicate(true)
		hidden["umbra_visible_tiles"] = []
		await _show(board, changed, hidden)
		assert(not (layer.get("_surface_rubble_layer") as CanvasItem).visible and not (layer.get("_surface_ice_layer") as CanvasItem).visible, "Hidden cached ground must disappear")
		assert(not (layer.get("_surface_electric_layer") as CanvasItem).visible)
		var next_room: Dictionary = original.duplicate(true)
		next_room["room_coord"] = Vector2i(9, 9)
		next_room["surfaces"] = {}
		next_room["grid"] = (original["grid"] as Array).slice(0, 7)
		next_room["enemies"] = []
		await _show(board, next_room, shown)
		for candidate: Node in (board.get("_scene_render_layers_by_tile") as Dictionary).values():
			for field: String in ["_surface_rubble_layer", "_surface_ice_layer", "_surface_fire_layer", "_surface_electric_layer"]:
				var cached_layer: CanvasItem = candidate.get(field) as CanvasItem
				assert(cached_layer == null or not cached_layer.visible, "A new room must not retain old visible ground")
		await _show(board, original, shown)
		node_samples.append(_node_count(board))
	assert(node_samples[-1] == node_samples[0], "Repeated replacement/consumption/visibility/room changes must not grow retained node counts")
	var file := FileAccess.open(OUTPUT.path_join("cache_equivalence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"comparisons": comparisons, "node_counts": node_samples, "transition_cycles": 12, "semantic_errors": []}, "\t"))
	file.close()
	print("BOARD SURFACE CACHE RESULT: " + JSON.stringify({"comparisons": comparisons, "node_counts": node_samples}))
	print("BOARD SURFACE CACHE PROBE: PASS")

func _show(board: Control, next_state: Dictionary, shown: Dictionary, settle_frames: int = 3) -> void:
	board.call("set_combat_state", next_state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, shown.duplicate(true))
	board.set("_idle_elapsed", 2.0)
	board.call("_queue_dynamic_redraw")
	for frame: int in range(settle_frames): await RenderingServer.frame_post_draw

func _difference(a: Image, b: Image) -> Dictionary:
	# Exact bytes are cheap to compare natively; channel-error analysis stays in
	# the external PNG inspector rather than millions of interpreted pixel reads.
	return {"byte_identical": a.get_data() == b.get_data(), "format": a.get_format(), "size": [a.get_width(), a.get_height()]}

func _node_count(node: Node) -> int:
	var result: int = 1
	for child: Node in node.get_children(): result += _node_count(child)
	return result
