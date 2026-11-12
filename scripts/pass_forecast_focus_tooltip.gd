extends RefCounted

const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Ink = preload("res://scripts/turn_order_ink.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const ICON_SIZE: float = 22.0
const PORTRAIT_SIZE: float = 24.0

const FADE_SECONDS: float = 0.12
const Clock = preload("res://scripts/presentation_clock.gd")

class FadeDriver extends Node:
	var chip: Button
	var panel: Control
	var clock: Callable = Clock.ticks_usec.bind(false)
	var target: float = 0.0
	var from_alpha: float = 0.0
	var started_usec: int = 0

	func _init() -> void:
		set_process(false)

	func present(active: bool) -> void:
		var next: float = 1.0 if active else 0.0
		if target == next: return
		if is_processing(): sample(int(clock.call()))
		from_alpha = panel.modulate.a
		target = next
		started_usec = int(clock.call())
		if active: panel.show()
		set_process(true)
		sample(started_usec)

	func sample(now_usec: int) -> void:
		var progress: float = clampf(float(now_usec - started_usec) / (FADE_SECONDS * 1000000.0), 0.0, 1.0)
		var alpha: float = lerpf(from_alpha, target, progress)
		panel.modulate.a = alpha
		chip.set_meta("pass_forecast_alpha", alpha)
		sync_visibility()
		if progress >= 1.0:
			set_process(false)
			if target == 0.0: panel.hide()

	func sync_visibility() -> void:
		for badge: Control in chip.get_meta("forecast_fade_badges", []):
			if is_instance_valid(badge):
				badge.modulate.a = panel.modulate.a
				badge.visible = panel.is_visible_in_tree() and panel.modulate.a > 0.0

	func _process(_delta: float) -> void:
		sample(int(clock.call()))

# Retain the rail's authored mask without its moving-rail coverage callback.
# This tooltip portrait changes only when its row data changes.
class ForecastPortrait extends Ink.PortraitMask:
	func _enter_tree() -> void:
		pass

	func _ready() -> void:
		pass

# Presentation only: the simulation and its semantic narration stay unchanged.
static func rows(summary: Dictionary, portraits: Array[Dictionary], inks: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if int(summary.get("wait_time", 0)) > 0:
		result.append({"parts": [_part("time", "+%d" % int(summary["wait_time"]), Palette.GOLD_BRIGHT)]})
	var amounts: Dictionary = row_losses(summary)
	var losses: Array[Dictionary]
	for key: String in ["block", "stoneskin", "health"]:
		var loss: int = int(amounts[key])
		if loss <= 0: continue
		var text: String = "−%d" % loss
		if key == "health" and bool(summary.get("defeat", false)): text += " → 0"
		losses.append(_part(key, text, inks[key]))
	if losses.is_empty() and int(amounts["fatigue"]) == 0 and not bool(summary.get("defeat", false)):
		losses.append(_part("", "Safe", Palette.SUCCESS))
	if not losses.is_empty(): result.append({"parts": losses})
	for index: int in range(mini(2, portraits.size())):
		result.append({"portrait": portraits[index], "parts": [_part("", "×2", inks["unknown"]), _part("", "?", inks["unknown"])]})
	if int(amounts["fatigue"]) > 0:
		var text: String = "−%d" % int(amounts["fatigue"])
		if bool(summary.get("defeat", false)) and int(amounts["health"]) == 0: text += " → 0"
		result.append({"parts": [_part("fatigue", text, inks["health"])]})
	if int(summary.get("defiance_spent", 0)) > 0:
		var hp: int = int(summary.get("projected_hp", -1))
		var max_hp: int = int(summary.get("projected_max_hp", -1))
		result.append({"parts": [_part("defiance", "−%d → %s/%s" % [int(summary["defiance_spent"]), str(hp) if hp >= 0 else "?", str(max_hp) if max_hp > 0 else "?"], inks["defiance"])]})
	if bool(summary.get("umbra_unknown_before_player", false)):
		result.append({"parts": [_part("umbra", "?", inks["unknown"])]})
	if bool(summary.get("forecast_limit_reached", false)):
		result.append({"parts": [_part("turn_clock", "?", inks["unknown"])]})
	return result

# The summary retains gross receipts for existing semantic consumers. Its
# separate Health value nets healing against non-Fatigue loss, using actual HP
# removed by drawing; the Fatigue row always retains the uncapped applied cost.
static func row_losses(summary: Dictionary) -> Dictionary:
	var fatigue: int = maxi(0, int(summary.get("fatigue_loss", 0)))
	var health: int = maxi(0, int(summary.get("hp_loss", 0)))
	var before: int = int(summary.get("source_hp", -1))
	var after: int = int(summary.get("projected_hp", -1))
	if summary.has("non_fatigue_hp_loss"):
		health = maxi(0, int(summary["non_fatigue_hp_loss"]))
	elif before >= 0 and after >= 0:
		health = maxi(0, before - after - fatigue)
	elif summary.has("source_hp"):
		health = maxi(0, health - fatigue)
	if before >= 0: health = mini(health, before)
	return {"block": maxi(0, int(summary.get("block_loss", 0))), "stoneskin": maxi(0, int(summary.get("stoneskin_loss", 0))), "health": health, "fatigue": fatigue}

static func _part(icon: String, text: String, color: Color) -> Dictionary:
	return {"icon": icon, "text": text, "color": color}

static func configure(chip: Button, data: Array[Dictionary]) -> void:
	if chip.get_meta("forecast_rows", []) == data: return
	chip.set_meta("forecast_rows", data.duplicate(true))
	var panel: PanelContainer = chip.get_node_or_null("PassForecastFocusTooltip") as PanelContainer
	var fresh: bool = panel == null
	if fresh:
		panel = Tooltip._make_panel(0.0, 16.0)
		panel.name = "PassForecastFocusTooltip"
		panel.z_as_relative = false
		panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
		panel.modulate.a = 0.0
		panel.hide()
		chip.add_child(panel)
		panel.set_as_top_level(true)
		panel.resized.connect(_position.bind(chip, panel))
		var fade := FadeDriver.new()
		fade.name = "ForecastFade"
		fade.chip = chip
		fade.panel = panel
		panel.add_child(fade)
		panel.visibility_changed.connect(fade.sync_visibility)
	panel.set_meta("forecast_rows", data.duplicate(true))
	panel.set_meta("forecast_text", chip.tooltip_text)
	var column: VBoxContainer = panel.get_node_or_null("ForecastRows") as VBoxContainer
	if column == null:
		column = VBoxContainer.new()
		column.name = "ForecastRows"
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", Typography.SPACE_SMALL)
		panel.add_child(column)
	while column.get_child_count() > data.size():
		var obsolete: Node = column.get_child(column.get_child_count() - 1)
		column.remove_child(obsolete)
		obsolete.queue_free()
	for index: int in range(data.size()):
		var row_data: Dictionary = data[index]
		var row: HBoxContainer
		if index < column.get_child_count():
			row = column.get_child(index) as HBoxContainer
		else:
			row = HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", Typography.SPACE_SMALL)
			column.add_child(row)
		if row.get_meta("forecast_row", {}) == row_data: continue
		row.set_meta("forecast_row", row_data.duplicate(true))
		for child: Node in row.get_children():
			row.remove_child(child)
			child.queue_free()
		if row_data.has("portrait"):
			var mask := ForecastPortrait.new()
			mask.skew = Ink.SKEW_RATIO
			var portrait_size := Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE / float(row_data["portrait"]["aspect"]))
			mask.custom_minimum_size = portrait_size
			mask.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mask)
			var portrait: TextureRect = _icon(Assets.load_texture(str(row_data["portrait"]["path"])), 0.0)
			portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var bleed: Vector2 = portrait_size * (1.04 - 1.0) * 0.5
			portrait.offset_left = -bleed.x
			portrait.offset_top = -bleed.y
			portrait.offset_right = bleed.x
			portrait.offset_bottom = bleed.y
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			mask.add_child(portrait)
		for part: Dictionary in row_data["parts"]:
			if not str(part["icon"]).is_empty(): row.add_child(_icon(Icons.icon_texture(part["icon"]), ICON_SIZE))
			var value := RichTextLabel.new()
			value.bbcode_enabled = true
			value.fit_content = true
			value.scroll_active = false
			value.autowrap_mode = TextServer.AUTOWRAP_OFF
			value.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Typography.apply_rich_text_role(value, Typography.ROLE_BODY)
			value.add_theme_color_override("default_color", part["color"])
			value.text = "[b]%s[/b]" % str(part["text"])
			row.add_child(value)
	if fresh: Tooltip._finish_panel(panel)
	panel.reset_size()
	_position(chip, panel)

static func _icon(texture: Texture2D, pixels: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2.ONE * pixels
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

# Only an active fade ticks. Stable destinations and idle controls do no work.
static func refresh(chip: Button, active: bool) -> void:
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	if panel == null: return
	chip.set_meta("pass_forecast_active", active)
	(panel.get_node("ForecastFade") as FadeDriver).present(active)
	if active:
		panel.reset_size()
		_position(chip, panel)

static func _position(chip: Button, panel: Control) -> void:
	if not is_instance_valid(chip) or not is_instance_valid(panel) or not panel.is_inside_tree(): return
	var anchor: Rect2 = chip.get_global_rect()
	panel.global_position = Vector2(anchor.end.x - panel.size.x, anchor.position.y - panel.size.y)
