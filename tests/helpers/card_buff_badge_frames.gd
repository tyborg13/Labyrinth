extends RefCounted

## Headless draw-command frames for fx-01's single landing swell, with no ring.
const Plates = preload("res://scripts/board_status_plates.gd")
const PopTracker = preload("res://scripts/status_pop_tracker.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const SAMPLE_INTERVALS: int = 30
const FIXTURE_RECT := Rect2(100, 100, 64, 22)

class PaintFrame extends RefCounted:
	var styles: Array[Rect2]
	var transforms: Array[Transform2D]
	var tooltips: Array[Rect2]
	func draw_style_box(_style: StyleBox, rect: Rect2) -> void: styles.append(rect)
	func draw_set_transform_matrix(transform: Transform2D) -> void: transforms.append(transform)
	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float, _antialiased: bool) -> void: pass
	func draw_texture_rect_region(_texture: Texture2D, _rect: Rect2, _source: Rect2, _color: Color) -> void: pass
	func draw_string_outline(_font: Font, _pos: Vector2, _text: String, _align: int, _width: float, _size: int, _outline: int, _color: Color) -> void: pass
	func draw_string(_font: Font, _pos: Vector2, _text: String, _align: int, _width: float, _size: int, _color: Color) -> void: pass
	func _register_tooltip(rect: Rect2, _tooltip: String) -> void: tooltips.append(rect)

static func run(expect: Callable) -> void:
	var tracker := PopTracker.new()
	tracker.observe("player", [])
	tracker.observe("player", [{"icon": "bleed", "count": 3}])
	expect.call(tracker.progress("player", "bleed") == 0.0, "A newly landed badge starts its swell on the landing frame")
	tracker.advance(PopTracker.POP_SECONDS * PopTracker.PEAK_PROGRESS)
	expect.call(is_equal_approx(PopTracker.pill_scale(tracker.progress("player", "bleed")), PopTracker.PEAK_SCALE), "The landing swell reaches its authored peak")
	tracker.advance(PopTracker.POP_SECONDS)
	expect.call(not tracker.is_active() and tracker.progress("player", "bleed") < 0.0, "The badge settles after its single landing swell")
	for defense: bool in [false, true]:
		var entry: Dictionary = {"rect": FIXTURE_RECT, "defense_plate": defense, "presentation_alpha": 1.0, "presentation_border": Palette.GOLD_BRIGHT, "label": "3", "label_font_size": 15, "tooltip": "fixture"}
		for still: bool in [false, true]:
			for index: int in range(SAMPLE_INTERVALS + 1):
				var progress: float = float(index) / SAMPLE_INTERVALS
				var frame := PaintFrame.new()
				Plates.draw_entry(frame, entry, null, 1.0, progress, still)
				expect.call(frame.styles.size() == 1 and frame.styles[0] == FIXTURE_RECT, "Every landing frame paints exactly one badge body and no second outline")
				expect.call(frame.tooltips.size() == 1 and frame.tooltips[0] == FIXTURE_RECT, "The landing swell retains the badge's tooltip region")
				if still:
					expect.call(frame.transforms.is_empty(), "Reduced Motion keeps the badge still")
				elif index in [0, SAMPLE_INTERVALS]:
					expect.call(frame.transforms.size() == 1 and frame.transforms[0] == Transform2D.IDENTITY, "The landing endpoints keep the badge at its settled transform")
				else:
					expect.call(frame.transforms.size() == 2 and frame.transforms.back() == Transform2D.IDENTITY, "The landing frame restores the canvas transform after its one swell")
					if frame.transforms.size() == 2:
						var transform: Transform2D = frame.transforms[0]
						expect.call((transform * FIXTURE_RECT.get_center()).is_equal_approx(FIXTURE_RECT.get_center()) and transform.get_scale().x > 1.0 and transform.get_scale().x <= PopTracker.PEAK_SCALE, "The single swell stays centered within its authored scale")
