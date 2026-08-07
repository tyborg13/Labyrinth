extends RefCounted
class_name CombatObjectiveRules

const KILL_ALL: String = "kill_all"
const KILL_LEADER: String = "kill_leader"
const SURVIVE: String = "survive"
const REACH_EXIT: String = "reach_exit"
const ONBOARDING_ROOM_KEY: String = "objective_onboarding"

const ICON_ROOT: String = "res://assets/art/icons/objectives/"
const DEFINITIONS := {
	KILL_ALL: {
		"name": "Kill All Enemies",
		"short_name": "Kill All",
		"description": "Defeat every enemy in the room.",
		"icon_path": ICON_ROOT + "kill_all_enemies.png"
	},
	KILL_LEADER: {
		"name": "Kill the Leader",
		"short_name": "Kill Leader",
		"description": "Slay the marked leader. The remaining enemies fall when their leader dies.",
		"icon_path": ICON_ROOT + "kill_the_leader.png"
	},
	SURVIVE: {
		"name": "Survive",
		"short_name": "Survive",
		"description": "Hold out until the marked time. Reinforcements emerge while the clock advances.",
		"icon_path": ICON_ROOT + "survive.png"
	},
	REACH_EXIT: {
		"name": "Reach the Exit",
		"short_name": "Reach Exit",
		"description": "Reach a marked threshold to escape through that door. Enemies and terrain are positioned to bar your path.",
		"icon_path": ICON_ROOT + "reach_the_exit.png"
	}
}

const SURVIVAL_TARGET_BY_ENCOUNTER_DEPTH: Array[int] = [42, 46, 50]
const SURVIVAL_REINFORCEMENT_INTERVAL: int = 16
const EXIT_EXTRA_ENEMIES_BY_ENCOUNTER_DEPTH: Array[int] = [1, 2, 2]
const EXIT_TERRAIN_BONUS: int = 3

static func build_for_room(run_seed: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
	var objective_type: String = _type_for_room(run_seed, room)
	var encounter_depth: int = clampi(posmod(int(room.get("depth", 1)) - 1, 4) + 1, 1, 3)
	var result: Dictionary = {
		"type": objective_type,
		"name": display_name(objective_type),
		"description": description(objective_type),
		"icon_path": icon_path(objective_type)
	}
	match objective_type:
		KILL_LEADER:
			var boss_room: bool = str(room.get("type", "combat")) == "boss"
			# Bosses already own authored health and defenses. They use the leader
			# objective so killing the boss ends the encounter, without receiving a
			# second layer of generic leader scaling.
			result["leader_health_multiplier"] = 1.0 if boss_room else 1.5
			result["leader_stoneskin"] = 0 if boss_room else 2 + encounter_depth
		SURVIVE:
			result["target_clock"] = SURVIVAL_TARGET_BY_ENCOUNTER_DEPTH[encounter_depth - 1]
			result["reinforcement_interval"] = SURVIVAL_REINFORCEMENT_INTERVAL
			result["next_reinforcement_clock"] = SURVIVAL_REINFORCEMENT_INTERVAL
			result["reinforcement_waves_spawned"] = 0
		REACH_EXIT:
			result["exits"] = _eligible_exit_specs(room, travel_dir)
			result["extra_enemy_count"] = EXIT_EXTRA_ENEMIES_BY_ENCOUNTER_DEPTH[encounter_depth - 1]
			result["terrain_bonus"] = EXIT_TERRAIN_BONUS
	return result

static func definition(objective_type: String) -> Dictionary:
	return Dictionary(DEFINITIONS.get(objective_type, DEFINITIONS[KILL_ALL])).duplicate(true)

static func display_name(objective_type: String) -> String:
	return str(definition(objective_type).get("name", "Kill All Enemies"))

static func short_name(objective_type: String) -> String:
	return str(definition(objective_type).get("short_name", "Kill All"))

static func description(objective_type: String) -> String:
	return str(definition(objective_type).get("description", "Defeat every enemy in the room."))

static func icon_path(objective_type: String) -> String:
	return str(definition(objective_type).get("icon_path", ICON_ROOT + "kill_all_enemies.png"))

static func exit_target_tiles(objective: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for exit_var: Variant in objective.get("exits", []):
		if typeof(exit_var) != TYPE_DICTIONARY:
			continue
		var exit_spec: Dictionary = exit_var
		var target: Variant = exit_spec.get("target_tile", Vector2i(-1, -1))
		if typeof(target) == TYPE_VECTOR2I and not tiles.has(target):
			tiles.append(target)
	return tiles

static func exit_door_tiles(objective: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for exit_var: Variant in objective.get("exits", []):
		if typeof(exit_var) != TYPE_DICTIONARY:
			continue
		var exit_spec: Dictionary = exit_var
		var door: Variant = exit_spec.get("door_tile", Vector2i(-1, -1))
		if typeof(door) == TYPE_VECTOR2I and not tiles.has(door):
			tiles.append(door)
	return tiles

static func exit_spec_for_target(objective: Dictionary, target_tile: Vector2i) -> Dictionary:
	for exit_var: Variant in objective.get("exits", []):
		if typeof(exit_var) != TYPE_DICTIONARY:
			continue
		var exit_spec: Dictionary = exit_var as Dictionary
		if exit_spec.get("target_tile", Vector2i(-1, -1)) == target_tile:
			return exit_spec.duplicate(true)
	return {}

static func exit_target_tile_for_direction(direction: Vector2i) -> Vector2i:
	match direction:
		Vector2i(0, -1):
			return Vector2i(4, 1)
		Vector2i(1, 0):
			return Vector2i(7, 4)
		Vector2i(0, 1):
			return Vector2i(4, 7)
		Vector2i(-1, 0):
			return Vector2i(1, 4)
	return Vector2i(-1, -1)

static func door_tile_for_direction(direction: Vector2i) -> Vector2i:
	match direction:
		Vector2i(0, -1):
			return Vector2i(4, 0)
		Vector2i(1, 0):
			return Vector2i(8, 4)
		Vector2i(0, 1):
			return Vector2i(4, 8)
		Vector2i(-1, 0):
			return Vector2i(0, 4)
	return Vector2i(-1, -1)

static func is_control_intent(intent: Dictionary) -> bool:
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		for control_key: String in ["immobilize", "freeze", "pull", "push"]:
			if int(action.get(control_key, 0)) > 0:
				return true
	return false

static func _type_for_room(run_seed: int, room: Dictionary) -> String:
	var room_type: String = str(room.get("type", "combat"))
	if room_type == "boss":
		return KILL_LEADER
	if room_type != "combat":
		return KILL_ALL
	if bool(room.get(ONBOARDING_ROOM_KEY, false)):
		return KILL_ALL
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var roll: int = posmod(_mixed_seed(run_seed, coord, 1709), 100)
	if roll < 25:
		return KILL_ALL
	if roll < 50:
		return KILL_LEADER
	if roll < 75:
		return SURVIVE
	return REACH_EXIT

static func _eligible_exit_specs(room: Dictionary, travel_dir: Vector2i) -> Array[Dictionary]:
	var exits: Array[Dictionary] = []
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var door_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
		if door_dir == Vector2i.ZERO or door_dir == -travel_dir:
			continue
		if str(connection.get("kind", "")) == "inward":
			continue
		var target_tile: Vector2i = exit_target_tile_for_direction(door_dir)
		if target_tile.x < 0:
			continue
		exits.append({
			"direction": door_dir,
			"door_tile": door_tile_for_direction(door_dir),
			"target_tile": target_tile,
			"coord": connection.get("coord", Vector2i.ZERO),
			"kind": str(connection.get("kind", "lateral"))
		})
	# A generated combat room should always have an onward choice. Keep a safe
	# fallback for handcrafted fixtures that only declare a single connection.
	if exits.is_empty():
		for connection_var: Variant in room.get("connections", []):
			if typeof(connection_var) != TYPE_DICTIONARY:
				continue
			var connection: Dictionary = connection_var
			var door_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
			var target_tile: Vector2i = exit_target_tile_for_direction(door_dir)
			if target_tile.x < 0:
				continue
			exits.append({
				"direction": door_dir,
				"door_tile": door_tile_for_direction(door_dir),
				"target_tile": target_tile,
				"coord": connection.get("coord", Vector2i.ZERO),
				"kind": str(connection.get("kind", "lateral"))
			})
	return exits

static func _mixed_seed(run_seed: int, coord: Vector2i, salt: int) -> int:
	var value: int = run_seed * 73856093
	value ^= coord.x * 19349663
	value ^= coord.y * 83492791
	value ^= salt * 2654435761
	return value
