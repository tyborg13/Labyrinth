extends "res://tests/pre_battle_fixture.gd"

func _initialize() -> void:
	_setup()
	await _run_layout_proof()
	await _run_input_proof()
	_viewport.queue_free()
	await process_frame
	print("PRE-BATTLE VIEW TEST: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _run_layout_proof() -> void:
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	var coord: Vector2i = _first_available_combat_coord(engine, state)
	state = _pre_battle_state_for_room(engine, state, coord)
	var instance: Node = await _instance(state)
	var preview: Dictionary = instance.get("_pre_battle_preview_run_state")
	var enemies: Array = []
	for type: String in ["grave_surgeon", "chainbound_gaoler", "frostglass_lancer", "warden", "harrier", "crawler"]:
		var definition: Dictionary = GameData.enemy_def(type)
		if definition.is_empty():
			type = "warden"
			definition = GameData.enemy_def(type)
		enemies.append({"type": type, "hp": int(definition.get("max_hp", 1)), "max_hp": int(definition.get("max_hp", 1)), "id": enemies.size() + 1})
	for count: int in [1, 2, 3, 5, 6]:
		var sized: Dictionary = preview.duplicate(true)
		sized["combat_state"]["enemies"] = enemies.slice(0, count)
		instance.set("_pre_battle_preview_run_state", sized)
		instance.call("_rebuild_pre_battle_overlay")
		await _settle()
		var panel := instance.get("_pre_battle_panel") as Control
		_assert_pre_battle_body_inside_panel(panel, "%d foes" % count)
		_assert_foe_fit(panel, count)
		_assert_cards(panel, state["deck_cards"], "deck")
		_assert_cards(panel, state["attuned_magic_cards"], "attuned")
		print("Pre-battle layout %d foes panel=%s" % [count, panel.size])
		await _layout_capture(instance, "%02d_foes" % count)
	var elemental: Dictionary = preview.duplicate(true)
	elemental["combat_state"]["room_element"] = "fire"
	elemental["combat_state"]["room_name"] = "Cindered Hall"
	elemental["combat_state"]["umbra"] = {"stage": "fringe"}
	instance.set("_pre_battle_preview_run_state", elemental)
	instance.call("_rebuild_pre_battle_overlay")
	await _settle()
	var elemental_panel := instance.get("_pre_battle_panel") as Control
	_assert_pre_battle_body_inside_panel(elemental_panel, "elemental Umbra")
	var room_title := elemental_panel.find_child("PreBattleRoomTitle", true, false) as Label
	var umbra := elemental_panel.find_child("PreBattleUmbraLabel", true, false) as Label
	_expect(room_title.get_theme_color("font_color") == Palette.GOLD_BRIGHT and umbra.get_theme_color("font_color") == Palette.UMBRA, "Element room title stays gold and Umbra stays violet")
	var diamond := elemental_panel.find_child("PreBattleDepthOrnament", true, false) as Label
	_expect(diamond.get_theme_color("font_color") == preload("res://scripts/element_data.gd").accent("fire"), "Element accent belongs only on the eyebrow diamond")
	await _layout_capture(instance, "elemental_umbra")
	elemental["combat_state"].erase("umbra")
	instance.set("_pre_battle_preview_run_state", elemental)
	instance.call("_rebuild_pre_battle_overlay")
	await _settle()
	_expect(elemental_panel.find_child("PreBattleDepthOrnament", true, false) == null and elemental_panel.find_child("PreBattleUmbraLabel", true, false) == null, "Without an Umbra tier the eyebrow shows only depth")
	var leader_roster: Dictionary = preview.duplicate(true)
	var marked: Array = enemies.duplicate(true)
	marked[0]["is_leader"] = true
	leader_roster["combat_state"]["enemies"] = marked
	leader_roster["combat_state"]["objective"] = {"type": "kill_leader", "leader_id": marked[0]["id"]}
	instance.set("_pre_battle_preview_run_state", leader_roster)
	instance.call("_rebuild_pre_battle_overlay")
	await _settle()
	var leader_panel := instance.get("_pre_battle_panel") as Control
	_assert_pre_battle_body_inside_panel(leader_panel, "six foes with leader")
	_assert_foe_fit(leader_panel, 6)
	var leader_flow := leader_panel.find_child("PreBattleEnemyFlow", true, false) as Control
	var center_foe := leader_flow.get_child(1) as Control
	_expect(bool(center_foe.get_meta("is_leader", false)) and absf(center_foe.get_global_rect().get_center().x - leader_flow.get_global_rect().get_center().x) < 1.0, "Leader belongs in the center slot")
	await _layout_capture(instance, "six_foes_leader")
	var boss: Dictionary = engine.create_debug_boss_run(ProgressionStore.default_data())
	boss["mode"] = RunEngine.MODE_PRE_BATTLE
	boss["combat_state"] = {}
	boss["pre_battle_pending"] = true
	boss["pre_battle_travel_dir"] = _travel_dir_for_coord(boss.get("current_room", INVALID_COORD))
	instance.call("_load_run_state", boss)
	instance.call("_show_pre_battle_preview")
	await _settle()
	var panel := instance.get("_pre_battle_panel") as Control
	_assert_pre_battle_body_inside_panel(panel, "boss")
	var leader := panel.find_child("PreBattleLeaderLabel", true, false) as Label
	_expect(leader != null, "Boss must be marked LEADER")
	var objective: Dictionary = instance.get("_pre_battle_preview_run_state")["combat_state"]["objective"]
	var plate := panel.find_child("PreBattleObjectiveChip", true, false) as Control
	_expect(str(plate.get_meta("objective_title")) == preload("res://scripts/combat_objective_rules.gd").title_for_objective(objective), "Boss name must preserve the live objective title")
	await _layout_capture(instance, "boss")
	instance.queue_free()
	await process_frame

func _layout_capture(_instance: Node, _name: String) -> void:
	pass

func _run_input_proof() -> void:
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	var coord: Vector2i = _first_available_combat_coord(engine, state)
	var progression: Dictionary = state["progression"].duplicate(true)
	progression["level"] = 5
	progression["skill_ids"] = ["ghost_stride", "sure_footed", "discerning_eye", "true_bearing"]
	state["progression"] = progression
	state = _pre_battle_state_for_room(engine, state, coord)
	var instance: Node = await _instance(state)
	var panel := instance.get("_pre_battle_panel") as Control
	_expect(panel.find_child("TrueBearingButton", true, false) != null, "Position action must remain present")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var foe := panel.find_child("PreBattleEnemyCard", true, false) as Control
	await _click(foe)
	await _settle()
	var pinned := instance.get("_pinned_tooltip_panel") as Control
	_expect(pinned != null and str(pinned.get_meta("inspection_kind", "")) == "enemy", "Foe pointer press opens known moves")
	if pinned != null:
		var close := pinned.find_child("PreBattleInspectionCloseButton", true, false) as Button
		_expect(close != null, "Known moves exposes close socket")
		var glyph := close.get_node("PreBattleCloseGlyph") as Label
		_expect(glyph.is_visible_in_tree() and glyph.text == "✕" and glyph.get_theme_font_size("font_size") == 18, "Close socket must visibly show the UI18 cross")
		_expect(glyph.get_theme_color("font_color") == Palette.TEXT_2, "Close glyph uses TEXT_2 at rest")
		await _pointer(close.get_global_rect().get_center())
		_expect(glyph.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Close glyph turns GOLD_BRIGHT on hover")
		await _click(close)
		await _settle()
		_expect(not (instance.get("_pinned_tooltip_scrim") as Control).visible, "Close socket dismisses known moves")
	for node_name: String in ["PreBattleEquipmentChip", "PreBattleAttunedBadge", "PreBattleDeckBadge"]:
		var source := panel.find_child(node_name, true, false) as Control
		var tooltip := source.call("_make_custom_tooltip", source.tooltip_text) as Control
		_expect(tooltip != null, "Equipment and card hover inspection remains available")
		if tooltip != null:
			tooltip.free()
		await _click(source)
		await process_frame
		_expect((instance.get("_pinned_tooltip_scrim") as Control).visible, "Equipment and card click inspection remains available")
		instance.call("_close_pinned_tooltip")
		await process_frame
	router.call("set_forced_state_for_test", "controller", "xbox")
	_expect(not (panel.find_child("PreBattleFoeHint", true, false) as Control).visible, "Pointer hint hides for controller")
	await _settle()
	_assert_foe_fit(panel, (panel.find_child("PreBattleEnemyFlow", true, false) as Control).get_child_count())
	var start := panel.find_child("PreBattleStartButton", true, false) as Button
	start.grab_focus()
	await _joy(JOY_BUTTON_DPAD_LEFT)
	_expect(_viewport.gui_get_focus_owner() == panel.find_child("PreBattleEquipButton", true, false), "Controller Left traverses Start to Equip")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_expect((instance.get("_upgrade_scrim") as Control).visible, "Controller A activates Equip")
	await _joy(JOY_BUTTON_B)
	await _settle()
	_expect(not (instance.get("_upgrade_scrim") as Control).visible and (instance.get("_pre_battle_scrim") as Control).visible, "Controller Back returns to pre-battle")
	panel = instance.get("_pre_battle_panel") as Control
	var strip := panel.find_child("PreBattleDeckBadge", true, false) as Button
	strip.grab_focus()
	await _joy(JOY_BUTTON_A)
	await process_frame
	_expect((instance.get("_pinned_tooltip_scrim") as Control).visible, "Controller A activates card strip inspection")
	instance.call("_close_pinned_tooltip")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	instance.call("_on_settings_changed", settings)
	instance.call("_close_pre_battle_preview")
	instance.call("_show_pre_battle_preview")
	await _settle()
	_expect(instance.get("_pre_battle_entry_tween") == null and panel.scale == Vector2.ONE, "Reduced motion leaves the entry static")
	start = panel.find_child("PreBattleStartButton", true, false) as Button
	start.grab_focus()
	await _key(KEY_ENTER)
	await _settle()
	_expect(str(instance.get("_run_state")["mode"]) == "combat", "Keyboard Enter starts the same combat state")
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
