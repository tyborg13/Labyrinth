extends RefCounted

# Card pool overhaul engine additions (spec/card_pool_overhaul). Wave 1:
# facing-aimed areas and their surface riders, player-raised outcrops, authored
# sideways force, and self-centered Radiance actions. Waves 2 and 3: the real
# keyword cards in data/cards.json (spec/card_keywords.md,
# spec/card_keywords_wave3.md), and the live Rotate for patterned outcrops.
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Fixture = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const RetaliateRules = preload("res://scripts/retaliate_rules.gd")
const TempoRules = preload("res://scripts/tempo_rules.gd")
const RiteRules = preload("res://scripts/rite_rules.gd")

const PLAYER := Vector2i(2, 4)


static func run(expect: Callable) -> void:
	_test_facing_aim_orients_from_selected_tile(expect)
	_test_facing_aim_lines_and_surface_rider(expect)
	_test_player_outcrops(expect)
	_test_outcrops_preserve_routes(expect)
	_test_authored_sideways_force(expect)
	_test_self_centered_radiance_actions(expect)
	_test_zero_damage_area_row(expect)
	_test_wave2_follow_up_and_empower_cards(expect)
	_test_wave2_stagger_cards(expect)
	_test_wave2_tiles_moved_scaling(expect)
	_test_wave2_light_state_bonuses(expect)
	_test_wave2_patterned_outcrop(expect)
	_test_wave3_reactive_and_tempo_cards(expect)
	_test_wave3_thorn_crown_pact(expect)
	_test_wave23_grimoire_unlocks(expect)
	_test_wave23_hand_display(expect)


static func run_live(tree: SceneTree, expect: Callable) -> void:
	await _test_live_earthen_rampart_rotate(tree, expect)


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
	var net: Dictionary = (GameData.card_def("throwing_net")["actions"] as Array)[0]
	var net_icons: Array[String]
	for token: Dictionary in ActionIcons.tokens_for_action(net):
		net_icons.append(str(token.get("icon", "")))
	expect.call(net_icons == ["range", "immobilize", "stagger"], "A zero-damage throw shows its range and statuses without a 0 damage chip: %s" % str(net_icons))


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


# ---------------------------------------------------------------- waves 2 and 3

const NO_TILE := Vector2i(-1, -1)
const RunSceneScript = preload("res://scripts/run_scene.gd")
# Every card definition card_defs.py authors for waves 2 and 3.
const WAVE23_CARD_IDS: Array[String] = [
	"cinder_bloom", "rite_of_the_pyre", "salamander_heart", "rimefang", "shatterline", "rite_of_hoarfrost",
	"chain_bolt", "static_rush", "capacitor", "arc_flash", "overclock", "rite_of_the_storm",
	"tempest_form", "wind_shear", "eye_of_the_storm", "rite_of_tailwinds", "tremor", "earthen_rampart",
	"stonefist", "rite_of_the_mountain", "tectonic_maul", "sunlance", "mirror_image", "dazzle",
	"rite_of_noon", "quick_stab", "bloody_lunge", "butcher_chop", "riposte_lunge", "battle_rhythm",
	"bodkin_arrow", "blood_price", "tombsplitter", "crushing_blow", "overhead_smash", "brace_the_spear",
	"hurl_spear", "palm_blade", "hallowed_strike", "couched_lance", "crack_the_whip", "spike_check",
	"deflect", "main_gauche", "blinding_bash", "stonewall_stance", "undertaker_stand", "barbed_mail",
	"bristle", "static_mantle", "galvanize", "shadow_gate", "heel_hook", "spur_spark",
	"iron_wheel", "headlong", "flowing_step", "palm_strike", "clockwork_mark", "thorn_crown_pact",
	"royal_bramble", "charged_orb", "stolen_moment", "sworn_oath", "hourglass_sand", "throwing_net",
	"whetstone"
]


static func _queued_state(combat: CombatEngine, hand: Array, enemies: Array) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 8 else "stone")
		grid.append(row)
	var layout: Dictionary = {
		"name": "Card pool waves", "type": "combat", "coord": Vector2i(2, 2), "element": "none",
		"umbra_stage": "clear", "grid": grid, "player_start": PLAYER,
		"terrain": [], "traps": [], "loot": [], "enemies": enemies,
	}
	var state: Dictionary = combat.create_combat(20261001, layout, {"hp": 30, "max_hp": 30, "deck_cards": hand.duplicate(), "hand_size": 0, "relics": []})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = ["brace", "brace", "brace", "brace"]
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	for enemy: Dictionary in state.get("enemies", []):
		enemy["block"] = 0
		enemy["stoneskin"] = 0
	state["cards_per_turn"] = 4
	state["current_actor"] = {"kind": "player", "key": "player"}
	return state


static func _queue_time(state: Dictionary, enemy_id: int) -> int:
	var best: int = -1
	for entry: Dictionary in state.get("turn_queue", []):
		if str(entry.get("kind", "")) == "enemy" and int(entry.get("enemy_id", -1)) == enemy_id:
			if best < 0 or int(entry.get("time", 0)) < best:
				best = int(entry.get("time", 0))
	return best


static func _card_actions(combat: CombatEngine, state: Dictionary, mode: String = "play") -> Dictionary:
	var prepared: Dictionary = combat.prepare_player_card(state, 0, mode)
	var card_id: String = str(((prepared.get("deck", {}) as Dictionary).get("hand", []) as Array)[0])
	return {"state": prepared, "actions": combat.card_play_actions(card_id, prepared)}


# Plays hand card 0 like a committed hand play: each targeted action takes the
# next tile from `targets`, then the card finishes.
static func _play_first(combat: CombatEngine, state: Dictionary, targets: Array, mode: String = "play") -> Dictionary:
	var started: Dictionary = _card_actions(combat, state, mode)
	var working: Dictionary = started["state"]
	var actions: Array = started["actions"]
	var cursor: int = 0
	for action_var: Variant in actions:
		var action: Dictionary = action_var
		var target: Vector2i = NO_TILE
		if combat.player_action_needs_target(action):
			target = targets[cursor] if cursor < targets.size() else NO_TILE
			cursor += 1
		working = combat.apply_player_action(working, action, target)
	return combat.finish_player_card(working, 0, combat.card_plays_spent_for_actions(actions), {"play_mode": mode})


static func _with_hand(state: Dictionary, hand: Array) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var deck: Dictionary = (next_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	next_state["deck"] = deck
	return next_state


static func _row_values(card_id: String) -> Array[String]:
	var values: Array[String]
	for row: Variant in ActionIcons.rows_for_card(GameData.card_def(card_id)):
		for token: Variant in row:
			if typeof(token) == TYPE_DICTIONARY and (token as Dictionary).get("value") != null:
				values.append("%s=%s" % [str((token as Dictionary).get("icon", "")), str((token as Dictionary).get("value"))])
	return values


static func _test_wave2_follow_up_and_empower_cards(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _queued_state(combat, ["quick_stab"], [{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 40, "max_hp": 40}])
	var first: Dictionary = (_card_actions(combat, state)["actions"] as Array)[0]
	expect.call(int(first.get("damage", 0)) == 6 and not bool(first.get("_follow_up_active", false)), "Quick Stab opens a turn for its printed 6")
	var second_state: Dictionary = state.duplicate(true)
	second_state["cards_played_this_turn"] = 1
	var second: Dictionary = (_card_actions(combat, second_state)["actions"] as Array)[0]
	expect.call(int(second.get("damage", 0)) == 9 and bool(second.get("_follow_up_active", false)), "Quick Stab's Follow-up deals 9 after another card")
	var after: Dictionary = _play_first(combat, second_state, [Vector2i(3, 4)])
	expect.call(int(((after.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 31, "Follow-up damage resolves exactly as shown")
	expect.call(int(GameData.card_def("quick_stab").get("time", 0)) == 2, "Quick Stab stays a 2-Time starter")
	# Bloody Lunge: printed Move 2 + strike 9, Empower pays 1 HP for +4.
	var lunge: Dictionary = GameData.card_def("bloody_lunge")
	expect.call(int(lunge.get("time", 0)) == 6 and int(lunge.get("health_cost", 0)) == 0, "Bloody Lunge costs 6 Time and no printed health")
	var lunge_state: Dictionary = _with_hand(state, ["bloody_lunge"])
	var plain: Array = _card_actions(combat, lunge_state)["actions"]
	var empowered: Array = _card_actions(combat, lunge_state, "empower")["actions"]
	expect.call(int((plain[1] as Dictionary).get("damage", 0)) == 9 and int((empowered[1] as Dictionary).get("damage", 0)) == 13, "Bloody Lunge strikes for 9, or 13 when Empowered")
	var paid: Dictionary = _play_first(combat, lunge_state, [PLAYER, Vector2i(3, 4)], "empower")
	expect.call(int((paid.get("player", {}) as Dictionary).get("hp", 0)) == 29 and int(paid.get("player_turn_time_spent", 0)) == 6, "Empowered Bloody Lunge pays 1 HP after resolving and keeps its 6 Time")
	expect.call(int(((paid.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 27, "Empowered Bloody Lunge deals 13")
	# Authored `set` values load as JSON floats; card chips must print whole numbers.
	for card_id: String in ["chain_bolt", "tremor", "overclock", "mirror_image", "wind_shear", "arc_flash", "palm_strike"]:
		for value: String in _row_values(card_id):
			expect.call(not value.contains(".0"), "%s's keyword chips print whole numbers: %s" % [card_id, value])


static func _test_wave2_stagger_cards(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var enemies: Array = [
		{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 60, "max_hp": 60},
		{"id": 2, "type": "crawler", "pos": Vector2i(4, 4), "hp": 60, "max_hp": 60},
		{"id": 3, "type": "crawler", "pos": Vector2i(5, 4), "hp": 60, "max_hp": 60},
	]
	var state: Dictionary = _queued_state(combat, ["tombsplitter"], enemies)
	var split: Dictionary = (_card_actions(combat, state)["actions"] as Array)[0]
	expect.call(str(split.get("aim", "")) == "facing" and int(split.get("stagger", 0)) == 3 and not combat.player_action_needs_orientation(split), "Tombsplitter is a facing-aimed line with Stagger 3 and no separate rotation")
	var after: Dictionary = _play_first(combat, state, [Vector2i(3, 4)])
	expect.call(_hp(after, 1) == 48 and _hp(after, 2) == 48 and _hp(after, 3) == 60, "Tombsplitter hits the first two tiles in its line for 12")
	expect.call(_queue_time(after, 1) == _queue_time(state, 1) + 3 and _queue_time(after, 2) == _queue_time(state, 2) + 3 and _queue_time(after, 3) == _queue_time(state, 3), "Tombsplitter staggers each enemy it hits by 3")
	var maul_state: Dictionary = _queued_state(combat, ["tectonic_maul"], [{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 60, "max_hp": 60}])
	var maul_after: Dictionary = _play_first(combat, maul_state, [Vector2i(3, 4), Vector2i(4, 4)])
	expect.call(_hp(maul_after, 1) == 49 and _queue_time(maul_after, 1) == _queue_time(maul_state, 1) + 3, "Tectonic Maul moves, strikes for 11 and staggers 3")
	expect.call(Surface.has_rubble(maul_after, Vector2i(4, 4)) and Surface.has_rubble(maul_after, Vector2i(5, 4)), "Tectonic Maul leaves its Rubble cross at the impact")
	var rubble_state: Dictionary = maul_state.duplicate(true)
	Surface.place(rubble_state, Vector2i(4, 4), "rubble")
	var rubble_after: Dictionary = _play_first(combat, rubble_state, [Vector2i(3, 4), Vector2i(4, 4)])
	expect.call(_hp(rubble_after, 1) == 45, "Tectonic Maul deals 15 to a target already on Rubble")
	var net_state: Dictionary = _queued_state(combat, ["throwing_net"], [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 60, "max_hp": 60}])
	var netted: Dictionary = _play_first(combat, net_state, [Vector2i(5, 4)])
	expect.call(_hp(netted, 1) == 60 and bool(((netted.get("enemies", []) as Array)[0] as Dictionary).get("immobilize", false)) and _queue_time(netted, 1) == _queue_time(net_state, 1) + 3, "Throwing Net's zero-damage throw still Immobilizes and staggers 3")
	expect.call(((netted.get("deck", {}) as Dictionary).get("consumed", []) as Array).has("throwing_net"), "Throwing Net is consumed")
	var cap: Dictionary = _play_first(combat, _queued_state(combat, ["capacitor", "chain_bolt", "quick_stab"], [{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 60, "max_hp": 60}]), [])
	var bolt: Dictionary = combat._resolved_surface_action(cap, (_card_actions(combat, cap)["actions"] as Array)[0] as Dictionary)
	var stab_hand: Dictionary = _with_hand(cap, ["quick_stab"])
	var stab: Dictionary = combat._resolved_surface_action(stab_hand, (_card_actions(combat, stab_hand)["actions"] as Array)[0] as Dictionary)
	expect.call(int(bolt.get("chain", 0)) == 4 and int(stab.get("chain", 0)) == 0, "Capacitor's Chain 2 reaches only the next Lightning attack")
	for card_id: String in ["crushing_blow", "heel_hook", "crack_the_whip", "clockwork_mark", "throwing_net"]:
		var stagger: int = 0
		for action: Dictionary in GameData.card_def(card_id).get("actions", []):
			stagger = maxi(stagger, int(action.get("stagger", 0)))
		expect.call(stagger > 0 and _row_values(card_id).has("stagger=%d" % stagger), "%s shows its Stagger %d chip" % [card_id, stagger])


static func _test_wave2_tiles_moved_scaling(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _queued_state(combat, ["iron_wheel"], [{"id": 1, "type": "crawler", "pos": Vector2i(6, 4), "hp": 60, "max_hp": 60}])
	var wheel: Array = _card_actions(combat, state)["actions"]
	var strike: Dictionary = wheel[1]
	expect.call(combat.final_damage_for_player_action(state, strike) == 4, "Iron Wheel prints 4 before moving")
	var moved: Dictionary = combat.apply_player_action(combat.prepare_player_card(state, 0, "play"), wheel[0] as Dictionary, Vector2i(5, 4))
	expect.call(combat.final_damage_for_player_action(moved, strike) == 7, "Iron Wheel's strike gains 1 per tile moved (3)")
	var preview: Dictionary = combat.surface_preview_for_player_action(moved, strike, Vector2i(6, 4), true)["state"]
	var hit: Dictionary = combat.apply_player_action(moved, strike, Vector2i(6, 4))
	expect.call(_hp(hit, 1) == 53 and _hp(preview, 1) == _hp(hit, 1), "Iron Wheel's scaled strike previews and resolves for 7")
	var lance_state: Dictionary = _queued_state(combat, ["couched_lance"], [{"id": 1, "type": "crawler", "pos": Vector2i(6, 4), "hp": 60, "max_hp": 60}])
	var lance: Dictionary = (_card_actions(combat, lance_state)["actions"] as Array)[0]
	var walked: Dictionary = combat.apply_player_movement(lance_state, Vector2i(4, 4))
	expect.call(combat.final_damage_for_player_action(walked, lance) == 6 and combat.valid_targets_for_player_action(walked, lance).has(Vector2i(6, 4)), "Couched Lance counts independent movement and strikes at reach 2")
	var capped: Dictionary = walked.duplicate(true)
	capped["turn_flags"]["tiles_moved"] = 9
	expect.call(combat.final_damage_for_player_action(capped, lance) == 9, "Couched Lance's bonus caps at +5")


static func _test_wave2_light_state_bonuses(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var cases: Array = [
		["hallowed_strike", Vector2i(3, 4), 6, 10, 0, 0],
		["sunlance", Vector2i(6, 4), 4, 7, 0, 0],
		["dazzle", Vector2i(5, 4), 2, 2, 0, 3],
		["blinding_bash", Vector2i(3, 4), 4, 4, 0, 3],
	]
	for case_var: Variant in cases:
		var case: Array = case_var
		var card_id: String = str(case[0])
		var tile: Vector2i = case[1]
		var state: Dictionary = _queued_state(combat, [card_id], [{"id": 1, "type": "crawler", "pos": tile, "hp": 60, "max_hp": 60}])
		var dark: Dictionary = _play_first(combat, state, [tile])
		var lit_state: Dictionary = state.duplicate(true)
		var umbra: Dictionary = (lit_state.get("umbra", {}) as Dictionary).duplicate(true)
		umbra["light_sources"] = [{"pos": tile, "radius": 0, "remaining_activations": 2}]
		lit_state["umbra"] = umbra
		var lit: Dictionary = _play_first(combat, lit_state, [tile])
		expect.call(_hp(dark, 1) == 60 - int(case[2]) and _hp(lit, 1) == 60 - int(case[3]), "%s deals %d, or %d to a target in Light" % [card_id, int(case[2]), int(case[3])])
		expect.call(_queue_time(dark, 1) - _queue_time(state, 1) == int(case[4]) and _queue_time(lit, 1) - _queue_time(state, 1) == int(case[5]), "%s staggers %d only when the target stands in Light" % [card_id, int(case[5])])
	var chop: Dictionary = _queued_state(combat, ["butcher_chop"], [{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 30, "max_hp": 60}])
	expect.call(_hp(_play_first(combat, chop, [Vector2i(3, 4)]), 1) == 15, "Butcher Chop deals 15 to a target at half health")


static func _test_wave2_patterned_outcrop(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _queued_state(combat, ["earthen_rampart"], [{"id": 1, "type": "crawler", "pos": Vector2i(8, 6), "hp": 60, "max_hp": 60}])
	var started: Dictionary = _card_actions(combat, state)
	var raise: Dictionary = (started["actions"] as Array)[0]
	expect.call(str(raise.get("type", "")) == "outcrop" and combat.player_action_needs_orientation(raise), "Earthen Rampart's three-tile line asks for an aim")
	var east: Dictionary = raise.duplicate(true)
	east["orientation"] = Vector2i(1, 0)
	var south: Dictionary = raise.duplicate(true)
	south["orientation"] = Vector2i(0, 1)
	var target := Vector2i(4, 4)
	expect.call(_same_tiles(combat.outcrop_tiles_for_player_action(state, east, target), [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]), "An east aim raises a horizontal line centered on the target")
	expect.call(_same_tiles(combat.outcrop_tiles_for_player_action(state, south, target), [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]), "A rotated aim raises a vertical line")
	var raised: Dictionary = combat.apply_player_action(started["state"], south, target)
	var preview: Dictionary = combat.surface_preview_for_player_action(started["state"], south, target)["state"]
	expect.call((raised.get("terrain", []) as Array).size() == 3 and (preview.get("terrain", []) as Array).size() == 3, "The rotated raise previews and commits three outcrops")
	var finished: Dictionary = combat.finish_player_card(combat.apply_player_action(raised, (started["actions"] as Array)[1] as Dictionary, NO_TILE), 0)
	expect.call(int((finished.get("player", {}) as Dictionary).get("stoneskin", 0)) == 3, "Earthen Rampart then grants 3 Stoneskin")
	var empowered: Dictionary = (_card_actions(combat, state, "empower")["actions"] as Array)[0]
	empowered["orientation"] = Vector2i(0, 1)
	expect.call(combat.outcrop_tiles_for_player_action(state, empowered, Vector2i(4, 4)).size() == 5, "Empowered Earthen Rampart raises a five-tile line")
	var tokens: Array = ActionIcons.tokens_for_action(raise)
	expect.call(str((tokens[0] as Dictionary).get("icon", "")) == "raise_terrain" and tokens.any(func(token: Dictionary) -> bool: return str(token.get("kind", "")) == "aoe_pattern"), "The outcrop row shows outcrop health and its line pattern")


static func _test_wave3_reactive_and_tempo_cards(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var enemies: Array = [{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 40, "max_hp": 40}]
	for case_var: Variant in [["undertaker_stand", 8, 5], ["battle_rhythm", 4, 3], ["spike_check", 5, 3], ["deflect", 3, 4], ["brace_the_spear", 3, 5]]:
		var case: Array = case_var
		var state: Dictionary = _play_first(combat, _queued_state(combat, [str(case[0])], enemies), [])
		expect.call(int((state.get("player", {}) as Dictionary).get("block", 0)) == int(case[1]) and int((state.get("retaliate", {}) as Dictionary).get("amount", 0)) == int(case[2]), "%s grants %d Block and Retaliate %d" % [str(case[0]), int(case[1]), int(case[2])])
		var struck: Dictionary = combat._resolve_enemy_action(state.duplicate(true), 0, {"type": "melee", "damage": 3, "range": 1})
		expect.call(_hp(struck, 1) == 40 - int(case[2]), "%s's Retaliate answers an enemy melee hit" % str(case[0]))
	var mail: Dictionary = _play_first(combat, _queued_state(combat, ["barbed_mail"], enemies), [])
	var mailed: Dictionary = combat._resolve_enemy_action(mail.duplicate(true), 0, {"type": "melee", "damage": 3, "range": 1})
	expect.call(_hp(mailed, 1) == 37 and int(((mailed.get("enemies", []) as Array)[0] as Dictionary).get("bleed", 0)) == 1, "Barbed Mail retaliates 3 with Bleed 1")
	var mantle: Dictionary = _play_first(combat, _queued_state(combat, ["static_mantle"], enemies), [])
	var shocked: Dictionary = combat._resolve_enemy_action(mantle.duplicate(true), 0, {"type": "melee", "damage": 3, "range": 1})
	expect.call(int(((shocked.get("enemies", []) as Array)[0] as Dictionary).get("shock", 0)) > 0 and _hp(shocked, 1) == 40, "Static Mantle Shocks a melee attacker without damage")
	var eye: Dictionary = _play_first(combat, _queued_state(combat, ["eye_of_the_storm"], enemies), [])
	var pushed: Dictionary = combat._resolve_enemy_action(eye.duplicate(true), 0, {"type": "melee", "damage": 3, "range": 1})
	expect.call(((pushed.get("enemies", []) as Array)[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(5, 4), "Eye of the Storm pushes a melee attacker 2 tiles")
	# Quicken: the next card this turn costs less, never the Quicken card itself.
	var rush: Dictionary = _queued_state(combat, ["static_rush", "bloody_lunge"], enemies)
	rush = _play_first(combat, rush, [Vector2i(2, 3)])
	expect.call(int(rush.get("player_turn_time_spent", 0)) == 2 and combat.card_time_cost("bloody_lunge", rush) == 4, "Static Rush pays its own 2 Time and Quickens the next card by 2")
	for case_var: Variant in [["galvanize", 1, 2], ["stolen_moment", 1, 3], ["hourglass_sand", 2, 4], ["charged_orb", 2, 2], ["spur_spark", 2, 1]]:
		var case: Array = case_var
		var quick: Dictionary = _play_first(combat, _queued_state(combat, [str(case[0]), "overhead_smash"], enemies), [Vector2i(2, 3)])
		expect.call(int(quick.get("player_turn_time_spent", 0)) == int(case[1]) and combat.card_time_cost("overhead_smash", quick) == 7 - int(case[2]), "%s Quickens the next card by %d" % [str(case[0]), int(case[2])])
	# Next-attack buffs reach the next attack card, including Pierce.
	var stone: Dictionary = _play_first(combat, _queued_state(combat, ["whetstone", "quick_stab"], enemies), [])
	var stab: Dictionary = (_card_actions(combat, stone)["actions"] as Array)[0]
	var buffed: Dictionary = combat._resolved_surface_action(stone, stab)
	expect.call(combat.final_damage_for_player_action(stone, stab) == 13 and bool(buffed.get("pierce", false)), "Whetstone's next attack deals 4 more and Pierces (Quick Stab with Follow-up: 9 + 4)")
	var oath: Dictionary = _play_first(combat, _queued_state(combat, ["sworn_oath", "hurl_spear"], [{"id": 1, "type": "crawler", "pos": Vector2i(6, 4), "hp": 40, "max_hp": 40}]), [])
	var after_oath: Dictionary = _play_first(combat, oath, [Vector2i(6, 4)])
	expect.call(_hp(after_oath, 1) == 31 and TempoRules.next_attack_buffs(after_oath).is_empty(), "Sworn Oath's +3 lands on the next attack and is consumed")
	var gate: Dictionary = _play_first(combat, _queued_state(combat, ["shadow_gate"], enemies), [Vector2i(5, 5)])
	expect.call((gate.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(5, 5) and TempoRules.next_attack_buffs(gate).size() == 1, "Shadow Gate blinks 4 and readies a next-attack bonus")
	var dash: Dictionary = _play_first(combat, _queued_state(combat, ["headlong", "quick_stab"], [{"id": 1, "type": "crawler", "pos": Vector2i(7, 4), "hp": 40, "max_hp": 40}]), [Vector2i(6, 4)])
	var dash_stab: Dictionary = (_card_actions(combat, dash)["actions"] as Array)[0]
	expect.call(combat.final_damage_for_player_action(dash, dash_stab) == 9 + 4, "Headlong's 4-tile run adds +4 to the next attack")


static func _test_wave3_thorn_crown_pact(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var card: Dictionary = GameData.card_def("thorn_crown_pact")
	expect.call(ActionIcons.card_is_rite(card) and ActionIcons.card_rules_text(card).contains("Health cost %d" % int(card.get("health_cost", 0))), "Thorn Crown Pact renders Rite text with its health cost")
	var state: Dictionary = _queued_state(combat, ["thorn_crown_pact"], [{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 40, "max_hp": 40}])
	var started: Array = _card_actions(combat, state)["actions"]
	expect.call(started.size() == 1 and str((started[0] as Dictionary).get("type", "")) == "rite" and not combat.player_action_needs_target(started[0] as Dictionary), "A Rite plays as one targetless step")
	var after: Dictionary = _play_first(combat, state, [])
	expect.call(int((after.get("player", {}) as Dictionary).get("hp", 0)) == 30 - int(card.get("health_cost", 0)) and int(after.get("player_turn_time_spent", 0)) == int(card.get("time", 0)), "Thorn Crown Pact pays its printed health cost and Time")
	expect.call(((after.get("deck", {}) as Dictionary).get("burned", []) as Array).has("thorn_crown_pact") and RiteRules.active_rites(after).size() == 1, "The Rite exhausts and stays active for the combat")
	var struck: Dictionary = combat._resolve_enemy_action(after.duplicate(true), 0, {"type": "melee", "damage": 3, "range": 1})
	expect.call(_hp(struck, 1) == 37 and int(((struck.get("enemies", []) as Array)[0] as Dictionary).get("bleed", 0)) == 1, "Thorns answer every melee hit with 3 and Bleed 1")
	for rite_id: String in ["rite_of_the_pyre", "salamander_heart", "rite_of_hoarfrost", "rite_of_the_storm", "tempest_form", "rite_of_tailwinds", "rite_of_the_mountain", "rite_of_noon"]:
		var rite_state: Dictionary = _play_first(combat, _queued_state(combat, [rite_id], [{"id": 1, "type": "crawler", "pos": Vector2i(6, 4), "hp": 40, "max_hp": 40}]), [])
		expect.call(RiteRules.active_rites(rite_state).size() == 1 and not RiteRules.effects(rite_state).is_empty(), "%s starts a Rite with live effects" % rite_id)
	# Rite of the Pyre boosts "your" Fire: player-made tiles only.
	var pyre: Dictionary = _play_first(combat, _queued_state(combat, ["rite_of_the_pyre"], [{"id": 1, "type": "crawler", "pos": Vector2i(6, 4), "hp": 40, "max_hp": 40}]), [])
	var own_fire: Dictionary = pyre.duplicate(true)
	Surface.place(own_fire, Vector2i(6, 4), "fire", {"actor_kind": "player", "causal_owner": "player"})
	var enemy_fire: Dictionary = pyre.duplicate(true)
	Surface.place(enemy_fire, Vector2i(6, 4), "fire", {"actor_kind": "enemy", "causal_owner": "enemy"})
	var own_burn: int = 40 - _hp(combat._surface_contact(own_fire, "enemy", 1, CombatEngine.INVALID_TILE, true), 1)
	var enemy_burn: int = 40 - _hp(combat._surface_contact(enemy_fire, "enemy", 1, CombatEngine.INVALID_TILE, true), 1)
	expect.call(own_burn == enemy_burn + 2 and enemy_burn > 0, "Rite of the Pyre adds 2 to the hero's Fire only (%d vs %d)" % [own_burn, enemy_burn])
	var tempest: Dictionary = _play_first(combat, _queued_state(combat, ["tempest_form", "overhead_smash"], [{"id": 1, "type": "crawler", "pos": Vector2i(6, 4), "hp": 40, "max_hp": 40}]), [])
	expect.call(combat.card_time_cost("overhead_smash", tempest) == int(GameData.card_def("overhead_smash").get("time", 0)) - 1 and int(tempest.get("player_turn_time_spent", 0)) == int(GameData.card_def("tempest_form").get("time", 0)), "Tempest Form discounts later cards, never itself")


static func _test_wave23_grimoire_unlocks(expect: Callable) -> void:
	var expected: Dictionary = {
		"quick_stab": ["keyword:follow_up"],
		"bloody_lunge": ["keyword:empower", "keyword:health_cost"],
		"tombsplitter": ["keyword:stagger"],
		"dazzle": ["keyword:stagger", "keyword:illuminate"],
		"sunlance": ["keyword:illuminate"],
		"stonefist": ["keyword:stoneskin"],
		"couched_lance": ["keyword:move"],
		"deflect": ["keyword:retaliate"],
		"galvanize": ["keyword:quicken"],
		"whetstone": ["keyword:next_attack", "keyword:pierce"],
		"thorn_crown_pact": ["keyword:rite", "keyword:retaliate", "keyword:bleed", "keyword:health_cost"],
		"rite_of_hoarfrost": ["keyword:rite", "keyword:freeze", "keyword:block", "keyword:draw"],
		"salamander_heart": ["keyword:surface_fire", "keyword:stoneskin"],
		"rite_of_tailwinds": ["keyword:move", "keyword:push", "keyword:pull"],
		"rite_of_noon": ["keyword:illuminate"],
		"earthen_rampart": ["combat:outcrops", "keyword:empower", "keyword:exhaust"],
	}
	for card_id: String in expected:
		var ids: Array[String] = Grimoire.entry_ids_for_card_ids([card_id])
		for entry_id: String in expected[card_id]:
			expect.call(ids.has(entry_id) and not Grimoire.entry_def(entry_id).is_empty(), "%s unlocks %s: %s" % [card_id, entry_id, str(ids)])


static func _test_live_earthen_rampart_rotate(tree: SceneTree, expect: Callable) -> void:
	var store = preload("res://scripts/progression_store.gd")
	var settings = preload("res://scripts/settings_store.gd")
	var analytics = preload("res://scripts/analytics_store.gd")
	var tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
	var profile_path: String = store._storage_path
	var run_path: String = store._run_storage_path
	var settings_path: String = settings.storage_path()
	var analytics_path: String = analytics.storage_dir()
	var prefix: String = "user://card_pool_rampart_live_%d" % Time.get_ticks_usec()
	store.set_storage_path(prefix + "_profile.json")
	store.set_run_storage_path(prefix + "_run.save")
	settings.set_storage_path(prefix + "_settings.json")
	analytics.set_storage_dir(prefix + "_events")
	var profile: Dictionary = store.default_data()
	profile[tutorial.PROGRESSION_KEY] = {"version": tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	store.save_data(profile)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	var combat := CombatEngine.new()
	var state: Dictionary = _queued_state(combat, ["earthen_rampart"], [{"id": 1, "type": "crawler", "pos": Vector2i(8, 6), "hp": 60, "max_hp": 60}])
	state["analytics"] = {"combat_id": "card_pool_rampart_live_c001"}
	var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = state
	run["analytics"] = {"run_id": "card_pool_rampart_live", "combat_counter": 1}
	instance.set("_run_state", run)
	instance.set("_combat_state", state)
	instance.set("_dialogue_active", false)
	instance.call("_mark_combat_preview_state_changed")
	await tree.process_frame
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	var target := Vector2i(4, 4)
	expect.call(bool(instance.call("_current_action_supports_rotation")), "A patterned outcrop raise supports Rotate like an area")
	instance.call("_refresh_action_step_tracker")
	expect.call(instance.find_child("ActionContextRotate", true, false) != null, "The action-context Rotate button appears for Earthen Rampart")
	instance.call("_on_board_tile_hovered", target)
	var hovered: Dictionary = instance.call("_active_card_preview")
	var default_tiles: Array = instance.call("_focus_tiles_for_preview", hovered)
	expect.call(_same_tiles(default_tiles, [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]), "Hover highlights the default east-west line: %s" % str(default_tiles))
	instance.call("_on_rotate_action_context_pressed")
	instance.call("_on_board_tile_hovered", target)
	var rotated: Dictionary = instance.call("_active_card_preview")
	var rotated_tiles: Array = instance.call("_focus_tiles_for_preview", rotated)
	expect.call(_same_tiles(rotated_tiles, [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]), "Rotate turns the highlighted line north-south: %s" % str(rotated_tiles))
	await instance.call("_on_board_tile_clicked", target)
	await tree.create_timer(1.5).timeout
	var final_state: Dictionary = instance.get("_combat_state")
	var raised: Array[Vector2i]
	for entry: Dictionary in final_state.get("terrain", []):
		if str(entry.get("kind", "")) == "crag_outcrop":
			raised.append(entry.get("pos", NO_TILE))
	expect.call(_same_tiles(raised, [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]), "The committed raise follows the rotated aim: %s" % str(raised))
	expect.call(int((final_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 3 and int(instance.get("_selected_card_index")) < 0, "Earthen Rampart commits with one board decision and grants 3 Stoneskin")
	instance.queue_free()
	await tree.process_frame
	await tree.process_frame
	store.clear_saved_run()
	store.set_storage_path(profile_path)
	store.set_run_storage_path(run_path)
	settings.set_storage_path(settings_path)
	analytics.set_storage_dir(analytics_path)


static func _display_damage(rows: Array) -> int:
	for row_var: Variant in rows:
		for token_var: Variant in row_var as Array:
			var token: Dictionary = token_var
			if str(token.get("field", "")) == "damage":
				return int(token.get("value", -1))
	return -1


static func _test_wave23_hand_display(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene: Node = RunSceneScript.new()
	var state: Dictionary = _queued_state(combat, ["quick_stab"], [{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 40, "max_hp": 40}])
	for card_id: String in WAVE23_CARD_IDS:
		var card: Dictionary = GameData.card_def(card_id)
		expect.call(not card.is_empty() and not bool(card.get("retired", false)), "%s is a live card" % card_id)
		var display: Dictionary = scene.call("_card_widget_display", card_id, state)
		var rows: Array = display.get("summary_rows", [])
		if ActionIcons.card_is_rite(card):
			expect.call(rows.is_empty() and str(display.get("summary_bbcode", "")) == ActionIcons.card_rules_text(card) and str(card.get("description", "")).begins_with("Rite:"), "%s shows its Rite rules text in the hand" % card_id)
			continue
		expect.call(not rows.is_empty(), "%s shows icon rows in the hand" % card_id)
		var keyword_segments: Array[String]
		for row_var: Variant in rows:
			for token_var: Variant in row_var as Array:
				var token: Dictionary = token_var
				expect.call(not str(token.get("value", "")).ends_with(".0"), "%s hand chip %s prints a whole number" % [card_id, str(token.get("icon", ""))])
				if token.has("keyword_segment"):
					keyword_segments.append(str(token["keyword_segment"]))
		expect.call(keyword_segments.has("follow_up") == card.has("follow_up") and keyword_segments.has("empower") == card.has("empower"), "%s shows exactly its Follow-up / Empower segments: %s" % [card_id, str(keyword_segments)])
	expect.call(_display_damage((scene.call("_card_widget_display", "quick_stab", state) as Dictionary).get("summary_rows", [])) == 6, "The hand shows Quick Stab's printed 6 before any card is played")
	var warm: Dictionary = state.duplicate(true)
	warm["cards_played_this_turn"] = 1
	expect.call(_display_damage((scene.call("_card_widget_display", "quick_stab", warm) as Dictionary).get("summary_rows", [])) == 9, "The hand shows Quick Stab's Follow-up 9 after a card")
	var armored: Dictionary = state.duplicate(true)
	(armored["player"] as Dictionary)["stoneskin"] = 3
	expect.call(_display_damage((scene.call("_card_widget_display", "stonefist", armored) as Dictionary).get("summary_rows", [])) == 8, "The hand shows Stonefist's current Stoneskin-scaled damage")
	var walked: Dictionary = state.duplicate(true)
	walked["turn_flags"]["tiles_moved"] = 2
	expect.call(_display_damage((scene.call("_card_widget_display", "couched_lance", walked) as Dictionary).get("summary_rows", [])) == 6, "The hand shows Couched Lance's tiles-moved damage")
	scene.free()
