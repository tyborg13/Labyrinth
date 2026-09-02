extends Control
class_name ContextualCombatPrompt

signal completed(phase_id: String)
signal skipped(phase_id: String)

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const InputPromptScript = preload("res://scripts/input_prompt.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const CALLOUT_MIN_SIZE: Vector2 = Vector2(430.0, 194.0)
const CALLOUT_MARGIN: float = 24.0
const CALLOUT_TARGET_GAP: float = 22.0
const SPOTLIGHT_GROW: float = 3.0
const SPOTLIGHT_CORNER: float = 16.0
const MAX_SPOTLIGHTS: int = 24

var _ui_skin: UiSkin = UiSkin.new()
var _phase_id: String = ""
var _definition: Dictionary = {}
var _spotlight_rects: Array = []
var _evidence_rects: Array = []
var _avoid_rects: Array = []
var _reduced_motion: bool = false
var _blocked_until_msec: int = 0
var _blocked_count: int = 0
var _completion_requested: bool = false

var _callout: PanelContainer
var _icon_frame: PanelContainer
var _icon: TextureRect
var _progress_label: Label
var _progress_segments: Array = []
var _kicker: Label
var _title: Label
var _message: Label
var _pointer_action: Label
var _controller_action
var _feedback: Label
var _continue_button: Button
var _skip_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build()
	_connect_input_router()
	clear_prompt()
	set_process(true)

func configure(
	definition: Dictionary,
	spotlight_rects: Array = [],
	avoid_rects: Array = [],
	reduced_motion: bool = false
) -> void:
	if _callout == null:
		_build()
	var next_phase_id: String = str(definition.get("id", ""))
	var phase_changed: bool = next_phase_id != _phase_id
	_definition = definition.duplicate(true)
	_phase_id = next_phase_id
	if phase_changed:
		_blocked_until_msec = 0
		_feedback.visible = false
		_completion_requested = false
	_reduced_motion = reduced_motion
	_spotlight_rects = _normalized_rects(spotlight_rects)
	_avoid_rects = _normalized_rects(avoid_rects)
	var icon_key: String = str(_definition.get("icon", ""))
	_icon_frame.visible = not icon_key.is_empty()
	_icon.texture = ActionIcons.icon_texture(icon_key) if not icon_key.is_empty() else null
	_kicker.text = str(_definition.get("kicker", "GUIDED RUN"))
	_title.text = str(_definition.get("title", "Your Next Action"))
	_progress_label.text = "GUIDED RUN  •  %d / %d" % [
		int(_definition.get("lesson", 1)),
		int(_definition.get("lesson_total", 1)),
	]
	_continue_button.visible = bool(_definition.get("requires_continue", false))
	_continue_button.text = str(_definition.get("continue_text", "Continue"))
	_skip_button.visible = _phase_id != "complete"
	# The final acknowledgement sits over an existing full-screen pre-battle
	# modal. Own that input plane explicitly so its Begin button cannot lose the
	# pointer to the modal beneath it. Gameplay phases remain click-through.
	mouse_filter = Control.MOUSE_FILTER_STOP if _phase_id == "complete" else Control.MOUSE_FILTER_IGNORE
	_refresh_progress_segments()
	_refresh_modality()
	set_meta("prompt_id", _phase_id)
	set_meta("prompt_text", _message.text)
	set_meta("spotlight_rects", _spotlight_rects.duplicate())
	set_meta("reduced_motion", _reduced_motion)
	set_meta("attention_pulse", bool(_definition.get("attention_pulse", false)))
	visible = not _phase_id.is_empty()
	call_deferred("_layout_callout")
	queue_redraw()

func update_geometry(spotlight_rects: Array, avoid_rects: Array = []) -> void:
	var next_spotlights: Array = _normalized_rects(spotlight_rects)
	var next_avoid_rects: Array = _normalized_rects(avoid_rects)
	if next_spotlights == _spotlight_rects and next_avoid_rects == _avoid_rects:
		return
	_spotlight_rects = next_spotlights
	_avoid_rects = next_avoid_rects
	set_meta("spotlight_rects", _spotlight_rects.duplicate())
	_layout_callout()
	queue_redraw()

func set_evidence_rects(evidence_rects: Array) -> void:
	var next_evidence: Array = _normalized_rects(evidence_rects)
	if next_evidence == _evidence_rects:
		return
	_evidence_rects = next_evidence
	set_meta("evidence_rects", _evidence_rects.duplicate())
	_layout_callout()
	queue_redraw()

func clear_prompt() -> void:
	_phase_id = ""
	_definition.clear()
	_spotlight_rects.clear()
	_evidence_rects.clear()
	_avoid_rects.clear()
	_blocked_until_msec = 0
	_completion_requested = false
	if _feedback != null:
		_feedback.visible = false
	set_meta("prompt_id", "")
	set_meta("spotlight_rects", [])
	set_meta("spotlight_hole_count", 0)
	set_meta("spotlight_frame_count", 0)
	set_meta("spotlight_frame_rects", [])
	set_meta("spotlight_glow_count", 0)
	set_meta("spotlight_pulse_border_count", 0)
	set_meta("evidence_rects", [])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	queue_redraw()

func active_prompt_id() -> String:
	return _phase_id

func show_blocked(message: String = "Follow the highlighted action.") -> void:
	if not visible:
		return
	_blocked_count += 1
	_blocked_until_msec = Time.get_ticks_msec() + 900
	_feedback.text = message
	_feedback.visible = true
	set_meta("blocked_count", _blocked_count)
	queue_redraw()

func focus_primary_action() -> void:
	if not visible:
		return
	if _continue_button.visible:
		_continue_button.grab_focus()
	elif _skip_button.visible:
		_skip_button.grab_focus()

func _process(_delta: float) -> void:
	if not visible:
		return
	if _feedback.visible and Time.get_ticks_msec() >= _blocked_until_msec:
		_feedback.visible = false
	if not _reduced_motion or _feedback.visible:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if (
		_phase_id != "complete"
		or _continue_button == null
		or not _continue_button.visible
		or not (event is InputEventMouseButton)
	):
		return
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event.button_index == MOUSE_BUTTON_LEFT
		and mouse_event.pressed
		and _continue_button.get_global_rect().has_point(mouse_event.position)
	):
		_on_completed_pressed()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		call_deferred("_layout_callout")
		queue_redraw()

func _draw() -> void:
	if not visible or size.x <= 1.0 or size.y <= 1.0:
		return
	var local_spotlights: Array = []
	for global_rect: Rect2 in _spotlight_rects:
		var local_rect := Rect2(global_rect.position - global_position, global_rect.size).grow(SPOTLIGHT_GROW)
		local_rect = local_rect.intersection(Rect2(Vector2.ZERO, size))
		if local_rect.has_area():
			local_spotlights.append(local_rect)
	var local_evidence: Array = []
	for global_rect: Rect2 in _evidence_rects:
		var local_rect := Rect2(global_rect.position - global_position, global_rect.size).grow(SPOTLIGHT_GROW)
		local_rect = local_rect.intersection(Rect2(Vector2.ZERO, size))
		if local_rect.has_area():
			local_evidence.append(local_rect)
	var holes: Array = local_spotlights.duplicate()
	holes.append_array(local_evidence)
	_draw_dimmer_with_holes(holes)
	var frame_spotlights: Array = local_spotlights.duplicate()
	set_meta("spotlight_hole_count", holes.size())
	set_meta("spotlight_frame_count", frame_spotlights.size())
	set_meta("spotlight_frame_rects", _global_spotlight_rects(frame_spotlights))
	var pulse: float = 1.0 if _reduced_motion else 0.78 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.005)
	var blocked: bool = Time.get_ticks_msec() < _blocked_until_msec
	var accent: Color = Color("e7775c") if blocked else Color("f0bd63")
	var attention_pulse: bool = bool(_definition.get("attention_pulse", false))
	# Keep tutorial emphasis outside the target. A filled wash changes the
	# board/card art underneath it and can read like a screen-wide color filter.
	set_meta("spotlight_glow_count", 0)
	set_meta("spotlight_pulse_border_count", frame_spotlights.size() if attention_pulse else 0)
	for rect: Rect2 in frame_spotlights:
		_draw_spotlight_frame(rect, accent, pulse if attention_pulse else 1.0)

func _global_spotlight_rects(local_rects: Array) -> Array:
	var result: Array = []
	for rect_var: Variant in local_rects:
		if typeof(rect_var) != TYPE_RECT2:
			continue
		var rect: Rect2 = rect_var
		result.append(Rect2(rect.position + global_position, rect.size))
	return result

func _draw_dimmer_with_holes(holes: Array) -> void:
	if holes.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.018, 0.025, 0.76))
		return
	var xs: Array = [0.0, size.x]
	var ys: Array = [0.0, size.y]
	for hole: Rect2 in holes:
		xs.append(clampf(hole.position.x, 0.0, size.x))
		xs.append(clampf(hole.end.x, 0.0, size.x))
		ys.append(clampf(hole.position.y, 0.0, size.y))
		ys.append(clampf(hole.end.y, 0.0, size.y))
	xs.sort()
	ys.sort()
	for x_index: int in range(xs.size() - 1):
		for y_index: int in range(ys.size() - 1):
			var cell := Rect2(
				Vector2(xs[x_index], ys[y_index]),
				Vector2(xs[x_index + 1] - xs[x_index], ys[y_index + 1] - ys[y_index])
			)
			if cell.size.x <= 0.0 or cell.size.y <= 0.0:
				continue
			var inside_hole: bool = false
			for hole: Rect2 in holes:
				if hole.has_point(cell.get_center()):
					inside_hole = true
					break
			if not inside_hole:
				draw_rect(cell, Color(0.025, 0.018, 0.025, 0.76))

func _draw_spotlight_frame(rect: Rect2, accent: Color, pulse: float) -> void:
	var halo_alpha: float = 0.10 + 0.13 * pulse
	var halo_distance: float = 2.0 if _reduced_motion else 2.0 + 3.0 * pulse
	draw_rect(rect.grow(halo_distance), Color(accent.r, accent.g, accent.b, halo_alpha), false, 3.0)
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.94), false, 2.5)
	var corner: float = minf(SPOTLIGHT_CORNER, minf(rect.size.x, rect.size.y) * 0.30)
	for corner_data: Dictionary in [
		{"point": rect.position, "x": Vector2(corner, 0.0), "y": Vector2(0.0, corner)},
		{"point": Vector2(rect.end.x, rect.position.y), "x": Vector2(-corner, 0.0), "y": Vector2(0.0, corner)},
		{"point": rect.end, "x": Vector2(-corner, 0.0), "y": Vector2(0.0, -corner)},
		{"point": Vector2(rect.position.x, rect.end.y), "x": Vector2(corner, 0.0), "y": Vector2(0.0, -corner)},
	]:
		var point: Vector2 = corner_data["point"]
		draw_line(point, point + (corner_data["x"] as Vector2), accent.lightened(0.20), 4.0)
		draw_line(point, point + (corner_data["y"] as Vector2), accent.lightened(0.20), 4.0)

func _build() -> void:
	if _callout != null:
		return
	_callout = PanelContainer.new()
	_callout.name = "GuidedActionCallout"
	_callout.custom_minimum_size = CALLOUT_MIN_SIZE
	_callout.mouse_filter = Control.MOUSE_FILTER_STOP
	_callout.z_index = 2
	_callout.set_meta("panel_surface_accent", Color("d9aa58"))
	_ui_skin.apply_inset_surface(_callout, UiSkin.SURFACE_HUD)
	add_child(_callout)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_callout.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	column.add_child(progress_row)
	_progress_label = Label.new()
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(_progress_label, UiTypography.ROLE_CAPTION)
	_progress_label.add_theme_color_override("font_color", Color("d6bb8a"))
	progress_row.add_child(_progress_label)
	var segments := HBoxContainer.new()
	segments.add_theme_constant_override("separation", 3)
	progress_row.add_child(segments)
	for _index: int in range(10):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(18.0, 4.0)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segments.add_child(segment)
		_progress_segments.append(segment)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	column.add_child(heading)
	_icon_frame = PanelContainer.new()
	_icon_frame.custom_minimum_size = Vector2(44.0, 44.0)
	_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_frame.add_theme_stylebox_override("panel", _icon_style())
	heading.add_child(_icon_frame)
	var icon_center := CenterContainer.new()
	_icon_frame.add_child(icon_center)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(32.0, 32.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(_icon)

	var heading_copy := VBoxContainer.new()
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_copy.add_theme_constant_override("separation", 0)
	heading.add_child(heading_copy)
	_kicker = Label.new()
	UiTypography.apply_label_role(_kicker, UiTypography.ROLE_CAPTION)
	_kicker.add_theme_color_override("font_color", Color("efbd66"))
	_kicker.add_theme_color_override("font_outline_color", Color("21150f"))
	_kicker.add_theme_constant_override("outline_size", 2)
	heading_copy.add_child(_kicker)
	_title = Label.new()
	UiTypography.apply_label_role(_title, UiTypography.ROLE_SECTION)
	_title.add_theme_color_override("font_color", Color("fff0d2"))
	_title.add_theme_color_override("font_outline_color", Color("21150f"))
	_title.add_theme_constant_override("outline_size", 2)
	heading_copy.add_child(_title)

	_message = Label.new()
	_message.custom_minimum_size = Vector2(0.0, 44.0)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(_message, UiTypography.ROLE_BODY)
	_message.add_theme_color_override("font_color", Color("f2dfbf"))
	_message.add_theme_color_override("font_outline_color", Color("1d130f"))
	_message.add_theme_constant_override("outline_size", 2)
	column.add_child(_message)

	_feedback = Label.new()
	_feedback.text = "Follow the highlighted action."
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(_feedback, UiTypography.ROLE_CAPTION)
	_feedback.add_theme_color_override("font_color", Color("f28c73"))
	column.add_child(_feedback)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	_pointer_action = Label.new()
	_pointer_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pointer_action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.apply_label_role(_pointer_action, UiTypography.ROLE_CAPTION)
	_pointer_action.add_theme_color_override("font_color", Color("d8be91"))
	footer.add_child(_pointer_action)
	_controller_action = InputPromptScript.new()
	_controller_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_controller_action)
	_continue_button = _small_button("Continue")
	_continue_button.pressed.connect(_on_completed_pressed)
	footer.add_child(_continue_button)
	_skip_button = _small_button("Skip Tutorial")
	_skip_button.modulate = Color(1.0, 1.0, 1.0, 0.78)
	_skip_button.pressed.connect(_on_skipped_pressed)
	footer.add_child(_skip_button)
	_continue_button.focus_neighbor_left = _skip_button.get_path()
	_continue_button.focus_neighbor_right = _skip_button.get_path()
	_skip_button.focus_neighbor_left = _continue_button.get_path()
	_skip_button.focus_neighbor_right = _continue_button.get_path()

func _small_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(108.0, UiSkin.BUTTON_HEIGHT_SMALL)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.apply_button_role(button, UiTypography.ROLE_BODY)
	return button

func _icon_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("120d0b")
	style.border_color = Color("8c673a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style

func _connect_input_router() -> void:
	var router: Node = get_node_or_null("/root/InputRouter")
	if router == null:
		return
	if router.has_signal("modality_changed") and not router.modality_changed.is_connected(_on_modality_changed):
		router.modality_changed.connect(_on_modality_changed)
	if router.has_signal("controller_family_changed") and not router.controller_family_changed.is_connected(_on_controller_family_changed):
		router.controller_family_changed.connect(_on_controller_family_changed)

func _on_modality_changed(_modality: String) -> void:
	_refresh_modality()

func _on_controller_family_changed(_family: String) -> void:
	_refresh_modality()

func _refresh_modality() -> void:
	if _message == null or _definition.is_empty():
		return
	var controller_active: bool = false
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null and router.has_method("using_controller"):
		controller_active = bool(router.call("using_controller"))
	_message.text = str(_definition.get("controller_text" if controller_active else "pointer_text", ""))
	_pointer_action.text = "HIGHLIGHTED ACTION"
	_pointer_action.visible = not controller_active and not bool(_definition.get("requires_continue", false))
	_controller_action.visible = controller_active and not bool(_definition.get("requires_continue", false))
	if _controller_action.visible:
		_controller_action.call(
			"configure",
			StringName(str(_definition.get("controller_action", "controller_accept"))),
			str(_definition.get("action_label", "Select"))
		)
	set_meta("prompt_text", _message.text)
	set_meta("controller_active", controller_active)
	if controller_active and _continue_button.visible:
		call_deferred("focus_primary_action")

func _refresh_progress_segments() -> void:
	var lesson: int = int(_definition.get("lesson", 1))
	for index: int in range(_progress_segments.size()):
		var segment: ColorRect = _progress_segments[index]
		if index + 1 < lesson:
			segment.color = Color("9b7744")
		elif index + 1 == lesson:
			segment.color = Color("f0bd63")
		else:
			segment.color = Color(0.28, 0.22, 0.17, 0.78)

func _layout_callout() -> void:
	if _callout == null or not visible or size.x <= 1.0 or size.y <= 1.0:
		return
	var desired_size: Vector2 = _callout.get_combined_minimum_size()
	desired_size.x = maxf(CALLOUT_MIN_SIZE.x, desired_size.x)
	desired_size.y = maxf(CALLOUT_MIN_SIZE.y, desired_size.y)
	var safe := Rect2(
		Vector2(CALLOUT_MARGIN, CALLOUT_MARGIN),
		Vector2(maxf(0.0, size.x - CALLOUT_MARGIN * 2.0), maxf(0.0, size.y - CALLOUT_MARGIN * 2.0))
	)
	var focus_bounds: Rect2 = _global_rect_union(_spotlight_rects)
	if focus_bounds.has_area():
		focus_bounds.position -= global_position
	var candidates: Array = []
	if focus_bounds.has_area():
		candidates = [
			Vector2(focus_bounds.end.x + CALLOUT_TARGET_GAP, focus_bounds.get_center().y - desired_size.y * 0.5),
			Vector2(focus_bounds.position.x - desired_size.x - CALLOUT_TARGET_GAP, focus_bounds.get_center().y - desired_size.y * 0.5),
			Vector2(focus_bounds.get_center().x - desired_size.x * 0.5, focus_bounds.position.y - desired_size.y - CALLOUT_TARGET_GAP),
			Vector2(focus_bounds.get_center().x - desired_size.x * 0.5, focus_bounds.end.y + CALLOUT_TARGET_GAP),
		]
	candidates.append(Vector2(safe.position.x, safe.get_center().y - desired_size.y * 0.5))
	candidates.append(Vector2(safe.end.x - desired_size.x, safe.get_center().y - desired_size.y * 0.5))
	candidates.append(Vector2(safe.get_center().x - desired_size.x * 0.5, safe.position.y))
	candidates.append(Vector2(safe.get_center().x - desired_size.x * 0.5, safe.end.y - desired_size.y))
	var chosen: Vector2 = safe.get_center() - desired_size * 0.5
	var best_score: float = INF
	for candidate: Vector2 in candidates:
		var rect := Rect2(candidate, desired_size)
		if not safe.encloses(rect):
			continue
		var score: float = 0.0
		if focus_bounds.has_area():
			score += rect.intersection(focus_bounds.grow(10.0)).get_area() * 100.0
			score += rect.get_center().distance_to(focus_bounds.get_center()) * 0.05
		for global_avoid: Rect2 in _avoid_rects:
			var local_avoid := Rect2(global_avoid.position - global_position, global_avoid.size)
			score += rect.intersection(local_avoid).get_area() * 12.0
		if score < best_score:
			best_score = score
			chosen = candidate
	_callout.position = chosen
	_callout.size = desired_size
	set_meta("callout_rect", Rect2(_callout.global_position, _callout.size))
	queue_redraw()

func _normalized_rects(values: Array) -> Array:
	var result: Array = []
	for rect_var: Variant in values:
		if typeof(rect_var) != TYPE_RECT2:
			continue
		var rect: Rect2 = rect_var
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		result.append(rect)
		if result.size() >= MAX_SPOTLIGHTS:
			break
	return result

func _global_rect_union(rects: Array) -> Rect2:
	var result := Rect2()
	var has_result: bool = false
	for rect_var: Variant in rects:
		if typeof(rect_var) != TYPE_RECT2:
			continue
		var rect: Rect2 = rect_var
		if not rect.has_area():
			continue
		result = rect if not has_result else result.merge(rect)
		has_result = true
	return result

func _on_completed_pressed() -> void:
	if _phase_id.is_empty() or _completion_requested:
		return
	_completion_requested = true
	completed.emit(_phase_id)

func _on_skipped_pressed() -> void:
	if not _phase_id.is_empty():
		skipped.emit(_phase_id)
