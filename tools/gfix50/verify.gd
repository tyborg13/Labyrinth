extends "res://tests/pre_battle_fixture.gd"

const Boons = preload("res://scripts/opening_boon_rules.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Dragon = preload("res://tools/dragon_boss_inspection.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const SectionFlow = preload("res://scripts/start_room_map_flow.gd")
const Gear = preload("res://tests/helpers/heirloom_fixture.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")

const FIXTURE_SEED: int = 2
const FIRST_DRAGON_DEPTH: int = 4
const PIECE_COUNT: int = 1
const FRAME_HOLD_SECONDS: float = 0.65
const UI_SCALE: float = 1.0
const OUTPUT_DIR: String = "res://.godot/gfix50/native"

var _engine := RunEngine.new()
var _headless: bool
var _release: bool

func _initialize() -> void:
	_setup()
	_headless = DisplayServer.get_name() == "headless"
	_release = OS.get_cmdline_user_args().has("--release")
	Settings.set_storage_path("user://gfix50_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = false
	_expect(Settings.save_settings(settings), "Save the 100% proof settings")
	call_deferred("_run")

func _run() -> void:
	await _defeat(false)
	await _defeat(true)
	if _headless and not _release:
		await _dragon()
		await _old_save()
		await _starter_only()
	_viewport.queue_free()
	await process_frame
	print("GFIX-50 %s %s: %s" % ["RELEASE" if _release else "WORKTREE", "HEADLESS" if _headless else "NATIVE", "FAIL" if _failed else "PASS"])
	Shutdown.request(self, "gfix50_proof", int(_failed))

func _fresh_scene(profile: Dictionary, case_id: String, saved_run: Dictionary = {}) -> Node:
	Analytics.set_storage_dir("user://gfix50_%s_analytics" % case_id)
	Analytics.clear_storage()
	ProgressionStore.set_storage_path("user://gfix50_%s_profile.json" % case_id)
	ProgressionStore.set_run_storage_path("user://gfix50_%s_run.save" % case_id)
	ProgressionStore.clear_saved_run()
	_expect(ProgressionStore.save_data(profile), "Save the %s starting profile" % case_id)
	if not saved_run.is_empty():
		_expect(ProgressionStore.save_run_state(saved_run), "Serialize the old mid-run save")
		root.set_meta("labyrinth_resume_saved_run", true)
	root.set_meta(InitialGraph.SEED_OVERRIDE, FIXTURE_SEED)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	root.remove_meta(InitialGraph.SEED_OVERRIDE)
	scene.call("_close_dialogue")
	await _settle()
	return scene

func _combat_from(state: Dictionary) -> Dictionary:
	for destination: Vector2i in _engine.available_moves(state):
		var entered: Dictionary = _engine.move_to_pre_battle(state, destination)
		if entered.get("mode") == "pre_battle": return _engine.begin_pre_battle_combat(entered)
		if entered.get("mode") == "combat": return entered
	_expect(false, "The proof room must have an adjacent combat")
	return {}

func _finish_combat(scene: Node, combat_state: Dictionary) -> void:
	# Start from a real combat checkpoint. Supply the final Health values so the
	# test is deterministic, then use the same save and refresh as live combat.
	var terminal: Dictionary = scene.call("_run_state_for_combat_checkpoint", scene.get("_run_state"), combat_state)
	var committed: Dictionary = scene.call("_hold_committed_run_state", terminal, "enemy_round_complete")
	scene.set("_run_state", committed)
	scene.call("_sync_combat_state_from_run")
	scene.call("_release_committed_run_state")
	scene.call("_refresh_ui")
	await _settle()

func _lose(scene: Node, living: Dictionary) -> void:
	scene.call("_load_run_state", living)
	var combat_state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	_expect(not combat_state.is_empty(), "Live scene loaded the combat fixture")
	if combat_state.is_empty(): return
	combat_state["player"]["hp"] = 0
	await _finish_combat(scene, combat_state)
	_expect(scene.get("_run_state").get("mode") == "defeat", "Combat saves a real defeat")

func _defeat(unlocked: bool) -> void:
	var profile: Dictionary = ProgressionStore.default_data()
	if unlocked:
		profile = Tutorial.complete_tutorial(profile)
		profile = ProgressionStore.mark_emaciated_awakening_seen(ProgressionStore.add_moltshard_for_award(profile, "gfix50_prior_dragon"))
		profile["run_counter"] = 1
	var case_id: String = "unlocked_defeat" if unlocked else "run1_defeat"
	var scene: Node = await _fresh_scene(profile, case_id)
	var living: Dictionary = _combat_from(Gear.equip(scene.get("_run_state"), PIECE_COUNT))
	if living.is_empty():
		await _discard(scene)
		return
	var item: String = Gear.PROOF_ITEMS[0]
	var before: Dictionary = _piece_state(living)
	await _lose(scene, living)
	var ending: Dictionary = scene.get("_run_state")
	var view: Control = scene.get("_opening_boon_flow").overlay
	var recap: Control = scene.get("_run_end_recap")
	_expect(int(ending.get("run_index", 0)) == (2 if unlocked else 1), "Proof uses the intended run number")
	_expect(_piece_state(ending) == before, "Defeat leaves the equipped piece and its ownership unchanged")
	_expect(_heirloom_events().is_empty() and ProgressionStore.heirloom(ProgressionStore.load_data()).is_empty(), "Defeat alone neither stores a piece nor emits an heirloom event")
	var dialogue: String = str(scene.get("_dialogue_script").get("id", ""))
	print("GFIX-50 %s: mode=%s dialogue=%s view=%s recap=%s piece=%s unchanged=%s receipts=%d" % [
		case_id, ending.get("mode"), dialogue if not dialogue.is_empty() else "none", view != null,
		recap.visible, item, _piece_state(ending) == before, _heirloom_events().size()])
	if unlocked:
		await _take_prompt(scene, view, recap, item)
	else:
		_expect(view == null and not scene.get("_dialogue_active") and recap.visible, "Run 1 goes directly to recap without a prompt")
		_expect(Boons.leave_heirloom(ending, item) == ending, "A stale choice cannot mutate a locked ending")
		if recap.visible:
			_expect(not ProgressionStore.has_saved_run(), "The locked ending clears its terminal checkpoint")
			recap.call("skip_presentation")
			await _save_frame("run1_defeat.png")
			await _rise_again(recap)
			_expect(int(scene.get("_run_state").get("run_index", 0)) == 2 and not Boons.pending(scene.get("_run_state")), "Rise Again installs run 2 without an opening offer")
			print("GFIX-50 run1_rise_again: run=%d offer=%s" % [scene.get("_run_state").get("run_index", 0), Boons.pending(scene.get("_run_state"))])
	await _discard(scene)

func _take_prompt(scene: Node, view: Control, recap: Control, item: String) -> void:
	_expect(view != null and view.is_visible_in_tree() and not recap.visible, "Unlocked defeat shows the heirloom view before recap")
	if view == null: return
	scene.call("_complete_current_dialogue_line")
	scene.get("_dialogue_overlay").finish_open()
	var copy: String = scene.get("_dialogue_text_label").get_parsed_text()
	var pieces: Array[String] = Boons.heirloom_pieces(scene.get("_run_state"))
	var choices: Array[String] = pieces.duplicate()
	if view.leave_button.is_visible_in_tree(): choices.append("")
	_expect(copy == Boons.definitions()["dialogue"]["heirloom_prompt"] and choices == [item, ""] and view.cards.size() == 1, "Prompt shows the authored line, eligible piece and Leave nothing")
	await _save_frame("unlocked_defeat.png")
	scene.get("_opening_boon_flow").leave_heirloom(scene, item)
	view.ceremony.skip()
	_expect(ProgressionStore.heirloom(ProgressionStore.load_data()) == item, "The selected base item survives on disk")
	_expect(_heirloom_events() == [{"item": item, "none": false}], "The choice emits one unchanged heirloom payload")
	scene.call("_complete_current_dialogue_line")
	scene.call("_advance_dialogue")
	await _settle()
	recap.call("skip_presentation")
	await _rise_again(recap)
	scene.call("_speak_to_emaciated_man")
	var rows: Array = Boons.available_offers(scene.get("_run_state"))
	_expect(not rows.is_empty() and rows.front() == {"boon": "heirloom", "column": Boons.definitions()["columns"][0]["label"], "item": item}, "Next descent returns the same item in the first offer row")
	_expect(scene.get("_opening_boon_flow").active(), "The next-run offer is presented through Speak")
	print("GFIX-50 unlocked_receipt: %s" % JSON.stringify({"dialogue": copy, "choices": choices, "stored": ProgressionStore.heirloom(ProgressionStore.load_data()), "payloads": _heirloom_events(), "rows": rows}))

func _rise_again(recap: Control) -> void:
	var button: Button = recap.find_child("NewRunButton", true, false)
	_expect(recap.visible and button.is_visible_in_tree() and not button.disabled, "Recap keeps Rise Again available")
	root.set_meta(InitialGraph.SEED_OVERRIDE, FIXTURE_SEED)
	button.pressed.emit()
	root.remove_meta(InitialGraph.SEED_OVERRIDE)
	await _settle()

func _dragon() -> void:
	var profile: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
	var scene: Node = await _fresh_scene(profile, "first_dragon")
	var id: String = Bosses.boss_id_for_depth(FIXTURE_SEED, FIRST_DRAGON_DEPTH)
	var living: Dictionary = Dragon.build(_engine, Combat.new(), scene.get("_run_state"), {"dragon_id": id, "dragon_depth": FIRST_DRAGON_DEPTH})
	scene.call("_load_run_state", living)
	var lethal: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	for index: int in range(lethal["enemies"].size()):
		var hp: int = int(lethal["enemies"][index]["hp"])
		lethal = Combat.new()._damage_enemy(lethal, index, hp, true, true)
	await _finish_combat(scene, lethal)
	var reward: Dictionary = scene.get("_run_state")
	var awarded: Dictionary = ProgressionStore.load_data()
	var award_ids: Array = awarded[ProgressionStore.MOLTSHARD_AWARD_IDS_KEY]
	_expect(_engine.is_dragon_reward(reward) and ProgressionStore.moltshard_count(awarded) == 1 and award_ids.size() == 1, "First dragon kill writes the award before recap")
	_expect(ProgressionStore.emaciated_awakening_is_due(awarded) and not ProgressionStore.emaciated_services_unlocked(awarded), "The award makes awakening due without setting the services flag")
	var advanced: Dictionary = _engine.continue_dragon_reward(reward)
	var destination: Vector2i = SectionFlow.next_section_destination(advanced, _engine)
	advanced = SectionFlow.transition_entry(advanced, _engine, destination, "auto_transition")
	var next_combat: Dictionary = _combat_from(Gear.equip(advanced, PIECE_COUNT))
	if not next_combat.is_empty():
		await _lose(scene, next_combat)
		var recap: bool = scene.get("_run_end_recap").visible
		var prompt: bool = scene.get("_opening_boon_flow").active()
		_expect(recap and not prompt and _heirloom_events().is_empty(), "The first dragon run still ends without the prompt when awakening was never acknowledged")
		print("GFIX-50 first_dragon: %s" % JSON.stringify({"dragon": id, "moltshards": ProgressionStore.moltshard_count(awarded), "award_ids": award_ids, "awakening_due": ProgressionStore.emaciated_awakening_is_due(awarded), "services_unlocked": ProgressionStore.emaciated_services_unlocked(ProgressionStore.load_data()), "recap": recap, "prompt": prompt}))
	await _discard(scene)

func _old_save() -> void:
	var item: String = Gear.PROOF_ITEMS[0]
	var profile: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
	profile["run_counter"] = 2
	profile = ProgressionStore.leave_heirloom(profile, item)
	var saved: Dictionary = _engine.create_new_run(FIXTURE_SEED, profile)
	var scene: Node = await _fresh_scene(profile, "old_save", saved)
	var resumed: Dictionary = scene.get("_run_state")
	_expect(int(resumed.get("run_index", 0)) == 2 and resumed.get("seed") == saved.get("seed") and not Boons.pending(resumed), "The locked old mid-run save resumes without rolling a new offer")
	_expect(ProgressionStore.heirloom(ProgressionStore.load_data()) == item, "The old heirloom survives a locked load")
	var awarded: Dictionary = ProgressionStore.add_moltshard_for_award(resumed["progression"], "gfix50_old_save_dragon")
	resumed["progression"] = awarded
	scene.set("_run_state", resumed)
	scene.call("_speak_to_emaciated_man")
	var awakening: Dictionary = scene.get("_dialogue_script")
	_expect(awakening.get("id") == "emaciated_awakening", "The existing awakening dialogue follows the award")
	for _line: Dictionary in awakening.get("lines", []):
		scene.call("_complete_current_dialogue_line")
		scene.call("_advance_dialogue")
	var unlocked: Dictionary = ProgressionStore.load_data()
	_expect(ProgressionStore.emaciated_services_unlocked(unlocked) and ProgressionStore.heirloom(unlocked) == item, "Awakening persists the flag and preserves the old heirloom")
	var living: Dictionary = _combat_from(Gear.equip(scene.get("_run_state"), PIECE_COUNT))
	if not living.is_empty():
		await _lose(scene, living)
		var view: Control = scene.get("_opening_boon_flow").overlay
		_expect(view != null, "A run that began locked can prompt after awakening is acknowledged")
		if view != null:
			scene.get("_opening_boon_flow").leave_heirloom(scene, "")
			view.ceremony.skip()
			await _settle()
			_expect(_heirloom_events() == [{"item": "", "none": true}], "Explicit Leave nothing retains its event payload")
			var recap: Control = scene.get("_run_end_recap")
			recap.call("skip_presentation")
			await _rise_again(recap)
			scene.call("_speak_to_emaciated_man")
			scene.get("_opening_boon_flow").call("_choose", "heirloom", [], scene)
			var restored: Dictionary = scene.get("_run_state")
			_expect(restored["equipped_equipment"].get("weapon") == item and ProgressionStore.heirloom(ProgressionStore.load_data()).is_empty(), "Next descent offers and returns the stored old item")
			print("GFIX-50 old_save: run=%d unlocked=%s same_run_prompt=true stored=%s returned=%s" % [resumed.get("run_index", 0), ProgressionStore.emaciated_services_unlocked(unlocked), ProgressionStore.heirloom(unlocked), restored["equipped_equipment"].get("weapon")])
	await _discard(scene)

func _starter_only() -> void:
	var ending: Dictionary = Gear.terminal(0)
	var scene: Node = await _fresh_scene(ending["progression"], "starter_only")
	scene.call("_load_run_state", ending)
	await _settle()
	_expect(scene.get("_run_end_recap").visible and not scene.get("_opening_boon_flow").active(), "Unlocked starter-only defeat skips the prompt")
	_expect(_heirloom_events().is_empty(), "An automatic skip has no heirloom event")
	print("GFIX-50 starter_only: recap=%s receipts=%d" % [scene.get("_run_end_recap").visible, _heirloom_events().size()])
	await _discard(scene)

func _piece_state(state: Dictionary) -> Dictionary:
	return {"equipped": state["equipped_equipment"].duplicate(), "collected": state["collected_equipment"].duplicate(), "inventory": state["equipment_inventory"].duplicate(), "grafts": state.get("equipment_grafts", {}).duplicate(true)}

func _heirloom_events() -> Array[Dictionary]:
	var payloads: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		if event.get("event_type") == "heirloom_left": payloads.append(event["payload"])
	return payloads

func _save_frame(filename: String) -> void:
	if _headless: return
	await create_timer(FRAME_HOLD_SECONDS).timeout
	var directory: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var path: String = directory.path_join(filename)
	await _capture(path)
	print(path)

func _discard(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	await process_frame
