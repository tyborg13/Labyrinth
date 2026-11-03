extends Control
const Preview = preload("res://scripts/event_reward_preview.gd")
const Separation = preload("res://scripts/event_reward_separation.gd")
var view: Control
var cache: Dictionary = {}
var current: Control
var current_line: Dictionary = {}
var preserve_painting: bool = false # The result receipt owns tone after a reward choice.
var _fade: Tween
var _pending_index: int = -1

func _ready() -> void:
	name = "EventHoverPreview"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_choice(index: int) -> void:
	if view.page != "choices" or index < 0 or index >= view.choices.size() or not view.choices[index].available:
		conceal()
		return
	if bool(view.get("_busy")):
		_pending_index = index
		return
	var line: Dictionary = Preview.first_concrete(view.cached_preview_lines(view.choices[index].choice_id))
	if line.is_empty(): conceal(); return
	if line == current_line and current != null and current.visible: return
	if _fade != null: _fade.kill()
	if current != null: current.hide()
	var key: int = hash(line)
	if not cache.has(key):
		var reward: Control = Preview.build(line, view.run_state)
		add_child(reward)
		reward.position = view.ART_RECT.get_center() - reward.size * 0.5
		cache[key] = reward
	current = cache[key]
	current_line = line
	current.show()
	current.modulate.a = 0 if not view.reduced_motion else 1
	if view.reduced_motion:
		view.set_preview_brightness(Separation.PAINTING_BRIGHTNESS)
	else:
		_fade = create_tween().set_parallel(true)
		_fade.tween_property(current, "modulate:a", 1.0, Separation.FADE_IN_SECONDS)
		_fade.tween_method(view.set_preview_brightness, view.preview_brightness, Separation.PAINTING_BRIGHTNESS, Separation.FADE_IN_SECONDS)

func conceal(instant: bool = false) -> void:
	_pending_index = -1
	if _fade != null: _fade.kill()
	current_line = {}
	if current == null or instant or view.reduced_motion:
		if current != null: current.hide()
		if not preserve_painting: view.set_preview_brightness(1)
		return
	var previous: Control = current
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(previous, "modulate:a", 0.0, Separation.FADE_OUT_SECONDS)
	if not preserve_painting: _fade.tween_method(view.set_preview_brightness, view.preview_brightness, 1.0, Separation.FADE_OUT_SECONDS)
	_fade.chain().tween_callback(previous.hide)

func show_pending() -> void:
	var index: int = _pending_index
	_pending_index = -1
	if index >= 0: show_choice(index)

func clear() -> void:
	conceal(true)
	for child: Node in get_children(): remove_child(child); child.free()
	cache.clear()
	current = null
