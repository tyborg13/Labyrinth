extends Node

const Backdrop = preload("res://scripts/large_map_backdrop.gd")

var _board: Control
var _fade_seconds: Callable
var _panels: Dictionary = {}
var _target: float = 1.0
var _fade: Tween

func setup(board: Control, fade_seconds: Callable) -> void:
	_board = board
	_fade_seconds = fade_seconds
	set_process(false)

func watch(surface: Control, panel: Callable = Callable()) -> void:
	_panels[surface] = panel
	surface.visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if not is_inside_tree(): return
	for surface: Control in _panels:
		if surface.is_visible_in_tree():
			set_process(true)
			return
	set_process(false)
	_fade_to(1.0)

func _process(_delta: float) -> void:
	# A container can finish sizing after opening, and Character can swap its
	# retained dialog while its scrim remains visible. Use the live geometry.
	var title: Rect2 = _board.status_title_screen_rect()
	if title.has_area():
		for surface: Control in _panels:
			if not surface.is_visible_in_tree(): continue
			var get_panel: Callable = _panels[surface]
			var panel: Control = get_panel.call() if get_panel.is_valid() else surface
			if panel == null or not panel.is_visible_in_tree(): continue
			var bounds: Rect2 = panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, panel.size)
			if title.intersects(bounds):
				_fade_to(0.0)
				return
	_fade_to(1.0)

func _fade_to(alpha: float) -> void:
	if _target == alpha: return
	_target = alpha
	if _fade != null and _fade.is_valid(): _fade.kill()
	_fade = Backdrop.tween_alpha(self, _board.set_status_title_alpha, _board.get_status_title_alpha(), alpha, _fade_seconds.call())
