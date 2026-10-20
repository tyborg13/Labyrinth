extends RefCounted

const Fixtures = preload("res://tests/suites/card_keywords_suite.gd")
const Departures = preload("res://tests/suites/empower_charge_departure_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const FIXTURE_SEED: int = 60501
const SETTLE_FRAMES: int = 5
const BLOCKED_CLOCK_MS: float = 10000.0
const TOGGLE_ORDER: Array = ["empower.charge", "empower.uncharge"]

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var original_size: Vector2i = tree.root.size
	var original_settings: Dictionary = Settings.load_settings()
	tree.root.size = PROOF_SIZE
	for reduced: bool in [false, true]:
		var settings: Dictionary = original_settings.duplicate(true)
		settings["reduced_motion"] = reduced
		Settings.apply_settings(settings, tree.root, false)
		tree.root.size = PROOF_SIZE
		for source: String in ["mouse", "keyboard", "controller"]:
			await _routed_toggles(tree, expect, source, reduced)
	for source: String in ["mouse", "keyboard", "controller"]:
		await _blocked_health(tree, expect, source)
	await _automatic_clears(tree, expect)
	Settings.apply_settings(original_settings, tree.root, false)
	tree.root.size = original_size

static func settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame

static func _listen(scene: Node, events: Array[Dictionary]) -> void:
	var bank: Node = scene.get("_sfx_bank")
	bank.cue_requested.connect(func(cue: String, result: String) -> void:
		events.append({"cue": cue, "result": result, "frame": Engine.get_process_frames()})
	)

static func _pointer(tree: SceneTree, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await settle(tree)

static func route_toggle(tree: SceneTree, scene: Node, source: String) -> int:
	var input_frame: int = -1
	if source == "mouse":
		var card: Control = scene.call("_hand_card_control", 0)
		var seal: Button = card.get_node("EmpowerSeal") as Button
		var point: Vector2 = seal.get_global_transform_with_canvas() * (seal.size * 0.5)
		await _pointer(tree, point)
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			if not pressed: input_frame = Engine.get_process_frames()
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await tree.process_frame
	else:
		for pressed: bool in [true, false]:
			var event: InputEvent
			if source == "keyboard":
				var key := InputEventKey.new()
				key.keycode = KEY_E
				key.physical_keycode = KEY_E
				key.pressed = pressed
				event = key
			else:
				var stick := InputEventJoypadButton.new()
				stick.button_index = JOY_BUTTON_RIGHT_STICK
				stick.pressed = pressed
				event = stick
			if pressed: input_frame = Engine.get_process_frames()
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await tree.process_frame
	await settle(tree)
	return input_frame

static func _prepare_input(tree: SceneTree, scene: Node, source: String) -> void:
	var router: Node = tree.root.get_node("InputRouter")
	router.call("clear_forced_state_for_test")
	router.call("set_modality", "pointer")
	var card: Control = scene.call("_hand_card_control", 0)
	await _pointer(tree, card.get_global_transform_with_canvas() * (card.size * 0.5))
	if source == "controller":
		router.call("set_forced_state_for_test", "controller", "xbox")
		scene.call("_controller_set_hand_index", 0)
	elif source == "mouse":
		var seal: Button = card.get_node("EmpowerSeal") as Button
		await _pointer(tree, seal.get_global_transform_with_canvas() * (seal.size * 0.5))
	await settle(tree)

static func _routed_toggles(tree: SceneTree, expect: Callable, source: String, reduced: bool) -> void:
	var scene: Node = await Fixtures._live_instance(tree, expect, ["kwtest_empower_block"], FIXTURE_SEED)
	await _prepare_input(tree, scene, source)
	var router: Node = tree.root.get_node("InputRouter")
	var events: Array[Dictionary]
	_listen(scene, events)
	for charged: bool in [true, false]:
		var before: int = events.size()
		var input_frame: int = await route_toggle(tree, scene, source)
		expect.call(events.size() > before and int(events[before]["frame"]) == input_frame, "%s: toggle sound starts on the input frame" % source)
		expect.call(bool(scene.call("_hand_card_empowered", 0)) == charged, "%s / reduced=%s: routed input changes the charge" % [source, reduced])
	var actual: Array[String]
	for event: Dictionary in events:
		expect.call(event["result"] == "played", "%s: every requested toggle cue really plays" % source)
		actual.append(str(event["cue"]))
	expect.call(actual == TOGGLE_ORDER, "%s / reduced=%s: exactly charge then uncharge, with no extra cues" % [source, reduced])
	print("EMPOWER ROUTED SFX %s reduced=%s: %s" % [source, reduced, actual])
	# Same-frame retriggers must steal immediately, never queue or suppress.
	var bank: Node = scene.get("_sfx_bank")
	for cue: String in TOGGLE_ORDER:
		var frame: int = Engine.get_process_frames()
		bank.play(cue)
		bank.play(cue)
		expect.call(events.back()["result"] == "played" and int(events.back()["frame"]) == frame, "Empower saturation plays on the requesting frame")
	router.call("clear_forced_state_for_test")
	router.call("set_modality", "pointer")
	scene.queue_free()
	await settle(tree)

static func _automatic_clears(tree: SceneTree, expect: Callable) -> void:
	for kind: String in ["play", "discard", "burn", "turn_end"]:
		var card: String = "kwtest_empower_exhaust" if kind == "burn" else "kwtest_empower_block"
		var scene: Node = await Fixtures._live_instance(tree, expect, [card], FIXTURE_SEED)
		var state: Dictionary = scene.get("_combat_state")
		if kind == "discard":
			state["skill_ids"] = ["quick_wits"]
			state["deck"]["draw"] = ["kwtest_filler"]
			scene.call("_mark_combat_preview_state_changed")
			scene.call("_refresh_ui")
		scene.call("_on_card_hover_started", 0)
		await route_toggle(tree, scene, "keyboard")
		expect.call(bool(scene.call("_hand_card_empowered", 0)), "%s: clear fixture starts charged" % kind)
		var events: Array[Dictionary]
		_listen(scene, events)
		match kind:
			"play":
				await scene.call("_on_card_pressed", 0)
				await scene.call("_on_confirm_card_play_pressed")
			"burn":
				await scene.call("_on_card_pressed", 0)
				await scene.call("_on_board_tile_clicked", Fixtures.NEAR_TILE)
			"discard":
				scene.call("_on_combat_skill_pressed", "quick_wits")
				await scene.call("_on_card_pressed", 0)
				await Departures.wait_for_idle(tree, scene, expect)
			"turn_end":
				# Observe the real turn-end boundary without running unrelated enemy actions.
				state["player_turn_ending"] = true
				scene.call("_mark_combat_preview_state_changed")
				scene.call("_refresh_ui")
		await settle(tree)
		expect.call(not bool(scene.call("_hand_card_empowered", 0)), "%s: automatic removal really clears charge" % kind)
		var toggles: Array = events.filter(func(event: Dictionary) -> bool: return str(event["cue"]).begins_with("empower."))
		expect.call(toggles.is_empty(), "%s: automatic clears play no Empower cue" % kind)
		var after: Dictionary = scene.get("_combat_state")
		if kind == "burn": expect.call((after["deck"]["burned"] as Array).has(card), "The burn proof really exhausts the charged card")
		if kind == "discard": expect.call(bool(after.get("skill_flags", {}).get("used:quick_wits", false)), "The discard proof really commits Quick Wits")
		print("EMPOWER CLEAR SFX %s: %d toggle cues" % [kind, toggles.size()])
		scene.queue_free()
		await settle(tree)

static func _blocked_health(tree: SceneTree, expect: Callable, source: String) -> void:
	var scene: Node = await Fixtures._live_instance(tree, expect, ["kwtest_empower_health"], FIXTURE_SEED)
	var state: Dictionary = scene.get("_combat_state")
	state["player"]["hp"] = 2
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _prepare_input(tree, scene, source)
	var seal: Button = (scene.call("_hand_card_control", 0) as Node).get_node("EmpowerSeal") as Button
	var original_tooltip: String = seal.tooltip_text
	var bank: Node = scene.get("_sfx_bank")
	bank.set_test_clock(BLOCKED_CLOCK_MS)
	var events: Array[Dictionary]
	_listen(scene, events)
	var input_frame: int = await route_toggle(tree, scene, source)
	var actual: Array[String]
	for event: Dictionary in events: actual.append(str(event["cue"]))
	expect.call(actual == ["card.invalid"] and events[0]["result"] == "played", "%s: one routed blocked attempt plays exactly card.invalid" % source)
	expect.call(not events.is_empty() and int(events[0]["frame"]) == input_frame, "%s: blocked feedback starts on the input frame" % source)
	print("EMPOWER BLOCKED SFX %s: %s" % [source, actual])
	# Drive the existing cooldown with a fixed bank clock, never wall sleeps.
	await route_toggle(tree, scene, source)
	expect.call(events.back()["result"] == "cooldown", "%s: an immediate blocked repeat respects card.invalid cooldown" % source)
	var cooldown: int = int(bank.data["cues"]["card.invalid"]["cooldown_ms"])
	bank.set_test_clock(BLOCKED_CLOCK_MS + float(cooldown) - 1.0)
	await route_toggle(tree, scene, source)
	expect.call(events.back()["result"] == "cooldown", "%s: blocked feedback remains suppressed before cooldown ends" % source)
	bank.set_test_clock(BLOCKED_CLOCK_MS + float(cooldown))
	await route_toggle(tree, scene, source)
	expect.call(events.size() == 4 and events.back()["result"] == "played", "%s: blocked feedback resumes exactly at the existing cooldown boundary" % source)
	expect.call(not bool(scene.call("_hand_card_empowered", 0)), "%s: health-blocked attempts never charge the card" % source)
	expect.call(bool(seal.get("blocked")) and seal.tooltip_text == original_tooltip, "%s: blocked visual and tooltip state are preserved" % source)
	expect.call(events.all(func(event: Dictionary) -> bool: return event["cue"] == "card.invalid"), "%s: blocked attempts never request an Empower cue or other sound" % source)
	var router: Node = tree.root.get_node("InputRouter")
	router.call("clear_forced_state_for_test")
	router.call("set_modality", "pointer")
	scene.queue_free()
	await settle(tree)
