extends Control
class_name TurnOrderLandingStrip

const TurnOrderInk = preload("res://scripts/turn_order_ink.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const CardFocusTooltipStack = preload("res://scripts/card_focus_tooltip_stack.gd")

const SLOT_SIZE := Vector2(86, 64)
const MINI_SCALE := 0.74
const GUTTER := 16.0
const DIM_AFTER := Color(0.80, 0.77, 0.74, 0.52)
const LEFT_BLEED := TurnOrderInk.BLEED_LEFT * MINI_SCALE
const SLOT_STEP := SLOT_SIZE.x + LEFT_BLEED
const CHEVRON_GAP := 20.0
const AGAIN_GLOW_SIZE := Vector2(150, 110)
var _roles: Dictionary = {}
var _signature: String = ""
var _target: Control
var _tooltip_stack: Control
var _allowed: Callable
var _fade: Tween

func _init() -> void:
	name = "TurnOrderLandingStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_as_relative = false
	z_index = 1310
	visible = false
	set_process(false)

static func roles_for(entries: Array[Dictionary]) -> Dictionary:
	var before: Array[Dictionary]
	var active_index: int = -1
	for index: int in range(entries.size()):
		if bool(entries[index].get("active", false)):
			active_index = index
			break
	if active_index < 0:
		return {}
	for index: int in range(active_index + 1, entries.size()):
		var entry: Dictionary = entries[index]
		if str(entry.get("kind", "")) == "player" and bool(entry.get("projected", false)):
			return {"before": before, "hero": entry, "after": entries[index + 1] if index + 1 < entries.size() else {}, "overflow": maxi(0, before.size() - 4), "act_again": before.is_empty()}
		before.append(entry)
	return {}

static func content_signature(roles: Dictionary, focused_index: int) -> String:
	var parts := PackedStringArray([str(focused_index)])
	for role: String in ["before", "hero", "after"]:
		var entries: Array = roles.get("before", []) if role == "before" else [roles.get(role, {})]
		for entry: Dictionary in entries:
			parts.append("%s:%s:%s:%s:%s:%s:%s" % [role, actor_key(entry), entry.get("time", 0), entry.get("seq", 0), entry.get("eta", 0), entry.get("hidden_by_umbra", false), entry.get("projected", false)])
	return "|".join(parts)

static func actor_key(entry: Dictionary) -> String:
	return "%s:%s" % [str(entry.get("kind", "")), str(entry.get("actor_key", ""))]

# Coordinates include the stroke's bleed, so the painted strip as well as its
# portrait Controls clears the stack and stays within the viewport gutter.
static func placement(card: Rect2, stack: Rect2, strip_size: Vector2, viewport: Rect2) -> Rect2:
	var safe: Rect2 = viewport.grow(-GUTTER)
	if strip_size.x > safe.size.x or strip_size.y > safe.size.y:
		return Rect2()
	var stack_left: bool = stack.has_area() and stack.get_center().x < card.get_center().x
	var x: float = card.position.x - 8.0 if stack_left else card.end.x + 8.0 - strip_size.x
	var y: float = card.position.y - 4.0 - strip_size.y
	x = clampf(x, safe.position.x, safe.end.x - strip_size.x)
	y = clampf(y, safe.position.y, safe.end.y - strip_size.y)
	var result := Rect2(Vector2(x, y), strip_size)
	if not stack.has_area() or not result.intersects(stack):
		return result
	var away_x: float = stack.end.x + 4.0 if stack_left else stack.position.x - 4.0 - strip_size.x
	var alternate_x: float = stack.position.x - 4.0 - strip_size.x if stack_left else stack.end.x + 4.0
	for candidate_x: float in [away_x, alternate_x]:
		var candidate := Rect2(Vector2(candidate_x, y), strip_size)
		if safe.encloses(candidate) and not candidate.intersects(stack):
			return candidate
	# A clamped tooltip can cross the card. Move above it only when neither side
	# fits; never change the tooltip stack's established placement rules.
	for candidate_y: float in [stack.position.y - 4.0 - strip_size.y, stack.end.y + 4.0]:
		var candidate := Rect2(Vector2(x, candidate_y), strip_size)
		if safe.encloses(candidate) and not candidate.intersects(stack):
			return candidate
	return Rect2()

func present(entries: Array[Dictionary], focused_index: int, target: Control, tooltip_stack: Control, portrait_path: Callable, allowed: Callable, reduced_motion: bool) -> void:
	var roles: Dictionary = roles_for(entries)
	if roles.is_empty() or target == null:
		hide_strip()
		return
	_target = target
	_tooltip_stack = tooltip_stack
	_allowed = allowed
	var signature: String = content_signature(roles, focused_index)
	if signature != _signature:
		_signature = signature
		_roles = roles
		_rebuild(portrait_path)
		set_meta("content_signature", signature)
		set_meta("rebuild_count", int(get_meta("rebuild_count", 0)) + 1)
	set_process(true)
	var was_visible: bool = visible
	_follow_target()
	if visible and not was_visible:
		if _fade != null:
			_fade.kill()
		modulate.a = 1.0 if reduced_motion else 0.0
		if not reduced_motion:
			_fade = create_tween()
			_fade.tween_property(self, "modulate:a", 1.0, 0.12)
	elif reduced_motion:
		if _fade != null:
			_fade.kill()
		modulate.a = 1.0

func hide_strip() -> void:
	visible = false
	set_process(false)
	_target = null
	if _fade != null:
		_fade.kill()

func role_entries() -> Dictionary:
	return _roles.duplicate(true)

func _process(_delta: float) -> void:
	_follow_target()

func _follow_target() -> void:
	if not is_instance_valid(_target) or _target.is_queued_for_deletion() or not _target.is_visible_in_tree() or (_allowed.is_valid() and not bool(_allowed.call())):
		hide_strip()
		return
	var stack_rect := Rect2()
	if is_instance_valid(_tooltip_stack) and _tooltip_stack.is_visible_in_tree():
		stack_rect = _tooltip_stack.get_global_rect()
	var rect: Rect2 = placement(CardFocusTooltipStack._visual_global_rect(_target), stack_rect, size, get_viewport().get_visible_rect())
	visible = rect.has_area()
	if visible:
		global_position = rect.position

func _rebuild(portrait_path: Callable) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var before: Array = _roles.get("before", [])
	# The cursor marks the next numeral's bleed, not its portrait. Only the
	# strokes may extend under a neighbour's numeral or portrait.
	var x: float = 0.0
	for index: int in range(mini(4, before.size())):
		_add_slot(before[index], "LandingStripSlot_%d" % index, "before", x + LEFT_BLEED, portrait_path)
		x += SLOT_STEP
	if int(_roles.get("overflow", 0)) > 0:
		var overflow: Label = _label("LandingStripOverflow", "+%d" % int(_roles["overflow"]), 15, UiPalette.TEXT, Vector2(32, 64))
		overflow.position.x = x + 4.0
		x += 36.0
	if not before.is_empty():
		_add_chevron(x, 16.0, UiPalette.GOLD)
		x += CHEVRON_GAP
	var hero_position := Vector2(x + LEFT_BLEED, 0)
	if bool(_roles.get("act_again", false)):
		_add_again_glow(hero_position)
	_add_slot(_roles["hero"], "LandingStripHero", "hero", hero_position.x, portrait_path)
	x += SLOT_STEP
	if bool(_roles.get("act_again", false)):
		var again: Label = _label("LandingStripAgainLabel", "ACT\nAGAIN", 16, UiPalette.GOLD_BRIGHT, Vector2(64, 64))
		again.position.x = x
		x += 67.0
		_add_chevron(x, 16.0, UiPalette.GOLD_DIM)
		x += CHEVRON_GAP
	if not (_roles.get("after", {}) as Dictionary).is_empty():
		_add_slot(_roles["after"], "LandingStripAfter", "after", x + LEFT_BLEED, portrait_path)
		x += SLOT_STEP
	size = Vector2(x + 8.0, SLOT_SIZE.y)
	queue_redraw()

func _add_again_glow(hero_position: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiPalette.GOLD_BRIGHT, 0.40))
	gradient.set_color(1, Color(UiPalette.GOLD_BRIGHT, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = int(AGAIN_GLOW_SIZE.x)
	texture.height = int(AGAIN_GLOW_SIZE.y)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.name = "LandingStripAgainGlow"
	glow.position = hero_position + SLOT_SIZE * 0.5 - AGAIN_GLOW_SIZE * 0.5
	glow.size = AGAIN_GLOW_SIZE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.texture = texture
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# After the strip's wash, before the hero's brush at the same canvas depth.
	glow.z_index = 0
	add_child(glow)

func _add_slot(entry: Dictionary, node_name: String, role: String, x: float, portrait_path: Callable) -> void:
	var slot := Control.new()
	slot.name = node_name
	slot.position = Vector2(x, 0)
	slot.size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta("landing_strip_role", role)
	slot.set_meta("turn_order_actor_key", actor_key(entry))
	slot.set_meta("turn_order_entry", entry.duplicate(true))
	if role == "after":
		slot.modulate = DIM_AFTER
	add_child(slot)
	var brush: Texture2D = TurnOrderInk.brush_texture(false, actor_key(entry))
	var rect: Rect2 = TurnOrderInk.brush_rect(SLOT_SIZE / MINI_SCALE, brush)
	var backing := TextureRect.new()
	backing.name = "LandingStripBrush"
	backing.position = rect.position * MINI_SCALE
	backing.size = rect.size * MINI_SCALE
	backing.pivot_offset = backing.size * 0.5
	backing.rotation_degrees = TurnOrderInk.brush_tilt_degrees(actor_key(entry), false)
	backing.flip_h = TurnOrderInk.brush_flipped(actor_key(entry), false)
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.stretch_mode = TextureRect.STRETCH_SCALE
	backing.texture = brush
	backing.modulate = TurnOrderInk.ink_color("enemy" if bool(entry.get("hidden_by_umbra", false)) else str(entry.get("team", "enemy")), false, role == "hero" or int(entry.get("stagger_preview", 0)) > 0)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.z_index = 0
	slot.add_child(backing)
	var mask := TurnOrderInk.PortraitMask.new()
	mask.name = "LandingStripPortraitCrop"
	mask.skew = 0.14
	mask.size = SLOT_SIZE
	mask.z_index = 1
	slot.add_child(mask)
	var portrait := TextureRect.new()
	portrait.name = "LandingStripPortrait"
	portrait.position = -SLOT_SIZE * 0.02
	portrait.size = SLOT_SIZE * 1.04
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path: String = "res://assets/art/icons/umbra_presence.png" if bool(entry.get("hidden_by_umbra", false)) else str(portrait_path.call(entry))
	portrait.texture = AssetLoader.load_texture(path)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(portrait)
	var eta: Label = _label("LandingStripTimeNumeral", str(entry.get("eta", 0)), 17, Color("f4c968") if role == "hero" else UiPalette.TEXT, Vector2(LEFT_BLEED, SLOT_SIZE.y), slot)
	eta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	eta.position = Vector2(-LEFT_BLEED + 2.0 * MINI_SCALE, SLOT_SIZE.y * (TurnOrderInk.BAND_CENTER_RATIO - 0.5))
	eta.z_index = 8

func _label(node_name: String, value: String, font_size: int, color: Color, area: Vector2, parent: Node = null) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.size = area
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiTypography.display_font())
	UiTypography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	(parent if parent != null else self).add_child(label)
	return label

func _add_chevron(x: float, height: float, color: Color) -> void:
	var chevron := Control.new()
	chevron.name = "LandingStripChevron"
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.position = Vector2(x + (CHEVRON_GAP - 8.0) * 0.5, (SLOT_SIZE.y - height) * 0.5)
	chevron.size = Vector2(8, height)
	chevron.z_index = 8
	chevron.set_meta("chevron_color", color)
	chevron.draw.connect(func() -> void:
		chevron.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(8, height * 0.5), Vector2(0, height), Vector2(3, height * 0.5)]), color)
	)
	add_child(chevron)

func _draw() -> void:
	# Layered rounded washes have a feathered edge without a framed HUD panel.
	for step: int in range(24):
		var wash := StyleBoxFlat.new()
		wash.bg_color = Color(0.024, 0.016, 0.012, lerpf(0.006, 0.135, float(step) / 23.0))
		wash.set_corner_radius_all(12)
		draw_style_box(wash, Rect2(Vector2.ZERO, size).grow(-float(step) * 0.5))
