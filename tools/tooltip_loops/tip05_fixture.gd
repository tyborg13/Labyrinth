extends RefCounted
## Offline Upheaval script: the Snare selector owns both mark and landing.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Throw = preload("res://scripts/displacement_throw.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Snare = preload("res://scripts/snare_room_rules.gd")
const IDS: Array = ["rule_upheaval"]
const BIOMES: Dictionary = {"rule_upheaval": "tharokh"}
const INSTANCE: String = "snare_earth"
const PATCH := Rect2i(0, 0, 4, 3)
# Debug fixture placement only; never override the instance's authored dials.
const HERO := Vector2i(0, 2)
const CRAWLER := Vector2i(2, 2)
const EXIT := Vector2i(3, 2)

static func configure(layout: Dictionary, _id: String) -> Dictionary:
	layout["player_start"] = HERO
	layout["snare_entry"] = HERO
	layout["element"] = "earth"
	var objective: Dictionary = Snare.objective({"special_variant": "earth"})
	objective["type"] = preload("res://scripts/combat_objective_rules.gd").KILL_ALL
	objective["exits"] = [{"target_tile": EXIT, "door_tile": EXIT, "sealed": false, "kept_open": true, "role": "jailer"}]
	# The proof is the room beat only. Mark arrivals exhausted so unrelated
	# end-turn forecasts cannot add hunters to this one-Crawler fixture.
	objective["hunters_spawned"] = Snare.Library.definition("umbral_snare")["hunters_max"]
	layout["objective"] = objective
	return {"units": [["crawler", CRAWLER]], "card": ""}

static func prepare(state: Dictionary, _id: String) -> void:
	var engine := preload("res://scripts/hero_facing_combat.gd").new()
	Rules.install(engine, state, Rules.instance_for(INSTANCE))
	# Marks are already announced at the preceding activation boundary.
	# Advance that boundary, rather than changing their production provenance.
	state["turn"] = int(state["turn"]) + 1

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var before: Dictionary = fixture["state"]
	var steps: Array[Dictionary]
	var after: Dictionary = Rules.dispatch(engine, before.duplicate(true), "after_player_turn", -1, "", steps)
	if not PATCH.has_point(after["enemies"][0]["pos"]):
		return {"beats": [], "final": after, "todo_design": "TODO_DESIGN_rule_upheaval: The room's production landing is outside the 4x3 patch."}
	return {"beats": [{"kind": "room_rule", "before": before, "after": after, "steps": steps}], "final": after}

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var failures: Array[String]
	if not str(result.get("todo_design", "")).is_empty(): return failures
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	var instance: Dictionary = Rules.instance_for(INSTANCE)
	if before["battlefield_rule"]["dials"] != instance["dials"] or after["battlefield_rule"]["dials"] != instance["dials"]: failures.append("Upheaval must retain snare_earth's authored dials")
	if before["battlefield_rule"]["source"] != instance["source"] or int(after["battlefield_rule"]["beats_fired"]) != 1: failures.append("Exactly one room-sourced Upheaval beat must fire")
	if before["enemies"].size() != 1 or before["enemies"][0]["type"] != "crawler": failures.append("Upheaval must show one Crawler")
	if Paths.manhattan(before["player"]["pos"], before["enemies"][0]["pos"]) != 2 or Surfaces.element_at(before, before["player"]["pos"]) != "": failures.append("Upheaval hero must stand two tiles away on plain floor")
	if after["player"] != before["player"]: failures.append("Upheaval must leave the hero untouched")
	if before["battlefield_rule"].get("marks", []) != [CRAWLER]: failures.append("The real exit-lane selector must mark the Crawler's tile")
	var outcrop: bool = false
	for terrain: Dictionary in after["terrain"]:
		if terrain["pos"] == CRAWLER and terrain.get("kind") == "crag_outcrop" and int(terrain["hp"]) == int(instance["dials"]["health"]): outcrop = true
	if not before["terrain"].is_empty() or not outcrop: failures.append("The marked open floor must rise as the production Outcrop")
	var flights: Array[Dictionary] = Throw.paths(before, after)
	if flights.size() != 1 or flights[0]["actor_key"] != "enemy_1" or flights[0]["from"] != CRAWLER or flights[0]["to"] != after["enemies"][0]["pos"]: failures.append("The production throw must carry only the Crawler to the resolver's landing")
	if not PATCH.has_point(after["enemies"][0]["pos"]): failures.append("The production landing must remain inside the patch")
	return failures

static func play(scene: Node, beat: Dictionary) -> void:
	# This is the production Upheaval path, including uph-01's throw and numbers.
	await scene.call("_animate_surface_change", beat["before"], beat["after"])
