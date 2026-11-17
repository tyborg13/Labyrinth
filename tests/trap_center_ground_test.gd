extends SceneTree
## Only trap-rule acceptance cases. UI/recording checks live with their tools.
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const CENTER := Vector2i(4, 3)
const ENTRY := Vector2i(3, 3)
const ELEMENTS: Array = ["fire", "ice", "lightning", "earth", "air"]
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := Combat.new()
	for element: String in ELEMENTS:
		for cause: String in ["hero", "enemy", "attack", "disarm"]: _trigger(engine, element, cause)
		_forecast(engine, element)
		_blocked_center(engine, element)
		_damage_before_ground(engine, element)
	for failure: String in failures: push_error(failure)
	print("TRP01 TRAP RULES: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func fixture(engine: RefCounted, element: String) -> Dictionary:
	var state: Dictionary = Base.fixture(engine)
	state["traps"] = [Rooms.new()._trap_for_tile(CENTER, element, 1)]
	state["enemies"].append(Base.enemy(2, CENTER + Vector2i.RIGHT))
	return state

func _trigger(engine: RefCounted, element: String, cause: String) -> void:
	var state: Dictionary = fixture(engine, element)
	var action: Dictionary
	if cause in ["hero", "disarm"]:
		state["enemies"][0]["pos"] = Vector2i(7, 6)
		state["player"]["pos"] = ENTRY
		if cause == "disarm":
			state["skill_ids"] = ["sure_footed"]
		action = {"type": "move", "range": 1}
	else:
		action = {"type": "ranged", "damage": 1, "range": 5, "element": "none"}
	var before: Dictionary = state.duplicate(true)
	var damage: int = int(state["traps"][0]["base_damage"])
	var after: Dictionary
	if cause == "enemy":
		state["enemies"][0]["pos"] = ENTRY
		before = state.duplicate(true)
		var path: Array[Vector2i]
		path.assign([ENTRY, CENTER])
		after = engine._move_enemy_along_planned_path(state.duplicate(true), 0, path, {"committed": true}, 1)
	else:
		var preview: Dictionary = engine.surface_preview_for_player_action(before, action, CENTER)
		after = engine.apply_player_action(before, action, CENTER)
		check(preview["state"] == after, "%s/%s preview matches the committed trap outcome" % [element, cause])
		var scene := RunScene.new()
		scene._combat_state = before
		scene._hovered_board_tile = CENTER
		var shown: Dictionary = {}
		scene._append_surface_action_preview(shown, {"state": before, "action": action, "target_tiles": [CENTER]})
		check((shown.get("trap_trigger_previews", []) as Array).size() == 1, "%s/%s retains the trap trigger preview" % [element, cause])
		if element != "air": check(_created_at(shown.get("surface_preview_events", []), CENTER, Ground.kind(element)), "%s/%s previews center ground" % [element, cause])
		scene.free()
	_ground(engine, before, after, element, cause)
	if cause in ["hero", "disarm"]:
		check(int(after["player"]["hp"]) == int(before["player"]["hp"]) - (0 if cause == "disarm" else damage), "%s/%s keeps damage/disarm and has no immediate ground contact" % [element, cause])
		check(not after["player"].get("chilled", false) and int(after["player"].get("shock", 0)) == 0, "Fresh trap ground does not immediately apply a status")
	else:
		check(int(before["enemies"][0]["hp"]) - int(after["enemies"][0]["hp"]) == damage + (1 if cause == "attack" else 0), "%s/%s keeps center damage before placement, with no extra contact" % [element, cause])
		check(not after["enemies"][0].get("chilled", false), "Fresh trap Ice does not Chill its center occupant")
	print("TRP01 TRIGGER %s/%s: %s" % [element, cause, "PASS" if failures.is_empty() else "FAIL"])

func _ground(engine: RefCounted, before: Dictionary, after: Dictionary, element: String, cause: String) -> void:
	check(after["traps"].is_empty(), "%s/%s removes the triggered trap once" % [element, cause])
	var events: Array = after.get("surface_events", [])
	var triggers: Array = events.filter(func(event: Dictionary) -> bool: return event.get("kind") == "trap_triggered")
	check(triggers.size() == 1, "Exactly one trap event")
	if triggers.is_empty(): return
	check(triggers[0].get("center_surface", "missing") == ("" if element == "air" else Ground.kind(element)), "Additive center_surface is normalized")
	check(engine.trap_wake_tiles(before, before["traps"][0]).size() == 4 and not engine.trap_wake_tiles(before, before["traps"][0]).has(CENTER), "trap_wake_tiles keeps four-neighbor meaning")
	if element == "air":
		check(after["surfaces"].is_empty() and after["enemies"][1]["pos"] == CENTER + Vector2i.RIGHT * 2, "Air still pushes outward 1 and creates no ground")
	else:
		var tiles: Array[Vector2i] = engine.trap_ground_tiles(before, before["traps"][0])
		check(tiles.size() == 5 and tiles.has(CENTER) and Ground.tiles(after).size() == 5, "All five and only five tiles receive ground")
		for tile: Vector2i in tiles:
			check(Ground.has_surface(after, tile, Ground.kind(element)), "%s/%s ground at %s" % [element, cause, tile])
			var layer: String = "rubble_source" if element == "earth" else "elemental_source"
			var source: Dictionary = Ground.surface_at(after, tile).get(layer, {})
			check(source.get("actor_kind") == "trap" and source.get("tile") == CENTER, "Center and neighbors retain the same trap placement source")

func _forecast(engine: RefCounted, element: String) -> void:
	var state: Dictionary = fixture(engine, element)
	state["player"]["pos"] = CENTER
	state["enemies"][0]["pos"] = ENTRY
	state["enemies"][0]["intent"] = {"id": "trap_proof", "name": "Trap proof", "actions": [{"type": "melee", "damage": 1, "range": 1, "element": "none"}]}
	var before: Dictionary = state.duplicate(true)
	var scheduled: Dictionary = engine.finish_player_activation(state)
	var preview: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled)
	var actual: Dictionary = engine.advance_to_next_player_turn_with_steps(scheduled)
	check(state == before, "Pass preview does not mutate the live state")
	check(preview["state"]["traps"].is_empty() and actual["state"]["traps"].is_empty(), "Pass forecast and execution trigger the trap")
	check(preview["state"]["surfaces"] == actual["state"]["surfaces"], "Pass forecast ground equals committed ground")
	if element == "air": check(preview["state"]["surfaces"].is_empty(), "Air forecast has no ground")
	else: check(Ground.has_surface(preview["state"], CENTER, Ground.kind(element)), "Pass forecast includes the center ground")
	print("TRP01 FORECAST %s: %s" % [element, "PASS" if failures.is_empty() else "FAIL"])

func _blocked_center(engine: RefCounted, element: String) -> void:
	var state: Dictionary = fixture(engine, element)
	state["terrain"] = [{"id": "blocked_center", "kind": "wooden_crate", "pos": CENTER, "hp": 1000, "max_hp": 1000}]
	state = engine._trigger_trap_at_index(state, 0)
	check(Ground.surface_at(state, CENTER).is_empty(), "Normal can_place rule rejects blocked center ground")
	for event: Dictionary in state["surface_events"]:
		if event.get("kind") == "trap_triggered": check(event.get("center_surface", "missing") == "", "Blocked center reports empty center_surface")

func _created_at(events: Array, tile: Vector2i, surface: String) -> bool:
	return events.any(func(event: Dictionary) -> bool: return event.get("kind") == "surface_created" and event.get("tile") == tile and event.get("surface") == surface)

func _damage_before_ground(engine: RefCounted, element: String) -> void:
	if element == "air": return
	var state: Dictionary = fixture(engine, element)
	state["enemies"][0]["hp"] = 1
	state = engine._trigger_trap_at_index(state, 0)
	var death: int = -1
	var ground: int = -1
	for event: Dictionary in state["surface_events"]:
		if event.get("kind") == "actor_death" and event.get("id") == 1: death = int(event["sequence"])
		if event.get("kind") == "surface_created" and event.get("tile") == CENTER: ground = int(event["sequence"])
	check(death > 0 and ground > death, "Trap center damage/death resolves before center ground placement")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
