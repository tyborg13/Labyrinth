extends RefCounted
## Verify the same states and submitted effects the recorder will capture.
const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const IllusionRules = preload("res://scripts/illusion_card_rules.gd")
const TerrainRules = preload("res://scripts/terrain_card_rules.gd")
const PULSE_DAMAGE: int = 3 # Requirement witness, never supplied to the resolver.
var _first_effect_by_tile: Dictionary = {}
var _saw_swap: bool = false
var _saw_all_spires: bool = false
var _last_motion_frame: int = -1
var max_idle_frames: int = 0

static func events(before: Dictionary, after: Dictionary, kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary]
	var since: int = int(before.get("surface_event_sequence", 0))
	for event: Dictionary in after.get("surface_events", []):
		if int(event.get("sequence", 0)) > since and event["kind"] == kind: found.append(event)
	return found

static func validate(fixture: Dictionary, result: Dictionary, setup: Script) -> Array[String]:
	var failures: Array[String]
	var id: String = fixture["id"]
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	var beats: Array = result["beats"]
	if beats.size() != (2 if id == setup.WORLDSPINE else 1):
		failures.append(id + ": the production action or turn-start beat could not resolve")
		return failures
	var action: Dictionary = beats[0]["action"]
	for enemy: Dictionary in before["enemies"]:
		var hp: int = Data.enemy_def(enemy["type"])["max_hp"]
		if enemy["hp"] != hp or enemy["max_hp"] != hp: failures.append(id + ": enemy Health must come from its definition")
	match id:
		setup.DETONATE:
			var blasts: Array[Dictionary] = events(before, after, "detonate")
			var centers: Array = blasts[0]["consumed"] if blasts.size() == 1 else []
			if not _same_tiles(centers, setup.FIRE_TILES) or not Surfaces.tiles(after, "fire").is_empty():
				failures.append("Detonate must consume both Fire tiles in one action")
			if _touches(centers, setup.OVERLAP_ENEMY) != 2 or _touches(centers, setup.SINGLE_ENEMY) != 1:
				failures.append("Detonate needs one overlap victim and one single-blast victim")
			if not _enemies_lost(before, after, int(action["damage"])) or after["player"]["hp"] != before["player"]["hp"]:
				failures.append("Detonate must hit each enemy once with the printed damage")
		setup.DISCHARGE:
			var engine := Combat.new()
			var discharges: Array[Dictionary] = events(before, after, "surface_discharge")
			if engine.is_tile_visible_to_player(before, setup.BRIDGE) or not engine.is_tile_visible_to_player(before, setup.TAIL):
				failures.append("Discharge must show a visible Electrified tail separated by a dark bridge")
			if discharges.size() != 1 or not _same_tiles(discharges[0]["tiles"], setup.NETWORK):
				failures.append("Discharge must use the three visible connected tiles")
			if not _same_tiles(Surfaces.tiles(after, "electrified"), [setup.BRIDGE, setup.TAIL]):
				failures.append("Discharge must leave the bridge and disconnected visible tail intact")
			if not _enemies_lost(before, after, int(action["damage"])) or Surfaces.has_surface(before, setup.BESIDE_NETWORK, "electrified") or not Surfaces.has_surface(before, setup.ON_NETWORK, "electrified"):
				failures.append("Discharge must hit one enemy on the network and one beside it, once each")
		setup.SWAP:
			var swaps: Array[Dictionary] = events(before, after, IllusionRules.SWAP_EVENT)
			var arrival: Array[Dictionary] = events(before, after, "surface_damage")
			var fire: int = Data.fixed_point_amount(Surfaces.FIRE_ENTRY_DAMAGE)
			if before["illusions"].size() != 1 or after["illusions"].size() != 1 or swaps.size() != 1:
				failures.append("Swap must exchange the hero and one production illusion")
			elif after["player"]["pos"] != before["illusions"][0]["pos"] or after["illusions"][0]["pos"] != before["player"]["pos"]:
				failures.append("Both actors must land on the other actor's original tile")
			if arrival.size() != 1 or arrival[0].get("actor_kind") != "player" or arrival[0].get("surface") != "fire" or arrival[0].get("trigger") != "entry" or before["player"]["hp"] - after["player"]["hp"] != fire:
				failures.append("The hero must take the production Fire entry loss on landing")
		setup.WORLDSPINE:
			var raised: Dictionary = beats[0]["after"]
			var spines: Array[Dictionary] = TerrainRules.player_worldspines(Combat.new(), raised)
			var pulses: Array[Dictionary] = events(raised, after, TerrainRules.PULSE_EVENT)
			if not before["terrain"].is_empty() or spines.size() != action["pattern"].size() or not _enemies_lost(before, raised, 0):
				failures.append("Worldspine must raise every spire around the enemy before dealing damage")
			for spine: Dictionary in spines:
				if Paths.manhattan(spine["pos"], setup.CAGE_CENTER) != 1 or spine["hp"] != int(action["health"]):
					failures.append("Each spire must have its printed Health and border the enemy")
			if after["turn"] != raised["turn"] + 1 or pulses.size() != 1 or not _same_tiles(pulses[0]["enemy_ids"], [after["enemies"][0]["id"]]) or not _enemies_lost(raised, after, Data.fixed_point_amount(PULSE_DAMAGE)):
				failures.append("The next player turn must issue one Worldspine pulse and hit once for 3")
	return failures

static func _same_tiles(actual: Array, expected: Array) -> bool:
	return actual.size() == expected.size() and expected.all(func(tile: Variant) -> bool: return actual.has(tile))

static func _touches(centers: Array, tile: Vector2i) -> int:
	return centers.filter(func(center: Vector2i) -> bool: return Paths.manhattan(center, tile) <= 1).size()

static func _enemies_lost(before: Dictionary, after: Dictionary, damage: int) -> bool:
	for index: int in range(before["enemies"].size()):
		if before["enemies"][index]["hp"] - after["enemies"][index]["hp"] != damage: return false
	return true

func observe(board: Control, setup: Script, id: String) -> void:
	var motion_frame: int = board.last_visible_frame
	if motion_frame > _last_motion_frame:
		if _last_motion_frame >= 0:
			max_idle_frames = maxi(max_idle_frames, motion_frame - _last_motion_frame - 1)
		_last_motion_frame = motion_frame
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	if id == setup.DETONATE and bool(effect.get("ground_burst", false)):
		for tile: Vector2i in effect.get("burst_tiles", []): _first_effect_by_tile[tile] = true
	if id == setup.SWAP and effect.get("kind") == "blink":
		_saw_swap = true
	if id == setup.WORLDSPINE and board.combat_state.get("terrain", []).size() >= Paths.DIRS_4.size():
		_saw_all_spires = true
	for event: Dictionary in shown.get("surface_feedback_events", []):
		if id == setup.DISCHARGE and event.get("break_surface") == "electrified":
			_first_effect_by_tile[event["tile"]] = true
		if id == setup.WORLDSPINE and event.get("kind") == TerrainRules.PULSE_EVENT and event.get("feedback_element") == "earth":
			for tile: Vector2i in event["tiles"]: _first_effect_by_tile[tile] = _saw_all_spires

func finish(fixture: Dictionary, result: Dictionary, board: Control, setup: Script) -> Array[String]:
	var failures: Array[String]
	var id: String = fixture["id"]
	var expected: Array = []
	match id:
		setup.DETONATE: expected = setup.FIRE_TILES
		setup.DISCHARGE: expected = setup.NETWORK
		setup.SWAP:
			if not _saw_swap: failures.append("Swap must submit the production exchange effect")
		setup.WORLDSPINE:
			for event: Dictionary in events(result["beats"][0]["after"], result["final"], TerrainRules.PULSE_EVENT):
				expected = event["tiles"]
	for tile: Vector2i in expected:
		if not _first_effect_by_tile.get(tile, false): failures.append("%s must submit the effect at %s" % [id, tile])
	if id == setup.DISCHARGE and not _same_tiles(_first_effect_by_tile.keys(), expected):
		failures.append("Discharge must submit removal effects only on its connected visible L")
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	if id == setup.SWAP:
		if not board.seen_numbers.has("player:-%d" % (before["player"]["hp"] - after["player"]["hp"])):
			failures.append("Swap must show the hero's Fire entry loss")
	else:
		for index: int in range(before["enemies"].size()):
			var enemy: Dictionary = before["enemies"][index]
			var loss: int = int(enemy["hp"]) - int(after["enemies"][index]["hp"])
			if not board.seen_numbers.has("enemy_%d:-%d" % [enemy["id"], loss]):
				failures.append(id + " must show each enemy's real Health loss")
	return failures
