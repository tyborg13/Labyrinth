extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")

const PROGRESSION_PATH: String = "user://save_resume_boundary_progression.json"
const UNWRITABLE_PROGRESSION_PATH: String = "user://save_resume_boundary_missing/progression.json"
const COMBAT_CONTINUATION_KEY: String = "pending_combat_checkpoints"

var _failures: Array[String] = []
var _combat_engine: CombatEngine = CombatEngine.new()
var _run_engine: RunEngine = RunEngine.new()
var _run_scene: Node
var _matrix_rows: Array[String] = []

func _initialize() -> void:
	var user_namespace: String = ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(ProgressionStore.DEFAULT_RUN_STORAGE_PATH)
	ProgressionStore.clear_saved_run()
	ProgressionStore.save_data(ProgressionStore.default_data())
	_run_scene = RunScene.new()
	_run_scene.set("_progression", ProgressionStore.default_data())
	_test_transactional_corrupt_recovery()
	_test_transactional_replacement_failure_recovery()
	_test_profile_transactional_recovery()
	_test_legacy_save_repair()
	var base_run: Dictionary = _normal_combat_run()
	if base_run.is_empty():
		_failures.append("Could not build deterministic normal combat run")
	else:
		_test_player_boundaries(base_run)
		_test_enemy_and_turn_boundaries(base_run)
		_test_room_and_reward_boundaries(base_run)
		_test_terminal_boundaries(base_run)
		_test_terminal_failure_recovery(base_run)
		_test_campfire_failure_preserves_run(base_run)
	_run_scene.free()
	ProgressionStore.clear_saved_run()
	print("SAVE NAMESPACE: %s" % user_namespace)
	print("SAVE PATH: %s" % ProjectSettings.globalize_path(ProgressionStore.DEFAULT_RUN_STORAGE_PATH))
	print("DEEP-COMPARE MATRIX: %s" % ", ".join(_matrix_rows))
	if _failures.is_empty():
		print("TEST RESULT: PASS — committed save/resume boundary matrix")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL — %d committed save/resume failure(s)" % _failures.size())
	quit(1)

func _test_transactional_corrupt_recovery() -> void:
	var valid: Dictionary = _run_engine.create_new_run(88001, ProgressionStore.default_data())
	var backup_path: String = "%s.backup" % ProgressionStore.DEFAULT_RUN_STORAGE_PATH
	var backup: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
	_assert(backup != null, "Corrupt recovery should create a backup fixture")
	if backup == null:
		return
	backup.store_var(valid, false)
	backup.close()
	var current: FileAccess = FileAccess.open(ProgressionStore.DEFAULT_RUN_STORAGE_PATH, FileAccess.WRITE)
	_assert(current != null, "Corrupt recovery should create a current fixture")
	if current == null:
		return
	current.store_var("not a run dictionary", false)
	current.close()
	_assert(ProgressionStore.load_saved_run() == valid, "Invalid current save should recover the last complete backup without rollback past it")
	ProgressionStore.clear_saved_run()
	_assert(not FileAccess.file_exists(backup_path), "Clearing a save should remove transactional backup artifacts")
	_matrix_rows.append("corrupt/current→backup")

func _test_transactional_replacement_failure_recovery() -> void:
	var blocked_run_path: String = "user://save_resume_blocked_live"
	var blocked_live_path: String = ProjectSettings.globalize_path(blocked_run_path)
	var blocked_backup_path: String = "%s.backup" % blocked_run_path
	ProgressionStore.set_run_storage_path(blocked_run_path)
	DirAccess.remove_absolute(blocked_live_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_backup_path))
	DirAccess.make_dir_recursive_absolute(blocked_live_path)
	var valid_backup: Dictionary = _run_engine.create_new_run(88009, ProgressionStore.default_data())
	var backup: FileAccess = FileAccess.open(blocked_backup_path, FileAccess.WRITE)
	_assert(backup != null, "Replacement failure should create a valid recovery backup")
	if backup != null:
		backup.store_var(valid_backup, false)
		backup.close()
	var replacement: Dictionary = _run_engine.create_new_run(88010, ProgressionStore.default_data())
	_assert(not ProgressionStore.save_run_state(replacement), "A directory occupying the live path should force replacement failure")
	_assert(ProgressionStore.load_saved_run() == valid_backup, "Failed replacement must keep the only valid backup loadable")
	DirAccess.remove_absolute(blocked_live_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_backup_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.tmp" % blocked_run_path))
	ProgressionStore.set_run_storage_path(ProgressionStore.DEFAULT_RUN_STORAGE_PATH)
	ProgressionStore.clear_saved_run()
	_matrix_rows.append("transaction/replacement_failure_backup")

func _test_profile_transactional_recovery() -> void:
	var profile_backup_path: String = "%s.backup" % PROGRESSION_PATH
	var expected: Dictionary = ProgressionStore.default_data()
	expected["embers"] = 37
	var backup: FileAccess = FileAccess.open(profile_backup_path, FileAccess.WRITE)
	_assert(backup != null, "Profile recovery should create a valid backup fixture")
	if backup == null:
		return
	backup.store_string(JSON.stringify(expected))
	backup.close()
	var current: FileAccess = FileAccess.open(PROGRESSION_PATH, FileAccess.WRITE)
	_assert(current != null, "Profile recovery should create a corrupt current fixture")
	if current == null:
		return
	current.store_string("not valid profile json")
	current.close()
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 37, "Invalid current progression should recover the last complete profile backup")

	var blocked_profile_path: String = "user://save_resume_blocked_profile"
	var blocked_live_path: String = ProjectSettings.globalize_path(blocked_profile_path)
	var blocked_backup_path: String = "%s.backup" % blocked_profile_path
	ProgressionStore.set_storage_path(blocked_profile_path)
	DirAccess.remove_absolute(blocked_live_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_backup_path))
	DirAccess.make_dir_recursive_absolute(blocked_live_path)
	var valid_backup: Dictionary = ProgressionStore.default_data()
	valid_backup["embers"] = 91
	backup = FileAccess.open(blocked_backup_path, FileAccess.WRITE)
	_assert(backup != null, "Profile replacement failure should create a valid recovery backup")
	if backup != null:
		backup.store_string(JSON.stringify(valid_backup))
		backup.close()
	var replacement: Dictionary = ProgressionStore.default_data()
	replacement["embers"] = 12
	_assert(not ProgressionStore.save_data(replacement), "A directory occupying the live profile path should force replacement failure")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 91, "Failed profile replacement must keep the only valid backup loadable")
	DirAccess.remove_absolute(blocked_live_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_backup_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.tmp" % blocked_profile_path))
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	_assert(ProgressionStore.save_data(expected), "Profile recovery fixture should restore the normal transactional path")
	_assert(not FileAccess.file_exists(profile_backup_path) and not FileAccess.file_exists("%s.tmp" % PROGRESSION_PATH), "Successful profile saves should clean transactional artifacts")
	_matrix_rows.append("profile/corrupt_and_replacement_recovery")

func _test_legacy_save_repair() -> void:
	var legacy: Dictionary = _run_engine.create_new_run(88002, ProgressionStore.default_data())
	var legacy_reward_card: String = _encoded_legacy_id([97, 115, 104, 108, 105, 110, 101, 95, 116, 101, 109, 112, 111])
	var legacy_equipment_card: String = _encoded_legacy_id([97, 115, 104, 119, 101, 97, 118, 101, 95, 103, 117, 97, 114, 100])
	var legacy_equipment: String = _encoded_legacy_id([97, 115, 104, 119, 101, 97, 118, 101, 95, 109, 97, 105, 108])
	var legacy_relic: String = _encoded_legacy_id([97, 115, 104, 101, 110, 95, 98, 117, 99, 107, 108, 101, 114])
	var legacy_intent_a: String = _encoded_legacy_id([97, 115, 104, 95, 98, 111, 108, 116])
	var legacy_intent_b: String = _encoded_legacy_id([97, 115, 104, 102, 97, 108, 108])
	var legacy_floor: String = _encoded_legacy_id([97, 115, 104])
	legacy.erase(RunEngine.RUN_CONTENT_SCHEMA_KEY)
	legacy.erase("held_embers")
	legacy["unbanked_embers"] = 17
	legacy.erase("equipment_drop_misses")
	legacy["reward_cards"] = [legacy_reward_card]
	legacy["attuned_magic_cards"] = [legacy_reward_card]
	legacy["magic_inventory"] = []
	var equipped: Dictionary = (legacy.get("equipped_equipment", {}) as Dictionary).duplicate(true)
	equipped["armor"] = legacy_equipment
	legacy["equipped_equipment"] = equipped
	legacy["equipment_inventory"] = [legacy_equipment]
	legacy["collected_equipment"] = [legacy_equipment]
	legacy["unread_loadout_equipment"] = [legacy_equipment]
	legacy["new_loadout_equipment"] = [legacy_equipment]
	legacy["unread_loadout_magic"] = [legacy_reward_card]
	legacy["new_loadout_magic"] = [legacy_reward_card]
	legacy["relics"] = [legacy_relic]
	legacy["pending_reward"] = {"cards": [legacy_reward_card, legacy_equipment_card]}
	legacy["pending_relics"] = [legacy_relic]
	legacy["skill_state"] = {
		"pending_card": legacy_reward_card,
		"pending_relic": legacy_relic,
		"reserved_merchant": {"kind": "blacksmith", "item_id": legacy_equipment},
	}
	var embedded_progression: Dictionary = (legacy.get("progression", {}) as Dictionary).duplicate(true)
	embedded_progression["grimoire_unlocked"] = ["magick:%s" % legacy_reward_card, "equipment:%s" % legacy_equipment]
	embedded_progression["grimoire_unread"] = ["magick:%s" % legacy_reward_card]
	legacy["progression"] = embedded_progression
	var rooms: Dictionary = (legacy.get("rooms", {}) as Dictionary).duplicate(true)
	var merchant_room_key: Variant = rooms.keys()[0]
	var merchant_room: Dictionary = (rooms.get(merchant_room_key, {}) as Dictionary).duplicate(true)
	merchant_room["merchant_stock"] = [legacy_equipment, legacy_reward_card]
	merchant_room["merchant_sold_items"] = [legacy_equipment]
	merchant_room["merchant_purchased_items"] = [legacy_reward_card]
	rooms[merchant_room_key] = merchant_room
	legacy["rooms"] = rooms
	var layout: Dictionary = (legacy.get("current_room_layout", {}) as Dictionary).duplicate(true)
	var layout_grid: Array = (layout.get("grid", []) as Array).duplicate(true)
	var layout_row: Array = (layout_grid[1] as Array).duplicate()
	layout_row[1] = legacy_floor
	layout_grid[1] = layout_row
	layout["grid"] = layout_grid
	layout["theme"] = legacy_floor
	layout["loot"] = [{
		"id": "loot_equipment_%s_1_1" % legacy_equipment,
		"kind": "equipment",
		"equipment_id": legacy_equipment,
		"pos": Vector2i(1, 1),
	}]
	legacy["current_room_layout"] = layout
	var legacy_combat_state: Dictionary = {
		"grid": layout_grid.duplicate(true),
		"deck": {
			"hand": [legacy_equipment_card],
			"draw": [legacy_equipment_card],
			"discard": [legacy_equipment_card],
			"burned": [legacy_equipment_card],
			"consumed": [legacy_equipment_card],
		},
		"loot": layout.get("loot", []).duplicate(true),
		"collected_equipment": [legacy_equipment],
		"missed_equipment": [legacy_equipment],
		"relics": [legacy_relic],
		"skill_ids": [],
	}
	legacy["combat_state"] = legacy_combat_state
	legacy["pending_combat_checkpoints"] = [{
		"state": {
			"grid": layout_grid.duplicate(true),
			"deck": {
				"hand": [legacy_reward_card, legacy_equipment_card],
				"draw": [legacy_equipment_card],
				"discard": [legacy_reward_card],
				"burned": [legacy_equipment_card],
				"consumed": [legacy_reward_card],
			},
			"loot": layout.get("loot", []).duplicate(true),
			"skill_flags": {"prismatic_target_card_id": legacy_reward_card},
		}
	}]
	legacy["compatibility_probe"] = {
		legacy_reward_card: [legacy_intent_a, legacy_intent_b],
		"notice": "Recovered %s." % legacy_relic,
	}
	var file: FileAccess = FileAccess.open(ProgressionStore.DEFAULT_RUN_STORAGE_PATH, FileAccess.WRITE)
	_assert(file != null, "Legacy fixture should open the production-format save path")
	if file == null:
		return
	file.store_var(legacy, false)
	file.close()
	var loaded: Dictionary = ProgressionStore.load_saved_run()
	var repaired: Dictionary = _run_engine.repair_loaded_run_state(loaded)
	_assert(int(repaired.get(RunEngine.RUN_CONTENT_SCHEMA_KEY, 0)) == RunEngine.RUN_CONTENT_SCHEMA, "Legacy saves should be stamped with the current run-content schema")
	_assert(int(repaired.get("held_embers", -1)) == 17, "Legacy unbanked embers should migrate into held embers")
	_assert(repaired.has("equipment_drop_misses"), "Legacy saves should receive current equipment defaults")
	_assert((repaired.get("reward_cards", []) as Array).has("cinderline_tempo"), "Legacy reward cards should migrate to their current content id")
	_assert((repaired.get("deck_cards", []) as Array).has("cinderline_tempo") and (repaired.get("deck_cards", []) as Array).has("cinderweave_guard"), "Legacy loadouts should rebuild a valid current deck")
	_assert(str((repaired.get("equipped_equipment", {}) as Dictionary).get("armor", "")) == "cinderweave_mail", "Legacy equipped gear should migrate to its current content id")
	_assert((repaired.get("relics", []) as Array).has("iron_buckler"), "Legacy relics should migrate to their current content id")
	var repaired_skill_state: Dictionary = repaired.get("skill_state", {}) as Dictionary
	_assert(str(repaired_skill_state.get("pending_card", "")) == "cinderline_tempo" and str(repaired_skill_state.get("pending_relic", "")) == "iron_buckler", "Legacy deferred rewards should survive content-id migration")
	_assert(str((repaired_skill_state.get("reserved_merchant", {}) as Dictionary).get("item_id", "")) == "cinderweave_mail", "Legacy reserved merchant stock should survive content-id migration")
	var compatibility_probe: Dictionary = repaired.get("compatibility_probe", {}) as Dictionary
	_assert(compatibility_probe.has("cinderline_tempo") and compatibility_probe.get("cinderline_tempo", []) == ["dust_bolt", "cinderfall"], "Legacy ids should migrate recursively through dictionary keys and nested arrays")
	var repaired_layout: Dictionary = repaired.get("current_room_layout", {}) as Dictionary
	var repaired_layout_grid: Array = repaired_layout.get("grid", []) as Array
	_assert(str(repaired_layout.get("theme", "")) == "stone" and str((repaired_layout_grid[1] as Array)[1]) == "stone", "Legacy floor themes and grid cells should migrate to valid stone terrain")
	var repaired_combat: Dictionary = repaired.get("combat_state", {}) as Dictionary
	_assert(str((((repaired_combat.get("grid", []) as Array)[1] as Array)[1])) == "stone", "Legacy combat grids should migrate to valid stone terrain")
	var repaired_combat_deck: Dictionary = repaired_combat.get("deck", {}) as Dictionary
	_assert((repaired_combat_deck.get("hand", []) as Array).has("cinderweave_guard") and (repaired_combat_deck.get("draw", []) as Array).has("cinderweave_guard"), "Legacy combat hand and draw piles should migrate their card ids")
	var repaired_loot: Dictionary = ((repaired_layout.get("loot", []) as Array)[0] as Dictionary)
	_assert(str(repaired_loot.get("id", "")) == "loot_equipment_cinderweave_mail_1_1" and str(repaired_loot.get("equipment_id", "")) == "cinderweave_mail", "Composite equipment loot ids should preserve their canonical prefix and coordinates")
	var repaired_progression: Dictionary = repaired.get("progression", {}) as Dictionary
	_assert((repaired_progression.get("grimoire_unlocked", []) as Array).has("magick:cinderline_tempo") and (repaired_progression.get("grimoire_unlocked", []) as Array).has("equipment:cinderweave_mail"), "Prefixed discovery ids should migrate without losing their namespace")
	_assert((repaired_progression.get("grimoire_unread", []) as Array).has("magick:cinderline_tempo"), "Unread discovery ids should migrate without losing their namespace")
	var repaired_rooms: Dictionary = repaired.get("rooms", {}) as Dictionary
	var repaired_merchant_room: Dictionary = repaired_rooms.get(merchant_room_key, {}) as Dictionary
	_assert((repaired_merchant_room.get("merchant_stock", []) as Array).has("cinderweave_mail") and (repaired_merchant_room.get("merchant_stock", []) as Array).has("cinderline_tempo"), "Merchant stock should migrate every renamed content id")
	var repaired_checkpoint: Dictionary = (((repaired.get("pending_combat_checkpoints", []) as Array)[0] as Dictionary).get("state", {}) as Dictionary)
	_assert(str((repaired_checkpoint.get("skill_flags", {}) as Dictionary).get("prismatic_target_card_id", "")) == "cinderline_tempo", "Pending combat checkpoint flags should migrate nested card ids")
	var repaired_checkpoint_deck: Dictionary = repaired_checkpoint.get("deck", {}) as Dictionary
	_assert((repaired_checkpoint_deck.get("hand", []) as Array).has("cinderline_tempo") and (repaired_checkpoint_deck.get("hand", []) as Array).has("cinderweave_guard"), "Pending combat checkpoint hands should migrate every renamed card id")
	_assert(str((((repaired_checkpoint.get("grid", []) as Array)[1] as Array)[1])) == "stone", "Pending combat checkpoint grids should migrate to valid stone terrain")
	var repaired_checkpoint_loot: Dictionary = ((repaired_checkpoint.get("loot", []) as Array)[0] as Dictionary)
	_assert(str(repaired_checkpoint_loot.get("id", "")) == "loot_equipment_cinderweave_mail_1_1" and str(repaired_checkpoint_loot.get("equipment_id", "")) == "cinderweave_mail", "Pending combat checkpoint loot should migrate composite and direct equipment ids")
	var legacy_pattern := RegEx.new()
	var legacy_prefix: String = _encoded_legacy_id([97, 115, 104])
	_assert(legacy_pattern.compile("(?i)(?<![[:alnum:]])%s[[:alnum:]_-]*" % legacy_prefix) == OK, "Legacy vocabulary scan should compile")
	_assert(legacy_pattern.search(var_to_str(repaired)) == null, "Repaired run state should contain no retired vocabulary tokens")
	_matrix_rows.append("legacy/repair")

func _encoded_legacy_id(values: Array) -> String:
	var bytes := PackedByteArray()
	for value: Variant in values:
		bytes.append(int(value))
	return bytes.get_string_from_ascii()

func _test_player_boundaries(base_run: Dictionary) -> void:
	var full_combat: Dictionary = _player_fixture(base_run, "quick_stab")
	var target: Vector2i = _first_target(full_combat, {"type": "melee", "damage": GameData.fixed_point_amount(9), "range": 1})
	var full_resolved: Dictionary = _combat_engine.apply_player_action(full_combat, {"type": "melee", "damage": GameData.fixed_point_amount(9), "range": 1}, target)
	full_resolved = _combat_engine.finish_player_card(full_resolved, 0)
	_assert_combat_resume("player/full_card", base_run, full_resolved)

	var attack_combat: Dictionary = _player_fixture(base_run, "guarded_step")
	target = _first_target(attack_combat, {"type": "melee", "damage": GameData.fixed_point_amount(2), "range": 1})
	var attack_resolved: Dictionary = _combat_engine.apply_player_action(attack_combat, {"type": "melee", "damage": GameData.fixed_point_amount(2), "range": 1}, target)
	attack_resolved = _combat_engine.finish_player_card(attack_resolved, 0)
	_assert_combat_resume("player/basic_attack", base_run, attack_resolved)

	var move_combat: Dictionary = _player_fixture(base_run, "quick_stab")
	var move_action: Dictionary = {"type": "move", "range": 2}
	var move_target: Vector2i = _first_target(move_combat, move_action)
	var move_resolved: Dictionary = _combat_engine.apply_player_action(move_combat, move_action, move_target)
	move_resolved = _combat_engine.finish_player_card(move_resolved, 0)
	_assert_combat_resume("player/basic_move", base_run, move_resolved)

	var compound_combat: Dictionary = _player_fixture(base_run, "patch_up")
	var compound_player: Dictionary = (compound_combat.get("player", {}) as Dictionary).duplicate(true)
	compound_player["hp"] = maxi(1, int(compound_player.get("max_hp", 1)) - GameData.fixed_point_amount(5))
	compound_combat["player"] = compound_player
	var compound_resolved: Dictionary = _combat_engine.apply_player_action(compound_combat, {"type": "heal", "amount": GameData.fixed_point_amount(3)})
	compound_resolved = _combat_engine.apply_player_action(compound_resolved, {"type": "block", "amount": GameData.fixed_point_amount(2)})
	compound_resolved = _combat_engine.finish_player_card(compound_resolved, 0)
	_assert_combat_resume("player/compound_card", base_run, compound_resolved)

	var pickup_combat: Dictionary = _player_fixture(base_run, "guarded_step")
	move_target = _first_target(pickup_combat, move_action)
	pickup_combat["loot"] = [{"kind": "equipment", "equipment_id": "iron_cleaver", "pos": move_target}]
	var pickup_resolved: Dictionary = _combat_engine.apply_player_action(pickup_combat, move_action, move_target)
	pickup_resolved = _combat_engine.finish_player_card(pickup_resolved, 0)
	_assert(bool(((pickup_resolved.get("loot", []) as Array)[0] as Dictionary).get("claimed", false)), "Pickup fixture should claim floor loot")
	_assert_combat_resume("player/pickup", base_run, pickup_resolved)

func _test_enemy_and_turn_boundaries(base_run: Dictionary) -> void:
	var combat_state: Dictionary = _player_fixture(base_run, "quick_stab")
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = maxi(int(player.get("hp", 1)), GameData.fixed_point_amount(100))
	player["max_hp"] = maxi(int(player.get("max_hp", 1)), player["hp"])
	combat_state["player"] = player
	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	var first_enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	first_enemy["intent"] = {
		"id": "save_resume_combo",
		"name": "Save Resume Combo",
		"time": 4,
		"actions": [
			{"type": "block", "amount": 2},
			{"type": "block", "amount": 3}
		]
	}
	first_enemy["shocked"] = 0
	first_enemy["immobilized"] = 0
	enemies[0] = first_enemy
	combat_state["enemies"] = enemies
	var scheduled: Dictionary = _combat_engine.finish_player_activation(combat_state)
	_assert(not _combat_engine.is_player_turn(scheduled), "A committed pass must not default an empty actor to another player activation")
	var phase: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(scheduled)
	var commit_checkpoints: Array = _run_scene.call("_combat_commit_checkpoints", phase.get("steps", [])) as Array
	var final_run_state: Dictionary = _run_scene.call("_run_state_for_combat_checkpoint", base_run, phase.get("state", {}) as Dictionary) as Dictionary
	var scheduled_run_state: Dictionary = _combat_checkpoint_run_state(base_run, scheduled, commit_checkpoints)
	_assert_run_resume("turn/pass_activation", scheduled_run_state)
	_assert_playable_continuation("resume/pass_activation", scheduled_run_state, final_run_state)
	var legacy_scheduled: Dictionary = scheduled.duplicate(true)
	legacy_scheduled["current_actor"] = {}
	var legacy_scheduled_run: Dictionary = _run_scene.call("_run_state_for_combat_checkpoint", base_run, legacy_scheduled) as Dictionary
	_assert_legacy_empty_actor_continuation(legacy_scheduled_run, final_run_state)
	var enemy_actions: int = 0
	var saw_player_turn_start: bool = false
	var checkpoint_index: int = 0
	for checkpoint_var: Variant in commit_checkpoints:
		var checkpoint_entry: Dictionary = checkpoint_var as Dictionary
		var boundary: String = str(checkpoint_entry.get("boundary", "checkpoint"))
		var checkpoint: Dictionary = (checkpoint_entry.get("state", {}) as Dictionary).duplicate(true)
		if boundary == "enemy_action":
			enemy_actions += 1
		if boundary == "player_turn_start":
			saw_player_turn_start = true
		var checkpoint_run_state: Dictionary = _combat_checkpoint_run_state(
			base_run,
			checkpoint,
			_remaining_checkpoints(commit_checkpoints, checkpoint_index + 1)
		)
		_assert_run_resume("enemy/%02d_%s" % [checkpoint_index, boundary], checkpoint_run_state)
		_assert_playable_continuation("resume/%02d_%s" % [checkpoint_index, boundary], checkpoint_run_state, final_run_state)
		checkpoint_index += 1
	_assert(enemy_actions >= 2, "Enemy phase matrix should include every action in a compound enemy intent")
	_assert(saw_player_turn_start, "Enemy phase matrix should include the next player turn/draw checkpoint")
	_assert_combat_resume("turn/round_complete", base_run, phase.get("state", {}) as Dictionary)

func _test_room_and_reward_boundaries(base_run: Dictionary) -> void:
	var completed_combat: Dictionary = (base_run.get("combat_state", {}) as Dictionary).duplicate(true)
	var enemies: Array = (completed_combat.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	completed_combat["enemies"] = enemies
	var reward_run: Dictionary = _run_engine.finish_combat(base_run, completed_combat)
	_assert(str(reward_run.get("mode", "")) == "reward", "Normal room completion should create a reward state")
	_assert_run_resume("room/combat_complete", reward_run)
	var reward_cards: Array = ((reward_run.get("pending_reward", {}) as Dictionary).get("cards", []) as Array)
	_assert(not reward_cards.is_empty(), "Reward boundary fixture should offer cards")
	if not reward_cards.is_empty():
		var claimed: Dictionary = _run_engine.claim_card_reward(reward_run, str(reward_cards[0]))
		_assert_run_resume("reward/card_pickup", claimed)

	var new_run: Dictionary = _run_engine.create_new_run(88003, ProgressionStore.default_data())
	var moves: Array[Vector2i] = _run_engine.available_moves(new_run)
	_assert(not moves.is_empty(), "Room mutation fixture should expose a legal move")
	if not moves.is_empty():
		var moved: Dictionary = _run_engine.move_to_pre_battle(new_run, moves[0])
		_assert_run_resume("room/move_commit", moved)

func _test_terminal_boundaries(base_run: Dictionary) -> void:
	var defeat_combat: Dictionary = (base_run.get("combat_state", {}) as Dictionary).duplicate(true)
	var defeated_player: Dictionary = (defeat_combat.get("player", {}) as Dictionary).duplicate(true)
	defeated_player["hp"] = 0
	defeat_combat["player"] = defeated_player
	var defeat_run: Dictionary = _run_engine.finish_combat(base_run, defeat_combat)
	defeat_run["held_embers"] = 23
	defeat_run["unbanked_embers"] = 23
	defeat_run["run_stats"] = {
		"enemies_killed": 7,
		"damage_dealt": 620,
		"damage_received": 140
	}
	var baseline_record: Dictionary = ProgressionStore.record_run_result(
		ProgressionStore.default_data(),
		"save-boundary:baseline",
		{
			"enemies_killed": 2,
			"damage_dealt": 300,
			"damage_received": 80,
			"depth": 0,
			"rooms_cleared": 0,
			"bosses_defeated": 0
		}
	)
	var baseline_progression: Dictionary = (baseline_record.get("data", {}) as Dictionary).duplicate(true)
	_run_scene.set("_progression", baseline_progression)
	_run_scene.set("_defeat_loss_processed", false)
	_run_scene.set("_run_state", defeat_run)
	_run_scene.set("_combat_state", {})
	ProgressionStore.clear_saved_run()
	_assert(bool(_run_scene.call("_persist_committed_boundary", "terminal_defeat")), "Defeat should finalize progression at the committed boundary")
	_assert(not ProgressionStore.has_saved_run(), "Committed defeat should not leave an older resumable combat")
	var committed_defeat: Dictionary = ProgressionStore.load_data()
	_assert(int(ProgressionStore.recovery_marker(committed_defeat).get("amount", 0)) == 23, "Committed defeat should persist the recovery marker before clearing the run")
	var defeat_result_id: String = RunEngine.run_result_id(defeat_run)
	var committed_result: Dictionary = ProgressionStore.run_result_for_id(committed_defeat, defeat_result_id)
	var committed_new_bests: Array = committed_result.get("new_bests", []) as Array
	_assert(not committed_result.is_empty(), "Terminal checkpoint finalization should durably record the run result before clearing the run")
	_assert(committed_new_bests.has("enemies_killed") and committed_new_bests.has("damage_dealt") and not committed_new_bests.has("damage_received"), "Terminal checkpoint finalization should persist strict eligible NEW BEST decisions")
	var committed_result_count: int = ProgressionStore.completed_run_results(committed_defeat).size()
	_run_scene.set("_progression", committed_defeat)
	_run_scene.set("_defeat_loss_processed", false)
	_assert(bool(_run_scene.call("_persist_run_state_snapshot", defeat_run, false, "terminal_defeat_reload_retry").get("saved", false)), "A reloaded terminal checkpoint should finalize successfully")
	var replayed_defeat: Dictionary = ProgressionStore.load_data()
	_assert(ProgressionStore.completed_run_results(replayed_defeat).size() == committed_result_count, "Reloading and retrying a terminal checkpoint must not duplicate its run-result ledger entry")
	_assert(ProgressionStore.run_result_for_id(replayed_defeat, defeat_result_id) == committed_result, "Reloading and retrying a terminal checkpoint must preserve the original NEW BEST decision")
	_matrix_rows.append("terminal/defeat")
	_matrix_rows.append("terminal/result_idempotence")

	var victory_run: Dictionary = _run_engine.create_debug_boss_run(ProgressionStore.default_data())
	victory_run["held_embers"] = 44
	victory_run["unbanked_embers"] = 44
	var victory_combat: Dictionary = (victory_run.get("combat_state", {}) as Dictionary).duplicate(true)
	var victory_enemies: Array = (victory_combat.get("enemies", []) as Array).duplicate(true)
	for index: int in range(victory_enemies.size()):
		var enemy: Dictionary = (victory_enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		victory_enemies[index] = enemy
	victory_combat["enemies"] = victory_enemies
	victory_run = _run_engine.finish_combat(victory_run, victory_combat)
	victory_run["debug_boss_run"] = false
	var expected_banked_embers: int = _run_engine.held_embers(victory_run)
	_run_scene.set("_progression", ProgressionStore.default_data())
	_run_scene.set("_victory_carry_processed", false)
	_run_scene.set("_run_state", victory_run)
	_run_scene.set("_combat_state", {})
	ProgressionStore.clear_saved_run()
	_assert(bool(_run_scene.call("_persist_committed_boundary", "terminal_victory")), "Victory should finalize progression at the committed boundary")
	_assert(not ProgressionStore.has_saved_run(), "Committed victory should not leave an older resumable combat")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == expected_banked_embers, "Committed victory should bank held embers before clearing the run")
	_matrix_rows.append("terminal/victory")

func _test_terminal_failure_recovery(base_run: Dictionary) -> void:
	var terminal_cases: Array = [
		{"mode": "defeat", "held": 31},
		{"mode": "victory", "held": 47}
	]
	for case_var: Variant in terminal_cases:
		var case: Dictionary = case_var as Dictionary
		var mode: String = str(case.get("mode", ""))
		var held: int = int(case.get("held", 0))
		var terminal_run: Dictionary = _terminal_run_state(base_run, mode, held)
		ProgressionStore.set_storage_path(PROGRESSION_PATH)
		_assert(ProgressionStore.save_data(ProgressionStore.default_data()), "%s failure fixture should reset progression" % mode)
		ProgressionStore.clear_saved_run()
		ProgressionStore.set_storage_path(UNWRITABLE_PROGRESSION_PATH)
		_run_scene.call("_release_committed_run_state")
		_run_scene.set("_progression", ProgressionStore.default_data())
		_run_scene.set("_victory_carry_processed", false)
		_run_scene.set("_defeat_loss_processed", false)
		_run_scene.set("_run_state", terminal_run.duplicate(true))
		_run_scene.set("_combat_state", {})
		var failure_result: Dictionary = _run_scene.call("_persist_run_state_snapshot", terminal_run, true, "terminal_%s_forced_failure" % mode) as Dictionary
		_assert(not bool(failure_result.get("saved", true)), "%s should report an unwritable progression path" % mode)
		var fallback: Dictionary = ProgressionStore.load_saved_run()
		_assert(fallback == terminal_run, "%s failure fallback must preserve the unprocessed terminal snapshot" % mode)
		_assert(_run_engine.held_embers(fallback) == held, "%s failure fallback must preserve held embers" % mode)
		var held_terminal_override: Dictionary = _run_scene.call("_committed_run_state") as Dictionary
		_assert(str(held_terminal_override.get("mode", "")) == mode and _run_engine.held_embers(held_terminal_override) == 0, "%s animation fixture should hold the finalized terminal snapshot" % mode)
		_run_scene.set("_run_state", base_run.duplicate(true))
		_run_scene.set("_combat_state", (base_run.get("combat_state", {}) as Dictionary).duplicate(true))
		_run_scene.call("_save_run_progress")
		_assert(ProgressionStore.load_saved_run() == terminal_run, "%s animation-time Save & Quit must not overwrite the unprocessed fallback" % mode)
		_run_scene.call("_release_committed_run_state")

		ProgressionStore.set_storage_path(PROGRESSION_PATH)
		_recreate_run_scene_from_saved(fallback)
		if mode == "victory":
			_run_scene.call("_process_victory_carry")
		else:
			_run_scene.call("_process_defeat_loss")
		_assert(bool(_run_scene.call("_persist_committed_boundary", "terminal_%s_retry" % mode)), "%s should finalize after storage recovers" % mode)
		_assert(not ProgressionStore.has_saved_run(), "%s retry should clear the resumable fallback only after durable progression" % mode)
		var recovered_progression: Dictionary = ProgressionStore.load_data()
		if mode == "victory":
			_assert(int(recovered_progression.get("embers", -1)) == held, "Victory retry should bank held embers exactly once")
		else:
			_assert(int(ProgressionStore.recovery_marker(recovered_progression).get("amount", -1)) == held, "Defeat retry should preserve the recovery marker exactly once")
		_matrix_rows.append("terminal/%s_io_retry" % mode)
	ProgressionStore.set_storage_path(PROGRESSION_PATH)

func _test_campfire_failure_preserves_run(base_run: Dictionary) -> void:
	var campfire_run: Dictionary = base_run.duplicate(true)
	campfire_run["held_embers"] = 37
	campfire_run["unbanked_embers"] = 37
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.clear_saved_run()
	_assert(ProgressionStore.save_run_state(campfire_run), "Campfire failure fixture should write a resumable run")
	ProgressionStore.set_storage_path(UNWRITABLE_PROGRESSION_PATH)
	_run_scene.call("_release_committed_run_state")
	_run_scene.set("_progression", ProgressionStore.default_data())
	_run_scene.set("_run_state", campfire_run.duplicate(true))
	_run_scene.set("_combat_state", (campfire_run.get("combat_state", {}) as Dictionary).duplicate(true))
	_run_scene.call("_on_campfire_embrace_pressed")
	_assert(ProgressionStore.load_saved_run() == campfire_run, "Failed Campfire Embrace must retain the exact resumable run")
	_assert(not bool((_run_scene.get("_progression") as Dictionary).get("rested_at_fire", false)), "Failed Campfire Embrace must not commit the rest flag in memory")
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.clear_saved_run()
	_matrix_rows.append("campfire/embrace_io_failure")

func _terminal_run_state(base_run: Dictionary, mode: String, held: int) -> Dictionary:
	var terminal_run: Dictionary
	var combat_state: Dictionary
	if mode == "victory":
		terminal_run = _run_engine.create_debug_boss_run(ProgressionStore.default_data())
		combat_state = (terminal_run.get("combat_state", {}) as Dictionary).duplicate(true)
		var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
		for index: int in range(enemies.size()):
			var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
			enemy["hp"] = 0
			enemies[index] = enemy
		combat_state["enemies"] = enemies
		terminal_run = _run_engine.finish_combat(terminal_run, combat_state)
		terminal_run["debug_boss_run"] = false
	else:
		combat_state = (base_run.get("combat_state", {}) as Dictionary).duplicate(true)
		var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
		player["hp"] = 0
		combat_state["player"] = player
		terminal_run = _run_engine.finish_combat(base_run, combat_state)
	terminal_run["held_embers"] = held
	terminal_run["unbanked_embers"] = held
	return terminal_run

func _normal_combat_run() -> Dictionary:
	for seed: int in range(88100, 88140):
		var run_state: Dictionary = _run_engine.create_new_run(seed, ProgressionStore.default_data())
		for coord: Vector2i in _run_engine.available_moves(run_state):
			var moved: Dictionary = _run_engine.move_to_room(run_state, coord)
			if str(moved.get("mode", "")) == "combat" and not (moved.get("combat_state", {}) as Dictionary).is_empty():
				moved["debug_boss_run"] = false
				return moved
	return {}

func _player_fixture(base_run: Dictionary, card_id: String) -> Dictionary:
	var state: Dictionary = (base_run.get("combat_state", {}) as Dictionary).duplicate(true)
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var enemy_pos: Vector2i = _adjacent_passable_tile(state, player_pos)
	var enemies: Array = state.get("enemies", []) as Array
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true) if not enemies.is_empty() else {"id": 1, "type": "crawler"}
	enemy["type"] = "crawler"
	enemy["pos"] = enemy_pos
	enemy["hp"] = GameData.fixed_point_amount(100)
	enemy["max_hp"] = GameData.fixed_point_amount(100)
	enemy["block"] = 0
	enemy["stoneskin"] = 0
	state["enemies"] = [enemy]
	state["turn_queue"] = [{
		"kind": "enemy",
		"enemy_id": int(enemy.get("id", 1)),
		"time": int(state.get("initiative_clock", 0)) + 1,
		"seq": int(state.get("activation_seq", 0)) + 1
	}]
	state["activation_seq"] = int(state.get("activation_seq", 0)) + 2
	state["terrain"] = []
	state["traps"] = []
	state["illusions"] = []
	state["loot"] = []
	state["current_actor"] = {"kind": "player", "actor_key": "player", "key": "player", "time": int(state.get("initiative_clock", 0)), "seq": 0}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 0
	state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id]
	deck["draw"] = ["quick_stab", "guarded_step", "patch_up", "sidestep_slash"]
	deck["discard"] = []
	deck["burned"] = []
	deck["consumed"] = []
	state["deck"] = deck
	return state

func _adjacent_passable_tile(state: Dictionary, origin: Vector2i) -> Vector2i:
	var grid: Array = state.get("grid", []) as Array
	for direction: Vector2i in PathUtils.DIRS_4:
		var candidate: Vector2i = origin + direction
		if PathUtils.is_passable(grid, candidate):
			return candidate
	_failures.append("Combat fixture needs an adjacent passable tile")
	return origin

func _first_target(state: Dictionary, action: Dictionary) -> Vector2i:
	var targets: Array[Vector2i] = _combat_engine.valid_targets_for_player_action(state, action)
	_assert(not targets.is_empty(), "Boundary fixture needs a legal target for %s" % str(action.get("type", "action")))
	return targets[0] if not targets.is_empty() else Vector2i(-1, -1)

func _combat_checkpoint_run_state(base_run: Dictionary, combat_state: Dictionary, remaining_checkpoints: Array) -> Dictionary:
	var run_state: Dictionary = _run_scene.call("_run_state_for_combat_checkpoint", base_run, combat_state) as Dictionary
	return _run_scene.call("_run_state_with_combat_checkpoints", run_state, remaining_checkpoints) as Dictionary

func _remaining_checkpoints(checkpoints: Array, start_index: int) -> Array:
	var remaining: Array = []
	for index: int in range(start_index, checkpoints.size()):
		remaining.append((checkpoints[index] as Dictionary).duplicate(true))
	return remaining

func _assert_playable_continuation(label: String, saved_run: Dictionary, expected_final_run: Dictionary) -> void:
	ProgressionStore.clear_saved_run()
	_assert(ProgressionStore.save_run_state(saved_run), "%s should seed the exact committed checkpoint" % label)
	_recreate_run_scene_from_saved(ProgressionStore.load_saved_run())
	var safety: int = 0
	while safety < 100 and bool(_run_scene.call("_consume_next_pending_combat_checkpoint")):
		safety += 1
	_run_scene.call("_release_committed_run_state")
	_assert(safety < 100, "%s continuation should be bounded" % label)
	var resumed: Dictionary = _run_scene.call("_committed_run_state") as Dictionary
	_assert(not resumed.has(COMBAT_CONTINUATION_KEY), "%s should consume its continuation cursor" % label)
	_assert(resumed == expected_final_run, "%s should continue to the exact final state without replay or rollback" % label)
	var final_combat: Dictionary = (resumed.get("combat_state", {}) as Dictionary)
	if str(resumed.get("mode", "")) == "combat":
		_assert(_combat_engine.is_player_turn(final_combat), "%s should resume at a playable player activation" % label)
	if resumed == expected_final_run:
		_matrix_rows.append(label)

func _assert_legacy_empty_actor_continuation(saved_run: Dictionary, expected_final_run: Dictionary) -> void:
	ProgressionStore.clear_saved_run()
	_assert(ProgressionStore.save_run_state(saved_run), "Legacy empty-actor transition should seed a production-format save")
	_recreate_run_scene_from_saved(ProgressionStore.load_saved_run())
	_assert(bool(_run_scene.call("_repair_legacy_empty_actor_transition")), "Legacy empty-actor transition should rebuild a deterministic continuation cursor")
	var repaired_save: Dictionary = ProgressionStore.load_saved_run()
	var repaired_combat: Dictionary = (repaired_save.get("combat_state", {}) as Dictionary)
	_assert(str((repaired_combat.get("current_actor", {}) as Dictionary).get("kind", "")) == "transition", "Legacy repair should persist an explicit transition actor")
	_assert(repaired_save.has(COMBAT_CONTINUATION_KEY), "Legacy repair should persist the rebuilt continuation before consuming it")
	var safety: int = 0
	while safety < 100 and bool(_run_scene.call("_consume_next_pending_combat_checkpoint")):
		safety += 1
	_run_scene.call("_release_committed_run_state")
	var resumed: Dictionary = _run_scene.call("_committed_run_state") as Dictionary
	_assert(resumed == expected_final_run, "Legacy empty-actor Continue should reach the exact final state without an extra player activation")
	if resumed == expected_final_run:
		_matrix_rows.append("legacy/empty_actor_transition_resume")

func _recreate_run_scene_from_saved(saved_run: Dictionary) -> void:
	if _run_scene != null:
		_run_scene.free()
	_run_scene = RunScene.new()
	var repaired: Dictionary = _run_engine.repair_loaded_run_state(saved_run)
	_run_scene.set("_progression", ProgressionStore.load_data())
	_run_scene.set("_run_state", repaired)
	_run_scene.set("_combat_state", (repaired.get("combat_state", {}) as Dictionary).duplicate(true))
	_run_scene.set("_victory_carry_processed", false)
	_run_scene.set("_defeat_loss_processed", false)
	_run_scene.call("_sync_progression_from_run")

func _assert_combat_resume(label: String, base_run: Dictionary, combat_state: Dictionary) -> void:
	_run_scene.call("_release_committed_run_state")
	_run_scene.set("_run_state", base_run.duplicate(true))
	_run_scene.set("_combat_state", combat_state.duplicate(true))
	_assert_saved_resume(label)

func _assert_run_resume(label: String, run_state: Dictionary) -> void:
	_run_scene.call("_release_committed_run_state")
	_run_scene.set("_run_state", run_state.duplicate(true))
	_run_scene.set("_combat_state", (run_state.get("combat_state", {}) as Dictionary).duplicate(true))
	_assert_saved_resume(label)

func _assert_saved_resume(label: String) -> void:
	ProgressionStore.clear_saved_run()
	var saved: bool = bool(_run_scene.call("_persist_committed_boundary", label))
	_assert(saved, "%s should write a committed save" % label)
	var expected: Dictionary = (_run_scene.call("_committed_run_state") as Dictionary).duplicate(true)
	var loaded: Dictionary = ProgressionStore.load_saved_run()
	_assert(loaded == expected, "%s should round-trip every authoritative field exactly" % label)
	var expected_resume: Dictionary = _run_engine.repair_loaded_run_state(expected)
	var resumed: Dictionary = _run_engine.repair_loaded_run_state(loaded)
	_assert(resumed == expected_resume, "%s should reconstruct the exact repaired resume state" % label)
	if loaded == expected and resumed == expected_resume:
		_matrix_rows.append(label)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
