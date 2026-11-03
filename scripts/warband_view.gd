extends RefCounted

const TileGlow = preload("res://scripts/tile_glow.gd")
const Rules = preload("res://scripts/warband_combat_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Actors = preload("res://scripts/actor_presentation.gd")
const Maquette = preload("res://scripts/maquette_cutout_runtime/action.gd")
# Director feedback 1 approves the existing two-tile travel cadence.
const BREAK_BEAT_SECONDS: float = 0.4

# Command is a soft gold ground glow, brightest under the captain and feathered
# at the zone's edge (owner, warband-built: no outlined shapes). Alphas are a
# zone-wide base plus a radial glow; edge corners keep a fraction of it.
const COMMAND_BASE_ALPHA: float = 0.12
const COMMAND_GLOW_ALPHA: float = 0.24
const COMMAND_EDGE_FRACTION: float = 0.6
# A feathered rim just inside the zone's edge gives it shape without a line.
const COMMAND_RIM_ALPHA: float = 0.34
const COMMAND_RIM_DEPTH: float = 0.26
# Each tile corner as a doubled grid offset, in `_tile_polygon` vertex order.
const TILE_CORNERS: Array = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]

static var _corner_alphas := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
static var _rim_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _rim_colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])

static func draw_banner_tile(board: Control, tile: Vector2i, polygon: PackedVector2Array, gold: Color, prepared_leader: Variant = null) -> void:
	var leader: Dictionary = command_leader(board) if prepared_leader == null else prepared_leader
	_draw_command(board, board.combat_state, leader, tile, polygon, gold)

static func _draw_command(canvas: Object, state: Dictionary, leader: Dictionary, tile: Vector2i, polygon: PackedVector2Array, gold: Color) -> void:
	if leader.is_empty() or not _in_command(state, leader, tile): return
	var radius: float = float(state["objective"]["command"]["radius"]) + 0.5
	var captain := Vector2(leader["pos"])
	for index: int in range(4):
		var corner: Vector2i = TILE_CORNERS[index]
		var inside: bool = _in_command(state, leader, tile + Vector2i(corner.x, 0)) and _in_command(state, leader, tile + Vector2i(0, corner.y)) and _in_command(state, leader, tile + corner)
		var alpha: float = _glow_alpha(Vector2(tile) + Vector2(corner) * 0.5, captain, radius)
		_corner_alphas[index] = alpha if inside else alpha * COMMAND_EDGE_FRACTION
	TileGlow.draw(canvas, polygon, gold, _glow_alpha(Vector2(tile), captain, radius), _corner_alphas)
	var centre: Vector2 = (polygon[0] + polygon[2]) * 0.5
	for edge: int in range(4):
		if _in_command(state, leader, tile + Paths.DIRS_4[edge]): continue
		var next: int = (edge + 1) % 4
		_rim_points[0] = polygon[edge]
		_rim_points[1] = polygon[next]
		_rim_points[2] = polygon[next].lerp(centre, COMMAND_RIM_DEPTH)
		_rim_points[3] = polygon[edge].lerp(centre, COMMAND_RIM_DEPTH)
		_rim_colours[0] = Color(gold, COMMAND_RIM_ALPHA)
		_rim_colours[1] = _rim_colours[0]
		_rim_colours[2] = Color(gold, 0.0)
		_rim_colours[3] = _rim_colours[2]
		canvas.draw_polygon(_rim_points, _rim_colours)

# Diagnostic command capture retained for marker/performance equivalence probes.
# The production overlay calls draw_banner_tile directly with retained buffers.
class CommandCapture extends RefCounted:
	var triangles: Array = []
	func draw_polygon(points: PackedVector2Array, colours: PackedColorArray) -> void:
		triangles.append([points.duplicate(), colours.duplicate()])

static func glow_fan(state: Dictionary, leader: Dictionary, tile: Vector2i, polygon: PackedVector2Array, gold: Color) -> Array:
	var capture := CommandCapture.new()
	_draw_command(capture, state, leader, tile, polygon, gold)
	return capture.triangles

# The living captain whose zone may be shown, or {} (Umbra privacy: an unseen
# captain shows no zone).
static func command_leader(board: Control) -> Dictionary:
	var state: Dictionary = board.get("combat_state")
	var leader: Dictionary = Rules.captain(state)
	if leader.is_empty(): return {}
	var presentation: Dictionary = board.get("presentation")
	if presentation.has("visible_enemy_ids") and not (presentation["visible_enemy_ids"] as Array).has(int(leader["id"])): return {}
	return leader

static func _in_command(state: Dictionary, leader: Dictionary, tile: Vector2i) -> bool:
	return Paths.is_passable(state.get("grid", []), tile) and Paths.manhattan(tile, leader["pos"]) <= int(state["objective"]["command"]["radius"])

static func _glow_alpha(at: Vector2, captain: Vector2, radius: float) -> float:
	var falloff: float = clampf(1.0 - at.distance_to(captain) / radius, 0.0, 1.0)
	return COMMAND_BASE_ALPHA + COMMAND_GLOW_ALPHA * falloff * falloff

static func break_started(before: Dictionary, after: Dictionary) -> bool:
	# The Ember Hoarder's brood scatters by this same break (spx-09).
	var breaks: bool = Rules.active(after) or preload("res://scripts/hoarder_room_rules.gd").active(after)
	return breaks and bool(after.get("objective", {}).get("completed_by_leader", false)) and not bool(before.get("objective", {}).get("completed_by_leader", false))

static func animate_break(scene: Node, before: Dictionary, after: Dictionary, base: Dictionary) -> void:
	if not break_started(before, after): return
	if not str(after["objective"].get("break_line", "")).is_empty(): scene._set_action_banner(str(after["objective"]["break_line"]))
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
	var duration: int = roundi(BREAK_BEAT_SECONDS * 1000000.0)
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
			# The flee keeps a constant pace through tile boundaries, like any other path.
			var root_override: Dictionary = {"forward_px": from.distance_to(to) * phase, "axis": (to - from).normalized(), "path_from": path[segment], "path_to": path[segment + 1]}
			Maquette.movement_frame(moving, str(enemy["type"]), key, from, to, path[segment + 1] - path[segment], phase, false, root_override)
			for field: String in moving:
				if not frame.has(field): frame[field] = {}
				(frame[field] as Dictionary).merge(moving[field], true)
		else:
			var motion_key: String = {"warden": "warden_motion", "cinder_ooze": "cinder_ooze_motion", "frostglass_lancer": "frostglass_motion", "gust_shrike": "gust_shrike_motion", "veilbound_acolyte": "veilbound_acolyte_motion"}.get(str(enemy["type"]), "")
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
		enemy.erase("veiled")
	return display
