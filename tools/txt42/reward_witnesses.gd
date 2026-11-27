extends RefCounted

# Reward settlement and Curator fixtures adapted from txt-40 run_witnesses.gd.
const F = preload("res://tools/txt42/fixture.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const FIRST := Vector2i(1, 0)
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Snare = preload("res://tools/snare_inspection.gd")
const SnareRules = preload("res://scripts/snare_room_rules.gd")
const Hoarder = preload("res://scripts/hoarder_room_rules.gd")
const SNARE_SEED: int = 1
const NATURAL_REPEAT_SEED: int = 73037
const NATURAL_REPEAT_RELIC: String = "hourglass_splinter"
const REPLACEMENT_RELIC: String = "thawing_charm"
const DRAGON_ROOM := Vector2i(4, 0)
const SPECIAL_ROOM := Vector2i(3, 0)
const VICTORY_HEALTH: int = 12


static func _linear_run(f: F, skills: Array = []) -> Dictionary:
	return f.run.create_new_run(F.SEED, f.profile(skills), false)


static func _room(f: F, state: Dictionary, coord: Vector2i, type: String, extra: Dictionary = {}) -> void:
	var key: String = f.run._room_key(coord)
	var room: Dictionary = f.run.room_metadata(state, coord)
	room.merge({"type": type, "cleared": false, "revealed": true, "sealed": false, "npcs": [], "merchant_kind": ""}, true)
	room.merge(extra, true)
	state["rooms"][key] = room


static func _enter_fight(f: F, state: Dictionary, coord: Vector2i, type: String, extra: Dictionary = {}) -> Dictionary:
	_room(f, state, coord, type, extra)
	state["current_room"] = coord
	state["mode"] = "pre_battle"
	return f.run.begin_pre_battle_combat(state)


static func _victory(f: F, state: Dictionary, hp: int = VICTORY_HEALTH) -> Dictionary:
	var combat: Dictionary = state["combat_state"].duplicate(true)
	combat["player"]["hp"] = hp
	# Start with a real generated encounter. Resolve its last damage with the
	# engine so leader/objective/reward hooks see the same state shape as play.
	for index: int in range(combat["enemies"].size()):
		var enemy: Dictionary = combat["enemies"][index]
		if int(enemy["hp"]) <= 0:
			continue
		combat = f.engine._damage_enemy(combat, index, enemy["hp"] + F.LETHAL_MARGIN, false, true)
	return f.run.finish_combat(state, combat)


static func rewards(f: F) -> void:
	var state: Dictionary = _linear_run(f)
	var regular: Dictionary = regular_reward(f)
	var choices: Array = regular["pending_reward"].get("cards", [])
	var picked: Dictionary = f.run.claim_card_reward(regular, str(choices.front()) if not choices.is_empty() else "")
	var heal: int = _skip_heal(f, regular)
	var one_card: bool = picked["deck_cards"].size() == regular["deck_cards"].size() + 1
	f.observe("rewards_regular", regular["mode"] == "reward" and choices.size() == 3 and one_card and heal == 3,
		"Ordinary card choices=%d, claim adds one card=%s, skip Health gain=%d" % [choices.size(), one_card, heal])

	var guard: Dictionary = _guardian_victory(f, state.duplicate(true), FIRST)
	var trophy: String = guard.get("guardian_reward", {}).get("relic_id", "")
	f.observe("rewards_guardian", guard["mode"] == "treasure" and not trophy.is_empty()
		and guard["pending_relics"] == [trophy] and guard["pending_reward"].is_empty(),
		"Guardian trophy=%s, card reward=%s" % [trophy, guard["pending_reward"]])
	var trophy_owned: Dictionary = state.duplicate(true)
	trophy_owned["relics"].append(trophy)
	var fallback: Dictionary = _guardian_victory(f, trophy_owned, FIRST)
	f.observe("rewards_guardian_owned", fallback["mode"] == "reward" and _choice_count(fallback) == 3,
		"Guardian trophy already owned: mode=%s, cards=%d" % [fallback["mode"], _choice_count(fallback)])

	var dragon: Dictionary = _dragon_victory(f, state.duplicate(true))
	var milestone: Dictionary = dragon["pending_reward"]
	f.observe("rewards_dragon", dragon["mode"] == "reward" and f.run.is_dragon_reward(dragon)
		and not milestone.has("cards") and not str(milestone.get("relic_id", "")).is_empty(),
		"Dragon rewards %s, %d Health, %d Moltshard; card choices=%d" %
		[milestone.get("relic_id", ""), milestone.get("healed_amount", 0), milestone.get("moltshards", 0), milestone.get("cards", []).size()])
	var final: Dictionary = _victory(f, _enter_fight(f, state.duplicate(true), DRAGON_ROOM, "boss",
		{"element": "shadow", "boss_id": Bosses.SHADOW_BOSS_ID, "depth": 24}))
	var final_reward: Dictionary = final["pending_reward"]
	f.observe("rewards_dragon_final", final["mode"] == "reward" and f.run.is_dragon_reward(final)
		and bool(final_reward.get("next_descent", false)) and bool(final_reward.get("final_boss", false)),
		"Final dragon: mode=%s, reward kind=%s, relic for next descent=%s" %
		[final["mode"], final_reward.get("kind", ""), final_reward.get("relic_id", "")])

	for type: String in Specials.enabled_types():
		if type == "umbral_snare":
			_snare_reward(f)
			continue
		var fight: Dictionary = _enter_fight(f, state.duplicate(true), SPECIAL_ROOM, "special",
			{"element": "fire", "special_type": type, "special_variant": "fire"})
		if type == "ember_hoarder":
			_hoarder_missed(f, fight.duplicate(true))
		elif type == "last_light":
			_last_light_failed(f, fight.duplicate(true))
		var combat: Dictionary = fight["combat_state"]
		var objective: Dictionary = combat["objective"]
		# Stage completion of the non-kill objectives before production settlement.
		if objective.get("type") == Objectives.SURVIVE:
			combat["initiative_clock"] = objective["target_clock"]
		var special: Dictionary = _victory(f, fight)
		var card_count: int = special["pending_reward"].get("cards", []).size()
		var special_heal: int = _skip_heal(f, special)
		var room: Dictionary = f.run.room_metadata(special, special["current_room"])
		f.observe("rewards_" + type, special["mode"] == "reward" and bool(room.get("special_goal_met", false)) and card_count == 4 and special_heal == 3,
			"%s with goal met offers %d cards and skip heals %d" %
			[Specials.definition(type)["name"], card_count, special_heal])


static func regular_reward(f: F) -> Dictionary:
	return _victory(f, _enter_fight(f, _linear_run(f), FIRST, "combat", {"element": "fire"}))


static func _hoarder_missed(f: F, fight: Dictionary) -> void:
	var combat: Dictionary = fight["combat_state"]
	Hoarder.slip_away(combat)
	var objective: Dictionary = combat["objective"]
	var reward: Dictionary = _victory(f, fight)
	var count: int = _choice_count(reward)
	var heal: int = _skip_heal(f, reward)
	f.observe("rewards_ember_hoarder_missed", bool(objective.get("hoarder_escaped", false))
		and not bool(objective["goal_met"]) and objective["type"] == Objectives.KILL_ALL
		and reward["mode"] == "reward" and count == 3 and heal == 3,
		"Hoarder escaped, then the remaining enemies were defeated: %d cards, skip heals %d" % [count, heal])


static func _last_light_failed(f: F, fight: Dictionary) -> void:
	var combat: Dictionary = fight["combat_state"]
	var before_dawn: bool = int(combat["initiative_clock"]) < int(combat["objective"]["target_clock"])
	var result: Dictionary = _defeat(f, fight)
	var count: int = _choice_count(result)
	f.observe("rewards_last_light_defeat_control", before_dawn and result["mode"] == "defeat" and count == 0,
		"Fell before dawn=%s, settlement mode=%s, cards=%d" % [before_dawn, result["mode"], count])
	# Extinguished braziers change the healing bonus. Surviving still meets the goal.
	for brazier: Dictionary in combat["guardian_braziers"]:
		brazier["lit"] = false
	combat["initiative_clock"] = combat["objective"]["target_clock"]
	combat["player"]["hp"] = VICTORY_HEALTH
	var dark_dawn: Dictionary = f.run.finish_combat(fight, combat)
	var room: Dictionary = f.run.room_metadata(dark_dawn, dark_dawn["current_room"])
	var bonus: int = dark_dawn["pending_reward"].get("healed_amount", -1)
	f.observe("rewards_last_light_dark_dawn", dark_dawn["mode"] == "reward" and bool(room.get("special_goal_met", false))
		and _choice_count(dark_dawn) == 4 and bonus == 0,
		"Survived with zero lit braziers: goal met=%s, cards=%d, dawn Health bonus=%d" %
		[room.get("special_goal_met", false), _choice_count(dark_dawn), bonus])


# From snare_suite.gd: preserve the generated section room and its outgoing
# doors, which the legacy linear fixture cannot supply for the formation.
static func _snare_reward(f: F) -> void:
	var run: Dictionary = f.run.create_new_run(SNARE_SEED, f.profile())
	for room: Dictionary in run["rooms"].values():
		if room.get("special_type", "") != "umbral_snare":
			continue
		for parent: Dictionary in run["rooms"].values():
			for link: Dictionary in parent["connections"]:
				if link["coord"] != room["coord"]:
					continue
				run["current_room"] = parent["coord"]
				parent["cleared"] = true
				run["mode"] = "room"
				var fight: Dictionary = f.run.begin_pre_battle_combat(f.run.move_to_pre_battle(run, room["coord"]))
				_snare_outcomes(f, fight)
				return
	f.observe("rewards_umbral_snare", false, "Seed did not produce a reachable Snare")


static func _snare_outcomes(f: F, fight: Dictionary) -> void:
	var late: Dictionary = fight.duplicate(true)
	var objective: Dictionary = late["combat_state"]["objective"]
	for exit: Dictionary in objective["exits"]:
		objective["player_turns_completed"] = maxi(int(objective["player_turns_completed"]), int(exit.get("seal_after_player_turns", 0)))
	objective["enemy_round_pending"] = true
	SnareRules.end_round(late["combat_state"])
	for after_sealing: bool in [false, true]:
		var escaping: Dictionary = late if after_sealing else fight.duplicate(true)
		Snare.stage(f.engine, escaping, "escape")
		var combat: Dictionary = escaping["combat_state"]
		combat["player"]["hp"] = VICTORY_HEALTH
		var doors: int = f.engine.snare_escape_context(combat)["doors_open_at_escape"]
		var reward: Dictionary = f.run.finish_combat(escaping, combat)
		var count: int = _choice_count(reward)
		var heal: int = _skip_heal(f, reward)
		f.observe("rewards_umbral_snare_sealed" if after_sealing else "rewards_umbral_snare",
			(doors == 1 if after_sealing else doors > 1) and reward["mode"] == "reward" and count == 3 and heal == 3,
			"Umbral Snare escape: open doors=%d, cards=%d, skip heals %d" % [doors, count, heal])
	var lost: Dictionary = _defeat(f, fight)
	f.observe("rewards_umbral_snare_defeat_control", lost["mode"] == "defeat" and _choice_count(lost) == 0,
		"Umbral Snare defeat: settlement mode=%s, cards=%d" % [lost["mode"], _choice_count(lost)])


static func curator_offer(f: F, seed: int = F.SEED) -> Dictionary:
	var state: Dictionary = _linear_run(f, ["curators_patience"])
	state["seed"] = seed
	_room(f, state, FIRST, "treasure")
	return f.run.move_to_room(state, FIRST)


static func curator(f: F) -> void:
	var offer: Dictionary = curator_offer(f)
	var offered: Array = offer["pending_relics"]
	var deferred: String = offered[1]
	var state: Dictionary = f.run.claim_relic(offer, offered[0], deferred)
	var second: Vector2i = f.run.available_moves(state).front()
	_room(f, state, second, "treasure")
	var treasure: Dictionary = f.run.move_to_room(state.duplicate(true), second)
	var guardian: Dictionary = _guardian_victory(f, state.duplicate(true), second)
	var dragon: Dictionary = _dragon_victory(f, state.duplicate(true))
	var dragon_relic: String = dragon["pending_reward"].get("relic_id", "")
	f.observe("curator_skill", state["skill_state"]["pending_relic"] == deferred
		and deferred in treasure["pending_relics"] and treasure["skill_state"]["pending_relic"] == ""
		and guardian["skill_state"]["pending_relic"] == deferred
		and not guardian["pending_relics"].is_empty() and deferred not in guardian["pending_relics"]
		and dragon["skill_state"]["pending_relic"] == deferred and not dragon_relic.is_empty() and dragon_relic != deferred,
		"Saved %s, next Relic room offers %s, Guardian offers %s, dragon awards %s, still saved after Guardian/dragon=%s/%s" %
		[deferred, treasure["pending_relics"], guardian["pending_relics"], dragon_relic,
		guardian["skill_state"]["pending_relic"], dragon["skill_state"]["pending_relic"]])
	_curator_dialog(f, NATURAL_REPEAT_SEED, NATURAL_REPEAT_RELIC, true)
	_curator_dialog(f, F.SEED, REPLACEMENT_RELIC, false)


static func _curator_dialog(f: F, seed: int, deferred: String, repeats: bool) -> void:
	var offer: Dictionary = curator_offer(f, seed)
	var offered: Array = offer["pending_relics"]
	var control: Dictionary = f.run.claim_relic(offer, offered[0])
	var saved: Dictionary = f.run.claim_relic(offer, offered[0], deferred)
	var destination: Vector2i = f.run.available_moves(control).front()
	_room(f, control, destination, "treasure")
	_room(f, saved, destination, "treasure")
	var natural: Array = f.run.move_to_room(control, destination)["pending_relics"]
	var room: Dictionary = f.run.move_to_room(saved, destination)
	var with_saved: Array = room["pending_relics"]
	var expected_offer: Array = natural.duplicate()
	if not repeats and not expected_offer.is_empty():
		expected_offer[expected_offer.size() - 1] = deferred
	f.observe("curator_dialog_repeat" if repeats else "curator_dialog_replacement",
		saved["skill_state"]["pending_relic"] == deferred and room["skill_state"]["pending_relic"] == ""
		and deferred in with_saved and natural.has(deferred) == repeats and with_saved == expected_offer,
		"Seed %d saved %s, roll without saving=%s, next Relic room after saving=%s" % [seed, deferred, natural, with_saved])


static func _defeat(f: F, fight: Dictionary) -> Dictionary:
	var combat: Dictionary = fight["combat_state"].duplicate(true)
	combat["player"]["hp"] = 0
	return f.run.finish_combat(fight, combat)


static func _choice_count(reward: Dictionary) -> int:
	return (reward["pending_reward"].get("cards", []) as Array).size()


static func _skip_heal(f: F, reward: Dictionary) -> int:
	return int(f.run.skip_reward_for_heal(reward)["player_hp"]) - int(reward["player_hp"])


static func _guardian_victory(f: F, state: Dictionary, coord: Vector2i) -> Dictionary:
	return _victory(f, _enter_fight(f, state, coord, "guardian",
		{"element": "fire", "boss_id": Bosses.FIRE_BOSS_ID, "guardian_id": "ashen_reaver"}))


static func _dragon_victory(f: F, state: Dictionary) -> Dictionary:
	return _victory(f, _enter_fight(f, state, DRAGON_ROOM, "boss", {"element": "fire", "boss_id": Bosses.FIRE_BOSS_ID}))
