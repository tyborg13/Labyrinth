extends SceneTree

const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Dragon = preload("res://tools/dragon_boss_inspection.gd")
const Demo = preload("res://scripts/demo_build.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Persist = preload("res://scripts/run_persistence.gd")

class Host extends Scene:
	var destination: String = ""
	func _ready() -> void:
		set_process(false)
	func _exit_tree() -> void: pass
	func _refresh_ui(_a: bool = false, _b: bool = false, _c: bool = false) -> void: pass
	func _close_menu_overlay() -> void: pass
	func _change_scene_to_file(path: String) -> void: destination = path

var engine := Run.new()
var store_script: Script = Store
var folder: String

func _initialize() -> void:
	call_deferred("_go")

func _has_static(script: Script, name: String) -> bool:
	for m: Dictionary in script.get_script_method_list():
		if m["name"] == name: return true
	return false

func _use(path: String) -> void:
	folder = path
	DirAccess.make_dir_recursive_absolute(folder)
	Store.set_storage_path(folder.path_join("progression.json"))
	Store.set_run_storage_path(folder.path_join("current_run.save"))
	Analytics.set_storage_dir(folder.path_join("analytics"))

func _host(state: Dictionary = {}, profile: Dictionary = {}) -> Host:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Host)
	var host: Host = scene
	root.add_child(host)
	host._progression = Store.load_data() if profile.is_empty() else profile.duplicate(true)
	host._run_state = state.duplicate(true)
	host._combat_state = state.get("combat_state", {}).duplicate(true)
	return host

func _make(kind: String, prompt: bool, profile: Dictionary, seed: int = 90217) -> Dictionary:
	var state := engine.create_new_run(seed, profile, true)
	match kind:
		"campfire": state["mode"] = "campfire"
		"defeat":
			state = engine.create_debug_boss_run(profile)
			state["debug_boss_run"] = false
			state["run_index"] = int(profile["run_counter"])
		"escape":
			var last: int = (DemoRules.last_section_index()+1)*Run.DEPTHS_PER_SEQUENCE if Demo.is_demo() else Run.MAX_DEPTH
			state = Dragon.build(engine, Combat.new(), state, {
				"dragon_id": Bosses.boss_id_for_depth(seed,last), "dragon_depth": last, "dragon_case": "reward", "equip": "starter"
			})
	if prompt:
		state["equipped_equipment"]["weapon"] = "duelist_rapier"
		if not state["collected_equipment"].has("duelist_rapier"): state["collected_equipment"].append("duelist_rapier")
		Boons.initialize(state)
	state = engine.set_held_embers(state, 720)
	return state

func _counts() -> Dictionary:
	var counts: Dictionary = {}
	for event: Dictionary in Analytics.load_all_events():
		var t := str(event["event_type"])
		if t in ["combat_ended", "run_ended", "run_scored", "reward_claimed", "run_started", "heirloom_left"]:
			counts[t] = int(counts.get(t, 0)) + 1
	return counts

func _summary(label: String) -> void:
	var p := Store.load_data()
	var read := Store.read_resumable_checkpoint()
	var selected: Dictionary = read.get("state", {})
	var raw := Store.load_saved_run()
	var ledger: Array = []
	for r: Dictionary in Store.completed_run_results(p): ledger.append(r["result_id"])
	var chron: Array = []
	for r: Dictionary in p.get("chronicle_records", []): chron.append(str(r.get("run_id", "")))
	print(label, " | status=", read["status"], " selected=", selected.get("mode", ""), " raw=", raw.get("mode", ""),
		" counter=", p["run_counter"], " bank=", p["embers"], " held=", engine.held_embers(selected),
		" marker=", Store.recovery_marker(p), " ids=", p.get("completed_run_ids", []),
		" unlock=", Store.unlocked_umbra_depth(p), " heirloom=", Store.heirloom(p),
		" prompt=", Boons.heirloom_prompt_pending(selected),
		" ledger=", ledger, " chronicle=", chron, " totals=", p.get("chronicle_totals", {}),
		" outbox=", Store.progression_analytics_outbox(p).map(func(e: Dictionary) -> String: return e["idempotency_key"]),
		" jsonl=", _counts())

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0]
	_use(args[1])
	match mode:
		"read":
			_summary("READ")
		"setup_profile":
			var profile := Store.default_data()
			profile["run_counter"] = 3
			profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
			profile["emaciated_awakening_seen"] = true
			assert(Store.save_data(profile))
			_summary("SETUP")
		"end_prompt":
			# Build an ending with an heirloom prompt and let this build persist it.
			var kind := args[2]
			var profile := Store.load_data()
			var host := _host({}, profile)
			var state := host._ensure_run_analytics_metadata(_make(kind, true, profile))
			host._run_state = state
			host._combat_state = state.get("combat_state", {})
			assert(Store.save_run_state(state))
			match kind:
				"defeat":
					var combat := host._combat_state.duplicate(true)
					combat["player"]["hp"] = 0
					var previous := host._run_state
					var final := host._run_state_for_combat_checkpoint(previous, combat)
					host._run_state = host._hold_committed_run_state(final, "terminal_defeat")
					host._analytics_log_combat_transition(previous, "enemy_round", combat)
					host._release_committed_run_state()
				"escape":
					print("DRAGON committed=", host._commit_dragon_reward_continue())
			print("END mode=", host._run_state.get("mode"), " prompt=", Boons.heirloom_prompt_pending(host._run_state))
			_summary("AFTER END")
			if args.size() > 3 and args[3] == "quit":
				await Persist.save_for_departure(host)
				_summary("AFTER QUIT")
			host.free()
		"end_plain", "end_answer":
			var kind := args[2]
			var prompt := mode == "end_answer"
			var profile := Store.load_data()
			var host := _host({}, profile)
			var state := host._ensure_run_analytics_metadata(_make(kind, prompt, profile))
			host._run_state = state
			host._combat_state = state.get("combat_state", {})
			assert(Store.save_run_state(state))
			match kind:
				"defeat":
					var combat := host._combat_state.duplicate(true)
					combat["player"]["hp"] = 0
					var previous := host._run_state
					var final := host._run_state_for_combat_checkpoint(previous, combat)
					host._run_state = host._hold_committed_run_state(final, "terminal_defeat")
					host._analytics_log_combat_transition(previous, "enemy_round", combat)
					host._release_committed_run_state()
				"escape":
					print("DRAGON committed=", host._commit_dragon_reward_continue())
				"campfire":
					host._on_campfire_embrace_pressed()
				"abandon":
					host._on_abandon_run_pressed()
			print("END mode=", host._run_state.get("mode"), " prompt=", Boons.heirloom_prompt_pending(host._run_state))
			if prompt:
				var flow: RefCounted = host._opening_boon_flow
				var picked := Boons.leave_heirloom(host._run_state, "duelist_rapier")
				print("LEFT saved=", flow.call("_commit", host, picked, "heirloom_left"))
				var done: Dictionary = host._run_state.duplicate(true)
				done[Boons.HEIRLOOM_END_KEY]["done"] = true
				print("CONFIRMED saved=", flow.call("_commit", host, done, "heirloom_confirmed"))
			_summary("AFTER END")
			# Abandon changes scene at once; only the other endings Save & Quit.
			if kind != "abandon": await Persist.save_for_departure(host)
			_summary("AFTER QUIT")
			host.free()
		"cloud_heirloom":
			# Machine A banked an heirloom and Depth 2; machine B's older active
			# checkpoint has a higher embedded revision from its own progress.
			var a := Store.default_data()
			a["run_counter"] = 5
			a["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
			a["umbra_depth_unlocked"] = 2
			a = Store.leave_heirloom(a, "duelist_rapier")
			a["progression_revision"] = 10
			assert(Store.save_data(a))
			var b := Store.default_data()
			b["run_counter"] = 4
			b["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
			b["progression_revision"] = 15
			var host0 := _host({}, b)
			var state := host0._ensure_run_analytics_metadata(engine.create_new_run(4242, b, true))
			host0.free()
			assert(Store.save_run_state(state))
			_summary("MIXED SET")
			if args.size() > 2 and args[2] == "setup_only":
				quit()
				return
			var loaded: Dictionary
			if _has_static(Store, "load_checkpoint_for_resume"): loaded = store_script.call("load_checkpoint_for_resume")
			else: loaded = Persist.load_resumable_checkpoint(true)
			var host := _host()
			host._load_run_state(loaded)
			_summary("AFTER CONTINUE")
			await Persist.save_for_departure(host)
			_summary("AFTER QUIT")
			host.free()
		"new_descent":
			# Title New Descent on either build: settle the saved run, install the next.
			_summary("TITLE")
			var host := _host()
			host._defer_initial_run_presentation = true
			var request: Dictionary = host._start_run(true)
			if request.is_empty():
				print("NOTE new descent refused")
			else:
				print("INSTALLED ", host._commit_new_run(request, {}), " run_index=", host._run_state.get("run_index"))
			_summary("AFTER NEW")
			host.free()
		"continue_heirloom":
			_summary("TITLE")
			var state: Dictionary
			if _has_static(Store, "load_checkpoint_for_resume"):
				state = store_script.call("load_checkpoint_for_resume")
			else:
				state = Persist.load_resumable_checkpoint(true)
			print("RESUME mode=", state.get("mode", ""), " prompt=", Boons.heirloom_prompt_pending(state))
			var host := _host()
			host._load_run_state(state)
			var item := args[2]
			var flow: RefCounted = host._opening_boon_flow
			var picked := Boons.leave_heirloom(host._run_state, item)
			print("LEFT saved=", flow.call("_commit", host, picked, "heirloom_left"))
			var done: Dictionary = host._run_state.duplicate(true)
			done[Boons.HEIRLOOM_END_KEY]["done"] = true
			print("CONFIRMED saved=", flow.call("_commit", host, done, "heirloom_confirmed"))
			_summary("AFTER HEIRLOOM")
			await Persist.save_for_departure(host)
			_summary("AFTER QUIT")
			host.free()
	quit()
