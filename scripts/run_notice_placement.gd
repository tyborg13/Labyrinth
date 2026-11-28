extends RefCounted

const DIALOGUE_GAP: float = 16.0
const RECAP_GAP: float = 16.0
const RETURN_SECONDS: float = 0.2
# The recap's bottom button row; the Chronicle link sits higher, beside the score.
const RECAP_ACTIONS := ["NewRunButton", "MainMenuButton"]

var _notice: Control
var _stage: Control
var _home_offsets: Vector2
var _choice_lift: float
var _band_top: float = INF
var _dialogue_lift: float
var _return_tween: Tween
var _departure_recap: Control
var _recap_actions: Array[Control]

func bind_notice(notice: Control) -> void:
	_notice = notice
	_stage = notice.get_parent_control()
	_home_offsets = Vector2(notice.offset_top, notice.offset_bottom)
	_stage.item_rect_changed.connect(_layout)
	_notice.minimum_size_changed.connect(_layout)
	_layout()

func set_choice_lift(lift: float) -> void:
	_choice_lift = lift
	_layout()

func set_band_top(top: float) -> void:
	_band_top = top
	if not is_instance_valid(_notice) or not _notice.is_inside_tree(): return
	if is_finite(top):
		if _return_tween != null:
			_return_tween.kill()
			_return_tween = null
		_layout()
	elif _dialogue_lift > 0.0:
		_return_tween = _notice.create_tween()
		_return_tween.tween_method(_set_dialogue_lift, _dialogue_lift, 0.0, RETURN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_dialogue_lift(lift: float) -> void:
	_dialogue_lift = lift
	_layout()

static func recap_actions(recap: Control) -> Array[Control]:
	var actions: Array[Control]
	if is_instance_valid(recap):
		for action_name: String in RECAP_ACTIONS:
			var action := recap.find_child(action_name, true, false) as Control
			if action != null: actions.append(action)
	return actions

func set_departure_recap(recap: Control) -> void:
	if recap == _departure_recap: return
	for action in _recap_actions:
		if not is_instance_valid(action): continue
		action.item_rect_changed.disconnect(_layout)
		action.visibility_changed.disconnect(_layout)
	_departure_recap = recap
	_recap_actions = recap_actions(recap)
	for action in _recap_actions:
		action.item_rect_changed.connect(_layout)
		action.visibility_changed.connect(_layout)
	_layout()

func _recap_action_top() -> float:
	var top: float = INF
	for action in _recap_actions:
		if is_instance_valid(action) and action.is_visible_in_tree():
			top = minf(top, action.get_global_rect().position.y)
	return top

func _layout() -> void:
	if not is_instance_valid(_notice) or not _notice.is_inside_tree(): return
	if is_finite(_band_top):
		var canvas_limit := Vector2(0.0, _band_top - DIALOGUE_GAP)
		var local_limit: Vector2 = _stage.get_global_transform_with_canvas().affine_inverse() * canvas_limit
		var home_top: float = _stage.size.y * _notice.anchor_top + _home_offsets.x
		var home_bottom: float = _stage.size.y * _notice.anchor_bottom + _home_offsets.y
		home_bottom = maxf(home_bottom, home_top + _notice.get_combined_minimum_size().y)
		_dialogue_lift = maxf(0.0, home_bottom - _choice_lift - local_limit.y)
	var lift: float = _choice_lift + _dialogue_lift
	var recap_top := _recap_action_top()
	if is_finite(recap_top):
		# The rendered rect includes any growth for the label's minimum size.
		var stage_inverse := _stage.get_global_transform().affine_inverse()
		var current_bottom: Vector2 = stage_inverse * _notice.get_global_rect().end
		var target_bottom: Vector2 = stage_inverse * Vector2(0.0, recap_top - RECAP_GAP)
		lift = _home_offsets.y - _notice.offset_bottom + current_bottom.y - target_bottom.y
	_notice.offset_top = _home_offsets.x - lift
	_notice.offset_bottom = _home_offsets.y - lift
