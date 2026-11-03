extends "res://scripts/combat_board_view.gd"
## Test-only observation at the real invalidation and draw dispatch boundaries.

var redraw_requests: Array[String]
var draw_events: Array[Dictionary]

func _queue_render_layer_redraw(layer: Control) -> void:
	if is_instance_valid(layer): redraw_requests.append(str(layer.get("_render_layer_kind")))
	super._queue_render_layer_redraw(layer)

func _record_render_section_time(section: String, started_usec: int) -> void:
	if section in ["unit_huds", "damage_preview_overlays"]:
		draw_events.append({"kind": section, "layer": self, "frame": Engine.get_process_frames()})
	super._record_render_section_time(section, started_usec)

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
	for layer: Control in board.call("_retained_render_layers"):
		layer.set("draw_events", board.get("draw_events"))
		layer.connect("intent_callout_drawn", Callable(board, "observe_callout").bind(layer))
	var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	shown["intent_callouts"] = [{"actor_key": "enemy_1", "text": "Redirected"}]
	(board.get("redraw_requests") as Array).clear()
	_submit(board, shown)
	# Read synchronously: idle animation/pulsing cannot mask this submission's
	# exact request by independently redrawing the HUD on a later process frame.
	expect.call(board.get("redraw_requests") == ["hud"], "Callout-only addition requests exactly the HUD redraw")
	(board.get("draw_events") as Array).clear()
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
		for section: String in ["unit_huds", "damage_preview_overlays"]:
			var prior: bool = false
			for earlier: Dictionary in events.slice(0, index):
				if earlier["kind"] == section and earlier["layer"] == hud and earlier["frame"] == event["frame"]: prior = true
			order_correct = order_correct and prior
	expect.call(callouts > 0, "Actual callout text draw submissions were observed")
	expect.call(owner_correct and hud.z_index >= effects.z_index and hud.get_index() > effects.get_index(), "Actual callout text is owned by the HUD layer above effects")
	expect.call(order_correct, "Actual callout text draws after actor HUDs and all HUD overlays/badges in the same frame")
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
