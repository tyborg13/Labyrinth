extends "res://tools/qa110/proof.gd"
## Run each interruption in a fresh production RunScene. Every path records
## setup, actual input effects, and the independent settled-state observations.

const Fixtures = preload("res://tools/qa110/interrupt_fixtures.gd")
const Encounters = Fixtures.Encounters
const Audit = preload("res://tools/qa110/settled.gd")
const Candidates = preload("res://scripts/controller_focus_candidates.gd")
const MODALS := {"grimoire_locked": "_grimoire_scrim", "settings_locked": "_settings_panel", "deck_locked": "_pile_scrim"}
const IDLE_FRAMES: int = 2
const BOOT_FRAME_LIMIT: int = 300
const SETTLE_FRAME_LIMIT: int = 600
const INPUT_LAYOUT_FRAMES: int = 4
const NATIVE_HOVER_SECONDS: float = 1.0
const HEADLESS_TIME_SCALE: float = 4.0
const NATIVE_FOCUS_TIMEOUT_MSEC: int = 20000
const OUTSIDE := Vector2(1, 1)
const ROUTES := ["cancel_right", "cancel_escape", "cancel_b", "rapid_hover",
	"grimoire_locked", "settings_locked", "deck_locked", "pass_with_loop",
	"own_move_death", "summon_under_hover", "focus_loss_drag", "application_pause_drag"]
const DRAG_INTERRUPTS := ["focus_loss_drag", "application_pause_drag"]

var sequence: int
var audit := Audit.new()
var scene: Node
var actual_focus_loss: bool
var focus_loss_seen: bool

func exercise() -> void:
	if headless: Engine.time_scale = HEADLESS_TIME_SCALE
	actual_focus_loss = not headless and OS.get_cmdline_user_args().has("--native-focus-loss")
	var chosen: Array[String]
	var routes: Array[String]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): chosen.append(arg.trim_prefix("--case="))
		if arg.begins_with("--route="): routes.append(arg.trim_prefix("--route="))
	var cases: int = 0
	for kind: String in Encounters.KINDS:
		for modality: String in ["mouse", "controller"]:
			for route: String in ROUTES:
				var label: String = "%s-%s-%s" % [kind, modality, route]
				if not chosen.is_empty() and not chosen.has(label): continue
				if not routes.is_empty() and not routes.has(route): continue
				if route in ["cancel_right", "cancel_escape", "application_pause_drag"] and modality != "mouse": continue
				if route == "cancel_b" and modality != "controller": continue
				await run_case(kind, modality, route, label)
				cases += 1
	check(cases > 0, "case selector matched")
	print("QA110 INTERRUPTIONS cases=%d headless=%s" % [cases, headless])

func run_case(kind: String, modality: String, route: String, label: String) -> void:
	sequence += 1
	var fixture: Dictionary = Fixtures.build(kind, route)
	if fixture.is_empty():
		if route in DRAG_INTERRUPTS: check(false, label + ": fixture available")
		emit_case({"path": label, "status": "fixture_unavailable"})
		return
	scene = Encounters.Board.mount(self, root, fixture["run"], 1.0)
	if scene == null:
		if route in DRAG_INTERRUPTS: check(false, label + ": fixture mounted")
		emit_case({"path": label, "status": "mount_failed"})
		return
	motion(OUTSIDE)
	for frame: int in range(BOOT_FRAME_LIMIT):
		if scene._dialogue_active: scene._close_dialogue()
		if Encounters.Board.ready_for_input(scene) and not scene._dialogue_active: break
		await process_frame
	if route in ["own_move_death", "summon_under_hover"] and fixture["witness"].is_empty():
		emit_case({"path": label, "status": "mechanic_fixture_unavailable"})
	elif await settled():
		if modality == "controller":
			joy(JOY_BUTTON_RIGHT_SHOULDER)
			await frames(INPUT_LAYOUT_FRAMES)
		var before: Dictionary = {
			"turn": scene._combat_state.get("turn"), "enemies": live_ids(),
			"hand": scene._combat_hand_cards(scene._combat_state)}
		var combat_before: Dictionary = scene._combat_state.duplicate(true) if route in DRAG_INTERRUPTS else {}
		var detail: Dictionary = await exercise_route(route, modality == "controller", fixture["witness"])
		detail["fixture"] = fixture["witness"]
		var clean_boundary: bool = await settled()
		if route in DRAG_INTERRUPTS:
			await verify_drag_interruption(label, modality == "controller", clean_boundary, combat_before, detail)
		var context: Dictionary = {"path": label, "seed": fixture["run"]["seed"], "decision": sequence, "room_kind": kind,
			"section": scene._run_engine.room_metadata(fixture["run"], fixture["run"]["current_room"]).get("section_index", -1), "room": str(fixture["run"].get("current_room")),
			"mode": scene._run_state.get("mode"), "action": route}
		var result: Dictionary = audit.sample(self, scene, context, output) if clean_boundary else {"context": context}
		if clean_boundary and result["checks"].has("targeting") and bool(detail.get("triggered", false)):
			if route.begins_with("cancel_") and scene._selected_card_index >= 0:
				result["checks"]["targeting"].append({"kind": "selection_cancel_failed", "selected": scene._selected_card_index})
			if route == "focus_loss_drag" and modality == "mouse" and scene._drag_card_index >= 0:
				result["checks"]["targeting"].append({"kind": "drag_survived_focus_loss", "drag_index": scene._drag_card_index,
					"proxy_visible": detail.get("proxy_visible"), "proxy_rect": detail.get("proxy_rect"), "arrow_visible": detail.get("arrow_visible")})
		result.merge({"path": label, "status": "settled" if clean_boundary else "unsettled", "before": before, "interruption": detail})
		emit_case(result)
		if clean_boundary: await capture(label)
	else:
		if route in DRAG_INTERRUPTS: check(false, label + ": fixture ready for input")
		emit_case({"path": label, "status": "boot_unsettled"})
	scene.queue_free()
	await frames(IDLE_FRAMES)

func exercise_route(route: String, controller: bool, witness: Dictionary) -> Dictionary:
	match route:
		"cancel_right", "cancel_escape", "cancel_b":
			await hover_card(controller)
			if controller: joy(JOY_BUTTON_A)
			else: click(card_point(), MOUSE_BUTTON_LEFT)
			await frames(INPUT_LAYOUT_FRAMES)
			var pending: bool = scene._board_targeting_active()
			if pending and not controller and not scene._pending_target_tiles.is_empty():
				motion(board_point(scene._pending_target_tiles.front()))
				await process_frame
			match route:
				"cancel_right": click(scene._hand_pointer_position, MOUSE_BUTTON_RIGHT)
				"cancel_escape": escape()
				_: joy(JOY_BUTTON_B)
			await process_frame
			return {"triggered": pending, "selection_after": scene._selected_card_index, "targeting_after": scene._board_targeting_active()}
		"rapid_hover": return await rapid_hover(controller)
		"grimoire_locked", "settings_locked", "deck_locked": return await interrupt_modal(route, controller)
		"pass_with_loop": return await pass_with_loop(controller)
		"own_move_death", "summon_under_hover": return await mechanic(route, controller, witness)
		"focus_loss_drag", "application_pause_drag":
			return await focus_loss(controller, route == "application_pause_drag", witness)
	return {}

func rapid_hover(controller: bool) -> Dictionary:
	var foe: Vector2i = visible_foe()
	var hero: Vector2i = scene._combat_state["player"]["pos"]
	await hover_card(controller)
	var hand: int = scene._hovered_card_index
	if controller:
		# Select exact nav candidates through the shipped virtual cursor path.
		joy(JOY_BUTTON_X)
		scene._controller_set_board_tile(foe)
	else: motion(board_point(foe))
	await process_frame
	var visited_foe: Vector2i = scene._hovered_board_tile
	if controller: scene._controller_set_board_tile(hero)
	else: motion(board_point(hero))
	await process_frame
	return {"triggered": hand == 0 and visited_foe == foe and scene._hovered_board_tile == hero,
		"hand": hand, "wanted_foe": foe, "foe": visited_foe, "wanted_tile": hero, "tile": scene._hovered_board_tile,
		"controller_candidate_driver": controller}

func interrupt_modal(route: String, controller: bool) -> Dictionary:
	pass_input(controller)
	var locked: bool = await wait_for_lock()
	await open_modal(route, controller)
	var modal: Control = scene.get(MODALS[route])
	var opened: bool = is_instance_valid(modal) and modal.is_visible_in_tree()
	if opened: await close_modal(modal, controller)
	var closed: bool = not opened or not modal.is_visible_in_tree()
	var unlocked_control: bool = false
	var closed_control: bool = false
	if await settled():
		await open_modal(route, controller)
		unlocked_control = is_instance_valid(modal) and modal.is_visible_in_tree()
		if unlocked_control:
			await close_modal(modal, controller)
			closed_control = not modal.is_visible_in_tree()
	return {"triggered": locked, "overlay": MODALS[route], "opened_during_lock": opened, "closed": closed,
		"opened_after_unlock": unlocked_control, "closed_after_unlock": closed_control}

func open_modal(route: String, controller: bool) -> void:
	match route:
		"grimoire_locked": activate(scene.grimoire_button, controller)
		"settings_locked":
			if controller: joy(JOY_BUTTON_START)
			else: activate(scene.menu_button, false)
			await process_frame
			if scene._menu_scrim.visible: activate(button_text(scene._menu_scrim, "Settings"), controller)
		"deck_locked": activate(scene.draw_pile, controller)
	await process_frame

func close_modal(modal: Control, controller: bool) -> void:
	if controller: joy(JOY_BUTTON_B)
	else: escape()
	await process_frame
	if modal == scene._settings_panel and not modal.visible and scene._menu_scrim.visible:
		if controller: joy(JOY_BUTTON_B)
		else: escape()
		await process_frame

func pass_with_loop(controller: bool) -> Dictionary:
	await hover_card(controller)
	await create_timer(NATIVE_HOVER_SECONDS, true, false, true).timeout
	var loops: int = visible_loops()
	var before: int = int(scene._combat_state.get("turn", -1))
	var at_pass: int = loops
	if not controller:
		var chip: Button = scene.find_child("PassPreviewChip", true, false)
		if is_instance_valid(chip):
			var point: Vector2 = chip.get_global_rect().get_center()
			motion(point)
			at_pass = visible_loops()
			Encounters.button(root, point, MOUSE_BUTTON_LEFT, true)
			Encounters.button(root, point, MOUSE_BUTTON_LEFT, false)
	else:
		pass_input(true)
	var locked: bool = await wait_for_lock()
	var resolved: bool = await settled()
	return {"triggered": at_pass > 0 and locked and resolved, "loops_before": loops, "loops_at_pass": at_pass, "loops_after": visible_loops(),
		"pass_started": locked, "turn_before": before, "turn_after": scene._combat_state.get("turn")}

func mechanic(route: String, controller: bool, witness: Dictionary) -> Dictionary:
	var before: Array[int] = live_ids()
	await hover_card(controller)
	var hover_before: int = scene._hovered_card_index
	pass_input(controller)
	var locked: bool = await wait_for_lock()
	var arrival_hover: int = -1
	var arrival_pointer: int = -1
	var first_change: Array[int]
	var dead_move_seen: bool = false
	var actor_key: String = "enemy_%d" % int(witness["actor"])
	for frame: int in range(SETTLE_FRAME_LIMIT):
		var board: Control = scene.board_view
		var board_ids: Array[int] = live_ids(board.combat_state)
		if route == "own_move_death":
			var drawn: Dictionary = board.presentation.get("unit_draw_tiles", {})
			var actors: Array = board.combat_state.get("enemies", [])
			for unit: Dictionary in actors:
				if unit["id"] == witness["actor"] and unit["pos"] != witness["from"]: dead_move_seen = true
			if drawn.has(actor_key) and drawn[actor_key] != witness["from"]: dead_move_seen = true
		elif first_change.is_empty() and board_ids.any(func(id: int) -> bool: return not before.has(id)):
			first_change = board_ids
			arrival_hover = scene._hovered_card_index
			if not controller and scene._hand_pointer_position_valid and scene.hand_box.is_visible_in_tree():
				arrival_pointer = scene._hand_index_under_pointer()
		if not scene._animation_lock: break
		if route == "summon_under_hover" and not controller and scene.hand_box.is_visible_in_tree():
			motion(card_point())
		await process_frame
	var finished_ids: Array[int] = live_ids()
	if route == "own_move_death" and not dead_move_seen:
		for event: Dictionary in scene._combat_state.get("surface_events", []):
			if event.get("id") == witness["actor"] and event.get("tile") == witness["fire_tile"] and event.get("trigger") == "entry":
				dead_move_seen = true
				break
	var change: bool = not finished_ids.has(witness["actor"]) if route == "own_move_death" else not first_change.is_empty()
	var overlap: bool = dead_move_seen if route == "own_move_death" else arrival_hover >= 0
	return {"triggered": locked and change and overlap, "mechanic_resolved": change, "simultaneous": overlap,
		"fixture": witness, "hover_before": hover_before, "hover_at_arrival": arrival_hover, "pointer_card_at_arrival": arrival_pointer,
		"first_arrival_roster": first_change, "live_after": finished_ids}

func focus_loss(controller: bool, application_pause: bool, witness: Dictionary) -> Dictionary:
	# Combat's physical drag is pointer-owned. For controller, hold a selected
	# card in aim and send the same loss event at that equivalent boundary.
	await hover_card(controller)
	if controller:
		joy(JOY_BUTTON_A)
		await frames(INPUT_LAYOUT_FRAMES)
	else:
		var point: Vector2 = card_point()
		Encounters.button(root, point, MOUSE_BUTTON_LEFT, true)
		Encounters.motion(root, board_point(visible_foe()), true)
		await frames(INPUT_LAYOUT_FRAMES)
		if application_pause:
			# The first motion starts the proxy. Continue the drag to enter aim.
			Encounters.motion(root, board_point(witness.get("foe", Vector2i(-1, -1))), true)
			await frames(INPUT_LAYOUT_FRAMES)
	var held: bool = scene._board_targeting_active() if controller else scene._drag_card_index >= 0
	var selection_before: int = scene._selected_card_index
	var drag_before: int = scene._drag_card_index
	var targeting_before: bool = scene._board_targeting_active()
	if application_pause:
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	elif actual_focus_loss and held:
		focus_loss_seen = false
		var mark: Callable = func() -> void: focus_loss_seen = true
		root.focus_exited.connect(mark, CONNECT_ONE_SHOT)
		print("QA110 FOCUS: switch away from the proof window now")
		var deadline: int = Time.get_ticks_msec() + NATIVE_FOCUS_TIMEOUT_MSEC
		while not focus_loss_seen and Time.get_ticks_msec() < deadline: await process_frame
		if root.focus_exited.is_connected(mark): root.focus_exited.disconnect(mark)
	else:
		root.focus_exited.emit()
		root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	return {"triggered": held and (application_pause or not actual_focus_loss or focus_loss_seen),
		"simulated_window_focus": not application_pause and not actual_focus_loss,
		"application_pause": application_pause, "selection_before": selection_before,
		"drag_before": drag_before, "targeting_before": targeting_before, "controller_aim_equivalent": controller}

func verify_drag_interruption(label: String, controller: bool, clean: bool, combat_before: Dictionary, detail: Dictionary) -> void:
	check(detail["triggered"], label + ": held drag or aim received the interruption")
	check(clean, label + ": settled after interruption")
	var proxy: Control = scene._drag_card_proxy
	var rect: Rect2 = proxy.get_global_rect() if is_instance_valid(proxy) else Rect2()
	var arrow: CanvasItem = scene._drag_target_arrow
	detail.merge({"drag_after": scene._drag_card_index, "selection_after": scene._selected_card_index,
		"proxy_visible": is_instance_valid(proxy) and proxy.is_visible_in_tree(),
		"proxy_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"arrow_visible": is_instance_valid(arrow) and arrow.is_visible_in_tree()})
	check(scene._combat_state == combat_before, label + ": interruption did not play or pay")
	if controller:
		check(scene._board_targeting_active() and scene._selected_card_index == detail["selection_before"], label + ": controller aim preserved")
		return
	var retired: bool = scene._drag_card_index < 0 and not scene._drag_cancel_in_progress
	check(retired and not detail["proxy_visible"], label + ": drag and proxy retired")
	check(scene._selected_card_index < 0 and not scene._board_targeting_active() and not detail["arrow_visible"], label + ": targeting cleared")
	var source_index: int = detail["drag_before"]
	if source_index >= 0:
		check(scene.hand_box.get_child(source_index).is_visible_in_tree(), label + ": source slot visible")
	if detail["application_pause"]:
		check(detail["targeting_before"], label + ": paused during drag targeting")
	if not retired:
		return
	if detail["application_pause"]:
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	elif detail["simulated_window_focus"]:
		root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	if detail["application_pause"] or detail["simulated_window_focus"]:
		Encounters.button(root, board_point(visible_foe()), MOUSE_BUTTON_LEFT, false)
		check(await settled(), label + ": settled after return and release")
		check(scene._drag_card_index < 0 and not scene._board_targeting_active() and scene._combat_state == combat_before,
			label + ": return and late release did not restore or play the card")

func hover_card(controller: bool) -> void:
	if controller:
		if not scene._controller_hand_focused: joy(JOY_BUTTON_X)
		scene._controller_set_hand_index(0)
	else:
		motion(card_point())
	await process_frame

func pass_input(controller: bool) -> void:
	if controller: joy(JOY_BUTTON_Y)
	else: activate(scene.find_child("PassPreviewChip", true, false), false)

func activate(control: Control, controller: bool) -> void:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return
	if controller:
		if scene._controller_custom_navigation_available():
			var candidate: Dictionary = Candidates.for_control(scene, control)
			if candidate.is_empty(): return
			scene._controller_region = "board"
			Candidates.set_candidate(scene, candidate, true)
		elif control.focus_mode != Control.FOCUS_NONE:
			control.grab_focus()
		else:
			return
		joy(JOY_BUTTON_A)
	else:
		click(control.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)

func button_text(scope: Control, label: String) -> Control:
	for button: Button in scope.find_children("*", "Button", true, false):
		if button.text.nocasecmp_to(label) == 0: return button
	return null

func settled() -> bool:
	var idle: int = 0
	for frame: int in range(SETTLE_FRAME_LIMIT):
		if audit.transitions_running(scene) or not audit.running_tweens(self).is_empty():
			idle = 0
		else:
			idle += 1
			if idle > IDLE_FRAMES: return true
		await process_frame
	return false

func wait_for_lock() -> bool:
	for frame: int in range(INPUT_LAYOUT_FRAMES):
		if scene._animation_lock: return true
		await process_frame
	return false

func visible_loops() -> int:
	var total: int = 0
	for control: Control in root.find_children("TooltipLoopWindow", "Control", true, false):
		if control.is_visible_in_tree(): total += 1
	return total

func live_ids(state: Dictionary = {}) -> Array[int]:
	var ids: Array[int]
	var source: Dictionary = state if not state.is_empty() else scene._combat_state
	for unit: Dictionary in source.get("enemies", []):
		if int(unit.get("hp", 0)) > 0: ids.append(int(unit["id"]))
	return ids

func visible_foe() -> Vector2i:
	for unit: Dictionary in scene.board_view._visible_units():
		if unit.get("role") == "enemy": return unit["pos"]
	return Vector2i(-1, -1)

func card_point() -> Vector2:
	return scene._hand_card_global_rect(0).get_center()

func board_point(tile: Vector2i) -> Vector2:
	if tile.x < 0: return OUTSIDE
	return scene.board_view.get_global_transform_with_canvas() * scene.board_view.world_position_for_tile(tile)

func motion(point: Vector2) -> void:
	Encounters.motion(root, point)

func click(point: Vector2, button: MouseButton) -> void:
	motion(point)
	Encounters.button(root, point, button, true)
	Encounters.button(root, point, button, false)

func joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)

func escape() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event, true)

func emit_case(result: Dictionary) -> void:
	print("QA110 PATH " + JSON.stringify(result))
