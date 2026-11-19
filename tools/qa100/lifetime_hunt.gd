extends "res://tools/run_hunt.gd"
## Sample the production tree at the hunt's settled room boundaries.

const TEARDOWN_SAMPLE_FRAMES: int = 2
const Assets = preload("res://scripts/asset_loader.gd")
const Pools = preload("res://scripts/run_card_pool_lifetime.gd")


func _emit(event: String, data: Dictionary) -> void:
	if event == "room":
		_emit_lifetime("lifetime_room", data)
	elif event == "finish":
		_emit_lifetime("lifetime_finish", data["context"])
		_sample_after_scene_free(data["context"])
	super._emit(event, data)


func _sample_after_scene_free(context: Dictionary) -> void:
	for frame: int in range(TEARDOWN_SAMPLE_FRAMES):
		await process_frame
	_emit_lifetime("lifetime_teardown", context)


func _emit_lifetime(event: String, context: Dictionary) -> void:
	var row: Dictionary = {
		"seed": hunt_seed,
		"section": context["section"],
		"room": context["room"],
		"room_kind": context["room_kind"],
		"mode": context["mode"],
		"decision": decision,
		"attached": root.get_tree().get_node_count(),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_bytes": OS.get_static_memory_usage(),
	}
	var attached_types: Dictionary = {}
	_count_attached(root, attached_types)
	var orphan_types: Dictionary = {}
	for id: int in Node.get_orphan_node_ids():
		var node: Node = instance_from_id(id) as Node
		if is_instance_valid(node):
			var key: String = "%s | %s" % [_node_type(node), node.name]
			orphan_types[key] = int(orphan_types.get(key, 0)) + 1
	row["attached_types"] = attached_types
	row["orphan_types"] = orphan_types
	row["retained_counts"] = _retained_counts()
	super._emit(event, row)


func _count_attached(node: Node, counts: Dictionary) -> void:
	var key: String = _node_type(node)
	counts[key] = int(counts.get(key, 0)) + 1
	for child: Node in node.get_children(true):
		_count_attached(child, counts)


func _node_type(node: Node) -> String:
	var script: Script = node.get_script() as Script
	return "%s | %s" % [node.get_class(), script.resource_path] if script else node.get_class()


func _retained_counts() -> Dictionary:
	var counts: Dictionary = {
		"asset_textures": Assets._texture_cache.size(),
		"asset_original_textures": Assets._original_texture_cache.size(),
		"asset_flipped_textures": Assets._flipped_texture_cache.size(),
		"asset_bounds": Assets._texture_used_rect_cache.size(),
		"asset_alpha_polygons": Assets._alpha_polygon_cache.size(),
		"asset_audio": Assets._audio_cache.size(),
		"asset_audio_loops": Assets._looping_audio_cache.size(),
	}
	if is_instance_valid(scene):
		var board: Control = scene.get("board_view")
		counts["board_tile_layers"] = (board.get("_scene_render_layers") as Array).size()
		var aim_focus: RefCounted = board.get("_aim_focus")
		var aim_canvases: Dictionary = aim_focus.canvases
		var visible_aim_canvases: int = 0
		var live_aim_canvases: int = 0
		for record: Dictionary in aim_canvases.values():
			if is_instance_valid(record.canvas):
				live_aim_canvases += 1
				if record.canvas.visible: visible_aim_canvases += 1
		counts["aim_canvas_records"] = aim_canvases.size()
		counts["aim_live_canvases"] = live_aim_canvases
		counts["aim_visible_canvases"] = visible_aim_canvases
		counts["hand_pool"] = (scene.get("_hand_card_pool") as Array).size()
		counts["pile_pool"] = (scene.get("_pile_dialog_card_pool") as Array).size()
		counts["pile_warm_limit"] = Pools.pile_limit(scene)
		counts["pile_is_open"] = scene.get("_pile_scrim").visible
	return counts
