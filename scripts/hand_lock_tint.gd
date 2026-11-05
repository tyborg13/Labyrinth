extends RefCounted

# Reuse the hand's existing closing-gap tint: cubic ease-out over 0.18 s.
# Keep logical card alphas intact while a refresh reads/updates interaction state.
const SECONDS: float = preload("res://scripts/hand_fan_container.gd").CLOSE_SLIDE_SECONDS
var _initialized: bool = false
var _locked: bool = false
var _tween: Tween
var _seconds: float = SECONDS
var _destinations: Dictionary = {}

func is_running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

func before_refresh(scene: Control) -> Dictionary:
	var running: bool = is_running()
	var remaining: float = maxf(0.0, _seconds - _tween.get_total_elapsed_time()) if running else SECONDS
	var locked: bool = bool(scene.get("_animation_lock"))
	var changed: bool = _initialized and locked != _locked
	var starts: Dictionary = {}
	var hand: Control = scene.get("hand_box")
	for index: int in range(hand.get_child_count()):
		var widget: Control = scene.call("_hand_card_control", index)
		if widget != null: starts[widget] = widget.modulate
	for widget: Variant in _destinations:
		if is_instance_valid(widget): (widget as Control).modulate = _destinations[widget]
	_initialized = true
	_locked = locked
	if (changed or running) and not scene.call("_reduced_motion_enabled"):
		return {"starts": starts, "changed": changed, "seconds": SECONDS if changed else remaining}
	_stop()
	return {}

func _stop() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null
	_destinations.clear()

func after_refresh(scene: Control, transition: Dictionary) -> void:
	if transition.is_empty(): return
	var hand: Control = scene.get("hand_box")
	var starts: Dictionary = transition["starts"]
	var targets: Dictionary = {}
	for entry: Variant in starts:
		if not is_instance_valid(entry): continue
		var widget: Control = entry
		if not is_instance_valid(widget) or not hand.is_ancestor_of(widget) or not widget.visible: continue
		var target: Color = widget.modulate
		if target.is_equal_approx(starts[widget]): continue
		targets[widget] = target
	# A retained refresh of the same destinations must not restart the curve or
	# extend its deadline. Only changed interaction targets need a new tween.
	if is_running() and not bool(transition["changed"]) and targets == _destinations:
		for widget: Control in targets: widget.modulate = starts[widget]
		return
	_stop()
	_seconds = float(transition["seconds"])
	for widget: Control in targets:
		if _tween == null:
			_tween = scene.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_destinations[widget] = targets[widget]
		widget.modulate = starts[widget]
		_tween.tween_property(widget, "modulate", targets[widget], _seconds)
	if _tween != null:
		_tween.chain().tween_callback(func() -> void:
			_destinations.clear()
			_tween = null
			# The lock cache must capture settled colors, never an in-flight tint.
			if bool(scene.get("_animation_lock")): scene.call("_begin_locked_hand_render_cache")
		)
