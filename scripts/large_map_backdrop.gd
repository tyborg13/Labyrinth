extends ColorRect

const FADE_SECONDS: float = 0.32
const REDUCED_FADE_SECONDS: float = 0.12

var room_title: Label
var _fade: Tween

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)

func fade_in(seconds: float) -> Tween:
	_stop_fade()
	set_fade_alpha(0.0)
	_fade = create_tween()
	_fade.tween_method(set_fade_alpha, 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return _fade

func set_fade_alpha(alpha: float) -> void:
	modulate.a = alpha
	# Preserve the room header's layout while the title fades under the map.
	room_title.self_modulate.a = 1.0 - alpha if visible else 1.0

func _on_visibility_changed() -> void:
	if not visible:
		_stop_fade()
		set_fade_alpha(1.0)
	else:
		set_fade_alpha(modulate.a)

func _stop_fade() -> void:
	if _fade != null and _fade.is_valid(): _fade.kill()
	_fade = null
