extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const SAVE_PATH: String = "user://save_pipeline_performance.save"
const DIRECT_FORMAT_PATH: String = "user://save_pipeline_performance_direct.save"
const SAVE_ITERATIONS: int = 24
const LOAD_ITERATIONS: int = 48

var _failures: Array[String] = []


func _initialize() -> void:
	var user_namespace: String = ParallelRuntime.apply_from_environment()
	ProgressionStore.set_run_storage_path(SAVE_PATH)
	ProgressionStore.clear_saved_run()
	var run_state: Dictionary = _representative_run_state()
	var original: Dictionary = run_state.duplicate(true)
	_assert(ProgressionStore.save_run_state(run_state), "Warm-up save should succeed")
	var started_usec: int = Time.get_ticks_usec()
	for checkpoint_index: int in range(SAVE_ITERATIONS):
		run_state["checkpoint_index"] = checkpoint_index
		_assert(ProgressionStore.save_run_state(run_state), "Checkpoint save %d should succeed" % checkpoint_index)
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	var expected: Dictionary = run_state.duplicate(true)
	started_usec = Time.get_ticks_usec()
	var loaded: Dictionary = {}
	for load_index: int in range(LOAD_ITERATIONS):
		loaded = ProgressionStore.load_saved_run()
		_assert(int(loaded.get("checkpoint_index", -1)) == SAVE_ITERATIONS - 1, "Reload %d should observe the latest checkpoint" % load_index)
	var load_elapsed_usec: int = Time.get_ticks_usec() - started_usec
	_assert(loaded == expected, "The optimized save pipeline must preserve exact Variant compatibility")
	var loaded_combat: Dictionary = loaded.get("combat_state", {}) as Dictionary
	loaded_combat["turn"] = -1
	loaded["combat_state"] = loaded_combat
	_assert(int((ProgressionStore.load_saved_run().get("combat_state", {}) as Dictionary).get("turn", -1)) == 37, "Loaded state must remain isolated from the persisted checkpoint")
	original["checkpoint_index"] = int(run_state.get("checkpoint_index", -1))
	_assert(run_state == original, "Saving must not mutate or normalize the caller-owned run state")
	_assert(not FileAccess.file_exists("%s.tmp" % SAVE_PATH), "A successful save should not leave a temp artifact")
	_assert(not FileAccess.file_exists("%s.backup" % SAVE_PATH), "A successful save should not leave a backup artifact")
	var transaction_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SAVE_PATH)
	var direct_file: FileAccess = FileAccess.open(DIRECT_FORMAT_PATH, FileAccess.WRITE)
	_assert(direct_file != null, "Direct-format compatibility fixture should open")
	if direct_file != null:
		direct_file.store_var(expected, false)
		direct_file.close()
		_assert(FileAccess.get_file_as_bytes(DIRECT_FORMAT_PATH) == transaction_bytes, "Transactional saves must retain the exact legacy store_var file format")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIRECT_FORMAT_PATH))
	var backup_file: FileAccess = FileAccess.open("%s.backup" % SAVE_PATH, FileAccess.WRITE)
	_assert(backup_file != null, "Backup recovery fixture should open")
	if backup_file != null:
		backup_file.store_var(expected, false)
		backup_file.close()
	var corrupt_live: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	_assert(corrupt_live != null, "Corrupt live recovery fixture should open")
	if corrupt_live != null:
		corrupt_live.store_var("not a run dictionary", false)
		corrupt_live.close()
	_assert(ProgressionStore.load_saved_run() == expected, "A corrupt live checkpoint must still fall back to its valid backup")
	print("SAVE PIPELINE NAMESPACE: %s" % user_namespace)
	print("SAVE PIPELINE BYTES: %d" % transaction_bytes.size())
	print("SAVE PIPELINE US PER CHECKPOINT: %.2f" % (float(elapsed_usec) / float(SAVE_ITERATIONS)))
	print("SAVE PIPELINE US PER LOAD: %.2f" % (float(load_elapsed_usec) / float(LOAD_ITERATIONS)))
	ProgressionStore.clear_saved_run()
	ProgressionStore.set_run_storage_path(ProgressionStore.DEFAULT_RUN_STORAGE_PATH)
	if _failures.is_empty():
		print("TEST RESULT: PASS — save pipeline compatibility and cleanup")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL — %d save pipeline failure(s)" % _failures.size())
	quit(1)


func _representative_run_state() -> Dictionary:
	var rooms: Dictionary = {}
	for y: int in range(9):
		for x: int in range(9):
			var coord := Vector2i(x, y)
			var room_enemies: Array[Dictionary] = []
			for enemy_index: int in range(5):
				room_enemies.append({
					"id": "enemy_%d_%d_%d" % [x, y, enemy_index],
					"type": "umbra_wraith",
					"hp": 120 - enemy_index * 7,
					"pos": Vector2i((x + enemy_index) % 9, (y + enemy_index * 2) % 9),
					"statuses": {"burn": enemy_index, "weak": enemy_index % 2},
				})
			rooms[coord] = {
				"coord": coord,
				"type": "combat",
				"revealed": true,
				"cleared": x + y < 7,
				"enemies": room_enemies,
				"terrain": [Vector2i(x % 4, y % 4), Vector2i((x + 3) % 9, (y + 4) % 9)],
			}
	var deck: Array[Dictionary] = []
	for card_index: int in range(120):
		deck.append({
			"id": "card_%03d" % card_index,
			"base_id": "guarded_step",
			"upgrades": ["keen_edge", "ember_bound"] if card_index % 3 == 0 else [],
			"mods": [{"id": "damage", "amount": card_index % 5}],
		})
	var event_log: Array[Dictionary] = []
	for event_index: int in range(600):
		event_log.append({
			"turn": int(event_index / 4),
			"actor": "enemy_%d" % (event_index % 12),
			"kind": "damage" if event_index % 2 == 0 else "status",
			"amount": event_index % 23,
			"tile": Vector2i(event_index % 9, int(event_index / 9) % 9),
		})
	return {
		"schema": 7,
		"seed": 741992,
		"mode": "combat",
		"checkpoint_index": -1,
		"current_room": Vector2i(4, 5),
		"rooms": rooms,
		"deck": deck,
		"draw_pile": deck.duplicate(true),
		"discard_pile": deck.slice(0, 59, 1, true),
		"combat_state": {
			"turn": 37,
			"player": {"hp": 184, "max_hp": 260, "pos": Vector2i(4, 4), "statuses": {}},
			"event_log": event_log,
			"pending_actions": deck.slice(0, 7, 1, true),
		},
		"progression": ProgressionStore.default_data(),
	}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
