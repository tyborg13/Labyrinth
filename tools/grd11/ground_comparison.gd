extends SceneTree
## Matched crop driver shared by the approved and current project revisions.

const Board = preload("res://scripts/combat_board_view.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Fixture = preload("res://tools/grd07/fixture.gd")
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Gallery = Fixture.Gallery
const COLUMNS: PackedStringArray = ["fire", "ice", "rubble", "electrified", "merged"]
const LEGACY_NODES: PackedStringArray = ["SurfaceFire", "SurfaceIce", "SurfaceRubble", "SurfaceElectric", "SurfaceRubbleFloor"]
const LEGACY_BY_GROUND: Dictionary = {
	"fire": ["SurfaceFire"], "ice": ["SurfaceIce"], "rubble": ["SurfaceRubble"],
	"electrified": ["SurfaceElectric"], "stormcoal": ["SurfaceFire", "SurfaceElectric"],
	"merged": ["SurfaceFire", "SurfaceIce"],
}
const SAMPLE_SECONDS: float = 1.0
const SETTLE_FRAMES: int = 4
const CROP_ZOOM: int = 2
const EFFECT_PROGRESS: float = 0.25

var _view: SubViewport
var _output: String
var _dry: bool
var _sliced: bool
var _off: bool
var _check_draw_path: bool

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_dry = args.has("--dry-run")
	_sliced = args.has("--sliced")
	_off = args.has("--off")
	_check_draw_path = args.has("--check-draw-path")
	assert(_dry == (DisplayServer.get_name() == "headless"))
	assert(not _check_draw_path or _sliced)
	assert(Cel.mode == "all" and not Cel._files.is_empty())
	assert(OS.get_environment("LABYRINTH_GRD03_FIXTURE_ATLASES") != "1")
	for arg: String in args:
		if not arg.begins_with("--"):
			_output = arg
	assert(_output.is_absolute_path() and DirAccess.make_dir_recursive_absolute(_output) == OK)
	if _off:
		OS.set_environment("LABYRINTH_GROUND_FX", "off")
	elif not args.has("--default"):
		OS.set_environment("LABYRINTH_GROUND_FX", "pixel")
	else:
		OS.unset_environment("LABYRINTH_GROUND_FX")
	root.content_scale_factor = 1.0
	_view = Gallery.make_view(Fixture.SIZE, Fixture.SIZE, Viewport.MSAA_4X)
	root.add_child(_view)
	if not _dry:
		var preview := Sprite2D.new()
		preview.centered = false
		preview.texture = _view.get_texture()
		root.add_child(preview)
	var manifest: Dictionary = {}
	var columns: PackedStringArray = COLUMNS.duplicate()
	if _check_draw_path:
		columns.append("stormcoal")
	for kind: String in columns:
		for occupied: bool in [true, false]:
			if kind == "merged" and not occupied:
				continue
			var id: String = kind + ("-occupied" if occupied else "-empty")
			manifest[id] = await _capture(kind, occupied, id)
	var file := FileAccess.open(_output.path_join("crops.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	print(_output)
	print("GRD-11 GROUND CROPS %s: %d cases (%s, %s)" % ["DRY RUN" if _dry else "NATIVE", manifest.size(),
		"sliced" if _sliced else "unsliced", "off" if _off else "pixel"])
	if _check_draw_path:
		print("GRD-11 SLICE DRAW PATHS: PASS (%d cases, %s, previews, feedback and conduction submitted)" % [
			manifest.size(), "off override retains legacy ground" if _off else "pixel mode submits zero legacy ground"])
	quit()

func _capture(kind: String, occupied: bool, id: String) -> Dictionary:
	var column: int = Fixture.GROUNDS.find(kind)
	var state: Dictionary = Fixture.state_for(column)
	var row: int = 2 if kind == "merged" else 0
	var tile: Vector2i = Fixture.tile_at(column, row)
	if not occupied:
		state["player"]["pos"] = tile + Vector2i(3, 3)
	var board := Board.new()
	board.size = Vector2(Fixture.SIZE)
	board.process_mode = Node.PROCESS_MODE_DISABLED
	_view.add_child(board)
	Fixture.frame_room(board, state)
	var shown: Dictionary = {
		"biome_id": "stone", "board_framing_mode": "combat",
		"board_encounter_types": Array(Fixture.UNITS).slice(1),
		"ambient_time_seconds": SAMPLE_SECONDS, "umbra_time_seconds": SAMPLE_SECONDS,
	}
	if _sliced:
		shown["isolated_enemy_actor_keys"] = []
	Gallery.submit(board, state, shown)
	board.call("_queue_continuously_animated_scene_redraws")
	var ground: Node = board.get_node_or_null("PixelGround")
	assert((ground == null) == _off)
	if ground != null:
		assert(ground.field.tiles.has(tile))
		ground.set_process(false)
		if ground.has_method("set_motion_time"):
			ground.sync_contacts(board, false)
			ground.set_motion_time(SAMPLE_SECONDS)
		else:
			ground.sync_contacts(board)
	var footprint: Array[Vector2i] = Fixture.merged_tiles(column, row) if kind == "merged" else Gallery.tiles_in(Rect2i(tile, Vector2i.ONE))
	var crop: Rect2i = Fixture.crop_for(board, footprint)
	assert(Rect2i(Vector2i.ZERO, Fixture.SIZE).encloses(crop))
	var standing: bool = false
	for unit: Dictionary in board.call("_visible_units"):
		standing = standing or board.call("_unit_footprint_tiles", unit).has(tile)
	assert(standing == occupied)
	for frame: int in SETTLE_FRAMES:
		await process_frame
	var legacy: Dictionary = _legacy_nodes(board, kind)
	if not _dry:
		await RenderingServer.frame_post_draw
		var source: Image = _view.get_texture().get_image()
		assert(source.get_size() == Fixture.SIZE)
		assert(source.save_png(_output.path_join(id + ".png")) == OK)
		var image: Image = source.get_region(crop)
		image.resize(crop.size.x * CROP_ZOOM, crop.size.y * CROP_ZOOM, Image.INTERPOLATE_NEAREST)
		assert(image.save_png(_output.path_join(id + "-crop.png")) == OK)
	var record: Dictionary = {"tile": Fixture.xy(Vector2(tile)), "crop_px": Fixture.rect_pixels(Rect2(crop)), "legacy": legacy}
	if _check_draw_path:
		record["live_commands"] = await _check_slice_effects(board, state, shown, tile, kind)
	board.free()
	await process_frame
	return record

func _legacy_nodes(board: Control, kind: String) -> Dictionary:
	var counts: Dictionary = {}
	for name: String in LEGACY_NODES:
		var nodes: Array[Node] = board.find_children(name, "", true, false)
		counts[name] = 0
		if _check_draw_path and not _off:
			assert(nodes.is_empty(), "%s created legacy %s in pixel mode" % [kind, name])
		for node: Node in nodes:
			counts[name] += int((node as CanvasItem).is_visible_in_tree())
		if _check_draw_path and _off and name in LEGACY_BY_GROUND[kind]:
			assert(counts[name] > 0, "%s lost legacy %s with the flag unset" % [kind, name])
	return counts

func _check_slice_effects(board: Board, state: Dictionary, shown: Dictionary, tile: Vector2i, kind: String) -> Dictionary:
	var event: Dictionary = {"kind": "surface_created", "surface": Fixture.Ground.element_at(state, tile), "tile": tile}
	if event["surface"].is_empty():
		event["surface"] = "rubble"
	var path: Array[Vector2i] = [tile, tile + Vector2i.RIGHT]
	shown = shown.duplicate()
	shown["surface_feedback_events"] = [event]
	shown["surface_feedback_progress"] = EFFECT_PROGRESS
	shown["surface_preview_events"] = [event]
	shown["surface_preview_arcs"] = [{"path": path}]
	shown["effect"] = {"kind": "chain", "element": "lightning", "path": path}
	shown["effect_progress"] = EFFECT_PROGRESS
	Gallery.submit(board, state, shown)
	for frame: int in SETTLE_FRAMES:
		await process_frame
	_legacy_nodes(board, kind)
	var layer: Board = board._scene_render_layers_by_tile[tile]
	for slice: Board in layer._layer_slices.canvases:
		var ground: Pixel.Drawing = slice.get_node_or_null("SurfaceGround")
		if ground == null:
			continue
		assert(slice._is_layer_slice_canvas and slice._render_instrumentation_owner == board)
		assert(not slice._pixel_ground_enabled and slice._pixel_ground == null)
		var base: PackedStringArray = _command_names(ground)
		assert(base.has("draw_tile") == _off, "%s submitted unexpected persistent ground commands" % kind)
		assert(base.has("draw_preview") and base.has("_draw_surface_connection_on"))
		var live := PackedStringArray()
		var feedback: Node2D = slice.get_node("SurfaceFeedbackPixels")
		for node: Node in feedback.find_children("*", "Node2D", true, false):
			if node is Pixel.Drawing:
				live.append_array(_command_names(node))
		assert(live.has("draw_feedback") and live.has("_draw_surface_conduction_on"))
		return {"base": Array(base), "feedback": Array(live)}
	assert(false, "%s did not exercise a ground slice with live effects" % kind)
	return {}

static func _command_names(drawing: Pixel.Drawing) -> PackedStringArray:
	var names := PackedStringArray()
	for command: Dictionary in drawing.commands:
		names.append((command["draw"] as Callable).get_method())
	return names
