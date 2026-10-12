extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Suite = preload("res://tests/suites/run_score_suite.gd")
const Overlay = preload("res://scripts/run_end_recap_overlay.gd")
const CLOCK_PROOF_FRAMES: int = 3
const POOL_WARM_PROOF_FRAME_BUDGET: int = 120
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	Store.set_storage_path("user://run_score_test_profile.json")
	Store.set_run_storage_path("user://run_score_test_run.save")
	Analytics.set_storage_dir("user://run_score_test_analytics")
	call_deferred("_run")

func _run() -> void:
	Suite.run(_assert)
	await _test_live_clock_and_terminal_bridge()
	var overlay := Overlay.new()
	overlay.size = Vector2(1920, 1080)
	root.add_child(overlay)
	await process_frame
	var state: Dictionary = {"run_stats": {"rooms_explored": 29, "enemies_slain": 61, "max_single_hit": 22}}
	for outcome: String in ["defeat", "victory", "embrace"]:
		overlay.present(Overlay.build_model(state, {}, outcome, 214))
		overlay.seek_presentation(0)
		_assert((overlay.find_child("OutcomeTitle", true, false) as Label).modulate.a == 0, "Title starts transparent")
		overlay.skip_presentation()
		_assert((overlay.find_child("ScoreValue", true, false) as Label).text == str(overlay.recap_model()["score"]["total"]), "Skip completes score count")
		_assert((overlay.find_child("ChronicleButton", true, false) as Button).disabled, "Chronicle remains disabled")
		_assert((overlay.find_child("ChronicleButton", true, false) as Button).tooltip_text == "Coming soon", "Chronicle tooltip is approved copy")
		_assert_recap_presentation(overlay, outcome)
		overlay.reset()
		overlay.set_motion_enabled(false)
		overlay.present(Overlay.build_model(state, {}, outcome, 214))
		_assert((overlay.find_child("OutcomeTitle", true, false) as Label).modulate.a == 1, "Reduced motion shows title immediately")
		_assert((overlay.find_child("NewBestTag", true, false) as Label).scale == Vector2.ONE, "Reduced motion settles NEW BEST pop")
		overlay.set_motion_enabled(true)
	await _test_ledger_layout(overlay)
	overlay.free()
	for failure: String in _failures:
		push_error(failure)
	print("RUN SCORE TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d failure(s))" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)

func _test_live_clock_and_terminal_bridge() -> void:
	var scene: Control = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var before: float = float((scene.get("_run_state") as Dictionary)["run_stats"]["run_seconds"])
	for index: int in range(CLOCK_PROOF_FRAMES):
		await physics_frame
		await process_frame
	var active: float = float((scene.get("_run_state") as Dictionary)["run_stats"]["run_seconds"])
	_assert(active > before, "Hidden recap clock advances active gameplay")
	scene.call("_open_menu_overlay")
	var paused_at: float = float((scene.get("_run_state") as Dictionary)["run_stats"]["run_seconds"])
	for index: int in range(CLOCK_PROOF_FRAMES):
		await physics_frame
		await process_frame
	_assert(float((scene.get("_run_state") as Dictionary)["run_stats"]["run_seconds"]) == paused_at, "Menu pauses live play-time clock")
	scene.call("_close_menu_overlay")
	var terminal: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	terminal["mode"] = "defeat"
	terminal["game_over"] = true
	terminal["run_stats"]["rooms_explored"] = 3
	var result: Dictionary = scene.call("_terminal_state_with_recorded_run_result", terminal, Store.default_data())
	_assert(result["run_result"]["score"] == 15 and result["progression"]["best_score"] == 15, "Existing terminal bridge stores score without changing Steam stat ids")
	var recap: Control = scene.get("_run_end_recap") as Control
	var portrait_state: Dictionary = terminal.duplicate(true)
	portrait_state.erase("run_result")
	for enemy_type: String in ["crawler", "ashen_reaver", "frostglass_lancer"]:
		portrait_state["run_stats"]["killer"] = {"enemy_type": enemy_type, "intent_id": "", "damage": 6}
		recap.call("present", Overlay.build_model(portrait_state, {}, "defeat", 0))
		var portrait: Control = recap.find_child("KillerPortrait", true, false) as Control
		_assert(portrait.visible and portrait.get("texture") is Texture2D, "Killer portrait uses the existing registry, including aliases and guardian paths")
	var engine := preload("res://scripts/run_engine.gd").new()
	var hearth: Dictionary = engine.create_new_run(8821, Store.default_data())
	var hearth_coord: Vector2i = engine.available_moves(hearth)[0]
	hearth["rooms"]["%d,%d" % [hearth_coord.x, hearth_coord.y]]["type"] = "campfire"
	hearth = engine.move_to_room(hearth, hearth_coord)
	hearth = engine.set_held_embers(hearth, 214)
	await _test_cutout_death(scene, engine, hearth, hearth_coord)
	Store.save_data(hearth["progression"])
	scene.call("_load_run_state", hearth)
	scene.call("_close_dialogue")
	recap.call("set_motion_enabled", false)
	await scene.call("_on_campfire_embrace_pressed")
	await process_frame
	await process_frame
	_assert(recap.visible and str(recap.call("recap_model")["title"]) == "WITHDRAWN" and (scene.get("_run_state") as Dictionary)["held_embers"] == 214, "Production Embrace routes into withdrawal recap without defeat-loss processing")
	_assert(Store.load_data()["embers"] == 214 and Store.last_run_result(Store.load_data())["outcome"] == "embrace" and Store.load_saved_run().is_empty(), "Embrace banks, scores and clears the resumable run before displaying recap")
	_assert(not bool(scene.get("_animation_lock")), "Embrace releases the choice animation lock for recap actions")
	_assert_recap_presentation(recap, "embrace")
	_assert(recap.get_parent() == scene.get_node("UiLayer/UiRoot") and recap.get_global_rect() == Rect2(0, 0, 1920, 1080), "Embrace uses the same full-viewport backdrop as victory")
	for property: String in ["stats_label", "loadout_button", "grimoire_button", "menu_button"]:
		_assert(not (scene.get(property) as Control).is_visible_in_tree(), "Withdrawal hides the top-right HUD: %s" % property)
	scene.call("_on_restart_pressed")
	_assert((scene.get("_run_state") as Dictionary)["mode"] == "room" and engine.held_embers(scene.get("_run_state")) == 214, "Rise Again starts a fresh run with banked Embrace Embers")
	for index: int in range(POOL_WARM_PROOF_FRAME_BUDGET):
		if not bool(scene.get("_pile_dialog_pool_warm_scheduled")): break
		await process_frame
	_assert(not bool(scene.get("_pile_dialog_pool_warm_scheduled")), "Restart's existing card-pool coroutine finishes before fixture teardown")
	scene.free()
	await process_frame

func _test_cutout_death(scene: Control, engine: RefCounted, run_state: Dictionary, coord: Vector2i) -> void:
	var room: Dictionary = engine.room_metadata(run_state, coord).duplicate(true)
	room["type"] = "combat"
	var layout: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i(1, 0), run_state)
	var combat := preload("res://scripts/combat_engine.gd").new()
	var before: Dictionary = combat.create_combat(int(run_state["seed"]), layout, engine.call("_player_snapshot", run_state))
	var living: Dictionary = run_state.duplicate(true)
	living["mode"] = "combat"
	living["combat_state"] = before
	living["current_room_layout"] = layout
	scene.call("_load_run_state", living)
	scene.call("_close_dialogue")
	var after: Dictionary = before.duplicate(true)
	after["player"]["hp"] = 0
	var death: Dictionary = scene.call("_death_hold_presentation", before, after, {})
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
	for progress: float in [0.20, 0.60, 1.0]:
		death["death_animation_units"][0]["death_progress"] = progress
		scene.call("_render_board_state", after, death)
		await process_frame
		await process_frame
		var snapshot: Dictionary = board.call("protagonist_animation_snapshot")
		var expected: float = clampf(progress / preload("res://scripts/cutout_context.gd").DEATH_SETTLE_PROGRESS, 0, 1)
		_assert(snapshot.get("clip") == "death" and is_equal_approx(float(snapshot.get("phase", -1)), expected) and int(snapshot.get("texture_id", 0)) != 0, "Probe death phases use the current cutout clip and approved texture")

func _test_ledger_layout(overlay: Control) -> void:
	var state: Dictionary = {"run_stats": {"rooms_explored": 29, "enemies_slain": 61, "guardians_slain": 6, "guardians_unscathed": ["craghide", "rimejaw"], "dragons_slain": ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"], "dragons_flawless": ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"], "max_single_hit": 22, "max_kills_one_card": 3, "mystery_rooms_entered": 10, "events_resolved": 8, "max_held_embers": 1200, "defiance_spent": 1, "run_seconds": 2699}}
	overlay.present(Overlay.build_model(state, {}, "victory", 1200))
	await process_frame
	await process_frame
	var ledger: Control = overlay.find_child("ScoreLedger", true, false)
	var bases: Control = ledger.get_node("ScoreRows")
	var feats: Control = ledger.get_node("FeatRows")
	_assert(not ledger is ScrollContainer and ledger.size == Vector2(780, 380), "Fifteen earned rows fit without scrolling in the full-width ledger")
	_assert(bases.get_child_count() == 5 and feats.get_child_count() == 10 and feats.position.x == 400, "Overflow puts base rows left and feats right with a 20 px gap")
	for column: Control in [bases, feats]:
		for row: Control in column.get_children():
			_assert(row.custom_minimum_size == Vector2(380, 38) and row.size == Vector2(380, 38), "Overflow preserves approved column width and row type sizes")
			var detail: Label = row.get_node("ScoreDetail")
			_assert(detail.clip_text and detail.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and detail.tooltip_text == detail.text and detail.mouse_filter == Control.MOUSE_FILTER_PASS, "Overflow details truncate with ellipsis and retain full tooltip")
			_assert_row_bounds(row)
	state["run_stats"].erase("events_resolved")
	state["run_stats"].erase("mystery_rooms_entered")
	state["run_stats"].erase("max_single_hit")
	state["run_stats"].erase("max_kills_one_card")
	state["run_stats"].erase("defiance_spent")
	state["run_stats"]["run_seconds"] = 3600
	overlay.present(Overlay.build_model(state, {}, "victory", 1200))
	await process_frame
	await process_frame
	_assert(bases.get_child_count() == 9 and not feats.visible and ledger.size.x == 560, "Exactly nine rows retain the single 560 px column")
	for row: Control in bases.get_children(): _assert_row_bounds(row)
	var no_quip: Dictionary = overlay.recap_model()
	no_quip["quip"] = ""
	overlay.present(no_quip)
	_assert(not (overlay.find_child("OutcomeQuip", true, false) as Label).visible, "Missing quip omits the line")

func _assert_row_bounds(row: Control) -> void:
	var label: Label = row.get_node("ScoreLabel")
	var detail: Label = row.get_node("ScoreDetail")
	var points: Label = row.get_node("ScorePoints")
	_assert(detail.position.x >= label.position.x + label.size.x and detail.position.x + detail.size.x <= points.position.x and points.position.x + points.size.x <= row.size.x, "Actual detail and value geometry cannot overlap labels, points or the other column")
	var expected_width: float = row.size.x - label.position.x - label.size.x - points.size.x - Overlay.SCORE_DETAIL_GAPS
	_assert(is_equal_approx(detail.size.x, maxf(0, expected_width)), "Detail width reserves the approved 12 px combined gap")

func _assert_recap_presentation(overlay: Control, outcome: String) -> void:
	var column: Control = overlay.find_child("OutcomeRecap", true, false)
	_assert(column.position == Vector2(1010, 82) and column.get_global_rect().size.x == 780 and column.global_position == Vector2(1010, 82), "Recap uses the approved viewport origin and width")
	var quip: Label = overlay.find_child("OutcomeQuip", true, false)
	var italic: FontVariation = quip.get_theme_font("font") as FontVariation
	_assert(italic != null and italic.base_font == load("res://fonts/LabyrinthCrumble-Text.tres") and is_equal_approx(italic.variation_transform.get_skew(), 0.2) and quip.get_theme_font_size("font_size") == 24 and quip.get_theme_color("font_color") == Overlay.Palette.TEXT_2, "Quip uses approved Text font with synthetic 0.2 oblique")
	var title: Label = overlay.find_child("OutcomeTitle", true, false)
	_assert(title.get_theme_constant("shadow_offset_x") == 0 and title.get_theme_constant("shadow_offset_y") == 3, "Title drop shadow retains offset 0,3")
	var glow: Control = overlay.find_child("TitleGlow", true, false)
	var color: Color = Overlay.Palette.UMBRA if outcome == "defeat" else Overlay.Palette.EMBER
	var opacity_remaining: float = 1.0
	_assert(glow.get_child_count() == 18, "Title glow uses the approved 18 px radius")
	for layer: Label in glow.get_children():
		var ink: Color = layer.get_theme_color("font_outline_color")
		_assert(Color(ink, 1) == Color(color, 1) and layer.text == title.text, "Glow uses the outcome color behind the same title glyphs")
		opacity_remaining *= 1.0 - ink.a
	_assert(is_equal_approx(1.0 - opacity_remaining, 0.25), "Glow combines to the approved 25% inner alpha")
	var rule: Control = overlay.find_child("GildedRule", true, false)
	_assert(rule.get_parent() == column and rule.size == Vector2(560, 14), "Gilded rule is drawn above the death shroud over 560 px")
	var primary: Button = overlay.find_child("NewRunButton", true, false)
	var menu: Button = overlay.find_child("MainMenuButton", true, false)
	_assert(primary.get_node(primary.focus_neighbor_right) == menu and primary.get_node(primary.focus_neighbor_left) == menu and menu.get_node(menu.focus_neighbor_right) == primary and menu.get_node(menu.focus_neighbor_left) == primary, "Controller focus paths survive viewport reparenting and skip Chronicle")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
