extends "res://tests/board_surface_dense_probe.gd"

# Compare every selective update against redrawing the same live board in full.
# The scene, clock and input state are frozen; only invalidation may differ.
func _capture(name: String, _settle_frames: int = 8) -> void:
	if name != "01_mixed_ground": return
	_seed_dense_ground()
	scene.call("_refresh_ui")
	for frame: int in range(8): await RenderingServer.frame_post_draw
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var board: Control = scene.get("board_view") as Control
	var base: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	base["ambient_time_seconds"] = 12.0
	base["damage_preview_time_seconds"] = 12.0
	board.set("_idle_elapsed", 2.0)
	var cases: Array = [
		{"id": "single", "surface_preview_events": [{"kind": "surface_created", "surface": "ice", "tile": Vector2i(2, 2)}]},
		{"id": "moved", "surface_preview_events": [{"kind": "surface_created", "surface": "fire", "tile": Vector2i(6, 6)}]},
		{"id": "multi", "surface_preview_events": [{"kind": "detonate", "tiles": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(6, 6)]}]},
		{"id": "diagonal", "surface_preview_arcs": [{"from": Vector2i(1, 1), "to": Vector2i(7, 6)}]},
		{"id": "bent", "surface_preview_arcs": [{"path": [Vector2i(1, 2), Vector2i(5, 6), Vector2i(7, 3)]}]},
		{"id": "chain_start", "effect": {"kind": "chain", "element": "lightning", "path": [Vector2i(1, 2), Vector2i(5, 6), Vector2i(7, 3)]}, "effect_progress": 0.1},
		{"id": "chain_progress", "effect": {"kind": "chain", "element": "lightning", "path": [Vector2i(1, 2), Vector2i(5, 6), Vector2i(7, 3)]}, "effect_progress": 0.7},
		{"id": "branches", "effect": {"kind": "chain", "element": "lightning", "branches": [{"path": [Vector2i(1, 1), Vector2i(6, 7)]}, {"path": [Vector2i(7, 1), Vector2i(2, 7)]}]}, "effect_progress": 0.4},
		{"id": "chain_to_other", "effect": {"kind": "ranged", "element": "ice", "from": Vector2i(2, 2), "to": Vector2i(6, 6)}, "effect_progress": 0.4},
		{"id": "cleared"},
		{"id": "feedback_start", "surface_feedback_events": [{"kind": "surface_created", "surface": "fire", "tile": Vector2i(4, 3)}], "surface_feedback_progress": 0.1},
		{"id": "feedback_end", "surface_feedback_events": [{"kind": "surface_created", "surface": "fire", "tile": Vector2i(4, 3)}], "surface_feedback_progress": 1.0},
		{"id": "feedback_removed"},
		{"id": "friendly_and_status", "friendly_damage_chips": [{"tile": state["player"]["pos"], "actor_key": "player", "label": "You: −2 HP", "kind": "danger"}], "surface_status_preview": {"player": {"chilled": true, "freeze": 0}}},
		{"id": "hud_cleared"},
	]
	var results: Array[Dictionary]
	for reduced: bool in [false, true]:
		base["reduced_motion"] = reduced
		board.call("set_combat_state", state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, base.duplicate(true))
		board.call("_queue_dynamic_redraw")
		for frame: int in range(3): await RenderingServer.frame_post_draw
		for sample: Dictionary in cases:
			var shown: Dictionary = base.duplicate(true)
			shown.merge(sample, true)
			shown.erase("id")
			board.call("set_combat_state", state.duplicate(true), [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
			await RenderingServer.frame_post_draw
			var selective: Image = view.get_texture().get_image()
			board.call("_queue_dynamic_redraw")
			await RenderingServer.frame_post_draw
			var reference: Image = view.get_texture().get_image()
			var identical: bool = selective.get_data() == reference.get_data()
			var difference: Dictionary = _pixel_difference(selective, reference)
			var id: String = "%s_%s" % ["reduced" if reduced else "normal", sample["id"]]
			results.append({"id": id, "byte_identical": identical, "difference": difference})
			if not identical or str(sample["id"]) in ["diagonal", "branches", "friendly_and_status"]:
				assert(selective.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(id + ".png"))) == OK)
				if not identical: reference.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(id + "_reference.png")))
			# Native alpha rasterization can differ at a handful of boundary
			# samples. This bound admits only sub-visible rounding (<=3/255 on
			# <=32 channel samples), never a stale glyph, floor segment or effect.
			assert(int(difference["max_channel_delta"]) <= 3 and int(difference["changed_channels"]) <= 32, "Selective surface redraw differs from full redraw: %s" % id)
	var file := FileAccess.open(OUTPUT.path_join("redraw_equivalence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"comparisons": results, "semantic_errors": []}, "\t"))
	file.close()
	print("SURFACE REDRAW EQUIVALENCE RESULT: " + JSON.stringify({"comparisons": results, "semantic_errors": []}))

func _pixel_difference(a: Image, b: Image) -> Dictionary:
	var left: PackedByteArray = a.get_data()
	var right: PackedByteArray = b.get_data()
	var changed: int = 0
	var maximum: int = 0
	if left != right:
		for index: int in range(left.size()):
			var delta: int = absi(int(left[index]) - int(right[index]))
			if delta > 0:
				changed += 1
				maximum = maxi(maximum, delta)
	return {"changed_channels": changed, "max_channel_delta": maximum}
