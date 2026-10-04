extends "res://tests/pre_battle_material_polish_probe.gd"

var _checked_art_textures: Dictionary = {}

const LARGE_ATTUNEMENT: Array = ["pale_spark", "dull_bolt", "waning_pulse", "bone_dart", "static_lash", "threaded_path"]

func _run_material_proof(settings: Dictionary) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	state = _pre_battle_state_for_room(engine, state, _first_available_combat_coord(engine, state))
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(instance)
	await _settle()
	var panel: Control
	for variant: String in ["small", "normal", "large"]:
		instance.call("_load_run_state", _refinement_variant(state, variant))
		instance.call("_close_dialogue")
		await _settle()
		panel = instance.get("_pre_battle_panel") as Control
		var loaded: Dictionary = instance.get("_run_state") as Dictionary
		_expect((loaded.get("deck_cards", []) as Array).size() == {"small": 16, "normal": 18, "large": 19}[variant], "Representative deck must retain its compiled size")
		_assert_pre_battle_body_inside_panel(panel, variant)
		_check_objects(panel, loaded, variant)
		await _snap("loadout_%s" % variant)

	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	for source_name: String in ["PreBattleEquipmentChip", "PreBattleAttunedBadge", "PreBattleDeckBadge"]:
		var source := panel.find_child(source_name, true, false) as Control
		var tooltip := source.call("_make_custom_tooltip", source.tooltip_text) as Control
		_expect(tooltip != null, "%s retains precise hover inspection" % source_name)
		if tooltip != null:
			tooltip.free()
		await _click(source)
		await _settle()
		var pinned := instance.get("_pinned_tooltip_panel") as Control
		var expected_id: String = str(source.get_meta("equipment_id", "")) if source_name == "PreBattleEquipmentChip" else str(source.get_meta("card_id", ""))
		_expect(pinned != null and str(pinned.get_meta("inspection_id", "")) == expected_id, "Pointer click must inspect exact source identity")
		await _snap("inspect_%s" % source_name)
		await _key(KEY_ESCAPE)
		await _settle()
		_expect(not (instance.get("_pinned_tooltip_scrim") as Control).visible, "Escape must dismiss pinned inspection")
	await _pointer(Vector2(80, 80))
	router.call("set_forced_state_for_test", "controller", "xbox")
	var start := panel.find_child("PreBattleStartButton", true, false) as Button
	start.grab_focus()
	await _joy(JOY_BUTTON_DPAD_LEFT)
	var equip := panel.find_child("PreBattleEquipButton", true, false) as Button
	_expect(equip.has_focus(), "Controller traversal must preserve Start to Equip")
	await _snap("equip_focus")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_expect((instance.get("_upgrade_scrim") as Control).visible, "Controller Equip retains full Character detail route")
	await _joy(JOY_BUTTON_B)
	await _settle()
	_expect(not (instance.get("_upgrade_scrim") as Control).visible, "Controller Back returns from Character")
	_expect(_viewport.gui_get_focus_owner() != null and panel.is_ancestor_of(_viewport.gui_get_focus_owner()), "Equip return restores prebattle focus")
	await _snap("equip_return")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	await _pointer(Vector2(80, 80))
	settings["reduced_motion"] = true
	instance.call("_on_settings_changed", settings)
	instance.call("_close_pre_battle_preview")
	instance.call("_show_pre_battle_preview")
	await _settle()
	_expect(instance.get("_pre_battle_entry_tween") == null, "Reduced Motion remains static")
	await _snap("reduced_motion")
	if not _before:
		await _extra_cases(instance, state, engine)
	panel = instance.get("_pre_battle_panel") as Control
	start = panel.find_child("PreBattleStartButton", true, false) as Button
	start.grab_focus()
	await _key(KEY_ENTER)
	await _settle()
	_expect(str((instance.get("_run_state") as Dictionary).get("mode")) == "combat", "Keyboard Start retains combat transition")
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame

func _refinement_variant(original: Dictionary, variant: String) -> Dictionary:
	var state: Dictionary = original.duplicate(true)
	if variant == "small":
		return state
	var equipped: Dictionary = {"weapon": "grave_greatsword", "offhand": "witchglass_aegis", "armor": "voidsilk_carapace", "boots": "worldroot_greaves", "trinket": "crown_of_thorns"}
	var attuned: Array = (state.get("attuned_magic_cards", []) as Array).duplicate()
	var items: Array = ["crimson_draught"]
	if variant == "large":
		attuned = LARGE_ATTUNEMENT.duplicate()
		items.append("mossglass_elixir")
	state["equipped_equipment"] = equipped
	state["attuned_magic_cards"] = attuned
	state["equipped_items"] = items
	state["deck_cards"] = GameData.compile_deck_cards(equipped, attuned, items)
	return state

func _check_objects(panel: Control, state: Dictionary, variant: String) -> void:
	var equipment := panel.find_child("PreBattleEquipmentRow", true, false) as Control
	_expect(equipment.get_child_count() == GameData.equipment_slots().size(), "Every equipment slot remains represented")
	for chip: Control in equipment.get_children():
		_expect(equipment.get_global_rect().grow(1).encloses(chip.get_global_rect()), "Equipment stays fully visible")
	for source_kind: String in ["attuned", "deck"]:
		var expected: Array = state.get("attuned_magic_cards" if source_kind == "attuned" else "deck_cards", []) as Array
		_assert_cards(panel, expected, source_kind)
		var source := panel.find_child("PreBattleAttunedRow" if source_kind == "attuned" else "PreBattleDeckFlow", true, false) as Control
		var bounds: Rect2 = (panel.find_child("PreBattleDeckSection", true, false) as Control).get_global_rect()
		for strip: Control in source.get_children():
			var art := strip.get_node("Art") as TextureRect
			_expect(art != null and art.texture != null and art.size == Vector2(54, 30), "Every strip keeps its authored thumbnail at 54x30")
			_expect(strip.get_global_rect().position.x >= bounds.position.x and strip.get_global_rect().end.x <= bounds.end.x, "Card strips remain within their column")
			var name_label := strip.get_node("Name") as Label
			_expect(name_label.text == str(strip.get_meta("display_name", "")), "Card identity stays precise")
	print("STRIP GEOMETRY %s panel=%s" % [variant, panel.size])

func _extra_cases(instance: Node, state: Dictionary, engine: RunEngine) -> void:
	for duplicates: bool in [true, false]:
		var pathological: Dictionary = _refinement_variant(state, "large")
		var attuned: Array = ["lodestone_reversal", "lodestone_reversal" if duplicates else "gathering_rhythm", "cinderweave_guard", "firebrand_volley", "skybreak_current", "stormstring_shot"]
		pathological["attuned_magic_cards"] = attuned
		pathological["deck_cards"] = GameData.compile_deck_cards(pathological["equipped_equipment"], attuned, pathological["equipped_items"])
		instance.call("_load_run_state", pathological)
		instance.call("_close_dialogue")
		await _settle()
		var panel := instance.get("_pre_battle_panel") as Control
		_check_objects(panel, instance.get("_run_state") as Dictionary, "long_duplicate" if duplicates else "six_long_names")
		await _snap("long_duplicate" if duplicates else "six_long_names")
	var art_outliers: Dictionary = _refinement_variant(state, "large")
	var outlier_cards: Array = ["molten_reach", "prism_sight", "ricochet_knife", "spark_focus", "cinderline_tempo", "grave_dust_satchel"]
	art_outliers["attuned_magic_cards"] = outlier_cards
	art_outliers["deck_cards"] = GameData.compile_deck_cards(art_outliers["equipped_equipment"], outlier_cards, art_outliers["equipped_items"])
	instance.call("_load_run_state", art_outliers)
	instance.call("_close_dialogue")
	await _settle()
	var art_panel := instance.get("_pre_battle_panel") as Control
	_check_objects(art_panel, instance.get("_run_state") as Dictionary, "art_outliers")
	await _snap("art_outliers")
	var umbra: Dictionary = engine.create_new_run(7262026, ProgressionStore.default_data())
	umbra = _pre_battle_state_for_room(engine, umbra, _first_room_coord_with_min_enemies(engine, umbra, 5))
	for variant: String in ["small", "normal", "large"]:
		instance.call("_load_run_state", _refinement_variant(umbra, variant))
		instance.call("_close_dialogue")
		await _settle()
		var preview: Dictionary = (instance.get("_pre_battle_preview_run_state") as Dictionary).duplicate(true)
		_expect(bool(instance.call("_pre_battle_has_active_umbra", preview["combat_state"])), "Density proof must retain the taller active Umbra header")
		for count: int in range(1, 6):
			var sized: Dictionary = preview.duplicate(true)
			(sized["combat_state"]["enemies"] as Array).resize(count)
			instance.set("_pre_battle_preview_run_state", sized)
			instance.call("_rebuild_pre_battle_overlay")
			await _settle()
			var umbra_panel := instance.get("_pre_battle_panel") as Control
			_check_objects(umbra_panel, instance.get("_run_state") as Dictionary, "umbra_%s_%d_foes" % [variant, count])
			_assert_pre_battle_body_inside_panel(umbra_panel, "umbra_%s_%d_foes" % [variant, count])
			if count == 3:
				await _snap("umbra_%s" % variant)
	var boss: Dictionary = engine.create_debug_boss_run(ProgressionStore.default_data())
	boss["mode"] = RunEngine.MODE_PRE_BATTLE
	boss["combat_state"] = {}
	boss["pre_battle_pending"] = true
	boss["pre_battle_travel_dir"] = _travel_dir_for_coord(boss.get("current_room", INVALID_COORD))
	instance.call("_load_run_state", _refinement_variant(boss, "large"))
	instance.call("_show_pre_battle_preview")
	instance.call("_close_dialogue")
	await _settle()
	var panel := instance.get("_pre_battle_panel") as Control
	_check_objects(panel, instance.get("_run_state") as Dictionary, "boss_large")
	_assert_pre_battle_body_inside_panel(panel, "boss_large")
	await _snap("boss_large")
	var defiance: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	defiance["defiance_capacity"] = 3
	defiance["defiance_remaining"] = 2
	defiance["player_hp"] = 92
	defiance["player_max_hp"] = 108
	instance.set("_run_state", defiance)
	instance.call("_rebuild_pre_battle_overlay")
	await _settle()
	panel = instance.get("_pre_battle_panel") as Control
	var health := panel.find_child("PreBattleHealthChip", true, false) as Control
	var defiance_count := health.find_child("PreBattleDefianceCount", true, false) as Label
	_expect(defiance_count != null and defiance_count.text == "2/3", "Compact health header preserves exact Defiance count")
	_expect(_labels_text(health).contains("92 / 108"), "Compact health header preserves exact three-digit HP")
	var equipment_header := health.get_parent() as Control
	_expect((panel.find_child("PreBattleDeckSection", true, false) as Control).get_global_rect().encloses(equipment_header.get_global_rect()), "Health and Defiance must not expand the right column")
	await _snap("health_defiance")
	# A deliberately oversized catalog checks the existing vertical overflow route.
	instance.call("_load_run_state", _refinement_variant(state, "large"))
	instance.call("_close_dialogue")
	var overflow: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var cards: Array = GameData.cards().keys().slice(0, 40)
	overflow["deck_cards"] = cards
	instance.set("_run_state", overflow)
	instance.call("_rebuild_pre_battle_overlay")
	await _settle()
	panel = instance.get("_pre_battle_panel") as Control
	var scroll := panel.find_child("PreBattleDeckScroll", true, false) as ScrollContainer
	var flow := panel.find_child("PreBattleDeckFlow", true, false) as Control
	_expect(flow.get_child_count() == cards.size(), "Oversized deck must retain every identity")
	_expect(scroll.get_v_scroll_bar().visible, "Oversized deck retains its existing vertical scroll route")
	await _snap("overflow_top")
	await _pointer(scroll.get_global_rect().get_center())
	for index: int in range(45):
		for pressed: bool in [true, false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = pressed
			wheel.position = scroll.get_global_rect().get_center()
			wheel.global_position = wheel.position
			_viewport.push_input(wheel, true)
		await process_frame
	await _settle()
	var last := flow.get_child(flow.get_child_count() - 1) as Control
	_expect(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "Real wheel input must reach the last deck object")
	await _snap("overflow_bottom")
	await _click(last)
	await _settle()
	var pinned := instance.get("_pinned_tooltip_panel") as Control
	_expect(str(pinned.get_meta("inspection_id", "")) == str(last.get_meta("card_id", "")), "Last overflow object retains click inspection")
	await _snap("overflow_inspect")
	await _key(KEY_ESCAPE)
	await _settle()
