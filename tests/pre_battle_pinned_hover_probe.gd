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
		var source := panel.find_child(str(entry[0]), true, false) as Button
		var kind: String = str(entry[1])
		_expect(source != null, "%s needs its real pre-battle control" % kind)
		if source == null:
			continue
		_viewport.gui_release_focus()
		await _pointer(Vector2(80.0, 80.0))
		await _settle()
		var idle_backing: Image = await _backing_image(source)
		await _capture("%s/%s_idle.png" % [OUTPUT, kind])
		for cycle: int in range(2):
			var prefix: String = "%d_%s" % [cycle + 1, kind]
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
			await _settle()
			_expect(not source.is_hovered(), "%s pointer must leave the source after close" % prefix)
			_expect(source.has_focus() and not source.has_focus(true), "%s must retain hidden pointer-acquired focus to exercise its custom visual" % prefix)
			var changed_pixels: int = _changed_pixels(idle_backing, await _backing_image(source))
			print("POINTER FOCUS BACKING: %s changed_pixels=%d" % [prefix, changed_pixels])
			_expect(changed_pixels <= 4, "%s closed pointer inspection must return to idle backing without glow (changed pixels=%d)" % [prefix, changed_pixels])
			await _capture("%s/%s_closed.png" % [OUTPUT, prefix])
		if kind == "enemy":
			router.call("set_forced_state_for_test", "controller", "xbox")
			_viewport.gui_release_focus()
			await _settle()
			var controller_idle: Image = await _backing_image(source)
			await _capture("%s/enemy_controller_idle.png" % OUTPUT)
			source.grab_focus()
			await _settle()
			_expect(not source.is_hovered() and source.has_focus(true), "Controller grab_focus must expose the foe's focus visual without pointer hover")
			var changed_pixels: int = _changed_pixels(controller_idle, await _backing_image(source))
			print("CONTROLLER FOCUS BACKING: changed_pixels=%d" % changed_pixels)
			_expect(changed_pixels > 100, "Controller-focused foe must draw its ember backing glow")
			await _capture("%s/enemy_controller_focus.png" % OUTPUT)
	_expect(popup_source_count > 0, "Real native popups must contain tooltip-bearing controls to exercise the reported lifetime bug")
	print("NATIVE PINNED HOVER PROOF: 2 cycles, card/equipment scrim close, foe Escape; popup tooltip controls=%d" % popup_source_count)
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT))
	print("PRE-BATTLE PINNED HOVER PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _backing_image(source: Control) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var region := Rect2i(source.get_global_rect().grow(8.0)).intersection(Rect2i(Vector2i.ZERO, PROBE_VIEWPORT))
	var backing: Image = image.get_region(region)
	backing.convert(Image.FORMAT_RGBA8)
	return backing

func _changed_pixels(before: Image, after: Image) -> int:
	_expect(before.get_size() == after.get_size(), "Focus must not change the control's backing bounds")
	if before.get_size() != after.get_size():
		return before.get_width() * before.get_height()
	var before_data: PackedByteArray = before.get_data()
	var after_data: PackedByteArray = after.get_data()
	var changed: int = 0
	for offset: int in range(0, before_data.size(), 4):
		for channel: int in range(3):
			if absi(int(before_data[offset + channel]) - int(after_data[offset + channel])) > 1:
				changed += 1
				break
	return changed

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
