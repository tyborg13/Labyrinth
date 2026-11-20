extends RefCounted

# A receipt observes the final routed commands and hit regions outside the
# measurement window. Native perf134 separately compares every output pixel.
static func collect(board: Control) -> Dictionary:
	var result: Dictionary = {"hud": {}, "props": {}, "bodies": {}}
	for record: Dictionary in board._aim_focus.canvases.values():
		if not bool(record.hud) or not is_instance_valid(record.canvas): continue
		var canvas: Control = record.canvas
		if not canvas.is_visible_in_tree(): continue
		if canvas._render_slice_ops.is_empty(): continue
		var operation: Array = canvas._render_slice_ops[0]
		if operation[0] == "_draw_slice_intent_orders": continue # No production paint.
		var id: String = "%s/%s/%s" % [canvas.get_parent().name, operation[0], record.unit.get("key", "")]
		result.hud[id] = [operation, canvas.z_index, canvas._tooltip_regions]
	for canvas: Control in board._retained_render_layers():
		if not canvas.is_visible_in_tree(): continue
		var operations: Array = canvas._render_slice_ops
		if operations.size() != 1 or operations[0][0] != "_draw_isolated_props": continue
		var tile: Vector2i = operations[0][1][0]
		var commands: Array = []
		for key: String in canvas._prop_command_cache._slots:
			if key.begins_with("terrain:"):
				commands.append_array(canvas._prop_command_cache._slots[key]["commands"])
		if not commands.is_empty(): result.props[str(tile)] = [commands, canvas._tile_tooltip_regions]
	var outlines: Node = board.get("_occlusion_silhouettes")
	if is_instance_valid(outlines):
		for canvas: Control in outlines.team.bodies.values():
			if not canvas.is_visible_in_tree(): continue
			var unit: Dictionary = canvas._unit_outline_actor
			result.bodies[str(unit.get("key", ""))] = [
				canvas._render_layer_tile, unit.get("type"), bool(unit.get("death_animation", false)), canvas._unit_draw_rect(unit)]
	return _stable(result)

static func _stable(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var output: Dictionary = {}
			for key: Variant in value: output[str(key)] = _stable(value[key])
			return output
		TYPE_ARRAY:
			var output: Array = []
			for item: Variant in value: output.append(_stable(item))
			return output
		TYPE_OBJECT:
			if not is_instance_valid(value): return null
			if value is Texture2D:
				return [value.get_class(), value.resource_path, value.get_size()]
			if value is Resource: return [value.get_class(), value.resource_path]
			return value.get_class()
	return value
