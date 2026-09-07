extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_scene.gd")

var errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var combat := Combat.new()
	var scene := Run.new()
	var checks: Array[Dictionary]
	var actions: Array = [
		{"type": "ranged", "damage": 20, "range": 6, "element": "lightning", "chain": 2},
		{"type": "ranged", "damage": 20, "range": 6, "element": "lightning"},
		{"type": "ranged", "damage": 20, "range": 6, "element": "ice"},
		{"type": "ranged", "damage": 20, "range": 6, "element": "none", "chain": 2, "push": 1},
		{"type": "aoe", "damage": 20, "range": 6, "element": "fire", "surface": "fire", "pattern": [[0,0],[1,0],[-1,0],[0,1],[0,-1]], "rotate": false},
		{"type": "aoe", "damage": 20, "range": 6, "element": "lightning", "chain": 2, "pattern": [[0,0],[1,0],[2,0]], "rotate": false},
		{"type": "detonate", "damage": 60, "range": 6},
		{"type": "move", "range": 3},
	]
	for stage: String in ["clear", "pressing", "heart"]:
		for network: String in ["connected", "islands", "conductive_fire"]:
			var state: Dictionary = Base.fixture(combat)
			state["umbra"]["stage"] = stage
			state["umbra"]["light_sources"] = [{"pos": Vector2i(7, 3), "radius": 1, "duration": 3}]
			state["relics"] = ["coalheart_crucible", "thunder_relay", "pilgrim_boots", "cold_mirror", "black_sun_dial"]
			state["surface_rule_overrides"] = {"conductive_fire": network == "conductive_fire"}
			state["enemies"].append(Base.enemy(2, Vector2i(7, 3)))
			state["enemies"].append(Base.enemy(3, Vector2i(6, 5)))
			state["enemies"][2]["footprint"] = Vector2i(2, 2)
			state["traps"] = [{"id": "hidden_wake", "pos": Vector2i(5, 3), "element": "fire", "damage": 20}]
			for y: int in range(2, 7):
				for x: int in range(3, 9):
					if network == "islands" and x == 6: continue
					Ground.place(state, Vector2i(x, y), "fire" if network == "conductive_fire" else "electrified")
			Ground.place(state, Vector2i(4, 3), "rubble")
			Ground.place(state, Vector2i(5, 4), "ice")
			var before: Dictionary = state.duplicate(true)
			for action: Dictionary in actions:
				var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
				var signature: Array = []
				for tile: Vector2i in targets:
					var reference: Dictionary = combat.resolve_player_action_for_presentation(state, action, tile)
					var preview: Dictionary = combat.surface_preview_for_player_action(state, action, tile)
					_check(reference["state"] == preview["state"] and _route(reference) == _route(preview), "Preview must retain exact state and route")
					signature.append({"tile": tile, "state": hash(reference["state"]), "route": _route(reference)})
					# Compare live damage/surface presentation with the prior separate
					# resolvers, including filtering causes under limited Umbra.
					scene.set("_combat_state", state)
					scene.set("_hovered_board_tile", tile)
					scene.set("_selected_card_index", 0)
					scene.call("_mark_preview_selection_changed")
					var known: Dictionary = scene.call("_surface_preview_information_state", state)
					var known_after: Dictionary = combat.apply_prevalidated_player_action(known, action, tile)
					var expected_damage: Dictionary = scene.call("_sanitize_damage_preview_for_umbra_information", state, scene.call("_damage_preview_between_states", known, known_after))
					var actual_damage: Dictionary = scene.call("_preview_damage_for_action", state, action, tile)
					if str(action["type"]) != "move": _check(actual_damage == expected_damage, "Live damage must match uncached information-safe resolution")
					if str(action["type"]) == "move" and bool(scene.call("_preview_umbra_is_limited", state)): continue
					var expected: Dictionary = combat.resolve_player_action_for_presentation(known, action, tile)
					var shown: Dictionary = {}
					scene.call("_append_surface_action_preview", shown, {"state": state, "action": action, "target_tiles": targets})
					_check(shown.get("surface_preview_events") == scene.call("_surface_events_between", known, expected["state"]), "Live surface events must match validated information-safe resolution")
					_check(shown.get("surface_preview_arcs") == _arcs(expected), "Live Chain arcs must match validated information-safe route")
				checks.append({"stage": stage, "network": network, "action": action, "targets": targets.size(), "digest": hash(signature)})
			_check(state == before, "Preview must not mutate source, event history, or RNG")
	_test_relic_ownership()
	_test_preview_edges(combat, scene)
	scene.free()
	print("SURFACE PREVIEW EQUIVALENCE RESULT: " + JSON.stringify({"cases": checks, "semantic_errors": errors}))
	quit(0 if errors.is_empty() else 1)

func _route(result: Dictionary) -> Array:
	var route: Array = []
	for hit: Dictionary in result.get("chain_hits", []):
		var metadata: Dictionary = hit.duplicate(false)
		metadata.erase("state")
		route.append(metadata)
	return route

func _arcs(result: Dictionary) -> Array:
	var arcs: Array = []
	for hit: Dictionary in result.get("chain_hits", []):
		arcs.append({"kind": hit.get("kind", "actor"), "from": hit.get("from", Vector2i(-1, -1)), "to": hit.get("to", Vector2i(-1, -1)), "path": hit.get("path", [])})
	return arcs

func _test_relic_ownership() -> void:
	for id: String in Data.relic_ids():
		var definition: Dictionary = Data.relic_def(id)
		var expected: Array = []
		for effect: Dictionary in definition.get("effects", []):
			var entry: Dictionary = effect.duplicate(true)
			entry["relic_id"] = id
			expected.append(entry)
		if expected.is_empty() and not str(definition.get("effect", "")).is_empty():
			expected.append({"type": definition["effect"], "value": int(definition.get("value", 0)), "relic_id": id})
		var actual: Array[Dictionary] = Data.relic_effects(id)
		_check(actual == expected, "Raw relic expansion must match authored definition: " + id)
		if not actual.is_empty():
			actual[0].clear()
			_check(Data.relic_effects(id) == expected, "Returned relic effects must remain independently mutable: " + id)

func _test_preview_edges(combat: Combat, scene: Node) -> void:
	var state: Dictionary = Base.fixture(combat)
	state["umbra"]["stage"] = "clear"
	state["relics"] = ["thunder_relay", "thornmail_brooch", "worldroot_idol"]
	state["player"]["stoneskin"] = 4
	state["enemies"].append(Base.enemy(3, Vector2i(2, 4)))
	state["enemies"].append(Base.enemy(2, Vector2i(6, 3)))
	for x: int in range(2, 7):
		Ground.place(state, Vector2i(x, 3), "rubble")
		Ground.place(state, Vector2i(x, 3), "electrified")
		Ground.place(state, Vector2i(x, 4), "rubble")
	# Ground was placed before the blocker, exercising a directed component start.
	state["terrain"] = [{"id": "blocked_conductor", "kind": "wooden_box", "pos": Vector2i(3, 3), "hp": 30, "max_hp": 30}]
	var actions: Array = [
		{"type": "melee", "range": 1, "damage": 5, "_surface_relic_modes": ["cross"]},
		{"type": "ranged", "range": 5, "damage": 20, "chain": 2, "_surface_relic_modes": ["swap"]},
		{"type": "ranged", "range": 2, "damage": 20, "element": "lightning", "_surface_relic_modes": ["remote"], "_origin_tile": Vector2i(4, 3)},
	]
	for action: Dictionary in actions:
		var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
		_check(not targets.is_empty(), "Technique edge fixture must have legal targets: " + str(action["_surface_relic_modes"]))
		for tile: Vector2i in targets:
			var reference: Dictionary = combat.resolve_player_action_for_presentation(state, action, tile)
			var preview: Dictionary = combat.surface_preview_for_player_action(state, action, tile)
			_check(reference["state"] == preview["state"] and _route(reference) == _route(preview), "Technique and blocked-conductor previews preserve routes, payment and outcomes")
			if scene.has_method("_surface_resolution_for_preview"):
				var fast: Dictionary = combat.call("surface_preview_for_player_action", state, action, tile, true)
				_check(fast["state"] == reference["state"] and _route(fast) == _route(reference), "Prevalidated technique retains exact public result")
				for hit: Dictionary in fast["chain_hits"]:
					_check(not hit.has("state"), "Hover route must omit intermediate animation snapshots")
				for hit: Dictionary in reference["chain_hits"]:
					_check(hit.has("state"), "Committed Chain animation must retain every intermediate snapshot")
		var rejected: Dictionary = combat.surface_preview_for_player_action(state, action, Vector2i(99, 99))
		_check(rejected["state"] == state and (rejected["chain_hits"] as Array).is_empty(), "Public surface preview must still reject an invalid target without payment")
	if not scene.has_method("_surface_resolution_for_preview"): return
	state = Base.fixture(combat)
	state["umbra"]["stage"] = "clear"
	var action: Dictionary = {"type": "ranged", "range": 5, "damage": 20, "surface": "fire"}
	var tile := Vector2i(4, 3)
	var alternative: Dictionary = state.duplicate(true)
	alternative["enemies"][0]["hp"] = 50
	scene.set("_pending_actions", scene.call("_dictionary_array", [action]))
	scene.set("_pending_action_index", 0)
	scene.set("_hovered_board_tile", tile)
	scene.set("_selected_card_index", 0)
	scene.call("_mark_preview_selection_changed")
	for source: Dictionary in [state, alternative, state]:
		scene.set("_combat_state", source)
		var after: Dictionary = combat.apply_player_action(source, action, tile)
		var first: Dictionary = {}
		var preview: Dictionary = {"state": source, "action": action, "target_tiles": [tile]}
		var damage: Dictionary = scene.call("_preview_damage_for_action", source, action, tile)
		scene.call("_append_surface_action_preview", first, preview)
		_check(first.get("damage_preview") == damage and damage == scene.call("_damage_preview_between_states", source, after), "Same-revision A/B/A source changes must not reuse stale outer surface losses")
		var engine: RefCounted = scene.get("_combat_engine") as RefCounted
		engine.call("set_runtime_performance_instrumentation_enabled", true)
		var repeated: Dictionary = {}
		scene.call("_preview_damage_for_action", source, action, tile)
		scene.call("_append_surface_action_preview", repeated, preview)
		_check(first == repeated and (engine.call("runtime_performance_instrumentation_snapshot") as Dictionary).is_empty(), "Repeated damage/surface cache hits must not resolve combat again")
		engine.call("set_runtime_performance_instrumentation_enabled", false)
	var followup: Dictionary = {"type": "detonate", "damage": 30, "range": 1, "target": "previous_target"}
	scene.set("_pending_actions", scene.call("_dictionary_array", [action, followup]))
	var shown: Dictionary = {}
	scene.call("_append_surface_action_preview", shown, {"state": state, "action": action, "target_tiles": [tile]})
	var single: Dictionary = combat.apply_player_action(state, action, tile)
	var final_state: Dictionary = combat.apply_player_action(single, followup)
	_check(shown.get("surface_preview_events") == scene.call("_surface_events_between", state, final_state), "Automatic followup changes must invalidate outer feedback in the same revision")
	var cached: Dictionary = scene.call("_surface_resolution_for_preview", state, action, tile)
	_check(cached["actual"]["state"] == single, "Followups must not mutate the shared single-action turn-risk result")

func _check(condition: bool, message: String) -> void:
	if not condition and not errors.has(message): errors.append(message)
