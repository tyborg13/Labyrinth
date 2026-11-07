extends RefCounted

const UiTooltipButton = preload("res://scripts/ui_tooltip_button.gd")

# Skill readiness and a spent Defiance update values on the existing focus
# targets. Ownership/compact-mode changes alone replace a sigil's structure.
static func reconcile(scene: Control, remaining: int, capacity: int, skills: Array[String], presentation: Dictionary, has_relics: bool) -> void:
	var host: Control = scene._relic_utility_bar
	if capacity <= 0:
		_remove(scene._defiance_badge)
		scene._defiance_badge = null
	elif not is_instance_valid(scene._defiance_badge):
		scene._defiance_badge = scene._build_defiance_badge(remaining, capacity)
		host.add_child(scene._defiance_badge)
	else:
		var badge: Control = scene._defiance_badge
		if int(badge.get_meta("defiance_remaining", -1)) != remaining or int(badge.get_meta("defiance_capacity", -1)) != capacity:
			scene._update_defiance_badge(badge, remaining, capacity)
	if is_instance_valid(scene._defiance_badge): host.move_child(scene._defiance_badge, 0)
	var divider: Control = host.get_node_or_null("DefianceUtilityDivider")
	if capacity > 0 and (not skills.is_empty() or has_relics):
		if divider == null:
			divider = scene._build_header_utility_divider("DefianceUtilityDivider")
			host.add_child(divider)
		host.move_child(divider, 1)
	else: _remove(divider)
	if skills.is_empty():
		_remove(scene._skill_sigil)
		scene._skill_sigil = null
		return
	var sigil: Button = scene._skill_sigil
	var compact: bool = bool(presentation.get("compact", false))
	if not is_instance_valid(sigil) or bool(sigil.get_meta("skill_sigil_compact", false)) != compact:
		_remove(sigil)
		sigil = scene._build_skill_sigil(skills, presentation)
		scene._skill_sigil = sigil
		host.add_child(sigil)
		return
	var ready: int = int(presentation.get("ready_count", 0))
	var ids: Array[String]
	for id: String in presentation.get("preview_ids", []): ids.append(id)
	sigil.set_meta("ready_count", ready)
	sigil.set_meta("owned_count", skills.size())
	sigil.set_meta("preview_skill_ids", ids)
	var summary: Label = sigil.find_child("SkillSigilSummary", true, false)
	summary.text = "%d READY / %d" % [ready, skills.size()] if compact else "%d READY  ·  %d OWNED" % [ready, skills.size()]
	var previews: Control = sigil.find_child("SkillSigilOwnedPreviews", true, false)
	var statuses: Dictionary = presentation.get("statuses", {})
	for child: Control in previews.get_children():
		if not ids.any(func(id: String) -> bool: return str(child.name) == "SkillSigilPreview_" + id): _remove(child)
	for index: int in range(ids.size()):
		var id: String = ids[index]
		var frame: PanelContainer = previews.get_node_or_null("SkillSigilPreview_" + id)
		if frame == null:
			frame = scene._build_skill_sigil_preview(id, statuses)
			previews.add_child(frame)
		var status: String = str(statuses.get(id, "PASSIVE"))
		if frame.get_meta("preview_status", "") != status:
			frame.add_theme_stylebox_override("panel", scene._skill_sigil_preview_style(scene._skill_status_accent(status)))
			scene.CombatHudBadgeBackground.refresh(frame)
			frame.set_meta("preview_status", status)
		previews.move_child(frame, index)

static func _remove(control: Control) -> void:
	if not is_instance_valid(control): return
	if control.get_parent() != null: control.get_parent().remove_child(control)
	control.queue_free()

static func fit_sigil(button: Button, content: Control, base_size: Vector2) -> void:
	# A Button does not inherit the minimum size of its child containers.
	button.custom_minimum_size = base_size.max(content.get_combined_minimum_size())

static func begin_commands(bar: Control) -> void:
	bar.set_meta("command_count", 0)
	for child: Control in bar.get_children(): child.set_meta("command_used", false)

static func command_button(bar: Control, text: String) -> UiTooltipButton:
	var button: UiTooltipButton = bar.get_node_or_null("ActionContext" + text.replace(" ", ""))
	if button == null: button = preload("res://scripts/ui_tooltip_button.gd").new()
	button.set_meta("command_used", true)
	return button

static func bind_command(button: Button, callback: Callable) -> void:
	var previous: Callable = button.get_meta("command_callback", Callable())
	if previous == callback: return
	if previous.is_valid() and button.pressed.is_connected(previous): button.pressed.disconnect(previous)
	button.pressed.connect(callback)
	button.set_meta("command_callback", callback)

static func place_command(bar: Control, button: Button) -> void:
	if button.get_parent() == null: bar.add_child(button)
	bar.move_child(button, int(bar.get_meta("command_count", 0)))
	bar.set_meta("command_count", int(bar.get_meta("command_count", 0)) + 1)

static func finish_commands(bar: Control) -> void:
	for child: Control in bar.get_children():
		if not child.get_meta("command_used", false): _remove(child)
