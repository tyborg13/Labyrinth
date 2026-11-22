extends RefCounted
## Catalog all glossary/Grimoire copy, with independent probes for combat terms.

const Fx = preload("res://tools/qa122/fixture.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Cards = preload("res://tools/qa122/cards.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const TestAmount: int = 3
const Damage: int = 6
const Attack: Dictionary = {"type": "melee", "damage": Damage, "range": 1, "element": "none"}
const EnemyTurn: Dictionary = {"id": "qa122_status", "name": "Audit", "time": 2, "actions": [
	{"type": "move_toward", "range": 2}, Attack, {"type": "block", "amount": TestAmount}]}
const Fields: Dictionary = {"freeze": TestAmount, "shock": TestAmount, "immobilize": true, "petrify": 1,
	"chilled": true, "bleed": TestAmount, "expose": TestAmount, "block": TestAmount,
	"stoneskin": TestAmount, "frost_armor": 1, "retaliate": {"amount": TestAmount}}

static func catalog(engine: RefCounted, filter: String) -> Array:
	var rows: Array = []
	for entry: Dictionary in Glossary.all_entries():
		var id: String = str(entry["id"])
		if not filter.is_empty() and id != filter: continue
		rows.append({"surface": "glossary", "id": id, "text": entry["definition"], "icon_tooltip": Icons.tooltip(id)})
	for entry: Dictionary in Grimoire.entries():
		if not filter.is_empty() and str(entry["id"]) != filter: continue
		rows.append({"surface": "grimoire", "id": entry["id"], "text": entry["body"]})
	for id: String in Fields:
		if not filter.is_empty() and id != filter: continue
		rows.append(_probe(engine, id))
	for id: String in ["fire", "ice", "rubble", "electrified"]:
		if not filter.is_empty() and id != filter: continue
		rows.append(_ground(engine, id))
	if filter.is_empty() or filter == "wait":
		var state: Dictionary = Fx.state(engine)
		rows.append({"surface": "probe", "id": "wait", "free_plays": engine.cards_remaining_this_turn(state),
			"wait": engine.pending_wait_time(state)})
	if filter.is_empty() or filter == "fatigue":
		var state: Dictionary = Fx.state(engine)
		state["deck"]["hand"] = []
		state["deck"]["draw"] = []
		state["deck"]["discard"] = []
		var empty_before: Dictionary = Fx.receipt(state)
		var empty: Dictionary = engine.apply_player_action(state, {"type": "draw", "amount": TestAmount})
		state["deck"]["discard"] = ["brace"]
		var discard: Dictionary = engine.apply_player_action(state, {"type": "draw", "amount": 1})
		rows.append({"surface": "probe", "id": "fatigue", "empty": Fx.delta(empty_before, Fx.receipt(empty)),
			"recycle": Fx.delta(Fx.receipt(state), Fx.receipt(discard))})
	for id: String in ["quicken_floor", "shock_cleanse", "kill_card_play", "retaliate_reach", "chain_without_shock", "chilled_leave", "wait_bonus", "powder_keg_burst", "bottled_gale_area", "petrify_repeat", "bleed_blink"]:
		if filter.is_empty() or filter == id: rows.append(_witness(engine, id))
	return rows

static func _witness(engine: RefCounted, id: String) -> Dictionary:
	var state: Dictionary = Fx.state(engine)
	var result: Dictionary = {"surface": "probe", "id": id, "text": ""}
	match id:
		"quicken_floor":
			var sand: Dictionary = Cards.play(engine, "hourglass_sand", [], "neutral", "play")
			var follow: Dictionary = Cards.play(engine, "quick_stab", [], "neutral", "play", "",
				{"turn_flags": sand["finish"]["turn_flags"][1]})
			result.merge({"text": sand["steps"][0]["tokens"][0]["tooltip"], "first": sand["finish"],
				"printed_next": int(Fx.Data.card_def("quick_stab")["time"]), "paid_next": follow["finish"]["player_turn_time_spent"][1]}, true)
		"shock_cleanse":
			state["player"]["shock"] = TestAmount
			state = engine._resolve_player_start_of_turn(state)
			var cleanse: Dictionary = {"type": "cleanse", "statuses": ["shock"]}
			var before: Dictionary = Fx.receipt(state)
			result["cleanse_allowed"] = engine.player_action_can_resolve(state, cleanse)
			state = engine.apply_player_action(state, cleanse)
			result["delta"] = Fx.delta(before, Fx.receipt(state))
		"kill_card_play":
			for summoned: bool in [false, true]:
				var trial: Dictionary = state.duplicate(true)
				trial["enemies"][0]["hp"] = 1
				trial["enemies"][0]["summoned"] = summoned
				var after: Dictionary = engine.apply_player_action(trial, Attack, Fx.Foe)
				result[str(summoned)] = Fx.receipt(after)
		"retaliate_reach":
			state["enemies"][0]["pos"] = Fx.Foe + Vector2i.RIGHT
			state["enemies"][0]["intent"] = {"id": id, "time": 1,
				"actions": [{"type": "melee", "range": 2, "damage": Damage}]}
			Retaliate.gain(state, {"amount": TestAmount})
			var before: Dictionary = Fx.receipt(state)
			var after: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]
			result["delta"] = Fx.delta(before, Fx.receipt(after))
		"chain_without_shock":
			result["card"] = Cards.play(engine, "storm_jar", [], "primed", "play")
		"wait_bonus":
			state["cards_played_this_turn"] = engine.BASE_CARDS_PER_TURN
			state["card_play_bonus_this_turn"] = 1
			result["available"] = engine.cards_remaining_this_turn(state)
			result["wait"] = engine.pending_wait_time(state)
		"powder_keg_burst":
			var aim: Vector2i = Fx.Hero + Vector2i.UP
			var adjacent := Fx.enemy(aim + Vector2i.RIGHT, 2)
			var far := Fx.enemy(aim + Vector2i.UP * 2, 3)
			state["enemies"].append_array([adjacent, far])
			var action: Dictionary = Fx.Data.card_def("powder_keg")["actions"][0]
			state = engine.apply_player_action(state, action, aim)
			var before: Dictionary = Fx.receipt(state)
			state = engine._damage_terrain(state, 0, Damage)
			result["aim"] = aim
			result["before"] = before
			result["delta"] = Fx.delta(before, Fx.receipt(state))
		"bottled_gale_area":
			result["card"] = Cards.play(engine, "bottled_gale", [], "primed", "play", "",
				{"enemies": [Fx.enemy(Fx.Foe), Fx.enemy(Fx.Hero + Vector2i.UP, 2), Fx.enemy(Fx.Hero + Vector2i.DOWN * 2, 3)]})
		"petrify_repeat":
			var action: Dictionary = Fx.Data.card_def("petrify")["actions"][0]
			var after: Dictionary = engine.apply_player_action(state, action, Fx.Foe)
			var before_repeat: Dictionary = Fx.receipt(after)
			var legal: Array = engine.valid_targets_for_player_action(after, action)
			var repeated: Dictionary = engine.apply_player_action(after, action, Fx.Foe)
			result.merge({"eligible": Fx.Foe in legal, "first": before_repeat["enemies"]["1"],
				"repeat": Fx.receipt(repeated)["enemies"]["1"]})
		"bleed_blink":
			state["player"]["bleed"] = TestAmount
			var target: Vector2i = Fx.Hero + Vector2i.LEFT
			for kind: String in ["move", "blink"]:
				var after: Dictionary = engine.apply_player_action(state, {"type": kind, "range": 1}, target)
				result[kind] = Fx.receipt(after)["hero"]
		"chilled_leave":
			var ice: Vector2i = Fx.Hero + Vector2i.LEFT
			Fx.Surface.place(state, ice, "ice")
			var entered: Dictionary = engine.apply_player_movement(state, ice)
			var left: Dictionary = engine.apply_player_action(entered, {"type": "blink", "range": 1}, Fx.Hero)
			result["enter"] = Fx.receipt(entered)["hero"]
			result["leave"] = Fx.receipt(left)["hero"]
	return result

static func _probe(engine: RefCounted, field: String) -> Dictionary:
	var state: Dictionary = Fx.state(engine, Fx.Foe + Vector2i.RIGHT if field in ["shock", "bleed", "immobilize"] else Fx.Foe)
	state["enemies"][0][field] = Fields[field]
	state["enemies"][0]["intent"] = EnemyTurn
	var before: Dictionary = Fx.receipt(state)
	var enemy_position: Vector2i = state["enemies"][0]["pos"]
	var ranged: Dictionary = {"type": "ranged", "range": 2, "damage": Damage}
	var first_hit: Dictionary = engine.apply_player_action(state, ranged, enemy_position)
	var second_hit: Dictionary = engine.apply_player_action(first_hit, ranged, enemy_position)
	var turn: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)
	var hero_state: Dictionary = state.duplicate(true)
	hero_state["player"][field] = Fields[field]
	var player_start: Dictionary = engine._resolve_player_start_of_turn(hero_state.duplicate(true))
	return {"surface": "probe", "id": field, "first_hit": Fx.delta(before, Fx.receipt(first_hit)),
		"second_hit": Fx.delta(Fx.receipt(first_hit), Fx.receipt(second_hit)), "enemy_turn": Fx.delta(before, Fx.receipt(turn["state"])),
		"enemy_steps": turn["steps"].map(func(step: Dictionary) -> Array: return [step.get("kind", ""), step.get("action_type", ""), step.get("label", ""), step.get("text", "")]),
		"player_start": Fx.delta(Fx.receipt(hero_state), Fx.receipt(player_start))}

static func _ground(engine: RefCounted, kind: String) -> Dictionary:
	var state: Dictionary = Fx.state(engine)
	var target: Vector2i = Fx.Hero + Vector2i.LEFT
	Fx.Surface.place(state, target, kind)
	var entered: Dictionary = engine.apply_player_movement(state, target)
	var started: Dictionary = engine._resolve_player_start_of_turn(entered.duplicate(true))
	return {"surface": "probe", "id": "surface_" + kind, "enter": Fx.delta(Fx.receipt(state), Fx.receipt(entered)),
		"start": Fx.delta(Fx.receipt(entered), Fx.receipt(started)),
		"cost_to_leave": engine.hero_move_step_cost(entered, entered["player"], target, Fx.Hero, Vector2i.ZERO)}
