extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const DragonBossLibrary = preload("res://scripts/dragon_boss_library.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const TEST_SEED: int = 74123
const NEW_BOSS_IDS: Array[String] = ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "noctyrax"]

static func run(expect: Callable) -> void:
	_test_boss_bookmarks_cover_six_sections(expect)
	_test_elemental_order_is_seeded_and_complete(expect)
	_test_boss_rooms_spawn_authored_dragons(expect)
	_test_boss_stats_scale_with_depth(expect)
	_test_opening_gimmicks_resolve(expect)
	_test_boss_death_ends_encounter_with_hazards_remaining(expect)
	_test_complete_run_can_clear_all_six_bosses(expect)
	_test_depth_twenty_four_victory_is_terminal(expect)
	_test_boss_assets_and_grimoire_entries_exist(expect)

static func _test_boss_bookmarks_cover_six_sections(expect: Callable) -> void:
	var seen: Dictionary = {}
	for depth: int in [4, 8, 12, 16, 20]:
		var boss_id: String = DragonBossLibrary.boss_id_for_depth(TEST_SEED, depth)
		expect.call(DragonBossLibrary.ELEMENTAL_BOSS_IDS.has(boss_id), "Depth %d should bookmark one of the five elemental dragons" % depth)
		expect.call(not seen.has(boss_id), "The first five boss bookmarks should not repeat a dragon")
		seen[boss_id] = true
	expect.call(seen.size() == 5, "The first five bookmarks should cover earth, fire, air, ice, and lightning exactly once")
	expect.call(DragonBossLibrary.boss_id_for_depth(TEST_SEED, 24) == DragonBossLibrary.SHADOW_BOSS_ID, "Depth 24 should always bookmark Noctyrax")
	for non_boss_depth: int in [1, 3, 5, 23]:
		expect.call(DragonBossLibrary.boss_id_for_depth(TEST_SEED, non_boss_depth).is_empty(), "Non-bookmark depth %d should not select a dragon" % non_boss_depth)

static func _test_elemental_order_is_seeded_and_complete(expect: Callable) -> void:
	var first_order: Array[String] = DragonBossLibrary.elemental_boss_order(TEST_SEED)
	var repeated_order: Array[String] = DragonBossLibrary.elemental_boss_order(TEST_SEED)
	var alternate_order: Array[String] = DragonBossLibrary.elemental_boss_order(TEST_SEED + 1)
	expect.call(first_order == repeated_order, "A run seed should reproduce the same elemental boss order")
	var sorted_order: Array[String] = first_order.duplicate()
	sorted_order.sort()
	var sorted_roster: Array[String] = DragonBossLibrary.ELEMENTAL_BOSS_IDS.duplicate()
	sorted_roster.sort()
	expect.call(sorted_order == sorted_roster, "The shuffled order should retain every elemental dragon exactly once")
	expect.call(first_order != alternate_order, "Neighboring run seeds should be able to produce different dragon orders")

static func _test_boss_rooms_spawn_authored_dragons(expect: Callable) -> void:
	var generator := RoomGenerator.new()
	for boss_id: String in DragonBossLibrary.ELEMENTAL_BOSS_IDS + [DragonBossLibrary.SHADOW_BOSS_ID]:
		var room: Dictionary = generator.generate_room(TEST_SEED, _boss_room_metadata(boss_id, 4), Vector2i.RIGHT)
		var enemies: Array = room.get("enemies", []) as Array
		var expected_count: int = 3 if boss_id == DragonBossLibrary.LIGHTNING_BOSS_ID else 1
		expect.call(enemies.size() == expected_count, "%s should spawn with its authored encounter roster" % boss_id)
		if enemies.is_empty():
			continue
		var boss: Dictionary = enemies[0] as Dictionary
		expect.call(str(boss.get("type", "")) == boss_id, "%s room should spawn the matching dragon" % boss_id)
		expect.call(boss.get("footprint", Vector2i.ZERO) == Vector2i(2, 2), "%s should occupy a 2x2 boss footprint" % boss_id)
		expect.call(bool(GameData.enemy_def(boss_id).get("boss_bar", false)), "%s should own the encounter boss bar" % boss_id)
		expect.call(str(room.get("name", "")) == DragonBossLibrary.room_name_for_boss(boss_id), "%s should use its authored arena name" % boss_id)
		expect.call(str(room.get("element", "")) == DragonBossLibrary.element_for_boss(boss_id), "%s arena should carry its matching element" % boss_id)

static func _test_boss_stats_scale_with_depth(expect: Callable) -> void:
	var generator := RoomGenerator.new()
	var combat := CombatEngine.new()
	for boss_id: String in DragonBossLibrary.ELEMENTAL_BOSS_IDS + [DragonBossLibrary.SHADOW_BOSS_ID]:
		var early_room: Dictionary = generator.generate_room(TEST_SEED, _boss_room_metadata(boss_id, 4), Vector2i.RIGHT)
		var late_room: Dictionary = generator.generate_room(TEST_SEED, _boss_room_metadata(boss_id, 20), Vector2i.RIGHT)
		var early_boss: Dictionary = (early_room.get("enemies", []) as Array)[0] as Dictionary
		var late_boss: Dictionary = (late_room.get("enemies", []) as Array)[0] as Dictionary
		expect.call(int(late_boss.get("max_hp", 0)) > int(early_boss.get("max_hp", 0)), "%s health should scale upward with sequence depth" % boss_id)
		var base_intents: Array = GameData.enemy_def(boss_id).get("intents", []) as Array
		var early_damage: int = _maximum_intent_damage(combat.call("_scaled_enemy_intents", base_intents, 4) as Array)
		var late_damage: int = _maximum_intent_damage(combat.call("_scaled_enemy_intents", base_intents, 20) as Array)
		expect.call(late_damage > early_damage, "%s damage should use the normal depth scaling curve" % boss_id)

static func _test_opening_gimmicks_resolve(expect: Callable) -> void:
	var earth_after: Dictionary = _resolve_opening("tharokh")
	var earth_spires: int = 0
	for terrain_var: Variant in earth_after.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY and str((terrain_var as Dictionary).get("kind", "")) == "dragon_spire":
			earth_spires += 1
	expect.call(earth_spires >= 3, "Tharokh should open by raising several attackable Worldspines")

	var fire_after: Dictionary = _resolve_opening("vyraketh")
	var cinder_marks: int = 0
	for trap_var: Variant in fire_after.get("traps", []):
		if typeof(trap_var) == TYPE_DICTIONARY and str((trap_var as Dictionary).get("boss_hazard_kind", "")) == "cinder_mark":
			cinder_marks += 1
	expect.call(cinder_marks >= 4, "Vyraketh should open by branding the arena with cinder marks")
	var fire_boss: Dictionary = _boss_from_state(fire_after)
	expect.call(str((fire_boss.get("intent", {}) as Dictionary).get("id", "")) == "crownfire", "Surviving cinder marks should force Crownfire as Vyraketh's next activation")

	var air_before: Dictionary = _boss_combat_state("vaeloryx")
	var air_hp_before: int = int((air_before.get("player", {}) as Dictionary).get("hp", 0))
	var air_pos_before: Vector2i = (air_before.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var air_after: Dictionary = _resolve_boss_turn(air_before)
	expect.call(int((air_after.get("player", {}) as Dictionary).get("hp", 0)) < air_hp_before, "Vaeloryx's Hollow Gale should damage the whole arena")
	expect.call((air_after.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) != air_pos_before, "Vaeloryx's Hollow Gale should forcibly reposition the player")

	var ice_after: Dictionary = _resolve_opening("iskaldra")
	expect.call(int(_boss_from_state(ice_after).get("frost_armor", 0)) == 2, "Iskaldra should open with two hit-negating crystal armor layers")

	var shadow_before: Dictionary = _boss_combat_state("noctyrax", 24)
	var shadow_hp_before: int = int((shadow_before.get("player", {}) as Dictionary).get("hp", 0))
	expect.call(CombatEngine.new().is_enemy_visible_to_player(shadow_before, _boss_from_state(shadow_before)), "Noctyrax should remain revealed through Heart Umbra")
	var shadow_after: Dictionary = _resolve_boss_turn(shadow_before)
	var shadow_umbra: Dictionary = shadow_after.get("umbra", {}) as Dictionary
	expect.call(int(shadow_umbra.get("boss_eclipse_activations", 0)) == 2, "Noctyrax should open with a two-activation Eclipse")
	expect.call(int((shadow_after.get("player", {}) as Dictionary).get("hp", 0)) < shadow_hp_before, "The Last Eclipse should punish actors outside Radiance")
	expect.call(CombatEngine.new().is_enemy_visible_to_player(shadow_after, _boss_from_state(shadow_after)), "Noctyrax should remain revealed during Eclipse")

static func _test_boss_death_ends_encounter_with_hazards_remaining(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var earth_after: Dictionary = _resolve_opening("tharokh")
	var enemies: Array = (earth_after.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		if str(enemy.get("type", "")) == "tharokh":
			enemy["hp"] = 0
		enemies[index] = enemy
	earth_after["enemies"] = enemies
	expect.call(not (earth_after.get("terrain", []) as Array).is_empty(), "Boss-outcome fixture should retain Worldspine hazards")
	expect.call(combat.combat_outcome(earth_after) == "victory", "Defeating the boss should end its encounter even when authored hazards remain")

static func _test_complete_run_can_clear_all_six_bosses(expect: Callable) -> void:
	var engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.default_data()
	var state: Dictionary = engine.create_new_run(TEST_SEED, progression)
	var defeated_bosses: Array[String] = []
	for depth: int in [4, 8, 12, 16, 20, 24]:
		state = _place_existing_run_at_boss(engine, state, depth)
		var combat_state: Dictionary = state.get("combat_state", {}) as Dictionary
		var boss_id: String = str(combat_state.get("boss_id", ""))
		expect.call(not boss_id.is_empty(), "Depth %d should load a boss in the continuous-run proof" % depth)
		defeated_bosses.append(boss_id)
		state = engine.finish_combat(state, _defeated_boss_combat(combat_state))
		if depth < 24:
			expect.call(str(state.get("mode", "")) == "room" and not bool(state.get("victory", false)), "Boss depth %d should return the same run to exploration" % depth)
		else:
			expect.call(str(state.get("mode", "")) == "victory" and bool(state.get("victory", false)), "The sixth boss should complete the same continuous run")
	var expected_order: Array[String] = DragonBossLibrary.elemental_boss_order(TEST_SEED)
	expected_order.append("noctyrax")
	expect.call(defeated_bosses == expected_order, "A single run should clear the seeded five-dragon order before Noctyrax")

static func _test_depth_twenty_four_victory_is_terminal(expect: Callable) -> void:
	var engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.default_data()
	var depth_twenty_state: Dictionary = _run_state_at_boss(engine, progression, 20)
	var depth_twenty_combat: Dictionary = _defeated_boss_combat(depth_twenty_state.get("combat_state", {}) as Dictionary)
	var after_twenty: Dictionary = engine.finish_combat(depth_twenty_state, depth_twenty_combat)
	expect.call(str(after_twenty.get("mode", "")) == "room" and not bool(after_twenty.get("victory", false)), "The fifth elemental dragon should open the final section instead of ending the run")

	var final_state: Dictionary = _run_state_at_boss(engine, progression, 24)
	var final_combat: Dictionary = final_state.get("combat_state", {}) as Dictionary
	expect.call(str(final_combat.get("boss_id", "")) == "noctyrax", "Depth 24 combat should instantiate Noctyrax")
	var final_result: Dictionary = engine.finish_combat(final_state, _defeated_boss_combat(final_combat))
	expect.call(bool(final_result.get("victory", false)), "Defeating Noctyrax should win the run")
	expect.call(str(final_result.get("mode", "")) == "victory" and not bool(final_result.get("game_over", false)), "The depth-24 win should enter the polished victory flow")

static func _test_boss_assets_and_grimoire_entries_exist(expect: Callable) -> void:
	for boss_id: String in NEW_BOSS_IDS:
		var definition: Dictionary = GameData.enemy_def(boss_id)
		for suffix: String in ["", "_idle", "_death"]:
			var path: String = "res://assets/art/enemies/%s%s.png" % [boss_id, suffix]
			expect.call(FileAccess.file_exists(path), "%s should ship its %s raster" % [boss_id, "static" if suffix.is_empty() else suffix.trim_prefix("_")])
		expect.call((definition.get("intents", []) as Array).size() >= 4, "%s should have a full authored intent kit" % boss_id)
		expect.call(not GrimoireLibrary.entry_def("enemy:%s" % boss_id).is_empty(), "%s should have a creature grimoire entry" % boss_id)

static func _boss_room_metadata(boss_id: String, depth: int) -> Dictionary:
	return {
		"coord": Vector2i(depth, 0),
		"depth": depth,
		"type": "boss",
		"element": DragonBossLibrary.element_for_boss(boss_id),
		"boss_id": boss_id,
		"connections": []
	}

static func _boss_combat_state(boss_id: String, depth: int = 4) -> Dictionary:
	var layout: Dictionary = RoomGenerator.new().generate_room(TEST_SEED, _boss_room_metadata(boss_id, depth), Vector2i.RIGHT)
	return CombatEngine.new().create_combat(TEST_SEED, layout, {
		"hp": 2000,
		"max_hp": 2000,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"cards_per_turn": 2,
		"draw_per_turn": 1,
		"heal_bonus": 0
	})

static func _resolve_opening(boss_id: String, depth: int = 4) -> Dictionary:
	return _resolve_boss_turn(_boss_combat_state(boss_id, depth))

static func _resolve_boss_turn(state: Dictionary) -> Dictionary:
	var boss_index: int = _boss_index(state)
	if boss_index < 0:
		return state
	return CombatEngine.new().resolve_enemy_turn_with_steps(state, boss_index, false).get("state", state) as Dictionary

static func _boss_index(state: Dictionary) -> int:
	var enemies: Array = state.get("enemies", []) as Array
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index] as Dictionary
		if bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)):
			return index
	return -1

static func _boss_from_state(state: Dictionary) -> Dictionary:
	var index: int = _boss_index(state)
	if index < 0:
		return {}
	return (state.get("enemies", []) as Array)[index] as Dictionary

static func _maximum_intent_damage(intents: Array) -> int:
	var result: int = 0
	for intent_var: Variant in intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		for action_var: Variant in (intent_var as Dictionary).get("actions", []):
			if typeof(action_var) == TYPE_DICTIONARY:
				result = maxi(result, int((action_var as Dictionary).get("damage", 0)))
	return result

static func _run_state_at_boss(engine: RunEngine, progression: Dictionary, depth: int) -> Dictionary:
	var state: Dictionary = engine.create_new_run(TEST_SEED, progression)
	return _place_existing_run_at_boss(engine, state, depth)

static func _place_existing_run_at_boss(engine: RunEngine, state: Dictionary, depth: int) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var coord := Vector2i(depth, 0)
	var room: Dictionary = engine.call("_build_room_metadata", TEST_SEED, coord) as Dictionary
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	next_state["current_room"] = coord
	var rooms: Dictionary = (next_state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["%d,%d" % [coord.x, coord.y]] = room
	next_state["rooms"] = rooms
	var layout: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i.RIGHT, next_state) as Dictionary
	next_state["current_room_layout"] = layout
	next_state["combat_state"] = CombatEngine.new().create_combat(TEST_SEED, layout, {
		"hp": 2000,
		"max_hp": 2000,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"cards_per_turn": 2,
		"draw_per_turn": 1,
		"heal_bonus": 0
	})
	next_state["mode"] = "combat"
	return next_state

static func _defeated_boss_combat(combat_state: Dictionary) -> Dictionary:
	var result: Dictionary = combat_state.duplicate(true)
	var enemies: Array = (result.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		if bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)):
			enemy["hp"] = 0
		enemies[index] = enemy
	result["enemies"] = enemies
	return result
