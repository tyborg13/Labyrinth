extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")


static func run(expect: Callable) -> void:
	_test_natural_unit_migration(expect)
	_test_natural_and_ambiguous_saves_are_not_rescaled(expect)
	_test_elemental_board_save_repair(expect)
	_test_defiance_capacity_and_mid_run_growth(expect)
	_test_defiance_trigger_and_phoenix_payoff(expect)
	_test_defiance_feedback_does_not_require_block_loss(expect)
	_test_last_reserve_precedes_defiance(expect)
	_test_every_boss_victory_restores_health(expect)
	_test_sustain_is_bounded(expect)
	_test_outward_route_appears_after_three_rooms(expect)


static func _test_natural_unit_migration(expect: Callable) -> void:
	var legacy: Dictionary = {
		"run_content_schema": 2,
		"player_hp": 235,
		"player_max_hp": 360,
		"heal_bonus": 15,
		"run_stats": {"damage_dealt": 105, "damage_received": 94},
		"pending_reward": {"heal_amount": 60},
		"current_room_layout": {
			"player": {"hp": 235, "max_hp": 360, "block": 11},
			"terrain": [{"hp": 25, "max_hp": 30}],
			"loot": [{"kind": "healing_vial", "amount": 41}]
		},
		"combat_state": {
			"player": {
				"hp": 9,
				"max_hp": 360,
				"block": 41,
				"stoneskin": 11,
				"poison": {"damage": 11, "trigger": 21, "stacks": []}
			},
			"enemies": [{
				"id": 1,
				"type": "crawler",
				"hp": 91,
				"max_hp": 140,
				"block": 41,
				"intent": {"actions": [{"type": "melee", "damage": 79, "range": 3}]}
			}],
			"traps": [{"damage": 65, "burn": 11}],
			"loot": [
				{"kind": "healing_vial", "amount": 41},
				{"kind": "ember_cache", "amount": 40}
			],
			"deck": {"fatigue_base": 15},
			"run_stats": {"damage_dealt": 105, "damage_received": 94}
		},
		"pending_combat_checkpoints": [{
			"state": {"player": {"hp": 1, "max_hp": 360}}
		}]
	}
	var migrated: Dictionary = RunEngine.migrate_combat_units(legacy)
	expect.call(int(migrated.get("combat_units_schema", 0)) == RunEngine.COMBAT_UNITS_SCHEMA, "Legacy saves should stamp the natural-unit schema")
	expect.call(int(migrated.get("player_hp", 0)) == 24 and int(migrated.get("player_max_hp", 0)) == 36, "Legacy outer health should preserve survivability when converted to natural units")
	expect.call(int((migrated.get("run_stats", {}) as Dictionary).get("damage_dealt", 0)) == 11, "Cumulative legacy damage should use nearest-unit rounding")
	expect.call(int((migrated.get("run_stats", {}) as Dictionary).get("damage_received", 0)) == 9, "Cumulative legacy received damage should use nearest-unit rounding")
	expect.call(int((migrated.get("pending_reward", {}) as Dictionary).get("heal_amount", 0)) == 6, "Pending legacy healing should convert with survivor rounding")
	var combat_state: Dictionary = migrated.get("combat_state", {}) as Dictionary
	var player: Dictionary = combat_state.get("player", {}) as Dictionary
	var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[0] as Dictionary
	var intent_action: Dictionary = (((enemy.get("intent", {}) as Dictionary).get("actions", []) as Array)[0] as Dictionary)
	expect.call(int(player.get("hp", 0)) == 1 and int(player.get("block", 0)) == 5 and int(player.get("stoneskin", 0)) == 2, "Active combat survivors and defenses should round upward")
	expect.call(not player.has("poison"), "Retired actor Poison should be removed rather than carried into the board-effect ruleset")
	expect.call(int(enemy.get("hp", 0)) == 10 and int(enemy.get("max_hp", 0)) == 14, "Enemy health should migrate with survivor rounding")
	expect.call(int(intent_action.get("damage", 0)) == 8 and int(intent_action.get("range", 0)) == 3, "Nested intent damage should migrate without changing distance fields")
	var loot: Array = combat_state.get("loot", []) as Array
	expect.call(not ((combat_state.get("traps", []) as Array)[0] as Dictionary).has("burn"), "Retired trap Burn payloads should be removed during migration")
	expect.call(int((loot[0] as Dictionary).get("amount", 0)) == 5, "Battlefield healing should migrate to natural units")
	expect.call(int((loot[1] as Dictionary).get("amount", 0)) == 40, "Non-combat currencies must not be rescaled")
	expect.call(RunEngine.migrate_combat_units(migrated) == migrated, "Natural-unit migration should be idempotent")


static func _test_natural_and_ambiguous_saves_are_not_rescaled(expect: Callable) -> void:
	var natural: Dictionary = {
		"run_content_schema": 0,
		"player_hp": 7,
		"player_max_hp": 24,
		"combat_state": {"player": {"hp": 7, "max_hp": 24}}
	}
	var migrated_natural: Dictionary = RunEngine.migrate_combat_units(natural)
	expect.call(int(migrated_natural.get("player_hp", 0)) == 7, "Pre-schema saves with natural health evidence should retain their values")
	var conflict: Dictionary = {
		"run_content_schema": 0,
		"player_hp": 7,
		"player_max_hp": 24,
		"combat_state": {"player": {"hp": 70, "max_hp": 240}}
	}
	var migrated_conflict: Dictionary = RunEngine.migrate_combat_units(conflict)
	expect.call(int(migrated_conflict.get("player_hp", 0)) == 7, "Conflicting unit evidence should preserve outer values")
	expect.call(int(((migrated_conflict.get("combat_state", {}) as Dictionary).get("player", {}) as Dictionary).get("max_hp", 0)) == 240, "Conflicting unit evidence should preserve nested values")
	expect.call(int(migrated_conflict.get("combat_units_schema", 0)) == RunEngine.COMBAT_UNITS_SCHEMA, "Ambiguous saves should still be stamped to avoid repeated destructive guesses")


static func _test_elemental_board_save_repair(expect: Callable) -> void:
	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(9941, ProgressionStore.default_data())
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(9942, {
		"name": "Legacy board repair",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 14, "max_hp": 14}],
		"terrain": [],
		"traps": [{"id": 1, "pos": Vector2i(3, 4), "damage": 2, "burn": 3}],
		"loot": [],
	}, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
	})
	combat_state["elemental_intensity"] = {"fire": 3}
	(combat_state.get("player", {}) as Dictionary)["burn"] = 2
	var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[0] as Dictionary
	enemy["shock"] = 1
	enemy["committed_intent_plan"] = {"schema": 0, "intent_signature": -1}
	(combat_state.get("enemies", []) as Array)[0] = enemy
	combat_state["tile_effects"] = {
		"fields": [{"pos": Vector2i(2, 3), "kind": "corruption", "expires_at": 21}],
		"surfaces": [{"pos": Vector2i(4, 4), "kind": "electrified", "expires_at": 19}],
	}
	run_state["run_content_schema"] = 2
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state.duplicate(true)
	run_state["pending_reward"] = {"board_state": combat_state.duplicate(true)}
	run_state["pending_combat_checkpoints"] = [{"state": combat_state.duplicate(true)}]
	var repaired: Dictionary = run_engine.repair_loaded_run_state(run_state)
	var repaired_combat: Dictionary = repaired.get("combat_state", {}) as Dictionary
	var repaired_enemy: Dictionary = (repaired_combat.get("enemies", []) as Array)[0] as Dictionary
	expect.call(not repaired_combat.has("elemental_intensity") and not (repaired_combat.get("player", {}) as Dictionary).has("burn") and not repaired_enemy.has("shock"), "Loaded combat should strip retired intensity and actor statuses")
	expect.call(int((repaired_enemy.get("committed_intent_plan", {}) as Dictionary).get("schema", 0)) == 1, "Loaded enemies should recommit current intent geometry")
	expect.call(((repaired_combat.get("tile_effects", {}) as Dictionary).get("fields", []) as Array).size() == 1 and ((repaired_combat.get("tile_effects", {}) as Dictionary).get("surfaces", []) as Array).size() == 1, "Loaded combat should preserve valid Field and Surface entries")
	var reward_board: Dictionary = ((repaired.get("pending_reward", {}) as Dictionary).get("board_state", {}) as Dictionary)
	var checkpoints: Array = repaired.get("pending_combat_checkpoints", []) as Array
	var checkpoint_state: Dictionary = ((checkpoints[0] as Dictionary).get("state", {}) as Dictionary)
	expect.call(not reward_board.has("elemental_intensity") and not checkpoint_state.has("elemental_intensity"), "Held reward boards and combat checkpoints should receive the same elemental-board repair")
	var checkpoint_enemy: Dictionary = (checkpoint_state.get("enemies", []) as Array)[0] as Dictionary
	expect.call(int((checkpoint_enemy.get("committed_intent_plan", {}) as Dictionary).get("schema", 0)) == 1, "Repaired checkpoints should recommit enemy geometry before resume")


static func _test_defiance_capacity_and_mid_run_growth(expect: Callable) -> void:
	var expected_by_level: Dictionary = {
		1: 0,
		3: 0,
		4: 1,
		7: 1,
		8: 2,
		12: 3,
		16: 4,
		20: 5
	}
	for level_var: Variant in expected_by_level.keys():
		var level: int = int(level_var)
		expect.call(
			ProgressionStore.defiance_capacity_for_level(level) == int(expected_by_level[level]),
			"Level %d should grant the documented bounded Defiance capacity" % level
		)
	var engine := RunEngine.new()
	var profile: Dictionary = ProgressionStore.default_data()
	profile["level"] = 3
	var run_state: Dictionary = engine.create_new_run(290731, profile)
	expect.call(engine.defiance_capacity(run_state) == 0 and engine.defiance_remaining(run_state) == 0, "A level-three run should begin without Defiance")
	profile["level"] = 4
	run_state = engine.apply_progression_update(run_state, profile)
	expect.call(engine.defiance_capacity(run_state) == 1 and engine.defiance_remaining(run_state) == 1, "Reaching a milestone mid-run should grant only its new charge")
	run_state["defiance_remaining"] = 0
	profile["level"] = 7
	run_state = engine.apply_progression_update(run_state, profile)
	expect.call(engine.defiance_remaining(run_state) == 0, "Ordinary levels must not refill spent Defiance")
	profile["level"] = 8
	run_state = engine.apply_progression_update(run_state, profile)
	expect.call(engine.defiance_capacity(run_state) == 2 and engine.defiance_remaining(run_state) == 1, "A later milestone should add one charge without refilling earlier spent charges")
	run_state["mode"] = "relic"
	run_state["pending_relics"] = ["phoenix_ember"]
	run_state = engine.claim_relic(run_state, "phoenix_ember")
	expect.call(engine.defiance_capacity(run_state) == 3 and engine.defiance_remaining(run_state) == 2, "Phoenix Ember should add one run-only Defiance charge")


static func _test_defiance_trigger_and_phoenix_payoff(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(290732, _combat_layout(), {
		"hp": 5,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"hand_size": 1,
		"defiance_capacity": 1,
		"defiance_remaining": 1,
		"skill_ids": ["pain_remembers"],
		"relics": ["phoenix_ember"]
	})
	state = combat.call("_damage_player", state, 7, true, true, "enemy_attack", false)
	expect.call(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 6, "Defiance should restore 25% of 24 maximum health after lethal damage")
	expect.call(int(state.get("defiance_remaining", -1)) == 0, "A lethal recovery should spend exactly one Defiance charge")
	expect.call(bool((state.get("skill_flags", {}) as Dictionary).get("pain_recall_primed", false)), "Defiance restoration should not hide the health loss from Pain Remembers")
	var events: Array[Dictionary] = combat.defiance_events(state)
	expect.call(events.size() == 1 and int(events[0].get("restored_hp", 0)) == 6, "Defiance should append one revisioned restoration event")
	expect.call(str(events[0].get("cause", "")) == "enemy_attack" and int(events[0].get("lethal_hp_loss", 0)) == 5, "Defiance analytics ingredients should retain the lethal cause and actual remaining HP loss")
	var enemy: Dictionary = ((state.get("enemies", []) as Array)[0] as Dictionary)
	expect.call(int(enemy.get("hp", 0)) == int(enemy.get("max_hp", 0)) - GameData.fixed_point_amount(6), "Phoenix Ember should immediately damage every live enemy when Defiance triggers")
	state = combat.call("_damage_player", state, 7, true, true, "enemy_attack", false)
	expect.call(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 0, "Lethal damage should end the run after all Defiance charges are spent")
	expect.call(combat.defiance_events(state).size() == 1, "Lethal damage without a charge should not append a false Defiance event")


static func _test_defiance_feedback_does_not_require_block_loss(expect: Callable) -> void:
	var scene: RunScene = RunScene.new()
	var floats: Array[Dictionary] = scene.call("_floating_texts_for_target_losses", [{
		"kind": "player",
		"tile": Vector2i(2, 4),
		"hp_loss": 5,
		"block_loss": 0,
		"stoneskin_loss": 0,
		"defiance_restored": 6,
		"defiance_remaining": 1,
	}])
	var found_defiance: bool = false
	for entry: Dictionary in floats:
		if str(entry.get("text", "")).begins_with("DEFIANCE +6"):
			found_defiance = true
			break
	expect.call(found_defiance, "Defiance restoration feedback should render even when the lethal hit removed no block")
	scene.free()


static func _test_last_reserve_precedes_defiance(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(290733, _combat_layout(), {
		"hp": 1,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"hand_size": 1,
		"skill_ids": ["last_reserve"],
		"defiance_capacity": 1,
		"defiance_remaining": 1
	})
	state["player"]["hp"] = 1
	state["deck"] = {
		"draw": [],
		"hand": [],
		"discard": ["quick_stab"],
		"burned": [],
		"consumed": [],
		"cycles": 0,
		"fatigue_base": CombatEngine.FATIGUE_BASE_DAMAGE
	}
	state = combat.call("_draw_cards_in_place", state, 1)
	expect.call(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 1, "Last Reserve should catch the first lethal Fatigue at one health")
	expect.call(int(state.get("defiance_remaining", 0)) == 1, "Last Reserve should resolve before and preserve Defiance")
	expect.call(combat.skill_was_used(state, "last_reserve"), "Last Reserve should spend its once-per-combat use")
	state["deck"] = {
		"draw": [],
		"hand": [],
		"discard": ["quick_stab"],
		"burned": [],
		"consumed": [],
		"cycles": 1,
		"fatigue_base": CombatEngine.FATIGUE_BASE_DAMAGE
	}
	state = combat.call("_draw_cards_in_place", state, 1)
	expect.call(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 6, "A later lethal Fatigue should fall through to Defiance")
	expect.call(int(state.get("defiance_remaining", -1)) == 0, "The fallback Defiance recovery should spend its charge")
	expect.call(str(combat.defiance_events(state)[0].get("cause", "")) == "fatigue", "Fatigue-triggered Defiance should retain its cause")


static func _test_every_boss_victory_restores_health(expect: Callable) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(290736, ProgressionStore.default_data())
	var boss_coord := Vector2i(8, 0)
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["8,0"] = {
		"coord": boss_coord,
		"depth": 8,
		"type": "boss",
		"element": "fire",
		"revealed": true,
		"visited": true,
		"cleared": false,
		"sealed": false,
	}
	state["rooms"] = rooms
	state["current_room"] = boss_coord
	state["mode"] = "combat"
	state["player_hp"] = 5
	state["player_max_hp"] = 24
	state[RunEngine.SKILL_STATE_KEY] = {"moltshard_awarded": true}
	var defeated_boss: Dictionary = {
		"player": {"hp": 5, "max_hp": 24, "pos": Vector2i(2, 4)},
		"enemies": [],
		"room_name": "Later Boss Recovery Test",
		"room_coord": boss_coord,
		"room_depth": 8,
		"room_type": "boss",
		"room_element": "fire",
		"room_embers": 0,
		"grid": _combat_layout().get("grid", []),
		"moss": {},
		"loot": [],
		"traps": [],
		"terrain": [],
		"collected_equipment": [],
		"missed_equipment": [],
		"run_stats": CombatEngine.normalized_run_stats({}),
	}
	var resolved: Dictionary = engine.finish_combat(state, defeated_boss)
	expect.call(int(resolved.get("player_hp", 0)) == 11, "Every boss should restore 25% max HP, even after the one-time Moltshard has already been awarded")
	expect.call(ProgressionStore.moltshard_count(resolved.get("progression", {}) as Dictionary) == 0, "Later-boss recovery should not duplicate the first-boss Moltshard")


static func _test_sustain_is_bounded(expect: Callable) -> void:
	var generator := RoomGenerator.new()
	var healing_rooms: int = 0
	for seed: int in range(200):
		var room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(2, 0),
			"depth": 2,
			"type": "combat",
			"element": "fire"
		}, Vector2i(1, 0))
		var utility_loot: Array = []
		for loot_var: Variant in room.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot: Dictionary = loot_var as Dictionary
			if str(loot.get("kind", "")) in ["healing_vial", "rusty_shield"]:
				utility_loot.append(loot)
		expect.call(utility_loot.size() == 1, "Normal combat rooms should contain exactly one utility pickup")
		if utility_loot.size() == 1:
			var utility: Dictionary = utility_loot[0] as Dictionary
			if str(utility.get("kind", "")) == "healing_vial":
				healing_rooms += 1
				expect.call(int(utility.get("amount", 0)) == 2, "Healing vials should restore two natural HP")
			else:
				expect.call(int(utility.get("amount", 0)) == 3, "Rusty shields should grant three natural block")
	expect.call(healing_rooms >= 30 and healing_rooms <= 70, "Normal-room healing should remain near its 25% authored chance across deterministic seeds")
	var boss_room: Dictionary = generator.generate_room(290734, {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss",
		"boss_id": "zekarion",
		"element": "lightning"
	}, Vector2i(1, 0))
	var boss_utility_kinds: Array[String] = []
	for loot_var: Variant in boss_room.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var kind: String = str((loot_var as Dictionary).get("kind", ""))
		if kind in ["healing_vial", "rusty_shield"]:
			boss_utility_kinds.append(kind)
	boss_utility_kinds.sort()
	expect.call(boss_utility_kinds == ["healing_vial", "rusty_shield"], "Boss rooms should retain one healing vial and one shield")
	for card_id_var: Variant in GameData.cards().keys():
		var card_id: String = str(card_id_var)
		var card: Dictionary = GameData.card_def(card_id)
		var has_heal: bool = false
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) == TYPE_DICTIONARY and str((action_var as Dictionary).get("type", "")) == "heal":
				has_heal = true
				break
		if has_heal and not GameData.card_is_item(card_id):
			expect.call(bool(card.get("burn", false)), "%s should exhaust after providing repeatable healing" % card_id)


static func _test_outward_route_appears_after_three_rooms(expect: Callable) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(290735, ProgressionStore.default_data())
	var ring: Array = engine.call("_ring_coords", 1)
	var current: Vector2i = Vector2i.ZERO
	for coord_var: Variant in ring:
		var coord: Vector2i = coord_var as Vector2i
		var room: Dictionary = engine.room_metadata(state, coord)
		var has_outward: bool = false
		for connection_var: Variant in room.get("connections", []):
			if typeof(connection_var) == TYPE_DICTIONARY and str((connection_var as Dictionary).get("kind", "")) == "outward":
				has_outward = true
				break
		if not has_outward:
			current = coord
			break
	expect.call(current != Vector2i.ZERO, "The test ring should contain a lateral room without a native outward link")
	var rooms: Dictionary = state.get("rooms", {}).duplicate(true)
	for index: int in range(3):
		var coord: Vector2i = ring[index] as Vector2i
		var room: Dictionary = engine.room_metadata(state, coord)
		room["visited"] = true
		room["revealed"] = true
		room["cleared"] = true
		room["sealed"] = false
		rooms["%d,%d" % [coord.x, coord.y]] = room
	var current_room: Dictionary = engine.room_metadata(state, current)
	current_room["visited"] = true
	current_room["revealed"] = true
	current_room["cleared"] = true
	current_room["sealed"] = false
	rooms["%d,%d" % [current.x, current.y]] = current_room
	state["rooms"] = rooms
	state["current_room"] = current
	engine.call("_ensure_loop_escape_connection", state, current)
	var offered_room: Dictionary = engine.room_metadata(state, current)
	var found_attrition_offer: bool = false
	for connection_var: Variant in offered_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var as Dictionary
		if str(connection.get("kind", "")) == "outward" and bool(connection.get("attrition_offer", false)):
			found_attrition_offer = true
			expect.call(engine.available_moves(state).has(connection.get("coord", Vector2i.ZERO)), "The attrition outward route should be revealed and selectable")
	expect.call(found_attrition_offer, "Three visited same-depth rooms should force an outward route when none is available")


static func _combat_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Balance Test Room",
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"element": "none",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 2),
			"hp": 14,
			"max_hp": 14,
			"block": 0
		}],
		"loot": []
	}
