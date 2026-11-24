extends RefCounted
## Headless equivalent of selecting legal targets and accepting a card play.
const Combat = preload("res://scripts/combat_engine.gd")
const Aim = preload("res://scripts/area_target_aim.gd")
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Fixture = preload("res://tests/suites/board_surface_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const NO_TARGET := Vector2i(-1, -1)
const HERO := Vector2i(2, 4)
const NEAR := Vector2i(3, 4)
const SECOND := Vector2i(4, 4)
const THIRD := Vector2i(5, 4)
const RESERVE_ENEMY_TILE := Vector2i(7, 6)
const OPEN_STAGE := "clear"
const LIMITED_STAGE := "heart"
const HEALTH := 100
const PLAYER_START_HEALTH := 50
const DRAW_STOCK := 12
const PLAY_BUDGET := 3
const BASE_PILE_CARD := "brace"
const TARGET_SEARCH_BUDGET := 160

var engine := Combat.new()
var _remaining_search: int

func fresh(tiles: Array = [NEAR, RESERVE_ENEMY_TILE], stage: String = OPEN_STAGE) -> Dictionary:
	var state: Dictionary = Fixture.fixture(engine)
	state["umbra"]["stage"] = stage
	state["player"]["pos"] = HERO
	state["player"]["hp"] = PLAYER_START_HEALTH
	state["player"]["max_hp"] = HEALTH
	state["cards_per_turn"] = PLAY_BUDGET
	state["enemies"] = []
	for tile: Vector2i in tiles:
		var unit: Dictionary = Fixture.enemy(state["enemies"].size() + 1, tile)
		unit["hp"] = HEALTH
		unit["max_hp"] = HEALTH
		state["enemies"].append(unit)
	var draw: Array[String]
	draw.resize(DRAW_STOCK)
	draw.fill(BASE_PILE_CARD)
	state["deck"]["hand"] = []
	state["deck"]["draw"] = draw
	state["deck"]["discard"] = [BASE_PILE_CARD]
	return engine._initialize_initiative_queue(state)

func play(state: Dictionary, id: String, preferred: Array = [], strict: bool = false, mode: String = "play") -> Dictionary:
	var before: Dictionary = state.duplicate(true)
	before["deck"]["hand"].push_front(id)
	if not engine.hand_card_has_play_budget(before, 0):
		return {"blocked": "No Card Plays remaining"}
	var working: Dictionary = engine.prepare_player_card(before, 0, mode)
	var actions: Array = engine.card_play_actions(id, working)
	_remaining_search = TARGET_SEARCH_BUDGET
	var resolved: Dictionary = _target(working, actions, 0, [], [], [], preferred, strict)
	if resolved.has("blocked"): return resolved
	var chosen: Array[Vector2i]
	chosen.assign(resolved["targets"])
	var after: Dictionary = Commit.player_card(engine, before, resolved["state"], 0, resolved["actions"], chosen, {"play_mode": mode})
	return {"before": before, "after": after, "targets": chosen, "steps": resolved["steps"]}

func _target(state: Dictionary, actions: Array, index: int, chosen: Array, selected: Array, steps: Array, preferred: Array, strict: bool) -> Dictionary:
	if index == actions.size():
		return {"state": state, "targets": chosen, "actions": selected, "steps": steps}
	_remaining_search -= 1
	if _remaining_search < 0:
		return {"blocked": "Target search budget exhausted"}
	var action: Dictionary = actions[index]
	var kind: String = str(action.get("type", ""))
	if not engine.player_action_can_resolve(state, action):
		return {"blocked": "%s cannot resolve" % kind}
	var legal: Array[Vector2i]
	var targeting: bool = engine.player_action_needs_target(action)
	if targeting:
		legal = engine.valid_targets_for_player_action(state, action)
		if chosen.size() < preferred.size() and legal.has(preferred[chosen.size()]):
			var first: Vector2i = preferred[chosen.size()]
			legal.erase(first)
			legal.push_front(first)
			if strict: legal.resize(1)
		elif strict:
			return {"blocked": "Requested tile illegal for %s; legal tiles %s" % [kind, str(legal)]}
		else:
			var foe: Vector2i = state["enemies"][0]["pos"]
			if legal.has(foe) and kind not in ["move", "blink", "outcrop", "illusion"]:
				legal.erase(foe)
				legal.push_front(foe)
	else:
		legal.append(NO_TARGET)
	if legal.is_empty(): return {"blocked": "No legal %s target" % kind}
	var blocked: Dictionary = {}
	for tile: Vector2i in legal:
		var aimed: Dictionary = engine.action_with_automatic_origin(state, action, tile) if targeting else action
		if targeting and engine.player_action_needs_orientation(aimed):
			aimed = aimed.duplicate()
			if kind in ["aoe", "surface", "detonate", "outcrop", "meteor_marks"]:
				var centers: Array[Vector2i] = [tile]
				aimed["orientation"] = Aim.placement(engine, state, state, aimed, centers, Vector2i.RIGHT)["direction"]
			else:
				var direction: Vector2i = engine.resolved_force_direction_for_player_action(state, aimed, tile)
				if direction != Vector2i.ZERO: aimed["force_direction"] = direction
			if not engine.valid_targets_for_player_action(state, aimed).has(tile): continue
		var next: Dictionary = engine.apply_player_action(state, aimed, tile)
		var step: Dictionary = {
			"action": kind, "tile": tile, "before": snapshot(state), "after": snapshot(next),
			"orientation": aimed.get("orientation", Vector2i.ZERO),
			"conditional_amount": aimed.has("surface_bonus") or aimed.has("state_bonus") or aimed.has("scale_bonus"),
			"secondary_damage": aimed.has("chain") or aimed.has("push") or aimed.has("pull"),
			"secondary": aimed.has("target") or bool(aimed.get("reuse_previous_target", false)) or aimed.has(Keywords.KEYWORD_APPENDED_FLAG),
		}
		var targets: Array = chosen + [tile] if targeting else chosen
		var result: Dictionary = _target(next, actions, index + 1, targets, selected + [aimed], steps + [step], preferred, strict)
		if not result.has("blocked"): return result
		blocked = result
		if _remaining_search < 0: break
	return blocked if not blocked.is_empty() else {"blocked": "No legal orientation for " + kind}

func snapshot(state: Dictionary) -> Dictionary:
	var enemies: Array = []
	for unit: Dictionary in state.get("enemies", []):
		var observed: Dictionary = _unit(unit)
		observed["id"] = int(unit["id"])
		observed["delay"] = Keywords.stagger_applied_this_turn(state, observed["id"])
		enemies.append(observed)
	var tiles: Dictionary = {}
	for ground: String in ["fire", "ice", "electrified", "rubble"]:
		var found: Array[Vector2i] = Ground.tiles(state, ground)
		found.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
		tiles[ground] = found
	var terrain: Array = []
	for obj: Dictionary in state.get("terrain", []):
		terrain.append({"kind": obj.get("kind"), "pos": obj.get("pos"), "hp": obj.get("hp")})
	var light: Array = []
	for source: Dictionary in state.get("umbra", {}).get("light_sources", []):
		light.append(source.duplicate(true))
	return {
		"player": _unit(state["player"]), "enemies": enemies, "ground": tiles,
		"hand_size": state["deck"]["hand"].size(), "time": int(state.get("player_turn_time_spent", 0)),
		"plays_spent": int(state.get("cards_played_this_turn", 0)),
		"plays_bonus": int(state.get("card_play_bonus_this_turn", 0)),
		"kill_plays": int(state.get("death_bonus_card_plays_this_turn", 0)),
		"destination": str(state.get("last_card_destination", "")), "terrain": terrain,
		"card_plays_left": engine.cards_remaining_this_turn(state),
		"rites": state.get("active_rites", []),
		"illusions": state.get("illusions", []), "lights": light,
	}

func _unit(unit: Dictionary) -> Dictionary:
	var out: Dictionary = {"pos": unit.get("pos"), "hp": int(unit.get("hp", 0))}
	for field: String in ["block", "stoneskin", "expose", "shock", "stagger", "immobilize", "next_time", "next_act_time", "marked", "bleed", "sunder"]:
		out[field] = int(unit.get(field, 0))
	return out
