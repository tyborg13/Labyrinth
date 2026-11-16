extends RefCounted
## Director-authored rule scripts, dispatched by the room's unchanged instance.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const IDS: Array = ["rule_gust", "rule_wildfire", "rule_frostbite", "rule_shadowstep"]
const INSTANCES: Dictionary = {"rule_gust": "snare_air", "rule_wildfire": "snare_fire", "rule_frostbite": "snare_ice", "rule_shadowstep": "snare_shadow"}
const BIOMES: Dictionary = {"rule_gust": "vaeloryx", "rule_wildfire": "vyraketh", "rule_frostbite": "iskaldra", "rule_shadowstep": "noctyrax"}
const PATCH := Rect2i(0, 0, 4, 3)
const GUST_HERO := Vector2i(2, 2)
const GUST_CRAWLER := Vector2i(0, 2)
const GUST_ENTRY := Vector2i(0, 1)
const GUST_AXIS := Vector2i.UP
const FROST_CRAWLER := Vector2i(1, 1)
const WILDFIRE_HERO := Vector2i(3, 2)
const WILDFIRE_ENTRY := Vector2i(1, 2)
const WILDFIRE_TILES: Array = [Vector2i(0, 2), Vector2i(1, 2)]
const WILDFIRE_NEW := Vector2i(2, 2)
const SHADOW_HERO := Vector2i(0, 2)
const SHADOW_ENEMY := Vector2i(3, 1)
const SHADOW_STAGE: String = "heart" # Canonical Shadowstep proof stage: sight 2, hidden origin 4 away.
const Blink = preload("res://scripts/enemy_mechanics/stalker.gd")
const BlinkView = preload("res://scripts/enemy_mechanics/stalker_view.gd")

static func configure(layout: Dictionary, id: String) -> Dictionary:
	layout["objective"] = {"type": preload("res://scripts/combat_objective_rules.gd").KILL_ALL}
	layout["element"] = {"rule_gust": "air", "rule_wildfire": "fire", "rule_frostbite": "ice", "rule_shadowstep": "shadow"}[id]
	# Fixture-only placement. The entry supplies the room's real cardinal wind.
	if id == "rule_gust":
		layout["player_start"] = GUST_HERO
		return {"units": [["crawler", GUST_CRAWLER]], "card": ""}

	if id == "rule_wildfire":
		layout["player_start"] = WILDFIRE_HERO
		layout["objective"] = {"type": preload("res://scripts/combat_objective_rules.gd").REACH_EXIT, "exits": []}
		return {"units": [], "card": ""}
	if id == "rule_shadowstep":
		layout["player_start"] = SHADOW_HERO
		layout["umbra_stage"] = SHADOW_STAGE
		return {"units": [["crawler", SHADOW_ENEMY]], "card": ""}
	return {"units": [["crawler", FROST_CRAWLER]], "card": ""}

static func prepare(state: Dictionary, id: String) -> void:
	if id == "rule_gust": state["snare_entry"] = GUST_ENTRY
	if id == "rule_wildfire":
		state["snare_entry"] = WILDFIRE_ENTRY
		for tile: Vector2i in WILDFIRE_TILES:
			Surfaces.place(state, tile, "fire", {"actor_kind": "room"})
			Surfaces.surface_at(state, tile)["elemental_source"][Surfaces.BeatFuel.LAID_ACTIVATION] = int(state.get("turn", 1)) - 1
	if id == "rule_frostbite":
		var tile: Vector2i = state["enemies"][0]["pos"]
		Surfaces.place(state, tile, "ice", {"actor_kind": "room"})
		# Room ground was present before this activation; keep fuel eligibility.
		Surfaces.surface_at(state, tile)["elemental_source"][Surfaces.BeatFuel.LAID_ACTIVATION] = int(state.get("turn", 1)) - 1
		var engine := preload("res://scripts/hero_facing_combat.gd").new()
		engine._surface_contact(state, "enemy", int(state["enemies"][0]["id"]), engine.INVALID_TILE, true)
	Rules.install(preload("res://scripts/hero_facing_combat.gd").new(), state, Rules.instance_for(INSTANCES[id]))

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var id: String = fixture["id"]
	var before: Dictionary = fixture["state"]
	var steps: Array[Dictionary]
	var after: Dictionary = Rules.dispatch(engine, before.duplicate(true), "after_player_turn", -1, "", steps)
	if id == "rule_shadowstep" and not engine.is_enemy_visible_to_player(after, after["enemies"][0]):
		return {"beats": [], "final": after, "todo_design": "TODO_DESIGN_rule_shadowstep: Production keeps the enemy hidden after landing, so there is no visible arrival."}
	return {"beats": [{"kind": "room_rule", "before": before, "after": after, "steps": steps}], "final": after}

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var failures: Array[String]
	var id: String = fixture["id"]
	if not str(result.get("todo_design", "")).is_empty(): return failures
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	if after["player"]["hp"] != before["player"]["hp"]: failures.append("Rule must leave hero Health untouched: " + id)
	if int(after["battlefield_rule"].get("beats_fired", 0)) != 1: failures.append("Exactly one real room beat must fire: " + id)
	if before["battlefield_rule"]["dials"] != Rules.instance_for(INSTANCES[id])["dials"]: failures.append("Room dials must remain authored: " + id)
	if id == "rule_gust":
		if Paths.manhattan(before["player"]["pos"], before["enemies"][0]["pos"]) != 2: failures.append("Gust actors must start two tiles apart across the wind")
		for pair: Array in [[before["player"], after["player"]], [before["enemies"][0], after["enemies"][0]]]:
			if pair[1]["pos"] != pair[0]["pos"] + GUST_AXIS or pair[1]["hp"] != pair[0]["hp"] or not PATCH.has_point(pair[1]["pos"]): failures.append("Wind must Push each actor 1 tile without collision inside the patch")
		if result["beats"][0]["steps"].size() != 1: failures.append("Gust must supply its real production animation step")
	elif id == "rule_frostbite":
		if not bool(before["enemies"][0].get("chilled", false)) or Surfaces.element_at(before, before["enemies"][0]["pos"]) != "ice": failures.append("Crawler must start Chilled from production Ice contact")
		# The room's base hit retains the ordinary Chilled +2 modifier.
		var damage: int = int(Rules.instance_for(INSTANCES[id])["dials"]["damage"]) + Surfaces.CHILLED_BONUS
		if Surfaces.element_at(before, before["player"]["pos"]) != "" or Paths.manhattan(before["player"]["pos"], before["enemies"][0]["pos"]) != 1: failures.append("Frostbite hero must stand on plain floor beside the Crawler")
		if int(after["enemies"][0].get("freeze", 0)) <= 0 or int(before["enemies"][0]["hp"]) - int(after["enemies"][0]["hp"]) != damage: failures.append("Ice must hit and Freeze the Crawler through the production resolver")
		if after["player"] != before["player"]: failures.append("Frostbite must leave the hero untouched")
	elif id == "rule_wildfire":
		if before["enemies"].size() != 0 or Surfaces.fuel_tiles(before, "fire").size() != 2 or Surfaces.fuel_tiles(after, "fire").size() != 2: failures.append("Wildfire must start with exactly two Fire tiles; new Fire remains ineligible until the next activation")
		if Surfaces.element_at(after, WILDFIRE_NEW) != "fire" or Surfaces.element_at(after, WILDFIRE_HERO) != "" or after["player"] != before["player"]: failures.append("Wildfire must paint the third row tile, beside the untouched hero")
		if after["surfaces"].size() != 3: failures.append("Exactly one new Fire tile must be placed")
	elif id == "rule_shadowstep":
		var engine := preload("res://scripts/hero_facing_combat.gd").new()
		var from: Vector2i = before["enemies"][0]["pos"]
		var to: Vector2i = after["enemies"][0]["pos"]
		if engine.is_enemy_visible_to_player(before, before["enemies"][0]) or not engine.is_enemy_visible_to_player(after, after["enemies"][0]): failures.append("Shadowstep must reveal the originally hidden enemy at its real landing")
		if Paths.manhattan(from, to) != 2 or Paths.manhattan(to, before["player"]["pos"]) != 2: failures.append("Shadowstep must Blink 2 tiles to a landing 2 tiles from the hero")
		if after["player"] != before["player"]: failures.append("Shadowstep must leave the hero untouched")
	return failures

static func play(scene: Node, beat: Dictionary) -> void:
	var rule: String = beat["before"]["battlefield_rule"]["rule"]
	if rule == "gust":
		await scene.call("_animate_enemy_phase_steps", beat["before"].duplicate(true), beat["steps"], beat["after"])
	elif rule == "wildfire":
		await scene.call("_animate_surface_change", beat["before"], beat["after"])
	elif rule == "shadowstep":
		var engine := preload("res://scripts/hero_facing_combat.gd").new()
		var context: Dictionary = {"blink_from": beat["before"]["enemies"][0]["pos"], "blink_to": beat["after"]["enemies"][0]["pos"], "blink_state": beat["after"]}
		var step: Dictionary = Blink.animation_step(engine, beat["before"], beat["after"], 0, {"type": "veil_blink"}, context)
		await BlinkView.animate(scene, beat["before"].duplicate(true), step)
	else:
		await scene.call("_animate_enemy_loss_feedback_between_states", beat["before"], beat["after"], "ice")
