extends SceneTree
## Recreate a synced completion and a late defeat callback before replay.

const Round1 = preload("res://tools/qa147/round1.gd")
const Store = Round1.Store
const Analytics = Round1.Analytics
const Persistence = Round1.Persistence
const Run = Round1.Run
const Menu = preload("res://scenes/main_menu.tscn")
const TYPES := ["combat_ended", "reward_offered"]
const WIN_COUNTER := 1
const DEFEAT_COUNTER := 2
const PROBE_BANK := 37

class BootHost extends Round1.Host:
	var resumed_defeat: Dictionary = {}
	func _load_run_state(state: Dictionary) -> void: _run_state = state
	func _consume_next_pending_combat_checkpoint(phase: Dictionary = {}) -> bool:
		if resumed_defeat.is_empty(): return super._consume_next_pending_combat_checkpoint(phase)
		_run_state = resumed_defeat
		return true

func _initialize() -> void:
	Round1.Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var finding := OS.get_cmdline_user_args()[0]
	var output := "user://qa147r2_" + finding
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	Store.set_storage_path(output.path_join("profile.json"))
	Store.set_run_storage_path(output.path_join("run.save"))
	Analytics.set_storage_dir(output.path_join("analytics"))
	var engine := Run.new()
	var profile := Store.default_data()
	assert(Store.save_data(profile))
	var run := engine.create_new_run(Round1.SEED, profile)
	for coord: Vector2i in engine.available_moves(run):
		var battle := engine.move_to_room(run, coord)
		if battle.get("mode") == "combat":
			run = engine.repair_loaded_run_state(battle)
			break
	assert(run.get("mode") == "combat")
	var run_id := "qa147r2_" + finding
	var win_id := run_id + "_c001"
	run["analytics"] = {"run_id": run_id, "combat_counter": WIN_COUNTER}
	run["combat_state"]["analytics"] = {"combat_id": win_id}
	var host := _host(run, profile)
	var ledger := Round1.Ledger.new()
	host._analytics_store = ledger
	var won: Dictionary = run["combat_state"].duplicate(true)
	for enemy: Dictionary in won["enemies"]: enemy["hp"] = 0
	won["objective"] = {"type": "kill_all"}
	host._run_state = host._hold_committed_run_state(host._run_state_for_combat_checkpoint(run, won, "card_play"), "player_card")
	host._release_committed_run_state()
	ledger.blocked = true
	host._analytics_log_combat_transition(run, "card_play", won)
	assert(ledger.win_attempts == 1 and Round1._closing_types(win_id).is_empty())
	ledger.blocked = false
	var result: Dictionary
	match finding:
		"STALE_CHECKPOINT", "STALE_OUTAGE":
			result = await _stale(host, run_id, win_id, finding == "STALE_OUTAGE")
		"DEPARTING_DEFEAT", "DEPARTING_ENEMY_RESUME":
			result = await _departure(host, ledger, run, win_id, finding == "DEPARTING_ENEMY_RESUME")
		"CHECKPOINT_DISCARD":
			result = _discard_paths(host, run, win_id)
		_:
			push_error("Unknown QA147R2 case " + finding)
			quit(2)
			return
	result["finding"] = finding
	print("QA147R2 RESULT " + JSON.stringify(result))
	quit(0 if result.get("passed", false) else 1)

func _host(run: Dictionary, profile: Dictionary) -> BootHost:
	var instance := Round1.Scene.instantiate()
	instance.set_script(BootHost)
	var host := instance as BootHost
	root.add_child(host)
	host._run_state = run
	host._progression = profile
	return host

func _stale(host: BootHost, run_id: String, win_id: String, outage: bool) -> Dictionary:
	host.free()
	var saved := Store.load_saved_run()
	var synced := Store.record_run_completion(Store.set_embers(Store.load_data(), PROBE_BANK), saved)
	assert(Round1._install_synced_profile(synced) and _staged_win_types(Store.load_data(), win_id).is_empty())
	assert(Store.read_resumable_checkpoint()["status"] == Store.RunFile.STALE)
	var rows_before := Round1._closing_types(win_id).size()
	if outage:
		# A separate ledger path leaves any earlier map rows outside the
		# simulated outage and blocks the real title writer at file open.
		Analytics.set_storage_dir(Analytics.storage_dir().path_join("outage"))
	var blocker := Analytics._event_file_path()
	if outage: assert(DirAccess.make_dir_recursive_absolute(blocker) == OK)
	var title := Menu.instantiate()
	root.add_child(title)
	await process_frame
	assert(title.continue_button.disabled)
	var title_rows := Round1._closing_types(win_id).size()
	title.get_node("MusicPlayer").stop()
	title.free()
	var replacement := _host({}, Store.load_data())
	replacement._defer_initial_run_presentation = true
	if outage: replacement._analytics_store = SilentStore.new()
	var request := replacement._start_run(true)
	assert(not request.is_empty() and not request["replaces_active_run"])
	assert(replacement._commit_new_run(request, {}))
	assert(Store.completion_run_id(Store.load_saved_run()) != run_id)
	assert(int(Store.load_data()["embers"]) == PROBE_BANK)
	replacement.free()
	if outage: assert(DirAccess.remove_absolute(blocker) == OK)
	var staged := _staged_win_types(Store.load_data(), win_id) == TYPES
	for attempt: int in range(2): Persistence.replay_run_closing_receipts(Store.load_data(), Store.load_saved_run())
	var rows := Round1._closing_types(win_id)
	var duplicates: int = maxi(0, rows.count(TYPES[0]) - 1) + maxi(0, rows.count(TYPES[1]) - 1)
	var passed := rows_before == 0 and rows == TYPES and (staged and title_rows == 0 if outage else title_rows == 2)
	return {"rows_before": rows_before, "rows_after": rows.size(), "rows": rows, "duplicates": duplicates,
		"title_rows": title_rows, "staged": staged, "passed": passed}

class SilentStore extends "res://scripts/analytics_store.gd":
	func _append_records_at(_path: String, records: Array) -> bool: return records.is_empty()

func _discard_paths(host: BootHost, run: Dictionary, win_id: String) -> Dictionary:
	host.free()
	var saved := Store.load_saved_run()
	var synced := Store.record_run_completion(Store.load_data(), saved)
	assert(Round1._install_synced_profile(synced))
	var alternate := run.duplicate(true)
	var alternate_id := String(run["analytics"]["run_id"]) + "_backup"
	alternate["analytics"]["run_id"] = alternate_id
	var file := FileAccess.open(Store._run_storage_path + ".backup", FileAccess.WRITE)
	assert(file != null)
	file.store_var(alternate, false)
	file.close()
	var promoted := Store.load_checkpoint_for_resume()
	var promotion_carried := Store.completion_run_id(promoted) == alternate_id and _staged_win_types(Store.load_data(), win_id) == TYPES
	# Recreate the outgoing save with a profile that has not carried its rows.
	assert(Store.save_run_state(saved) and Round1._install_synced_profile(synced))
	var blocker := ProjectSettings.globalize_path(Store._storage_path + ".tmp")
	assert(DirAccess.make_dir_absolute(blocker) == OK)
	var guarded := not Store.clear_saved_run() and _staged_win_types(Store.load_saved_run().get("progression", {}), win_id) == TYPES
	assert(DirAccess.remove_absolute(blocker) == OK)
	var clear_carried := Store.clear_saved_run() and not Store.has_saved_run() and _staged_win_types(Store.load_data(), win_id) == TYPES
	var rewrite_kept := Store.save_data(synced) and _staged_win_types(Store.load_data(), win_id) == TYPES
	var before_replay := Round1._closing_types(win_id)
	for attempt: int in range(2): Persistence.replay_run_closing_receipts(Store.load_data(), {})
	var rows := Round1._closing_types(win_id)
	var rewrite_acked := Store.save_data(synced) and _staged_win_types(Store.load_data(), win_id).is_empty()
	return {"promotion_carried": promotion_carried, "failed_clear_kept_checkpoint": guarded, "clear_carried": clear_carried,
		"rewrite_kept": rewrite_kept, "rewrite_acked": rewrite_acked, "rows": rows,
		"passed": promotion_carried and guarded and clear_carried and rewrite_kept and rewrite_acked and before_replay.is_empty() and rows == TYPES}

func _departure(host: BootHost, ledger: Round1.Ledger, run: Dictionary, win_id: String, enemy_resume: bool) -> Dictionary:
	run["progression"] = host._run_state["progression"]
	run["analytics"]["combat_counter"] = DEFEAT_COUNTER
	var combat: Dictionary = run["combat_state"].duplicate(true)
	combat["analytics"]["combat_id"] = win_id.trim_suffix("_c001") + "_c002"
	combat["player"]["hp"] = 0
	host._run_state = run
	var defeated := host._run_state_for_combat_checkpoint(run, combat)
	assert(defeated.get("mode") == "defeat")
	defeated = host._hold_committed_run_state(defeated, "enemy_round_complete")
	host._save_in_progress = true
	if enemy_resume:
		# The installed scene consumes its last enemy-phase step after draw.
		# Hold a real defeat checkpoint for the separate departure snapshot.
		host.resumed_defeat = defeated
		host._run_state = run.duplicate(true)
		host._run_state[host.COMBAT_CONTINUATION_KEY] = [{"state": combat}]
		host._combat_state = run["combat_state"]
		host._resume_pending_combat_checkpoints()
	var departure := {"done": false}
	Round1._save_for_quit(host, departure)
	assert(host._leaving_tree and not departure["done"])
	var prior_attempts := ledger.win_attempts
	if enemy_resume:
		RenderingServer.frame_post_draw.emit()
		assert(host._run_state.get("mode") == "defeat")
	else:
		host._run_state = defeated
		host._release_committed_run_state()
		host._analytics_log_combat_transition(run, "enemy_round", combat)
	var live_writes := ledger.win_attempts - prior_attempts
	host._save_in_progress = false
	while not departure["done"]: await process_frame
	var profile := Store.load_data()
	var saved := Store.load_saved_run()
	var staged_kept := _staged_win_types(profile, win_id) == TYPES or _staged_win_types(saved.get("progression", {}), win_id) == TYPES
	var before_continue := Round1._closing_types(win_id).size()
	host.free()
	for attempt: int in range(2): Persistence.replay_run_closing_receipts(profile, saved)
	var rows := Round1._closing_types(win_id)
	var replayed := 1 if before_continue == 0 and rows == TYPES else 0
	return {"live_writes": live_writes, "staged_kept": staged_kept, "replayed_on_continue": replayed, "rows": rows,
		"passed": live_writes == 0 and staged_kept and replayed == 1}

func _staged_win_types(progression: Dictionary, id: String) -> Array:
	return Store.progression_analytics_outbox(progression).filter(func(receipt: Dictionary) -> bool:
		return receipt["context"].get("combat_id") == id and receipt["event_type"] in TYPES
	).map(func(receipt: Dictionary) -> String: return receipt["event_type"])
