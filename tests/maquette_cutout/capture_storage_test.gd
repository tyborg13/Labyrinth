extends SceneTree

const Storage = preload("capture_storage.gd")
const TEST_SIZE := Vector2i(96, 72)
const TEST_BOUNDS := Rect2(30.25, 24.75, 12.5, 8.25)
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
	# The real board readback can be RGB8 while stored crops are RGBA8.
	var board: Image = Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	board.fill(Color(0.1, 0.2, 0.3))
	Storage.set_crop(Rect2(700, 400, 100, 120), Vector2i(1920, 1080))
	Storage.save(board, output.path_join("board.png"), "idle")
	var proof: Image = Image.load_from_file(Storage.proof_png(output.path_join("board.png")))
	board.convert(Image.FORMAT_RGBA8)
	proof.convert(Image.FORMAT_RGBA8)
	_check(proof.get_data() == board.get_data(), "RGB board full-reference restoration")
	Storage.finish()
	for error: String in failures: push_error(error)
	print("CAPTURE STORAGE: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
