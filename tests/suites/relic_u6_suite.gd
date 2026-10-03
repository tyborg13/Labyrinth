extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/illusion_relic_rules.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Fixture = preload("res://tests/suites/illusion_terrain_suite.gd")
static func run(expect: Callable) -> void:
	Fixture._install_fixtures()
	var engine := Combat.new()
	_test_shatter(engine, expect)
	_test_rattle(engine, expect)
	_test_puppet(engine, expect)
	_test_glassway(engine, expect)
	_test_triptych(engine, expect)
	_test_copper(engine, expect)
	_test_rebound(engine, expect)
	_test_integration_edges(engine, expect)
	Fixture._remove_fixtures()
static func state(engine: RefCounted, relics: Array = []) -> Dictionary:
	return Fixture._state(engine, [Fixture._enemy(1, Vector2i(4, 4), 30), Fixture._enemy(2, Vector2i(6, 4), 30), Fixture._enemy(3, Vector2i(7, 6), 30)], relics)
static func hp(engine: RefCounted, s: Dictionary, kind: String, id: int) -> int:
	return int(engine._surface_actor(s, kind, id).get("hp", 0))
static func preview_commit(engine: RefCounted, s: Dictionary, action: Dictionary, target: Vector2i, expect: Callable, label: String) -> Dictionary:
	var original: Dictionary = s.duplicate(true)
	var preview: Dictionary = engine.resolve_player_action_for_presentation(s, action, target)
	var commit: Dictionary = engine.apply_player_action(s, action, target)
	expect.call(preview["state"] == commit and s == original, label + " forecast equals commit and keeps source immutable")
	return commit
static func _test_shatter(e: RefCounted, check: Callable) -> void:
	var s: Dictionary = state(e, ["mirror_shard"])
	s = e._create_illusion(s, Vector2i(5, 4), 2)
	s["enemies"][0]["block"] = 2
	var before: Dictionary = s.duplicate(true)
	s = e._damage_illusion(s, 1, 1)
	check.call(hp(e, s, "enemy", 1) == 30, "Mirror Shard idle on a surviving illusion")
	s = e._damage_illusion(s, 1, 1)
	check.call(hp(e, s, "enemy", 1) == 29 and hp(e, s, "enemy", 2) == 27 and hp(e, s, "enemy", 3) == 30, "Mirror Shard hits each adjacent enemy once, through Block, not distant enemies")
	check.call(int(s.get("death_bonus_card_plays_this_turn", 0)) == 0, "Mirror Shard grants no card-hit kill play")
	var again: Dictionary = e._damage_illusion(s, 1, 5)
	check.call(hp(e, again, "enemy", 2) == 27, "Mirror Shard cannot trigger twice for one death")
	preview_commit(e, before, {"type": "destroy_illusion", "range": 5, "damage": 0}, Vector2i(5, 4), check, "Mirror Shard")
static func _test_rattle(e: RefCounted, check: Callable) -> void:
	var s: Dictionary = state(e, ["changelings_rattle"])
	s = e._create_illusion(s, Vector2i(3, 4), 2)
	s["current_actor"] = {"kind": "enemy", "id": 1}
	s["damage_context"] = {"actor_kind": "enemy", "actor_id": 1, "source_kind": "direct_attack", "player_card": false}
	var action: Dictionary = {"type": "melee", "damage": 1, "range": 1, "_enemy_id": 1}
	s = e._resolve_board_attack(s, action, Vector2i(3, 4), "enemy", 1)
	check.call(int(e._surface_actor(s, "enemy", 1).get("expose", 0)) == 0, "Rattle idle when enemy attack leaves illusion alive")
	var time_before: int = int(e._surface_actor(s, "enemy", 1).get("next_time", 0))
	s = e._resolve_board_attack(s, action, Vector2i(3, 4), "enemy", 1)
	check.call(int(e._surface_actor(s, "enemy", 1).get("expose", 0)) == 2, "Rattle exposes the enemy attack's destroyer")
	check.call(not e.stagger_delays_between({}, s).is_empty() or int(e._surface_actor(s, "enemy", 1).get("next_time", 0)) > time_before, "Rattle applies normal Stagger")
	var passive: Dictionary = state(e, ["changelings_rattle"])
	passive = e._create_illusion(passive, Vector2i(3, 4), 1)
	passive["damage_context"] = {"actor_kind": "enemy", "actor_id": 1, "source_kind": "surface_fire"}
	passive = e._damage_illusion(passive, 1, 2)
	check.call(int(e._surface_actor(passive, "enemy", 1).get("expose", 0)) == 0, "Rattle idle for passive damage")
	var turn_start: Dictionary = state(e, ["changelings_rattle"])
	turn_start = e._create_illusion(turn_start, Vector2i(3, 4), 1)
	turn_start["current_actor"] = {"kind": "enemy", "enemy_id": 1}
	turn_start["enemies"][0]["intent"] = {"id": "u6_bite", "name": "Bite", "time": 2, "actions": [{"type": "melee", "damage": 1, "range": 1}]}
	var original: Dictionary = turn_start.duplicate(true)
	var forecast: Dictionary = e.resolve_enemy_turn_with_steps(turn_start, 0, false)["state"]
	var commit: Dictionary = e.resolve_enemy_turn_with_steps(turn_start, 0, true)["state"]
	check.call(forecast == commit and turn_start == original, "Rattle revealed-enemy forecast equals committed turn and keeps source immutable")
	check.call(hp(e, commit, "illusion", 1) == 0 and int(e._surface_actor(commit, "enemy", 1).get("expose", 0)) == 2, "Rattle forecast includes attack destruction and destroyer status")
static func _test_puppet(e: RefCounted, check: Callable) -> void:
	var s: Dictionary = state(e, ["hollow_puppet"])
	s = e._create_illusion(s, Vector2i(3, 4), 5)
	var action: Dictionary = {"type": "push", "amount": 2, "damage": 99, "range": 3}
	check.call(e.valid_targets_for_player_action(s, action).has(Vector2i(3, 4)), "Puppet permits targeting an illusion")
	var result: Dictionary = preview_commit(e, s, action, Vector2i(3, 4), check, "Puppet")
	check.call(hp(e, result, "illusion", 1) == 0 and hp(e, result, "enemy", 1) == 25, "Puppet deals remaining health instead of collision or card damage")
	var marker: Dictionary = {}
	for event: Dictionary in result.get("surface_events", []):
		if str(event.get("kind", "")) == "force_collision": marker = event
	check.call(int(marker.get("damage", 0)) == 5 and int(marker.get("target_damage", -1)) == 0, "Puppet marker displays illusion health and no normal mover damage")
	var idle: Dictionary = s.duplicate(true); idle["relics"] = []
	check.call(not e.valid_targets_for_player_action(idle, action).has(Vector2i(3, 4)), "Illusions remain illegal force targets without Puppet")
	var rider: Dictionary = {"type": "ranged", "range": 3, "damage": 7, "push": 1}
	check.call(e.valid_targets_for_player_action(s, rider).has(Vector2i(3, 4)), "Puppet supports single-target attack riders")
	var pull: Dictionary = {"type": "pull", "range": 4, "amount": 2, "damage": 10}
	check.call(not e.valid_targets_for_player_action(s, pull).has(Vector2i(3, 4)), "Adjacent Pull cannot harm an illusion or pass through puller")
	var wall: Dictionary = state(e, ["hollow_puppet"])
	wall["player"]["pos"] = Vector2i(3, 2)
	wall = e._create_illusion(wall, Vector2i(2, 2), 9)
	wall = preview_commit(e, wall, action, Vector2i(2, 2), check, "Puppet wall")
	check.call(hp(e, wall, "illusion", 1) == 7 and wall["illusions"][0]["pos"] == Vector2i(1, 2), "Puppet wall collision obeys normal lost-tile damage")
static func _test_glassway(e: RefCounted, check: Callable) -> void:
	for type: String in ["move", "blink"]:
		var s: Dictionary = state(e, ["glassway_compass"])
		s = e._create_illusion(s, Vector2i(3, 4), 6)
		Surface.place(s, Vector2i(2, 4), "fire")
		Surface.place(s, Vector2i(3, 4), "fire")
		var action: Dictionary = {"type": type, "range": 2}
		check.call(e.valid_targets_for_player_action(s, action).has(Vector2i(3, 4)), "Glassway " + type + " may end on an illusion")
		var result: Dictionary = preview_commit(e, s, action, Vector2i(3, 4), check, "Glassway " + type)
		check.call(result["player"]["pos"] == Vector2i(3, 4) and result["illusions"][0]["pos"] == Vector2i(2, 4), "Glassway trades endpoint positions")
		var swaps: Array = (result.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "illusion_swapped")
		check.call(swaps.size() == 1 and swaps[0].get("from") == Vector2i(2, 4) and swaps[0].get("to") == Vector2i(3, 4), "Glassway " + type + " records the trade the board presents")
		if type == "move":
			var path: Array[Vector2i] = e.path_for_player_action(s, action, Vector2i(3, 4))
			var segments: Array[Dictionary] = preload("res://scripts/run_scene.gd").player_move_segments(s, path, swaps[0])
			check.call(not segments.is_empty() and segments[-1].get("blink_to") == Vector2i(3, 4) and segments[-1].get("exchange") == swaps[0], "Glassway Move presents the trade as a blink exchange, not a walk onto the Illusion")
		check.call(hp(e, result, "illusion", 1) == 4 and int(result["player"]["hp"]) == 22, "Glassway both arrivals trigger ground")
		var idle: Dictionary = s.duplicate(true); idle["relics"] = []
		idle = e.apply_player_action(idle, action, Vector2i(3, 4))
		check.call(hp(e, idle, "illusion", 1) == 0, "Glassway idle without relic preserves ordinary illusion dispel")
	# A Move trade teleports: the Fire on the tiles between is never entered.
	var far: Dictionary = state(e, ["glassway_compass"])
	far = e._create_illusion(far, Vector2i(3, 5), 4)
	Surface.place(far, Vector2i(2, 5), "fire")
	Surface.place(far, Vector2i(3, 4), "fire")
	var far_move: Dictionary = {"type": "move", "range": 2}
	var origin: Vector2i = far["player"]["pos"]
	var far_hp: int = int(far["player"]["hp"])
	check.call(e.valid_targets_for_player_action(far, far_move).has(Vector2i(3, 5)), "Glassway Move reaches an Illusion two tiles away")
	var far_path: Array[Vector2i] = e.path_for_player_action(far, far_move, Vector2i(3, 5))
	far = preview_commit(e, far, far_move, Vector2i(3, 5), check, "Glassway teleport")
	check.call(far_path.size() == 3 and far["player"]["pos"] == Vector2i(3, 5) and far["illusions"][0]["pos"] == origin and int(far["player"]["hp"]) == far_hp, "A Glassway Move trade skips the route: no Fire between, and the Illusion lands on the origin")
	var far_swaps: Array = (far.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "illusion_swapped")
	var far_segments: Array[Dictionary] = preload("res://scripts/run_scene.gd").player_move_segments(far, far_path, far_swaps[0] if not far_swaps.is_empty() else {})
	check.call(far_segments.size() == 1 and far_segments[0].get("blink_from") == origin and far_segments[0].get("blink_to") == Vector2i(3, 5), "A Glassway Move trade is presented as one exchange blink from the origin")
	_test_glassway_trade_edges(e, check)
	var corridor: Dictionary = state(e, ["glassway_compass"])
	corridor = e._create_illusion(corridor, Vector2i(3, 4), 2)
	var line: Dictionary = {"type": "move", "range": 4, "straight_line": true}
	check.call(not e.valid_targets_for_player_action(corridor, line).has(Vector2i(5, 4)), "Glassway cannot path through another illusion")
# Peer-review cases: a trade skips its route, so nothing on the route counts.
static func _test_glassway_trade_edges(e: RefCounted, check: Callable) -> void:
	var lane: Callable = func(relics: Array) -> Dictionary: return Fixture._state(e, [Fixture._enemy(1, Vector2i(6, 2), 30), Fixture._enemy(2, Vector2i(7, 2), 30)], relics)
	var wind: Dictionary = {"type": "move", "range": 3, "block_per_tile": 1}
	var s: Dictionary = lane.call(["glassway_compass"])
	s = e._create_illusion(s, Vector2i(2, 7), 4)
	var origin: Vector2i = s["player"]["pos"]
	s = preview_commit(e, s, wind, Vector2i(2, 7), check, "Glassway Catch the Wind")
	check.call(s["player"]["pos"] == Vector2i(2, 7) and int(s["player"].get("block", 0)) == 3 and origin == Vector2i(2, 4) and int(s["turn_flags"].get("tiles_moved", 0)) == 3, "A trade's per-tile Block counts its whole distance")
	var hidden: Dictionary = lane.call(["glassway_compass"])
	hidden["enemies"][0]["pos"] = Vector2i(2, 6)
	hidden["umbra"]["stage"] = "eclipse"
	hidden = e._create_illusion(hidden, Vector2i(2, 7), 4)
	hidden["umbra"]["light_sources"].append({"pos": Vector2i(2, 7), "radius": 0, "owner": "player", "remaining_activations": 3})
	check.call(e.valid_targets_for_player_action(hidden, {"type": "move", "range": 3}).has(Vector2i(2, 7)), "A lit Illusion beyond an unseen body is a trade target")
	hidden = e.apply_player_action(hidden, {"type": "move", "range": 3}, Vector2i(2, 7))
	check.call(hidden["player"]["pos"] == Vector2i(2, 7) and hidden["illusions"][0]["pos"] == origin and int(hidden["umbra"].get("movement_interrupted_total", 0)) == 0, "An unseen body on the skipped tiles cannot stop a trade")
	var detour: Dictionary = lane.call(["glassway_compass", "beaconrunner_spurs"])
	detour = e._create_illusion(detour, Vector2i(2, 6), 4)
	Surface.place(detour, Vector2i(2, 5), "fire")
	for tile: Vector2i in [Vector2i(1, 5), Vector2i(1, 6)]:
		detour["umbra"]["light_sources"].append({"pos": tile, "radius": 0, "owner": "player", "remaining_activations": 3})
	var route: Array[Vector2i] = e.path_for_player_action(detour, {"type": "move", "range": 4}, Vector2i(2, 6))
	check.call(route.size() == 3 and route.has(Vector2i(2, 5)), "A trade takes the cheapest route even through Fire it will never enter")
	var hp: int = int(detour["player"]["hp"])
	detour = preview_commit(e, detour, {"type": "move", "range": 4}, Vector2i(2, 6), check, "Glassway cheapest route")
	check.call(int(detour["player"]["hp"]) == hp and int(detour["turn_flags"].get(preload("res://scripts/surface_variety_relic_rules.gd").REFUNDS, 0)) == 0, "A trade takes no Fire and claims no Light refund for skipped tiles")

static func _test_triptych(e: RefCounted, check: Callable) -> void:
	var s: Dictionary = state(e, ["mirror_triptych"])
	for tile: Vector2i in [Vector2i(3, 3), Vector2i(3, 5), Vector2i(6, 5), Vector2i(1, 1)]: s = e._create_illusion(s, tile, 3)
	s["deck"]["hand"] = ["w4c_fx_shot", "w4c_fx_shot"]
	var action: Dictionary = {"type": "ranged", "range": 3, "damage": 5, "bleed": 9, "surface": "fire", "_card_id": "w4c_fx_shot"}
	var resolved: Dictionary = preview_commit(e, s, action, Vector2i(4, 4), check, "Triptych primary")
	var trace: Dictionary = {"echoes": []}
	var forecast: Dictionary = Rules.finish_echoes(e, resolved.duplicate(true), trace)
	var commit: Dictionary = e.finish_player_card(resolved, 0)
	check.call(hp(e, forecast, "enemy", 1) == hp(e, commit, "enemy", 1) and trace["echoes"].size() == 3, "Triptych forecasts three sequential half-damage echoes")
	check.call(hp(e, commit, "illusion", 1) == 2 and hp(e, commit, "illusion", 2) == 2 and hp(e, commit, "illusion", 3) == 2 and hp(e, commit, "illusion", 4) == 3, "Triptych nearest illusions wear down; cap excludes distant fourth")
	check.call(hp(e, commit, "enemy", 1) == 21 and hp(e, commit, "enemy", 2) == 28, "Triptych nearest targets take floor(5/2), without extra Fire or Bleed")
	var resumed: Dictionary = bytes_to_var(var_to_bytes(commit)) as Dictionary
	resumed = e.apply_player_action(resumed, action, Vector2i(4, 4))
	resumed = e.finish_player_card(resumed, 0)
	check.call(hp(e, resumed, "illusion", 1) == 2, "Triptych once per turn survives save/resume")
	var idle: Dictionary = state(e, ["mirror_triptych"])
	idle["deck"]["hand"] = ["w4c_fx_guard"]
	idle = e._create_illusion(idle, Vector2i(3, 3), 2)
	idle = e.finish_player_card(e.apply_player_action(idle, {"type": "block", "amount": 2, "_card_id": "w4c_fx_guard"}), 0)
	check.call(hp(e, idle, "illusion", 1) == 2, "Triptych idle for a nonattack card")
	# The animation consumes the same snapshots as each echoed Chain resolver.
	s = state(e, ["mirror_triptych"])
	s["enemies"][1]["pos"] = Vector2i(5, 4); s["enemies"][2]["pos"] = Vector2i(6, 4)
	s = e._create_illusion(s, Vector2i(3, 3), 3)
	s["deck"]["hand"] = ["w4c_fx_shot"]
	var chain: Dictionary = {"type": "ranged", "range": 4, "damage": 4, "chain": 1, "element": "lightning", "_card_id": "w4c_fx_shot"}
	resolved = e.apply_player_action(s, chain, Vector2i(4, 4))
	trace = {"echoes": []}
	forecast = Rules.finish_echoes(e, resolved.duplicate(true), trace)
	commit = e.finish_player_card(resolved, 0)
	check.call(forecast == commit or forecast["enemies"] == commit["enemies"], "Triptych captured Chain echo matches committed enemy state")
	var echo_hits: Array = trace["echoes"][0]["chain_hits"]
	check.call(echo_hits.size() == 3 and not (echo_hits[0].get("state", {}) as Dictionary).is_empty() and trace["echoes"][0]["choice"]["from"] == Vector2i(3, 3), "Triptych animation retains each Chain hit snapshot and illusion origin")
static func _test_copper(e: RefCounted, check: Callable) -> void:
	var s: Dictionary = state(e, ["copper_shod_staff"])
	s["enemies"][1]["pos"] = Vector2i(7, 4)
	s = e._create_illusion(s, Vector2i(6, 4), 3)
	s["terrain"] = [{"id": "outcrop_1", "kind": "crag_outcrop", "owner_kind": "player", "pos": Vector2i(5, 4), "hp": 4, "max_hp": 4, "blocks_sight": true}]
	for tile: Vector2i in [Vector2i(4, 4), Vector2i(7, 4)]: Surface.place(s, tile, "electrified")
	var action: Dictionary = {"type": "ranged", "range": 3, "damage": 4, "element": "lightning"}
	var result: Dictionary = preview_commit(e, s, action, Vector2i(4, 4), check, "Copper conduction")
	check.call(hp(e, result, "enemy", 2) == 26 and hp(e, result, "illusion", 1) == 3 and int(result["terrain"][0]["hp"]) == 4, "Copper conducts through outcrop and illusion without hurting them")
	check.call(not Surface.has_surface(result, Vector2i(5, 4), "electrified"), "Copper virtual tiles never create real ground")
	var idle: Dictionary = s.duplicate(true); idle["relics"] = []
	idle = e.apply_player_action(idle, action, Vector2i(4, 4))
	check.call(hp(e, idle, "enemy", 2) == 30, "Copper route absent without relic")
	var area: Dictionary = {"type": "aoe", "range": 4, "damage": 8, "pattern": [[0,0],[1,0],[2,0]], "element": "lightning"}
	result = e.apply_player_action(s, area, Vector2i(4, 4))
	check.call(int(result["terrain"][0]["hp"]) == 4, "Copper protects outcrop from direct Lightning")
static func _test_rebound(e: RefCounted, check: Callable) -> void:
	var s: Dictionary = state(e, ["storm_crown"])
	s["enemies"][1]["pos"] = Vector2i(5, 4); s["enemies"][2]["pos"] = Vector2i(6, 4)
	var action: Dictionary = {"type": "ranged", "range": 3, "damage": 5, "chain": 1, "bleed": 2, "element": "lightning"}
	var result: Dictionary = preview_commit(e, s, action, Vector2i(4, 4), check, "Crown")
	for id: int in [1,2,3]:
		check.call(hp(e, result, "enemy", id) == 23 and int(e._surface_actor(result, "enemy", id).get("bleed", 0)) == 2, "Crown rebounds once per enemy at floor half without reapplying riders")
	var trace: Array = e.resolve_player_action_for_presentation(s, action, Vector2i(4, 4))["chain_hits"]
	check.call(trace.size() == 6 and int(trace[3].get("enemy_id", -1)) == 3 and int(trace[-1].get("enemy_id", -1)) == 1, "Crown animation trace reverses route")
	var ordinary: Dictionary = action.duplicate(true); ordinary.erase("chain")
	result = e.apply_player_action(s, ordinary, Vector2i(4, 4))
	check.call(hp(e, result, "enemy", 1) == 25, "Crown idle on ordinary non-Chain Lightning")

static func _test_integration_edges(e: RefCounted, check: Callable) -> void:
	# A secondary relic shatter can kill, but never grants the card's extra play.
	var s: Dictionary = state(e, ["mirror_shard"])
	s["enemies"][0]["hp"] = 2
	s = e._create_illusion(s, Vector2i(3, 4), 1)
	s["damage_context"] = {"actor_kind": "player", "player_card": true, "source_kind": "direct_attack"}
	s = e._damage_illusion(s, 1, 1)
	check.call(hp(e, s, "enemy", 1) == 0 and int(s.get("death_bonus_card_plays_this_turn", 0)) == 0, "Mirror Shard lethal damage stays secondary relic damage")
	# Large footprints touch several neighbors, but shatter hits each actor once.
	s = state(e, ["mirror_shard"])
	s["enemies"][0]["footprint"] = Vector2i(2, 2)
	s = e._create_illusion(s, Vector2i(3, 4), 1)
	s = e._damage_illusion(s, 1, 1)
	check.call(hp(e, s, "enemy", 1) == 27, "Mirror Shard large footprints take one shatter hit")
	# Pull uses ordinary direction choice; health spent en route reduces its payload.
	s = state(e, ["hollow_puppet", "mirror_shard"])
	s["enemies"][0]["pos"] = Vector2i(5, 3)
	s = e._create_illusion(s, Vector2i(7, 3), 7)
	Surface.place(s, Vector2i(6, 3), "fire")
	var pull: Dictionary = {"type": "pull", "range": 7, "amount": 3, "damage": 99, "force_direction": Vector2i.LEFT}
	s = preview_commit(e, s, pull, Vector2i(7, 3), check, "Puppet Pull through Fire")
	check.call(hp(e, s, "illusion", 1) == 0 and hp(e, s, "enemy", 1) == 22, "Puppet collision uses five remaining health plus separate three-point Shard")
	# Illusion blockers still get the ordinary collision, and AOE has no extra targets.
	s = state(e, ["hollow_puppet"])
	s["enemies"][0]["pos"] = Vector2i(4, 2)
	s = e._create_illusion(s, Vector2i(3, 4), 9)
	s = e._create_illusion(s, Vector2i(4, 4), 9)
	s = preview_commit(e, s, {"type": "push", "range": 3, "amount": 2}, Vector2i(3, 4), check, "Puppet illusion blocker")
	check.call(hp(e, s, "illusion", 1) == 5 and hp(e, s, "illusion", 2) == 5, "Puppet preserves ordinary collision against another illusion")
	# Swap ordering is observable in Fire contact events, even when the illusion dies.
	s = state(e, ["glassway_compass", "mirror_shard"])
	s = e._create_illusion(s, Vector2i(3, 4), 1)
	Surface.place(s, Vector2i(2, 4), "fire")
	Surface.place(s, Vector2i(3, 4), "fire")
	var sequence: int = int(s.get("surface_event_sequence", 0))
	s = e.apply_player_action(s, {"type": "move", "range": 2}, Vector2i(3, 4))
	var contacts: Array[String]
	for event: Dictionary in s.get("surface_events", []):
		if int(event.get("sequence", 0)) > sequence and str(event.get("kind", "")) == "surface_damage": contacts.append(str(event.get("actor_kind", "")))
	check.call(contacts == ["illusion", "player"], "Glassway illusion ground entry precedes hero ground entry")
	check.call(hp(e, s, "illusion", 1) == 0 and s["player"]["pos"] == Vector2i(3, 4), "Glassway completes hero entry after origin hazard destroys illusion")
	# Save the pending first action and limit flag through the actual run store.
	var Store = preload("res://scripts/progression_store.gd")
	var old_path: String = Store._run_storage_path
	Store.set_run_storage_path("user://relic_u6_resume.save")
	s = state(e, ["mirror_triptych"])
	s = e._create_illusion(s, Vector2i(3, 3), 2)
	s["deck"]["hand"] = ["w4c_fx_shot", "w4c_fx_shot"]
	var attack: Dictionary = {"type": "ranged", "range": 3, "damage": 5, "_card_id": "w4c_fx_shot"}
	s = e.apply_player_action(s, attack, Vector2i(4, 4))
	Store.save_run_state({"mode": "combat", "combat_state": s})
	var resumed: Dictionary = Store.load_saved_run().get("combat_state", {}) as Dictionary
	check.call(resumed.get(Rules.PENDING, {}) == s.get(Rules.PENDING, {}), "Triptych pending first attack survives actual run save/resume")
	resumed = e.finish_player_card(resumed, 0)
	Store.save_run_state({"mode": "combat", "combat_state": resumed})
	resumed = Store.load_saved_run().get("combat_state", {}) as Dictionary
	resumed = e.finish_player_card(e.apply_player_action(resumed, attack, Vector2i(4, 4)), 0)
	check.call(hp(e, resumed, "illusion", 1) == 1, "Triptych saved consumed limit blocks a second attack card")
	Store.clear_saved_run()
	Store.set_run_storage_path(old_path)
	# A first card without a legal echo target still consumes the turn opportunity.
	s = state(e, ["mirror_triptych"])
	s["deck"]["hand"] = ["w4c_fx_shot", "w4c_fx_shot"]
	s = e._create_illusion(s, Vector2i(1, 1), 2)
	s = e.finish_player_card(e.apply_player_action(s, attack, Vector2i(4, 4)), 0)
	check.call(hp(e, s, "illusion", 1) == 2, "Triptych unreachable illusion spends no health")
	s = e._create_illusion(s, Vector2i(3, 3), 2)
	s = e.finish_player_card(e.apply_player_action(s, attack, Vector2i(4, 4)), 0)
	check.call(hp(e, s, "illusion", 2) == 2, "Triptych first-card limit is consumed even if no illusion echoes")
	s = e.prepare_next_player_turn(s)
	s["deck"]["hand"] = ["w4c_fx_shot"]
	s = e.finish_player_card(e.apply_player_action(s, attack, Vector2i(4, 4)), 0)
	check.call(hp(e, s, "illusion", 2) == 1, "Triptych resets for a fresh player turn")
	# Echo only the first attack; wait for all later card actions before selecting.
	s = state(e, ["mirror_triptych"])
	s = e._create_illusion(s, Vector2i(3, 3), 4)
	s["deck"]["hand"] = ["w4c_fx_shot"]
	s = e.apply_player_action(s, attack, Vector2i(4, 4))
	s = e.apply_player_action(s, {"type": "ranged", "range": 4, "damage": 9, "_card_id": "w4c_fx_shot"}, Vector2i(6, 4))
	check.call(hp(e, s, "illusion", 1) == 4, "Triptych waits until all actions finish")
	s = e.finish_player_card(s, 0)
	check.call(hp(e, s, "enemy", 1) == 23 and hp(e, s, "enemy", 2) == 21 and hp(e, s, "illusion", 1) == 3, "Triptych repeats only the first attack of a multiple-attack card")
	# Half after target damage modifiers; Expose and Freeze do not apply twice.
	s = state(e, ["mirror_triptych"])
	s["enemies"][1]["pos"] = Vector2i(5, 5)
	s["enemies"][1]["expose"] = 2; s["enemies"][1]["freeze"] = 1
	s = e._create_illusion(s, Vector2i(5, 6), 2)
	s["deck"]["hand"] = ["w4c_fx_shot"]
	s = e.finish_player_card(e.apply_player_action(s, attack, Vector2i(4, 4)), 0)
	check.call(hp(e, s, "enemy", 2) == 20, "Triptych halves full (5+2)*3 damage with floor rounding")
	# No surface or status rider is duplicated, but first-action forces are.
	s = state(e, ["mirror_triptych"])
	s["enemies"][0]["pos"] = Vector2i(4, 3)
	s = e._create_illusion(s, Vector2i(3, 3), 3)
	s["deck"]["hand"] = ["w4c_fx_shot"]
	var forced: Dictionary = attack.duplicate(true)
	forced["push"] = 1; forced["bleed"] = 4; forced["surface"] = "fire"
	s = e.finish_player_card(e.apply_player_action(s, forced, Vector2i(4, 3)), 0)
	check.call(s["enemies"][0]["pos"] == Vector2i(6, 3) and int(s["enemies"][0].get("bleed", 0)) == 4 and not Surface.has_surface(s, Vector2i(5, 3), "fire"), "Triptych echoes Push once, without Bleed or Fire rider")
	# Chain relay gaps require both virtual constructs; no real ground is authored.
	s = state(e, ["copper_shod_staff"])
	s["enemies"][1]["pos"] = Vector2i(8, 4)
	s["enemies"][2]["pos"] = Vector2i(8, 6)
	s = e._create_illusion(s, Vector2i(7, 4), 3)
	s["terrain"] = [{"id": "outcrop_1", "kind": "crag_outcrop", "owner_kind": "player", "pos": Vector2i(5, 4), "hp": 4, "max_hp": 4}]
	var bolt: Dictionary = {"type": "ranged", "range": 3, "damage": 4, "chain": 2, "element": "lightning"}
	var result: Dictionary = preview_commit(e, s, bolt, Vector2i(4, 4), check, "Copper Chain relays")
	check.call(hp(e, result, "enemy", 2) == 26 and hp(e, result, "enemy", 3) == 26, "Copper Chain relays across both outcrop and illusion")
	var saved_terrain: Array = s["terrain"]
	s["terrain"] = []
	Surface.place(s, Vector2i(5, 4), "fire")
	s["terrain"] = saved_terrain
	result = e.apply_player_action(s, bolt, Vector2i(4, 4))
	check.call(Surface.has_surface(result, Vector2i(5, 4), "fire"), "Copper virtual relay does not consume underlying Fire")
	var physical: Dictionary = bolt.duplicate(true); physical["element"] = "none"
	result = e.apply_player_action(s, physical, Vector2i(4, 4))
	check.call(hp(e, result, "enemy", 2) == 30, "Copper does not relay non-Lightning Chain")
	# No direct-hit amplification, riders or hop growth apply to the return.
	s = state(e, ["storm_crown", "resonant_clapper"])
	s["enemies"][1]["pos"] = Vector2i(5, 4); s["enemies"][2]["pos"] = Vector2i(6, 4)
	s["enemies"][0]["expose"] = 2; s["enemies"][0]["freeze"] = 1
	bolt["damage"] = 5; bolt["chain"] = 1
	result = preview_commit(e, s, bolt, Vector2i(4, 4), check, "Crown exact return")
	check.call(hp(e, result, "enemy", 1) == 0 and hp(e, result, "enemy", 2) == 21 and hp(e, result, "enemy", 3) == 18, "Crown half-damage return preserves original hop scaling and does not amplify again")
	# Pure conduction without native Chain never rebounds.
	s = state(e, ["storm_crown"])
	Surface.place(s, Vector2i(4, 4), "electrified")
	Surface.place(s, Vector2i(5, 4), "electrified")
	Surface.place(s, Vector2i(6, 4), "electrified")
	bolt.erase("chain")
	result = e.apply_player_action(s, bolt, Vector2i(4, 4))
	check.call(hp(e, result, "enemy", 1) == 25 and hp(e, result, "enemy", 2) == 25, "Crown does not rebound conduction-only attacks")
	# Area footprints can legally reach enemies beyond the clicked tile's range.
	s = state(e, ["mirror_triptych"])
	s["enemies"][0]["hp"] = 6
	s["enemies"][1]["pos"] = Vector2i(7, 4)
	s["enemies"][2]["pos"] = Vector2i(8, 7)
	s = e._create_illusion(s, Vector2i(5, 4), 3)
	s["deck"]["hand"] = ["w4c_fx_shot"]
	var area: Dictionary = {"type": "aoe", "range": 1, "damage": 6, "pattern": [[0, 0], [1, 0], [2, 0]], "_card_id": "w4c_fx_shot"}
	s = e.apply_player_action(s, area, Vector2i(3, 4))
	s = e.finish_player_card(s, 0)
	check.call(hp(e, s, "enemy", 2) == 27 and hp(e, s, "illusion", 1) == 2, "Triptych area footprint legally reaches beyond target range from illusion")
	# Detonate is an attack, but its echo repeats damage without consuming fuel.
	s = state(e, ["mirror_triptych"])
	s = e._create_illusion(s, Vector2i(6, 5), 4)
	s["deck"]["hand"] = ["w4c_fx_shot"]
	Surface.place(s, Vector2i(4, 4), "fire")
	Surface.place(s, Vector2i(6, 4), "fire")
	var detonate: Dictionary = {"type": "detonate", "range": 3, "damage": 4, "_card_id": "w4c_fx_shot"}
	s = e.finish_player_card(e.apply_player_action(s, detonate, Vector2i(4, 4)), 0)
	check.call(hp(e, s, "enemy", 1) == 26 and hp(e, s, "enemy", 2) == 28 and Surface.has_surface(s, Vector2i(6, 4), "fire"), "Triptych Detonate echo repeats half damage without consuming new fuel")
	# A pure force action is not the card's attack; its later damaging shot is.
	s = state(e, ["mirror_triptych"])
	s = e._create_illusion(s, Vector2i(3, 3), 4)
	s["deck"]["hand"] = ["w4c_fx_shot"]
	s = e.apply_player_action(s, {"type": "push", "range": 3, "amount": 1, "damage": 0, "_card_id": "w4c_fx_shot"}, Vector2i(4, 4))
	check.call(not s.has(Rules.PENDING), "Triptych pure Push does not claim first attack")
	s = e.finish_player_card(e.apply_player_action(s, attack, Vector2i(5, 4)), 0)
	check.call(hp(e, s, "illusion", 1) == 3, "Triptych echoes the first damaging action after pure Push")
	# An owned illusion is also a legal primary Lightning conductor target.
	s = state(e, ["copper_shod_staff"])
	s["enemies"][0]["pos"] = Vector2i(5, 4)
	s = e._create_illusion(s, Vector2i(3, 4), 4)
	Surface.place(s, Vector2i(4, 4), "electrified")
	Surface.place(s, Vector2i(5, 4), "electrified")
	var contact: Dictionary = {"type": "melee", "range": 1, "damage": 5, "element": "lightning"}
	check.call(e.valid_targets_for_player_action(s, contact).has(Vector2i(3, 4)), "Copper allows aiming Lightning at a useful virtual conductor")
	result = preview_commit(e, s, contact, Vector2i(3, 4), check, "Copper virtual primary")
	check.call(hp(e, result, "enemy", 1) == 25 and hp(e, result, "illusion", 1) == 4, "Copper virtual primary conducts damage while protecting the illusion")
