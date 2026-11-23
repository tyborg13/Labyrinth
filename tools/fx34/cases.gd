extends RefCounted

const Witness = preload("res://tools/fx33/cases.gd")
const SPARK: String = "spark_dart"
const FINISHER: String = "quick_stab"
const FIRST_GEAR := Vector2i(4, 3)
const SECOND_GEAR := Vector2i(5, 4)
const FOG_GEAR := Vector2i(7, 1)
const FIRST_ID: String = "ward_kite"
const SECOND_ID: String = "iron_cleaver"
const BRANCH_TARGET := Vector2i(4, 2)
const BRANCH_HERO := Vector2i(5, 2)
const CONTACT_ON_TRUNK := Vector2i(6, 2)
const FOG_TRUNK := Vector2i(6, 2)
const FOG_RADIUS: int = 0
const FOG_HERO := Vector2i(5, 4)
const LIT_TRUNK := Vector2i(6, 3)
const CHAIN_CASES: Array[String] = ["spark", "branches", "fog_path"]
const GEAR_CASES: Array[String] = ["missed", "two_missed", "salvaged", "fog_gear"]
const NATIVE_CASES: Array[String] = ["spark", "missed"]

static func options(id: String, seed: int) -> Dictionary:
	var result: Dictionary = Witness.options("spark_conduction" if id in CHAIN_CASES else "tick", seed)
	if id == "branches":
		var positions: Array[Vector2i] = [Witness.PRIMARY, Witness.CONDUCTION_TARGET, BRANCH_TARGET, CONTACT_ON_TRUNK]
		result["enemy_positions"] = ",".join(positions.map(Witness.coord))
		result["enemy_types"] = "crawler,crawler,crawler,crawler"
		result["player_position"] = Witness.coord(BRANCH_HERO)
	if id == "fog_path": result["player_position"] = Witness.coord(FOG_HERO)
	if id in GEAR_CASES:
		result["enemy_positions"] = Witness.coord(Witness.TICK)
		result["enemy_types"] = "crawler"
	result["hand"] = SPARK if id in CHAIN_CASES else FINISHER
	return result

static func configure(id: String, state: Dictionary) -> void:
	Witness.configure("spark_conduction" if id in CHAIN_CASES else "tick", state)
	state["loot"] = []
	if id == "branches":
		for tile: Vector2i in [BRANCH_HERO, BRANCH_TARGET]:
			Witness.Surface.place(state, tile, "electrified")
	if id == "fog_path":
		_fog(state)
		state["umbra"]["light_sources"] = [
			{"id": 1, "pos": Witness.CONDUCTION_TARGET, "radius": FOG_RADIUS, "remaining_activations": -1},
			{"id": 2, "pos": LIT_TRUNK, "radius": FOG_RADIUS, "remaining_activations": -1},
		]
	if id not in GEAR_CASES: return
	# The finisher resolves a real victory with the same enemy and board.
	state["objective"] = {"type": "kill_all"}
	state["loot"].append(_equipment(FIRST_ID, FOG_GEAR if id == "fog_gear" else FIRST_GEAR))
	if id in ["two_missed", "salvaged"]: state["loot"].append(_equipment(SECOND_ID, SECOND_GEAR))
	if id == "fog_gear": _fog(state)

static func _fog(state: Dictionary) -> void:
	state["umbra"]["stage"] = "eclipse"
	state["umbra"]["light_sources"] = []
	state["umbra"]["vision_activations"] = 0

static func _equipment(id: String, tile: Vector2i) -> Dictionary:
	return {"id": "fx34_" + id, "kind": "equipment", "equipment_id": id, "pos": tile}
