extends Node
## Adapter for the inherited ux-09/perf-97 controller route. No product patches.
const Route = preload("res://tools/hitch_census/demo/route.gd")
const Gate = preload("res://tools/hitch_census/demo/input_gate.gd")
const DemoEnd = preload("res://scripts/demo_end_panel.gd")
signal process_frame
var host: SceneTree
var input_gate: Node
var driver: RefCounted
var milestones: Array[String]
var external_request_count: int = 0
var failure: String = ""
var output: String:
	get: return host.output
var proof_seed: int:
	get: return host.run_seed
var root: Window:
	get: return host.root
var current_scene: Node:
	get: return host.current_scene

func run() -> void:
	host.census_finished.connect(func() -> void: failure = "census_stopped")
	host.process_frame.connect(func() -> void: process_frame.emit())
	DemoEnd.store_page_override_for_test = func() -> void: external_request_count += 1; log_event("external_link_suppressed")
	DemoEnd.shell_open = func(_url: String) -> int: external_request_count += 1; log_event("external_link_suppressed"); return OK
	input_gate = Gate.new()
	input_gate.session = self
	host.root.add_child(input_gate)
	driver = Route.new(self)
	host.change_scene_to_file("res://scenes/startup.tscn")
	await driver.run()

func hold(seconds: float) -> void:
	if host.finished: await process_frame
	await host.hold(seconds)
	if host.finished: await process_frame

func mark(label: String) -> void:
	if milestones.has(label): return
	milestones.append(label)
	host.mark("demo:" + label, "controller_route")
	print("HITCH DEMO MILESTONE: " + label)
	await process_frame

func log_event(kind: String, data: Dictionary = {}) -> void:
	if host.finished: return
	if kind == "input": host.mark("controller:" + str(data.get("event", "input")), "controller_input")
	var started: int = Time.get_ticks_usec()
	host.decisions.store_line(JSON.stringify({"kind": kind, "frame": Engine.get_process_frames(), "data": data, "decision": host.trace.decision}))

	host.trace.record_driver_cost("controller_log", started)

func fail(reason: String) -> void:
	if not failure.is_empty(): return
	failure = reason
	host.errors.append(reason)
	finish(false)

func finish(passed: bool) -> void:
	if passed and input_gate.accepted != int(driver.inputs["joypad_button"]) + int(driver.inputs["joypad_motion"]):
		host.errors.append("Controller input gate count mismatch")
	var receipt: Dictionary = {"passed": passed and host.errors.is_empty(), "milestones": milestones, "inputs": driver.inputs, "input_gate_accepted": input_gate.accepted, "failure": failure}
	FileAccess.open(host.output.path_join("route.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt, "\t"))
	host.finish("demo_complete" if passed else "demo_incomplete")
