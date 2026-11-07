extends RefCounted

const UiTooltipControl = preload("res://scripts/ui_tooltip_control.gd")
const TurnOrderInk = preload("res://scripts/turn_order_ink.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const TempoRelicRules = preload("res://scripts/tempo_relic_rules.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")

static func controller_controls(scene: Node) -> Array[Control]:
	var result: Array[Control]
	for slot: Control in scene._turn_order_bar.get_children():
		if slot.is_visible_in_tree() and not slot.tooltip_text.is_empty(): result.append(slot)
	var details: Control = scene._enemy_intent_toggle_button
	if details != null and details.is_visible_in_tree() and not details.disabled: result.append(details)
	return result

# Reconcile in place instead of rebuilding all six portrait subtrees whenever
# the clock, health or selection changes. Animated transitions and shape
# changes retain the original fresh-control lifecycle (including tween teardown).
static func reconcile(scene: Node, entries: Array[Dictionary]) -> void:
	var available: Array[Node] = scene._turn_order_bar.get_children()
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var shape: Array = _shape(scene, entry)
		var slot: Control = null
		for previous: Node in available:
			if not scene._turn_order_animating and previous.get_meta("perf03_shape", []) == shape and not previous.has_node("TurnOrderShadowDissolve"):
				slot = previous as Control
				available.erase(previous)
				break
		var source: Array = _inputs(scene, entry, index)
		var key: int = hash(source)
		if slot == null or int(slot.get_meta("perf03_content_key", 0)) != key or slot.get_meta("perf03_source", []) != source:
			slot = update(scene, entry, index, slot)
			slot.set_meta("perf03_source", source.duplicate(true))
			slot.set_meta("perf03_content_key", key)
			slot.set_meta("perf03_shape", shape.duplicate(true))
		if slot.get_parent() == null: scene._turn_order_bar.add_child(slot)
		scene._turn_order_bar.move_child(slot, index)
		# The old factory supplied a fresh motion baseline at each rail update.
		# Reuse controls while preserving that baseline for removal/reflow tweens.
		slot.scale = Vector2.ONE
		slot.modulate = Color.WHITE
		slot.pivot_offset = Vector2.ZERO
		slot.rotation = 0.0
		if slot.has_meta("turn_order_removal_style"): slot.remove_meta("turn_order_removal_style")
		slot.position = scene._turn_order_slot_position(index)
	for obsolete: Node in available:
		scene._turn_order_bar.remove_child(obsolete)
		obsolete.queue_free()

static func _shape(scene: Node, entry: Dictionary) -> Array:
	return [entry.get("kind"), entry.get("actor_key"), entry.get("pos"), entry.get("type"), entry.get("hidden_by_umbra", false),
		entry.get("late_relic_id", ""), entry.has("hp") and entry.has("max_hp"), scene._turn_order_is_card_preview_projection(entry), entry.get("petrified", false), scene._reduced_motion_enabled(), scene._turn_order_portrait_path(entry)]

static func _inputs(scene: Node, entry: Dictionary, index: int) -> Array:
	return [entry, index, scene._reduced_motion_enabled(), scene._turn_order_relative_time(entry), scene._turn_order_portrait_path(entry), scene._turn_order_slot_size(index, bool(entry.get("active", false)))]

static func _part(parts: Dictionary, key: String, factory: Callable) -> Node:
	if not parts.has(key): parts[key] = factory.call()
	return parts[key]

static func _attach(parent: Node, child: Node) -> void:
	if child.get_parent() == null: parent.add_child(child)

static func update(scene: Node, entry: Dictionary, index: int, frame: Control = null) -> Control:
	if str(entry.get("kind", "")) == "beat": return _update_beat(scene, entry, index, frame)
	if frame == null: frame = UiTooltipControl.new()
	var parts: Dictionary = frame.get_meta("perf03_retained_parts", {})
	frame.set_meta("perf03_retained_parts", parts)
	var active: bool = bool(entry.get("active", false))
	var slot_size: Vector2 = scene._turn_order_slot_size(index, active)
	frame.custom_minimum_size = slot_size
	frame.size = slot_size
	frame.clip_contents = false
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = scene.TOOLTIP_ONLY_CURSOR_SHAPE if str(entry.get("kind", "")) == "enemy" and not bool(entry.get("hidden_by_umbra", false)) else Control.CURSOR_ARROW
	frame.tooltip_text = scene._turn_order_tooltip(entry, index)
	frame.set_meta("turn_order_key", scene._turn_order_entry_key(entry))
	frame.set_meta("turn_order_actor_key", scene._turn_order_actor_key(entry))
	frame.set_meta("turn_order_animation_role", scene._turn_order_animation_role(entry))
	frame.set_meta("turn_order_size", slot_size)
	frame.set_meta("turn_order_projected", bool(entry.get("projected", false)))
	frame.set_meta("turn_order_projection_card_name", str(entry.get("projected_card_name", "")))
	frame.set_meta("turn_order_projection_time_cost", int(entry.get("projected_time_cost", 0)))
	frame.set_meta("turn_order_projection_time_delta", int(entry.get("projected_time_delta", 0)))
	frame.set_meta("turn_order_projection_wait_time", int(entry.get("projected_wait_time", 0)))
	frame.set_meta("turn_order_tooltip", frame.tooltip_text)
	frame.set_meta("turn_order_rail_index", index)
	frame.set_meta("turn_order_art_hook", scene.TURN_ORDER_INK_ART_HOOK)
	frame.set_meta("turn_order_team", str(entry.get("team", "enemy")))
	var team_name: String = str(entry.get("team", "enemy"))
	var projected_entry: bool = scene._turn_order_is_card_preview_projection(entry)
	var ink_key: String = scene._turn_order_actor_key(entry)
	# Painted stroke behind the actor. It bleeds past the slot (widest on the
	# left, where the time is painted) and keeps its variant and tilt per actor.
	var backing: TextureRect = _part(parts, "backing", func() -> Node: return TextureRect.new())
	backing.name = "TurnOrderBrushBacking"
	var brush: Texture2D = TurnOrderInk.brush_texture(active, ink_key)
	var backing_rect: Rect2 = TurnOrderInk.brush_rect(slot_size, brush)
	backing.position = backing_rect.position
	backing.size = backing_rect.size
	backing.pivot_offset = backing_rect.size * 0.5
	backing.rotation_degrees = TurnOrderInk.brush_tilt_degrees(ink_key, active)
	backing.flip_h = TurnOrderInk.brush_flipped(ink_key, active)
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.stretch_mode = TextureRect.STRETCH_SCALE
	backing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backing.clip_contents = false
	backing.texture = brush
	backing.modulate = TurnOrderInk.ink_color(team_name, active, projected_entry)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Drawn beneath every portrait in the rail so a neighbour's stroke never
	# covers a face; the slot panel stays the frame's first child.
	backing.z_index = -1
	var panel: PanelContainer = _part(parts, "panel", func() -> Node: return PanelContainer.new())
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.clip_contents = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", scene._turn_order_slot_style(entry, active))
	_attach(frame, panel)
	_attach(frame, backing)
	var margin: MarginContainer = _part(parts, "margin", func() -> Node: return MarginContainer.new())
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	var side_inset: int = 0
	var top_inset: int = 0
	var bottom_inset: int = 0
	margin.add_theme_constant_override("margin_left", side_inset)
	margin.add_theme_constant_override("margin_top", top_inset)
	margin.add_theme_constant_override("margin_right", side_inset)
	margin.add_theme_constant_override("margin_bottom", bottom_inset)
	_attach(panel, margin)
	# The slanted, slightly ragged window is the mask; only the portrait inside
	# it is drawn.
	var portrait_crop: TurnOrderInk.PortraitMask = _part(parts, "portrait_crop", func() -> Node: return TurnOrderInk.PortraitMask.new())
	portrait_crop.name = "TurnOrderPortraitCrop"
	portrait_crop.skew = TurnOrderInk.SKEW_RATIO
	portrait_crop.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_crop.anchor_right = 1.0
	portrait_crop.anchor_bottom = 1.0
	portrait_crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach(margin, portrait_crop)
	var portrait: TextureRect = _part(parts, "portrait", func() -> Node: return TextureRect.new())
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	var portrait_zoom: float = 1.04
	var portrait_bleed: Vector2 = slot_size * (portrait_zoom - 1.0) * 0.5
	portrait.offset_left = -portrait_bleed.x
	portrait.offset_top = -portrait_bleed.y
	portrait.offset_right = portrait_bleed.x
	portrait.offset_bottom = portrait_bleed.y
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = AssetLoader.load_texture(scene._turn_order_portrait_path(entry))
	portrait.modulate = scene._turn_order_portrait_modulate(entry, active)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach(portrait_crop, portrait)
	frame.set_meta("turn_order_portrait_texture", portrait.texture)
	if not str(entry.get("late_relic_id", "")).is_empty():
		# A miniature of the relic-bar badge, so the cue reads as "this relic applies here".
		var late_relic_id: String = str(entry["late_relic_id"])
		var bell_badge: Panel = _part(parts, "bell_badge", func() -> Node: return Panel.new())
		bell_badge.name = "LateRelicIcon"
		bell_badge.size = Vector2(30, 30)
		bell_badge.position = Vector2(slot_size.x - 32, 2)
		bell_badge.z_index = 7
		bell_badge.mouse_filter = Control.MOUSE_FILTER_PASS
		var late_effect: Dictionary = TempoRelicRules.effect_of_type(GameData.relic_effects(late_relic_id), "damage_vs_late")
		bell_badge.tooltip_text = "Late: your attacks deal %d more." % int(late_effect.get("amount", 0))
		bell_badge.add_theme_stylebox_override("panel", scene._pile_card_style(scene.TURN_ORDER_RELIC_BADGE_FILL, Color(GameData.relic_accent(late_relic_id)), 3.0))
		var bell: TextureRect = _part(parts, "bell", func() -> Node: return TextureRect.new())
		bell.texture = AssetLoader.load_texture(str(GameData.relic_def(late_relic_id).get("icon_path", "")))
		bell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bell.size = Vector2(24, 24)
		bell.position = Vector2(3, 3)
		bell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_attach(bell_badge, bell)
		_attach(frame, bell_badge)
	var edge: TurnOrderInk.SlashEdge = _part(parts, "edge", func() -> Node: return TurnOrderInk.SlashEdge.new())
	edge.name = "TurnOrderSlashEdge"
	edge.skew = TurnOrderInk.SKEW_RATIO
	edge.color = scene.TURN_ORDER_ACTIVE_EDGE_COLOR if active else Color(UiPalette.TEXT, 0.30)
	edge.width = 2.5 if active else 1.2
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.anchor_right = 1.0
	edge.anchor_bottom = 1.0
	edge.z_index = 6
	_attach(frame, edge)
	var health_bar: SegmentedHealthBar = scene._turn_order_health_bar(entry, slot_size, parts.get("health"))
	if health_bar != null:
		parts["health"] = health_bar
		_attach(frame, health_bar)
	# ui-30: the hero keeps its projected numeral and motion, without the
	# card-name/Time caption. Enemy Stagger and Petrify badges remain unchanged.
	if str(entry.get("kind", "")) != "player" and scene._turn_order_is_card_preview_projection(entry):
		var projection: Control = scene._turn_order_projection_badge(entry, slot_size, parts.get("projection"))
		parts["projection"] = projection
		_attach(frame, projection)
	elif bool(entry.get("petrified", false)):
		# Petrify: this queued activation is skipped but keeps its Time.
		var skip_badge: Control = scene._turn_order_projection_badge(entry, slot_size, parts.get("projection"))
		parts["projection"] = skip_badge
		skip_badge.name = "PetrifiedSkipBadge"
		_attach(frame, skip_badge)
	var badge_text: String = scene._turn_order_clock_badge_text(entry)
	frame.set_meta("turn_order_badge_text", badge_text)
	var numeral: Label = scene._turn_order_number_badge(badge_text, entry, active, slot_size, parts.get("numeral"))
	parts["numeral"] = numeral
	_attach(frame, numeral)
	if str(entry.get("kind", "")) == "enemy" and not bool(entry.get("hidden_by_umbra", false)):
		var tile: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var actor_key: String = str(entry.get("actor_key", ""))
		if not frame.mouse_entered.is_connected(scene._on_turn_order_enemy_hovered.bind(tile, actor_key)): frame.mouse_entered.connect(scene._on_turn_order_enemy_hovered.bind(tile, actor_key))
		if not frame.mouse_exited.is_connected(scene._on_turn_order_enemy_unhovered.bind(tile, actor_key)): frame.mouse_exited.connect(scene._on_turn_order_enemy_unhovered.bind(tile, actor_key))
	return frame

# A battlefield rule's beat: a round rule token in the rail, at the clock of the turn it follows.
class BeatToken extends Control:
	func _draw() -> void:
		var radius: float = minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, radius, Color(UiPalette.INK_0, 0.96))
		draw_arc(size * 0.5, radius - 1.0, 0.0, TAU, 48, UiPalette.GOLD, 2.0, true)

const BEAT_TOKEN_RATIO: float = 0.62
const BEAT_ICON_INSET_RATIO: float = 0.18

static func _update_beat(scene: Node, entry: Dictionary, index: int, frame: Control) -> Control:
	if frame == null: frame = UiTooltipControl.new()
	var parts: Dictionary = frame.get_meta("perf03_retained_parts", {})
	frame.set_meta("perf03_retained_parts", parts)
	var slot_size: Vector2 = scene._turn_order_slot_size(index, false)
	frame.custom_minimum_size = slot_size
	frame.size = slot_size
	frame.clip_contents = false
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = scene.TOOLTIP_ONLY_CURSOR_SHAPE
	frame.tooltip_text = "%s — %s" % [str(entry.get("name", "")), str(entry.get("sentence", ""))]
	frame.set_meta("turn_order_key", scene._turn_order_entry_key(entry))
	frame.set_meta("turn_order_actor_key", scene._turn_order_actor_key(entry))
	frame.set_meta("turn_order_animation_role", scene._turn_order_animation_role(entry))
	frame.set_meta("turn_order_size", slot_size)
	frame.set_meta("turn_order_projected", true)
	frame.set_meta("turn_order_tooltip", frame.tooltip_text)
	frame.set_meta("turn_order_rail_index", index)
	frame.set_meta("turn_order_team", "rule")
	frame.set_meta("turn_order_beat_rule", str(entry.get("rule", "")))
	# The same faded stroke as a projected turn, so the numeral sits on paint like every row.
	var backing: TextureRect = _part(parts, "backing", func() -> Node: return TextureRect.new())
	backing.name = "TurnOrderBrushBacking"
	var ink_key: String = scene._turn_order_actor_key(entry)
	var brush: Texture2D = TurnOrderInk.brush_texture(false, ink_key)
	var backing_rect: Rect2 = TurnOrderInk.brush_rect(slot_size, brush)
	backing.position = backing_rect.position
	backing.size = backing_rect.size
	backing.pivot_offset = backing_rect.size * 0.5
	backing.rotation_degrees = TurnOrderInk.brush_tilt_degrees(ink_key, false)
	backing.flip_h = TurnOrderInk.brush_flipped(ink_key, false)
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.stretch_mode = TextureRect.STRETCH_SCALE
	backing.texture = brush
	backing.modulate = TurnOrderInk.ink_color("enemy", false, true)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.z_index = -1
	_attach(frame, backing)
	var diameter: float = roundf(slot_size.y * BEAT_TOKEN_RATIO)
	var token: BeatToken = _part(parts, "token", func() -> Node: return BeatToken.new())
	token.name = "TurnOrderBeatToken"
	token.size = Vector2.ONE * diameter
	token.position = Vector2(slot_size.x - diameter, slot_size.y - diameter) * Vector2(0.62, 0.5)
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach(frame, token)
	var icon: TextureRect = _part(parts, "icon", func() -> Node: return TextureRect.new())
	icon.name = "TurnOrderBeatIcon"
	var inset: float = diameter * BEAT_ICON_INSET_RATIO
	icon.position = Vector2.ONE * inset
	icon.size = Vector2.ONE * (diameter - inset * 2.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = preload("res://scripts/action_icon_library.gd").icon_texture(str(entry.get("icon", "")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach(token, icon)
	var badge_text: String = scene._turn_order_clock_badge_text(entry)
	frame.set_meta("turn_order_badge_text", badge_text)
	var numeral: Label = scene._turn_order_number_badge(badge_text, entry, false, slot_size, parts.get("numeral"))
	parts["numeral"] = numeral
	_attach(frame, numeral)
	return frame

# Reuse the exact portrait masks, brush family, health-free frame and numeral.
# No separate chip and no invented overflow art or wording.
const OVERFLOW_PORTRAIT_OFFSET: Vector2 = preload("res://scripts/turn_order_layout.gd").OVERFLOW_PORTRAIT_OFFSET

static func overflow(scene: Node, entries: Array[Dictionary], index: int) -> Control:
	var representative: Dictionary = entries[0].duplicate(true)
	representative.erase("hp")
	representative.erase("max_hp")
	representative.erase("projected_time_delta")
	representative.erase("projected_card_name")
	representative.erase("stagger_preview")
	representative.erase("petrified")
	representative.erase("late_relic_id")
	representative["projected"] = false
	representative["active"] = false
	var frame: Control = update(scene, representative, index)
	frame.name = "TurnOrderOverflowEntry"
	frame.position = scene._turn_order_slot_position(index)
	frame.set_meta("turn_order_overflow_count", entries.size())
	frame.remove_meta("turn_order_actor_key")
	# The aggregate discloses scheduled turns through its tooltip. It is not a
	# hover target for whichever actor happened to supply its front portrait.
	for connection: Dictionary in frame.mouse_entered.get_connections(): frame.mouse_entered.disconnect(connection.callable)
	for connection: Dictionary in frame.mouse_exited.get_connections(): frame.mouse_exited.disconnect(connection.callable)
	frame.tooltip_text = scene._turn_order_overflow_tooltip(entries)
	frame.set_meta("turn_order_tooltip", frame.tooltip_text)
	var numeral: Label = frame.get_meta("perf03_retained_parts")["numeral"]
	numeral.text = "+%d" % entries.size()
	frame.set_meta("turn_order_badge_text", numeral.text)
	# Up to two offset portraits sit behind the front portrait. Reuse the
	# rail's inactive tint once more to dim each successive background layer.
	for layer: int in range(1, mini(3, entries.size())):
		var mask := TurnOrderInk.PortraitMask.new()
		mask.name = "OverflowPortraitEdge%d" % layer
		mask.skew = TurnOrderInk.SKEW_RATIO
		mask.size = frame.size
		mask.position = OVERFLOW_PORTRAIT_OFFSET * layer
		var portrait := TextureRect.new()
		portrait.texture = AssetLoader.load_texture(scene._turn_order_portrait_path(entries[layer]))
		var inactive_tint: Color = scene._turn_order_portrait_modulate(representative, false)
		portrait.modulate = scene._turn_order_portrait_modulate(entries[layer], false)
		for tint_layer: int in range(layer): portrait.modulate *= inactive_tint
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.size = frame.size
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.add_child(portrait)
		frame.add_child(mask)
		frame.move_child(mask, 0)
	return frame
