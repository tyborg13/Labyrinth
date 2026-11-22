extends "res://tools/perf171/arena_probe.gd"
## Verify that Begin actually uses reserved canvases from the room board.

var _reserved: Dictionary

func _click(point: Vector2) -> void:
	var board: Control = current_scene.board_view
	for reference: WeakRef in board._prepared_opening_tile_layers:
		var layer: Control = reference.get_ref()
		if not is_instance_valid(layer): continue
		for canvas: Control in layer._layer_slices._opening_canvases:
			_reserved[canvas.get_instance_id()] = true
	super._click(point)

func _take() -> void:
	await super._take()
	if not _errors.is_empty(): return
	var board: Control = current_scene.board_view
	var reused: int = 0
	for layer: Control in board._scene_render_layers_by_tile.values():
		for canvas: Control in layer._layer_slices.canvases:
			if _reserved.has(canvas.get_instance_id()): reused += 1
	_receipt["reserved_opening_canvases"] = _reserved.size()
	_receipt["reused_opening_canvases"] = reused
	if reused == 0: _errors.append("Begin did not adopt a reserved opening canvas")
	print("QA127 OPENING CANVASES %s: reserved=%d reused=%d" % [_fixture, _reserved.size(), reused])
