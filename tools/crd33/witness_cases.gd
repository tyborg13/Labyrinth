extends RefCounted

const Fight = preload("res://tools/crd33/fight.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const LOW_HEALTH := 1
const SHORT_TIME_CARD := "brace"
const ICE_BRIDGE_FAR := Vector2i(6, 4)
const HIDDEN_ILLUSION_ID := 10
const FAR_LANE := Vector2i(7, 4)
const FAR_SIDE_LANE := Vector2i(7, 5)
const BLOCKER_COLUMN := 4
const STAGGER_SETUP_CARD := "petrify"
const CONTROL_BLOCK := 4
const CONTROL_STONESKIN := 5

static func run(fight: Fight) -> Dictionary:
	var receipts: Dictionary = {}
	_quicken(fight, receipts)
	_old_claims(fight, receipts)
	_ranges(fight, receipts)
	_kill_plays(fight, receipts)
	_staggers(fight, receipts)
	_bursts_and_light(fight, receipts)
	_stoke(fight, receipts)
	_cinder_trail(fight, receipts)
	_ice_rule(fight, receipts)
	_time_rule(fight, receipts)
	_defense_rule(fight, receipts)
	for key: String in receipts:
		print("CRD32 WITNESS %s %s" % [key, JSON.stringify(receipts[key])])
	return receipts

static func _quicken(fight: Fight, receipts: Dictionary) -> void:
	for id: String in Data.cards():
		if not (Data.card_def(id).get("actions", []) as Array).any(func(action: Dictionary) -> bool: return action["type"] == "quicken"):
			continue
		var first: Dictionary = fight.play(fight.fresh(), id)
		if not _reached(first, receipts, "quicken/" + id): continue
		var baseline: Dictionary = fight.play(fight.fresh(), SHORT_TIME_CARD)
		var next: Dictionary = fight.play(first["after"], SHORT_TIME_CARD)
		if not _reached(next, receipts, "quicken/" + id): continue
		receipts["quicken/" + id] = {
			"next_card": SHORT_TIME_CARD, "normal_time": _time(baseline), "quickened_time": _time(next),
			"quicken_card_time": _time(first), "quicken_card_plays": int(first["after"]["cards_played_this_turn"]),
		}

static func _old_claims(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh([Fight.NEAR], Fight.LIMITED_STAGE)
	for tile: Vector2i in [Fight.NEAR, Fight.SECOND, Fight.THIRD, ICE_BRIDGE_FAR]:
		Ground.place(state, tile, "ice")
	var result: Dictionary = fight.play(state, "frost_circuit", [Fight.NEAR], true)
	if _reached(result, receipts, "frost_circuit"):
		var observed: Dictionary = fight.snapshot(result["after"])
		receipts["frost_circuit"] = {
			"clicked": Fight.NEAR, "far_tile": ICE_BRIDGE_FAR,
			"far_tile_visible": fight.engine.is_tile_visible_to_player(state, ICE_BRIDGE_FAR),
			"ice_before": Ground.tiles(state, "ice"), "ground_after": observed["ground"],
			"damage": Fight.HEALTH - observed["enemies"][0]["hp"], "shock": observed["enemies"][0]["shock"],
		}
	state = fight.fresh([Fight.NEAR, Fight.THIRD])
	state["enemies"][1]["type"] = "zekarion"
	for tile: Vector2i in [Fight.NEAR, Fight.SECOND, Fight.THIRD]:
		Ground.place(state, tile, "electrified")
	result = fight.play(state, "skybolt", [Fight.NEAR], true)
	if _reached(result, receipts, "skybolt"):
		var units: Array = fight.snapshot(result["after"])["enemies"]
		receipts["skybolt"] = {"clicked": Fight.NEAR, "targets": ["crawler", "zekarion"], "damage": [Fight.HEALTH - units[0]["hp"], Fight.HEALTH - units[1]["hp"]], "shock": [units[0]["shock"], units[1]["shock"]]}
	state = fight.fresh([Fight.NEAR], Fight.LIMITED_STAGE)
	state["illusions"] = [{"id": HIDDEN_ILLUSION_ID, "pos": ICE_BRIDGE_FAR, "hp": Fight.HEALTH, "max_hp": Fight.HEALTH}]
	var actions: Array = fight.engine.card_play_actions("empty_husk", state)
	var legal: Array = fight.engine.valid_targets_for_player_action(state, actions[0])
	var hidden: bool = not fight.engine.is_tile_visible_to_player(state, ICE_BRIDGE_FAR)
	var rejected: Dictionary = fight.play(state, "empty_husk", [ICE_BRIDGE_FAR], true)
	state["umbra"]["stage"] = Fight.OPEN_STAGE
	result = fight.play(state, "empty_husk", [ICE_BRIDGE_FAR], true)
	if _reached(result, receipts, "empty_husk"):
		receipts["empty_husk"] = {
			"clicked": ICE_BRIDGE_FAR, "hidden": hidden, "legal_while_hidden": ICE_BRIDGE_FAR in legal,
			"hidden_rejection": rejected.get("blocked", ""), "hero_after_visible_click": result["after"]["player"]["pos"],
		}
	state = fight.fresh([Fight.NEAR])
	Ground.place(state, Fight.NEAR, "fire")
	result = fight.play(state, "immolation")
	if _reached(result, receipts, "immolation"):
		receipts["immolation"] = {
			"hero_tile": Fight.HERO, "fire_center": Fight.NEAR,
			"hero_damage": int(state["player"]["hp"]) - int(result["after"]["player"]["hp"]),
			"enemy_damage": Fight.HEALTH - int(result["after"]["enemies"][0]["hp"]),
			"fuel_after": Ground.element_at(result["after"], Fight.NEAR),
		}
	_fire_rite(fight, receipts)

static func _fire_rite(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh([Fight.NEAR])
	var rite: Dictionary = fight.play(state, "salamander_heart")
	if not _reached(rite, receipts, "salamander_heart"): return
	# An authored Fire Burst hits the hero on the adjacent tile with the Rite active.
	Ground.place(rite["after"], Fight.NEAR, "fire")
	var result: Dictionary = fight.play(rite["after"], "cinder_second", [Fight.NEAR], true)
	var baseline_state: Dictionary = state.duplicate(true)
	Ground.place(baseline_state, Fight.NEAR, "fire")
	var baseline: Dictionary = fight.play(baseline_state, "cinder_second", [Fight.NEAR], true)
	var fire_control: Dictionary = fight.fresh([Fight.NEAR])
	var fire_protected: Dictionary = rite["after"].duplicate(true)
	Ground.place(fire_control, Fight.HERO, "fire")
	Ground.place(fire_protected, Fight.HERO, "fire")
	var entry_control: Dictionary = fight.engine.surface_actor_arrival(fire_control, "player", -1, Fight.HERO + Vector2i.UP)
	var entry_protected: Dictionary = fight.engine.surface_actor_arrival(fire_protected, "player", -1, Fight.HERO + Vector2i.UP)
	if _reached(result, receipts, "salamander_heart"):
		receipts["salamander_heart"] = {
			"fire_card": "cinder_second", "fire_tile": Fight.NEAR, "hero_tile": Fight.HERO,
			"hero_health_before": rite["after"]["player"]["hp"], "hero_health_after": result["after"]["player"]["hp"],
			"burst_without_rite": baseline.get("after", {}).get("player", {}).get("hp", -1),
			"fire_entry_without_rite": entry_control["player"]["hp"], "fire_entry_with_rite": entry_protected["player"]["hp"],
		}

static func _ranges(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh([Fight.THIRD])
	var result: Dictionary = fight.play(state, "sleet_squall", [Fight.THIRD], true)
	if _reached(result, receipts, "sleet_squall"):
		var unit: Dictionary = result["after"]["enemies"][0]
		var tile: Vector2i = unit["pos"]
		receipts["sleet_squall"] = {
			"clicked": Fight.THIRD, "hero": Fight.HERO, "enemy_after_push": tile,
			"distance_at_hit": absi(tile.x - Fight.HERO.x) + absi(tile.y - Fight.HERO.y),
			"damage": Fight.HEALTH - int(unit["hp"]),
		}
	state = fight.fresh([FAR_LANE])
	Ground.place(state, FAR_LANE, "ice")
	state["grid"][FAR_LANE.y][BLOCKER_COLUMN] = "wall"
	result = fight.play(state, "white_silence")
	if _reached(result, receipts, "white_silence"):
		receipts["white_silence"] = {
			"hero": Fight.HERO, "blocking_wall": Vector2i(BLOCKER_COLUMN, FAR_LANE.y), "enemy": FAR_LANE,
			"damage": Fight.HEALTH - int(result["after"]["enemies"][0]["hp"]),
			"line_of_sight": fight.engine.combat_line_of_sight(state, Fight.HERO, FAR_LANE),
		}
		var control: Dictionary = fight.fresh([Fight.NEAR, Fight.SECOND, FAR_LANE], Fight.LIMITED_STAGE)
		Ground.place(control, Fight.NEAR, "ice")
		Ground.place(control, FAR_LANE, "ice")
		receipts["white_silence"]["selector_control"] = _selector_control(fight, control, "white_silence")
	for id: String in ["skybolt", "thunderstone"]:
		var blocked_los: Dictionary = fight.fresh([FAR_LANE])
		blocked_los["grid"][FAR_LANE.y][BLOCKER_COLUMN] = "wall"
		result = fight.play(blocked_los, id, [FAR_LANE], true)
		if _reached(result, receipts, "infinite_range/" + id):
			receipts["infinite_range/" + id] = {
				"hero": Fight.HERO, "blocked_at": Vector2i(BLOCKER_COLUMN, FAR_LANE.y), "clicked": FAR_LANE,
				"visible": fight.engine.is_tile_visible_to_player(blocked_los, FAR_LANE),
				"line_of_sight": fight.engine.combat_line_of_sight(blocked_los, Fight.HERO, FAR_LANE),
				"damage": Fight.HEALTH - result["after"]["enemies"][0]["hp"],
			}

static func _kill_plays(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh()
	state["enemies"][0]["hp"] = LOW_HEALTH
	var ordinary: Dictionary = fight.play(state, "quick_stab", [Fight.NEAR], true)
	state["enemies"][0]["summoned"] = true
	var summoned: Dictionary = fight.play(state, "quick_stab", [Fight.NEAR], true)
	if _reached(ordinary, receipts, "kill_card_play") and _reached(summoned, receipts, "kill_card_play"):
		receipts["kill_card_play"] = {
			"card": "quick_stab", "clicked": Fight.NEAR, "starting_hp": LOW_HEALTH,
			"ordinary_hp_after": ordinary["after"]["enemies"][0]["hp"], "summoned_hp_after": summoned["after"]["enemies"][0]["hp"],
			"ordinary_reward": ordinary["after"]["death_bonus_card_plays_this_turn"],
			"summoned_reward": summoned["after"]["death_bonus_card_plays_this_turn"],
		}

static func _staggers(fight: Fight, receipts: Dictionary) -> void:
	for id: String in Data.cards():
		var patterns: Array = []
		var card: Dictionary = Data.card_def(id)
		for action: Dictionary in card.get("actions", []):
			if int(action.get("stagger", 0)) > 0:
				patterns.append("")
			var bonus: Dictionary = action.get("surface_bonus", {})
			if int(bonus.get("stagger", 0)) > 0:
				patterns.append(str(bonus.get("surface", "")))
		for action: Dictionary in card.get("actions", []):
			for condition: Dictionary in action.get("state_bonus", []):
				if condition.get("state") == "light" and int(condition.get("stagger", 0)) > 0:
					patterns.append("light")
		if id == "white_silence": patterns.assign(["ice"])
		if id == "worldbreak": patterns.assign(["outcrop"])
		if id == "overhead_smash": patterns.assign(["empower"])
		for ground: String in patterns:
			var state: Dictionary = fight.fresh([Fight.NEAR])
			var mode: String = "empower" if ground == "empower" else "play"
			var target: Array = []
			match ground:
				"light", "outcrop":
					var tile: Vector2i = Fight.NEAR if ground == "light" else Fight.HERO + Vector2i.DOWN
					if ground == "outcrop":
						state = fight.fresh([tile + Vector2i.RIGHT])
						target = [tile]
					var setup_card: String = "beacon" if ground == "light" else "geode"
					var terrain_setup: Dictionary = fight.play(state, setup_card, [tile], true)
					if terrain_setup.has("blocked"): continue
					state = terrain_setup["after"]
				"ice", "fire", "electrified", "rubble":
					for tile: Vector2i in [Fight.NEAR, Fight.SECOND, Fight.THIRD]:
						Ground.place(state, tile, ground)
			var baseline: Dictionary = fight.play(state, id, target, not target.is_empty(), mode)
			if baseline.has("blocked"): continue
			var before_cap: int = Keywords.stagger_applied_this_turn(baseline["after"], 1)
			if before_cap <= 0: continue
			var setup: Dictionary = fight.play(state, STAGGER_SETUP_CARD, [state["enemies"][0]["pos"]], true)
			if setup.has("blocked"): continue
			var capped: Dictionary = fight.play(setup["after"], id, baseline["targets"], true, mode)
			if capped.has("blocked"): continue
			var delay_before: int = Keywords.stagger_applied_this_turn(capped["before"], 1)
			var delay_after: int = Keywords.stagger_applied_this_turn(capped["after"], 1)
			receipts["stagger/" + id] = {
				"enemy_hp_after": capped["after"]["enemies"][0]["hp"],
				"clicked": capped["targets"], "ground": ground,
				"ordinary_delta": before_cap, "pre_delayed_by": delay_before, "delay_now": delay_after,
			}

static func _bursts_and_light(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh([Fight.NEAR, Vector2i(6, 4)])
	for tile: Vector2i in [Fight.NEAR, Fight.SECOND, Fight.THIRD]:
		Ground.place(state, tile, "electrified")
	var discharge: Dictionary = fight.play(state, "discharge", [Fight.NEAR], true)
	if _reached(discharge, receipts, "discharge"):
		receipts["discharge"] = {
			"clicked": Fight.NEAR, "network": Ground.tiles(state, "electrified"),
			"far_enemy": Vector2i(6, 4), "far_enemy_damage": Fight.HEALTH - discharge["after"]["enemies"][1]["hp"],
			"remaining_electrified": Ground.tiles(discharge["after"], "electrified"),
		}
	state = fight.fresh([Fight.NEAR, FAR_LANE])
	var beacon: Dictionary = fight.play(state, "beacon", [Vector2i(6, 4)], true)
	var beacon_near: Dictionary = fight.play(beacon["after"], "beacon", [Fight.NEAR], true) if not beacon.has("blocked") else beacon
	if not beacon_near.has("blocked"):
		var glare: Dictionary = fight.play(beacon_near["after"], "revealing_glare")
		if _reached(glare, receipts, "revealing_glare"):
			receipts["revealing_glare"] = {
				"hero": Fight.HERO, "enemy_tiles": [Fight.NEAR, FAR_LANE], "light": fight.snapshot(glare["before"])["lights"],
				"expose_after": [glare["after"]["enemies"][0].get("expose", 0), glare["after"]["enemies"][1].get("expose", 0)],
			}

static func _stoke(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh([FAR_LANE, FAR_SIDE_LANE])
	state["grid"][FAR_LANE.y][BLOCKER_COLUMN] = "wall"
	state["grid"][FAR_SIDE_LANE.y][BLOCKER_COLUMN] = "wall"
	Ground.place(state, FAR_SIDE_LANE, "fire")
	var result: Dictionary = fight.play(state, "stoke")
	if _reached(result, receipts, "stoke"):
		receipts["stoke"] = {
			"hero": Fight.HERO, "enemies": [FAR_LANE, FAR_SIDE_LANE],
			"fire": Ground.tiles(state, "fire"),
			"line_of_sight": [
				fight.engine.combat_line_of_sight(state, Fight.HERO, FAR_LANE),
				fight.engine.combat_line_of_sight(state, Fight.HERO, FAR_SIDE_LANE),
			],
			"damage": [Fight.HEALTH - result["after"]["enemies"][0]["hp"], Fight.HEALTH - result["after"]["enemies"][1]["hp"]],
		}
		var control: Dictionary = fight.fresh([Fight.NEAR, FAR_LANE], Fight.LIMITED_STAGE)
		receipts["stoke"]["selector_control"] = _selector_control(fight, control, "stoke")

static func _selector_control(fight: Fight, state: Dictionary, card: String) -> Dictionary:
	var result: Dictionary = fight.play(state, card)
	if result.has("blocked"): return result
	var visible: Array = []
	var damage: Array = []
	for unit: Dictionary in state["enemies"]:
		visible.append(fight.engine.is_enemy_visible_to_player(state, unit))
	for unit: Dictionary in result["after"]["enemies"]:
		damage.append(Fight.HEALTH - int(unit["hp"]))
	return {"visible": visible, "damage": damage, "ice": Ground.tiles(state, "ice")}

static func _cinder_trail(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh([Fight.NEAR])
	var landing := Fight.HERO + Vector2i.UP
	var trail: Dictionary = fight.play(state, "cinder_trail", [landing], true)
	if not _reached(trail, receipts, "cinder_trail"): return
	var result: Dictionary = fight.play(trail["after"], "cinder_second", [Fight.HERO], true)
	var entry_state: Dictionary = fight.fresh([Fight.NEAR])
	Ground.place(entry_state, landing, "fire")
	var control: Dictionary = fight.play(entry_state, "guarded_step", [landing], true)
	var protected: Dictionary = fight.play(entry_state, "cinder_trail", [landing], true)
	if _reached(result, receipts, "cinder_trail"):
		receipts["cinder_trail"] = {
			"move_destination": landing, "burning_tile_left": Fight.HERO,
			"fire_before_burst": Ground.tiles(trail["after"], "fire"), "burst_card": "cinder_second",
			"hero_hp_before_burst": trail["after"]["player"]["hp"], "hero_hp_after_burst": result["after"]["player"]["hp"],
			"fire_entry_without_protection": control.get("after", {}).get("player", {}).get("hp", -1),
			"fire_entry_with_protection": protected.get("after", {}).get("player", {}).get("hp", -1),
		}

static func _ice_rule(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh([Fight.NEAR])
	var ice: Dictionary = fight.play(state, "frost_lane", [Fight.NEAR], true)
	if not _reached(ice, receipts, "ice_rule"): return
	var enemy: Dictionary = Commit.enemy_turn(fight.engine, ice["after"], 0)
	var after: Dictionary = enemy.get("state", enemy)
	var entry_state: Dictionary = fight.fresh([Fight.NEAR])
	Ground.place(entry_state, Fight.SECOND, "ice")
	var push: Dictionary = fight.play(entry_state, "buffet", [Fight.NEAR], true)
	receipts["ice_rule"] = {
		"ice": Ground.tiles(ice["after"], "ice"), "enemy_tile_at_start": ice["after"]["enemies"][0]["pos"],
		"expose_before_activation": ice["after"]["enemies"][0].get("expose", 0),
		"expose_after_activation": after["enemies"][0].get("expose", 0),
		"entry_result": fight.snapshot(push["after"])["enemies"][0] if not push.has("blocked") else push,
	}

static func _time_rule(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh()
	var quick: Dictionary = fight.play(state, SHORT_TIME_CARD)
	var slow: Dictionary = fight.play(state, "pale_spark", [Fight.NEAR], true)
	if not _reached(quick, receipts, "time_rule") or not _reached(slow, receipts, "time_rule"): return
	var earlier: Array = Commit.finish_player_activation(fight.engine, quick["after"])["turn_queue"]
	var later: Array = Commit.finish_player_activation(fight.engine, slow["after"])["turn_queue"]
	var earlier_slot: Dictionary = earlier.filter(func(entry: Dictionary) -> bool: return entry["kind"] == "player")[0]
	var later_slot: Dictionary = later.filter(func(entry: Dictionary) -> bool: return entry["kind"] == "player")[0]
	receipts["time_rule"] = {
		"cards": [SHORT_TIME_CARD, "pale_spark"], "less_time": _time(quick), "more_time": _time(slow),
		"earlier_turn": earlier_slot["time"], "later_turn": later_slot["time"],
		"plays": [quick["after"]["cards_played_this_turn"], slow["after"]["cards_played_this_turn"]],
	}

static func _defense_rule(fight: Fight, receipts: Dictionary) -> void:
	var state: Dictionary = fight.fresh([Fight.NEAR])
	state["enemies"][0]["block"] = CONTROL_BLOCK
	state["enemies"][0]["stoneskin"] = CONTROL_STONESKIN
	var result: Dictionary = fight.play(state, "quick_stab", [Fight.NEAR], true)
	if not _reached(result, receipts, "defense_rule"): return
	var activation: Dictionary = Commit.enemy_turn(fight.engine, state, 0)
	receipts["defense_rule"] = {
		"card": "quick_stab", "target": Fight.NEAR, "before": _defense(state["enemies"][0]),
		"after_hit": _defense(result["after"]["enemies"][0]), "after_activation": _defense(activation["state"]["enemies"][0]),
	}

static func _defense(unit: Dictionary) -> Dictionary:
	return {"hp": unit["hp"], "block": unit.get("block", 0), "stoneskin": unit.get("stoneskin", 0)}

static func _time(result: Dictionary) -> int:
	return int(result["after"]["player_turn_time_spent"]) - int(result["before"]["player_turn_time_spent"])

static func _reached(result: Dictionary, receipts: Dictionary, key: String) -> bool:
	if not result.has("blocked"): return true
	receipts[key] = result
	return false
