extends "res://scripts/combat_board_view.gd"
## Test-only observation at the real invalidation and draw dispatch boundaries.

var redraw_requests: Array[String]
var draw_events: Array[Dictionary]

func _queue_render_layer_redraw(layer: Control, clock_only: bool = false) -> void:
	# perf-63 (fd1d5a9ae) joins requests during submission, then calls this
	# boundary again to flush. Count only requests that reach the retained layer.
	if not _batching_submission_redraws and is_instance_valid(layer): redraw_requests.append(str(layer.get("_render_layer_kind")))
	super._queue_render_layer_redraw(layer, clock_only)

func _record_render_section_time(section: String, started_usec: int) -> void:
	if section in ["unit_huds", "damage_preview_overlays"]:
		_record_hud_draw(section)
	super._record_render_section_time(section, started_usec)

func _record_hud_draw(kind: String) -> void:
	# A retained slice paints inside its original logical HUD layer.
	var owner: Control = get_parent() as Control if _is_layer_slice_canvas else self
	# rd-03 per-unit HUD canvases are fresh children of the layer; record into the
	# layer's shared event list so their paint order is observed with it.
	var sink: Variant = owner.get("draw_events") if owner != null else null
	(sink if sink is Array else draw_events).append({"kind": kind, "layer": owner, "frame": Engine.get_process_frames()})

# perf-35's sliced HUD bypasses the monolithic section-timing callbacks.
# Observe the real paint calls, including every overlay/badge after the bars.
func _draw_health_bar_entry(entry: Dictionary) -> void:
	super._draw_health_bar_entry(entry)
	_record_hud_draw("health_bars")

# hud-03 (57af3dda7) dispatches bars and actor details separately in depth
# order. Observe both real paint boundaries rather than its retired wrapper.
func _draw_unit_hud_details(units: Array[Dictionary]) -> void:
	super._draw_unit_hud_details(units)
	_record_hud_draw("unit_huds")

func _draw_health_damage_preview(unit: Dictionary, rect: Rect2, preview: Dictionary) -> void:
	super._draw_health_damage_preview(unit, rect, preview)
	_record_hud_draw("damage_preview_overlays")

func _draw_health_bar_text(unit: Dictionary, rect: Rect2, preview: Dictionary, font: Font) -> void:
	super._draw_health_bar_text(unit, rect, preview, font)
	_record_hud_draw("damage_preview_overlays")

func _draw_slice_hud_chips() -> void:
	super._draw_slice_hud_chips()
	_record_hud_draw("damage_preview_overlays")

func _draw_slice_intent_orders(badges: Array[Dictionary]) -> void:
	super._draw_slice_intent_orders(badges)
	_record_hud_draw("damage_preview_overlays")

func _draw_slice_intent_halo(badge: Dictionary) -> void:
	super._draw_slice_intent_halo(badge)
	_record_hud_draw("damage_preview_overlays")

func _draw_slice_intent_chip(badge: Dictionary) -> void:
	super._draw_slice_intent_chip(badge)
	_record_hud_draw("damage_preview_overlays")

func observe_callout(_layout: Dictionary, layer: Control) -> void:
	draw_events.append({"kind": "callout", "layer": layer, "frame": Engine.get_process_frames()})

static func verify(canvas: SubViewport, state: Dictionary, settle_frames: int, expect: Callable) -> void:
	var board: Control = load("res://tests/helpers/enemy_no_action_hud_observer.gd").new()
	board.size = canvas.size
	canvas.add_child(board)
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"show_all_enemy_intents": true})
	for _frame: int in range(settle_frames): await canvas.get_tree().process_frame
	var hud: Control = board.get("_hud_render_layer")
	var effects: Control = board.get("_effects_render_layer")
	var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	shown["intent_callouts"] = [{"actor_key": "enemy_1", "text": "Redirected"}]
	(board.get("redraw_requests") as Array).clear()
	_submit(board, shown)
	# Read synchronously: idle animation/pulsing cannot mask this submission's
	# exact request by independently redrawing the HUD on a later process frame.
	expect.call(board.get("redraw_requests") == ["hud"], "Callout-only addition requests exactly the HUD redraw")
	(board.get("draw_events") as Array).clear()
	for layer: Control in board.call("_retained_render_layers"):
		layer.set("draw_events", board.get("draw_events"))
		# Slices forward this signal to their base layer; observe it once there.
		if not bool(layer.get("_is_layer_slice_canvas")):
			layer.connect("intent_callout_drawn", Callable(board, "observe_callout").bind(layer))
	# Exercise every possible draw owner after observing the isolated request.
	# A misplaced draw must identify its wrong layer, even if it was retained.
	for layer: Control in board.call("_retained_render_layers"): layer.queue_redraw()
	for _frame: int in range(settle_frames): await canvas.get_tree().process_frame
	var events: Array = board.get("draw_events")
	var callouts: int = 0
	var owner_correct: bool = true
	var order_correct: bool = true
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		if event["kind"] != "callout": continue
		callouts += 1
		owner_correct = owner_correct and event["layer"] == hud
		for section: String in ["health_bars", "unit_huds", "damage_preview_overlays"]:
			var prior: bool = false
			for other_index: int in range(events.size()):
				var other: Dictionary = events[other_index]
				if other["kind"] != section or other["layer"] != hud or other["frame"] != event["frame"]: continue
				if other_index < index: prior = true
				else: order_correct = false
			order_correct = order_correct and prior
	expect.call(callouts > 0, "Actual callout text draw submissions were observed")
	expect.call(owner_correct and hud.z_index >= effects.z_index and hud.get_index() > effects.get_index(), "Actual callout text is owned by the HUD layer above effects")
	var hud_kinds: Array = []
	for event: Dictionary in events:
		if event["layer"] == hud: hud_kinds.append(str(event["kind"]))
	expect.call(order_correct, "Actual callout text draws after actor HUDs and all HUD overlays/badges in the same frame: " + ",".join(hud_kinds))
	shown = (board.get("presentation") as Dictionary).duplicate(true)
	shown.erase("intent_callouts")
	(board.get("redraw_requests") as Array).clear()
	_submit(board, shown)
	expect.call(board.get("redraw_requests") == ["hud"], "Callout-only expiry requests exactly the HUD redraw")
	expect.call(((hud.get("presentation") as Dictionary).get("intent_callouts", []) as Array).is_empty(), "Expired callout is removed from its actual HUD draw owner")
	board.queue_free()
	await canvas.get_tree().process_frame

static func _submit(board: Control, shown: Dictionary) -> void:
	board.call("set_combat_state", board.get("combat_state"), board.get("move_tiles"), board.get("attack_tiles"), board.get("selected_tile"), board.get("status_label"), board.get("status_detail"), board.get("exit_tiles"), board.get("exit_icon_ids"), shown)
