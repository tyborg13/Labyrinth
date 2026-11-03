extends RefCounted
## Integration coverage for activation-end effects before room pressure.
const Combat = preload("res://scripts/combat_engine.gd")
const Fixtures = preload("res://tests/suites/snare_pressure_suite.gd")
const Pressure = preload("res://scripts/snare_pressure_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const TEST_LETHAL_HP: int = 2
const TEST_BLOCK: int = 2
const TEST_TICK_HP: int = 1
const TEST_CINDER_DESTINATION := Vector2i(5, 4)
const TEST_TICK_TILE := Vector2i(3, 4)

# Observe the real relic hook, without replacing any game rule or its result.
class ObservedCombat extends Combat:
	var preparation_results: Array[Dictionary]
	func _trigger_activation_end_relics(state: Dictionary) -> Dictionary:
		var result: Dictionary = super._trigger_activation_end_relics(state)
		preparation_results.append({"player": result["player"].duplicate(true), "enemies": result["enemies"].duplicate(true), "surfaces": result["surfaces"].duplicate(true)})
		return result

const En02 = preload("res://tests/suites/en02_enemies_suite.gd")

const Data = preload("res://scripts/game_data.gd")

const BoardScript = preload("res://scripts/combat_board_view.gd")

static func run(expect: Callable) -> void:
	_cinder_trail(expect)
	_presentation_projection(expect)
	_ghost_projection(expect)
	for biome: String in ["earth", "fire", "air", "ice", "lightning", "shadow"]:
		_end_turn_relics(expect, biome)
		_preparation_defeat(expect, biome)
	print("Snare pressure boundary regressions: Cinder Trail and six real Worldheart/death-burst preparation cases checked")

static func _cinder_trail(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Fixtures.battle("air")
	state["player"]["hp"] = TEST_LETHAL_HP
	for action: Dictionary in engine.card_play_actions("cinder_trail", state):
		state = engine.apply_player_action(state, action, TEST_CINDER_DESTINATION)
	expect.call(engine.ManeuverRules.player_fire_immune(state) and Surfaces.element_at(state, Fixtures.TEST_POSITIONS["hero"]) == "fire", "Real Cinder Trail arms Fireproof and leaves the return tile burning")
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = Pressure.preview(engine, state)["wind_preview"]
	var ended: Dictionary = engine.finish_player_activation(state)
	print("Snare Cinder Trail forecast HP=%d; outcome HP=%d" % [forecast["state"]["player"]["hp"], ended["player"]["hp"]])
	expect.call(int(ended["player"]["hp"]) == 0 and ended["player"]["pos"] == Fixtures.TEST_POSITIONS["hero"], "Headwind enters real Cinder Trail Fire after Fireproof expires")
	expect.call(forecast["state"]["player"] == ended["player"], "Lethal Cinder Trail headwind forecast equals completion")
	expect.call(state == before, "Boundary forecast never expires live flags or mutates the source")
	var batch: Dictionary = engine.resolve_enemy_phase(state)
	expect.call(batch["player"] == ended["player"], "Batch Snare completion expires Fireproof before the same lethal headwind")

static func _end_turn_relics(expect: Callable, biome: String) -> void:
	var engine := ObservedCombat.new()
	var state: Dictionary = Fixtures.battle(biome)
	# Worldheart's normal conversion kills a one-HP Ember Tick; its ordinary
	# death burst changes surfaces and damages the hero before any pressure.
	var tile: Vector2i = TEST_TICK_TILE
	if biome == "fire":
		tile = state["snare_entry"]
		state["player"]["pos"] = tile + Vector2i.RIGHT
	elif biome == "ice":
		tile = Pressure.approach_tiles(state)[0]
		state["player"]["pos"] = tile + Vector2i.DOWN
	state["relics"] = ["worldheart"]
	state["player"]["block"] = TEST_BLOCK
	state["enemies"][0]["type"] = "ember_tick"
	state["enemies"][0]["hp"] = TEST_TICK_HP
	state["enemies"][0]["block"] = 0
	state["enemies"][0]["stoneskin"] = 0
	state["enemies"][0]["pos"] = tile
	state["enemies"][0].erase("snare_sealbinder")
	state["objective"]["player_turns_completed"] = 0 if biome == "fire" else 1
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = Pressure.preview(engine, state)
	expect.call(engine.preparation_results.size() == 1, "Pressure forecast runs real activation-end preparation: " + biome)
	var preparation: Dictionary = engine.preparation_results[0] if not engine.preparation_results.is_empty() else {}
	var ended: Dictionary = engine.finish_player_activation(state)
	expect.call(int(ended["enemies"][0]["hp"]) == 0 and Surfaces.element_at(ended, tile) == "fire", "End-turn relic pulse and death burst precede pressure: " + biome)
	if not preparation.is_empty():
		expect.call(preparation == engine.preparation_results.back(), "Forecast and completion run identical real end-turn relic effects: " + biome)
	if biome == "fire": expect.call(not forecast["tiles"].has(tile), "Fire forecast excludes Fire created by end-turn death burst")
	elif biome == "air": expect.call(forecast["wind_preview"]["state"]["player"] == ended["player"], "Headwind includes converted Stoneskin and new Fire in its forecast")
	elif biome == "shadow": expect.call(forecast["radius"] == engine.effective_umbra_radius(ended), "Umbra shrinks after real end-turn preparation")
	else:
		for marked: Vector2i in forecast["tiles"]:
			if biome == "earth": expect.call(engine._terrain_index_at_tile(ended, marked) >= 0, "Prepared Upheaval marks equal completion")
	expect.call(state == before, "Real relic preparation forecast preserves source state: " + biome)

static func _preparation_defeat(expect: Callable, biome: String) -> void:
	var engine := Combat.new()
	var state: Dictionary = Fixtures.battle(biome)
	state["relics"] = ["worldheart"]
	state["player"]["hp"] = TEST_TICK_HP
	state["player"]["block"] = TEST_BLOCK
	state["enemies"][0].merge({"type": "ember_tick", "hp": TEST_TICK_HP, "block": 0, "stoneskin": 0, "pos": state["player"]["pos"] + Vector2i.LEFT}, true)
	state["objective"]["player_turns_completed"] = 1
	var forecast: Dictionary = Pressure.preview(engine, state)
	var ended: Dictionary = engine.finish_player_activation(state)
	expect.call(int(ended["player"]["hp"]) == 0 and ended["objective"]["player_turns_completed"] == 1, "Lethal activation-end death burst cancels the pressure boundary: " + biome)
	expect.call(forecast["tiles"].is_empty() and not forecast.has("wind_preview") and not forecast.has("radius"), "Forecast shows no pressure after lethal end-turn preparation: " + biome)
	expect.call(ended["snare_pressure"] == state["snare_pressure"], "No pressure state changes after preparation defeat: " + biome)

static func _presentation_projection(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Fixtures.battle("air")
	state["player"]["pos"] = state["snare_entry"]
	var forecast: Dictionary = Pressure.preview(engine, state)
	var expected: Dictionary = Pressure.presentation_projection(forecast)
	var board := preload("res://scripts/combat_board_view.gd").new()
	board.set_combat_state(state)
	expect.call(board.presentation["snare_pressure_preview"] == expected and expected.keys().size() == 3, "Pressure presentation contains only drawn tiles, paths and collision markers")
	var changed: Dictionary = state.duplicate(true)
	changed["analytics"] = {"combat_id": "scene_load", "combat_skill_event_revision_staged": 0, "combat_defiance_event_revision_staged": 0}
	board.set_combat_state(changed)
	expect.call(board.presentation["snare_pressure_preview"] == expected, "Scene-load analytics metadata cannot change the drawn pressure projection")
	var drawn: Dictionary = WindView.forecast(board)
	expect.call(not drawn.has("state") and not drawn.get("layers", [])[0].has("state"), "Room wind presentation and its memo omit resolver snapshots")
	expect.call(drawn["displacement_paths"] == expected["displacement_paths"] and drawn["collision_markers"] == expected["collision_markers"], "Room wind drawing consumes the shared prepared pressure projection")
	for marker: Dictionary in expected["collision_markers"]:
		expect.call(not marker.has("sequence") and not marker.has("source") and not marker.has("rules_version"), "Collision presentation omits event bookkeeping")
	# Compare against the resolver's own markers, not the projection helper.
	var raw: Array = (forecast.get("wind_preview", {}) as Dictionary).get("collision_markers", [])
	expect.call(not raw.is_empty() and raw.size() == (expected["collision_markers"] as Array).size(), "The headwind fixture forecasts collisions and projects each one")
	for index: int in range(mini(raw.size(), (expected["collision_markers"] as Array).size())):
		for field: String in ["tile", "blocked_tile", "damage", "actor_key"]:
			expect.call(expected["collision_markers"][index].get(field) == (raw[index] as Dictionary).get(field), "Collision projection keeps the resolver's " + field)
	for entry: Dictionary in preload("res://scripts/snare_pressure_view.gd")._memo._entries.values():
		expect.call(entry["result"].keys().size() == 3 and not entry["result"].has("wind_preview"), "Pressure memo retains only the drawn projection")
	board.free()
	# Room wind landing ghosts stand where the submitted prepared projection lands each
	# unit (the projection reflects end-turn preparation; wbv-01 draws ghosts, not arrows).
	var ghost_board := preload("res://scripts/combat_board_view.gd").new()
	ghost_board.combat_state = Fixtures.battle("air")
	var projection: Dictionary = Pressure.presentation_projection(Pressure.preview(engine, ghost_board.combat_state))
	ghost_board.presentation = {"snare_pressure_preview": projection}
	var landings: Array = []
	for path: Array in projection["displacement_paths"]: landings.append(path[-1])
	var ghost_tiles: Array = WindView.landing_ghosts(ghost_board).map(func(unit: Dictionary) -> Vector2i: return unit["pos"])
	landings.sort()
	ghost_tiles.sort()
	expect.call(not landings.is_empty() and ghost_tiles == landings, "Room wind landing ghosts stand where the prepared projection lands each unit")
	ghost_board.free()

# Snare room wind ghosts read the submitted prepared projection (selection,
# privacy, dedup and enemy-call layers); wbv-01 merge review cases.
static func _ghost_projection(expect: Callable) -> void:
	var board := BoardScript.new()
	var state: Dictionary = Fixtures.battle("air")
	state["illusions"] = [{"id": 77, "pos": Vector2i(5, 5), "hp": 1, "max_hp": 1}]
	board.combat_state = state
	var hero: Vector2i = state["player"]["pos"]
	var source_enemy: Dictionary = state["enemies"][0]
	var projection: Dictionary = {"tiles": [], "collision_markers": [], "displacement_paths": [[hero, hero + Vector2i.DOWN], [hero, hero + Vector2i.DOWN], [source_enemy["pos"], source_enemy["pos"] + Vector2i.UP], [Vector2i(5, 5), Vector2i(5, 6)]]}
	board.presentation = {"snare_pressure_preview": projection}
	expect.call(WindView._ghost_layers(board) == [projection], "The submitted projection replaces the active room wind layer")
	var ghosts: Array[Dictionary] = WindView.landing_ghosts(board)
	expect.call(ghosts.size() == 3 and ghosts.all(func(unit: Dictionary) -> bool: return not unit["wind_forecast"]), "Room projection ghosts cover hero, enemy and illusion, deduplicated")
	expect.call(ghosts.any(func(unit: Dictionary) -> bool: return str(unit["key"]).begins_with("wind_ghost_player_") and unit["pos"] == hero + Vector2i.DOWN), "Ghosts use the submitted landing, not a recalculated forecast")
	board.presentation["visible_enemy_ids"] = []
	expect.call(not WindView.landing_ghosts(board).any(func(unit: Dictionary) -> bool: return str(unit["key"]).begins_with("wind_ghost_enemy_")), "Room projection ghosts keep enemy privacy")
	board.presentation["umbra_visible_tiles"] = [hero]
	expect.call(not WindView.landing_ghosts(board).any(func(unit: Dictionary) -> bool: return str(unit["key"]).begins_with("wind_ghost_player_")), "Room projection ghosts skip unseen landings")
	board.presentation = {"snare_pressure_preview": projection, "displacement_paths": [[hero, hero + Vector2i.DOWN]]}
	expect.call(not WindView.landing_ghosts(board).any(func(unit: Dictionary) -> bool: return str(unit["key"]).begins_with("wind_ghost_player_")), "Room projection ghosts respect paths already drawn")
	var herald: Dictionary = En02.enemy(99, Vector2i(6, 7), 20, "gale_herald")
	for intent: Dictionary in Data.enemy_def("gale_herald")["intents"]:
		if str(intent["actions"][0]["type"]) == "call_wind":
			herald["intent"] = intent.duplicate(true)
			herald["intent"]["actions"][0]["_wind_direction"] = Vector2i.RIGHT
	state["enemies"].append(herald)
	board.presentation = {"snare_pressure_preview": projection}
	var dashed: Array = (WindView.forecast(board)["layers"] as Array).filter(func(layer: Dictionary) -> bool: return bool(layer["dashed"]))
	expect.call(not dashed.is_empty() and WindView._ghost_layers(board) == [projection] + dashed, "The room projection keeps every dashed enemy call layer")
	expect.call(WindView.landing_ghosts(board).any(func(unit: Dictionary) -> bool: return bool(unit["wind_forecast"])), "Enemy calls keep fainter forecast ghosts beside room ghosts")
	var same: Dictionary = (dashed[0] as Dictionary).duplicate(true)
	same.erase("dashed")
	board.presentation = {"snare_pressure_preview": same}
	var seen: Dictionary = {}
	var clean: bool = true
	for ghost: Dictionary in WindView.landing_ghosts(board):
		clean = clean and not seen.has(ghost["key"]) and not bool(ghost["wind_forecast"])
		seen[ghost["key"]] = true
	expect.call(clean, "Agreeing room and call landings dedupe and keep the solid tint")
	board.presentation = {}
	expect.call(WindView._ghost_layers(board) == WindView.forecast(board)["layers"], "Without a projection, ghosts use the full exact forecast")
	state["wind"] = {"direction": Vector2i.RIGHT, "rounds_left": 2, "source_id": 99, "push": 1}
	board.presentation = {"snare_pressure_preview": projection}
	expect.call(WindView._ghost_layers(board) == WindView.forecast(board)["layers"], "Enemy-sourced wind ignores the Snare projection")
	board.free()
	var still := BoardScript.new()
	still.combat_state = {}
	expect.call(not still._wind_ghost_inputs_changed({"snare_pressure_preview": true}), "Without wind, a pressure preview change keeps the unit cache")
	still.free()
