extends "res://tools/run_hunt_policy.gd"
## Coverage-only choice order. Every choice still uses the inherited legal
## offers and UI dispatch. Avoid wasting real-speed combat on empty attacks.
var map_origin: Vector2i
var map_origin_known: bool = false
var attempted_map_targets: Dictionary = {}

func choose(scene: Node, candidates: Array) -> Dictionary:
	var run: Dictionary = scene.get("_run_state")
	var mode: String = str(run.get("mode", ""))
	if mode != "combat":
		var current_room: Vector2i = run.get("current_room", Vector2i.ZERO)
		if not map_origin_known or current_room != map_origin:
			map_origin = current_room
			map_origin_known = true
			attempted_map_targets.clear()
		if scene.has_method("_treasure_presentation_busy") and bool(scene.call("_treasure_presentation_busy")):
			var interactions: Array[Dictionary]
			for candidate: Dictionary in candidates:
				if str(candidate.get("kind", "")) == "ui": interactions.append(candidate)
			if not interactions.is_empty():
				attempted_map_targets.clear()
				return interactions[rng.randi_range(0, interactions.size() - 1)]
		var destinations: Array[Dictionary]
		var best_section: int = -1
		var best_step: int = -1
		for candidate: Dictionary in candidates:
			if str(candidate.get("kind", "")) == "begin_combat": return candidate
			if str(candidate.get("kind", "")) != "map_room": continue
			if candidate["args"][0] == current_room or attempted_map_targets.has(candidate["args"][0]): continue
			var metadata: Dictionary = scene.get("_run_engine").room_metadata(run, candidate["args"][0])
			var section: int = int(metadata.get("section_index", 0))
			var step: int = int(metadata.get("map_step", metadata.get("depth", 0)))
			if section > best_section or (section == best_section and step > best_step):
				destinations.clear()
				best_section = section
				best_step = step
			if section == best_section and step == best_step: destinations.append(candidate)
		if not destinations.is_empty():
			var selected: Dictionary = destinations[rng.randi_range(0, destinations.size() - 1)]
			attempted_map_targets[selected["args"][0]] = true
			return selected
		# An unchanged origin after dispatch means that transition did not enter
		# its destination. Service contextual UI instead of looping that offer.
		var remaining: Array[Dictionary]
		for candidate: Dictionary in candidates:
			if str(candidate.get("kind", "")) != "map_room": remaining.append(candidate)
		if not remaining.is_empty():
			attempted_map_targets.clear()
			return super.choose(scene, remaining)
		attempted_map_targets.clear()
		return super.choose(scene, candidates)
	var state: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	var attacks: Array[Dictionary]
	var advances: Array[Dictionary]
	var other_cards: Array[Dictionary]
	for candidate: Dictionary in candidates:
		var kind: String = str(candidate.get("kind", ""))
		if kind == "card":
			var options: Dictionary = scene.call("_card_play_options_for_index", int(candidate["args"][0]))
			var preview: Dictionary = options.get("play", {})
			var action: Dictionary = preview.get("action", {})
			var preview_state: Dictionary = preview.get("state", state)
			var action_type: String = str(action.get("type", ""))
			# Completed previews can already contain targetless/AoE damage and
			# expose no pending action. Use the engine's existing damage counter.
			var damage_before: int = int((state.get("run_stats", {}) as Dictionary).get("damage_dealt", 0))
			var damage_after: int = int((preview_state.get("run_stats", {}) as Dictionary).get("damage_dealt", 0))
			if damage_after > damage_before:
				attacks.append(candidate)
			elif ATTACK_TYPES.has(action_type):
				for tile: Vector2i in preview.get("target_tiles", []):
					if _hits_enemy(engine, preview_state, action, tile):
						attacks.append(candidate)
						break
			elif action_type in ["move", "blink"]:
				for tile: Vector2i in preview.get("target_tiles", []):
					if _toward_enemy(preview_state, tile):
						advances.append(candidate)
						break
			else: other_cards.append(candidate)
		elif ATTACK_TYPES.has(kind) and bool(candidate.get("preferred", false)):
			attacks.append(candidate)
		elif kind in ["move", "blink"] and bool(candidate.get("preferred", false)):
			advances.append(candidate)
		elif kind in ["confirm_card", "orientation", "cancel_card"]:
			return candidate
	if str((state.get("objective", {}) as Dictionary).get("type", "")) == "reach_exit" and not advances.is_empty():
		return _best_advance(state, advances)
	if not attacks.is_empty():
		var focused: Dictionary = attacks[rng.randi_range(0, attacks.size() - 1)]
		var lowest_hp: int = -1
		for candidate: Dictionary in attacks:
			if str(candidate.get("kind", "")) == "card": continue
			for enemy: Dictionary in state.get("enemies", []):
				var hp: int = int(enemy.get("hp", 0))
				if hp <= 0: continue
				if int(enemy.get("id", -2)) == int((state.get("objective", {}) as Dictionary).get("leader_id", -1)) and engine._enemy_footprint_tiles(enemy).has(candidate["args"][0]): return candidate
				if engine._enemy_footprint_tiles(enemy).has(candidate["args"][0]) and (lowest_hp < 0 or hp < lowest_hp):
					focused = candidate
					lowest_hp = hp
		return focused
	if not advances.is_empty(): return _best_advance(state, advances)
	# Defensive/targetless cards still need to cycle out of the hand. Skipping
	# them can leave no new attacks available even across repeated passes.
	if not other_cards.is_empty(): return other_cards[rng.randi_range(0, other_cards.size() - 1)]
	for candidate: Dictionary in candidates:
		if str(candidate.get("kind", "")) == "pass": return candidate
	return super.choose(scene, candidates)

func _best_advance(state: Dictionary, advances: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = advances[0]
	var best_distance: int = 2147483647
	for candidate: Dictionary in advances:
		if str(candidate.get("kind", "")) == "card": continue
		var tile: Vector2i = candidate.get("tile", (candidate.get("args", [Vector2i.ZERO]) as Array)[0])
		var distance: int = _goal_distance(state, tile)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func _toward_enemy(state: Dictionary, tile: Vector2i) -> bool:
	var origin: Vector2i = state.get("player", {}).get("pos", Vector2i.ZERO)
	return _goal_distance(state, tile) < _goal_distance(state, origin)

func _goal_distance(state: Dictionary, tile: Vector2i) -> int:
	var objective: Dictionary = state.get("objective", {})
	var goals: Array[Vector2i]
	if str(objective.get("type", "")) == "reach_exit":
		for exit_spec: Dictionary in objective.get("exits", []):
			if not bool(exit_spec.get("sealed", false)): goals.append(exit_spec["target_tile"])
	else:
		var leader: int = int(objective.get("leader_id", -1))
		for enemy: Dictionary in state.get("enemies", []):
			if int(enemy.get("hp", 0)) <= 0: continue
			if leader >= 0 and int(enemy.get("id", -2)) != leader: continue
			goals.append(enemy["pos"])
	var distance: int = 2147483647
	for goal: Vector2i in goals: distance = mini(distance, absi(tile.x - goal.x) + absi(tile.y - goal.y))
	return distance
