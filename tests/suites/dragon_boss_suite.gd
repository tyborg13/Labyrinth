extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const DragonBossLibrary = preload("res://scripts/dragon_boss_library.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")

const TEST_SEED: int = 74123
const NEW_BOSS_IDS: Array[String] = ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "noctyrax"]

static func run(expect: Callable) -> void:
	_test_boss_bookmarks_cover_six_sections(expect)
	_test_elemental_order_is_seeded_and_complete(expect)
	_test_boss_rooms_spawn_authored_dragons(expect)
	_test_boss_stats_scale_with_depth(expect)
	_test_status_immunities_are_atomic(expect)
	_test_opening_gimmicks_resolve(expect)
	_test_noctyrax_minions_make_eclipse_visibility_matter(expect)
	_test_large_dragon_footprints_use_actor_level_target_highlighting(expect)
	_test_last_eclipse_uses_a_dedicated_icon(expect)
	_test_boss_death_ends_encounter_with_hazards_remaining(expect)
	_test_complete_run_can_clear_all_six_bosses(expect)
	_test_depth_twenty_four_victory_is_terminal(expect)
	_test_boss_assets_and_grimoire_entries_exist(expect)
	_test_boss_animation_sheets_and_death_presentations(expect)

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
		var expected_count: int = 3 if boss_id in [DragonBossLibrary.LIGHTNING_BOSS_ID, DragonBossLibrary.SHADOW_BOSS_ID] else 1
		expect.call(enemies.size() == expected_count, "%s should spawn with its authored encounter roster" % boss_id)
		if enemies.is_empty():
			continue
		var boss: Dictionary = enemies[0] as Dictionary
		expect.call(str(boss.get("type", "")) == boss_id, "%s room should spawn the matching dragon" % boss_id)
		expect.call(boss.get("footprint", Vector2i.ZERO) == Vector2i(2, 2), "%s should occupy a 2x2 boss footprint" % boss_id)
		expect.call(bool(GameData.enemy_def(boss_id).get("boss_bar", false)), "%s should own the encounter boss bar" % boss_id)
		expect.call(str(room.get("name", "")) == DragonBossLibrary.room_name_for_boss(boss_id), "%s should use its authored arena name" % boss_id)
		expect.call(str(room.get("element", "")) == DragonBossLibrary.element_for_boss(boss_id), "%s arena should carry its matching element" % boss_id)
		if boss_id == DragonBossLibrary.SHADOW_BOSS_ID:
			var minion_types: Array[String] = []
			for minion_index: int in range(1, enemies.size()):
				minion_types.append(str((enemies[minion_index] as Dictionary).get("type", "")))
			expect.call(minion_types == ["veilbound_acolyte", "veilbound_acolyte"], "Noctyrax should enter battle with two Veilbound Acolytes")
		var run_scene := RunSceneScript.new()
		expect.call(str(run_scene.call("_room_title_text", room)) == DragonBossLibrary.room_name_for_boss(boss_id), "%s arena title should surface its authored name in game" % boss_id)
		run_scene.free()

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
	var early_spires: Dictionary = _resolve_opening("tharokh", 4)
	var late_spires: Dictionary = _resolve_opening("tharokh", 20)
	expect.call(_maximum_terrain_health(late_spires) > _maximum_terrain_health(early_spires), "Worldspine health should scale upward with Tharokh's sequence depth")

static func _test_status_immunities_are_atomic(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var cases: Array[Dictionary] = [
		{"boss_id": "tharokh", "status": "poison", "action": {"poison": 3}},
		{"boss_id": "vyraketh", "status": "burn", "action": {"burn": 3}, "relic": "cinderbrand_tongs", "element": ElementData.FIRE},
		{"boss_id": "vaeloryx", "status": "immobilize", "action": {"immobilize": true}},
		{"boss_id": "iskaldra", "status": "freeze", "action": {"freeze": 3}, "relic": "rimecatcher_vial", "element": ElementData.ICE},
		{"boss_id": "zekarion", "status": "shock", "action": {"shock": 3}, "relic": "ion_spool", "element": ElementData.LIGHTNING}
	]
	for case: Dictionary in cases:
		var boss_id: String = str(case.get("boss_id", ""))
		var status_id: String = str(case.get("status", ""))
		var state: Dictionary = _boss_combat_state(boss_id)
		var relic_id: String = str(case.get("relic", ""))
		if not relic_id.is_empty():
			state["relics"] = [relic_id]
		var boss_index: int = _boss_index(state)
		var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		var direct_result: Dictionary = combat.call("_apply_action_keywords_to_enemy", state, boss_index, case.get("action", {}) as Dictionary, player_pos, true) as Dictionary
		expect.call(_enemy_status_amount(_boss_from_state(direct_result), status_id) == 0, "%s immunity should reject direct %s application before any trigger can observe it" % [boss_id, status_id])
		var relic_element: String = str(case.get("element", ""))
		if not relic_element.is_empty():
			expect.call(combat.elemental_intensity(direct_result, relic_element) == combat.elemental_intensity(state, relic_element), "%s immunity should not fire a relic trigger for rejected %s" % [boss_id, status_id])
		var all_result: Dictionary = combat.call("_apply_status_to_all_live_enemies", state, status_id, 3) as Dictionary
		expect.call(_enemy_status_amount(_boss_from_state(all_result), status_id) == 0, "%s immunity should reject all-enemy %s application atomically" % [boss_id, status_id])

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

static func _test_noctyrax_minions_make_eclipse_visibility_matter(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var before: Dictionary = _boss_combat_state("noctyrax", 24)
	var minions_before: Array[Dictionary] = []
	for enemy_var: Variant in before.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if str(enemy.get("type", "")) == "veilbound_acolyte":
			minions_before.append(enemy)
	expect.call(minions_before.size() == 2, "Noctyrax's final arena should contain two shadow minions")
	var minion_def: Dictionary = GameData.enemy_def("veilbound_acolyte")
	expect.call(int(minion_def.get("reward_embers", -1)) == 0, "Veilbound Acolytes should not inflate final-boss ember rewards")
	if not minions_before.is_empty():
		expect.call(int((minions_before[0] as Dictionary).get("max_hp", 0)) > int(minion_def.get("max_hp", 0)), "Veilbound Acolyte health should inherit depth-24 sequence scaling")
	var base_damage: int = _maximum_intent_damage(minion_def.get("intents", []) as Array)
	var scaled_damage: int = _maximum_intent_damage(combat.call("_scaled_enemy_intents", minion_def.get("intents", []) as Array, 24) as Array)
	expect.call(scaled_damage > base_damage, "Veilbound Acolyte damage should inherit depth-24 sequence scaling")

	var after: Dictionary = _resolve_boss_turn(before)
	var hidden_minions: int = 0
	for enemy_var: Variant in after.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if str(enemy.get("type", "")) == "veilbound_acolyte" and not combat.is_enemy_visible_to_player(after, enemy):
			hidden_minions += 1
	expect.call(hidden_minions > 0, "Last Eclipse should hide at least one active minion so battlefield vision matters")
	var revealed: Dictionary = after.duplicate(true)
	var umbra: Dictionary = (revealed.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["truesight_activations"] = 1
	revealed["umbra"] = umbra
	for enemy_var: Variant in revealed.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if str(enemy.get("type", "")) == "veilbound_acolyte":
			expect.call(combat.is_enemy_visible_to_player(revealed, enemy), "Truesight should reveal each Veilbound Acolyte through Eclipse")
	expect.call(not GrimoireLibrary.entry_def("enemy:veilbound_acolyte").is_empty(), "Veilbound Acolytes should have creature grimoire guidance")

static func _test_large_dragon_footprints_use_actor_level_target_highlighting(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _boss_combat_state("noctyrax", 24)
	var boss: Dictionary = _boss_from_state(state)
	var action := {"type": "ranged", "damage": 10, "range": 12}
	var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
	var footprint_tiles: Array[Vector2i] = []
	var boss_origin: Vector2i = boss.get("pos", Vector2i.ZERO)
	for y: int in range(2):
		for x: int in range(2):
			footprint_tiles.append(boss_origin + Vector2i(x, y))
	for tile: Vector2i in footprint_tiles:
		expect.call(targets.has(tile), "A targetable Noctyrax should accept clicks anywhere on its footprint: %s" % str(tile))
		var damaged: Dictionary = combat.apply_player_action(state, action, tile)
		expect.call(int(_boss_from_state(damaged).get("hp", 0)) < int(boss.get("hp", 0)), "Targeting footprint tile %s should damage the same dragon" % str(tile))
	var adjacent_state: Dictionary = state.duplicate(true)
	var adjacent_player: Dictionary = (adjacent_state.get("player", {}) as Dictionary).duplicate(true)
	adjacent_player["pos"] = boss_origin + Vector2i(-1, 0)
	adjacent_state["player"] = adjacent_player
	var adjacent_targets: Array[Vector2i] = combat.valid_targets_for_player_action(adjacent_state, {"type": "melee", "damage": 10, "range": 1})
	for tile: Vector2i in footprint_tiles:
		expect.call(adjacent_targets.has(tile), "If any dragon footprint tile is in melee range, the whole actor should use normal enemy targeting: %s" % str(tile))
	var board := CombatBoardView.new()
	var one_target: Array[Vector2i] = []
	one_target.append(footprint_tiles[0])
	board.attack_tiles = one_target
	board.presentation = {"pulse_attack_tiles": true}
	var target_unit: Dictionary = {
		"role": "enemy",
		"type": "noctyrax",
		"pos": boss_origin,
		"footprint": Vector2i(2, 2)
	}
	var target_units: Array[Dictionary] = []
	target_units.append(target_unit)
	var highlight_tiles: Array[Vector2i] = []
	for tile_var: Variant in board.call("_large_enemy_attack_highlight_tiles", target_units):
		if typeof(tile_var) == TYPE_VECTOR2I:
			highlight_tiles.append(tile_var as Vector2i)
	for tile: Vector2i in footprint_tiles:
		expect.call(highlight_tiles.has(tile), "One targetable footprint tile should apply the established attack highlight across the whole dragon: %s" % str(tile))
	board.free()

static func _test_last_eclipse_uses_a_dedicated_icon(expect: Callable) -> void:
	var eclipse_action: Dictionary = ((_enemy_intent_by_id("noctyrax", "last_eclipse").get("actions", []) as Array)[0] as Dictionary)
	var icons: Array[String] = []
	for token_var: Variant in ActionIcons.tokens_for_action(eclipse_action):
		if typeof(token_var) == TYPE_DICTIONARY:
			icons.append(str((token_var as Dictionary).get("icon", "")))
	expect.call(icons.has("eclipse"), "Last Eclipse should use its own Eclipse icon")
	expect.call(not icons.has("dispel_umbra"), "Last Eclipse should never reuse the opposing Dispel Umbra icon")
	expect.call(ActionIcons.icon_path("eclipse").ends_with("/eclipse.svg"), "Eclipse should resolve to its purpose-built high-contrast asset")
	expect.call(FileAccess.file_exists(ActionIcons.icon_path("eclipse")), "The dedicated Eclipse icon asset should ship with the encounter")
	var eclipse_texture: Texture2D = ActionIcons.icon_texture("eclipse")
	expect.call(eclipse_texture != null and eclipse_texture.get_size() == Vector2(64.0, 64.0), "The dedicated Eclipse icon should load at the shared 64px action-icon size")

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
	var save_round_trip_proved: bool = false
	var safety: int = 0
	ProgressionStore.set_run_storage_path("user://dragon_boss_end_to_end_test.save")
	ProgressionStore.clear_saved_run()
	while not bool(state.get("victory", false)) and safety < 160:
		safety += 1
		var mode: String = str(state.get("mode", ""))
		match mode:
			"room":
				var moves: Array[Vector2i] = engine.available_moves(state)
				expect.call(not moves.is_empty(), "The traversed run should always expose an onward map move before depth 24")
				if moves.is_empty():
					break
				var destination: Vector2i = _farthest_available_move(engine, state, moves)
				state = engine.move_to_room(state, destination)
			"campfire":
				state = engine.leave_campfire(state)
			"treasure":
				state = engine.claim_relic(state, "")
			"reward":
				state = engine.claim_card_reward(state, "")
			"escape":
				state = engine.continue_pending_escape(state)
			"pre_battle":
				state = engine.begin_pre_battle_combat(state)
			"combat":
				var room: Dictionary = engine.room_metadata(state, state.get("current_room", Vector2i.ZERO))
				var combat_state: Dictionary = state.get("combat_state", {}) as Dictionary
				if str(room.get("type", "")) == "boss":
					var depth: int = int(room.get("depth", 0))
					var boss_id: String = str(combat_state.get("boss_id", ""))
					expect.call(not boss_id.is_empty(), "Depth %d should load a boss through normal map travel" % depth)
					defeated_bosses.append(boss_id)
					if depth == 12 and not save_round_trip_proved:
						expect.call(ProgressionStore.save_run_state(state), "The depth-12 boss checkpoint should save in production format")
						var loaded: Dictionary = ProgressionStore.load_saved_run()
						expect.call(loaded == state, "The depth-12 boss checkpoint should round-trip without losing run state")
						loaded = engine.repair_loaded_run_state(loaded)
						expect.call(int(loaded.get("seed", -1)) == TEST_SEED, "The resumed boss checkpoint should preserve the seeded dragon order")
						expect.call(loaded.get("current_room", Vector2i.ZERO) == state.get("current_room", Vector2i.ONE), "The resumed boss checkpoint should preserve the map position")
						expect.call(str((loaded.get("combat_state", {}) as Dictionary).get("boss_id", "")) == boss_id, "The resumed boss checkpoint should preserve the live boss encounter")
						state = loaded
						save_round_trip_proved = true
				state = engine.finish_combat(state, _defeated_all_enemy_combat(combat_state))
			"victory":
				break
			_:
				expect.call(false, "End-to-end dragon traversal reached unexpected mode %s" % mode)
				break
	ProgressionStore.clear_saved_run()
	ProgressionStore.set_run_storage_path(ProgressionStore.DEFAULT_RUN_STORAGE_PATH)
	expect.call(safety < 160, "The available-move traversal should reach the final boss without looping")
	expect.call(save_round_trip_proved, "The available-move traversal should prove a mid-run, mid-boss save and resume")
	expect.call(str(state.get("mode", "")) == "victory" and bool(state.get("victory", false)), "The sixth boss should complete the same map-traversed run")
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

static func _test_boss_animation_sheets_and_death_presentations(expect: Callable) -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {"enemies": []}
	var run_scene := RunSceneScript.new()
	for boss_id: String in NEW_BOSS_IDS:
		var unit: Dictionary = {"key": "enemy_%s" % boss_id, "id": 91, "role": "enemy", "type": boss_id, "pos": Vector2i(5, 3)}
		var idle_frames: Array = board.call("_unit_idle_frames", unit)
		var death_frames: Array = board.call("_unit_death_frames", unit)
		expect.call(idle_frames.size() == 16, "%s idle animation should load all 16 authored frames" % boss_id)
		expect.call(death_frames.size() == 16, "%s death animation should load all 16 authored frames" % boss_id)
		if idle_frames.size() == 16:
			var idle_first: AtlasTexture = idle_frames[0] as AtlasTexture
			var idle_last: AtlasTexture = idle_frames[15] as AtlasTexture
			expect.call(idle_first != null and idle_first.region.position == Vector2.ZERO, "%s idle sheet should start at its first 255px cell" % boss_id)
			expect.call(idle_last != null and idle_last.region.position == Vector2(765, 765), "%s idle sheet should include its last 4x4 cell" % boss_id)
		if death_frames.size() == 16:
			var death_first: AtlasTexture = death_frames[0] as AtlasTexture
			var death_last: AtlasTexture = death_frames[15] as AtlasTexture
			expect.call(death_first != null and death_first.region.position == Vector2.ZERO, "%s death sheet should start at its first 255px cell" % boss_id)
			expect.call(death_last != null and death_last.region.position == Vector2(765, 765), "%s death sheet should include its last 4x4 cell" % boss_id)
			var frame_unit: Dictionary = unit.duplicate(true)
			frame_unit["death_animation"] = true
			frame_unit["death_frame"] = 7
			expect.call(board.call("_texture_for_unit", frame_unit) == death_frames[7], "%s death presentation should select the requested authored frame" % boss_id)
		var before_state: Dictionary = {"enemies": [unit.merged({"hp": 30, "max_hp": 30, "footprint": Vector2i(2, 2)})]}
		var after_state: Dictionary = before_state.duplicate(true)
		(after_state.get("enemies", []) as Array)[0]["hp"] = 0
		var presentation: Dictionary = run_scene.call("_death_hold_presentation", before_state, after_state, {}) as Dictionary
		var death_units: Array = presentation.get("death_animation_units", [])
		expect.call(death_units.size() == 1 and str((death_units[0] as Dictionary).get("type", "")) == boss_id, "%s lethal transition should create an in-game death presentation unit" % boss_id)
		board.combat_state = after_state
		board.presentation = presentation
		var death_unit_visible: bool = false
		for visible_var: Variant in board.call("_visible_units"):
			if typeof(visible_var) == TYPE_DICTIONARY and str((visible_var as Dictionary).get("type", "")) == boss_id and bool((visible_var as Dictionary).get("death_animation", false)):
				death_unit_visible = true
		expect.call(death_unit_visible, "%s death presentation should remain drawable after combat HP reaches zero" % boss_id)
	run_scene.free()
	board.free()

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

static func _enemy_intent_by_id(enemy_type: String, intent_id: String) -> Dictionary:
	for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		if str(intent.get("id", "")) == intent_id:
			return intent
	return {}

static func _maximum_terrain_health(state: Dictionary) -> int:
	var result: int = 0
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY:
			result = maxi(result, int((terrain_var as Dictionary).get("max_hp", 0)))
	return result

static func _enemy_status_amount(enemy: Dictionary, status_id: String) -> int:
	if status_id == "immobilize":
		return 1 if bool(enemy.get("immobilize", false)) else 0
	if status_id == "poison":
		return int((enemy.get("poison", {}) as Dictionary).get("damage", 0))
	return int(enemy.get(status_id, 0))

static func _farthest_available_move(engine: RunEngine, state: Dictionary, moves: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = moves[0]
	var best_depth: int = int(engine.room_metadata(state, best).get("depth", 0))
	for candidate: Vector2i in moves:
		var candidate_depth: int = int(engine.room_metadata(state, candidate).get("depth", 0))
		var candidate_key: String = "%d,%d" % [candidate.x, candidate.y]
		var best_key: String = "%d,%d" % [best.x, best.y]
		if candidate_depth > best_depth or (candidate_depth == best_depth and candidate_key < best_key):
			best = candidate
			best_depth = candidate_depth
	return best

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

static func _defeated_all_enemy_combat(combat_state: Dictionary) -> Dictionary:
	var result: Dictionary = combat_state.duplicate(true)
	var enemies: Array = (result.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	result["enemies"] = enemies
	var objective: Dictionary = result.get("objective", {}) as Dictionary
	match str(objective.get("type", CombatObjectiveRules.KILL_ALL)):
		CombatObjectiveRules.SURVIVE:
			result["initiative_clock"] = int(objective.get("target_clock", result.get("initiative_clock", 0)))
		CombatObjectiveRules.REACH_EXIT:
			var target_tiles: Array[Vector2i] = CombatObjectiveRules.exit_target_tiles(objective)
			if not target_tiles.is_empty():
				var player: Dictionary = (result.get("player", {}) as Dictionary).duplicate(true)
				player["pos"] = target_tiles[0]
				result["player"] = player
	return result
