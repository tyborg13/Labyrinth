extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/guardian_combat_rules.gd")
const Original = preload("res://tests/fixtures/guardian_combat_rules_reference.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
var errors: Array[String]
var cases: int = 0

func _initialize() -> void:
	Parallel.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var engine := Combat.new()
	# All small floor graphs, including walls, isolated neighbors, cycles,
	# bridges, edge cells and blocked coordinates outside the board.
	for mask: int in range(512):
		var grid: Array = []
		for y: int in range(3):
			var row: Array = []
			for x: int in range(3): row.append("floor" if mask & (1 << (y * 3 + x)) else "wall")
			grid.append(row)
		var state: Dictionary = {"grid": grid, "terrain": []}
		for y: int in range(-1, 4):
			for x: int in range(-1, 4): _compare(engine, state, Vector2i(x, y))
		if mask % 128 == 0: await process_frame
	# Larger ragged boards and mutable terrain. Dead entries, absent HP/position,
	# duplicate positions and non-dictionary entries use original normalization.
	var rng := RandomNumberGenerator.new()
	rng.seed = 240718
	for iteration: int in range(240):
		var grid: Array = []
		for y: int in range(rng.randi_range(4, 13)):
			var row: Array = []
			for x: int in range(rng.randi_range(3, 15)):
				row.append(["floor", "rubble", "wall", "pillar", "door", "void"][rng.randi_range(0, 5)])
			grid.append(row)
		var terrain: Array = ["non-dictionary", {}, {"hp": 2}, {"pos": Vector2i(1, 1)}, {"pos": Vector2i(1, 1), "hp": -2}]
		for index: int in range(18): terrain.append({"pos": Vector2i(rng.randi_range(-1, 15), rng.randi_range(-1, 13)), "hp": rng.randi_range(-1, 4), "nested": {"unchanged": true}})
		var state: Dictionary = {"grid": grid, "terrain": terrain, "player": {"pos": Vector2i(1, 1)}, "enemies": [{"pos": Vector2i(2, 2), "hp": 9}], "illusions": [{"pos": Vector2i(3, 3), "hp": 2}]}
		for y: int in range(-1, grid.size() + 1):
			for x: int in range(-1, 16): _compare(engine, state, Vector2i(x, y))
		if iteration % 12 == 0: await process_frame
	print("STRUCTURAL ROUTE EQUIVALENCE RESULT: ", JSON.stringify({"cases": cases, "errors": errors}))
	quit(0 if errors.is_empty() else 1)

func _compare(engine: RefCounted, state: Dictionary, blocked: Vector2i) -> void:
	var before: Dictionary = state.duplicate(true)
	var expected: bool = Original.preserves_routes(engine, state, blocked)
	var actual: bool = Rules.preserves_routes(engine, state, blocked)
	cases += 1
	if actual != expected: errors.append("Connectivity differed at %s in %s" % [blocked, state])
	if state != before: errors.append("Connectivity query mutated its caller")
