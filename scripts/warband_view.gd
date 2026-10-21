extends RefCounted

const Rules = preload("res://scripts/warband_combat_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Pacing = preload("res://scripts/combat_pacing.gd")
const Actors = preload("res://scripts/actor_presentation.gd")
const Maquette = preload("res://scripts/maquette_cutout_runtime/action.gd")
# The brief specifies one simultaneous beat, but no duration. Retain the
# existing two-tile travel cadence pending the director's timing value.
const TODO_DESIGN_WARBAND_BREAK_BEAT_SECONDS: float = Pacing.ENEMY_TILE_SECONDS * Rules.FLEE_TILES

static func draw_banner_tile(board: Control, tile: Vector2i, polygon: PackedVector2Array, gold: Color) -> void:
	var state: Dictionary = board.get("combat_state")
	var leader: Dictionary = Rules.captain(state)
	if leader.is_empty() or not Paths.is_passable(state.get("grid", []), tile): return
	var radius: int = int(state["objective"]["command"]["radius"])
	if Paths.manhattan(tile, leader["pos"]) > radius: return
	# Preserve Umbra privacy: the banner never reveals an unseen captain/zone.
	var presentation: Dictionary = board.get("presentation")
	if presentation.has("visible_enemy_ids") and not (presentation["visible_enemy_ids"] as Array).has(int(leader["id"])): return
	board.draw_colored_polygon(polygon, Color(gold, 0.18))
	for edge: int in range(4):
		var neighbor: Vector2i = tile + Paths.DIRS_4[edge]
		if Paths.manhattan(neighbor, leader["pos"]) > radius or not Paths.is_passable(state["grid"], neighbor):
			board.draw_line(polygon[edge], polygon[edge + 1], Color(gold, 0.70), 2.0, true)

static func break_started(before: Dictionary, after: Dictionary) -> bool:
	return Rules.active(after) and bool(after.get("objective", {}).get("completed_by_leader", false)) and not bool(before.get("objective", {}).get("completed_by_leader", false))

static func animate_break(scene: Node, before: Dictionary, after: Dictionary, base: Dictionary) -> void:
	if not break_started(before, after): return
	scene._set_action_banner(str(after["objective"]["break_line"]))
	if scene._reduced_motion_enabled(): return
	var display: Dictionary = flee_display_state(before, after)
	var followers: Array[Dictionary]
	for enemy: Dictionary in display["enemies"]:
		if bool(enemy.get("warband_fled", false)): followers.append(enemy)
	# Keep the captain silhouette continuous from the lethal hit through the
	# escape beat, until the ordinary dissolve takes ownership.
	var held: Dictionary = scene._death_hold_presentation(before, after, base)
	var held_captain: Array[Dictionary]
	for unit: Dictionary in held.get("death_animation_units", []):
		if not bool(unit.get("warband_fled", false)): held_captain.append(unit)
	held["death_animation_units"] = held_captain
	var origin: int = scene._combat_pacing.presentation_usec()
	var duration: int = roundi(TODO_DESIGN_WARBAND_BREAK_BEAT_SECONDS * 1000000.0)
	while true:
		var progress: float = clampf(float(scene._combat_pacing.presentation_usec() - origin) / duration, 0.0, 1.0)
		var frame: Dictionary = break_frame(scene.board_view, followers, progress, held)
		scene._render_board_state(display, frame)
		if progress >= 1.0: break
		await scene.get_tree().process_frame

static func break_frame(board: Control, followers: Array[Dictionary], progress: float, base: Dictionary = {}) -> Dictionary:
	var frame: Dictionary = base.duplicate(true)
	frame["unit_world_positions"] = {}
	frame["unit_draw_tiles"] = {}
	for enemy: Dictionary in followers:
		var path: Array = enemy["warband_flee_path"]
		var segment: int = mini(path.size() - 2, floori(progress * (path.size() - 1)))
		if segment < 0: continue
		var phase: float = minf(1.0, progress * (path.size() - 1) - segment)
		var from: Vector2 = board.world_position_for_unit_origin(enemy, path[segment])
		var to: Vector2 = board.world_position_for_unit_origin(enemy, path[segment + 1])
		var key: String = "enemy_%d" % int(enemy["id"])
		frame["unit_world_positions"][key] = from.lerp(to, phase)
		frame["unit_draw_tiles"][key] = board.draw_tile_for_unit_origin(enemy, path[segment + 1])
		if Maquette.handles(str(enemy["type"])):
			# The ordinary one-actor adapter owns its dictionaries. Compose each
			# result so repeated types and all other walkers survive this beat.
			var moving: Dictionary = {}
			Maquette.movement_frame(moving, str(enemy["type"]), key, from, to, path[segment + 1] - path[segment], phase, false)
			for field: String in moving:
				if not frame.has(field): frame[field] = {}
				(frame[field] as Dictionary).merge(moving[field], true)
		else:
			var motion_key: String = {"warden": "warden_motion", "chainbound_gaoler": "gaoler_motion", "cinder_ooze": "cinder_ooze_motion", "frostglass_lancer": "frostglass_motion", "gust_shrike": "gust_shrike_motion", "veilbound_acolyte": "veilbound_acolyte_motion"}.get(str(enemy["type"]), "")
			if not motion_key.is_empty():
				if not frame.has(motion_key): frame[motion_key] = {}
				var gait: float = phase
				var renderer: Script = Actors.travel_renderer(str(enemy["type"]))
				if enemy["type"] != "gust_shrike" and renderer != null:
					var distance: float = from.distance_to(to) * phase
					for index: int in range(segment):
						distance += board.world_position_for_unit_origin(enemy, path[index]).distance_to(board.world_position_for_unit_origin(enemy, path[index + 1]))
					gait = distance / board.source_pixel_scale_for_type(str(enemy["type"])) / float(renderer.call("walk_cycle_distance"))
				frame[motion_key][key] = {"clip": "move" if enemy["type"] == "gust_shrike" else "walk", "direction": path[segment + 1] - path[segment], "phase": gait}
	return frame

# Fleeing is a removal, never a hit/death/heal. Filter only the audio snapshot;
# the board still receives the full run and dissolve units at every frame.
static func sound_snapshot(state: Dictionary, shown: Dictionary) -> Dictionary:
	var has_fled: bool = false
	for enemy: Dictionary in state.get("enemies", []):
		if bool(enemy.get("warband_fled", false)): has_fled = true; break
	if not has_fled: return {"state": state, "shown": shown}
	var silent: Dictionary = state.duplicate(false)
	var enemies: Array[Dictionary]
	for enemy: Dictionary in state.get("enemies", []):
		if not bool(enemy.get("warband_fled", false)): enemies.append(enemy)
	silent["enemies"] = enemies
	var presentation: Dictionary = shown.duplicate(false)
	if shown.has("death_animation_units"):
		var deaths: Array[Dictionary]
		for unit: Dictionary in shown["death_animation_units"]:
			if not bool(unit.get("warband_fled", false)): deaths.append(unit)
		presentation["death_animation_units"] = deaths
	return {"state": silent, "shown": presentation}

# Every fleeing follower presents its body for the run/dissolve. This transient
# exposure never executes Burrow/Erupt/Ambush or changes the committed statuses.
static func flee_display_state(before: Dictionary, after: Dictionary) -> Dictionary:
	var display: Dictionary = after.duplicate(true)
	var previous: Dictionary = {}
	for enemy: Dictionary in before.get("enemies", []): previous[int(enemy["id"])] = enemy
	for enemy: Dictionary in display.get("enemies", []):
		if not bool(enemy.get("warband_fled", false)): continue
		enemy["hp"] = previous.get(int(enemy["id"]), enemy).get("hp", 1)
		enemy["burrowed"] = false
		enemy["veiled"] = false
	return display
