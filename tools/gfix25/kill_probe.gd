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

func _initialize() -> void:
	call_deferred("_go")

func _use(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	Store.set_storage_path(path.path_join("progression.json"))
	Store.set_run_storage_path(path.path_join("current_run.save"))
	Analytics.set_storage_dir(path.path_join("analytics"))

func _host(state: Dictionary = {}, profile: Dictionary = {}) -> Host:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Host)
	var host: Host = scene
	root.add_child(host)
	host._progression = Store.load_data() if profile.is_empty() else profile.duplicate(true)
	host._run_state = state.duplicate(true)
	host._combat_state = state.get("combat_state", {}).duplicate(true)
	return host

func _make(kind: String, profile: Dictionary, seed: int = 90217) -> Dictionary:
	var state := engine.create_new_run(seed, profile, true)
	match kind:
		"defeat":
			state = engine.create_debug_boss_run(profile)
			state["debug_boss_run"] = false
			state["run_index"] = int(profile["run_counter"])
		"escape":
			var last: int = (DemoRules.last_section_index()+1)*Run.DEPTHS_PER_SEQUENCE if Demo.is_demo() else Run.MAX_DEPTH
			state = Dragon.build(engine, Combat.new(), state, {
				"dragon_id": Bosses.boss_id_for_depth(seed,last), "dragon_depth": last, "dragon_case": "reward", "equip": "starter"
			})
		"campfire": state["mode"] = "campfire"
	if kind != "campfire":
		state["equipped_equipment"]["weapon"] = "duelist_rapier"
		if not state["collected_equipment"].has("duelist_rapier"): state["collected_equipment"].append("duelist_rapier")
		Boons.initialize(state)
	state = engine.set_held_embers(state, 720)
	return state

func _counts() -> Dictionary:
	var counts: Dictionary = {}
	for event: Dictionary in Analytics.load_all_events():
		var t := str(event["event_type"])
		if t in ["combat_ended", "run_ended", "run_scored", "reward_claimed", "heirloom_left"]:
			counts[t] = int(counts.get(t, 0)) + 1
	return counts

func _summary(label: String) -> void:
	var p := Store.load_data()
	var read := Store.read_resumable_checkpoint()
	var selected: Dictionary = read.get("state", {})
	var ledger: Array = []
	for r: Dictionary in Store.completed_run_results(p): ledger.append(r["result_id"].substr(0, 12))
	print(label, " | status=", read["status"], " selected=", selected.get("mode", ""), " raw=", Store.load_saved_run().get("mode", ""),
		" counter=", p["run_counter"], " bank=", int(p["embers"]), " held=", engine.held_embers(selected),
		" marker=", int(Store.recovery_marker(p).get("amount", 0)), "@", int(Store.recovery_marker(p).get("available_run", -1)),
		" ids=", p.get("completed_run_ids", []).size(), " unlock=", Store.unlocked_umbra_depth(p), " heirloom=", Store.heirloom(p),
		" prompt=", Boons.heirloom_prompt_pending(selected), " ledger=", ledger.size(), " chron=", p.get("chronicle_totals", {}).get("runs", 0),
		" outbox=", Store.progression_analytics_outbox(p).size(), " jsonl=", _counts())

func _refresh_outcome(host: Host) -> void:
	# Mirrors _refresh_ui_header's outcome step, which the stubbed UI skips.
	if str(host._run_state.get("mode", "")) == "victory" and not host._victory_carry_processed: host._process_victory_carry()
	if str(host._run_state.get("mode", "")) == "defeat" and not host._defeat_loss_processed: host._process_defeat_loss()

func _answer(host: Host) -> void:
	_refresh_outcome(host)
	if not Boons.heirloom_prompt_pending(host._run_state): return
	var flow: RefCounted = host._opening_boon_flow
	var picked := Boons.leave_heirloom(host._run_state, "duelist_rapier")
	print("LEFT saved=", flow.call("_commit", host, picked, "heirloom_left"))
	var done: Dictionary = host._run_state.duplicate(true)
	done[Boons.HEIRLOOM_END_KEY]["done"] = true
	print("CONFIRMED saved=", flow.call("_commit", host, done, "heirloom_confirmed"))

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0]
	_use(args[1])
	match mode:
		"dragon_kill":
			var profile := Store.default_data()
			profile["run_counter"] = 3
			profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
			var state := engine.create_new_run(90217, profile, true)
			state = Dragon.build(engine, Combat.new(), state, {"dragon_id": Bosses.boss_id_for_depth(90217, Run.MAX_DEPTH), "dragon_depth": Run.MAX_DEPTH, "dragon_case": "encounter", "equip": "starter"})
			state["mode"] = "combat"
			state = engine.set_held_embers(state, 720)
			var host := _host({}, profile)
			state = host._ensure_run_analytics_metadata(state)
			profile = Store.normalized_data(state["progression"])
			assert(Store.save_data(profile))
			host._progression = profile.duplicate(true)
			host._run_state = state
			host._combat_state = state["combat_state"]
			host._sync_analytics_combat_tracker()
			state = host._run_state
			assert(Store.save_run_state(state))
			var battle: Dictionary = host._combat_state.duplicate(true)
			for index: int in range(battle["enemies"].size()):
				battle = Combat.new()._damage_enemy(battle, index, int(battle["enemies"][index]["hp"]) + 999, true, true)
			var previous := host._run_state
			var final := host._run_state_for_combat_checkpoint(previous, battle, "card_play")
			print("NOTE final mode=", final.get("mode"), " final_boss=", final.get("pending_reward", {}).get("final_boss"))
			host._run_state = host._hold_committed_run_state(final, "player_card")
			Store.flush_pending_run_saves()
			if args[2] == "crash":
				print("CUT AT death animation")
				OS.kill(OS.get_process_id())
			host._analytics_log_combat_transition(previous, "card_play", battle)
			host._release_committed_run_state()
			if args[2] == "wait":
				# Save & Quit on the final dragon's reward screen, reward unclaimed.
				await Persist.save_for_departure(host)
				_summary("END")
				host.free()
				quit()
				return
			print("DRAGON committed=", host._commit_dragon_reward_continue())
			print("COMPLETED")
			_summary("END")
			host.free()
		"crash_nd":
			# A defeat in run 3 left a 720-Ember marker; the checkpoint was cleared.
			var profile := Store.default_data()
			profile["run_counter"] = 3
			profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
			profile = Store.record_lost_embers(profile, 720, Vector2i(4, 0), 3)
			assert(Store.save_data(profile))
			if args.size() > 2 and args[2] == "active":
				# Run 4 already installed and saved; the player replaces it from the title.
				var host0 := _host({}, profile)
				host0._defer_initial_run_presentation = true
				var req0 := host0._start_run(true)
				assert(host0._commit_new_run(req0, {}))
				host0.free()
			_summary("BEFORE ND")
			var host := _host()
			host._defer_initial_run_presentation = true
			OS.set_environment("GFIX_ARMED", "1")
			var request := host._start_run(true)
			print("INSTALLED ", host._commit_new_run(request, {}), " run_index=", host._run_state.get("run_index"))
			OS.set_environment("GFIX_ARMED", "")
			print("COMPLETED")
			_summary("END")
			host.free()
		"crash":
			var kind := args[2]
			var profile := Store.default_data()
			profile["run_counter"] = 3
			profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
			assert(Store.save_data(profile))
			var host := _host({}, profile)
			var state := host._ensure_run_analytics_metadata(_make(kind, profile))
			if OS.get_environment("GFIX_SYNC_PROFILE") == "1":
				# Real play saves the dragon's progression bump before the reward screen.
				profile = Store.normalized_data(state["progression"])
				assert(Store.save_data(profile))
				host._progression = profile.duplicate(true)
				print("NOTE synced profile rev=", profile.get("progression_revision"))
			host._run_state = state
			host._combat_state = state.get("combat_state", {})
			assert(Store.save_run_state(state))
			OS.set_environment("GFIX_ARMED", "1")
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
			if args.size() > 3 and args[3] == "quit_at_prompt":
				await Persist.save_for_departure(host)
			else:
				_answer(host)
				if kind not in ["abandon", "campfire"]:
					await Persist.save_for_departure(host)
			OS.set_environment("GFIX_ARMED", "")
			print("COMPLETED")
			_summary("END")
			host.free()
		"relaunch":
			var action := args[2]
			var profile := Store.load_data()
			Persist.replay_run_closing_receipts(profile, Store.read_resumable_checkpoint(false, true).get("state", {}) if Store.read_resumable_checkpoint()["status"] == Store.RunFile.TERMINAL else Store.read_resumable_checkpoint().get("state", {}))
			_summary("TITLE")
			var title := Store.read_resumable_checkpoint()
			if action == "continue":
				if title["status"] != Store.RunFile.READY:
					print("NOTE no continue")
					quit(); return
				var state: Dictionary = Store.load_checkpoint_for_resume()
				var host := _host()
				host._load_run_state(state)
				print("RESUMED mode=", host._run_state.get("mode"), " run_index=", host._run_state.get("run_index"), " prompt=", Boons.heirloom_prompt_pending(host._run_state), " held=", engine.held_embers(host._run_state), " flags=", host._victory_carry_processed, "/", host._defeat_loss_processed, " wallet=", host._run_state.get("heirloom_terminal_wallet", "none"))
				if OS.get_environment("GFIX_DEBUG") == "1":
					_summary("AFTER LOAD")
					print("NOTE embedded rev=", host._run_state.get("progression", {}).get("progression_revision"), " live rev=", host._progression.get("progression_revision"), " disk rev=", Store.load_data().get("progression_revision"), " embedded chron=", host._run_state.get("progression", {}).get("chronicle_totals", {}))
					_refresh_outcome(host)
					_summary("AFTER OUTCOME")
					print("NOTE run marker=", Store.recovery_marker(host._run_state.get("progression", {})), " live marker=", Store.recovery_marker(host._progression), " flags=", host._victory_carry_processed, "/", host._defeat_loss_processed)
				if host._run_state.get("mode") == "reward":
					print("DRAGON committed=", host._commit_dragon_reward_continue())
				elif host._run_state.get("mode") == "combat":
					var combat := host._combat_state.duplicate(true)
					combat["player"]["hp"] = 0
					var previous := host._run_state
					var final := host._run_state_for_combat_checkpoint(previous, combat)
					host._run_state = host._hold_committed_run_state(final, "terminal_defeat")
					host._analytics_log_combat_transition(previous, "enemy_round", combat)
					host._release_committed_run_state()
				elif host._run_state.get("mode") == "campfire":
					host._on_campfire_embrace_pressed()
				_answer(host)
				await Persist.save_for_departure(host)
				_summary("AFTER CONTINUE")
				host.free()
			elif action == "new":
				var host := _host()
				host._defer_initial_run_presentation = true
				var request := host._start_run(true)
				if request.is_empty():
					print("NOTE new descent refused")
					quit(); return
				print("INSTALLED ", host._commit_new_run(request, {}), " new_held=", engine.held_embers(host._run_state), " run_index=", host._run_state.get("run_index"))
				_summary("AFTER NEW")
				host.free()
	quit()
