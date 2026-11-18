extends RefCounted
const Data = preload("res://scripts/game_data.gd")
const Runs = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Progression = preload("res://scripts/progression_store.gd")
const PatchChecks = preload("res://tools/tooltip_loops/patch_checks.gd")
const Tip05 = preload("res://tools/tooltip_loops/tip05_fixture.gd")
const Tip04 = preload("res://tools/tooltip_loops/tip04_fixture.gd")
const Tip03 = preload("res://tools/tooltip_loops/tip03_fixture.gd")
const Txt13 = preload("res://tools/txt13/loop_fixture.gd")
const Traps = preload("res://tools/tooltip_loops/trap_fixture.gd")
const SEED: int = 1511 # Debug fixture RNG only.
const HERO := Vector2i(1, 2)
const GRUB_HERO := Vector2i(2, 2)
const BIOMES: Dictionary = {"burst_ember_tick": "vyraketh", "marked_burrow_grub": "tharokh", "chain_card": "zekarion"}

static func build(id: String) -> Dictionary:
	var runs := Runs.new()
	var run: Dictionary = runs.create_new_run(SEED, Progression.default_data())
	var layout: Dictionary = run["current_room_layout"].duplicate(true)
	layout["grid"] = [["stone", "stone", "stone", "stone"], ["stone", "stone", "stone", "stone"], ["stone", "stone", "stone", "stone"]]
	layout["player_start"] = HERO
	layout["type"] = "combat"
	layout["depth"] = 1
	layout["objective"] = {}
	for key: String in ["terrain", "traps", "loot", "npcs", "enemies"]: layout[key] = []
	layout["surfaces"] = {}
	layout["moss"] = {}
	var units: Array = []
	var card: String = ""
	match id:
		"burst_ember_tick":
			units = [["ember_tick", Vector2i(1, 1)], ["crawler", Vector2i(1, 0)]]
			card = "quick_stab"
			layout["element"] = "fire"
		"marked_burrow_grub":
			units = [["burrow_grub", Vector2i(2, 0)]]
			layout["player_start"] = GRUB_HERO
			layout["element"] = "earth"
		"chain_card":
			units = [["crawler", Vector2i(1, 1)], ["crawler", Vector2i(2, 1)], ["crawler", Vector2i(3, 0)]]
			card = "chain_bolt"
			layout["element"] = "none"
	if Tip05.IDS.has(id):
		var config: Dictionary = Tip05.configure(layout, id)
		units = config["units"]
		card = config["card"]
	if Tip04.IDS.has(id):
		var config: Dictionary = Tip04.configure(layout, id)
		units = config["units"]
		card = config["card"]
	if Tip03.IDS.has(id):
		var config: Dictionary = Tip03.configure(layout, id)
		units = config["units"]
		card = config["card"]
	if Traps.IDS.has(id):
		var config: Dictionary = Traps.configure(layout, id)
		units = config["units"]
		card = config["card"]
	if Txt13.IDS.has(id): units = Txt13.configure(layout, id)
	for entry: Array in units:
		var definition: Dictionary = Data.enemy_def(entry[0])
		layout["enemies"].append({"id": layout["enemies"].size() + 1, "type": entry[0], "pos": entry[1], "hp": definition["max_hp"], "max_hp": definition["max_hp"]})
	if id == Txt13.BARRAGE:
		var leaders: Array[Dictionary]
		leaders.assign(layout["enemies"])
		preload("res://scripts/room_generator.gd").new()._apply_leader_objective(leaders, layout["objective"])
		layout["enemies"] = leaders
	var snapshot: Dictionary = runs._player_snapshot(run)
	var state: Dictionary = Combat.new().create_combat(SEED, layout, snapshot)
	if not card.is_empty():
		var hand: Array[String]
		hand.append(card)
		state["deck"]["hand"] = hand
	if id == "marked_burrow_grub": state["enemies"][0]["intent"] = Data.enemy_def("burrow_grub")["intents"][0].duplicate(true)
	if Tip03.IDS.has(id): Tip03.prepare(state, id)
	if Tip04.IDS.has(id): Tip04.prepare(state, id)
	if Tip05.IDS.has(id): Tip05.prepare(state, id)
	if Txt13.IDS.has(id): Txt13.prepare(state, id)
	run["mode"] = "combat"
	run["current_room_layout"] = layout
	run["combat_state"] = state
	return {"run": run, "state": state, "card": card, "id": id, "layout": layout}

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	if Txt13.IDS.has(fixture["id"]): return Txt13.plan(fixture, engine)
	if Traps.IDS.has(fixture["id"]): return Traps.plan(fixture, engine)
	if Tip05.IDS.has(fixture["id"]): return Tip05.plan(fixture, engine)
	if Tip04.IDS.has(fixture["id"]): return Tip04.plan(fixture, engine)
	if Tip03.IDS.has(fixture["id"]): return Tip03.plan(fixture, engine)
	var state: Dictionary = fixture["state"]
	var beats: Array[Dictionary]
	if fixture["id"] == "marked_burrow_grub":
		var burrow: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
		beats.append({"kind": "enemy", "before": state, "after": burrow["state"], "steps": burrow["steps"]})
		state = burrow["state"]
		var action: Dictionary = {"type": "move", "range": 2}
		var target := Vector2i(0, 2)
		var moved: Dictionary = engine.resolve_player_action_for_presentation(state, action, target)
		beats.append({"kind": "player", "before": state, "after": moved["state"], "action": action, "target": target, "chain_hits": []})
		state = moved["state"]
		var erupt: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
		beats.append({"kind": "enemy", "before": state, "after": erupt["state"], "steps": erupt["steps"]})
		state = erupt["state"]
	else:
		var action: Dictionary = engine.card_play_actions(fixture["card"], state)[0]
		var target: Vector2i = state["enemies"][0]["pos"]
		var resolution: Dictionary = engine.resolve_player_action_for_presentation(state, action, target)
		beats.append({"kind": "player", "before": state, "after": resolution["state"], "action": action, "target": target, "chain_hits": resolution.get("chain_hits", []), "card": fixture["card"]})
		state = resolution["state"]
	return {"beats": beats, "final": state}

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var failures: Array[String] = _validate_mechanics(fixture, result)
	failures.append_array(PatchChecks.tiles(fixture, result, crop_tiles(fixture["id"])))
	return failures

static func _validate_mechanics(fixture: Dictionary, result: Dictionary) -> Array[String]:
	if Txt13.IDS.has(fixture["id"]): return Txt13.validate(fixture, result)
	if Traps.IDS.has(fixture["id"]): return Traps.validate(fixture, result)
	if Tip05.IDS.has(fixture["id"]): return Tip05.validate(fixture, result)
	if Tip04.IDS.has(fixture["id"]): return Tip04.validate(fixture, result)
	if Tip03.IDS.has(fixture["id"]): return Tip03.validate(fixture, result)
	var failures: Array[String]
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	match fixture["id"]:
		"burst_ember_tick":
			if int(after["enemies"][0]["hp"]) > 0: failures.append("Quick Stab must kill the Tick")
			if int(after["player"]["hp"]) >= int(before["player"]["hp"]) or int(after["enemies"][1]["hp"]) >= int(before["enemies"][1]["hp"]): failures.append("Burst must damage both neighbours")
			if after.get("surfaces", {}).is_empty(): failures.append("Burst must leave Fire")
		"marked_burrow_grub":
			var marked: Dictionary = result["beats"][0]["after"]["enemies"][0]
			if not bool(marked.get("burrowed", false)) or marked.get("erupt_tile") != GRUB_HERO: failures.append("Burrow must mark the hero's original tile")
			if after["player"]["pos"] != Vector2i(0, 2) or after["enemies"][0]["pos"] != GRUB_HERO or bool(after["enemies"][0].get("burrowed", false)): failures.append("Hero evades; Grub erupts on the empty original tile")
			var evaded: Dictionary = result["beats"][1]["after"]["player"]
			if evaded["pos"] != Vector2i(0, 2): failures.append("Hero must walk two tiles left before Erupt")
			if after["player"]["pos"] != evaded["pos"]: failures.append("Erupt must push nobody")
			if after["player"]["hp"] != evaded["hp"] or after["player"]["block"] != evaded["block"] or after["player"]["hp"] != before["player"]["hp"]: failures.append("Nobody is hit by Erupt")
		"chain_card":
			if result["beats"][0]["chain_hits"].size() != 3: failures.append("Chain Bolt must hit three Crawlers")
			for index: int in range(3):
				if after["enemies"][index]["hp"] >= before["enemies"][index]["hp"]: failures.append("Every Crawler takes real Chain damage")
	return failures

static func crop_tiles(id: String) -> Rect2i:
	return Txt13.BARRAGE_PATCH if id == Txt13.BARRAGE else PatchChecks.PATCH
