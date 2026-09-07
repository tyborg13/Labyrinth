extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()

func _run() -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	root.add_child(board)
	await process_frame
	var sources: Array[Texture2D]
	for element: String in ElementData.all_elements():
		for variant: int in range(Board.AMBIENT_PARTICLE_ATLAS_COLUMNS):
			board.call("_append_unique_ambient_atlas_source", sources, board.call("_ambient_particle_texture", element, variant))
			board.call("_append_unique_ambient_atlas_source", sources, board.call("_ambient_particle_glow_texture", element, variant))
			if element == "fire": board.call("_append_unique_ambient_atlas_source", sources, board.call("_ambient_fire_soft_texture", variant))
		if element == "air":
			for variant: int in range(Board.AMBIENT_AIR_WISP_VARIANTS):
				board.call("_append_unique_ambient_atlas_source", sources, board.call("_ambient_air_wisp_texture", variant, Board.AMBIENT_AIR_WISP_FULL_FRAME_INDEX))
				board.call("_append_unique_ambient_atlas_source", sources, board.call("_ambient_air_wisp_soft_texture", variant))
				board.call("_append_unique_ambient_atlas_source", sources, board.call("_ambient_air_wisp_glow_texture", variant, Board.AMBIENT_AIR_WISP_FULL_FRAME_INDEX))
	board.call("_ensure_ambient_combined_atlas")
	var packed: Image = (board.get("_ambient_combined_atlas") as Texture2D).get_image()
	var oracle := Image.create(packed.get_width(), packed.get_height(), false, Image.FORMAT_RGBA8)
	oracle.fill(Color.TRANSPARENT)
	var parents: Dictionary = {}
	var source_hashes: Array[String]
	for source: Texture2D in sources:
		var expected: Image = source.get_image()
		var actual: Image = board.call("_ambient_atlas_source_image", source, parents)
		_expect(_same_pixels(actual, expected), "Cached ambient region must preserve native source pixels")
		source_hashes.append(expected.get_data().hex_encode().sha256_text())
		var region: Rect2i = (board.get("_ambient_combined_atlas_regions") as Dictionary)[source.get_instance_id()]
		_expect(region.size == expected.get_size(), "Packed region size must preserve source dimensions")
		if expected.get_format() != Image.FORMAT_RGBA8: expected.convert(Image.FORMAT_RGBA8)
		oracle.blit_rect(expected, Rect2i(Vector2i.ZERO, expected.get_size()), region.position)
	_expect(_same_pixels(packed, oracle), "Combined atlas must exactly match original source.get_image packing")
	_expect(sources.size() == 56 and parents.size() == 6, "Ambient preparation must read six parent images for 56 regions")
	var unusual := AtlasTexture.new()
	unusual.atlas = sources[0]
	unusual.region = Rect2(0, 0, 8, 8)
	unusual.margin = Rect2(2, 2, 4, 4)
	_expect(_same_pixels(board.call("_ambient_atlas_source_image", unusual, parents), unusual.get_image()), "Unsupported regional layouts must preserve AtlasTexture fallback")
	var sheet: Image = AssetLoader.load_texture(Board.DOOR_OPENING_SHEET_PATH).get_image()
	var canvas: Vector2i = board.call("_door_opening_frame_canvas_size")
	var frames: Array = board.get("_door_opening_frames")
	var flipped: Array = board.get("_door_opening_flipped_frames")
	_expect(frames.size() == 8 and flipped.size() == 8, "Both complete door orientations must be prepared")
	for index: int in range(frames.size()):
		var region: Rect2i = Board.DOOR_OPENING_FRAME_REGIONS[index]
		var expected := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
		expected.fill(Color(0.0, 0.0, 0.0, 0.0))
		expected.blit_rect(sheet, region, canvas - region.size)
		_expect(_same_pixels((frames[index] as Texture2D).get_image(), expected), "Door frame registration/pixels must match original canvas")
		expected.flip_x()
		_expect(_same_pixels((flipped[index] as Texture2D).get_image(), expected), "Flipped door pixels must match original readback flip")
	print("BOARD STARTUP ASSETS RESULT: %s" % JSON.stringify({"source_count": sources.size(), "parent_image_count": 6, "source_hashes": source_hashes, "atlas_sha256": packed.get_data().hex_encode().sha256_text(), "door_frames": frames.size(), "semantic_errors": _errors, "renderer": RenderingServer.get_video_adapter_name()}))
	board.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _same_pixels(left: Image, right: Image) -> bool:
	return left != null and right != null and left.get_size() == right.get_size() and left.get_format() == right.get_format() and left.get_data() == right.get_data()

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
