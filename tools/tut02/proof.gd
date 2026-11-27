extends "res://tests/pre_battle_fixture.gd"

const Analytics = preload("res://scripts/analytics_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tools/tut02/run_fixture.gd")
const Hover = preload("res://tools/gfix54/native_hover.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "res://.godot/tut02/native"
const UI_SCALE: float = 1.0
const VISION_CONTROL_ACTIVATIONS: int = 1
const CAPTURE_NAMES: Array[String] = ["01_umbra_pointer.png", "02_after_continue.png", "03_umbra_hover.png"]
const EXPECTED_COPY: String = "Enemies on dark tiles are hidden: you can't target them or see their intents."

var _dry_run: bool
var _scene: Node

func _initialize() -> void:
	_run_proof.call_deferred()

func _run_proof() -> void:
	var trigger: bool = OS.get_cmdline_user_args().has("--trigger")
	_dry_run = OS.get_cmdline_user_args().has("--dry-run")
	_setup()
	ProgressionStore.set_storage_path("user://tut02_profile.json")
	ProgressionStore.set_run_storage_path("user://tut02_run.save")
	Analytics.set_storage_dir("user://tut02_analytics")
	Hover.prepare(_viewport)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	_expect(Settings.save_settings(settings), "Store the 100% proof settings")
	_expect(not ProgressionStore.has_saved_run() and ProgressionStore.load_data()["run_counter"] == 0, "Start with an isolated fresh profile")
	_expect(DisplayServer.get_name() == "headless" if trigger or _dry_run else DisplayServer.get_name() != "headless", "Use a headless trigger or dry run and a windowed capture")
	if not trigger:
		_expect(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Use the production cel look")
	if not _failed:
		var completed: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
		var first: Dictionary = Fixture.first_umbra(ProgressionStore.prepare_for_new_run(completed))
		_expect(not first.is_empty() and Fixture.has_concealed_enemy(Combat.new(), first["combat_state"]), "The first normal Umbra fight starts with a concealed living enemy")
		if not _failed:
			if trigger:
				await _witness_trigger(first)
			else:
				await _record_native(first)
	await _unmount()
	print("TUT-02 %s: %s" % ["TRIGGER WITNESS" if trigger else ("NATIVE DRY RUN" if _dry_run else "NATIVE CAPTURE"), "FAIL" if _failed else "PASS"])
	quit(int(_failed))

func _mount(state: Dictionary, lock: bool = false) -> void:
	await _unmount()
	if not ProgressionStore.save_data(state["progression"]) or not ProgressionStore.save_run_state(state):
		_fail("Write isolated profile and run checkpoint")
		return
	await _resume(lock)

func _resume(lock: bool = false) -> void:
	await _unmount()
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_scene.set("_animation_lock", lock)
	_viewport.add_child(_scene)
	await _settle()
	_expect(_scene.call("has_installed_run"), "RunScene loaded through Continue Run")

func _unmount() -> void:
	if is_instance_valid(_scene):
		_scene.queue_free()
		await process_frame
	_scene = null

func _umbra_visible() -> bool:
	if not is_instance_valid(_scene):
		return false
	var host: Control = _scene.get("_contextual_combat_prompt_host")
	return host != null and host.is_visible_in_tree() and _scene.get("_guided_tutorial_phase_id") == Tutorial.PHASE_UMBRA

func _presented_copy() -> void:
	_expect(_umbra_visible(), "First qualifying player turn shows the Umbra prompt")
	if _failed:
		return
	var prompt: Control = _scene.get("_contextual_combat_prompt")
	var subtitle: Label = _scene.get("umbra_subtitle")
	var definition: Dictionary = prompt.get("_definition")
	var title: Label = prompt.get("_title")
	var kicker: Label = prompt.get("_kicker")
	var progress_row: Control = prompt.get("_progress_row")
	var skip: Button = prompt.get("_skip_button")
	var advance: Button = prompt.get("_continue_button")
	var tooltip_lines: PackedStringArray = subtitle.tooltip_text.split("\n")
	_expect(title.text == "The Umbra" and subtitle.text == "Fringe Umbra", "The general Umbra card and the stage-specific HUD label have their own titles")
	_expect(kicker.text == "UMBRA" and definition.get("icon") == "", "Umbra kicker with no icon")
	_expect(definition.get("pointer_text") == EXPECTED_COPY and definition.get("controller_text") == EXPECTED_COPY, "Both inputs carry the approved exact copy")
	_expect(tooltip_lines == PackedStringArray([subtitle.text, EXPECTED_COPY]), "The HUD popup has only the stage title and the approved sentence")
	_expect(not definition.has("lesson") and not definition.has("lesson_total") and not progress_row.is_visible_in_tree() and not skip.is_visible_in_tree(), "The entire progress row and Skip are hidden")
	_expect(advance.is_visible_in_tree() and advance.text == "Continue" and definition.get("controller_action") == "controller_accept", "Continue uses the lesson's existing action")
	var spotlights: Array = prompt.get_meta("spotlight_rects", [])
	var text_rect: Rect2 = subtitle.get_global_rect()
	text_rect.size.x = subtitle.get_minimum_size().x
	_expect(spotlights == [text_rect] and not definition.get("spotlight_frame", true), "The subtitle stays lit without a frame")
	var callout: Rect2 = prompt.get_meta("callout_rect", Rect2())
	_expect(callout.has_area() and not callout.intersects(text_rect), "The callout leaves the Umbra subtitle reachable")
	print("TUT-02 POINTER: title=%s spotlight=%s card=%s" % [title.text, spotlights, callout])

func _witness_trigger(first: Dictionary) -> void:
	await _mount(first, true)
	_expect(_scene.get("_animation_lock") and not _umbra_visible(), "An animation lock keeps the first-turn card hidden")
	_scene.call("_unlock_after_ui_refresh", false)
	_scene.call("_refresh_ui")
	await _settle()
	_presented_copy()
	if _failed:
		return
	_witness_input_copy()
	var combat: Dictionary = _scene.get("_combat_state")
	print("TUT-02 FIRST UMBRA: seed=%d room=%s turn=%d first=visible animation_locked=hidden" % [Fixture.SEED, first["current_room"], combat["turn"]])
	_expect(not Tutorial.has_completed(ProgressionStore.load_data(), Tutorial.MILESTONE_UMBRA) and _step_receipts().is_empty(), "Presentation alone leaves the profile and analytics untouched")
	_scene.call("_save_run_progress")
	var checkpoint: Dictionary = ProgressionStore.load_checkpoint_for_resume()
	_expect(not checkpoint.is_empty() and not Tutorial.has_completed(checkpoint["progression"], Tutorial.MILESTONE_UMBRA), "A save before Continue contains no Umbra acknowledgement")
	await _resume()
	_expect(_umbra_visible(), "Continue Run before acknowledgement shows the card again")
	if _failed:
		return
	print("TUT-02 SAVE/RELOAD: before=unread restored=visible")
	await _joy(JOY_BUTTON_A)
	_expect(not _umbra_visible() and Tutorial.has_completed(ProgressionStore.load_data(), Tutorial.MILESTONE_UMBRA), "The controller Continue commits the profile and closes the card")
	var completed: Dictionary = ProgressionStore.load_checkpoint_for_resume()
	_expect(not completed.is_empty() and Tutorial.has_completed(completed["progression"], Tutorial.MILESTONE_UMBRA), "The Continue boundary includes the milestone in the run save")
	if _failed:
		return
	print("TUT-02 CONTINUE: controller=accepted profile=stored run=stored card=closed")
	var replay: Dictionary = Tutorial.restart_tutorial(ProgressionStore.load_data())
	_expect(Tutorial.is_active(replay) and Tutorial.guided_milestone_count(replay) == 0
		and Tutorial.has_completed(Tutorial.complete_tutorial(replay), Tutorial.MILESTONE_UMBRA), "Replaying the guide preserves the once-per-profile acknowledgement")
	print("TUT-02 REPLAY: guided_steps=%d umbra_read=%s" % [Tutorial.guided_milestone_count(replay), Tutorial.has_completed(replay, Tutorial.MILESTONE_UMBRA)])
	var later: Dictionary = Fixture.later_umbra(completed)
	_expect(not later.is_empty() and later["current_room"] != first["current_room"], "The same run reaches another concealed fight")
	if not later.is_empty():
		await _mount(later)
		_expect(not _umbra_visible(), "A later qualifying fight does not show the pointer again")
		print("TUT-02 LATER FIGHT: room=%s visible=%s" % [later["current_room"], _umbra_visible()])
	var next_profile: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.load_data(), completed)
	var new_run: Dictionary = Fixture.first_umbra(next_profile)
	_expect(not new_run.is_empty() and new_run["run_index"] > first["run_index"], "A new run uses the saved profile")
	if not new_run.is_empty():
		await _mount(new_run)
		_expect(not _umbra_visible(), "A new qualifying run does not show the pointer again")
		print("TUT-02 NEW RUN: index=%s visible=%s" % [new_run["run_index"], _umbra_visible()])
	await _witness_controls(first)
	var receipts: Array[Dictionary] = _step_receipts()
	_expect(receipts.size() == 1, "Continue produces exactly one Umbra step receipt")
	if receipts.size() == 1:
		var payload: Dictionary = receipts[0]["payload"]
		_expect(payload.get("phase_id") == Tutorial.PHASE_UMBRA and int(payload.get("completed_step_count", 0)) == Tutorial.milestone_ids().size(), "The existing step event has the new phase and milestone values")
		print("TUT-02 ANALYTICS: %s %s" % [receipts[0]["event_type"], JSON.stringify(payload)])

func _witness_input_copy() -> void:
	var router: Node = root.get_node("InputRouter")
	var prompt: Control = _scene.get("_contextual_combat_prompt")
	var body: Label = prompt.get("_message")
	router.call("set_modality", "pointer")
	var pointer: String = body.text
	router.call("set_modality", "controller")
	var controller: String = body.text
	var matched: bool = pointer == EXPECTED_COPY and controller == pointer and prompt.get_meta("controller_active")
	router.call("set_modality", "pointer")
	_expect(matched and not prompt.get_meta("controller_active"), "The rendered body is identical in pointer and controller modes")
	print("TUT-02 INPUT COPY: identical=%s body=%s" % [matched, JSON.stringify(pointer)])

func _witness_controls(first: Dictionary) -> void:
	for status: String in [Tutorial.STATUS_DISMISSED, Tutorial.STATUS_LEGACY_EXEMPT, Tutorial.STATUS_ACTIVE]:
		var state: Dictionary = first.duplicate(true)
		state["progression"][Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": status, "completed_steps": []}
		await _mount(state)
		_expect(not _umbra_visible(), "%s profile suppresses the optional prompt" % status)
		print("TUT-02 CONTROL: %s visible=%s" % [status, _umbra_visible()])
	for flag: String in ["debug_boss_run", "inspection_fixture"]:
		var state: Dictionary = first.duplicate(true)
		state[flag] = true if flag == "debug_boss_run" else {"scenario": "boss"}
		await _mount(state)
		_expect(not _umbra_visible(), "%s suppresses the optional prompt" % flag)
		print("TUT-02 CONTROL: %s visible=%s" % [flag, _umbra_visible()])
	var enemy_turn: Dictionary = first.duplicate(true)
	enemy_turn["combat_state"]["current_actor"] = {"kind": "enemy"}
	await _mount(enemy_turn)
	_expect(not _umbra_visible(), "Enemy turns suppress the optional prompt")
	print("TUT-02 CONTROL: enemy_turn visible=%s" % _umbra_visible())
	var revealed: Dictionary = first.duplicate(true)
	revealed["combat_state"]["umbra"]["vision_activations"] = VISION_CONTROL_ACTIVATIONS
	await _mount(revealed)
	_expect(not _umbra_visible() and not Fixture.has_concealed_enemy(Combat.new(), _scene.get("_combat_state")), "An active Umbra that hides nobody shows no pointer")
	print("TUT-02 CONTROL: no_hidden_enemies visible=%s" % _umbra_visible())
	var combat: Dictionary = _scene.get("_combat_state")
	combat["umbra"]["vision_activations"] = 0
	_scene.call("_refresh_ui")
	await _settle()
	_expect(not _umbra_visible(), "Concealment added mid-turn does not prompt on refresh")
	combat = Combat.new().prepare_next_player_turn(combat)
	_scene.set("_combat_state", combat)
	_scene.call("_finish_enemy_round_player_handoff")
	await _settle()
	_expect(_umbra_visible(), "The next player-turn handoff shows the pending acknowledgement")
	print("TUT-02 TURN BOUNDARY: mid_turn=hidden next_turn=%s" % ("visible" if _umbra_visible() else "hidden"))

func _step_receipts() -> Array[Dictionary]:
	return Analytics.load_all_events().filter(func(event: Dictionary) -> bool:
		return event.get("event_type") == "guided_tutorial_step_completed" and event.get("payload", {}).get("milestone_id") == Tutorial.MILESTONE_UMBRA
	)

func _record_native(first: Dictionary) -> void:
	await _mount(first)
	_presented_copy()
	if _failed:
		return
	var subtitle: Label = _scene.get("umbra_subtitle")
	var original_turn: int = _scene.get("_combat_state")["turn"]
	await _capture_frame(0)
	var prompt: Control = _scene.get("_contextual_combat_prompt")
	var spot: Rect2 = prompt.get_meta("spotlight_rects")[0]
	var hover_error: String = await Hover.capture(subtitle, spot.get_center(), subtitle.text, _path(2))
	_expect(hover_error.is_empty() and _umbra_visible(), "Real HUD hover coexists with the pointer. " + hover_error)
	await _click(prompt.get("_continue_button"))
	await _settle()
	_expect(not _umbra_visible() and _scene.get("_combat_state")["turn"] == original_turn, "The pointer closes on the same turn after Continue")
	await _capture_frame(1)
	if not _failed:
		print("TUT-02 CAPTURE STATES: pointer=visible hover=visible after_continue=hidden same_turn=true")
	if _dry_run:
		for name: String in CAPTURE_NAMES:
			print("TUT-02 PLANNED PNG: " + ProjectSettings.globalize_path(OUTPUT.path_join(name)))

func _capture_frame(index: int) -> void:
	_expect(_viewport.size == PROBE_VIEWPORT and float(Settings.load_settings()["ui_scale"]) == UI_SCALE, "Capture layout is 1920x1080 at 100% UI scale")
	if _dry_run or _failed:
		return
	await _capture(_path(index))
	print(_path(index))

func _path(index: int) -> String:
	return ProjectSettings.globalize_path(OUTPUT.path_join(CAPTURE_NAMES[index]))
