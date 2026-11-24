extends SceneTree

const HeirloomFixture = preload("res://tests/helpers/heirloom_fixture.gd")
const OpeningBoonFixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const TerminalCrash = preload("res://tests/helpers/terminal_crash_fixture.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GraftwrightSuite = preload("res://tests/suites/graftwright_suite.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const DragonBossInspection = preload("res://tools/dragon_boss_inspection.gd")

const PROGRESSION_PATH: String = "user://main_menu_resume_test_progression.json"
const RUN_PATH: String = "user://main_menu_resume_test_run.save"
const FINISHED_RUN_ID: String = "run_fixture_finished"
const OTHER_RUN_ID: String = "run_fixture_other"
const REPLACED_RUN_ID: String = "run_fixture_replacement"

const RECOVERY_ROOM := Vector2i(4, 0)
const DEFEATED_RUN := 2

class BootHost extends RunScene:
	func _ready() -> void: pass
	func _load_run_state(state: Dictionary) -> void: _run_state = state
	func _analytics_log_run_resumed() -> void: pass

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var args := OS.get_cmdline_user_args()
	if args.has("--terminal-crash") or args.has("--terminal-relaunch"):
		await _terminal_crash_phase(args)
		return
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	_cleanup_storage()
	await _test_valid_save_summary_and_replacement_gate()
	await _test_graftwright_saves_resume()
	await _test_dragon_reward_save_resumes()
	await _test_no_save_hides_summary()
	await _test_corrupt_save_is_hidden_and_recoverable()
	await _test_completed_checkpoint_selection()
	_test_backup_resume_rotation()
	_test_interrupted_new_descent_marker()
	_test_interrupted_descent_then_defeat()
	_test_terminal_withdrawal_without_profile()
	_cleanup_storage()
	await process_frame
	await process_frame
	var steam_service: Node = root.get_node_or_null("SteamService")
	if steam_service != null:
		root.remove_child(steam_service)
		steam_service.free()
	AssetLoader._audio_cache.clear()
	if _failures.is_empty():
		print("TEST RESULT: PASS — main menu resume safety")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL — %d main menu resume safety failure(s)" % _failures.size())
	quit(1)

func _terminal_crash_phase(args: PackedStringArray) -> void:
	var kind := ""
	var directory := ""
	for arg: String in args:
		if arg.begins_with("--path="): kind = arg.trim_prefix("--path=")
		if arg.begins_with("--output="): directory = arg.trim_prefix("--output=")
	if not TerminalCrash.configure(self, directory, kind):
		TerminalCrash._fail(self, "invalid terminal crash fixture arguments")
		return
	var abandon_profile_blocked := kind == "abandon" and args.has("--abandon-profile-blocked")
	if args.has("--terminal-crash"):
		if abandon_profile_blocked:
			TerminalCrash.abandon_while_profile_blocked(self, args.has("--abandon-analytics-blocked"))
		else:
			TerminalCrash.crash(self, kind, args.has("--after-terminal-checkpoint"))
		return
	var profile_before := ProgressionStore.load_data()
	var profile_hash: String = FileAccess.get_sha256(ProgressionStore._storage_path)
	var bank := TerminalCrash.expected_bank(kind)
	_assert(int(profile_before["embers"]) == bank, "Crash fixture profile must contain the authored terminal bank")
	var instance: Node = await _instantiate_menu()
	if instance == null:
		TerminalCrash._fail(self, "title did not load")
		return
	if kind == "defeat":
		_assert(_defeat_closing_types() == ["combat_ended", "run_ended"], "Title boot must deliver the defeat closing pair")
		var rows := TerminalCrash.Analytics.load_all_events().filter(func(event: Dictionary) -> bool:
			return event["run_id"] == TerminalCrash.RUN_ID and event["event_type"] == "combat_ended")
		if rows.size() == 1:
			var payload: Dictionary = rows[0]["payload"]
			_assert(payload["objective_completion_tile"] is Dictionary and payload["objective_completion_tile"] == {"x": -1.0, "y": -1.0}
				and payload["objective_completion_door"] is Dictionary and payload["objective_completion_door"] == {"x": -1.0, "y": -1.0}
				and payload["objective_completion_destination"] is Dictionary and payload["objective_completion_destination"] == {"x": 999.0, "y": 999.0},
				"4 — recovered defeat coordinates retain the live JSON object shape")
			print("DEFEAT REPLAY COORDINATES: ", JSON.stringify(payload["objective_completion_tile"]))
	if abandon_profile_blocked:
		var endings := _run_ended_events(TerminalCrash.RUN_ID)
		_assert(endings.is_empty(), "1 — relaunch cannot publish an uncommitted Abandon")
		_assert(not instance.continue_button.disabled and ProgressionStore.load_data() == profile_before,
			"Failed Abandon must preserve Continue and the profile on relaunch")
		print("ABANDON RELAUNCH: run_ended=", endings.size(), " continue=", not instance.continue_button.disabled)
		_stop_menu_music(instance)
		instance.free()
		for failure: String in _failures: push_error(failure)
		print("TEST RESULT: %s — blocked Abandon relaunch" % ["PASS" if _failures.is_empty() else "FAIL"])
		quit(0 if _failures.is_empty() else 1)
		return
	var continue_disabled: bool = instance.continue_button.disabled
	var profile_intact: bool = ProgressionStore.load_data() == profile_before and FileAccess.get_sha256(ProgressionStore._storage_path) == profile_hash
	_assert(continue_disabled and not instance.resume_panel.visible, "Finished %s must not offer Continue" % kind)
	_assert(profile_intact, "Discarding %s must preserve the entire profile" % kind)
	if args.has("--capture"):
		await RenderingServer.frame_post_draw
		_assert(root.size == TerminalCrash.VIEWPORT and is_equal_approx(root.content_scale_factor, 1.0), "Title capture must use 1920×1080 at 100% UI scale")
		var title: Image = root.get_texture().get_image()
		var capture_path := directory.path_join("terminal-title.png")
		_assert(title != null and not title.is_empty() and title.save_png(capture_path) == OK, "Title capture should be saved")
		print(capture_path)
	_stop_menu_music(instance)
	instance.call("_prepare_new_game")
	instance.free()
	await _complete_new_game_transition()
	if kind == "defeat":
		var types := _defeat_closing_types()
		print("DEFEAT CLOSING EVENTS: ", types)
		_assert(types == ["combat_ended", "run_ended"], "Defeat relaunch must deliver the ordered closing pair exactly once")
	else:
		var outcome: String = {"embrace": "embrace", "abandon": "abandoned", "escape": "victory", "demo": "victory"}[kind]
		var endings := _run_ended_events(TerminalCrash.RUN_ID)
		_assert(endings.size() == 1 and endings[0]["idempotency_key"] == "run_ended|" + TerminalCrash.RUN_ID and endings[0]["payload"]["outcome"] == outcome,
			"Terminal relaunch must deliver one run-ID-keyed " + outcome)
		print("RUN END RELAUNCH: outcome=", outcome, " run_ended=", endings.size())
	var next_profile := ProgressionStore.load_data()
	var new_run := ProgressionStore.load_saved_run()
	var bank_preserved: bool = int(next_profile["embers"]) == bank and int(new_run.get("held_embers", -1)) == bank
	_assert(bank_preserved, "New Descent after %s must keep the bank" % kind)
	_assert(next_profile["recovery_marker"] == profile_before["recovery_marker"], "New Descent must preserve the recovery marker")
	_assert(ProgressionStore.completed_run_results(next_profile) == ProgressionStore.completed_run_results(profile_before), "New Descent must preserve completed results")
	print("TERMINAL RELAUNCH: %s continue=%s profile_intact=%s bank=%d new_bank=%d new_held=%d" % [
		kind, not continue_disabled, profile_intact, bank, next_profile["embers"], new_run.get("held_embers", -1),
	])
	for failure: String in _failures: push_error(failure)
	print("TEST RESULT: %s — %s terminal crash recovery" % ["PASS" if _failures.is_empty() else "FAIL", kind])
	quit(0 if _failures.is_empty() else 1)

func _run_ended_events(run_id: String) -> Array:
	return TerminalCrash.Analytics.load_all_events().filter(func(event: Dictionary) -> bool:
		return event["event_type"] == "run_ended" and event["run_id"] == run_id)

func _defeat_closing_types() -> Array:
	var records := TerminalCrash.Analytics.load_all_events().filter(func(event: Dictionary) -> bool:
		return event["run_id"] == TerminalCrash.RUN_ID and event["event_type"] in ["combat_ended", "run_ended"])
	return records.map(func(event: Dictionary) -> String: return event["event_type"])

func _test_completed_checkpoint_selection() -> void:
	var profile := OpeningBoonFixture.unlocked_profile()
	var finished := _valid_combat_run(profile)
	finished["run_index"] = 0
	finished["analytics"] = {"run_id": FINISHED_RUN_ID}
	var completed := ProgressionStore.record_run_completion(profile, finished)
	_assert(ProgressionStore.record_run_completion(completed, finished) == completed, "Completing one run twice must retain exactly one receipt")
	_assert(ProgressionStore.save_data(completed), "Completion profile should save")

	var other := finished.duplicate(true)
	other["analytics"]["run_id"] = OTHER_RUN_ID
	_assert(ProgressionStore.save_run_state(other), "Cloned-counter and seed fixture should save")
	_expect_checkpoint("4 — a distinct run with the same seed and counter remains resumable", OTHER_RUN_ID)

	var legacy := finished.duplicate(true)
	legacy.erase("analytics")
	_assert(ProgressionStore.save_run_state(legacy), "Legacy checkpoint should save")
	_expect_checkpoint("4 — a legacy checkpoint without an ID remains resumable", "", "combat")
	var coarse_profile := ProgressionStore.record_run_result(profile, RunEngine.run_result_id(legacy), {"damage_dealt": 1})["data"] as Dictionary
	coarse_profile["completed_run_ids"] = [RunEngine.run_result_id(legacy)]
	_assert(ProgressionStore.save_data(coarse_profile), "Legacy completion profile should save")
	_expect_checkpoint("4 — old result and completion IDs do not establish a match", "", "combat")
	_assert(ProgressionStore.save_data(completed), "Restore the finished run's profile")

	_assert(ProgressionStore.save_run_state(finished), "Stale live checkpoint should save")
	var live_hash := FileAccess.get_sha256(RUN_PATH)
	var menu: Node = await _instantiate_menu()
	_assert(menu.continue_button.disabled and not menu.resume_panel.visible, "A matching finished checkpoint must hide Continue")
	_assert(FileAccess.get_sha256(RUN_PATH) == live_hash, "5 — matching a finished checkpoint must preserve its bytes")
	_stop_menu_music(menu)
	menu.free()

	other["run_index"] = 1
	_assert(ProgressionStore.save_run_state(finished), "Restore the stale live checkpoint")
	var backup := FileAccess.open(RUN_PATH + ".backup", FileAccess.WRITE)
	backup.store_var(other)
	backup.close()
	var backup_hash := FileAccess.get_sha256(RUN_PATH + ".backup")
	_expect_checkpoint("5 — a stale live file must allow inspection of the distinct backup", OTHER_RUN_ID)
	_assert(FileAccess.get_sha256(RUN_PATH) == live_hash and FileAccess.get_sha256(RUN_PATH + ".backup") == backup_hash, "5 — selection must preserve both checkpoint files")

	var terminal := finished.duplicate(true)
	terminal["mode"] = "defeat"
	terminal["combat_state"] = {}
	_assert(ProgressionStore.save_run_state(terminal), "A finalized terminal record should save")
	backup = FileAccess.open(RUN_PATH + ".backup", FileAccess.WRITE)
	backup.store_var(other)
	backup.close()
	terminal = ProgressionStore.load_saved_run()
	var terminal_hash := FileAccess.get_sha256(RUN_PATH)
	_expect_checkpoint("Finalized terminal live file leaves a distinct active backup selectable", OTHER_RUN_ID)
	_assert(FileAccess.get_sha256(RUN_PATH) == terminal_hash and FileAccess.get_sha256(RUN_PATH + ".backup") == backup_hash,
		"Selecting the playable backup leaves both terminal and active files intact")
	var promoted := ProgressionStore.load_checkpoint_for_replacement()
	_assert(ProgressionStore.completion_run_id(promoted.get("state", {})) == OTHER_RUN_ID
		and ProgressionStore.completion_run_id(ProgressionStore.load_saved_run()) == OTHER_RUN_ID,
		"Confirmed replacement promotes the selected backup before its transaction")

	var prompt := HeirloomFixture.equip(finished)
	prompt["mode"] = "victory"
	prompt["heirloom_end"] = {"done": false}
	_assert(ProgressionStore.save_run_state(prompt), "Unprocessed terminal fallback should save")
	_expect_checkpoint("1 — an unprocessed heirloom fallback wins over the completion receipt", FINISHED_RUN_ID, "victory")
	prompt["heirloom_terminal_wallet"] = {"victory_carry": 74}
	completed["run_counter"] = 1
	_assert(ProgressionStore.save_data(completed) and ProgressionStore.save_run_state(prompt), "Interrupted New Descent fixture should save its settled prompt and advanced profile")
	_expect_checkpoint("2 — an advanced descent counter must preserve a pending prompt", FINISHED_RUN_ID, "victory")

func _expect_checkpoint(label: String, id: String, mode: String = "combat") -> void:
	var before := FileAccess.get_sha256(RUN_PATH)
	var selected: Dictionary = ProgressionStore.read_resumable_checkpoint().get("state", {})
	print("COMPLETION REGRESSION ", label, " selected=", selected.get("mode", "none"))
	_assert(selected.get("mode", "") == mode and selected.get("analytics", {}).get("run_id", "") == id, label)
	_assert(FileAccess.get_sha256(RUN_PATH) == before, label + " (live bytes preserved)")

func _boot_host() -> BootHost:
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	instance.set_script(BootHost)
	root.add_child(instance)
	return instance as BootHost

func _test_backup_resume_rotation() -> void:
	var profile := ProgressionStore.default_data()
	var finished := _valid_combat_run(profile)
	finished["analytics"] = {"run_id": FINISHED_RUN_ID}
	var active := _valid_combat_run(profile)
	active["analytics"] = {"run_id": OTHER_RUN_ID}
	_assert(ProgressionStore.save_data(ProgressionStore.record_run_completion(profile, finished)), "Backup fixture records the finished live run")
	_assert(ProgressionStore.save_run_state(finished), "Backup fixture writes the finished live checkpoint")
	var backup := FileAccess.open(RUN_PATH + ".backup", FileAccess.WRITE)
	backup.store_var(active)
	backup.close()
	var backup_hash := FileAccess.get_sha256(RUN_PATH + ".backup")
	_expect_checkpoint("2 — title selects the distinct backup", OTHER_RUN_ID)

	var host := _boot_host()
	root.set_meta("labyrinth_resume_saved_run", true)
	host._boot_initial_run(false)
	_assert(host._run_state.get("analytics", {}).get("run_id", "") == OTHER_RUN_ID, "2 — Continue actually installs the backup run")
	_assert(FileAccess.get_sha256(RUN_PATH) == backup_hash, "2 — actual Continue promotes the exact bytes before any writer can run")
	_assert(FileAccess.get_sha256(RUN_PATH + ".backup") == backup_hash, "2 — backup remains intact at promotion")
	var stop_after_rotation := func(stage: String) -> bool: return stage != "recovery_ready"
	_assert(not ProgressionStore._save_run_state_at(RUN_PATH, active, stop_after_rotation, true), "2 — force Windows rotation and interrupt before promotion")
	_assert(not FileAccess.file_exists(RUN_PATH), "2 — interruption leaves live missing")
	_assert(FileAccess.get_sha256(RUN_PATH + ".backup") == backup_hash, "2 — the first interrupted rotation preserves run B")
	_assert(ProgressionStore.read_resumable_checkpoint().get("state", {}).get("analytics", {}).get("run_id", "") == OTHER_RUN_ID, "2 — a relaunch can still select B after interrupted rotation")
	host.free()
	ProgressionStore.clear_saved_run()

func _test_interrupted_new_descent_marker() -> void:
	var profile := ProgressionStore.default_data()
	profile["run_counter"] = DEFEATED_RUN
	profile = ProgressionStore.record_lost_embers(profile, TerminalCrash.HELD, RECOVERY_ROOM, DEFEATED_RUN)
	_assert(ProgressionStore.save_data(profile), "3 — fixture saves the dropped Embers")
	var marker: Dictionary = ProgressionStore.recovery_marker(ProgressionStore.load_data())
	var legacy := profile.duplicate(true)
	legacy["run_counter"] = DEFEATED_RUN + 1
	var predecessor := {"mode": "defeat", "run_index": DEFEATED_RUN, "current_room": RECOVERY_ROOM}
	var legacy_retry := ProgressionStore.prepare_for_new_run(legacy, predecessor)
	_assert(int(legacy_retry["run_counter"]) == DEFEATED_RUN + 1 and int(ProgressionStore.recovery_marker(legacy_retry).get("amount", 0)) == TerminalCrash.HELD, "3 — an older interrupted descent can recover from the terminal checkpoint that owns its marker")
	var blocker := ProjectSettings.globalize_path(RUN_PATH + ".tmp")
	var first := _boot_host()
	first._defer_initial_run_presentation = true
	_assert(DirAccess.make_dir_absolute(blocker) == OK, "3 — block replacement after the profile advances")
	_assert(not first._commit_new_run(first._start_run(true), {}), "3 — failed replacement is reported as failed")
	_assert(int(ProgressionStore.load_data()["run_counter"]) == DEFEATED_RUN + 1 and not ProgressionStore.has_saved_run(), "3 — reservation advanced but no run was installed")
	_assert(ProgressionStore.recovery_marker(ProgressionStore.load_data()) == marker, "3 — interrupted install keeps its recovery marker")
	_assert(DirAccess.remove_absolute(blocker) == OK, "3 — remove the checkpoint blocker")
	first.free()

	var retry := _boot_host()
	retry._defer_initial_run_presentation = true
	_assert(retry._commit_new_run(retry._start_run(true), {}), "3 — a fresh scene can retry New Descent")
	_assert(int(ProgressionStore.load_saved_run().get("run_index", -1)) == DEFEATED_RUN + 1, "3 — retry installs the reserved run counter")
	_assert(ProgressionStore.recovery_marker(ProgressionStore.load_data()) == marker, "3 — retry keeps the marker for the run the player can now play")
	_assert(DirAccess.make_dir_absolute(blocker) == OK, "3 — block the replacement that would normally expire the marker")
	_assert(not retry._commit_new_run(retry._start_run(true), {}), "3 — the expiring replacement fails to install")
	_assert(ProgressionStore.recovery_marker(ProgressionStore.load_data()) == marker, "3 — the marker remains durable until the expiring checkpoint installs")
	_assert(DirAccess.remove_absolute(blocker) == OK, "3 — remove the second blocker")
	_assert(retry._commit_new_run(retry._start_run(true), {}), "3 — the next checkpoint now installs")
	_assert(int(ProgressionStore.load_saved_run().get("run_index", -1)) == DEFEATED_RUN + 2 and ProgressionStore.recovery_marker(ProgressionStore.load_data()).is_empty(), "3 — expiry commits only once the following checkpoint installs")
	retry.free()

func _test_interrupted_descent_then_defeat() -> void:
	ProgressionStore.clear_saved_run()
	const OLD_LOSS := 100
	var profile := ProgressionStore.record_lost_embers(ProgressionStore.default_data(), OLD_LOSS, RECOVERY_ROOM, DEFEATED_RUN - 1)
	profile["run_counter"] = DEFEATED_RUN
	var active := RunEngine.new().create_debug_boss_run(profile)
	active["debug_boss_run"] = false
	active["run_index"] = DEFEATED_RUN
	active["analytics"] = {"run_id": FINISHED_RUN_ID}
	active = RunEngine.new().set_held_embers(active, TerminalCrash.HELD)
	_assert(ProgressionStore.save_data(profile) and ProgressionStore.save_run_state(active), "5 — save the active run with its earlier marker")
	var run_blocker := ProjectSettings.globalize_path(RUN_PATH + ".tmp")
	_assert(DirAccess.make_dir_absolute(run_blocker) == OK, "5 — block the replacement checkpoint")
	var host := _boot_host()
	host._defer_initial_run_presentation = true
	_assert(not host._commit_new_run(host._start_run(true), {}), "5 — interrupt replacement after reservation")
	_assert(not str(ProgressionStore.load_data().get(ProgressionStore.PENDING_DESCENT_ID_KEY, "")).is_empty(), "5 — the interrupted descent has a reservation")
	_assert(DirAccess.remove_absolute(run_blocker) == OK, "5 — restore checkpoint writes")
	host._run_state = ProgressionStore.load_saved_run()
	host._progression = host._run_state["progression"]
	var combat: Dictionary = host._run_state["combat_state"].duplicate(true)
	combat["player"]["hp"] = 0
	var blocker := ProjectSettings.globalize_path(PROGRESSION_PATH + ".tmp")
	_assert(DirAccess.make_dir_absolute(blocker) == OK, "5 — block defeat profile settlement")
	var defeated := host._run_state_for_combat_checkpoint(host._run_state, combat)
	_assert(not bool(host._persist_run_state_snapshot(defeated, false, "enemy_round_complete")["saved"]), "5 — defeat keeps its terminal fallback")
	_assert(ProgressionStore.load_saved_run().get("mode") == "defeat", "5 — the new loss is recoverable from the checkpoint")
	_assert(DirAccess.remove_absolute(blocker) == OK, "5 — restore profile writes before New Descent")
	var request := host._start_run(true)
	var marker := ProgressionStore.recovery_marker(ProgressionStore.load_data())
	print("RECOVERY MARKER AFTER INTERRUPTED DESCENT: ", marker.get("amount", 0))
	_assert(not request.is_empty() and int(marker.get("amount", 0)) == TerminalCrash.HELD, "5 — recovering the new defeat replaces the older marker")
	host.free()

func _test_terminal_withdrawal_without_profile() -> void:
	const Recap = preload("res://scripts/run_end_recap_overlay.gd")
	_cleanup_storage()
	var profile := ProgressionStore.leave_heirloom(ProgressionStore.default_data(), HeirloomFixture.PROOF_ITEMS[0])
	profile["run_counter"] = DEFEATED_RUN
	var engine := RunEngine.new()
	var active := engine.set_held_embers(engine.create_new_run(TerminalCrash.SEED, profile), TerminalCrash.HELD)
	active["mode"] = "campfire"
	active["analytics"] = {"run_id": FINISHED_RUN_ID}
	var settled_profile := ProgressionStore.set_embers(profile, TerminalCrash.HELD)
	var withdrawal := Recap.embrace_state(active, settled_profile)
	withdrawal["embrace_settlement"] = true
	withdrawal["progression"] = ProgressionStore.record_run_completion(withdrawal["progression"], withdrawal)
	_assert(ProgressionStore.save_run_state(withdrawal), "Cloud fixture receives only the terminal checkpoint")
	var host := _boot_host()
	host._defer_initial_run_presentation = true
	var request := host._start_run(true)
	_assert(not request.is_empty() and host._commit_new_run(request, {}), "A fresh profile can recover the withdrawal and start a new descent")
	var installed := ProgressionStore.load_data()
	_assert(int(installed["embers"]) == TerminalCrash.HELD and int(installed["run_counter"]) == DEFEATED_RUN + 1
		and ProgressionStore.heirloom(installed) == HeirloomFixture.PROOF_ITEMS[0],
		"The terminal checkpoint recovers the bank, descent counter and heirloom together")
	host.free()

func _test_valid_save_summary_and_replacement_gate() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 91
	progression["level"] = 3
	progression["skill_ids"] = ["quick_wits", "discerning_eye"]
	progression = ProgressionStore.normalized_data(progression)
	_assert(ProgressionStore.save_data(progression), "Valid-save fixture should write progression")
	var run_state: Dictionary = _valid_combat_run(progression)
	run_state["analytics"] = {"run_id": REPLACED_RUN_ID}
	_assert(ProgressionStore.save_run_state(run_state), "Valid-save fixture should write the run")
	var bytes_before: PackedByteArray = _run_file_bytes()
	var instance: Node = await _instantiate_menu()
	if instance == null:
		return
	var continue_button: Button = instance.get_node("MenuColumn/ContinueButton")
	var start_button: Button = instance.get_node("MenuColumn/StartButton")
	var footer: Label = instance.get_node("ProfileBlock/Footer")
	var resume_panel: PanelContainer = instance.get_node("ResumePanel")
	var resume_location: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation")
	var resume_stats: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeStats")
	var replacement_panel: PanelContainer = instance.get_node("ReplacementPanel")
	var replacement_location: Label = instance.get_node("ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementLocation")
	var replacement_stats: Label = instance.get_node("ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementStats")
	var replacement_cancel: Button = instance.get_node("ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementActions/ReplacementCancelButton")
	var replacement_confirm: Button = instance.get_node("ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementActions/ReplacementConfirmButton")
	_assert(resume_panel.visible, "A valid save should show the resume card")
	_assert(resume_location.text == "DEPTH 4 · IN COMBAT", "Resume card should show the saved depth and mode")
	_assert(resume_stats.text == "HEALTH 175/260 · HELD 74 EMBERS", "Resume card should show accurate saved HP and explicitly identify held embers")
	_assert(footer.text == "LV 3 · EMBERS 91 · SKILLS 2/19", "Main-menu profile summary should show learned skills instead of retired card growth")
	_assert(continue_button.text == "Continue Run" and not continue_button.disabled, "Continue should become the primary enabled action for a valid save")
	_assert(str(continue_button.get_meta("button_variant", "")) == "umbra" and str(start_button.get_meta("button_variant", "")) == "umbra", "Main-menu actions should use the generated-art Umbra Obsidian button variant")
	_assert(bool(continue_button.get_meta("umbra_selected", false)) and not bool(start_button.get_meta("umbra_selected", false)), "A valid save should make Continue the only glowing default selection")
	var continue_style: StyleBoxFlat = continue_button.get_theme_stylebox("normal") as StyleBoxFlat
	var start_style: StyleBoxFlat = start_button.get_theme_stylebox("normal") as StyleBoxFlat
	_assert(continue_style != null and start_style != null and continue_style.bg_color == Color.TRANSPARENT and start_style.bg_color == Color.TRANSPARENT, "Umbra layout styles should stay transparent so generated raster art is the sole visible button surface")
	var continue_ornament: Control = continue_button.get_node_or_null("ThemedButtonOrnament") as Control
	var start_ornament: Control = start_button.get_node_or_null("ThemedButtonOrnament") as Control
	_assert(continue_ornament != null and start_ornament != null and str(continue_ornament.call("_visual_state")) == "selected" and str(start_ornament.call("_visual_state")) == "normal", "Primary Continue should render the only focused generated-art state")
	_assert(_run_file_bytes() == bytes_before, "Rendering the valid-save summary must not rewrite the run file")

	start_button.pressed.emit()
	await process_frame
	_assert(replacement_panel.visible and not resume_panel.visible, "New Game should open replacement confirmation instead of replacing a valid save")
	_assert(continue_button.disabled and start_button.disabled, "Replacement confirmation should lock the background menu actions")
	_assert(replacement_location.text == resume_location.text and replacement_stats.text == resume_stats.text, "Replacement confirmation should repeat the exact saved-run summary")
	_assert(ProgressionStore.has_saved_run() and _run_file_bytes() == bytes_before, "Opening replacement confirmation must not mutate or clear the save")

	replacement_cancel.pressed.emit()
	await process_frame
	_assert(not replacement_panel.visible and resume_panel.visible, "Cancel should return to the resume card")
	_assert(ProgressionStore.has_saved_run() and _run_file_bytes() == bytes_before, "Cancel should leave the saved run byte-for-byte unchanged")

	start_button.pressed.emit()
	await process_frame
	_stop_menu_music(instance)
	root.remove_child(instance)
	instance.call("_prepare_new_game")
	# meta-02 defers replacement to RunScene's durable save boundary.
	_assert(_run_file_bytes() == bytes_before, "Replacement preparation must preserve the previous save")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 91, "Replacement preparation must preserve the previous profile")
	await _complete_new_game_transition()
	_assert(ProgressionStore.has_saved_run() and _run_file_bytes() != bytes_before, "Explicit replacement should durably replace the saved run")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 0, "Confirmed replacement should preserve the existing New Game ember-reset semantic")
	var ends := _run_ended_events(REPLACED_RUN_ID)
	_assert(ends.size() == 1 and ends[0]["idempotency_key"] == "run_ended|" + REPLACED_RUN_ID and ends[0]["payload"]["outcome"] == "abandoned",
		"Confirmed replacement should end the previous run exactly once")
	var replacement_bytes := _run_file_bytes()
	var stale := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	stale.store_buffer(bytes_before)
	stale.close()
	_assert(ProgressionStore.read_resumable_checkpoint().get("state", {}).is_empty(),
		"The confirmed replacement's discarded checkpoint cannot resume after sync")
	var restored := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	restored.store_buffer(replacement_bytes)
	restored.close()
	instance.free()
	await process_frame

func _test_graftwright_saves_resume() -> void:
	var state: Dictionary = GraftwrightSuite.fixture()
	_assert(ProgressionStore.save_data(state["progression"]), "Graftwright resume fixture should write progression")
	for used: bool in [false, true]:
		if used:
			state = RunEngine.new().graft_equipment(state, "undertaker_plate", "patched_cloak", 1, 1)
		_assert(ProgressionStore.save_run_state(state), "Graftwright resume fixture should write the run")
		var bytes_before: PackedByteArray = _run_file_bytes()
		var instance: Node = await _instantiate_menu()
		if instance == null: return
		var button: Button = instance.get_node("MenuColumn/ContinueButton")
		var location: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation")
		_assert(not button.disabled and button.text == "Continue Run", "Graftwright save should enable Continue before and after grafting (used=%s)" % used)
		_assert(location.text.contains("GRAFTWRIGHT"), "Graftwright save summary should identify the encounter")
		_assert(_run_file_bytes() == bytes_before, "Inspecting a Graftwright save must not change equipment or replay a graft")
		var invalid: Dictionary = state.duplicate(true)
		var coord: Vector2i = invalid["current_room"]
		invalid["rooms"]["%d,%d" % [coord.x, coord.y]]["type"] = "combat"
		_assert((instance.call("_build_saved_run_preview", invalid) as Dictionary).is_empty(), "A mismatched room must not masquerade as a resumable Graftwright")
		_stop_menu_music(instance)
		instance.queue_free()
		await process_frame

func _test_dragon_reward_save_resumes() -> void:
	var options: Dictionary = {"dragon_id": "vyraketh", "dragon_depth": 4, "dragon_case": "reward", "dragon_build": "balanced"}
	var engine := RunEngine.new()
	var state: Dictionary = DragonBossInspection.build(engine, CombatEngine.new(), engine.create_new_run(DragonBossInspection.seed_for_options(options), ProgressionStore.default_data()), options)
	_assert(engine.is_dragon_reward(state), "Dragon reward resume fixture should be a dragon milestone reward")
	_assert(ProgressionStore.save_data(ProgressionStore.default_data()), "Dragon reward resume fixture should write progression")
	_assert(ProgressionStore.save_run_state(state), "Dragon reward resume fixture should write the run")
	var instance: Node = await _instantiate_menu()
	if instance == null: return
	var button: Button = instance.get_node("MenuColumn/ContinueButton")
	_assert(not button.disabled and button.text == "Continue Run", "A save paused on a dragon's milestone reward should enable Continue")
	var invalid: Dictionary = state.duplicate(true)
	(invalid["pending_reward"] as Dictionary)["milestone_id"] = ""
	_assert((instance.call("_build_saved_run_preview", invalid) as Dictionary).is_empty(), "A dragon reward without its milestone must not be resumable")
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _test_no_save_hides_summary() -> void:
	ProgressionStore.clear_saved_run()
	var instance: Node = await _instantiate_menu()
	if instance == null:
		return
	var continue_button: Button = instance.get_node("MenuColumn/ContinueButton")
	var start_button: Button = instance.get_node("MenuColumn/StartButton")
	var settings_button: Button = instance.get_node("MenuColumn/SettingsButton")
	var resume_panel: PanelContainer = instance.get_node("ResumePanel")
	var replacement_panel: PanelContainer = instance.get_node("ReplacementPanel")
	var resume_location: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation")
	var resume_stats: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeStats")
	_assert(continue_button.disabled and continue_button.text == "Continue", "No-save state should keep Continue secondary and disabled")
	_assert(not bool(continue_button.get_meta("umbra_selected", false)) and bool(start_button.get_meta("umbra_selected", false)), "Without a save, New Game should be the only glowing default selection")
	settings_button.mouse_entered.emit()
	_assert(bool(settings_button.get_meta("umbra_selected", false)) and not bool(start_button.get_meta("umbra_selected", false)), "Pointer hover should move the exclusive Umbra glow to the hovered action")
	settings_button.mouse_exited.emit()
	await process_frame
	_assert(bool(settings_button.get_meta("umbra_selected", false)) and not bool(start_button.get_meta("umbra_selected", false)), "Leaving a menu action should retain the last selection instead of snapping to the default primary action")
	_assert(not resume_panel.visible and not replacement_panel.visible, "No-save state should hide all saved-run context panels")
	_assert(resume_location.text.is_empty() and resume_stats.text.is_empty(), "No-save state should clear summary text instead of retaining stale data")
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _test_corrupt_save_is_hidden_and_recoverable() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 33
	_assert(ProgressionStore.save_data(progression), "Corrupt-save fixture should write progression")
	var file: FileAccess = FileAccess.open(RUN_PATH, FileAccess.WRITE)
	_assert(file != null, "Corrupt-save fixture should open the run path")
	if file == null:
		return
	file.store_var(_dictionary_shaped_corrupt_run(), false)
	file.close()
	var bytes_before: PackedByteArray = _run_file_bytes()
	var instance: Node = await _instantiate_menu()
	if instance == null:
		return
	var continue_button: Button = instance.get_node("MenuColumn/ContinueButton")
	var start_button: Button = instance.get_node("MenuColumn/StartButton")
	var resume_panel: PanelContainer = instance.get_node("ResumePanel")
	var replacement_panel: PanelContainer = instance.get_node("ReplacementPanel")
	var resume_location: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation")
	var resume_stats: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeStats")
	_assert(continue_button.disabled and not resume_panel.visible and not replacement_panel.visible, "A dictionary-shaped corrupt save should not expose Continue or saved-run context")
	_assert(resume_location.text.is_empty() and resume_stats.text.is_empty(), "A corrupt save should not leak stale summary text")
	_assert(_run_file_bytes() == bytes_before, "Rendering a corrupt-save state must not rewrite or clear the bad file")
	_stop_menu_music(instance)
	root.remove_child(instance)
	instance.call("_prepare_new_game")
	_assert(_run_file_bytes() == bytes_before, "Corrupt-save replacement preparation must preserve the old bytes")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 33, "Corrupt-save replacement preparation must preserve the profile")
	await _complete_new_game_transition()
	_assert(ProgressionStore.has_saved_run() and _run_file_bytes() != bytes_before and not ProgressionStore.load_saved_run().is_empty(), "New Game should recover by durably replacing the corrupt save")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 0, "Corrupt-save recovery should use the existing New Game replacement semantic")
	instance.free()
	await process_frame

func _complete_new_game_transition() -> void:
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	# Exercise the real fresh-run bootstrap while deferring unrelated presentation.
	scene.set("_defer_initial_run_presentation", true)
	root.add_child(scene)
	await process_frame
	scene.queue_free()
	await process_frame

func _valid_combat_run(progression: Dictionary) -> Dictionary:
	var run_state: Dictionary = RunEngine.new().create_debug_boss_run(progression)
	run_state["debug_boss_run"] = false
	run_state["player_hp"] = 175
	run_state["player_max_hp"] = 260
	run_state["held_embers"] = 74
	run_state["unbanked_embers"] = 74
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 175
	player["max_hp"] = 260
	combat_state["player"] = player
	run_state["combat_state"] = combat_state
	return run_state

func _dictionary_shaped_corrupt_run() -> Dictionary:
	return {
		"seed": 9081,
		"mode": "combat",
		"current_room": Vector2i.ZERO,
		"current_room_layout": {"width": 9, "height": 9},
		"rooms": {"0,0": {"coord": Vector2i.ZERO, "depth": 0, "type": "combat"}},
		"deck_cards": ["quick_stab"],
		"player_hp": 50,
		"player_max_hp": 100,
		"held_embers": 10,
		"unbanked_embers": 10,
		"combat_state": {}
	}

func _instantiate_menu() -> Node:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_assert(packed != null, "Main menu scene should load")
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance

func _run_file_bytes() -> PackedByteArray:
	var file: FileAccess = FileAccess.open(RUN_PATH, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes

func _cleanup_storage() -> void:
	ProgressionStore.clear_saved_run()
	var progression_path: String = ProjectSettings.globalize_path(PROGRESSION_PATH)
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(progression_path)

func _stop_menu_music(instance: Node) -> void:
	var music_player: AudioStreamPlayer = instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player == null:
		return
	music_player.stop()
	music_player.stream = null

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
