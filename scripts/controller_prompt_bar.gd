extends PanelContainer
class_name ControllerPromptBar

const InputPromptScript = preload("res://scripts/input_prompt.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const BOSS_FRAME_GAP: float = 6.0

var _prompt_row: HBoxContainer
var _undo_available: bool = false
var _boss_frame: Control
var _below_boss: bool = false

func place_below_boss_health_frame(frame: Control) -> void:
	if frame != _boss_frame:
		if is_instance_valid(_boss_frame):
			_boss_frame.item_rect_changed.disconnect(_place_below_boss)
			_boss_frame.visibility_changed.disconnect(_place_below_boss)
		_boss_frame = frame
		if is_instance_valid(frame):
			frame.item_rect_changed.connect(_place_below_boss)
			frame.visibility_changed.connect(_place_below_boss)
	_place_below_boss()

func _place_below_boss() -> void:
	if is_instance_valid(_boss_frame) and _boss_frame.is_visible_in_tree():
		# Both surfaces use UI coordinates; the viewport applies resolution/UI scale.
		var bottom: Vector2 = _boss_frame.get_global_transform() * Vector2(0, _boss_frame.size.y)
		var local_bottom: Vector2 = (get_parent() as Control).get_global_transform().affine_inverse() * bottom
		anchor_top = 0.0
		anchor_bottom = 0.0
		anchor_left = 0.5
		anchor_right = 0.5
		offset_top = local_bottom.y + BOSS_FRAME_GAP
		offset_bottom = offset_top
		_below_boss = true
	elif _below_boss:
		if is_zero_approx(anchor_top):
			offset_top = 14.0
			offset_bottom = offset_top
		_below_boss = false

const GUIDED_REWARD_PANEL_GAP: float = 12.0

var _guided_reward_panel: Control
var _guided_reward_frame_padding: float = 0.0
var _below_guided_reward: bool = false

func place_below_guided_reward_panel(panel: Control, frame_padding: float = 0.0) -> void:
	if panel != _guided_reward_panel:
		if is_instance_valid(_guided_reward_panel):
			_guided_reward_panel.item_rect_changed.disconnect(refresh_guided_reward_placement)
			_guided_reward_panel.visibility_changed.disconnect(refresh_guided_reward_placement)
		_guided_reward_panel = panel
		if is_instance_valid(panel):
			panel.item_rect_changed.connect(refresh_guided_reward_placement)
			panel.visibility_changed.connect(refresh_guided_reward_placement)
	_guided_reward_frame_padding = frame_padding
	refresh_guided_reward_placement()

func is_below_guided_reward_panel() -> bool:
	return _below_guided_reward

func refresh_guided_reward_placement() -> void:
	if visible and is_instance_valid(_guided_reward_panel) and _guided_reward_panel.is_visible_in_tree():
		# Match the boss-frame placement hook: use UI coordinates, then let
		# the viewport apply resolution and UI scale. Include the visible
		# tutorial frame rather than seating the bar against its border.
		var bottom: Vector2 = _guided_reward_panel.get_global_transform() * Vector2(0.0, _guided_reward_panel.size.y + _guided_reward_frame_padding)
		var local_bottom: Vector2 = (get_parent() as Control).get_global_transform().affine_inverse() * bottom
		anchor_top = 0.0
		anchor_bottom = 0.0
		anchor_left = 0.5
		anchor_right = 0.5
		offset_top = local_bottom.y + GUIDED_REWARD_PANEL_GAP
		offset_bottom = offset_top
		_below_guided_reward = true
	elif _below_guided_reward:
		if is_zero_approx(anchor_top):
			offset_top = 14.0
			offset_bottom = offset_top
		_below_guided_reward = false

func set_undo_available(available: bool) -> void:
	_undo_available = available

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 2200
	add_theme_stylebox_override("panel", _panel_style())
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	_prompt_row = HBoxContainer.new()
	_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_row.add_theme_constant_override("separation", 14)
	margin.add_child(_prompt_row)
	_connect_router()
	_sync_visibility()

func set_prompts(prompts: Array) -> void:
	if _prompt_row == null:
		call_deferred("set_prompts", prompts)
		return
	for child: Node in _prompt_row.get_children():
		child.queue_free()
	var displayed: Array = prompts.duplicate(true)
	if _undo_available:
		displayed.append({"action": InputRouterScript.ACTION_UNDO_MOVE, "label": "Undo move"})
	for prompt_var: Variant in displayed:
		if typeof(prompt_var) != TYPE_DICTIONARY:
			continue
		var prompt_data: Dictionary = prompt_var
		var action_name := StringName(str(prompt_data.get("action", "")))
		var label_text: String = str(prompt_data.get("label", ""))
		if action_name.is_empty() or label_text.is_empty():
			continue
		var prompt = InputPromptScript.new()
		prompt.configure(action_name, label_text)
		_prompt_row.add_child(prompt)
	queue_sort()

func prompts_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary]
	if _prompt_row == null:
		return snapshot
	for child: Node in _prompt_row.get_children():
		if child.get_script() == InputPromptScript:
			var prompt = child
			snapshot.append({"action": str(prompt.action_name), "label": prompt.label_text})
	return snapshot

func _connect_router() -> void:
	var router: Node = get_node_or_null("/root/InputRouter")
	if router == null:
		return
	if router.has_signal("modality_changed") and not router.modality_changed.is_connected(_on_modality_changed):
		router.modality_changed.connect(_on_modality_changed)

func _on_modality_changed(_modality: String) -> void:
	_sync_visibility()

func _sync_visibility() -> void:
	var router: Node = get_node_or_null("/root/InputRouter")
	visible = router != null and router.has_method("using_controller") and bool(router.call("using_controller"))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.028, 0.034, 0.94)
	style.border_color = Color("8f6a39")
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 8
	return style
