extends SceneTree

## occ-02 proof: real certified fights, native cel look, 1920x1080, 100% UI.
## --survey prints every floor tile's reveal occluders (headless is fine).
## Stills: --case front (a: hero in front of a crate/foe tile, plus c: aiming)
## and --case pillar (b: a pillar hiding a move-range tile). --case sweep (d)
## steps the production fade at a fixed 1/30 s per captured frame.
const Real = preload("res://tools/ptf09/real_fixture.gd")
const Fixture = preload("res://tools/rd02/fixture.gd")
const Reveal = preload("res://scripts/board_occlusion_reveal.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const SIZE := Vector2i(1920, 1080)
const SETTLE_LIMIT: int = 120
const STRIP_DELTA: float = 1.0 / 30.0 # Proof-only fixed step, like a 30 fps movie.
const STRIP_FRAMES_PER_TILE: int = 4
var failures: Array[String]
var samples: Array[Dictionary]
var check_only: bool = false
var survey: bool = false
var case_name: String = "front"
var manifest_path: String = ""
var output: String = "/private/tmp/labyrinth_codex/occ-02/stills"
var tiles_arg: Array[Vector2i]
var scene: Node
var board: Control
var reveal: Node
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	check_only = args.has("--check-only")
	survey = args.has("--survey")
	if args.has("--case"): case_name = args[args.find("--case") + 1]
	if args.has("--manifest"): manifest_path = args[args.find("--manifest") + 1]
	if args.has("--output-dir"): output = args[args.find("--output-dir") + 1]
	if args.has("--tiles"):
		for part: String in args[args.find("--tiles") + 1].split(";"):
			var xy: PackedStringArray = part.split(",")
			tiles_arg.append(Vector2i(int(xy[0]), int(xy[1])))
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not (check_only or survey):
		push_error("Native capture needs the real renderer")
		quit(1)
		return
	Fixture.install_manifest(manifest_path)
	canvas = Real.make_canvas(self)
	scene = Real.resume(self, canvas)
	for frame: int in range(Fixture.SETTLE_FRAMES): await process_frame
	board = scene.get("board_view")
	reveal = board.get("_occlusion_reveal")
	_check(str(scene.get("_run_state").get("mode", "")) == "combat", "Real combat resume")
	_check(is_equal_approx(Typography.ui_scale(scene), 1.0), "Actual UI scale is 100%")
	_check(is_instance_valid(reveal), "Board owns the focus reveal")
	DirAccess.make_dir_recursive_absolute(output)
	if survey: _survey()
	else:
		match case_name:
			"front": await _front_case()
			"pillar": await _pillar_case()
			"sweep": await _sweep_case()
			_: _check(false, "Unknown case " + case_name)
	var file := FileAccess.open(output.path_join("semantics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"real_game": true, "case": case_name, "manifest": manifest_path, "size": [SIZE.x, SIZE.y], "ui_scale": 1.0,
		"cel_look": OS.get_environment("LABYRINTH_CEL_LOOK"), "samples": samples, "failures": failures}, "\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print(output)
	print("OCC02 CAPTURE: %s (%s, %d samples)" % ["PASS" if failures.is_empty() else "FAIL", "survey" if survey else case_name, samples.size()])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _state() -> Dictionary:
	return scene.get("_combat_state")

func _occupant(tile: Vector2i) -> String:
	for unit: Dictionary in board.call("_visible_units"):
		if (board.call("_unit_footprint_tiles", unit) as Array).has(tile): return "unit:" + str(unit.get("key", ""))
	for terrain: Dictionary in _state().get("terrain", []):
		if terrain.get("pos") == tile: return "terrain:" + str(terrain.get("kind", ""))
	return ""

func _survey() -> void:
	var grid: Array = _state().get("grid", [])
	for y: int in range(grid.size()):
		var row: PackedStringArray = []
		for x: int in range(grid[y].size()):
			var id: String = board.call("_display_tile_id", str(grid[y][x]), Vector2i(x, y))
			var occupant: String = _occupant(Vector2i(x, y))
			row.append("%-6s" % (id.substr(0, 3) + ("*" if not occupant.is_empty() else "")))
		print("OCC02 GRID %2d: %s" % [y, " ".join(row)])
	var moves: Array = scene.get("_combat_engine").call("player_movement_targets", _state())
	print("OCC02 MOVES: ", moves)
	var texture: Texture2D = (board.get("_prop_textures") as Dictionary).get("pillar")
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		if texture == null or not board.call("_tile_renders_as_pillar", grid, tile): continue
		var rect: Rect2 = board.call("_prop_draw_rect", texture, board.call("_prop_rect_for_tile", tile))
		print("OCC02 PILLAR %s rest shaft alpha %.2f" % [str(tile), (board.call("_foreground_blocker_tint_uncached", "pillar", tile, rect, board.get("_foreground_obstruction_entries_cache")) as Color).a])
	var slowest: int = 0
	var total: int = 0
	var count: int = 0
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		var started: int = Time.get_ticks_usec()
		var found: Dictionary = reveal.occluders_for(tile)
		var spent: int = Time.get_ticks_usec() - started
		slowest = maxi(slowest, spent)
		total += spent
		count += 1
		if found.is_empty(): continue
		var parts: PackedStringArray = []
		for id: String in found: parts.append("%s %.2f" % [id, float(found[id]["coverage"])])
		print("OCC02 TILE %s [%s]%s: %s" % [str(tile), _occupant(tile), " move" if moves.has(tile) else "", ", ".join(parts)])
		samples.append({"tile": tile, "occupant": _occupant(tile), "move": moves.has(tile), "occluders": found.keys()})
	print("OCC02 COVERAGE COST: %d tiles, mean %d us, max %d us (cold, per focus change)" % [count, total / maxi(1, count), slowest])

func _point_for(tile: Vector2i) -> Vector2:
	return board.call("_tile_center", tile)

# A board point beside every tile: the pointer is on the board, focusing none.
func _empty_point() -> Vector2:
	var bounds := Rect2(board.call("_tile_center", Vector2i.ZERO), Vector2.ZERO)
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		for corner: Vector2 in board.call("_tile_polygon", tile): bounds = bounds.expand(corner)
	var point := Vector2(bounds.get_center().x, bounds.position.y - 40.0)
	_check(board.call("_tile_at_point", point) == Vector2i(-1, -1), "Rest pointer is off every tile")
	return point

func _hover(tile: Vector2i) -> void:
	Real.pointer(self, board, _point_for(tile) if tile.x >= 0 else _empty_point())
	await process_frame
	_check(tile.x < 0 or board.get("_hover_tile") == tile, "Pointer hover reaches %s" % str(tile))

func _settled() -> bool:
	for id: String in reveal.targets:
		var target: Dictionary = reveal.targets[id]
		if float(target["progress"]) != (1.0 if bool(target["on"]) else 0.0): return false
	return true

func _settle() -> void:
	for frame: int in range(SETTLE_LIMIT):
		await process_frame
		if _settled() and not reveal.is_processing(): break
	for frame: int in range(4): await process_frame
	_check(_settled() and not reveal.is_processing(), "Reveal settles and stops processing")

func _sprite_alpha(key: String) -> float:
	var result: float = -1.0
	for record: Dictionary in (board.get("_aim_focus") as RefCounted).get("canvases").values():
		if bool(record.hud) or str(record.unit.get("key", "")) != key or not is_instance_valid(record.canvas): continue
		result = (record.canvas as Control).modulate.a
	return result

func _team_alpha(key: String) -> float:
	var team: Dictionary = board.get("_occlusion_silhouettes").get("team").get("entries")
	return float(team[key].get("base_alpha", -1.0)) if team.has(key) else -1.0

func _record(label: String, focus: Vector2i) -> Dictionary:
	var units: Dictionary = {}
	for unit: Dictionary in board.call("_visible_units"):
		var key: String = str(unit.get("key", ""))
		units[key] = {"pos": unit.get("pos"), "sprite_alpha": _sprite_alpha(key), "team_rim_alpha": _team_alpha(key)}
	var faded: Dictionary = {}
	for id: String in reveal.targets: faded[id] = reveal.targets[id]["progress"]
	var entry: Dictionary = {"name": label, "focus": focus, "reveal_focus": reveal.focus_tile, "occupant": _occupant(focus) if focus.x >= 0 else "",
		"faded": faded, "units": units, "coverage_builds": reveal.coverage_builds, "reveal_processing": reveal.is_processing(),
		"scene_tile_draw_counts": board.call("render_instrumentation_snapshot").get("scene_tile_draw_counts", {})}
	samples.append(entry)
	return entry

func _still(label: String, focus: Vector2i) -> Dictionary:
	var entry: Dictionary = _record(label, focus)
	if check_only:
		await process_frame
		return entry
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_check(image.get_size() == SIZE and image.save_png(output.path_join(label + ".png")) == OK, "1920x1080 capture " + label)
	return entry

# The first requested tile, else the first tile matching the predicate.
func _pick(index: int, predicate: Callable) -> Vector2i:
	if tiles_arg.size() > index: return tiles_arg[index]
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		if predicate.call(tile, reveal.occluders_for(tile)): return tile
	return Vector2i(-1, -1)

func _expect_faded(entry: Dictionary, focus: Vector2i, ids: Array) -> void:
	var name: String = entry["name"]
	for id: String in ids:
		_check(is_equal_approx(float((entry["faded"] as Dictionary).get(id, 0.0)), 1.0), "%s: %s fully revealed" % [name, id])
		if id.begins_with("unit:"):
			var key: String = id.trim_prefix("unit:")
			_check(is_equal_approx(float(entry["units"][key]["sprite_alpha"]), Reveal.REVEAL_ALPHA), "%s: %s body at 30%%" % [name, key])
	var own: String = _occupant(focus)
	if own.begins_with("unit:"):
		_check(is_equal_approx(float(entry["units"][own.trim_prefix("unit:")]["sprite_alpha"]), 1.0), "%s: focus tile's own unit stays opaque" % name)
	for id: String in entry["faded"]:
		_check(ids.has(id), "%s: only occluders of the focus tile fade (%s)" % [name, id])

func _front_case() -> void:
	# a) hero in front of a tile that holds a foe or terrain.
	var hero_tile: Vector2i = _pick(0, func(tile: Vector2i, found: Dictionary) -> bool:
		return found.has("unit:player") and not _occupant(tile).is_empty())
	_check(hero_tile.x >= 0, "Fixture has a foe/terrain tile behind the hero")
	print("OCC02 FRONT TILE ", hero_tile, " ", _occupant(hero_tile), " ", reveal.occluders_for(hero_tile).keys())
	await _settle()
	var rest: Dictionary = await _still("a1_rest", Vector2i(-1, -1))
	_check((rest["faded"] as Dictionary).is_empty(), "Rest: nothing faded")
	await _hover(hero_tile)
	_check(not (reveal.targets as Dictionary).is_empty() and reveal.is_processing(), "Fade starts on the hover frame, with no rest delay")
	await _settle()
	_expect_faded(await _still("a2_hover_behind_hero", hero_tile), hero_tile, reveal.occluders_for(hero_tile).keys())
	await _hover(Vector2i(-1, -1))
	await _settle()
	_check((await _still("a3_pointer_off_tiles", Vector2i(-1, -1)))["faded"].is_empty(), "Leaving the tiles ends the reveal")
	# c) aiming a card at a tile partly hidden by a unit.
	var aim_tile: Vector2i = _pick(1, func(tile: Vector2i, found: Dictionary) -> bool:
		for id: String in found:
			if id.begins_with("unit:") and id != "unit:player": return true
		return false)
	_check(aim_tile.x >= 0, "Fixture has a tile partly hidden by a foe")
	var card: int = _ranged_card()
	_check(card >= 0, "Hand has a targeted card")
	await scene.call("_on_card_pressed", card)
	await _settle()
	await _still("c1_aiming_rest", Vector2i(-1, -1))
	await _hover(aim_tile)
	await _settle()
	var highlight: Node2D = board.get("_targeted_tile_highlight")
	_check(is_instance_valid(highlight) and highlight.visible and highlight.get("tile") == aim_tile, "Aimed tile shows the target border")
	_expect_faded(await _still("c2_aiming_hidden_tile", aim_tile), aim_tile, reveal.occluders_for(aim_tile).keys())
	await scene.call("_on_cancel_requested")

func _ranged_card() -> int:
	var hand: Array = (_state().get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		var card: Dictionary = hand[index] if hand[index] is Dictionary else {}
		var id: String = str(card.get("card_id", card.get("id", hand[index])))
		if id in ["pale_spark", "lantern_shot"]: return index
	return 0 if not hand.is_empty() else -1

func _pillar_case() -> void:
	scene.call("_begin_player_movement_selection")
	await _settle()
	var moves: Array = scene.get("_player_movement_target_tiles")
	var tile: Vector2i = _pick(0, func(candidate: Vector2i, found: Dictionary) -> bool:
		if not moves.has(candidate): return false
		for id: String in found:
			if id.begins_with("pillar:"): return true
		return false)
	_check(tile.x >= 0 and moves.has(tile), "A pillar hides a move-range tile")
	print("OCC02 PILLAR TILE ", tile, " ", reveal.occluders_for(tile).keys())
	var rest: Dictionary = await _still("b1_move_range_rest", Vector2i(-1, -1))
	_check((rest["faded"] as Dictionary).is_empty(), "Rest: nothing faded")
	await _hover(tile)
	await _settle()
	_expect_faded(await _still("b2_hover_behind_pillar", tile), tile, reveal.occluders_for(tile).keys())

func _sweep_case() -> void:
	var tiles: Array[Vector2i] = []
	tiles.assign(tiles_arg)
	_check(tiles.size() == 3, "Sweep needs three tiles (--tiles x,y;x,y;x,y)")
	if OS.get_cmdline_user_args().has("--move"): scene.call("_begin_player_movement_selection")
	await _settle()
	await _still("d_rest", Vector2i(-1, -1))
	# Fixed proof clock: the production _process stepped at 1/30 s per frame.
	reveal.process_mode = Node.PROCESS_MODE_DISABLED
	var frame: int = 0
	var previous: Dictionary = {}
	for tile: Vector2i in tiles:
		await _hover(tile)
		for step: int in range(STRIP_FRAMES_PER_TILE):
			reveal._process(STRIP_DELTA)
			var entry: Dictionary = await _still("d_%02d" % frame, tile)
			entry["time"] = frame * STRIP_DELTA
			for id: String in previous:
				var now: float = float((entry["faded"] as Dictionary).get(id, 0.0))
				var wanted: bool = reveal.occluders_for(tile).has(id)
				# No flicker: each occluder moves monotonically toward its goal.
				_check(now >= float(previous[id]) if wanted else now <= float(previous[id]), "Frame %d: %s moves monotonically" % [frame, id])
			previous = entry["faded"]
			frame += 1
	for step: int in range(2):
		reveal._process(STRIP_DELTA)
		await _still("d_%02d" % frame, tiles[-1])
		frame += 1
	reveal.process_mode = Node.PROCESS_MODE_INHERIT
