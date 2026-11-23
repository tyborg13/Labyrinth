extends "res://tools/gfix34/fixture.gd"
## Exact-size production viewport samples and a 60 Hz, silent production take.

const Cel = preload("res://scripts/cel_look.gd")
const CROP := Vector2i(640, 480)
const FPS: int = 60
const REEL_SECONDS: int = 3
const REEL_LEAD_FRAMES: int = 30
const TRAVEL_SAMPLES := [0.33, 0.66]
const LABELS := ["outbound33", "outbound66", "flash", "return33", "return66", "return_contact"]

var _output: String
var _dry: bool
var _reel_done: bool
var _reel_legs: Dictionary

func _take() -> void:
	_dry = "--dry-run" in OS.get_cmdline_user_args()
	_output = _arg("--out")
	var mode: String = _arg("--mode")
	var base: String = _arg("--base")
	if not _expect(_dry == (DisplayServer.get_name() == "headless") and Cel.mode == "all"
			and FileAccess.file_exists("res://cel_look_variants/manifest.json")
			and _output.is_absolute_path() and mode in ["strip", "reel"],
			"native proof needs a cel-look viewport, output path and valid mode"):
		quit(2)
		return
	if await _open(SHOT_CARD, base, false, false):
		DirAccess.make_dir_recursive_absolute(_output)
		if mode == "strip":
			await _strip(not base.is_empty())
		else:
			await _reel()
	await _close()
	print("GFIX-34 NATIVE %s %s: %d checks, %d failures" % ["DRY RUN" if _dry else "CAPTURE", mode, _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _strip(is_base: bool) -> void:
	await _drive(SHOT_CARD)
	var effect: Dictionary = _scene.proof_effect
	if not _expect(not effect.is_empty(), "RunScene produces the Hurl Spear reflection descriptor"): return
	var board: Control = _scene.board_view
	var fx: RefCounted = board._single_shot_fx
	fx.advance(1.0)
	_scene._render_board_state(_before, {})
	var center: Vector2 = board.get_global_transform_with_canvas() * board._tile_center(HERO).lerp(board._tile_center(MIRROR), 0.5)
	var crop := Rect2i((Vector2i(center) - CROP / 2).clamp(Vector2i.ZERO, SIZE - CROP), CROP)
	var outbound: float = effect["en05_outbound_seconds"]
	var flash: float = View.FLASH_SECONDS
	var returning: float = outbound / View.RETURN_SPEED
	var total: float = View.projectile_seconds(outbound)
	var times: Array[float] = [
		outbound * TRAVEL_SAMPLES[0], outbound * TRAVEL_SAMPLES[1], outbound + flash * 0.5,
		outbound + flash + returning * TRAVEL_SAMPLES[0], outbound + flash + returning * TRAVEL_SAMPLES[1], total,
	]
	var strip: Image
	if not _dry:
		strip = Image.create_empty(CROP.x * LABELS.size(), CROP.y, false, Image.FORMAT_RGB8)
	var mirror_key: String = _scene._combat_engine._enemy_key(_before["enemies"][0])
	for index: int in LABELS.size():
		var progress: float = times[index] / total
		var contact: bool = index == LABELS.size() - 1
		if contact:
			var terminal: Dictionary = {} if is_base else {"effect": effect, "effect_progress": 1.0}
			_scene._render_board_state(_after, terminal)
		else:
			var phase: Dictionary = View.projectile_frame(progress, outbound)
			_scene._render_board_state(_before, {
				"effect": effect, "effect_progress": progress,
				"combat_feel_flash": {mirror_key: 1.0 if phase["flash"] else 0.0},
				"combat_feel_flash_actor_keys": [mirror_key],
			})
		if _dry:
			print("GFIX-34 STRIP %s t=%.6fs crop=%s" % [LABELS[index], times[index], crop])
			continue
		var image: Image = await _frame()
		if image == null: return
		var path: String = _output.path_join(LABELS[index] + ".png")
		_expect(image.save_png(path) == OK, "saves " + path)
		print(path)
		strip.blit_rect(image, crop, Vector2i(index * CROP.x, 0))
	var strip_path: String = _output.path_join("strip.png")
	if not _dry: _expect(strip.save_png(strip_path) == OK, "saves the six-panel strip")
	print(strip_path)

func _reel() -> void:
	var raw_path: String = _output.path_join("frames.rgb")
	var preview_path: String = _output.path_join("reel_preview.png")
	var raw: FileAccess
	if not _dry:
		if not _expect(not Engine.get_write_movie_path().is_empty(), "movie clock is enabled"): return
		raw = FileAccess.open(raw_path, FileAccess.WRITE)
		if not _expect(raw != null, "opens raw movie output"): return
	_scene.proof_step_frames = false
	_scene.proof_observer = _observe_reel
	var frames: int = FPS * REEL_SECONDS
	var preview_saved: bool = false
	for index: int in frames:
		if index == REEL_LEAD_FRAMES: _play_reel()
		if _dry:
			await process_frame
		else:
			var image: Image = await _frame()
			if image == null: return
			raw.store_buffer(image.get_data())
			if not preview_saved and _reel_legs.has("return"):
				preview_saved = _expect(image.save_png(preview_path) == OK, "saves the native reel preview")
	_scene.proof_observer = Callable()
	if raw != null: raw.close()
	_expect(_reel_done and _reel_legs.size() == 4, "reel includes outbound, flash, return and contact")
	print("GFIX-34 REEL: %d frames at %d fps" % [frames, FPS])
	print(preview_path)
	print(raw_path)

func _observe_reel(shown: Dictionary) -> void:
	var progress: float = shown["effect_progress"]
	var phase: Dictionary = View.projectile_frame(progress, shown["effect"]["en05_outbound_seconds"])
	if progress >= 1.0: _reel_legs["contact"] = true
	elif phase["flash"]: _reel_legs["flash"] = true
	elif phase["returning"]: _reel_legs["return"] = true
	else: _reel_legs["outbound"] = true

func _play_reel() -> void:
	await _drive(SHOT_CARD)
	_reel_done = true

func _frame() -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if not _expect(image != null and image.get_size() == SIZE, "renderer returns the exact viewport size"): return null
	image.convert(Image.FORMAT_RGB8)
	return image
