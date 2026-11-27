extends RefCounted
## Threat isolation puts the actual prop submissions on retained child slices.
## Replace only their prop operation while the clear frame is being captured.

const PROPS := "_draw_isolated_props"
const PICKUPS := "_draw_tile_floating_loot"
const DRAW_WAIT_FRAMES := 10

var _slices: Dictionary = {}
var _tiles: Dictionary = {}


func install(board: Control, blocker_tiles: Dictionary) -> int:
	var layers: Dictionary = board.get("_scene_render_layers_by_tile")
	for tile: Vector2i in blocker_tiles:
		var layer: Control = layers.get(tile)
		if not is_instance_valid(layer): continue
		for canvas: Control in layer.get("_layer_slices").canvases:
			var off: Array = canvas.get("_render_slice_ops")
			var clear: Array = _without_blockers(off, tile)
			if clear == off: continue
			_slices[canvas] = {"off": off, "clear": clear}
			_tiles[tile] = true
	return _tiles.size()


static func _without_blockers(operations: Array, tile: Vector2i) -> Array:
	var clear: Array = []
	for operation: Array in operations:
		if operation[0] != PROPS or operation[1][0] != tile:
			clear.append(operation)
		elif operation[1].size() < 2 or operation[1][1]:
			clear.append([PICKUPS, [tile]])
	return clear


func submit(session: SceneTree, phase: String) -> bool:
	var previous_draws: Dictionary = {}
	for canvas: Control in _slices:
		previous_draws[canvas] = canvas.get("_dynamic_draw_count")
		canvas.set("_render_slice_ops", _slices[canvas][phase])
		canvas.queue_redraw()
	# The process signal precedes the deferred redraw. Wait for the actual
	# slice submissions instead of assuming one process signal flushed them.
	for frame: int in DRAW_WAIT_FRAMES:
		if _submitted(previous_draws, phase): return true
		await session.process_frame
	return _submitted(previous_draws, phase)


func _submitted(previous_draws: Dictionary, phase: String) -> bool:
	for canvas: Control in _slices:
		if canvas.get("_render_slice_ops") != _slices[canvas][phase]: return false
		if canvas.get("_dynamic_draw_count") <= previous_draws[canvas]: return false
	return true


func changed_slices() -> int:
	return _slices.size()
