extends Node

# A displayed texture never forwards desktop input into the isolated game.
# The production cursor is drawn in this viewport and driven only by route().
const Cursor = preload("res://scripts/cursor_feedback.gd")
const SIZE := Vector2i(1920, 1080)

var viewport: SubViewport
var display: TextureRect
var _cursor: CanvasLayer
var _glyph: Control
var _original_cursor_process: bool
var _original_cursor_input: bool

func setup(window: Window) -> void:
	viewport = SubViewport.new()
	viewport.name = "IsolatedGameViewport"
	viewport.size = SIZE
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.notify_mouse_entered()
	display = TextureRect.new()
	display.name = "CaptureDisplay"
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cursor = window.get_node("CursorFeedback") as CanvasLayer
	_glyph = _cursor.call("glyph_for_test") as Control
	_original_cursor_process = _cursor.is_processing()
	_original_cursor_input = _cursor.is_processing_input()
	_cursor.set_process(false)
	_cursor.set_process_input(false)
	var cursor_layer := CanvasLayer.new()
	cursor_layer.name = "CaptureCursorLayer"
	cursor_layer.layer = _cursor.layer
	viewport.add_child(cursor_layer)
	_glyph.reparent(cursor_layer)
	RenderingServer.frame_pre_draw.connect(_sync_cursor)

func route(event: InputEvent) -> void:
	# Preserve production cursor feedback without letting its root-viewport
	# mouse polling or raw desktop events enter the recorded gesture.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var hovered: Control = viewport.gui_get_hovered_control()
		var context: Dictionary = Cursor.context_for_control(hovered, (event as InputEventMouseButton).position)
		context["cue_click"] = Cursor.cue_owns_feedback(hovered)
		_cursor.call("_begin_pointer_press_with_context", (event as InputEventMouseButton).position, context)
	else:
		_cursor.call("_input", event)
	viewport.push_input(event, true)
	_sync_cursor()

func _process(_delta: float) -> void:
	_sync_cursor()

func _sync_cursor() -> void:
	if viewport == null or _glyph == null: return
	var point: Vector2 = viewport.get_mouse_position()
	_glyph.position = point - Cursor.CustomCursorGlyphScript.HOTSPOT
	_glyph.visible = Cursor.glyph_should_be_visible(viewport.get_visible_rect().has_point(point), true, bool(get_node("/root/InputRouter").call("using_controller")), bool(_cursor.call("glyph_visibility_suppressed")))
	_glyph.call("set_cursor_state", _cursor.call("_resolved_cursor_state", viewport.gui_get_hovered_control(), point))

func close() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_cursor):
		RenderingServer.frame_pre_draw.disconnect(_sync_cursor)
	if is_instance_valid(_cursor) and is_instance_valid(_glyph):
		_glyph.reparent(_cursor)
		_cursor.set_process(_original_cursor_process)
		_cursor.set_process_input(_original_cursor_input)
	set_process(false)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_cursor):
		RenderingServer.frame_pre_draw.disconnect(_sync_cursor)
