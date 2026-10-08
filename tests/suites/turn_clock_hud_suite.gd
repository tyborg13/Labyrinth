extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const Ink = preload("res://scripts/turn_order_ink.gd")
const Strip = preload("res://scripts/turn_order_landing_strip.gd")
const ForecastLine = preload("res://scripts/turn_clock_forecast_line.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const GameData = preload("res://scripts/game_data.gd")
const ReviewSuite = preload("res://tests/suites/turn_clock_hud_review_suite.gd")
const SIZE := Vector2i(1920, 1080)
const HAND: Array = ["pale_spark", "quick_stab", "sidestep_slash", "bloody_lunge", "brace"]

# The same semantic checks run headlessly and before each real-renderer capture.
static func run(tree: SceneTree, expect: Callable, capture_dir: String = "") -> void:
	# The caller collects every failure. Failed semantic checks must not suppress
	# this or later states' captures, which remain useful for diagnosing the HUD.
	var check: Callable = expect
	_test_pills_and_tooltips(check)
	_test_roles_and_placement(check)
	var old_mode: int = tree.root.mode
	var old_scale: float = tree.root.content_scale_factor
	var old_reduced_motion: bool = SettingsStore._applied_reduced_motion
	# A root Window's backing texture follows the display's Retina pixel density.
	# Keep both headless geometry checks and renderer captures in this fixed target.
	var capture_viewport := SubViewport.new()
	capture_viewport.name = "TurnClockHud1920x1080"
	capture_viewport.size = SIZE
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(capture_viewport)
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	capture_viewport.add_child(scene)
	await _settle(tree)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	scene.set("_settings", settings)
	SettingsStore.apply_settings(settings, tree.root, false)
	check.call(scene.get_viewport() == capture_viewport and capture_viewport.size == SIZE and capture_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "The production run scene uses the fixed 1920x1080 capture SubViewport")
	var engine := CombatEngine.new()
	var state: Dictionary = fixture(engine)
	await _install(tree, scene, state)
	_assert_state(scene, check, 10, "", -1, [], "", "idle")
	var idle_hero: Dictionary = _projected_hero(scene)
	check.call(int(idle_hero.get("eta", -1)) == 19 and int(idle_hero.get("projected_wait_time", -1)) == 10, "idle: the end-now ghost is +19 including +10 Wait")
	await _capture(capture_viewport, check, capture_dir, "idle")

	await _hover(tree, scene, 1)
	_assert_state(scene, check, 10, "Quick Stab −3", -3, ["enemy:enemy_1"], "enemy:enemy_2", "hover_fast")
	_assert_badge_tooltip(scene, check)
	await _capture(capture_viewport, check, capture_dir, "hover_fast")
	await _hover(tree, scene, 3)
	_assert_state(scene, check, 10, "Bloody Lunge +1", 1, ["enemy:enemy_1", "enemy:enemy_2"], "enemy:enemy_3", "hover_heavy")
	await _capture(capture_viewport, check, capture_dir, "hover_heavy")

	state = _play(engine, state, "brace")
	check.call(int(state.get("cards_played_this_turn", 0)) == 1 and int(state.get("player_turn_time_spent", 0)) == 1, "Brace is actually played through the engine, spending one play and one Time")
	await _install(tree, scene, state)
	await _hover(tree, scene, 1)
	_assert_state(scene, check, 5, "Quick Stab −3", -3, [], "enemy:enemy_1", "mid_turn_act_again")
	check.call(int(_projected_hero(scene).get("eta", -1)) == 12, "mid_turn_act_again: Quick Stab returns at +12 before Harrier +13")
	await _capture(capture_viewport, check, capture_dir, "mid_turn_act_again")
	state = _play(engine, state, "quick_stab", Vector2i(3, 4))
	await _install(tree, scene, state)
	_assert_state(scene, check, 0, "", -1, [], "", "both_plays_used")
	await _capture(capture_viewport, check, capture_dir, "both_plays_used")

	await _install(tree, scene, fixture(engine))
	var router: Node = tree.root.get_node("InputRouter")
	var old_modality: String = str(router.call("modality"))
	router.call("set_modality", "controller")
	scene.set("_controller_hand_index", 0)
	scene.call("_controller_cycle_hand", 1)
	await _settle(tree)
	check.call(int(scene.get("_controller_hand_index")) == 1, "controller_focus_fast: the bumper advances focus to Quick Stab")
	_assert_state(scene, check, 10, "Quick Stab −3", -3, ["enemy:enemy_1"], "enemy:enemy_2", "controller_focus_fast")
	await _capture(capture_viewport, check, capture_dir, "controller_focus_fast")
	router.call("set_modality", "pointer")
	settings["reduced_motion"] = true
	scene.set("_settings", settings)
	SettingsStore.apply_settings(settings, tree.root, false)
	await _install(tree, scene, fixture(engine))
	scene.call("_on_card_hover_started", 1)
	check.call(is_equal_approx((scene.get("_turn_order_landing_strip") as Control).modulate.a, 1.0), "Reduced motion makes the strip opaque before advancing any frames")
	await _settle(tree)
	_assert_state(scene, check, 10, "Quick Stab −3", -3, ["enemy:enemy_1"], "enemy:enemy_2", "reduced_motion_fast")
	check.call(is_equal_approx((scene.get("_turn_order_landing_strip") as Control).modulate.a, 1.0), "reduced_motion_fast: the strip appears at full opacity immediately")
	await _capture(capture_viewport, check, capture_dir, "reduced_motion_fast")

	await _install(tree, scene, lap_fixture(engine))
	_assert_state(scene, check, 10, "", -1, [], "", "pass_lap_known_damage")
	var summary: Dictionary = scene.call("_pass_preview_summary")
	var line: Label = scene.find_child("PassPreviewForecastLine", true, false) as Label
	check.call(bool(summary.get("unrevealed_before_player", false)) and not bool(summary.get("umbra_unknown_before_player", false)) and int(summary.get("hp_loss", 0)) == 5, "pass_lap_known_damage: a revealed 5 HP hit precedes an unrevealed second activation")
	check.call(line.text == "+10  •  -5 +?", "pass_lap_known_damage: exact lead, damage, and single-space +? suffix: %s" % line.text)
	scene.call("_update_action_context_risk")
	var risk_text: String = str((scene.get("_action_step_tracker") as Control).get_meta("risk_text", ""))
	check.call(risk_text == "WAIT +10 · -5 HP +?", "The action context retains known HP damage and the same suffix: %s" % risk_text)
	await _capture(capture_viewport, check, capture_dir, "pass_lap_known_damage")
	await _test_preview_visibility(tree, scene, engine, check)
	_test_forecasts(scene, check)
	await ReviewSuite.run(tree, scene, engine, check, fixture(engine), _install, _hover, func(phase: String) -> void: await _capture(capture_viewport, check, capture_dir, phase))
	router.call("set_modality", old_modality)
	capture_viewport.queue_free()
	await tree.process_frame
	tree.root.content_scale_factor = old_scale
	tree.root.mode = old_mode
	SettingsStore._applied_reduced_motion = old_reduced_motion

static func _test_pills_and_tooltips(expect: Callable) -> void:
	var scene := RunScene.new()
	for delta: int in [-3, 0, 1]:
		var entry: Dictionary = {"kind": "player", "projected": true, "projected_card_name": "  Quick Stab  ", "projected_time_delta": delta, "projected_time_cost": 2}
		expect.call(str(scene.call("_turn_order_projection_badge_text", entry)) == "Quick Stab %s" % Ink.delta_text(delta), "Pill uses the signed delta and strips surrounding name whitespace")
		var style: StyleBoxFlat = scene.call("_turn_order_projection_badge_style", delta)
		var bg: Color = Color(Color("27465a"), 0.94) if delta < 0 else Color(Color("4a2410"), 0.94) if delta > 0 else Color(0.12, 0.085, 0.035, 0.92)
		var border: Color = Color("a8e4ff") if delta < 0 else UiPalette.EMBER if delta > 0 else Color("f4c968")
		expect.call(style.bg_color.is_equal_approx(bg) and style.border_color.is_equal_approx(border), "Pill style matches delta sign %d" % delta)
		entry["projected_card_name"] = ""
		expect.call(Ink.projection_text(entry) == "%s Time" % Ink.delta_text(delta), "Unnamed pill keeps the delta followed by Time")
		entry["projected_card_name"] = "A Very Long Card Name That Must Be Shortened"
		var text: String = Ink.projection_text(entry, UiTypography.ui_font(), 80)
		expect.call(text.ends_with(" " + Ink.delta_text(delta)) and text.contains("…") and UiTypography.ui_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 80, "Name trimming preserves the complete delta and fits its width")
		expect.call(Ink.projection_text(entry, UiTypography.ui_font(), 1) == Ink.delta_text(delta), "Even an impossibly narrow name budget keeps the delta")
		expect.call(bool(scene.call("_turn_order_is_card_preview_projection", entry)), "Zero-Time and zero-delta cards still show a preview")
	expect.call(str(scene.call("_turn_order_projection_badge_text", {"stagger_preview": 4})) == "Stagger +4", "Stagger pill copy remains unchanged")
	expect.call(str(scene.call("_turn_order_projection_badge_text", {"petrified": true})) == "Skips", "Petrified pill copy remains unchanged")
	var entry: Dictionary = {"kind": "player", "projected": true, "projection_kind": "end_now", "name": "Reaver", "eta": 12, "base_initiative": 9, "turn_time_spent": 1, "projected_time_cost": 2, "projected_wait_time": 0, "projected_time_delta": -3, "projected_card_name": "Quick Stab"}
	var tooltip: String = scene.call("_turn_order_tooltip", entry, 0)
	expect.call(tooltip.contains("Preview: Quick Stab (−3 vs ending now)") and tooltip.contains("Base 9 + cards 3 + unused plays 0"), "Projected tooltip shows delta and full Time breakdown")
	entry["eta"] = 17
	expect.call(str(scene.call("_turn_order_tooltip", entry, 0)).contains("Carried +5"), "Projected tooltip exposes carried Time")
	entry["eta"] = 10
	expect.call(str(scene.call("_turn_order_tooltip", entry, 0)).contains("Relics −2"), "Projected tooltip exposes relic reductions")
	entry.erase("projected_time_delta")
	entry["projected_time_cost"] = 0
	entry["projected_wait_time"] = 10
	entry["turn_time_spent"] = 0
	entry["eta"] = 19
	tooltip = scene.call("_turn_order_tooltip", entry, 0)
	expect.call(not tooltip.contains("Preview:") and tooltip.contains("Base 9 + cards 0 + unused plays 10"), "End-now tooltip keeps the breakdown without a preview line")
	scene.free()

static func _test_roles_and_placement(expect: Callable) -> void:
	var entries: Array[Dictionary]
	entries.append({"kind": "player", "actor_key": "player", "active": true})
	for index: int in range(6):
		entries.append({"kind": "enemy", "actor_key": "enemy_%d" % index, "eta": index + 1, "team": "enemy", "hidden_by_umbra": index == 0})
	entries.append({"kind": "player", "actor_key": "player", "projected": true, "eta": 9})
	entries.append({"kind": "enemy", "actor_key": "after", "eta": 10})
	var roles: Dictionary = Strip.roles_for(entries)
	expect.call((roles.get("before", []) as Array).size() == 6 and int(roles.get("overflow", 0)) == 2 and str((roles["after"] as Dictionary)["actor_key"]) == "after", "Strip roles include all overflow rail entries and exactly the next actor")
	expect.call(bool((roles["before"][0] as Dictionary)["hidden_by_umbra"]), "Umbra-hidden before entries stay hidden during extraction")
	var again_entries: Array[Dictionary]
	again_entries.append(entries[0])
	again_entries.append(entries[7])
	again_entries.append(entries[8])
	expect.call(bool(Strip.roles_for(again_entries).get("act_again", false)), "No actors before the hero means ACT AGAIN")
	expect.call(Strip.content_signature(roles, 1) != Strip.content_signature(roles, 2), "Focused index participates in strip content signature")
	var view := Rect2(0, 0, 1920, 1080)
	var card := Rect2(850, 650, 250, 352)
	var right := Rect2(1120, 520, 300, 430)
	var left := Rect2(520, 520, 300, 430)
	var area := Vector2(330, 64)
	var rect: Rect2 = Strip.placement(card, right, area, view)
	expect.call(is_equal_approx(rect.end.x, card.end.x + 8) and is_equal_approx(rect.end.y, card.position.y - 4) and not rect.intersects(right), "Strip right-aligns above the card away from a right tooltip")
	rect = Strip.placement(card, left, area, view)
	expect.call(is_equal_approx(rect.position.x, card.position.x - 8) and not rect.intersects(left), "Strip left-aligns away from a left tooltip")
	for fixture_card: Rect2 in [Rect2(0, 0, 250, 352), Rect2(1780, 1060, 250, 352)]:
		rect = Strip.placement(fixture_card, Rect2(), area, view)
		expect.call(view.grow(-16).encloses(rect), "Strip clamps inside all viewport gutters")
	var crossing := Rect2(900, 500, 360, 450)
	rect = Strip.placement(card, crossing, area, view)
	expect.call(rect.has_area() and not rect.intersects(crossing) and view.grow(-16).encloses(rect), "Clamped tooltip crossing the card cannot overlap the strip")
	var full_width := Rect2(16, 200, 1888, 800)
	rect = Strip.placement(card, full_width, area, view)
	expect.call(rect.has_area() and not rect.intersects(full_width), "Placement can clear a full-width stack vertically")
	expect.call(not Strip.placement(card, view, area, view).has_area(), "Impossible placement yields no overlapping strip")

static func fixture(engine: CombatEngine) -> Dictionary:
	var state: Dictionary = engine.create_combat(73101, room_layout(), {"hp": 24, "max_hp": 24, "deck_cards": HAND.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	state["deck"]["hand"] = HAND.duplicate()
	state["deck"]["draw"] = ["patch_up", "dull_bolt", "whirlwind_slash"]
	state["deck"]["discard"] = []
	return state

static func room_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {"name": "Fevered Vault", "coord": Vector2i(1, 0), "type": "combat", "grid": grid, "player_start": Vector2i(2, 4), "enemies": [
		{"id": 1, "type": "harrier", "pos": Vector2i(3, 4), "hp": 10, "max_hp": 10, "block": 0},
		{"id": 2, "type": "acolyte", "pos": Vector2i(5, 2), "hp": 11, "max_hp": 11, "block": 0},
		{"id": 3, "type": "warden", "pos": Vector2i(5, 5), "hp": 16, "max_hp": 16, "block": 0}], "traps": [], "terrain": [], "loot": []}

static func lap_fixture(engine: CombatEngine) -> Dictionary:
	var state: Dictionary = fixture(engine)
	var enemy: Dictionary = (state["enemies"][0] as Dictionary).duplicate(true)
	enemy["type"] = "crawler"
	enemy["intent"] = {"name": "Revealed bite", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	state["enemies"] = [enemy]
	state["turn_queue"] = [{"kind": "enemy", "actor_key": "enemy_1", "enemy_id": 1, "type": "crawler", "name": "Tunnel Crawler", "team": "enemy", "time": 1, "seq": 1, "pos": Vector2i(3, 4)}]
	return state

static func _play(engine: CombatEngine, state: Dictionary, card_id: String, target: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var index: int = (state["deck"]["hand"] as Array).find(card_id)
	var working: Dictionary = engine.prepare_player_card(state, index)
	var actions: Array = engine.card_play_actions(card_id, working)
	for action: Dictionary in actions:
		working = engine.apply_player_action(working, action, target if engine.player_action_needs_target(action) else Vector2i(-1, -1))
	return engine.finish_player_card(working, index, engine.card_plays_spent_for_actions(actions))

static func _install(tree: SceneTree, scene: Node, state: Dictionary) -> void:
	var viewport: Viewport = scene.get_viewport()
	viewport.gui_release_focus()
	if DisplayServer.get_name() != "headless":
		viewport.warp_mouse(Vector2(120, 560))
	# A standalone SubViewport otherwise keeps its pointer at the top-left.
	# Feed viewport-local pointer coordinates, independently of the root Window.
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(120, 560)
	pointer.global_position = pointer.position
	viewport.push_input(pointer, true)
	scene.call("_cancel_drag_play")
	scene.call("_reset_card_resolution")
	scene.set("_hovered_card_index", -1)
	scene.set("_controller_hand_focused", false)
	var run: Dictionary = RunEngine.new().create_new_run(73101, ProgressionStore.default_data())
	run["mode"] = "combat"
	run["current_room"] = Vector2i(1, 0)
	run["current_room_layout"] = room_layout()
	run["combat_state"] = state
	run["notice"] = ""
	var tutorial_states: Dictionary = {}
	for prompt_id: String in Tutorial.prompt_ids():
		tutorial_states[prompt_id] = Tutorial.STATUS_COMPLETED
	run["progression"][Tutorial.PROGRESSION_KEY] = tutorial_states
	scene.call("_load_run_state", run)
	scene.set("_animation_lock", false)
	(scene.get("log_overlay") as Control).visible = false
	scene.call("_refresh_ui")
	await _settle(tree)

static func _hover(tree: SceneTree, scene: Node, index: int) -> void:
	var old_index: int = int(scene.get("_hovered_card_index"))
	if old_index >= 0:
		scene.call("_on_card_hover_ended", old_index)
	scene.call("_on_card_hover_started", index)
	await _settle(tree)

static func _settle(tree: SceneTree) -> void:
	for _frame: int in range(4):
		await tree.process_frame
	await tree.create_timer(0.22).timeout
	await tree.process_frame

static func _projected_hero(scene: Node) -> Dictionary:
	for entry: Dictionary in scene.get("_turn_order_all_entries"):
		if bool(entry.get("projected", false)) and str(entry.get("kind", "")) == "player":
			return entry
	return {}

static func _assert_state(scene: Node, expect: Callable, wait_time: int, pill: String, delta: int, before_keys: Array, after_key: String, phase: String) -> void:
	var strip: Control = scene.get("_turn_order_landing_strip") as Control
	var line: Label = scene.find_child("PassPreviewForecastLine", true, false) as Label
	var row: Control = scene.find_child("PassPreviewDamageRow", true, false) as Control
	expect.call(line != null and row != null, "%s: Pass forecast exists" % phase)
	if line == null or row == null:
		return
	expect.call(int(line.get_meta("pass_preview_wait_time", -1)) == wait_time and int(row.get_meta("pass_preview_wait_time", -1)) == wait_time, "%s: plate and row carry the exact Wait meta" % phase)
	expect.call(line.text.begins_with("+%d  •  " % wait_time if wait_time > 0 else "TURN END  •  "), "%s: plate lead is the Wait cost or TURN END: %s" % [phase, line.text])
	expect.call(line.content_width() <= row.size.x and is_equal_approx(line.get_global_rect().get_center().x, row.get_global_rect().get_center().x) and line.get_theme_font_size("font_size") == UiTypography.SIZE_SMALL, "%s: the full colored forecast with icon fits its centred line" % phase)
	expect.call(line.get_meta("pass_preview_values", []) == row.get_meta("pass_preview_values", []), "%s: forecast values meta is preserved" % phase)
	var icon: Texture2D = line.get("_time_icon") as Texture2D
	expect.call(icon == preload("res://scripts/action_icon_library.gd").icon_texture("time") if wait_time > 0 else icon == null, "%s: the existing Time icon appears only while Wait is pending" % phase)
	var cells: Array = line.get("_cells")
	if wait_time > 0:
		expect.call(cells[0].get("color") == UiPalette.GOLD_BRIGHT, "%s: Wait cost uses GOLD_BRIGHT" % phase)
	var values: Array = line.get_meta("pass_preview_values", [])
	for index: int in range(values.size()):
		expect.call(cells[2 + index * 2].get("color") == values[index].get("color"), "%s: forecast cell %d keeps its semantic color" % [phase, index])
	var tooltip: String = str(scene.call("_pass_preview_tooltip", scene.call("_pass_preview_summary")))
	if wait_time > 0:
		expect.call(tooltip.begins_with("Ending now leaves %d card %s unused: +%d Time." % [wait_time / 5, "play" if wait_time == 5 else "plays", wait_time]), "%s: Pass tooltip leads with exact unused plays and Wait" % phase)
	else:
		expect.call(not tooltip.begins_with("Ending now leaves"), "%s: no Wait tooltip when both plays were used" % phase)
	expect.call(is_equal_approx(float((scene.get("_settings") as Dictionary).get("ui_scale", 0)), 1.0) and scene.get_viewport().get_visible_rect().size == Vector2(SIZE), "%s: exactly 1920x1080 at 100%% scale: viewport %s, settings %s" % [phase, scene.get_viewport().get_visible_rect(), (scene.get("_settings") as Dictionary).get("ui_scale", 0)])
	if pill.is_empty():
		expect.call(not strip.visible, "%s: no landing strip without a card preview" % phase)
		return
	expect.call(strip.is_visible_in_tree(), "%s: card preview shows the landing strip" % phase)
	var entry: Dictionary = _projected_hero(scene)
	expect.call(int(entry.get("projected_time_delta", 99)) == delta, "%s: projected delta is exact" % phase)
	var badge: PanelContainer = null
	for slot: Node in (scene.get("_turn_order_bar") as Control).get_children():
		if bool(slot.get_meta("turn_order_projected", false)) and str(slot.get_meta("turn_order_projection_card_name", "")) == str(entry.get("projected_card_name", "")):
			badge = slot.find_child("ProjectionPreviewBadge", true, false) as PanelContainer
			break
	expect.call(badge != null, "%s: projected rail pill is present" % phase)
	if badge != null:
		var label: Label = badge.get_child(0) as Label
		var style: StyleBoxFlat = badge.get_theme_stylebox("panel") as StyleBoxFlat
		var expected_style: StyleBoxFlat = Ink.projection_style(delta)
		expect.call(label.text == pill and style.bg_color.is_equal_approx(expected_style.bg_color) and style.border_color.is_equal_approx(expected_style.border_color), "%s: exact pill copy and sign style: %s" % [phase, label.text])
		expect.call(label.get_theme_font_size("font_size") == 9 and label.get_theme_color("font_color") == Color("fff6ce") and label.get_theme_color("font_outline_color") == Color("120b07") and label.get_theme_constant("outline_size") == 1, "%s: pill typography stays unchanged" % phase)
	var roles: Dictionary = strip.role_entries()
	var keys: Array = []
	for before: Dictionary in roles.get("before", []):
		keys.append(Strip.actor_key(before))
	expect.call(keys == before_keys and Strip.actor_key(roles.get("hero", {})) == "player:player" and Strip.actor_key(roles.get("after", {})) == after_key, "%s: strip role order matches the rail: %s" % [phase, keys])
	expect.call((strip.find_child("LandingStripAgainLabel", true, false) != null) == before_keys.is_empty(), "%s: ACT AGAIN appears exactly when no actor acts first" % phase)
	var after: Control = strip.find_child("LandingStripAfter", true, false) as Control
	expect.call(after != null and after.modulate == Strip.DIM_AFTER, "%s: the next actor is dimmed" % phase)
	_assert_strip_art(strip, expect, phase)
	var stack: Control = scene.get("_card_focus_tooltip_stack") as Control
	expect.call(stack.visible, "%s: existing focus tooltip stack stays visible" % phase)
	expect.call(not stack.visible or not strip.get_global_rect().intersects(stack.get_global_rect()), "%s: strip never overlaps the tooltip stack" % phase)
	expect.call(scene.get_viewport().get_visible_rect().grow(-16).encloses(strip.get_global_rect()), "%s: strip stays within viewport gutters: %s" % [phase, strip.get_global_rect()])
	var index: int = int(scene.get("_selected_card_index")) if int(scene.get("_selected_card_index")) >= 0 else int(scene.get("_hovered_card_index"))
	var card: Control = scene.call("_hand_card_control", index)
	var card_rect: Rect2 = preload("res://scripts/card_focus_tooltip_stack.gd")._visual_global_rect(card)
	expect.call(is_equal_approx(strip.get_global_rect().end.y, card_rect.position.y - 4), "%s: strip ends 4px above the card frame" % phase)
	expect.call(strip.z_index < stack.z_index and strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: strip stays below tooltips and ignores the mouse" % phase)

static func _assert_strip_art(strip: Control, expect: Callable, phase: String) -> void:
	var slots: Array[Control]
	for child: Node in strip.get_children():
		if child is Control and child.has_meta("landing_strip_role"):
			slots.append(child as Control)
	for index: int in range(slots.size()):
		var slot: Control = slots[index]
		var numeral: Label = slot.get_node_or_null("LandingStripTimeNumeral") as Label
		expect.call(slot.size.is_equal_approx(Vector2(86, 64)) and numeral != null, "%s: %s keeps its 86x64 portrait and ETA: size %s, numeral %s" % [phase, slot.name, slot.size, numeral])
		if numeral == null:
			continue
		if index > 0:
			var previous: Control = slots[index - 1]
			expect.call(slot.position.x + numeral.position.x >= previous.position.x + previous.size.x, "%s: %s numeral clears the preceding portrait" % [phase, slot.name])
			if (slot.get_meta("landing_strip_role") == "before" and previous.get_meta("landing_strip_role") == "before") or (slot.get_meta("landing_strip_role") == "after" and not bool(strip.role_entries().get("act_again", false))):
				expect.call(is_equal_approx(slot.position.x - previous.position.x, 115.6), "%s: consecutive portraits step by 86px plus 29.6px numeral bleed" % phase)
		if slot.get_meta("landing_strip_role") == "after":
			expect.call(slot.modulate.is_equal_approx(Color(0.80, 0.77, 0.74, 0.52)) and numeral.get_theme_color("font_color") == UiPalette.TEXT and numeral.get_theme_font_size("font_size") == 17 and numeral.get_theme_constant("outline_size") == 3, "%s: the grey after-actor retains a legible ivory, outlined ETA at 0.52 opacity" % phase)
	var hero: Control = strip.get_node_or_null("LandingStripHero") as Control
	var chevron: Control = strip.get_node_or_null("LandingStripChevron") as Control
	expect.call(hero != null and chevron != null, "%s: hero and chevron exist" % phase)
	if hero == null or chevron == null:
		return
	var again: bool = bool(strip.role_entries().get("act_again", false))
	var label_width: float = 67.0 if again else (36.0 if strip.has_node("LandingStripOverflow") else 0.0)
	expect.call(is_equal_approx(strip.size.x, slots.size() * 115.6 + label_width + 20.0 + 8.0) and strip.size.y == 64.0, "%s: strip width includes every numeral bleed, the chevron gap and labels" % phase)
	var gap_start: float
	var gap_end: float
	if again:
		var label: Control = strip.get_node("LandingStripAgainLabel") as Control
		gap_start = label.position.x + label.size.x + 3.0
		var after: Control = strip.get_node_or_null("LandingStripAfter") as Control
		gap_end = after.position.x - Strip.LEFT_BLEED if after != null else strip.size.x - 8.0
	else:
		var overflow: Control = strip.get_node_or_null("LandingStripOverflow") as Control
		gap_start = overflow.position.x + overflow.size.x if overflow != null else slots[slots.find(hero) - 1].position.x + Strip.SLOT_SIZE.x
		gap_end = hero.position.x - Strip.LEFT_BLEED
	expect.call(is_equal_approx(gap_end - gap_start, 20.0) and is_equal_approx(chevron.position.x, gap_start + 6.0) and chevron.size.is_equal_approx(Vector2(8, 16)) and is_equal_approx(chevron.position.y, 24.0), "%s: the centred 16px chevron has its own 20px gap before the next numeral: gap %s..%s, rect %s" % [phase, gap_start, gap_end, chevron.get_rect()])
	expect.call(chevron.get_meta("chevron_color") == (UiPalette.GOLD_DIM if again else UiPalette.GOLD), "%s: chevron uses the appropriate gold" % phase)
	for slot: Control in slots:
		expect.call(chevron.z_index > (slot.get_node("LandingStripBrush") as Control).z_index, "%s: chevron draws above %s brush" % [phase, slot.name])
	var glow: TextureRect = strip.get_node_or_null("LandingStripAgainGlow") as TextureRect
	expect.call((glow != null) == again, "%s: the warm radial glow appears only for ACT AGAIN" % phase)
	if glow != null:
		var texture: GradientTexture2D = glow.texture as GradientTexture2D
		expect.call(glow.size == Vector2(150, 110) and (glow.position + glow.size * 0.5).is_equal_approx(hero.position + hero.size * 0.5), "%s: the 150x110 glow is centred on the hero portrait" % phase)
		expect.call(glow.z_index == (hero.get_node("LandingStripBrush") as Control).z_index and glow.get_index() < hero.get_index() and glow.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: glow draws behind the hero brush and ignores input" % phase)
		expect.call(texture != null and texture.fill == GradientTexture2D.FILL_RADIAL and texture.fill_from == Vector2(0.5, 0.5) and texture.fill_to == Vector2(1.0, 0.5), "%s: glow uses a centred radial GradientTexture2D" % phase)
		if texture != null:
			expect.call(texture.gradient.sample(0).is_equal_approx(Color(UiPalette.GOLD_BRIGHT, 0.40)) and is_equal_approx(texture.gradient.sample(0.5).a, 0.20) and is_zero_approx(texture.gradient.sample(1).a), "%s: glow falls smoothly from warm 0.40 alpha to transparent" % phase)

static func _assert_badge_tooltip(scene: Node, expect: Callable) -> void:
	var card: Control = scene.call("_hand_card_control", 1)
	var badge: Control = card.get("_time_badge") as Control
	expect.call(badge.tooltip_text == "Time\nDelays your next turn by 2. An unused play takes 5.", "The Time badge uses the exact requested copy")
	var modified: Dictionary = GameData.card_def("quick_stab").duplicate(true)
	modified["_quicken_discount"] = 1
	card.call("_refresh_time_badge", modified)
	expect.call(badge.tooltip_text.ends_with("\nQuickened: -1"), "The Time badge preserves modifier lines")
	card.call("_refresh_time_badge", GameData.card_def("quick_stab"))

static func _test_forecasts(scene: Node, expect: Callable) -> void:
	var summary: Dictionary = {"unrevealed_before_player": true, "hp_loss": 5, "entries": [{"name": "PassPreviewHpLoss", "text": "-5", "color": Color("f39779")}]}
	var entries: Array[Dictionary] = scene.call("_pass_preview_forecast_entries", summary)
	expect.call(entries.size() == 2 and str(entries.back().get("text", "")) == "+?" and entries.back().get("color") == Color("c89be3") and bool(entries.back().get("suffix", false)), "Known HP loss retains a violet, single-space suffix cell")
	summary["hp_loss"] = 0
	summary["entries"] = []
	entries = scene.call("_pass_preview_forecast_entries", summary)
	expect.call(entries.size() == 1 and str(entries[0].get("text", "")) == "UNKNOWN", "An unrevealed lap without known losses stays UNKNOWN")
	summary["hp_loss"] = 5
	summary["umbra_unknown_before_player"] = true
	entries = scene.call("_pass_preview_forecast_entries", summary)
	expect.call(entries.size() == 1 and str(entries[0].get("text", "")) == "UNKNOWN", "Umbra unknown retains its existing precedence")
	summary["defeat"] = true
	entries = scene.call("_pass_preview_forecast_entries", summary)
	expect.call(entries.size() == 1 and str(entries[0].get("text", "")) == "DEFEAT", "DEFEAT retains its existing precedence")

static func _test_preview_visibility(tree: SceneTree, scene: Node, engine: CombatEngine, expect: Callable) -> void:
	await _install(tree, scene, fixture(engine))
	await _hover(tree, scene, 1)
	var strip: Control = scene.get("_turn_order_landing_strip") as Control
	var rebuilds: int = int(strip.get_meta("rebuild_count", 0))
	scene.call("_refresh_turn_order_bar")
	await tree.process_frame
	expect.call(int(strip.get_meta("rebuild_count", 0)) == rebuilds, "Unchanged content never rebuilds the strip")
	var preview: Dictionary = scene.call("_card_preview_for_index", 1)
	await scene.call("_begin_card_preview", 1, preview)
	await _settle(tree)
	expect.call(int(scene.get("_selected_card_index")) == 1 and strip.visible, "Click-select keeps the same card strip visible")
	var selected_line: Label = scene.find_child("PassPreviewForecastLine", true, false) as Label
	scene.call("_refresh_selected_card_forecast")
	expect.call(int(selected_line.get_meta("pass_preview_wait_time", -1)) == engine.pending_wait_time(scene.call("_pass_preview_source_state")), "Selected-card refresh updates Wait meta using the forecast source state")
	for property: String in ["_drag_card_index", "_animation_lock"]:
		scene.set(property, 1 if property == "_drag_card_index" else true)
		scene.call("_refresh_turn_order_bar")
		await tree.process_frame
		expect.call(not strip.visible, "Strip hides during %s" % property)
		scene.set(property, -1 if property == "_drag_card_index" else false)
		scene.call("_refresh_turn_order_bar")
		expect.call(strip.visible, "Strip returns after %s clears" % property)
	var card: Control = scene.call("_hand_card_control", 1)
	card.visible = false
	scene.call("_refresh_turn_order_bar")
	expect.call(not strip.visible, "Strip hides when its hand control is invisible")
	card.visible = true
	var combat: Dictionary = scene.get("_combat_state")
	combat["current_actor"] = {"kind": "enemy", "actor_key": "enemy_1"}
	scene.call("_refresh_turn_order_bar")
	expect.call(not strip.visible, "Strip hides outside the player's turn")
	# Test construction beyond the rail's visible slots, including Unknown Presence.
	var target := Control.new()
	target.position = Vector2(850, 650)
	target.size = Vector2(250, 352)
	scene.get_viewport().add_child(target)
	var mini := Strip.new()
	scene.get_viewport().add_child(mini)
	var entries: Array[Dictionary]
	entries.append({"kind": "player", "actor_key": "player", "active": true})
	for index: int in range(6):
		entries.append({"kind": "enemy", "actor_key": "enemy_%d" % index, "team": "enemy", "eta": index + 1, "hidden_by_umbra": index == 0})
	entries.append({"kind": "player", "actor_key": "player", "team": "player", "projected": true, "eta": 9})
	entries.append({"kind": "enemy", "actor_key": "after", "eta": 10})
	mini.present(entries, 0, target, null, Callable(scene, "_turn_order_portrait_path"), Callable(), true)
	expect.call(mini.get_node("LandingStripOverflow").text == "+2" and mini.has_node("LandingStripSlot_3") and not mini.has_node("LandingStripSlot_4"), "Overflow renders the first four before-slots then +N")
	var unknown: TextureRect = mini.get_node("LandingStripSlot_0/LandingStripPortraitCrop/LandingStripPortrait")
	expect.call(unknown.texture == preload("res://scripts/asset_loader.gd").load_texture("res://assets/art/icons/umbra_presence.png") and (mini.get_node("LandingStripSlot_0/LandingStripBrush") as TextureRect).modulate == Ink.ink_color("enemy", false, false), "Umbra-hidden actors render the rail's Unknown Presence portrait and enemy ink")
	var mini_brush: TextureRect = mini.get_node("LandingStripSlot_0/LandingStripBrush")
	var expected_rect: Rect2 = Ink.brush_rect(Strip.SLOT_SIZE / Strip.MINI_SCALE, mini_brush.texture)
	expect.call(mini_brush.position.is_equal_approx(expected_rect.position * Strip.MINI_SCALE) and mini_brush.size.is_equal_approx(expected_rect.size * Strip.MINI_SCALE) and is_equal_approx(mini_brush.rotation_degrees, Ink.brush_tilt_degrees("enemy:enemy_0", false)) and mini_brush.flip_h == Ink.brush_flipped("enemy:enemy_0", false), "Mini stroke reuses rail geometry, actor key, tilt and mirroring at 0.74 scale")
	expect.call((mini.get_node("LandingStripSlot_0") as Control).size == Vector2(86, 64) and is_equal_approx((mini.get_node("LandingStripSlot_1") as Control).position.x - (mini.get_node("LandingStripSlot_0") as Control).position.x, 115.6), "Consecutive mini slots are 86x64 with a 115.6px step that reserves the numeral bleed")
	_assert_strip_art(mini, expect, "overflow")
	mini.hide_strip()
	mini.present(entries, 0, target, null, Callable(scene, "_turn_order_portrait_path"), Callable(), false)
	expect.call(is_zero_approx(mini.modulate.a), "Normal-motion strip starts its fade transparent")
	await tree.create_timer(0.13).timeout
	await tree.process_frame
	expect.call(is_equal_approx(mini.modulate.a, 1.0), "Normal-motion strip completes its 0.12s fade")
	mini.queue_free()
	target.queue_free()
	await tree.process_frame

static func _capture(viewport: SubViewport, expect: Callable, capture_dir: String, name: String) -> void:
	if capture_dir.is_empty():
		return
	expect.call(DisplayServer.get_name() != "headless", "%s capture requires the real renderer" % name)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	expect.call(image != null, "%s capture has a rendered image" % name)
	if image == null:
		return
	expect.call(image.get_size() == SIZE, "%s capture is exactly 1920x1080 without resizing" % name)
	if image.get_size() != SIZE:
		return
	var path: String = "%s/%s.png" % [capture_dir, name]
	expect.call(image.save_png(path) == OK, "Save capture %s" % path)
	print("TURN CLOCK HUD CAPTURE: %s" % path)
