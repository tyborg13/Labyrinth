extends SceneTree

## Each phase is a separate game process. Pass a fresh absolute directory to
## fail, then reuse it for choose, recover, and verify (see README.md).
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Dragon = preload("res://tools/dragon_boss_inspection.gd")
const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")

const HELD: int = 73
const HEIRLOOM: String = "duelist_rapier"
const RUN_ID: String = "gfix-28-terminal-relaunch"
const COMBAT_ID: String = RUN_ID + "_c001"

var _directory: String
var _outcome: String
var _phase: String
var _profile_path: String
var _failures: int


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or not args[0].is_absolute_path() or args[1] not in ["victory", "defeat"] or args[2] not in ["fail", "choose", "choose-retry", "recover", "verify"]:
		_expect(false, "Pass an absolute directory, victory or defeat, and fail, choose, choose-retry, recover, or verify.")
		_finish()
		return
	_directory = args[0]
	_outcome = args[1]
	_phase = args[2]
	_profile_path = _directory.path_join("profile.json")
	Store.set_storage_path(_profile_path)
	Store.set_run_storage_path(_directory.path_join("run.save"))
	Analytics.set_storage_dir(_directory.path_join("analytics"))
	match _phase:
		"fail": _fail_terminal_and_quit()
		"choose", "choose-retry": _choose_and_quit()
		"recover": _recover_and_quit()
		"verify": _verify_final_disk()


func _fail_terminal_and_quit() -> void:
	if FileAccess.file_exists(_profile_path) or DirAccess.make_dir_recursive_absolute(_directory) != OK:
		_expect(false, "Use a fresh writable directory for fail.")
		_finish()
		return
	var engine := Run.new()
	var state := Fixture.state()
	state["analytics"] = {"run_id": RUN_ID, "combat_counter": 1}
	var depth := Run.MAX_DEPTH
	var reward_case: String = "reward" if _outcome == "victory" else "encounter"
	state = Dragon.build(engine, Combat.new(), state, {
		"dragon_id": Bosses.boss_id_for_depth(int(state["seed"]), depth),
		"dragon_depth": depth, "dragon_case": reward_case,
	})
	state = engine.set_held_embers(state, HELD)
	if _outcome == "defeat": state["combat_state"]["analytics"] = {"combat_id": COMBAT_ID}
	# Pre-discover the fixture's entries so boot does not also persist a first
	# Grimoire discovery while testing the terminal profile boundary.
	var discoveries := Grimoire.entry_ids_for_run_state(state)
	discoveries.append_array(Grimoire.entry_ids_for_combat_state(state.get("combat_state", {})))
	state = Grimoire.unlock_entries(state, discoveries)["state"]
	if not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		_expect(false, "Write the initial profile and active checkpoint.")
		_finish()
		return
	var host := _continue_run()
	_observe("before-failure")
	_expect(_wallet(Store.load_data()) == 0, "The fixture starts with no settled terminal wallet.")
	var profile_hash := FileAccess.get_sha256(_profile_path)
	_block_profile()
	if _outcome == "victory":
		host.call("_on_dragon_reward_continue")
		_expect(host.get("_run_state").get("mode") == "reward", "Blocked dragon Continue leaves the reward live.")
	else:
		var combat: Dictionary = host.get("_combat_state").duplicate(true)
		combat["player"]["hp"] = 0
		var terminal: Dictionary = host.call("_run_state_for_combat_checkpoint", host.get("_run_state"), combat)
		host.call("_hold_committed_run_state", terminal, "enemy_round_complete")
		_expect(host.call("_committed_run_state").get("mode") == "defeat", "Lethal combat owns the held defeat boundary.")
	var fallback := _observe("after-failure-before-quit")
	_expect(fallback.get("mode") == _outcome and engine.held_embers(fallback) == HELD and Boons.heirloom_prompt_pending(fallback), "A failed profile write leaves the prompt and unprocessed wallet on disk.")
	_expect(FileAccess.get_sha256(_profile_path) == profile_hash, "The blocked terminal transition leaves the profile bytes intact.")
	_finish(host)


func _choose_and_quit() -> void:
	var fallback := _observe("relaunched-after-blocked-quit")
	_expect(fallback.get("mode") == _outcome and Run.new().held_embers(fallback) == HELD, "Blocked quit preserves the terminal fallback for Continue.")
	_expect(not Store.has_completed_run(Store.load_data(), fallback), "The fallback carries no durable profile completion.")
	var profile_hash := FileAccess.get_sha256(_profile_path)
	_block_profile()
	var host := _continue_run()
	var flow: RefCounted = host.get("_opening_boon_flow")
	_expect(Boons.heirloom_pieces(host.get("_run_state")).has(HEIRLOOM), "Continue offers the fixture heirloom.")
	flow.call("leave_heirloom", host, HEIRLOOM)
	var chosen := _observe("choice-saved-before-profile")
	_expect(chosen.get("heirloom_end", {}).get("item") == HEIRLOOM and Store.heirloom(chosen.get("progression", {})) == HEIRLOOM, "The choice commits to the checkpoint before the blocked profile write.")
	_expect(_wallet(chosen.get("progression", {})) == HELD and Run.new().held_embers(chosen) == 0, "The run-first choice checkpoint owns the settled wallet.")
	_expect(FileAccess.get_sha256(_profile_path) == profile_hash, "The blocked heirloom choice leaves the profile bytes intact.")
	if _phase == "choose-retry": Store.set_storage_path(_profile_path)
	_finish(host)


func _recover_and_quit() -> void:
	var chosen := _observe("relaunched-after-choice-quit")
	_expect(chosen.get("heirloom_end", {}).get("item") == HEIRLOOM, "The chosen item survives another process restart.")
	_expect(_wallet(chosen.get("progression", {})) == HELD, "A departure retry retains the settled checkpoint wallet.")
	var result_id := Run.run_result_id(chosen)
	var saved_result := Store.run_result_for_id(chosen.get("progression", {}), result_id)
	_expect(not saved_result.is_empty(), "The choice checkpoint retains the staged run result.")
	if _outcome == "defeat":
		var marker := Store.recovery_marker(chosen.get("progression", {}))
		_expect(Store.recovery_coord(chosen.get("progression", {})) == chosen.get("current_room") and int(marker.get("available_run", 0)) == int(chosen.get("run_index", 0)) + 1, "The defeat marker retains its recovery room and descent.")
	var host := _continue_run()
	var recovered := Store.load_data()
	_observe("after-continue-repaired-profile")
	_expect(_wallet(recovered) == HELD and Store.heirloom(recovered) == HEIRLOOM and Store.has_completed_run(recovered, chosen), "Continue repairs the wallet, heirloom, and completion together.")
	_expect(Store.run_result_for_id(recovered, result_id) == saved_result, "Continue retains the original run result and score details.")
	var dialogue: Dictionary = host.get("_dialogue_script")
	_expect(dialogue.get("id") == "opening_boon_heirloom_confirmation", "Continue restores the confirmation for the saved choice.")
	host.call("_close_dialogue")
	_finish(host)


func _verify_final_disk() -> void:
	var checkpoint := _observe("relaunched-after-confirmation")
	var profile := Store.load_data()
	_expect(checkpoint.is_empty() and not Store.has_saved_run(), "Confirmation clears the live checkpoint and backup.")
	_expect(_wallet(profile) == HELD and Store.heirloom(profile) == HEIRLOOM, "Final profile owns the original wallet and selected heirloom.")
	_expect(profile.get(Store.RUN_RESULT_LEDGER_KEY, []).size() == 1 and profile.get("completed_run_ids", []).count(RUN_ID) == 1, "The result and completion are each recorded once.")
	var counts := _event_counts()
	for type: String in ["run_ended", "run_scored", "heirloom_left", "reward_claimed" if _outcome == "victory" else "combat_ended"]:
		_expect(counts.get(type, 0) == 1, "The append-only log contains exactly one %s row." % type)
	_finish()


func _continue_run() -> Node:
	root.set_meta("labyrinth_resume_saved_run", true)
	var host: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(host)
	current_scene = host
	_expect(host.call("has_installed_run"), "Continue installs the saved run in the authored RunScene.")
	return host


func _block_profile() -> void:
	# The same filesystem failure hook as deferred_skill_analytics_test.gd.
	Store.set_storage_path(_profile_path.path_join("blocked.json"))


func _wallet(profile: Dictionary) -> int:
	return int(profile.get("embers", 0)) if _outcome == "victory" else int(Store.recovery_marker(profile).get("amount", 0))


func _event_counts() -> Dictionary:
	var counts: Dictionary = {}
	for row: Dictionary in Analytics.load_all_events():
		var type: String = row["event_type"]
		counts[type] = int(counts.get(type, 0)) + 1
	return counts


func _observe(label: String) -> Dictionary:
	var raw := Store._inspect_run_file(Store._run_storage_path)
	var checkpoint: Dictionary = raw.get("state", {})
	var profile := Store._load_data_at(_profile_path)
	var embedded: Dictionary = checkpoint.get("progression", {})
	print("TERMINAL DISK ", label, " ", JSON.stringify({
		"checkpoint": checkpoint.get("mode", "missing"), "status": raw["status"],
		"checkpoint_hash": FileAccess.get_sha256(Store._run_storage_path) if not checkpoint.is_empty() else "",
		"held": Run.new().held_embers(checkpoint), "choice": checkpoint.get("heirloom_end", {}),
		"heirloom_terminal_wallet": checkpoint.get("heirloom_terminal_wallet", {}),
		"checkpoint_wallet": _wallet(embedded), "profile_wallet": _wallet(profile),
		"profile_hash": FileAccess.get_sha256(_profile_path), "profile_heirloom": Store.heirloom(profile),
		"checkpoint_outbox": _receipt_keys(embedded), "profile_outbox": _receipt_keys(profile),
		"checkpoint_results": _result_ids(embedded), "profile_results": _result_ids(profile),
		"completed": profile.get("completed_run_ids", []), "jsonl_rows": _event_counts(),
	}))
	return checkpoint


func _receipt_keys(profile: Dictionary) -> Array[String]:
	var keys: Array[String]
	for receipt: Dictionary in Store.progression_analytics_outbox(profile): keys.append(receipt["idempotency_key"])
	return keys

func _result_ids(profile: Dictionary) -> Array[String]:
	var ids: Array[String]
	for result: Dictionary in Store.completed_run_results(profile): ids.append(result["result_id"])
	return ids


func _expect(condition: bool, message: String) -> void:
	if condition: return
	_failures += 1
	push_error(message)


func _finish(host: Node = null) -> void:
	print("TERMINAL RELAUNCH %s %s: %s (%d failures)" % [_outcome, _phase, "PASS" if _failures == 0 else "FAIL", _failures])
	if host != null and _failures == 0:
		host.call("_on_exit_to_desktop_pressed")
	else:
		Shutdown.request(self, "terminal_relaunch_probe", int(_failures > 0))
