extends "res://tests/pre_battle_view_test.gd"

const OUTPUT_DIR: String = "user://probes/pre_battle_vp4_preview"

func _initialize() -> void:
	_setup()
	await _run_layout_proof()
	await _run_input_proof()
	await _visual_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("PRE-BATTLE PREVIEW PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _layout_capture(_instance: Node, name: String) -> void:
	await _capture("%s/%s.png" % [OUTPUT_DIR, name])

func _visual_states() -> void:
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
	_assert_pre_battle_body_inside_panel(panel, "true bearing")
	await _capture("%s/true_bearing_header.png" % OUTPUT_DIR)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var start := panel.find_child("PreBattleStartButton", true, false) as Button
	await _pointer(start.get_global_rect().get_center())
	_expect(_viewport.gui_get_hovered_control() == start, "Start hover must use actual pointer routing")
	await _capture("%s/start_hover.png" % OUTPUT_DIR)
	await _pointer(Vector2(80, 80))
	router.call("set_forced_state_for_test", "controller", "xbox")
	start.grab_focus()
	await process_frame
	_expect(start.has_focus(), "Start must retain visible keyboard/controller focus")
	await _capture("%s/start_focus.png" % OUTPUT_DIR)
	router.call("set_forced_state_for_test", "pointer", "xbox")
	start.release_focus()
	var foe := panel.find_child("PreBattleEnemyCard", true, false) as Control
	await _click(foe)
	await _settle()
	var pinned := instance.get("_pinned_tooltip_panel") as Control
	_expect(pinned != null and pinned.find_child("PreBattleKnownMoves", true, false) != null, "Known moves should expand")
	if pinned != null:
		var move_icons := PackedStringArray()
		for icon_node: Node in pinned.find_children("PreBattleKnownMoveIcon", "TextureRect", true, false):
			move_icons.append(str(icon_node.get_meta("icon_key", "")))
		# Retain this known master failure; the visual unit does not alter move semantics.
		if move_icons != PackedStringArray(["melee", "block", "aoe"]):
			_fail("Compound Warden moves should use melee/block/aoe semantics instead of their incidental movement icons: %s" % str(move_icons))
	await _capture("%s/known_moves.png" % OUTPUT_DIR)
	instance.call("_close_pinned_tooltip")
	var preview: Dictionary = instance.get("_pre_battle_preview_run_state").duplicate(true)
	preview["combat_state"]["room_name"] = "Cindered Hall"
	preview["combat_state"]["room_element"] = "fire"
	preview["combat_state"]["umbra"] = {"stage": "fringe"}
	instance.set("_pre_battle_preview_run_state", preview)
	instance.call("_rebuild_pre_battle_overlay")
	await _settle()
	var title := panel.find_child("PreBattleRoomTitle", true, false) as Label
	var umbra := panel.find_child("PreBattleUmbraLabel", true, false) as Label
	_expect(title.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Elemental room title must stay gold")
	_expect(umbra != null and umbra.get_theme_color("font_color") == Palette.UMBRA, "Umbra eyebrow must stay violet")
	await _capture("%s/elemental_room.png" % OUTPUT_DIR)
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	instance.call("_on_settings_changed", settings)
	instance.call("_close_pre_battle_preview")
	instance.call("_show_pre_battle_preview")
	await _settle()
	_expect(instance.get("_pre_battle_entry_tween") == null and panel.scale == Vector2.ONE, "Reduced motion must remain static")
	await _capture("%s/reduced_motion.png" % OUTPUT_DIR)
	var boss: Dictionary = engine.create_debug_boss_run(ProgressionStore.default_data())
	boss["mode"] = RunEngine.MODE_PRE_BATTLE
	boss["combat_state"] = {}
	boss["pre_battle_pending"] = true
	boss["pre_battle_travel_dir"] = _travel_dir_for_coord(boss.get("current_room", INVALID_COORD))
	instance.call("_load_run_state", boss)
	instance.call("_show_pre_battle_preview")
	await _settle()
	var objective_chip := panel.find_child("PreBattleObjectiveChip", true, false) as Control
	# Retain the old literal assertion even though today's named-boss copy differs.
	if objective_chip == null or not _labels_text(objective_chip).contains("KILL THE LEADER"):
		_fail("Boss pre-battle preview should always identify the boss as the leader objective")
	await _capture("%s/boss_pathological.png" % OUTPUT_DIR)
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
