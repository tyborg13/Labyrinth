extends PanelContainer
class_name ControllerPromptBar

const InputPromptScript = preload("res://scripts/input_prompt.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")

var _prompt_row: HBoxContainer

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
	for prompt_var: Variant in prompts:
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
	var snapshot: Array[Dictionary] = []
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
