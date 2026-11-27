extends SceneTree

const Fight = preload("res://tools/crd33/fight.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const GuardianFixture = preload("res://tests/suites/guardian_suite.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")

const GRID_EDGE := 9
const OUTCROP := Vector2i(2, 4)
const OUTCROP_HP := 2
const CRAGHIDE_TILE := Vector2i(7, 1)
const HERO_TILE := Vector2i(2, 3)
const ENEMY_TILE := Vector2i(3, 4)
const ILLUSION_TILE := Vector2i(2, 5)
const ILLUSION_ID := 41


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fight := Fight.new()
	if not _witness_light(fight):
		quit(1)
		return
	quit(int(not _witness_groundsplit(fight)))


func _witness_light(fight: Fight) -> bool:
	var state: Dictionary = fight.fresh([Fight.NEAR])
	var beacon: Dictionary = fight.play(state, "beacon", [Fight.NEAR], true)
	if beacon.has("blocked"):
		push_error("Beacon did not resolve: " + str(beacon))
		return false
	var lit: Dictionary = beacon["after"]
	var before: int = int(lit["enemies"][0].get("expose", 0))
	var lit_turn: Dictionary = Commit.enemy_turn(fight.engine, lit, 0)
	var dark_turn: Dictionary = Commit.enemy_turn(fight.engine, state, 0)
	var after: int = int(lit_turn["state"]["enemies"][0].get("expose", 0))
	var unlit: int = int(dark_turn["state"]["enemies"][0].get("expose", 0))
	print("CRD34 LIGHT WITNESS: " + JSON.stringify({
		"enemy_tile_at_start": lit["enemies"][0]["pos"], "light": lit["umbra"]["light_sources"],
		"before": before, "after": after, "unlit_control": unlit,
	}))
	return before == 0 and after == 2 and unlit == 0


func _witness_groundsplit(fight: Fight) -> bool:
	# Keep txt-37's owned Outcrop and distance-one hero tile. Add the Crawler and
	# Illusion on distinct sides of the same Outcrop in the same resolution.
	var fixture := GuardianFixture.new()
	var state: Dictionary = fixture.guardian_fixture("craghide")
	state["grid"] = _open_grid()
	state["terrain"] = []
	state["player"]["pos"] = HERO_TILE
	state["enemies"].resize(1)
	var craghide: Dictionary = state["enemies"][0]
	craghide["pos"] = CRAGHIDE_TILE
	var crawler: Dictionary = fight.fresh([ENEMY_TILE])["enemies"][0]
	crawler["id"] = int(craghide["id"]) + 1
	state["enemies"].append(crawler)
	state["illusions"] = [{"id": ILLUSION_ID, "pos": ILLUSION_TILE, "hp": Fight.HEALTH, "max_hp": Fight.HEALTH}]
	var source: Dictionary = {"actor_kind": "enemy", "actor_id": craghide["id"]}
	if not Terrain.raise_outcrop(fight.engine, state, OUTCROP, OUTCROP_HP, source):
		push_error("Could not raise the owned Outcrop")
		return false
	fixture.set_cycle(fight.engine, state, 1)
	var intent: Dictionary = state["enemies"][0]["intent"]
	var forecast: Array = fight.engine.enemy_intent_plan(state, 0)["projected_attack"]
	if intent["id"] != "groundsplit" or not [HERO_TILE, ENEMY_TILE, ILLUSION_TILE].all(func(tile: Vector2i) -> bool: return forecast.has(tile)):
		push_error("Groundsplit did not forecast all three occupied tiles")
		return false
	var hero_before: int = int(state["player"]["hp"])
	var result: Dictionary = fight.engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var hero_loss: int = hero_before - int(result["player"]["hp"])
	var enemy_loss: int = Fight.HEALTH - int(result["enemies"][1]["hp"])
	var illusion_loss: int = Fight.HEALTH - int(result["illusions"][0]["hp"])
	print("CRD34 GROUNDSPLIT UNITS: " + JSON.stringify({
		"owned_outcrop": OUTCROP, "hero_tile": HERO_TILE, "enemy_tile": ENEMY_TILE,
		"illusion_tile": ILLUSION_TILE, "hero_damage": hero_loss,
		"enemy_damage": enemy_loss, "illusion_damage": illusion_loss,
	}))
	return hero_loss == int(intent["actions"][0]["damage"])


func _open_grid() -> Array:
	var grid: Array = []
	for y: int in range(GRID_EDGE):
		var row: Array = []
		for x: int in range(GRID_EDGE):
			row.append("wall" if x in [0, GRID_EDGE - 1] or y in [0, GRID_EDGE - 1] else "stone")
		grid.append(row)
	return grid
