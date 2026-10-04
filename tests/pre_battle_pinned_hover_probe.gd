extends "res://tests/pre_battle_fixture.gd"

const OUTPUT: String = "user://probes/pre_battle_pinned_hover"
var _last_pointer: Vector2 = Vector2.ZERO

func _initialize() -> void:
	_setup()
	_viewport.gui_embed_subwindows = true
	_viewport.notify_mouse_entered()
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	state = _pre_battle_state_for_room(engine, state, _first_available_combat_coord(engine, state))
	var instance: Node = await _instance(state)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var panel := instance.get("_pre_battle_panel") as Control
	var sources: Array = [
		["PreBattleDeckBadge", "card"],
		["PreBattleEquipmentChip", "equipment"],
		["PreBattleEnemyCard", "enemy"]
	]
	var popup_source_count: int = 0
	for entry: Array in sources:
		for cycle: int in range(2):
			var source := panel.find_child(str(entry[0]), true, false) as Control
			var kind: String = str(entry[1])
			var prefix: String = "%d_%s" % [cycle + 1, kind]
			_expect(source != null, "%s needs its real pre-battle control" % prefix)
			if source == null:
				continue
			var tooltip_text: String = source.tooltip_text
			var popup: Window = await _hover_popup(source, prefix)
			if popup == null:
				continue
			for child: Node in popup.find_children("*", "Control", true, false):
				if not (child as Control).tooltip_text.is_empty():
					popup_source_count += 1
			await _capture("%s/%s_hover.png" % [OUTPUT, prefix])
			await _press_at(source.get_global_rect().get_center())
			await _settle()
			var pinned := instance.get("_pinned_tooltip_panel") as Control
			_expect(pinned != null and str(pinned.get_meta("inspection_kind", "")) == kind, "%s pointer click must open its pinned inspection" % prefix)
			_expect(not is_instance_valid(popup), "%s click must dismiss the real native tooltip Window" % prefix)
			var suppressed: Dictionary = instance.get("_pinned_pre_battle_tooltip_sources")
			var invalid_sources: int = 0
			for key: Variant in suppressed.keys():
				if not is_instance_valid(key):
					invalid_sources += 1
			_expect(invalid_sources == 0, "%s suppression must omit freed native popup controls (got %d)" % [prefix, invalid_sources])
			await _capture("%s/%s_pinned.png" % [OUTPUT, prefix])
			if kind == "enemy":
				await _key(KEY_ESCAPE)
			else:
				await _pointer(Vector2(80.0, 80.0))
				await _press_at(Vector2(80.0, 80.0))
			await _settle()
			_expect(not (instance.get("_pinned_tooltip_scrim") as Control).visible, "%s must close via %s" % [prefix, "Escape" if kind == "enemy" else "scrim click"])
			_expect((instance.get("_pre_battle_scrim") as Control).visible, "%s close must leave pre-battle open" % prefix)
			_expect(source.tooltip_text == tooltip_text, "%s must restore the original source tooltip" % prefix)
			_expect((instance.get("_pinned_pre_battle_tooltip_sources") as Dictionary).is_empty(), "%s close must clear saved hover sources" % prefix)
			await _pointer(Vector2(80.0, 80.0))
			await _capture("%s/%s_closed.png" % [OUTPUT, prefix])
	_expect(popup_source_count > 0, "Real native popups must contain tooltip-bearing controls to exercise the reported lifetime bug")
	print("NATIVE PINNED HOVER PROOF: 2 cycles, card/equipment scrim close, foe Escape; popup tooltip controls=%d" % popup_source_count)
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT))
	print("PRE-BATTLE PINNED HOVER PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _hover_popup(source: Control, context: String) -> Window:
	await _pointer(Vector2(80.0, 80.0))
	await _settle()
	_expect(not source.tooltip_text.is_empty(), "%s source hover must be available" % context)
	await _pointer(source.get_global_rect().get_center())
	_expect(_viewport.gui_get_hovered_control() == source, "%s pointer must hover the actual source" % context)
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		for child: Node in source.find_children("*", "Window", true, false):
			var popup := child as Window
			if popup.visible and not popup.is_queued_for_deletion() and popup.theme_type_variation == &"TooltipPanel":
				return popup
		await create_timer(0.05).timeout
	_expect(false, "%s timed hover must show a real native tooltip popup" % context)
	return null

func _pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - _last_pointer
	_last_pointer = position
	_viewport.push_input(event, true)
	await process_frame

func _press_at(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame
