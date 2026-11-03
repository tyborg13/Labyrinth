extends SceneTree

## Windowed native 1920x1080 captures; 4x drawing is a proof-only transform.
const Fixture = preload("res://tests/status_icon_fixture.gd")
const Plates = preload("res://scripts/board_status_plates.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://status-icon-fit"
const PROOF_SCALE: float = 4.0
const ROWS_PER_PAGE: int = 8
const ROW_ORIGIN := Vector2(32, 112)
const ROW_STEP: float = 118.0
const ICON_COLUMNS: PackedFloat32Array = [320.0, 1020.0, 1400.0]
const HEADER_Y: float = 38.0
const COLUMN_LABEL_Y: float = 80.0
const PROOF_FONT_SIZE: int = 18
const SETTLE_FRAMES: int = 3
var _failures: Array[String]
var _captures: Array[Dictionary]

class PaintProxy extends RefCounted:
	var canvas: Control
	var entry: Dictionary
	var before: bool
	func draw_style_box(style: StyleBox, rect: Rect2) -> void: canvas.draw_style_box(style, rect)
	func draw_line(a: Vector2, b: Vector2, color: Color, width: float, aa: bool) -> void: canvas.draw_line(a, b, color, width, aa)
	func draw_texture_rect_region(texture: Texture2D, rect: Rect2, source: Rect2, color: Color) -> void:
		canvas.draw_texture_rect_region(texture, Fixture.legacy_rect(entry, source) if before else rect, source, color)
	func draw_string_outline(font: Font, pos: Vector2, text: String, align: int, width: float, size: int, outline: int, color: Color) -> void:
		canvas.draw_string_outline(font, pos, text, align, width, size, outline, color)
	func draw_string(font: Font, pos: Vector2, text: String, align: int, width: float, size: int, color: Color) -> void:
		canvas.draw_string(font, pos, text, align, width, size, color)
	func _register_tooltip(_rect: Rect2, _tooltip: String) -> void: pass

class Sheet extends Control:
	var page: int
	var before: bool
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), Palette.INK_0)
		var font: Font = Typography.heavy_ui_font()
		draw_string(font, Vector2(ROW_ORIGIN.x, HEADER_Y), "Status icons — %s — 4x — page %d" % ["before" if before else "after", page + 1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, PROOF_FONT_SIZE, Palette.TEXT)
		for column: int in range(Fixture.KINDS.size()):
			draw_string(font, Vector2(ICON_COLUMNS[column], COLUMN_LABEL_Y), Fixture.KINDS[column], HORIZONTAL_ALIGNMENT_LEFT, -1.0, PROOF_FONT_SIZE, Palette.TEXT)
		for index: int in range(page * ROWS_PER_PAGE, mini((page + 1) * ROWS_PER_PAGE, Fixture.ICON_KEYS.size())):
			var icon: String = Fixture.ICON_KEYS[index]
			var y: float = ROW_ORIGIN.y + float(index % ROWS_PER_PAGE) * ROW_STEP
			draw_string(font, Vector2(ROW_ORIGIN.x, y + PROOF_FONT_SIZE), Icons.label(icon), HORIZONTAL_ALIGNMENT_LEFT, -1.0, PROOF_FONT_SIZE, Palette.TEXT)
			for column: int in range(Fixture.KINDS.size()):
				var entry: Dictionary = Fixture.entry(icon, Fixture.KINDS[column])
				var rect: Rect2 = entry["rect"]
				entry["rect"] = Rect2(Vector2.ZERO, rect.size)
				draw_set_transform(Vector2(ICON_COLUMNS[column], y), 0.0, Vector2.ONE * PROOF_SCALE)
				var proxy := PaintProxy.new()
				proxy.canvas = self
				proxy.entry = entry
				proxy.before = before
				Plates.draw_entry(proxy, entry, Icons.icon_texture(icon))
				draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	preload("res://tests/suites/board_status_icon_fit_suite.gd").run(_expect)
	var check_only: bool = OS.get_cmdline_user_args().has("--check-only")
	if not check_only and DisplayServer.get_name() == "headless":
		_expect(false, "4x sheets require the windowed visual runner")
		_finish()
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	root.add_child(viewport)
	var sheet := Sheet.new()
	sheet.size = Vector2(SIZE)
	viewport.add_child(sheet)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var pages: int = ceili(float(Fixture.ICON_KEYS.size()) / ROWS_PER_PAGE)
	for before: bool in [true, false]:
		for page: int in range(pages):
			sheet.before = before
			sheet.page = page
			sheet.queue_redraw()
			for _frame: int in range(SETTLE_FRAMES): await process_frame
			var path: String = OUTPUT.path_join("status_icons_%s_page_%02d_4x_1920x1080.png" % ["before" if before else "after", page + 1])
			if not check_only:
				await RenderingServer.frame_post_draw
				var image: Image = viewport.get_texture().get_image()
				_expect(image.get_size() == SIZE and image.save_png(path) == OK, "Write native 4x sheet: " + path)
			var keys: PackedStringArray = Fixture.ICON_KEYS.slice(page * ROWS_PER_PAGE, mini((page + 1) * ROWS_PER_PAGE, Fixture.ICON_KEYS.size()))
			_captures.append({"path": ProjectSettings.globalize_path(path), "before": before, "page": page + 1, "icons": keys, "kinds": Fixture.KINDS})
	var file := FileAccess.open(OUTPUT.path_join("semantic-proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution": [1920, 1080], "ui_scale": 1.0, "proof_scale": PROOF_SCALE, "check_only": check_only, "before_source": "Exact pre-sb-03 icon geometry in status_icon_fixture.legacy_rect; shared production frame/text paint", "captures": _captures, "failures": _failures}, "\t"))
	file.close()
	print("STATUS ICON SHEETS: " + ProjectSettings.globalize_path(OUTPUT))
	viewport.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _finish() -> void:
	for failure: String in _failures: push_error(failure)
	print("STATUS ICON FIT PROBE RESULT: %s (%d icons; %d sheets; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", Fixture.ICON_KEYS.size(), _captures.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)
