extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Glossary = preload("res://scripts/glossary.gd")
const GuardianFixture = preload("res://tests/suites/guardian_suite.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")

const GRID_EDGE: int = 9
const OUTCROP_HP: int = 2
const OUTCROPS: Array[Vector2i] = [Vector2i(2, 4), Vector2i(5, 4)]
const FOREIGN_OUTCROP := Vector2i(6, 6)
const FOREIGN_OWNER: int = 999
const WALL := Vector2i(2, 2)
const SOURCE_TILE := Vector2i(7, 1)
const TARGETS: Dictionary = {
	"distance 1": Vector2i(2, 3),
	"distance 2 axial": Vector2i(2, 6),
	"distance 2 diagonal": Vector2i(1, 3),
	"distance 2 from second Outcrop": Vector2i(6, 3),
	"overlap": Vector2i(4, 4),
	"distance 3": Vector2i(2, 1),
	"foreign-only": Vector2i(6, 7),
}

var _failed: bool


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var engine := Combat.new()
	var fixture := GuardianFixture.new()
	var baseline: Dictionary = fixture.guardian_fixture("craghide")
	baseline["grid"] = _grid()
	baseline["terrain"] = []
	baseline["enemies"].resize(1)
	var craghide: Dictionary = baseline["enemies"][0]
	craghide["pos"] = SOURCE_TILE
	baseline["player"]["pos"] = TARGETS["distance 3"]
	var owned_source: Dictionary = {"actor_kind": "enemy", "actor_id": craghide["id"]}
	for tile: Vector2i in OUTCROPS:
		_check(Terrain.raise_outcrop(engine, baseline, tile, OUTCROP_HP, owned_source), "Raise owned Outcrop")
	var foreign_source: Dictionary = {"actor_kind": "enemy", "actor_id": FOREIGN_OWNER}
	_check(Terrain.raise_outcrop(engine, baseline, FOREIGN_OUTCROP, OUTCROP_HP, foreign_source), "Raise foreign Outcrop")
	var expected_tiles: Array[Vector2i]
	for y: int in range(1, GRID_EDGE - 1):
		for x: int in range(1, GRID_EDGE - 1):
			var tile := Vector2i(x, y)
			var distance: int = mini(Paths.manhattan(tile, OUTCROPS[0]), Paths.manhattan(tile, OUTCROPS[1]))
			if distance in [1, 2] and tile != WALL:
				expected_tiles.append(tile)
	print("TXT37 GROUNDSPLIT GLOSSARY: " + Glossary.definition("terrain_burst"))
	var footprint: Array[Vector2i]
	for label: String in TARGETS:
		var tile: Vector2i = TARGETS[label]
		var state: Dictionary = baseline.duplicate(true)
		state["player"]["pos"] = tile
		fixture.set_cycle(engine, state, 1)
		var intent: Dictionary = state["enemies"][0]["intent"]
		var forecast: Array = engine.enemy_intent_plan(state, 0)["projected_attack"]
		_check(intent["id"] == "groundsplit", "Resolve the real Groundsplit intent")
		_check(forecast.size() == expected_tiles.size() and expected_tiles.all(
			func(position: Vector2i) -> bool: return forecast.has(position)), "Forecast matches the two-Outcrop footprint")
		if footprint.is_empty():
			footprint.assign(forecast)
		var hp: int = state["player"]["hp"]
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
		var loss: int = hp - int(result["player"]["hp"])
		var expected_loss: int = int(intent["actions"][0]["damage"]) if expected_tiles.has(tile) else 0
		_check(loss == expected_loss, "%s damage matches forecast" % label)
		print("TXT37 GROUNDSPLIT HIT: %s %s, HP lost %d" % [label, tile, loss])
	footprint.sort()
	print("TXT37 GROUNDSPLIT FOOTPRINT: %d tiles %s" % [footprint.size(), footprint])
	print("TXT37 GROUNDSPLIT: %s (%d live resolutions)" % ["FAIL" if _failed else "PASS", TARGETS.size()])
	quit(int(_failed))


func _grid() -> Array:
	var grid: Array = []
	for y: int in range(GRID_EDGE):
		var row: Array = []
		for x: int in range(GRID_EDGE):
			var edge: bool = x in [0, GRID_EDGE - 1] or y in [0, GRID_EDGE - 1]
			row.append("wall" if edge or Vector2i(x, y) == WALL else "stone")
		grid.append(row)
	return grid


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
