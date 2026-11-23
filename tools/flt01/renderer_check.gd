extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/suites/en01_enemies_suite.gd")
const Floats = preload("res://scripts/floating_combat_text.gd")
const FontStyle = preload("res://scripts/ui_typography.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const TARGET := Vector2i(2, 4)
const TEST_VIEW_SIZE := Vector2(960, 680)
const TEST_BOX := Rect2(80, 30, 800, 600)
const TEST_MAGNIFICATION: float = 2.0
const TEST_FRACTIONAL_SCALE: float = 1.5
const DRAW_WAIT_FRAMES: int = 6
const TIMING_TOLERANCE: float = 0.060

class DrawCounter extends Board:
	var samples: Array[Dictionary]
	var costs: Array[int]

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		_floating_icon_canvas.clear()
		costs.clear()
		for popup: Dictionary in samples:
			costs.append(_draw_floating_text_popup(popup))

class BeatClock extends "res://scripts/run_scene.gd":
	var timed_frames: int
	var last_progress: float

	func _ready() -> void:
		pass

	func _render_board_state(_state: Dictionary, shown: Dictionary, _stable: bool = false) -> void:
		assert((shown.get("floating_texts", []) as Array).is_empty())
		timed_frames += 1
		last_progress = float(shown.get("impact_progress", 0.0))

var _failures: Array[String]
var _checks: int

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var board := DrawCounter.new()
	board.size = TEST_VIEW_SIZE
	board.combat_state = Fixture.fixture(["crawler"])
	board.presentation = {"board_fit_rect": TEST_BOX}
	var base: Dictionary = Floats.resource_entry("block", TARGET, -4, {"width": 112.0, "offset": 0.0, "alignment": HORIZONTAL_ALIGNMENT_CENTER})
	var art: Texture2D = Icons.icon_texture("block")
	var font: Font = FontStyle.ui_font()
	_check_geometry(board, base, art, font)
	for reduced: bool in [false, true]:
		var shown: Dictionary = Floats.animate_entry(base, 0.0, reduced)
		var without: Dictionary = shown.duplicate(true)
		without.erase("icon")
		var plain: Dictionary = _layout(board, without, font)
		var with_icon: Dictionary = _layout(board, shown, font)
		board.samples.append(plain)
		board.samples.append(with_icon)
	root.add_child(board)
	for _frame: int in range(DRAW_WAIT_FRAMES): await process_frame
	_expect(board.costs.size() == 4, "A headless canvas draws the four matched comparison popups")
	if board.costs.size() == 4:
		for index: int in [0, 2]:
			var plain: int = board.costs[index]
			var outlined_icon: int = board.costs[index + 1]
			var ratio: float = float(outlined_icon) / plain
			_expect(outlined_icon == plain + 3 and ratio <= 1.5, "Outline, shadow and art add only three canvas submissions")
			print("FLT-01 DRAW SUBMISSIONS %s: %d plain, %d icon, %.3fx" % [
				"REDUCED" if index == 2 else "NORMAL", plain, outlined_icon, ratio,
			])
	board.queue_free()
	await _check_illusion_timing()
	var before: int = _checks
	preload("res://tests/suites/balance_pacing_suite.gd").run(_expect)
	print("FLT-01 BALANCE PACING: %d checks" % (_checks - before))
	before = _checks
	preload("res://tests/suites/maneuver_suite.gd").run(_expect)
	print("FLT-01 MANEUVERS: %d checks" % (_checks - before))
	for failure: String in _failures: push_error(failure)
	print("FLT-01 RENDERER CHECK: %s (%d checks, %d failures)" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)

func _layout(board: Control, entry: Dictionary, font: Font) -> Dictionary:
	board.presentation["floating_texts"] = [entry]
	return board._floating_text_screen_layout(font)[0]

func _check_geometry(board: Control, base: Dictionary, art: Texture2D, font: Font) -> void:
	var peak_center: float = 0.0
	for progress: float in [0.0, Floats.DAMAGE_SETTLE_PROGRESS, 1.0]:
		var entry: Dictionary = Floats.animate_entry(base, progress, false)
		var popup: Dictionary = _layout(board, entry, font)
		var rect: Rect2 = popup["icon_rect"]
		var scale: float = popup["font_scale"]
		var size: int = entry["font_size"]
		var rendered_font: float = size * scale
		_expect(is_equal_approx(rect.size.y * scale, rendered_font * 1.15), "Icon scales with the digits")
		_expect(is_equal_approx(rect.size.aspect(), art.get_size().aspect()), "Icon retains the source aspect ratio")
		_expect(is_equal_approx((float(popup["icon_advance"]) - rect.size.x) * scale, rendered_font * 0.16), "Gap scales with the digits")
		_expect(rect.get_center().y < 0.0 and rect.get_center().y > -font.get_ascent(size), "Digit center is in the ink above the baseline")
		var width: float = font.get_string_size(entry["text"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + float(popup["icon_advance"])
		_expect(is_equal_approx(board._floating_text_glyph_width(entry, font), width), "Width includes unpadded icon art and glyphs")
		_expect(float(popup["label_width"]) >= maxf(112.0, width), "Allocation honours the width override and actual composition")
		var unshifted_center: float = (popup["origin"] as Vector2).x + (float(popup["glyph_inset"]) + width * 0.5) * scale - (entry["motion_offset"] as Vector2).x
		if progress == 0.0: peak_center = unshifted_center
		_expect(is_equal_approx(unshifted_center, peak_center), "Scaling leaves the composition on its lane across the whole arc")
		_expect((popup["envelope"] as Rect2).size.x >= (popup["rendered_rect"] as Rect2).size.x, "Peak allocation contains the current ink")
	_expect(Floats.uses_nearest_filter(art.get_size(), art.get_size() * TEST_MAGNIFICATION), "Integer scaling uses nearest")
	_expect(not Floats.uses_nearest_filter(art.get_size(), art.get_size() * TEST_FRACTIONAL_SCALE), "Fractional scaling uses linear")

func _check_illusion_timing() -> void:
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(BeatClock)
	root.add_child(scene)
	var clock: BeatClock = scene
	for overlap: bool in [false, true]:
		clock._player_popup_timeline_active = overlap
		clock.timed_frames = 0
		clock.last_progress = 0.0
		await clock._animate_floating_text_presentation({}, {Floats.HOLD_EFFECT_BEAT_KEY: true}, 0.0, overlap)
		var elapsed: float = clock.last_progress * Floats.ANIMATION_DURATION_SECONDS
		var expected: float = Floats.ACTION_ADVANCE_SECONDS if overlap else Floats.ANIMATION_DURATION_SECONDS
		_expect(clock.timed_frames > 1 and elapsed >= expected - 0.000001 and elapsed <= expected + TIMING_TOLERANCE, "Illusion retains the original beat length in both timeline modes")
		_expect(clock._player_popup_timeline_groups.is_empty(), "Illusion enqueues no invisible popup")
		print("FLT-01 ILLUSION HOLD %s: %.3fs" % ["OVERLAP" if overlap else "SOLO", elapsed])
	scene.queue_free()

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
