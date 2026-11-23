extends "res://tools/qa131/live_effects.gd"
## QA-133's seed 131011 economy fixture, narrowed to Burst teardown.

const TARGET := Vector2i(5, 4)
const SECOND_TICK := Vector2i(6, 4)
const CHAIN_END := Vector2i(7, 4)
const START_TIME := 8
const PAID_TIME := 10
const DIRECT_KILL_GRANTS := 1
const NEXT_TURN_ETA := 24
const START_PLAYS := 2
const LETHAL_HEALTH := 1
const EXPECTED_VICTIMS := [1, 2, 3]
const PLAY_KEY := "death_bonus_card_plays_this_turn"
const TIME_KEY := "player_turn_time_spent"
const TITLE := "res://scenes/main_menu.tscn"
const PATHS := ["application", "retained_stamp", "main_menu", "abandon", "victory", "defeat"]

func _probe() -> void:
	_directory = OS.get_environment("LABYRINTH_GFIX40_OUT")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if _directory.is_empty() or args.size() != 1 or not PATHS.has(args[0]):
		push_error("Set LABYRINTH_GFIX40_OUT and pass one path: %s" % str(PATHS))
		quit(2)
		return
	_case = args[0]
	root.size = SIZE
	root.content_scale_factor = 1.0
	if await _open(_case) and await _aim("quick_stab", TARGET):
		await _exercise()
	if current_scene == _scene: current_scene = null
	if is_instance_valid(_scene) and not is_instance_valid(_viewport): _scene.queue_free()
	await _leave()
	for failure: String in _failures: push_error(failure)
	print("GFIX40 %s: %d checks, %d failures" % [_case, _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _open(label: String) -> bool:
	var directory: String = _directory.path_join(label)
	DirAccess.make_dir_recursive_absolute(directory)
	ProgressionStore.set_storage_path(directory.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(directory.path_join("run.save"))
	Settings.set_storage_path(directory.path_join("settings.json"))
	Analytics.set_storage_dir(directory.path_join("analytics"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["combat_speed"] = Settings.COMBAT_FASTEST
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	_options = {"scenario": "combat", "seed": SEED}
	var progression: Dictionary = Tutorial.complete_tutorial(_build_progression())
	var run: Dictionary = _build_run_state("combat", progression)
	if not _check(not run.is_empty(), "combat fixture exists"): return false
	var units: Array[Dictionary] = [
		_victim("ember_tick", 1, TARGET), _victim("ember_tick", 2, SECOND_TICK), _victim("crawler", 3, CHAIN_END),
	]
	if label != "victory":
		var survivor: Dictionary = Base.enemy("crawler", 9, SURVIVOR)
		survivor["hp"] = FIXTURE_HP
		survivor["max_hp"] = FIXTURE_HP
		units.append(survivor)
	var layout: Dictionary = Base.layout(units, HERO)
	layout["coord"] = run["current_room"]
	var hand: Array[String] = ["quick_stab", "brace"]
	var hp: int = LETHAL_HEALTH if label == "defeat" else FIXTURE_HP
	var state: Dictionary = _combat_engine.create_combat(SEED, layout, {
		"hp": hp, "max_hp": FIXTURE_HP, "deck_cards": hand, "hand_size": hand.size(),
	})
	state["deck"]["hand"] = hand
	state["cards_per_turn"] = START_PLAYS
	state["cards_played_this_turn"] = 0
	state[PLAY_KEY] = 0
	state[TIME_KEY] = START_TIME
	state["surface_events"] = []
	state["death_rewards"] = []
	run["combat_state"] = state
	run["current_room_layout"] = layout
	run["player_hp"] = hp
	run["player_max_hp"] = FIXTURE_HP
	if not _check(ProgressionStore.save_data(progression) and ProgressionStore.save_run_state(run), "writes isolated fixture"):
		return false
	if label not in ["main_menu", "abandon"]:
		return await _enter()
	# SceneTree's real title transition must own the run as its current scene.
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while not _scene.initial_presentation_is_ready() and Time.get_ticks_msec() < cutoff:
		await process_frame
	_scene._close_dialogue()
	await _settle()
	return _check(_scene.initial_presentation_is_ready() and _scene._run_state.get("mode") == "combat",
		"production resume opens a ready current scene")

func _victim(kind: String, id: int, tile: Vector2i) -> Dictionary:
	var unit: Dictionary = Base.enemy(kind, id, tile)
	unit["hp"] = VICTIM_HP
	return unit

func _exercise() -> void:
	_fire(TARGET)
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while _playing and Time.get_ticks_msec() < cutoff:
		var board: Dictionary = _scene.board_view.presentation
		var contact: int = int(board.get("burst_playback_count", 0))
		if contact == 1 and not board.get("burst_effects", []).is_empty():
			if _case != "retained_stamp" or _has_retained_stamp(): break
		await process_frame
	var presentation: Dictionary = _scene.board_view.presentation
	var contact: int = int(presentation.get("burst_playback_count", 0))
	var authored: Array = _scene._burst_playback._events
	_receipt("first_contact", {"contact": contact, "authored": authored.size(), "stamp": _has_retained_stamp(),
		"hit_stop": _scene._combat_pacing.hit_stop.active, "lock": _scene._animation_lock})
	if not _check(contact == 1 and authored.size() == 2 and _scene._animation_lock,
			"first contact is visible while the second is pending"): return
	match _case:
		"application", "retained_stamp": await _interrupt_and_resume()
		"main_menu", "abandon": await _leave_for_title()
		"victory", "defeat": await _finish_fight(authored)

func _has_retained_stamp() -> bool:
	return _stamps("_tile_bursts").any(func(stamp: Node2D) -> bool: return stamp.visible)

func _interrupt_and_resume() -> void:
	var committed: Dictionary = _economy(_held({}))
	if _case == "retained_stamp":
		_check(_has_retained_stamp(), "retained Burst stamp is visible")
		# Pin an active production kill stop at the stamp boundary if the natural
		# stop already expired. This isolates the exit callback from save latency.
		var pacing: Node = _scene._combat_pacing
		var stop: Node = pacing.hit_stop
		var injected: bool = not stop.active
		if injected:
			stop.cancel()
			pacing.present_hits({"combat_feel_hits": [{"id": "gfix40_exit", "actor_key": "player",
				"damage": int(_held({})["death_burst_events"][0]["damage"]), "killed": true}]})
		_receipt("retained_stamp_exit", {"active": stop.active, "injected": injected})
		_check(stop.active, "kill hit stop active at retained stamp")
		await _leave()
		_check(not is_instance_valid(_scene) and Engine.time_scale == 1.0, "retained-stamp exit releases the scene and restores engine scale")
		return
	_action("depart and resume after grants")
	await _scene.prepare_application_quit("gfix40")
	var saved: Dictionary = _economy(ProgressionStore.load_saved_run().get("combat_state", {}))
	_check(saved == committed, "checkpoint matches the committed grant and Time receipt")
	await _leave()
	if not await _enter(): return
	var resumed: Dictionary = _economy(_scene._combat_state)
	_check(resumed == saved and resumed == {"grants": DIRECT_KILL_GRANTS, "paid": PAID_TIME, "victims": EXPECTED_VICTIMS},
		"resume preserves all grants, card Time and victims exactly once")
	await _scene._on_pass_turn_pressed()
	await _settle()
	Analytics.flush_pending_events(true)
	var counts: Dictionary = {}
	var persisted_victims: Array
	var journal_paid: int = -1
	var journal_grants: int = -1
	var eta: int = -1
	for event: Dictionary in Analytics.load_all_events():
		var kind: String = event.get("event_type", "")
		var payload: Dictionary = event.get("payload", {})
		if kind == "surface_event" and payload.get("kind") == "actor_death" and payload.get("actor_kind") == "enemy":
			persisted_victims.append(int(payload["id"]))
		elif kind in ["card_played", "player_turn_ended"]:
			counts[kind] = int(counts.get(kind, 0)) + 1
			if kind == "card_played":
				journal_grants = int(payload.get("death_bonus_card_plays_gained", -1))
			else:
				journal_paid = int(payload.get("card_time", -1))
				eta = int(payload.get("next_turn_eta", -1))
	_check(counts == {"card_played": 1, "player_turn_ended": 1} and persisted_victims == EXPECTED_VICTIMS,
		"journal has one card, one activation end and one death entry per victim")
	_check(eta == NEXT_TURN_ETA and journal_paid == PAID_TIME and journal_grants == DIRECT_KILL_GRANTS
		and int(_scene._combat_state.get("initiative_clock", -1)) == NEXT_TURN_ETA,
		"resumed Pass schedules the candidate 7 ETA once, with matching card Time and grant")
	_receipt("resumed", {"economy": resumed, "journal": counts, "journal_victims": persisted_victims,
		"journal_paid": journal_paid, "journal_grants": journal_grants, "eta": eta})

func _economy(state: Dictionary) -> Dictionary:
	var victims: Array
	for event: Dictionary in state.get("surface_events", []):
		if event.get("kind") == "actor_death" and event.get("actor_kind") == "enemy":
			victims.append(int(event["id"]))
	return {"grants": int(state.get(PLAY_KEY, 0)), "paid": int(state.get(TIME_KEY, 0)), "victims": victims}

func _leave_for_title() -> void:
	_scene._on_menu_button_pressed()
	_check(not _scene._menu_scrim.visible, "normal pause-menu input is locked during the chain")
	# Exercise the connected production buttons despite the input gate.
	_scene._open_menu_overlay()
	var caption: String = "Save and Quit" if _case == "main_menu" else "Succumb to the Darkness"
	var buttons: Array[Node] = _scene._menu_scrim.find_children("*", "Button", true, false)
	for button: Button in buttons:
		if button.text != caption: continue
		button.pressed.emit()
		break
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while Time.get_ticks_msec() < cutoff:
		if current_scene != null and current_scene.scene_file_path == TITLE and root.get_node_or_null("DepartedRunCleanup") == null:
			break
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == TITLE and not is_instance_valid(_scene),
		"selected pause-menu action retires the old run and reaches the title")
	var has_save: bool = not ProgressionStore.load_saved_run().is_empty()
	_check(has_save == (_case == "main_menu"), "Save and Quit preserves the run; Abandon clears it")
	_receipt("title", {"has_save": has_save, "scale": Engine.time_scale})

func _finish_fight(authored: Array) -> void:
	var expected: String = _case
	var final_snapshot: Dictionary = authored.back()["after"]
	var contacts: Array[int] = [1]
	var terminal_mode: String = "reward" if expected == "victory" else "defeat"
	_check(_scene._committed_run_state_override.get("mode") == terminal_mode
		and _combat_engine.combat_outcome(final_snapshot) == expected, "committed combat has expected terminal outcome")
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while _playing and Time.get_ticks_msec() < cutoff:
		var contact: int = int(_scene.board_view.presentation.get("burst_playback_count", 0))
		if contact > 0 and not contacts.has(contact): contacts.append(contact)
		await process_frame
	_check(contacts == [1, 2], "both authored contacts play in order before the outcome")
	var mode: String = _scene._run_state.get("mode", "")
	_check(not _playing and mode == terminal_mode, "combat settles into " + terminal_mode)
	_receipt("settled", {"outcome": expected, "contacts": contacts, "mode": mode, "hero_hp": final_snapshot["player"]["hp"]})
