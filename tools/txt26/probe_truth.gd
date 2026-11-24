extends SceneTree
## Scenarios copied from TXT-23 with director-approved post-fix expectations.

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Patterns = preload("res://scripts/pattern_text.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")

const SEED := 2304
const BOARD_SIZE := 9
const HERO := Vector2i(2, 4)
const ADJACENT := Vector2i(3, 4)
const FAR := Vector2i(5, 4)
const OTHER := Vector2i(5, 3)
const NO_TARGET := Vector2i(-1, -1)
const HERO_HEALTH := 24
const PREEXISTING_SKIN := 6
const EARLY_ENEMY_TIME := 5
const GROUND_SOURCE := {"actor_kind": "player", "kind": "card"}

var _combat := Combat.new()
var _preview_scene := RunSceneScript.new()
var _passed := 0
var _failed := 0
var _forecast_checks := 0
var _held_checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Runtime.apply_from_environment()
	_iron_lung()
	_pilgrim_boots()
	_worldheart()
	_eclipse_mantle()
	_hobnail()
	_frost_prism()
	_card_block()
	_hollow_puppet()
	_copper_shod()
	_thresholds()
	_winters_spur()
	_crowncoal()
	_waxen_effigy()
	_overflow_censer()
	_toll_late_bell()
	_briar_throne()
	_additional_regressions()
	_preview_scene.free()
	print("TXT26 forecast comparisons: %d resolver, %d held-card" % [_forecast_checks, _held_checks])
	print("TXT26 truth probe %s: %d rerun cases matched, %d failed" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed,
	])
	quit(int(_failed > 0))


func _state(relics: Array, cards: Array, enemies: Array = [], walls: Array = [], umbra_stage: String = "clear") -> Dictionary:
	var grid: Array = []
	for y: int in range(BOARD_SIZE):
		var row: Array[String]
		for x: int in range(BOARD_SIZE):
			var boundary: bool = x == 0 or y == 0 or x == BOARD_SIZE - 1 or y == BOARD_SIZE - 1
			row.append("wall" if boundary or walls.has(Vector2i(x, y)) else "stone")
		grid.append(row)
	var room: Dictionary = {
		"name": "Relic truth probe", "coord": Vector2i(1, 0), "type": "combat",
		"depth": 1, "grid": grid, "player_start": HERO, "traps": [], "loot": [], "umbra_stage": umbra_stage,
		"enemies": [_enemy(1, ADJACENT)] if enemies.is_empty() else enemies,
	}
	var state: Dictionary = _combat.create_combat(SEED, room, {
		"hp": HERO_HEALTH, "max_hp": HERO_HEALTH, "deck_cards": cards, "relics": relics,
	})
	state["deck"]["hand"] = cards.duplicate()
	state["deck"]["draw"] = []
	return state


func _enemy(id: int, tile: Vector2i, type: String = "crawler") -> Dictionary:
	var definition: Dictionary = Data.enemies()[type]
	var health: int = int(definition["max_hp"])
	var dimensions: Array = definition.get("footprint", [1, 1])
	return {
		"id": id, "type": type, "pos": tile, "hp": health, "max_hp": health,
		"footprint": Vector2i(int(dimensions[0]), int(dimensions[1])),
	}



func _enemy_activation(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	for entry: Dictionary in next["turn_queue"]:
		if entry.get("kind") == "enemy" and entry.get("enemy_id") == 1:
			next["current_actor"] = entry
			break
	return next


func _play(source: Dictionary, id: String, targets: Array = [], mode: String = "play") -> Dictionary:
	var hand: Array = source["deck"]["hand"]
	var index: int = hand.find(id)
	if index < 0 or not _combat.is_player_turn(source) or _combat.cards_remaining_this_turn(source) <= 0:
		_fail("Card unavailable in fixture: " + id)
		return source
	var state: Dictionary = _combat.prepare_player_card(source, index, mode)
	var actions: Array = _combat.card_play_actions(id, state)
	var aimed: int = 0
	for action: Dictionary in actions:
		var tile: Vector2i = NO_TARGET
		if _combat.player_action_needs_target(action):
			if aimed >= targets.size():
				_fail("Missing target for " + id)
				return state
			tile = targets[aimed]
			aimed += 1
			if not _combat.valid_targets_for_player_action(state, action).has(tile):
				_fail("Illegal target for %s (%s): %s" % [id, action["type"], tile])
				return state
		state = _forecast_action(state, action, tile, id)
	return _combat.finish_player_card(state, index, _combat.card_plays_spent_for_actions(actions))


func _forecast_action(state: Dictionary, action: Dictionary, tile: Vector2i, label: String) -> Dictionary:
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = _combat.surface_preview_for_player_action(state, action, tile)
	var after: Dictionary = _combat.apply_player_action(state, action, tile)
	_check(forecast["single_state"] == after and state == before, label + " forecast equals resolution")
	_forecast_checks += 1
	_preview_scene.set("_combat_state", state)
	var held: Dictionary = _preview_scene.call("_surface_resolution_for_preview", state, action, tile)
	var shown: Dictionary = held["known"]["single_state"]
	for field: String in ["player", "retaliate", "illusions", "terrain"]:
		_check(shown.get(field) == after.get(field), "%s held-card forecast: %s" % [label, field])
	_check(_combat.effective_light_sources(shown) == _combat.effective_light_sources(after), label + " held-card forecast: Light sources")
	if _combat.effective_umbra_stage(state) == "clear":
		_check(shown.get("enemies") == after.get("enemies"), label + " held-card forecast: damage and Stagger")
	_held_checks += 1
	return after


func _check(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)


func _record(id: String, actual: Dictionary, observed: Dictionary) -> void:
	var matches: bool = actual == observed
	print("TXT26_CASE %s %s %s" % [id, "PASS" if matches else "FAIL", JSON.stringify(actual)])
	if matches:
		_passed += 1
	else:
		_fail("%s expected TXT-26 outcome %s" % [id, observed])


func _fail(reason: String) -> void:
	_failed += 1
	push_error(reason)


func _hp(state: Dictionary, id: int = 1, kind: String = "enemy") -> int:
	return int(_combat._surface_actor(state, kind, id).get("hp", 0))


func _iron_lung() -> void:
	var state: Dictionary = _state(["iron_lung"], ["overhead_smash"], [_enemy(1, ADJACENT), _enemy(2, OTHER)])
	state["player"]["stoneskin"] = PREEXISTING_SKIN
	var after: Dictionary = _play(state, "overhead_smash", [ADJACENT], "empower")
	_record("iron_lung_time", {
		"base_time": _combat.card_time_cost("overhead_smash", state),
		"paid_time": after["player_turn_time_spent"], "stoneskin_spent": PREEXISTING_SKIN - int(after["player"]["stoneskin"]),
	}, {"base_time": 6, "paid_time": 8, "stoneskin_spent": 0})


func _pilgrim_boots() -> void:
	var landing := Vector2i(3, 4)
	var state: Dictionary = _state(["pilgrim_boots"], ["spur_vault"], [_enemy(1, landing + Vector2i.RIGHT)])
	var after: Dictionary = _play(state, "spur_vault", [landing, landing + Vector2i.RIGHT])
	_record("pilgrim_boots_blink", {
		"landed": after["player"]["pos"] == landing, "light_sources": _combat.effective_light_source_count(after),
	}, {"landed": true, "light_sources": 2})


func _worldheart() -> void:
	var state: Dictionary = _state(["worldheart"], ["raise_the_anvil"])
	var after: Dictionary = _play(state, "raise_the_anvil", [HERO + Vector2i.UP])
	_record("worldheart_midturn", {
		"player_turn": _combat.is_player_turn(after), "block": after["player"]["block"],
		"stoneskin_gain": int(after["player"]["stoneskin"]) - int(state["player"]["stoneskin"]),
		"enemy_health_loss": _hp(state) - _hp(after),
	}, {"player_turn": true, "block": 0, "stoneskin_gain": 6, "enemy_health_loss": 3})


func _eclipse_mantle() -> void:
	var state: Dictionary = _state(["eclipse_mantle"], ["dust_skip"], [_enemy(1, ADJACENT)], [], "eclipse")
	var after: Dictionary = _play(state, "dust_skip", [HERO + Vector2i.UP])
	var sources: Array[Dictionary] = _combat.effective_light_sources(after)
	var lit_tile := Vector2i(2, 6)
	var attack: Dictionary = Data.enemies()["crawler"]["intents"][0]["actions"][1]
	var destroyed: Dictionary = _combat._resolve_enemy_action(_enemy_activation(after), 0, attack)
	_record("eclipse_tether", {
		"blink_light_radius": int(sources.front().get("radius", 0)) if not sources.is_empty() else 0,
		"illusion_health_before_hit": _hp(after, 1, "illusion"), "illusion_health_after_hit": _hp(destroyed, 1, "illusion"),
		"light_sources_after_hit": _combat.effective_light_source_count(destroyed),
		"tile_visible_before_hit": _combat.is_tile_visible_to_player(after, lit_tile),
		"tile_visible_after_hit": _combat.is_tile_visible_to_player(destroyed, lit_tile),
	}, {
		"blink_light_radius": 2, "illusion_health_before_hit": 2, "illusion_health_after_hit": 0,
		"light_sources_after_hit": 1, "tile_visible_before_hit": true, "tile_visible_after_hit": true,
	})


func _hobnail() -> void:
	var state: Dictionary = _state(["hobnail_cleats"], ["white_silence"])
	for tile: Vector2i in [HERO, ADJACENT]:
		Surface.place(state, tile, "ice", GROUND_SOURCE)
	var after: Dictionary = _play(state, "white_silence")
	_record("hobnail_white_silence", {"enemy_health_loss": _hp(state) - _hp(after)}, {"enemy_health_loss": 10})


func _frost_prism() -> void:
	var anchor := Vector2i(4, 3)
	var state: Dictionary = _state(["frost_prism"], ["white_silence"], [_enemy(1, anchor, "tharokh")])
	Surface.place(state, anchor, "ice", GROUND_SOURCE)
	var after: Dictionary = _play(state, "white_silence")
	var base_offsets: Array[Vector2i] = Patterns.offsets("cross")
	var rubble: Array[Vector2i] = Surface.tiles(after, "rubble")
	var extra := Vector2i(2, 0)
	_record("frost_prism_footprint", {
		"diagram_tiles": base_offsets.size(), "rubble_tiles": rubble.size(),
		"diagram_has_anchor_plus_2_east": base_offsets.has(extra),
		"rubble_at_anchor_plus_2_east": rubble.has(anchor + extra),
	}, {"diagram_tiles": 5, "rubble_tiles": 12, "diagram_has_anchor_plus_2_east": false, "rubble_at_anchor_plus_2_east": true})


func _card_block() -> void:
	var destination := Vector2i(2, 2)
	var shield: Dictionary = _state(["reinforced_shield"], ["catch_the_wind"])
	shield["player"]["stoneskin"] = PREEXISTING_SKIN
	var shield_after: Dictionary = _play(shield, "catch_the_wind", [destination])
	_record("reinforced_shield_move_block", {
		"tiles_moved": Combat.PathUtils.manhattan(HERO, shield_after["player"]["pos"]),
		"block": shield_after["player"]["block"], "stoneskin": shield_after["player"]["stoneskin"],
	}, {"tiles_moved": 2, "block": 5, "stoneskin": 6})
	var vambrace: Dictionary = _play(_state(["briar_vambrace"], ["catch_the_wind"]), "catch_the_wind", [destination])
	_record("briar_vambrace_move_block", {"block": vambrace["player"]["block"], "retaliate": vambrace.get("retaliate", {}).get("amount", 0)}, {"block": 2, "retaliate": 1})


func _hollow_puppet() -> void:
	var illusion_tile := Vector2i(4, 4)
	var wall := Vector2i(6, 4)
	var state: Dictionary = _state(["hollow_puppet"], ["shield_charge"], [_enemy(1, OTHER)], [wall])
	state = _combat._create_illusion(state, illusion_tile, 2)
	var after: Dictionary = _play(state, "shield_charge", [ADJACENT, illusion_tile])
	_record("hollow_puppet_wall", {
		"wall": str(wall), "illusion_health_after_push": _hp(after, 1, "illusion"),
	}, {"wall": "(6, 4)", "illusion_health_after_push": 2})


func _copper_shod() -> void:
	var seed := Vector2i(4, 4)
	var state: Dictionary = _state(["copper_shod_staff"], ["discharge"], [_enemy(1, OTHER)])
	Surface.place(state, seed, "electrified", GROUND_SOURCE)
	state = _combat._create_illusion(state, FAR, 2)
	var after: Dictionary = _play(state, "discharge", [seed])
	_record("copper_shod_discharge", {
		"illusion_health_before": _hp(state, 1, "illusion"), "illusion_health_after": _hp(after, 1, "illusion"),
		"seed_destroyed": not Surface.has_surface(after, seed, "electrified"),
		"enemy_health_loss_beyond_real_source": _hp(state) - _hp(after),
	}, {"illusion_health_before": 2, "illusion_health_after": 2, "seed_destroyed": true, "enemy_health_loss_beyond_real_source": 5})


func _thresholds() -> void:
	var state: Dictionary = _state(["hourglass_awl", "leaden_pommel"], ["static_rush", "overhead_smash"], [
		_enemy(1, ADJACENT), _enemy(2, HERO + Vector2i.UP + Vector2i.RIGHT),
	])
	state = _play(state, "static_rush", [HERO + Vector2i.UP])
	var cost: int = _combat.card_time_cost("overhead_smash", state)
	var action: Dictionary = _combat.card_play_actions("overhead_smash", state)[0]
	var after: Dictionary = _play(state, "overhead_smash", [HERO + Vector2i.UP + Vector2i.RIGHT])
	var paid: int = int(after["player_turn_time_spent"]) - int(state["player_turn_time_spent"])
	var surcharge: Dictionary = _state(["hourglass_awl", "leaden_pommel", "whirling_sash"], [
		"brace", "polar_guard", "dull_bolt",
	], [_enemy(1, FAR)])
	surcharge = _play(_play(surcharge, "brace"), "polar_guard")
	var third_cost: int = _combat.card_time_cost("dull_bolt", surcharge)
	var third_action: Dictionary = _combat.card_play_actions("dull_bolt", surcharge)[0]
	var third: Dictionary = _play(surcharge, "dull_bolt", [FAR])
	var third_paid: int = int(third["player_turn_time_spent"]) - int(surcharge["player_turn_time_spent"])
	_record("hourglass_awl_price", {
		"discounted_time": cost, "discounted_paid": paid, "discounted_pierce": action.get("pierce", false),
		"surcharged_time": third_cost, "surcharged_paid": third_paid, "surcharged_pierce": third_action.get("pierce", false),
	}, {
		"discounted_time": 4, "discounted_paid": 4, "discounted_pierce": false,
		"surcharged_time": 6, "surcharged_paid": 6, "surcharged_pierce": true,
	})
	_record("leaden_pommel_price", {
		"discounted_time": cost, "discounted_paid": paid, "discounted_stagger": int(action.get("stagger", 0)),
		"surcharged_time": third_cost, "surcharged_paid": third_paid, "surcharged_stagger": int(third_action.get("stagger", 0)),
	}, {
		"discounted_time": 4, "discounted_paid": 4, "discounted_stagger": 0,
		"surcharged_time": 6, "surcharged_paid": 6, "surcharged_stagger": 1,
	})


func _winters_spur() -> void:
	var state: Dictionary = _state(["winters_spur"], [], [_enemy(1, OTHER)])
	for tile: Vector2i in [HERO, ADJACENT]:
		Surface.place(state, tile, "ice", GROUND_SOURCE)
	Surface.place(state, HERO, "rubble", GROUND_SOURCE)
	var moves: int = _combat.player_movement_remaining(state)
	var after: Dictionary = _combat.apply_player_movement(state, ADJACENT)
	_record("winters_spur_rubble", {
		"reached": after["player"]["pos"] == ADJACENT, "movement_spent": moves - _combat.player_movement_remaining(after),
	}, {"reached": true, "movement_spent": 2})


func _crowncoal() -> void:
	var state: Dictionary = _state(["crowncoal_heart"], ["raise_the_anvil", "overhead_smash"], [_enemy(1, OTHER)])
	state = _play(state, "raise_the_anvil", [ADJACENT])
	var after: Dictionary = _play(state, "overhead_smash", [ADJACENT])
	_record("crowncoal_terrain_hit", {
		"terrain_destroyed": _combat._terrain_index_at_tile(after, ADJACENT) < 0,
		"fire_on_hit_tile": Surface.has_surface(after, ADJACENT, "fire"),
	}, {"terrain_destroyed": true, "fire_on_hit_tile": false})


func _waxen_effigy() -> void:
	var enemy_tile := Vector2i(2, 1)
	var state: Dictionary = _state(["waxen_effigy"], [], [_enemy(1, enemy_tile)], [], "eclipse")
	var illusion: Dictionary = _combat._surface_actor(state, "illusion", 1)
	_record("waxen_effigy_hidden", {
		"visible_enemies": _combat.visible_enemy_ids(state).size(),
		"nearest_adjacent_tile": str(HERO + Vector2i.UP), "illusion_tile": str(illusion.get("pos", NO_TARGET)),
	}, {"visible_enemies": 0, "nearest_adjacent_tile": "(2, 3)", "illusion_tile": "(3, 4)"})


func _overflow_censer() -> void:
	var state: Dictionary = _state(["overflow_censer"], [], [_enemy(1, ADJACENT, "arc_thrall")])
	Surface.place(state, HERO, "ice", GROUND_SOURCE)
	var bolt: Dictionary = Data.enemies()["arc_thrall"]["intents"][0]["actions"][1]
	var after: Dictionary = _combat._resolve_enemy_action(_enemy_activation(state), 0, bolt)
	_record("overflow_censer_enemy_overwrite", {
		"under_hero": Surface.element_at(after, HERO),
		"electrified_tiles": Surface.tiles(after, "electrified").size(),
	}, {"under_hero": "electrified", "electrified_tiles": 1})


func _toll_late_bell() -> void:
	var state: Dictionary = _state(["toll_late_bell", "borrowed_hourglass"], ["quick_stab"])
	state["turn_queue"] = [{"kind": "enemy", "key": "enemy:1", "enemy_id": 1, "time": EARLY_ENEMY_TIME, "seq": 1}]
	var after: Dictionary = _play(state, "quick_stab", [ADJACENT])
	var ended: Dictionary = _combat.prepare_player_activation_end(after)
	var queue: Array = ended["turn_queue"]
	_record("toll_late_bell_extra_turn", {
		"enemy_health_loss": _hp(state) - _hp(after), "next_actor": queue[0].get("kind", ""), "next_actor_time": queue[0].get("time", -1),
		"enemy_turn_time": queue[1].get("time", -1),
	}, {"enemy_health_loss": 6, "next_actor": "player", "next_actor_time": 0, "enemy_turn_time": EARLY_ENEMY_TIME})


func _briar_throne() -> void:
	var state: Dictionary = _play(_state(["briar_throne"], ["static_mantle"]), "static_mantle")
	var bite: Dictionary = Data.enemies()["crawler"]["intents"][0]["actions"][1]
	var after: Dictionary = _combat._resolve_enemy_action(_enemy_activation(state), 0, bite)
	var enemy_turn: Dictionary = _enemy_activation(state)
	enemy_turn["enemies"][0]["intent"] = {"actions": [bite]}
	var forecast: Dictionary = _combat.resolve_enemy_turn_with_steps(enemy_turn, 0, false)["state"]
	var committed: Dictionary = _combat.resolve_enemy_turn_with_steps(enemy_turn, 0, true)["state"]
	_check(forecast == committed and int(committed.get("retaliate", {}).get("amount", 0)) == 0, "Briar Throne enemy forecast resolves a rider-only reaction without growth")
	_check(committed["enemies"][0].get("shock", 0) > 0, "Briar Throne forecast fixture actually triggers the Shock rider")
	_forecast_checks += 1
	_record("briar_throne_zero_damage", {
		"enemy_health_loss": _hp(state) - _hp(after),
		"retaliate_before": state.get("retaliate", {}).get("amount", 0),
		"retaliate_after": after.get("retaliate", {}).get("amount", 0),
	}, {"enemy_health_loss": 0, "retaliate_before": 0, "retaliate_after": 0})


func _additional_regressions() -> void:
	_block_regressions()
	_light_regressions()
	_copper_regressions()
	_puppet_regressions()
	_time_and_damage_faces()


func _block_regressions() -> void:
	var state: Dictionary = _state(["reinforced_shield", "briar_vambrace", "fivefold_knot"], ["brace"])
	state["relic_element_knots"] = ["fire", "ice", "lightning", "air", "earth"]
	state["player"]["stoneskin"] = PREEXISTING_SKIN
	var face: String = Display.for_card("brace", state)["summary_bbcode"]
	var after: Dictionary = _play(state, "brace")
	var expected_block: int = int(Data.card_def("brace")["actions"][0]["amount"]) + 3 + 3
	_check(after["player"]["block"] == expected_block and after["retaliate"]["amount"] == 1, "Two Block actions share one Shield and Vambrace bonus")
	_check(face.contains("Retaliate 1") and face.count("Retaliate") == 1, "Double-Block face shows one Vambrace reward")
	state = _state(["briar_throne", "reinforced_shield", "briar_vambrace"], ["catch_the_wind"])
	state["player"]["stoneskin"] = PREEXISTING_SKIN
	after = _play(state, "catch_the_wind", [HERO + Vector2i.UP * 2])
	_check(after["player"]["block"] == 0 and not after.has("retaliate"), "Briar Throne suppresses per-tile Block and both reactions")
	var growth: Dictionary = _enemy_activation(state.duplicate(true))
	growth["retaliate"] = {"amount": 2}
	growth["enemies"][0]["stoneskin"] = PREEXISTING_SKIN
	var bite: Dictionary = Data.enemies()["crawler"]["intents"][0]["actions"][1]
	growth["enemies"][0]["intent"] = {"actions": [bite]}
	var forecast: Dictionary = _combat.resolve_enemy_turn_with_steps(growth, 0, false)["state"]
	var committed: Dictionary = _combat.resolve_enemy_turn_with_steps(growth, 0, true)["state"]
	_check(forecast == committed and int(committed.get("retaliate", {}).get("amount", 0)) == 3 and _hp(growth) == _hp(committed), "Briar Throne grows on a damaging hit that defenses absorb")
	_forecast_checks += 1


func _light_regressions() -> void:
	var state: Dictionary = _state(["eclipse_mantle", "waxen_effigy", "glassway_compass"], ["dust_skip"], [_enemy(1, OTHER)])
	var lights: Array[Dictionary] = _combat.effective_light_sources(state)
	_check(lights.size() == 1 and lights[0]["radius"] == 2 and lights[0]["pos"] == state["illusions"][0]["pos"] and not lights[0].get("tethered", false), "Waxen Effigy creates permanent Eclipse Light on spawn")
	var illusion_tile: Vector2i = state["illusions"][0]["pos"]
	var after: Dictionary = _play(state, "dust_skip", [illusion_tile])
	_check(after["illusions"][0]["pos"] != illusion_tile and lights == _combat.effective_light_sources(after), "Glassway swap moves the Illusion without moving or adding Light")
	state = _state(["eclipse_mantle"], ["ice_sculpture"], [_enemy(1, OTHER)])
	after = _play(state, "ice_sculpture", [ADJACENT])
	_check(_combat.effective_light_sources(after).size() == 1, "Card-created Illusion also creates Eclipse Light")
	state = _state(["pilgrim_boots"], ["shield_charge"], [_enemy(1, HERO + Vector2i.RIGHT * 2)])
	after = _play(state, "shield_charge", [ADJACENT, HERO + Vector2i.RIGHT * 2])
	_check(_combat.effective_light_sources(after).is_empty(), "Pilgrim Boots keeps the attack filter on Move")
	state = _state(["pilgrim_boots"], ["catch_the_wind"], [_enemy(1, OTHER)])
	after = _play(state, "catch_the_wind", [HERO + Vector2i.UP * 2])
	_check(_combat.effective_light_sources(after).size() == 2, "Pilgrim Boots still lights each entered tile on a non-attacking Move")


func _copper_regressions() -> void:
	var seed := Vector2i(4, 4)
	var outcrop := seed + Vector2i.RIGHT
	var illusion := outcrop + Vector2i.RIGHT
	var victim := illusion + Vector2i.UP
	var state: Dictionary = _state(["copper_shod_staff"], ["discharge"], [_enemy(1, victim)])
	state["terrain"] = [{"id": "fixture_outcrop", "kind": "crag_outcrop", "owner_kind": "player", "pos": outcrop, "hp": 4, "max_hp": 4}]
	state = _combat._create_illusion(state, illusion, 2)
	Surface.place(state, seed, "electrified", GROUND_SOURCE)
	var after: Dictionary = _play(state, "discharge", [outcrop])
	_check(_hp(after) == _hp(state) - 5 and _hp(after, 1, "illusion") == 2 and int(after["terrain"][0]["hp"]) == 4, "Virtual Outcrop can seed Discharge and both constructs survive the Burst")
	_check(not Surface.has_surface(after, seed, "electrified") and not Surface.has_surface(after, illusion, "electrified"), "Discharge consumes only real Electrified")
	state = _state(["copper_shod_staff"], ["thunderclap"], [_enemy(1, ADJACENT)])
	state["terrain"] = [{"id": "fixture_outcrop", "kind": "crag_outcrop", "owner_kind": "player", "pos": seed, "hp": 4, "max_hp": 4}]
	after = _play(state, "thunderclap")
	_check(_hp(after) < _hp(state) - 5 and int(after["terrain"][0]["hp"]) == 4, "Lightning card collision still damages the moved enemy and spares the owned Outcrop")
	state["terrain"] = []
	state = _combat._create_illusion(state, seed, 2)
	after = _play(state, "thunderclap")
	_check(_hp(after) < _hp(state) - 5 and _hp(after, 1, "illusion") == 2, "Lightning card collision also spares an Illusion blocker")


func _puppet_regressions() -> void:
	var start := Vector2i(5, 4)
	var fire := Vector2i(4, 4)
	var state: Dictionary = _state(["hollow_puppet"], [], [_enemy(1, OTHER)])
	Surface.place(state, fire, "fire", GROUND_SOURCE)
	state = _combat._create_illusion(state, start, 2)
	var pull: Dictionary = {"type": "pull", "range": 4, "amount": 1}
	var after: Dictionary = _forecast_action(state, pull, start, "Hollow Puppet Pull through Fire")
	_check(_hp(after, 1, "illusion") == 2 and after["illusions"][0]["pos"] == fire and Surface.has_surface(after, fire, "fire"), "Puppet Pull protects the Illusion from Fire entry")
	var terrain_tile := start + Vector2i.RIGHT
	state["terrain"] = [{"id": "fixture_crate", "kind": "wooden_box", "pos": terrain_tile, "hp": 4, "max_hp": 4}]
	var push: Dictionary = {"type": "push", "range": 4, "amount": 1}
	after = _forecast_action(state, push, start, "Hollow Puppet terrain collision")
	_check(_hp(after, 1, "illusion") == 2 and after["illusions"][0]["pos"] == start, "Puppet Push protects the Illusion from terrain collision")


func _time_and_damage_faces() -> void:
	var state: Dictionary = _state(["hourglass_awl", "leaden_pommel"], ["overhead_smash"], [_enemy(1, ADJACENT)])
	state["turn_flags"]["quicken_pending"] = 2
	var prepared: Dictionary = _combat.prepare_player_card(state, 0, "empower")
	var action: Dictionary = _combat.card_play_actions("overhead_smash", prepared)[0]
	var face: Dictionary = Display.for_card("overhead_smash", prepared)
	var empowered: Dictionary = _play(state, "overhead_smash", [ADJACENT], "empower")
	_check(action["_tempo_card_time"] == 6 and face["time_surcharge"] == 2 and action.get("pierce", false) and int(action.get("stagger", 0)) == 5 and int(empowered["player_turn_time_spent"]) == 6, "Empower Time crosses both relic thresholds in the face and paid play")
	state = _state(["hobnail_cleats"], ["white_silence"])
	for tile: Vector2i in [HERO, ADJACENT]:
		Surface.place(state, tile, "ice", GROUND_SOURCE)
	var ice_face: String = Display.for_card("white_silence", state)["summary_bbcode"]
	_check(ice_face.contains("10"), "White Silence shows the boosted 10 damage on the hand face")
