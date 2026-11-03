extends Control
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Ghost = preload("res://scripts/health_ghost_tracker.gd")
const WIDTH: float = 240.0
const BAR_HEIGHT: float = 12.0 # YOUR KIT Health.
const GHOST_TINT: Color = Ghost.ENEMY_GHOST_COLOR # Existing pale-red combat ghost.
const NUMBER_SCALE: float = 0.8
const NUMBER_MAX_RISE: float = 34.0
var panel_bounds: Rect2
var hp: float = 0
var cap: float = 1
var ghost_hp: float = 0
var ghost_alpha: float = 0
var flash: Color = Color.TRANSPARENT
var _numbers: Label
var _bar: ProgressBar
var _ghost: ProgressBar
var _motion: Tween
var _ghost_motion: Tween
var _flash_motion: Tween
var _popups: Array[Control]
var _empty_style := StyleBoxEmpty.new()
var _bars: Array[ProgressBar]
var _background_showing: bool = false
var _number_hp: int = -1
var _number_cap: int = -1
var _flash_overlay: ColorRect

func _ready() -> void:
	name = "EventHealth"
	size = Vector2(WIDTH, Typography.SIZE_BODY_LARGE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Icons.icon_texture("health")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2.ONE * Typography.SIZE_BODY_LARGE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	_numbers = Label.new()
	Typography.set_label_size(_numbers, 19)
	_numbers.add_theme_color_override("font_color", Palette.ALLY)
	_numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_numbers)
	for index: int in range(2):
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Surface.style_kit_health_bar(bar, GHOST_TINT if index == 0 else Palette.ALLY)
		add_child(bar)
		_bars.append(bar)
		if index == 0: _ghost = bar
		else: _bar = bar; _bar.add_theme_stylebox_override("background", _empty_style)
	_flash_overlay = ColorRect.new()
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color.TRANSPARENT
	add_child(_flash_overlay)
	_numbers.move_to_front()
	_update()

func set_health(value: float, maximum: float) -> void:
	hp = value
	cap = maxf(1, maximum)
	_update()

func _update() -> void:
	if _numbers == null: return
	if roundi(hp) != _number_hp or roundi(cap) != _number_cap:
		_number_hp = roundi(hp)
		_number_cap = roundi(cap)
		_numbers.text = "%d / %d" % [_number_hp, _number_cap]
		_numbers.size = _numbers.get_combined_minimum_size()
		_numbers.position = Vector2(WIDTH - _numbers.size.x, (size.y - _numbers.size.y) * 0.5)
	var origin := Vector2(Typography.SIZE_BODY_LARGE, (size.y - BAR_HEIGHT) * 0.5)
	var extent := Vector2(maxf(0, _numbers.position.x - origin.x), BAR_HEIGHT)
	for bar: ProgressBar in _bars:
		bar.position = origin
		bar.size = extent
		bar.max_value = cap
	_flash_overlay.position = origin
	_flash_overlay.size = extent
	_bar.value = hp
	_ghost.value = maxf(hp, ghost_hp)
	_ghost.modulate.a = ghost_alpha
	# Background remains visible when the damage ghost is absent.
	if _background_showing != (ghost_alpha <= 0):
		_background_showing = ghost_alpha <= 0
		_bar.add_theme_stylebox_override("background", _ghost.get_theme_stylebox("background") if _background_showing else _empty_style)
	queue_redraw()

func beat(kind: String, amount: int, reduced: bool, resolved_hp: float = -1, resolved_cap: float = -1) -> void:
	if _motion != null: _motion.kill()
	_motion = null
	var old_hp: float = hp
	var old_cap: float = cap
	var target_hp: float = hp
	var target_cap: float = cap
	if kind == "max_hp":
		target_cap = maxf(1, cap + amount)
		target_hp = minf(target_cap, hp + maxi(0, amount))
	else: target_hp = clampf(hp + amount, 1, cap)
	if resolved_hp >= 0: target_hp = resolved_hp
	if resolved_cap > 0: target_cap = resolved_cap
	if reduced:
		set_health(target_hp, target_cap)
	else:
		if kind == "max_hp":
			_motion = create_tween()
			_motion.tween_method(func(value: float) -> void: set_health(lerpf(old_hp, target_hp, value), lerpf(old_cap, target_cap, value)), 0.0, 1.0, 0.25)
			flash = Palette.GOLD if amount > 0 else Palette.DANGER
			if _flash_motion != null: _flash_motion.kill()
			_flash_motion = create_tween()
			_flash_motion.tween_method(func(value: float) -> void: flash.a = value; queue_redraw(), 1.0, 0.0, 0.25)
		elif amount < 0:
			if _ghost_motion != null: _ghost_motion.kill()
			ghost_hp = maxf(old_hp, ghost_hp)
			ghost_alpha = 1
			set_health(target_hp, cap)
			_ghost_motion = create_tween()
			_ghost_motion.tween_interval(0.20)
			_ghost_motion.tween_method(func(value: float) -> void: ghost_hp = value; _update(), ghost_hp, target_hp, 0.35)
			_ghost_motion.tween_callback(func() -> void: ghost_alpha = 0; _update())
		else:
			_motion = create_tween()
			_motion.tween_method(func(value: float) -> void: set_health(value, cap), hp, target_hp, 0.35)
	_spawn_number(("%+d max" if kind == "max_hp" else "%+d") % amount, Palette.GOLD if kind == "max_hp" and amount > 0 else Palette.DANGER if amount < 0 else Palette.ALLY, reduced)

func _spawn_number(text: String, tint: Color, reduced: bool) -> void:
	var entry: Dictionary = Floating.damage_entry(Vector2i.ZERO, text, tint, {"hit_scale": 1.0})
	Floating._animate_damage_entry(entry, 0, reduced)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Typography.display_font())
	Typography.set_label_size(label, int(entry["font_size"]))
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", entry["outline_color"])
	label.add_theme_constant_override("outline_size", int(entry["outline_size"]))
	label.add_theme_color_override("font_shadow_color", entry["shadow_color"])
	label.add_theme_constant_override("shadow_offset_x", int(entry["shadow_offset"].x))
	label.add_theme_constant_override("shadow_offset_y", int(entry["shadow_offset"].y))
	add_child(label)
	_popups.append(label)
	var origin: Vector2 = _bar.position
	_pose_number(label, entry, origin, 0, reduced)
	var motion := label.create_tween()
	# Reuse the combat pop/arc/fade in-place; no per-frame dictionaries or widgets.
	motion.tween_method(func(progress: float) -> void:
		entry["font_size"] = Floating.DAMAGE_BASE_FONT_SIZE
		Floating._animate_damage_entry(entry, progress, reduced)
		_pose_number(label, entry, origin, progress, reduced), 0.0, 1.0, 0.12 if reduced else Floating.ANIMATION_DURATION_SECONDS)
	motion.tween_callback(func() -> void: _popups.erase(label); label.queue_free())

func _pose_number(label: Label, entry: Dictionary, origin: Vector2, progress: float, reduced: bool) -> void:
	label.scale = Vector2.ONE * float(entry["font_scale"]) * NUMBER_SCALE
	label.modulate.a = float(entry["alpha"])
	var rise: float = clampf(-Floating._motion_offset(entry, progress, reduced).y, 0, NUMBER_MAX_RISE)
	var point: Vector2 = origin - Vector2(0, rise)
	var extent: Vector2 = label.get_combined_minimum_size() * label.scale
	point.x -= extent.x * 0.5
	if panel_bounds.has_area():
		point.x = clampf(point.x, panel_bounds.position.x, panel_bounds.end.x - extent.x)
		point.y = clampf(point.y, panel_bounds.position.y, panel_bounds.end.y - extent.y)
	label.position = point

func finish(value: int, maximum: int) -> void:
	for motion: Tween in [_motion, _ghost_motion, _flash_motion]:
		if motion != null: motion.kill()
	for popup: Control in _popups:
		if is_instance_valid(popup): popup.free()
	_popups.clear()
	ghost_alpha = 0
	ghost_hp = value
	flash = Color.TRANSPARENT
	set_health(value, maximum)

func _draw() -> void:
	if _flash_overlay != null: _flash_overlay.color = flash
