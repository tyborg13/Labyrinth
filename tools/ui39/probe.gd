extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Boons = preload("res://tests/helpers/opening_boon_fixture.gd")
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const Gate = preload("res://tools/hitch_census/demo/gate.gd")
const Paint = preload("res://tools/ui39/paint.gd")

const TOUR_SEED: int = 83
const ARRIVAL_SEED: int = 7
const ARRIVAL_ROOM: String = "2,-1"
const DECK_SIZE := Vector2i(1280, 800)
const DESKTOP_SIZE := Vector2i(1920, 1080)
const DECK_SCALE: float = 1.15
const SETTLE_SECONDS: float = 0.65
const MAX_ENTRY_FRAMES: int = 60
const READY_TIMEOUT_SECONDS: float = 16.0
const STOCK := {"equipment_inventory": "ward_kite,iron_cleaver,boiled_leather,glassbone_cuirass",
	"magic_inventory": "spark_dart,frostbolt", "attuned_magic": "pale_spark",
	"item_inventory": "crimson_draught,nail_bomb", "held_embers": 720}

var _run: Control
var _failed: bool
var _observe: bool
var _capture: bool
var _size: Vector2i
var _output: String
var _receipts: Array[Dictionary]

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run_cases.call_deferred()

func _run_cases() -> void:
	var profile: String = OS.get_environment("UI39_PROFILE")
	var surface: String = OS.get_environment("UI39_SURFACE")
	if profile not in ["deck", "desktop"] or surface not in ["combat", "boon", "arrival"]:
		_expect(false, "Set UI39_PROFILE=deck|desktop and UI39_SURFACE=combat|boon|arrival")
		quit(1)
		return
	_capture = DisplayServer.get_name() != "headless"
	_observe = OS.get_environment("UI39_OBSERVE") == "1"
	_output = OS.get_environment("UI39_OUTPUT")
	if _output.is_empty(): _output = "user://ui39"
	_output = ProjectSettings.globalize_path(_output)
	_expect(DirAccess.make_dir_recursive_absolute(_output) == OK, "Create proof directory")
	_size = DECK_SIZE if profile == "deck" else DESKTOP_SIZE
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = DECK_SCALE if profile == "deck" else 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	Settings.set_storage_path("user://ui39-settings.json")
	Settings.save_settings(settings)
	Store.set_storage_path("user://ui39-profile.json")
	Store.set_run_storage_path("user://ui39-run.save")
	Store.save_data(Boons.profile())
	Store.clear_saved_run()
	root.mode = Window.MODE_WINDOWED
	root.gui_embed_subwindows = true
	root.size = _size
	root.content_scale_factor = settings["ui_scale"]
	if not _capture:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	root.get_node("InputRouter").set_forced_state_for_test("controller", "steam_deck")
	change_scene_to_file("res://scenes/run_scene.tscn")
	await scene_changed
	_run = current_scene
	_expect(root.size == _size, "Window dimensions match proof profile")
	print("UI39 CONFIG: %s %s %s" % [profile, root.content_scale_factor, root.get_visible_rect()])
	var fixtures := Fixtures.new()
	match surface:
		"combat": await _combat(fixtures.make("combat", TOUR_SEED, STOCK))
		"boon": await _boon()
		"arrival":
			await _arrival(fixtures.make("pre_battle", ARRIVAL_SEED, {"room_coord": ARRIVAL_ROOM}), "route-pre-battle")
			var tour_state: Dictionary = fixtures.make("pre_battle", TOUR_SEED, STOCK)
			await _arrival(tour_state, "tour-pre-battle")
			if not _capture: await _reduced_motion(tour_state, settings)
	fixtures.free()
	var file := FileAccess.open(_output.path_join("measurements.json"), FileAccess.WRITE)
	_expect(file != null, "Write measurements")
	if file != null: file.store_string(JSON.stringify(_receipts, "\t"))
	print("UI39 RESULT: %s %s %s %s" % [profile, surface, "native" if _capture else "headless", "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _load(state: Dictionary) -> void:
	_expect(not state.is_empty(), "Maintained fixture produces a run")
	_run.set("_progression", state["progression"])
	_run.call("_load_run_state", state)
	_run.call("_close_dialogue")

func _settle() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame
	await process_frame

func _wait_ready(require_ready: bool = true) -> void:
	var timeout: SceneTreeTimer = create_timer(READY_TIMEOUT_SECONDS)
	while not Gate.ready(_run) and timeout.time_left > 0.0:
		await process_frame
	if require_ready: _expect(Gate.ready(_run), "Combat input gate becomes ready")

func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _combat(state: Dictionary) -> void:
	_load(state)
	await _settle()
	await _wait_ready(false)
	if not _run.get("_controller_hand_focused"): await _joy(JOY_BUTTON_X)
	await _joy(JOY_BUTTON_LEFT_SHOULDER)
	await _joy(JOY_BUTTON_A)
	await _settle()
	_combat_sample("combat-selected")
	await _joy(JOY_BUTTON_B)
	var details: Button = _run.get("_enemy_intent_toggle_button")
	var candidate: Dictionary = _run.call("_controller_candidate_for_control", details)
	if not candidate.is_empty():
		_run.call("_controller_set_focus_candidate", candidate, true)
		await _joy(JOY_BUTTON_A)
	await _settle()
	_combat_sample("combat-details")
	var pass_button: Button = _run.find_child("PassPreviewChip", true, false)
	if pass_button != null: pass_button.grab_focus()
	await _settle()
	_combat_sample("combat-pass-forecast")
	await _joy(JOY_BUTTON_Y)
	await _settle()
	_combat_sample("combat-pass-turn")

func _combat_sample(checkpoint: String) -> void:
	var details: Button = _run.get("_enemy_intent_toggle_button")
	var pass_button: Button = _run.find_child("PassPreviewChip", true, false)
	var forecast: Control = pass_button.get_node_or_null("PassForecastFocusTooltip") if pass_button != null else null
	# Forecast occlusion is allowed. These envelopes and native silhouettes
	# are diagnostics, including when the two button faces are alone.
	_sample(checkpoint, {"details": details, "pass_button": pass_button, "pass_forecast": forecast},
		[["details", "pass_button"], ["details", "pass_forecast"]])

func _boon() -> void:
	_load(Boons.state(false, TOUR_SEED))
	var overlay: Control = await _open_boon()
	var offer: Control = overlay.get("_controls")[0]
	_expect(offer.name == "Boon_elemental_gift", "Seed 83 starts with Elemental Gift")
	offer.grab_focus()
	await _joy(JOY_BUTTON_A)
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _settle()
	var rules: RichTextLabel = overlay.find_child("BoonSecondaryRules", true, false)
	var glossary: Control = overlay.get("_secondary_tooltips")
	_expect(glossary.visible, "Elemental Gift secondary controller focus shows the glossary")
	if not _observe:
		_expect(root.get_visible_rect().grow(-Typography.SAFE_MARGIN).encloses(rules.get_global_rect()),
			"Secondary wrapper is safe for the full rules line")
		_expect(rules.size.x <= overlay.find_child("BoonSelectionBanner", true, false).size.x
			and rules.get_theme_font_size("normal_font_size") >= Typography.SIZE_BODY
			and rules.get_content_height() <= rules.size.y, "Secondary rules fit the panel at body size")
	_sample("opening-boon-secondary-tooltip", {"rules": rules, "glossary": glossary}, [["rules", "glossary"]])

	_load(Boons.state())
	overlay = await _open_boon()
	overlay.get("_controls")[0].grab_focus()
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _settle()
	var purge: Control = overlay.find_child("Boon_purge", true, false)
	_expect(purge.has_focus(), "Seed 2 focuses Purge as the second offer")
	_sample("opening-boon-card-2", {"rules": purge.get_node("BoonRules"), "title": purge.get_node("BoonTitle"),
		"tag": purge.get_node("BoonColumnTag").get_child(0)}, [["rules", "title"], ["rules", "tag"]])

func _open_boon() -> Control:
	_run.call("_speak_to_emaciated_man")
	_run.call("_complete_current_dialogue_line")
	await _settle()
	return _run.get("_opening_boon_flow").overlay

func _arrival(state: Dictionary, checkpoint: String) -> void:
	_run.call("_close_pre_battle_preview")
	_load(state)
	var scrim: Control = _run.get("_pre_battle_scrim")
	var panel: Control = _run.get("_pre_battle_panel")
	var equip: Button = panel.find_child("PreBattleEquipButton", true, false)
	_expect(scrim.visible and equip != null, "Pre-battle opens with its normal equipment action")
	var sampled: bool = false
	var early_focus: bool = false
	for frame: int in range(MAX_ENTRY_FRAMES):
		var settled: bool = scrim.modulate.a == 1.0 and panel.scale == Vector2.ONE
		if settled: break
		var owner: Control = root.gui_get_focus_owner()
		early_focus = early_focus or (owner != null and scrim.is_ancestor_of(owner))
		if not sampled and scrim.modulate.a > 0.0 and scrim.modulate.a < 1.0:
			_sample(checkpoint + "-arrival", {"panel": panel, "focus_target": equip}, [])
			sampled = true
		await process_frame
	_expect(sampled, "Sample at least one partially painted entry frame")
	if not _observe: _expect(not early_focus, "No pre-battle focus before full opacity and scale")
	print("UI39 ENTRY: %s early_focus=%s" % [checkpoint, early_focus])
	await _settle()
	_expect(equip.has_focus(), "Pre-battle assigns its preferred focus after settling")
	_sample(checkpoint + "-settled", {"panel": panel, "focus_target": equip}, [])
	var begin: Button = panel.find_child("PreBattleStartButton", true, false)
	begin.grab_focus()
	await _joy(JOY_BUTTON_A)
	await _wait_ready()
	_expect(_run.get("_run_state").get("mode") == "combat", "Settled Begin still accepts controller A")

func _reduced_motion(state: Dictionary, settings: Dictionary) -> void:
	settings = settings.duplicate()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, root, false)
	_run.call("_on_settings_changed", settings)
	_load(state)
	var panel: Control = _run.get("_pre_battle_panel")
	var scrim: Control = _run.get("_pre_battle_scrim")
	await process_frame
	await process_frame
	_expect(scrim.modulate.a == 1.0 and panel.scale == Vector2.ONE
		and panel.is_ancestor_of(root.gui_get_focus_owner()), "Reduced motion gives immediate full-pose focus")

func _sample(checkpoint: String, targets: Dictionary, pairs: Array) -> void:
	var owner: Control = root.gui_get_focus_owner()
	var safe: Rect2 = root.get_visible_rect().grow(-Typography.SAFE_MARGIN)
	var scrim: Control = _run.get("_pre_battle_scrim")
	var receipt: Dictionary = {"checkpoint": checkpoint, "logical_safe_area": str(safe),
		"focus": str(owner.name) if owner != null else "", "entry_alpha": scrim.modulate.a,
		"room": str(_run.get("_run_state").get("current_room"))}
	for key: String in targets:
		var control: Control = targets[key]
		receipt[key] = Paint.layout(control, safe)
	if _capture:
		var measurement: Dictionary = Paint.capture(root, targets, pairs, safe, _size,
			_output.path_join(checkpoint + ".png"))
		_expect(not measurement.is_empty(), "Save exact native frame and measure its paint")
		receipt["renderer"] = measurement
		if not measurement.is_empty(): print(measurement.capture)
		if not measurement.is_empty() and not _observe and not checkpoint.begins_with("combat-"):
			for pair: String in measurement.intersections:
				_expect(measurement.intersections[pair] == 0, "%s has no shared painted pixels (%s)" % [checkpoint, pair])
			if checkpoint.begins_with("opening-boon"):
				_expect(measurement.paints.rules.pixels > 0 and measurement.paints.rules.in_safe_area,
					"%s rules paint inside the safe area" % checkpoint)
	_receipts.append(receipt)
	print("UI39 STATE: " + JSON.stringify(receipt))

func _expect(condition: bool, message: String) -> void:
	if condition: return
	_failed = true
	print("UI39 CHECK FAIL: " + message)
