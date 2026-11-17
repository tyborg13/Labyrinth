extends RefCounted
## Offline staging only; damage, arrival, ground and push use production rules.
const Ground = preload("res://scripts/board_surface_rules.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Ownership = preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd")
const IDS: Array = ["trap_fire", "trap_ice", "trap_lightning", "trap_earth", "trap_air"]
const BIOMES: Dictionary = {"trap_fire": "vyraketh", "trap_ice": "iskaldra", "trap_lightning": "zekarion", "trap_earth": "tharokh", "trap_air": "vaeloryx"}
# Debug staging within the recorder's existing 4x3 patch and crop.
const CENTER := Vector2i(1, 1)
const ENTRY := Vector2i(0, 1)
const FAR := Vector2i(2, 1)
const PUSH_END := Vector2i(3, 1)
const HERO := Vector2i(3, 0)  # director: the hero stands behind the plus, clear of its sprite overlap (trp-01 review)

static func configure(layout: Dictionary, id: String) -> Dictionary:
	var element: String = id.trim_prefix("trap_")
	layout["element"] = element
	layout["player_start"] = HERO
	layout["traps"] = [Rooms.new()._trap_for_tile(CENTER, element, 1)]
	var units: Array = [["crawler", ENTRY]]
	if element == "air": units.append(["crawler", FAR])
	return {"units": units, "card": ""}

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var before: Dictionary = fixture["state"]
	# Author the demonstration's held one-step route, then execute it through
	# the same committed-path resolver and arrival trace as live enemy movement.
	var context: Dictionary = {"committed": true, "action_index": 0, "movement_action_index": 0, "path": [ENTRY, CENTER], "reaction_trace": {"capture_reactions": true}}
	var action: Dictionary = {"type": "move_toward", "range": 1}
	var after: Dictionary = engine._resolve_enemy_action(before.duplicate(true), 0, action, null, {}, engine._dictionary_values([]), context)
	var steps: Array[Dictionary] = Ownership.before_attack_steps(engine, context)
	var step: Dictionary = engine._enemy_action_step(before, after, 0, action, context)
	if not step.is_empty(): steps.append(step)
	steps.append_array(Ownership.presentation_steps(engine, before, after, context))
	return {"beats": [{"kind": "trap", "before": before, "after": after, "steps": steps}], "final": after}

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var errors: Array[String]
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	var element: String = str(fixture["id"]).trim_prefix("trap_")
	var trap: Dictionary = before["traps"][0]
	if before["room_element"] != element or before["traps"].size() != 1 or trap != Rooms.new()._trap_for_tile(CENTER, element, 1): errors.append("Trap fixture must use its room element and generator depth-1 damage")
	if before["player"] != after["player"]: errors.append("Trap loop must leave the idle hero untouched")
	for tile: Vector2i in affected_tiles():
		if Paths.manhattan(HERO, tile) < 2: errors.append("Hero must remain at least two tiles from every affected tile")
	if before["enemies"][0]["type"] != "crawler" or before["enemies"][0]["pos"] != ENTRY or after["enemies"][0]["pos"] != CENTER: errors.append("Crawler must step from the adjacent tile onto the trap")
	if int(before["enemies"][0]["hp"]) - int(after["enemies"][0]["hp"]) != int(trap["base_damage"]) or int(after["enemies"][0]["hp"]) <= 0: errors.append("Center Crawler must survive exactly the trap's real damage")
	if not after["traps"].is_empty(): errors.append("The live trap must trigger once")
	if element == "air":
		if not after["surfaces"].is_empty() or after["enemies"].size() != 2 or after["enemies"][1]["pos"] != PUSH_END or after["enemies"][1]["hp"] != before["enemies"][1]["hp"]: errors.append("Air must push the far Crawler one tile away without ground or collateral damage")
	else:
		if Ground.tiles(after).size() != 5: errors.append("Trap must leave exactly five ground tiles")
		for tile: Vector2i in affected_tiles():
			if not Ground.has_surface(after, tile, Ground.kind(element)): errors.append("Trap ground missing from center/cardinal tile " + str(tile))
	return errors

static func affected_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	tiles.append(CENTER)
	for direction: Vector2i in Paths.DIRS_4: tiles.append(CENTER + direction)
	return tiles

static func play(scene: Control, beat: Dictionary) -> void:
	var after: Dictionary = beat["after"]
	if beat["before"]["room_element"] != "air":
		await scene._animate_enemy_phase_steps(beat["before"].duplicate(true), beat["steps"], after)
		return
	# Enemy arrival feedback presents the real blast and center loss. Hold only
	# the pushed actor's display position until the existing production push
	# slide plays; the fully resolved gameplay state is never changed.
	var held: Dictionary = after.duplicate(true)
	held["enemies"][1]["pos"] = FAR
	await scene._animate_enemy_phase_steps(beat["before"].duplicate(true), beat["steps"], held)
	var actors: Array[Dictionary]
	actors.append({"kind": "enemy", "id": int(held["enemies"][1]["id"]), "unit": held["enemies"][1]})
	await preload("res://scripts/forced_displacement_view.gd").animate(scene, held, after, actors)
