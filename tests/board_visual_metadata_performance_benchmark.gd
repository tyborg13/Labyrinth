extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Data = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var board := Board.new()
	var original_enemies: Dictionary = Data.enemies().duplicate(true)
	var original_npcs: Dictionary = Data.npcs().duplicate(true)
	var fixtures: Array[Dictionary]
	for enemy_type: String in Data.enemies():
		for footprint: Vector2i in [Vector2i(-1, 0), Vector2i.ONE, Vector2i(2, 3), Vector2i(5, 4)]:
			fixtures.append({"type": enemy_type, "footprint": footprint})
	for npc_id: String in Data.npcs():
		fixtures.append({"type": npc_id, "footprint": Vector2i.ONE})
	fixtures.append({"type": "player"})
	fixtures.append({"type": "missing_definition"})
	fixtures.append({})
	var expected: Array[Dictionary]
	for unit: Dictionary in fixtures:
		var type: String = str(unit.get("type", ""))
		var enemy: Dictionary = Data.enemy_def(type)
		var definition: Dictionary = Data.npc_def(type)
		if definition.is_empty(): definition = enemy
		var footprint: Vector2i = unit.get("footprint", Vector2i.ONE)
		footprint = Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
		var authored: Array = enemy.get("footprint", []) as Array
		if authored.size() >= 2: footprint = Vector2i(maxi(footprint.x, int(authored[0])), maxi(footprint.y, int(authored[1])))
		var player: bool = type == "player" or type.is_empty()
		expected.append({
			"footprint": footprint,
			"scale": 1.0 if player else float(definition.get("art_scale", 1.0)),
			"offset": Vector2.ZERO if player else Vector2(float(definition.get("art_offset_x", 0.0)), float(definition.get("art_offset_y", 0.0))),
			"idle_seconds": Board.IDLE_FRAME_SECONDS if player else maxf(0.01, float(definition.get("idle_frame_seconds", Board.IDLE_FRAME_SECONDS)))
		})
	for index: int in range(fixtures.size()):
		if _read_metadata(board, fixtures[index]) != expected[index]:
			_errors.append("Visual metadata must match expanded definition: %s" % str(fixtures[index]))
	var samples: Array[float]
	for _batch: int in range(7):
		var started: int = Time.get_ticks_usec()
		for _iteration: int in range(10):
			for unit: Dictionary in fixtures: _read_metadata(board, unit)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0 / 10.0)
	if Data.enemies() != original_enemies or Data.npcs() != original_npcs:
		_errors.append("Visual readers must leave shared catalogs unchanged")
	print("BOARD VISUAL METADATA RESULT: %s" % JSON.stringify({"workload_id": "all_authored_visual_metadata_v1", "fixtures": fixtures.size(), "batch_ms": samples, "semantic_digest": hash(expected), "semantic_errors": _errors}))
	board.free()
	quit(0 if _errors.is_empty() else 1)

func _read_metadata(board: Control, unit: Dictionary) -> Dictionary:
	return {"footprint": board.call("_resolved_unit_footprint", unit), "scale": board.call("_unit_art_scale", unit), "offset": board.call("_unit_art_offset", unit), "idle_seconds": board.call("_unit_idle_frame_seconds", unit)}
