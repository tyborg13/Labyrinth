extends SceneTree
## Run the txt-32 resolver-witness approach against the rendered article inventory.

const F = preload("res://tools/txt24/fixture.gd")
const Run = preload("res://scripts/run_engine.gd")
const Profile = preload("res://scripts/progression_store.gd")
const SummonPlays = preload("res://scripts/summon_card_play_rules.gd")
const Depths = preload("res://scripts/depth_rules.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")
const PassForecast = preload("res://scripts/pass_forecast_red_tiles.gd")
const Authored = preload("res://scripts/guardian_combat_rules.gd")
const Dragon = preload("res://scripts/dragon_combat_rules.gd")
const SurfaceCards = preload("res://scripts/surface_card_rules.gd")

const FATIGUE_DEPTHS: Array = [0, 17, 18]
const FATIGUE_RESHUFFLES: int = 2
const TEST_BLOCK: int = 50
const FRAIL_DEPTH: int = 14
const DEFIANCE_LEVEL: int = 4
const LETHAL_TEST_HEALTH: int = 1
const CROWN_FIRE: Vector2i = Vector2i(7, 2)
const NEAR_BRAZIER: Vector2i = F.PLAYER + Vector2i.LEFT
const MAX_TEST_LAYERS: int = 2
const FAR_BRAZIER: Vector2i = Vector2i(7, 7)

var _articles: Dictionary
var _checks: int
var _design_findings: int
var _failed: int


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path: String = OS.get_environment("TXT34_OUTPUT").path_join("inventory.json")
	_articles = JSON.parse_string(FileAccess.get_file_as_string(path))
	var engine := F.Combat.new()
	_map()
	_defiance(engine)
	_targeting(engine)
	_fatigue(engine)
	_summon_card_play(engine)
	_crownfire(engine)
	_meteorfall(engine)
	_shatterstorm(engine)
	_crystal_mantle_card(engine)
	_night_coil(engine)
	print("TXT34 RULES WITNESSES: %s (%d checks, %d design findings, %d unexpected failures)" %
		["PASS" if _failed == 0 else "FAIL", _checks, _design_findings, _failed])
	quit(int(_failed != 0))


func _record(id: String, article: String, quote: String, observed: bool, details: String,
		design_finding: String = "") -> void:
	var rendered: bool = quote in _articles.get(article, {}).get("body", "")
	var ok: bool = observed and rendered
	_checks += 1
	_design_findings += int(ok and not design_finding.is_empty())
	_failed += int(not ok)
	var verdict: String = design_finding if ok and not design_finding.is_empty() else ("PASS" if ok else "FAIL")
	print("TXT34 WITNESS %s | %s | %s%s" % [id, verdict, details, "" if rendered else " Rendered quote missing."])


func _map() -> void:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(F.SEED, Profile.default_data())
	var start: Vector2i = state["current_room"]
	var available: Array = engine.available_moves(state)
	var first: Vector2i = available.front()
	var revealed: bool = engine.room_metadata(state, first)["revealed"]
	state = engine.move_to_room(state, first)
	var previous: Dictionary = engine.room_metadata(state, start)
	var return_is_legal: bool = engine.available_moves(state).has(start)
	_record("map_revealed_move", "basic:map", "Revealed exits show where you can travel next.",
		revealed and state["current_room"] == first, "Revealed exit %s is a legal next room." % str(first))
	_record("map_sealed", "basic:map", "Rooms you leave are sealed behind you.",
		previous["cleared"] and previous["sealed"] and not return_is_legal,
		"Departed room cleared=%s, sealed=%s, legal return=%s." % [previous["cleared"], previous["sealed"], return_is_legal])


func _defiance(engine: RefCounted) -> void:
	var run_engine := Run.new()
	var profile: Dictionary = Profile.default_data()
	profile[Profile.UMBRA_DEPTH_UNLOCKED_KEY] = FRAIL_DEPTH
	profile["level"] = DEFIANCE_LEVEL
	var descent: Dictionary = run_engine.create_new_run(F.SEED, profile, true, FRAIL_DEPTH)
	var state: Dictionary = F.fight(engine)
	var maximum: int = descent["player_max_hp"]
	state["player"]["max_hp"] = maximum
	state["player"]["hp"] = LETHAL_TEST_HEALTH
	state["defiance_capacity"] = run_engine.defiance_capacity(descent)
	state["defiance_remaining"] = run_engine.defiance_remaining(descent)
	state["enemies"][0]["intent"] = F.intent("crawler", "skitter_strike")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var hp: int = result["player"]["hp"]
	var spent: int = state["defiance_remaining"] - int(result["defiance_remaining"])
	var quote: String = "Each Defiance charge saves you from 1 lethal hit and leaves you at 25% of your maximum Health, rounded up."
	_record("defiance_lethal_hit", "combat:defiance", quote, hp > 0 and spent == 1,
		"Lethal Skitter Strike spends %d charge and leaves %d Health." % [spent, hp])
	_record("defiance_rounding", "combat:defiance", quote, hp == 6 and maximum == 22,
		"Maximum Health %d, literal quarter %.1f, restored %d." % [maximum, maximum * 0.25, hp],
		"TODO_DESIGN_combat_defiance")


func _targeting(engine: RefCounted) -> void:
	var state: Dictionary = F.fight(engine)
	var tile: Vector2i = state["enemies"][0]["pos"]
	var attack: Dictionary = engine.card_def("arc_flash", state)["actions"][0]
	var light: Dictionary = engine.card_def("beacon", state)["actions"][0]
	var visible_attack: bool = engine.valid_targets_for_player_action(state, attack).has(tile)
	var too_far: Dictionary = state.duplicate(true)
	too_far["enemies"][0]["pos"] = F.PLAYER + Vector2i.RIGHT * (int(attack["range"]) + 1)
	var range_rejects: bool = not engine.valid_targets_for_player_action(too_far, attack).has(too_far["enemies"][0]["pos"])
	var wall: Dictionary = state.duplicate(true)
	wall["grid"][F.PLAYER.y][F.PLAYER.x + 1] = "wall"
	wall["umbra"]["vision_activations"] = 1
	var wall_rejects: bool = not engine.valid_targets_for_player_action(wall, attack).has(tile)
	state["umbra"]["stage"] = "eclipse"
	var hidden: bool = not engine.is_enemy_visible_to_player(state, state["enemies"][0])
	var attack_rejects: bool = not engine.valid_targets_for_player_action(state, attack).has(tile)
	var light_accepts: bool = engine.valid_targets_for_player_action(state, light).has(tile)
	var lit: Dictionary = engine.apply_player_action(state, light, tile)
	var attack_after_light: bool = engine.valid_targets_for_player_action(lit, attack).has(tile)
	_record("targeting_attack_and_light", "combat:targeting", "Attacks need a visible target within Range.",
		visible_attack and hidden and attack_rejects and range_rejects and light_accepts and attack_after_light,
		"Arc Flash can target in-range visible enemy=%s, out-of-range rejected=%s, hidden rejected=%s. Beacon targets the hidden tile=%s and restores attack legality=%s." %
		[visible_attack, range_rejects, attack_rejects, light_accepts, attack_after_light])
	_record("targeting_ranged_sight", "combat:targeting", "Ranged attacks also need line of sight.",
		visible_attack and wall_rejects, "A wall between the hero and the visible Arc Flash target blocks the cast.")
	var skybolt: Dictionary = engine.card_def("skybolt", wall)["actions"][0]
	var bypass: bool = engine.valid_targets_for_player_action(wall, skybolt).has(tile)
	_record("targeting_ranged_exception", "combat:targeting", "Ranged attacks also need line of sight.",
		wall_rejects and bypass, "Skybolt can target the same visible enemy through the wall.",
		"TODO_DESIGN_combat_targeting")


func _empty_draw(state: Dictionary) -> void:
	state["deck"]["hand"] = []
	state["deck"]["draw"] = []
	state["deck"]["discard"] = ["arc_flash"]


func _fatigue(engine: RefCounted) -> void:
	var losses: Array = []
	var new_combat_losses: Array[int]
	var kept_block: bool = true
	for depth: int in FATIGUE_DEPTHS:
		var layout: Dictionary = {"player_start": F.PLAYER, "grid": F.grid(),
			"enemies": [F.unit("crawler", 0, F.ENEMY)], Depths.STATE_KEY: depth}
		var profile: Dictionary = {"hp": F.TEST_HEALTH, "max_hp": F.TEST_HEALTH, "deck_cards": F.Data.starting_deck()}
		var state: Dictionary = engine.create_combat(F.SEED, layout, profile)
		var per_depth: Array[int]
		for _cycle: int in range(FATIGUE_RESHUFFLES):
			_empty_draw(state)
			state["player"]["block"] = TEST_BLOCK
			var before: int = state["player"]["hp"]
			state = engine._draw_cards_in_place(state, 1)
			per_depth.append(before - int(state["player"]["hp"]))
			kept_block = kept_block and int(state["player"]["block"]) == TEST_BLOCK
		losses.append(per_depth)
		var fresh: Dictionary = engine.create_combat(F.SEED, layout, profile)
		_empty_draw(fresh)
		fresh = engine._draw_cards_in_place(fresh, 1)
		new_combat_losses.append(F.TEST_HEALTH - int(fresh["player"]["hp"]))
	_record("fatigue_steps_and_resets", "combat:fatigue", "Each Fatigue in a combat costs 1 more Health than the last.",
		losses == [[2, 3], [2, 3], [3, 4]] and new_combat_losses == [2, 2, 3],
		"Depths %s reshuffle costs %s. Fresh combat costs %s." % [FATIGUE_DEPTHS, losses, new_combat_losses])
	_record("fatigue_ignores_block", "combat:fatigue", "Fatigue bypasses Block.", kept_block and losses[0][0] > 0,
		"Each reshuffle costs Health and retains the full %d Block." % TEST_BLOCK)
	var preview_state: Dictionary = F.fight(engine)
	_empty_draw(preview_state)
	var forecast: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(PassForecast.schedule(engine, preview_state), true)
	var draw: Dictionary = engine.card_def("beacon", preview_state)["actions"][1]
	var drawn: Dictionary = engine.apply_player_action(preview_state, draw)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene._pending_actions.assign(engine.card_def("beacon", preview_state)["actions"])
	scene._pending_action_index = 0
	var draw_preview: Dictionary = {}
	scene._append_followup_fatigue_preview(draw_preview, preview_state)
	scene.free()
	var loss: int = F.TEST_HEALTH - int(drawn["player"]["hp"])
	var draw_cost: int = draw_preview.get("damage_preview", {}).get("player", {}).get("hp_loss", 0)
	var pass_cost: int = forecast.get("fatigue_loss", 0)
	_record("fatigue_preview_cost", "combat:fatigue", "Draw and Pass previews show the Health that Fatigue costs.",
		loss == 2 and pass_cost == loss and draw_cost == loss,
		"Draw resolution costs %d, Draw preview reports %d and Pass forecast reports %d." % [loss, draw_cost, pass_cost])


func _summon_card_play(engine: RefCounted) -> void:
	var state: Dictionary = F.fight(engine, "zekarion")
	state["enemies"][0]["intent"] = F.intent("zekarion", "call_wisps")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var pending: int = result.get(SummonPlays.PENDING_FIELD, 0)
	var turn: Dictionary = engine.prepare_next_player_turn(result)
	var bonus: int = turn.get("card_play_bonus_this_turn", 0)
	var wisps: Array = (turn["enemies"] as Array).filter(func(unit: Dictionary) -> bool: return unit.get("type") == "lightning_wisp")
	_record("summon_play", "keyword:card_play", "Each enemy summon gives you 1 more Card Play next turn.",
		wisps.size() == 1 and pending == 1 and bonus == 1, "Arrivals=%d, pending=%d, next-turn bonus=%d." % [wisps.size(), pending, bonus])
	if wisps.is_empty():
		_record("summoned_kill", "keyword:card_play", "Killing a summoned enemy gives none.", false, "No Wisp arrived.")
		return
	var wisp: Dictionary = wisps.front()
	wisp["hp"] = LETHAL_TEST_HEALTH
	var index: int = engine._enemy_index_for_id(turn, wisp["id"])
	var action: Dictionary = engine.card_def("arc_flash", turn)["actions"][0]
	var target: Vector2i = wisp["pos"]
	var before: int = turn.get("death_bonus_card_plays_this_turn", 0)
	var killed: Dictionary = engine.apply_player_action(turn, action, target)
	var control: Dictionary = turn.duplicate(true)
	control["enemies"][index]["summoned"] = false
	control = engine.apply_player_action(control, action, target)
	var gained: int = int(killed.get("death_bonus_card_plays_this_turn", 0)) - before
	var control_gain: int = int(control.get("death_bonus_card_plays_this_turn", 0)) - before
	_record("summoned_kill", "keyword:card_play", "Killing a summoned enemy gives none.",
		wisp.get("summoned", false) and int(killed["enemies"][index]["hp"]) == 0 and gained == 0 and control_gain == 1,
		"Lethal Arc Flash: summoned kill grants %d, unsummoned control grants %d." % [gained, control_gain])


func _crownfire(engine: RefCounted) -> void:
	var state: Dictionary = F.fight(engine, "vyraketh")
	var enemy: Dictionary = state["enemies"][0]
	enemy["cinder_tiles"] = F.Combat.TypedArrays.vector2i([CROWN_FIRE])
	Ground.place(state, CROWN_FIRE, "fire", {"actor_kind": "enemy", "actor_id": 0})
	enemy["intent"] = Authored.commit_owned(engine, state, 0, F.intent("vyraketh", "crownfire"))
	var intact: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)
	var replaced: Dictionary = state.duplicate(true)
	Ground.place(replaced, CROWN_FIRE, "ice")
	var no_fire: Dictionary = engine.resolve_enemy_turn_with_steps(replaced, 0, true, false)
	var order: Array[String] = _crownfire_steps(intact["steps"])
	var replacement: Array[String] = _crownfire_steps(no_fire["steps"])
	_record("crownfire_order", "combat:cinder_marks",
		"Crownfire Bursts each of Vyraketh's Marked Fire tiles, then Vyraketh moves toward you and attacks.",
		order == ["Burst", "Move", "Attack"] and replacement == ["Move", "Attack"],
		"Marked Fire resolves %s. Marked Ice resolves %s." % [str(order), str(replacement)])


func _crownfire_steps(steps: Array) -> Array[String]:
	var order: Array[String]
	for step: Dictionary in steps:
		for event: Dictionary in step.get("surface_events", []):
			if event.get("kind") == "detonate": order.append("Burst")
		if step.get("kind") in ["movement", "move"]: order.append("Move")
		if step.get("action_type") == "melee": order.append("Attack")
	return order


func _meteorfall(engine: RefCounted) -> void:
	var state: Dictionary = F.fight(engine)
	var action: Dictionary = engine.card_def("meteorfall", state)["actions"][0]
	var marked: Dictionary = engine.apply_player_action(state, action, F.ENEMY)
	var marks: Array = SurfaceCards.meteor_marks(marked)
	var tiles: Array = [] if marks.is_empty() else marks[0]["tiles"]
	var before: int = marked["enemies"][0]["hp"]
	var next: Dictionary = engine.prepare_next_player_turn(marked)
	var burning: int = 0
	for tile: Vector2i in tiles:
		if Ground.has_surface(next, tile, "fire"): burning += 1
	var damage: int = before - int(next["enemies"][0]["hp"])
	_record("meteorfall_marks", "combat:cinder_marks", "The Meteorfall card Marks tiles.",
		not tiles.is_empty() and before == int(state["enemies"][0]["hp"]), "Meteorfall places %d Marks before any damage." % tiles.size())
	_record("meteorfall_lands", "combat:cinder_marks",
		"At the start of your next turn, each unit on a Marked tile takes damage, and each Marked tile becomes Fire.",
		burning == tiles.size() and damage > 0 and SurfaceCards.meteor_marks(next).is_empty(),
		"Turn start resolves %d enemy Health loss and leaves Fire on %d/%d marked tiles." % [damage, burning, tiles.size()])


func _shatterstorm(engine: RefCounted) -> void:
	var state: Dictionary = F.fight(engine, "iskaldra")
	var intent: Dictionary = F.intent("iskaldra", "shatterstorm")
	var reaches: Array[int]
	var tile_counts: Array[int]
	for layer: int in range(MAX_TEST_LAYERS + 1):
		var fixture: Dictionary = state.duplicate(true)
		fixture["enemies"][0]["frost_armor"] = layer
		var held: Dictionary = Authored.commit(engine, fixture, 0, intent)
		reaches.append(int(Authored.status_range(fixture["enemies"][0], intent["actions"][1])["range"]))
		tile_counts.append(Areas.shown(held["actions"][1]).size())
	state["enemies"][0]["frost_armor"] = MAX_TEST_LAYERS
	state["enemies"][0]["intent"] = Authored.commit_owned(engine, state, 0, intent)
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
	var remaining: int = result["enemies"][0]["frost_armor"]
	_record("shatterstorm_layers", "combat:crystal_armor",
		"Each layer extends Iskaldra's Shatterstorm by 1 tile, and Shatterstorm breaks the remaining layers.",
		reaches == [1, 2, 3] and tile_counts[0] < tile_counts[1] and tile_counts[1] < tile_counts[2] and remaining == 0,
		"Reach for 0, 1, 2 layers is %s, with %s marked tiles. Shatterstorm spends both remaining layers." %
		[str(reaches), str(tile_counts)])


func _crystal_mantle_card(engine: RefCounted) -> void:
	var state: Dictionary = F.fight(engine)
	var card: Dictionary = engine.card_def("crystal_mantle", state)["actions"][0]
	var after_card: Dictionary = engine.apply_player_action(state, card)
	var gained: int = after_card["player"]["frost_armor"]
	var next: Dictionary = engine.prepare_next_player_turn(after_card)
	var retained: int = next["player"]["frost_armor"]
	next["enemies"][0]["intent"] = F.intent("crawler", "skitter_strike")
	var after_hit: Dictionary = engine.resolve_enemy_turn_with_steps(next, 0, true, false)["state"]
	var after_hit_layers: int = after_hit["player"]["frost_armor"]
	var fresh: int = F.fight(engine)["player"].get("frost_armor", 0)
	_record("crystal_mantle_card", "combat:crystal_armor",
		"Crystal Mantle cards give you layers that last until broken or combat ends.",
		gained == int(card["amount"]) and retained == gained and after_hit_layers == gained - 1 and fresh == 0,
		"Card adds %d layers, next turn retains %d, direct hit leaves %d, fresh combat has %d." %
		[gained, retained, after_hit_layers, fresh])


func _night_coil(engine: RefCounted) -> void:
	var state: Dictionary = F.fight(engine, "noctyrax")
	state["guardian_braziers"] = [{"id": 0, "pos": NEAR_BRAZIER, "lit": true}, {"id": 1, "pos": FAR_BRAZIER, "lit": true}]
	var enemy: Dictionary = state["enemies"][0]
	enemy["dragon_cycle"] = -1
	enemy["intent"] = Dragon.declare(engine, state, 0, F.Data.enemy_def("noctyrax")["intents"])
	var snuffed: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, true)["state"]
	var braziers: Array = snuffed["guardian_braziers"]
	_record("night_coil_nearest", "combat:boss_eclipse", "Night Coil puts out the nearest brazier.",
		enemy["intent"]["id"] == "night_coil" and not braziers[0]["lit"] and braziers[1]["lit"],
		"Near brazier lit=%s, far brazier lit=%s." % [braziers[0]["lit"], braziers[1]["lit"]])
	var walk: Dictionary = engine.apply_player_action(snuffed, {"type": "move", "range": 3}, NEAR_BRAZIER)
	var blink: Dictionary = engine.apply_player_action(snuffed, {"type": "blink", "range": 3}, NEAR_BRAZIER)
	_record("night_coil_relight", "combat:boss_eclipse", "Walk or Blink onto a dark brazier's tile to relight that brazier.",
		walk["guardian_braziers"][0]["lit"] and blink["guardian_braziers"][0]["lit"],
		"Walk relight=%s, Blink relight=%s." % [walk["guardian_braziers"][0]["lit"], blink["guardian_braziers"][0]["lit"]])
	var dark: Dictionary = F.fight(engine, "noctyrax")
	dark["umbra"]["stage"] = "eclipse"
	var tile: Vector2i = F.PLAYER + Vector2i.UP * 2
	var hidden: bool = not engine.is_tile_visible_to_player(dark, tile)
	var light: Dictionary = engine.card_def("beacon", dark)["actions"][0]
	var lit: Dictionary = engine.apply_player_action(dark, light, tile)
	_record("eclipse_light", "combat:boss_eclipse", "Light blocks Eclipse's darkness.",
		hidden and engine.is_tile_visible_to_player(lit, tile), "Beacon makes the Eclipse-hidden tile visible.")
