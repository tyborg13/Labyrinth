extends SceneTree
## Deterministic, bounded, greedy measurement policy. All transitions are the
## same CombatEngine APIs used by tools/headless_playtest.gd.
const Sweep = preload("res://tools/encounter_sweep.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Game = preload("res://scripts/game_data.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Store = preload("res://scripts/analytics_store.gd")
const POLICY_VERSION: int = 2
const DECK_REWARD_SEED: int = 2102026
const REWARD_ROLL_LIMIT: int = 10000
const MAX_TURNS: int = 30
const MAX_DECISIONS_PER_TURN: int = 12
const MAX_MOVE_OPTIONS: int = 5
const MAX_ACTION_TARGETS: int = 3
const MAX_CARD_BRANCHES: int = 3
const MAX_PREVIEW_OPTIONS: int = 6
const MAX_EXPANDED_ACTION_STATES: int = 96
const KILL_SCORE: float = 5.0
const INCOMING_DAMAGE_WEIGHT: float = 1.5
const HEALING_WEIGHT: float = 1.0
const MAX_HP: int = 24

static func defaults() -> Dictionary:
	return {"policy_version": POLICY_VERSION, "healing_weight": HEALING_WEIGHT, "survival_first": true, "dodge_search": "all remaining free-movement destinations plus stay; objective-sorted zero-damage bound", "approach_order": "retained movement, objective distance, engine order", "damage_score": "1.5 times (pass-dodge damage minus candidate-dodge damage)", "trace": false, "deck_reward_seed": DECK_REWARD_SEED, "reward_roll_limit": REWARD_ROLL_LIMIT, "max_turns": MAX_TURNS, "max_decisions_per_turn": MAX_DECISIONS_PER_TURN, "max_move_options": MAX_MOVE_OPTIONS, "max_action_targets": MAX_ACTION_TARGETS, "max_card_branches": MAX_CARD_BRANCHES, "max_preview_options": MAX_PREVIEW_OPTIONS, "max_expanded_action_states": MAX_EXPANDED_ACTION_STATES, "hp": MAX_HP, "kill_score": KILL_SCORE, "incoming_damage_weight": INCOMING_DAMAGE_WEIGHT, "objective_progress_weight": 1.0, "empower": false, "skills": [], "relics": [], "defiance": 0}

static func deck_presets() -> Dictionary:
	var engine := Run.new()
	var common: Array[String]
	var rare: Array[String]
	# Rejection sample the actual reward offer stream, retaining its authored
	# rarity and card weights. No manually maintained reward pool or card ids.
	for roll: int in range(REWARD_ROLL_LIMIT):
		var offered: Array[String] = engine._generate_card_rewards({"seed": DECK_REWARD_SEED}, Vector2i(roll + 1, 0))
		for card_id: String in offered:
			var rarity: String = str(Game.card_def(card_id).get("rarity", "common"))
			if rarity == "common" and common.size() < 3: common.append(card_id)
			if rarity == "rare" and rare.size() < 2: rare.append(card_id)
		if common.size() == 3 and rare.size() == 2: break
	assert(common.size() == 3 and rare.size() == 2, "Reward stream must supply deck presets")
	var tier1: Array = Game.starting_deck().duplicate()
	var tier2: Array = tier1 + common
	return {"1": tier1, "2": tier2, "3": tier2 + rare, "common_rewards": common, "rare_rewards": rare}

class Policy:
	extends RefCounted
	var engine = CombatEngine.new()
	var expanded: int = 0
	var last_preview_count: int = 0
	var trace: bool = false

	func enemy_hp(state: Dictionary) -> Dictionary:
		var result: Dictionary = {}
		for enemy: Dictionary in state.get("enemies", []): result[int(enemy["id"])] = maxi(0, int(enemy["hp"]))
		return result

	func exit_distance(state: Dictionary) -> int:
		return Sweep.unblocked_distance(state["grid"], state["player"]["pos"], Objectives.exit_target_tiles(state.get("objective", {})))

	func kill_count(state: Dictionary) -> int:
		return int((state.get("run_stats", {}) as Dictionary).get("enemies_killed", 0))

	func gain(before: Dictionary, after: Dictionary) -> float:
		# Leader completion marks living followers objective_cleared with zero HP.
		# Only the engine counters distinguish that cull from actual damage/kills;
		# they also include summoned units born and killed inside one transition.
		var previous_stats: Dictionary = before.get("run_stats", {})
		var current_stats: Dictionary = after.get("run_stats", {})
		var value: float = maxi(0, int(current_stats.get("damage_dealt", 0)) - int(previous_stats.get("damage_dealt", 0)))
		value += KILL_SCORE * maxi(0, kill_count(after) - kill_count(before))
		var leader: int = int((before.get("objective", {}) as Dictionary).get("leader_id", -1))
		if leader >= 0:
			value += maxi(0, int(enemy_hp(before).get(leader, 0)) - int(enemy_hp(after).get(leader, 0)))
		if str(before.get("objective", {}).get("type", "")) == Objectives.REACH_EXIT:
			var old_distance: int = exit_distance(before)
			var new_distance: int = exit_distance(after)
			if old_distance >= 0 and new_distance >= 0: value += old_distance - new_distance
		return value

	func phase_preview(state: Dictionary) -> Dictionary:
		# The same revealed-intent preview as the UI; never peek at unrevealed
		# follow-up intents. It includes card Time, Block and Stoneskin.
		last_preview_count += 1
		var scheduled: Dictionary = engine.finish_player_activation(state)
		var preview: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled)
		var after: Dictionary = preview.get("state", state)
		return {"damage": maxi(0, int(state["player"]["hp"]) - int(after["player"]["hp"])), "survives": int(after["player"]["hp"]) > 0}

	func objective_distance(state: Dictionary) -> int:
		var objective: Dictionary = state.get("objective", {})
		if str(objective.get("type", "")) == Objectives.REACH_EXIT: return exit_distance(state)
		var leader_id: int = int(objective.get("leader_id", -1))
		if leader_id >= 0:
			for enemy: Dictionary in state["enemies"]:
				if int(enemy["id"]) == leader_id and int(enemy["hp"]) > 0:
					return Sweep.Paths.manhattan(state["player"]["pos"], enemy["pos"])
		return nearest_enemy(state)

	func dodge_precedes(candidate: Dictionary, incumbent: Dictionary) -> bool:
		if incumbent.is_empty(): return true
		if candidate["survives"] != incumbent["survives"]: return bool(candidate["survives"])
		if candidate["damage"] != incumbent["damage"]: return int(candidate["damage"]) < int(incumbent["damage"])
		return int(candidate["distance"]) < int(incumbent["distance"])

	func best_dodge(state: Dictionary) -> Dictionary:
		# Search every legal destination in the remaining free movement pool,
		# including staying put. Movement is committed only after the final card.
		var candidates: Array[Dictionary]
		candidates.append({"state": state, "distance": objective_distance(state), "order": 0})
		for tile: Vector2i in engine.player_movement_targets(state):
			var moved: Dictionary = engine.apply_player_movement(state, tile)
			candidates.append({"state": moved, "distance": objective_distance(moved), "order": candidates.size()})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["distance"] != b["distance"]: return a["distance"] < b["distance"]
			return int(a["order"]) < int(b["order"]))
		var best: Dictionary = {}
		for candidate: Dictionary in candidates:
			var moved: Dictionary = candidate["state"]
			var preview: Dictionary = phase_preview(moved)
			# Include damage on the way to the destination (Fire, Bleed, traps).
			var damage: int = int(preview["damage"]) + maxi(0, int(state["player"]["hp"]) - int(moved["player"]["hp"]))
			var distance: int = int(candidate["distance"])
			var evaluated: Dictionary = {"state": moved, "damage": damage, "survives": preview["survives"], "distance": distance}
			if dodge_precedes(evaluated, best): best = evaluated
			# Zero is the exact lower bound. Objective-sorted destinations make
			# the first surviving zero-damage preview provably optimal.
			if bool(preview["survives"]) and damage == 0: break
		return best

	func option_score(before: Dictionary, after: Dictionary, baseline: Dictionary, dodge: Dictionary) -> float:
		# Marginal preview damage credits defense only when it actually saves HP
		# this phase, and charges cards that expose the hero or extend the clock.
		var value: float = gain(before, after) + INCOMING_DAMAGE_WEIGHT * (int(baseline["damage"]) - int(dodge["damage"]))
		value += HEALING_WEIGHT * (int(after["player"]["hp"]) - int(before["player"]["hp"]))
		if str(before.get("objective", {}).get("type", "")) == Objectives.REACH_EXIT:
			# Free progress available even when passing is not a card's benefit.
			value += exit_distance(after) - int(dodge["distance"]) - (exit_distance(before) - int(baseline["distance"]))
		return value

	func branches(state: Dictionary, actions: Array, index: int, effect: bool) -> Array[Dictionary]:
		var result: Array[Dictionary]
		if index >= actions.size():
			if effect: result.append(state)
			return result
		if expanded >= MAX_EXPANDED_ACTION_STATES: return result
		var action: Dictionary = actions[index]
		if not engine.player_action_can_resolve(state, action): return branches(state, actions, index + 1, effect)
		if not engine.player_action_needs_target(action) or (str(action.get("type", "")) == "aoe" and int(action.get("range", 0)) <= 0):
			expanded += 1
			return branches(engine.apply_player_action(state, action), actions, index + 1, true)
		var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
		var candidates: Array[Dictionary]
		for target: Vector2i in targets:
			if expanded >= MAX_EXPANDED_ACTION_STATES: break
			expanded += 1
			var after: Dictionary = engine.apply_player_action(state, action, target)
			candidates.append({"state": after, "gain": gain(state, after), "order": candidates.size()})
		# Stable ordering is the engine's target order on equal gain.
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if float(a["gain"]) != float(b["gain"]): return float(a["gain"]) > float(b["gain"])
			return int(a["order"]) < int(b["order"]))
		for candidate: Dictionary in candidates.slice(0, MAX_ACTION_TARGETS):
			result.append_array(branches(candidate["state"], actions, index + 1, true))
			if result.size() >= MAX_CARD_BRANCHES: break
		return result.slice(0, MAX_CARD_BRANCHES)

	func choose(state: Dictionary) -> Dictionary:
		last_preview_count = 0
		var baseline: Dictionary = best_dodge(state)
		if engine.combat_outcome(baseline["state"]) == "victory": return {}
		var origins: Array[Dictionary]
		origins.append({"state": state, "order": 0})
		var movements: Array[Dictionary]
		for tile: Vector2i in engine.player_movement_targets(state):
			var moved: Dictionary = engine.apply_player_movement(state, tile)
			movements.append({"state": moved, "distance": objective_distance(moved), "remaining": engine.player_movement_remaining(moved), "order": movements.size() + 1})
		movements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["remaining"] != b["remaining"]: return a["remaining"] > b["remaining"]
			if a["distance"] != b["distance"]: return a["distance"] < b["distance"]
			return int(a["order"]) < int(b["order"]))
		origins.append_array(movements.slice(0, MAX_MOVE_OPTIONS))
		var options: Array[Dictionary]
		for origin: Dictionary in origins:
			var base: Dictionary = origin["state"]
			var hand: Array = base["deck"]["hand"]
			for hand_index: int in range(hand.size()):
				if not engine.hand_card_has_play_budget(base, hand_index): continue
				expanded = 0
				var prepared: Dictionary = engine.prepare_player_card(base, hand_index)
				var card_actions: Array = engine.card_play_actions(str(hand[hand_index]), prepared)
				for resolved: Dictionary in branches(prepared, card_actions, 0, false):
					var after: Dictionary = engine.finish_player_card(resolved, hand_index, engine.card_plays_spent_for_actions(card_actions), {"play_mode": "play"})
					var defense: int = maxi(0, int(after["player"].get("block", 0)) + int(after["player"].get("stoneskin", 0)) - int(state["player"].get("block", 0)) - int(state["player"].get("stoneskin", 0)))
					var potential: float = gain(state, after) + INCOMING_DAMAGE_WEIGHT * mini(defense, int(baseline["damage"]))
					potential += HEALING_WEIGHT * (int(after["player"]["hp"]) - int(state["player"]["hp"]))
					options.append({"state": after, "card": hand[hand_index], "potential": potential, "remaining": engine.player_movement_remaining(after), "order": options.size()})
		options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if float(a["potential"]) != float(b["potential"]): return float(a["potential"]) > float(b["potential"])
			if a["remaining"] != b["remaining"]: return a["remaining"] > b["remaining"]
			return int(a["order"]) < int(b["order"]))
		var best: Dictionary = {}
		var score: float = 0.0
		var survives: bool = bool(baseline["survives"])
		for option: Dictionary in options.slice(0, MAX_PREVIEW_OPTIONS):
			var dodge: Dictionary = best_dodge(option["state"])
			var value: float = option_score(state, option["state"], baseline, dodge)
			if survives and not bool(dodge["survives"]): continue
			if (bool(dodge["survives"]) and not survives) or value > score:
				survives = bool(dodge["survives"])
				score = value
				best = {"state": option["state"], "score": score, "card": option["card"], "dodge": dodge["state"]["player"]["pos"], "predicted_damage": dodge["damage"]}
		return best

	func nearest_enemy(state: Dictionary) -> int:
		var nearest: int = 1000000
		for enemy: Dictionary in state["enemies"]:
			if int(enemy["hp"]) > 0: nearest = mini(nearest, Sweep.Paths.manhattan(state["player"]["pos"], enemy["pos"]))
		return nearest

	func run_room(seed_value: int, layout: Dictionary, deck: Array) -> Dictionary:
		var state: Dictionary = engine.create_combat(seed_value, layout, {"hp": MAX_HP, "max_hp": MAX_HP, "deck_cards": deck, "equipped_equipment": Game.starting_equipped_equipment(), "relics": []})
		var first_death: Variant = null
		var kills: int = 0
		var turns: int = 1
		var actions: int = 0
		var previews: int = 0
		var capped: bool = false
		while engine.combat_outcome(state).is_empty():
			turns = int(state["turn"])
			if turns > MAX_TURNS:
				capped = true
				turns = MAX_TURNS
				break
			var decision: int = 0
			while decision < MAX_DECISIONS_PER_TURN and engine.combat_outcome(state).is_empty():
				var selected: Dictionary = choose(state)
				previews += last_preview_count
				if selected.is_empty(): break
				if trace: print("BOT CARD: ", Store._sanitize_variant({"turn": turns, "before": state["player"], "remaining": engine.player_movement_remaining(state), "card": selected["card"], "after": selected["state"]["player"], "dodge": selected["dodge"], "predicted_damage": selected["predicted_damage"], "score": selected["score"]}))
				state = selected["state"]
				if kill_count(state) > kills and first_death == null: first_death = turns
				kills = kill_count(state)
				decision += 1
				actions += 1
			if decision == MAX_DECISIONS_PER_TURN: capped = true
			if not engine.combat_outcome(state).is_empty(): break
			last_preview_count = 0
			var dodge: Dictionary = best_dodge(state)
			state = dodge["state"]
			if trace: print("BOT DODGE: ", Store._sanitize_variant({"turn": turns, "player": state["player"], "predicted_damage": dodge["damage"], "enemies": state["enemies"]}))
			if kill_count(state) > kills and first_death == null: first_death = turns
			kills = kill_count(state)
			previews += last_preview_count
			if not engine.combat_outcome(state).is_empty(): break
			state = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))["state"]
			if trace: print("BOT PHASE: ", Store._sanitize_variant({"turn": turns, "player": state["player"], "outcome": engine.combat_outcome(state)}))
			if kill_count(state) > kills and first_death == null: first_death = turns
			kills = kill_count(state)
		var outcome: String = engine.combat_outcome(state)
		return {"policy_version": POLICY_VERSION, "seed": seed_value, "objective": layout["objective"]["type"], "outcome": outcome if not outcome.is_empty() else "lost", "won": outcome == "victory", "turns": turns, "hp_lost": int(state.get("run_stats", {}).get("damage_received", 0)), "net_hp_lost": MAX_HP - int(state["player"]["hp"]), "kills": kills, "first_enemy_death_turn": first_death, "search_capped": capped, "turn_cap_reached": outcome.is_empty(), "decisions": actions, "intent_previews": previews}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var presets: Dictionary = deck_presets()
	var tier: int = int(Sweep.option(args, "--tier", "1"))
	assert(tier in [1, 2, 3])
	var count: int = int(Sweep.option(args, "--runs", "1"))
	var objective: String = Sweep.option(args, "--objective", "kill_all")
	var requested_coord: String = Sweep.option(args, "--coord", "")
	assert(requested_coord.is_empty() or count == 1, "Coordinate replay requires exactly one run")
	assert(objective in ["kill_all", "kill_leader", "reach_exit"] and count > 0)
	var output: String = Sweep.option(args, "--output", "user://encounter_bot.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var policy := Policy.new()
	policy.trace = args.has("--trace")
	var results: Array[Dictionary]
	var seed_value: int = int(Sweep.option(args, "--seed", "1"))
	while results.size() < count:
		var state: Dictionary = Sweep.map_for_seed(seed_value)
		for sample: Dictionary in Sweep.samples(state):
			if int(sample["tier"]) != tier: continue
			var coord: Vector2i = sample["room"]["coord"]
			if not requested_coord.is_empty() and requested_coord != "%d,%d" % [coord.x, coord.y]: continue
			var room: Dictionary = Sweep.layout(sample, state)
			if room["objective"]["type"] != objective: continue
			var result: Dictionary = policy.run_room(seed_value, room, presets[str(tier)])
			result.merge({"tier": tier, "biome": sample["biome"], "section_index": sample["section_index"], "coord": Store._sanitize_variant(sample["room"]["coord"]), "travel_dir": Store._sanitize_variant(sample["travel_dir"]), "encounter_id": room.get("encounter_id", "")})
			results.append(result)
			print("ENCOUNTER BOT RUN: " + JSON.stringify(result))
			if results.size() >= count: break
		if not requested_coord.is_empty() and results.is_empty():
			push_error("No sampled room matches the requested seed, tier, objective and coordinate")
			quit(1)
			return
		seed_value += 1
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"defaults": defaults(), "decks": presets, "results": results}, "\t"))
	print("ENCOUNTER BOT: PASS (%d runs, tier %d, %s)" % [results.size(), tier, objective])
	quit()
