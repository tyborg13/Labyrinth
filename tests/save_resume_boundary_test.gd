extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")

var _failures: Array[String] = []
var _combat_engine: CombatEngine = CombatEngine.new()
var _run_engine: RunEngine = RunEngine.new()
var _run_scene: Node
var _matrix_rows: Array[String] = []

func _initialize() -> void:
	var user_namespace: String = ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://save_resume_boundary_progression.json")
	ProgressionStore.set_run_storage_path(ProgressionStore.DEFAULT_RUN_STORAGE_PATH)
	ProgressionStore.clear_saved_run()
	ProgressionStore.save_data(ProgressionStore.default_data())
	_run_scene = RunScene.new()
	_run_scene.set("_progression", ProgressionStore.default_data())
	_test_transactional_corrupt_recovery()
	_test_legacy_save_repair()
	var base_run: Dictionary = _normal_combat_run()
	if base_run.is_empty():
		_failures.append("Could not build deterministic normal combat run")
	else:
		_test_player_boundaries(base_run)
		_test_enemy_and_turn_boundaries(base_run)
		_test_room_and_reward_boundaries(base_run)
		_test_terminal_boundaries(base_run)
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

func _test_legacy_save_repair() -> void:
	var legacy: Dictionary = _run_engine.create_new_run(88002, ProgressionStore.default_data())
	legacy.erase("held_embers")
	legacy["unbanked_embers"] = 17
	legacy.erase("equipment_drop_misses")
	var file: FileAccess = FileAccess.open(ProgressionStore.DEFAULT_RUN_STORAGE_PATH, FileAccess.WRITE)
	_assert(file != null, "Legacy fixture should open the production-format save path")
	if file == null:
		return
	file.store_var(legacy, false)
	file.close()
	var loaded: Dictionary = ProgressionStore.load_saved_run()
	var repaired: Dictionary = _run_engine.repair_loaded_run_state(loaded)
	_assert(int(repaired.get("held_embers", -1)) == 17, "Legacy unbanked embers should migrate into held embers")
	_assert(repaired.has("equipment_drop_misses"), "Legacy saves should receive current equipment defaults")
	_matrix_rows.append("legacy/repair")

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
	var scheduled: Dictionary = _combat_engine.finish_player_activation(combat_state)
	_assert_combat_resume("turn/pass_activation", base_run, scheduled)
	var phase: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(scheduled)
	var enemy_actions: int = 0
	var saw_player_turn_start: bool = false
	var checkpoint_index: int = 0
	for step_var: Variant in phase.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		if str(step.get("kind", "")) != "commit":
			continue
		var boundary: String = str(step.get("boundary", "checkpoint"))
		var checkpoint: Dictionary = (step.get("state", {}) as Dictionary).duplicate(true)
		if boundary == "enemy_action":
			enemy_actions += 1
		if boundary == "player_turn_start":
			saw_player_turn_start = true
		_assert_combat_resume("enemy/%02d_%s" % [checkpoint_index, boundary], base_run, checkpoint)
		checkpoint_index += 1
	_assert(enemy_actions > 0, "Enemy phase matrix should include at least one resolved enemy action checkpoint")
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
	_run_scene.set("_progression", ProgressionStore.default_data())
	_run_scene.set("_defeat_loss_processed", false)
	_run_scene.set("_run_state", defeat_run)
	_run_scene.set("_combat_state", {})
	ProgressionStore.clear_saved_run()
	_assert(bool(_run_scene.call("_persist_committed_boundary", "terminal_defeat")), "Defeat should finalize progression at the committed boundary")
	_assert(not ProgressionStore.has_saved_run(), "Committed defeat should not leave an older resumable combat")
	_assert(int(ProgressionStore.recovery_marker(ProgressionStore.load_data()).get("amount", 0)) == 23, "Committed defeat should persist the recovery marker before clearing the run")
	_matrix_rows.append("terminal/defeat")

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
