extends RefCounted
## Exercise the retained tab lifecycle with combat Details enabled.

const Badges = preload("res://scripts/intent_badges.gd")
const ViewSettings = preload("res://scripts/settings_store.gd")
const ROUTES := ["x-cancel", "b-cancel", "rapid-x-b", "mouse-x-cancel", "mouse-b-cancel"]
const PREPARE_FRAMES: int = 24
const REVEAL_FRAMES: int = 12
const CAPTURE_FRAMES := [1, REVEAL_FRAMES]

static func run(host: SceneTree, encounter: String) -> void:
	if host._scene._settings.get("board_health_bars") != ViewSettings.BOARD_HEALTH_CONTEXTUAL:
		host._errors.append(encounter + " must use On Hover and Aim health bars")
		return
	host._scene._set_show_all_enemy_intents(true)
	var combat_before: String = host._combat_digest(host._scene._combat_state)
	for route: String in ROUTES:
		var key: String = encounter + "/intent-tabs/" + route
		if not await _prepare_card(host, key, route.begins_with("mouse-")): return
		var before: Dictionary = _tabs(host)
		if before.is_empty() or not _fully_open(before):
			host._errors.append(key + " did not start with fully open enemy tabs")
			return
		# Both button events reach the viewport before the next draw in rapid X/B.
		var opens_hand: bool = route in ["x-cancel", "mouse-x-cancel", "rapid-x-b"]
		host._button(JOY_BUTTON_X if opens_hand else JOY_BUTTON_B)
		if route == "rapid-x-b":
			if host._scene._controller_region != "hand" or host._scene._selected_card_index >= 0:
				host._errors.append(key + " X did not cancel onto the hand")
				return
			host._button(JOY_BUTTON_B)
			opens_hand = false
		_sync_headless_tabs(host)
		var frames: Array = []
		for frame: int in range(1, REVEAL_FRAMES + 1):
			await host._wait_frames(1)
			frames.append(_tabs(host))
			if frame in CAPTURE_FRAMES:
				host._record_frame(key, frame)
		if host._scene._selected_card_index >= 0 or host._scene._controller_region != ("hand" if opens_hand else "board"):
			host._errors.append(key + " did not reach its expected region")
			return
		if not _fully_open(frames.back()):
			host._errors.append(key + " tabs did not finish opening")
			return
		host._receipts[key] = {"before": before, "frames": frames}
	if combat_before != host._combat_digest(host._scene._combat_state):
		host._errors.append(encounter + " intent tab replay changed committed combat")

static func _prepare_card(host: SceneTree, key: String, pointer: bool) -> bool:
	var scene: Control = host._scene
	var hand: Array = scene._combat_state["deck"]["hand"]
	var index: int = hand.find(host.TARGET_CARD)
	if index < 0:
		host._errors.append(key + " missing Flowing Step")
		return false
	if pointer:
		if scene._controller_is_active() and scene._controller_region != "hand":
			host._button(JOY_BUTTON_X)
		if not await host._rest(key + "/hand"): return false
		var card: Control = scene._hand_card_control(index)
		host._motion(card.get_global_transform_with_canvas() * Vector2(card.size.x * 0.5, 14.0))
		await host._wait_frames(PREPARE_FRAMES)
		_click_card(host, card.get_global_transform_with_canvas() * (card.size * 0.5))
	else:
		if scene._controller_region != "hand": host._button(JOY_BUTTON_X)
		for attempt: int in range(hand.size()):
			if scene._controller_hand_index == index: break
			host._button(JOY_BUTTON_RIGHT_SHOULDER)
			await host._wait_frames(1)
		if not await host._rest(key + "/hand"): return false
		host._button(JOY_BUTTON_A)
	var deadline: int = Time.get_ticks_usec() + host.REST_TIMEOUT_USEC
	while scene._selected_pass_pending() and Time.get_ticks_usec() < deadline:
		await host._wait_frames(1)
	await host._wait_frames(PREPARE_FRAMES)
	_sync_headless_tabs(host)
	await host._wait_frames(PREPARE_FRAMES)
	if (scene._selected_card_index != index or scene._pending_target_tiles.is_empty()
		or scene._controller_is_active() == pointer or scene._selected_pass_pending()):
		host._errors.append("%s selection: index=%d expected=%d controller=%s targets=%d pending=%s" % [
			key, scene._selected_card_index, index, scene._controller_is_active(),
			scene._pending_target_tiles.size(), scene._selected_pass_pending()
		])
		return false
	return true

static func _click_card(host: SceneTree, point: Vector2) -> void:
	host._motion(point)
	var router: Node = host.root.get_node("InputRouter")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		# The proof SubViewport cannot deliver input to the root autoload.
		router.record_input_activity(event)
		host._canvas.push_input(event, true)

static func _chip_canvases(host: SceneTree) -> Array[Control]:
	var result: Array[Control]
	for record: Dictionary in host._board._aim_focus.canvases.values():
		if not record.hud or not is_instance_valid(record.canvas):
			continue
		var canvas: Control = record.canvas
		var ops: Array = canvas._render_slice_ops
		if canvas.is_visible_in_tree() and not ops.is_empty() and ops[0][0] == "_draw_slice_intent_chip":
			if bool(ops[0][1][0].get("contextual", false)):
				result.append(canvas)
	return result

static func _sync_headless_tabs(host: SceneTree) -> void:
	if not host._headless: return
	# The dummy renderer skips CanvasItem draw callbacks. Run the tab's normal
	# presentation function on the current routed chip, with the real scene tween.
	for canvas: Control in _chip_canvases(host):
		Badges.present_contextual_tab(canvas, canvas._render_slice_ops[0][1][0])

static func _tabs(host: SceneTree) -> Dictionary:
	var tabs: Dictionary = {}
	for canvas: Control in _chip_canvases(host):
		var key: String = canvas._render_slice_ops[0][1][0]["key"]
		var tab: Badges.TabWindow = canvas.get_node_or_null("IntentTab_" + key) as Badges.TabWindow
		if is_instance_valid(tab) and tab.is_visible_in_tree():
			tabs[key] = {"reveal": tab.reveal, "expanded": tab.expanded, "clip_width": tab.size.x}
	return tabs

static func _fully_open(tabs: Dictionary) -> bool:
	if tabs.is_empty(): return false
	for tab: Dictionary in tabs.values():
		if not tab["expanded"] or tab["reveal"] != 1.0: return false
	return true
