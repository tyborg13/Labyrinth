extends RefCounted

const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Rules = preload("res://scripts/demo_rules.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const DragonFixture = preload("res://tools/dragon_boss_inspection.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PATHS := ["embrace", "defeat", "escape", "abandon", "demo"]
const SEED := 7124
const RUN_INDEX := 3
const RUN_ID := "run_fixture_terminal_crash"
const HELD := 720
const CRASH_WAIT_MSEC := 2000
const OBSERVER_TIMEOUT_MSEC := 5000
const OBSERVER_POLL_MSEC := 1
const VIEWPORT := Vector2i(1920, 1080)

class Host extends Scene:
	func _refresh_ui(_frame_sliced: bool = false, _unlock: bool = false, _wave: bool = false) -> void:
		pass

	func _close_menu_overlay() -> void:
		pass

	func _change_scene_to_file(_path: String) -> void:
		pass

static func configure(tree: SceneTree, directory: String, kind: String) -> bool:
	if not PATHS.has(kind) or DemoBuild.is_demo() != (kind == "demo") or not directory.is_absolute_path():
		return false
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	Store.set_storage_path(directory.path_join("progression.json"))
	Store.set_run_storage_path(directory.path_join("current_run.save"))
	Analytics.set_storage_dir(directory.path_join("analytics"))
	Settings.set_storage_path("user://terminal_crash_settings.json")
	var settings := Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0}, true)
	tree.root.size = VIEWPORT
	return Settings.save_settings(settings)

class KillAfterCheckpoint extends "res://scripts/opening_boon_flow.gd":
	func flush_events(_host: Node, state: Dictionary) -> bool:
		var live := Store.load_saved_run()
		if state.get("mode") == "defeat" and live.get("mode") == "defeat":
			print("TERMINAL CRASH: defeat terminal checkpoint promoted")
			OS.kill(OS.get_process_id())
		return false

static func crash(tree: SceneTree, kind: String, after_checkpoint: bool = false) -> void:
	var profile := Store.default_data()
	profile["run_counter"] = RUN_INDEX
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var engine := Run.new()
	var state := engine.create_new_run(SEED, profile)
	var defeated_combat := {}
	match kind:
		"embrace":
			state["mode"] = "campfire"
		"defeat":
			state = engine.create_debug_boss_run(profile)
			state["debug_boss_run"] = false
			state["run_index"] = RUN_INDEX
			var combat: Dictionary = state["combat_state"].duplicate(true)
			combat["player"]["hp"] = 0
			state = engine.set_held_embers(state, HELD)
			defeated_combat = combat
		"escape", "demo":
			var depth: int = (Rules.last_section_index() + 1) * Run.DEPTHS_PER_SEQUENCE if kind == "demo" else Run.MAX_DEPTH
			state = DragonFixture.build(engine, Combat.new(), state, {
				"dragon_id": Bosses.boss_id_for_depth(SEED, depth), "dragon_depth": depth, "dragon_case": "reward", "equip": "starter",
			})
			if not bool(state.get("pending_reward", {}).get("final_boss", false)):
				_fail(tree, "expected the final dragon reward for " + kind)
				return
	state = engine.set_held_embers(state, HELD)
	state["analytics"] = {"run_id": RUN_ID}
	if not defeated_combat.is_empty(): defeated_combat["analytics"] = {"combat_id": RUN_ID + "_c001"}
	if DemoBuild.is_demo(): state["build_kind"] = "demo"
	if not Store.save_data(profile) or not Store.save_run_state(state):
		_fail(tree, "could not write the original fixture")
		return
	var checkpoint: Dictionary = Store.read_resumable_checkpoint()
	if checkpoint.get("state", {}).get("mode") != state["mode"]:
		_fail(tree, "fixture is not resumable before finishing " + kind)
		return
	var host := Host.new()
	host.set("_progression", profile)
	host.set("_run_state", state)
	host.set("_combat_state", state.get("combat_state", {}))
	if after_checkpoint:
		host.set("_opening_boon_flow", KillAfterCheckpoint.new())
	else:
		Store._run_writer.probe_delay_msec = CRASH_WAIT_MSEC
		WorkerThreadPool.add_task(_kill_after_profile.bind(kind, state), true, "Observe terminal profile commit")
	match kind:
		"embrace": host.call("_on_campfire_embrace_pressed")
		"defeat":
			var defeated: Dictionary = host.call("_run_state_for_combat_checkpoint", state, defeated_combat)
			host.call("_hold_committed_run_state", defeated, "enemy_round_complete")
		"escape", "demo": host.call("_commit_dragon_reward_continue")
		"abandon": host.call("_on_abandon_run_pressed")
	host.free()
	_fail(tree, "process survived the terminal checkpoint write for " + kind)

class BlockedAnalytics extends "res://scripts/analytics_store.gd":
	func write_events_durable(_events: Array) -> bool:
		return false

static func abandon_while_profile_blocked(tree: SceneTree, block_analytics: bool) -> void:
	var profile := Store.default_data()
	var state := Run.new().create_debug_boss_run(profile)
	state["debug_boss_run"] = false
	state["analytics"] = {"run_id": RUN_ID}
	state = Run.new().set_held_embers(state, HELD)
	if not Store.save_data(profile) or not Store.save_run_state(state):
		_fail(tree, "could not save the Abandon fixture")
		return
	var blocker := Store._storage_path + ".tmp"
	if DirAccess.make_dir_absolute(blocker) != OK:
		_fail(tree, "could not block progression.json.tmp")
		return
	var host := Host.new()
	host.set("_progression", profile)
	host.set("_run_state", state)
	host.set("_combat_state", state["combat_state"])
	if block_analytics: host.set("_analytics_store", BlockedAnalytics.new())
	host.get("_analytics_store").deferred_writes = true
	host.call("_on_abandon_run_pressed")
	if Store.has_completed_run(Store.load_data(), state):
		_fail(tree, "profile settlement succeeded through the blocker")
		host.free()
		return
	print("TERMINAL CRASH: abandon profile blocked analytics_blocked=", block_analytics)
	OS.kill(OS.get_process_id())
	_fail(tree, "process survived the Abandon fixture")

static func expected_bank(kind: String) -> int:
	return 0 if kind in ["defeat", "abandon"] else HELD

static func _kill_after_profile(kind: String, original: Dictionary) -> void:
	var deadline := Time.get_ticks_msec() + OBSERVER_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var profile := Store.load_data()
		var observed := (
			int(Store.recovery_marker(profile).get("amount", 0)) >= HELD
			if kind in ["defeat", "abandon"] else int(profile["embers"]) == HELD
		)
		if observed:
			var live: Dictionary = Store._inspect_run_file(Store._run_storage_path).get("state", {})
			if live.get("mode") != original["mode"] or int(live.get("held_embers", -1)) != HELD:
				push_error("Terminal checkpoint already changed for " + kind)
				return
			print("TERMINAL CRASH: %s bank=%d checkpoint=%s held=%d" % [kind, profile["embers"], live["mode"], live["held_embers"]])
			if OS.kill(OS.get_process_id()) != OK: push_error("Could not terminate the isolated crash fixture")
			return
		OS.delay_msec(OBSERVER_POLL_MSEC)

static func _fail(tree: SceneTree, message: String) -> void:
	print("TEST RESULT: FAIL — " + message)
	tree.quit(1)
