extends RefCounted
## Replay the census's recorded Tharokh decision states and plans through joypad input.

const DemoRoute = preload("res://tools/hitch_census/demo/route.gd")
const Joypad = preload("res://tools/hitch_census/demo/joypad.gd")
const HudAssertion = preload("res://tools/perf148/hud_assertion.gd")
const FPS: int = 60
const WATCH_FRAMES: int = 2

class Session extends RefCounted:
	var probe: SceneTree
	var board_trace: RefCounted
	var samples: Array[Dictionary]
	var start: Dictionary = {}
	var output: String
	var host: RefCounted:
		get: return self
	var trace: RefCounted:
		get: return self
	var current_scene: Node:
		get: return probe._scene
	var root: Window:
		get: return probe.root
	var process_frame: Signal:
		get: return probe.process_frame

	func hold(seconds: float) -> void:
		await probe._wait_frames(ceili(seconds * FPS))

	func record_driver_cost(_section: String, _started: int) -> void:
		pass

	func log_event(_kind: String, _data: Dictionary = {}) -> void:
		pass

	func fail(message: String) -> void:
		probe._errors.append(message)

	func button_down(button: int) -> void:
		var live: Node = current_scene
		if button not in [JOY_BUTTON_A, JOY_BUTTON_Y] or not start.is_empty(): return
		start = {"button": button, "start_frame": Engine.get_process_frames(),
			"turn": live._combat_state["turn"], "selected": live._selected_card_index,
			"walking": live._player_movement_selected, "action_index": live._pending_action_index}
		board_trace.begin()
		await probe._wait_frames(WATCH_FRAMES)
		start["draws"] = board_trace.finish()
		samples.append(start)
		start = {}

class ReplayJoy extends Joypad:
	func send(event: InputEvent) -> void:
		if event is InputEventJoypadButton and event.pressed:
			session.button_down(event.button_index)
		session.probe._canvas.push_input(event, true)

class Route extends DemoRoute:
	var archived_plan: Dictionary

	func _init(session: Session, plan: Dictionary) -> void:
		super(session)
		archived_plan = plan
		pad = ReplayJoy.new(session)

	func _measured_bot(method: String, state: Dictionary) -> Dictionary:
		if method == "choose": return archived_plan.duplicate(true)
		return super._measured_bot(method, state)

static func run(probe: SceneTree) -> Dictionary:
	if not _has_tharokh(probe._scene._combat_state): return {}
	var source: String = probe._argument("--census-archive=")
	var fixture: Dictionary = probe._fixtures["tharokh"]
	var limit: int = int(probe._argument("--archive-limit="))
	var results: Dictionary = {}
	var assertions: Dictionary = {}
	for name: String in DirAccess.get_files_at(source):
		if not name.begins_with("decision-") or not name.ends_with(".bin"): continue
		var file := FileAccess.open(source.path_join(name), FileAccess.READ)
		if file == null: continue
		var row: Dictionary = file.get_var(false)
		file.close()
		if not _has_tharokh(row.get("state", {})): continue
		probe._scene.queue_free()
		await probe._wait_frames(2)
		var state: Dictionary = fixture.duplicate(true)
		state["combat_state"] = row["state"]
		state["player_hp"] = row["state"]["player"]["hp"]
		state["player_max_hp"] = row["state"]["player"]["max_hp"]
		probe._fixtures["tharokh"] = state
		if not await probe._open("tharokh"): break
		var session := Session.new()
		session.probe = probe
		session.output = probe._output.path_join(name.get_basename())
		DirAccess.make_dir_recursive_absolute(session.output)
		session.board_trace = probe._board.get("_board_redraw_trace")
		if session.board_trace == null:
			probe._errors.append("Enable LABYRINTH_BOARD_REDRAW_TRACE")
			break
		var route := Route.new(session, row["plan"])
		route.scene = probe._scene
		var initial: String = probe._combat_digest(probe._scene._combat_state)
		await route.combat()
		await probe._wait_for_action()
		var final: String = probe._combat_digest(probe._scene._combat_state)
		results[name] = {"samples": session.samples, "initial": initial, "final": final}
		var verified: Dictionary = await HudAssertion.verify(probe)
		for method: String in verified: assertions[method] = int(assertions.get(method, 0)) + int(verified[method])
		if session.samples.is_empty() or initial == final:
			probe._errors.append("Archived decision did not execute: " + name)
		if not probe._errors.is_empty() or (limit > 0 and results.size() >= limit): break
	if results.is_empty(): probe._errors.append("No Tharokh decisions in census archive " + source)
	var count: int = 0
	for result: Dictionary in results.values(): count += result["samples"].size()
	print("PERF-148 ARCHIVE REPLAY: %d Tharokh decisions, %d A/Y presses" % [results.size(), count])
	var trace: RefCounted = probe._board.get("_board_redraw_trace")
	if trace != null and trace.resolve_inputs and not trace.confirm_baseline:
		for method: String in ["_draw_health_bar_entry", "_draw_slice_intent_chip", "_draw_unit_hud_details"]:
			if not assertions.has(method): probe._errors.append("Missing retained HUD repaint coverage: " + method)
		print("PERF-148 HUD REPAINT RECEIPTS: %s %s" % ["PASS" if probe._errors.is_empty() else "FAIL", assertions])
	return results

static func _has_tharokh(state: Dictionary) -> bool:
	return (state.get("enemies", []) as Array).any(func(enemy: Dictionary) -> bool: return str(enemy.get("type", "")) == "tharokh")
