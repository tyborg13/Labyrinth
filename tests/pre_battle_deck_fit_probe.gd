extends "res://tests/pre_battle_fixture.gd"

const OUTPUT_DIR: String = "user://probes/pre_battle_vp4_deck_fit"

func _initialize() -> void:
	_setup()
	await _run_deck_proof(true)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("PRE-BATTLE DECK FIT PROBE: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _run_deck_proof(capture: bool) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	state = _pre_battle_state_for_room(engine, state, _first_available_combat_coord(engine, state))
	var instance: Node = await _instance(state)
	var roster: Array = GameData.cards().keys()
	roster.sort()
	for count: int in [18, 28]:
		# Exercise overflow with distinct real cards; duplicates alone would collapse
		# to counted strips and would not prove the scrollbar's last row.
		var deck: Array = roster.slice(0, count)
		_expect(deck.size() == count, "Deck fixture needs exactly %d real cards" % count)
		var loaded: Dictionary = instance.get("_run_state").duplicate(true)
		loaded["deck_cards"] = deck
		instance.set("_run_state", loaded)
		instance.call("_rebuild_pre_battle_overlay")
		await _settle()
		var panel := instance.get("_pre_battle_panel") as Control
		_assert_pre_battle_body_inside_panel(panel, "%d cards" % count)
		_assert_cards(panel, deck, "deck")
		_assert_cards(panel, loaded["attuned_magic_cards"], "attuned")
		var scroll := panel.find_child("PreBattleDeckScroll", true, false) as ScrollContainer
		var grid := panel.find_child("PreBattleDeckFlow", true, false) as Control
		_expect(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Deck must never scroll horizontally")
		var scrollbar := scroll.get_v_scroll_bar()
		_expect(scrollbar.visible and scrollbar.max_value > scrollbar.page + 1.0, "%d distinct cards should scroll within the kit" % count)
		var columns := panel.find_child("PreBattleEquipmentRow", true, false) as Control
		_expect(columns.get_child_count() == 5, "Kit must keep five gear sockets in slot order")
		if capture:
			await _capture("%s/%d_cards_top.png" % [OUTPUT_DIR, count])
		scroll.scroll_vertical = roundi(scrollbar.max_value - scrollbar.page)
		await process_frame
		await process_frame
		var last := grid.get_child(grid.get_child_count() - 1) as Control
		_expect(scroll.get_global_rect().grow(1.0).encloses(last.get_global_rect()), "Scrolling must fully reveal the last card")
		last.grab_focus()
		await process_frame
		_expect(last.has_focus(), "Last deck card remains focusable")
		if capture:
			await _capture("%s/%d_cards_bottom_focus.png" % [OUTPUT_DIR, count])
		print("Deck fit %d cards: groups=%d scroll max=%.0f page=%.0f" % [count, grid.get_child_count(), scrollbar.max_value, scrollbar.page])
	instance.queue_free()
	await process_frame
