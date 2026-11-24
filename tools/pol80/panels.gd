extends RefCounted

const Backdrop = preload("res://scripts/large_map_backdrop.gd")
const Events = preload("res://tests/suites/event_view_suite.gd")
const MID_FADE_FRACTION := 0.5
const TIMING_TOLERANCE := 0.08
const EVENT_ID := "weeping_statue"

static func run(t) -> bool:
	if not await t.resume(t.new_run()): return false
	var scene: Control = t.scene
	await t.settle(Backdrop.FADE_SECONDS)
	t.root.get_node("InputRouter").set_forced_state_for_test("pointer", "xbox")
	scene._close_large_map()
	await t.settle()

	scene._on_menu_button_pressed()
	# Submit the normal waypoint board while the run menu is active, as in the
	# candidate capture. With board-door navigation active the title is absent.
	scene._refresh_stage_view()
	if not t.check(scene.board_view.status_label == "Choose Door", "Expected the centred waypoint title under the run menu"): return false
	if not await sample(t, "Camp", scene._menu_dialog): return false
	if not t.press_text(scene._menu_dialog, "Settings"): return false
	if not await sample(t, "Settings", scene._settings_panel): return false
	scene._close_settings_overlay()
	scene._close_menu_overlay()
	if not await sample(t, "Camp and Settings closed"): return false

	scene._on_menu_button_pressed()
	if not t.press_text(scene._menu_dialog, "Character"): return false
	await t.settle(Backdrop.FADE_SECONDS * MID_FADE_FRACTION)
	if not await sample(t, "Character opening midpoint", scene._upgrade_dialog, true): return false
	if not await t.capture("character_mid_fade"): return false
	if not await sample(t, "Character Gear", scene._upgrade_dialog): return false
	if not await t.capture("character_gear"): return false
	var magic := scene._upgrade_dialog.find_child("CharacterMagicTab", true, false) as Button
	if not t.check(magic != null, "Expected the native Magic tab"): return false
	magic.grab_focus()
	if not t.check(t.viewport.gui_get_focus_owner() == magic, "Expected keyboard focus on Magic"): return false
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	tap(t.viewport, enter)
	await t.settle()
	if not t.check(scene._progression_overlay_mode == "magic", "Enter did not activate Magic"): return false
	if not await sample(t, "Character Magic", scene._upgrade_dialog): return false
	if not await t.capture("character_magic"): return false

	var next_tab := InputEventJoypadButton.new()
	next_tab.button_index = JOY_BUTTON_RIGHT_SHOULDER
	tap(t.viewport, next_tab)
	await t.settle()
	if not t.check(scene._progression_overlay_mode == "skills", "Controller shoulder did not activate Skills"): return false
	if not await sample(t, "Character Skills", scene._upgrade_dialog): return false
	if not await t.capture("character_skills"): return false
	print("POL-80 CHARACTER INPUT: PASS (keyboard focus and Enter, controller shoulder)")
	scene._close_card_upgrade_overlay()
	await t.settle(Backdrop.FADE_SECONDS * MID_FADE_FRACTION)
	if not await sample(t, "Character closing midpoint", null, true): return false
	if not await sample(t, "Character closed"): return false
	if not await t.capture("character_closed"): return false

	scene._on_grimoire_button_pressed()
	scene._refresh_stage_view()
	if not await sample(t, "Grimoire", scene._grimoire_scrim._grimoire_dialog): return false
	scene._close_grimoire_overlay()
	if not await sample(t, "Grimoire closed"): return false
	for kind: String in ["draw", "discard"]:
		scene._open_pile_view(kind)
		scene._refresh_stage_view()
		if not await sample(t, kind.capitalize() + " pile", scene._pile_dialog): return false
		scene._close_pile_view()
		if not await sample(t, kind.capitalize() + " pile closed"): return false

	scene._open_large_map()
	scene._refresh_stage_view()
	if not await sample(t, "Large map", scene._large_map_scrim): return false
	scene._close_large_map()
	if not await sample(t, "Large map closed"): return false

	scene._settings["reduced_motion"] = true
	scene._on_loadout_button_pressed()
	scene._refresh_stage_view()
	await t.settle(Backdrop.REDUCED_FADE_SECONDS * MID_FADE_FRACTION)
	if not await sample(t, "Character reduced motion midpoint", scene._upgrade_dialog, true): return false
	if not await sample(t, "Character reduced motion", scene._upgrade_dialog): return false
	scene._close_card_upgrade_overlay()
	if not await sample(t, "Character reduced motion closed"): return false

	if not await t.resume(t.run_fixture("scavenger")): return false
	scene = t.scene
	if not await sample(t, "Scavenger", scene._scavenger_shop_view._canvas): return false
	scene._on_merchant_hide_pressed()
	if not await sample(t, "Scavenger closed"): return false

	if not await t.resume(Events.fixture(EVENT_ID, false, t.new_run())): return false
	scene = t.scene
	if not await sample(t, "Event", scene._event_view.panel): return false
	scene._event_view.dismiss()
	if not await t.wait_for(func() -> bool: return not scene._event_view.visible): return false
	return await sample(t, "Event closed")

static func tap(viewport: Viewport, event: InputEvent) -> void:
	event.pressed = true
	viewport.push_input(event, true)
	event.pressed = false
	viewport.push_input(event, true)

static func sample(t, id: String, panel: Control = null, midpoint: bool = false) -> bool:
	if not midpoint: await t.settle(Backdrop.FADE_SECONDS + TIMING_TOLERANCE)
	var scene: Control = t.scene
	var board: Control = scene.board_view
	var painter: Control = board._effects_render_layer
	var title: Rect2 = painter.get_global_transform_with_canvas() * (painter.get_meta("pol80_painted_title", Rect2()) as Rect2) if t.before else board.status_title_screen_rect()
	var bounds: Rect2 = panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, panel.size) if panel != null else Rect2()
	var intersects: bool = title.has_area() and bounds.intersects(title)
	var board_alpha: float = board.get_status_title_alpha() if board.has_method("get_status_title_alpha") else 1.0
	var header_alpha: float = scene.room_title.self_modulate.a
	var row: Dictionary = {"panel": id, "panel_rect": str(bounds), "title_rect": str(title),
		"title": board.status_label, "intersects": intersects, "board_title_alpha": board_alpha, "header_alpha": header_alpha}
	if panel != null and id.begins_with("Character"):
		row["scrim_rect"] = str(scene._upgrade_scrim.get_global_rect())
	t.panel_rows.append(row)
	print("POL-80 PANEL " + JSON.stringify(row))
	if panel != null and not t.check(t.shown(panel) and bounds.has_area(), "Expected visible panel: " + id): return false
	if id.begins_with("Large map") and not t.check(is_equal_approx(header_alpha, 0.0 if panel != null else 1.0), "Large-map header opacity changed"): return false
	if t.before: return t.check(is_equal_approx(board_alpha, 1.0), "Expected candidate placard opacity")
	if midpoint:
		return t.check(board_alpha > 0.0 and board_alpha < 1.0, "Expected intermediate title opacity: " + id)
	var fades: bool = (intersects and id != "Large map") or (panel != null and id.begins_with("Character"))
	return t.check(is_equal_approx(board_alpha, 0.0 if fades else 1.0), "Unexpected centred title opacity: " + id)
