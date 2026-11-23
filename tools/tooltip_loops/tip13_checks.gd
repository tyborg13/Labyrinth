extends RefCounted
## Verify the resolver journals and the effects submitted to the recording board.
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const CardChecks = preload("res://tools/tooltip_loops/tip06_checks.gd")
const Board = preload("res://tools/tooltip_loops/record_board.gd")

const EMBER_TICK: String = "burst_ember_tick"
const IDS: Array = [EMBER_TICK, "discharge_network"]
const TICK_TILE := Vector2i(1, 1)
const ADJACENT_TILE := TICK_TILE + Vector2i.UP
const DIAGONAL_TILE := ADJACENT_TILE + Vector2i.RIGHT
const MIN_LOOP_SECONDS: float = 2.0
const MAX_LOOP_SECONDS: float = 6.0

var impact_frame: int = -1
var _effect_tiles: Dictionary = {}
var _numbers: Dictionary = {}
var _wrong_footprint: bool = false
var _diagonal_visible: bool = false

static func validate(fixture: Dictionary, result: Dictionary, setup: Script) -> Array[String]:
	var failures: Array[String]
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	var beats: Array = result["beats"]
	if beats.size() != 1:
		failures.append("%s must resolve one production action" % fixture["id"])
		return failures
	for state: Dictionary in [before, after]:
		if not CardChecks.plain_room(state) or state.get("room_element", "none") != "none" or not state["illusions"].is_empty():
			failures.append("%s must use plain floor without ambient elements, light, Umbra or hazards" % fixture["id"])
			break
	if fixture["id"] == EMBER_TICK:
		_validate_ember_tick(before, after, failures)
	else:
		_validate_discharge(before, after, beats[0]["action"], setup.NETWORK, failures)
	return failures

static func _validate_ember_tick(before: Dictionary, after: Dictionary, failures: Array[String]) -> void:
	var events: Array = after.get("death_burst_events", [])
	if events.size() != 1 or before["enemies"].size() != 3:
		failures.append("Ember Tick must die and record one Burst with an adjacent and a diagonal witness")
		return
	var event: Dictionary = events[0]
	var tick: Dictionary = before["enemies"][0]
	var center: Vector2i = tick["pos"]
	var cross: Array = _expected_area(before["grid"], [center])
	if tick["type"] != "ember_tick" or tick["hp"] <= 0 or event["id"] != tick["id"] or event["tile"] != center or event["before"]["enemies"][0]["hp"] > 0 or after["enemies"][0]["hp"] > 0:
		failures.append("The live Ember Tick must be killed before its Burst")
	if cross.size() != 5 or not _same_members(event["tiles"], cross):
		failures.append("The death Burst must hit its center and all four orthogonal neighbors")
	var neighbor: Vector2i = before["enemies"][1]["pos"]
	var diagonal: Vector2i = before["enemies"][2]["pos"] - center
	if Paths.manhattan(center, neighbor) != 1 or Paths.manhattan(center, before["player"]["pos"]) != 1 or diagonal.abs() != Vector2i.ONE:
		failures.append("The hero and one Crawler must be adjacent, with the other Crawler on a diagonal")
	var loss: int = int(event["damage"])
	var burst_losses: Dictionary = _health_losses(event["before"], event["after"])
	var total_losses: Dictionary = _health_losses(before, after)
	if loss <= 0 or burst_losses.size() != 2 or burst_losses.get("player") != loss or burst_losses.get(_enemy_key(before, 1)) != loss or total_losses.has(_enemy_key(before, 2)):
		failures.append("The Burst must damage both adjacent units and leave the diagonal Crawler's Health unchanged")
	if not before["surfaces"].is_empty() or not _same_members(Surfaces.tiles(after), [center]) or not Surfaces.has_surface(after, center, "fire"):
		failures.append("The death Burst must leave only Fire on its source tile")

static func _validate_discharge(before: Dictionary, after: Dictionary, action: Dictionary, network: Array, failures: Array[String]) -> void:
	var discharges: Array[Dictionary] = CardChecks.events(before, after, "surface_discharge")
	var bursts: Array[Dictionary] = CardChecks.events(before, after, "detonate")
	if before["enemies"].size() != 1 or discharges.size() != 1 or bursts.size() != 1:
		failures.append("Discharge must record one connected-network Burst with a single enemy witness")
		return
	var area: Array = _expected_area(before["grid"], network)
	if not _same_members(Surfaces.tiles(before), network) or not _same_members(Surfaces.tiles(before, "electrified"), network) or not after["surfaces"].is_empty():
		failures.append("Discharge must consume the entire Electrified network in one action")
	if not _same_members(discharges[0]["tiles"], network) or not _same_members(discharges[0]["area"], area) or not _same_members(bursts[0]["burst_tiles"], area):
		failures.append("Discharge must Burst the union of the connected tiles' crosses")
	if not network.has(before["enemies"][0]["pos"]) or not area.has(before["player"]["pos"]):
		failures.append("The enemy must be on the Electrified network and the hero on or next to it")
	var loss: int = int(action["damage"])
	var enemy_key: String = _enemy_key(before, 0)
	var losses: Dictionary = _health_losses(before, after)
	if loss <= 0 or losses.get("player") != loss or losses.get(enemy_key) != loss or not _same_members(bursts[0]["actor_keys"], ["player", enemy_key]):
		failures.append("Discharge must hit both the hero and the enemy once for the card's damage")

static func _expected_area(grid: Array, sources: Array) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			var tile := Vector2i(x, y)
			if sources.any(func(source: Vector2i) -> bool: return Paths.manhattan(source, tile) <= 1):
				tiles.append(tile)
	return tiles

static func _same_members(actual: Array, expected: Array) -> bool:
	return actual.size() == expected.size() and expected.all(func(value: Variant) -> bool: return actual.has(value))

static func _enemy_key(state: Dictionary, index: int) -> String:
	return "enemy_%d" % state["enemies"][index]["id"]

static func _health_losses(before: Dictionary, after: Dictionary) -> Dictionary:
	var losses: Dictionary = {}
	var hero_loss: int = int(before["player"]["hp"]) - int(after["player"]["hp"])
	if hero_loss != 0: losses["player"] = hero_loss
	for index: int in range(before["enemies"].size()):
		var loss: int = int(before["enemies"][index]["hp"]) - int(after["enemies"][index]["hp"])
		if loss != 0: losses[_enemy_key(before, index)] = loss
	return losses

func observe(board: Control, fixture: Dictionary, result: Dictionary, frame: int) -> void:
	var is_tick: bool = fixture["id"] == EMBER_TICK
	var after: Dictionary = result["final"]
	var before: Dictionary = fixture["state"]
	var losses: Dictionary = _health_losses(before, after)
	var effects: Array = board.presentation.get("burst_effects", [])
	if is_tick:
		var expected: Array = after["death_burst_events"][0]["tiles"]
		for effect: Dictionary in effects:
			var tiles: Array = effect["tiles"]
			if not _same_members(tiles, expected): _wrong_footprint = true
			for tile: Vector2i in tiles: _effect_tiles[tile] = true
	else:
		for event: Dictionary in board.presentation.get("surface_feedback_events", []):
			if event.get("break_surface") == "electrified": _effect_tiles[event["tile"]] = true
	var labels: Dictionary = {}
	for entry: Dictionary in board.presentation.get("floating_texts", []):
		if float(entry.get("alpha", 1.0)) <= 0.0: continue
		var key: String = str(entry.get("reaction_actor_key", ""))
		var label: String = "%s:%s" % [key, Board.audit_number_label(entry)]
		labels[label] = true
		_numbers[label] = true
	var enemy_key: String = _enemy_key(before, 1 if is_tick else 0)
	if impact_frame < 0 and labels.has("player:-%d" % losses["player"]) and labels.has("%s:-%d" % [enemy_key, losses[enemy_key]]):
		if is_tick and effects.is_empty(): return
		impact_frame = frame
		if is_tick:
			var diagonal_key: String = _enemy_key(before, 2)
			_diagonal_visible = board._visible_units().any(func(unit: Dictionary) -> bool: return unit["key"] == diagonal_key)

func finish(fixture: Dictionary, result: Dictionary, failures: Array[String]) -> Dictionary:
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	var is_tick: bool = fixture["id"] == EMBER_TICK
	var event: Dictionary = after["death_burst_events"][0] if is_tick else CardChecks.events(before, after, "surface_discharge")[0]
	if _wrong_footprint or not _same_members(_effect_tiles.keys(), event["tiles"]):
		failures.append("%s did not submit its recorded Burst or ground removal footprint" % fixture["id"])
	if impact_frame < 0:
		failures.append("%s must show both real Burst damage numbers in the same impact frame" % fixture["id"])
	var receipt: Dictionary = {
		"affected_tiles": event["tiles"] if is_tick else event["area"],
		"effect_tiles": _effect_tiles.keys(), "health_losses": _health_losses(before, after),
		"seen_numbers": _numbers.keys(), "impact_frame": impact_frame,
	}
	if is_tick:
		var diagonal_key: String = _enemy_key(before, 2)
		if not _diagonal_visible or _numbers.keys().any(func(label: String) -> bool: return label.begins_with(diagonal_key + ":")):
			failures.append("The diagonal Crawler must be visible at impact without a damage number")
		receipt["diagonal_visible_at_impact"] = _diagonal_visible
		receipt["diagonal_tile"] = before["enemies"][2]["pos"]
		receipt["burst_health_losses"] = _health_losses(event["before"], event["after"])
	else:
		receipt["network_tiles"] = event["tiles"]
	return receipt
