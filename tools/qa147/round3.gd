extends SceneTree
## Exercise player choices while the outgoing win receipts cannot be carried.

const Round1 = preload("res://tools/qa147/round1.gd")
const Store = Round1.Store
const Analytics = Round1.Analytics
const Run = Round1.Run
const Menu = preload("res://scenes/main_menu.tscn")
const Recovery = preload("res://scripts/opening_boon_recovery.gd")
const CASES := ["CONTINUE", "NEW_RUN", "RISE_AGAIN", "NEW_RUN_DEPTH_SAVE_FAILURE"]
const OUTGOING_RUN := "qa147r3_outgoing"
const BACKUP_RUN := "qa147r3_backup"
const COMBAT_ID := OUTGOING_RUN + "_c001"
const DEPTH := 1

class Host extends Round1.Host:
	var promotion_blocker := ""

	func _acknowledge_saved_starting_relic_gift(state: Dictionary) -> bool:
		restore_profile_writes()
		return super._acknowledge_saved_starting_relic_gift(state)

	func restore_profile_writes() -> void:
		# Scope the promotion outage to its carry. The player choice still
		# requires the ordinary profile save later in New Run and Rise Again.
		if not promotion_blocker.is_empty():
			assert(DirAccess.remove_absolute(promotion_blocker) == OK)
			promotion_blocker = ""

func _initialize() -> void:
	Round1.Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var choice := OS.get_cmdline_user_args()[0]
	assert(choice in CASES)
	var depth_outage := choice == "NEW_RUN_DEPTH_SAVE_FAILURE"
	var output := "user://qa147r3"
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	Store.set_storage_path(output.path_join("progression.json"))
	Store.set_run_storage_path(output.path_join("run.save"))
	Analytics.set_storage_dir(output.path_join("analytics"))
	var profile := Store.default_data()
	if depth_outage: profile[Store.UMBRA_DEPTH_UNLOCKED_KEY] = DEPTH
	assert(Store.save_data(profile))
	var engine := Run.new()
	var run := engine.create_new_run(Round1.SEED, profile)
	for coord: Vector2i in engine.available_moves(run):
		var battle := engine.move_to_room(run, coord)
		if battle.get("mode") == "combat":
			run = engine.repair_loaded_run_state(battle)
			break
	assert(run.get("mode") == "combat")
	run["analytics"] = {"run_id": OUTGOING_RUN, "combat_counter": 1}
	run["combat_state"]["analytics"] = {"combat_id": COMBAT_ID}
	var instance := Round1.Scene.instantiate()
	instance.set_script(Host)
	var host := instance as Host
	root.add_child(host)
	host._defer_initial_run_presentation = true
	host._progression = profile
	var won: Dictionary = run["combat_state"].duplicate(true)
	for enemy: Dictionary in won["enemies"]: enemy["hp"] = 0
	won["objective"] = {"type": "kill_all"}
	var outgoing := host._run_state_for_combat_checkpoint(run, won, "card_play")
	assert(outgoing["mode"] == "reward" and _win_keys(outgoing) == _expected_win_keys())
	assert(Store.save_run_state(outgoing))
	var live_hash := FileAccess.get_sha256(Store._run_storage_path)
	var backup_path := Store._run_storage_path + ".backup"
	var backup_hash := ""
	if not depth_outage:
		assert(Store.save_data(Store.record_run_completion(profile, outgoing)))
		assert(Store.read_resumable_checkpoint()["status"] == Store.RunFile.STALE)
		var backup := run.duplicate(true)
		backup["analytics"]["run_id"] = BACKUP_RUN
		backup["combat_state"]["analytics"]["combat_id"] = BACKUP_RUN + "_c001"
		var file := FileAccess.open(backup_path, FileAccess.WRITE)
		assert(file != null)
		assert(file.store_var(backup, false))
		file.close()
		backup_hash = FileAccess.get_sha256(backup_path)
	var analytics_blocker := Analytics._event_file_path()
	var profile_blocker := Store._storage_path + ".tmp"
	assert(DirAccess.make_dir_recursive_absolute(analytics_blocker) == OK)
	assert(DirAccess.make_dir_absolute(profile_blocker) == OK)
	var title := Menu.instantiate()
	root.add_child(title)
	assert(not title.continue_button.disabled)
	assert(FileAccess.get_sha256(Store._run_storage_path) == live_hash)
	assert(Round1._closing_types(COMBAT_ID).is_empty())
	title.get_node("MusicPlayer").stop()
	title.free()
	if depth_outage:
		Store.remember_umbra_depth(Store.load_data(), DEPTH)
		assert(Store._session_depth_save_failed and Store.selected_umbra_depth(Store.load_data()) != DEPTH)
		# Acknowledge the previous run before the staged startup commits.
		assert(DirAccess.remove_absolute(profile_blocker) == OK)
	elif choice != "CONTINUE":
		host.promotion_blocker = profile_blocker
		Recovery.profile_writer = func(data: Dictionary) -> bool:
			host.restore_profile_writes()
			return Store.save_data(data)

	var status := "INVALID"
	match choice:
		"CONTINUE":
			root.set_meta("labyrinth_resume_saved_run", true)
			host._boot_initial_run(false)
			if root.has_meta("play_stats_checkpoint_load_failed"):
				status = "UNAVAILABLE"
			elif Store.completion_run_id(host._run_state) == BACKUP_RUN and host._run_state.get("mode") == "combat":
				assert(FileAccess.get_sha256(Store._run_storage_path) == backup_hash)
				assert(FileAccess.get_sha256(backup_path) == backup_hash)
				var combat: Dictionary = host._combat_state
				var targets := host._combat_engine.player_movement_targets(combat)
				assert(not targets.is_empty())
				var moved := host._combat_engine.apply_player_movement(combat, targets[0])
				if moved["player"]["pos"] == targets[0]: status = "PLAYABLE_BACKUP"
		"RISE_AGAIN":
			host._on_restart_pressed()
			status = _replacement_status(host, live_hash, false)
		_:
			var request := host._boot_initial_run(true)
			if depth_outage:
				assert(not request.is_empty() and _win_keys({"progression": Store.load_data()}) == _expected_win_keys())
				# Sync an older profile during staged startup. Leave the pair in
				# the outgoing checkpoint and the pending replacement.
				assert(Round1._install_synced_profile(profile))
				assert(DirAccess.make_dir_absolute(profile_blocker) == OK)
			if not request.is_empty():
				assert(Store.completion_run_id(request["previous"]) == (OUTGOING_RUN if depth_outage else BACKUP_RUN))
				host._commit_new_run(request, {})
			status = _replacement_status(host, live_hash, depth_outage)

	assert(Round1._closing_types(COMBAT_ID).is_empty())
	assert(DirAccess.remove_absolute(analytics_blocker) == OK)
	if DirAccess.dir_exists_absolute(profile_blocker): assert(DirAccess.remove_absolute(profile_blocker) == OK)
	Recovery.profile_writer = Store.save_data
	host.free()
	print("QA147R3 RESULT %s %s" % [choice, status])
	quit(0 if status in ["PLAYABLE_BACKUP", "REPLACED", "REPLACED_WITH_RECEIPTS"] else 1)

static func _replacement_status(host: Host, live_hash: String, depth_outage: bool) -> String:
	if not host.has_installed_run():
		assert(FileAccess.get_sha256(Store._run_storage_path) == live_hash)
		return "INSTALL_FAILED" if depth_outage else "UNAVAILABLE"
	var saved := Store.load_saved_run()
	var run_id := Store.completion_run_id(saved)
	assert(not run_id.is_empty() and run_id not in [OUTGOING_RUN, BACKUP_RUN])
	assert(run_id == Store.completion_run_id(host._run_state))
	if depth_outage:
		assert(int(saved["umbra_depth"]) == DEPTH and Store._session_depth_save_failed)
		return "REPLACED_WITH_RECEIPTS" if _win_keys(saved) == _expected_win_keys() else "MISSING_RECEIPTS"
	assert(Store.has_completed_run(Store.load_data(), {"analytics": {"run_id": BACKUP_RUN}}))
	return "REPLACED"

static func _win_keys(state: Dictionary) -> Array:
	return Store.progression_analytics_outbox(state.get("progression", {})).filter(Store.is_combat_win_receipt).map(
		func(receipt: Dictionary) -> String: return receipt["idempotency_key"])

static func _expected_win_keys() -> Array:
	return [Analytics.combat_ended_key(COMBAT_ID), Analytics.reward_offered_key(COMBAT_ID)]
