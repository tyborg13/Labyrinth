extends RefCounted
## Director scripts only. No production rules, catalog values or art are changed.
const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const IDS: Array = ["retaliate_hollow_mimic", "charge_storm_capacitor", "lightning_strikes", "marked_icefall_seer", "marked_lob_slag", "splits_cinder_ooze"]
const BIOMES: Dictionary = {"retaliate_hollow_mimic": "noctyrax", "charge_storm_capacitor": "zekarion", "lightning_strikes": "zekarion", "marked_icefall_seer": "iskaldra", "marked_lob_slag": "tharokh", "splits_cinder_ooze": "vyraketh"}
const TODO_DESIGN_lob_slag_one_tile: String = "A real centered Lob Slag plus includes every legal one-tile step. Closest no-hit script walks two tiles horizontally inside the patch."
const SPLITS_OOZE := Vector2i(1, 2) # Spawn tiles (1,1)/(2,2), both to the hero's right.
const SPLITS_HERO := Vector2i(0, 2)
const SPLITS_PATCH := Rect2i(0, 0, 4, 3)
const CHARGE_CAPACITOR := Vector2i(1, 1) # Keep the full discharge sprite below the top crop edge.
const ICEFALL_HERO := Vector2i(1, 1)
const ICEFALL_ESCAPE := Vector2i(2, 1)
const LIGHTNING_RULE: String = "snare_lightning" # Existing room rule owns damage/cadence/Chain dials.

static func configure(layout: Dictionary, id: String) -> Dictionary:
	var units: Array = []
	var card: String = ""
	match id:
		"splits_cinder_ooze":
			units = [["cinder_ooze", SPLITS_OOZE]]
			layout["player_start"] = SPLITS_HERO
			card = "quick_stab"
			layout["element"] = "fire"
		"retaliate_hollow_mimic":
			units = [["hollow_mimic", Vector2i(1, 1)]]
			card = "quick_stab"
			layout["element"] = "shadow"
		"charge_storm_capacitor":
			units = [["storm_capacitor", CHARGE_CAPACITOR], ["crawler", Vector2i(2, 2)]]
			layout["element"] = "lightning"
		"marked_icefall_seer":
			units = [["hoarfrost_seer", Vector2i(3, 1)]]
			layout["player_start"] = ICEFALL_HERO
			layout["element"] = "ice"
		"marked_lob_slag":
			units = [["slag_mortar", Vector2i(3, 2)]]
			layout["player_start"] = Vector2i(0, 2)
			layout["element"] = "fire"
		"lightning_strikes":
			layout["objective"] = {"type": preload("res://scripts/combat_objective_rules.gd").KILL_ALL}
			units = [["crawler", Vector2i(1, 0)]]
			layout["element"] = "lightning"
	return {"units": units, "card": card}

static func prepare(state: Dictionary, id: String) -> void:
	if id == "splits_cinder_ooze": state["enemies"][0]["hp"] = 1
	if id == "lightning_strikes":
		var engine := preload("res://scripts/hero_facing_combat.gd").new()
		Rules.install(engine, state, Rules.instance_for(LIGHTNING_RULE))
		for tile: Vector2i in [state["player"]["pos"], state["enemies"][0]["pos"]]:
			Surfaces.place(state, tile, "electrified", {"actor_kind": "room"})
			Surfaces.surface_at(state, tile)["elemental_source"][Surfaces.BeatFuel.LAID_ACTIVATION] = int(state.get("turn", 1)) - 1
	if id == "retaliate_hollow_mimic":
		Retaliate.gain(state["enemies"][0], Data.enemy_def("hollow_mimic")["intents"][0]["actions"][1], "Echo")
	if id == "charge_storm_capacitor":
		state["enemies"][0]["charge"] = 3
		state["enemies"][0]["intent"] = Data.enemy_def("storm_capacitor")["intents"][1].duplicate(true)
	if id in ["marked_icefall_seer", "marked_lob_slag"]:
		var type: String = "hoarfrost_seer" if id == "marked_icefall_seer" else "slag_mortar"
		state["enemies"][0]["intent"] = Data.enemy_def(type)["intents"][0].duplicate(true)

static func player_beat(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i, card: String = "") -> Dictionary:
	var resolution: Dictionary = engine.resolve_player_action_for_presentation(state, action, target)
	return {"kind": "player", "before": state, "after": resolution["state"], "action": action, "target": target, "chain_hits": resolution.get("chain_hits", []), "card": card}

static func enemy_beat(engine: RefCounted, state: Dictionary) -> Dictionary:
	var resolution: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	return {"kind": "enemy", "before": state, "after": resolution["state"], "steps": resolution["steps"]}

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var state: Dictionary = fixture["state"]
	var id: String = fixture["id"]
	var beats: Array[Dictionary]
	if id == "lightning_strikes":
		beats.append(player_beat(engine, state, {"type": "move", "range": 1}, Vector2i(0, 2)))
		state = beats.back()["after"]
		var tiles: Array[Vector2i] = Surfaces.fuel_tiles(state, "electrified")
		var steps: Array[Dictionary]
		var after: Dictionary = Rules.dispatch(engine, state.duplicate(true), "after_player_turn", -1, "", steps)
		beats.append({"kind": "rule", "before": state, "after": after, "tiles": tiles})
	elif id == "charge_storm_capacitor":
		beats.append(enemy_beat(engine, state))
	elif id in ["marked_icefall_seer", "marked_lob_slag"]:
		beats.append(enemy_beat(engine, state))
		state = beats.back()["after"]
		# Icefall spans y=0..2 at x=1. A centered Slag plus requires two
		# orthogonal steps to evade; walk right, fully inside the 4x3 patch.
		var destination := ICEFALL_ESCAPE if id == "marked_icefall_seer" else Vector2i(2, 2)
		var distance: int = 1 if id == "marked_icefall_seer" else 2
		beats.append(player_beat(engine, state, {"type": "move", "range": distance}, destination))
		state = beats.back()["after"]
		beats.append(enemy_beat(engine, state))
	else:
		var card: String = fixture["card"]
		beats.append(player_beat(engine, state, engine.card_play_actions(card, state)[0], state["enemies"][0]["pos"], card))
	return {"beats": beats, "final": beats.back()["after"]}

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var failures: Array[String]
	var id: String = fixture["id"]
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	match id:
		"splits_cinder_ooze":
			var children: Array = after["enemies"].filter(func(enemy: Dictionary) -> bool: return enemy["type"] == "cinder_droplet" and int(enemy["hp"]) > 0)
			if int(after["enemies"][0]["hp"]) != 0 or children.size() != 2: failures.append("Quick Stab must kill the 1 HP Ooze and create two living Droplets")
			for child: Dictionary in children:
				if not SPLITS_PATCH.has_point(child["pos"]): failures.append("Both Droplet tiles must be fully inside the 4x3 patch")
				if after["grid"][child["pos"].y][child["pos"].x] != "stone": failures.append("Both Droplets must spawn on open floor")
				if absi(child["pos"].x - SPLITS_OOZE.x) + absi(child["pos"].y - SPLITS_OOZE.y) != 1: failures.append("Droplets must appear on neighbouring tiles")
		"lightning_strikes":
			var old_hero: Vector2i = before["player"]["pos"]
			var crawler: Vector2i = before["enemies"][0]["pos"]
			var strike: Dictionary = result["beats"][1]
			if strike["tiles"].size() != 2 or not strike["tiles"].has(old_hero) or not strike["tiles"].has(crawler): failures.append("Rule must strike exactly both Electrified tiles")
			if after["player"]["pos"] != Vector2i(0, 2) or after["player"]["hp"] != before["player"]["hp"] or int(after["player"].get("shock", 0)) != 0: failures.append("Hero walks one tile to plain floor and avoids the strike")
			var damage: int = Rules.instance_for(LIGHTNING_RULE)["dials"]["damage"]
			if int(before["enemies"][0]["hp"]) - int(after["enemies"][0]["hp"]) != damage: failures.append("Crawler takes the existing rule's real strike damage")
			if int(after["battlefield_rule"].get("beats_fired", 0)) != 1: failures.append("Exactly one rule beat must fire")
			if after["surfaces"] != before["surfaces"]: failures.append("Rule must preserve the two existing Electrified tiles without creating ground")
		"retaliate_hollow_mimic":
			if int(before["player"]["hp"]) - int(after["player"]["hp"]) != 3: failures.append("Retaliate must hit the hero for exactly 3")
			if int(before["enemies"][0]["hp"]) - int(after["enemies"][0]["hp"]) != 6: failures.append("Quick Stab must hit the Mimic for 6")
		"charge_storm_capacitor":
			if int(after["enemies"][0].get("charge", -1)) != 0: failures.append("Arc Burst must reset Charge to 0")
			if int(after["player"]["hp"]) >= int(before["player"]["hp"]) or int(after["enemies"][1]["hp"]) >= int(before["enemies"][1]["hp"]): failures.append("Arc Burst must hit both hero and Crawler")
		"marked_icefall_seer", "marked_lob_slag":
			var field: String = "icefall_tiles" if id == "marked_icefall_seer" else "lob_tiles"
			var marks: Array = result["beats"][0]["after"]["enemies"][0].get(field, [])
			if not marks.has(before["player"]["pos"]): failures.append("Enemy must mark the hero's original tile")
			if id == "marked_icefall_seer" and marks.size() != 3: failures.append("Icefall must mark exactly three tiles")
			if marks.has(after["player"]["pos"]) or after["player"]["pos"] == before["player"]["pos"]: failures.append("Hero must walk out of every marked tile")
			if after["player"]["hp"] != before["player"]["hp"] or after["enemies"][0]["hp"] != before["enemies"][0]["hp"]: failures.append("Nobody is hit by the landing")
			for tile: Vector2i in marks:
				var expected: String = "ice" if id == "marked_icefall_seer" else "fire"
				if Surfaces.element_at(after, tile) != expected: failures.append("Landing must leave real " + expected + " on " + str(tile))
			if after["enemies"][0].has(field): failures.append("Landing must consume the marks")
	return failures

