extends "res://tests/combat_hud_badges_test.gd"

const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const TooltipButton = preload("res://scripts/ui_tooltip_button.gd")

var _header_instance: Node

func _run() -> void:
	await _exercise_source("res://scenes/run_scene.tscn")
	_finish()

func _exercise_source(scene_path: String) -> void:
	Settings.set_storage_path("user://combat_hud_buttons_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://combat_hud_buttons_profile.json")
	Store.set_run_storage_path("user://combat_hud_buttons_run.save")
	Store.clear_saved_run()
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(profile)
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "HUD scene must load")
	if packed == null:
		return
	_header_instance = packed.instantiate()
	_expect(_header_instance.has_method("_load_run_state"), "HUD fixture must load its complete run script")
	if not _header_instance.has_method("_load_run_state"):
		_header_instance.free()
		_viewport.queue_free()
		await process_frame
		return
	_viewport.add_child(_header_instance)
	await _settle()
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var engine := Run.new()
	var room: Dictionary = engine.create_new_run(123, profile)
	var coord := Vector2i(-999, -999)
	for candidate: Vector2i in engine.available_moves(room):
		if str(engine.room_metadata(room, candidate).get("type", "")) == "combat":
			coord = candidate
			break
	_expect(coord != Vector2i(-999, -999), "HUD fixture must offer a real combat room")
	var normal: Dictionary = engine.begin_pre_battle_combat(engine.move_to_pre_battle(room, coord))
	await _load(_header_instance, normal)
	await _pointer(Vector2(960, 500))
	_assert_header()
	await _capture("01_normal_combat")
	var grimoire := _header_instance.get("grimoire_button") as Button
	_expect((_header_instance.get("_grimoire_badge") as Control).visible, "Notification proof must include a live grimoire unread badge before inspection")
	await _pointer(grimoire.get_global_rect().get_center())
	_expect(_viewport.gui_get_hovered_control() == grimoire, "Native grimoire button receives hover through its notification badge")
	await _settle()
	await _capture("02_notification_dot")
	await _pointer(Vector2(960, 500))
	grimoire.grab_focus()
	await _settle()
	_expect(grimoire.has_focus(), "Top-right buttons retain keyboard focus")
	await _capture("03_keyboard_focus")
	await _key(KEY_ENTER)
	_expect((_header_instance.get("_grimoire_scrim") as Control).visible, "Enter opens the grimoire")
	await _key(KEY_ESCAPE)
	await _settle()
	_expect(not (_header_instance.get("_grimoire_scrim") as Control).visible and grimoire.has_focus(), "Escape closes grimoire and returns button focus")
	await _click(grimoire)
	_expect((_header_instance.get("_grimoire_scrim") as Control).visible, "Pointer opens the grimoire")
	await _key(KEY_ESCAPE)
	await _settle()
	router.call("set_forced_state_for_test", "controller", "xbox")
	_header_instance.call("_controller_enter_board", false)
	_header_instance.call("_controller_set_focus_candidate", _header_instance.call("_controller_candidate_for_control", grimoire), true)
	await _settle()
	_expect(grimoire.has_focus(), "Top-right buttons retain controller focus")
	var open_prompt: bool = false
	for prompt: Dictionary in (_header_instance.get("_controller_prompt_bar") as Node).call("prompts_snapshot"):
		if str(prompt.get("action", "")) == str(InputRouter.ACTION_ACCEPT) and str(prompt.get("label", "")) == "Open":
			open_prompt = true
	_expect(open_prompt, "Focused top-right button retains its controller A Open prompt")
	await _capture("04_controller_focus")
	await _joy(JOY_BUTTON_A)
	_expect((_header_instance.get("_grimoire_scrim") as Control).visible, "Controller A opens the focused grimoire")
	await _joy(JOY_BUTTON_B)
	await _settle()
	_expect(not (_header_instance.get("_grimoire_scrim") as Control).visible, "Controller B returns from grimoire")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var options := {"dragon_id": "zekarion", "dragon_depth": 20, "relics": "iron_lung,ember_lens,pilgrim_boots,mirror_shard,phoenix_ember,winters_hour,stormroad_coil"}
	var boss_profile: Dictionary = profile.duplicate(true)
	boss_profile["level"] = 5
	var boss: Dictionary = BossFactory.build(engine, Combat.new(), engine.create_new_run(BossFactory.seed_for_options(options), boss_profile), options)
	boss["relics"] = ["iron_lung", "ember_lens", "pilgrim_boots", "mirror_shard", "phoenix_ember", "winters_hour", "stormroad_coil"]
	boss["combat_state"]["relics"] = boss["relics"].duplicate()
	boss["combat_state"]["relic_time_reserve"] = {"winters_hour": 2}
	await _load(_header_instance, boss)
	await _pointer(Vector2(960, 500))
	var focused: Control = _viewport.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	_expect((_header_instance.get("_boss_health_overlay") as Control).is_visible_in_tree(), "Boss HUD proof must include the live boss bar")
	_expect((_header_instance.get("_relic_icon_grid") as Control).get_child_count() == 7, "Boss HUD proof must contain seven relics")
	_assert_header()
	await _capture("05_boss_combat_relics")
	await _load(_header_instance, room)
	_expect((_header_instance.get("_large_map_scrim") as Control).visible, "Room entry preserves automatic section-map presentation")
	await _key(KEY_ESCAPE)
	await _settle()
	var map_button := _header_instance.get("_section_map_hud_button") as Button
	_expect(map_button.is_visible_in_tree(), "Room HUD retains the section map button")
	_assert_header()
	await _pointer(Vector2(960, 500))
	await _capture("06_section_map_button")
	await _click(map_button)
	_expect((_header_instance.get("_large_map_scrim") as Control).visible, "Pointer opens section map")
	await _key(KEY_ESCAPE)
	await _settle()
	_expect(not (_header_instance.get("_large_map_scrim") as Control).visible and map_button.has_focus(), "Map back returns focus to its button")
	await _key(KEY_M)
	_expect((_header_instance.get("_large_map_scrim") as Control).visible, "M still opens section map")
	await _key(KEY_M)
	_expect(not (_header_instance.get("_large_map_scrim") as Control).visible, "M still closes section map")
	await _click(_header_instance.get("loadout_button") as Button)
	_expect((_header_instance.get("_upgrade_scrim") as Control).visible, "Pointer opens character loadout")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_expect((_header_instance.get("_menu_scrim") as Control).visible, "Escape retains the menu hotkey")
	await _key(KEY_ESCAPE)
	_expect(not (_header_instance.get("_menu_scrim") as Control).visible, "Escape closes menu")
	router.call("clear_forced_state_for_test")
	_header_instance.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame

func _assert_header() -> void:
	var stats := _header_instance.get("stats_label") as Label
	var profile: Dictionary = (_header_instance.get("_run_state") as Dictionary).get("progression", {})
	_expect(stats.text == "LV %d  EMBERS %d" % [int(profile.get("level", 1)), int(_header_instance.call("_displayed_ember_count"))], "StatsLabel retains master's exact live level and ember text")
	_expect(stats.get_child_count() == 0 and stats.get_theme_font("font") == Typography.ui_font() and stats.get_theme_font_size("font_size") == Typography.SIZE_SECTION - 1, "StatsLabel uses master's original single-line typography")
	_expect(stats.get_theme_color("font_color") == Palette.GOLD_BRIGHT and stats.get_theme_color("font_outline_color") == Palette.TEXT_OUTLINE and stats.get_theme_constant("outline_size") == 3, "StatsLabel restores master's gold and outline styling")
	var previous: Control = stats
	for key: String in ["_section_map_hud_button", "loadout_button", "grimoire_button", "menu_button"]:
		var button := _header_instance.get(key) as Button
		_expect(button is TooltipButton and button.icon != null and button.expand_icon and button.text.is_empty(), "Header actions use master's native icon buttons")
		_expect(button.custom_minimum_size == Vector2(68, 56) and button.size == Vector2(68, 56) and button.focus_mode == Control.FOCUS_ALL, "Header actions restore master's 68x56 size and native focus")
		_expect(str(button.get_meta("button_variant", "")) == UiSkin.VARIANT_ICON and bool(button.get_meta("ui_button_feedback_bound", false)), "Header actions retain UiSkin's icon variant and audio feedback")
		_expect(button.get_node_or_null("HotkeyHint") == null and button.get_node_or_null("Ring") == null, "Restored header actions have no socket or keycap presentation")
		_expect(button.get_theme_color("icon_normal_color") == Color("f7dfad") and button.get_theme_color("icon_hover_color") == Color("fff0c8") and button.get_theme_color("icon_pressed_color") == Color("e8b968") and button.get_theme_color("icon_disabled_color") == Color("8f7a5a"), "Header icons retain master's state tints")
		if button.is_visible_in_tree():
			_expect(absf(button.global_position.x - previous.get_global_rect().end.x - 8.0) < 1.0, "Header actions retain master's order and eight-pixel spacing")
			_expect(Rect2(Vector2.ZERO, Vector2(SIZE)).encloses(button.get_global_rect()), "Header actions remain inside the viewport")
			previous = button
	_expect((_header_instance.get("loadout_button") as Button).tooltip_text == "Character Loadout" and (_header_instance.get("grimoire_button") as Button).tooltip_text == "Grimoire" and (_header_instance.get("menu_button") as Button).tooltip_text == "Menu" and (_header_instance.get("_section_map_hud_button") as Button).tooltip_text == "Map [M]", "Header actions retain exact tooltips and map binding")
	for key: String in ["_grimoire_badge", "_loadout_badge"]:
		var badge := _header_instance.get(key) as PanelContainer
		_expect(badge != null and badge.custom_minimum_size == Vector2(18, 18) and badge.offset_left == -18.0 and badge.offset_top == -3.0 and badge.offset_right == 0.0 and badge.offset_bottom == 15.0, "Notification badges retain master's exact size and offsets")

func _finish() -> void:
	print("COMBAT HUD BUTTONS TEST: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
