extends SceneTree
## Deterministic outbox delivery cuts used by the save/resume regression.

const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Persistence = preload("res://scripts/run_persistence.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Run = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Scene = preload("res://scenes/run_scene.tscn")

const FINDINGS := ["later_checkpoint", "departing_transition"]
const SEED := 88100
const VIEWPORT := Vector2i(1920, 1080)
const PROFILE_REVISION_STEP := 1
const LEDGER_TYPES := ["combat_ended", "reward_offered"]

class Host extends "res://tests/helpers/terminal_crash_fixture.gd".Host:
	func _ready() -> void: pass

class Ledger extends "res://scripts/analytics_store.gd":
	var blocked: bool
	var win_attempts := 0
	func write_events_durable(events: Array) -> bool:
		if events.any(func(row: Dictionary) -> bool: return row["event_type"] == "reward_offered"):
			win_attempts += 1
			if blocked: return false
		return super.write_events_durable(events)
	func _append_records_at(path: String, records: Array) -> bool:
		if blocked and not records.is_empty(): return false
		return super._append_records_at(path, records)

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var finding := OS.get_cmdline_user_args()[0]
	var report := await exercise(self, finding)
	print("QA147R1 RESULT " + JSON.stringify(report))
	quit(0 if report["passed"] else 1)

static func exercise(tree: SceneTree, finding: String) -> Dictionary:
	assert(finding in FINDINGS)
	var old_profile: String = Store._storage_path
	var old_run: String = Store._run_storage_path
	var old_analytics := Analytics.storage_dir()
	var directory := "user://qa147r1_" + finding
	DirAccess.make_dir_recursive_absolute(directory)
	Store.set_storage_path(directory.path_join("profile.json"))
	Store.set_run_storage_path(directory.path_join("run.save"))
	Analytics.set_storage_dir(directory.path_join("analytics"))
	Store.clear_saved_run()
	Analytics.clear_storage()
	var profile := Store.default_data()
	assert(Store.save_data(profile))
	var engine := Run.new()
	var run := engine.create_new_run(SEED, profile)
	for coord: Vector2i in engine.available_moves(run):
		var moved := engine.move_to_room(run, coord)
		if moved.get("mode") == "combat":
			run = engine.repair_loaded_run_state(moved)
			break
	assert(run.get("mode") == "combat")
	var run_id := "qa147r1_" + finding
	var combat_id := run_id + "_c001"
	run["analytics"] = {"run_id": run_id, "combat_counter": 1}
	run["combat_state"]["analytics"] = {"combat_id": combat_id}
	var final_combat: Dictionary = run["combat_state"].duplicate(true)
	var instance := Scene.instantiate()
	instance.set_script(Host)
	var host := instance as Host
	tree.root.add_child(host)
	host._run_state = run
	host._progression = profile
	var ledger := Ledger.new()
	host._analytics_store = ledger
	var result: Dictionary
	if finding == "later_checkpoint":
		result = await _later_checkpoint(tree, host, ledger, engine, run, final_combat, combat_id)
	else:
		result = await _departing_transition(tree, host, ledger, run, final_combat, combat_id)
	Store.clear_saved_run()
	Analytics.clear_storage()
	Analytics.set_storage_dir(old_analytics)
	Store.set_run_storage_path(old_run)
	Store.set_storage_path(old_profile)
	return result

static func _later_checkpoint(tree: SceneTree, host: Host, ledger: Ledger, engine: Run,
		run: Dictionary, combat: Dictionary, combat_id: String) -> Dictionary:
	var moves := engine.available_moves(run.merged({"mode": "room"}, true))
	assert(not moves.is_empty())
	var destination: Vector2i = moves[0]
	var tile: Vector2i = combat["player"]["pos"]
	combat["objective"] = {"type": "reach_exit", "exits": [{"target_tile": tile, "door_tile": tile, "coord": destination}]}
	ledger.blocked = true
	var reward := host._run_state_for_combat_checkpoint(run, combat, "player_movement")
	host._run_state = host._hold_committed_run_state(reward, "player_movement")
	host._release_committed_run_state()
	host._analytics_log_combat_transition(run, "player_movement", combat)
	var claimed := engine.claim_card_reward(host._run_state, reward["pending_reward"]["cards"][0])
	assert(claimed.get("mode") == Run.MODE_ESCAPE)
	host._run_state = engine.continue_pending_escape(claimed)
	assert(host._run_state.get("current_room") == destination)
	assert(host._persist_committed_boundary("reach_exit_room_move_analytics"))
	await host._save_for_quit()
	host.free()
	# Restart with only the committed files. A failed departure may have left
	# an ordered append in process memory, which a new process cannot inherit.
	Analytics._receipt_orders.erase(ProjectSettings.globalize_path(Analytics.storage_dir()).simplify_path())
	var checkpoint := Store.load_saved_run()
	var newer := Store.load_data()
	newer[Store.PROGRESSION_ANALYTICS_OUTBOX_KEY] = []
	newer["progression_revision"] = int(checkpoint["progression"]["progression_revision"]) + PROFILE_REVISION_STEP
	assert(_install_synced_profile(newer))
	var blocker := Analytics._event_file_path()
	assert(DirAccess.make_dir_absolute(blocker) == OK)
	Persistence.replay_run_closing_receipts(newer, checkpoint)
	assert(_closing_types(combat_id).is_empty())
	assert(DirAccess.remove_absolute(blocker) == OK)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT
	tree.root.add_child(viewport)
	tree.root.set_meta("labyrinth_resume_saved_run", true)
	var resumed := Scene.instantiate() as RunScene
	var blocked_resume := Ledger.new()
	blocked_resume.blocked = true
	resumed._analytics_store = blocked_resume
	viewport.add_child(resumed)
	assert(resumed._run_state.get("mode") == checkpoint.get("mode"))
	assert(resumed._persist_committed_boundary("explicit_save"))
	var retained := Store.load_saved_run()
	var staged := Store.progression_analytics_outbox(retained.get("progression", {})).filter(func(receipt: Dictionary) -> bool:
		return receipt["context"].get("combat_id") == combat_id and receipt["event_type"] in LEDGER_TYPES
	)
	viewport.queue_free()
	await tree.process_frame
	for attempt: int in range(2): Persistence.replay_run_closing_receipts(Store.load_data(), retained)
	var rows := _closing_types(combat_id)
	return {"finding": "later_checkpoint", "mode": str(retained.get("mode")), "retained": staged.size(), "rows": rows,
		"passed": staged.size() == LEDGER_TYPES.size() and rows == LEDGER_TYPES}

static func _departing_transition(tree: SceneTree, host: Host, ledger: Ledger, run: Dictionary,
		combat: Dictionary, combat_id: String) -> Dictionary:
	for enemy: Dictionary in combat["enemies"]: enemy["hp"] = 0
	combat["objective"] = {"type": "kill_all"}
	var reward := host._run_state_for_combat_checkpoint(run, combat, "card_play")
	reward = host._hold_committed_run_state(reward, "player_card")
	# Freeze departure at its real save-in-progress await. This is the same
	# analytics callback the VICTORY timer reaches after installing the reward.
	host._save_in_progress = true
	var departure := {"done": false}
	_save_for_quit(host, departure)
	assert(host._leaving_tree and not departure["done"])
	host._run_state = reward
	host._release_committed_run_state()
	host._analytics_log_combat_transition(run, "card_play", combat)
	var during := ledger.win_attempts
	host._save_in_progress = false
	while not departure["done"]: await tree.process_frame
	var checkpoint := Store.load_saved_run()
	var before_continue := _closing_types(combat_id)
	host.free()
	for attempt: int in range(2): Persistence.replay_run_closing_receipts(Store.load_data(), checkpoint)
	var rows := _closing_types(combat_id)
	return {"finding": "departing_transition", "live_writes": during, "before_continue": before_continue.size(), "rows": rows,
		"passed": during == 0 and before_continue.is_empty() and rows == LEDGER_TYPES}

static func _save_for_quit(host: Host, status: Dictionary) -> void:
	await host._save_for_quit()
	status["done"] = true

static func _install_synced_profile(profile: Dictionary) -> bool:
	# Sync replaces the file outside the game's profile transaction.
	var file := FileAccess.open(Store._storage_path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(profile))
	file.flush()
	var saved := file.get_error() == OK
	file.close()
	return saved

static func _closing_types(combat_id: String) -> Array:
	return Analytics._read_all_events().filter(func(row: Dictionary) -> bool:
		return row.get("combat_id") == combat_id and row["event_type"] in LEDGER_TYPES
	).map(func(row: Dictionary) -> String: return row["event_type"])
