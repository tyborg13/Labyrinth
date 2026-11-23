extends "res://tests/pre_battle_fixture.gd"

const ChronicleFixture = preload("res://tests/chronicle_probe.gd")
const MagicFixture = preload("res://tests/suites/magic_deck_suite.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Typed = preload("res://scripts/typed_arrays.gd")
const WEAPON: String = "grave_greatsword"
const PROJECTION_CARD: String = "tempest_form"
const REDRAW_CARD: String = "brace"
const DRAW_CARD: String = "rallying_breath"
const DRAW_RESULT: String = "pale_spark"
const PREVIOUS_NOTICE_CARD: String = "spark_dart"
const PURGED_CARD: String = "pale_spark"
const PURGE_MID_SECONDS: float = 0.30
const HEARTH_RESULT_SAMPLE_SECONDS: float = 0.50
const REDRAW_WATCHDOG_MS: int = 12000
const RAIL_CROP := Rect2i(1680, 0, 240, 900)
const POINTER_START := Vector2(500, 300)
const FIXTURE_ENEMY_HP: int = 5
const HEARTH_CHOICE_WATCHDOG_MS: int = 3000

var _output: String
var _after: bool
var _native: bool
var _container: SubViewportContainer
var _sound_log: FileAccess
var _hover_requests: int = 0
var _hover_plays: int = 0
var _mouse_motions: int = 0
var _hand_endpoint := Vector2.ZERO
var _redraw_reproduced: bool = false

class NoticeAudit extends Node:
	var label: RichTextLabel
	var panel: Control
	var previous: String
	var sampled_frames: int = 0
	var stale_frames: int = 0

	func _process(_delta: float) -> void:
		sampled_frames += 1
		if panel.is_visible_in_tree() and label.text.contains(previous): stale_frames += 1

class MotionAudit extends Node:
	signal moved(event: InputEventMouseMotion)

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and not event.relative.is_zero_approx():
			moved.emit(event)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("POL76_OUTPUT")
	_after = OS.get_environment("POL76_PHASE") == "after"
	_native = DisplayServer.get_name() != "headless"
	if _output.is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("An absolute POL76_OUTPUT directory is required")
		quit(1)
		return
	_setup()
	Settings.set_storage_path("user://pol76_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	_container = SubViewportContainer.new()
	_container.size = Vector2(PROBE_VIEWPORT)
	root.add_child(_container)
	_viewport.reparent(_container)
	_viewport.gui_disable_input = false
	_fit_proof_window()
	await _chronicle(false)
	await _chronicle(true)
	ProgressionStore.save_data(Tutorials.complete_tutorial(ProgressionStore.default_data()))
	await _equipment()
	await _purge("campfire")
	await _purge("scavenger")
	await _combat_rail(3)
	await _combat_rail(8)
	_container.queue_free()
	await process_frame
	print("POL-76 PROBE: %s (%s)" % ["FAIL" if _failed else "PASS", "native" if _native else "headless dry-run"])
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _fit_proof_window() -> void:
	# Keep the capture canvas exact even when the host display cannot fit the
	# full window. Scale only its on-screen preview for native mouse input.
	root.mode = Window.MODE_WINDOWED
	var window_size: Vector2i = PROBE_VIEWPORT
	if _native: window_size = window_size.min(DisplayServer.screen_get_usable_rect(root.current_screen).size)
	root.size = window_size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var display_size: Vector2 = root.get_visible_rect().size
	_container.scale = Vector2.ONE * minf(display_size.x / PROBE_VIEWPORT.x, display_size.y / PROBE_VIEWPORT.y)

func _chronicle(with_runs: bool) -> void:
	var name: String = "chronicle_runs" if with_runs else "chronicle_empty"
	ProgressionStore.save_data(ChronicleFixture.seeded_profile() if with_runs else ProgressionStore.default_data())
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	_viewport.add_child(menu)
	_fit_proof_window()
	await _settle()
	var backdrop: Array = [menu.get_node("Title"), menu.get_node("TitleShadow"), menu.get_node("TitleRim"),
		menu.get_node("TitleFaceBlend"), menu.get_node("ProfileBlock/Footer")]
	(menu.get_node("MenuColumn/SettingsButton") as Button).pressed.emit()
	await _settle()
	_report_backdrop(name + " settings", backdrop)
	menu.call("_on_settings_back_button_pressed")
	(menu.get("chronicle_button") as Button).pressed.emit()
	await _settle()
	var chronicle: Control = menu.get("_chronicle")
	_expect(chronicle.is_visible_in_tree(), name + " opened from the main menu")
	var frame: Control = chronicle.get_node("ChronicleFrame")
	print("%s frame %s" % [name, _rect(frame)])
	_report_backdrop(name + " open", backdrop)
	for control: Control in backdrop:
		_expect(not control.is_visible_in_tree(), name + " hides " + str(control.name))
	var empty: Control = frame.get_node("ChronicleEmpty")
	_expect(empty.is_visible_in_tree() == not with_runs, name + " displays the expected profile")
	if not with_runs: _report_visible_controls(frame, name)
	await _snapshot(name)
	chronicle.call("close")
	await _settle()
	_report_backdrop(name + " closed", backdrop)
	_expect((backdrop[0] as Control).is_visible_in_tree(), name + " restores the title")
	await _dispose(menu)

func _report_backdrop(phase: String, controls: Array) -> void:
	for control: Control in controls:
		print("%s %s visible=%s rect=%s" % [phase, control.name, control.is_visible_in_tree(), _rect(control)])

func _report_visible_controls(node: Node, phase: String) -> void:
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree(): return
		var text: String = control.text if control is Label or control is Button else ""
		print("%s %s %s %s" % [phase, control.name, _rect(control), JSON.stringify(text)])
	for child: Node in node.get_children():
		_report_visible_controls(child, phase)

func _equipment() -> void:
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	state = engine.call("_apply_collected_equipment_to_owned_state", state, {"collected_equipment": [WEAPON]})
	state = engine.equip_equipment(state, WEAPON, "weapon")
	var coord: Vector2i = _first_available_combat_coord(engine, state)
	state = engine.move_to_pre_battle(state, coord)
	var instance: Node = await _instance(state)
	_fit_proof_window()
	await _settle()
	var panel: Control = instance.get("_pre_battle_panel")
	var button: Button = panel.find_child("PreBattleEquipButton", true, false)
	var row: Control = panel.find_child("PreBattleEquipmentRow", true, false)
	_expect(button != null and row != null and panel.is_visible_in_tree(), "Real room entry opens the pre-battle kit")
	if button != null and row != null:
		var slot: Control = row.get_child(GameData.equipment_slots().find("weapon"))
		var expected: String = str(GameData.equipment_def(WEAPON)["icon_path"])
		var icon_path: String = button.icon.resource_path if button.icon != null else ""
		var gear_texture: Texture2D = slot.get("_source_icon")
		print("equip id=%s button=%s gear=%s expected=%s" % [slot.get_meta("equipment_id"), icon_path, gear_texture.resource_path, expected])
		_expect(button.icon == gear_texture and icon_path == expected, "Equip uses the weapon slot's item texture")
		await _snapshot("equip_weapon")
	await _dispose(instance)

func _purge(source: String) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = MagicFixture.shop_fixture(engine)
	if source == "campfire":
		state["mode"] = "campfire"
		var room: Dictionary = engine.room_metadata(state, state["current_room"])
		room["type"] = "campfire"
		state["rooms"]["2,1"] = room
		state["current_room_layout"] = engine.call("_display_layout_for_room", int(state["seed"]), room, Vector2i.ZERO)
	state = engine.grant_magic_to_deck(state, PURGED_CARD)
	state = engine.claim_card_reward(state, PREVIOUS_NOTICE_CARD)
	if source == "campfire": state["mode"] = "campfire"
	var instance: Node = await _instance(state)
	_fit_proof_window()
	var previous: String = str(state["notice"])
	_notice(instance, source, "before", previous)
	if source == "campfire":
		var choice: Control
		for child: Control in instance.get("_relic_choice_bar").get_children():
			if str(child.get_meta("choice_id", "")) == "purge":
				choice = child
				break
		if choice != null:
			var deadline: int = Time.get_ticks_msec() + HEARTH_CHOICE_WATCHDOG_MS
			while not bool(choice.get_meta("choice_revealed", false)) and Time.get_ticks_msec() < deadline:
				await process_frame
			var activate := InputEventAction.new()
			activate.action = &"ui_accept"
			activate.pressed = true
			instance.call("_on_campfire_choice_gui_input", activate, "purge", choice, Color.WHITE)
	else:
		var button: Button = instance.get("_scavenger_shop_view").find_child("ScavengerPurge", true, false)
		if button != null: button.pressed.emit()
	var modal: Control = instance.get("_magic_purge_overlay")
	_expect(modal != null, source + " opened via its Purge control")
	if modal != null:
		modal.call("select_card", PURGED_CARD)
		var confirm: Button = modal.find_child("ConfirmMagicPurge", true, false)
		var audit := NoticeAudit.new()
		audit.label = instance.get("log_label")
		audit.panel = instance.get("log_overlay")
		audit.previous = previous
		instance.add_child(audit)
		confirm.pressed.emit()
		_expect(modal.find_child("CardProxy", true, false) != null, source + " ran the real exhaust animation")
		await create_timer(PURGE_MID_SECONDS).timeout
		_notice(instance, source, "mid_exhaust", previous)
		await _snapshot("purge_" + source + "_exhaust")
		if is_instance_valid(instance.get("_magic_purge_overlay")): await modal.exhaust_finished
		await process_frame
		_notice(instance, source, "post_exhaust", previous)
		if source == "campfire":
			await create_timer(HEARTH_RESULT_SAMPLE_SECONDS).timeout
			_notice(instance, source, "hearth_result", previous)
			await _snapshot("purge_campfire_result")
			var deadline: int = Time.get_ticks_msec() + REDRAW_WATCHDOG_MS
			while bool(instance.get("_campfire_choice_action_pending")) and Time.get_ticks_msec() < deadline:
				await process_frame
			_expect(not bool(instance.get("_campfire_choice_action_pending")), "Hearth outcome completed")
		var run_state: Dictionary = instance.get("_run_state")
		_expect(int(run_state.get("magic_purges_this_run", 0)) == 1, source + " committed exactly one Purge")
		_notice(instance, source, "finished", previous)
		audit.set_process(false)
		print("purge %s sampled_frames=%d stale_frames=%d" % [source, audit.sampled_frames, audit.stale_frames])
		_expect(audit.sampled_frames > 0, source + " samples the live notice each frame")
		if _after: _expect(audit.stale_frames == 0, source + " never paints the prior notice during Purge")
	await _dispose(instance)

func _notice(instance: Node, source: String, phase: String, previous: String) -> void:
	var label: RichTextLabel = instance.get("log_label")
	var panel: Control = instance.get("log_overlay")
	var stale_visible: bool = panel.is_visible_in_tree() and label.text.contains(previous)
	print("purge %s %s visible=%s stale_visible=%s text=%s" % [source, phase, panel.is_visible_in_tree(), stale_visible, JSON.stringify(label.text)])
	if _after and phase != "before":
		_expect(not stale_visible, source + " does not replay the previous notice at " + phase)

func _combat_rail(count: int) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	var coord: Vector2i = _first_available_combat_coord(engine, state)
	state = engine.grant_magic_to_deck(state, PROJECTION_CARD)
	state = engine.move_to_pre_battle(state, coord)
	var prepared: Dictionary = engine.prepare_pre_battle_combat(state)
	var layout: Dictionary = prepared["layout"].duplicate(true)
	var placed: Array = []
	var grid: Array = layout["grid"]
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			var tile := Vector2i(x, y)
			if tile == layout["player_start"] or not PathUtils.is_passable(grid, tile): continue
			placed.append({"id": placed.size() + 1, "type": "ash_hound", "pos": tile, "hp": FIXTURE_ENEMY_HP, "max_hp": FIXTURE_ENEMY_HP})
			if placed.size() == count: break
		if placed.size() == count: break
	_expect(placed.size() == count, "Fixture needs enough floor for %d enemies" % count)
	if placed.size() != count: return
	layout["enemies"] = placed
	var combat_state: Dictionary = Combat.new().create_combat(int(state["seed"]), layout, engine.call("_player_snapshot", state))
	var deck: Dictionary = combat_state["deck"]
	deck["hand"] = Typed.strings([PROJECTION_CARD, DRAW_CARD, REDRAW_CARD, "quick_stab"])
	deck["draw"] = Typed.strings([DRAW_RESULT])
	state = engine.begin_pre_battle_combat(state, prepared)
	state = engine.set_combat_state(state, combat_state)
	var instance: Node = await _instance(state)
	_fit_proof_window()
	var combat: Dictionary = instance.get("_combat_state")
	_expect((combat["enemies"] as Array).size() == count, "Live combat has %d enemies" % count)
	instance.call("_on_card_hover_started", 0)
	await _settle()
	var bar: Control = instance.get("_turn_order_bar")
	var projected: int = 0
	var chips: int = 0
	for slot: Control in bar.get_children():
		if str(slot.get_meta("turn_order_projection_card_name", "")) != str(GameData.card_def(PROJECTION_CARD)["name"]): continue
		print("rail projection enemies=%d actor=%s delta=%s" % [
			count, slot.get_meta("turn_order_actor_key"), slot.get_meta("turn_order_projection_time_delta")])
		projected += 1
		var badge: Control = slot.get_node_or_null("ProjectionPreviewBadge")
		var label: Label = badge.get_child(0) if badge != null and badge.get_child_count() > 0 else null
		if label == null: continue
		chips += 1
		var scale_y: float = label.get_global_transform_with_canvas().y.length()
		if _after:
			_expect(is_equal_approx(label.get_theme_font_size("font_size") * scale_y, 14.0), "Projection text is a 14 px caption")
		for neighbor: Control in slot.get_children():
			if neighbor.name not in ["TurnOrderHealthBar", "TurnOrderTimeNumeral"]: continue
			if _rect(badge).intersects(_rect(neighbor)):
				print("TODO_DESIGN_projection_overlap badge=%s %s=%s" % [_rect(badge), neighbor.name, _rect(neighbor)])
		print("rail enemies=%d chip=%s font=%d scale=%.4f effective=%.4f rect=%s" % [
			count, label.text, label.get_theme_font_size("font_size"), scale_y,
			label.get_theme_font_size("font_size") * scale_y, _rect(label.get_parent())])
	var rail_slot: Control = bar.get_child(0) if bar.get_child_count() > 0 else null
	var plan: Dictionary = instance.get("_combat_hud_layout").right_column.plan
	print("rail enemies=%d projected=%d chips=%d queue_size_scale=%.4f children=%d active_rect=%s rect=%s" % [
		count, projected, chips, float(plan.get("scale", 0.0)), bar.get_child_count(),
		_rect(rail_slot) if rail_slot != null else Rect2(), _rect(bar)])
	_expect(projected > 0, "Tempest Form really projects on the live %d-enemy rail" % count)
	await _snapshot("rail_%d_enemies" % count, RAIL_CROP)
	if count == 3: await _redraw(instance)
	await _dispose(instance)

func _redraw(instance: Node) -> void:
	_sound_log = FileAccess.open(_output.path_join("hover_sound.log"), FileAccess.WRITE)
	_expect(_sound_log != null, "Open the hover sound trace")
	if _sound_log == null: return
	var bank: Node = instance.get("_sfx_bank")
	bank.cue_requested.connect(_trace_cue)
	var audit := MotionAudit.new()
	audit.moved.connect(func(event: InputEventMouseMotion) -> void:
		_mouse_motions += 1
		_hand_endpoint = event.position
		_trace("viewport motion local=%s relative=%s" % [event.position, event.relative])
	)
	_viewport.add_child(audit)
	if _native:
		root.grab_focus()
		await _settle()
		await _move_mouse(POINTER_START)
		var projection_index: int = (instance.get("_combat_state")["deck"]["hand"] as Array).find(PROJECTION_CARD)
		await _prove_mouse_entry(instance, projection_index, "entry")
	else:
		_trace("headless dry-run skips OS pointer and hover verdict")
	await _redraw_action(instance, DRAW_CARD, "draw")
	await _redraw_action(instance, REDRAW_CARD, "play")
	if _native:
		var hand: Array = instance.get("_combat_state")["deck"]["hand"]
		await _prove_mouse_entry(instance, hand.find(DRAW_RESULT), "move to different card")
		var verdict: String = "REPRODUCED" if _redraw_reproduced else "STALE"
		if _after: verdict = "FIXED"
		if _failed: verdict = "INCONCLUSIVE"
		print("POL-76 real-pointer double tick: " + verdict)
	bank.cue_requested.disconnect(_trace_cue)
	audit.queue_free()
	print("POL-76 sound trace " + _sound_log.get_path_absolute())
	_sound_log = null

func _redraw_action(instance: Node, card_id: String, action: String) -> void:
	var before: Array = (instance.get("_combat_state")["deck"]["hand"] as Array).duplicate()
	var start_requests: int = _hover_requests
	var start_plays: int = _hover_plays
	var start_motions: int = _mouse_motions
	var cursor: Vector2i = DisplayServer.mouse_get_position()
	var before_hover: int = int(instance.get("_hovered_card_index"))
	_trace("before %s redraw hand=%s hovered=%d endpoint=%s os_cursor=%s" % [action, before, before_hover, _hand_endpoint, cursor])
	var index: int = before.find(card_id)
	_expect(index >= 0, "Redraw uses a real playable card other than the hovered card")
	if index >= 0:
		await instance.call("_on_card_pressed", index)
		if int(instance.get("_selected_card_index")) == index:
			await instance.call("_on_confirm_card_play_pressed")
		var deadline: int = Time.get_ticks_msec() + REDRAW_WATCHDOG_MS
		while bool(instance.get("_animation_lock")) and Time.get_ticks_msec() < deadline: await process_frame
		await _settle()
	var after: Array = instance.get("_combat_state")["deck"]["hand"]
	_expect(not after.has(card_id) and before != after, "Real %s action changed the hand" % action)
	if action == "draw":
		_expect(after.has(DRAW_RESULT) and not before.has(DRAW_RESULT), "Draw action actually dealt the scheduled card")
	var hovered: int = int(instance.get("_hovered_card_index"))
	var lifted: int = int(instance.get("hand_box").emphasized_index())
	var lifted_card: Control = instance.call("_hand_card_control", lifted) if lifted >= 0 else null
	var lifted_id: String = str(lifted_card.get("card_id")) if lifted_card != null else ""
	_trace("after %s redraw hand=%s hovered=%d lifted_card_id=%s requests=%d played=%d motion_events=%d os_cursor=%s" % [
		action, after, hovered, lifted_id, _hover_requests - start_requests, _hover_plays - start_plays,
		_mouse_motions - start_motions, DisplayServer.mouse_get_position()])
	if _native:
		_redraw_reproduced = _redraw_reproduced or _hover_plays > start_plays
		_expect(_mouse_motions == start_motions and DisplayServer.mouse_get_position() == cursor, "OS pointer stayed in place across the %s redraw" % action)
		_expect(not lifted_id.is_empty() and lifted == hovered and hovered == int(instance.call("_hand_index_under_pointer")),
			"The card under the cursor lifted after the %s redraw" % action)
		if _after:
			_expect(_hover_requests == start_requests and _hover_plays == start_plays, "Stationary %s redraw must be silent" % action)

func _prove_mouse_entry(instance: Node, index: int, phase: String) -> void:
	var card: Control = instance.call("_hand_card_control", index) if index >= 0 else null
	_expect(card != null, phase + " has a target card")
	if card == null: return
	var previous_index: int = int(instance.get("_hovered_card_index"))
	var cursor: Vector2i = DisplayServer.mouse_get_position()
	var start_motions: int = _mouse_motions
	var start_requests: int = _hover_requests
	var start_plays: int = _hover_plays
	await _move_mouse(_rect(card).get_center())
	var hovered: int = int(instance.get("_hovered_card_index"))
	var requests: int = _hover_requests - start_requests
	var plays: int = _hover_plays - start_plays
	_trace("%s card_id=%s hovered=%d requests=%d played=%d motion_events=%d os_cursor=%s" % [
		phase, instance.call("_card_id_for_hand_index", index), hovered, requests, plays,
		_mouse_motions - start_motions, DisplayServer.mouse_get_position()])
	_expect(DisplayServer.mouse_get_position() != cursor and _mouse_motions > start_motions, phase + " delivered actual OS movement")
	_expect(hovered == index and hovered != previous_index and _rect(card).has_point(_hand_endpoint),
		phase + " moved hover onto the target card")
	_expect(requests == 1 and plays == 1, phase + " played exactly one hover cue")

func _move_mouse(point: Vector2) -> void:
	var before: Vector2i = DisplayServer.mouse_get_position()
	var motion_count: int = _mouse_motions
	Input.warp_mouse(_container.get_global_transform_with_canvas() * point)
	await process_frame
	await process_frame
	var after: Vector2i = DisplayServer.mouse_get_position()
	_trace("OS warp from=%s to=%s intended_viewport=%s" % [before, after, point])
	if motion_count == _mouse_motions and before != after:
		# macOS may coalesce the warp event. Forward the observed OS cursor delta
		# through the Window so SubViewportContainer delivers the motion normally.
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(after - root.position)
		motion.global_position = Vector2(after)
		motion.relative = Vector2(after - before)
		root.push_input(motion, true)
	await _settle()

func _trace_cue(cue: String, result: String) -> void:
	if cue == "card.hover":
		_hover_requests += 1
		if result == "played": _hover_plays += 1
	if cue.begins_with("card."):
		_trace("sfx %s %s" % [cue, result])

func _trace(event: String) -> void:
	var line: String = "%dms %s" % [Time.get_ticks_msec(), event]
	print(line)
	_sound_log.store_line(line)
	_sound_log.flush()

func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _snapshot(name: String, crop: Rect2i = Rect2i()) -> void:
	_expect(_viewport.size == PROBE_VIEWPORT and Vector2i(_viewport.get_visible_rect().size) == PROBE_VIEWPORT, "Exact proof canvas")
	if not _native: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == PROBE_VIEWPORT, "Native frame is exactly 1920x1080")
	if image == null: return
	_save_image(image, name)
	if crop.has_area():
		var zoom: Image = image.get_region(crop)
		zoom.resize(crop.size.x * 2, crop.size.y * 2, Image.INTERPOLATE_NEAREST)
		_save_image(zoom, name + "_2x")

func _save_image(image: Image, name: String) -> void:
	var path: String = _output.path_join(name + ".png")
	_expect(image.save_png(path) == OK, "Save " + path)
	print(path)

func _dispose(node: Node) -> void:
	node.queue_free()
	await process_frame
	await process_frame
