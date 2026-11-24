extends "res://tests/pre_battle_fixture.gd"

const RunScene = preload("res://scripts/run_scene.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const Skills = preload("res://tests/suites/skill_run_suite.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")

const SEED: int = Skills.SEED
const UI_SCALE: float = 1.0
const PASS_LIMIT: int = 24
const CAPTURE_DIRECTORY: String = "res://.godot/gfix52/native"
const BAND_GAP: float = 16.0
const DIALOGUE_WAIT_MS: int = 12000
const NOTICE_RETURN_WAIT_MS: int = 2000

var _engine := RunEngine.new()
var _headless: bool


func _initialize() -> void:
	_setup()
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	root.content_scale_size = PROBE_VIEWPORT
	Settings.set_storage_path("user://gfix52-settings.json")
	ProgressionStore.set_storage_path("user://gfix52-profile.json")
	ProgressionStore.set_run_storage_path("user://gfix52-run.save")
	Analytics.set_storage_dir("user://gfix52-analytics")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = false
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	_expect(Settings.save_settings(settings), "The proof uses 100% UI scale")
	_expect(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "The proof uses the full cel look")
	call_deferred("_run")


func _run() -> void:
	var profile: Dictionary = Skills._new_run(_engine, ["last_door"])["progression"]
	profile = Tutorial.dismiss_tutorial(profile)
	_expect(ProgressionStore.save_data(profile), "Save a starting profile with Last Door owned")
	root.set_meta(InitialGraph.SEED_OVERRIDE, SEED)
	var scene: RunScene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(scene)
	root.remove_meta(InitialGraph.SEED_OVERRIDE)
	await _settle()
	scene._close_dialogue()
	scene._close_large_map()
	await _settle()
	scene._close_large_map()
	await _play_first_fight(scene)
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	print("GFIX-52 RETREAT CAPTURE %s: %s" % ["DRY RUN" if _headless else "NATIVE", "FAIL" if _failed else "PASS"])
	Shutdown.request(self, "gfix52_retreat_capture", int(_failed))


func _play_first_fight(scene: RunScene) -> void:
	var start: Dictionary = scene._run_state
	var previous: Vector2i = start["current_room"]
	var resting: Rect2 = _canvas_rect(scene.log_overlay)
	_expect(not scene._dialogue_overlay.is_visible_in_tree()
		and is_equal_approx(scene.log_overlay.offset_top, -118.0)
		and is_equal_approx(scene.log_overlay.offset_bottom, -12.0), "The notice uses its usual offsets with no dialogue")
	var destinations: Array[Vector2i] = _engine.available_moves(start)
	_expect(SectionMapGraph.enabled(start) and previous == Vector2i.ZERO and _engine.run_skill_is_ready(start, "last_door"),
		"Start a fresh default-section run with Last Door ready")
	if destinations.is_empty():
		_fail("The starting room has no outward connection")
		return
	var first: Vector2i = destinations.front()
	_expect(_engine.room_metadata(start, first)["type"] == "combat", "The first route opens an ordinary fight")
	await scene._on_map_view_room_selected(first)
	await scene._on_pre_battle_start_pressed()
	_expect(scene._run_state["mode"] == "combat" and scene._run_state["current_room"] == first, "Enter the generated first fight")
	if _failed: return
	var passes: int = 0
	while scene._run_state["mode"] == "combat" and passes < PASS_LIMIT:
		passes += 1
		await _settle()
		await scene._on_pass_turn_pressed()
	var retreated: Dictionary = scene._run_state
	_expect(retreated["mode"] == "room" and retreated["current_room"] == previous
		and retreated["player_hp"] == GameData.fixed_point_amount(1) and _engine.run_skill_used_this_sequence(retreated, "last_door"),
		"Enemy turns defeat the player and Last Door returns to the starting room at 1 Health")
	if _failed: return
	scene._close_large_map()
	await _settle()
	var saved: Dictionary = ProgressionStore.load_checkpoint_for_resume()
	_expect(saved.get("current_room") == previous and saved.get("player_hp") == 1 and saved.get("mode") == "room"
		and _engine.run_skill_used_this_sequence(saved, "last_door"), "The live retreat checkpoint is resumable")
	var board: Dictionary = scene.board_view.get("combat_state")
	var health_rects: Dictionary = scene.board_view.get("_hud_health_rects_cache")
	var health_rect: Rect2 = health_rects.get("player", Rect2())
	_expect(board.get("room_coord") == previous and board.get("player", {}).get("hp") == 1 and health_rect.has_area()
		and is_equal_approx(Typography.ui_scale(scene), UI_SCALE), "The returned room submits a visible Health plate at 100% UI scale")
	var events: Array[Dictionary] = Analytics.load_all_events()
	var retreats: Array = events.filter(func(event: Dictionary) -> bool:
		return event.get("event_type") == "skill_triggered" and event.get("payload", {}).get("skill_id") == "last_door")
	_expect(retreats.size() == 1, "The live retreat emits one Last Door receipt")
	print("GFIX-52 live_retreat | passes=%d fight=%s returned=%s Health=%s HUD=%s/%s saved=%s skill_receipts=%d" %
		[passes, first, retreated["current_room"], retreated["player_hp"], board.get("player", {}).get("hp"),
			board.get("player", {}).get("max_hp"), not saved.is_empty(), retreats.size()])
	await _check_notice_placement(scene, resting, str(retreated["notice"]))


func _check_notice_placement(scene: RunScene, resting: Rect2, retreat_notice: String) -> void:
	var deadline: int = Time.get_ticks_msec() + DIALOGUE_WAIT_MS
	while not (scene._dialogue_text_complete and scene.log_overlay.is_visible_in_tree()) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(scene._dialogue_overlay.is_visible_in_tree() and scene._dialogue_text_complete
		and scene._dialogue_script.get("npc_id") == "emaciated_man"
		and scene.log_overlay.is_visible_in_tree() and scene.log_label.text.contains(retreat_notice),
		"The real retreat notice and the fully revealed Emaciated Man dialogue are visible together")
	if _failed: return
	var text: String = scene.log_label.text
	var raised: Rect2 = _canvas_rect(scene.log_overlay)
	var band_top: float = _band_top(scene._dialogue_overlay)
	var gap: float = band_top - raised.end.y
	_expect(gap >= BAND_GAP and is_equal_approx(raised.end.x, resting.end.x) and raised.size.is_equal_approx(resting.size),
		"The notice keeps its right margin and size at least 16 pixels above the painted dialogue")
	await _capture_state("last_door_retreat_dialogue_open.png")
	scene._close_dialogue()
	var eased: bool = false
	var clear_through_fade: bool = true
	deadline = Time.get_ticks_msec() + NOTICE_RETURN_WAIT_MS
	while Time.get_ticks_msec() < deadline:
		if scene._large_map_scrim.visible: scene._close_large_map()
		var current: Rect2 = _canvas_rect(scene.log_overlay)
		if scene._dialogue_overlay.is_visible_in_tree():
			clear_through_fade = clear_through_fade and _band_top(scene._dialogue_overlay) - current.end.y >= BAND_GAP
		elif current.is_equal_approx(resting):
			break
		elif current.position.y > raised.position.y and current.position.y < resting.position.y:
			eased = true
		await process_frame
	var returned: Rect2 = _canvas_rect(scene.log_overlay)
	_expect(not scene._dialogue_overlay.is_visible_in_tree() and clear_through_fade and eased
		and returned.is_equal_approx(resting) and scene.log_overlay.is_visible_in_tree() and scene.log_label.text == text,
		"The unchanged notice eases home after the band finishes fading")
	print("GFIX-52 notice_placement | gradient_top=%.1f raised_bottom=%.1f gap=%.1f resting_bottom=%.1f returned_bottom=%.1f clear_through_fade=%s eased=%s" %
		[band_top, raised.end.y, gap, resting.end.y, returned.end.y, clear_through_fade, eased])
	await _capture_state("last_door_retreat_dialogue_closed.png")


func _band_top(dialogue: Control) -> float:
	var scrim: Control = dialogue.get_node("HudSeatScrim")
	var gradient: Dictionary = scrim.get("_bottom_seat")
	var gradient_top: float = (scrim.get_global_transform_with_canvas() * Vector2(0.0, gradient["top"])).y
	return minf(gradient_top, _canvas_rect(dialogue.get_node("DialogueDialog/DialogueContentRow/DialogueBandWipe")).position.y)


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _capture_state(filename: String) -> void:
	if _headless or _failed: return
	var path: String = ProjectSettings.globalize_path(CAPTURE_DIRECTORY.path_join(filename))
	await _capture(path)
	if not _failed: print(path)
