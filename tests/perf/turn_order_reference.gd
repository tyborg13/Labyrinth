extends RefCounted

const UiTooltipControl = preload("res://scripts/ui_tooltip_control.gd")
const TurnOrderInk = preload("res://scripts/turn_order_ink.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const TempoRelicRules = preload("res://scripts/tempo_relic_rules.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")

# Exact pre-retention slot factory; equivalence oracle only.
static func build(scene: Node, entry: Dictionary, index: int) -> Control:
	var active: bool = bool(entry.get("active", false))
	var slot_size: Vector2 = scene._turn_order_slot_size(index, active)
	var frame := UiTooltipControl.new()
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
	var backing := TextureRect.new()
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
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.clip_contents = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", scene._turn_order_slot_style(entry, active))
	frame.add_child(panel)
	frame.add_child(backing)
	var margin := MarginContainer.new()
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
	panel.add_child(margin)
	# The slanted, slightly ragged window is the mask; only the portrait inside
	# it is drawn.
	var portrait_crop := TurnOrderInk.PortraitMask.new()
	portrait_crop.name = "TurnOrderPortraitCrop"
	portrait_crop.skew = TurnOrderInk.SKEW_RATIO
	portrait_crop.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_crop.anchor_right = 1.0
	portrait_crop.anchor_bottom = 1.0
	portrait_crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(portrait_crop)
	var portrait := TextureRect.new()
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
	portrait_crop.add_child(portrait)
	if not bool(entry.get("hidden_by_umbra", false)):
		preload("res://scripts/maquette_cutout_runtime/portrait.gd").bind(portrait, str(entry.get("type", "")), scene._reduced_motion_enabled(), true)
	frame.set_meta("turn_order_portrait_texture", portrait.texture)
	if not str(entry.get("late_relic_id", "")).is_empty():
		# A miniature of the relic-bar badge, so the cue reads as "this relic applies here".
		var late_relic_id: String = str(entry["late_relic_id"])
		var bell_badge := Panel.new()
		bell_badge.name = "LateRelicIcon"
		bell_badge.size = Vector2(30, 30)
		bell_badge.position = Vector2(slot_size.x - 32, 2)
		bell_badge.z_index = 7
		bell_badge.mouse_filter = Control.MOUSE_FILTER_PASS
		var late_effect: Dictionary = TempoRelicRules.effect_of_type(GameData.relic_effects(late_relic_id), "damage_vs_late")
		bell_badge.tooltip_text = "Late: your attacks deal %d more." % int(late_effect.get("amount", 0))
		bell_badge.add_theme_stylebox_override("panel", scene._pile_card_style(Color("261b14"), Color(GameData.relic_accent(late_relic_id)), 3.0))
		var bell := TextureRect.new()
		bell.texture = AssetLoader.load_texture(str(GameData.relic_def(late_relic_id).get("icon_path", "")))
		bell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bell.size = Vector2(24, 24)
		bell.position = Vector2(3, 3)
		bell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bell_badge.add_child(bell)
		frame.add_child(bell_badge)
	var edge := TurnOrderInk.SlashEdge.new()
	edge.name = "TurnOrderSlashEdge"
	edge.skew = TurnOrderInk.SKEW_RATIO
	edge.color = Color(1.0, 0.95, 0.82, 0.85) if active else Color(UiPalette.TEXT, 0.30)
	edge.width = 2.5 if active else 1.2
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.anchor_right = 1.0
	edge.anchor_bottom = 1.0
	edge.z_index = 6
	frame.add_child(edge)
	var health_bar: SegmentedHealthBar = scene._turn_order_health_bar(entry, slot_size)
	if health_bar != null:
		frame.add_child(health_bar)
	# ui-30 (owner-approved 2026-11-07): the hero's projection has no card caption.
	if str(entry.get("kind", "")) != "player" and scene._turn_order_is_card_preview_projection(entry):
		frame.add_child(scene._turn_order_projection_badge(entry, slot_size))
	elif bool(entry.get("petrified", false)):
		# Petrify: this queued activation is skipped but keeps its Time.
		var skip_badge: Control = scene._turn_order_projection_badge(entry, slot_size)
		skip_badge.name = "PetrifiedSkipBadge"
		frame.add_child(skip_badge)
	var badge_text: String = scene._turn_order_clock_badge_text(entry)
	frame.set_meta("turn_order_badge_text", badge_text)
	frame.add_child(scene._turn_order_number_badge(badge_text, entry, active, slot_size))
	if str(entry.get("kind", "")) == "enemy" and not bool(entry.get("hidden_by_umbra", false)):
		var tile: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var actor_key: String = str(entry.get("actor_key", ""))
		frame.mouse_entered.connect(scene._on_turn_order_enemy_hovered.bind(tile, actor_key))
		frame.mouse_exited.connect(scene._on_turn_order_enemy_unhovered.bind(tile, actor_key))
	return frame

