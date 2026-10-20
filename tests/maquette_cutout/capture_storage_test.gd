extends SceneTree

const Storage = preload("capture_storage.gd")
const TEST_SIZE := Vector2i(96, 72)
const TEST_BOUNDS := Rect2(30.25, 24.75, 12.5, 8.25)
const TEST_PATTERN_MODULUS := Vector3i(251, 253, 256)
const TEST_BLUE_FACTORS := Vector2i(7, 11)
const CAPTURE_SCRIPT_PATHS := [
	"res://experiments/cutouts/arc_thrall/rr24_native_capture.gd",
	"res://tests/gait01/move_capture.gd",
	"res://tests/maquette_cutout/native_capture.gd",
	"res://tests/maquette_cutout/pixel_capture.gd",
	"res://tests/maquette_cutout/production_capture.gd",
	"res://tests/maquette_cutout/seam_capture.gd",
	"res://tests/rr07/production_capture.gd",
	"res://tests/rr10/native_capture.gd",
	"res://tests/rr10/production_capture.gd",
	"res://tests/rr11/native_capture.gd",
	"res://tests/rr11/production_capture.gd",
	"res://tests/rr12/production_capture.gd",
	"res://tests/rr17/native_capture.gd",
	"res://tests/rr17/production_capture.gd",
	"res://tests/rr18/native_capture.gd",
	"res://tests/rr18/production_capture.gd",
	"res://tests/rr20/native_capture.gd",
	"res://tests/rr20/production_capture.gd",
	"res://tests/rr21/native_capture.gd",
	"res://tests/rr21/production_capture.gd",
	"res://tests/rr22/native_capture.gd",
	"res://tests/rr22/production_capture.gd",
]
class FixtureBoard extends Control:
	const BODY := Rect2(40, 70, 255, 255)
	func world_position_for_unit_origin(_unit: Dictionary, _tile: Vector2i) -> Vector2:
		return Vector2(500, 500)
	func _unit_hud_anchor_texture(_unit: Dictionary) -> Texture2D:
		return null
	func _unit_draw_rect_for_texture(_unit: Dictionary, _center: Vector2, _texture: Texture2D) -> Rect2:
		return BODY

var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for script_path: String in CAPTURE_SCRIPT_PATHS:
		_check(load(script_path) != null, "Capture script loads: " + script_path)
	var board_fixture := FixtureBoard.new()
	root.add_child(board_fixture)
	var bounds: Rect2 = Storage._include_unit(board_fixture, {"type": "capture_fixture", "pos": Vector2i.ZERO}, Rect2())
	_check(bounds == Rect2(-88, -58, 512, 512), "Non-profile actors preserve the board's actual registration")
	board_fixture.free()
	Storage.setup(output)
	_check(Storage.clamp_crop(TEST_BOUNDS, TEST_SIZE) == Rect2i(14, 8, 45, 41), "Outward crop rounding")
	_check(Storage.clamp_crop(Rect2(-10, -20, 130, 120), TEST_SIZE) == Rect2i(Vector2i.ZERO, TEST_SIZE), "Edge clamping")
	var bytes := PackedByteArray()
	bytes.resize(TEST_SIZE.x * TEST_SIZE.y * 4)
	for i: int in range(bytes.size()): bytes[i] = i % 251
	var image := Image.create_from_data(TEST_SIZE.x, TEST_SIZE.y, false, Image.FORMAT_RGBA8, bytes)
	for codec: String in ["png", "webp", "rgba"]:
		var path: String = output.path_join("roundtrip." + codec)
		_check(Storage.write_image(image, path, codec) == OK, codec + " writes")
		var decoded: Image = Storage.load_image(path, codec)
		decoded.convert(Image.FORMAT_RGBA8)
		_check(decoded.get_data() == bytes, codec + " exact RGBA bytes")
		# Include hidden RGB under transparent alpha; the production benchmark
		# independently repeats this exact-byte check for every real frame.
	Storage.save(image, output.path_join("frame.png"))
	Storage.finish()
	_check(not Storage.file_hash(output.path_join("frame.png")).is_empty(), "Encoded hash")
	_check(FileAccess.file_exists(Storage.proof_png(output.path_join("frame.png"))), "PNG proof export")
	# Non-uniform RGB readback catches a shifted crop even when its recorded
	# coordinates remain unchanged. Python independently reconstructs every byte.
	var board_bytes := PackedByteArray()
	board_bytes.resize(1920 * 1080 * 3)
	for y: int in range(1080):
		for x: int in range(1920):
			var index: int = (y * 1920 + x) * 3
			board_bytes[index] = x % TEST_PATTERN_MODULUS.x
			board_bytes[index + 1] = y % TEST_PATTERN_MODULUS.y
			board_bytes[index + 2] = (x * TEST_BLUE_FACTORS.x + y * TEST_BLUE_FACTORS.y) % TEST_PATTERN_MODULUS.z
	var board := Image.create_from_data(1920, 1080, false, Image.FORMAT_RGB8, board_bytes)
	Storage.set_crop(Rect2(700, 400, 100, 120), Vector2i(1920, 1080))
	for codec: String in ["png", "webp", "rgba"]:
		Storage.encoding = codec
		var logical: String = output.path_join("board_" + codec + ".png")
		Storage.save(board, logical, "idle_" + codec)
		var proof: Image = Image.load_from_file(Storage.proof_png(logical))
		var expected: Image = board.duplicate()
		expected.convert(Image.FORMAT_RGBA8)
		proof.convert(Image.FORMAT_RGBA8)
		_check(proof.get_data() == expected.get_data(), codec + " RGB board full-reference restoration")
	Storage.finish()
	for error: String in failures: push_error(error)
	print("CAPTURE STORAGE: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
