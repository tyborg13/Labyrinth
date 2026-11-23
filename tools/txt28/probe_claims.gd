extends SceneTree
## Runtime scenarios copied from txt-25. F01 and F14 also compare the forecast.
const Combat = preload("res://scripts/combat_engine.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const Data = preload("res://scripts/game_data.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const KeywordRules = preload("res://scripts/card_keyword_rules.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const SurfaceCards = preload("res://scripts/surface_card_rules.gd")
const Fixture = preload("res://tests/suites/board_surface_suite.gd")
const NO_TARGET := Vector2i(-1, -1)
const HERO := Vector2i(2, 4)
const NEAR := Vector2i(3, 4)
const SECOND := Vector2i(4, 4)
const THIRD := Vector2i(5, 4)
const FOURTH := Vector2i(6, 4)
const FIFTH := Vector2i(7, 4)
const SIDE := Vector2i(2, 5)
const NORTH := Vector2i(2, 3)
const NORTH_PUSH_END := Vector2i(2, 1)
const FIXTURE_HP: int = 40
const TARGET_ID: int = 1
const SECOND_ID: int = 2
const TODO_DESIGN_grapple_terrain: Array = ["wooden_box", "raised_cover", "barrel", "dragon_spire", "bramble", "ice_pillar", "any other live terrain kind"]
const GRAPPLE_TERRAIN_FIXTURE: Array = ["crag_outcrop", "powder_keg", "wooden_crate", "crate", "wooden_box", "raised_cover", "barrel", "dragon_spire", "bramble", "ice_pillar", "_txt28_arbitrary"]

var _engine := Combat.new()
var _witnesses: int = 0
var _failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_placement()
	_force()
	_items()
	_special_targeting()
	_candidate_changes()
	print("TXT28 WITNESS RESULT: %s (%d witnesses, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _witnesses, _failures])
	quit(0 if _failures == 0 else 1)

func _fight(enemies: Array[Dictionary]) -> Dictionary:
	var state: Dictionary = Fixture.fixture(_engine)
	state["player"]["pos"] = HERO
	state["enemies"] = enemies
	for unit: Dictionary in enemies:
		unit["hp"] = FIXTURE_HP
		unit["max_hp"] = FIXTURE_HP
	return state

func _play(state: Dictionary, id: String, targets: Array[Vector2i]) -> Dictionary:
	state["deck"]["hand"].push_front(id)
	var working: Dictionary = _engine.prepare_player_card(state, 0, "play")
	var actions: Array = _engine.card_play_actions(id, working)
	var index: int = 0
	for action: Dictionary in actions:
		var tile: Vector2i = NO_TARGET
		if _engine.player_action_needs_target(action):
			var legal: Array[Vector2i] = _engine.valid_targets_for_player_action(working, action)
			if index >= targets.size() or not legal.has(targets[index]):
				_failures += 1
				print("TXT28 ILLEGAL FIXTURE %s/%s targets=%s legal=%s" % [id, action["type"], targets, legal])
				return working
			tile = targets[index]
			index += 1
		working = _engine.apply_player_action(working, action, tile)
	if index != targets.size():
		_failures += 1
		print("TXT28 UNUSED FIXTURE AIMS %s: %s" % [id, targets.slice(index)])
	return Commit.player_card(_engine, state, working, 0, actions, targets)

func _witness(id: String, holds: bool, detail: Dictionary) -> void:
	_witnesses += 1
	if not holds:
		_failures += 1
	print("TXT28 WITNESS %s %s %s" % [id, "PASS" if holds else "FAIL", JSON.stringify(detail)])

func _placement() -> void:
	var state: Dictionary = _fight([Fixture.enemy(TARGET_ID, SECOND)])
	var forecast: Dictionary = _forecast(state, "lodestone_reversal", SECOND)
	var after: Dictionary = _play(state, "lodestone_reversal", [SECOND])
	var pos: Vector2i = after["enemies"][0]["pos"]
	var ground: Array[Vector2i] = Ground.tiles(after, "electrified")
	_witness("F01", pos == NEAR and ground == [NEAR] and _same_force_outcome(forecast, after), {"enemy_destination": pos, "electrified": ground, "forecast": Ground.tiles(forecast, "electrified")})
	state = _fight([Fixture.enemy(TARGET_ID, SECOND), Fixture.enemy(SECOND_ID, NEAR)])
	forecast = _forecast(state, "lodestone_reversal", SECOND)
	after = _play(state, "lodestone_reversal", [SECOND])
	pos = after["enemies"][0]["pos"]
	ground = Ground.tiles(after, "electrified")
	_witness("F01-BLOCKED", pos == SECOND and ground == [SECOND] and _same_force_outcome(forecast, after), {"enemy_destination": pos, "electrified": ground, "forecast": Ground.tiles(forecast, "electrified")})
	for case: Array in [
		["F02", "ember_guard", "fire"],
		["F03", "ember_ward", "fire"],
		["F04", "static_ward", "electrified"],
		["F05", "stone_ward", "rubble"],
	]:
		state = _fight([Fixture.enemy(TARGET_ID, NEAR), Fixture.enemy(SECOND_ID, THIRD)])
		after = _play(state, case[1], [])
		ground = Ground.tiles(after, case[2])
		_witness(case[0], ground.has(NEAR) and not ground.has(THIRD) and ground.has(HERO) == (case[1] == "static_ward"), {"card": case[1], "adjacent": NEAR, "distant": THIRD, "painted": ground})
	state = _fight([Fixture.enemy(TARGET_ID, NEAR), Fixture.enemy(SECOND_ID, SIDE)])
	after = _play(state, "cinderweave_guard", [])
	ground = Ground.tiles(after, "fire")
	_witness("F06", ground.size() == 4 and ground.has(NEAR) and ground.has(SIDE) and after["enemies"][0]["hp"] == FIXTURE_HP - 2 and after["enemies"][1]["hp"] == FIXTURE_HP - 2, {"fire": ground, "enemy_hp": [after["enemies"][0]["hp"], after["enemies"][1]["hp"]]})

	state = _fight([Fixture.enemy(TARGET_ID, NEAR)])
	Ground.place(state, SIDE, "electrified")
	after = _play(state, "grounding", [])
	_witness("F10", not Ground.has_surface(after, SIDE, "electrified") and after["player"]["stoneskin"] == 6, {"empty_ground_removed": not Ground.has_surface(after, SIDE, "electrified"), "stoneskin": after["player"]["stoneskin"]})
	Ground.place(state, SIDE, "rubble")
	after = _play(state, "spike_mantle", [])
	_witness("F11", not Ground.has_rubble(after, SIDE) and after["player"]["stoneskin"] == 4, {"empty_ground_removed": not Ground.has_rubble(after, SIDE), "stoneskin": after["player"]["stoneskin"]})

func _force() -> void:
	var state: Dictionary = _fight([Fixture.enemy(TARGET_ID, NEAR), Fixture.enemy(SECOND_ID, NORTH)])
	var after: Dictionary = _play(state, "bottled_gale", [])
	var positions: Array = [after["enemies"][0]["pos"], after["enemies"][1]["pos"]]
	_witness("F07", positions[0] == FOURTH and positions[1] == NORTH_PUSH_END, {"start": [NEAR, NORTH], "end": positions, "aims": 0})
	state = _fight([Fixture.enemy(TARGET_ID, THIRD)])
	after = _play(state, "sleet_squall", [THIRD])
	_witness("F13", after["enemies"][0]["pos"] == FIFTH and after["enemies"][0]["hp"] == FIXTURE_HP - 3, {"aim_distance": 3, "hit_distance": 5, "enemy_hp": after["enemies"][0]["hp"]})
	state = _fight([Fixture.enemy(TARGET_ID, SECOND), Fixture.enemy(SECOND_ID, NEAR)])
	var plain: Dictionary = _play(state.duplicate(true), "snare_coil", [SECOND])
	state["relics"] = ["fetter_spikes"]
	var forecast: Dictionary = _forecast(state, "snare_coil", SECOND)
	var after_relic: Dictionary = _play(state.duplicate(true), "snare_coil", [SECOND])
	var plain_hit: int = _collision_damage(plain)
	var relic_hit: int = _collision_damage(after_relic)
	var immobilized: bool = after_relic["enemies"][0].get("immobilize", false)
	_witness("F14", plain_hit == 6 and relic_hit == plain_hit and immobilized and _same_force_outcome(forecast, after_relic), {"ordinary_collision": plain_hit, "collision_with_fetter_spikes": relic_hit, "forecast_collision": _collision_damage(forecast), "immobilized_after": immobilized})
	state["enemies"][0]["immobilize"] = true
	forecast = _forecast(state, "snare_coil", SECOND)
	after_relic = _play(state, "snare_coil", [SECOND])
	_witness("F14-PREEXISTING", _collision_damage(after_relic) == 2 * plain_hit and _same_force_outcome(forecast, after_relic), {"collision_with_fetter_spikes": _collision_damage(after_relic), "forecast_collision": _collision_damage(forecast)})
	# Director: the same Pull-then-Immobilize order holds for Anchor Slam.
	state = _fight([Fixture.enemy(TARGET_ID, SECOND), Fixture.enemy(SECOND_ID, NEAR)])
	var anchor_plain: Dictionary = _play(state.duplicate(true), "anchor_slam", [SECOND])
	state["relics"] = ["fetter_spikes"]
	var anchor_forecast: Dictionary = _forecast_type(state, "anchor_slam", SECOND, "pull")
	var anchor_relic: Dictionary = _play(state.duplicate(true), "anchor_slam", [SECOND])
	_witness("F14-ANCHOR", _collision_damage(anchor_plain) > 0 and _collision_damage(anchor_relic) == _collision_damage(anchor_plain) and anchor_relic["enemies"][0].get("immobilize", false) and _same_force_outcome(anchor_forecast, anchor_relic), {"ordinary_collision": _collision_damage(anchor_plain), "collision_with_fetter_spikes": _collision_damage(anchor_relic), "immobilized_after": anchor_relic["enemies"][0].get("immobilize", false), "forecast_collision": _collision_damage(anchor_forecast), "forecast_pos": anchor_forecast.get("enemies", [{}])[0].get("pos"), "actual_pos": anchor_relic["enemies"][0]["pos"]})

func _forecast(state: Dictionary, card_id: String, tile: Vector2i) -> Dictionary:
	state = state.duplicate(true)
	state["deck"]["hand"].push_front(card_id)
	var prepared: Dictionary = _engine.prepare_player_card(state, 0, "play")
	var actions: Array = _engine.card_play_actions(card_id, prepared)
	return _engine.surface_preview_for_player_action(prepared, actions[0], tile)["state"]

func _forecast_type(state: Dictionary, card_id: String, tile: Vector2i, action_type: String) -> Dictionary:
	state = state.duplicate(true)
	state["deck"]["hand"].push_front(card_id)
	var prepared: Dictionary = _engine.prepare_player_card(state, 0, "play")
	for action: Dictionary in _engine.card_play_actions(card_id, prepared):
		if str(action.get("type", "")) == action_type:
			return _engine.surface_preview_for_player_action(prepared, action, tile)["state"]
	return {}

func _same_force_outcome(forecast: Dictionary, resolved: Dictionary) -> bool:
	for index: int in range(forecast["enemies"].size()):
		for field: String in ["hp", "pos", "immobilize"]:
			if forecast["enemies"][index].get(field) != resolved["enemies"][index].get(field):
				return false
	return Ground.tiles(forecast, "electrified") == Ground.tiles(resolved, "electrified") and _collision_damage(forecast) == _collision_damage(resolved)

func _collision_damage(state: Dictionary) -> int:
	for event: Dictionary in state.get("surface_events", []):
		if event.get("kind") == "force_collision":
			return int(event["damage"])
	return 0

func _items() -> void:
	var state: Dictionary = _fight([Fixture.enemy(TARGET_ID, THIRD)])
	var after: Dictionary = _play(state, "caltrops", [SECOND])
	var consumed: bool = (after["deck"]["consumed"] as Array).has("caltrops")
	_witness("F08", consumed and after["grid"][SECOND.y][SECOND.x] == "stone" and Ground.has_rubble(after, SECOND), {"item_consumed": consumed, "tile": after["grid"][SECOND.y][SECOND.x], "rubble": Ground.has_rubble(after, SECOND)})
	after = _play(_fight([Fixture.enemy(TARGET_ID, THIRD)]), "powder_keg", [NEAR])
	var terrain: Dictionary = after["terrain"][0] if not after["terrain"].is_empty() else {}
	_witness("F09", terrain.get("kind") == "powder_keg" and terrain.get("pos") == NEAR, terrain)
	state = _fight([Fixture.enemy(TARGET_ID, SECOND)])
	state["relics"] = ["alchemists_retort"]
	var definition: Dictionary = Data.card_def_for_progression("jaw_trap", state)
	var rules: String = Display.resolved_rules_text("jaw_trap", state)
	after = _play(state, "jaw_trap", [SECOND])
	_witness("F25", rules == "Consume. Deal 3 damage at Range 2 and Immobilize." and after["enemies"][0]["hp"] == FIXTURE_HP - 3 and definition["actions"][0]["range"] == 2, {"inspection": rules, "range": definition["actions"][0]["range"], "enemy_hp": after["enemies"][0]["hp"]})
	_check_other_item_numbers()

func _check_other_item_numbers() -> void:
	var damage_number := RegEx.create_from_string("\\b(?:Deal|Bursts) ([0-9]+)\\b")
	var range_number := RegEx.create_from_string("\\bRange ([0-9]+)\\b")
	for id: String in Data.cards():
		var base: Dictionary = Data.card_def(id)
		var authored: String = base["description"]
		if not Data.card_is_item(id) or damage_number.search(authored) == null or range_number.search(authored) == null:
			continue
		for relics: Array in [["alchemists_retort"], ["quartermasters_ledger"], ["alchemists_retort", "quartermasters_ledger"]]:
			var state: Dictionary = {"relics": relics}
			var effective: Dictionary = Data.card_def_for_progression(id, state)
			var action: Dictionary = effective["actions"][0]
			var rows: Array = Display.for_card(id, state, effective)["summary_rows"]
			var detail: String = Display.rules_text(id, effective, rows)
			var damage: RegExMatch = damage_number.search(detail)
			var reach: RegExMatch = range_number.search(detail)
			var face: Dictionary = {}
			for row: Array in rows:
				for token: Dictionary in row:
					if token.get("field") in ["damage", "range"]:
						face[token["field"]] = Icons.token_value_text(token).to_int()
					elif token.get("icon") == "burst":
						face["damage"] = Icons.token_value_text(token).to_int()
			var damage_value: int = int(action.get("damage", action.get("burst_damage", 0)))
			var range_value: int = int(action["range"])
			var bound: bool = damage != null and reach != null and damage.get_string(1).to_int() == damage_value and reach.get_string(1).to_int() == range_value
			_witness("ITEM-" + id, bound and face.get("damage") == damage_value and face.get("range") == range_value, {"relics": relics, "inspection": detail, "face": face})

func _special_targeting() -> void:
	var state: Dictionary = _fight([Fixture.enemy(TARGET_ID, THIRD)])
	Ground.place(state, NEAR, "ice")
	state = _engine._create_umbra_light_source(state, FIFTH, {"radius": 1, "silent": true})
	var after: Dictionary = _play(state, "seek_the_light", [FIFTH])
	_witness("F12", after["player"]["pos"] == FIFTH, {"blink_distance": 5, "landed": after["player"]["pos"]})
	for case: Array in [["F15", "skybolt", 8], ["F16", "thunderstone", 5]]:
		state = _fight([Fixture.enemy(TARGET_ID, THIRD)])
		state["grid"][SECOND.y][SECOND.x] = "wall"
		var los: bool = _engine.combat_line_of_sight(state, HERO, THIRD)
		after = _play(state, case[1], [THIRD])
		_witness(case[0], not los and after["enemies"][0]["hp"] == FIXTURE_HP - case[2], {"line_of_sight": los, "enemy_hp": after["enemies"][0]["hp"]})
	state = _fight([Fixture.enemy(TARGET_ID, FIFTH)])
	after = _play(state, "meteorfall", [FOURTH])
	var marks: Array[Vector2i] = SurfaceCards.meteor_mark_tiles(_engine, after)
	after = SurfaceCards.resolve_meteor_marks(_engine, after)
	_witness("F17", marks.has(FIFTH) and after["enemies"][0]["hp"] == FIXTURE_HP - 8, {"aim_distance": 4, "marks": marks, "enemy_distance": 5, "enemy_hp": after["enemies"][0]["hp"]})
	_witness("F18", marks.has(FIFTH), {"aim_distance": 4, "marks": marks})
	_witness("F19", marks.has(FIFTH), {"aim_distance": 4, "mark_at_distance_5": FIFTH})
	for case: Array in [
		["F20", "cinder_wall", "fire", SECOND, THIRD],
		["F21", "frost_lane", "ice", THIRD, FOURTH],
		["F22", "lamp_oil", "fire", THIRD, FOURTH],
	]:
		state = _fight([Fixture.enemy(TARGET_ID, case[4])])
		after = _play(state, case[1], [case[3]])
		var ground: Array[Vector2i] = Ground.tiles(after, case[2])
		_witness(case[0], ground.has(case[4]), {"card": case[1], "aim": case[3], "affected": ground, "out_of_range": case[4]})
	state = _fight([Fixture.enemy(TARGET_ID, FIFTH)])
	after = _play(state, "earthen_rampart", [SECOND])
	var terrain_tiles: Array = (after["terrain"] as Array).map(func(piece: Dictionary) -> Vector2i: return piece["pos"])
	_witness("F23", terrain_tiles.has(THIRD), {"aim": SECOND, "outcrops": terrain_tiles, "out_of_range": THIRD})
	state = _fight([Fixture.enemy(TARGET_ID, FIFTH)])
	after = _play(state, "powder_keg", [NEAR])
	after = _play(after, "grapple", [SECOND])
	_witness("F24", after["player"]["pos"] == SECOND, {"only_adjacent_target": "powder_keg", "landed": after["player"]["pos"]})
	var accepted: Array = []
	var grapple: Dictionary = Data.card_def("grapple")["actions"][0]
	for kind: String in GRAPPLE_TERRAIN_FIXTURE:
		state = _fight([Fixture.enemy(TARGET_ID, FIFTH)])
		state["terrain"] = [{"id": "_txt28_anchor", "kind": kind, "pos": NEAR, "hp": 1}]
		if _engine.valid_targets_for_player_action(state, grapple).has(SECOND):
			accepted.append(kind)
	_witness("F24-TERRAIN", accepted == GRAPPLE_TERRAIN_FIXTURE, {"accepted": accepted, "TODO_DESIGN_grapple_terrain": TODO_DESIGN_grapple_terrain})

func _candidate_changes() -> void:
	var state: Dictionary = _fight([Fixture.enemy(TARGET_ID, FOURTH)])
	state["umbra"]["stage"] = "heart"
	for tile: Vector2i in [NEAR, SECOND, THIRD, FOURTH]:
		Ground.place(state, tile, "ice")
	var hidden: bool = not _engine.is_tile_visible_to_player(state, FOURTH)
	var after: Dictionary = _play(state, "frost_circuit", [NEAR])
	var converted: bool = Ground.has_surface(after, FOURTH, "electrified") and after["enemies"][0]["hp"] == FIXTURE_HP - 2
	_witness("CRD28-08-22", hidden and converted, {"hidden_before": hidden, "connected_tile": Ground.element_at(after, FOURTH), "enemy_hp": after["enemies"][0]["hp"]})
	_witness("F26", converted, {"aim_distance": 1, "hit_distance": 4, "enemy_hp": after["enemies"][0]["hp"]})
	state = _fight([Fixture.enemy(TARGET_ID, NEAR)])
	Ground.place(state, NEAR, "ice")
	after = _play(state, "white_silence", [])
	var delay: int = KeywordRules.stagger_applied_this_turn(after, TARGET_ID)
	_witness("CRD28-18", delay == 6 and after["enemies"][0]["hp"] == FIXTURE_HP - 6 and int(after["enemies"][0].get("freeze", 0)) == 0, {"enemy_hp": after["enemies"][0]["hp"], "freeze": after["enemies"][0].get("freeze", 0), "stagger": delay})
	state = _fight([Fixture.enemy(TARGET_ID, NEAR)])
	after = _play(state, "sun_flash", [HERO])
	var light: Array = after["umbra"]["light_sources"]
	_witness("CANDIDATE-LIGHT", light.size() == 1 and light[0]["radius"] == 2 and light[0]["remaining_activations"] == -1, {"light_sources": light})
