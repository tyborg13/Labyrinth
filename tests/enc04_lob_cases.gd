extends RefCounted
## A revealed, legal Lob remains selected while the hero walks adjacent.
const Fixture = preload("res://tests/suites/warband_orders_suite.gd")
const Base = preload("res://tests/suites/en04_enemies_suite.gd")
const CAPTAIN := Vector2i(5, 5)
const DECLARATION_DISTANCE: int = 2
const DECLARATION_SEED: int = 1
const REVIEW_BLOCK_OFFSETS: PackedInt32Array = [-1, 3]
const ADJACENT_DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func revealed_adjacent(engine: RefCounted, direction: Vector2i, side: int, blockers: String = "") -> Dictionary:
	var state: Dictionary = Fixture.battle("fire")
	state["enemies"].resize(1)
	state["enemies"][0]["pos"] = CAPTAIN
	state["player"]["pos"] = CAPTAIN + direction * DECLARATION_DISTANCE
	if not blockers.is_empty():
		for offset: int in REVIEW_BLOCK_OFFSETS:
			var tile: Vector2i = CAPTAIN + direction * offset
			if blockers == "wall": state["grid"][tile.y][tile.x] = "wall"
			else: state["terrain"].append(Base.terrain(tile))
	state["enemies"][0]["intent"] = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = DECLARATION_SEED
	engine._assign_enemy_intent(state, 0, rng)
	state["enemies"][0]["intent"]["barrage_side"] = side
	return {"declared": state, "adjacent": engine.apply_player_movement(state, CAPTAIN + direction)}
