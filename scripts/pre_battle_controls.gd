extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const CardStrip = preload("res://scripts/ui_card_strip.gd")
const Socket = preload("res://scripts/ui_socket.gd")

class Foe:
	extends Button
	var host: Node
	var enemy: Dictionary
	var _glow: Texture2D = Surface.radial_texture(Color(Palette.EMBER, 0.12))

	func _init() -> void:
		Surface.clear_button_style(self)
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		pressed.connect(_inspect)

	func _inspect() -> void:
		if host != null and bool(host.call("_pre_battle_click_inspections_enabled")):
			host.call("_open_pinned_pre_battle_inspection", "enemy", str(enemy.get("type", "")), self, enemy)

	func _make_custom_tooltip(_text: String) -> Object:
		if not bool(host.call("_pre_battle_hover_inspections_enabled")):
			return host.call("_suppressed_pre_battle_tooltip")
		return host.call("_build_pre_battle_enemy_inspection_panel", enemy)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_inspect()
			accept_event()

	func _draw() -> void:
		if is_hovered() or has_focus():
			draw_texture_rect(_glow, Rect2(Vector2.ZERO, size), false)

class Strip:
	extends CardStrip
	var host: Node
	var source_kind: String

	func _layout() -> void:
		super._layout()
		custom_minimum_size.x = Typography.scaled_value(self, 190.0)

	func _init() -> void:
		super._init()
		pressed.connect(_inspect)

	func _inspect() -> void:
		if bool(host.call("_pre_battle_click_inspections_enabled")):
			host.call("_open_pinned_pre_battle_inspection", "card", card_id, self)

	func _make_custom_tooltip(_text: String) -> Object:
		if not bool(host.call("_pre_battle_hover_inspections_enabled")):
			return host.call("_suppressed_pre_battle_tooltip")
		return host.call("_build_card_tooltip_panel", card_id)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_inspect()
			accept_event()

class Gear:
	extends Socket
	var host: Node
	var equipment_id: String

	func _init() -> void:
		super._init()
		pressed.connect(_inspect)

	func _inspect() -> void:
		if not equipment_id.is_empty() and bool(host.call("_pre_battle_click_inspections_enabled")):
			host.call("_open_pinned_pre_battle_inspection", "equipment", equipment_id, self)

	func _make_custom_tooltip(_text: String) -> Object:
		if not bool(host.call("_pre_battle_hover_inspections_enabled")):
			return host.call("_suppressed_pre_battle_tooltip")
		return host.call("_build_equipment_tooltip_panel", equipment_id)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_inspect()
			accept_event()

class MoveTags:
	extends Container
	var base_overflow: int = 0
	var gap: float = 6.0
	var _overflow := Label.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overflow.name = "Overflow"
		Surface.label_style(_overflow, 14, Palette.TEXT_2)
		add_child(_overflow)

	func _get_minimum_size() -> Vector2:
		var height: float = 0.0
		for child: Control in get_children():
			height = maxf(height, child.get_combined_minimum_size().y)
		return Vector2(0.0, height)

	func _notification(what: int) -> void:
		if what != NOTIFICATION_SORT_CHILDREN:
			return
		var tags: Array = []
		var width: float = 0.0
		for child: Control in get_children():
			if child != _overflow:
				tags.append(child)
				width += child.get_combined_minimum_size().x
		var shown: int = tags.size()
		var total: float = 0.0
		var marker: String = ""
		var marker_width: float = 0.0
		var font: Font = _overflow.get_theme_font("font")
		var font_size: int = _overflow.get_theme_font_size("font_size")
		while true:
			var hidden: int = base_overflow + tags.size() - shown
			marker = "+%d" % hidden if hidden > 0 else ""
			marker_width = ceilf(font.get_string_size(marker, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
			total = width + maxi(0, shown - 1) * gap
			if hidden > 0:
				total += marker_width + (gap if shown > 0 else 0.0)
			if total <= size.x or shown == 0:
				break
			shown -= 1
			width -= (tags[shown] as Control).get_combined_minimum_size().x
		if _overflow.text != marker:
			_overflow.text = marker
		var left: float = maxf(0.0, (size.x - total) * 0.5)
		var height: float = get_minimum_size().y
		for index: int in range(tags.size()):
			var tag: Control = tags[index]
			tag.visible = index < shown
			if tag.visible:
				var tag_width: float = tag.get_combined_minimum_size().x
				fit_child_in_rect(tag, Rect2(left, 0.0, tag_width, height))
				left += tag_width + gap
		_overflow.visible = not _overflow.text.is_empty()
		if _overflow.visible:
			fit_child_in_rect(_overflow, Rect2(left, 0.0, marker_width, height))

class Rule:
	extends Control
	var vertical: bool = false
	var reverse: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for index: int in range(33):
			var t: float = float(index) / 32.0
			points.append(Vector2(size.x * 0.5, size.y * t) if vertical else Vector2(size.x * t, size.y * 0.5))
			var alpha: float = sin(PI * t) * 0.7 if vertical else (t if reverse else 1.0 - t) * 0.8
			colors.append(Color(Palette.GOLD_DIM, alpha))
		draw_polyline_colors(points, colors, Typography.scaled_value(self, 1.0), true)

class Plate:
	extends PanelContainer
	var top := Color(0.19, 0.05, 0.04, 0.96)
	var bottom := Color(0.065, 0.022, 0.018, 0.96)
	var border := Color(Palette.DANGER, 0.55)
	var radius: float = 2.0

	func _init() -> void:
		var style := StyleBoxEmpty.new()
		style.set_content_margin_all(6.0)
		add_theme_stylebox_override("panel", style)

	func _draw() -> void:
		Surface.draw_plate(self, Rect2(Vector2.ZERO, size), top, bottom, Typography.scaled_value(self, radius), border)

class PointerHint:
	extends Label

	func _ready() -> void:
		var router: Node = get_node_or_null("/root/InputRouter")
		if router != null:
			router.modality_changed.connect(_modality_changed)
			_modality_changed(str(router.call("modality")))

	func _modality_changed(modality: String) -> void:
		visible = modality == "pointer"
