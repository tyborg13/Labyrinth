extends RefCounted

# Card pool overhaul wave 1 engine additions (spec/card_pool_overhaul):
# facing-aimed areas and their surface riders, player-raised outcrops, authored
# sideways force, and self-centered Radiance actions.
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Fixture = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")

const PLAYER := Vector2i(2, 4)


static func run(expect: Callable) -> void:
	_test_facing_aim_orients_from_selected_tile(expect)
	_test_facing_aim_lines_and_surface_rider(expect)
	_test_player_outcrops(expect)
	_test_outcrops_preserve_routes(expect)
	_test_authored_sideways_force(expect)
	_test_self_centered_radiance_actions(expect)
	_test_zero_damage_area_row(expect)


static func _enemy(id: int, tile: Vector2i) -> Dictionary:
	return {"id": id, "type": "crawler", "pos": tile, "hp": 100, "max_hp": 100, "block": 0, "stoneskin": 0}


static func _state(combat: CombatEngine, card_id: String, enemy_tiles: Array) -> Dictionary:
	var state: Dictionary = Fixture._combat_state(combat, card_id, Vector2i(10, 7), 20260930)
	var enemies: Array = []
	for index: int in range(enemy_tiles.size()):
		enemies.append(_enemy(index + 1, enemy_tiles[index] as Vector2i))
	state["enemies"] = enemies
	state["current_actor"] = {"kind": "player", "key": "player"}
	return state


static func _same_tiles(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for tile: Variant in expected:
		if not actual.has(tile):
			return false
	return true


static func _hp(state: Dictionary, enemy_id: int) -> int:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == enemy_id:
			return int(enemy.get("hp", 0))
	return -1


static func _test_facing_aim_orients_from_selected_tile(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, "needle_flurry", [Vector2i(3, 3), Vector2i(3, 5), Vector2i(1, 4)])
	var sweep: Dictionary = combat.card_play_actions("needle_flurry", state)[0]
	var damage: int = int(sweep.get("damage", 0))
	expect.call(str(sweep.get("aim", "")) == "facing" and int(sweep.get("range", 0)) == 1, "Cleaver Sweep is a range-1 facing-aimed area")
	expect.call(not combat.player_action_needs_orientation(sweep), "Facing-aimed areas never ask for a separate rotation")
	var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, sweep)
	expect.call(_same_tiles(targets, [Vector2i(3, 4), Vector2i(1, 4), Vector2i(2, 3), Vector2i(2, 5)]), "A facing sweep aims at any adjacent floor tile, including empty ones: %s" % str(targets))
	# Aiming east at the empty tile between two enemies turns the arc toward them.
	var east: Array[Vector2i] = combat.aoe_tiles_for_player_action(state, sweep, Vector2i(3, 4))
	expect.call(_same_tiles(east, [Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5)]), "East aim covers the front arc beside the chosen tile: %s" % str(east))
	var after: Dictionary = combat.apply_player_action(state, sweep, Vector2i(3, 4))
	expect.call(_hp(after, 1) == 100 - damage and _hp(after, 2) == 100 - damage and _hp(after, 3) == 100, "East aim hits the enemies flanking the empty target and spares the one behind")
	var preview: Dictionary = combat.surface_preview_for_player_action(state, sweep, Vector2i(3, 4))["state"]
	expect.call(_hp(preview, 1) == _hp(after, 1) and _hp(preview, 2) == _hp(after, 2) and _hp(preview, 3) == _hp(after, 3), "Facing-aim preview resolves exactly like commit")
	var north: Array[Vector2i] = combat.aoe_tiles_for_player_action(state, sweep, Vector2i(2, 3))
	expect.call(_same_tiles(north, [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]), "North aim rotates the arc to face north: %s" % str(north))
	var north_after: Dictionary = combat.apply_player_action(state, sweep, Vector2i(2, 3))
	expect.call(_hp(north_after, 1) == 100 - damage and _hp(north_after, 2) == 100 and _hp(north_after, 3) == 100, "North aim hits only the enemy in the northern arc")
	expect.call(ActionIcons.card_role_emblem_key(GameData.card_def("needle_flurry")) == "attack_melee", "Facing sweeps read as melee attacks")
	var tokens: Array = ActionIcons.tokens_for_action(sweep)
	var icons: Array[String] = []
	for token: Dictionary in tokens:
		icons.append(str(token.get("icon", "")))
	expect.call(icons.has("melee") and not icons.has("range") and not icons.has("ranged"), "Facing sweeps show melee damage without a range chip: %s" % str(icons))
	var pattern_token: Dictionary = tokens[icons.find("aoe_pattern")] if icons.has("aoe_pattern") else {}
	expect.call(bool(pattern_token.get("show_origin", false)) and _same_tiles(pattern_token.get("pattern", []), [[1, 0], [1, -1], [1, 1]]), "The pattern chip is drawn from the hero, facing the chosen tile")


static func _test_facing_aim_lines_and_surface_rider(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, "flame_jet", [Vector2i(3, 4), Vector2i(5, 4), Vector2i(6, 4)])
	var jet: Dictionary = combat.card_play_actions("flame_jet", state)[0]
	var damage: int = int(jet.get("damage", 0))
	var east: Array[Vector2i] = combat.aoe_tiles_for_player_action(state, jet, Vector2i(3, 4))
	expect.call(_same_tiles(east, [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]), "Flame Jet hits the first three tiles in a line from the hero: %s" % str(east))
	var after: Dictionary = combat.apply_player_action(state, jet, Vector2i(3, 4))
	expect.call(_hp(after, 1) == 100 - damage and _hp(after, 2) == 100 - damage and _hp(after, 3) == 100, "Flame Jet damages enemies in its line only")
	expect.call(Surface.has_surface(after, Vector2i(5, 4), "fire") and not Surface.has_surface(after, Vector2i(3, 4), "fire") and not Surface.has_surface(after, Vector2i(4, 4), "fire"), "Flame Jet leaves Fire only on its farthest pattern tile")
	var preview: Dictionary = combat.surface_preview_for_player_action(state, jet, Vector2i(3, 4))["state"]
	expect.call(Surface.has_surface(preview, Vector2i(5, 4), "fire") and not Surface.has_surface(preview, Vector2i(4, 4), "fire"), "Flame Jet's surface preview matches its commit")
	var south: Dictionary = combat.apply_player_action(state, jet, Vector2i(2, 5))
	expect.call(Surface.has_surface(south, Vector2i(2, 7), "fire") and not Surface.has_surface(south, Vector2i(2, 5), "fire") and _hp(south, 1) == 100, "The surface rider rotates with the facing aim")
	var thrust: Dictionary = combat.card_play_actions("spear_thrust", state)[0]
	expect.call(_same_tiles(combat.aoe_tiles_for_player_action(state, thrust, Vector2i(3, 4)), [Vector2i(3, 4), Vector2i(4, 4)]), "Spear Thrust anchors its two-tile line on the chosen adjacent tile")
	var cleave: Dictionary = combat.card_play_actions("grave_cleave", state)[0]
	expect.call(str(cleave.get("aim", "")) == "facing" and _same_tiles(combat.aoe_tiles_for_player_action(state, cleave, Vector2i(2, 5)), [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)]), "Grave Cleave shares the facing arc")


static func _test_zero_damage_area_row(expect: Callable) -> void:
	var caltrops: Dictionary = (GameData.card_def("caltrops")["actions"] as Array)[0]
	var icons: Array[String] = []
	for token: Dictionary in ActionIcons.tokens_for_action(caltrops):
		icons.append(str(token.get("icon", "")))
	expect.call(not icons.has("ranged") and not icons.has("melee") and icons.has("range") and icons.has("bleed"), "Zero-damage areas show placement and statuses without a 0 damage chip: %s" % str(icons))


static func _test_player_outcrops(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, "raise_stone", [Vector2i(4, 4)])
	var raise: Dictionary = combat.card_play_actions("raise_stone", state)[0]
	expect.call(str(raise.get("type", "")) == "outcrop" and combat.player_action_needs_target(raise), "Raise Stone targets one outcrop tile")
	var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, raise)
	expect.call(targets.has(Vector2i(3, 4)) and targets.has(Vector2i(2, 1)) and targets.has(Vector2i(5, 4)), "Outcrops rise on empty floor within range 3")
	expect.call(not targets.has(PLAYER) and not targets.has(Vector2i(4, 4)), "Outcrops never rise under the hero or an enemy")
	expect.call(not targets.has(Vector2i(6, 4)) and not targets.has(Vector2i(0, 4)), "Outcrops respect range and walls")
	var after: Dictionary = combat.apply_player_action(state, raise, Vector2i(3, 4))
	var raised: Array = (after.get("terrain", []) as Array).filter(func(entry: Dictionary) -> bool: return entry.get("pos", Vector2i(-1, -1)) == Vector2i(3, 4))
	expect.call(raised.size() == 1, "Raise Stone creates one outcrop at its target")
	if raised.size() == 1:
		var outcrop: Dictionary = raised[0]
		expect.call(str(outcrop.get("kind", "")) == "crag_outcrop" and int(outcrop.get("hp", 0)) == 3 and int(outcrop.get("max_hp", 0)) == 3, "The outcrop is a 3-health crag outcrop")
		expect.call(bool(outcrop.get("blocks_sight", false)) and str(outcrop.get("surface_on_destroy", "")) == "rubble", "The outcrop blocks sight and leaves Rubble")
		expect.call(str(outcrop.get("owner_kind", "")) == "player" and int(outcrop.get("owner_id", 0)) == -1, "The hero owns player-raised outcrops")
	var created: Array = (after.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "terrain_created")
	expect.call(created.size() == 1 and str((created[0] as Dictionary).get("source", {}).get("card_id", "")) == "raise_stone", "The raise records one card-sourced terrain event")
	expect.call(not combat.combat_line_of_sight(after, PLAYER, Vector2i(4, 4)), "An outcrop blocks line of sight through its tile")
	expect.call(not combat.valid_targets_for_player_action(after, raise).has(Vector2i(3, 4)), "An occupied outcrop tile cannot be raised again")
	var preview: Dictionary = combat.surface_preview_for_player_action(state, raise, Vector2i(3, 4))["state"]
	expect.call((preview.get("terrain", []) as Array).size() == (after.get("terrain", []) as Array).size(), "Outcrop preview matches commit")
	var smashed: Dictionary = combat.apply_player_action(after, {"type": "melee", "range": 1, "damage": 5, "element": "none"}, Vector2i(3, 4))
	expect.call(Surface.has_rubble(smashed, Vector2i(3, 4)), "A destroyed outcrop leaves Rubble")
	var tokens: Array = ActionIcons.tokens_for_action(raise)
	expect.call(tokens.size() == 2 and str((tokens[0] as Dictionary).get("icon", "")) == "raise_terrain" and (tokens[0] as Dictionary).get("value") == 3 and str((tokens[1] as Dictionary).get("icon", "")) == "range" and (tokens[1] as Dictionary).get("value") == 3, "Outcrop rows show health then placement range")
	expect.call(ActionIcons.action_icon_key(raise) == "raise_terrain", "Outcrops use the Raise Terrain identity")
	expect.call(ActionIcons.card_role_emblem_key(GameData.card_def("plant_pavise")) == "block", "Outcrop cover cards read as defense")
	expect.call(Grimoire.entry_ids_for_card_ids(["raise_stone"]).has("combat:outcrops") and not Grimoire.entry_def("combat:outcrops").is_empty(), "Outcrop cards unlock the Outcrops grimoire topic")
	# Adjacent-only raises (Plant Pavise, Raise the Anvil) keep range 1.
	var pavise: Dictionary = combat.card_play_actions("plant_pavise", state)[0]
	var pavise_targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, pavise)
	expect.call(_same_tiles(pavise_targets, [Vector2i(3, 4), Vector2i(1, 4), Vector2i(2, 3), Vector2i(2, 5)]), "Plant Pavise raises only next to the hero")


static func _test_outcrops_preserve_routes(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, "raise_stone", [Vector2i(9, 4)])
	# Column 5 is a wall with one doorway at (5, 4); (4, 4) is its only approach.
	for y: int in range(1, 8):
		if y != 4:
			state["grid"][y][5] = "wall"
	var raise: Dictionary = combat.card_play_actions("raise_stone", state)[0]
	var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, raise)
	expect.call(not targets.has(Vector2i(5, 4)), "An outcrop cannot seal the only doorway")
	expect.call(not targets.has(Vector2i(4, 4)), "An outcrop cannot cut the doorway off from its approach")
	expect.call(targets.has(Vector2i(3, 4)) and targets.has(Vector2i(4, 3)), "Open floor beside the doorway stays legal")
	var sealed: Dictionary = combat.apply_player_action(state, raise, Vector2i(5, 4))
	expect.call((sealed.get("terrain", []) as Array).is_empty(), "An illegal sealing raise has no effect")
	# Each raise re-checks routes against the outcrops already standing.
	var first: Dictionary = combat.apply_player_action(state, raise, Vector2i(4, 3))
	expect.call((first.get("terrain", []) as Array).size() == 1, "The first flanking outcrop rises")
	expect.call(combat.valid_targets_for_player_action(first, raise).has(Vector2i(4, 5)), "A second flank remains legal while routes stay connected")
	var pattern_action: Dictionary = {"type": "outcrop", "range": 3, "health": 3, "pattern": [[0, -1], [0, 0], [0, 1]], "rotate": false}
	var line: Array[Vector2i] = combat.outcrop_tiles_for_player_action(state, pattern_action, Vector2i(5, 4))
	expect.call(line.is_empty(), "Pattern outcrops skip wall tiles and the sealing doorway: %s" % str(line))
	var open_line: Array[Vector2i] = combat.outcrop_tiles_for_player_action(state, pattern_action, Vector2i(3, 4))
	expect.call(_same_tiles(open_line, [Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5)]), "Pattern outcrops raise every legal pattern tile: %s" % str(open_line))


static func _test_authored_sideways_force(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, "crosswind", [Vector2i(4, 4)])
	var gust: Dictionary = combat.card_play_actions("crosswind", state)[0]
	expect.call(bool(gust.get("_allow_sideways_force", false)), "Crosswind authors sideways force as card data")
	var directions: Array[Vector2i] = combat.force_directions_for_player_action(state, gust, Vector2i(4, 4))
	expect.call(directions.has(Vector2i(0, 1)) and directions.has(Vector2i(0, -1)) and directions.has(Vector2i(1, 0)), "Crosswind may push in any open direction: %s" % str(directions))
	var sideways: Dictionary = gust.duplicate(true)
	sideways["force_direction"] = Vector2i(0, 1)
	expect.call(combat.valid_targets_for_player_action(state, sideways).has(Vector2i(4, 4)), "A sideways Crosswind remains a legal target")
	var after: Dictionary = combat.apply_player_action(state, sideways, Vector2i(4, 4))
	var moved: Dictionary = (after.get("enemies", []) as Array)[0]
	expect.call(moved.get("pos", Vector2i.ZERO) == Vector2i(4, 6) and int(moved.get("hp", 0)) == 100 - int(gust.get("damage", 0)), "Crosswind resolves its sideways push: %s" % str(moved.get("pos")))
	var push_token: Dictionary = ActionIcons.tokens_for_action(gust).back()
	expect.call(str(push_token.get("icon", "")) == "push" and ActionIcons.token_tooltip(push_token).contains("any open direction"), "Crosswind's push chip explains its free direction")


static func _test_self_centered_radiance_actions(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, "sun_flash", [Vector2i(3, 4)])
	for card_id: String in ["sun_flash", "censer_swing", "blessed_salve"]:
		var light: Dictionary = {}
		for action: Dictionary in combat.card_play_actions(card_id, state):
			if str(action.get("type", "")) == "illuminate":
				light = action
		expect.call(int(light.get("range", -1)) == 0, "%s creates Light on the hero" % card_id)
		expect.call(_same_tiles(combat.valid_targets_for_player_action(state, light), [PLAYER]), "%s's range-0 Light has exactly the hero's tile as its target" % card_id)
		var lit: Dictionary = combat.apply_player_action(state, light, PLAYER)
		var sources: Array = (lit.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
		expect.call(sources.size() == 1 and (sources[0] as Dictionary).get("pos", Vector2i.ZERO) == PLAYER and int((sources[0] as Dictionary).get("remaining_activations", 0)) == 2, "%s leaves two-turn Light where the hero stands" % card_id)
		var light_icons: Array[String] = []
		for token: Dictionary in ActionIcons.tokens_for_action(light):
			light_icons.append(str(token.get("icon", "")))
		expect.call(light_icons == ["illuminate", "time"], "%s shows Light radius and duration without a range-0 chip: %s" % [card_id, str(light_icons)])
	for card_id: String in ["vigil", "incense_haze", "seekers_mark", "seers_candle"]:
		for action: Dictionary in combat.card_play_actions(card_id, state):
			if str(action.get("type", "")) in ["vision", "truesight"]:
				expect.call(not combat.player_action_needs_target(action), "%s grants its Umbra sight without a target" % card_id)
