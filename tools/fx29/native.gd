extends "res://tools/fx29/fixture.gd"
## Matched production-viewport samples and a silent four-second combat take.

const Cel = preload("res://scripts/cel_look.gd")
const Crop := Vector2i(640, 480)
const FPS: int = 60
const REEL_SECONDS: int = 4
const LEAD_FRAMES: int = 30
const REEL_MIRROR_DELAY: int = 1
const RELEASE: int = 13
const ARRIVAL: int = 34
const STRIP_FRAMES: Array[int] = [RELEASE, 20, 27, ARRIVAL, ARRIVAL + 6, ARRIVAL + 14]
const LABELS: Array[String] = ["release", "flight33", "flight66", "arrival", "arrival_plus100ms", "arrival_plus233ms"]

var _output: String
var _dry: bool
var _strip_image: Image
var _crop: Rect2i
var _captured: int
var _cast: Dictionary
var _reel_done: bool

func _take() -> void:
	_dry = "--dry-run" in OS.get_cmdline_user_args()
	_output = _arg("--out")
	var mode: String = _arg("--mode")
	var base: String = _arg("--base")
	if not _expect(_dry == (DisplayServer.get_name() == "headless") and Cel.mode == "all"
			and FileAccess.file_exists("res://cel_look_variants/manifest.json")
			and _output.is_absolute_path() and mode in ["strip", "reel"],
			"native proof requires cel look, a viewport, a capture mode and an output path"):
		quit(2)
		return
	if await _open(base):
		DirAccess.make_dir_recursive_absolute(_output)
		if mode == "strip": await _strip()
		else: await _reel()
	await _close()
	print("FX-29 NATIVE %s %s: %d checks, %d failures" % ["DRY RUN" if _dry else "CAPTURE", mode, _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _strip() -> void:
	_prepare("two_units", false)
	var board: Control = _scene.board_view
	var center: Vector2 = board.get_global_transform_with_canvas() * board._tile_center(MIRROR).lerp(board._tile_center(HERO), 0.5)
	_crop = Rect2i((Vector2i(center) - Crop / 2).clamp(Vector2i.ZERO, SIZE - Crop), Crop)
	if not _dry: _strip_image = Image.create_empty(Crop.x * LABELS.size(), Crop.y, false, Image.FORMAT_RGB8)
	_scene.proof_observer = _strip_sample
	await _play(false)
	_scene.proof_observer = Callable()
	_expect(_captured == LABELS.size() and _scene.proof_contact == ARRIVAL, "all six samples use the unchanged contact clock")
	var strip_path: String = _output.path_join("strip.png")
	if not _dry: _expect(_strip_image.save_png(strip_path) == OK, "saves matched strip")
	print(strip_path)

func _strip_sample(frame: int) -> void:
	var index: int = STRIP_FRAMES.find(frame)
	if index < 0: return
	var board: Control = _scene.board_view
	var flight: bool = board._single_shot_fx._heads[0].visible
	var beam: bool = board.presentation.get("effect", {}).get("action_type") == "refraction" and float(board.presentation.get("effect_progress", 1.0)) < 1.0
	var expected_hp: int = _after["player"]["hp"] if frame >= ARRIVAL else _before["player"]["hp"]
	_expect(board.combat_state["player"]["hp"] == expected_hp, LABELS[index] + " uses the correct damage state")
	_expect(flight == (_base.is_empty() and frame <= ARRIVAL) and (_base.is_empty() or beam == (frame >= ARRIVAL)), LABELS[index] + " uses the correct flight/beam sample")
	_captured += 1
	var path: String = _output.path_join(LABELS[index] + ".png")
	print("FX-29 STRIP %s frame=%d t=%.6fs crop=%s" % [LABELS[index], frame, float(frame - 1) / FPS, _crop])
	print(path)
	if _dry: return
	var image: Image = await _frame()
	if image == null: return
	_expect(image.save_png(path) == OK, "saves " + path)
	_strip_image.blit_rect(image, _crop, Vector2i(index * Crop.x, 0))

func _reel() -> void:
	var raw_path: String = _output.path_join("frames.rgb")
	var preview_path: String = _output.path_join("reel_preview.png")
	var raw: FileAccess
	if not _dry:
		if not _expect(not Engine.get_write_movie_path().is_empty(), "movie clock is enabled"): return
		raw = FileAccess.open(raw_path, FileAccess.WRITE)
		if not _expect(raw != null, "opens raw movie output"): return
	_prepare("hero_end", false)
	# Arrange the opening queue in the fixture, then play Pass through normal
	# resolution so the real enemy turn casts the committed Refraction.
	for entry: Dictionary in _scene._combat_state["turn_queue"]:
		if entry.get("actor_key") == _step["actor_key"]:
			entry["time"] = int(_scene._combat_state["initiative_clock"]) + REEL_MIRROR_DELAY
	_scene._combat_state["turn_queue"] = _combat_engine._sorted_turn_queue(_scene._combat_state["turn_queue"])
	_scene._refresh_ui()
	_scene.proof_step_frames = false
	_scene.proof_render_observer = _observe_reel
	var starting_hp: int = _scene._combat_state["player"]["hp"]
	var frames: int = FPS * REEL_SECONDS
	var preview_saved: bool = false
	for index: int in frames:
		if index == LEAD_FRAMES: _pass_turn()
		if _dry:
			await process_frame
		else:
			var image: Image = await _frame()
			if image == null: return
			raw.store_buffer(image.get_data())
			if not preview_saved and _cast.has("flight") and not _cast.has("contact"):
				preview_saved = _expect(image.save_png(preview_path) == OK, "saves native flight preview")
	_scene.proof_render_observer = Callable()
	if raw != null: raw.close()
	var shown_hp: int = _scene.board_view.combat_state.get("player", {}).get("hp", starting_hp)
	print("FX-29 REEL receipt cast=%s displayed_hp=%d started_hp=%d turn_finished=%s" % [_cast, shown_hp, starting_hp, _reel_done])
	_expect(_cast.has("flight") and _cast.has("contact") and shown_hp < starting_hp,
		"real Pass input resolves Refraction with flight, contact and hero loss")
	# The recorded interval is fixed. Let any remaining normal turn wrap-up
	# finish before disposing the scene.
	var cutoff: int = Time.get_ticks_msec() + int(READY_SECONDS * 1000.0)
	while not _reel_done and Time.get_ticks_msec() < cutoff: await process_frame
	_expect(_reel_done, "enemy turn completes")
	print("FX-29 REEL: %d frames at %d fps" % [frames, FPS])
	print(preview_path)
	print(raw_path)

func _observe_reel(shown: Dictionary) -> void:
	var sample: Dictionary = shown.get(View.REFRACTION_SAMPLE, {})
	if not sample.is_empty() and float(sample["travel"]) < 1.0:
		_cast["flight"] = true
	if shown.get("effect", {}).get("action_type") == "refraction" and not shown.get("floating_texts", []).is_empty():
		_cast["contact"] = true

func _pass_turn() -> void:
	await _scene._on_pass_turn_pressed()
	_reel_done = true

func _frame() -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if not _expect(image != null and image.get_size() == SIZE, "renderer returns 1920x1080"): return null
	image.convert(Image.FORMAT_RGB8)
	return image
