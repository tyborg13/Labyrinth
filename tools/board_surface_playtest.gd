extends "res://tools/headless_playtest.gd"

# Bounded, inspectable regression policy, not a general game solver. All committed
# plays, travel, rewards and initiative transitions use the manual harness APIs.
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const BUILDS: Dictionary = {
	"mixed": ["cinder_bloom", "cinderline_tempo", "quarry_step", "cold_grasp", "chain_bolt", "slipstream_cut"],
	"fire": ["guiding_flare", "firebrand_volley", "cinder_bloom", "hearth_rush", "cinderline_tempo", "ember_tithe"],
	"earth": ["venom_claw", "stone_plate", "quarry_step", "thorn_skewer", "root_snare", "stone_plate"],
	"ice": ["frostbolt", "rime_shard", "cold_grasp", "icicle_lance", "frostbolt", "cold_grasp"],
	"air": ["dawnstep", "threaded_path", "gust_step", "slipstream_cut", "updraft", "slipstream_cut"],
	"lightning": ["spark_dart", "chain_bolt", "spark_focus", "static_lash", "spark_dart", "chain_bolt"]
}
var build: String = "mixed"
var manual: bool = false
var decisions: int = 0
var rounds: int = 0
var room_rounds: int = 0
var rooms_won: int = 0
var end_reason: String = ""
var counters: Dictionary = {}
var played: Dictionary = {}
var journey: Array = []
var last_room: Vector2i = Vector2i(999, 999)
var last_mode: String = ""

func _start_new_run(seed: int) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	manual = args.has("--manual")
	for index: int in range(args.size() - 1):
		if args[index] == "--build":
			build = args[index + 1]
	assert(BUILDS.has(build), "Unknown controlled build")
	super._start_new_run(seed)
	_run_state["attuned_magic_cards"] = (BUILDS[build] as Array).duplicate()
	_run_state["reward_cards"] = (BUILDS[build] as Array).duplicate()
	_run_state["magic_inventory"] = []
	_run_state = _run_engine._rebuild_deck_cards(_run_state)
	_append_note("Controlled loadout: %s. Six common spells; ordinary starter equipment, HP, progression, room generation and enemy scaling. Rewards heal to preserve the controlled spell comparison. No tactical state edits after setup.\nPolicy: legal greedy full-card targets; actual next-activation forecast ranks cards; movement seeks a useful shot or escapes disclosed threat; ground has local positional value, never a global tile-count bonus.\n" % str(BUILDS[build]))

func _print_state() -> void:
	if OS.get_cmdline_user_args().has("--manual"):
		super._print_state()
		return
	var mode: String = str(_run_state.get("mode", ""))
	var coord: Vector2i = _run_state.get("current_room", Vector2i.ZERO)
	if mode != last_mode or coord != last_room:
		var metadata: Dictionary = _run_engine.room_metadata(_run_state, coord)
		var row: Dictionary = {"room": str(coord), "depth": metadata.get("depth", 0), "type": metadata.get("type", ""), "mode": mode, "hp": _run_state.get("player_hp", 0), "decisions": decisions}
		journey.append(row)
		print("CHECKPOINT %s" % JSON.stringify(row))
		if mode == "combat":
			room_rounds = 0
			_append_note("\nEncounter %s: %s\n" % [coord, str(_combat_state.get("enemies", []))])
		last_room = coord
		last_mode = mode

func _print_card_resolution(card_id: String, before_state: Dictionary, after_state: Dictionary, actions: Array, _targets: Array[Vector2i]) -> void:
	_count(played, card_id)
	_observe(before_state, after_state)
	print("PLAY %s | %s" % [card_id, _card_delta_text(before_state, after_state, actions)])

func _print_enemy_round_resolution(_phase: Dictionary, before_state: Dictionary, after_enemy_state: Dictionary, _before_draw_state: Dictionary, next_turn_state: Dictionary) -> void:
	var after: Dictionary = next_turn_state if not next_turn_state.is_empty() else after_enemy_state
	_observe(before_state, after)
	if manual:
		super._print_enemy_round_resolution(_phase, before_state, after_enemy_state, _before_draw_state, next_turn_state)
		return
	print("ROUND %d | HP %s | enemies %d | ground %d" % [rounds, str((after.get("player", {}) as Dictionary).get("hp", 0)), _living(after), (after.get("surfaces", {}) as Dictionary).size()])

func _observe(before: Dictionary, after: Dictionary) -> void:
	for event: Dictionary in _combat_engine._surface_events_since(before, after):
		var key: String = str(event.get("kind", ""))
		if key == "surface_removed":
			key += ":" + str(event.get("reason", ""))
		elif key in ["surface_created", "surface_replaced"]:
			key += ":" + str(event.get("surface", ""))
		elif key == "surface_damage":
			key += ":" + str(event.get("actor_kind", ""))
		_count(counters, key)
		_append_note("  Ground event: %s\n" % JSON.stringify(event))

func _repl() -> void:
	manual = OS.get_cmdline_user_args().has("--manual")
	if manual:
		super._repl()
		return
	while decisions < 900:
		decisions += 1
		var mode: String = str(_run_state.get("mode", ""))
		match mode:
			"room":
				if not _travel():
					end_reason = "no_legal_room_progress"
					break
			"escape", "pre_battle":
				_command_continue()
			"combat":
				if room_rounds > 90:
					end_reason = "combat_stalemate_90_activations"
					break
				_fight()
			"reward":
				rooms_won += 1
				var metadata: Dictionary = _run_engine.room_metadata(_run_state, _run_state.get("current_room", Vector2i.ZERO))
				_command_reward(PackedStringArray(["reward", "heal"]))
				if str(metadata.get("type", "")) == "boss":
					end_reason = "boss_victory"
					break
			"treasure":
				_command_relic(PackedStringArray(["relic", "0"]))
			"campfire":
				_command_linger()
			"defeat", "victory", "rested":
				end_reason = mode
				break
			_:
				end_reason = "unhandled_mode:" + mode
				break
	if end_reason.is_empty():
		end_reason = "safety_decision_limit"
	var summary: Dictionary = {"seed": _run_state.get("seed", 0), "build": build, "loadout": BUILDS[build], "end_reason": end_reason, "decisions": decisions, "player_activations": rounds, "rooms_won": rooms_won, "hp": _run_state.get("player_hp", 0), "surface_events": counters, "cards_played": played, "journey": journey, "policy_version": 1}
	var file: FileAccess = FileAccess.open(str(_options["output_dir"]).path_join("policy_summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	_append_note("\nEndpoint: %s. %d completed combats, %d player activations.\nLimitations: controlled common loadouts, greedily chosen card targets, first available relic, heal rewards; no claim of optimal play or equal-seed statistical balance.\n" % [end_reason, rooms_won, rounds])
	print("POLICY RESULT %s" % JSON.stringify(summary))
	_print_analytics_summary()

func _travel() -> bool:
	var moves: Array[Vector2i] = _run_engine.available_moves(_run_state)
	if moves.is_empty():
		return false
	var best_index: int = 0
	var best_score: float = -INF
	for index: int in range(moves.size()):
		var room: Dictionary = _run_engine.room_metadata(_run_state, moves[index])
		var score: float = float(room.get("depth", 0)) * 10.0
		if str(room.get("type", "")) == "boss":
			score += 5
		if str(room.get("type", "")) == "campfire" and int(_run_state.get("player_hp", 0)) < int(_run_state.get("player_max_hp", 1)) * 0.7:
			score += 7
		if str(room.get("element", "")) == build:
			score += 1
		if score > best_score:
			best_score = score
			best_index = index
	_command_move(best_index)
	return true

func _fight() -> void:
	var plan: Dictionary = _best_card(_combat_state)
	var score: float = float(plan.get("score", -INF))
	# Independent movement is considered before each card, so it can connect two
	# plays, escape a threat after attacking, or reveal useful nearby floor.
	var walk: Dictionary = _best_walk(_combat_state, score)
	if not walk.is_empty():
		_append_note("- Policy walk: %s, score %.2f vs immediate card %.2f.\n" % [walk["tile"], float(walk["score"]), score])
		_command_walk("%d,%d" % [(walk["tile"] as Vector2i).x, (walk["tile"] as Vector2i).y])
		return
	if not plan.is_empty() and score > 0.45:
		_append_note("- Policy card: %s; evaluated gain %.2f, targets %s.\n" % [plan["card_id"], score, str(plan["targets"])])
		_pending = plan
		_commit_pending()
		return
	rounds += 1
	room_rounds += 1
	_append_note("- Policy pass: best useful card score %.2f; allow revealed initiative to advance.\n" % score)
	_command_pass()

func _best_card(state: Dictionary) -> Dictionary:
	if _combat_engine.cards_remaining_this_turn(state) <= 0:
		return {}
	var hand: Array = (state.get("deck", {}) as Dictionary).get("hand", [])
	var baseline: float = _value(state)
	var pass_value: float = _future_value(state)
	var best: Dictionary = {}
	var evaluated_ids: Dictionary = {}
	for index: int in range(hand.size()):
		var card_id: String = str(hand[index])
		if evaluated_ids.has(card_id):
			continue
		evaluated_ids[card_id] = true
		var working: Dictionary = _combat_engine.prepare_player_card(state, index, "play")
		var actions: Array = _combat_engine.card_play_actions(card_id, working)
		var targets: Array[Vector2i]
		var changed: bool = false
		for action: Dictionary in actions:
			var chosen: Vector2i = INVALID_TARGET_TILE
			var candidate: Dictionary = working
			if _combat_engine.player_action_can_resolve(working, action):
				if _combat_engine.player_action_needs_target(action):
					var action_best: float = -INF
					for tile: Vector2i in _combat_engine.valid_targets_for_player_action(working, action):
						var tested: Dictionary = _combat_engine.apply_prevalidated_player_action(working, action, tile)
						var value: float = _value(tested)
						if value > action_best:
							action_best = value
							candidate = tested
							chosen = tile
				else:
					candidate = _combat_engine.apply_player_action(working, action)
			if candidate != working:
				changed = true
			working = candidate
			targets.append(chosen)
		if not changed:
			continue
		var finished: Dictionary = _combat_engine.finish_player_card(working, index, _combat_engine.card_plays_spent_for_actions(actions), {"play_mode": "play"})
		var score: float = (_value(working) - baseline) * 0.55 + (_future_value(finished) - pass_value) * 0.65 - 0.15
		if best.is_empty() or score > float(best["score"]):
			best = {"score": score, "state": working, "card_id": card_id, "hand_index": index, "actions": actions, "targets": targets}
	return best

func _best_walk(state: Dictionary, card_score: float) -> Dictionary:
	var origin: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var candidates: Array = []
	var baseline: float = _value(state)
	for tile: Vector2i in _combat_engine.player_movement_targets(state):
		var moved: Dictionary = _combat_engine.apply_player_movement(state, tile)
		var score: float = _value(moved) - baseline
		candidates.append({"tile": tile, "state": moved, "score": score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var best: Dictionary = {}
	var pass_value: float = _future_value(state)
	for index: int in range(mini(3, candidates.size())):
		var candidate: Dictionary = candidates[index]
		var moved: Dictionary = candidate["state"]
		var card: Dictionary = _best_card(moved)
		var score: float = float(candidate["score"]) * 0.4 + maxf(0, float(card.get("score", 0))) + (_future_value(moved) - pass_value) * 0.6 - PathUtils.manhattan(origin, candidate["tile"]) * 0.1
		if score > maxf(0.6, card_score + 0.5) and (best.is_empty() or score > float(best["score"])):
			best = {"tile": candidate["tile"], "score": score}
	return best

func _future_value(state: Dictionary) -> float:
	if not _combat_engine.combat_outcome(state).is_empty():
		return _value(state)
	var phase: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(_combat_engine.finish_player_activation(state))
	return _value(phase.get("state", state))

func _value(state: Dictionary) -> float:
	var player: Dictionary = state.get("player", {})
	var pos: Vector2i = player.get("pos", Vector2i.ZERO)
	var score: float = float(player.get("hp", 0)) * 0.3 + minf(80, float(player.get("block", 0))) * 0.035 + float(player.get("stoneskin", 0)) * 0.06
	if int(player.get("hp", 0)) <= 0:
		score -= 500
	var objective: Dictionary = state.get("objective", {})
	if str(objective.get("type", "")) == Objectives.REACH_EXIT:
		var distance: int = 999
		for exit_tile: Vector2i in Objectives.exit_target_tiles(objective):
			var path: Array[Vector2i] = PathUtils.find_path(state.get("grid", []), pos, exit_tile)
			if not path.is_empty():
				distance = mini(distance, path.size() - 1)
		if distance < 999:
			score -= distance * 1.2
	if _combat_engine.combat_outcome(state) == "victory":
		score += 30
	var nearest: int = 99
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0:
			continue
		score -= float(enemy.get("hp", 0)) * 0.1 + 6
		var enemy_pos: Vector2i = enemy.get("pos", Vector2i.ZERO)
		if not _combat_engine.is_tile_visible_to_player(state, enemy_pos):
			continue
		nearest = mini(nearest, PathUtils.manhattan(pos, enemy_pos))
		if int(enemy.get("freeze", 0)) > 0:
			score += 5
		if int(enemy.get("shock", 0)) > 0:
			score += 2
		if BoardSurfaceRules.unit_on(state, enemy, "fire"):
			score += 1.8
		if BoardSurfaceRules.unit_on(state, enemy, "ice"):
			score += 1.1
		if BoardSurfaceRules.unit_on(state, enemy, "electrified"):
			score += 0.9
		if BoardSurfaceRules.unit_on(state, enemy, "rubble"):
			score += 0.25
	if nearest < 99:
		score -= maxi(0, nearest - 2) * 0.5
	else:
		score += _combat_engine.umbra_visible_tile_lookup(state).size() * 0.05
	if BoardSurfaceRules.unit_on(state, player, "fire"):
		score -= 3
	if BoardSurfaceRules.unit_on(state, player, "ice"):
		score -= 1.5
	return score

func _living(state: Dictionary) -> int:
	var count: int = 0
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0:
			count += 1
	return count
