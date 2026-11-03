extends RefCounted

## Headless ordering oracle. Ground depth comparisons are independent of
## production's segment projection. Native crops: depth_probe.gd.
const Board = preload("res://scripts/combat_board_view.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tools/warband_inspection.gd")
const Library = preload("res://scripts/special_encounter_library.gd")
const Types = preload("timing.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Death = preload("res://scripts/maquette_cutout_runtime/death.gd")
const Rules = preload("res://scripts/warband_combat_rules.gd")
const PROOF_SIZE := Vector2(1920, 1080)
const PROOF_PLAYER_HP: int = 40
const GROUND_ROUNDOFF_PIXELS: float = 0.001
const DIRECTIONS := [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1), Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)]

static func run() -> Dictionary:
	var board := Board.new()
	board.size = PROOF_SIZE
	var report: Dictionary = {"boards": [], "frames": 0, "errors": [], "findings": [], "legacy_rejected_frames": 0, "keep_distance_paths": 0, "native_pixels": false}
	for revision: int in [6, 7]:
		for biome: String in Library.definition("warband")["variants"]:
			for tier: int in [1, 2, 3]:
				var spec: Dictionary = Fixture.room_spec(biome, tier)
				spec["section_map_layout_revision"] = revision
				var layout: Dictionary = Rooms.new().generate_room(Fixture.FIXTURE_SEED, spec, Vector2i.UP)
				var battle: Dictionary = Combat.new().create_combat(Fixture.FIXTURE_SEED, layout, {"hp":PROOF_PLAYER_HP,"max_hp":PROOF_PLAYER_HP})
				board.combat_state = battle
				board._board_layout_cache_valid = false
				var label: String = "%s_t%d_r%d" % [biome, tier, revision]
				report["boards"].append(label)
				var origin: Vector2i = battle["enemies"][0]["pos"]
				# Include the actual captain retreat route produced by keep_distance.
				if Fixture.stage_keep_distance(battle):
					var retreat: Array[Vector2i] = Rules.retreat_path(Combat.new(), battle, battle["enemies"][0])
					if not retreat.is_empty(): report["keep_distance_paths"] += 1
					for index: int in range(1, retreat.size()):
						_sweep(board, report, label, str(battle["enemies"][0]["type"]), retreat[index-1], retreat[index], "keep_distance")
				for type: String in Types.TYPES:
					for direction: Vector2i in DIRECTIONS:
						_sweep(board, report, label, type, origin, origin + direction, "move")
					# A stationary death must retain its board depth at every phase.
					for frame: int in range(Death.frames(type)):
						var unit: Dictionary = {"key":"enemy_1", "id":1, "type":type, "pos":origin, "death_animation":true, "death_progress":float(frame)/maxi(1,Death.frames(type)-1)}
						board.presentation = {"death_animation_units":[unit]}
						if board._effective_unit_tile(unit) != origin: report["errors"].append(label+"/"+type+"/death/"+str(frame))
						report["frames"] += 1
	board.free()
	return report

static func _sweep(board: Control, report: Dictionary, label: String, type: String, from: Vector2i, to: Vector2i, clip: String) -> void:
	if type not in Types.TYPES: return
	var unit: Dictionary = {"key":"enemy_1", "id":1, "type":type, "pos":from}
	var start: Vector2 = board.world_position_for_tile(from)
	var end: Vector2 = board.world_position_for_tile(to)
	var failed_frames: Array[int]
	var count: int = Action.frames_for(type, "move")
	var representative: Dictionary = {}
	# RunScene submits phases 1/count through 1, never a t=0 travel frame.
	for frame: int in range(1, count + 1):
		var phase: float = float(frame) / count
		var ground: Vector2 = start.lerp(end, phase)
		board.presentation = {"unit_draw_tiles":{"enemy_1":to}, "unit_footprint_world_positions":{"enemy_1":ground}, "unit_world_positions":{"enemy_1":ground}}
		# The resolved path gives an independent tile-space oracle, without
		# calling production's inverse or its depth helper.
		var expected: Vector2i = expected_host(board,from,to,ground,start,end)
		var actual: Vector2i = board._effective_unit_tile(unit)
		if actual != expected:
			report["errors"].append({"board":label,"actor":type,"clip":clip,"frame":frame,"expected":str(expected),"actual":str(actual)})
		if to != expected:
			failed_frames.append(frame)
			report["legacy_rejected_frames"] += 1
			if representative.is_empty():
				var rect: Rect2 = board._unit_draw_rect_for_center(unit, ground)
				representative = {"board":label,"actor":type,"clip":clip,"frame":frame,"phase":phase,"from":[from.x,from.y],"to":[to.x,to.y],"expected_tile":[expected.x,expected.y],"legacy_tile":[to.x,to.y],"crop_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"kind":"destination depth differs from occupied floor tile","crop":label+"_"+type+"_"+clip+"_"+str(to.x-from.x)+"_"+str(to.y-from.y)+".png"}
		report["frames"] += 1
	if not representative.is_empty():
		representative["failed_frames"] = failed_frames
		report["findings"].append(representative)

static func expected_host(board: Control, from: Vector2i, to: Vector2i, ground: Vector2, start: Vector2, end: Vector2) -> Vector2i:
	# Compare ground depths directly by a linear reference walk, independent
	# of production's binary search and segment dot product. No lattice inverse
	# or independent coordinate rounding participates in this oracle.
	var midpoint: Vector2 = start.lerp(end,0.5)
	if start.y==end.y:
		if absf(ground.x-midpoint.x)<GROUND_ROUNDOFF_PIXELS: return from
		return to if (ground.x>midpoint.x)==(end.x>start.x) else from
	if ground.distance_to(end)<GROUND_ROUNDOFF_PIXELS: return to
	var expected: Vector2i = from
	for tile: Vector2i in board._rendered_tiles_in_draw_order():
		var centre: Vector2 = board.world_position_for_tile(tile)
		if centre.y>ground.y or (centre.y==ground.y and centre.x>ground.x): break
		expected=tile
	return expected
