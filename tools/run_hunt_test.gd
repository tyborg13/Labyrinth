extends "res://tools/run_hunt.gd"
## Focused harness tests: fake engine state and native Controls, no game fixture.

class FakeEngine:
	extends RefCounted
	func available_moves(_run: Dictionary) -> Array:
		return [Vector2i(-4, 0)]
	func room_metadata(_run: Dictionary, coord: Vector2i) -> Dictionary:
		return {"section_index": 1 if coord == Vector2i(-4, 0) else 0}

class FakeMap:
	extends Control
	var node_buttons: Dictionary = {}
	var enabled: bool = false
	func can_activate_room(_coord: Vector2i) -> bool:
		return enabled

class FakeBoard:
	extends Control
	var rendered: Array = [Vector2i(1, 1)]
	func controller_navigable_tiles(_doors_only: bool) -> Array:
		return rendered

class FakeFlow:
	extends RefCounted
	var pending: bool = false
	func active() -> bool:
		return pending

class FakePanel:
	extends Control
	var kind: String = "full"

class FakeScene:
	extends Node
	var _run_state: Dictionary = {"mode": "reward", "player_hp": 700, "player_max_hp": 700, "rooms": {}}
	var _combat_state: Dictionary = {"player": {"hp": 700, "max_hp": 700}}
	var _run_engine := FakeEngine.new()
	var _large_map_view: Control
	var board_view: Control
	var _run_end_recap: Control
	var _exit_destinations_by_tile: Dictionary = {}
	var _animation_lock: bool = false
	var _dialogue_active: bool = false
	var _relic_claim_in_progress: bool = false
	var _relic_delivery_phase: String = ""
	var _opening_boon_flow := FakeFlow.new()
	var saves: int = 0
	func _save_run_progress() -> void:
		saves += 1
	func _reduced_motion_enabled() -> bool:
		return false

var checks: int = 0
var failures: Array[String]
var emitted: Array[Dictionary]

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run_checks")

func _context() -> Dictionary:
	return {"seed": 23, "room_kind": "boss", "section": 0, "decision": decision}

func _finding(severity: String, message: String) -> void:
	findings.append({"severity": severity, "error": message})

func _emit(event: String, data: Dictionary) -> void:
	emitted.append({"event": event, "data": data})

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _run_checks() -> void:
	var host := FakeScene.new()
	scene = host
	root.add_child(host)
	var map := FakeMap.new()
	host._large_map_view = map
	host.add_child(map)
	var board := FakeBoard.new()
	host.board_view = board
	host.add_child(board)
	var node := Control.new()
	map.add_child(node)
	map.node_buttons[Vector2i(-4, 0)] = node
	_check_demo_map()
	_check(findings.is_empty(), "Raw outward connection in reward mode is not a selectable exit")
	map.enabled = true
	demo_map_findings.clear()
	_check_demo_map()
	_check(findings.size() == 1, "A visible map node admitted by the action gate is checked")
	findings.clear()
	demo_map_findings.clear()
	node.hide()
	_check_demo_map()
	_check(findings.is_empty(), "Hidden map nodes are not player choices")
	node.show()
	map.hide()
	_check_demo_map()
	_check(findings.is_empty(), "A hidden map panel cannot offer destinations")
	host._run_state["mode"] = "room"
	host._exit_destinations_by_tile[Vector2i(1, 1)] = Vector2i(-4, 0)
	_check_demo_map()
	_check(findings.size() == 1, "A rendered board door in room mode is checked")
	findings.clear()
	demo_map_findings.clear()
	board.rendered.clear()
	_check_demo_map()
	_check(findings.is_empty(), "A stale, unrendered board door is not selectable")
	board.rendered.append(Vector2i(1, 1))
	host._run_state["mode"] = "reward"
	_check_demo_map()
	_check(findings.is_empty(), "Board navigation is inactive during a reward")

	defeat_after_hearth = true
	host._run_state["mode"] = "combat"
	_arm_hearth_defeat()
	_check(not hearth_defeat_armed and host._combat_state["player"]["hp"] == 700, "Health is preserved before a visited Hearth")
	host._run_state["rooms"]["hearth"] = {"type": "campfire", "visited": true, "section_index": 0, "map_step": 4}
	host._run_state["mode"] = "campfire"
	_arm_hearth_defeat()
	_check(not hearth_defeat_armed, "Health is preserved while at the Hearth")
	host._run_state["mode"] = "combat"
	_arm_hearth_defeat()
	_check(hearth_defeat_armed and host._run_state["player_hp"] == 1 and host._combat_state["player"]["hp"] == 1, "Both Health fields drop at the next fight")
	_check(host._run_state["player_max_hp"] == 700 and host._combat_state["player"]["max_hp"] == 700, "The override does not alter max Health")
	_check(host.saves == 1, "The Health override is saved once")
	_arm_hearth_defeat()
	_check(host.saves == 1, "The override does not repeatedly reset Health")
	hunt_health = 0
	_apply_hunt_health()
	_check(host._run_state["player_hp"] == 1, "Health zero means no starting override")

	var recap := Control.new()
	host._run_end_recap = recap
	host.add_child(recap)
	var column := Control.new()
	recap.add_child(column)
	var panel := FakePanel.new()
	panel.name = "DemoEndPanel"
	column.add_child(panel)
	recap.hide()
	_check(_demo_panel_kind() == "none", "A hidden recap is not a shown end panel")
	recap.show()
	_check(_demo_panel_kind() == "full", "The nested visible panel supplies the observed kind")
	panel_sample_elapsed = 0.0
	panel_samples.clear()
	_sample_demo_panel(false)
	_check(panel_sample_elapsed == 0.0 and panel_samples.size() == 1, "Initial sample does not consume scene time")
	panel_sample_elapsed = DEMO_PANEL_SAMPLE_SECONDS
	_sample_demo_panel(false)
	_check(panel_sample_elapsed < 0.0 and emitted.back()["event"] == "demo_panel_samples", "The three-scene-second observation emits its samples before ending")
	panel.kind = "links"
	_check(_demo_panel_kind() == "links", "Links observations read the actual panel kind")
	for control_name: String in ["WishlistButton", "DemoWishlistLink", "DemoDiscordLink", "DemoFeedbackLink"]:
		panel.name = control_name
		_check(not _demo_safe_offer({"control": panel}), "External control is excluded: " + control_name)
	panel.name = "NewRunButton"
	_check(_demo_safe_offer({"control": panel}), "Rise Again remains available")
	host._dialogue_active = true
	_check(_demo_end_interaction_pending(), "A dialogue opened during delivery defers the end-panel check")
	host._dialogue_active = false
	host._opening_boon_flow.pending = true
	_check(_demo_end_interaction_pending(), "A late heirloom overlay defers the end-panel check")
	host._opening_boon_flow.pending = false
	_check(not _demo_end_interaction_pending(), "The end-panel check resumes after required interactions")
	host.queue_free()
	await process_frame
	for failure: String in failures: printerr("FAIL: " + failure)
	print("RUN HUNT TEST RESULT: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
