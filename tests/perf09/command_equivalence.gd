extends SceneTree
## Invoked by tools/perf09_command_proof.py. Both source variants redirect every
## native board/helper draw call to the same sink; source methods still execute.
const VIEWPORT := Vector2i(1920, 1080)
const PROOF_CLOCK_SECONDS: float = 42.0
const PROOF_IDLE_TIME: float = 0.375
var failures: Array[String]
var rows: Array = []
var comparisons: int = 0
var changed_layer_transitions: int = 0
var output: String
var _last_sections: Dictionary = {}
var _viewport_texture_labels: Dictionary = {}
var _texture_fixtures: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var reference: Script = load(args[args.find("--reference") + 1])
	var candidate: Script = load(args[args.find("--candidate") + 1])
	output = args[args.find("--output-dir") + 1]
	if reference == null or candidate == null or not reference.can_instantiate() or not candidate.can_instantiate():
		push_error("Could not compile command sink variants")
		quit(1)
		return
	for script: Script in [reference, candidate]:
		if script.get_script_constant_map().get("PERF09_WINDOWS_PATH_PROOF", "") != "C:/temp/quote\"part/board.gd":
			failures.append("Generated Windows path literal did not round-trip through GDScript")
	root.size = VIEWPORT
	root.content_scale_size = VIEWPORT
	var old: Control = reference.new()
	var current: Control = candidate.new()
	for board: Control in [old, current]:
		board.size = Vector2(VIEWPORT)
		root.add_child(board)
		board.set_process(false)
		board.set_submission_performance_instrumentation_enabled(true)
	var retained: Dictionary = {}
	var previous_sample: Dictionary = {}
	for path: String in args.slice(args.find("--states") + 1):
		var file := FileAccess.open(path, FileAccess.READ)
		var states: Dictionary = file.get_var()
		file.close()
		for label: String in states:
			var sample: Dictionary = states[label]
			for board: Control in [old, current]:
				board.perf09_dirty_layers.clear()
				board.size = sample["board_size"]
				var shown: Dictionary = sample["presentation"].duplicate(true)
				for key: String in ["ambient_time_seconds", "damage_preview_time_seconds", "lethal_preview_time_seconds"]: shown[key] = PROOF_CLOCK_SECONDS
				board.set_combat_state(sample["state"].duplicate(true), sample["move_tiles"], sample["attack_tiles"], sample["selected_tile"], "", "", sample["exit_tiles"], sample["exit_icon_ids"], shown)
				_apply_operations(board, sample)
				board._idle_elapsed = PROOF_IDLE_TIME
				for layer: Control in board._retained_render_layers(): layer._idle_elapsed = PROOF_IDLE_TIME
			# Warm layout/path/texture metadata on both sides before timing the
			# original; only the candidate retains the new prop command slots.
			_commands(old)
			var reference_started: int = Time.get_ticks_usec()
			var expected: Dictionary = _commands(old)
			var reference_usec: int = Time.get_ticks_usec() - reference_started
			var reference_sections: Dictionary = _last_sections.duplicate()
			var cold_started: int = Time.get_ticks_usec()
			var cold: Dictionary = _commands(current)
			var cold_usec: int = Time.get_ticks_usec() - cold_started
			var cold_sections: Dictionary = _last_sections.duplicate()
			var warm_started: int = Time.get_ticks_usec()
			var warm: Dictionary = _commands(current)
			var warm_usec: int = Time.get_ticks_usec() - warm_started
			var differences: Array = []
			for layer: String in expected:
				comparisons += 2
				if expected[layer] != cold.get(layer) or expected[layer] != warm.get(layer):
					differences.append(layer)
					if failures.size() < 3: failures.append("%s %s: %s != %s" % [label, layer, str(expected[layer]).left(600), str(cold.get(layer)).left(600)])
				if retained.has(layer) and not current.perf09_dirty_layers.has(layer) and retained[layer] != expected[layer]:
					failures.append("Unqueued changed canvas: " + label + " " + layer)
					var diff_file := FileAccess.open(output.path_join("unqueued_" + layer + ".json"), FileAccess.WRITE)
					diff_file.store_string(JSON.stringify({"state": label, "old": retained[layer], "new": expected[layer], "old_presentation": previous_sample.get("presentation", {}), "new_presentation": sample["presentation"]}, "\t"))
					diff_file.close()
				if retained.has(layer) and retained[layer] != expected[layer]: changed_layer_transitions += 1
			retained = expected
			previous_sample = sample
			rows.append({"source": path, "state": label, "layers": expected.size(), "differences": differences, "original_usec": reference_usec, "original_sections": reference_sections, "candidate_cold_sections": cold_sections, "candidate_warm_sections": _last_sections.duplicate(), "candidate_cold_usec": cold_usec, "candidate_warm_usec": warm_usec})
		retained.clear()
	old.free()
	current.free()
	if comparisons == 0: failures.append("No canvas commands compared")
	var report := {"method": "Native CanvasItem primitive arguments, in paint order; original methods vs candidate cold and warm; exact equality; wall clock frozen at 42s; idle clock 0.375s; meshes expanded to surface arrays; textures identified by source/owning viewport path and dimensions", "states": rows, "comparisons": comparisons, "injected_fault": "drop terrain target queue" if args.has("--fault-injection") else "none", "changed_layer_transitions": changed_layer_transitions, "errors": failures}
	var report_file := FileAccess.open(output.path_join("equivalence.json"), FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	for error: String in failures: push_error(error)
	print("PERF09 COMMAND EQUIVALENCE: %s (%d states; %d exact cold/warm layer comparisons; %d changed layer transitions; %d differences)" % ["PASS" if failures.is_empty() else "FAIL", rows.size(), comparisons, changed_layer_transitions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _apply_operations(board: Control, sample: Dictionary) -> void:
	var navigation: Dictionary = sample.get("navigation", {})
	if bool(navigation.get("reset", false)): board.reset_navigation()
	if navigation.has("zoom"): board.set_navigation_zoom(float(navigation["zoom"]), board.size * 0.5)
	if navigation.has("pan"): board.set_navigation_pan(navigation["pan"])
	var mutation: Dictionary = sample.get("texture_mutation", {})
	if mutation.is_empty(): return
	var id: int = board.get_instance_id()
	if not _texture_fixtures.has(id):
		var original: Texture2D = board._terrain_textures["wooden_crate"]
		var atlas := AtlasTexture.new()
		atlas.atlas = original
		atlas.region = Rect2(Vector2.ZERO, original.get_size() * 0.5)
		_texture_fixtures[id] = {"original": original, "atlas": atlas}
	var fixture: Dictionary = _texture_fixtures[id]
	var atlas: AtlasTexture = fixture["atlas"]
	match str(mutation["stage"]):
		"base": board._terrain_textures["wooden_crate"] = atlas
		"region": atlas.region.position.x = atlas.region.size.x
		"margin": atlas.margin.position.x = 1.0
		"underlying": atlas.atlas = board._terrain_textures["wooden_box"]
		"reset": board._terrain_textures["wooden_crate"] = fixture["original"]
	# This models an explicit repaint after editing a texture resource; the
	# command-cache key must notice changes even though the Atlas object is same.
	board._queue_scene_render_layer_for_tile(mutation["tile"])

func _commands(board: Control) -> Dictionary:
	_viewport_texture_labels.clear()
	_index_viewport_textures(board)
	board.reset_render_instrumentation()
	var result: Dictionary = {}
	var layers: Array = board._retained_render_layers().duplicate()
	layers.push_front(board._static_render_cache_layer)
	for layer: Control in layers:
		if layer == null: continue
		layer.perf09_commands.clear()
		# draw_path's resource retention is normally started by _draw().
		layer._path_draw_cache.begin_canvas_draw(layer)
		layer._draw_board_commands()
		result[str(layer.name)] = [_normalize(layer.perf09_commands), _normalize(layer._tooltip_regions), _child_commands(layer)]
	_last_sections = board.render_instrumentation_snapshot().get("render_section_total_usec", {})
	return result

func _index_viewport_textures(node: Node, path: String = "") -> void:
	if node is SubViewport:
		_viewport_texture_labels[node.get_texture().get_instance_id()] = path
	for child: Node in node.get_children():
		var label: String = str(child.name)
		if label.begins_with("@"): label = "%s_%d" % [child.get_class(), child.get_index()]
		_index_viewport_textures(child, path.path_join(label))

func _child_commands(parent: Node) -> Array:
	var result: Array = []
	for child: Node in parent.get_children():
		if child.has_method("_perf09_emit"):
			child.perf09_commands.clear()
			if child.has_method("_draw"): child.call("_draw")
			var label: String = str(child.name)
			if label.begins_with("@"): label = (child.get_script() as Script).resource_path.get_file()
			result.append([label, child.visible, child.modulate, child.get_transform(), child.z_index, child.show_behind_parent,
				_normalize(child.material), _normalize(child.perf09_commands), _child_commands(child)])
	return result

func _normalize(value: Variant) -> Variant:
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedColorArray or value is PackedInt32Array or value is PackedFloat32Array:
		var result: Array = []
		for entry: Variant in value: result.append(_normalize(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _normalize(value[key])
		return result
	if value is ArrayMesh:
		var surfaces: Array = []
		for index: int in range(value.get_surface_count()): surfaces.append(_normalize(value.surface_get_arrays(index)))
		return ["ArrayMesh", surfaces]
	if value is Texture2D:
		var path: String = str(value.get_meta("asset_source_path", value.resource_path))
		if value is AtlasTexture: return ["AtlasTexture", _normalize(value.atlas), value.region, value.margin]
		if value is ViewportTexture:
			path = str(_viewport_texture_labels.get(value.get_instance_id(), str(value.viewport_path)))
			if path.is_empty(): failures.append("Unidentified viewport texture in canvas command")
		return [value.get_class(), path, value.get_size()]
	if value is ShaderMaterial:
		var uniforms: Dictionary = {}
		for uniform: Dictionary in value.shader.get_shader_uniform_list(): uniforms[uniform["name"]] = _normalize(value.get_shader_parameter(uniform["name"]))
		return ["ShaderMaterial", value.shader.resource_path, uniforms]
	if value is StyleBox:
		var properties: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_STORAGE and str(property["name"]) != "script":
				properties[property["name"]] = _normalize(value.get(property["name"]))
		return [value.get_class(), properties]
	if value is Resource: return [value.get_class(), value.resource_path]
	return value
