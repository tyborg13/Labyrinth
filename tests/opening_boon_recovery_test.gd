extends "res://tests/pre_battle_fixture.gd"

## Fault injection stays focused: no extra scene startups/waits in the full suite.
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recovery = preload("res://scripts/opening_boon_recovery.gd")
const PROFILE_PATH: String = "user://pre_battle_probe_progression.json"
const RUN_PATH: String = "user://pre_battle_probe_run.save"
const ANALYTICS_PATH: String = "user://opening_boon_recovery_analytics"
const WRITE_BLOCKER: String = "user://opening_boon_write_blocker"
const FAILED_WRITE_PATH: String = WRITE_BLOCKER + "/unwritable"
const SETTLED_WALLET: int = 120
const RECOVERY_COORD: Vector2i = Vector2i(2, 0)
var _acknowledgment_failures: int = 0

func _initialize() -> void:
	_setup()
	Analytics.set_storage_dir(ANALYTICS_PATH)
	Analytics.clear_storage()
	var blocker := FileAccess.open(WRITE_BLOCKER, FileAccess.WRITE)
	blocker.store_string("A file cannot be used as the parent directory of a write.")
	blocker.close()
	call_deferred("_run")

func _run() -> void:
	ProgressionStore.save_data(Fixture.profile())
	var scene: Node = await _instance(Fixture.force_boon("vitality"))
	_consumed_heirloom_replacement(scene)
	_equal_revision_profile(scene)
	_terminal_wallet_replacement(scene)
	_failed_terminal_profile(scene)
	scene = await _resumed_victory_wallet(scene)
	for quit_first: bool in [true, false]: _terminal_receipts(scene, quit_first)
	_failed_choices(scene)
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	await process_frame
	print("OPENING BOON RECOVERY TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _prepare(scene: Node, state: Dictionary) -> void:
	scene.set("_dialogue_script", {})
	scene.call("_close_dialogue")
	scene.set("_progression", state["progression"].duplicate(true))
	_expect(ProgressionStore.save_data(state["progression"]) and ProgressionStore.save_run_state(state), "Fault fixture saves its baseline")
	scene.call("_load_run_state", state)

func _consumed_heirloom_replacement(scene: Node) -> void:
	_prepare(scene, Fixture.force_boon("heirloom"))
	scene.call("_speak_to_emaciated_man")
	_block_profile_writes()
	scene.get("_opening_boon_flow").call("_choose", "heirloom", [], scene)
	_restore_profile_writes()
	_expect(ProgressionStore.heirloom(ProgressionStore.load_data()) == Fixture.PROOF_HEIRLOOM, "Injected profile failure leaves the older Rapier profile on disk")
	_expect(ProgressionStore.heirloom(ProgressionStore.load_saved_run()["progression"]).is_empty(), "The durable run records Rapier consumption despite deferred profile write")
	_expect(scene.get("_run_state")["equipped_equipment"]["weapon"] == Fixture.PROOF_HEIRLOOM, "Taking the Rapier committed gameplay before the failed profile write")
	var previous: Dictionary = ProgressionStore.load_saved_run()
	Recovery.profile_writer = _fail_acknowledgment_once
	scene.call("_start_run")
	_expect(_acknowledgment_failures == 1, "Exactly one acknowledgment write failed; later writes are available")
	_expect(ProgressionStore.load_saved_run() == previous, "Failed durable acknowledgment refuses to replace the saved run")
	_expect(scene.get("_run_state")[Boons.STATE_KEY].get("chosen", "") == "heirloom", "One-shot acknowledgment failure retains the consumed-heirloom descent")
	scene.call("_start_run")
	var replacement: Dictionary = scene.get("_run_state")
	_expect(ProgressionStore.heirloom(ProgressionStore.load_data()).is_empty(), "Replacement durably acknowledges consumed heirloom")
	_expect(replacement[Boons.STATE_KEY]["offers"][0]["boon"] != "heirloom", "The next descent cannot offer the consumed Rapier again")
	print("BOON RECOVERY: failed profile write / consumed Rapier / replacement checked")

func _fail_acknowledgment_once(_profile: Dictionary) -> bool:
	Recovery.profile_writer = ProgressionStore.save_data
	_acknowledgment_failures += 1
	return false

func _terminal_wallet_replacement(scene: Node) -> void:
	var profile: Dictionary = Fixture.profile()
	var terminal: Dictionary = Fixture.force_boon("vitality")
	terminal["mode"] = "victory"
	terminal["held_embers"] = 0
	terminal["unbanked_embers"] = 0
	terminal["heirloom_terminal_wallet"] = {"victory_carry": SETTLED_WALLET, "defeat_lost": 0}
	terminal["progression"] = ProgressionStore.set_embers(profile, SETTLED_WALLET)
	terminal["progression"]["progression_revision"] = int(profile["progression_revision"]) + 1
	ProgressionStore.save_data(profile)
	ProgressionStore.save_run_state(terminal)
	scene.call("_start_run")
	_expect(scene.get("_run_engine").held_embers(scene.get("_run_state")) == SETTLED_WALLET, "Replacement recovers the newer settled terminal wallet before creating a descent")

func _equal_revision_profile(scene: Node) -> void:
	var previous: Dictionary = Fixture.force_boon("vitality")
	var profile: Dictionary = ProgressionStore.record_lost_embers(previous["progression"], SETTLED_WALLET, RECOVERY_COORD, int(previous["run_index"]))
	_expect(profile["progression_revision"] == previous["progression"]["progression_revision"], "Stale-save regression has equal revisions and a newer profile recovery marker")
	ProgressionStore.save_data(profile)
	ProgressionStore.save_run_state(previous)
	scene.call("_start_run")
	_expect(int(ProgressionStore.recovery_marker(scene.get("_run_state")["progression"]).get("amount", 0)) == SETTLED_WALLET, "Equal-revision replacement preserves the profile's committed recovery marker")

func _failed_terminal_profile(scene: Node) -> void:
	for outcome: String in ["victory", "defeat"]:
		for presented: bool in [false, true]:
			var living: Dictionary = Fixture.force_boon("vitality")
			_prepare(scene, living)
			var terminal: Dictionary = living.duplicate(true)
			terminal["mode"] = outcome
			terminal["held_embers"] = SETTLED_WALLET
			terminal["unbanked_embers"] = SETTLED_WALLET
			terminal["current_room"] = RECOVERY_COORD
			_block_profile_writes()
			if presented:
				scene.call("_load_run_state", terminal)
				scene.call("_persist_committed_boundary", "boon_failed_terminal_profile")
			else:
				scene.call("_persist_run_state_snapshot", terminal, false, "boon_failed_terminal_profile")
			_restore_profile_writes()
			scene.call("_start_run")
			var replacement: Dictionary = scene.get("_run_state")
			if outcome == "victory":
				_expect(scene.get("_run_engine").held_embers(replacement) == SETTLED_WALLET, "Replacement recovers failed terminal victory banking, presented=" + str(presented))
			else:
				_expect(scene.get("_run_engine").held_embers(replacement) == 0 and int(ProgressionStore.recovery_marker(replacement["progression"]).get("amount", 0)) == SETTLED_WALLET, "Replacement recovers failed terminal death loss once, presented=" + str(presented))
	print("BOON RECOVERY: failed terminal profile writes before/after presentation preserve victory bank and death marker")

func _resumed_victory_wallet(scene: Node) -> Node:
	var living: Dictionary = Fixture.force_boon("vitality")
	_prepare(scene, living)
	var terminal: Dictionary = living.duplicate(true)
	terminal["mode"] = "victory"
	terminal["held_embers"] = SETTLED_WALLET
	terminal["unbanked_embers"] = SETTLED_WALLET
	_block_profile_writes()
	scene.call("_load_run_state", terminal)
	scene.get("_opening_boon_flow").leave_heirloom(scene, "")
	var fallback: Dictionary = ProgressionStore.load_saved_run()
	_restore_profile_writes()
	_expect(int(fallback["progression"]["embers"]) == SETTLED_WALLET and fallback.has("heirloom_terminal_wallet"), "Failed settlement and Leave nothing save the settled victory wallet")
	_expect(int(ProgressionStore.load_data()["embers"]) == 0, "Failed settlement leaves the old bank on disk before resume")
	scene.queue_free()
	await process_frame
	await process_frame
	root.set_meta("labyrinth_resume_saved_run", true)
	var resumed: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(resumed)
	await _settle()
	_expect(resumed.get("_run_state")["mode"] == "victory", "A fresh scene resumes the terminal save before replacement")
	_expect(int(ProgressionStore.load_data()["embers"]) == SETTLED_WALLET, "Resume repairs the settled 120-Ember bank with its terminal receipt")
	_expect(int(resumed.get("_progression")["embers"]) == SETTLED_WALLET, "The resumed live profile retains the settled victory bank")
	resumed.call("_start_run")
	_expect(resumed.get("_run_engine").held_embers(resumed.get("_run_state")) == SETTLED_WALLET, "The descent after fresh-scene resume receives all 120 banked Embers")
	print("BOON RECOVERY: failed victory settlement / Leave nothing / fresh-scene resume bank=120 / next descent held=120 checked")
	return resumed

func _terminal_receipts(scene: Node, quit_first: bool) -> void:
	Analytics.clear_storage()
	Analytics.set_storage_dir(WRITE_BLOCKER)
	var state: Dictionary = Boons.choose(RunEngine.new(), Boons.offer(Fixture.force_boon("vitality")), "vitality")
	state["mode"] = "defeat"
	state["player_hp"] = 0
	_prepare(scene, state)
	scene.call("_persist_committed_boundary", "boon_recovery_terminal")
	scene.get("_opening_boon_flow").leave_heirloom(scene, "")
	_expect(ProgressionStore.load_saved_run().get(Boons.EVENTS_KEY, []).size() == 3, "Failed appends retain all three terminal boon receipts")
	var receipt_state: Dictionary = ProgressionStore.load_saved_run()
	if quit_first:
		_block_profile_writes()
		scene.call("_save_run_progress")
		_expect(ProgressionStore.load_saved_run() == receipt_state, "Failed receipt transfer keeps the terminal save intact")
		_restore_profile_writes()
		scene.call("_save_run_progress")
		var outbox: Array[Dictionary] = ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data())
		_expect(_boon_receipts(outbox) == 3, "Save & Quit durably transfers undelivered receipts before clearing the run")
	scene.call("_start_run")
	_expect(_boon_receipts(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data())) == 3, "Replacement preserves the previous run's receipts while appends still fail")
	Analytics.set_storage_dir(ANALYTICS_PATH)
	_expect(_boon_receipts(Analytics.load_all_events()) == 0, "Forced append failure wrote no boon events")
	_expect(scene.call("_reconcile_progression_analytics_outbox"), "Restored appends deliver the durable profile outbox")
	scene.call("_reconcile_progression_analytics_outbox")
	scene.get("_opening_boon_flow").flush_events(scene, receipt_state)
	var counts: Dictionary = {}
	for event: Dictionary in Analytics.load_all_events():
		var type: String = str(event["event_type"])
		counts[type] = int(counts.get(type, 0)) + 1
	for type: String in ["run_start_boon_offered", "run_start_boon_chosen", "heirloom_left"]:
		_expect(int(counts.get(type, 0)) == 1, "Quit/replacement/replay append exactly one " + type)
	_expect(_boon_receipts(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data())) == 0, "Delivered boon receipts are durably acknowledged")
	print("BOON RECOVERY: failed analytics / Leave nothing / Save & Quit / replacement / exactly-once delivery checked")

func _block_profile_writes() -> void:
	_expect(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PROFILE_PATH + ".tmp")) == OK, "Create a write-only profile failure without disturbing its readable live file")

func _restore_profile_writes() -> void:
	_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH + ".tmp")) == OK, "Restore profile writes")

func _boon_receipts(events: Array) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if str(event.get("event_type", "")) in ["run_start_boon_offered", "run_start_boon_chosen", "heirloom_left"]: count += 1
	return count

func _failed_choices(scene: Node) -> void:
	for id: String in ["vitality", "heirloom"]:
		_prepare(scene, Boons.offer(Fixture.force_boon(id)))
		_assert_failed_commit(scene, false, id)
	for outcome: String in ["victory", "defeat"]:
		for leave_item: bool in [false, true]:
			var living: Dictionary = Fixture.force_boon("heirloom")
			_prepare(scene, living)
			var terminal: Dictionary = living.duplicate(true)
			terminal["mode"] = outcome
			terminal["held_embers"] = SETTLED_WALLET
			terminal["unbanked_embers"] = SETTLED_WALLET
			terminal["current_room"] = RECOVERY_COORD
			scene.set("_run_state", terminal)
			_expect(not scene.get("_victory_carry_processed") and not scene.get("_defeat_loss_processed"), "Rollback starts before terminal wallet bookkeeping is processed")
			_expect(ProgressionStore.save_run_state(terminal), "Unprocessed terminal rollback fixture is durable")
			var item: String = str(terminal["equipped_equipment"]["offhand"]) if leave_item else ""
			_assert_failed_commit(scene, true, item)
	print("BOON RECOVERY: injected run-save failures roll back build, progression, terminal flags and receipts")

func _assert_failed_commit(scene: Node, terminal: bool, id: String) -> void:
	var before: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	var profile: Dictionary = (scene.get("_progression") as Dictionary).duplicate(true)
	var saved: Dictionary = ProgressionStore.load_saved_run()
	var disk_profile: Dictionary = ProgressionStore.load_data()
	var events: Array[Dictionary] = Analytics.load_all_events()
	var flags: Array = [scene.get("_victory_carry_processed"), scene.get("_defeat_loss_processed"), scene.get("_victory_carry_amount"), scene.get("_defeat_lost_amount")]
	ProgressionStore.set_run_storage_path(FAILED_WRITE_PATH)
	if terminal: scene.get("_opening_boon_flow").leave_heirloom(scene, id)
	else: scene.get("_opening_boon_flow").call("_choose", id, [], scene)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	_expect(scene.get("_run_state") == before, "Failed authoritative run save rolls back gameplay and run receipts: " + id)
	_expect(scene.get("_progression") == profile, "Failed authoritative run save rolls back live progression: " + id)
	_expect(ProgressionStore.load_saved_run() == saved and ProgressionStore.load_data() == disk_profile, "Failed authoritative run save changes neither durable run nor profile: " + id)
	_expect(Analytics.load_all_events() == events, "A rolled-back choice emits no analytics: " + id)
	_expect(flags == [scene.get("_victory_carry_processed"), scene.get("_defeat_loss_processed"), scene.get("_victory_carry_amount"), scene.get("_defeat_lost_amount")], "A rolled-back choice restores terminal bookkeeping")
