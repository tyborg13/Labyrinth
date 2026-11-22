extends Control
const Cache = preload("res://scripts/tooltip_loop_cache.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Settings = preload("res://scripts/settings_store.gd")
const WINDOW := Vector2(282, 168)
const HOLD_SECONDS: float = 0.6
const CROSSFADE_SECONDS: float = 0.25
const FADE_IN_SECONDS: float = 0.12
const OUTER_WINDOW_MAX_SIZE := Vector2(420, 252)
var ready_usec: int = 0
var lease_usec: int = 0
var fit_content_width: bool = false
var displayed_frame: int = -1
var asset_path: String
var hold_seconds: float = HOLD_SECONDS
var proof_seconds: float = -1.0
var _elapsed: float = 0.0
var _fade: float = 0.0
var _leased: bool = false
var _texture: Texture2D
var _first: Texture2D
var _blend: float = 0.0
var _cache: Node
var reduced_motion: bool = false

func _init() -> void:
	name = "TooltipLoopWindow"
	custom_minimum_size = WINDOW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_resize_window)

func fit_to_content_width() -> void:
	fit_content_width = true
	custom_minimum_size.x = 0.0
	_resize_window()

func _resize_window() -> void:
	if fit_content_width and size.x > 0.0:
		custom_minimum_size.y = window_rect().size.y
	queue_redraw()

func window_rect() -> Rect2:
	if not fit_content_width: return Rect2(Vector2.ZERO, WINDOW)
	var width: float = minf(size.x, OUTER_WINDOW_MAX_SIZE.x)
	var extent := Vector2(width, roundf(width * OUTER_WINDOW_MAX_SIZE.y / OUTER_WINDOW_MAX_SIZE.x))
	return Rect2(Vector2((size.x - width) * 0.5, 0.0), extent)

func _ready() -> void:
	var started: int = Time.get_ticks_usec()
	reduced_motion = bool(Settings.load_settings().get("reduced_motion", false))
	# Corner ink is baked into the lossless recording. No first-use custom
	# CanvasItem shader/pipeline or additional overlay texture is created here.
	visibility_changed.connect(_sync_lease)
	_sync_lease()
	ready_usec = Time.get_ticks_usec() - started

func _sync_lease() -> void:
	var active: bool = is_inside_tree() and is_visible_in_tree()
	if active == _leased: return
	_leased = active
	if active:
		var started: int = Time.get_ticks_usec()
		_cache = Cache.shared()
		_cache.acquire(asset_path)
		_elapsed = 0.0
		_fade = 0.0
		_texture = null
		_first = null
		lease_usec = Time.get_ticks_usec() - started
	else:
		_cache.release(asset_path)
		_texture = null
		_first = null
	set_process(active)

func _exit_tree() -> void:
	if _leased and is_instance_valid(_cache): _cache.release(asset_path)
	_leased = false

func _process(delta: float) -> void:
	var info: Dictionary = _cache.header(asset_path)
	var count: int = int(info.get("count", 1))
	var duration: float = float(count) / 30.0
	var period: float = duration + hold_seconds + CROSSFADE_SECONDS
	var at: float = fmod(proof_seconds if proof_seconds >= 0.0 else _elapsed, period)
	var index: int = count - 1 if reduced_motion else mini(int(at * 30.0), count - 1)
	var next: Texture2D = _first if index == 0 and _first != null else _cache.frame(asset_path, index)
	if next != null:
		displayed_frame = index
		_texture = next
		if index == 0: _first = next
	if next != null and index + 2 < count and not reduced_motion: _cache.frame(asset_path, index + 2)
	if _first == null and not reduced_motion: _first = _cache.frame(asset_path, 0)
	if _texture != null and not info.is_empty():
		_elapsed += delta
		_fade = minf(FADE_IN_SECONDS, _fade + delta)
	_blend = clampf((at - duration - hold_seconds) / CROSSFADE_SECONDS, 0.0, 1.0) if not reduced_motion else 0.0
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = window_rect()
	var extent: Vector2 = rect.size
	var origin: Vector2 = rect.position
	if _texture != null:
		var alpha: float = 1.0 if reduced_motion else _fade / FADE_IN_SECONDS
		draw_texture_rect(_texture, rect, false, Color(1, 1, 1, alpha))
		if _first != null and _blend > 0.0: draw_texture_rect(_first, rect, false, Color(1, 1, 1, alpha * _blend))
	# Four filled one-pixel strips keep the requested hairline inside the window.
	for edge: Rect2 in [Rect2(0, 0, extent.x, 1), Rect2(0, extent.y - 1, extent.x, 1), Rect2(0, 0, 1, extent.y), Rect2(extent.x - 1, 0, 1, extent.y)]:
		draw_rect(Rect2(edge.position + origin, edge.size), Palette.GOLD_DIM)
