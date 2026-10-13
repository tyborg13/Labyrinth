extends SceneTree

## Before/after proof only. Native rest comparison needs a real renderer.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Rig = preload("res://scripts/crawler_cutout/rig.gd")
const Settings = preload("res://scripts/settings_store.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/crawler_recolour"
const BASELINE_DIR: String = "res://output/rr-01/before"
const PATHS = [
	"assets/units/crawler_cutout/front/rest.png",
	"assets/units/crawler_cutout/rear/rest.png",
	"assets/art/portraits/tunnel_crawler.png",
]
# Non-player-facing proof layout and sampling defaults.
const PROOF_COLUMN_X = [64, 704, 1344]
const PROOF_IMAGE_Y = [35, 565]
const PROOF_LABEL_Y = [8, 548]
const PROOF_CELL_SIDE: int = 510
const PROOF_ZOOM: int = 2
const PROOF_FONT_SIZE: int = 22
const PROOF_NATIVE_REGION := Rect2i(128, 128, 255, 255)
const PROOF_NATIVE_VIEWPORT := Vector2i(512, 512)
const PROOF_SETTLE_FRAMES: int = 2
var _errors: Array[String]
var _records: Array[Dictionary]
var _validate_only: bool = false
var _baseline: Dictionary
var _canvas: SubViewport

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	Settings.set_storage_path("user://crawler_recolour_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	_expect(Settings.save_settings(settings), "Proof uses isolated 100% UI scale")
	_run.call_deferred()

func _run() -> void:
	_baseline = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_DIR.path_join("manifest.json"))) as Dictionary
	_expect(not _baseline.is_empty(), "Run recolour_lab.py --prepare-proof first")
	if _baseline.is_empty():
		_finish()
		return
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.disable_3d = true
	_canvas.world_2d = World2D.new()
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	for column: int in range(PATHS.size()):
		var path: String = PATHS[column]
		var before: Image = Image.load_from_file(BASELINE_DIR.path_join(path))
		var after: Image = Image.load_from_file("res://" + path)
		_expect(before != null and after != null, "Both source PNGs load: " + path)
		if before == null or after == null: continue
		before.convert(Image.FORMAT_RGBA8)
		after.convert(Image.FORMAT_RGBA8)
		_expect(_pixel_digest(before) == (_baseline.get("before_pixels", {}) as Dictionary).get(path, ""), "Before pixels match the fixed baseline: " + path)
		_expect(_same_alpha_and_hidden(before, after), "Alpha and hidden pixels retained: " + path)
		var before_value: float = _value(before)
		var after_value: float = _value(after)
		_expect(after_value < before_value, "Shipped paint is recoloured: " + path)
		var native_equal: bool = false
		if not _validate_only and column < 2:
			native_equal = await _native_rest_equal("front" if column == 0 else "rear", after)
			_expect(native_equal, "Shipped rest equals current native rig: " + path)
		_records.append({"path": path, "before_value": before_value, "after_value": after_value,
			"native_rest_compared": not _validate_only and column < 2, "native_rest_equal": native_equal,
			"source_sha256": FileAccess.get_sha256("res://" + path)})
		for row: int in range(2):
			var image: Image = before if row == 0 else after
			var rect := TextureRect.new()
			rect.texture = ImageTexture.create_from_image(image)
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.size = Vector2(image.get_size() * PROOF_ZOOM)
			rect.position = Vector2(PROOF_COLUMN_X[column], PROOF_IMAGE_Y[row]) + (Vector2.ONE * PROOF_CELL_SIDE - rect.size) / 2.0
			_canvas.add_child(rect)
			var label := Label.new()
			label.text = ("Front rest" if column == 0 else ("Rear rest" if column == 1 else "Turn-order portrait")) + (" — before" if row == 0 else " — after")
			label.position = Vector2(PROOF_COLUMN_X[column], PROOF_LABEL_Y[row])
			label.add_theme_font_size_override("font_size", PROOF_FONT_SIZE)
			_canvas.add_child(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if not _validate_only and _errors.is_empty():
		for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
		await RenderingServer.frame_post_draw
		var path: String = OUTPUT_DIR.path_join("crawler_before_after.png")
		_expect(_canvas.get_texture().get_image().save_png(path) == OK, "Contact sheet saves")
		print("Saved " + ProjectSettings.globalize_path(path))
	var file := FileAccess.open(OUTPUT_DIR.path_join("semantic-proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline_commit": _baseline.get("baseline_commit", ""),
		"size": [1920, 1080], "ui_scale": 1.0, "zoom": PROOF_ZOOM, "validate_only": _validate_only,
		"records": _records, "failures": _errors}, "\t"))
	file.close()
	_canvas.free()
	_finish()

func _native_rest_equal(facing: String, expected: Image) -> bool:
	var viewport := SubViewport.new()
	viewport.size = PROOF_NATIVE_VIEWPORT
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rig := Rig.new()
	rig.facing = facing
	rig.position = Vector2(PROOF_NATIVE_REGION.position)
	viewport.add_child(rig)
	if not rig.load_rig():
		viewport.free()
		return false
	rig.apply_pose("rest", 0.0)
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = viewport.get_texture().get_image().get_region(PROOF_NATIVE_REGION)
	rendered.convert(Image.FORMAT_RGBA8)
	var equal: bool = rendered.get_data() == expected.get_data()
	viewport.free()
	return equal

func _same_alpha_and_hidden(before: Image, after: Image) -> bool:
	if before.get_size() != after.get_size(): return false
	var a: PackedByteArray = before.get_data()
	var b: PackedByteArray = after.get_data()
	for index: int in range(0, a.size(), 4):
		if a[index + 3] != b[index + 3]: return false
		if a[index + 3] == 0 and a.slice(index, index + 4) != b.slice(index, index + 4): return false
	return true

func _pixel_digest(image: Image) -> String:
	var bytes: PackedByteArray = "RGBA".to_utf8_buffer()
	bytes.append(0)
	for dimension: int in [image.get_width(), image.get_height()]:
		for shift: int in [24, 16, 8, 0]: bytes.append((dimension >> shift) & 255)
	bytes.append_array(image.get_data())
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _value(image: Image) -> float:
	var pixels: PackedByteArray = image.get_data()
	var total: float = 0.0
	var count: int = 0
	for index: int in range(0, pixels.size(), 4):
		if pixels[index + 3] <= 128: continue
		total += (0.299 * pixels[index] + 0.587 * pixels[index + 1] + 0.114 * pixels[index + 2]) / 255.0
		count += 1
	return total / maxi(1, count)

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)

func _finish() -> void:
	for message: String in _errors: push_error(message)
	print("CRAWLER RECOLOUR %s: %s" % ["HEADLESS VALIDATION" if _validate_only else "PROBE", "PASS" if _errors.is_empty() else "FAIL"])
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)
