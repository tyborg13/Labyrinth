extends SceneTree
## Sample two adjacent outlines and the hero fill from live canvases.

const Board = preload("res://scripts/combat_board_view.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Fixtures = preload("res://tests/suites/threats_at_rest_suite.gd")
const Observe = preload("observe.gd")
const Trace = preload("trace.gd")
const SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES := 4
const PULSE_SAMPLE_MS := 1000
const MIN_PULSE_RANGE := 0.01
const MIN_SAMPLE_COUNT := 3
const TARGET_OFFSET := Vector2i.RIGHT

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	Runtime.apply_from_environment()
	root.size = SIZE
	root.content_scale_size = SIZE
	Engine.max_fps = 60
	var board := Board.new()
	board.size = Vector2(SIZE)
	root.add_child(board)
	var state: Dictionary = Fixtures.staged_state(Fixtures.Combat.new())
	var hero: Vector2i = state["player"]["pos"]
	var neighbor: Vector2i = hero + TARGET_OFFSET
	var presentation: Dictionary = {
		"board_targeting": true,
		"threats_at_rest": {"hero_tile": hero,
			"threats": [{"key": "enemy_1", "tiles": [hero, neighbor], "alpha": 1.0}]},
	}
	_present(board, state, presentation)
	var context: Dictionary = {
		"active": true, "targets": [neighbor], "attack": true,
		"colors": {"attack": Trace.Palette.DANGER_BRIGHT},
	}
	board.set_targeted_tile_context(context, neighbor)
	await _settle()
	var commands: Dictionary = Trace.snapshot(board)
	var border: Node2D = board.get("_targeted_tile_highlight")
	var targeted: Node2D = board.get("_targeted_tile_threat")
	if not _target_above_border(border, targeted, commands.get(neighbor, {})):
		_fail("targeted border and red line were not submitted in sibling order")
		return
	var tiles: Array[Dictionary]
	for tile: Vector2i in [hero, neighbor]:
		var row: Dictionary = commands.get(tile, {})
		if row.get("strokes", []).is_empty():
			_fail("no live outline at %s" % tile)
			return
		row["diamond"] = Observe.points(board.get_global_transform_with_canvas() * board._tile_polygon(tile))
		tiles.append(row)
	if tiles[0]["strokes"].back()["canvas"] == str(targeted.name):
		_fail("fixture must cover the retained path and the targeted sibling")
		return
	var moving: Dictionary = await _pulse_samples(board, hero, false)
	presentation["reduced_motion"] = true
	_present(board, state, presentation)
	await _settle()
	var steady: Dictionary = await _pulse_samples(board, hero, true)
	board.free()
	if moving["count"] < MIN_SAMPLE_COUNT or float(moving["range"]) < MIN_PULSE_RANGE or steady["count"] < MIN_SAMPLE_COUNT or not is_zero_approx(float(steady["range"])):
		_fail("hero fill varied incorrectly: %s reduced=%s" % [moving, steady])
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		_fail("cannot write the live fixture trace")
		return
	file.store_string(JSON.stringify({"tiles": tiles, "pulse": moving, "reduced_motion": steady,
		"targeting": {"border_index": border_index, "outline_index": outline_index}}))
	print("FEL32 HERO PULSE range=%.4f reduced_motion_range=%.4f PASS" % [moving["range"], steady["range"]])
	print("FEL32 TARGET ABOVE BORDER border_index=%d outline_index=%d PASS" % [border_index, outline_index])
	quit()


var border_index: int
var outline_index: int

func _target_above_border(border: Node2D, targeted: Node2D, row: Dictionary) -> bool:
	if not border.is_visible_in_tree() or not targeted.is_visible_in_tree() or not border.has_meta(Trace.BORDER):
		return false
	border_index = border.get_index()
	outline_index = targeted.get_index()
	var strokes: Array = row.get("strokes", [])
	return border.get_parent() == targeted.get_parent() and border.z_index == targeted.z_index 		and not targeted.show_behind_parent and outline_index == border_index + 1 		and not strokes.is_empty() and strokes.back()["canvas"] == str(targeted.name)


func _present(board: Control, state: Dictionary, shown: Dictionary) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown.duplicate(true))


func _pulse_samples(board: Control, tile: Vector2i, force_repaint: bool) -> Dictionary:
	var low: float = INF
	var high: float = -INF
	var count: int = 0
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < PULSE_SAMPLE_MS:
		if force_repaint:
			var overlays: Control = board._overlay_render_layer
			overlays.queue_redraw()
			for canvas: Control in overlays._layer_slices.canvases: canvas.queue_redraw()
		await process_frame
		var row: Dictionary = Trace.snapshot(board).get(tile, {})
		if not row.has("fill"): continue
		var alpha: float = row["fill"][3]
		low = minf(low, alpha)
		high = maxf(high, alpha)
		count += 1
	return {"range": high - low, "count": count}


func _settle() -> void:
	for frame: int in SETTLE_FRAMES: await process_frame


func _fail(message: String) -> void:
	push_error("FEL32 FIXTURE: " + message)
	quit(1)
