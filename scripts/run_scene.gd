extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const AttackSfxLibrary = preload("res://scripts/attack_sfx_library.gd")
const DialogueEngineScript = preload("res://scripts/dialogue_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const EmberRewardFeedback = preload("res://scripts/ember_reward_feedback.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const MusicLibrary = preload("res://scripts/music_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const LabyrinthMapViewScript = preload("res://scripts/labyrinth_map_view.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const SettingsPanelScript = preload("res://scripts/settings_panel.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")
const HandFanContainer = preload("res://scripts/hand_fan_container.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const RunEndRecapOverlay = preload("res://scripts/run_end_recap_overlay.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const UiTooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const UiTooltipControl = preload("res://scripts/ui_tooltip_control.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ContextualCombatPromptScene = preload("res://scripts/contextual_combat_prompt.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const TOOLTIP_ONLY_CURSOR_SHAPE: int = Control.CURSOR_HELP
const MOLTSHARD_GAIN_EVENT_TYPE: String = "progression_moltshard_gained"
const COMBAT_SKILL_EVENT_STAGED_REVISION_KEY: String = "combat_skill_event_revision_staged"
const COMBAT_DEFIANCE_EVENT_STAGED_REVISION_KEY: String = "combat_defiance_event_revision_staged"
const BOARD_BACKDROP_PATH: String = "res://assets/art/backgrounds/sealed_dungeon_hall.png"

class TooltipPanelContainer:
	extends PanelContainer
	const UiTooltipPanelScript = preload("res://scripts/ui_tooltip_panel.gd")

	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.strip_edges().is_empty():
			return null
		return UiTooltipPanelScript.make_text(for_text)

class EquipmentTooltipPanelContainer:
	extends TooltipPanelContainer

	var equipment_id: String = ""
	var host: Node = null

	func _make_custom_tooltip(for_text: String) -> Object:
		if host == null or equipment_id.is_empty():
			return super._make_custom_tooltip(for_text)
		return host.call("_build_equipment_tooltip_panel", equipment_id)

class EquipmentInventoryTile:
	extends EquipmentTooltipPanelContainer

	var _left_pressed: bool = false

	func _gui_input(event: InputEvent) -> void:
		if host == null or equipment_id.is_empty():
			return
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event
			if mouse_event.button_index != MOUSE_BUTTON_LEFT:
				return
			if mouse_event.pressed:
				if mouse_event.double_click:
					_left_pressed = false
					host.call("_equip_equipment_from_overlay", equipment_id)
					accept_event()
					return
				if bool(host.call("_equipment_overlay_can_change")):
					_left_pressed = true
					host.call("_begin_equipment_overlay_drag", equipment_id, host.call("_equipment_icon_rect_for_control", self), self, get_viewport().get_mouse_position())
					accept_event()
					return
			elif _left_pressed:
				_left_pressed = false
				host.call("_release_equipment_overlay_drag", get_viewport().get_mouse_position())
				accept_event()
				return
		elif event is InputEventMouseMotion and _left_pressed:
			host.call("_update_equipment_overlay_drag", get_viewport().get_mouse_position())
			accept_event()

class EquipmentSlotDrop:
	extends EquipmentTooltipPanelContainer

	var slot_id: String = ""

class EquipmentCardBadge:
	extends TooltipPanelContainer

	var card_id: String = ""
	var host: Node = null

	func _make_custom_tooltip(for_text: String) -> Object:
		if host == null or card_id.is_empty():
			return super._make_custom_tooltip(for_text)
		return host.call("_build_card_tooltip_panel", card_id)

class PreBattleEnemyCard:
	extends TooltipPanelContainer

	var enemy: Dictionary = {}
	var host: Node = null

	func _make_custom_tooltip(for_text: String) -> Object:
		if host == null or enemy.is_empty():
			return super._make_custom_tooltip(for_text)
		if host.has_method("_pre_battle_hover_inspections_enabled") and not bool(host.call("_pre_battle_hover_inspections_enabled")):
			return host.call("_suppressed_pre_battle_tooltip")
		return host.call("_build_pre_battle_enemy_inspection_panel", enemy)

	func _gui_input(event: InputEvent) -> void:
		if host == null or enemy.is_empty() or not (event is InputEventMouseButton):
			return
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if host.has_method("_pre_battle_click_inspections_enabled") and not bool(host.call("_pre_battle_click_inspections_enabled")):
				accept_event()
				return
			host.call("_open_pinned_pre_battle_inspection", "enemy", str(enemy.get("type", "")), self, enemy)
			accept_event()

class PreBattleEquipmentChip:
	extends EquipmentTooltipPanelContainer

	func _make_custom_tooltip(for_text: String) -> Object:
		if host != null and host.has_method("_pre_battle_hover_inspections_enabled") and not bool(host.call("_pre_battle_hover_inspections_enabled")):
			return host.call("_suppressed_pre_battle_tooltip")
		return super._make_custom_tooltip(for_text)

	func _gui_input(event: InputEvent) -> void:
		if host == null or equipment_id.is_empty() or not (event is InputEventMouseButton):
			return
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if host.has_method("_pre_battle_click_inspections_enabled") and not bool(host.call("_pre_battle_click_inspections_enabled")):
				accept_event()
				return
			host.call("_open_pinned_pre_battle_inspection", "equipment", equipment_id, self)
			accept_event()

class PreBattleCardBadge:
	extends EquipmentCardBadge

	var source_kind: String = "deck"

	func _make_custom_tooltip(for_text: String) -> Object:
		if host != null and host.has_method("_pre_battle_hover_inspections_enabled") and not bool(host.call("_pre_battle_hover_inspections_enabled")):
			return host.call("_suppressed_pre_battle_tooltip")
		return super._make_custom_tooltip(for_text)

	func _gui_input(event: InputEvent) -> void:
		if host == null or card_id.is_empty() or not (event is InputEventMouseButton):
			return
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if host.has_method("_pre_battle_click_inspections_enabled") and not bool(host.call("_pre_battle_click_inspections_enabled")):
				accept_event()
				return
			host.call("_open_pinned_pre_battle_inspection", "card", card_id, self)
			accept_event()

class MagicCardTile:
	extends EquipmentCardBadge

	var source_kind: String = ""
	var magic_index: int = -1
	var _left_pressed: bool = false

	func _gui_input(event: InputEvent) -> void:
		if host == null or card_id.is_empty():
			return
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event
			var mouse_position: Vector2 = mouse_event.global_position
			if mouse_position == Vector2.ZERO:
				mouse_position = get_viewport().get_mouse_position()
			if mouse_event.button_index != MOUSE_BUTTON_LEFT:
				return
			if mouse_event.pressed:
				if bool(host.call("_magic_overlay_can_change")):
					_left_pressed = true
					host.call("_begin_magic_overlay_drag", source_kind, magic_index, card_id, get_global_rect(), self, mouse_position)
					accept_event()
					return
			elif _left_pressed or bool(host.call("_magic_overlay_drag_active")):
				_left_pressed = false
				host.call("_release_magic_overlay_drag", mouse_position)
				accept_event()
				return
		elif event is InputEventMouseMotion:
			var motion_event: InputEventMouseMotion = event
			var motion_position: Vector2 = motion_event.global_position
			if motion_position == Vector2.ZERO:
				motion_position = get_viewport().get_mouse_position()
			if _left_pressed or bool(host.call("_magic_overlay_drag_active")):
				host.call("_update_magic_overlay_drag", motion_position)
				accept_event()


class ItemCardTile:
	extends EquipmentCardBadge

	var source_kind: String = ""
	var item_index: int = -1
	var _left_pressed: bool = false

	func _gui_input(event: InputEvent) -> void:
		if host == null or card_id.is_empty():
			return
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event
			var mouse_position: Vector2 = mouse_event.global_position
			if mouse_position == Vector2.ZERO:
				mouse_position = get_viewport().get_mouse_position()
			if mouse_event.button_index != MOUSE_BUTTON_LEFT:
				return
			if mouse_event.pressed:
				if bool(host.call("_item_overlay_can_change")):
					_left_pressed = true
					host.call("_begin_item_overlay_drag", source_kind, item_index, card_id, get_global_rect(), self, mouse_position)
					accept_event()
					return
			elif _left_pressed or bool(host.call("_item_overlay_drag_active")):
				_left_pressed = false
				host.call("_release_item_overlay_drag", mouse_position)
				accept_event()
				return
		elif event is InputEventMouseMotion:
			var motion_event: InputEventMouseMotion = event
			var motion_position: Vector2 = motion_event.global_position
			if motion_position == Vector2.ZERO:
				motion_position = get_viewport().get_mouse_position()
			if _left_pressed or bool(host.call("_item_overlay_drag_active")):
				host.call("_update_item_overlay_drag", motion_position)
				accept_event()

class CardArtBadgeWash:
	extends Control

	var accent: Color = Color("f0c978")
	var wash_alpha: float = 0.36

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.06), true)
		draw_rect(rect, Color(0.025, 0.018, 0.014, wash_alpha), true)
		var vertical_steps: int = max(12, int(rect.size.y))
		for index: int in range(vertical_steps):
			var t: float = float(index) / float(max(1, vertical_steps - 1))
			var eased_bottom: float = _badge_smoothstep(0.22, 1.0, t)
			var eased_top: float = 1.0 - _badge_smoothstep(0.0, 0.34, t)
			var alpha: float = 0.16 * eased_bottom + 0.05 * eased_top
			var y0: float = rect.size.y * float(index) / float(vertical_steps)
			var y1: float = rect.size.y * float(index + 1) / float(vertical_steps)
			draw_rect(Rect2(0.0, y0, rect.size.x, y1 - y0 + 1.0), Color(0.0, 0.0, 0.0, alpha), true)
		var side_width: float = minf(34.0, rect.size.x * 0.18)
		var side_steps: int = max(8, int(side_width))
		for index: int in range(side_steps):
			var edge_t: float = float(index) / float(max(1, side_steps - 1))
			var alpha: float = 0.12 * pow(1.0 - edge_t, 1.7)
			var x0: float = side_width * float(index) / float(side_steps)
			var x1: float = side_width * float(index + 1) / float(side_steps)
			var strip_width: float = x1 - x0 + 1.0
			draw_rect(Rect2(x0, 0.0, strip_width, rect.size.y), Color(0.0, 0.0, 0.0, alpha), true)
			draw_rect(Rect2(rect.size.x - x1, 0.0, strip_width, rect.size.y), Color(0.0, 0.0, 0.0, alpha), true)

	func _badge_smoothstep(edge0: float, edge1: float, value: float) -> float:
		var t: float = clampf((value - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)

class CardArtBadgeBacking:
	extends Control

	var accent: Color = Color("f0c978")
	var base_color: Color = Color("51463f")

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		var ground: Color = base_color.darkened(0.24).lerp(accent.darkened(0.34), 0.10)
		var glow: Color = base_color.lightened(0.08).lerp(accent, 0.14)
		var bottom: Color = base_color.darkened(0.42).lerp(accent.darkened(0.42), 0.08)
		var steps: int = max(12, int(rect.size.y))
		for index: int in range(steps):
			var t: float = float(index) / float(max(1, steps - 1))
			var eased: float = _badge_smoothstep(0.0, 1.0, t)
			var color: Color = ground.lerp(bottom, eased)
			var glow_alpha: float = 0.12 * (1.0 - minf(absf(t - 0.42) / 0.58, 1.0))
			var y0: float = rect.size.y * float(index) / float(steps)
			var y1: float = rect.size.y * float(index + 1) / float(steps)
			draw_rect(Rect2(0.0, y0, rect.size.x, y1 - y0 + 1.0), Color(color.r, color.g, color.b, 1.0), true)
			draw_rect(Rect2(0.0, y0, rect.size.x, y1 - y0 + 1.0), Color(glow.r, glow.g, glow.b, glow_alpha), true)

	func _badge_smoothstep(edge0: float, edge1: float, value: float) -> float:
		var t: float = clampf((value - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)

class FatigueEdgeOverlay:
	extends Control

	const WEB_LINE_COLOR: Color = Color(0.96, 0.06, 0.04, 0.70)
	const WEB_GLOW_COLOR: Color = Color(0.58, 0.0, 0.0, 0.30)
	const EDGE_WASH_COLOR: Color = Color(0.52, 0.0, 0.0, 0.14)

	var progress: float = -1.0:
		set(value):
			progress = value
			visible = progress >= 0.0
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		if progress < 0.0 or size.x <= 0.0 or size.y <= 0.0:
			return
		var t: float = clampf(progress, 0.0, 1.0)
		var pulse: float = sin(t * PI)
		if pulse <= 0.001:
			return
		var wash_color: Color = EDGE_WASH_COLOR
		wash_color.a *= pulse
		var edge_thickness: float = lerpf(18.0, 46.0, pulse)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, edge_thickness)), wash_color, true)
		draw_rect(Rect2(Vector2(0.0, size.y - edge_thickness), Vector2(size.x, edge_thickness)), wash_color, true)
		draw_rect(Rect2(Vector2.ZERO, Vector2(edge_thickness, size.y)), wash_color, true)
		draw_rect(Rect2(Vector2(size.x - edge_thickness, 0.0), Vector2(edge_thickness, size.y)), wash_color, true)

		var line_color: Color = WEB_LINE_COLOR
		line_color.a *= pulse
		var glow_color: Color = WEB_GLOW_COLOR
		glow_color.a *= pulse
		var reach: float = minf(size.x, size.y) * lerpf(0.10, 0.27, pulse)
		_draw_corner_web(Vector2.ZERO, Vector2(1.0, 1.0), reach, line_color, glow_color)
		_draw_corner_web(Vector2(size.x, 0.0), Vector2(-1.0, 1.0), reach, line_color, glow_color)
		_draw_corner_web(Vector2(0.0, size.y), Vector2(1.0, -1.0), reach, line_color, glow_color)
		_draw_corner_web(size, Vector2(-1.0, -1.0), reach, line_color, glow_color)
		_draw_edge_strand(Vector2(size.x * 0.20, 0.0), Vector2(0.12, 1.0), reach * 0.62, line_color, glow_color)
		_draw_edge_strand(Vector2(size.x * 0.78, size.y), Vector2(-0.18, -1.0), reach * 0.58, line_color, glow_color)
		_draw_edge_strand(Vector2(0.0, size.y * 0.36), Vector2(1.0, -0.12), reach * 0.66, line_color, glow_color)
		_draw_edge_strand(Vector2(size.x, size.y * 0.62), Vector2(-1.0, 0.16), reach * 0.60, line_color, glow_color)

	func _draw_corner_web(origin: Vector2, direction: Vector2, reach: float, line_color: Color, glow_color: Color) -> void:
		var endpoints: Array = [
			origin + Vector2(direction.x * reach, 0.0),
			origin + Vector2(direction.x * reach * 0.78, direction.y * reach * 0.28),
			origin + Vector2(direction.x * reach * 0.50, direction.y * reach * 0.64),
			origin + Vector2(0.0, direction.y * reach)
		]
		for endpoint_var: Variant in endpoints:
			var endpoint: Vector2 = endpoint_var
			draw_line(origin, endpoint, glow_color, 4.0, true)
			draw_line(origin, endpoint, line_color, 1.3, true)
		for ring_var: Variant in [0.34, 0.58, 0.82]:
			var ring: float = float(ring_var)
			var points := PackedVector2Array()
			for endpoint_var: Variant in endpoints:
				var endpoint: Vector2 = endpoint_var
				points.append(origin.lerp(endpoint, ring))
			draw_polyline(points, glow_color, 3.0, true)
			draw_polyline(points, line_color, 1.1, true)

	func _draw_edge_strand(start: Vector2, direction: Vector2, length: float, line_color: Color, glow_color: Color) -> void:
		var points := PackedVector2Array()
		points.append(start)
		points.append(start + Vector2(direction.x * length * 0.34, direction.y * length * 0.34) + Vector2(direction.y, -direction.x) * 7.0)
		points.append(start + Vector2(direction.x * length * 0.68, direction.y * length * 0.68) - Vector2(direction.y, -direction.x) * 5.0)
		points.append(start + direction * length)
		draw_polyline(points, glow_color, 4.0, true)
		draw_polyline(points, line_color, 1.2, true)

class RelicChoiceSparkleLayer:
	extends Control

	var accent: Color = Color("f0c978")
	var phase: float = 0.0
	var halo_texture: Texture2D = null:
		set(value):
			halo_texture = value
			if _halo != null:
				_halo.texture = halo_texture
	var glint_texture: Texture2D = null:
		set(value):
			glint_texture = value
			for glint_var: Variant in _glints:
				var glint: TextureRect = glint_var
				glint.texture = glint_texture
			for dust_var: Variant in _dust:
				var dust: TextureRect = dust_var
				dust.texture = glint_texture

	var _halo: TextureRect = null
	var _glints: Array = []
	var _dust: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		set_process(false)

	func _ready() -> void:
		_ensure_texture_nodes()
		_layout_texture_nodes()
		_animate_texture_nodes()
		set_process(is_visible_in_tree())

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layout_texture_nodes()
		elif what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			set_process(false)
			return
		phase = wrapf(phase + delta, 0.0, 3600.0)
		_animate_texture_nodes()

	func _ensure_texture_nodes() -> void:
		if _halo == null:
			_halo = TextureRect.new()
			_halo.name = "RelicChoiceRuneHalo"
			_configure_texture_rect(_halo)
			_halo.texture = halo_texture
			_halo.z_index = 0
			add_child(_halo)
		while _glints.size() < 9:
			var glint := TextureRect.new()
			glint.name = "RelicChoiceGlint%d" % _glints.size()
			_configure_texture_rect(glint)
			glint.texture = glint_texture
			glint.z_index = 1
			_glints.append(glint)
			add_child(glint)
		while _dust.size() < 16:
			var dust := TextureRect.new()
			dust.name = "RelicChoiceDust%d" % _dust.size()
			_configure_texture_rect(dust)
			dust.texture = glint_texture
			dust.z_index = 1
			_dust.append(dust)
			add_child(dust)

	func _configure_texture_rect(rect: TextureRect) -> void:
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE

	func _layout_texture_nodes() -> void:
		_ensure_texture_nodes()
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var icon_center := Vector2(size.x * 0.5, size.y * 0.34)
		var halo_inset := Vector2(12.0, 12.0)
		var halo_size := size + halo_inset * 2.0
		_halo.size = halo_size
		_halo.position = -halo_inset
		_halo.pivot_offset = halo_size * 0.5
		_halo.visible = halo_texture != null

		var glint_layout: Array = [
			{"pos": Vector2(27.0, 26.0), "size": 34.0},
			{"pos": Vector2(size.x - 30.0, 29.0), "size": 32.0},
			{"pos": Vector2(size.x * 0.50, 22.0), "size": 28.0},
			{"pos": Vector2(size.x * 0.25, 88.0), "size": 27.0},
			{"pos": Vector2(size.x * 0.76, 86.0), "size": 30.0},
			{"pos": Vector2(37.0, size.y - 40.0), "size": 26.0},
			{"pos": Vector2(size.x - 40.0, size.y - 42.0), "size": 30.0},
			{"pos": Vector2(size.x * 0.50, size.y - 24.0), "size": 24.0},
			{"pos": Vector2(size.x * 0.82, size.y - 76.0), "size": 22.0}
		]
		for index: int in range(_glints.size()):
			var glint: TextureRect = _glints[index]
			var entry: Dictionary = glint_layout[index]
			var glint_size := Vector2.ONE * float(entry.get("size", 40.0))
			glint.size = glint_size
			glint.position = (entry.get("pos", Vector2.ZERO) as Vector2) - glint_size * 0.5
			glint.pivot_offset = glint_size * 0.5
			glint.visible = glint_texture != null

		for index: int in range(_dust.size()):
			var dust: TextureRect = _dust[index]
			var dust_size: float = 12.0 + float(index % 4) * 2.5
			dust.size = Vector2.ONE * dust_size
			dust.pivot_offset = dust.size * 0.5
			dust.visible = glint_texture != null

	func _animate_texture_nodes() -> void:
		_ensure_texture_nodes()
		var shimmer: float = 0.5 + 0.5 * sin(phase * 2.25)
		_halo.rotation = sin(phase * 0.34) * 0.035
		_halo.scale = Vector2.ONE * (1.0 + 0.018 * shimmer)
		_halo.modulate = _accent_modulate(0.76 + 0.18 * shimmer)
		var glint_delays := [0.0, 0.18, 0.34, 0.51, 0.67, 0.82, 0.94, 0.27, 0.73]
		for index: int in range(_glints.size()):
			var glint: TextureRect = _glints[index]
			var pulse: float = 0.5 + 0.5 * sin(phase * 3.0 + float(glint_delays[index]) * TAU)
			glint.rotation = sin(phase * 0.72 + float(index)) * 0.22
			glint.scale = Vector2.ONE * (0.72 + 0.58 * pulse)
			glint.modulate = _accent_modulate(0.22 + 0.70 * pow(pulse, 2.0))
		var center := Vector2(size.x * 0.5, size.y * 0.50)
		for index: int in range(_dust.size()):
			var dust: TextureRect = _dust[index]
			var angle: float = phase * (0.13 + float(index % 4) * 0.028) + float(index) * TAU / float(_dust.size())
			var radius := Vector2(size.x * (0.40 + 0.025 * float(index % 2)), size.y * (0.41 + 0.018 * float((index + 1) % 2)))
			var offset := Vector2(cos(angle) * radius.x, sin(angle * 0.86) * radius.y)
			var drift: float = 0.5 + 0.5 * sin(phase * 1.55 + float(index) * 1.7)
			dust.position = center + offset - dust.size * 0.5
			dust.rotation = angle
			dust.scale = Vector2.ONE * (0.48 + 0.42 * drift)
			dust.modulate = _accent_modulate(0.12 + 0.30 * drift)

	func _accent_modulate(alpha: float) -> Color:
		return Color(
			clampf(0.92 + accent.r * 0.10, 0.0, 1.0),
			clampf(0.82 + accent.g * 0.14, 0.0, 1.0),
			clampf(0.56 + accent.b * 0.16, 0.0, 1.0),
			alpha
		)

class SelectionBannerEffect:
	extends Control

	var accent: Color = Color("f0c978"):
		set(value):
			accent = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		if size.x < 180.0 or size.y < 52.0:
			return
		var width: float = size.x
		var height: float = size.y
		var tail_inset: float = clampf(width * 0.085, 34.0, 54.0)
		var body_points := PackedVector2Array([
			Vector2(tail_inset, 7.0),
			Vector2(width - tail_inset, 7.0),
			Vector2(width - tail_inset + 11.0, height * 0.5),
			Vector2(width - tail_inset, height - 9.0),
			Vector2(tail_inset, height - 9.0),
			Vector2(tail_inset - 11.0, height * 0.5),
		])
		var left_tail := PackedVector2Array([
			Vector2(2.0, 17.0),
			Vector2(tail_inset + 5.0, 11.0),
			Vector2(tail_inset, height - 13.0),
			Vector2(2.0, height - 18.0),
			Vector2(13.0, height * 0.5),
		])
		var right_tail := PackedVector2Array([
			Vector2(width - 2.0, 17.0),
			Vector2(width - tail_inset - 5.0, 11.0),
			Vector2(width - tail_inset, height - 13.0),
			Vector2(width - 2.0, height - 18.0),
			Vector2(width - 13.0, height * 0.5),
		])
		var shadow_offset := Vector2(0.0, 7.0)
		draw_colored_polygon(_offset_banner_points(left_tail, shadow_offset), Color(0.0, 0.0, 0.0, 0.55))
		draw_colored_polygon(_offset_banner_points(right_tail, shadow_offset), Color(0.0, 0.0, 0.0, 0.55))
		draw_colored_polygon(_offset_banner_points(body_points, shadow_offset), Color(0.0, 0.0, 0.0, 0.68))
		var tail_color: Color = Color("38221d").lerp(accent.darkened(0.62), 0.22)
		var body_color: Color = Color("25151b").lerp(accent.darkened(0.78), 0.18)
		draw_colored_polygon(left_tail, tail_color)
		draw_colored_polygon(right_tail, tail_color)
		draw_colored_polygon(body_points, body_color)
		draw_polyline(_closed_banner_points(body_points), Color(accent.r, accent.g, accent.b, 0.82), 2.0, true)
		var inner_rect := Rect2(
			Vector2(tail_inset + 6.0, 13.0),
			Vector2(width - (tail_inset + 6.0) * 2.0, height - 28.0)
		)
		draw_rect(inner_rect, Color(0.02, 0.012, 0.018, 0.30), true)
		draw_rect(inner_rect, Color(accent.r, accent.g, accent.b, 0.28), false, 1.0)
		draw_line(
			Vector2(tail_inset + 12.0, 12.0),
			Vector2(width - tail_inset - 12.0, 12.0),
			Color(1.0, 0.88, 0.58, 0.20),
			1.0,
			true
		)
		draw_line(
			Vector2(tail_inset + 7.0, height - 13.0),
			Vector2(width - tail_inset - 7.0, height - 13.0),
			Color(0.0, 0.0, 0.0, 0.58),
			2.0,
			true
		)
		var fold_color: Color = Color(accent.r, accent.g, accent.b, 0.36)
		draw_line(Vector2(tail_inset, 14.0), Vector2(tail_inset - 8.0, height * 0.5), fold_color, 2.0, true)
		draw_line(Vector2(width - tail_inset, 14.0), Vector2(width - tail_inset + 8.0, height * 0.5), fold_color, 2.0, true)

	func _offset_banner_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
		var shifted := PackedVector2Array()
		for point: Vector2 in points:
			shifted.append(point + offset)
		return shifted

	func _closed_banner_points(points: PackedVector2Array) -> PackedVector2Array:
		var closed: PackedVector2Array = points.duplicate()
		if not closed.is_empty():
			closed.append(closed[0])
		return closed

class RelicChoiceTitleEffect:
	extends Control

	const UiTypographyScript = preload("res://scripts/ui_typography.gd")

	var accent: Color = Color("f0c978"):
		set(value):
			accent = value
			_sync_label_style()
	var title_text: String = "":
		set(value):
			title_text = value
			_sync_label_text()
	var font_size: int = 76:
		set(value):
			font_size = value
			_sync_label_size()
	var phase: float = 0.0

	var _shadow_label: Label = null
	var _glow_label: Label = null
	var _bevel_label: Label = null
	var _shimmer_label: RichTextLabel = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false
		set_process(false)

	func _ready() -> void:
		_ensure_labels()
		_sync_label_text()
		_sync_label_size()
		_sync_label_style()
		_layout_labels()
		_animate_labels()
		set_process(is_visible_in_tree())

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layout_labels()
		elif what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			set_process(false)
			return
		phase = wrapf(phase + delta, 0.0, 3600.0)
		_animate_labels()

	func _ensure_labels() -> void:
		if _shadow_label == null:
			_shadow_label = _make_effect_label("TreasureTitleCastShadow", 0)
		if _glow_label == null:
			_glow_label = _make_effect_label("TreasureTitleGlyphGlow", 1)
		if _bevel_label == null:
			_bevel_label = _make_effect_label("TreasureTitleTopLight", 2)
		if _shimmer_label == null:
			_shimmer_label = _make_shimmer_label()

	func _make_effect_label(node_name: String, draw_order: int) -> Label:
		var label := Label.new()
		label.name = node_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
		label.z_index = draw_order
		add_child(label)
		return label

	func _make_shimmer_label() -> RichTextLabel:
		var label := RichTextLabel.new()
		label.name = "TreasureTitleShimmer"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.bbcode_enabled = true
		label.fit_content = false
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_contents = false
		label.z_index = 3
		add_child(label)
		return label

	func _sync_label_text() -> void:
		_ensure_labels()
		for label: Label in [_shadow_label, _glow_label, _bevel_label]:
			label.text = title_text
		_update_shimmer_text()

	func _sync_label_size() -> void:
		_ensure_labels()
		for label: Label in [_shadow_label, _glow_label, _bevel_label]:
			UiTypographyScript.apply_label_role(label, UiTypographyScript.ROLE_BANNER)
			UiTypographyScript.set_label_size(label, font_size)
		UiTypographyScript.apply_rich_text_role(_shimmer_label, UiTypographyScript.ROLE_BANNER)
		UiTypographyScript.set_rich_text_size(_shimmer_label, font_size)

	func _sync_label_style() -> void:
		_ensure_labels()
		_shadow_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.58))
		_shadow_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.52))
		_shadow_label.add_theme_constant_override("outline_size", 11)
		_glow_label.add_theme_color_override("font_color", _accent_color(0.26))
		_glow_label.add_theme_color_override("font_outline_color", _accent_color(0.34))
		_glow_label.add_theme_constant_override("outline_size", 15)
		_bevel_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.70, 0.18))
		_bevel_label.add_theme_color_override("font_outline_color", Color(1.0, 0.94, 0.70, 0.0))
		_bevel_label.add_theme_constant_override("outline_size", 0)
		_shimmer_label.add_theme_color_override("default_color", Color(1.0, 0.95, 0.76, 0.0))

	func _layout_labels() -> void:
		_ensure_labels()
		var center_pivot := Vector2(size.x * 0.5, size.y * 0.5)
		_shadow_label.position = Vector2(0.0, 8.0)
		_glow_label.position = Vector2.ZERO
		_bevel_label.position = Vector2(0.0, -2.0)
		for label: Label in [_shadow_label, _glow_label, _bevel_label]:
			label.set_anchors_preset(Control.PRESET_TOP_LEFT)
			label.size = size
			label.pivot_offset = center_pivot
		_shimmer_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var shimmer_top: float = maxf(0.0, (size.y - float(font_size) * 1.18) * 0.5)
		_shimmer_label.position = Vector2(0.0, shimmer_top - 2.0)
		_shimmer_label.size = Vector2(size.x, size.y - shimmer_top)
		_shimmer_label.pivot_offset = center_pivot

	func _animate_labels() -> void:
		_ensure_labels()
		var breath: float = 0.5 + 0.5 * sin(phase * 1.45)
		_shadow_label.modulate = Color(1.0, 1.0, 1.0, 0.92)
		_shadow_label.position = Vector2(0.0, 7.0 + 1.2 * breath)
		_glow_label.modulate = Color(1.0, 1.0, 1.0, 0.58 + 0.16 * breath)
		_glow_label.scale = Vector2.ONE * (1.0 + 0.006 * breath)
		_bevel_label.modulate = Color(1.0, 1.0, 1.0, 0.76 + 0.14 * sin(phase * 2.1))
		_shimmer_label.modulate = Color(1.0, 1.0, 1.0, 0.94 + 0.06 * breath)
		_update_shimmer_text()

	func _update_shimmer_text() -> void:
		if _shimmer_label == null:
			return
		if title_text.is_empty():
			_shimmer_label.text = ""
			return
		var span: float = float(maxi(title_text.length(), 1)) + 8.0
		var sweep_center: float = fposmod(phase * 4.1, span) - 4.0
		var pieces := PackedStringArray()
		pieces.append("[center]")
		for index: int in range(title_text.length()):
			var glyph: String = title_text.substr(index, 1)
			var distance: float = absf(float(index) - sweep_center)
			var core: float = clampf(1.0 - distance / 1.85, 0.0, 1.0)
			var tail: float = clampf(1.0 - distance / 5.40, 0.0, 1.0)
			var flicker: float = 0.5 + 0.5 * sin(phase * 5.2 + float(index) * 0.78)
			var strength: float = clampf(pow(core, 1.24) + pow(tail, 2.55) * 0.46 + flicker * core * 0.14, 0.0, 1.0)
			if strength > 0.015 and glyph != " ":
				pieces.append("[color=#%s]%s[/color]" % [_shimmer_glyph_color(strength).to_html(true), _bbcode_glyph(glyph)])
			else:
				pieces.append(_bbcode_glyph(glyph))
		pieces.append("[/center]")
		_shimmer_label.text = "".join(pieces)

	func _shimmer_glyph_color(strength: float) -> Color:
		var low: Color = accent.lightened(0.44)
		var high: Color = Color("fffef4").lerp(accent.lightened(0.62), 0.10)
		var color: Color = low.lerp(high, clampf(strength * 1.24, 0.0, 1.0))
		color.a = 0.08 + 0.80 * strength
		return color

	func _bbcode_glyph(glyph: String) -> String:
		if glyph == "[":
			return "[lb]"
		if glyph == "]":
			return "[rb]"
		return glyph

	func _accent_color(alpha: float) -> Color:
		return Color(
			clampf(0.76 + accent.r * 0.28, 0.0, 1.0),
			clampf(0.58 + accent.g * 0.36, 0.0, 1.0),
			clampf(0.28 + accent.b * 0.28, 0.0, 1.0),
			alpha
		)

class RelicAcquisitionBeam:
	extends TextureRect

	var start: Vector2 = Vector2.ZERO:
		set(value):
			start = value
			_sync_layout()
	var target: Vector2 = Vector2.ZERO:
		set(value):
			target = value
			_sync_layout()
	var accent: Color = Color("f0c978"):
		set(value):
			accent = value
			self_modulate = _accent_modulate(1.0)
	var progress: float = 0.0:
		set(value):
			progress = clampf(value, 0.0, 1.0)
			_sync_layout()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		self_modulate = _accent_modulate(1.0)

	func _sync_layout() -> void:
		if progress <= 0.0:
			visible = false
			return
		var t: float = clampf(progress, 0.0, 1.0)
		var lead: Vector2 = start.lerp(target, t)
		var delta: Vector2 = lead - start
		var length: float = delta.length()
		if length <= 2.0:
			visible = false
			return
		var beam_height: float = 24.0 + 8.0 * sin(t * PI)
		size = Vector2(length, beam_height)
		pivot_offset = Vector2(0.0, beam_height * 0.5)
		position = start - pivot_offset
		rotation = delta.angle()
		visible = texture != null

	func _accent_modulate(alpha: float) -> Color:
		return Color(
			clampf(accent.r * 1.10, 0.0, 1.0),
			clampf(accent.g * 1.06, 0.0, 1.0),
			clampf(accent.b * 1.02, 0.0, 1.0),
			alpha
		)

class RelicAcquisitionMote:
	extends TextureRect

	var accent: Color = Color("f0c978"):
		set(value):
			accent = value
			self_modulate = _accent_modulate(1.0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		self_modulate = _accent_modulate(1.0)

	func _accent_modulate(alpha: float) -> Color:
		return Color(
			clampf(accent.r * 1.14, 0.0, 1.0),
			clampf(accent.g * 1.10, 0.0, 1.0),
			clampf(accent.b * 1.04, 0.0, 1.0),
			alpha
		)

class LoadoutAcquisitionBurst:
	extends Control

	var accent: Color = Color("f0c978")
	var kind: String = "magic"
	var progress: float = 0.0:
		set(value):
			progress = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if progress <= 0.0 or progress >= 1.0:
			return
		var center: Vector2 = size * 0.5
		var flare: float = sin(progress * PI)
		var radius: float = lerpf(22.0, 94.0, 1.0 - pow(1.0 - progress, 3.0))
		var ring_color := Color(accent.r, accent.g, accent.b, 0.72 * flare)
		var core_color := Color(1.0, 0.96, 0.78, 0.92 * flare)
		draw_arc(center, radius, 0.0, TAU, 64, ring_color, 4.0 if kind == "equipment" else 2.5, true)
		if kind == "magic":
			draw_arc(center, radius * 0.68, progress * 2.8, progress * 2.8 + PI * 1.45, 40, core_color, 2.0, true)
			for index: int in range(12):
				var angle: float = TAU * float(index) / 12.0 - progress * 2.2
				var rune_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.82
				var tangent := Vector2(-sin(angle), cos(angle))
				var radial := Vector2(cos(angle), sin(angle))
				draw_line(rune_center - tangent * 5.0, rune_center + radial * 6.0, ring_color, 2.0, true)
		else:
			for index: int in range(8):
				var angle: float = TAU * float(index) / 8.0 + 0.18
				var direction := Vector2(cos(angle), sin(angle))
				var start: Vector2 = center + direction * radius * 0.48
				var finish: Vector2 = center + direction * radius * (0.88 + 0.10 * float(index % 2))
				draw_line(start, finish, ring_color, 5.0, true)
				draw_line(start, finish, core_color, 1.5, true)

const STEP_DELAY_SECONDS: float = 0.26
const MOVE_STEP_FRAMES: int = 8
const MOVE_FRAME_SECONDS: float = 0.045
const ATTACK_FRAMES: int = 6
const ATTACK_FRAME_SECONDS: float = 0.04
const MISSED_EQUIPMENT_FRAMES: int = 10
const MISSED_EQUIPMENT_FRAME_SECONDS: float = 0.045
const DRAW_FRAME_SECONDS: float = 0.32
const DRAW_STAGGER_SECONDS: float = 0.16
const CARD_PLAY_SECONDS: float = 0.30
const CARD_PLAY_HOLD_SECONDS: float = 0.11
const CARD_PILE_SECONDS: float = 0.28
const CARD_SNAPBACK_SECONDS: float = 0.16
const CARD_DRAW_ARC_HEIGHT: float = 54.0
const CARD_PLAY_ARC_HEIGHT: float = 58.0
const CARD_PILE_ARC_HEIGHT: float = 42.0
const CARD_DRAG_TILT_DEGREES: float = 4.5
const CARD_DRAG_LIFT_SCALE: float = 1.025
const CARD_PROXY_POOL_LIMIT: int = 2
const DOOR_OPENING_FRAMES: int = 8
const DOOR_OPENING_FRAME_SECONDS: float = 0.075
const DOOR_OPENING_SETTLE_SECONDS: float = 0.04
const FLOAT_TEXT_FRAMES: int = 7
const FLOAT_TEXT_FRAME_SECONDS: float = 0.05
const ENEMY_DEATH_MIN_FRAMES: int = 8
const ENEMY_DEATH_FALLBACK_FRAMES: int = 16
const ENEMY_DEATH_FALLBACK_FRAME_SECONDS: float = 0.065
const TERRAIN_DESTRUCTION_FALLBACK_FRAMES: int = 16
const TERRAIN_DESTRUCTION_FALLBACK_FRAME_SECONDS: float = 0.065
const IMPACT_DECAL_MAX_TILES: int = 7
const FATIGUE_EFFECT_FRAMES: int = 9
const FATIGUE_EFFECT_FRAME_SECONDS: float = 0.045
const FATIGUE_EDGE_LINGER_FRAMES: int = 3
const FATIGUE_EDGE_HOLD_PROGRESS: float = 0.82
const PLAYER_PREVIEW_FOCUS: Color = Color("f1d18b")
const PLAYER_ATTACK_FOCUS: Color = Color("f08c53")
const ILLUSION_PREVIEW_FOCUS: Color = Color("9beeff")
const ENEMY_PATH_PREVIEW_COLOR: Color = Color("b78cff")
const INVALID_TARGET_TILE: Vector2i = Vector2i(-1, -1)
const INVALID_ROOM_COORD: Vector2i = Vector2i(999, 999)
const SHORTCUT_ATTACK_TYPES := ["melee", "ranged", "push", "pull"]
const FALLBACK_ATTACK_BASE_DAMAGE: int = 3
const FALLBACK_MOVE_RANGE: int = 2
const CARD_WIDGET_BASE_SIZE: Vector2 = Vector2(250.0, 352.0)
const CARD_ASPECT_RATIO: float = 352.0 / 250.0
const ORIENTATION_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
const HAND_CARD_OVERLAP: float = -28.0
const HAND_CARD_GAP: float = 14.0
const HAND_READY_WAVE_STAGGER_SECONDS: float = 0.055
const PILE_CARD_SIZE: Vector2 = Vector2(220.0, 220.0 * CARD_ASPECT_RATIO)
const PILE_DIALOG_CARD_SIZE: Vector2 = Vector2(196.0, 196.0 * CARD_ASPECT_RATIO)
const PILE_DIALOG_FULL_SIZE: Vector2 = Vector2(1220.0, 620.0)
const PILE_DIALOG_ROW_SIZE: Vector2 = Vector2(1220.0, 438.0)
const PILE_DIALOG_EMPTY_SIZE: Vector2 = Vector2(520.0, 238.0)
const PILE_DIALOG_MIN_CARD_WIDTH: float = 620.0
const PILE_CARD_SCALE: float = 0.80
const PILE_STACK_OFFSET: Vector2 = Vector2(8.0, 10.0)
const PILE_STACK_LAYERS: int = 3
const UPGRADE_CARD_SIZE: Vector2 = Vector2(186.0, 186.0 * CARD_ASPECT_RATIO)
const CARD_BACK_TEXTURE_PATH: String = "res://assets/art/ui/card_back.png"
const CARD_FRAME_TEXTURE_PATH: String = "res://assets/art/ui/card_frame.png"
const CARD_PLAY_ICON_PATH: String = "res://assets/art/icons/card_play.png"
const ACTION_STEP_TRACKER_MIN_SIZE: Vector2 = Vector2(328.0, 116.0)
const ACTION_STEP_CHIP_SIZE: Vector2 = Vector2(46.0, 46.0)
const ACTION_STEP_ICON_INSET: float = 9.0
const ACTION_STEP_TRACKER_GAP: float = 12.0
const ACTION_CONTEXT_MAX_WIDTH: float = 960.0
const ACTION_CONTEXT_EDGE_MARGIN: float = 16.0
const ACTION_CONTEXT_COMMAND_SIZE: Vector2 = Vector2(144.0, 50.0)
const CARD_ACTION_MODE_OPTION_HEIGHT: float = 40.0
const ACTION_CONTEXT_BUTTON_MIN_WIDTH: float = 94.0
const ACTION_CONTEXT_CONNECTOR_WIDTH: float = 3.0
const CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP: float = 8.0
const CONTEXTUAL_COMBAT_PROMPT_VIEWPORT_MARGIN: float = 4.0
const PLAYER_UNIT_TEXTURE_PATH: String = "res://assets/placeholders/units/player_reaver.png"
const HEALTH_ICON_PATH: String = "res://assets/art/icons/health.png"
const RELIC_BADGE_SIZE: Vector2 = Vector2(52.0, 52.0)
const RELIC_BAR_HORIZONTAL_GAP: float = 8.0
const RELIC_BAR_MIN_VISIBLE_RELICS: int = 8
const SKILL_SIGIL_SIZE: Vector2 = Vector2(200.0, 56.0)
const SKILL_SIGIL_COMPACT_SIZE: Vector2 = Vector2(132.0, 56.0)
const SKILL_SIGIL_PREVIEW_ICON_SIZE: Vector2 = Vector2(28.0, 28.0)
const SKILL_SIGIL_PREVIEW_COUNT: int = 2
const SKILL_SIGIL_COMPACT_PREVIEW_COUNT: int = 1
const SKILL_SIGIL_COMPACT_VIEWPORT_WIDTH: float = 1100.0
const SKILL_STATUS_POPOVER_SIZE: Vector2 = Vector2(800.0, 492.0)
const SKILL_STATUS_TILE_SIZE: Vector2 = Vector2(132.0, 92.0)
const SKILL_STATUS_DETAIL_HEIGHT: float = 136.0
const SKILL_STATUS_PAGE_SIZE: int = 10
const SKILL_STATUS_GRID_COLUMNS: int = 5
const SKILL_CARD_SELECTION_PROMPT_SIZE: Vector2 = Vector2(620.0, 56.0)
const SKILL_CHOICE_DIALOG_SIZE: Vector2 = Vector2(610.0, 520.0)
const SKILL_CHOICE_DIALOG_MIN_SIZE: Vector2 = Vector2(360.0, 320.0)
const HEADER_RELIC_WRAP_MARGIN: float = 24.0
const ELEMENTAL_INTENSITY_HEADER_GAP: float = 3.0
const INTENSITY_BADGE_SIZE: Vector2 = Vector2(87.0, 87.0)
const INTENSITY_ICON_INSET: float = 8.0
const CAMPFIRE_ACTION_OVERLAY_SIZE: Vector2 = Vector2(468.0, 88.0)
const CAMPFIRE_LINGER_HEAL_AMOUNT: int = RunEngineScript.CAMPFIRE_LINGER_HEAL
const CAMPFIRE_CHOICE_LINGER_ICON_PATH: String = "res://assets/art/ui/campfire_choice_linger.png"
const CAMPFIRE_CHOICE_EMBRACE_ICON_PATH: String = "res://assets/art/ui/campfire_choice_embrace.png"
const CAMPFIRE_CHOICE_STRENGTH_ICON_PATH: String = "res://assets/art/ui/campfire_choice_strength.png"
const CAMPFIRE_CHOICE_LINGER_TEXT: String = "Linger for a moment"
const CAMPFIRE_CHOICE_EMBRACE_TEXT: String = "Embrace the fire's warmth"
const CAMPFIRE_CHOICE_STRENGTH_TEXT: String = "Learn a new skill"
const CAMPFIRE_CHOICE_LINGER_DESCRIPTION: String = "Heal, continue"
const CAMPFIRE_CHOICE_EMBRACE_DESCRIPTION: String = "Bank embers, end run"
const CAMPFIRE_CHOICE_STRENGTH_DESCRIPTION: String = "Spend embers, choose a skill, continue"
const CAMPFIRE_CHOICE_CHIP_SIZE: Vector2 = Vector2(108.0, 34.0)
const MERCHANT_PANEL_SIZE: Vector2 = Vector2(940.0, 290.0)
const MERCHANT_COLUMN_SIZE: Vector2 = Vector2(430.0, 236.0)
const MERCHANT_ROW_HEIGHT: float = 58.0
const MERCHANT_ICON_SIZE: Vector2 = Vector2(44.0, 44.0)
const MERCHANT_TITLE_BLACKSMITH: String = "BLACKSMITH"
const MERCHANT_TITLE_ARCANIST: String = "ARCANIST"
const MERCHANT_TITLE_SCAVENGER: String = "SCAVENGER"
const RELIC_CHOICE_OVERLAY_SIZE: Vector2 = Vector2(1040.0, 248.0)
const RELIC_CHOICE_CARD_SIZE: Vector2 = Vector2(264.0, 220.0)
const REWARD_CHOICE_TITLE_TEXT: String = "GROW YOUR POWER"
const REWARD_CHOICE_CARD_GAP: float = 30.0
const REWARD_CHOICE_STACK_GAP: float = 18.0
const REWARD_ACTION_BUTTON_MIN_WIDTH: float = 360.0
const REWARD_REROLL_BUTTON_MIN_WIDTH: float = 160.0
const REWARD_CARD_HOVER_LIFT: float = -20.0
const REWARD_CARD_HOVER_SCALE: float = 1.10
const RELIC_CHOICE_TITLE_TEXT: String = "CLAIM YOUR TREASURE"
const RELIC_CHOICE_TITLE_FONT_SIZE: int = UiTypography.SIZE_BANNER
const RELIC_CHOICE_TITLE_HEIGHT: float = 118.0
const RELIC_CHOICE_TITLE_TOP_RATIO: float = 0.0
const RELIC_CHOICE_BOTTOM_MARGIN: float = 44.0
const SELECTION_BANNER_TEXTURE_PATH: String = "res://assets/art/ui/reward_selection_banner_v1.png"
const SELECTION_BANNER_MIN_WIDTH: float = 680.0
const SELECTION_BANNER_MAX_WIDTH: float = 760.0
const SELECTION_TITLE_FONT_SIZE: int = 32
const SELECTION_TITLE_HEIGHT: float = 110.0
const SELECTION_TITLE_TO_OFFERS_GAP: float = 14.0
const SELECTION_GROUP_TOP_BIAS: float = 0.44
const RELIC_CHOICE_RUNE_HALO_PATH: String = "res://assets/art/effects/relic_choice_rune_halo.png"
const RELIC_CHOICE_GLINT_PATH: String = "res://assets/art/effects/relic_choice_glint.png"
const RELIC_ACQUISITION_BEAM_PATH: String = "res://assets/art/effects/relic_acquisition_beam.png"
const RELIC_ACQUISITION_MOTE_PATH: String = "res://assets/art/effects/relic_acquisition_mote.png"
const RELIC_ACQUISITION_SECONDS: float = 0.38
const RELIC_ACQUISITION_MOTES: int = 8
const LOADOUT_ACQUISITION_FLAIR_SECONDS: float = 0.48
const LOADOUT_ACQUISITION_RAY_SECONDS: float = 0.42
const LOADOUT_ACQUISITION_MOTES: int = 10
const DIALOGUE_DIALOG_WIDTH: float = 1060.0
const DIALOGUE_DIALOG_HINT_MIN_HEIGHT: float = 154.0
const DIALOGUE_DIALOG_OPTION_MIN_HEIGHT: float = 206.0
const DIALOGUE_TEXT_HINT_MIN_HEIGHT: float = 46.0
const DIALOGUE_TEXT_OPTION_MIN_HEIGHT: float = 78.0
const DIALOGUE_HINT_FOOTER_HEIGHT: float = 34.0
const DIALOGUE_OPTION_BUTTON_HEIGHT: float = 58.0
const DIALOGUE_OPTION_BUTTON_MIN_WIDTH: float = 292.0
const MENU_DIALOG_BUTTON_MIN_WIDTH: float = 234.0
const MENU_OVERLAY_Z_INDEX: int = 2000
const UPGRADE_LIST_BUTTON_MIN_WIDTH: float = 216.0
const HEADER_ICON_BUTTON_SIZE: Vector2 = Vector2(68.0, 56.0)
const HEADER_ICON_TEXTURE_SIZE: int = 48
const GRIMOIRE_DIALOG_SIZE: Vector2 = Vector2(1120.0, 640.0)
const GRIMOIRE_MIN_DIALOG_SIZE: Vector2 = Vector2(820.0, 520.0)
const GRIMOIRE_LEFT_PAGE_WIDTH: float = 300.0
const GRIMOIRE_DETAIL_PAGE_WIDTH: float = 620.0
const GRIMOIRE_ENTRY_BUTTON_HEIGHT: float = 44.0
const GRIMOIRE_CARD_PREVIEW_SIZE: Vector2 = Vector2(240.0, 337.92)
const GRIMOIRE_EQUIPMENT_CARD_SIZE: Vector2 = Vector2(176.0, 246.4)
const GRIMOIRE_BADGE_SIZE: Vector2 = Vector2(18.0, 18.0)
const CHARACTER_DIALOG_SIZE: Vector2 = Vector2(1500.0, 900.0)
const CHARACTER_DIALOG_MIN_SIZE: Vector2 = Vector2(1120.0, 620.0)
const SKILL_TREE_DIALOG_SIZE: Vector2 = Vector2(1500.0, 900.0)
const SKILL_TREE_DIALOG_MIN_SIZE: Vector2 = Vector2(1120.0, 620.0)
const PROGRESSION_SUMMARY_COMPACT_VIEWPORT_WIDTH: float = 1200.0
const CHARACTER_BODY_MIN_HEIGHT: float = 360.0
const EQUIPMENT_TILE_SIZE: Vector2 = Vector2(178.0, 92.0)
const EQUIPMENT_SLOT_SIZE: Vector2 = Vector2(300.0, 58.0)
const EQUIPMENT_ICON_SIZE: Vector2 = Vector2(42.0, 42.0)
const EQUIPMENT_DRAG_GHOST_SIZE: Vector2 = Vector2(78.0, 78.0)
const EQUIPMENT_DRAG_CURSOR_OFFSET: Vector2 = Vector2(18.0, 20.0)
const EQUIPMENT_SWAP_SNAP_SECONDS: float = 0.22
const EQUIPMENT_SWAP_RETURN_SECONDS: float = 0.24
const EQUIPMENT_DECK_BADGE_SIZE: Vector2 = Vector2(164.0, 34.0)
const ITEM_EQUIPPED_TILE_SIZE: Vector2 = Vector2(300.0, 52.0)
const ITEM_INVENTORY_TILE_SIZE: Vector2 = Vector2(336.0, 56.0)
const ITEM_ART_CHIP_SIZE: Vector2 = Vector2(42.0, 42.0)
const ITEM_DRAG_CURSOR_OFFSET: Vector2 = Vector2(14.0, 18.0)
const MAGIC_ATTUNED_TILE_SIZE: Vector2 = Vector2(292.0, 46.0)
const MAGIC_INVENTORY_TILE_SIZE: Vector2 = Vector2(164.0, 38.0)
const MAGIC_DRAG_CURSOR_OFFSET: Vector2 = Vector2(14.0, 18.0)
const EQUIPMENT_TOOLTIP_CARD_SIZE: Vector2 = Vector2(150.0, 150.0 * CARD_ASPECT_RATIO)
const CARD_TOOLTIP_SIZE: Vector2 = Vector2(180.0, 180.0 * CARD_ASPECT_RATIO)
const PINNED_TOOLTIP_CURSOR_OFFSET: Vector2 = Vector2(12.0, 0.0)
const TURN_ORDER_PANEL_MIN_SIZE: Vector2 = Vector2(840.0, 104.0)
const TURN_ORDER_PANEL_MIN_WIDTH: float = 520.0
const TURN_ORDER_LABEL_WIDTH: float = 118.0
const TURN_ORDER_BOSS_DOSSIER_WIDTH: float = 206.0
const TURN_ORDER_BOSS_HEALTH_HEIGHT: float = 16.0
const TURN_ORDER_BOSS_MAX_SEGMENTS: int = 48
const TURN_ORDER_PORTRAIT_SIZE: Vector2 = Vector2(84.0, 84.0)
const TURN_ORDER_ACTIVE_SIZE: Vector2 = Vector2(84.0, 84.0)
const TURN_ORDER_SLOT_GAP: float = 9.0
const TURN_ORDER_MAX_SLOTS: int = 10
const TURN_ORDER_REMOVE_SECONDS: float = 0.18
const TURN_ORDER_REFLOW_SECONDS: float = 0.24
const TURN_ORDER_INSERT_SECONDS: float = 0.20
const TURN_ORDER_STYLE_SECONDS: float = 0.18
const TURN_ORDER_FLOAT_OFFSET: float = 24.0
const PASS_PREVIEW_CHIP_SIZE: Vector2 = Vector2(340.0, 64.0)
const PASS_PREVIEW_DANGER_CHIP_HEIGHT: float = 88.0
const PASS_PREVIEW_STACK_GAP: float = 6.0
const PASS_PREVIEW_VALUE_SIZE: Vector2 = Vector2(54.0, 34.0)
const PASS_PREVIEW_STONESKIN_ICON_PATH: String = "res://assets/art/icons/stoneskin.png"
const PASS_PREVIEW_BLOCK_ICON_PATH: String = "res://assets/art/icons/block.png"
const PASS_PREVIEW_HEALTH_ICON_PATH: String = "res://assets/art/icons/health.png"
const PASS_PREVIEW_DEFIANCE_ICON_PATH: String = "res://assets/art/icons/defiance.png"
const PRE_BATTLE_DIALOG_SIZE: Vector2 = Vector2(1210.0, 770.0)
const PRE_BATTLE_DIALOG_MIN_SIZE: Vector2 = Vector2(980.0, 560.0)
const PRE_BATTLE_ENEMY_CARD_SOLO_SIZE: Vector2 = Vector2(420.0, 270.0)
const PRE_BATTLE_ENEMY_CARD_SIZE: Vector2 = Vector2(252.0, 188.0)
const PRE_BATTLE_ENEMY_CARD_COMPACT_SIZE: Vector2 = Vector2(198.0, 152.0)
const PRE_BATTLE_EQUIPMENT_ICON_SIZE: Vector2 = Vector2(46.0, 46.0)
const PRE_BATTLE_CARD_BADGE_COMPACT_SIZE: Vector2 = Vector2(120.0, 33.0)
const PRE_BATTLE_CARD_BADGE_DENSE_SIZE: Vector2 = Vector2(120.0, 34.0)
const PRE_BATTLE_CARD_BADGE_DENSE_THRESHOLD: int = 9
const PRE_BATTLE_CARD_LIMIT: int = 18
const PRE_BATTLE_PORTRAIT_INSET: float = 12.0
const PRE_BATTLE_UMBRA_COLOR: Color = Color("c78bea")
const PRE_BATTLE_HP_COLOR: Color = Color("f08a7a")
const PRE_BATTLE_INITIATIVE_COLOR: Color = Color("8ec5ff")
const TURN_ORDER_PORTRAITS := {
	"player": "res://assets/art/portraits/player_reaver.png",
	"crawler": "res://assets/art/portraits/tunnel_crawler.png",
	"acolyte": "res://assets/art/portraits/dust_acolyte.png",
	"harrier": "res://assets/art/portraits/bone_harrier.png",
	"grave_surgeon": "res://assets/art/portraits/grave_surgeon.png",
	"warden": "res://assets/art/portraits/stone_warden.png",
	"bile_bloomer": "res://assets/art/portraits/bile_bloomer.png",
	"chainbound_gaoler": "res://assets/art/portraits/chainbound_gaoler.png",
	"zekarion": "res://assets/art/portraits/zekarion.png",
	"tharokh": "res://assets/art/portraits/tharokh.png",
	"vyraketh": "res://assets/art/portraits/vyraketh.png",
	"vaeloryx": "res://assets/art/portraits/vaeloryx.png",
	"iskaldra": "res://assets/art/portraits/iskaldra.png",
	"noctyrax": "res://assets/art/portraits/noctyrax.png",
	"veilbound_acolyte": "res://assets/art/portraits/dust_acolyte.png",
	"lightning_wisp": "res://assets/art/portraits/lightning_wisp.png",
	"frostglass_lancer": "res://assets/art/enemies/frostglass_lancer.png",
	"cinder_ooze": "res://assets/art/portraits/cinder_ooze.png",
	"cinder_droplet": "res://assets/art/portraits/cinder_droplet.png"
}
const MUSIC_FADE_SECONDS: float = 2.5
const MUSIC_SILENCE_DB: float = -60.0
const COMBAT_CONTINUATION_KEY: String = "pending_combat_checkpoints"
const PASS_PREVIEW_CACHE_LIMIT: int = 64
@onready var ui_root: Control = $UiLayer/UiRoot
@onready var top_bar: HBoxContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar
@onready var title_box: VBoxContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox
@onready var room_title: Label = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/RoomTitle
@onready var room_subtitle: Label = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/RoomSubtitle
@onready var umbra_subtitle: Label = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/UmbraSubtitle
@onready var relic_bar: HFlowContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/RelicBar
@onready var header_spacer: Control = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/Spacer
@onready var stats_label: Label = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/StatsLabel
@onready var loadout_button: Button = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/LoadoutButton
@onready var grimoire_button: Button = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/GrimoireButton
@onready var menu_button: Button = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/MenuButton
@onready var stage_root: Control = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot
@onready var board_backdrop: TextureRect = $BoardUnderlay/BoardBackdrop
@onready var board_view = $BoardUnderlay/CombatBoard
@onready var action_banner: Label = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/ActionBanner
@onready var mini_map_overlay: PanelContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay
@onready var mini_map = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay/MiniMapMargin/MiniMap
@onready var log_overlay: PanelContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/LogOverlay
@onready var log_label: RichTextLabel = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/LogOverlay/LogMargin/Log
@onready var bottom_stack: VBoxContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack
@onready var left_action_stack: VBoxContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack
@onready var choice_bar: HBoxContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar
@onready var hand_row: HBoxContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow
@onready var piles_bar: HBoxContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar
@onready var draw_pile: PanelContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DrawPile
@onready var discard_pile: PanelContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DiscardPile
@onready var burn_pile: PanelContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/BurnPile
@onready var draw_count: Label = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DrawPile/DrawMargin/DrawVBox/DrawCount
@onready var discard_count: Label = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DiscardPile/DiscardMargin/DiscardVBox/DiscardCount
@onready var burn_count: Label = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/BurnPile/BurnMargin/BurnVBox/BurnCount
@onready var hand_scroll: ScrollContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll
@onready var hand_box: HandFanContainer = $UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox

var _ui_skin: UiSkin = UiSkin.new()
var _dialogue_engine = DialogueEngineScript.new()
var _run_engine = RunEngineScript.new()
var _combat_engine = CombatEngineScript.new()
var _progression: Dictionary = {}
var _run_state: Dictionary = {}
var _combat_state: Dictionary = {}
var _committed_run_state_override: Dictionary = {}
var _save_in_progress: bool = false
var _preview_combat_state: Dictionary = {}
var _combat_preview_revision: int = 0
var _preview_selection_revision: int = 0
var _card_preview_cache: Dictionary = {}
var _fallback_preview_cache: Dictionary = {}
var _card_play_options_cache: Dictionary = {}
var _card_widget_display_cache: Dictionary = {}
var _preview_shortcuts_cache_key: String = ""
var _preview_shortcuts_cache: Dictionary = {}
var _pass_preview_cache: Dictionary = {}
var _pass_preview_cache_order: Array[String] = []
var _analytics_store: AnalyticsStore = AnalyticsStore.new()
var _analytics_combat_tracker: Dictionary = {}
var _selected_card_index: int = -1
var _card_action_choice_index: int = -1
var _card_action_choice_options: Dictionary = {}
var _card_action_choice_mode: String = "play"
var _hovered_card_index: int = -1
var _hovered_board_tile: Vector2i = Vector2i(-1, -1)
var _pending_actions: Array = []
var _pending_action_index: int = 0
var _pending_action_can_skip: bool = false
var _pending_target_tiles: Array[Vector2i] = []
var _pending_selected_targets: Array[Vector2i] = []
var _pending_umbra_commit_locked: bool = false
var _pending_orientation_target_tile: Vector2i = INVALID_TARGET_TILE
var _aoe_aim_orientation: Vector2i = Vector2i(1, 0)
var _victory_carry_processed: bool = false
var _defeat_loss_processed: bool = false
var _victory_carry_amount: int = 0
var _defeat_lost_amount: int = 0
var _exit_destinations_by_tile: Dictionary = {}
var _animation_lock: bool = false
var _board_presentation: Dictionary = {}
var _menu_scrim: ColorRect
var _menu_dialog: PanelContainer
var _settings_panel: PanelContainer
var _grimoire_scrim: ColorRect
var _grimoire_dialog: PanelContainer
var _grimoire_section_list: VBoxContainer
var _grimoire_entry_scroll: ScrollContainer
var _grimoire_entry_list: VBoxContainer
var _grimoire_detail_panel: PanelContainer
var _grimoire_detail_icon: TextureRect
var _grimoire_detail_kicker: Label
var _grimoire_detail_title: Label
var _grimoire_detail_body: RichTextLabel
var _grimoire_detail_content: VBoxContainer
var _grimoire_badge: PanelContainer
var _grimoire_badge_label: Label
var _loadout_badge: PanelContainer
var _loadout_badge_label: Label
var _grimoire_selected_section: String = ""
var _grimoire_selected_group: String = ""
var _grimoire_selected_entry: String = ""
var _grimoire_nav_scroll_revision: int = 0
var _header_icon_textures: Dictionary = {}
var _pile_scrim: ColorRect
var _pile_dialog: PanelContainer
var _pile_dialog_title: Label
var _pile_dialog_scroll: ScrollContainer
var _pile_dialog_cards: HFlowContainer
var _pile_dialog_empty: Label
var _pile_content_hosts: Dictionary = {}
var _pile_visual_hosts: Dictionary = {}
var _pile_badges: Dictionary = {}
var _active_pile_kind: String = ""
var _pile_visual_signature: String = "<unset>"
var _relic_bar_signature: String = "<unset>"
var _skill_sigil: Button
var _defiance_badge: Control
var _skill_status_scrim: ColorRect
var _skill_status_popover: PanelContainer
var _skill_status_grid: GridContainer
var _skill_status_detail_icon: TextureRect
var _skill_status_detail_title: Label
var _skill_status_detail_status: Label
var _skill_status_detail_description: RichTextLabel
var _skill_status_action_button: Button
var _skill_status_title: Label
var _skill_status_summary: Label
var _skill_status_close_button: Button
var _skill_status_page_host: Control
var _skill_status_page_label: Label
var _skill_status_previous_page: Button
var _skill_status_next_page: Button
var _skill_status_return_focus: Control
var _skill_status_selected_id: String = ""
var _skill_status_skill_ids: Array[String]
var _skill_status_tiles: Dictionary = {}
var _skill_status_page: int = 0
var _skill_choice_scrim: ColorRect
var _skill_choice_dialog: PanelContainer
var _skill_choice_title: Label
var _skill_choice_description: Label
var _skill_choice_list: VBoxContainer
var _skill_choice_cancel_button: Button
var _skill_choice_return_focus: Control
var _combat_skill_card_selection_zone: String = ""
var _combat_skill_card_selection_skill_id: String = ""
var _combat_skill_card_selection_indices: Array[int]
var _combat_skill_card_selection_prompt: PanelContainer
var _combat_skill_card_selection_label: Label
var _combat_skill_card_selection_cancel_button: Button
var _skill_event_revision_seen: int = 0
var _run_skill_event_revision_seen: int = 0
var _defiance_event_revision_seen: int = 0
var _analytics_skill_event_revision: int = 0
var _hand_panel_signature: String = "<unset>"
var _play_meter: PanelContainer
var _play_meter_count: Label
var _play_meter_icon: TextureRect
var _play_meter_banked_badge: PanelContainer
var _play_meter_banked_label: Label
var _action_step_tracker: PanelContainer
var _action_step_tracker_title: Label
var _action_context_step_label: Label
var _action_context_detail_row: HBoxContainer
var _action_context_status_row: HBoxContainer
var _action_context_verb_label: Label
var _action_context_target_label: Label
var _action_context_risk_panel: PanelContainer
var _action_context_risk_label: Label
var _action_step_tracker_steps: HBoxContainer
var _card_action_mode_selector: HBoxContainer
var _contextual_combat_prompt_host: CenterContainer
var _contextual_combat_prompt: Control
var _active_contextual_combat_prompt_id: String = ""
var _action_context_command_bar: HBoxContainer
var _action_context_connector: ColorRect
var _action_step_tracker_position_locked: bool = false
var _action_step_tracker_locked_position: Vector2 = Vector2.ZERO
var _action_step_resolution_active: bool = false
var _action_step_resolution_card_id: String = ""
var _action_step_resolution_actions: Array = []
var _action_step_resolution_index: int = 0
var _action_step_resolution_targets: Array[Vector2i] = []
var _intensity_bar: Control
var _turn_order_panel: PanelContainer
var _turn_order_anchor: CenterContainer
var _turn_order_bar: Control
var _turn_order_header_host: Control
var _turn_order_label: Label
var _turn_order_boss_dossier: PanelContainer
var _turn_order_boss_name: Label
var _turn_order_boss_health_host: Control
var _turn_order_boss_health_bar: SegmentedHealthBar
var _turn_order_boss_damage_preview: ColorRect
var _turn_order_boss_hp_label: Label
var _turn_order_animating: bool = false
var _turn_order_hovered_enemy_key: String = ""
var _turn_order_panel_locked_width: float = -1.0
var _turn_order_source_signature: String = "<unset>"
var _turn_order_render_signature: String = "<unset>"
var _intensity_badges: Dictionary = {}
var _intensity_labels: Dictionary = {}
var _ember_count_override: int = -1
var _card_play_count_override: int = -1
var _card_play_resolution_spend: int = 0
var _card_play_budget_override: Dictionary = {}
var _choice_button_overlay: HBoxContainer
var _pass_preview_overlay: CenterContainer
var _context_choice_overlay: PanelContainer
var _context_choice_bar: HBoxContainer
var _relic_choice_overlay: Control
var _relic_choice_backdrop: ColorRect
var _relic_choice_banner: TextureRect
var _relic_choice_title_effect: RelicChoiceTitleEffect
var _relic_choice_title: Label
var _relic_choice_host: CenterContainer
var _relic_choice_bar: HBoxContainer
var _campfire_choice_action_pending: bool = false
var _relic_claim_in_progress: bool = false
var _loadout_acquisition_in_progress: bool = false
var _run_end_recap: RunEndRecapOverlay
var _large_map_scrim: ColorRect
var _large_map_dialog: PanelContainer
var _large_map_view: Control
var _pinned_tooltip_scrim: ColorRect
var _pinned_tooltip_host: Control
var _pinned_tooltip_panel: Control
var _pinned_tooltip_close_button: Button
var _pinned_tooltip_source_row: Control
var _pinned_tooltip_source_text: String = ""
var _pinned_pre_battle_tooltip_sources: Dictionary = {}
var _selected_card_label_override: String = ""
var _drag_overlay: Control
var _drag_zone_panels: Dictionary = {}
var _drag_zone_labels: Dictionary = {}
var _drag_zone_detail_labels: Dictionary = {}
var _drag_card_index: int = -1
var _drag_card_options: Dictionary = {}
var _drag_hover_zone: String = ""
var _card_fx_layer: Control
var _card_proxy_pool_host: Control
var _card_proxy_pool: Array[Control] = []
var _equipment_fx_layer: Control
var _fatigue_edge_overlay: FatigueEdgeOverlay
var _drag_card_proxy: Control
var _music_player: AudioStreamPlayer
var _sfx_players: Array = []
var _music_tween: Tween
var _active_music_id: String = ""
var _settings: Dictionary = {}
var _drag_card_source_rect: Rect2 = Rect2()
var _drag_card_grab_offset: Vector2 = Vector2.ZERO
var _drag_card_base_scale: Vector2 = Vector2.ONE
var _animating_hand_card_index: int = -1
var _hand_ready_wave_indices: Dictionary = {}
var _hand_ready_wave_token: int = 0
var _hand_ready_wave_reason: String = ""
var _dialogue_overlay: Control
var _dialogue_dialog: PanelContainer
var _dialogue_name_label: Label
var _dialogue_text_label: RichTextLabel
var _dialogue_footer: HBoxContainer
var _dialogue_hint_label: Label
var _dialogue_choice_bar: HBoxContainer
var _upgrade_scrim: ColorRect
var _upgrade_center: CenterContainer
var _upgrade_dialog: PanelContainer
var _upgrade_embers_label: Label
var _upgrade_card_list: VBoxContainer
var _upgrade_element_list: VBoxContainer
var _upgrade_option_list: VBoxContainer
var _upgrade_preview_box: HBoxContainer
var _upgrade_selected_card_id: String = ""
var _upgrade_selected_element_key: String = ""
var _progression_overlay_mode: String = ""
var _progression_focused_skill_id: String = ""
var _progression_level_label: Label
var _progression_skill_points_label: Label
var _progression_moltshards_label: Label
var _progression_defiance_label: Label
var _progression_summary_compact: bool = false
var _progression_overlay_notice: String = ""
var _progression_overlay_notice_is_error: bool = false
var _skill_tree_view: SkillTreeView
var _skill_reset_button: Button
var _skill_hud_refresh_pending: bool = false
var _skill_reset_confirmation_scrim: ColorRect
var _equipment_slot_panels: Dictionary = {}
var _equipment_inventory_tiles: Dictionary = {}
var _equipment_drag_id: String = ""
var _equipment_drag_source_rect: Rect2 = Rect2()
var _equipment_drag_source_control: Control
var _equipment_held_proxy: Control
var _equipment_swap_animation_active: bool = false
var _magic_attuned_tiles: Dictionary = {}
var _magic_inventory_tiles: Dictionary = {}
var _magic_drag_source_kind: String = ""
var _magic_drag_index: int = -1
var _magic_drag_card_id: String = ""
var _magic_drag_source_rect: Rect2 = Rect2()
var _magic_drag_source_control: Control
var _magic_held_proxy: Control
var _magic_drag_release_in_progress: bool = false
var _magic_drag_last_mouse_position: Vector2 = Vector2(-1.0, -1.0)
var _magic_attuned_drop_panel: Control
var _magic_inventory_drop_panel: Control
var _item_equipped_tiles: Dictionary = {}
var _item_inventory_tiles: Dictionary = {}
var _item_drag_source_kind: String = ""
var _item_drag_index: int = -1
var _item_drag_card_id: String = ""
var _item_drag_source_rect: Rect2 = Rect2()
var _item_drag_source_control: Control
var _item_held_proxy: Control
var _item_drag_release_in_progress: bool = false
var _item_drag_last_mouse_position: Vector2 = Vector2(-1.0, -1.0)
var _item_inventory_drop_panel: Control
var _item_swap_animation_active: bool = false
var _dialogue_active: bool = false
var _dialogue_script: Dictionary = {}
var _dialogue_line_index: int = -1
var _dialogue_char_progress: float = 0.0
var _dialogue_text_complete: bool = false
var _dialogue_suppresses_choices: bool = false
var _last_auto_dialogue_key: String = ""
var _merchant_hovered_kind: String = ""
var _merchant_hovered_item_id: String = ""
var _merchant_hovered_row: Control
var _merchant_trade_animation_active: bool = false
var _merchant_shop_open: bool = true
var _merchant_shop_room_coord: Vector2i = INVALID_ROOM_COORD
var _pre_battle_scrim: ColorRect
var _pre_battle_panel: PanelContainer
var _pre_battle_destination: Vector2i = INVALID_TARGET_TILE
var _pre_battle_door_tile: Vector2i = INVALID_TARGET_TILE
var _pre_battle_preview_run_state: Dictionary = {}
var _pre_battle_start_pending: bool = false

func _ready() -> void:
	ParallelRuntime.apply_from_environment()
	_settings = SettingsStore.load_settings()
	SettingsStore.apply_settings(_settings, get_window())
	set_process(false)
	board_view.equipment_tooltip_builder = Callable(self, "_build_equipment_tooltip_panel")
	_sync_board_view_rect()
	if not stage_root.item_rect_changed.is_connected(_queue_board_view_rect_sync):
		stage_root.item_rect_changed.connect(_queue_board_view_rect_sync)
	call_deferred("_sync_board_view_rect")
	_apply_style()
	_layout_mini_map_overlay()
	_build_overlay_ui()
	_build_context_choice_overlay()
	_setup_pile_widgets()
	_setup_contextual_combat_tutorial()
	_setup_action_step_tracker()
	_setup_play_meter()
	_setup_elemental_intensity_bar()
	_connect_header_layout_signals()
	_connect_choice_overlay_layout_signals()
	_connect_board_aim_signals()
	_boot_run()

func _process(delta: float) -> void:
	if not _dialogue_active or _dialogue_text_complete or _dialogue_text_label == null:
		return
	var line: Dictionary = _current_dialogue_line()
	var text: String = _dialogue_visible_text()
	if text.is_empty():
		_complete_current_dialogue_line()
		return
	if SettingsStore.dialogue_is_instant(_settings):
		_complete_current_dialogue_line()
		return
	var characters_per_second: float = SettingsStore.dialogue_characters_per_second(_settings)
	_dialogue_char_progress = minf(_dialogue_char_progress + delta * characters_per_second, float(text.length()))
	_dialogue_text_label.visible_characters = int(floor(_dialogue_char_progress))
	if _dialogue_char_progress >= float(text.length()):
		_complete_current_dialogue_line()

func _input(event: InputEvent) -> void:
	if _dialogue_active:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if _skill_choice_scrim != null and _skill_choice_scrim.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_skill_choice_dialog()
			get_viewport().set_input_as_handled()
		return
	if _skill_status_scrim != null and _skill_status_scrim.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_skill_status_popover()
			get_viewport().set_input_as_handled()
		return
	if not _combat_skill_card_selection_zone.is_empty():
		if event.is_action_pressed("ui_cancel"):
			_cancel_combat_skill_card_selection()
			get_viewport().set_input_as_handled()
		return
	if _pinned_tooltip_scrim != null and _pinned_tooltip_scrim.visible:
		if _is_shift_press_event(event) or event.is_action_pressed("ui_cancel"):
			_close_pinned_tooltip()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and _pinned_pre_battle_enemy_inspection_active():
			var mouse_event: InputEventMouseButton = event
			if mouse_event.button_index == MOUSE_BUTTON_LEFT \
					and mouse_event.pressed \
					and _pinned_pre_battle_close_button_hit(mouse_event):
				_close_pinned_tooltip()
			get_viewport().set_input_as_handled()
		return
	elif _is_merchant_tooltip_pin_event(event):
		_open_pinned_merchant_tooltip(_merchant_hovered_kind, _merchant_hovered_item_id)
		get_viewport().set_input_as_handled()
		return
	if _upgrade_scrim != null and _upgrade_scrim.visible:
		if not _equipment_drag_id.is_empty():
			if event is InputEventMouseMotion:
				_update_equipment_overlay_drag(_current_mouse_position())
				get_viewport().set_input_as_handled()
				return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				get_viewport().set_input_as_handled()
				await _release_equipment_overlay_drag(_current_mouse_position())
				return
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				await _cancel_equipment_overlay_drag(true)
				return
		if not _magic_drag_card_id.is_empty():
			if event is InputEventMouseMotion:
				_update_magic_overlay_drag(_mouse_event_position(event))
				get_viewport().set_input_as_handled()
				return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				get_viewport().set_input_as_handled()
				await _release_magic_overlay_drag(_mouse_event_position(event))
				return
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				await _cancel_magic_overlay_drag(true)
				return
		if not _item_drag_card_id.is_empty():
			if event is InputEventMouseMotion:
				_update_item_overlay_drag(_mouse_event_position(event))
				get_viewport().set_input_as_handled()
				return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				get_viewport().set_input_as_handled()
				await _release_item_overlay_drag(_mouse_event_position(event))
				return
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				await _cancel_item_overlay_drag(true)
				return
		if event.is_action_pressed("ui_cancel"):
			if _skill_reset_confirmation_scrim != null:
				_close_skill_reset_confirmation()
			else:
				_close_card_upgrade_overlay()
			get_viewport().set_input_as_handled()
		return
	if _drag_card_index >= 0:
		if event is InputEventMouseMotion:
			_update_drag_overlay_hover(_drag_zone_at(_current_mouse_position()))
			_update_drag_proxy_position(_current_mouse_position())
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			await _commit_drag_drop(_drag_zone_at(_current_mouse_position()))
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			await _animate_drag_cancel_to_source()
			get_viewport().set_input_as_handled()
			return
	if _selected_card_index >= 0 and _current_action_is_aimed_aoe():
		if event.is_action_pressed("ui_left"):
			_rotate_aoe_aim(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			_rotate_aoe_aim(1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		await _on_cancel_requested()

func _connect_board_aim_signals() -> void:
	if board_view == null:
		return
	if board_view.has_signal("tile_dragged") and not board_view.tile_dragged.is_connected(_on_board_tile_dragged):
		board_view.tile_dragged.connect(_on_board_tile_dragged)
	if board_view.has_signal("tile_drag_released") and not board_view.tile_drag_released.is_connected(_on_board_tile_drag_released):
		board_view.tile_drag_released.connect(_on_board_tile_drag_released)

func _queue_board_view_rect_sync() -> void:
	call_deferred("_sync_board_view_rect")

func _sync_board_view_rect() -> void:
	if board_view == null or stage_root == null or not board_view.is_inside_tree() or not stage_root.is_inside_tree():
		return
	board_view.position = stage_root.global_position
	board_view.size = stage_root.size

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_run_progress()
		get_tree().quit()
	elif what == NOTIFICATION_RESIZED:
		_sync_board_view_rect()
		_layout_mini_map_overlay()
		_layout_context_choice_overlay()
		_layout_relic_choice_overlay()
		_layout_choice_button_overlay()
		_layout_header_hud()
		_layout_elemental_intensity_bar()
		_layout_turn_order_anchor()
		_layout_contextual_combat_prompt_overlay()
		_layout_grimoire_dialog()
		_layout_pre_battle_dialog()
		_layout_skill_status_popover()
		_layout_combat_skill_card_selection_prompt()
		_layout_skill_choice_dialog()
		if _pre_battle_scrim != null and _pre_battle_scrim.visible:
			call_deferred("_rebuild_pre_battle_overlay")
		_layout_progression_dialog()

func _apply_style() -> void:
	_apply_tooltip_wrapper_style()
	$BoardUnderlay/BaseBackdrop.color = Color("18120f")
	board_backdrop.texture = AssetLoader.load_texture(BOARD_BACKDROP_PATH)
	var mini_map_style := StyleBoxFlat.new()
	mini_map_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	mini_map_style.corner_radius_top_left = 10
	mini_map_style.corner_radius_top_right = 10
	mini_map_style.corner_radius_bottom_right = 10
	mini_map_style.corner_radius_bottom_left = 10
	mini_map_style.border_color = Color(0.91, 0.82, 0.67, 0.24)
	mini_map_style.border_width_left = 1
	mini_map_style.border_width_top = 1
	mini_map_style.border_width_right = 1
	mini_map_style.border_width_bottom = 1
	mini_map_style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	mini_map_style.shadow_size = 0
	mini_map_overlay.add_theme_stylebox_override("panel", mini_map_style)
	_ui_skin.apply_panel_surface(mini_map_overlay, UiSkin.SURFACE_HUD)
	mini_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	mini_map_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mini_map_overlay.set_meta("cursor_feedback_context_provider", _mini_map_cursor_feedback_context)
	mini_map_overlay.tooltip_text = "Map"
	if not mini_map_overlay.gui_input.is_connected(_on_mini_map_overlay_gui_input):
		mini_map_overlay.gui_input.connect(_on_mini_map_overlay_gui_input)
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.055, 0.032, 0.024, 0.96)
	log_style.border_color = Color("c9914e")
	log_style.border_width_left = 5
	log_style.border_width_top = 2
	log_style.border_width_right = 2
	log_style.border_width_bottom = 2
	log_style.corner_radius_top_left = 10
	log_style.corner_radius_top_right = 10
	log_style.corner_radius_bottom_right = 10
	log_style.corner_radius_bottom_left = 10
	log_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	log_style.shadow_size = 18
	log_style.shadow_offset = Vector2(0.0, 6.0)
	# The scene already owns the combat log's content margins.
	log_overlay.set_meta("panel_safe_inset", 0.0)
	log_overlay.add_theme_stylebox_override("panel", log_style)
	_ui_skin.apply_panel_surface(log_overlay, UiSkin.SURFACE_HUD)
	for pile_panel: PanelContainer in [draw_pile, discard_pile, burn_pile]:
		pile_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		pile_panel.clip_contents = true
	UiTypography.set_label_size(room_title, UiTypography.SIZE_TITLE + 3)
	UiTypography.set_label_size(room_subtitle, UiTypography.SIZE_SECTION)
	UiTypography.set_label_size(umbra_subtitle, UiTypography.SIZE_BODY_LARGE)
	UiTypography.set_label_size(stats_label, UiTypography.SIZE_SECTION)
	UiTypography.set_label_size(action_banner, UiTypography.SIZE_SMALL)
	room_title.add_theme_color_override("font_color", Color("f0e6d2"))
	room_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	room_title.add_theme_constant_override("outline_size", 2)
	room_subtitle.add_theme_color_override("font_color", Color("cdbca2"))
	umbra_subtitle.add_theme_color_override("font_color", Color("b994d0"))
	umbra_subtitle.add_theme_color_override("font_outline_color", Color("160d20"))
	umbra_subtitle.add_theme_constant_override("outline_size", 2)
	umbra_subtitle.mouse_filter = Control.MOUSE_FILTER_STOP
	umbra_subtitle.mouse_default_cursor_shape = TOOLTIP_ONLY_CURSOR_SHAPE
	stats_label.add_theme_color_override("font_color", Color("f0c978"))
	stats_label.add_theme_color_override("font_outline_color", Color("2c1f16"))
	stats_label.add_theme_constant_override("outline_size", 2)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_stretch_ratio = 2.0
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_spacer.size_flags_stretch_ratio = 1.0
	_setup_turn_order_bar()
	relic_bar.visible = false
	relic_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_bar.add_theme_constant_override("h_separation", int(RELIC_BAR_HORIZONTAL_GAP))
	relic_bar.add_theme_constant_override("v_separation", 8)
	action_banner.add_theme_color_override("font_color", Color("fbf0d7"))
	action_banner.add_theme_color_override("font_outline_color", Color("2d1f18"))
	action_banner.add_theme_constant_override("outline_size", 2)
	choice_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	_setup_header_icon_button(grimoire_button, "book", "Grimoire")
	_setup_header_icon_button(loadout_button, "loadout", "Character Loadout")
	_setup_header_icon_button(menu_button, "gear", "Menu")
	UiTypography.set_rich_text_size(log_label, UiTypography.SIZE_BODY_LARGE)
	log_label.add_theme_color_override("default_color", Color("fff3dc"))
	log_label.add_theme_color_override("font_outline_color", Color("21140f"))
	log_label.add_theme_constant_override("outline_size", 2)
	log_label.add_theme_constant_override("line_separation", 3)
	log_label.fit_content = true
	log_label.scroll_following = false
	log_label.scroll_active = false
	mini_map.interactive = false
	mini_map.show_legend = false
	mini_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_map.custom_minimum_size = Vector2.ZERO
	board_view.visible = true
	board_view.custom_minimum_size = Vector2.ZERO
	hand_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hand_scroll.clip_contents = false
	piles_bar.custom_minimum_size = Vector2.ZERO
	piles_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	piles_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	piles_bar.add_theme_constant_override("separation", 18)
	hand_row.custom_minimum_size = Vector2(0.0, 352.0)
	for pile_label: Label in [
		$UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DrawPile/DrawMargin/DrawVBox/DrawTitle,
		$UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DiscardPile/DiscardMargin/DiscardVBox/DiscardTitle,
		$UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/BurnPile/BurnMargin/BurnVBox/BurnTitle,
		draw_count,
		discard_count,
		burn_count
	]:
		UiTypography.set_label_size(pile_label, UiTypography.SIZE_SMALL)
		pile_label.add_theme_color_override("font_color", Color("f0e4c8"))
		pile_label.add_theme_color_override("font_outline_color", Color("261b14"))
		pile_label.add_theme_constant_override("outline_size", 1)

func _apply_tooltip_wrapper_style() -> void:
	var scene_theme: Theme = theme if theme != null else Theme.new()
	scene_theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	theme = scene_theme

func _setup_header_icon_button(button: Button, icon_kind: String, tooltip: String) -> void:
	if button == null:
		return
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_ICON)
	button.add_theme_color_override("icon_normal_color", Color("f7dfad"))
	button.add_theme_color_override("icon_hover_color", Color("fff0c8"))
	button.add_theme_color_override("icon_pressed_color", Color("e8b968"))
	button.add_theme_color_override("icon_disabled_color", Color("8f7a5a"))
	button.text = ""
	button.icon = _header_icon_texture(icon_kind)
	button.expand_icon = true
	button.tooltip_text = tooltip
	button.custom_minimum_size = HEADER_ICON_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = false
	button.modulate = Color.WHITE
	if button == grimoire_button:
		_ensure_grimoire_badge()
	elif button == loadout_button:
		_ensure_loadout_badge()

func _ensure_grimoire_badge() -> void:
	if grimoire_button == null or _grimoire_badge != null:
		return
	_grimoire_badge = PanelContainer.new()
	_grimoire_badge.name = "GrimoireBadge"
	_grimoire_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grimoire_badge.custom_minimum_size = GRIMOIRE_BADGE_SIZE
	_grimoire_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_grimoire_badge.anchor_left = 1.0
	_grimoire_badge.anchor_right = 1.0
	_grimoire_badge.offset_left = -18.0
	_grimoire_badge.offset_top = -3.0
	_grimoire_badge.offset_right = 0.0
	_grimoire_badge.offset_bottom = 15.0
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("d64a3a")
	badge_style.border_color = Color("ffe0a2")
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.corner_radius_top_left = 6
	badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_right = 6
	badge_style.corner_radius_bottom_left = 6
	_grimoire_badge.add_theme_stylebox_override("panel", badge_style)
	_grimoire_badge_label = Label.new()
	_grimoire_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grimoire_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_grimoire_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_grimoire_badge_label, 8)
	_grimoire_badge_label.add_theme_color_override("font_color", Color("fff7d8"))
	_grimoire_badge_label.add_theme_color_override("font_outline_color", Color("2b130e"))
	_grimoire_badge_label.add_theme_constant_override("outline_size", 1)
	_grimoire_badge.add_child(_grimoire_badge_label)
	grimoire_button.add_child(_grimoire_badge)
	_refresh_grimoire_badge()

func _ensure_loadout_badge() -> void:
	if loadout_button == null or _loadout_badge != null:
		return
	_loadout_badge = PanelContainer.new()
	_loadout_badge.name = "LoadoutBadge"
	_loadout_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loadout_badge.custom_minimum_size = GRIMOIRE_BADGE_SIZE
	_loadout_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_loadout_badge.anchor_left = 1.0
	_loadout_badge.anchor_right = 1.0
	_loadout_badge.offset_left = -18.0
	_loadout_badge.offset_top = -3.0
	_loadout_badge.offset_right = 0.0
	_loadout_badge.offset_bottom = 15.0
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("d64a3a")
	badge_style.border_color = Color("ffe0a2")
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(6)
	_loadout_badge.add_theme_stylebox_override("panel", badge_style)
	_loadout_badge_label = Label.new()
	_loadout_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loadout_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loadout_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_loadout_badge_label, 8)
	_loadout_badge_label.add_theme_color_override("font_color", Color("fff7d8"))
	_loadout_badge_label.add_theme_color_override("font_outline_color", Color("2b130e"))
	_loadout_badge_label.add_theme_constant_override("outline_size", 1)
	_loadout_badge.add_child(_loadout_badge_label)
	loadout_button.add_child(_loadout_badge)
	_refresh_loadout_badge()

func _header_icon_texture(icon_kind: String) -> Texture2D:
	if _header_icon_textures.has(icon_kind):
		return _header_icon_textures[icon_kind]
	var image := Image.create(HEADER_ICON_TEXTURE_SIZE, HEADER_ICON_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var ink := Color("f4ddb0")
	match icon_kind:
		"gear":
			_draw_header_gear_icon(image, ink)
		"loadout":
			_draw_header_loadout_icon(image, ink)
		_:
			_draw_header_book_icon(image, ink)
	var texture := ImageTexture.create_from_image(image)
	_header_icon_textures[icon_kind] = texture
	return texture

func _draw_header_book_icon(image: Image, ink: Color) -> void:
	_draw_image_line(image, Vector2i(11, 15), Vector2i(23, 11), ink, 3)
	_draw_image_line(image, Vector2i(23, 11), Vector2i(23, 36), ink, 3)
	_draw_image_line(image, Vector2i(23, 36), Vector2i(11, 32), ink, 3)
	_draw_image_line(image, Vector2i(11, 32), Vector2i(11, 15), ink, 3)
	_draw_image_line(image, Vector2i(25, 11), Vector2i(37, 15), ink, 3)
	_draw_image_line(image, Vector2i(37, 15), Vector2i(37, 32), ink, 3)
	_draw_image_line(image, Vector2i(37, 32), Vector2i(25, 36), ink, 3)
	_draw_image_line(image, Vector2i(25, 36), Vector2i(25, 11), ink, 3)
	_draw_image_line(image, Vector2i(15, 19), Vector2i(20, 17), ink.darkened(0.18), 2)
	_draw_image_line(image, Vector2i(15, 24), Vector2i(20, 23), ink.darkened(0.18), 2)
	_draw_image_line(image, Vector2i(28, 17), Vector2i(33, 19), ink.darkened(0.18), 2)
	_draw_image_line(image, Vector2i(28, 23), Vector2i(33, 24), ink.darkened(0.18), 2)

func _draw_header_gear_icon(image: Image, ink: Color) -> void:
	var center := Vector2i(24, 24)
	for tooth_index: int in range(8):
		var angle: float = TAU * float(tooth_index) / 8.0
		var start := Vector2i(roundi(float(center.x) + cos(angle) * 12.0), roundi(float(center.y) + sin(angle) * 12.0))
		var finish := Vector2i(roundi(float(center.x) + cos(angle) * 18.0), roundi(float(center.y) + sin(angle) * 18.0))
		_draw_image_line(image, start, finish, ink, 4)
	_draw_image_ring(image, center, 10.0, 14.0, ink)
	_draw_image_ring(image, center, 3.8, 6.0, ink)

func _draw_header_loadout_icon(image: Image, ink: Color) -> void:
	# A compact paper-doll silhouette paired with a sword reads as character loadout
	# at header scale while keeping the same hand-drawn line weight as its neighbors.
	_draw_image_ring(image, Vector2i(20, 14), 4.5, 7.5, ink)
	_draw_image_line(image, Vector2i(9, 37), Vector2i(12, 27), ink, 3)
	_draw_image_line(image, Vector2i(12, 27), Vector2i(17, 23), ink, 3)
	_draw_image_line(image, Vector2i(17, 23), Vector2i(20, 27), ink, 3)
	_draw_image_line(image, Vector2i(20, 27), Vector2i(23, 23), ink, 3)
	_draw_image_line(image, Vector2i(23, 23), Vector2i(29, 27), ink, 3)
	_draw_image_line(image, Vector2i(29, 27), Vector2i(31, 37), ink, 3)
	_draw_image_line(image, Vector2i(9, 37), Vector2i(31, 37), ink, 3)
	_draw_image_line(image, Vector2i(14, 31), Vector2i(26, 31), ink.darkened(0.12), 2)
	_draw_image_line(image, Vector2i(38, 8), Vector2i(38, 33), ink, 3)
	_draw_image_line(image, Vector2i(38, 8), Vector2i(35, 13), ink, 2)
	_draw_image_line(image, Vector2i(38, 8), Vector2i(41, 13), ink, 2)
	_draw_image_line(image, Vector2i(33, 31), Vector2i(43, 31), ink, 3)
	_draw_image_line(image, Vector2i(38, 33), Vector2i(38, 40), ink, 3)
	_draw_image_ring(image, Vector2i(38, 42), 1.0, 3.0, ink)

func _draw_image_ring(image: Image, center: Vector2i, inner_radius: float, outer_radius: float, color: Color) -> void:
	var min_x: int = maxi(0, int(floor(float(center.x) - outer_radius - 1.0)))
	var max_x: int = mini(image.get_width() - 1, int(ceil(float(center.x) + outer_radius + 1.0)))
	var min_y: int = maxi(0, int(floor(float(center.y) - outer_radius - 1.0)))
	var max_y: int = mini(image.get_height() - 1, int(ceil(float(center.y) + outer_radius + 1.0)))
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var distance: float = Vector2(float(x), float(y)).distance_to(Vector2(float(center.x), float(center.y)))
			if distance >= inner_radius and distance <= outer_radius:
				image.set_pixel(x, y, color)

func _draw_image_line(image: Image, from_point: Vector2i, to_point: Vector2i, color: Color, width: int = 1) -> void:
	var delta: Vector2i = to_point - from_point
	var steps: int = maxi(abs(delta.x), abs(delta.y))
	if steps <= 0:
		_draw_image_point(image, from_point, color, width)
		return
	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps)
		var point := Vector2i(
				roundi(lerpf(float(from_point.x), float(to_point.x), t)),
				roundi(lerpf(float(from_point.y), float(to_point.y), t))
		)
		_draw_image_point(image, point, color, width)

func _draw_image_point(image: Image, point: Vector2i, color: Color, width: int = 1) -> void:
	var radius: int = maxi(0, int(floor(float(width) * 0.5)))
	for y: int in range(point.y - radius, point.y + radius + 1):
		if y < 0 or y >= image.get_height():
			continue
		for x: int in range(point.x - radius, point.x + radius + 1):
			if x < 0 or x >= image.get_width():
				continue
			if Vector2(float(x), float(y)).distance_to(Vector2(float(point.x), float(point.y))) <= float(radius) + 0.65:
				image.set_pixel(x, y, color)

func _build_overlay_ui() -> void:
	_build_card_fx_layer()
	_build_equipment_fx_layer()
	_build_fatigue_edge_overlay()
	_build_choice_button_overlay()
	_build_dialogue_overlay()
	_build_pinned_tooltip_overlay()
	_build_menu_overlay()
	_build_grimoire_overlay()
	_build_pile_overlay()
	_build_card_upgrade_overlay()
	_build_large_map_overlay()
	_build_pre_battle_overlay()
	_build_drag_overlay()
	_build_skill_status_popover()
	_build_combat_skill_card_selection_prompt()
	_build_skill_choice_dialog()

func _build_skill_status_popover() -> void:
	_skill_status_scrim = ColorRect.new()
	_skill_status_scrim.name = "SkillStatusScrim"
	_skill_status_scrim.visible = false
	_skill_status_scrim.color = Color(0.015, 0.01, 0.025, 0.44)
	_skill_status_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_status_scrim.z_index = 409
	_skill_status_scrim.z_as_relative = false
	_skill_status_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skill_status_scrim.gui_input.connect(_on_skill_status_scrim_gui_input)
	ui_root.add_child(_skill_status_scrim)

	_skill_status_popover = PanelContainer.new()
	_skill_status_popover.name = "SkillStatusPopover"
	_skill_status_popover.visible = false
	_skill_status_popover.custom_minimum_size = SKILL_STATUS_POPOVER_SIZE
	_skill_status_popover.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_status_popover.z_index = 410
	_skill_status_popover.z_as_relative = false
	_skill_status_popover.add_theme_stylebox_override("panel", _skill_panel_style(Color("a783d6"), 0.98))
	_skill_status_scrim.add_child(_skill_status_popover)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_skill_status_popover.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	_skill_status_title = Label.new()
	_skill_status_title.text = "ABILITIES"
	_skill_status_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(_skill_status_title, UiTypography.ROLE_SECTION)
	_skill_status_title.add_theme_color_override("font_color", Color("eadcff"))
	header.add_child(_skill_status_title)
	_skill_status_summary = Label.new()
	_skill_status_summary.name = "SkillStatusSummary"
	_skill_status_summary.text = "0 READY  ·  0 OWNED"
	UiTypography.apply_label_role(_skill_status_summary, UiTypography.ROLE_CAPTION)
	_skill_status_summary.add_theme_color_override("font_color", Color("bfa7d7"))
	header.add_child(_skill_status_summary)
	_skill_status_close_button = Button.new()
	_skill_status_close_button.name = "CloseSkillStatus"
	_skill_status_close_button.text = "Close"
	_skill_status_close_button.custom_minimum_size = Vector2(82.0, 36.0)
	_ui_skin.apply_button_stylebox_overrides(_skill_status_close_button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(_skill_status_close_button)
	UiTypography.apply_button_role(_skill_status_close_button, UiTypography.ROLE_CAPTION)
	_skill_status_close_button.pressed.connect(_close_skill_status_popover)
	header.add_child(_skill_status_close_button)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color("765e96")
	column.add_child(rule)

	var palette_center := CenterContainer.new()
	palette_center.name = "SkillStatusPaletteCenter"
	palette_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(palette_center)
	_skill_status_grid = GridContainer.new()
	_skill_status_grid.name = "SkillStatusIconGrid"
	_skill_status_grid.columns = SKILL_STATUS_GRID_COLUMNS
	_skill_status_grid.add_theme_constant_override("h_separation", 7)
	_skill_status_grid.add_theme_constant_override("v_separation", 7)
	_skill_status_grid.custom_minimum_size = Vector2(
		SKILL_STATUS_TILE_SIZE.x * float(SKILL_STATUS_GRID_COLUMNS) + 7.0 * float(SKILL_STATUS_GRID_COLUMNS - 1),
		SKILL_STATUS_TILE_SIZE.y * 2.0 + 7.0
	)
	palette_center.add_child(_skill_status_grid)

	_skill_status_page_host = CenterContainer.new()
	_skill_status_page_host.name = "SkillStatusPageHost"
	_skill_status_page_host.custom_minimum_size = Vector2(0.0, 30.0)
	column.add_child(_skill_status_page_host)
	var page_row := HBoxContainer.new()
	page_row.name = "SkillStatusPageControls"
	page_row.add_theme_constant_override("separation", 10)
	_skill_status_page_host.add_child(page_row)
	_skill_status_previous_page = Button.new()
	_skill_status_previous_page.name = "PreviousSkillStatusPage"
	_skill_status_previous_page.text = "←  PREV"
	_skill_status_previous_page.custom_minimum_size = Vector2(86.0, 28.0)
	_ui_skin.apply_button_stylebox_overrides(_skill_status_previous_page, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(_skill_status_previous_page)
	UiTypography.apply_button_role(_skill_status_previous_page, UiTypography.ROLE_CAPTION)
	_skill_status_previous_page.pressed.connect(_on_skill_status_page_pressed.bind(-1))
	page_row.add_child(_skill_status_previous_page)
	_skill_status_page_label = Label.new()
	_skill_status_page_label.name = "SkillStatusPageLabel"
	_skill_status_page_label.custom_minimum_size = Vector2(64.0, 0.0)
	_skill_status_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_status_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.apply_label_role(_skill_status_page_label, UiTypography.ROLE_CAPTION)
	_skill_status_page_label.add_theme_color_override("font_color", Color("cdb8df"))
	page_row.add_child(_skill_status_page_label)
	_skill_status_next_page = Button.new()
	_skill_status_next_page.name = "NextSkillStatusPage"
	_skill_status_next_page.text = "NEXT  →"
	_skill_status_next_page.custom_minimum_size = Vector2(86.0, 28.0)
	_ui_skin.apply_button_stylebox_overrides(_skill_status_next_page, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(_skill_status_next_page)
	UiTypography.apply_button_role(_skill_status_next_page, UiTypography.ROLE_CAPTION)
	_skill_status_next_page.pressed.connect(_on_skill_status_page_pressed.bind(1))
	page_row.add_child(_skill_status_next_page)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "SkillStatusSelectedDetail"
	detail_panel.custom_minimum_size = Vector2(0.0, SKILL_STATUS_DETAIL_HEIGHT)
	detail_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	detail_panel.clip_contents = true
	detail_panel.add_theme_stylebox_override("panel", _skill_status_row_style(Color("a783d6")))
	column.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 12)
	detail_margin.add_theme_constant_override("margin_top", 8)
	detail_margin.add_theme_constant_override("margin_right", 10)
	detail_margin.add_theme_constant_override("margin_bottom", 8)
	detail_panel.add_child(detail_margin)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 12)
	detail_margin.add_child(detail_row)
	_skill_status_detail_icon = TextureRect.new()
	_skill_status_detail_icon.name = "SkillStatusSelectedIcon"
	_skill_status_detail_icon.custom_minimum_size = Vector2(58.0, 58.0)
	_skill_status_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skill_status_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skill_status_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_row.add_child(_skill_status_detail_icon)
	var detail_copy := VBoxContainer.new()
	detail_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_copy.add_theme_constant_override("separation", 2)
	detail_row.add_child(detail_copy)
	var detail_heading := HBoxContainer.new()
	detail_heading.add_theme_constant_override("separation", 8)
	detail_copy.add_child(detail_heading)
	_skill_status_detail_title = Label.new()
	_skill_status_detail_title.name = "SkillStatusSelectedTitle"
	_skill_status_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(_skill_status_detail_title, UiTypography.ROLE_BODY_LARGE)
	_skill_status_detail_title.add_theme_color_override("font_color", Color("f1e7ff"))
	detail_heading.add_child(_skill_status_detail_title)
	_skill_status_detail_status = Label.new()
	_skill_status_detail_status.name = "SkillStatusSelectedState"
	UiTypography.apply_label_role(_skill_status_detail_status, UiTypography.ROLE_CAPTION)
	detail_heading.add_child(_skill_status_detail_status)
	_skill_status_detail_description = RichTextLabel.new()
	_skill_status_detail_description.name = "SkillStatusSelectedDescription"
	_skill_status_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_status_detail_description.fit_content = false
	_skill_status_detail_description.scroll_active = false
	_skill_status_detail_description.bbcode_enabled = false
	_skill_status_detail_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTypography.apply_rich_text_role(_skill_status_detail_description, UiTypography.ROLE_CAPTION)
	_skill_status_detail_description.add_theme_color_override("default_color", Color("cbbbd5"))
	detail_copy.add_child(_skill_status_detail_description)
	_skill_status_action_button = Button.new()
	_skill_status_action_button.name = "ActivateSelectedSkill"
	_skill_status_action_button.custom_minimum_size = Vector2(108.0, 44.0)
	_skill_status_action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ui_skin.apply_button_stylebox_overrides(_skill_status_action_button, UiSkin.VARIANT_SELECTED)
	_ui_skin.apply_button_text_overrides(_skill_status_action_button)
	UiTypography.apply_button_role(_skill_status_action_button, UiTypography.ROLE_BODY)
	_skill_status_action_button.pressed.connect(_on_skill_status_action_pressed)
	detail_row.add_child(_skill_status_action_button)

func _on_skill_status_scrim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_close_skill_status_popover()
			get_viewport().set_input_as_handled()

func _build_combat_skill_card_selection_prompt() -> void:
	_combat_skill_card_selection_prompt = PanelContainer.new()
	_combat_skill_card_selection_prompt.name = "SkillCardSelectionPrompt"
	_combat_skill_card_selection_prompt.visible = false
	_combat_skill_card_selection_prompt.custom_minimum_size = SKILL_CARD_SELECTION_PROMPT_SIZE
	_combat_skill_card_selection_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_combat_skill_card_selection_prompt.z_index = 430
	_combat_skill_card_selection_prompt.z_as_relative = false
	_combat_skill_card_selection_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_combat_skill_card_selection_prompt.add_theme_stylebox_override("panel", _skill_panel_style(Color("ae82dc"), 0.98))
	ui_root.add_child(_combat_skill_card_selection_prompt)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_combat_skill_card_selection_prompt.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	margin.add_child(row)
	_combat_skill_card_selection_label = Label.new()
	_combat_skill_card_selection_label.name = "SkillCardSelectionInstruction"
	_combat_skill_card_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_skill_card_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.apply_label_role(_combat_skill_card_selection_label, UiTypography.ROLE_BODY_LARGE)
	_combat_skill_card_selection_label.add_theme_color_override("font_color", Color("f0e2ff"))
	row.add_child(_combat_skill_card_selection_label)
	_combat_skill_card_selection_cancel_button = Button.new()
	_combat_skill_card_selection_cancel_button.name = "CancelSkillCardSelection"
	_combat_skill_card_selection_cancel_button.text = "Cancel"
	_combat_skill_card_selection_cancel_button.custom_minimum_size = Vector2(94.0, 40.0)
	_ui_skin.apply_button_stylebox_overrides(_combat_skill_card_selection_cancel_button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(_combat_skill_card_selection_cancel_button)
	UiTypography.apply_button_role(_combat_skill_card_selection_cancel_button, UiTypography.ROLE_BODY)
	_combat_skill_card_selection_cancel_button.pressed.connect(_cancel_combat_skill_card_selection)
	row.add_child(_combat_skill_card_selection_cancel_button)

func _layout_combat_skill_card_selection_prompt() -> void:
	if _combat_skill_card_selection_prompt == null or not _combat_skill_card_selection_prompt.visible:
		return
	var root_rect: Rect2 = ui_root.get_global_rect()
	var available_width: float = maxf(1.0, root_rect.size.x - 16.0)
	var prompt_size := Vector2(minf(SKILL_CARD_SELECTION_PROMPT_SIZE.x, available_width), SKILL_CARD_SELECTION_PROMPT_SIZE.y)
	_combat_skill_card_selection_prompt.custom_minimum_size = prompt_size
	_combat_skill_card_selection_prompt.size = prompt_size
	var hand_top: float = root_rect.end.y - 8.0
	if hand_scroll != null and hand_scroll.is_inside_tree() and hand_scroll.is_visible_in_tree():
		hand_top = hand_scroll.get_global_rect().position.y
	var desired := Vector2(
		root_rect.position.x + (root_rect.size.x - prompt_size.x) * 0.5,
		hand_top - prompt_size.y - 12.0
	)
	desired.x = clampf(desired.x, root_rect.position.x + 8.0, root_rect.end.x - prompt_size.x - 8.0)
	desired.y = clampf(desired.y, root_rect.position.y + 8.0, root_rect.end.y - prompt_size.y - 8.0)
	_combat_skill_card_selection_prompt.global_position = desired

func _build_skill_choice_dialog() -> void:
	_skill_choice_scrim = ColorRect.new()
	_skill_choice_scrim.name = "SkillChoiceScrim"
	_skill_choice_scrim.visible = false
	_skill_choice_scrim.color = Color(0.015, 0.01, 0.025, 0.82)
	_skill_choice_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_choice_scrim.z_index = 820
	_skill_choice_scrim.z_as_relative = false
	_skill_choice_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(_skill_choice_scrim)

	_skill_choice_dialog = PanelContainer.new()
	_skill_choice_dialog.name = "SkillChoiceDialog"
	_skill_choice_dialog.custom_minimum_size = SKILL_CHOICE_DIALOG_SIZE
	_skill_choice_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_skill_choice_dialog.offset_left = -SKILL_CHOICE_DIALOG_SIZE.x * 0.5
	_skill_choice_dialog.offset_top = -SKILL_CHOICE_DIALOG_SIZE.y * 0.5
	_skill_choice_dialog.offset_right = SKILL_CHOICE_DIALOG_SIZE.x * 0.5
	_skill_choice_dialog.offset_bottom = SKILL_CHOICE_DIALOG_SIZE.y * 0.5
	_skill_choice_dialog.add_theme_stylebox_override("panel", _skill_panel_style(Color("b28ae6"), 1.0))
	_skill_choice_scrim.add_child(_skill_choice_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_skill_choice_dialog.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_skill_choice_title = Label.new()
	_skill_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTypography.apply_label_role(_skill_choice_title, UiTypography.ROLE_TITLE)
	_skill_choice_title.add_theme_color_override("font_color", Color("f0e2ff"))
	column.add_child(_skill_choice_title)
	_skill_choice_description = Label.new()
	_skill_choice_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_choice_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_choice_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_choice_description.custom_minimum_size.y = 104.0
	UiTypography.apply_label_role(_skill_choice_description, UiTypography.ROLE_BODY)
	_skill_choice_description.add_theme_color_override("font_color", Color("cdbce0"))
	column.add_child(_skill_choice_description)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_skill_choice_list = VBoxContainer.new()
	_skill_choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_choice_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_skill_choice_list)
	_skill_choice_cancel_button = Button.new()
	_skill_choice_cancel_button.name = "CancelSkillChoice"
	_skill_choice_cancel_button.text = "Cancel"
	_skill_choice_cancel_button.custom_minimum_size = Vector2(0.0, 44.0)
	_ui_skin.apply_button_stylebox_overrides(_skill_choice_cancel_button, UiSkin.VARIANT_STANDARD)
	_ui_skin.apply_button_text_overrides(_skill_choice_cancel_button)
	UiTypography.apply_button_role(_skill_choice_cancel_button, UiTypography.ROLE_BODY)
	_skill_choice_cancel_button.pressed.connect(_close_skill_choice_dialog)
	column.add_child(_skill_choice_cancel_button)

func _layout_skill_choice_dialog() -> void:
	if _skill_choice_dialog == null:
		return
	var dialog_size: Vector2 = UiTypography.modal_size(
		_skill_choice_dialog,
		SKILL_CHOICE_DIALOG_SIZE,
		SKILL_CHOICE_DIALOG_MIN_SIZE,
		16.0
	)
	_skill_choice_dialog.custom_minimum_size = dialog_size
	_skill_choice_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_skill_choice_dialog.offset_left = -dialog_size.x * 0.5
	_skill_choice_dialog.offset_top = -dialog_size.y * 0.5
	_skill_choice_dialog.offset_right = dialog_size.x * 0.5
	_skill_choice_dialog.offset_bottom = dialog_size.y * 0.5

func _skill_panel_style(accent: Color, opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.045, 0.085, opacity)
	style.border_color = accent.darkened(0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 7.0)
	return style

func _open_skill_choice_dialog(title: String, description: String, options: Array) -> void:
	if _skill_choice_scrim == null or _skill_choice_list == null or options.is_empty():
		return
	_skill_choice_return_focus = get_viewport().gui_get_focus_owner()
	if not _can_restore_gui_focus(_skill_choice_return_focus):
		_skill_choice_return_focus = _skill_sigil
	_close_skill_status_popover()
	_skill_choice_title.text = title
	_skill_choice_description.text = description
	_clear_children_now(_skill_choice_list)
	var first_option_button: Button
	var first_option_name: String = ""
	var first_option_detail: String = ""
	for option_var: Variant in options:
		if typeof(option_var) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_var
		var callback: Callable = option.get("callback", Callable())
		if not callback.is_valid():
			continue
		var button := UiTooltipButton.new()
		var option_name: String = str(option.get("text", "Choose"))
		var option_detail: String = str(option.get("detail", ""))
		button.text = option_name
		button.tooltip_text = option_detail
		button.custom_minimum_size = Vector2(0.0, 54.0)
		_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_STANDARD)
		_ui_skin.apply_button_text_overrides(button)
		UiTypography.apply_button_role(button, UiTypography.ROLE_BODY)
		button.pressed.connect(_on_skill_choice_option_pressed.bind(callback))
		button.focus_entered.connect(_show_skill_choice_option_detail.bind(description, option_name, option_detail))
		button.mouse_entered.connect(_focus_skill_choice_option.bind(button))
		_skill_choice_list.add_child(button)
		if first_option_button == null:
			first_option_button = button
			first_option_name = option_name
			first_option_detail = option_detail
	_skill_choice_scrim.visible = _skill_choice_list.get_child_count() > 0
	if _skill_choice_scrim.visible:
		_layout_skill_choice_dialog()
		call_deferred("_layout_skill_choice_dialog")
		_show_skill_choice_option_detail(description, first_option_name, first_option_detail)
		call_deferred("_grab_preferred_gui_focus", first_option_button, _skill_choice_cancel_button)

func _show_skill_choice_option_detail(instruction: String, option_name: String, option_detail: String) -> void:
	if _skill_choice_description == null:
		return
	var clean_detail: String = option_detail.strip_edges()
	if clean_detail.is_empty():
		_skill_choice_description.text = instruction
		return
	_skill_choice_description.text = "%s\n\n%s — %s" % [instruction, option_name, clean_detail]

func _focus_skill_choice_option(button: Button) -> void:
	if button == null or not is_instance_valid(button) or button.disabled or not button.is_visible_in_tree():
		return
	button.grab_focus()

func _on_skill_choice_option_pressed(callback: Callable) -> void:
	_close_skill_choice_dialog()
	if callback.is_valid():
		callback.call()

func _close_skill_choice_dialog() -> void:
	var was_visible: bool = _skill_choice_scrim != null and _skill_choice_scrim.visible
	if _skill_choice_scrim != null:
		_skill_choice_scrim.visible = false
	if _skill_choice_list != null:
		_clear_children_now(_skill_choice_list)
	if was_visible:
		var return_focus: Control = _skill_choice_return_focus
		_skill_choice_return_focus = null
		call_deferred("_grab_preferred_gui_focus", return_focus, _skill_sigil)

func _close_skill_status_popover(restore_focus: bool = true) -> void:
	var was_visible: bool = _skill_status_scrim != null and _skill_status_scrim.visible
	if _skill_status_scrim != null:
		_skill_status_scrim.visible = false
	if _skill_status_popover != null:
		_skill_status_popover.visible = false
	if was_visible and restore_focus:
		var return_focus: Control = _skill_status_return_focus
		_skill_status_return_focus = null
		call_deferred("_grab_preferred_gui_focus", return_focus, _skill_sigil)
	elif was_visible:
		_skill_status_return_focus = null

func _can_restore_gui_focus(control: Variant) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not is_instance_of(control, Control):
		return false
	var focus_control: Control = control as Control
	return (
		is_instance_valid(focus_control)
		and focus_control.is_inside_tree()
		and focus_control.is_visible_in_tree()
		and focus_control.focus_mode != Control.FOCUS_NONE
	)

func _grab_preferred_gui_focus(preferred: Variant, fallback: Variant = null) -> void:
	var target: Control = preferred as Control if _can_restore_gui_focus(preferred) else fallback as Control
	if _can_restore_gui_focus(target):
		target.grab_focus()

func _build_choice_button_overlay() -> void:
	_choice_button_overlay = HBoxContainer.new()
	_choice_button_overlay.name = "ChoiceButtonOverlay"
	_choice_button_overlay.visible = false
	_choice_button_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_choice_button_overlay.clip_contents = false
	_choice_button_overlay.z_index = 120
	_choice_button_overlay.z_as_relative = false
	_choice_button_overlay.alignment = BoxContainer.ALIGNMENT_BEGIN
	_choice_button_overlay.add_theme_constant_override("separation", int(choice_bar.get_theme_constant("separation")))
	ui_root.add_child(_choice_button_overlay)
	_pass_preview_overlay = CenterContainer.new()
	_pass_preview_overlay.name = "PassPreviewOverlay"
	_pass_preview_overlay.visible = false
	_pass_preview_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_pass_preview_overlay.clip_contents = false
	_pass_preview_overlay.z_index = 121
	_pass_preview_overlay.z_as_relative = false
	ui_root.add_child(_pass_preview_overlay)

func _build_pinned_tooltip_overlay() -> void:
	_pinned_tooltip_scrim = ColorRect.new()
	_pinned_tooltip_scrim.name = "PinnedTooltipScrim"
	_pinned_tooltip_scrim.visible = false
	_pinned_tooltip_scrim.color = Color(0.0, 0.0, 0.0, 0.0)
	_pinned_tooltip_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pinned_tooltip_scrim.set_meta("cursor_feedback_context_provider", _pinned_tooltip_cursor_feedback_context)
	_pinned_tooltip_scrim.z_index = 1240
	_pinned_tooltip_scrim.z_as_relative = false
	_pinned_tooltip_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pinned_tooltip_scrim.gui_input.connect(_on_pinned_tooltip_scrim_gui_input)
	ui_root.add_child(_pinned_tooltip_scrim)

	_pinned_tooltip_host = Control.new()
	_pinned_tooltip_host.name = "PinnedTooltipHost"
	_pinned_tooltip_host.mouse_filter = Control.MOUSE_FILTER_PASS
	_pinned_tooltip_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pinned_tooltip_scrim.add_child(_pinned_tooltip_host)

func _is_shift_press_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_SHIFT or key_event.physical_keycode == KEY_SHIFT)
	return false

func _is_merchant_tooltip_pin_event(event: InputEvent) -> bool:
	if _merchant_hovered_kind.is_empty() or _merchant_hovered_item_id.is_empty():
		return false
	return _is_shift_press_event(event)

func _open_pinned_merchant_tooltip(merchant_kind: String, item_id: String) -> void:
	if _pinned_tooltip_scrim == null or _pinned_tooltip_host == null:
		return
	if merchant_kind.is_empty() or item_id.is_empty():
		return
	var source_row: Control = _merchant_hovered_row if _node_is_alive(_merchant_hovered_row) else null
	for child: Node in _pinned_tooltip_host.get_children():
		child.queue_free()
	_suppress_pinned_tooltip_source(source_row)
	_pinned_tooltip_panel = _build_merchant_item_tooltip_panel(merchant_kind, item_id, true)
	if _pinned_tooltip_panel == null:
		_restore_pinned_tooltip_source()
		return
	_pinned_tooltip_panel.name = "PinnedMerchantTooltip"
	_pinned_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pinned_tooltip_host.add_child(_pinned_tooltip_panel)
	var panel_size: Vector2 = _pinned_tooltip_panel.get_combined_minimum_size()
	_pinned_tooltip_panel.size = panel_size
	_pinned_tooltip_panel.global_position = _pinned_merchant_tooltip_position(source_row, panel_size)
	_pinned_tooltip_scrim.color = Color(0.0, 0.0, 0.0, 0.0)
	_pinned_tooltip_scrim.visible = true

func _open_pinned_pre_battle_inspection(kind: String, content_id: String, source_control: Control = null, enemy: Dictionary = {}) -> void:
	if _pinned_tooltip_scrim == null or _pinned_tooltip_host == null:
		return
	if _pre_battle_scrim == null or not _pre_battle_scrim.visible:
		return
	if kind not in ["enemy", "equipment", "card"] or content_id.is_empty():
		return
	for child: Node in _pinned_tooltip_host.get_children():
		child.queue_free()
	_pinned_tooltip_close_button = null
	_suppress_pinned_tooltip_source(source_control)
	_suppress_pre_battle_hover_sources()
	_dismiss_pre_battle_tooltip_popups(_pre_battle_panel)
	match kind:
		"enemy":
			_pinned_tooltip_panel = _build_pre_battle_enemy_inspection_panel(enemy, true)
		"equipment":
			_pinned_tooltip_panel = _build_equipment_tooltip_panel(content_id, true)
		"card":
			_pinned_tooltip_panel = _build_card_tooltip_panel(content_id, true)
	if _pinned_tooltip_panel == null:
		_restore_pinned_tooltip_source()
		_restore_pre_battle_hover_sources()
		return
	_pinned_tooltip_panel.name = "PinnedPreBattleInspection"
	_pinned_tooltip_panel.set_meta("inspection_kind", kind)
	_pinned_tooltip_panel.set_meta("inspection_id", content_id)
	_pinned_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pinned_tooltip_host.add_child(_pinned_tooltip_panel)
	var panel_size: Vector2 = _pinned_tooltip_panel.get_combined_minimum_size()
	_pinned_tooltip_panel.size = panel_size
	var viewport_size: Vector2 = get_viewport_rect().size
	_pinned_tooltip_panel.global_position = Vector2(
		maxf(12.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(12.0, (viewport_size.y - panel_size.y) * 0.5)
	)
	_pinned_tooltip_close_button = _pinned_tooltip_panel.find_child("PreBattleInspectionCloseButton", true, false) as Button if kind == "enemy" else null
	_pinned_tooltip_scrim.color = Color(0.0, 0.0, 0.0, 0.66)
	_pinned_tooltip_scrim.visible = true
	_pinned_tooltip_scrim.move_to_front()
	call_deferred("_refresh_pinned_tooltip_hover_owner")

func _pre_battle_hover_inspections_enabled() -> bool:
	return _pre_battle_summary_inspections_enabled()

func _pre_battle_click_inspections_enabled() -> bool:
	return _pre_battle_summary_inspections_enabled()

func _pre_battle_summary_inspections_enabled() -> bool:
	return _pre_battle_scrim != null \
		and _pre_battle_scrim.visible \
		and (_pinned_tooltip_scrim == null or not _pinned_tooltip_scrim.visible)

func _pinned_pre_battle_enemy_inspection_active() -> bool:
	return _pinned_tooltip_scrim != null \
		and _pinned_tooltip_scrim.visible \
		and _pinned_tooltip_panel != null \
		and _pinned_tooltip_panel.name == "PinnedPreBattleInspection" \
		and str(_pinned_tooltip_panel.get_meta("inspection_kind", "")) == "enemy"

func _pinned_pre_battle_close_button_hit(mouse_event: InputEventMouseButton) -> bool:
	if not _node_is_alive(_pinned_tooltip_close_button):
		return false
	var close_rect: Rect2 = _pinned_tooltip_close_button.get_global_rect()
	# Native mouse events already arrive in the canvas coordinates used by Control global rects.
	return close_rect.has_point(mouse_event.position) or close_rect.has_point(mouse_event.global_position)

func _suppressed_pre_battle_tooltip() -> Control:
	var suppressed := Control.new()
	suppressed.visible = false
	return suppressed

func _suppress_pre_battle_hover_sources() -> void:
	_restore_pre_battle_hover_sources()
	if _pre_battle_panel == null:
		return
	for node_var: Variant in _pre_battle_panel.find_children("*", "Control", true, false):
		var control: Control = node_var as Control
		if control == null or control.tooltip_text.is_empty() or control == _pinned_tooltip_source_row:
			continue
		_pinned_pre_battle_tooltip_sources[control] = control.tooltip_text
		control.tooltip_text = ""

func _restore_pre_battle_hover_sources() -> void:
	for control_var: Variant in _pinned_pre_battle_tooltip_sources.keys():
		var control: Control = control_var as Control
		if _node_is_alive(control):
			control.tooltip_text = str(_pinned_pre_battle_tooltip_sources.get(control, ""))
	_pinned_pre_battle_tooltip_sources.clear()

func _dismiss_pre_battle_tooltip_popups(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		if child is Window and str(child.get("theme_type_variation")) == "TooltipPanel":
			child.queue_free()
			continue
		_dismiss_pre_battle_tooltip_popups(child)

func _refresh_pinned_tooltip_hover_owner() -> void:
	if _pinned_tooltip_scrim == null or not _pinned_tooltip_scrim.visible:
		return
	var motion := InputEventMouseMotion.new()
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	motion.position = mouse_position
	motion.global_position = mouse_position
	get_viewport().push_input(motion, true)

func _close_pinned_tooltip() -> void:
	_restore_pinned_tooltip_source()
	_restore_pre_battle_hover_sources()
	_pinned_tooltip_close_button = null
	if _pinned_tooltip_scrim != null:
		_pinned_tooltip_scrim.visible = false
		_pinned_tooltip_scrim.color = Color(0.0, 0.0, 0.0, 0.0)
	if _pinned_tooltip_host != null:
		for child: Node in _pinned_tooltip_host.get_children():
			child.queue_free()
	_pinned_tooltip_panel = null

func _on_pinned_tooltip_scrim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _pinned_tooltip_panel != null and _pinned_tooltip_panel.get_global_rect().has_point(mouse_event.global_position):
				return
			if _pinned_pre_battle_enemy_inspection_active():
				accept_event()
				return
			_close_pinned_tooltip()
			accept_event()

func _pinned_tooltip_cursor_feedback_context(local_position: Vector2) -> String:
	if _pinned_tooltip_scrim == null or not _pinned_tooltip_scrim.visible:
		return "inert"
	var global_position: Vector2 = _pinned_tooltip_scrim.get_global_transform_with_canvas() * local_position
	if _pinned_pre_battle_enemy_inspection_active():
		if _node_is_alive(_pinned_tooltip_close_button) \
				and _pinned_tooltip_close_button.get_global_rect().has_point(global_position):
			return "action"
		return "inert"
	if _pinned_tooltip_panel != null and _pinned_tooltip_panel.get_global_rect().has_point(global_position):
		return "inert"
	return "action"

func _suppress_pinned_tooltip_source(source_row: Control) -> void:
	_restore_pinned_tooltip_source()
	if not _node_is_alive(source_row):
		return
	_pinned_tooltip_source_row = source_row
	_pinned_tooltip_source_text = source_row.tooltip_text
	source_row.tooltip_text = ""

func _restore_pinned_tooltip_source() -> void:
	if _node_is_alive(_pinned_tooltip_source_row):
		_pinned_tooltip_source_row.tooltip_text = _pinned_tooltip_source_text
	_pinned_tooltip_source_row = null
	_pinned_tooltip_source_text = ""

func _pinned_merchant_tooltip_position(_source_row: Control, panel_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var margin: float = 10.0
	var position: Vector2 = _current_mouse_position() + PINNED_TOOLTIP_CURSOR_OFFSET
	position.x = clampf(position.x, margin, maxf(margin, viewport_size.x - panel_size.x - margin))
	position.y = clampf(position.y, margin, maxf(margin, viewport_size.y - panel_size.y - margin))
	return position

func _combat_choice_placeholder_size() -> Vector2:
	return _ui_skin.button_native_size(UiSkin.BUTTON_HEIGHT_ACTION, 0.0, UiSkin.VARIANT_LARGE)

func _layout_choice_button_overlay() -> void:
	if _choice_button_overlay == null:
		return
	if not choice_bar.is_inside_tree():
		return
	if not choice_bar.visible and not (_choice_button_overlay.visible or (_pass_preview_overlay != null and _pass_preview_overlay.visible)):
		return
	var button_overlay_size: Vector2 = _choice_button_overlay.get_combined_minimum_size()
	var button_overlay_position: Vector2 = _choice_button_overlay_anchor_position(button_overlay_size)
	var viewport_size: Vector2 = get_viewport_rect().size
	button_overlay_position.x = clampf(
		button_overlay_position.x,
		8.0,
		maxf(8.0, viewport_size.x - button_overlay_size.x - 8.0)
	)
	if _choice_button_overlay.visible:
		_choice_button_overlay.global_position = button_overlay_position
		_choice_button_overlay.size = button_overlay_size
	if _pass_preview_overlay == null or not _pass_preview_overlay.visible:
		_layout_action_step_tracker()
		_queue_contextual_combat_prompt_layout()
		return
	var preview_size: Vector2 = _pass_preview_overlay.get_combined_minimum_size()
	_pass_preview_overlay.global_position = Vector2(
		button_overlay_position.x,
		button_overlay_position.y - preview_size.y - PASS_PREVIEW_STACK_GAP
	)
	_pass_preview_overlay.size = preview_size
	_layout_action_step_tracker()
	_queue_contextual_combat_prompt_layout()

func _connect_choice_overlay_layout_signals() -> void:
	for control_var: Variant in [choice_bar, piles_bar, left_action_stack, bottom_stack, hand_row, board_view, _choice_button_overlay, _pass_preview_overlay]:
		var control: Control = control_var as Control
		if control == null:
			continue
		if not control.resized.is_connected(_queue_choice_button_overlay_layout):
			control.resized.connect(_queue_choice_button_overlay_layout)
		if not control.resized.is_connected(_queue_action_step_tracker_layout):
			control.resized.connect(_queue_action_step_tracker_layout)
		if not control.resized.is_connected(_queue_contextual_combat_prompt_layout):
			control.resized.connect(_queue_contextual_combat_prompt_layout)

func _queue_choice_button_overlay_layout() -> void:
	call_deferred("_layout_choice_button_overlay")

func _queue_action_step_tracker_layout() -> void:
	call_deferred("_layout_action_step_tracker")

func _queue_contextual_combat_prompt_layout() -> void:
	call_deferred("_layout_contextual_combat_prompt_overlay")

func _choice_button_overlay_anchor_position(overlay_size: Vector2) -> Vector2:
	var choice_rect: Rect2 = choice_bar.get_global_rect()
	var piles_position := Vector2.ZERO
	var has_piles_position: bool = false
	if piles_bar != null and piles_bar.is_inside_tree():
		var piles_rect: Rect2 = piles_bar.get_global_rect()
		if piles_rect.size.y > 0.0 and piles_rect.position.y > 0.0:
			var separation: float = float(left_action_stack.get_theme_constant("separation")) if left_action_stack != null else 0.0
			piles_position = Vector2(
				piles_rect.position.x,
				piles_rect.position.y - overlay_size.y - separation
			)
			has_piles_position = true
	if _choice_bar_anchor_is_ready(choice_rect):
		var choice_position: Vector2 = Vector2(choice_rect.position.x, choice_rect.position.y)
		if has_piles_position:
			return Vector2(choice_position.x, piles_position.y)
		return choice_position
	if has_piles_position:
		return piles_position
	return choice_rect.position

func _choice_bar_anchor_is_ready(choice_rect: Rect2) -> bool:
	if choice_rect.size.x <= 0.0 or choice_rect.size.y <= 0.0:
		return false
	if bottom_stack != null and bottom_stack.is_inside_tree():
		var bottom_rect: Rect2 = bottom_stack.get_global_rect()
		if bottom_rect.position.y > 0.0 and choice_rect.position.y < bottom_rect.position.y - 1.0:
			return false
	return choice_rect.position.y > 0.0

func _build_large_map_overlay() -> void:
	_large_map_scrim = ColorRect.new()
	_large_map_scrim.name = "LargeMapScrim"
	_large_map_scrim.visible = false
	_large_map_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_large_map_scrim.z_index = 940
	_large_map_scrim.z_as_relative = false
	_large_map_scrim.color = Color(0.015, 0.012, 0.010, 1.0)
	_large_map_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_large_map_scrim.anchor_right = 1.0
	_large_map_scrim.anchor_bottom = 1.0
	ui_root.add_child(_large_map_scrim)

	var frame_margin := MarginContainer.new()
	frame_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_margin.anchor_right = 1.0
	frame_margin.anchor_bottom = 1.0
	frame_margin.add_theme_constant_override("margin_left", int(UiTypography.SAFE_MARGIN))
	frame_margin.add_theme_constant_override("margin_top", int(UiTypography.SAFE_MARGIN))
	frame_margin.add_theme_constant_override("margin_right", int(UiTypography.SAFE_MARGIN))
	frame_margin.add_theme_constant_override("margin_bottom", int(UiTypography.SAFE_MARGIN))
	frame_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_large_map_scrim.add_child(frame_margin)

	_large_map_dialog = PanelContainer.new()
	_large_map_dialog.name = "LargeMapDialog"
	_large_map_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_large_map_dialog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_large_map_dialog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dialog_style := _ui_skin.make_plain_card_style(Color(0.09, 0.065, 0.048, 0.96), Color(0.92, 0.80, 0.60, 0.86), 16.0)
	dialog_style.corner_radius_top_left = 10
	dialog_style.corner_radius_top_right = 10
	dialog_style.corner_radius_bottom_right = 10
	dialog_style.corner_radius_bottom_left = 10
	dialog_style.shadow_size = 18
	_large_map_dialog.add_theme_stylebox_override("panel", dialog_style)
	frame_margin.add_child(_large_map_dialog)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING))
	content_margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING_COMPACT))
	content_margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING))
	content_margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING))
	_large_map_dialog.add_child(content_margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	content_margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	vbox.add_child(top_row)

	var title := Label.new()
	title.text = "Map"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(title, UiTypography.ROLE_TITLE)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	top_row.add_child(title)

	var close_button := UiTooltipButton.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.tooltip_text = "Close"
	_ui_skin.apply_button_stylebox_overrides(close_button, UiSkin.VARIANT_ICON)
	_ui_skin.apply_button_text_overrides(close_button)
	UiTypography.apply_button_role(close_button, UiTypography.ROLE_BODY)
	close_button.custom_minimum_size = Vector2(40.0, 40.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close_large_map)
	top_row.add_child(close_button)

	_large_map_view = LabyrinthMapViewScript.new()
	_large_map_view.name = "LargeMap"
	_large_map_view.set("interactive", true)
	_large_map_view.set("show_legend", true)
	_large_map_view.set("draw_background", false)
	_large_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_large_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_large_map_view.custom_minimum_size = Vector2(640.0, 400.0)
	_large_map_view.connect("room_selected", _on_large_map_room_selected)
	vbox.add_child(_large_map_view)
	_ui_skin.apply_outer_panel_frame(_large_map_dialog, UiSkin.SURFACE_PARCHMENT)

func _build_pre_battle_overlay() -> void:
	_pre_battle_scrim = ColorRect.new()
	_pre_battle_scrim.name = "PreBattleScrim"
	_pre_battle_scrim.visible = false
	_pre_battle_scrim.color = Color(0.018, 0.012, 0.010, 0.72)
	_pre_battle_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pre_battle_scrim.z_index = 1130
	_pre_battle_scrim.z_as_relative = false
	_pre_battle_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(_pre_battle_scrim)

	var center := CenterContainer.new()
	center.name = "PreBattleCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pre_battle_scrim.add_child(center)

	_pre_battle_panel = PanelContainer.new()
	_pre_battle_panel.name = "PreBattlePanel"
	_pre_battle_panel.custom_minimum_size = PRE_BATTLE_DIALOG_SIZE
	_pre_battle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := _pre_battle_style(Color(0.074, 0.050, 0.039, 0.98), Color(0.94, 0.76, 0.49, 0.74), 18.0, 10)
	style.shadow_size = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	_pre_battle_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_pre_battle_panel)
	_layout_pre_battle_dialog()

func _layout_pre_battle_dialog() -> void:
	if _pre_battle_panel == null:
		return
	var dialog_size: Vector2 = UiTypography.modal_size(_pre_battle_panel, PRE_BATTLE_DIALOG_SIZE, PRE_BATTLE_DIALOG_MIN_SIZE, UiTypography.SPACE_LARGE)
	_pre_battle_panel.custom_minimum_size = dialog_size
	_pre_battle_panel.size = dialog_size

func _pre_battle_style(fill: Color, border: Color, content_margin: float = 10.0, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

func _sync_pre_battle_overlay_layering() -> void:
	if _pre_battle_scrim == null:
		return
	var character_overlay_open: bool = _upgrade_scrim != null and _upgrade_scrim.visible
	_pre_battle_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE if character_overlay_open else Control.MOUSE_FILTER_STOP
	if character_overlay_open:
		_upgrade_scrim.move_to_front()
	elif _pre_battle_scrim.visible:
		_pre_battle_scrim.move_to_front()

func _rebuild_pre_battle_overlay() -> void:
	if _pre_battle_panel == null:
		return
	_clear_children_now(_pre_battle_panel)
	var preview_state: Dictionary = _pre_battle_preview_run_state.duplicate(true)
	var combat_state: Dictionary = (preview_state.get("combat_state", {}) as Dictionary).duplicate(true)
	if combat_state.is_empty():
		return
	var room: Dictionary = _run_engine.room_metadata(preview_state, preview_state.get("current_room", _run_state.get("current_room", _pre_battle_destination)))
	var room_element: String = str(combat_state.get("room_element", room.get("element", ElementData.NONE)))
	var accent: Color = ElementData.accent(room_element) if ElementData.is_elemental(room_element) else Color("d8b06d")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING))
	margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING))
	_pre_battle_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "PreBattleContent"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UiTypography.PANEL_GAP)
	margin.add_child(vbox)
	vbox.add_child(_build_pre_battle_header(room, combat_state, accent))

	var body := HBoxContainer.new()
	body.name = "PreBattleBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTypography.PANEL_GAP)
	vbox.add_child(body)
	body.add_child(_build_pre_battle_enemy_section(combat_state, accent))
	body.add_child(_build_pre_battle_deck_section(accent))

	call_deferred("_animate_pre_battle_living_parts")

func _build_pre_battle_header(room: Dictionary, combat_state: Dictionary, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.name = "PreBattleHeader"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)

	row.add_child(_build_pre_battle_room_chip(room, combat_state, accent))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var start_tiles: Array[Vector2i] = _run_engine.pre_battle_start_tiles(_run_state)
	if not start_tiles.is_empty():
		var position_button := UiTooltipButton.new()
		position_button.name = "TrueBearingButton"
		var selected_tile: Vector2i = _run_state.get("pre_battle_start", start_tiles[0])
		var selected_index: int = maxi(0, start_tiles.find(selected_tile))
		position_button.text = "Position %d/%d" % [selected_index + 1, start_tiles.size()]
		position_button.tooltip_text = "%s\nSelected tile: %d, %d" % [SkillTreeLibrary.description("true_bearing"), selected_tile.x, selected_tile.y]
		_ui_skin.apply_button_stylebox_overrides(position_button, UiSkin.VARIANT_STANDARD)
		_ui_skin.apply_button_text_overrides(position_button)
		UiTypography.apply_button_role(position_button, UiTypography.ROLE_BODY)
		_ui_skin.apply_button_native_size(position_button, UiSkin.BUTTON_HEIGHT_STANDARD)
		position_button.custom_minimum_size.x = 148.0
		position_button.pressed.connect(_on_true_bearing_pressed)
		row.add_child(position_button)

	var gear_button := UiTooltipButton.new()
	gear_button.name = "PreBattleEquipButton"
	gear_button.text = "Equip"
	gear_button.tooltip_text = "Character"
	gear_button.icon = AssetLoader.load_texture("res://assets/art/equipment/training_sword.png")
	gear_button.expand_icon = true
	_ui_skin.apply_button_stylebox_overrides(gear_button, UiSkin.VARIANT_STANDARD)
	_ui_skin.apply_button_text_overrides(gear_button)
	UiTypography.apply_button_role(gear_button, UiTypography.ROLE_BODY)
	_ui_skin.apply_button_native_size(gear_button, UiSkin.BUTTON_HEIGHT_STANDARD)
	gear_button.custom_minimum_size.x = 132.0
	gear_button.pressed.connect(_on_pre_battle_equip_pressed)
	row.add_child(gear_button)

	var start_button := UiTooltipButton.new()
	start_button.name = "PreBattleStartButton"
	start_button.text = "Start"
	start_button.tooltip_text = "Start combat"
	start_button.icon = ActionIcons.icon_texture("melee")
	start_button.expand_icon = true
	_ui_skin.apply_button_stylebox_overrides(start_button, UiSkin.VARIANT_SELECTED)
	_ui_skin.apply_button_text_overrides(start_button)
	UiTypography.apply_button_role(start_button, UiTypography.ROLE_SECTION)
	_ui_skin.apply_button_native_size(start_button, UiSkin.BUTTON_HEIGHT_ACTION, 0.0, true, UiSkin.VARIANT_SELECTED)
	start_button.custom_minimum_size.x = 158.0
	start_button.pressed.connect(_on_pre_battle_start_pressed)
	row.add_child(start_button)
	return row

func _on_true_bearing_pressed() -> void:
	var start_tiles: Array[Vector2i] = _run_engine.pre_battle_start_tiles(_run_state)
	if start_tiles.is_empty():
		return
	var current_tile: Vector2i = _run_state.get("pre_battle_start", start_tiles[0])
	var current_index: int = start_tiles.find(current_tile)
	var next_tile: Vector2i = start_tiles[(maxi(0, current_index) + 1) % start_tiles.size()]
	var before_state: Dictionary = _run_state.duplicate(true)
	_run_state = _run_engine.set_pre_battle_start(_run_state, next_tile)
	if _run_state == before_state:
		return
	_persist_committed_boundary("pre_battle_position_chosen")
	_refresh_pre_battle_preview_if_visible()

func _build_pre_battle_room_chip(room: Dictionary, combat_state: Dictionary, accent: Color) -> Control:
	var chip := VBoxContainer.new()
	chip.name = "PreBattleRoomChip"
	chip.custom_minimum_size = Vector2(510.0, 62.0)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_constant_override("separation", 0)
	var title := Label.new()
	var header_room: Dictionary = room.duplicate(true)
	header_room["name"] = str(combat_state.get("room_name", room.get("name", "Combat")))
	header_room["type"] = str(combat_state.get("room_type", room.get("type", "combat")))
	header_room["element"] = str(combat_state.get("room_element", room.get("element", ElementData.NONE)))
	title.text = _room_title_text(header_room)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTypography.apply_label_role(title, UiTypography.ROLE_TITLE)
	title.add_theme_color_override("font_color", accent if ElementData.is_elemental(str(header_room.get("element", ElementData.NONE))) else Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	chip.add_child(title)
	var meta_row := HBoxContainer.new()
	meta_row.name = "PreBattleRoomMeta"
	meta_row.add_theme_constant_override("separation", 0)
	chip.add_child(meta_row)
	var depth_label := Label.new()
	depth_label.name = "PreBattleDepthLabel"
	depth_label.text = "Depth %d" % int(combat_state.get("room_depth", room.get("depth", 0)))
	UiTypography.apply_label_role(depth_label, UiTypography.ROLE_BODY_LARGE)
	depth_label.add_theme_color_override("font_color", accent.lightened(0.28))
	meta_row.add_child(depth_label)
	if combat_state.has("umbra"):
		var umbra_stage: String = _combat_engine.effective_umbra_stage(combat_state)
		if umbra_stage != "clear":
			var separator := Label.new()
			separator.text = "  ·  "
			UiTypography.apply_label_role(separator, UiTypography.ROLE_BODY_LARGE)
			separator.add_theme_color_override("font_color", accent.lightened(0.28))
			meta_row.add_child(separator)
			var umbra_label := Label.new()
			umbra_label.name = "PreBattleUmbraLabel"
			umbra_label.text = "%s Umbra" % CombatEngineScript.umbra_stage_display_name(umbra_stage)
			UiTypography.apply_label_role(umbra_label, UiTypography.ROLE_BODY_LARGE)
			umbra_label.add_theme_color_override("font_color", PRE_BATTLE_UMBRA_COLOR)
			meta_row.add_child(umbra_label)
	return chip

func _build_pre_battle_enemy_section(combat_state: Dictionary, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.name = "PreBattleEnemySection"
	panel.custom_minimum_size = Vector2(676.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.045, 0.034, 0.029, 0.90), Color(0.72, 0.58, 0.42, 0.48), 12.0, 8))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	margin.add_child(vbox)
	vbox.add_child(_pre_battle_section_label("Foes", ActionIcons.icon_texture("melee"), accent))

	var scroll := ScrollContainer.new()
	scroll.name = "PreBattleEnemyScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	vbox.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.name = "PreBattleEnemyFlow"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	scroll.add_child(flow)

	var enemies: Array = []
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if int(enemy.get("hp", 0)) <= 0:
			continue
		enemies.append(enemy)
	var card_size: Vector2 = _pre_battle_enemy_card_size(enemies.size())
	var card_gap: int = 8 if enemies.size() >= 5 else 12
	flow.add_theme_constant_override("h_separation", card_gap)
	flow.add_theme_constant_override("v_separation", card_gap)
	for enemy_var: Variant in enemies:
		flow.add_child(_build_pre_battle_enemy_card(enemy_var as Dictionary, accent, card_size))
	return panel

func _pre_battle_enemy_card_size(enemy_count: int) -> Vector2:
	if enemy_count == 1:
		return PRE_BATTLE_ENEMY_CARD_SOLO_SIZE
	if enemy_count >= 5:
		return PRE_BATTLE_ENEMY_CARD_COMPACT_SIZE
	return PRE_BATTLE_ENEMY_CARD_SIZE

func _build_pre_battle_deck_section(accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.name = "PreBattleDeckSection"
	panel.custom_minimum_size = Vector2(438.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.045, 0.034, 0.029, 0.90), Color(0.72, 0.58, 0.42, 0.48), 12.0, 8))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	margin.add_child(vbox)
	vbox.add_child(_build_pre_battle_player_strip(accent))
	var active_deck: Array = (_run_state.get("deck_cards", []) as Array).duplicate()
	var deck_groups: Array = _pre_battle_card_groups(active_deck)
	var badge_layout: Dictionary = _pre_battle_card_badge_layout("deck", deck_groups.size())
	vbox.add_child(_pre_battle_section_label("Active Deck  %d" % active_deck.size(), ActionIcons.icon_texture("card_play"), accent))

	var scroll := ScrollContainer.new()
	scroll.name = "PreBattleDeckScroll"
	scroll.set_meta("deck_entry_count", active_deck.size())
	scroll.set_meta("deck_group_count", deck_groups.size())
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	vbox.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.name = "PreBattleDeckFlow"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", int(badge_layout.get("h_gap", 5)))
	flow.add_theme_constant_override("v_separation", int(badge_layout.get("v_gap", 5)))
	scroll.add_child(flow)
	for group_var: Variant in deck_groups:
		var group: Dictionary = group_var as Dictionary
		flow.add_child(_build_pre_battle_card_badge(
			str(group.get("card_id", "")),
			"PreBattleDeckBadge",
			"deck",
			int(group.get("count", 1)),
			badge_layout.get("badge_size", EQUIPMENT_DECK_BADGE_SIZE) as Vector2,
			int(badge_layout.get("font_size", UiTypography.SIZE_CAPTION))
		))
	return panel

func _build_pre_battle_player_strip(accent: Color) -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "PreBattlePlayerStrip"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UiTypography.SPACE_TIGHT)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	vbox.add_child(top_row)
	top_row.add_child(_build_pre_battle_hp_chip(accent))

	vbox.add_child(_pre_battle_loadout_label("Equipment", "Hover or click to inspect"))

	var equipment_row := HFlowContainer.new()
	equipment_row.name = "PreBattleEquipmentRow"
	equipment_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_row.add_theme_constant_override("h_separation", 6)
	equipment_row.add_theme_constant_override("v_separation", 4)
	vbox.add_child(equipment_row)
	var equipped: Dictionary = (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
	for slot: String in GameData.equipment_slots():
		var equipment_id: String = str(equipped.get(slot, ""))
		if equipment_id.is_empty():
			continue
		equipment_row.add_child(_build_pre_battle_equipment_chip(equipment_id))

	var attuned: Array = (_run_state.get("attuned_magic_cards", []) as Array).duplicate()
	var attuned_groups: Array = _pre_battle_card_groups(attuned)
	var badge_layout: Dictionary = _pre_battle_card_badge_layout("attuned", attuned_groups.size())
	vbox.add_child(_pre_battle_loadout_label("Attuned Magic  %d/%d" % [attuned.size(), GameData.magic_loadout_limit()], "Active spells"))
	var attuned_row := HFlowContainer.new()
	attuned_row.name = "PreBattleAttunedRow"
	attuned_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attuned_row.add_theme_constant_override("h_separation", int(badge_layout.get("h_gap", 5)))
	attuned_row.add_theme_constant_override("v_separation", int(badge_layout.get("v_gap", 5)))
	vbox.add_child(attuned_row)
	for group_var: Variant in attuned_groups:
		var group: Dictionary = group_var as Dictionary
		attuned_row.add_child(_build_pre_battle_card_badge(
			str(group.get("card_id", "")),
			"PreBattleAttunedBadge",
			"attuned",
			int(group.get("count", 1)),
			badge_layout.get("badge_size", PRE_BATTLE_CARD_BADGE_COMPACT_SIZE) as Vector2,
			int(badge_layout.get("font_size", UiTypography.SIZE_CAPTION))
		))
	return vbox

func _pre_battle_card_groups(card_ids: Array) -> Array:
	var groups: Array = []
	var group_index_by_card: Dictionary = {}
	for card_id_var: Variant in card_ids:
		var card_id: String = str(card_id_var)
		if card_id.is_empty():
			continue
		if group_index_by_card.has(card_id):
			var existing_index: int = int(group_index_by_card[card_id])
			var existing_group: Dictionary = (groups[existing_index] as Dictionary).duplicate(true)
			existing_group["count"] = int(existing_group.get("count", 1)) + 1
			groups[existing_index] = existing_group
			continue
		group_index_by_card[card_id] = groups.size()
		groups.append({"card_id": card_id, "count": 1})
	return groups

func _pre_battle_card_badge_layout(source_kind: String, group_count: int) -> Dictionary:
	var viewport_height: float = get_viewport_rect().size.y
	var compact_height: bool = viewport_height <= 740.0
	var dense: bool = source_kind == "attuned" or group_count >= PRE_BATTLE_CARD_BADGE_DENSE_THRESHOLD
	if not dense:
		return {
			"badge_size": EQUIPMENT_DECK_BADGE_SIZE,
			"font_size": UiTypography.SIZE_CAPTION,
			"h_gap": 7,
			"v_gap": 7,
		}
	return {
		"badge_size": PRE_BATTLE_CARD_BADGE_COMPACT_SIZE if compact_height else PRE_BATTLE_CARD_BADGE_DENSE_SIZE,
		"font_size": 12,
		"h_gap": 5,
		"v_gap": 1 if compact_height else 2,
	}

func _pre_battle_loadout_label(text: String, detail: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("f0c978"))
	label.add_theme_color_override("font_outline_color", Color("120b08"))
	label.add_theme_constant_override("outline_size", 1)
	row.add_child(label)
	var detail_label := Label.new()
	detail_label.text = detail
	UiTypography.set_label_size(detail_label, 10)
	detail_label.add_theme_color_override("font_color", Color("a99a83"))
	row.add_child(detail_label)
	return row

func _build_pre_battle_hp_chip(accent: Color) -> Control:
	var chip := PanelContainer.new()
	chip.name = "PreBattleHealthChip"
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size = Vector2(0.0, 40.0)
	chip.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.035, 0.027, 0.024, 0.86), accent.darkened(0.05), 6.0, 7))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ActionIcons.icon_texture("health")
	icon.custom_minimum_size = Vector2(28.0, 28.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = "%d/%d" % [int(_run_state.get("player_hp", 0)), int(_run_state.get("player_max_hp", 0))]
	UiTypography.apply_label_role(label, UiTypography.ROLE_BODY)
	label.add_theme_color_override("font_color", Color("fff0ce"))
	label.add_theme_color_override("font_outline_color", Color("120b08"))
	label.add_theme_constant_override("outline_size", 1)
	row.add_child(label)
	var defiance_capacity: int = _run_engine.defiance_capacity(_run_state)
	if defiance_capacity > 0:
		var separator := ColorRect.new()
		separator.custom_minimum_size = Vector2(1.0, 22.0)
		separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		separator.color = Color("725f76")
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(separator)
		var defiance_icon := TextureRect.new()
		defiance_icon.texture = ActionIcons.icon_texture("defiance")
		defiance_icon.custom_minimum_size = Vector2(24.0, 24.0)
		defiance_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		defiance_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		defiance_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		defiance_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(defiance_icon)
		var defiance_label := Label.new()
		defiance_label.name = "PreBattleDefianceCount"
		defiance_label.text = "%d/%d" % [
			_run_engine.defiance_remaining(_run_state),
			defiance_capacity
		]
		UiTypography.apply_label_role(defiance_label, UiTypography.ROLE_BODY)
		defiance_label.add_theme_color_override("font_color", Color("f6d77d"))
		defiance_label.add_theme_color_override("font_outline_color", Color("120b08"))
		defiance_label.add_theme_constant_override("outline_size", 1)
		row.add_child(defiance_label)
	return chip

func _pre_battle_section_label(text: String, icon_texture: Texture2D, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.name = "PreBattle%sLabel" % text
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(28.0, 28.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(label, UiTypography.ROLE_SECTION)
	label.add_theme_color_override("font_color", Color("fff0ce"))
	label.add_theme_color_override("font_outline_color", Color("120b08"))
	label.add_theme_constant_override("outline_size", 1)
	row.add_child(label)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.color = Color(accent.r, accent.g, accent.b, 0.38)
	row.add_child(line)
	return row

func _build_pre_battle_enemy_card(enemy: Dictionary, room_accent: Color, card_size: Vector2) -> Control:
	var enemy_type: String = str(enemy.get("type", ""))
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var accent: Color = room_accent
	var card := PreBattleEnemyCard.new()
	card.name = "PreBattleEnemyCard"
	card.enemy = enemy.duplicate(true)
	card.host = self
	card.custom_minimum_size = card_size
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.clip_contents = true
	card.tooltip_text = "enemy:%s" % enemy_type
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.038, 0.029, 0.025, 0.96), accent.lightened(0.08), 0.0, 8))

	var stack := Control.new()
	stack.clip_contents = true
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(stack)

	var art := _pre_battle_enemy_portrait(enemy_type, enemy_def)
	art.name = "PreBattleEnemyArt"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = PRE_BATTLE_PORTRAIT_INSET
	art.offset_top = 40.0
	art.offset_right = -PRE_BATTLE_PORTRAIT_INSET
	art.offset_bottom = -50.0
	art.modulate = Color(1.0, 0.96, 0.88, 1.0)
	stack.add_child(art)

	var tint := ColorRect.new()
	tint.name = "PreBattleEnemyTint"
	tint.color = Color(accent.r, accent.g, accent.b, 0.10)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(tint)

	var name_label := Label.new()
	name_label.name = "PreBattleEnemyName"
	name_label.text = str(enemy_def.get("name", enemy_type))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.offset_top = card_size.y - 48.0
	name_label.offset_bottom = -21.0
	name_label.offset_left = 8.0
	name_label.offset_right = -8.0
	UiTypography.set_label_size(name_label, UiTypography.SIZE_CAPTION)
	name_label.add_theme_color_override("font_color", Color("fff4d6"))
	name_label.add_theme_color_override("font_outline_color", Color("100907"))
	name_label.add_theme_constant_override("outline_size", 2)
	stack.add_child(name_label)

	var threat_label := Label.new()
	threat_label.name = "PreBattleThreatSummary"
	threat_label.text = _pre_battle_enemy_threat_summary(enemy_type)
	threat_label.clip_text = true
	threat_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	threat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	threat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	threat_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	threat_label.offset_top = card_size.y - 24.0
	threat_label.offset_left = 8.0
	threat_label.offset_right = -8.0
	UiTypography.set_label_size(threat_label, 10)
	threat_label.add_theme_color_override("font_color", accent.lightened(0.34))
	threat_label.add_theme_color_override("font_outline_color", Color("100907"))
	threat_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(threat_label)

	var hp := _build_pre_battle_enemy_hp_badge(enemy, accent)
	hp.position = Vector2(8.0, 8.0)
	stack.add_child(hp)
	return card

func _build_pre_battle_enemy_hp_badge(enemy: Dictionary, accent: Color) -> Control:
	var chip := PanelContainer.new()
	chip.name = "PreBattleEnemyHealth"
	chip.custom_minimum_size = Vector2(88.0, 32.0)
	chip.size = chip.custom_minimum_size
	chip.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.035, 0.027, 0.024, 0.88), accent.lightened(0.14), 5.0, 7))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ActionIcons.icon_texture("health")
	icon.custom_minimum_size = Vector2(22.0, 22.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var label := Label.new()
	var hp: int = int(enemy.get("hp", 0))
	var max_hp: int = int(enemy.get("max_hp", hp))
	label.text = str(hp) if hp == max_hp else "%d/%d" % [hp, max_hp]
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("fff0ce"))
	label.add_theme_color_override("font_outline_color", Color("100907"))
	label.add_theme_constant_override("outline_size", 1)
	row.add_child(label)
	return chip

func _build_pre_battle_card_badge(card_id: String, badge_name: String, source_kind: String, card_count: int = 1, badge_size: Vector2 = EQUIPMENT_DECK_BADGE_SIZE, font_size: int = UiTypography.SIZE_CAPTION) -> Control:
	var card: Dictionary = GameData.card_def(card_id)
	var accent: Color = ElementData.accent(GameData.card_element(card_id))
	var badge := PreBattleCardBadge.new()
	badge.name = badge_name
	badge.card_id = card_id
	badge.host = self
	badge.source_kind = source_kind
	badge.set_meta("card_id", card_id)
	badge.set_meta("source_kind", source_kind)
	badge.set_meta("card_count", maxi(1, card_count))
	badge.custom_minimum_size = badge_size
	badge.tooltip_text = "card:%s" % card_id
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.clip_contents = true
	badge.add_theme_stylebox_override("panel", _equipment_panel_style(accent, false))
	var display_name: String = str(card.get("name", card_id))
	if card_count > 1:
		display_name += " x%d" % card_count
	badge.set_meta("display_name", display_name)
	var content: Control = _build_card_art_badge_content(card, accent, display_name)
	var name_label: Label = content.find_child("CardBadgeName", true, false) as Label
	if name_label != null:
		var fitted_font_size: int = _pre_battle_badge_font_size(display_name, badge_size.x, font_size)
		UiTypography.set_label_size(name_label, fitted_font_size)
		badge.set_meta("label_font_size", fitted_font_size)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = 2
		name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		name_label.add_theme_constant_override("line_spacing", -3)
		name_label.offset_left = 4.0
		name_label.offset_right = -4.0
	badge.add_child(content)
	return badge

func _pre_battle_badge_font_size(display_name: String, badge_width: float, preferred_size: int) -> int:
	var font: Font = UiTypography.body_font()
	var fitted_size: int = preferred_size
	var available_width: float = maxf(24.0, badge_width - 18.0)
	while font != null and fitted_size > 10 and font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > available_width:
		fitted_size -= 1
	return fitted_size

func _build_pre_battle_equipment_chip(equipment_id: String) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var chip := PreBattleEquipmentChip.new()
	chip.name = "PreBattleEquipmentChip"
	chip.equipment_id = equipment_id
	chip.host = self
	chip.set_meta("equipment_id", equipment_id)
	chip.tooltip_text = "equipment:%s" % equipment_id
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.custom_minimum_size = PRE_BATTLE_EQUIPMENT_ICON_SIZE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _equipment_icon_style(Color(GameData.equipment_accent(equipment_id))))
	var icon := TextureRect.new()
	icon.texture = AssetLoader.load_texture(str(item.get("icon_path", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chip.add_child(icon)
	return chip

func _pre_battle_enemy_threat_summary(enemy_type: String) -> String:
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var tags: Array[String] = []
	for intent_var: Variant in enemy_def.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		for action_var: Variant in (intent_var as Dictionary).get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			var action_type: String = str(action.get("type", ""))
			var tag: String = ""
			match action_type:
				"melee":
					tag = "Melee"
				"ranged":
					tag = "Ranged"
				"aoe", "lightning_strikes":
					tag = "Area"
				"block", "guard_ally":
					tag = "Guard"
				"stoneskin":
					tag = "Stoneskin"
				"heal", "heal_self", "heal_ally":
					tag = "Heal"
				"move_away":
					tag = "Retreat"
				"pull":
					tag = "Pull"
				"push":
					tag = "Push"
				"summon_minions":
					tag = "Summon"
				"raise_terrain", "terrain_burst":
					tag = "Worldspines"
				"cinder_marks", "detonate_cinders":
					tag = "Cinder Marks"
				"gale_force":
					tag = "Arena Gale"
				"frost_armor":
					tag = "Crystal Armor"
				"umbra_eclipse":
					tag = "Eclipse"
				"split":
					tag = "Split"
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
			if bool(action.get("pierce", false)) and not tags.has("Pierce"):
				tags.append("Pierce")
			if int(action.get("bleed", 0)) > 0 and not tags.has("Bleed"):
				tags.append("Bleed")
	if tags.is_empty():
		return "Inspect known moves"
	var visible_tags: Array[String] = []
	for index: int in range(mini(3, tags.size())):
		visible_tags.append(tags[index])
	var summary: String = " / ".join(visible_tags)
	if tags.size() > visible_tags.size():
		summary += "  +%d" % (tags.size() - visible_tags.size())
	return summary

func _pre_battle_known_enemy_intents(enemy_type: String) -> Array:
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var base_intents: Array = enemy_def.get("intents", []) as Array
	var combat_state: Dictionary = _pre_battle_preview_run_state.get("combat_state", {}) as Dictionary
	var room_depth: int = int(combat_state.get("room_depth", 1))
	var scaled_var: Variant = _combat_engine.call("_scaled_enemy_intents", base_intents, room_depth)
	if typeof(scaled_var) == TYPE_ARRAY:
		return (scaled_var as Array).duplicate(true)
	return base_intents.duplicate(true)

func _build_pre_battle_enemy_inspection_panel(enemy: Dictionary, interactive: bool = false) -> Control:
	var enemy_type: String = str(enemy.get("type", ""))
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var accent := Color(str(enemy_def.get("accent", "#d8b06d")))
	var panel := PanelContainer.new()
	panel.name = "PreBattleEnemyInspection"
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.054, 0.038, 0.031, 0.99), accent.lightened(0.22), 14.0, 10))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(138.0, 138.0)
	portrait_frame.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.025, 0.021, 0.020, 0.98), accent, 6.0, 8))
	header.add_child(portrait_frame)
	var portrait_inset := MarginContainer.new()
	portrait_inset.name = "PreBattleEnemyPortraitInset"
	portrait_inset.add_theme_constant_override("margin_left", int(PRE_BATTLE_PORTRAIT_INSET * 0.5))
	portrait_inset.add_theme_constant_override("margin_top", int(PRE_BATTLE_PORTRAIT_INSET * 0.5))
	portrait_inset.add_theme_constant_override("margin_right", int(PRE_BATTLE_PORTRAIT_INSET * 0.5))
	portrait_inset.add_theme_constant_override("margin_bottom", int(PRE_BATTLE_PORTRAIT_INSET * 0.5))
	portrait_frame.add_child(portrait_inset)
	var portrait := _pre_battle_enemy_portrait(enemy_type, enemy_def)
	portrait.name = "PreBattleEnemyPortrait"
	portrait_inset.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 5)
	header.add_child(identity)
	var name_label := Label.new()
	name_label.text = str(enemy_def.get("name", enemy_type))
	UiTypography.set_label_size(name_label, UiTypography.SIZE_TITLE)
	name_label.add_theme_color_override("font_color", Color("fff0ce"))
	name_label.add_theme_color_override("font_outline_color", Color("120b08"))
	name_label.add_theme_constant_override("outline_size", 2)
	identity.add_child(name_label)
	var hp: int = int(enemy.get("hp", enemy_def.get("max_hp", 0)))
	var max_hp: int = int(enemy.get("max_hp", hp))
	var stat_row := HBoxContainer.new()
	stat_row.name = "PreBattleEnemyStatRow"
	stat_row.add_theme_constant_override("separation", 10)
	identity.add_child(stat_row)
	var hp_label := Label.new()
	hp_label.name = "PreBattleEnemyHpLine"
	hp_label.text = "HP %d/%d" % [hp, max_hp]
	UiTypography.set_label_size(hp_label, UiTypography.SIZE_SMALL)
	hp_label.add_theme_color_override("font_color", PRE_BATTLE_HP_COLOR)
	stat_row.add_child(hp_label)
	var stat_separator := Label.new()
	stat_separator.text = "/"
	UiTypography.set_label_size(stat_separator, UiTypography.SIZE_SMALL)
	stat_separator.add_theme_color_override("font_color", Color("a99a83"))
	stat_row.add_child(stat_separator)
	var initiative_label := Label.new()
	initiative_label.name = "PreBattleEnemyInitiativeLine"
	initiative_label.text = "Base initiative %d" % int(enemy_def.get("base_initiative", 0))
	UiTypography.set_label_size(initiative_label, UiTypography.SIZE_SMALL)
	initiative_label.add_theme_color_override("font_color", PRE_BATTLE_INITIATIVE_COLOR)
	stat_row.add_child(initiative_label)
	var threat_label := Label.new()
	threat_label.text = _pre_battle_enemy_threat_summary(enemy_type)
	UiTypography.set_label_size(threat_label, UiTypography.SIZE_SMALL)
	threat_label.add_theme_color_override("font_color", accent.lightened(0.36))
	identity.add_child(threat_label)
	if interactive:
		var close_button := UiTooltipButton.new()
		close_button.name = "PreBattleInspectionCloseButton"
		close_button.text = "X"
		close_button.tooltip_text = "Close"
		_ui_skin.apply_button_stylebox_overrides(close_button, UiSkin.VARIANT_ICON)
		_ui_skin.apply_button_text_overrides(close_button)
		UiTypography.apply_button_role(close_button, UiTypography.ROLE_BODY)
		close_button.custom_minimum_size = Vector2(40.0, 40.0)
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		close_button.pressed.connect(_close_pinned_tooltip)
		header.add_child(close_button)

	vbox.add_child(_pre_battle_section_label("Known Moves", ActionIcons.icon_texture("time"), accent))
	var moves := VBoxContainer.new()
	moves.name = "PreBattleKnownMoves"
	moves.add_theme_constant_override("separation", 7)
	vbox.add_child(moves)
	var intents: Array = _pre_battle_known_enemy_intents(enemy_type)
	for intent_var: Variant in intents:
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		moves.add_child(_build_pre_battle_known_move_row(intent_var as Dictionary, accent))
	if moves.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "No recorded moves."
		UiTypography.set_label_size(empty_label, UiTypography.SIZE_SMALL)
		empty_label.add_theme_color_override("font_color", Color("b8a891"))
		moves.add_child(empty_label)
	return panel

func _build_pre_battle_known_move_row(intent: Dictionary, accent: Color) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.name = "PreBattleKnownMoveRow"
	row_panel.custom_minimum_size = Vector2(0.0, 58.0)
	row_panel.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.032, 0.026, 0.024, 0.94), Color(accent.r, accent.g, accent.b, 0.48), 8.0, 7))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row_panel.add_child(row)
	var actions: Array = intent.get("actions", []) as Array
	var icon_key: String = _pre_battle_known_move_icon_key(intent)
	var icon := TextureRect.new()
	icon.name = "PreBattleKnownMoveIcon"
	icon.set_meta("icon_key", icon_key)
	icon.texture = ActionIcons.icon_texture(icon_key)
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)
	var title := Label.new()
	title.text = str(intent.get("name", "Move"))
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("fff0ce"))
	text_box.add_child(title)
	var summary := Label.new()
	var summary_text: String = ActionIcons.plain_text_for_rows(ActionIcons.rows_for_actions(actions)).replace("\n", "  /  ")
	summary.text = summary_text if not summary_text.is_empty() else "Special action"
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTypography.set_label_size(summary, UiTypography.SIZE_CAPTION)
	summary.add_theme_color_override("font_color", Color("cdbda5"))
	text_box.add_child(summary)
	var time_chip := PanelContainer.new()
	time_chip.custom_minimum_size = Vector2(76.0, 34.0)
	time_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_chip.add_theme_stylebox_override("panel", _pre_battle_style(Color(0.08, 0.055, 0.03, 0.96), accent, 5.0, 6))
	row.add_child(time_chip)
	var time_label := Label.new()
	time_label.text = "TIME %d" % int(intent.get("time", 0))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(time_label, UiTypography.SIZE_CAPTION)
	time_label.add_theme_color_override("font_color", Color("f4d895"))
	time_chip.add_child(time_label)
	return row_panel

func _pre_battle_known_move_icon_key(intent: Dictionary) -> String:
	var best_key: String = "melee"
	var best_priority: int = 1000
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		var action_type: String = str(action.get("type", ""))
		var candidate: String = ActionIcons.action_icon_key(action)
		var priority: int = 100
		match action_type:
			"melee", "aoe":
				priority = 0
			"ranged", "lightning_strikes":
				priority = 1
			"push", "pull":
				priority = 2
			"block", "guard_ally":
				priority = 3
			"stoneskin":
				priority = 3
			"heal", "heal_self", "heal_ally":
				priority = 4
			"summon_minions":
				priority = 5
			"raise_terrain", "terrain_burst":
				priority = 2
			"cinder_marks", "detonate_cinders":
				priority = 2
			"gale_force":
				priority = 1
			"frost_armor":
				priority = 2
			"umbra_eclipse":
				priority = 1
			"move", "move_toward":
				priority = 20
			"move_away":
				priority = 20
			"blink":
				priority = 20
			_:
				priority = 10
		if candidate.is_empty():
			candidate = _action_step_icon_key(action)
		if not candidate.is_empty() and priority < best_priority:
			best_key = candidate
			best_priority = priority
	return best_key

func _pre_battle_enemy_portrait(enemy_type: String, enemy_def: Dictionary) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = _pre_battle_enemy_texture(enemy_type, enemy_def)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait

func _pre_battle_enemy_texture(enemy_type: String, enemy_def: Dictionary) -> Texture2D:
	var art_path: String = str(enemy_def.get("art_path", ""))
	if not art_path.is_empty():
		return AssetLoader.load_texture(art_path)
	var portrait_path: String = str(TURN_ORDER_PORTRAITS.get(enemy_type, ""))
	if not portrait_path.is_empty():
		return AssetLoader.load_texture(portrait_path)
	return null

func _animate_pre_battle_entry() -> void:
	if _pre_battle_scrim == null or _pre_battle_panel == null or not _pre_battle_scrim.visible:
		return
	await get_tree().process_frame
	if _pre_battle_scrim == null or _pre_battle_panel == null or not _pre_battle_scrim.visible:
		return
	if _reduced_motion_enabled():
		_pre_battle_scrim.modulate = Color.WHITE
		_pre_battle_panel.scale = Vector2.ONE
		return
	_pre_battle_scrim.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_pre_battle_panel.pivot_offset = _pre_battle_panel.size * 0.5
	_pre_battle_panel.scale = Vector2(0.965, 0.965)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_pre_battle_scrim, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_pre_battle_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_pre_battle_living_parts() -> void:
	if _reduced_motion_enabled() or _pre_battle_panel == null or not _node_is_alive(_pre_battle_panel):
		return
	await get_tree().process_frame
	if _pre_battle_panel == null or not _node_is_alive(_pre_battle_panel):
		return
	var index: int = 0
	for badge_node: Node in _pre_battle_panel.find_children("PreBattleDeckBadge", "PanelContainer", true, false):
		if badge_node is Control and index < PRE_BATTLE_CARD_LIMIT:
			_animate_pre_battle_badge_lift(badge_node as Control, float(index) * 0.012)
			index += 1

func _animate_pre_battle_badge_lift(badge: Control, delay: float) -> void:
	if badge == null:
		return
	var start_position: Vector2 = badge.position
	badge.modulate = Color(1.0, 1.0, 1.0, 0.78)
	badge.position = start_position + Vector2(0.0, 5.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(badge, "position", start_position, 0.18).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "modulate:a", 1.0, 0.18).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _build_context_choice_overlay() -> void:
	if stage_root == null:
		return
	_context_choice_overlay = PanelContainer.new()
	_context_choice_overlay.name = "ContextChoiceOverlay"
	_context_choice_overlay.visible = false
	_context_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.10, 0.065, 0.045, 0.88)
	overlay_style.border_color = Color(0.88, 0.63, 0.32, 0.72)
	overlay_style.border_width_left = 2
	overlay_style.border_width_top = 2
	overlay_style.border_width_right = 2
	overlay_style.border_width_bottom = 2
	overlay_style.corner_radius_top_left = 8
	overlay_style.corner_radius_top_right = 8
	overlay_style.corner_radius_bottom_right = 8
	overlay_style.corner_radius_bottom_left = 8
	overlay_style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	overlay_style.shadow_size = 12
	overlay_style.content_margin_left = 12
	overlay_style.content_margin_top = 10
	overlay_style.content_margin_right = 12
	overlay_style.content_margin_bottom = 10
	_context_choice_overlay.add_theme_stylebox_override("panel", overlay_style)
	stage_root.add_child(_context_choice_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_context_choice_overlay.add_child(margin)

	_context_choice_bar = HBoxContainer.new()
	_context_choice_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_context_choice_bar.add_theme_constant_override("separation", 16)
	margin.add_child(_context_choice_bar)
	_layout_context_choice_overlay()
	_build_relic_choice_overlay(stage_root)
	_build_run_end_recap(stage_root)

func _layout_context_choice_overlay() -> void:
	if _context_choice_overlay == null:
		return
	var stage_size: Vector2 = stage_root.size if stage_root != null else get_viewport_rect().size
	var width: float = clampf(stage_size.x * 0.52, 360.0, CAMPFIRE_ACTION_OVERLAY_SIZE.x)
	var height: float = CAMPFIRE_ACTION_OVERLAY_SIZE.y
	_context_choice_overlay.anchor_left = 0.5
	_context_choice_overlay.anchor_top = 1.0
	_context_choice_overlay.anchor_right = 0.5
	_context_choice_overlay.anchor_bottom = 1.0
	_context_choice_overlay.offset_left = -width * 0.5
	_context_choice_overlay.offset_right = width * 0.5
	_context_choice_overlay.offset_top = -height - 24.0
	_context_choice_overlay.offset_bottom = -24.0
	_layout_relic_choice_overlay()

func _build_relic_choice_overlay(stage_root: Control) -> void:
	_relic_choice_overlay = Control.new()
	_relic_choice_overlay.name = "RelicChoiceOverlay"
	_relic_choice_overlay.visible = false
	_relic_choice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_overlay.z_index = 70
	stage_root.add_child(_relic_choice_overlay)

	_relic_choice_backdrop = ColorRect.new()
	_relic_choice_backdrop.name = "SelectionBackdrop"
	_relic_choice_backdrop.visible = false
	_relic_choice_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_relic_choice_backdrop.anchor_right = 1.0
	_relic_choice_backdrop.anchor_bottom = 1.0
	_relic_choice_backdrop.color = Color(0.012, 0.008, 0.006, 0.62)
	_relic_choice_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_overlay.add_child(_relic_choice_backdrop)

	_relic_choice_banner = TextureRect.new()
	_relic_choice_banner.name = "SelectionBanner"
	_relic_choice_banner.visible = false
	_relic_choice_banner.texture = AssetLoader.load_texture(SELECTION_BANNER_TEXTURE_PATH)
	_relic_choice_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_relic_choice_banner.stretch_mode = TextureRect.STRETCH_SCALE
	_relic_choice_banner.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_relic_choice_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_banner.z_index = 1
	_relic_choice_overlay.add_child(_relic_choice_banner)

	_relic_choice_title_effect = RelicChoiceTitleEffect.new()
	_relic_choice_title_effect.name = "TreasureTitleEffect"
	_relic_choice_title_effect.visible = false
	_relic_choice_title_effect.font_size = RELIC_CHOICE_TITLE_FONT_SIZE
	_relic_choice_title_effect.z_index = 1
	_relic_choice_overlay.add_child(_relic_choice_title_effect)

	_relic_choice_title = Label.new()
	_relic_choice_title.name = "TreasureTitle"
	_relic_choice_title.visible = false
	_relic_choice_title.text = ""
	_relic_choice_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_choice_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_relic_choice_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	UiTypography.apply_label_role(_relic_choice_title, UiTypography.ROLE_BANNER)
	UiTypography.set_label_size(_relic_choice_title, RELIC_CHOICE_TITLE_FONT_SIZE)
	_relic_choice_title.add_theme_color_override("font_color", Color("ffe4a5"))
	_relic_choice_title.add_theme_color_override("font_outline_color", Color("26160e"))
	_relic_choice_title.add_theme_constant_override("outline_size", 8)
	_relic_choice_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	_relic_choice_title.add_theme_constant_override("shadow_offset_x", 0)
	_relic_choice_title.add_theme_constant_override("shadow_offset_y", 7)
	_relic_choice_title.z_index = 2
	_relic_choice_overlay.add_child(_relic_choice_title)

	_relic_choice_host = CenterContainer.new()
	_relic_choice_host.name = "RelicChoiceHost"
	_relic_choice_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_overlay.add_child(_relic_choice_host)

	_relic_choice_bar = HBoxContainer.new()
	_relic_choice_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_choice_bar.add_theme_constant_override("separation", 28)
	_relic_choice_host.add_child(_relic_choice_bar)
	_layout_relic_choice_overlay()

func _layout_relic_choice_overlay() -> void:
	if _relic_choice_overlay == null:
		return
	var stage_size: Vector2 = stage_root.size if stage_root != null else get_viewport_rect().size
	var mode: String = str(_run_state.get("mode", "room"))
	var selection_mode: bool = mode in ["reward", "treasure"]
	var title_height: float = (
		clampf(stage_size.y * 0.13, 72.0, SELECTION_TITLE_HEIGHT)
		if selection_mode
		else clampf(stage_size.y * 0.18, 96.0, RELIC_CHOICE_TITLE_HEIGHT)
	)
	var content_height: float = 0.0
	if _relic_choice_bar != null:
		content_height = _relic_choice_bar.get_combined_minimum_size().y
	var host_height: float = content_height if selection_mode else maxf(RELIC_CHOICE_OVERLAY_SIZE.y, content_height)
	var title_top: float = maxf(10.0, stage_size.y * RELIC_CHOICE_TITLE_TOP_RATIO)
	var host_top: float = stage_size.y - host_height - RELIC_CHOICE_BOTTOM_MARGIN
	if selection_mode and _relic_choice_title != null and _relic_choice_title.visible:
		var group_height: float = title_height + SELECTION_TITLE_TO_OFFERS_GAP + host_height
		var available_slack: float = maxf(0.0, stage_size.y - group_height)
		title_top = maxf(18.0, available_slack * SELECTION_GROUP_TOP_BIAS)
		host_top = title_top + title_height + SELECTION_TITLE_TO_OFFERS_GAP
	_relic_choice_overlay.anchor_left = 0.0
	_relic_choice_overlay.anchor_top = 0.0
	_relic_choice_overlay.anchor_right = 1.0
	_relic_choice_overlay.anchor_bottom = 1.0
	_relic_choice_overlay.offset_left = 0.0
	_relic_choice_overlay.offset_top = 0.0
	_relic_choice_overlay.offset_right = 0.0
	_relic_choice_overlay.offset_bottom = 0.0
	if _relic_choice_title != null:
		var title_left: float = 0.0
		var title_width: float = stage_size.x
		if selection_mode and _relic_choice_banner != null:
			var banner_available_width: float = maxf(180.0, stage_size.x - 24.0)
			var banner_width: float = clampf(
				stage_size.x * 0.55,
				minf(SELECTION_BANNER_MIN_WIDTH, banner_available_width),
				minf(SELECTION_BANNER_MAX_WIDTH, banner_available_width)
			)
			title_left = (stage_size.x - banner_width) * 0.5
			title_width = banner_width
			_relic_choice_banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_relic_choice_banner.position = Vector2(title_left, title_top)
			_relic_choice_banner.size = Vector2(banner_width, title_height)
		if _relic_choice_title_effect != null:
			_relic_choice_title_effect.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_relic_choice_title_effect.position = Vector2(title_left, title_top)
			_relic_choice_title_effect.size = Vector2(title_width, title_height)
		_relic_choice_title.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_relic_choice_title.position = Vector2(title_left, title_top)
		_relic_choice_title.size = Vector2(title_width, title_height)
	if _relic_choice_host != null:
		var max_width: float = minf(RELIC_CHOICE_OVERLAY_SIZE.x, maxf(360.0, stage_size.x - 24.0))
		var min_width: float = minf(640.0, max_width)
		var width: float = clampf(stage_size.x * 0.90, min_width, max_width)
		var left: float = (stage_size.x - width) * 0.5
		_relic_choice_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_relic_choice_host.position = Vector2(left, host_top)
		_relic_choice_host.size = Vector2(width, host_height)

func _build_run_end_recap(stage_root: Control) -> void:
	_run_end_recap = RunEndRecapOverlay.new()
	_run_end_recap.name = "RunEndRecapOverlay"
	_run_end_recap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_run_end_recap.anchor_right = 1.0
	_run_end_recap.anchor_bottom = 1.0
	_run_end_recap.z_index = 88
	_run_end_recap.new_run_pressed.connect(_on_restart_pressed)
	_run_end_recap.main_menu_pressed.connect(_on_back_to_menu_pressed)
	stage_root.add_child(_run_end_recap)
	_run_end_recap.set_motion_enabled(not _reduced_motion_enabled())

func _build_card_fx_layer() -> void:
	_card_fx_layer = Control.new()
	_card_fx_layer.name = "CardFxLayer"
	_card_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_fx_layer.anchors_preset = Control.PRESET_FULL_RECT
	_card_fx_layer.anchor_right = 1.0
	_card_fx_layer.anchor_bottom = 1.0
	ui_root.add_child(_card_fx_layer)
	_card_proxy_pool_host = Control.new()
	_card_proxy_pool_host.name = "CardProxyPool"
	_card_proxy_pool_host.visible = false
	_card_proxy_pool_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_proxy_pool_host.set_process(false)
	ui_root.add_child(_card_proxy_pool_host)

func _build_equipment_fx_layer() -> void:
	_equipment_fx_layer = Control.new()
	_equipment_fx_layer.name = "EquipmentFxLayer"
	_equipment_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_fx_layer.anchors_preset = Control.PRESET_FULL_RECT
	_equipment_fx_layer.anchor_right = 1.0
	_equipment_fx_layer.anchor_bottom = 1.0
	_equipment_fx_layer.z_index = 1300
	_equipment_fx_layer.z_as_relative = false
	ui_root.add_child(_equipment_fx_layer)

func _build_fatigue_edge_overlay() -> void:
	_fatigue_edge_overlay = FatigueEdgeOverlay.new()
	_fatigue_edge_overlay.name = "FatigueEdgeOverlay"
	_fatigue_edge_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fatigue_edge_overlay.anchor_right = 1.0
	_fatigue_edge_overlay.anchor_bottom = 1.0
	_fatigue_edge_overlay.z_index = 210
	_fatigue_edge_overlay.z_as_relative = false
	ui_root.add_child(_fatigue_edge_overlay)

func _build_menu_overlay() -> void:
	_menu_scrim = ColorRect.new()
	_menu_scrim.name = "MenuScrim"
	_menu_scrim.visible = false
	_menu_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_scrim.color = Color(0.02, 0.02, 0.02, 0.56)
	_menu_scrim.anchors_preset = Control.PRESET_FULL_RECT
	_menu_scrim.anchor_right = 1.0
	_menu_scrim.anchor_bottom = 1.0
	# Pause and its settings view share one absolute canvas plane above every combat
	# HUD, hand-card fan, and transient gameplay effect.
	_menu_scrim.z_index = MENU_OVERLAY_Z_INDEX
	_menu_scrim.z_as_relative = false
	ui_root.add_child(_menu_scrim)

	_menu_dialog = PanelContainer.new()
	_menu_dialog.name = "MenuDialog"
	_menu_dialog.custom_minimum_size = Vector2(400.0, 0.0)
	_menu_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var dialog_style := _ui_skin.make_plain_card_style(Color(0.11, 0.08, 0.06, 0.96), Color("9d7a50"), 18.0)
	dialog_style.corner_radius_top_left = 14
	dialog_style.corner_radius_top_right = 14
	dialog_style.corner_radius_bottom_right = 14
	dialog_style.corner_radius_bottom_left = 14
	dialog_style.shadow_size = 12
	_menu_dialog.add_theme_stylebox_override("panel", dialog_style)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_menu_scrim.add_child(center)
	center.add_child(_menu_dialog)

	_settings_panel = SettingsPanelScript.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.visible = false
	_settings_panel.connect("back_requested", Callable(self, "_close_settings_overlay"))
	_settings_panel.connect("settings_changed", Callable(self, "_on_settings_changed"))
	center.add_child(_settings_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING))
	margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING))
	margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING))
	margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING))
	_menu_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Camp"
	UiTypography.apply_label_role(title, UiTypography.ROLE_TITLE)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose your next step."
	UiTypography.apply_label_role(subtitle, UiTypography.ROLE_BODY)
	subtitle.add_theme_color_override("font_color", Color("cdbca2"))
	vbox.add_child(subtitle)

	for entry: Dictionary in [
		{"text": "Character", "callback": Callable(self, "_on_character_pressed")},
		{"text": "Settings", "callback": Callable(self, "_open_settings_overlay")},
		{"text": "Exit to Desktop", "callback": Callable(self, "_on_exit_to_desktop_pressed")},
		{"text": "Save and Quit", "callback": Callable(self, "_on_save_and_quit_pressed")},
		{"text": "Succumb to the Darkness", "callback": Callable(self, "_on_abandon_run_pressed")},
		{"text": "Close", "callback": Callable(self, "_close_menu_overlay")}
	]:
		var button := Button.new()
		button.text = str(entry.get("text", ""))
		var variant: String = UiSkin.VARIANT_DESTRUCTIVE if button.text == "Succumb to the Darkness" else UiSkin.VARIANT_STANDARD
		_ui_skin.apply_button_stylebox_overrides(button, variant)
		_ui_skin.apply_button_text_overrides(button)
		UiTypography.apply_button_role(button, UiTypography.ROLE_BODY)
		_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_STANDARD, MENU_DIALOG_BUTTON_MIN_WIDTH, true, variant)
		button.pressed.connect(entry.get("callback", Callable()))
		vbox.add_child(button)
	_ui_skin.apply_outer_panel_frame(_menu_dialog, UiSkin.SURFACE_DIALOG)

func _build_grimoire_overlay() -> void:
	_grimoire_scrim = ColorRect.new()
	_grimoire_scrim.name = "GrimoireScrim"
	_grimoire_scrim.visible = false
	_grimoire_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_grimoire_scrim.color = Color(0.025, 0.018, 0.014, 0.72)
	_grimoire_scrim.anchors_preset = Control.PRESET_FULL_RECT
	_grimoire_scrim.anchor_right = 1.0
	_grimoire_scrim.anchor_bottom = 1.0
	_grimoire_scrim.z_index = 255
	_grimoire_scrim.z_as_relative = false
	_grimoire_scrim.set_meta("cursor_feedback_context_provider", _grimoire_scrim_cursor_feedback_context)
	_grimoire_scrim.gui_input.connect(_on_grimoire_scrim_gui_input)
	ui_root.add_child(_grimoire_scrim)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grimoire_scrim.add_child(center)

	_grimoire_dialog = PanelContainer.new()
	_grimoire_dialog.name = "GrimoireDialog"
	_grimoire_dialog.custom_minimum_size = GRIMOIRE_DIALOG_SIZE
	_grimoire_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_grimoire_dialog.add_theme_stylebox_override("panel", _grimoire_cover_style())
	center.add_child(_grimoire_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING))
	margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING_LARGE))
	_grimoire_dialog.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)

	var title := Label.new()
	title.text = "Grimoire"
	UiTypography.apply_label_role(title, UiTypography.ROLE_TITLE)
	title.add_theme_color_override("font_color", Color("f3ddb0"))
	title.add_theme_color_override("font_outline_color", Color("2b1a10"))
	title.add_theme_constant_override("outline_size", 2)
	title_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Collected field notes"
	UiTypography.apply_label_role(subtitle, UiTypography.ROLE_BODY)
	subtitle.add_theme_color_override("font_color", Color("c9ad7c"))
	title_stack.add_child(subtitle)

	var close_button := UiTooltipButton.new()
	close_button.text = "Close"
	close_button.tooltip_text = "Close Grimoire"
	_ui_skin.apply_button_stylebox_overrides(close_button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(close_button, Color("f7dfad"))
	UiTypography.apply_button_role(close_button, UiTypography.ROLE_BODY)
	close_button.custom_minimum_size = Vector2(104.0, 36.0)
	close_button.pressed.connect(_close_grimoire_overlay)
	header.add_child(close_button)

	var book_row := HBoxContainer.new()
	book_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_row.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	root.add_child(book_row)

	var left_page := PanelContainer.new()
	left_page.name = "GrimoireLeftPage"
	left_page.custom_minimum_size = Vector2(GRIMOIRE_LEFT_PAGE_WIDTH, 0.0)
	left_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_theme_stylebox_override("panel", _grimoire_page_style(false))
	book_row.add_child(left_page)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	left_margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING_COMPACT))
	left_margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	left_margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING_LARGE))
	left_page.add_child(left_margin)

	var left_stack := VBoxContainer.new()
	left_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_stack.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	left_margin.add_child(left_stack)

	_grimoire_entry_scroll = ScrollContainer.new()
	_grimoire_entry_scroll.name = "GrimoireNavScroll"
	_grimoire_entry_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_entry_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grimoire_entry_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_grimoire_entry_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	left_stack.add_child(_grimoire_entry_scroll)

	_grimoire_section_list = VBoxContainer.new()
	_grimoire_section_list.name = "GrimoireNavList"
	_grimoire_section_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_section_list.add_theme_constant_override("separation", UiTypography.SPACE_TIGHT)
	_grimoire_entry_scroll.add_child(_grimoire_section_list)
	_grimoire_entry_list = _grimoire_section_list

	var binding := ColorRect.new()
	binding.custom_minimum_size = Vector2(3.0, 0.0)
	binding.color = Color(0.25, 0.14, 0.07, 0.72)
	binding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_row.add_child(binding)

	_grimoire_detail_panel = PanelContainer.new()
	_grimoire_detail_panel.name = "GrimoireDetailPage"
	_grimoire_detail_panel.custom_minimum_size = Vector2(GRIMOIRE_DETAIL_PAGE_WIDTH, 0.0)
	_grimoire_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_detail_panel.add_theme_stylebox_override("panel", _grimoire_page_style(true))
	book_row.add_child(_grimoire_detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	detail_margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING))
	detail_margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	detail_margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING_LARGE))
	_grimoire_detail_panel.add_child(detail_margin)

	var detail_stack := VBoxContainer.new()
	detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	detail_margin.add_child(detail_stack)

	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	detail_stack.add_child(detail_header)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(86.0, 86.0)
	icon_frame.add_theme_stylebox_override("panel", _grimoire_icon_frame_style())
	detail_header.add_child(icon_frame)

	var icon_margin := MarginContainer.new()
	icon_margin.add_theme_constant_override("margin_left", 3)
	icon_margin.add_theme_constant_override("margin_top", 3)
	icon_margin.add_theme_constant_override("margin_right", 3)
	icon_margin.add_theme_constant_override("margin_bottom", 3)
	icon_frame.add_child(icon_margin)

	_grimoire_detail_icon = TextureRect.new()
	_grimoire_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_grimoire_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_grimoire_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_grimoire_detail_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_child(_grimoire_detail_icon)

	var detail_title_stack := VBoxContainer.new()
	detail_title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_title_stack.add_theme_constant_override("separation", 1)
	detail_header.add_child(detail_title_stack)

	_grimoire_detail_kicker = Label.new()
	UiTypography.apply_label_role(_grimoire_detail_kicker, UiTypography.ROLE_CAPTION)
	_grimoire_detail_kicker.add_theme_color_override("font_color", Color("a97546"))
	detail_title_stack.add_child(_grimoire_detail_kicker)

	_grimoire_detail_title = Label.new()
	_grimoire_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_grimoire_detail_title, UiTypography.ROLE_TITLE)
	_grimoire_detail_title.add_theme_color_override("font_color", Color("3a2416"))
	_grimoire_detail_title.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.64, 0.20))
	_grimoire_detail_title.add_theme_constant_override("outline_size", 1)
	detail_title_stack.add_child(_grimoire_detail_title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color(0.45, 0.27, 0.13, 0.46)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_stack.add_child(rule)

	_grimoire_detail_body = RichTextLabel.new()
	_grimoire_detail_body.bbcode_enabled = false
	_grimoire_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grimoire_detail_body.fit_content = true
	_grimoire_detail_body.scroll_active = true
	_grimoire_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTypography.apply_rich_text_role(_grimoire_detail_body, UiTypography.ROLE_BODY)
	_grimoire_detail_body.add_theme_color_override("default_color", Color("4a3320"))
	detail_stack.add_child(_grimoire_detail_body)

	_grimoire_detail_content = VBoxContainer.new()
	_grimoire_detail_content.name = "GrimoireDetailContent"
	_grimoire_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_detail_content.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	detail_stack.add_child(_grimoire_detail_content)
	_ui_skin.apply_outer_panel_frame(_grimoire_dialog, UiSkin.SURFACE_PARCHMENT)

func _grimoire_cover_style() -> StyleBoxFlat:
	var style := _ui_skin.make_plain_card_style(Color(0.12, 0.065, 0.035, 0.98), Color("7c4a24"), 18.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_size = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	return style

func _grimoire_page_style(right_page: bool) -> StyleBoxFlat:
	var base: Color = Color("d8c08f") if right_page else Color("ccb07c")
	var style := _ui_skin.make_plain_card_style(base, Color(0.54, 0.33, 0.16, 0.74), 14.0)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	return style

func _grimoire_icon_frame_style() -> StyleBoxFlat:
	var style := _ui_skin.make_plain_card_style(Color(0.25, 0.14, 0.075, 0.88), Color("8b5b2e"), 8.0)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.shadow_size = 4
	return style

func _rebuild_grimoire_overlay(scroll_to_selection: bool = false) -> void:
	if _grimoire_section_list == null:
		return
	_layout_grimoire_dialog()
	var preserved_scroll_vertical: int = 0
	if _grimoire_entry_scroll != null:
		preserved_scroll_vertical = _grimoire_entry_scroll.scroll_vertical
	_grimoire_nav_scroll_revision += 1
	var scroll_revision: int = _grimoire_nav_scroll_revision
	_run_state = GrimoireLibrary.ensure_run_state(_run_state)
	var unlocked: Array[String] = GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNLOCKED_KEY, []))
	var unread: Array[String] = GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNREAD_KEY, []))
	var sections: Array = GrimoireLibrary.sections()
	var entries_by_section: Dictionary = _grimoire_entries_by_section(unlocked)
	if _grimoire_selected_section.is_empty() or _grimoire_entries_for_section_map(entries_by_section, _grimoire_selected_section).is_empty():
		_grimoire_selected_section = _first_unlocked_grimoire_section_from(sections, entries_by_section)
	_grimoire_sync_selected_entry(_grimoire_entries_for_section_map(entries_by_section, _grimoire_selected_section))
	_clear_children_now(_grimoire_section_list)
	var selected_index: int = 0
	for section_var: Variant in sections:
		if typeof(section_var) != TYPE_DICTIONARY:
			continue
		var section: Dictionary = section_var as Dictionary
		var section_id: String = str(section.get("id", ""))
		var section_entries: Array[Dictionary] = _grimoire_entries_for_section_map(entries_by_section, section_id)
		if section_entries.is_empty():
			continue
		var section_selected: bool = section_id == _grimoire_selected_section
		var section_button := _grimoire_nav_button(
			"%s  %d" % [str(section.get("title", section_id)), section_entries.size()],
			0,
			section_selected,
			_grimoire_section_has_unread(section_id, unread),
			str(section.get("summary", "")),
			"section"
		)
		section_button.pressed.connect(_on_grimoire_section_pressed.bind(section_id))
		_add_grimoire_nav_button(section_button, 0)
		if section_selected and _grimoire_selected_entry.is_empty():
			selected_index = _grimoire_section_list.get_child_count() - 1
		if not section_selected:
			continue
		var groups: Array[String] = _grimoire_group_ids_for_entries(section_entries)
		if groups.is_empty():
			for entry: Dictionary in section_entries:
				var entry_index: int = _add_grimoire_entry_tab(entry, unread, 1)
				if str(entry.get("id", "")) == _grimoire_selected_entry:
					selected_index = entry_index
			continue
		for group_id: String in groups:
			var group_entries: Array[Dictionary] = _grimoire_entries_for_group(section_entries, group_id)
			var group_selected: bool = group_id == _grimoire_selected_group
			var group_button := _grimoire_nav_button(
				"%s  %d" % [_grimoire_group_title(group_entries, group_id), group_entries.size()],
				1,
				group_selected,
				_grimoire_group_has_unread(group_entries, unread),
				"",
				"group"
			)
			group_button.pressed.connect(_on_grimoire_group_pressed.bind(section_id, group_id))
			_add_grimoire_nav_button(group_button, 1)
			if not group_selected:
				continue
			for entry: Dictionary in group_entries:
				var entry_index: int = _add_grimoire_entry_tab(entry, unread, 2)
				if str(entry.get("id", "")) == _grimoire_selected_entry:
					selected_index = entry_index
	if scroll_to_selection:
		call_deferred("_scroll_grimoire_entry_list_to_index", selected_index, 0, scroll_revision)
	else:
		call_deferred("_restore_grimoire_entry_list_scroll", preserved_scroll_vertical, 0, scroll_revision)
	_refresh_grimoire_detail()
	_refresh_grimoire_badge()

func _grimoire_entries_by_section(unlocked: Array[String]) -> Dictionary:
	var unlocked_lookup: Dictionary = {}
	for entry_id: String in unlocked:
		unlocked_lookup[entry_id] = true
	var result: Dictionary = {}
	for entry_var: Variant in GrimoireLibrary.entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if entry_id.is_empty() or not bool(unlocked_lookup.get(entry_id, false)):
			continue
		var section_id: String = str(entry.get("section", ""))
		if section_id.is_empty():
			continue
		if not result.has(section_id):
			result[section_id] = []
		var section_entries: Array = result.get(section_id, [])
		section_entries.append(entry)
		result[section_id] = section_entries
	return result

func _grimoire_entries_for_section_map(entries_by_section: Dictionary, section_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_var: Variant in entries_by_section.get(section_id, []):
		if typeof(entry_var) == TYPE_DICTIONARY:
			result.append(entry_var as Dictionary)
	return result

func _first_unlocked_grimoire_section_from(sections: Array, entries_by_section: Dictionary) -> String:
	for section_var: Variant in sections:
		if typeof(section_var) != TYPE_DICTIONARY:
			continue
		var section_id: String = str((section_var as Dictionary).get("id", ""))
		if not _grimoire_entries_for_section_map(entries_by_section, section_id).is_empty():
			return section_id
	return ""

func _select_first_unread_grimoire_entry() -> void:
	var unread: Array[String] = GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNREAD_KEY, []))
	if unread.is_empty():
		return
	var entry: Dictionary = GrimoireLibrary.entry_def(unread[0])
	if entry.is_empty():
		return
	_grimoire_selected_section = str(entry.get("section", ""))
	_grimoire_selected_group = _grimoire_entry_group_id(entry)
	_grimoire_selected_entry = unread[0]

func _grimoire_section_has_unread(section_id: String, unread: Array[String]) -> bool:
	for entry_id: String in unread:
		var entry: Dictionary = GrimoireLibrary.entry_def(entry_id)
		if str(entry.get("section", "")) == section_id:
			return true
	return false

func _layout_grimoire_dialog() -> void:
	if _grimoire_dialog == null:
		return
	var dialog_size: Vector2 = UiTypography.modal_size(_grimoire_dialog, GRIMOIRE_DIALOG_SIZE, GRIMOIRE_MIN_DIALOG_SIZE)
	_grimoire_dialog.custom_minimum_size = dialog_size
	_grimoire_dialog.size = dialog_size

func _grimoire_sync_selected_entry(entries_for_section: Array[Dictionary]) -> void:
	if entries_for_section.is_empty():
		_grimoire_selected_entry = ""
		_grimoire_selected_group = ""
		return
	var groups: Array[String] = _grimoire_group_ids_for_entries(entries_for_section)
	var selected_in_section: bool = false
	for entry: Dictionary in entries_for_section:
		if str(entry.get("id", "")) == _grimoire_selected_entry:
			selected_in_section = true
			break
	if not selected_in_section:
		_grimoire_selected_entry = ""
	if groups.is_empty():
		_grimoire_selected_group = ""
		if _grimoire_selected_entry.is_empty():
			_grimoire_selected_entry = str(entries_for_section[0].get("id", ""))
		return
	if _grimoire_selected_group.is_empty() or not groups.has(_grimoire_selected_group):
		_grimoire_selected_group = _grimoire_entry_group_id(GrimoireLibrary.entry_def(_grimoire_selected_entry))
	if _grimoire_selected_group.is_empty() or not groups.has(_grimoire_selected_group):
		_grimoire_selected_group = groups[0]
	var group_entries: Array[Dictionary] = _grimoire_entries_for_group(entries_for_section, _grimoire_selected_group)
	var selected_in_group: bool = false
	for entry: Dictionary in group_entries:
		if str(entry.get("id", "")) == _grimoire_selected_entry:
			selected_in_group = true
			break
	if not selected_in_group and not group_entries.is_empty():
		_grimoire_selected_entry = str(group_entries[0].get("id", ""))

func _add_grimoire_entry_tab(entry: Dictionary, unread: Array[String], depth: int) -> int:
	var entry_id: String = str(entry.get("id", ""))
	var button := _grimoire_nav_button(
		str(entry.get("title", entry_id)),
		depth,
		entry_id == _grimoire_selected_entry,
		unread.has(entry_id),
		str(entry.get("title", entry_id)),
		"entry"
	)
	button.pressed.connect(_on_grimoire_entry_pressed.bind(entry_id))
	_add_grimoire_nav_button(button, depth)
	return _grimoire_section_list.get_child_count() - 1

func _add_grimoire_nav_button(button: Button, depth: int) -> void:
	var wrapper := MarginContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("margin_left", depth * UiTypography.SPACE_LARGE)
	wrapper.add_theme_constant_override("margin_right", 0)
	wrapper.add_child(button)
	_grimoire_section_list.add_child(wrapper)

func _grimoire_nav_button(label: String, depth: int, selected: bool, unread: bool, tooltip: String, kind: String) -> Button:
	var button := UiTooltipButton.new()
	var marker: String = "* " if unread else ""
	button.text = "%s%s" % [marker, label]
	button.toggle_mode = true
	button.button_pressed = selected
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = tooltip if not tooltip.is_empty() else label
	button.custom_minimum_size = Vector2(0.0, 44.0 if depth == 0 else 38.0 if kind == "group" else GRIMOIRE_ENTRY_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _grimoire_tab_style(depth, selected, false, false, kind))
	button.add_theme_stylebox_override("hover", _grimoire_tab_style(depth, selected, true, false, kind))
	button.add_theme_stylebox_override("pressed", _grimoire_tab_style(depth, true, false, true, kind))
	button.add_theme_stylebox_override("focus", _grimoire_tab_style(depth, selected, true, false, kind))
	button.add_theme_stylebox_override("disabled", _grimoire_tab_style(depth, false, false, false, kind))
	var text_color: Color = Color("fff1cf") if selected and depth == 0 else Color("3d2818")
	if selected and kind == "group":
		text_color = Color("fff1cf")
	elif selected and depth > 0:
		text_color = Color("2f1d10")
	elif depth == 2:
		text_color = Color("4c3522")
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color("26170d"))
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	UiTypography.apply_button_role(button, UiTypography.ROLE_BODY if depth <= 1 else UiTypography.ROLE_CAPTION)
	return button

func _grimoire_tab_style(depth: int, selected: bool, hover: bool, pressed: bool, kind: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if depth == 0:
		style.bg_color = Color("5d351d") if selected else Color(0.72, 0.55, 0.32, 0.22)
		style.border_color = Color("d1a35e") if selected or hover else Color(0.39, 0.24, 0.12, 0.42)
	elif kind == "group":
		style.bg_color = Color("8a5628") if selected else Color(0.72, 0.53, 0.29, 0.22)
		style.border_color = Color("d6a057") if selected or hover else Color(0.48, 0.29, 0.13, 0.52)
	else:
		style.bg_color = Color("d7b16d") if selected else Color(0.98, 0.88, 0.66, 0.18)
		style.border_color = Color("8a5628") if selected or hover else Color(0.53, 0.34, 0.16, 0.34)
	if hover and not selected:
		style.bg_color = style.bg_color.lightened(0.16)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.10)
	style.border_width_left = 3 if selected and depth > 0 else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = UiTypography.SPACE_MEDIUM
	style.content_margin_top = UiTypography.SPACE_TIGHT
	style.content_margin_right = UiTypography.SPACE_SMALL
	style.content_margin_bottom = UiTypography.SPACE_TIGHT
	return style

func _restore_grimoire_entry_list_scroll(scroll_position: int, attempt: int = 0, revision: int = 0) -> void:
	if revision != _grimoire_nav_scroll_revision:
		return
	if _grimoire_entry_scroll == null:
		return
	if (_grimoire_entry_scroll.size.y <= 0.0 or (_grimoire_entry_list != null and _grimoire_entry_list.size.y <= 0.0)) and attempt < 4:
		call_deferred("_restore_grimoire_entry_list_scroll", scroll_position, attempt + 1, revision)
		return
	_grimoire_entry_scroll.scroll_vertical = maxi(0, scroll_position)

func _scroll_grimoire_entry_list_to_index(index: int, attempt: int = 0, revision: int = 0) -> void:
	if revision != _grimoire_nav_scroll_revision:
		return
	if _grimoire_entry_scroll == null:
		return
	if _grimoire_entry_list == null or _grimoire_entry_list.get_child_count() <= 0:
		return
	var safe_index: int = clampi(index, 0, _grimoire_entry_list.get_child_count() - 1)
	var child: Control = _grimoire_entry_list.get_child(safe_index) as Control
	if child == null:
		return
	if (child.size.y <= 0.0 or _grimoire_entry_scroll.size.y <= 0.0) and attempt < 4:
		call_deferred("_scroll_grimoire_entry_list_to_index", safe_index, attempt + 1, revision)
		return
	var target: int = maxi(0, int(child.position.y - _grimoire_entry_scroll.size.y * 0.45 + child.size.y * 0.5))
	_grimoire_entry_scroll.scroll_vertical = target
	_grimoire_entry_scroll.ensure_control_visible(child)

func _grimoire_group_ids_for_entries(entries: Array[Dictionary]) -> Array[String]:
	var found: Array[String] = []
	for entry: Dictionary in entries:
		var group_id: String = _grimoire_entry_group_id(entry)
		if group_id.is_empty() or found.has(group_id):
			continue
		found.append(group_id)
	if found.size() <= 1:
		return found
	var ordered: Array[String] = []
	for preferred: String in ["none", "fire", "ice", "lightning", "air", "earth", "weapon", "offhand", "armor", "boots", "trinket"]:
		if found.has(preferred):
			ordered.append(preferred)
	for group_id: String in found:
		if not ordered.has(group_id):
			ordered.append(group_id)
	return ordered

func _grimoire_entry_group_id(entry: Dictionary) -> String:
	return str(entry.get("group", ""))

func _grimoire_entries_for_group(entries: Array[Dictionary], group_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if _grimoire_entry_group_id(entry) == group_id:
			result.append(entry)
	return result

func _grimoire_group_title(entries: Array[Dictionary], group_id: String) -> String:
	for entry: Dictionary in entries:
		var title: String = str(entry.get("group_title", ""))
		if not title.is_empty():
			return title
	return group_id.capitalize()

func _grimoire_group_has_unread(entries: Array[Dictionary], unread: Array[String]) -> bool:
	for entry: Dictionary in entries:
		if unread.has(str(entry.get("id", ""))):
			return true
	return false

func _refresh_grimoire_detail() -> void:
	if _grimoire_detail_title == null or _grimoire_detail_body == null:
		return
	if _grimoire_detail_content != null:
		_clear_children_now(_grimoire_detail_content)
	var entry: Dictionary = GrimoireLibrary.entry_def(_grimoire_selected_entry)
	if entry.is_empty():
		_grimoire_detail_kicker.text = ""
		_grimoire_detail_title.text = "No entries"
		_grimoire_detail_body.text = ""
		_grimoire_detail_body.visible = true
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_grimoire_detail_icon.texture = _header_icon_texture("book")
		return
	var section: Dictionary = GrimoireLibrary.section_def(str(entry.get("section", "")))
	_grimoire_detail_kicker.text = str(section.get("title", ""))
	_grimoire_detail_title.text = str(entry.get("title", _grimoire_selected_entry))
	_grimoire_detail_icon.texture = _grimoire_entry_icon(entry)
	var body_text: String = _grimoire_body_text(entry)
	var card_id: String = str(entry.get("card_id", ""))
	var equipment_id: String = str(entry.get("equipment_id", ""))
	if not card_id.is_empty():
		_grimoire_detail_body.text = ""
		_grimoire_detail_body.visible = false
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_populate_grimoire_card_detail(card_id)
	elif not equipment_id.is_empty():
		_grimoire_detail_body.text = body_text
		_grimoire_detail_body.visible = not body_text.is_empty()
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_populate_grimoire_equipment_detail(equipment_id)
	else:
		_grimoire_detail_body.text = body_text
		_grimoire_detail_body.visible = true
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _populate_grimoire_card_detail(card_id: String) -> void:
	if _grimoire_detail_content == null:
		return
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_build_card_preview_widget(card_id, GRIMOIRE_CARD_PREVIEW_SIZE, true))
	_grimoire_detail_content.add_child(center)

func _populate_grimoire_equipment_detail(equipment_id: String) -> void:
	if _grimoire_detail_content == null:
		return
	var card_ids: Array = GameData.equipment_cards(equipment_id)
	if card_ids.is_empty():
		return
	var label := Label.new()
	label.text = "Granted Cards"
	UiTypography.set_label_size(label, UiTypography.SIZE_SMALL)
	label.add_theme_color_override("font_color", Color("6a3e1f"))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.64, 0.18))
	label.add_theme_constant_override("outline_size", 1)
	_grimoire_detail_content.add_child(label)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 10)
	_grimoire_detail_content.add_child(row)
	for card_id_var: Variant in card_ids:
		row.add_child(_build_card_preview_widget(str(card_id_var), GRIMOIRE_EQUIPMENT_CARD_SIZE, true))

func _grimoire_body_text(entry: Dictionary) -> String:
	var paragraphs: Array[String] = []
	for paragraph_var: Variant in entry.get("body", []):
		var paragraph: String = str(paragraph_var).strip_edges()
		if not paragraph.is_empty():
			paragraphs.append(paragraph)
	return "\n\n".join(paragraphs)

func _grimoire_entry_icon(entry: Dictionary) -> Texture2D:
	var card_id: String = str(entry.get("card_id", ""))
	if not card_id.is_empty():
		var card: Dictionary = GameData.card_def(card_id)
		var card_art_path: String = str(card.get("art_path", ""))
		var card_texture: Texture2D = AssetLoader.load_texture(card_art_path)
		if card_texture != null:
			return card_texture
	var equipment_id: String = str(entry.get("equipment_id", ""))
	if not equipment_id.is_empty():
		var equipment: Dictionary = GameData.equipment_def(equipment_id)
		var equipment_texture: Texture2D = AssetLoader.load_texture(str(equipment.get("icon_path", "")))
		if equipment_texture != null:
			return equipment_texture
	var npc_id: String = str(entry.get("npc_id", ""))
	if not npc_id.is_empty():
		var npc: Dictionary = GameData.npc_def(npc_id)
		var npc_texture: Texture2D = AssetLoader.load_texture(str(npc.get("art_path", "")))
		if npc_texture != null:
			return npc_texture
	var enemy_id: String = str(entry.get("enemy_id", ""))
	if not enemy_id.is_empty():
		var enemy: Dictionary = GameData.enemy_def(enemy_id)
		var enemy_art_path: String = str(enemy.get("art_path", ""))
		var enemy_texture: Texture2D = AssetLoader.load_texture(enemy_art_path)
		if enemy_texture != null:
			return enemy_texture
	var icon_key: String = str(entry.get("icon", ""))
	if not icon_key.is_empty():
		var action_icon: Texture2D = ActionIcons.icon_texture(icon_key)
		if action_icon != null:
			return action_icon
	return _header_icon_texture("book")

func _refresh_grimoire_badge() -> void:
	if _grimoire_badge == null:
		return
	var unread: Array[String] = GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNREAD_KEY, []))
	_grimoire_badge.visible = not unread.is_empty()
	if _grimoire_badge_label != null:
		_grimoire_badge_label.text = str(mini(9, unread.size()))

func _refresh_loadout_badge() -> void:
	if _loadout_badge == null:
		return
	var unread_count: int = _run_engine.loadout_unread_count(_run_state)
	_loadout_badge.visible = unread_count > 0
	if _loadout_badge_label != null:
		_loadout_badge_label.text = str(mini(9, unread_count))

func _first_unlocked_grimoire_section(unlocked: Array[String]) -> String:
	for section_var: Variant in GrimoireLibrary.sections():
		if typeof(section_var) != TYPE_DICTIONARY:
			continue
		var section_id: String = str((section_var as Dictionary).get("id", ""))
		if GrimoireLibrary.section_has_unlocked_entries(section_id, unlocked):
			return section_id
	return ""

func _on_grimoire_section_pressed(section_id: String) -> void:
	_grimoire_selected_section = section_id
	_grimoire_selected_group = ""
	_grimoire_selected_entry = ""
	_rebuild_grimoire_overlay()

func _on_grimoire_group_pressed(section_id: String, group_id: String) -> void:
	_grimoire_selected_section = section_id
	_grimoire_selected_group = group_id
	_grimoire_selected_entry = ""
	_rebuild_grimoire_overlay()

func _on_grimoire_entry_pressed(entry_id: String) -> void:
	var entry: Dictionary = GrimoireLibrary.entry_def(entry_id)
	if not entry.is_empty():
		_grimoire_selected_section = str(entry.get("section", _grimoire_selected_section))
	_grimoire_selected_entry = entry_id
	_grimoire_selected_group = _grimoire_entry_group_id(entry)
	_rebuild_grimoire_overlay()

func _on_grimoire_scrim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event: InputEventMouseButton = event
		if _grimoire_dialog != null and _grimoire_dialog.get_global_rect().has_point(mouse_event.global_position):
			return
		_close_grimoire_overlay()
		accept_event()

func _grimoire_scrim_cursor_feedback_context(local_position: Vector2) -> String:
	if _grimoire_scrim == null or not _grimoire_scrim.visible:
		return "inert"
	var global_position: Vector2 = _grimoire_scrim.get_global_transform_with_canvas() * local_position
	if _grimoire_dialog != null and _grimoire_dialog.get_global_rect().has_point(global_position):
		return "inert"
	return "action"

func _build_dialogue_overlay() -> void:
	_dialogue_overlay = Control.new()
	_dialogue_overlay.name = "DialogueOverlay"
	_dialogue_overlay.visible = false
	_dialogue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_overlay.z_index = 260
	_dialogue_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_dialogue_overlay.anchor_right = 1.0
	_dialogue_overlay.anchor_bottom = 1.0
	_dialogue_overlay.set_meta("cursor_feedback_context_provider", _dialogue_cursor_feedback_context)
	_dialogue_overlay.gui_input.connect(_on_dialogue_overlay_gui_input)
	ui_root.add_child(_dialogue_overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.01, 0.01, 0.18)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.anchors_preset = Control.PRESET_FULL_RECT
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	_dialogue_overlay.add_child(scrim)

	var anchor := MarginContainer.new()
	anchor.anchors_preset = Control.PRESET_FULL_RECT
	anchor.anchor_right = 1.0
	anchor.anchor_bottom = 1.0
	anchor.add_theme_constant_override("margin_left", 18)
	anchor.add_theme_constant_override("margin_top", 18)
	anchor.add_theme_constant_override("margin_right", 18)
	anchor.add_theme_constant_override("margin_bottom", 18)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_overlay.add_child(anchor)

	var bottom := VBoxContainer.new()
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(bottom)

	_dialogue_dialog = PanelContainer.new()
	_dialogue_dialog.custom_minimum_size = Vector2(DIALOGUE_DIALOG_WIDTH, DIALOGUE_DIALOG_HINT_MIN_HEIGHT)
	_dialogue_dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dialogue_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dialogue_style := _ui_skin.make_plain_card_style(Color(0.10, 0.07, 0.05, 0.96), Color("b8aa90"), 18.0)
	dialogue_style.corner_radius_top_left = 14
	dialogue_style.corner_radius_top_right = 14
	dialogue_style.corner_radius_bottom_right = 14
	dialogue_style.corner_radius_bottom_left = 14
	dialogue_style.shadow_size = 10
	_dialogue_dialog.add_theme_stylebox_override("panel", dialogue_style)
	bottom.add_child(_dialogue_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	_dialogue_name_label = Label.new()
	UiTypography.set_label_size(_dialogue_name_label, UiTypography.SIZE_BODY)
	_dialogue_name_label.add_theme_color_override("font_color", Color("f0c978"))
	_dialogue_name_label.add_theme_color_override("font_outline_color", Color("2d1f18"))
	_dialogue_name_label.add_theme_constant_override("outline_size", 1)
	_dialogue_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_name_label)

	_dialogue_text_label = RichTextLabel.new()
	_dialogue_text_label.bbcode_enabled = true
	_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text_label.visible_characters = 0
	_dialogue_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_text_label.size_flags_vertical = Control.SIZE_FILL
	_dialogue_text_label.custom_minimum_size = Vector2(0.0, DIALOGUE_TEXT_HINT_MIN_HEIGHT)
	_dialogue_text_label.fit_content = true
	_dialogue_text_label.scroll_active = false
	UiTypography.set_rich_text_size(_dialogue_text_label, UiTypography.SIZE_SECTION)
	_dialogue_text_label.add_theme_color_override("default_color", Color("f5ebd8"))
	_dialogue_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_text_label)

	_dialogue_footer = HBoxContainer.new()
	_dialogue_footer.custom_minimum_size = Vector2(0.0, DIALOGUE_HINT_FOOTER_HEIGHT)
	_dialogue_footer.add_theme_constant_override("separation", 12)
	_dialogue_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_footer)

	_dialogue_hint_label = Label.new()
	_dialogue_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_dialogue_hint_label, UiTypography.SIZE_BODY)
	_dialogue_hint_label.add_theme_color_override("font_color", Color("cab697"))
	_dialogue_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_footer.add_child(_dialogue_hint_label)

	_dialogue_choice_bar = HBoxContainer.new()
	_dialogue_choice_bar.custom_minimum_size = Vector2.ZERO
	_dialogue_choice_bar.alignment = BoxContainer.ALIGNMENT_END
	_dialogue_choice_bar.add_theme_constant_override("separation", 10)
	_dialogue_choice_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_choice_bar.visible = false
	_dialogue_footer.add_child(_dialogue_choice_bar)

func _build_pile_overlay() -> void:
	_pile_scrim = ColorRect.new()
	_pile_scrim.name = "PileScrim"
	_pile_scrim.visible = false
	_pile_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pile_scrim.z_index = 1000
	_pile_scrim.z_as_relative = false
	_pile_scrim.color = Color(0.02, 0.02, 0.02, 0.58)
	_pile_scrim.anchors_preset = Control.PRESET_FULL_RECT
	_pile_scrim.anchor_right = 1.0
	_pile_scrim.anchor_bottom = 1.0
	ui_root.add_child(_pile_scrim)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_pile_scrim.add_child(center)

	_pile_dialog = PanelContainer.new()
	_pile_dialog.custom_minimum_size = PILE_DIALOG_FULL_SIZE
	var dialog_style := _ui_skin.make_plain_card_style(Color(0.11, 0.08, 0.06, 0.98), Color("9d7a50"), 16.0)
	dialog_style.corner_radius_top_left = 14
	dialog_style.corner_radius_top_right = 14
	dialog_style.corner_radius_bottom_right = 14
	dialog_style.corner_radius_bottom_left = 14
	dialog_style.shadow_size = 12
	_pile_dialog.add_theme_stylebox_override("panel", dialog_style)
	center.add_child(_pile_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_pile_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	_pile_dialog_title = Label.new()
	_pile_dialog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(_pile_dialog_title, UiTypography.SIZE_SECTION)
	_pile_dialog_title.add_theme_color_override("font_color", Color("f0e6d2"))
	_pile_dialog_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	_pile_dialog_title.add_theme_constant_override("outline_size", 2)
	top_row.add_child(_pile_dialog_title)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	_ui_skin.apply_button_stylebox_overrides(close_button, UiSkin.VARIANT_ICON)
	_ui_skin.apply_button_text_overrides(close_button)
	UiTypography.set_button_size(close_button, UiTypography.SIZE_SMALL)
	close_button.custom_minimum_size = Vector2(40.0, 40.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close_pile_view)
	top_row.add_child(close_button)

	_pile_dialog_scroll = ScrollContainer.new()
	_pile_dialog_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_pile_dialog_scroll)

	_pile_dialog_cards = HFlowContainer.new()
	_pile_dialog_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_dialog_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_dialog_cards.alignment = FlowContainer.ALIGNMENT_CENTER
	_pile_dialog_cards.add_theme_constant_override("h_separation", 12)
	_pile_dialog_cards.add_theme_constant_override("v_separation", 12)
	_pile_dialog_scroll.add_child(_pile_dialog_cards)

	_pile_dialog_empty = Label.new()
	_pile_dialog_empty.text = "No cards in this pile."
	_pile_dialog_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pile_dialog_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pile_dialog_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_dialog_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_dialog_empty.custom_minimum_size = Vector2(0.0, 96.0)
	UiTypography.set_label_size(_pile_dialog_empty, UiTypography.SIZE_BODY)
	_pile_dialog_empty.add_theme_color_override("font_color", Color("d2c2a7"))
	_pile_dialog_empty.add_theme_color_override("font_outline_color", Color("2c1f16"))
	_pile_dialog_empty.add_theme_constant_override("outline_size", 1)
	_pile_dialog_empty.visible = false
	vbox.add_child(_pile_dialog_empty)

func _build_card_upgrade_overlay() -> void:
	_upgrade_scrim = ColorRect.new()
	_upgrade_scrim.name = "CardUpgradeScrim"
	_upgrade_scrim.visible = false
	_upgrade_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_scrim.z_index = 1200
	_upgrade_scrim.z_as_relative = false
	_upgrade_scrim.color = Color(0.02, 0.02, 0.02, 0.64)
	_upgrade_scrim.anchors_preset = Control.PRESET_FULL_RECT
	_upgrade_scrim.anchor_right = 1.0
	_upgrade_scrim.anchor_bottom = 1.0
	# Character progression must be viewport-bound. The gameplay UI root can grow
	# beyond the visible rect while room content is being rebuilt (notably when a
	# level-up leaves a campfire), which used to drag this modal offscreen.
	ui_root.get_parent().add_child(_upgrade_scrim)

	_upgrade_center = CenterContainer.new()
	_upgrade_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_scrim.add_child(_upgrade_center)

	_upgrade_dialog = PanelContainer.new()
	_upgrade_dialog.custom_minimum_size = Vector2(1120.0, 620.0)
	var dialog_style := _ui_skin.make_plain_card_style(Color(0.10, 0.07, 0.05, 0.98), Color("c28a53"), 16.0)
	dialog_style.corner_radius_top_left = 14
	dialog_style.corner_radius_top_right = 14
	dialog_style.corner_radius_bottom_right = 14
	dialog_style.corner_radius_bottom_left = 14
	dialog_style.shadow_size = 12
	_upgrade_dialog.add_theme_stylebox_override("panel", dialog_style)
	_upgrade_center.add_child(_upgrade_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_upgrade_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	var title := Label.new()
	title.text = "Bound Magicks"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SECTION)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	top_row.add_child(title)

	_upgrade_embers_label = Label.new()
	UiTypography.set_label_size(_upgrade_embers_label, UiTypography.SIZE_SMALL)
	_upgrade_embers_label.add_theme_color_override("font_color", Color("f0c978"))
	_upgrade_embers_label.add_theme_color_override("font_outline_color", Color("2c1f16"))
	_upgrade_embers_label.add_theme_constant_override("outline_size", 1)
	top_row.add_child(_upgrade_embers_label)

	var close_button := Button.new()
	close_button.name = "CloseCharacterOverlay"
	close_button.text = "X"
	_ui_skin.apply_button_stylebox_overrides(close_button, UiSkin.VARIANT_ICON)
	_ui_skin.apply_button_text_overrides(close_button)
	UiTypography.set_button_size(close_button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(close_button, 36.0, 0.0, true, UiSkin.VARIANT_ICON)
	close_button.pressed.connect(_on_progression_overlay_close_pressed)
	top_row.add_child(close_button)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	vbox.add_child(body)

	_upgrade_card_list = _build_upgrade_column(body, "Cards", 220.0)
	_upgrade_element_list = _build_upgrade_column(body, "Parts", 220.0)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	body.add_child(right_column)

	var preview_title := Label.new()
	preview_title.text = "Preview"
	UiTypography.set_label_size(preview_title, UiTypography.SIZE_SMALL)
	preview_title.add_theme_color_override("font_color", Color("f0e6d2"))
	preview_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	preview_title.add_theme_constant_override("outline_size", 1)
	right_column.add_child(preview_title)

	_upgrade_preview_box = HBoxContainer.new()
	_upgrade_preview_box.custom_minimum_size = Vector2(0.0, 286.0)
	_upgrade_preview_box.add_theme_constant_override("separation", 12)
	right_column.add_child(_upgrade_preview_box)

	var option_title := Label.new()
	option_title.text = "Options"
	UiTypography.set_label_size(option_title, UiTypography.SIZE_SMALL)
	option_title.add_theme_color_override("font_color", Color("f0e6d2"))
	option_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	option_title.add_theme_constant_override("outline_size", 1)
	right_column.add_child(option_title)

	var option_scroll := ScrollContainer.new()
	option_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_column.add_child(option_scroll)

	_upgrade_option_list = VBoxContainer.new()
	_upgrade_option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_option_list.add_theme_constant_override("separation", 10)
	option_scroll.add_child(_upgrade_option_list)

func _build_upgrade_column(parent: Node, title_text: String, width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(width, 0.0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)

	var title := Label.new()
	title.text = title_text
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 1)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list

func _build_drag_overlay() -> void:
	_drag_overlay = Control.new()
	_drag_overlay.name = "DragOverlay"
	_drag_overlay.visible = false
	_drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_drag_overlay.anchor_right = 1.0
	_drag_overlay.anchor_bottom = 1.0
	ui_root.add_child(_drag_overlay)
	_drag_zone_panels.clear()
	_drag_zone_labels.clear()
	_drag_zone_detail_labels.clear()

func _build_drag_command_zone(zone: String, title_text: String, detail_text: String, accent: Color, fill: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Drag%sCommand" % zone.capitalize()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = ACTION_CONTEXT_COMMAND_SIZE
	panel.set_meta("accent", accent)
	panel.set_meta("fill", fill)
	panel.set_meta("detail_text", detail_text)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = title_text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, UiTypography.SIZE_SMALL)
	label.add_theme_color_override("font_color", Color("f4ead5"))
	label.add_theme_color_override("font_outline_color", Color("241912"))
	label.add_theme_constant_override("outline_size", 2)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 0)
	center.add_child(vbox)
	vbox.add_child(label)
	var detail_label := Label.new()
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.text = detail_text.to_upper()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(detail_label, UiTypography.SIZE_SMALL)
	detail_label.add_theme_color_override("font_color", accent.lightened(0.28))
	detail_label.add_theme_color_override("font_outline_color", Color("241912"))
	detail_label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(detail_label)
	panel.set_meta("label", label)
	panel.set_meta("detail_label", detail_label)
	panel.add_theme_stylebox_override("panel", _drag_zone_style(fill, accent, false, true))
	_drag_zone_panels[zone] = panel
	_drag_zone_labels[zone] = label
	_drag_zone_detail_labels[zone] = detail_label
	return panel

func _on_dialogue_overlay_gui_input(event: InputEvent) -> void:
	if not _dialogue_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _has_current_dialogue_options() and _dialogue_choice_bar != null and _dialogue_choice_bar.get_global_rect().has_point(get_global_mouse_position()):
			return
		accept_event()
		_advance_dialogue()

func _dialogue_cursor_feedback_context(local_position: Vector2) -> String:
	if not _dialogue_active or _dialogue_overlay == null:
		return "inert"
	var global_position: Vector2 = _dialogue_overlay.get_global_transform_with_canvas() * local_position
	if _has_current_dialogue_options() and _dialogue_choice_bar != null and _dialogue_choice_bar.get_global_rect().has_point(global_position):
		return "inert"
	return "action"

func _start_dialogue(dialogue: Dictionary) -> void:
	if dialogue.is_empty():
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_menu_overlay()
	_close_card_upgrade_overlay()
	_dialogue_script = dialogue.duplicate(true)
	_dialogue_active = true
	_dialogue_suppresses_choices = not _current_room_merchant_kind().is_empty()
	_dialogue_overlay.visible = true
	if _dialogue_suppresses_choices:
		_refresh_choice_bar()
	_show_dialogue_line(0)

func _show_dialogue_line(index: int) -> void:
	var lines: Array = _dialogue_script.get("lines", [])
	if index < 0 or index >= lines.size():
		_close_dialogue()
		return
	_dialogue_line_index = index
	_dialogue_char_progress = 0.0
	_dialogue_text_complete = false
	var line: Dictionary = lines[index]
	var speaker: String = str(line.get("speaker", _dialogue_script.get("speaker", "")))
	var accent_text: String = str(line.get("accent", _dialogue_script.get("accent", "#b8aa90")))
	_apply_dialogue_accent(accent_text)
	_dialogue_name_label.text = speaker
	_dialogue_text_label.text = _dialogue_line_markup(line)
	_sync_dialogue_layout()
	var visible_text_length: int = _dialogue_visible_text().length()
	if visible_text_length > 0:
		_dialogue_char_progress = 1.0
		_dialogue_text_label.visible_characters = 1
	else:
		_dialogue_text_label.visible_characters = 0
	_update_dialogue_footer()
	if _dialogue_visible_text().is_empty():
		_complete_current_dialogue_line()
	elif SettingsStore.dialogue_is_instant(_settings):
		_complete_current_dialogue_line()
	else:
		set_process(true)

func _complete_current_dialogue_line() -> void:
	if not _dialogue_active:
		return
	_dialogue_text_complete = true
	_dialogue_char_progress = float(_dialogue_visible_text().length())
	_dialogue_text_label.visible_characters = -1
	set_process(false)
	_update_dialogue_footer()

func _advance_dialogue() -> void:
	if not _dialogue_active:
		return
	if not _dialogue_text_complete:
		_complete_current_dialogue_line()
		return
	if _has_current_dialogue_options():
		return
	var lines: Array = _dialogue_script.get("lines", [])
	var next_index: int = _dialogue_line_index + 1
	if next_index >= lines.size():
		_close_dialogue()
		return
	_show_dialogue_line(next_index)

func _on_dialogue_option_pressed(option: Dictionary) -> void:
	if not _dialogue_active or not _dialogue_text_complete:
		return
	var action: String = str(option.get("action", ""))
	if action == "open_card_upgrades":
		_close_dialogue()
		_open_card_upgrade_overlay()
		return
	if action == "close":
		_close_dialogue()
		return
	var next_index: int = int(option.get("next", -1))
	if next_index >= 0:
		_show_dialogue_line(next_index)
		return
	_close_dialogue()

func _close_dialogue() -> void:
	var should_restore_choices := _dialogue_active and _dialogue_suppresses_choices
	_maybe_mark_fire_rest_dialogue_seen()
	_maybe_mark_umbra_warning_seen()
	_dialogue_active = false
	_dialogue_suppresses_choices = false
	_dialogue_script.clear()
	_dialogue_line_index = -1
	_dialogue_char_progress = 0.0
	_dialogue_text_complete = false
	set_process(false)
	_clear_dialogue_choices()
	if _dialogue_hint_label != null:
		_dialogue_hint_label.text = ""
	if _dialogue_overlay != null:
		_dialogue_overlay.visible = false
	if should_restore_choices and is_inside_tree() and not _run_state.is_empty():
		_refresh_choice_bar()

func _maybe_mark_fire_rest_dialogue_seen() -> void:
	if _dialogue_script.is_empty() or not bool(_dialogue_script.get("marks_fire_rest_seen", false)):
		return
	_progression = ProgressionStore.mark_fire_rest_dialogue_seen(_progression)
	ProgressionStore.save_data(_progression)
	if not _run_state.is_empty():
		_run_state["progression"] = _progression.duplicate(true)
		_persist_committed_boundary("fire_dialogue_seen")

func _maybe_mark_umbra_warning_seen() -> void:
	if _dialogue_script.is_empty() or not bool(_dialogue_script.get("marks_umbra_warning_seen", false)):
		return
	_progression = ProgressionStore.mark_umbra_warning_seen(_progression)
	ProgressionStore.save_data(_progression)
	if not _run_state.is_empty():
		_run_state["progression"] = _progression.duplicate(true)
		_persist_committed_boundary("umbra_warning_seen")

func _current_dialogue_line() -> Dictionary:
	if not _dialogue_active or _dialogue_line_index < 0:
		return {}
	var lines: Array = _dialogue_script.get("lines", [])
	if _dialogue_line_index >= lines.size():
		return {}
	return lines[_dialogue_line_index]

func _dialogue_line_markup(line: Dictionary) -> String:
	return str(line.get("bbcode", line.get("text", "")))

func _dialogue_visible_text() -> String:
	if _dialogue_text_label == null:
		return ""
	return _dialogue_text_label.get_parsed_text()

func _has_current_dialogue_options() -> bool:
	return (_current_dialogue_line().get("options", []) as Array).size() > 0 and _dialogue_text_complete

func _sync_dialogue_layout() -> void:
	if _dialogue_dialog == null or _dialogue_text_label == null or _dialogue_footer == null:
		return
	var options: Array = _current_dialogue_line().get("options", [])
	var has_options: bool = not options.is_empty()
	var dialog_height: float = DIALOGUE_DIALOG_OPTION_MIN_HEIGHT if has_options else DIALOGUE_DIALOG_HINT_MIN_HEIGHT
	var text_height: float = DIALOGUE_TEXT_OPTION_MIN_HEIGHT if has_options else DIALOGUE_TEXT_HINT_MIN_HEIGHT
	var footer_height: float = DIALOGUE_OPTION_BUTTON_HEIGHT if has_options else DIALOGUE_HINT_FOOTER_HEIGHT
	_dialogue_dialog.custom_minimum_size = Vector2(DIALOGUE_DIALOG_WIDTH, dialog_height)
	_dialogue_text_label.custom_minimum_size = Vector2(0.0, text_height)
	_dialogue_footer.custom_minimum_size = Vector2(0.0, footer_height)
	if _dialogue_choice_bar != null:
		_dialogue_choice_bar.custom_minimum_size = Vector2(0.0, DIALOGUE_OPTION_BUTTON_HEIGHT if has_options else 0.0)
		_dialogue_choice_bar.visible = has_options

func _update_dialogue_footer() -> void:
	_clear_dialogue_choices()
	if _dialogue_hint_label == null:
		return
	_dialogue_hint_label.text = ""
	if not _dialogue_active:
		return
	if not _dialogue_text_complete:
		_dialogue_hint_label.text = "Click to reveal"
		return
	var options: Array = _current_dialogue_line().get("options", [])
	if options.is_empty():
		_dialogue_hint_label.text = _dialogue_hint_text()
		return
	for option_var: Variant in options:
		if typeof(option_var) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = (option_var as Dictionary).duplicate(true)
		var button := Button.new()
		button.text = str(option.get("label", "Continue"))
		_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_STANDARD)
		_ui_skin.apply_button_text_overrides(button)
		UiTypography.set_button_size(button, UiTypography.SIZE_BODY_LARGE)
		_ui_skin.apply_button_native_size(button, DIALOGUE_OPTION_BUTTON_HEIGHT, DIALOGUE_OPTION_BUTTON_MIN_WIDTH)
		button.pressed.connect(_on_dialogue_option_pressed.bind(option))
		_dialogue_choice_bar.add_child(button)

func _dialogue_hint_text() -> String:
	var lines: Array = _dialogue_script.get("lines", [])
	if _dialogue_line_index >= 0 and _dialogue_line_index < lines.size() - 1:
		return "Click to continue"
	return "Click to leave"

func _clear_dialogue_choices() -> void:
	if _dialogue_choice_bar == null:
		return
	_clear_children(_dialogue_choice_bar)

func _apply_dialogue_accent(accent_text: String) -> void:
	var accent: Color = Color(accent_text)
	if _dialogue_name_label != null:
		_dialogue_name_label.add_theme_color_override("font_color", accent.lightened(0.08))
	if _dialogue_dialog == null:
		return
	var dialogue_style := _ui_skin.make_plain_card_style(Color(0.10, 0.07, 0.05, 0.96), accent, 18.0)
	dialogue_style.corner_radius_top_left = 14
	dialogue_style.corner_radius_top_right = 14
	dialogue_style.corner_radius_bottom_right = 14
	dialogue_style.corner_radius_bottom_left = 14
	dialogue_style.shadow_size = 10
	_dialogue_dialog.add_theme_stylebox_override("panel", dialogue_style)

func _show_drag_overlay() -> void:
	if _drag_overlay == null:
		return
	_close_pile_view()
	_drag_overlay.visible = true
	_drag_overlay.move_to_front()
	_refresh_choice_bar()
	_refresh_stage_view()
	_refresh_contextual_combat_tutorial()

func _cancel_drag_play() -> void:
	if _drag_card_index >= 0 and _drag_card_index < hand_box.get_child_count():
		var source_slot: Control = hand_box.get_child(_drag_card_index) as Control
		if source_slot != null:
			source_slot.visible = true
	if _drag_overlay != null:
		_drag_overlay.visible = false
	if _drag_card_proxy != null:
		_release_card_proxy(_drag_card_proxy)
		_drag_card_proxy = null
	_drag_card_index = -1
	_drag_card_options.clear()
	_drag_hover_zone = ""
	_drag_card_source_rect = Rect2()
	_drag_card_grab_offset = Vector2.ZERO
	_drag_card_base_scale = Vector2.ONE
	_update_drag_overlay_hover("")
	_refresh_hand_panel()
	_refresh_choice_bar()
	_refresh_stage_view()
	_refresh_contextual_combat_tutorial()

func _animate_drag_cancel_to_source() -> void:
	if _drag_card_proxy != null and _drag_card_source_rect.size.length() > 0.0:
		await _animate_card_proxy_to_rect(_drag_card_proxy, _drag_card_source_rect, CARD_SNAPBACK_SECONDS)
	_cancel_drag_play()

func _commit_drag_drop(zone: String) -> void:
	if _drag_card_index < 0:
		return
	if not _drag_option_valid(zone):
		await _animate_drag_cancel_to_source()
		return
	var hand_index: int = _drag_card_index
	var options: Dictionary = _drag_card_options.duplicate(true)
	var preview: Dictionary = {}
	var label_override: String = ""
	match zone:
		"play":
			preview = options.get("play", {})
		"attack":
			preview = options.get("attack", {})
			label_override = _fallback_label("attack")
		"move":
			preview = options.get("move", {})
			label_override = _fallback_label("move")
		_:
			await _animate_drag_cancel_to_source()
			return
	if not bool(preview.get("playable", false)):
		await _animate_drag_cancel_to_source()
		return
	if _drag_card_proxy != null:
		var destination_rect: Rect2 = _stage_card_rect(_drag_card_source_rect.size)
		if zone in ["attack", "move"]:
			var command_panel: PanelContainer = _drag_zone_panels.get(zone, null) as PanelContainer
			if command_panel != null:
				destination_rect = _rect_from_center(command_panel.get_global_rect().get_center(), _drag_card_source_rect.size)
		await _animate_card_proxy_to_rect(_drag_card_proxy, destination_rect, 0.10)
	_cancel_drag_play()
	await _begin_card_preview(hand_index, preview, label_override, true)

func _drag_zone_at(mouse_position: Vector2) -> String:
	for zone: String in ["attack", "move"]:
		var panel: PanelContainer = _drag_zone_panels.get(zone, null)
		if panel == null or not panel.visible:
			continue
		if panel.get_global_rect().has_point(mouse_position):
			return zone
	if bool(_drag_card_options.get("printed_playable", false)) and board_view != null and board_view.get_global_rect().has_point(mouse_position):
		return "play"
	return ""

func _current_mouse_position() -> Vector2:
	return get_viewport().get_mouse_position()

func _mouse_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		return mouse_button.position
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event
		return mouse_motion.position
	return _current_mouse_position()

func _update_drag_proxy_position(mouse_position: Vector2) -> void:
	if _drag_card_proxy == null:
		return
	var visual_rect := Rect2(mouse_position - _drag_card_grab_offset, _drag_card_source_rect.size)
	_drag_card_proxy.position = _card_proxy_position_for_rect(visual_rect)
	if _reduced_motion_enabled():
		_drag_card_proxy.rotation = 0.0
		_drag_card_proxy.scale = _drag_card_base_scale
		return
	var viewport_width: float = maxf(1.0, get_viewport_rect().size.x)
	var normalized_x: float = clampf((mouse_position.x / viewport_width - 0.5) * 2.0, -1.0, 1.0)
	_drag_card_proxy.rotation = deg_to_rad(normalized_x * CARD_DRAG_TILT_DEGREES)
	_drag_card_proxy.scale = _drag_card_base_scale * CARD_DRAG_LIFT_SCALE

func _spawn_card_proxy(card_id: String, rect: Rect2) -> Control:
	var proxy: Control = _take_pooled_card_proxy()
	if proxy == null:
		proxy = Control.new()
		var new_widget = CardWidgetScene.instantiate()
		new_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
		proxy.add_child(new_widget)
	proxy.name = "CardProxy"
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.visible = true
	proxy.process_mode = Node.PROCESS_MODE_INHERIT
	# Top-level geometry is restored after mounting. Reused Controls otherwise retain
	# their former parent transform when they re-enter an FX layer and appear gigantic.
	proxy.top_level = false
	proxy.z_index = 122
	proxy.z_as_relative = false
	proxy.position = Vector2.ZERO
	proxy.rotation = 0.0
	proxy.pivot_offset = CARD_WIDGET_BASE_SIZE * 0.5
	proxy.custom_minimum_size = CARD_WIDGET_BASE_SIZE
	proxy.size = CARD_WIDGET_BASE_SIZE
	proxy.scale = Vector2.ONE
	proxy.modulate = Color.WHITE
	proxy.self_modulate = Color.WHITE
	proxy.set_meta("scaled_card_proxy", true)
	var widget: Control = proxy.get_child(0) as Control if proxy.get_child_count() > 0 else null
	if widget == null:
		widget = CardWidgetScene.instantiate()
		proxy.add_child(widget)
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_prepare_native_card_widget(widget)
	_reset_card_proxy_widget_transients(widget)
	widget.configure(card_id, false, false, true, false, false, true, _card_def(card_id, _combat_state))
	var display: Dictionary = _card_widget_display(card_id, _combat_state)
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	# CardWidget configuration can resolve a previously stretched reusable child
	# against its parent a second time. Pin proxy widgets to their native rect after
	# every configure so reuse cannot grow 250x352 into 500x704.
	_prepare_native_card_widget(widget)
	return proxy

func _mount_card_proxy(proxy: Control, parent: Node, rect: Rect2) -> void:
	if proxy == null or parent == null:
		return
	var old_parent: Node = proxy.get_parent()
	if old_parent != null and old_parent != parent:
		old_parent.remove_child(proxy)
	if proxy.get_parent() == null:
		parent.add_child(proxy)
	# Apply top-level state only after the Control is inside its destination tree.
	# This keeps drag motion independent from hand layout while avoiding the stale
	# parent transform that pooled proxies carried when mounted before reparenting.
	proxy.top_level = true
	proxy.position = _card_proxy_position_for_rect(rect)
	proxy.size = CARD_WIDGET_BASE_SIZE
	proxy.pivot_offset = CARD_WIDGET_BASE_SIZE * 0.5
	proxy.scale = Vector2.ONE * _card_widget_scale_for_size(_normalized_card_size(rect.size))
	proxy.rotation = 0.0
	proxy.modulate = Color.WHITE
	proxy.self_modulate = Color.WHITE
	proxy.visible = true
	proxy.process_mode = Node.PROCESS_MODE_INHERIT

func _card_proxy_scale_for_size(size_hint: Vector2) -> Vector2:
	return Vector2.ONE * _card_widget_scale_for_size(_normalized_card_size(size_hint))

func _card_proxy_position_for_rect(rect: Rect2) -> Vector2:
	return rect.get_center() - CARD_WIDGET_BASE_SIZE * 0.5

func _card_proxy_visual_rect(proxy) -> Rect2:
	if not _node_is_alive(proxy):
		return Rect2()
	var center: Vector2 = proxy.get_global_transform() * proxy.pivot_offset
	var visual_size: Vector2 = CARD_WIDGET_BASE_SIZE * proxy.get_global_transform().get_scale().abs()
	return _rect_from_center(center, visual_size)

func _apply_card_proxy_arc_progress(
	progress: float,
	proxy,
	start_center: Vector2,
	end_center: Vector2,
	arc_height: float,
	start_scale: Vector2,
	end_scale: Vector2,
	start_rotation: float,
	end_rotation: float,
	start_modulate: Color,
	end_modulate: Color,
	scale_bulge: float
) -> void:
	if not _node_is_alive(proxy):
		return
	var inverse: float = 1.0 - progress
	var control_center: Vector2 = start_center.lerp(end_center, 0.5) - Vector2(0.0, arc_height)
	var center: Vector2 = start_center * inverse * inverse + control_center * 2.0 * inverse * progress + end_center * progress * progress
	var bulge: float = 1.0 + sin(progress * PI) * scale_bulge
	proxy.position = center - CARD_WIDGET_BASE_SIZE * 0.5
	proxy.scale = start_scale.lerp(end_scale, progress) * bulge
	proxy.rotation = lerpf(start_rotation, end_rotation, progress)
	proxy.modulate = start_modulate.lerp(end_modulate, progress)

func _start_card_proxy_arc(
	proxy,
	target_rect: Rect2,
	arc_height: float,
	duration: float,
	end_rotation: float = 0.0,
	end_modulate: Color = Color.WHITE,
	scale_bulge: float = 0.0,
	delay: float = 0.0
) -> Tween:
	if not _node_is_alive(proxy):
		return null
	var start_rect: Rect2 = _card_proxy_visual_rect(proxy)
	var start_scale: Vector2 = proxy.scale
	var target_scale: Vector2 = _card_proxy_scale_for_size(target_rect.size)
	var tween: Tween = create_tween()
	proxy.set_meta("active_card_proxy_tween", tween)
	tween.tween_method(
		_apply_card_proxy_arc_progress.bind(
			proxy,
			start_rect.get_center(),
			target_rect.get_center(),
			arc_height,
			start_scale,
			target_scale,
			proxy.rotation,
			end_rotation,
			proxy.modulate,
			end_modulate,
			scale_bulge
		),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
	return tween

func _animate_card_proxy_arc(
	proxy,
	target_rect: Rect2,
	arc_height: float,
	duration: float,
	end_rotation: float = 0.0,
	end_modulate: Color = Color.WHITE,
	scale_bulge: float = 0.0
) -> void:
	var tween: Tween = _start_card_proxy_arc(proxy, target_rect, arc_height, duration, end_rotation, end_modulate, scale_bulge)
	if tween == null:
		return
	await tween.finished
	if _node_is_alive(proxy) and proxy.has_meta("active_card_proxy_tween") and proxy.get_meta("active_card_proxy_tween") == tween:
		proxy.remove_meta("active_card_proxy_tween")

func _reset_card_proxy_widget_transients(widget: Control) -> void:
	# These values are zeroed by a fresh CardWidget instance. Reset them explicitly so
	# reuse cannot carry animation/input phase into an otherwise identical card effect.
	widget.set("_left_pressed", false)
	widget.set("_drag_emitted", false)
	widget.set("_press_position", Vector2.ZERO)
	widget.set("_local_hovered", false)
	widget.set("_ready_wave_progress", 0.0)
	widget.set("_ready_wave_active", false)
	var time_badge: Variant = widget.get("_time_badge")
	if time_badge is Node and (time_badge as Node).has_method("set_hovered"):
		(time_badge as Node).call("set_hovered", false)
	var intensity_glow: Variant = widget.get("_intensity_active_glow")
	if intensity_glow is Node:
		(intensity_glow as Node).set("_pulse_phase", 0.0)

func _take_pooled_card_proxy() -> Control:
	while not _card_proxy_pool.is_empty():
		var proxy: Control = _card_proxy_pool.pop_back()
		if not _node_is_alive(proxy):
			continue
		var parent: Node = proxy.get_parent()
		if parent != null:
			parent.remove_child(proxy)
		return proxy
	return null

func _release_card_proxy(proxy) -> void:
	# Animation coroutines can resume while their scene is being torn down. Keep the
	# argument untyped so a previously freed proxy reaches the liveness guard instead
	# of failing GDScript's typed-argument check before this function can run.
	if not _node_is_alive(proxy):
		return
	var active_tween: Variant = proxy.get_meta("active_card_proxy_tween") if proxy.has_meta("active_card_proxy_tween") else null
	if active_tween is Tween and (active_tween as Tween).is_valid() and (active_tween as Tween).is_running():
		# A cancellation can race a snapback/drop tween. Preserve the old free-on-cancel
		# behavior in that case so a still-running tween can never mutate a reused proxy.
		_queue_free_node_now(proxy)
		return
	if proxy.has_meta("active_card_proxy_tween"):
		proxy.remove_meta("active_card_proxy_tween")
	proxy.visible = false
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.process_mode = Node.PROCESS_MODE_DISABLED
	proxy.top_level = false
	proxy.position = Vector2.ZERO
	proxy.rotation = 0.0
	proxy.pivot_offset = Vector2.ZERO
	proxy.scale = Vector2.ONE
	proxy.modulate = Color.WHITE
	proxy.self_modulate = Color.WHITE
	var parent: Node = proxy.get_parent()
	if parent != null:
		parent.remove_child(proxy)
	if _node_is_alive(_card_proxy_pool_host) and _card_proxy_pool.size() < CARD_PROXY_POOL_LIMIT:
		_card_proxy_pool_host.add_child(proxy)
		_card_proxy_pool.append(proxy)
		return
	proxy.queue_free()

func _animate_card_proxy_to_rect(proxy: Control, target_rect: Rect2, duration: float) -> void:
	if proxy == null:
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	proxy.set_meta("active_card_proxy_tween", tween)
	tween.tween_property(proxy, "position", _card_proxy_position_for_rect(target_rect), duration)
	if bool(proxy.get_meta("scaled_card_proxy", false)):
		tween.parallel().tween_property(proxy, "scale", Vector2.ONE * _card_widget_scale_for_size(_normalized_card_size(target_rect.size)), duration)
	else:
		tween.parallel().tween_property(proxy, "size", _normalized_card_size(target_rect.size), duration)
	tween.parallel().tween_property(proxy, "rotation", 0.0, duration)
	await tween.finished
	if _node_is_alive(proxy) and proxy.has_meta("active_card_proxy_tween") and proxy.get_meta("active_card_proxy_tween") == tween:
		proxy.remove_meta("active_card_proxy_tween")

func _hand_card_global_rect(index: int) -> Rect2:
	var control: Control = _hand_card_control(index)
	if control == null:
		return Rect2()
	# Hand cards are native 250x352 widgets inside scaled layout frames. Control.size
	# reports the native dimensions, so animation proxies must include the frame's
	# global scale or they jump to the oversized native card as soon as they move.
	var visual_scale: Vector2 = control.get_global_transform().get_scale().abs()
	return Rect2(control.global_position, control.size * visual_scale)

func _hand_card_control(index: int) -> Control:
	if index < 0 or index >= hand_box.get_child_count():
		return null
	var slot: Control = hand_box.get_child(index) as Control
	if slot == null:
		return null
	if slot.get_child_count() > 0 and slot.get_child(0) is Control:
		return slot.get_child(0) as Control
	return slot

func _pile_global_rect(kind: String) -> Rect2:
	var source: Control = null
	match kind:
		"draw":
			source = draw_pile
		"discard":
			source = discard_pile
		"burn":
			source = burn_pile
	if source == null:
		return Rect2()
	return Rect2(source.global_position, source.size)

func _rect_from_center(center: Vector2, rect_size: Vector2) -> Rect2:
	return Rect2(center - rect_size * 0.5, rect_size)

func _hand_receive_rect(index: int, total: int, size_hint: Vector2) -> Rect2:
	var hand_rect := Rect2(hand_scroll.global_position, hand_scroll.size)
	var content_size: Vector2 = HandFanContainer.content_size_for_layout(total, size_hint, HAND_CARD_OVERLAP, true)
	var local_rect: Rect2 = HandFanContainer.card_rect_for_layout(index, total, size_hint, HAND_CARD_OVERLAP, true)
	var origin: Vector2 = hand_rect.get_center() - content_size * 0.5
	return Rect2(origin + local_rect.position, local_rect.size)

func _stage_card_rect(size_hint: Vector2) -> Rect2:
	var board_rect := Rect2(board_view.global_position, board_view.size)
	var center: Vector2 = board_rect.get_center() + Vector2(0.0, board_rect.size.y * 0.16)
	return _rect_from_center(center, size_hint)

func _update_drag_overlay_hover(zone: String) -> void:
	_drag_hover_zone = zone
	for zone_name: String in ["attack", "move"]:
		var panel: PanelContainer = _drag_zone_panels.get(zone_name, null)
		var label: Label = _drag_zone_labels.get(zone_name, null)
		var detail_label: Label = _drag_zone_detail_labels.get(zone_name, null)
		if panel == null or label == null or detail_label == null:
			continue
		var accent: Color = panel.get_meta("accent", Color("9d7a50"))
		var fill: Color = panel.get_meta("fill", Color("241912"))
		var valid: bool = _drag_option_valid(zone_name)
		panel.add_theme_stylebox_override("panel", _drag_zone_style(fill, accent, zone == zone_name and valid, valid))
		label.add_theme_color_override("font_color", Color("fff1d0") if valid else Color("a69a8d"))
		detail_label.text = _drag_zone_detail_text(zone_name, valid).to_upper()
		detail_label.add_theme_color_override("font_color", accent.lightened(0.32) if valid else Color("8c8277"))
		label.modulate = Color.WHITE if valid else Color(1.0, 1.0, 1.0, 0.52)
		detail_label.modulate = Color.WHITE if valid else Color(1.0, 1.0, 1.0, 0.64)
	_update_action_context_copy()

func _drag_zone_detail_text(zone: String, valid: bool) -> String:
	if not valid:
		return "Unavailable"
	match zone:
		"play":
			return "Card Action"
		"attack":
			return _fallback_command_detail("attack")
		"move":
			return _fallback_command_detail("move")
		_:
			return ""

func _drag_zone_style(fill: Color, accent: Color, hovered: bool, valid: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if valid:
		style.bg_color = fill.lightened(0.20) if hovered else fill.lightened(0.04)
		style.border_color = accent.lightened(0.38) if hovered else accent.lightened(0.08)
	else:
		style.bg_color = fill.darkened(0.34).lerp(Color("17120f"), 0.28)
		style.border_color = Color("6f6256")
	var border_width: int = 3 if hovered else 2 if valid else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.24) if hovered else Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 10 if hovered else 4 if valid else 0
	style.content_margin_left = 6.0
	style.content_margin_top = 4.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 4.0
	return style

func _drag_option_valid(zone: String) -> bool:
	match zone:
		"play":
			return bool(_drag_card_options.get("printed_playable", false))
		"attack":
			return bool(_drag_card_options.get("attack_playable", false))
		"move":
			return bool(_drag_card_options.get("move_playable", false))
		_:
			return false

func _setup_pile_widgets() -> void:
	burn_pile.visible = false
	burn_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burn_pile.custom_minimum_size = Vector2.ZERO
	var pile_specs: Array[Dictionary] = [
		{"kind": "draw", "panel": draw_pile, "title": "Draw", "accent": Color("8a6b49"), "fill": Color("33261d")},
		{"kind": "discard", "panel": discard_pile, "title": "Discard", "accent": Color("7f8ea4"), "fill": Color("ede2cd")}
	]
	for spec_var: Variant in pile_specs:
		var spec: Dictionary = spec_var
		_build_pile_widget(spec)

func _setup_contextual_combat_tutorial() -> void:
	_contextual_combat_prompt_host = CenterContainer.new()
	_contextual_combat_prompt_host.name = "ContextualCombatPromptHost"
	_contextual_combat_prompt_host.visible = false
	_contextual_combat_prompt_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contextual_combat_prompt_host.z_index = 122
	_contextual_combat_prompt_host.z_as_relative = false
	ui_root.add_child(_contextual_combat_prompt_host)

	_contextual_combat_prompt = ContextualCombatPromptScene.new()
	_contextual_combat_prompt_host.add_child(_contextual_combat_prompt)
	_contextual_combat_prompt.connect("completed", Callable(self, "_on_contextual_combat_prompt_completed"))
	_contextual_combat_prompt.connect("skipped", Callable(self, "_on_contextual_combat_prompt_skipped"))
	_contextual_combat_prompt.connect("grimoire_requested", Callable(self, "_on_contextual_combat_prompt_grimoire_requested"))
	_layout_contextual_combat_prompt_overlay()
	call_deferred("_layout_contextual_combat_prompt_overlay")

func _layout_contextual_combat_prompt_overlay() -> void:
	if _contextual_combat_prompt_host == null or _contextual_combat_prompt == null or board_view == null:
		return
	if str(_run_state.get("mode", "room")) != "combat":
		_contextual_combat_prompt_host.visible = false
		return
	var prompt_size: Vector2 = _contextual_combat_prompt.get_combined_minimum_size()
	_contextual_combat_prompt_host.set_meta("prompt_size", prompt_size)
	if prompt_size.x <= 0.0 or prompt_size.y <= 0.0:
		return
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var stage_rect: Rect2 = stage_root.get_global_rect() if stage_root != null else viewport_rect
	var safe_top: float = maxf(stage_rect.position.y + CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP, top_bar.get_global_rect().end.y + CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP)
	var safe_bottom: float = viewport_rect.end.y - CONTEXTUAL_COMBAT_PROMPT_VIEWPORT_MARGIN
	var safe_area := Rect2(
		Vector2(viewport_rect.position.x + CONTEXTUAL_COMBAT_PROMPT_VIEWPORT_MARGIN, safe_top),
		Vector2(viewport_rect.size.x - CONTEXTUAL_COMBAT_PROMPT_VIEWPORT_MARGIN * 2.0, maxf(0.0, safe_bottom - safe_top))
	)
	var protected_rects: Array = _contextual_combat_prompt_protected_rects()
	_contextual_combat_prompt_host.set_meta("safe_area", safe_area)
	_contextual_combat_prompt_host.set_meta("protected_rects", protected_rects)
	var x_candidates: Array = []
	x_candidates.append(safe_area.position.x)
	x_candidates.append(safe_area.end.x - prompt_size.x)
	var board_bounds: Rect2 = _contextual_combat_rendered_board_bounds()
	if board_bounds.size.x > 0.0:
		x_candidates.append(board_bounds.position.x - prompt_size.x - CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP)
		x_candidates.append(board_bounds.end.x + CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP)
	var y_candidates: Array = []
	y_candidates.append(safe_area.position.y)
	y_candidates.append(safe_area.get_center().y - prompt_size.y * 0.5)
	y_candidates.append(safe_area.end.y - prompt_size.y)
	for protected_rect: Rect2 in protected_rects:
		x_candidates.append(protected_rect.end.x)
		x_candidates.append(protected_rect.position.x - prompt_size.x)
		y_candidates.append(protected_rect.end.y)
		y_candidates.append(protected_rect.position.y - prompt_size.y)
	var chosen_rect := Rect2()
	var chosen_score: float = INF
	for x: float in x_candidates:
		for y: float in y_candidates:
			var candidate := Rect2(Vector2(x, y), prompt_size)
			if not safe_area.encloses(candidate) or _rect_intersects_any(candidate, protected_rects):
				continue
			var score: float = absf(candidate.position.x - safe_area.position.x) * 0.25 + absf(candidate.get_center().y - safe_area.get_center().y)
			if score < chosen_score:
				chosen_rect = candidate
				chosen_score = score
	_contextual_combat_prompt_host.set_meta("safe_layout_found", chosen_score < INF)
	_contextual_combat_prompt_host.set_meta("chosen_rect", chosen_rect)
	if chosen_score == INF:
		_contextual_combat_prompt_host.visible = false
		return
	_contextual_combat_prompt_host.global_position = chosen_rect.position
	_contextual_combat_prompt_host.size = chosen_rect.size

func _contextual_combat_prompt_protected_rects() -> Array:
	var result: Array = []
	var board_bounds: Rect2 = _contextual_combat_rendered_board_bounds()
	if board_bounds.size.x > 0.0 and board_bounds.size.y > 0.0:
		result.append(board_bounds.grow(CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP))
	for control_var: Variant in [
		top_bar,
		_intensity_bar,
		draw_pile,
		discard_pile,
		_turn_order_panel,
		_play_meter,
		mini_map_overlay,
		_action_step_tracker,
		_choice_button_overlay,
		_pass_preview_overlay
	]:
		var control: Control = control_var as Control
		if control == null or not control.visible or not control.is_inside_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			result.append(rect.grow(CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP))
	var hand: Array = ((_combat_state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	for index: int in range(hand.size()):
		var card_control: Control = _hand_card_control(index)
		if card_control == null or not card_control.visible:
			continue
		result.append(_control_visual_global_rect(card_control).grow(CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP))
	return result

func _contextual_combat_rendered_board_bounds() -> Rect2:
	if board_view == null or not board_view.is_inside_tree():
		return Rect2()
	var bounds := Rect2()
	var has_bounds: bool = false
	var board_transform: Transform2D = board_view.get_global_transform()
	for tile_var: Variant in board_view.call("_rendered_tiles_in_draw_order") as Array:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var
		var polygon: PackedVector2Array = board_view.call("_tile_polygon", tile)
		for point: Vector2 in polygon:
			var global_point: Vector2 = board_transform * point
			if not has_bounds:
				bounds = Rect2(global_point, Vector2.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(global_point)
	return bounds

func _rect_intersects_any(rect: Rect2, others: Array) -> bool:
	for other: Rect2 in others:
		if rect.intersects(other):
			return true
	return false

func _refresh_contextual_combat_tutorial() -> void:
	if _contextual_combat_prompt_host == null or _contextual_combat_prompt == null:
		return
	_layout_contextual_combat_prompt_overlay()
	var prompt: Dictionary = ContextualCombatTutorial.next_prompt(_contextual_combat_tutorial_context(), _progression)
	_active_contextual_combat_prompt_id = str(prompt.get("id", ""))
	if prompt.is_empty():
		_contextual_combat_prompt.call("clear_prompt")
		_contextual_combat_prompt_host.visible = false
		if log_overlay != null:
			log_overlay.visible = log_label != null and not log_label.text.is_empty()
		return
	_contextual_combat_prompt.call("configure", prompt)
	_contextual_combat_prompt_host.visible = true
	if log_overlay != null:
		log_overlay.visible = false
	_layout_contextual_combat_prompt_overlay()
	call_deferred("_layout_contextual_combat_prompt_overlay")

func _contextual_combat_tutorial_context() -> Dictionary:
	var mode: String = str(_run_state.get("mode", "room"))
	var selected: bool = _selected_card_index >= 0
	var current_action: Dictionary = {}
	if selected and _pending_action_index >= 0 and _pending_action_index < _pending_actions.size():
		current_action = _pending_actions[_pending_action_index] as Dictionary
	var hand_count: int = 0
	if not _combat_state.is_empty():
		hand_count = ((_combat_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size()
	var pass_available: bool = (
		mode == "combat"
		and not selected
		and not _animation_lock
		and _drag_card_index < 0
		and not _combat_state.is_empty()
		and _combat_engine.is_player_turn(_combat_state)
	)
	return {
		"mode": mode,
		"player_turn": mode == "combat" and not _combat_state.is_empty() and _combat_engine.is_player_turn(_combat_state),
		"hand_count": hand_count,
		"card_selected": selected,
		"target_required": not current_action.is_empty() and _combat_engine.player_action_needs_target(current_action),
		"target_count": _pending_target_tiles.size(),
		"optional_step": selected and _pending_action_can_skip,
		"pass_available": pass_available,
		"pass_preview_visible": _pass_preview_overlay != null and _pass_preview_overlay.visible,
		"timeline_visible": _turn_order_panel != null and _turn_order_panel.visible,
		"card_time_preview": not _turn_order_card_time_preview().is_empty(),
		"suppressed": _contextual_combat_tutorial_suppressed()
	}

func _contextual_combat_tutorial_suppressed() -> bool:
	return (
		_dialogue_active
		or _animation_lock
		or _drag_card_index >= 0
		or _visible_control(_menu_scrim)
		or _visible_control(_grimoire_scrim)
		or _visible_control(_pile_scrim)
		or _visible_control(_large_map_scrim)
		or _visible_control(_upgrade_scrim)
		or _visible_control(_pre_battle_scrim)
		or _visible_control(_run_end_recap)
	)

func _visible_control(control: Control) -> bool:
	return control != null and control.visible

func _on_contextual_combat_prompt_completed(prompt_id: String) -> void:
	_resolve_contextual_combat_prompt(prompt_id, false)

func _on_contextual_combat_prompt_skipped(prompt_id: String) -> void:
	_resolve_contextual_combat_prompt(prompt_id, true)

func _on_contextual_combat_prompt_grimoire_requested(prompt_id: String, entry_id: String) -> void:
	_resolve_contextual_combat_prompt(prompt_id, false)
	_open_grimoire_overlay()
	_on_grimoire_entry_pressed(entry_id)

func _complete_active_contextual_combat_prompt(prompt_id: String) -> void:
	if _active_contextual_combat_prompt_id == prompt_id:
		_resolve_contextual_combat_prompt(prompt_id, false)

func _resolve_contextual_combat_prompt(prompt_id: String, skipped: bool) -> void:
	if not ContextualCombatTutorial.prompt_ids().has(prompt_id):
		return
	_progression = ContextualCombatTutorial.resolve_progression(_progression, prompt_id, skipped)
	var run_progression: Dictionary = (_run_state.get("progression", {}) as Dictionary).duplicate(true)
	if not run_progression.is_empty():
		run_progression = ContextualCombatTutorial.resolve_progression(run_progression, prompt_id, skipped)
		_run_state["progression"] = run_progression
	if not _is_debug_boss_run():
		ProgressionStore.save_data(_progression)
		if not _run_state.is_empty():
			_persist_committed_boundary("tutorial_progress")
	_refresh_contextual_combat_tutorial()

func _setup_action_step_tracker() -> void:
	_action_context_connector = ColorRect.new()
	_action_context_connector.name = "ActionContextConnector"
	_action_context_connector.visible = false
	_action_context_connector.color = Color("d5aa62")
	_action_context_connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_context_connector.z_index = 123
	_action_context_connector.z_as_relative = false
	ui_root.add_child(_action_context_connector)

	_action_step_tracker = PanelContainer.new()
	_action_step_tracker.name = "ActionStepTracker"
	_action_step_tracker.visible = false
	_action_step_tracker.custom_minimum_size = ACTION_STEP_TRACKER_MIN_SIZE
	_action_step_tracker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_action_step_tracker.z_index = 124
	_action_step_tracker.z_as_relative = false
	_action_step_tracker.mouse_filter = Control.MOUSE_FILTER_PASS
	_action_step_tracker.add_theme_stylebox_override("panel", _action_step_tracker_style())
	ui_root.add_child(_action_step_tracker)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 9)
	_action_step_tracker.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var header := VBoxContainer.new()
	header.name = "ActionContextHeader"
	header.custom_minimum_size = Vector2(0.0, 26.0)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(0.0, 26.0)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 4)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_row)

	_action_context_detail_row = HBoxContainer.new()
	_action_context_detail_row.name = "ActionContextDetailRow"
	_action_context_detail_row.custom_minimum_size = Vector2(0.0, 22.0)
	_action_context_detail_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_context_detail_row.add_theme_constant_override("separation", 4)
	_action_context_detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_action_context_detail_row)

	_action_context_status_row = HBoxContainer.new()
	_action_context_status_row.name = "ActionContextStatusRow"
	_action_context_status_row.custom_minimum_size = Vector2(0.0, 22.0)
	_action_context_status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_context_status_row.add_theme_constant_override("separation", 4)
	_action_context_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_action_context_status_row)

	_action_step_tracker_title = Label.new()
	_action_step_tracker_title.name = "ActionStepTitle"
	_action_step_tracker_title.custom_minimum_size = Vector2(0.0, 26.0)
	_action_step_tracker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_step_tracker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_action_step_tracker_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_step_tracker_title.clip_text = true
	_action_step_tracker_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_action_step_tracker_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_action_step_tracker_title, UiTypography.SIZE_BODY)
	_action_step_tracker_title.add_theme_color_override("font_color", Color("fff1d5"))
	_action_step_tracker_title.add_theme_color_override("font_outline_color", Color("20140d"))
	_action_step_tracker_title.add_theme_constant_override("outline_size", 2)
	title_row.add_child(_action_step_tracker_title)

	_action_context_step_label = Label.new()
	_action_context_step_label.name = "ActionContextStep"
	_action_context_step_label.custom_minimum_size = Vector2(64.0, 26.0)
	_action_context_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_context_step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_context_step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_action_context_step_label, UiTypography.SIZE_SMALL)
	_action_context_step_label.add_theme_color_override("font_color", Color("d8ad65"))
	_action_context_step_label.add_theme_color_override("font_outline_color", Color("20140d"))
	_action_context_step_label.add_theme_constant_override("outline_size", 1)
	title_row.add_child(_action_context_step_label)

	_action_context_verb_label = Label.new()
	_action_context_verb_label.name = "ActionContextVerb"
	_action_context_verb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_context_verb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_context_verb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_context_verb_label.clip_text = true
	_action_context_verb_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_action_context_verb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_action_context_verb_label, UiTypography.SIZE_SMALL)
	_action_context_verb_label.add_theme_color_override("font_color", Color("fff0ce"))
	_action_context_verb_label.add_theme_color_override("font_outline_color", Color("20140d"))
	_action_context_verb_label.add_theme_constant_override("outline_size", 2)
	_action_context_detail_row.add_child(_action_context_verb_label)

	_action_context_target_label = Label.new()
	_action_context_target_label.name = "ActionContextTarget"
	_action_context_target_label.custom_minimum_size = Vector2(64.0, 22.0)
	_action_context_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_action_context_target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_context_target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_action_context_target_label, UiTypography.SIZE_SMALL)
	_action_context_target_label.add_theme_color_override("font_color", Color("9ed7df"))
	_action_context_target_label.add_theme_color_override("font_outline_color", Color("20140d"))
	_action_context_target_label.add_theme_constant_override("outline_size", 1)
	_action_context_status_row.add_child(_action_context_target_label)

	_action_context_risk_panel = PanelContainer.new()
	_action_context_risk_panel.name = "ActionContextRisk"
	_action_context_risk_panel.custom_minimum_size = Vector2(96.0, 22.0)
	_action_context_risk_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_context_risk_panel.add_theme_stylebox_override("panel", _action_context_risk_style("safe"))
	_action_context_status_row.add_child(_action_context_risk_panel)

	_action_context_risk_label = Label.new()
	_action_context_risk_label.name = "ActionContextRiskLabel"
	_action_context_risk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_context_risk_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_context_risk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_action_context_risk_label, UiTypography.SIZE_SMALL)
	_action_context_risk_label.add_theme_color_override("font_color", Color("aee49f"))
	_action_context_risk_panel.add_child(_action_context_risk_label)

	_card_action_mode_selector = HBoxContainer.new()
	_card_action_mode_selector.name = "CardActionModeSelector"
	_card_action_mode_selector.visible = false
	_card_action_mode_selector.custom_minimum_size = Vector2(0.0, CARD_ACTION_MODE_OPTION_HEIGHT)
	_card_action_mode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_action_mode_selector.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_action_mode_selector.add_theme_constant_override("separation", 4)
	vbox.add_child(_card_action_mode_selector)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionContextActions"
	action_row.custom_minimum_size = Vector2(0.0, ACTION_STEP_CHIP_SIZE.y)
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	vbox.add_child(action_row)

	_action_step_tracker_steps = HBoxContainer.new()
	_action_step_tracker_steps.name = "ActionStepChips"
	_action_step_tracker_steps.alignment = BoxContainer.ALIGNMENT_BEGIN
	_action_step_tracker_steps.add_theme_constant_override("separation", 6)
	_action_step_tracker_steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.add_child(_action_step_tracker_steps)

	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.add_child(action_spacer)

	_action_context_command_bar = HBoxContainer.new()
	_action_context_command_bar.name = "ActionContextCommands"
	_action_context_command_bar.alignment = BoxContainer.ALIGNMENT_END
	_action_context_command_bar.add_theme_constant_override("separation", 8)
	action_row.add_child(_action_context_command_bar)

func _setup_play_meter() -> void:
	_play_meter = PanelContainer.new()
	_play_meter.name = "CardPlayMeter"
	_play_meter.custom_minimum_size = Vector2(222.0, 108.0)
	_play_meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_play_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_play_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_meter.tooltip_text = "Card plays remaining"
	var meter_style := _pile_card_style(Color(0.10, 0.07, 0.05, 0.94), Color("c28a53"), 6.0)
	meter_style.corner_radius_top_left = 8
	meter_style.corner_radius_top_right = 8
	meter_style.corner_radius_bottom_right = 8
	meter_style.corner_radius_bottom_left = 8
	meter_style.shadow_size = 5
	_play_meter.add_theme_stylebox_override("panel", meter_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 11)
	_play_meter.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	_play_meter_icon = TextureRect.new()
	_play_meter_icon.custom_minimum_size = Vector2(68.0, 68.0)
	_play_meter_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_play_meter_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_play_meter_icon.texture = AssetLoader.load_texture(CARD_PLAY_ICON_PATH)
	_play_meter_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_play_meter_icon)

	var count_column := VBoxContainer.new()
	count_column.custom_minimum_size = Vector2(122.0, 68.0)
	count_column.alignment = BoxContainer.ALIGNMENT_CENTER
	count_column.add_theme_constant_override("separation", 4)
	hbox.add_child(count_column)

	_play_meter_count = Label.new()
	_play_meter_count.custom_minimum_size = Vector2(122.0, 38.0)
	_play_meter_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_meter_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_play_meter_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_play_meter_count, UiTypography.SIZE_SECTION_LARGE)
	_play_meter_count.add_theme_color_override("font_color", Color("fff4dc"))
	_play_meter_count.add_theme_color_override("font_outline_color", Color("2b1b12"))
	_play_meter_count.add_theme_constant_override("outline_size", 2)
	count_column.add_child(_play_meter_count)

	_play_meter_banked_badge = PanelContainer.new()
	_play_meter_banked_badge.name = "BankedPlayBadge"
	_play_meter_banked_badge.custom_minimum_size = Vector2(122.0, 26.0)
	_play_meter_banked_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banked_style := StyleBoxFlat.new()
	banked_style.bg_color = Color(0.25, 0.12, 0.34, 0.96)
	banked_style.border_color = Color("c89bea")
	banked_style.set_border_width_all(1)
	banked_style.set_corner_radius_all(6)
	_play_meter_banked_badge.add_theme_stylebox_override("panel", banked_style)
	count_column.add_child(_play_meter_banked_badge)

	_play_meter_banked_label = Label.new()
	_play_meter_banked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_meter_banked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_play_meter_banked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(_play_meter_banked_label, UiTypography.ROLE_CAPTION)
	_play_meter_banked_label.add_theme_color_override("font_color", Color("f0d9ff"))
	_play_meter_banked_badge.add_child(_play_meter_banked_label)

	var insert_index: int = hand_row.get_child_count()
	for index: int in range(hand_row.get_child_count()):
		if hand_row.get_child(index) == hand_scroll:
			insert_index = index
			break
	hand_row.add_child(_play_meter)
	hand_row.move_child(_play_meter, insert_index)
	_play_meter.set_meta("panel_surface_accent", Color("c28a53"))
	_ui_skin.apply_inset_surface(_play_meter, UiSkin.SURFACE_HUD)
	_refresh_card_play_meter()

func _setup_elemental_intensity_bar() -> void:
	_intensity_bar = Control.new()
	_intensity_bar.name = "ElementalIntensityBar"
	_intensity_bar.visible = false
	_intensity_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_intensity_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_intensity_bar.custom_minimum_size = _intensity_bar_size()
	_intensity_bar.size = _intensity_bar_size()
	_intensity_bar.z_index = 30
	ui_root.add_child(_intensity_bar)
	for element_id: String in ElementData.all_elements():
		var badge := TooltipPanelContainer.new()
		badge.custom_minimum_size = INTENSITY_BADGE_SIZE
		badge.size = INTENSITY_BADGE_SIZE
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.mouse_default_cursor_shape = TOOLTIP_ONLY_CURSOR_SHAPE
		badge.tooltip_text = _intensity_tooltip(element_id)
		badge.add_theme_stylebox_override("panel", _intensity_badge_style(element_id, 0))
		_intensity_bar.add_child(badge)
		_intensity_badges[element_id] = badge

		var content := Control.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.anchor_right = 1.0
		content.anchor_bottom = 1.0
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(content)

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = INTENSITY_ICON_INSET
		icon.offset_top = INTENSITY_ICON_INSET
		icon.offset_right = -INTENSITY_ICON_INSET
		icon.offset_bottom = -INTENSITY_ICON_INSET
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = AssetLoader.load_texture(ElementData.intensity_icon_path(element_id))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)

		var count := Label.new()
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		count.anchor_right = 1.0
		count.anchor_bottom = 1.0
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.text = "0"
		UiTypography.set_label_size(count, UiTypography.SIZE_SECTION)
		count.add_theme_color_override("font_color", Color("fff7df"))
		count.add_theme_color_override("font_outline_color", Color("24160f"))
		count.add_theme_constant_override("outline_size", 4)
		content.add_child(count)
		_intensity_labels[element_id] = count
	_layout_intensity_badges()
	_refresh_elemental_intensity_bar()

func _connect_header_layout_signals() -> void:
	for control_var: Variant in [title_box, room_title, room_subtitle, umbra_subtitle, relic_bar]:
		var control: Control = control_var as Control
		if control == null:
			continue
		if not control.resized.is_connected(_queue_elemental_intensity_layout):
			control.resized.connect(_queue_elemental_intensity_layout)

func _queue_elemental_intensity_layout() -> void:
	call_deferred("_layout_header_hud")
	call_deferred("_layout_elemental_intensity_bar")
	call_deferred("_layout_turn_order_anchor")

func _intensity_bar_size() -> Vector2:
	return Vector2(INTENSITY_BADGE_SIZE.x * 3.0 + 9.0 * 2.0, INTENSITY_BADGE_SIZE.y * 2.0 + 7.0)

func _intensity_badge_position(index: int) -> Vector2:
	var row: int = 0 if index < 3 else 1
	var column: int = index if row == 0 else index - 3
	var row_count: int = 3 if row == 0 else 2
	var row_width: float = INTENSITY_BADGE_SIZE.x * float(row_count) + 9.0 * float(maxi(0, row_count - 1))
	var x_offset: float = (_intensity_bar_size().x - row_width) * 0.5
	return Vector2(
		x_offset + float(column) * (INTENSITY_BADGE_SIZE.x + 9.0),
		float(row) * (INTENSITY_BADGE_SIZE.y + 7.0)
	)

func _layout_intensity_badges() -> void:
	if _intensity_bar == null:
		return
	for index: int in range(_intensity_bar.get_child_count()):
		var child: Control = _intensity_bar.get_child(index) as Control
		if child == null:
			continue
		child.position = _intensity_badge_position(index)
		child.size = INTENSITY_BADGE_SIZE

func _layout_header_hud() -> void:
	if title_box == null:
		return
	var min_width: float = maxf(room_title.get_combined_minimum_size().x, room_subtitle.get_combined_minimum_size().x)
	if umbra_subtitle != null and umbra_subtitle.visible:
		min_width = maxf(min_width, umbra_subtitle.get_combined_minimum_size().x)
	var intensity_active: bool = str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty()
	if intensity_active:
		min_width = maxf(min_width, _intensity_bar_size().x)
	if relic_bar != null and relic_bar.visible and relic_bar.get_child_count() > 0:
		min_width = maxf(min_width, _desired_relic_bar_width())
	var available_width: float = _header_title_available_width()
	if available_width > 0.0:
		min_width = minf(min_width, available_width)
	title_box.custom_minimum_size = Vector2(min_width, title_box.custom_minimum_size.y)
	if relic_bar != null:
		relic_bar.custom_minimum_size = Vector2(min_width, relic_bar.custom_minimum_size.y)
		# The wider combat hand can make the main HUD overhang a compact viewport.
		# Keep this interactive group centered inside its title column in that case,
		# so the skill entry point never becomes the offscreen edge item.
		var safe_left: float = ui_root.get_global_rect().position.x + 8.0 if ui_root != null else 8.0
		relic_bar.alignment = (
			FlowContainer.ALIGNMENT_CENTER
			if title_box.get_global_rect().position.x < safe_left
			else FlowContainer.ALIGNMENT_BEGIN
		)

func _desired_relic_bar_width() -> float:
	if relic_bar == null or relic_bar.get_child_count() <= 0:
		return 0.0
	var width: float = 0.0
	var visible_count: int = 0
	var relic_count: int = 0
	for child: Node in relic_bar.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		var child_control: Control = child as Control
		var is_utility: bool = bool(child_control.get_meta("header_utility", false))
		if not is_utility:
			if relic_count >= RELIC_BAR_MIN_VISIBLE_RELICS:
				break
			relic_count += 1
		if visible_count > 0:
			width += RELIC_BAR_HORIZONTAL_GAP
		width += child_control.get_combined_minimum_size().x
		visible_count += 1
	return width

func _header_title_available_width() -> float:
	if top_bar == null or title_box == null:
		return 0.0
	var width: float = top_bar.size.x
	if width <= 0.0:
		return 0.0
	var fixed_width: float = 0.0
	var visible_children: int = 0
	for child: Node in top_bar.get_children():
		if not (child is Control):
			continue
		var child_control: Control = child as Control
		if not child_control.visible:
			continue
		visible_children += 1
		if child_control == title_box or child_control == header_spacer:
			continue
		fixed_width += child_control.get_combined_minimum_size().x
	var separation: float = float(top_bar.get_theme_constant("separation"))
	var total_gap: float = separation * float(maxi(0, visible_children - 1))
	return maxf(0.0, width - fixed_width - total_gap - HEADER_RELIC_WRAP_MARGIN)

func _layout_elemental_intensity_bar() -> void:
	if _intensity_bar == null or room_title == null or room_subtitle == null:
		return
	_layout_header_hud()
	_intensity_bar.size = _intensity_bar_size()
	_layout_intensity_badges()
	var title_rect: Rect2 = room_title.get_global_rect()
	var subtitle_bottom: float = room_subtitle.get_global_rect().end.y
	if umbra_subtitle != null and umbra_subtitle.visible:
		subtitle_bottom = umbra_subtitle.get_global_rect().end.y
	var y: float = subtitle_bottom + ELEMENTAL_INTENSITY_HEADER_GAP
	if relic_bar != null and relic_bar.visible and relic_bar.get_child_count() > 0:
		y = _relic_bar_visible_bottom_y() + ELEMENTAL_INTENSITY_HEADER_GAP
	_intensity_bar.global_position = Vector2(title_rect.position.x, y)

func _layout_turn_order_anchor() -> void:
	if _turn_order_anchor == null:
		return
	var header_y: float = 0.0
	var header_height: float = TURN_ORDER_PANEL_MIN_SIZE.y
	if top_bar != null:
		var top_bar_rect: Rect2 = top_bar.get_global_rect()
		header_y = top_bar_rect.position.y - get_global_rect().position.y
		header_height = maxf(header_height, top_bar_rect.size.y)
	_turn_order_anchor.anchor_left = 0.0
	_turn_order_anchor.anchor_top = 0.0
	_turn_order_anchor.anchor_right = 1.0
	_turn_order_anchor.anchor_bottom = 0.0
	_turn_order_anchor.offset_left = 0.0
	_turn_order_anchor.offset_top = header_y
	_turn_order_anchor.offset_right = 0.0
	_turn_order_anchor.offset_bottom = header_y + header_height

func _relic_bar_visible_bottom_y() -> float:
	if relic_bar == null:
		return 0.0
	var bottom: float = relic_bar.get_global_rect().end.y
	for child: Node in relic_bar.get_children():
		if not (child is Control):
			continue
		var child_control: Control = child as Control
		if not child_control.visible:
			continue
		bottom = maxf(bottom, child_control.get_global_rect().end.y)
	return bottom

func _build_pile_widget(spec: Dictionary) -> void:
	var kind: String = str(spec.get("kind", ""))
	var panel: PanelContainer = spec.get("panel", null)
	if panel == null:
		return
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_NONE
	panel.custom_minimum_size = _pile_widget_size(PILE_CARD_SIZE * PILE_CARD_SCALE)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.clip_contents = false
	panel.tooltip_text = "%s pile" % str(spec.get("title", kind)).capitalize()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for child: Node in panel.get_children():
		child.visible = false
		if child is Control:
			var child_control: Control = child
			child_control.custom_minimum_size = Vector2.ZERO
			child_control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			child_control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var content := Control.new()
	content.name = "PileContent_%s" % kind
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.clip_contents = false
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.add_child(content)
	_pile_content_hosts[kind] = content

	var visual := Control.new()
	visual.name = "PileVisual_%s" % kind
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.clip_contents = false
	visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.add_child(visual)
	_pile_visual_hosts[kind] = visual

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 50
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(badge, UiTypography.SIZE_BODY)
	badge.add_theme_color_override("font_color", Color("fff4dc"))
	badge.add_theme_color_override("font_outline_color", Color("2f2018"))
	badge.add_theme_constant_override("outline_size", 2)
	var badge_style := _pile_card_style(Color(0.16, 0.12, 0.09, 0.94), spec.get("accent", Color("8a6d49")), 4.0)
	badge_style.corner_radius_top_left = 8
	badge_style.corner_radius_top_right = 8
	badge_style.corner_radius_bottom_right = 8
	badge_style.corner_radius_bottom_left = 8
	badge.add_theme_stylebox_override("normal", badge_style)
	content.add_child(badge)
	_pile_badges[kind] = badge

	panel.set_meta("cursor_feedback_context_provider", _pile_cursor_feedback_context.bind(kind))
	panel.gui_input.connect(_on_pile_gui_input.bind(kind))

func _pile_panel_for_kind(kind: String) -> PanelContainer:
	match kind:
		"draw":
			return draw_pile
		"discard":
			return discard_pile
		"burn":
			return burn_pile
	return null

func _pile_display_card_size() -> Vector2:
	var hand_count: int = 1
	if not _combat_state.is_empty():
		var deck: Dictionary = _combat_state.get("deck", {})
		hand_count = maxi(1, (deck.get("hand", []) as Array).size())
	return _hand_card_size(hand_count, false) * PILE_CARD_SCALE

func _pile_widget_size(card_size: Vector2) -> Vector2:
	return card_size + _pile_stack_offset() * float(PILE_STACK_LAYERS - 1)

func _pile_stack_offset() -> Vector2:
	return PILE_STACK_OFFSET * PILE_CARD_SCALE

func _layout_pile_widget(kind: String, card_size: Vector2) -> void:
	var panel: PanelContainer = _pile_panel_for_kind(kind)
	var content: Control = _pile_content_hosts.get(kind, null)
	var host: Control = _pile_visual_hosts.get(kind, null)
	if panel == null or content == null or host == null:
		return
	var widget_size: Vector2 = _pile_widget_size(card_size)
	panel.custom_minimum_size = widget_size
	content.custom_minimum_size = widget_size
	content.position = Vector2.ZERO
	content.size = widget_size
	host.custom_minimum_size = widget_size
	host.position = Vector2.ZERO
	host.size = widget_size
	var badge: Label = _pile_badges.get(kind, null)
	if badge != null:
		badge.position = Vector2(card_size.x - 46.0, 7.0)
		badge.size = Vector2(38.0, 30.0)

func _populate_draw_pile(host: Control, cards: Array, card_size: Vector2) -> void:
	_clear_children_now(host)
	var visible_layers: int = clampi(cards.size(), 1, PILE_STACK_LAYERS)
	for stack_index: int in range(visible_layers - 1, -1, -1):
		var alpha: float = 0.34 if cards.is_empty() else clampf(1.0 - float(stack_index) * 0.12, 0.72, 1.0)
		_add_card_back_layer(host, card_size, stack_index, alpha)

func _populate_discard_pile(host: Control, cards: Array, card_size: Vector2) -> void:
	_clear_children_now(host)
	if cards.is_empty():
		var empty_frame := TextureRect.new()
		empty_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_frame.position = Vector2.ZERO
		empty_frame.size = card_size
		empty_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		empty_frame.stretch_mode = TextureRect.STRETCH_SCALE
		empty_frame.texture = AssetLoader.load_texture(CARD_FRAME_TEXTURE_PATH)
		empty_frame.modulate = Color(1.0, 1.0, 1.0, 0.16)
		host.add_child(empty_frame)
		return
	var visible_layers: int = clampi(cards.size(), 1, PILE_STACK_LAYERS)
	for stack_index: int in range(visible_layers - 1, 0, -1):
		_add_card_back_layer(host, card_size, stack_index, 0.58)
	var top_card_id: String = str(cards[cards.size() - 1])
	var display: Dictionary = _card_widget_display(top_card_id, _combat_state)
	var widget := CardWidgetScene.instantiate() as CardWidget
	widget.configure(top_card_id, false, false, true, false, false, true, _card_def(top_card_id, _combat_state))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	var slot: Control = _scaled_card_slot(widget, card_size)
	host.add_child(slot)
	slot.position = Vector2.ZERO
	slot.size = _normalized_card_size(card_size)
	_set_mouse_filter_recursive(slot, Control.MOUSE_FILTER_IGNORE)

func _add_card_back_layer(host: Control, card_size: Vector2, stack_index: int, alpha: float) -> void:
	var card_back := TextureRect.new()
	card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_back.position = _pile_stack_offset() * float(stack_index)
	card_back.size = card_size
	card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_back.stretch_mode = TextureRect.STRETCH_SCALE
	card_back.texture = AssetLoader.load_texture(CARD_BACK_TEXTURE_PATH)
	card_back.modulate = Color(1.0, 1.0, 1.0, alpha)
	host.add_child(card_back)

func _pile_card_style(fill: Color, border: Color, margin: float = 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 4
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style

func _boot_run() -> void:
	_progression = ProgressionStore.load_data()
	_reconcile_progression_analytics_outbox()
	var debug_boss: bool = bool(get_tree().root.get_meta("labyrinth_debug_boss_run", false))
	if get_tree().root.has_meta("labyrinth_debug_boss_run"):
		get_tree().root.remove_meta("labyrinth_debug_boss_run")
	if debug_boss:
		_start_debug_boss_run()
		return
	var should_resume: bool = bool(get_tree().root.get_meta("labyrinth_resume_saved_run", false))
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	if should_resume and ProgressionStore.has_saved_run():
		var saved_run: Dictionary = ProgressionStore.load_saved_run()
		if not saved_run.is_empty():
			_load_run_state(saved_run)
			_analytics_log_run_resumed()
			return
	_start_run()

func _load_run_state(next_run_state: Dictionary) -> void:
	_close_dialogue()
	_last_auto_dialogue_key = ""
	_merchant_shop_room_coord = INVALID_ROOM_COORD
	_merchant_shop_open = true
	_committed_run_state_override.clear()
	var content_migration_required: bool = _run_engine.run_content_migration_required(next_run_state)
	var combat_units_migration_required: bool = _run_engine.combat_units_migration_required(next_run_state)
	var migrated_profile: Dictionary = _run_engine.migrate_renamed_content_ids(_progression)
	if migrated_profile != _progression:
		_progression = migrated_profile
		if not bool(next_run_state.get("debug_boss_run", false)) and not ProgressionStore.save_data(_progression):
			push_error("Failed to persist migrated profile content references.")
	var migrated_run_state: Dictionary = _run_engine.migrate_renamed_content_ids(next_run_state) if content_migration_required else next_run_state.duplicate(true)
	var merged_run_state: Dictionary = _run_state_with_profile_grimoire(migrated_run_state)
	merged_run_state = _run_engine.reconcile_progression_revision(merged_run_state, _progression)
	_run_state = _ensure_run_analytics_metadata(_run_engine.repair_loaded_run_state(merged_run_state))
	_run_state = GrimoireLibrary.ensure_run_state(_run_state)
	_baseline_run_skill_event_cursors()
	_sync_progression_from_run()
	_repair_profile_progression_from_run()
	_reconcile_progression_analytics_outbox()
	_sync_progression_analytics_outbox_to_run()
	_sync_combat_state_from_run()
	_repair_legacy_empty_actor_transition()
	if (
		(content_migration_required or combat_units_migration_required)
		and not bool(_run_state.get("debug_boss_run", false))
		and not ProgressionStore.save_run_state(_run_state)
	):
		push_error("Failed to persist migrated run content or combat units.")
	_sync_analytics_combat_tracker()
	_reset_card_resolution()
	_victory_carry_processed = false
	_defeat_loss_processed = false
	_victory_carry_amount = 0
	_defeat_lost_amount = 0
	if _run_end_recap != null:
		_run_end_recap.reset()
	_set_fatigue_edge_progress(-1.0)
	_board_presentation.clear()
	action_banner.visible = false
	_refresh_ui()
	if _has_pending_combat_checkpoints():
		call_deferred("_resume_pending_combat_checkpoints")

func _start_run() -> void:
	_progression = ProgressionStore.prepare_for_new_run(ProgressionStore.load_data())
	ProgressionStore.save_data(_progression)
	ProgressionStore.clear_saved_run()
	var new_run_state: Dictionary = _ensure_run_analytics_metadata(_run_engine.create_new_run(_new_seed(), _progression))
	_load_run_state(new_run_state)
	_analytics_log_run_started()
	_persist_committed_boundary("run_started")

func _start_debug_boss_run() -> void:
	_progression = ProgressionStore.default_data()
	var run_state: Dictionary = _run_engine.create_debug_boss_run(_progression)
	_load_run_state(_ensure_run_analytics_metadata(run_state))
	_analytics_log_run_started()

func _refresh_ui() -> void:
	if _dialogue_active and str(_run_state.get("mode", "room")) != "room":
		_close_dialogue()
	_sync_analytics_combat_tracker()
	if str(_run_state.get("mode", "room")) == "victory" and not _victory_carry_processed:
		_process_victory_carry()
	if str(_run_state.get("mode", "room")) == "defeat" and not _defeat_loss_processed:
		_process_defeat_loss()
	_sync_progression_from_run()
	_sync_umbra_warning_progression()
	_run_state = GrimoireLibrary.ensure_run_state(_run_state)
	_sync_grimoire_discoveries()
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, _run_state.get("current_room", Vector2i.ZERO))
	var display_room: Dictionary = current_room.duplicate(true)
	if str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty():
		display_room["name"] = str(_combat_state.get("room_name", display_room.get("name", "Chamber")))
		display_room["type"] = str(_combat_state.get("room_type", display_room.get("type", "combat")))
		display_room["element"] = str(_combat_state.get("room_element", display_room.get("element", ElementData.NONE)))
	_update_music_for_context(display_room)
	var room_element: String = str(display_room.get("element", ElementData.NONE))
	var title_color: Color = ElementData.accent(room_element) if ElementData.is_elemental(room_element) else Color("f0e6d2")
	room_title.add_theme_color_override("font_color", title_color)
	room_subtitle.add_theme_color_override("font_color", title_color.lightened(0.28) if ElementData.is_elemental(room_element) else Color("cdbca2"))
	room_title.text = _room_title_text(display_room)
	room_subtitle.text = _room_subtitle_text(display_room)
	_refresh_umbra_subtitle()
	_set_stats_label_text(_displayed_ember_count())
	_refresh_relic_bar()
	_refresh_turn_order_bar()
	_layout_header_hud()
	_refresh_elemental_intensity_bar()
	call_deferred("_layout_header_hud")
	call_deferred("_layout_elemental_intensity_bar")
	mini_map.set_run_state(_run_state)
	if _large_map_view != null:
		_large_map_view.call("set_run_state", _run_state)
	_refresh_pile_counts()
	_refresh_card_play_meter()
	_refresh_action_step_tracker()
	_refresh_pile_visuals()
	_refresh_choice_bar()
	_refresh_stage_view()
	_refresh_hand_panel()
	_refresh_visibility()
	_sync_pre_battle_preview_after_refresh()
	_layout_action_step_tracker()
	call_deferred("_layout_action_step_tracker")
	_refresh_grimoire_badge()
	_refresh_loadout_badge()
	log_label.text = _log_text()
	log_overlay.visible = not log_label.text.is_empty()
	_refresh_contextual_combat_tutorial()
	_maybe_auto_trigger_room_dialogue()

func _refresh_animation_lock_ui() -> void:
	# Animation entry only changes combat interactivity/presentation. Avoid rebuilding
	# unrelated maps, relics, piles, progression, and room chrome at the exact moment
	# the player expects an action to begin.
	_refresh_turn_order_bar()
	_refresh_card_play_meter()
	_refresh_choice_bar()
	_refresh_stage_view()
	_refresh_hand_panel()
	_refresh_visibility()
	_refresh_contextual_combat_tutorial()

func _refresh_pile_counts() -> void:
	var mode: String = str(_run_state.get("mode", "room"))
	if mode != "combat" or _combat_state.is_empty():
		draw_count.text = "-"
		discard_count.text = "-"
		burn_count.text = "-"
		return
	var deck: Dictionary = _combat_state.get("deck", {})
	draw_count.text = str((deck.get("draw", []) as Array).size())
	discard_count.text = str((deck.get("discard", []) as Array).size())
	burn_count.text = str((deck.get("burned", []) as Array).size())

func _refresh_relic_bar() -> void:
	if relic_bar == null:
		return
	var relic_ids: Array = (_run_state.get("relics", []) as Array).duplicate()
	var skill_ids: Array[String] = _selected_skill_ids_for_hud()
	var event_revision: int = int(_combat_state.get("skill_event_revision", 0)) if not _combat_state.is_empty() else 0
	var defiance_event_revision: int = int(_combat_state.get("defiance_event_revision", 0)) if not _combat_state.is_empty() else 0
	var defiance_capacity: int = (
		maxi(0, int(_combat_state.get(RunEngineScript.DEFIANCE_CAPACITY_KEY, 0)))
		if not _combat_state.is_empty()
		else _run_engine.defiance_capacity(_run_state)
	)
	var defiance_remaining: int = (
		clampi(int(_combat_state.get(RunEngineScript.DEFIANCE_REMAINING_KEY, 0)), 0, defiance_capacity)
		if not _combat_state.is_empty()
		else _run_engine.defiance_remaining(_run_state)
	)
	var run_event_revision: int = _run_engine.run_skill_event_revision(_run_state)
	var should_pulse: bool = (
		event_revision > _skill_event_revision_seen
		or run_event_revision > _run_skill_event_revision_seen
	)
	var should_pulse_defiance: bool = defiance_event_revision > _defiance_event_revision_seen
	_reconcile_skill_event_analytics()
	_flush_run_skill_event_analytics("hud_run_skill")
	_skill_event_revision_seen = maxi(_skill_event_revision_seen, event_revision)
	_run_skill_event_revision_seen = maxi(_run_skill_event_revision_seen, run_event_revision)
	_defiance_event_revision_seen = maxi(_defiance_event_revision_seen, defiance_event_revision)
	var signature: String = str(hash([
		relic_ids,
		skill_ids,
		_combat_state.get("skill_flags", {}),
			_run_state.get(RunEngineScript.SKILL_STATE_KEY, {}),
			event_revision,
			defiance_event_revision,
			defiance_capacity,
			defiance_remaining,
			run_event_revision,
		str(_run_state.get("mode", "room"))
	]))
	if signature == _relic_bar_signature:
		if _skill_status_popover != null and _skill_status_popover.visible:
			_refresh_skill_status_popover(skill_ids)
		return
	_relic_bar_signature = signature
	_clear_children(relic_bar)
	_skill_sigil = null
	_defiance_badge = null
	relic_bar.visible = defiance_capacity > 0 or not relic_ids.is_empty() or not skill_ids.is_empty()
	if defiance_capacity > 0:
		_defiance_badge = _build_defiance_badge(defiance_remaining, defiance_capacity)
		relic_bar.add_child(_defiance_badge)
		if not skill_ids.is_empty() or not relic_ids.is_empty():
			relic_bar.add_child(_build_header_utility_divider("DefianceUtilityDivider"))
	if not skill_ids.is_empty():
		_skill_sigil = _build_skill_sigil(skill_ids)
		relic_bar.add_child(_skill_sigil)
		if not relic_ids.is_empty():
			relic_bar.add_child(_build_header_utility_divider("SkillRelicDivider"))
	for relic_id_var: Variant in relic_ids:
		var relic_id: String = str(relic_id_var)
		var relic: Dictionary = GameData.relic_def(relic_id)
		if relic.is_empty():
			continue
		var frame := TooltipPanelContainer.new()
		frame.custom_minimum_size = RELIC_BADGE_SIZE
		frame.set_meta("relic_id", relic_id)
		frame.tooltip_text = "%s\n%s" % [
				str(relic.get("name", relic_id)),
				str(relic.get("description", ""))
		]
		frame.mouse_default_cursor_shape = TOOLTIP_ONLY_CURSOR_SHAPE
		frame.add_theme_stylebox_override("panel", _pile_card_style(
				Color("261b14"),
				Color(GameData.relic_accent(relic_id)),
				4.0
		))
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.anchor_right = 1.0
		margin.anchor_bottom = 1.0
		margin.add_theme_constant_override("margin_left", 5)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_right", 5)
		margin.add_theme_constant_override("margin_bottom", 5)
		frame.add_child(margin)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = AssetLoader.load_texture(str(relic.get("icon_path", "")))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(icon)
		if icon.texture == null:
			var fallback := Label.new()
			fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
			fallback.anchor_right = 1.0
			fallback.anchor_bottom = 1.0
			fallback.text = str(relic.get("name", "?")).substr(0, 1).to_upper()
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			UiTypography.set_label_size(fallback, UiTypography.SIZE_CAPTION)
			fallback.add_theme_color_override("font_color", Color("f0e6d2"))
			fallback.add_theme_color_override("font_outline_color", Color("2c1f16"))
			fallback.add_theme_constant_override("outline_size", 1)
			margin.add_child(fallback)
		relic_bar.add_child(frame)
	_refresh_skill_status_popover(skill_ids)
	_layout_header_hud()
	call_deferred("_layout_header_hud")
	call_deferred("_layout_elemental_intensity_bar")
	if should_pulse and _skill_sigil != null:
		call_deferred("_pulse_skill_sigil")
	if should_pulse_defiance and _defiance_badge != null:
		call_deferred("_pulse_defiance_badge")

func _build_header_utility_divider(node_name: String) -> ColorRect:
	var divider := ColorRect.new()
	divider.name = node_name
	divider.custom_minimum_size = Vector2(2.0, RELIC_BADGE_SIZE.y - 12.0)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.color = Color("765e96")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.set_meta("header_utility", true)
	return divider

func _build_defiance_badge(remaining: int, capacity: int) -> Control:
	var frame := TooltipPanelContainer.new()
	frame.name = "DefianceBadge"
	frame.custom_minimum_size = RELIC_BADGE_SIZE
	frame.tooltip_text = (
		"DEFIANCE %d / %d\nLethal health loss spends 1 to restore 25%% max health.\n"
		+ "Every fourth permanent level grants 1. Defiance does not refill during a run."
	) % [remaining, capacity]
	frame.mouse_default_cursor_shape = TOOLTIP_ONLY_CURSOR_SHAPE
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.set_meta("header_utility", true)
	frame.set_meta("defiance_remaining", remaining)
	frame.set_meta("defiance_capacity", capacity)
	var accent: Color = Color("d6aa5e") if remaining > 0 else Color("62556e")
	frame.add_theme_stylebox_override("panel", _pile_card_style(
		Color("211326") if remaining > 0 else Color("19151c"),
		accent,
		4.0
	))
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 7.0
	icon.offset_top = 4.0
	icon.offset_right = -7.0
	icon.offset_bottom = -12.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture("res://assets/art/icons/defiance.png")
	icon.modulate = Color.WHITE if remaining > 0 else Color(0.55, 0.50, 0.60, 0.86)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	var count := Label.new()
	count.name = "DefianceCount"
	count.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	count.anchor_top = 1.0
	count.anchor_bottom = 1.0
	count.offset_top = -17.0
	count.offset_bottom = -2.0
	count.text = "%d/%d" % [remaining, capacity]
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(count, UiTypography.SIZE_CAPTION)
	count.add_theme_color_override("font_color", Color("ffe7a3") if remaining > 0 else Color("8d8296"))
	count.add_theme_color_override("font_outline_color", Color("160d19"))
	count.add_theme_constant_override("outline_size", 2)
	frame.add_child(count)
	return frame

func _selected_skill_ids_for_hud() -> Array[String]:
	if str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty():
		return _combat_engine.skill_ids(_combat_state)
	if not _run_state.is_empty():
		return _run_engine.run_skill_ids(_run_state)
	return ProgressionStore.selected_skill_ids(_progression)

func _baseline_run_skill_event_cursors() -> void:
	_run_skill_event_revision_seen = _run_engine.run_skill_event_revision(_run_state)

func _build_skill_sigil(skill_ids: Array[String]) -> Button:
	var button := Button.new()
	button.name = "SkillSigil"
	var compact: bool = ui_root != null and ui_root.get_global_rect().size.x < SKILL_SIGIL_COMPACT_VIEWPORT_WIDTH
	button.custom_minimum_size = SKILL_SIGIL_COMPACT_SIZE if compact else SKILL_SIGIL_SIZE
	button.text = ""
	button.tooltip_text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("header_utility", true)
	var ready_count: int = _skill_status_ready_count(skill_ids)
	var preview_ids: Array[String] = _skill_sigil_preview_ids(
		skill_ids,
		SKILL_SIGIL_COMPACT_PREVIEW_COUNT if compact else SKILL_SIGIL_PREVIEW_COUNT
	)
	button.set_meta("ready_count", ready_count)
	button.set_meta("owned_count", skill_ids.size())
	button.set_meta("preview_skill_ids", preview_ids)
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		var accent := Color("9b72cb")
		if state_name == "hover":
			accent = accent.lightened(0.18)
		elif state_name == "pressed":
			accent = accent.darkened(0.12)
		button.add_theme_stylebox_override(state_name, _skill_sigil_style(accent, state_name == "hover"))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 4 if compact else 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 4 if compact else 7)
	margin.add_theme_constant_override("margin_bottom", 5)
	button.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 3 if compact else 7)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)
	var copy := VBoxContainer.new()
	copy.custom_minimum_size = Vector2(80.0 if compact else 95.0, 0.0)
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", -2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(copy)
	var title := Label.new()
	title.name = "SkillSigilTitle"
	title.text = "ABILITIES"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(title, UiTypography.ROLE_BODY)
	title.add_theme_color_override("font_color", Color("f0e2ff"))
	copy.add_child(title)
	var summary := Label.new()
	summary.name = "SkillSigilSummary"
	summary.text = (
		"%d READY / %d" % [ready_count, skill_ids.size()]
		if compact
		else "%d READY  ·  %d OWNED" % [ready_count, skill_ids.size()]
	)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(summary, 10)
	summary.add_theme_color_override("font_color", Color("bfa7d7"))
	copy.add_child(summary)
	var previews := HBoxContainer.new()
	previews.name = "SkillSigilOwnedPreviews"
	previews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previews.alignment = BoxContainer.ALIGNMENT_END
	previews.add_theme_constant_override("separation", 3)
	previews.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(previews)
	for skill_id: String in preview_ids:
		var accent: Color = _skill_status_accent(_skill_hud_status(skill_id))
		var frame := PanelContainer.new()
		frame.name = "SkillSigilPreview_%s" % skill_id
		frame.custom_minimum_size = SKILL_SIGIL_PREVIEW_ICON_SIZE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", _skill_sigil_preview_style(accent))
		var icon := TextureRect.new()
		icon.texture = ActionIcons.icon_texture(SkillTreeLibrary.icon_key(skill_id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
		previews.add_child(frame)
	var expansion := Label.new()
	expansion.name = "SkillSigilExpansionIndicator"
	expansion.text = "›"
	expansion.visible = not compact
	expansion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	expansion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(expansion, UiTypography.ROLE_SECTION)
	expansion.add_theme_color_override("font_color", Color("d8c0ed"))
	content.add_child(expansion)
	button.pressed.connect(_toggle_skill_status_popover)
	return button

func _skill_status_ready_count(skill_ids: Array[String]) -> int:
	var result: int = 0
	for skill_id: String in skill_ids:
		if _skill_hud_status(skill_id) == "READY":
			result += 1
	return result

func _skill_sigil_preview_ids(skill_ids: Array[String], preview_count: int = SKILL_SIGIL_PREVIEW_COUNT) -> Array[String]:
	var result: Array[String]
	for skill_id: String in skill_ids:
		if _skill_hud_status(skill_id) == "READY":
			result.append(skill_id)
			if result.size() >= preview_count:
				return result
	for skill_id: String in skill_ids:
		if result.has(skill_id):
			continue
		result.append(skill_id)
		if result.size() >= preview_count:
			break
	return result

func _skill_sigil_preview_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("150d1c")
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0
	return style

func _skill_sigil_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("24172f") if not hovered else Color("342044")
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.25 if hovered else 0.13)
	style.shadow_size = 7 if hovered else 3
	return style

func _toggle_skill_status_popover() -> void:
	if _skill_status_scrim == null or _skill_status_popover == null:
		return
	if _skill_status_scrim.visible:
		_close_skill_status_popover()
		return
	_skill_status_return_focus = get_viewport().gui_get_focus_owner()
	if not _can_restore_gui_focus(_skill_status_return_focus):
		_skill_status_return_focus = _skill_sigil
	_skill_status_scrim.visible = true
	_skill_status_popover.visible = true
	_refresh_skill_status_popover(_selected_skill_ids_for_hud())
	_layout_skill_status_popover()
	call_deferred("_layout_skill_status_popover")
	call_deferred("_grab_skill_status_palette_focus")

func _layout_skill_status_popover() -> void:
	if _skill_status_popover == null or not _skill_status_popover.visible or _skill_sigil == null or not is_instance_valid(_skill_sigil):
		return
	var root_rect: Rect2 = ui_root.get_global_rect()
	var popover_size := Vector2(
		minf(SKILL_STATUS_POPOVER_SIZE.x, maxf(1.0, root_rect.size.x - 16.0)),
		minf(SKILL_STATUS_POPOVER_SIZE.y, maxf(1.0, root_rect.size.y - 16.0))
	)
	_skill_status_popover.custom_minimum_size = popover_size
	_skill_status_popover.size = popover_size
	var desired: Vector2 = root_rect.position + (root_rect.size - popover_size) * 0.5
	_skill_status_popover.global_position = desired

func _skill_status_page_count() -> int:
	return maxi(1, ceili(float(_skill_status_skill_ids.size()) / float(SKILL_STATUS_PAGE_SIZE)))

func _skill_status_visible_ids() -> Array[String]:
	var result: Array[String]
	var start_index: int = _skill_status_page * SKILL_STATUS_PAGE_SIZE
	var end_index: int = mini(start_index + SKILL_STATUS_PAGE_SIZE, _skill_status_skill_ids.size())
	for index: int in range(start_index, end_index):
		result.append(_skill_status_skill_ids[index])
	return result

func _on_skill_status_page_pressed(direction: int) -> void:
	var next_page: int = clampi(_skill_status_page + direction, 0, _skill_status_page_count() - 1)
	if next_page == _skill_status_page:
		return
	_skill_status_page = next_page
	var visible_ids: Array[String] = _skill_status_visible_ids()
	_skill_status_selected_id = visible_ids[0] if not visible_ids.is_empty() else ""
	_refresh_skill_status_popover(_skill_status_skill_ids)
	call_deferred("_grab_skill_status_palette_focus")

func _show_skill_status_page_for_skill(skill_id: String) -> void:
	var index: int = _skill_status_skill_ids.find(skill_id)
	if index < 0:
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and focus_owner.has_meta("skill_id"):
		focus_owner.release_focus()
	_skill_status_page = floori(float(index) / float(SKILL_STATUS_PAGE_SIZE))
	_skill_status_selected_id = skill_id
	_refresh_skill_status_popover(_skill_status_skill_ids)

func _refresh_skill_status_popover(skill_ids: Array[String]) -> void:
	_skill_status_skill_ids = SkillTreeLibrary.normalized_ids(skill_ids)
	if _skill_status_title != null:
		_skill_status_title.text = "ABILITIES"
	if _skill_status_summary != null:
		_skill_status_summary.text = "%d READY  ·  %d OWNED" % [
			_skill_status_ready_count(_skill_status_skill_ids),
			_skill_status_skill_ids.size()
		]
	if _skill_status_grid == null or _skill_status_popover == null or not _skill_status_popover.visible:
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var restore_skill_id: String = _skill_status_selected_id
	if focus_owner != null and focus_owner.has_meta("skill_id"):
		restore_skill_id = str(focus_owner.get_meta("skill_id", restore_skill_id))
	if not _skill_status_skill_ids.has(restore_skill_id):
		restore_skill_id = _skill_status_skill_ids[0] if not _skill_status_skill_ids.is_empty() else ""
		_skill_status_page = 0
	_skill_status_page = clampi(_skill_status_page, 0, _skill_status_page_count() - 1)
	var visible_ids: Array[String] = _skill_status_visible_ids()
	if not restore_skill_id.is_empty() and not visible_ids.has(restore_skill_id):
		restore_skill_id = visible_ids[0] if not visible_ids.is_empty() else ""
	_skill_status_selected_id = restore_skill_id
	var multiple_pages: bool = _skill_status_page_count() > 1
	if _skill_status_page_label != null:
		_skill_status_page_label.text = "%d / %d" % [_skill_status_page + 1, _skill_status_page_count()]
		_skill_status_page_label.visible = multiple_pages
	if _skill_status_previous_page != null:
		_skill_status_previous_page.visible = multiple_pages
		_skill_status_previous_page.disabled = _skill_status_page <= 0
		_skill_status_previous_page.focus_mode = Control.FOCUS_ALL if multiple_pages and not _skill_status_previous_page.disabled else Control.FOCUS_NONE
	if _skill_status_next_page != null:
		_skill_status_next_page.visible = multiple_pages
		_skill_status_next_page.disabled = _skill_status_page >= _skill_status_page_count() - 1
		_skill_status_next_page.focus_mode = Control.FOCUS_ALL if multiple_pages and not _skill_status_next_page.disabled else Control.FOCUS_NONE
	_clear_children_now(_skill_status_grid)
	_skill_status_tiles.clear()
	for skill_id: String in visible_ids:
		var tile := Button.new()
		tile.name = "SkillStatusTile_%s" % skill_id
		tile.custom_minimum_size = SKILL_STATUS_TILE_SIZE
		tile.focus_mode = Control.FOCUS_ALL
		tile.text = ""
		tile.tooltip_text = ""
		tile.set_meta("skill_id", skill_id)
		var status: String = _skill_hud_status(skill_id)
		var accent: Color = _skill_status_accent(status)
		tile.set_meta("skill_status", status)
		tile.set_meta("icon_key", SkillTreeLibrary.icon_key(skill_id))
		for style_name: String in ["normal", "disabled"]:
			tile.add_theme_stylebox_override(style_name, _skill_status_tile_style(accent, skill_id == _skill_status_selected_id))
		for style_name: String in ["hover", "pressed", "focus"]:
			tile.add_theme_stylebox_override(style_name, _skill_status_tile_style(accent, true, style_name == "focus"))
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.pressed.connect(_on_skill_status_tile_pressed.bind(skill_id))
		tile.focus_entered.connect(_on_skill_status_tile_focused.bind(skill_id))
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 4)
		tile.add_child(margin)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		margin.add_child(column)
		var icon_center := CenterContainer.new()
		icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(icon_center)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48.0, 48.0)
		icon.texture = ActionIcons.icon_texture(SkillTreeLibrary.icon_key(skill_id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_center.add_child(icon)
		var name_label := Label.new()
		name_label.name = "SkillStatusName_%s" % skill_id
		name_label.text = SkillTreeLibrary.display_name(skill_id)
		name_label.custom_minimum_size = Vector2(0.0, 30.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = 2
		name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		UiTypography.apply_label_role(name_label, UiTypography.ROLE_CAPTION)
		name_label.add_theme_color_override("font_color", Color("e8def0"))
		column.add_child(name_label)
		var state_glyph := Label.new()
		state_glyph.text = _skill_status_glyph(status)
		state_glyph.position = Vector2(SKILL_STATUS_TILE_SIZE.x - 24.0, 4.0)
		state_glyph.size = Vector2(18.0, 18.0)
		state_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.apply_label_role(state_glyph, UiTypography.ROLE_CAPTION)
		state_glyph.add_theme_color_override("font_color", accent)
		tile.add_child(state_glyph)
		_skill_status_grid.add_child(tile)
		_skill_status_tiles[skill_id] = tile
	_refresh_skill_status_detail()
	_configure_skill_status_focus_neighbors()
	call_deferred("_restore_skill_status_popover_state", restore_skill_id)

func _configure_skill_status_focus_neighbors() -> void:
	if _skill_status_close_button == null or _skill_status_grid == null:
		return
	var tiles: Array[Control]
	for skill_id: String in _skill_status_visible_ids():
		var tile: Control = _skill_status_tiles.get(skill_id, null) as Control
		if tile != null:
			tiles.append(tile)
	if tiles.is_empty():
		_skill_status_close_button.focus_neighbor_top = NodePath()
		_skill_status_close_button.focus_neighbor_bottom = NodePath()
		return
	var page_focus: Control = null
	if _can_restore_gui_focus(_skill_status_next_page):
		page_focus = _skill_status_next_page
	elif _can_restore_gui_focus(_skill_status_previous_page):
		page_focus = _skill_status_previous_page
	var action_focus: Control = _skill_status_action_button if _can_restore_gui_focus(_skill_status_action_button) else null
	var bottom_target: Control = page_focus if page_focus != null else (action_focus if action_focus != null else tiles[tiles.size() - 1])
	_set_skill_status_focus_neighbor(_skill_status_close_button, "down", tiles[0])
	_set_skill_status_focus_neighbor(_skill_status_close_button, "up", action_focus if action_focus != null else bottom_target)
	for index: int in range(tiles.size()):
		var tile: Control = tiles[index]
		var column_index: int = index % SKILL_STATUS_GRID_COLUMNS
		var up_target: Control = _skill_status_close_button if index < SKILL_STATUS_GRID_COLUMNS else tiles[index - SKILL_STATUS_GRID_COLUMNS]
		var down_index: int = index + SKILL_STATUS_GRID_COLUMNS
		var down_target: Control = tiles[down_index] if down_index < tiles.size() else bottom_target
		var left_target: Control = tiles[index - 1] if column_index > 0 else tile
		var right_target: Control = tiles[index + 1] if column_index < SKILL_STATUS_GRID_COLUMNS - 1 and index + 1 < tiles.size() else tile
		_set_skill_status_focus_neighbor(tile, "up", up_target)
		_set_skill_status_focus_neighbor(tile, "down", down_target)
		_set_skill_status_focus_neighbor(tile, "left", left_target)
		_set_skill_status_focus_neighbor(tile, "right", right_target)
	if page_focus != null:
		var page_down_target: Control = action_focus if action_focus != null else _skill_status_close_button
		var page_buttons: Array[Button]
		page_buttons.append(_skill_status_previous_page)
		page_buttons.append(_skill_status_next_page)
		for page_button: Button in page_buttons:
			if not _can_restore_gui_focus(page_button):
				continue
			_set_skill_status_focus_neighbor(page_button, "up", tiles[tiles.size() - 1])
			_set_skill_status_focus_neighbor(page_button, "down", page_down_target)
			_set_skill_status_focus_neighbor(
				page_button,
				"left",
				_skill_status_previous_page if _can_restore_gui_focus(_skill_status_previous_page) else page_button
			)
			_set_skill_status_focus_neighbor(
				page_button,
				"right",
				_skill_status_next_page if _can_restore_gui_focus(_skill_status_next_page) else page_button
			)
	if action_focus != null:
		var selected_tile: Control = _skill_status_tiles.get(_skill_status_selected_id, tiles[0]) as Control
		_set_skill_status_focus_neighbor(action_focus, "up", page_focus if page_focus != null else selected_tile)
		_set_skill_status_focus_neighbor(action_focus, "down", _skill_status_close_button)
		_set_skill_status_focus_neighbor(action_focus, "left", action_focus)
		_set_skill_status_focus_neighbor(action_focus, "right", _skill_status_close_button)

func _set_skill_status_focus_neighbor(source: Control, direction: String, target: Control) -> void:
	if source == null or target == null or not source.is_inside_tree() or not target.is_inside_tree():
		return
	var target_path: NodePath = source.get_path_to(target)
	match direction:
		"left":
			source.focus_neighbor_left = target_path
		"right":
			source.focus_neighbor_right = target_path
		"up":
			source.focus_neighbor_top = target_path
		"down":
			source.focus_neighbor_bottom = target_path

func _restore_skill_status_popover_state(skill_id: String) -> void:
	if _skill_status_popover == null or not _skill_status_popover.visible:
		return
	if skill_id.is_empty():
		return
	var tile: Control = _skill_status_tiles.get(skill_id, null) as Control
	if tile != null:
		tile.grab_focus()

func _grab_skill_status_palette_focus() -> void:
	var tile: Control = _skill_status_tiles.get(_skill_status_selected_id, null) as Control
	_grab_preferred_gui_focus(tile, _skill_status_close_button)

func _on_skill_status_tile_pressed(skill_id: String) -> void:
	_select_skill_status_skill(skill_id)

func _on_skill_status_tile_focused(skill_id: String) -> void:
	_select_skill_status_skill(skill_id)

func _select_skill_status_skill(skill_id: String) -> void:
	if not _skill_status_skill_ids.has(skill_id):
		return
	_skill_status_selected_id = skill_id
	_refresh_skill_status_detail()
	_configure_skill_status_focus_neighbors()

func _refresh_skill_status_detail() -> void:
	if _skill_status_selected_id.is_empty() or not _skill_status_skill_ids.has(_skill_status_selected_id):
		if _skill_status_detail_title != null:
			_skill_status_detail_title.text = "No abilities learned"
		if _skill_status_detail_status != null:
			_skill_status_detail_status.text = ""
		if _skill_status_detail_description != null:
			_skill_status_detail_description.text = "Learn abilities at campfires to add them here."
		if _skill_status_action_button != null:
			_skill_status_action_button.visible = false
			_skill_status_action_button.focus_mode = Control.FOCUS_NONE
		return
	var status: String = _skill_hud_status(_skill_status_selected_id)
	var accent: Color = _skill_status_accent(status)
	if _skill_status_detail_icon != null:
		_skill_status_detail_icon.texture = ActionIcons.icon_texture(SkillTreeLibrary.icon_key(_skill_status_selected_id))
	if _skill_status_detail_title != null:
		_skill_status_detail_title.text = SkillTreeLibrary.display_name(_skill_status_selected_id)
	if _skill_status_detail_status != null:
		_skill_status_detail_status.text = status
		_skill_status_detail_status.add_theme_color_override("font_color", accent)
	if _skill_status_detail_description != null:
		_skill_status_detail_description.text = SkillTreeLibrary.description(_skill_status_selected_id)
	for skill_id: String in _skill_status_skill_ids:
		var tile: Button = _skill_status_tiles.get(skill_id, null) as Button
		if tile == null:
			continue
		var tile_accent: Color = _skill_status_accent(_skill_hud_status(skill_id))
		tile.add_theme_stylebox_override("normal", _skill_status_tile_style(tile_accent, skill_id == _skill_status_selected_id))
	if _skill_status_action_button != null:
		var activatable: bool = _combat_skill_is_activatable(_skill_status_selected_id)
		var activation: String = SkillTreeLibrary.activation_kind(_skill_status_selected_id)
		var manual: bool = activation == "manual"
		_skill_status_action_button.visible = manual
		_skill_status_action_button.focus_mode = Control.FOCUS_ALL if manual and activatable else Control.FOCUS_NONE
		_skill_status_action_button.disabled = not activatable
		_skill_status_action_button.text = "Activate" if activatable else status.capitalize()
		var variant: String = UiSkin.VARIANT_SELECTED if activatable else UiSkin.VARIANT_STANDARD
		_ui_skin.apply_button_stylebox_overrides(_skill_status_action_button, variant)
		_ui_skin.apply_button_text_overrides(_skill_status_action_button)

func _on_skill_status_action_pressed() -> void:
	if _combat_skill_is_activatable(_skill_status_selected_id):
		_on_combat_skill_pressed(_skill_status_selected_id)

func _combat_skill_is_activatable(skill_id: String) -> bool:
	return (
		SkillTreeLibrary.activation_kind(skill_id) == "manual"
		and _combat_skill_activation_surface_available()
		and _combat_engine.skill_is_ready(_combat_state, skill_id)
	)

func _combat_skill_activation_surface_available() -> bool:
	return (
		str(_run_state.get("mode", "room")) == "combat"
		and not _combat_state.is_empty()
		and not _animation_lock
		and _combat_engine.is_player_turn(_combat_state)
		and _selected_card_index < 0
		and _card_action_choice_index < 0
		and _drag_card_index < 0
		and not _pending_umbra_commit_locked
		and _combat_skill_card_selection_zone.is_empty()
	)

func _skill_hud_status(skill_id: String) -> String:
	var effect: Dictionary = SkillTreeLibrary.effect(skill_id)
	var effect_type: String = SkillTreeLibrary.effect_type(skill_id)
	var activation: String = SkillTreeLibrary.activation_kind(skill_id)
	var mode: String = str(_run_state.get("mode", "room"))
	var run_skill_state: Dictionary = _run_state.get(RunEngineScript.SKILL_STATE_KEY, {}) as Dictionary
	var combat_scoped: bool = activation == "manual" or effect.has("uses_per_combat") or effect.has("uses_per_turn")
	if effect.has("uses_per_sequence") and _run_engine.run_skill_used_this_sequence(_run_state, skill_id):
		return "SPENT"
	if mode == "combat" and not _combat_state.is_empty():
		var flags: Dictionary = _combat_state.get("skill_flags", {}) as Dictionary
		if effect_type == "arm_intensity" and bool(flags.get("prismatic_armed", false)):
			return "ARMED"
		if effect_type == "preserve_burn" and bool(flags.get("burn_preserve_armed", false)):
			return "ARMED"
		if effect_type == "preserve_fallback_item" and bool(flags.get("item_preserve_armed", false)):
			return "ARMED"
		if effect_type == "convert_block" and bool(flags.get("guard_carry_armed", false)):
			return "ARMED"
		if effect_type == "pain_recall" and bool(flags.get("pain_recall_primed", false)):
			return "PRIMED"
		if effect_type == "bank_unused_play" and _combat_engine.has_skill(_combat_state, skill_id) and (int(_combat_state.get("banked_plays", 0)) > 0 or int(_combat_engine.card_play_budget(_combat_state).get("banked_remaining", 0)) > 0):
			return "BANKED"
		if effect_type == "banked_play_no_time" and _combat_engine.has_skill(_combat_state, skill_id):
			if _combat_engine.skill_was_used(_combat_state, skill_id):
				return "SPENT"
			if int(_combat_engine.card_play_budget(_combat_state).get("banked_remaining", 0)) > 0:
				return "PRIMED"
		if not combat_scoped and not effect.has("uses_per_sequence") and activation in ["automatic", "passive"]:
			return "AUTOMATIC" if activation == "automatic" else "PASSIVE"
		if combat_scoped:
			if effect.has("uses_per_turn"):
				var turn_key: String = "turn:%s" % skill_id
				return "SPENT" if int(flags.get(turn_key, -1)) == int(_combat_state.get("turn", 1)) else "WAITING"
			if _combat_engine.skill_was_used(_combat_state, skill_id):
				return "SPENT"
			if activation in ["manual", "contextual"]:
				return "READY" if _combat_engine.skill_is_ready(_combat_state, skill_id) else "WAITING"
			if effect.has("uses_per_combat"):
				return "WAITING"
	if effect_type == "defer_card_reward" and not str(run_skill_state.get("pending_card", "")).is_empty():
		return "PRIMED"
	if effect_type == "defer_relic" and not str(run_skill_state.get("pending_relic", "")).is_empty():
		return "PRIMED"
	if effect_type == "defer_card_reward":
		var reward_cards: Array = ((_run_state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array)
		return "READY" if mode == "reward" and not reward_cards.is_empty() else "WAITING"
	if effect_type == "defer_relic":
		return "READY" if mode == "treasure" and (_run_state.get("pending_relics", []) as Array).size() > 1 else "WAITING"
	if effect_type == "choose_start":
		return "READY" if mode == "pre_battle" and not _run_engine.pre_battle_start_tiles(_run_state).is_empty() else "WAITING"
	if effect.has("uses_per_sequence"):
		if effect_type == "reserve_merchant_offer" and not (run_skill_state.get("reserved_merchant", {}) as Dictionary).is_empty():
			return "WAITING"
		if _run_engine.run_skill_used_this_sequence(_run_state, skill_id):
			return "SPENT"
		if activation == "automatic":
			return "WAITING"
		if effect_type == "reward_reroll" and mode == "reward":
			return "READY"
		if mode == "room" and effect_type == "reserve_merchant_offer" and not _run_engine.merchant_kind_for_current_room(_run_state).is_empty():
			return "READY"
		return "WAITING"
	if activation == "contextual":
		return "WAITING"
	if activation == "automatic":
		return "AUTOMATIC"
	return "PASSIVE"

func _skill_status_accent(status: String) -> Color:
	match status:
		"READY":
			return Color("8fe4b0")
		"SPENT":
			return Color("9b8ea8")
		"WAITING":
			return Color("d7b36d")
		"ARMED", "PRIMED", "BANKED":
			return Color("d8a2ff")
		"AUTOMATIC":
			return Color("9fc9f4")
	return Color("c8a6ed")

func _skill_status_glyph(status: String) -> String:
	match status:
		"READY":
			return "!"
		"SPENT":
			return "×"
		"ARMED", "PRIMED":
			return "◆"
		"BANKED":
			return "+"
		"AUTOMATIC":
			return "↻"
		"PASSIVE":
			return "∞"
	return "·"

func _skill_status_tile_style(accent: Color, selected: bool = false, focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2c1c36") if selected else Color("1c1422")
	style.border_color = accent.lightened(0.16) if focused else accent
	style.set_border_width_all(3 if selected or focused else 1)
	style.set_corner_radius_all(7)
	if focused:
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.34)
		style.shadow_size = 6
	return style

func _skill_status_row_style(accent: Color, focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.11, 0.21, 0.98) if focused else Color(0.12, 0.08, 0.15, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.96 if focused else 0.62)
	style.border_width_left = 3
	if focused:
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	style.set_corner_radius_all(6)
	return style

func _pulse_skill_sigil() -> void:
	if _skill_sigil == null or not is_instance_valid(_skill_sigil):
		return
	_skill_sigil.pivot_offset = _skill_sigil.size * 0.5
	var tween := create_tween()
	tween.tween_property(_skill_sigil, "scale", Vector2(1.16, 1.16), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_skill_sigil, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _pulse_defiance_badge() -> void:
	if _defiance_badge == null or not is_instance_valid(_defiance_badge):
		return
	_defiance_badge.pivot_offset = _defiance_badge.size * 0.5
	var tween := create_tween()
	tween.tween_property(_defiance_badge, "scale", Vector2(1.20, 1.20), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_defiance_badge, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _setup_turn_order_bar() -> void:
	if _turn_order_panel != null:
		return
	_turn_order_anchor = CenterContainer.new()
	_turn_order_anchor.name = "TurnOrderAnchor"
	_turn_order_anchor.visible = false
	_turn_order_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_order_anchor.z_index = 35
	ui_root.add_child(_turn_order_anchor)
	_layout_turn_order_anchor()
	_turn_order_panel = PanelContainer.new()
	_turn_order_panel.name = "TurnOrderPanel"
	_turn_order_panel.visible = false
	_turn_order_panel.custom_minimum_size = TURN_ORDER_PANEL_MIN_SIZE
	_turn_order_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_turn_order_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_turn_order_panel.set_meta("panel_safe_inset", 0.0)
	_turn_order_panel.add_theme_stylebox_override("panel", _turn_order_panel_style())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 10)
	_turn_order_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	_turn_order_header_host = Control.new()
	_turn_order_header_host.name = "TurnOrderHeaderHost"
	_turn_order_header_host.custom_minimum_size = Vector2(TURN_ORDER_LABEL_WIDTH, TURN_ORDER_PORTRAIT_SIZE.y)
	_turn_order_header_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_turn_order_header_host)
	_turn_order_label = Label.new()
	_turn_order_label.name = "TurnClockLabel"
	_turn_order_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_order_label.anchor_right = 1.0
	_turn_order_label.anchor_bottom = 1.0
	_turn_order_label.text = "TURN\nCLOCK"
	_turn_order_label.offset_left = 20.0
	_turn_order_label.offset_right = -8.0
	_turn_order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_turn_order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_order_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_turn_order_label, UiTypography.SIZE_SECTION)
	_turn_order_label.add_theme_color_override("font_color", Color("f5dfb3"))
	_turn_order_label.add_theme_color_override("font_outline_color", Color("21150f"))
	_turn_order_label.add_theme_constant_override("outline_size", 2)
	_turn_order_header_host.add_child(_turn_order_label)
	_setup_turn_order_boss_dossier()
	_turn_order_bar = Control.new()
	_turn_order_bar.name = "TurnOrderBar"
	_turn_order_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_order_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_turn_order_bar.custom_minimum_size = TURN_ORDER_PORTRAIT_SIZE
	row.add_child(_turn_order_bar)
	_turn_order_anchor.add_child(_turn_order_panel)
	_ui_skin.apply_panel_surface(_turn_order_panel, UiSkin.SURFACE_HUD)

func _setup_turn_order_boss_dossier() -> void:
	_turn_order_boss_dossier = PanelContainer.new()
	_turn_order_boss_dossier.name = "BossDossier"
	_turn_order_boss_dossier.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_order_boss_dossier.anchor_right = 1.0
	_turn_order_boss_dossier.anchor_bottom = 1.0
	_turn_order_boss_dossier.visible = false
	_turn_order_boss_dossier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_order_boss_dossier.add_theme_stylebox_override("panel", _turn_order_boss_dossier_style(Color("d36a55")))
	_turn_order_header_host.add_child(_turn_order_boss_dossier)
	var dossier_margin := MarginContainer.new()
	dossier_margin.add_theme_constant_override("margin_left", 8)
	dossier_margin.add_theme_constant_override("margin_top", 3)
	dossier_margin.add_theme_constant_override("margin_right", 8)
	dossier_margin.add_theme_constant_override("margin_bottom", 3)
	_turn_order_boss_dossier.add_child(dossier_margin)
	var dossier_stack := VBoxContainer.new()
	dossier_stack.add_theme_constant_override("separation", 1)
	dossier_margin.add_child(dossier_stack)
	var kicker := Label.new()
	kicker.name = "BossDossierKicker"
	kicker.text = "TURN CLOCK  ·  BOSS"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(kicker, UiTypography.SIZE_CAPTION)
	kicker.add_theme_color_override("font_color", Color("d8b96f"))
	kicker.add_theme_color_override("font_outline_color", Color("160e0a"))
	kicker.add_theme_constant_override("outline_size", 1)
	dossier_stack.add_child(kicker)
	_turn_order_boss_name = Label.new()
	_turn_order_boss_name.name = "BossName"
	_turn_order_boss_name.custom_minimum_size = Vector2(0.0, 32.0)
	_turn_order_boss_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_turn_order_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_turn_order_boss_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_order_boss_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_order_boss_name.max_lines_visible = 2
	_turn_order_boss_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_turn_order_boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_turn_order_boss_name, UiTypography.SIZE_BODY)
	_turn_order_boss_name.add_theme_color_override("font_color", Color("ffe66d"))
	_turn_order_boss_name.add_theme_color_override("font_outline_color", Color("120b07"))
	_turn_order_boss_name.add_theme_constant_override("outline_size", 2)
	dossier_stack.add_child(_turn_order_boss_name)
	_turn_order_boss_health_host = Control.new()
	_turn_order_boss_health_host.name = "BossHealthHost"
	_turn_order_boss_health_host.custom_minimum_size = Vector2(0.0, TURN_ORDER_BOSS_HEALTH_HEIGHT)
	_turn_order_boss_health_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier_stack.add_child(_turn_order_boss_health_host)
	_turn_order_boss_health_bar = SegmentedHealthBar.new()
	_turn_order_boss_health_bar.name = "BossHealthBar"
	_turn_order_boss_health_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_order_boss_health_bar.anchor_right = 1.0
	_turn_order_boss_health_bar.anchor_bottom = 1.0
	_turn_order_boss_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_order_boss_health_bar.set_fill(Color("b83d3a"), Color("f5efdf"))
	_turn_order_boss_health_bar.set_appearance(Color("1a1110"), Color("f5d96c"), Color(0.0, 0.0, 0.0, 0.38))
	_turn_order_boss_health_bar.separator_width = 1.0
	_turn_order_boss_health_bar.border_width = 1.0
	_turn_order_boss_health_host.add_child(_turn_order_boss_health_bar)
	_turn_order_boss_damage_preview = ColorRect.new()
	_turn_order_boss_damage_preview.name = "BossDamagePreview"
	_turn_order_boss_damage_preview.anchor_top = 0.0
	_turn_order_boss_damage_preview.anchor_bottom = 1.0
	_turn_order_boss_damage_preview.offset_top = 1.0
	_turn_order_boss_damage_preview.offset_bottom = -1.0
	_turn_order_boss_damage_preview.color = Color(1.0, 0.72, 0.34, 0.76)
	_turn_order_boss_damage_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_order_boss_damage_preview.visible = false
	_turn_order_boss_health_host.add_child(_turn_order_boss_damage_preview)
	_turn_order_boss_hp_label = Label.new()
	_turn_order_boss_hp_label.name = "BossHpLabel"
	_turn_order_boss_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_order_boss_hp_label.anchor_right = 1.0
	_turn_order_boss_hp_label.anchor_bottom = 1.0
	_turn_order_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_order_boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_order_boss_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_order_boss_hp_label.z_index = 2
	UiTypography.set_label_size(_turn_order_boss_hp_label, 10)
	_turn_order_boss_hp_label.add_theme_color_override("font_color", Color("fff4dc"))
	_turn_order_boss_hp_label.add_theme_color_override("font_outline_color", Color("140f0b"))
	_turn_order_boss_hp_label.add_theme_constant_override("outline_size", 1)
	_turn_order_boss_health_host.add_child(_turn_order_boss_hp_label)

func _refresh_turn_order_bar() -> void:
	if _turn_order_bar == null:
		return
	if _turn_order_animating:
		return
	var mode: String = str(_run_state.get("mode", "room"))
	if mode != "combat" or _combat_state.is_empty():
		_refresh_turn_order_boss_dossier({}, {})
		_clear_children(_turn_order_bar)
		_turn_order_source_signature = "<unset>"
		_turn_order_render_signature = "<unset>"
		_turn_order_panel_locked_width = -1.0
		_set_turn_order_visible(false)
		return
	_refresh_turn_order_boss_dossier(_board_display_state(), _board_presentation)
	var source_signature: String = "%d|%d|%d|%d|%d" % [
		_combat_preview_revision,
		hash(_combat_state),
		_selected_card_index,
		_hovered_card_index,
		1 if _animation_lock else 0
	]
	if source_signature == _turn_order_source_signature:
		return
	_turn_order_source_signature = source_signature
	var entries: Array[Dictionary] = _combat_engine.current_turn_order(_turn_order_display_state(), TURN_ORDER_MAX_SLOTS)
	_set_turn_order_bar_entries(entries)

func _turn_order_display_state() -> Dictionary:
	var preview: Dictionary = _turn_order_card_time_preview()
	if preview.is_empty():
		return _combat_state
	# The turn-order projection only reads nested combat data. A shallow shell is
	# sufficient for its two transient top-level fields and avoids cloning the
	# complete combat snapshot on every hover/UI refresh.
	var state: Dictionary = _combat_state.duplicate()
	state["turn_order_preview_time_delta"] = int(preview.get("time", 0))
	state["turn_order_preview_card_name"] = str(preview.get("name", ""))
	return state

func _turn_order_card_time_preview() -> Dictionary:
	if _animation_lock or _combat_state.is_empty() or not _combat_engine.is_player_turn(_combat_state):
		return {}
	var index: int = _selected_card_index if _selected_card_index >= 0 else _hovered_card_index
	if index < 0:
		return {}
	if not bool(_card_play_options_for_index(index).get("any_playable", false)):
		return {}
	var card_id: String = _card_id_for_hand_index(index)
	if card_id.is_empty():
		return {}
	var card: Dictionary = _card_def(card_id, _combat_state)
	return {
		"time": _combat_engine.card_time_cost_from_def(card),
		"name": str(card.get("name", card_id))
	}

func _set_turn_order_bar_entries(entries: Array[Dictionary]) -> void:
	if _turn_order_bar == null:
		return
	var signature: String = _turn_order_signature(entries)
	if not _turn_order_animating and signature == _turn_order_render_signature:
		return
	_turn_order_render_signature = signature
	_clear_children(_turn_order_bar)
	var entries_width: float = _turn_order_entries_width(entries.size())
	_turn_order_bar.custom_minimum_size = Vector2(entries_width, TURN_ORDER_PORTRAIT_SIZE.y)
	_turn_order_bar.size = _turn_order_bar.custom_minimum_size
	if _turn_order_panel != null:
		var panel_width: float = _turn_order_panel_locked_width if _turn_order_panel_locked_width > 0.0 else _turn_order_panel_width_for_count(entries.size())
		_turn_order_panel.custom_minimum_size = Vector2(panel_width, TURN_ORDER_PANEL_MIN_SIZE.y)
		_set_turn_order_visible(not entries.is_empty())
	for index: int in range(entries.size()):
		var slot: Control = _build_turn_order_slot(entries[index], index)
		slot.position = _turn_order_slot_position(index)
		_turn_order_bar.add_child(slot)

func _set_turn_order_visible(visible: bool) -> void:
	if _turn_order_panel != null:
		_turn_order_panel.visible = visible
	if _turn_order_anchor != null:
		_turn_order_anchor.visible = visible
	if visible:
		_layout_turn_order_anchor()

func _turn_order_entries_width(count: int) -> float:
	if count <= 0:
		return 0.0
	return float(count) * TURN_ORDER_PORTRAIT_SIZE.x + float(count - 1) * TURN_ORDER_SLOT_GAP

func _turn_order_panel_width_for_count(count: int) -> float:
	return maxf(TURN_ORDER_PANEL_MIN_WIDTH, 28.0 + _turn_order_header_width() + 12.0 + _turn_order_entries_width(count))

func _turn_order_header_width() -> float:
	if _turn_order_boss_dossier != null and _turn_order_boss_dossier.visible:
		return TURN_ORDER_BOSS_DOSSIER_WIDTH
	return TURN_ORDER_LABEL_WIDTH

func _refresh_turn_order_boss_dossier(display_state: Dictionary, source_presentation: Dictionary) -> void:
	if _turn_order_boss_dossier == null or _turn_order_header_host == null:
		return
	var boss: Dictionary = _boss_unit_for_turn_order_dossier(display_state)
	var visible: bool = not boss.is_empty()
	_turn_order_boss_dossier.visible = visible
	if _turn_order_label != null:
		_turn_order_label.visible = not visible
	_turn_order_header_host.custom_minimum_size = Vector2(
		TURN_ORDER_BOSS_DOSSIER_WIDTH if visible else TURN_ORDER_LABEL_WIDTH,
		TURN_ORDER_PORTRAIT_SIZE.y
	)
	if not visible:
		if _turn_order_boss_damage_preview != null:
			_turn_order_boss_damage_preview.visible = false
		return
	var boss_def: Dictionary = GameData.enemy_def(str(boss.get("type", "")))
	var boss_name: String = str(boss_def.get("name", boss.get("name", "Boss")))
	var preview: Dictionary = _boss_damage_preview_for_dossier(boss, source_presentation)
	var current_boss: Dictionary = boss
	if not preview.is_empty():
		var boss_id: int = int(boss.get("id", -1))
		for committed_var: Variant in _combat_state.get("enemies", []):
			if typeof(committed_var) != TYPE_DICTIONARY:
				continue
			var committed_enemy: Dictionary = committed_var
			if int(committed_enemy.get("id", -2)) == boss_id:
				current_boss = committed_enemy
				break
	var max_hp: int = maxi(1, int(current_boss.get("max_hp", boss.get("max_hp", 1))))
	var hp: int = clampi(int(current_boss.get("hp", boss.get("hp", 0))), 0, max_hp)
	var preview_hp: int = clampi(int(preview.get("hp", hp)), 0, max_hp)
	if _turn_order_boss_name != null:
		_turn_order_boss_name.text = boss_name
	if _turn_order_boss_health_bar != null:
		_turn_order_boss_health_bar.set_health(float(hp), float(max_hp))
		_turn_order_boss_health_bar.set_segment_count(_turn_order_boss_segment_count(max_hp))
	if _turn_order_boss_hp_label != null:
		_turn_order_boss_hp_label.text = "%d/%d" % [hp, max_hp]
	if _turn_order_boss_damage_preview != null:
		var current_ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
		var preview_ratio: float = clampf(float(preview_hp) / float(max_hp), 0.0, current_ratio)
		_turn_order_boss_damage_preview.anchor_left = preview_ratio
		_turn_order_boss_damage_preview.anchor_right = current_ratio
		_turn_order_boss_damage_preview.offset_left = 0.0
		_turn_order_boss_damage_preview.offset_right = 0.0
		_turn_order_boss_damage_preview.visible = preview_hp < hp
	var accent: Color = Color(str(boss_def.get("accent", "#d36a55")))
	_turn_order_boss_dossier.add_theme_stylebox_override("panel", _turn_order_boss_dossier_style(accent))

func _boss_unit_for_turn_order_dossier(display_state: Dictionary) -> Dictionary:
	for enemy_var: Variant in display_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		if bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)):
			return enemy
	return {}

func _boss_damage_preview_for_dossier(boss: Dictionary, source_presentation: Dictionary) -> Dictionary:
	var actor_key: String = _enemy_key(boss)
	var preview_map: Dictionary = source_presentation.get("damage_preview", {}) as Dictionary
	var effect: Dictionary = source_presentation.get("effect", {}) as Dictionary
	var effect_preview_map: Dictionary = effect.get("damage_preview", {}) as Dictionary
	if effect_preview_map.has(actor_key):
		return effect_preview_map.get(actor_key, {}) as Dictionary
	return preview_map.get(actor_key, {}) as Dictionary

func _turn_order_boss_segment_count(max_hp: int) -> int:
	return mini(TURN_ORDER_BOSS_MAX_SEGMENTS, SegmentedHealthBar.segment_count_for_max_hp(float(maxi(1, max_hp))))

func _turn_order_slot_position(index: int) -> Vector2:
	return Vector2(float(index) * (TURN_ORDER_PORTRAIT_SIZE.x + TURN_ORDER_SLOT_GAP), 0.0)

func _build_turn_order_slot(entry: Dictionary, index: int) -> Control:
	var active: bool = bool(entry.get("active", false))
	var slot_size: Vector2 = TURN_ORDER_ACTIVE_SIZE if active else TURN_ORDER_PORTRAIT_SIZE
	var frame := UiTooltipControl.new()
	frame.custom_minimum_size = slot_size
	frame.size = slot_size
	frame.clip_contents = false
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = TOOLTIP_ONLY_CURSOR_SHAPE if str(entry.get("kind", "")) == "enemy" and not bool(entry.get("hidden_by_umbra", false)) else Control.CURSOR_ARROW
	frame.tooltip_text = _turn_order_tooltip(entry, index)
	frame.set_meta("turn_order_key", _turn_order_entry_key(entry))
	frame.set_meta("turn_order_size", slot_size)
	frame.set_meta("turn_order_projected", bool(entry.get("projected", false)))
	frame.set_meta("turn_order_projection_card_name", str(entry.get("projected_card_name", "")))
	frame.set_meta("turn_order_projection_time_cost", int(entry.get("projected_time_cost", 0)))
	frame.set_meta("turn_order_tooltip", frame.tooltip_text)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _turn_order_slot_style(entry, active))
	frame.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	var inset: int = 5 if active else 6
	margin.add_theme_constant_override("margin_left", inset)
	margin.add_theme_constant_override("margin_top", inset)
	margin.add_theme_constant_override("margin_right", inset)
	margin.add_theme_constant_override("margin_bottom", inset)
	panel.add_child(margin)
	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = AssetLoader.load_texture(_turn_order_portrait_path(entry))
	portrait.modulate = _turn_order_portrait_modulate(entry, active)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(portrait)
	if _turn_order_is_card_preview_projection(entry):
		frame.add_child(_turn_order_projection_badge(entry))
	var badge_text: String = _turn_order_clock_badge_text(entry)
	frame.set_meta("turn_order_badge_text", badge_text)
	frame.add_child(_turn_order_number_badge(badge_text, entry, active))
	if str(entry.get("kind", "")) == "enemy" and not bool(entry.get("hidden_by_umbra", false)):
		var tile: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var actor_key: String = str(entry.get("actor_key", ""))
		frame.mouse_entered.connect(_on_turn_order_enemy_hovered.bind(tile, actor_key))
		frame.mouse_exited.connect(_on_turn_order_enemy_unhovered.bind(tile, actor_key))
	return frame

func _turn_order_clock_badge_text(entry: Dictionary) -> String:
	return str(_turn_order_relative_time(entry))

func _turn_order_is_card_preview_projection(entry: Dictionary) -> bool:
	return (
		bool(entry.get("projected", false))
		and str(entry.get("kind", "")) == "player"
		and int(entry.get("projected_time_cost", 0)) > 0
	)

func _turn_order_portrait_modulate(entry: Dictionary, active: bool) -> Color:
	if active:
		return Color.WHITE
	if _turn_order_is_card_preview_projection(entry):
		return Color(1.0, 1.0, 1.0, 0.98)
	if bool(entry.get("projected", false)):
		return Color(1.0, 1.0, 1.0, 0.74)
	return Color.WHITE

func _turn_order_projection_badge(entry: Dictionary) -> Control:
	var badge := PanelContainer.new()
	badge.name = "ProjectionPreviewBadge"
	badge.custom_minimum_size = Vector2(TURN_ORDER_PORTRAIT_SIZE.x - 8.0, 22.0)
	badge.size = badge.custom_minimum_size
	badge.position = Vector2(4.0, TURN_ORDER_PORTRAIT_SIZE.y - 26.0)
	badge.tooltip_text = _turn_order_tooltip(entry, 0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 8
	badge.add_theme_stylebox_override("panel", _turn_order_projection_badge_style())
	var label := Label.new()
	label.text = _turn_order_projection_badge_text(entry)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, 9)
	label.add_theme_color_override("font_color", Color("fff6ce"))
	label.add_theme_color_override("font_outline_color", Color("120b07"))
	label.add_theme_constant_override("outline_size", 1)
	badge.add_child(label)
	return badge

func _turn_order_projection_badge_text(entry: Dictionary) -> String:
	var preview_time: int = int(entry.get("projected_time_cost", 0))
	var card_name: String = str(entry.get("projected_card_name", "")).strip_edges()
	if card_name.is_empty():
		return "+%d time" % preview_time
	return "%s +%d" % [card_name, preview_time]

func _turn_order_projection_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.085, 0.035, 0.92)
	style.border_color = Color("f4c968")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

func _turn_order_number_badge(text: String, entry: Dictionary, active: bool) -> Control:
	var badge := PanelContainer.new()
	badge.position = Vector2(3.0, 3.0)
	var badge_size := Vector2(maxf(24.0, 12.0 + float(text.length()) * 8.0), 22.0)
	badge.custom_minimum_size = badge_size
	badge.size = badge_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _turn_order_number_badge_style(entry, active))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_SMALL if text.length() >= 3 else UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", Color("fff4d2"))
	label.add_theme_color_override("font_outline_color", Color("120b07"))
	label.add_theme_constant_override("outline_size", 1)
	badge.add_child(label)
	return badge

func _turn_order_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.035, 0.025, 0.86)
	style.border_color = Color(0.63, 0.43, 0.25, 0.78)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 7.0)
	return style

func _turn_order_boss_dossier_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.045, 0.035, 0.94)
	style.border_color = accent.lightened(0.28)
	style.border_color.a = 0.82
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style

func _turn_order_slot_style(entry: Dictionary, active: bool) -> StyleBoxFlat:
	var team: String = str(entry.get("team", "enemy"))
	var accent: Color = Color("5ca7e0") if team == "player" else Color("d36a55")
	if team == "enemy":
		var enemy_type: String = str(entry.get("type", ""))
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		if not enemy_def.is_empty():
			accent = Color(str(enemy_def.get("accent", "#d36a55")))
	var style := StyleBoxFlat.new()
	var projected: bool = bool(entry.get("projected", false)) and not active
	var card_preview_projected: bool = _turn_order_is_card_preview_projection(entry) and not active
	style.bg_color = Color(0.075, 0.050, 0.036, 0.94 if not projected else 0.78)
	style.border_color = accent.lightened(0.30 if active else 0.06)
	style.border_color.a = 0.95 if active else 0.74 if not projected else 0.52
	var border_width: int = 5 if active else 3 if not projected else 2
	if card_preview_projected:
		style.bg_color = Color(0.075, 0.105, 0.125, 0.96)
		style.border_color = Color("f4c968")
		style.border_color.a = 0.98
		border_width = 4
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34 if active else 0.26)
	style.shadow_size = 14 if active else 9
	style.shadow_offset = Vector2(0.0, 4.0)
	if card_preview_projected:
		style.shadow_color = Color(0.10, 0.32, 0.45, 0.48)
		style.shadow_size = 18
		style.shadow_offset = Vector2(0.0, 5.0)
	return style

func _turn_order_number_badge_style(entry: Dictionary, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var team: String = str(entry.get("team", "enemy"))
	var accent: Color = Color("5ca7e0") if team == "player" else Color("d36a55")
	style.bg_color = Color(0.05, 0.03, 0.02, 0.88)
	style.border_color = accent.lightened(0.18 if active else 0.02)
	if _turn_order_is_card_preview_projection(entry) and not active:
		style.bg_color = Color(0.055, 0.075, 0.090, 0.94)
		style.border_color = Color("f4c968")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style

func _turn_order_tooltip(entry: Dictionary, _index: int) -> String:
	var clock: int = int(entry.get("time", 0))
	var eta: int = _turn_order_relative_time(entry)
	var name: String = str(entry.get("name", "Actor"))
	var lines: Array[String] = []
	if eta <= 0:
		lines.append("Now: %s" % name)
	else:
		lines.append("+%d: %s" % [eta, name])
	if bool(entry.get("active", false)):
		lines.append("Acting now")
	else:
		lines.append("Acts in %d" % eta)
	if clock > 0:
		lines.append("Clock %d" % clock)
	if bool(entry.get("projected", false)):
		lines.append("Projected next turn")
	var base: int = int(entry.get("base_initiative", 0))
	if str(entry.get("kind", "")) == "enemy":
		var intent_time: int = int(entry.get("intent_time_cost", 0))
		if intent_time > 0:
			lines.append("Base %d + intent %d" % [base, intent_time])
		elif base > 0:
			lines.append("Base %d" % base)
	else:
		var spent: int = int(entry.get("turn_time_spent", 0))
		var preview_time: int = int(entry.get("projected_time_cost", 0))
		if preview_time > 0:
			var card_name: String = str(entry.get("projected_card_name", "")).strip_edges()
			if not card_name.is_empty():
				lines.append("Preview: %s (+%d time)" % [card_name, preview_time])
			else:
				lines.append("Preview: +%d time" % preview_time)
			lines.append("Base %d + played %d + preview %d" % [base, spent, preview_time])
		elif spent > 0:
			lines.append("Base %d + played %d" % [base, spent])
		elif base > 0:
			lines.append("Base %d" % base)
	return "\n".join(lines)

func _turn_order_relative_time(entry: Dictionary) -> int:
	if entry.has("eta"):
		return maxi(0, int(entry.get("eta", 0)))
	return maxi(0, int(entry.get("time", 0)) - int(_combat_state.get("initiative_clock", 0)))

func _turn_order_portrait_path(entry: Dictionary) -> String:
	if bool(entry.get("hidden_by_umbra", false)):
		return "res://assets/art/icons/umbra_presence.png"
	var key: String = "player" if str(entry.get("kind", "")) == "player" else str(entry.get("type", ""))
	if TURN_ORDER_PORTRAITS.has(key):
		return str(TURN_ORDER_PORTRAITS.get(key, ""))
	if str(entry.get("kind", "")) == "enemy":
		var enemy_art_path: String = str(GameData.enemy_def(key).get("art_path", ""))
		if not enemy_art_path.is_empty():
			return enemy_art_path
	return str(TURN_ORDER_PORTRAITS.get("player", ""))

func _on_turn_order_enemy_hovered(tile: Vector2i, actor_key: String) -> void:
	if tile.x < 0:
		return
	_turn_order_hovered_enemy_key = actor_key
	_hovered_board_tile = tile
	if _animation_lock:
		return
	_refresh_stage_view()

func _on_turn_order_enemy_unhovered(tile: Vector2i, actor_key: String) -> void:
	var hover_changed: bool = false
	if _turn_order_hovered_enemy_key == actor_key:
		_turn_order_hovered_enemy_key = ""
		hover_changed = true
	if _hovered_board_tile == tile:
		_hovered_board_tile = Vector2i(-1, -1)
		hover_changed = true
	if _animation_lock:
		return
	if hover_changed:
		_refresh_stage_view()

func _turn_order_entries_from_state(state: Dictionary) -> Array[Dictionary]:
	return _combat_engine.current_turn_order(state, TURN_ORDER_MAX_SLOTS)

func _turn_order_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_var: Variant in value:
		if typeof(entry_var) == TYPE_DICTIONARY:
			result.append((entry_var as Dictionary).duplicate(true))
	return result

func _turn_order_entry_key(entry: Dictionary) -> String:
	return "%s:%s:%d:%d" % [
		str(entry.get("kind", "")),
		str(entry.get("actor_key", "")),
		int(entry.get("time", 0)),
		int(entry.get("seq", 0))
	]

func _turn_order_signature(entries: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in entries:
		parts.append("%s:%s:%d:%d:%s:%s:%s" % [
			_turn_order_entry_key(entry),
			str(bool(entry.get("active", false))),
			int(entry.get("eta", -1)),
			int(entry.get("projected_time_cost", 0)),
			str(entry.get("projected_card_name", "")),
			str(entry.get("type", "")),
			str(entry.get("pos", Vector2i.ZERO))
		])
	return "|".join(parts)

func _turn_order_actor_key(entry: Dictionary) -> String:
	return "%s:%s" % [str(entry.get("kind", "")), str(entry.get("actor_key", ""))]

func _turn_order_animation_role(entry: Dictionary) -> String:
	if bool(entry.get("active", false)):
		return "active"
	if bool(entry.get("projected", false)):
		return "projected"
	return "scheduled"

func _turn_order_animation_base_key(entry: Dictionary) -> String:
	return "%s:%s" % [_turn_order_actor_key(entry), _turn_order_animation_role(entry)]

func _turn_order_active_removal_indices(before_order: Array[Dictionary]) -> Array:
	for index: int in range(before_order.size()):
		if bool(before_order[index].get("active", false)):
			return [index]
	return []

func _turn_order_index_set(indices: Array) -> Dictionary:
	var result: Dictionary = {}
	for index_var: Variant in indices:
		result[int(index_var)] = true
	return result

func _turn_order_is_activation_style_update(before_order: Array[Dictionary], after_order: Array[Dictionary]) -> bool:
	if before_order.is_empty() or after_order.is_empty():
		return false
	if bool(before_order[0].get("active", false)) or not bool(after_order[0].get("active", false)):
		return false
	return _turn_order_actor_key(before_order[0]) == _turn_order_actor_key(after_order[0])

func _turn_order_instance_keys(entries: Array[Dictionary], excluded_indices: Array = []) -> Array[String]:
	var counts: Dictionary = {}
	var keys: Array[String] = []
	var excluded: Dictionary = _turn_order_index_set(excluded_indices)
	for index: int in range(entries.size()):
		if bool(excluded.get(index, false)):
			keys.append("")
			continue
		var key: String = _turn_order_animation_base_key(entries[index])
		var occurrence: int = int(counts.get(key, 0))
		counts[key] = occurrence + 1
		keys.append("%s#%d" % [key, occurrence])
	return keys

func _turn_order_child_positions(entries: Array[Dictionary], excluded_indices: Array = []) -> Dictionary:
	var positions: Dictionary = {}
	if _turn_order_bar == null:
		return positions
	var keys: Array[String] = _turn_order_instance_keys(entries, excluded_indices)
	var count: int = mini(keys.size(), _turn_order_bar.get_child_count())
	for index: int in range(count):
		if keys[index].is_empty():
			continue
		var child: Control = _turn_order_bar.get_child(index) as Control
		if child != null:
			positions[keys[index]] = child.position
	return positions

func _animate_turn_order_transition_between_states(before_state: Dictionary, after_state: Dictionary) -> void:
	await _animate_turn_order_transition(_turn_order_entries_from_state(before_state), _turn_order_entries_from_state(after_state))

func _animate_turn_order_transition(before_order: Array[Dictionary], after_order: Array[Dictionary]) -> void:
	if _turn_order_bar == null:
		return
	if _turn_order_signature(before_order) == _turn_order_signature(after_order):
		return
	if before_order.is_empty():
		_set_turn_order_bar_entries(after_order)
		return
	if _turn_order_is_activation_style_update(before_order, after_order):
		_set_turn_order_bar_entries(after_order)
		await get_tree().create_timer(TURN_ORDER_STYLE_SECONDS).timeout
		return
	_turn_order_animating = true
	var working_order: Array[Dictionary] = _turn_order_array(before_order)
	_turn_order_panel_locked_width = maxf(_turn_order_panel_width_for_count(working_order.size()), _turn_order_panel_width_for_count(after_order.size()))
	_set_turn_order_bar_entries(working_order)
	await get_tree().process_frame
	var removed_indices: Array = _turn_order_active_removal_indices(working_order)
	if not removed_indices.is_empty():
		var remove_tween: Tween = null
		for index_var: Variant in removed_indices:
			var removed_index: int = int(index_var)
			if removed_index < 0 or removed_index >= _turn_order_bar.get_child_count():
				continue
			var removed_child: Control = _turn_order_bar.get_child(removed_index) as Control
			if removed_child == null:
				continue
			if remove_tween == null:
				remove_tween = create_tween().set_parallel(true)
			var removed_target_position: Vector2 = removed_child.position + Vector2(0.0, -TURN_ORDER_FLOAT_OFFSET)
			remove_tween.tween_property(removed_child, "position", removed_target_position, TURN_ORDER_REMOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			remove_tween.tween_property(removed_child, "modulate:a", 0.0, TURN_ORDER_REMOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if remove_tween != null:
			await remove_tween.finished
	var previous_positions: Dictionary = _turn_order_child_positions(working_order, removed_indices)
	var after_keys: Array[String] = _turn_order_instance_keys(after_order)
	_set_turn_order_bar_entries(after_order)
	await get_tree().process_frame
	var reflow_tween: Tween = null
	var inserted_slots: Array[Dictionary] = []
	var child_count: int = mini(after_order.size(), _turn_order_bar.get_child_count())
	for index: int in range(child_count):
		var child: Control = _turn_order_bar.get_child(index) as Control
		if child == null:
			continue
		var final_position: Vector2 = child.position
		var instance_key: String = after_keys[index]
		if previous_positions.has(instance_key):
			var previous_position: Vector2 = previous_positions[instance_key]
			var offset: Vector2 = previous_position - final_position
			if offset.length() > 0.5:
				child.position = final_position + offset
				if reflow_tween == null:
					reflow_tween = create_tween().set_parallel(true)
				reflow_tween.tween_property(child, "position", final_position, TURN_ORDER_REFLOW_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		else:
			child.modulate.a = 0.0
			child.position = final_position + Vector2(0.0, -TURN_ORDER_FLOAT_OFFSET)
			inserted_slots.append({
				"child": child,
				"position": final_position
			})
	if reflow_tween != null:
		await reflow_tween.finished
	else:
		await get_tree().create_timer(TURN_ORDER_STYLE_SECONDS).timeout
	if not inserted_slots.is_empty():
		var insert_tween: Tween = create_tween().set_parallel(true)
		for slot_var: Variant in inserted_slots:
			var slot: Dictionary = slot_var
			var inserted_child: Control = slot.get("child", null) as Control
			if inserted_child == null:
				continue
			var target_position: Vector2 = slot.get("position", inserted_child.position)
			insert_tween.tween_property(inserted_child, "position", target_position, TURN_ORDER_INSERT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			insert_tween.tween_property(inserted_child, "modulate:a", 1.0, TURN_ORDER_INSERT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await insert_tween.finished
	_turn_order_panel_locked_width = -1.0
	_set_turn_order_bar_entries(after_order)
	_turn_order_animating = false

func _refresh_pile_visuals() -> void:
	var piles: Dictionary = _deck_piles()
	var card_size: Vector2 = _pile_display_card_size()
	var signature: String = "%d|%d|%d|%d|%.2f,%.2f" % [
		_combat_preview_revision,
		hash(piles.get("draw", [])),
		hash(piles.get("discard", [])),
		hash(piles.get("burn", [])),
		card_size.x,
		card_size.y
	]
	if signature == _pile_visual_signature:
		return
	_pile_visual_signature = signature
	for kind: String in ["draw", "discard"]:
		var host: Control = _pile_visual_hosts.get(kind, null)
		if host == null:
			continue
		var cards: Array = (piles.get(kind, []) as Array).duplicate()
		_layout_pile_widget(kind, card_size)
		var badge: Label = _pile_badges.get(kind, null)
		if badge != null:
			badge.text = str(cards.size()) if kind == "draw" else ""
			badge.visible = kind == "draw"
		if kind == "draw":
			_populate_draw_pile(host, cards, card_size)
			continue
		_populate_discard_pile(host, cards, card_size)

func _refresh_card_play_meter() -> void:
	if _play_meter == null or _play_meter_count == null:
		return
	var mode: String = str(_run_state.get("mode", "room"))
	var active: bool = mode == "combat" and not _combat_state.is_empty()
	_play_meter.visible = active
	if not active:
		_play_meter_count.text = ""
		if _play_meter_banked_badge != null:
			_play_meter_banked_badge.visible = false
		return
	var budget: Dictionary = _displayed_card_play_budget()
	var ordinary_left: int = int(budget.get("ordinary_remaining", 0))
	var banked_left: int = int(budget.get("banked_remaining", 0))
	var cards_left: int = int(budget.get("total_remaining", ordinary_left + banked_left))
	_play_meter_count.text = str(ordinary_left)
	_play_meter.tooltip_text = "%d ordinary card %s remaining." % [ordinary_left, "play" if ordinary_left == 1 else "plays"]
	if _play_meter_banked_badge != null and _play_meter_banked_label != null:
		_play_meter_banked_badge.visible = banked_left > 0
		if banked_left > 0:
			var borrowed_id: String = SkillTreeLibrary.skill_id_for_effect("banked_play_no_time")
			var no_time: bool = _combat_engine.has_skill(_combat_state, borrowed_id) and not _combat_engine.skill_was_used(_combat_state, borrowed_id)
			_play_meter_banked_label.text = ("NEXT" if ordinary_left == 0 else "+%d BANKED" % banked_left) + (" • NO TIME" if no_time else "")
			if no_time and ordinary_left == 0:
				_play_meter.tooltip_text = "Your next card spends the banked play and adds no Time."
			elif no_time:
				_play_meter.tooltip_text = "%d ordinary %s remain first. The card that reaches the banked play adds no Time." % [ordinary_left, "play" if ordinary_left == 1 else "plays"]
			else:
				_play_meter.tooltip_text = "%d banked %s remain after your ordinary plays." % [banked_left, "play" if banked_left == 1 else "plays"]
	var meter_tint: Color = Color.WHITE if cards_left > 0 else Color(1.0, 1.0, 1.0, 0.42)
	_play_meter.modulate = meter_tint

func _refresh_action_step_tracker() -> void:
	if _action_step_tracker == null or _action_step_tracker_steps == null or _action_context_command_bar == null:
		return
	_clear_children_now(_action_step_tracker_steps)
	_clear_children_now(_action_context_command_bar)
	if _card_action_mode_selector != null:
		_clear_children_now(_card_action_mode_selector)
		_card_action_mode_selector.visible = false
	_drag_zone_panels.clear()
	_drag_zone_labels.clear()
	_drag_zone_detail_labels.clear()
	_action_step_tracker.set_meta("step_statuses", [])
	_action_step_tracker.set_meta("step_action_types", [])
	_action_step_tracker.set_meta("choice_card_index", -1)
	var tracker_state: Dictionary = _action_step_tracker_state()
	var active: bool = bool(tracker_state.get("active", false))
	_action_step_tracker.visible = active
	if _action_context_connector != null:
		_action_context_connector.visible = false
	if not active:
		if _action_step_tracker_title != null:
			_action_step_tracker_title.text = ""
		return
	var card_id: String = str(tracker_state.get("card_id", ""))
	var actions: Array = tracker_state.get("actions", [])
	var current_index: int = int(tracker_state.get("action_index", 0))
	var context_mode: String = str(tracker_state.get("mode", "selection"))
	var compact_header_mode: bool = context_mode == "drag"
	if _action_context_detail_row != null:
		_action_context_detail_row.visible = compact_header_mode
	if _action_context_status_row != null:
		_action_context_status_row.visible = false
	var selected_targets: Array[Vector2i] = _vector2i_array(tracker_state.get("selected_targets", []))
	var card: Dictionary = _card_def(card_id, _preview_combat_state if not _preview_combat_state.is_empty() else _combat_state)
	var current_number: int = clampi(current_index + 1, 1, maxi(1, actions.size()))
	if _action_step_tracker_title != null:
		_action_step_tracker_title.text = str(card.get("name", card_id))
	if _action_context_step_label != null:
		_action_context_step_label.visible = not compact_header_mode
		_action_context_step_label.text = "STEP %d/%d" % [current_number, maxi(1, actions.size())]
	var skipped_indices: Dictionary = _action_step_skipped_target_indices_for(actions, selected_targets)
	var statuses: Array = []
	var action_types: Array = []
	for index: int in range(0 if context_mode == "drag" else actions.size()):
		var action: Dictionary = {}
		if typeof(actions[index]) == TYPE_DICTIONARY:
			action = actions[index] as Dictionary
		var status: String = _action_step_status_for_index(index, current_index, skipped_indices)
		statuses.append(status)
		action_types.append(str(action.get("type", "")))
		_action_step_tracker_steps.add_child(_build_action_step_chip(index, action, status))
	_action_step_tracker.set_meta("step_statuses", statuses)
	_action_step_tracker.set_meta("step_action_types", action_types)
	_action_step_tracker.set_meta("context_mode", context_mode)
	_action_step_tracker.set_meta("choice_card_index", _card_action_choice_index if context_mode == "choice" else -1)
	_refresh_card_action_mode_selector(context_mode)
	_build_action_context_commands(tracker_state)
	_update_action_context_copy(tracker_state)
	_layout_action_step_tracker()
	call_deferred("_layout_action_step_tracker")

func _action_step_tracker_state() -> Dictionary:
	var mode: String = str(_run_state.get("mode", "room"))
	if mode != "combat":
		return {}
	if _action_step_resolution_active and _action_step_resolution_actions.size() > 1:
		return {
			"active": true,
			"mode": "resolution",
			"card_id": _action_step_resolution_card_id,
			"actions": _action_step_resolution_actions,
			"action_index": clampi(_action_step_resolution_index, 0, _action_step_resolution_actions.size()),
			"selected_targets": _action_step_resolution_targets
		}
	if _drag_card_index >= 0:
		var printed_preview: Dictionary = _drag_card_options.get("play", {})
		var drag_actions: Array = printed_preview.get("actions", [])
		if drag_actions.is_empty():
			drag_actions = _combat_engine.card_play_actions(_card_id_for_hand_index(_drag_card_index), _combat_state)
		return {
			"active": true,
			"mode": "drag",
			"card_id": _card_id_for_hand_index(_drag_card_index),
			"actions": drag_actions,
			"action_index": clampi(int(printed_preview.get("action_index", 0)), 0, maxi(0, drag_actions.size() - 1)),
			"selected_targets": []
		}
	if _card_action_choice_index >= 0:
		var choice_card_id: String = _card_id_for_hand_index(_card_action_choice_index)
		if choice_card_id.is_empty():
			return {}
		var active_preview: Dictionary = _card_action_choice_options.get(_card_action_choice_mode, {})
		var choice_actions: Array = active_preview.get("actions", [])
		if choice_actions.is_empty():
			choice_actions = _combat_engine.card_play_actions(choice_card_id, _combat_state)
		var choice_action_index: int = int(active_preview.get("action_index", 0))
		var choice_targets: Array[Vector2i] = []
		if _selected_card_index == _card_action_choice_index and not _pending_actions.is_empty():
			choice_actions = _pending_actions
			choice_action_index = _pending_action_index
			choice_targets = _pending_selected_targets
		return {
			"active": true,
			"mode": "choice",
			"card_id": choice_card_id,
			"actions": choice_actions,
			"action_index": choice_action_index,
			"selected_targets": choice_targets
		}
	if _selected_card_index < 0 or _pending_action_index >= _pending_actions.size():
		return {}
	return {
		"active": true,
		"mode": "selection",
		"card_id": _card_id_for_hand_index(_selected_card_index),
		"actions": _pending_actions,
		"action_index": _pending_action_index,
		"selected_targets": _pending_selected_targets
	}

func _action_step_skipped_target_indices_for(actions: Array, selected_targets: Array[Vector2i]) -> Dictionary:
	var skipped: Dictionary = {}
	var target_cursor: int = 0
	for index: int in range(actions.size()):
		var action: Dictionary = {}
		if typeof(actions[index]) == TYPE_DICTIONARY:
			action = actions[index] as Dictionary
		if not _combat_engine.player_action_needs_target(action):
			continue
		if target_cursor < selected_targets.size():
			var selected_tile: Vector2i = selected_targets[target_cursor]
			if selected_tile.x < 0:
				skipped[index] = true
		target_cursor += 1
	return skipped

func _action_step_status_for_index(index: int, current_index: int, skipped_indices: Dictionary) -> String:
	if bool(skipped_indices.get(index, false)):
		return "skipped"
	if index < current_index:
		return "done"
	if index == current_index:
		return "current"
	return "remaining"

func _layout_action_step_tracker() -> void:
	if _action_step_tracker == null or not _action_step_tracker.visible:
		if _action_context_connector != null:
			_action_context_connector.visible = false
		_layout_contextual_combat_prompt_overlay()
		return
	var tracker_size: Vector2 = _action_step_tracker.get_combined_minimum_size()
	if tracker_size.x <= 0.0 or tracker_size.y <= 0.0:
		tracker_size = ACTION_STEP_TRACKER_MIN_SIZE
	var viewport_size: Vector2 = get_viewport_rect().size
	tracker_size.x = minf(maxf(ACTION_STEP_TRACKER_MIN_SIZE.x, tracker_size.x), viewport_size.x - ACTION_CONTEXT_EDGE_MARGIN * 2.0)
	_action_step_tracker.size = tracker_size
	if _action_step_tracker_position_locked:
		_action_step_tracker.global_position = Vector2(
			clampf(_action_step_tracker_locked_position.x, ACTION_CONTEXT_EDGE_MARGIN, maxf(ACTION_CONTEXT_EDGE_MARGIN, viewport_size.x - tracker_size.x - ACTION_CONTEXT_EDGE_MARGIN)),
			clampf(_action_step_tracker_locked_position.y, ACTION_CONTEXT_EDGE_MARGIN, maxf(ACTION_CONTEXT_EDGE_MARGIN, viewport_size.y - tracker_size.y - ACTION_CONTEXT_EDGE_MARGIN))
		)
		_layout_contextual_combat_prompt_overlay()
		call_deferred("_layout_contextual_combat_prompt_overlay")
		return
	var anchor_rect: Rect2 = _action_step_tracker_anchor_rect()
	if anchor_rect.size.x <= 0.0 and anchor_rect.size.y <= 0.0:
		return
	var target_x: float = anchor_rect.get_center().x - tracker_size.x * 0.5
	target_x = clampf(target_x, ACTION_CONTEXT_EDGE_MARGIN, maxf(ACTION_CONTEXT_EDGE_MARGIN, viewport_size.x - tracker_size.x - ACTION_CONTEXT_EDGE_MARGIN))
	var minimum_y: float = maxf(ACTION_CONTEXT_EDGE_MARGIN, top_bar.get_global_rect().end.y + CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP)
	if _intensity_bar != null and _intensity_bar.visible:
		minimum_y = maxf(minimum_y, _intensity_bar.get_global_rect().end.y + CONTEXTUAL_COMBAT_PROMPT_EDGE_GAP)
	var target_y: float = anchor_rect.position.y - tracker_size.y - ACTION_STEP_TRACKER_GAP
	var maximum_y: float = maxf(minimum_y, viewport_size.y - tracker_size.y - ACTION_CONTEXT_EDGE_MARGIN)
	target_y = clampf(target_y, minimum_y, maximum_y)
	_action_step_tracker.global_position = Vector2(target_x, target_y)
	if _action_context_connector != null:
		_action_context_connector.visible = false
	_layout_contextual_combat_prompt_overlay()
	call_deferred("_layout_contextual_combat_prompt_overlay")

func _action_step_tracker_anchor_rect() -> Rect2:
	if _drag_card_index >= 0 and _drag_card_source_rect.size.x > 0.0 and _drag_card_source_rect.size.y > 0.0:
		return Rect2(
			Vector2(_drag_card_source_rect.get_center().x - 1.0, minf(_hand_visual_top(), _drag_card_source_rect.position.y)),
			Vector2(2.0, 1.0)
		)
	var active_card_index: int = _selected_card_index if _selected_card_index >= 0 else _card_action_choice_index
	if active_card_index >= 0:
		var selected_rect: Rect2 = _hand_card_global_rect(active_card_index)
		if selected_rect.size.x > 0.0 and selected_rect.size.y > 0.0:
			return Rect2(
				Vector2(selected_rect.get_center().x - 1.0, minf(_hand_visual_top(), selected_rect.position.y)),
				Vector2(2.0, 1.0)
			)
	if _animating_hand_card_index >= 0:
		var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
		return _hand_receive_rect(_animating_hand_card_index, maxi(1, hand.size()), _hand_card_size(maxi(1, hand.size()), false))
	if hand_scroll != null and hand_scroll.is_inside_tree():
		var hand_rect: Rect2 = hand_scroll.get_global_rect()
		if hand_rect.size.x > 0.0 and hand_rect.size.y > 0.0:
			return Rect2(Vector2(hand_rect.get_center().x - 1.0, hand_rect.position.y), Vector2(2.0, hand_rect.size.y))
	return Rect2()

func _action_step_tracker_connector_target_y(anchor_rect: Rect2) -> float:
	if _drag_card_index >= 0 and _drag_card_source_rect.size.y > 0.0:
		return _drag_card_source_rect.position.y
	var active_card_index: int = _selected_card_index if _selected_card_index >= 0 else _card_action_choice_index
	if active_card_index >= 0:
		var selected_rect: Rect2 = _hand_card_global_rect(active_card_index)
		if selected_rect.size.y > 0.0:
			return selected_rect.position.y
	return anchor_rect.position.y

func _hand_visual_top() -> float:
	if hand_box == null or hand_box.get_child_count() <= 0:
		return INF
	var visual_top: float = INF
	for index: int in range(hand_box.get_child_count()):
		var card_control: Control = _hand_card_control(index)
		if card_control == null or not card_control.visible:
			continue
		visual_top = minf(visual_top, _control_visual_global_rect(card_control).position.y)
	return visual_top

func _control_visual_global_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var transform: Transform2D = control.get_global_transform()
	var corners: Array[Vector2] = []
	corners.append(transform * Vector2.ZERO)
	corners.append(transform * Vector2(control.size.x, 0.0))
	corners.append(transform * control.size)
	corners.append(transform * Vector2(0.0, control.size.y))
	var min_point: Vector2 = corners[0]
	var max_point: Vector2 = corners[0]
	for corner: Vector2 in corners:
		min_point.x = minf(min_point.x, corner.x)
		min_point.y = minf(min_point.y, corner.y)
		max_point.x = maxf(max_point.x, corner.x)
		max_point.y = maxf(max_point.y, corner.y)
	return Rect2(min_point, max_point - min_point)

func _build_action_context_commands(tracker_state: Dictionary) -> void:
	if _action_context_command_bar == null:
		return
	var context_mode: String = str(tracker_state.get("mode", "selection"))
	_action_context_command_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_action_context_command_bar.alignment = BoxContainer.ALIGNMENT_END
	_action_context_command_bar.add_theme_constant_override("separation", 8)
	if context_mode == "drag":
		_action_context_command_bar.add_child(_build_drag_command_zone(
			"attack",
			"Basic Attack",
			_fallback_command_detail("attack"),
			Color("cf7657"),
			Color("2f1d18")
		))
		_action_context_command_bar.add_child(_build_drag_command_zone(
			"move",
			"Basic Move",
			_fallback_command_detail("move"),
			Color("5b8ea2"),
			Color("18262f")
		))
		_update_drag_overlay_hover(_drag_hover_zone)
		return
	if context_mode not in ["selection", "choice"]:
		return
	var alongside_mode_tabs: bool = context_mode == "choice"
	if _current_action_supports_rotation():
		_add_action_context_button("Rotate", _on_rotate_action_context_pressed, "Rotate area", alongside_mode_tabs)
	if _current_action_can_skip():
		_add_action_context_button("Skip", _on_skip_action_pressed, "Skip this step", alongside_mode_tabs)
	if _pending_card_requires_confirmation():
		_add_card_play_confirmation_button()
	if not _pending_umbra_commit_locked:
		_add_action_context_button("Cancel", _on_cancel_requested, "Return card to hand", alongside_mode_tabs)

func _add_card_play_confirmation_button() -> void:
	if _action_context_command_bar == null:
		return
	var button := UiTooltipButton.new()
	button.name = "ActionContextPlayCard"
	button.text = "Play Card"
	button.tooltip_text = "Confirm this card without choosing a board target"
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_SELECTED)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_CAPTION)
	_ui_skin.apply_button_native_size(button, 36.0, 88.0, true, UiSkin.VARIANT_SELECTED)
	button.pressed.connect(_on_confirm_card_play_pressed)
	_action_context_command_bar.add_child(button)

func _refresh_card_action_mode_selector(context_mode: String) -> void:
	if _card_action_mode_selector == null or context_mode != "choice":
		return
	_card_action_mode_selector.visible = true
	var mode_group := ButtonGroup.new()
	mode_group.allow_unpress = false
	_card_action_mode_selector.add_child(_build_card_action_mode_option(
			"play",
			"PRINTED",
			bool(_card_action_choice_options.get("printed_playable", false)),
			Color("d8aa5f"),
			Color("342719"),
			"Use this card's printed actions",
			mode_group
		))
	_card_action_mode_selector.add_child(_build_card_action_mode_option(
			"attack",
			"ATTACK %d" % _fallback_attack_damage(),
			bool(_card_action_choice_options.get("attack_playable", false)),
			Color("d97558"),
			Color("321c18"),
			"Spend this card for a basic Attack",
			mode_group
		))
	_card_action_mode_selector.add_child(_build_card_action_mode_option(
			"move",
			"MOVE %d" % FALLBACK_MOVE_RANGE,
			bool(_card_action_choice_options.get("move_playable", false)),
			Color("65a7bf"),
			Color("182833"),
			"Spend this card for a basic Move",
			mode_group
		))
	if bool(_card_action_choice_options.get("blink_available", false)):
		_card_action_mode_selector.add_child(_build_card_action_mode_option(
				"blink",
				"BLINK %d" % FALLBACK_MOVE_RANGE,
				bool(_card_action_choice_options.get("blink_playable", false)),
				Color("ae8ee0"),
				Color("251b35"),
				"Use Ghost Stride to spend this card for a Blink",
				mode_group
			))

func _build_card_action_mode_option(play_kind: String, text: String, available: bool, accent: Color, fill: Color, tooltip: String, mode_group: ButtonGroup) -> Button:
	var button := UiTooltipButton.new()
	var active: bool = play_kind == _card_action_choice_mode
	button.name = "CardActionChoice%s" % play_kind.capitalize()
	button.text = ""
	button.tooltip_text = tooltip if available else "%s · unavailable with current targets" % tooltip
	var option_width: float = 112.0 if play_kind == "attack" else (100.0 if play_kind == "blink" else 96.0)
	button.custom_minimum_size = Vector2(option_width, CARD_ACTION_MODE_OPTION_HEIGHT)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_group = mode_group
	button.set_pressed_no_signal(active)
	button.disabled = not available
	button.modulate = Color.WHITE if available else Color(0.62, 0.62, 0.62, 0.58)
	button.set_meta("play_kind", play_kind)
	button.set_meta("available", available)
	button.set_meta("active", active)
	button.add_theme_stylebox_override("normal", _card_action_mode_option_style(fill, accent, "normal", active))
	button.add_theme_stylebox_override("hover", _card_action_mode_option_style(fill, accent, "hover", active))
	button.add_theme_stylebox_override("pressed", _card_action_mode_option_style(fill, accent, "pressed", true))
	button.add_theme_stylebox_override("hover_pressed", _card_action_mode_option_style(fill, accent, "hover", true))
	button.add_theme_stylebox_override("disabled", _card_action_mode_option_style(fill, accent, "disabled", active))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_add_card_action_mode_option_content(button, text, accent, active, available)
	button.pressed.connect(_on_card_action_choice_pressed.bind(play_kind))
	return button

func _add_card_action_mode_option_content(button: Button, text: String, accent: Color, active: bool, available: bool) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var indicator := PanelContainer.new()
	indicator.name = "ModeIndicator"
	indicator.custom_minimum_size = Vector2(13.0, 13.0)
	indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.add_theme_stylebox_override("panel", _card_action_mode_indicator_style(accent, active, available, false))
	row.add_child(indicator)
	var indicator_center := CenterContainer.new()
	indicator_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.add_child(indicator_center)
	var dot := PanelContainer.new()
	dot.name = "SelectedDot"
	dot.visible = active
	dot.custom_minimum_size = Vector2(5.0, 5.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_stylebox_override("panel", _card_action_mode_indicator_style(accent, active, available, true))
	indicator_center.add_child(dot)
	var label := Label.new()
	label.name = "ModeLabel"
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("fff4df") if active and available else (Color("d8cbb8") if available else Color("817a73")))
	label.add_theme_color_override("font_outline_color", Color("20140d"))
	label.add_theme_constant_override("outline_size", 1)
	row.add_child(label)

func _card_action_mode_indicator_style(accent: Color, active: bool, available: bool, dot: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var resolved_accent: Color = accent if available else Color("59544f")
	style.bg_color = resolved_accent.lightened(0.18) if dot else (Color("1c1713") if available else Color("171513"))
	if not dot:
		style.border_color = resolved_accent.lightened(0.2) if active else resolved_accent.darkened(0.2)
		style.border_width_left = 2 if active else 1
		style.border_width_top = 2 if active else 1
		style.border_width_right = 2 if active else 1
		style.border_width_bottom = 2 if active else 1
	var radius: int = 3 if dot else 7
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style

func _card_action_mode_option_style(fill: Color, accent: Color, state: String, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = fill.lightened(0.2 if active else 0.08)
			style.border_color = accent.lightened(0.28)
			style.shadow_color = Color(accent.r, accent.g, accent.b, 0.26)
			style.shadow_size = 6
		"pressed":
			style.bg_color = fill.lightened(0.12)
			style.border_color = accent.lightened(0.24)
			style.shadow_color = Color(accent.r, accent.g, accent.b, 0.16)
			style.shadow_size = 4
		"disabled":
			style.bg_color = Color("171411") if active else Color("0d0c0b")
			style.border_color = Color("625a52") if active else Color("3f3b37")
			style.shadow_color = Color.TRANSPARENT
		_:
			style.bg_color = fill.lightened(0.08) if active else Color("17130f")
			style.border_color = accent.lightened(0.18) if active else accent.darkened(0.12)
			style.shadow_color = Color(accent.r, accent.g, accent.b, 0.2) if active else Color(0.0, 0.0, 0.0, 0.2)
			style.shadow_size = 5 if active else 2
	var border_width: int = 2 if state != "disabled" else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	return style

func _add_action_context_button(text: String, callback: Callable, tooltip: String = "", extra_compact: bool = false) -> void:
	if _action_context_command_bar == null:
		return
	var button := UiTooltipButton.new()
	button.name = "ActionContext%s" % text.replace(" ", "")
	button.text = text
	button.tooltip_text = tooltip
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_CAPTION if extra_compact else UiTypography.SIZE_SMALL)
	var button_height: float = 36.0 if extra_compact else UiSkin.BUTTON_HEIGHT_STANDARD
	var minimum_width: float = 72.0 if extra_compact else ACTION_CONTEXT_BUTTON_MIN_WIDTH
	_ui_skin.apply_button_native_size(button, button_height, minimum_width, true, UiSkin.VARIANT_COMPACT)
	button.pressed.connect(callback)
	_action_context_command_bar.add_child(button)

func _current_action_supports_rotation() -> bool:
	if _selected_card_index < 0 or _pending_action_index < 0 or _pending_action_index >= _pending_actions.size():
		return false
	var action: Dictionary = _pending_actions[_pending_action_index]
	return str(action.get("type", "")) == "aoe" and _combat_engine.player_action_needs_orientation(action)

func _on_rotate_action_context_pressed() -> void:
	if not _current_action_supports_rotation():
		return
	_rotate_aoe_aim(1)
	_update_action_context_copy()

func _update_action_context_copy(tracker_state: Dictionary = {}) -> void:
	if _action_step_tracker == null or not _action_step_tracker.visible:
		return
	var state: Dictionary = tracker_state if not tracker_state.is_empty() else _action_step_tracker_state()
	if state.is_empty():
		return
	var actions: Array = state.get("actions", [])
	var action_index: int = clampi(int(state.get("action_index", 0)), 0, maxi(0, actions.size() - 1))
	var action: Dictionary = {}
	if not actions.is_empty() and typeof(actions[action_index]) == TYPE_DICTIONARY:
		action = actions[action_index] as Dictionary
	var context_mode: String = str(state.get("mode", "selection"))
	var verb_text: String = ""
	var target_text: String = ""
	var target_tone: String = "neutral"
	if context_mode == "drag":
		match _drag_hover_zone:
			"attack":
				verb_text = "RELEASE · ATTACK"
				target_text = _fallback_command_detail("attack").to_upper()
				target_tone = "attack"
			"move":
				verb_text = "RELEASE · MOVE"
				target_text = _fallback_command_detail("move").to_upper()
				target_tone = "move"
			"play":
				verb_text = "RELEASE TO PLAY"
				target_text = _action_context_valid_target_count_text(_drag_card_options.get("play", {}))
				target_tone = "valid"
			_:
				if bool(_drag_card_options.get("printed_playable", false)):
					verb_text = "DROP ON BOARD"
					target_text = _action_context_valid_target_count_text(_drag_card_options.get("play", {}))
				else:
					verb_text = "CHOOSE A DEFAULT COMMAND"
					target_text = "FULL CARD UNAVAILABLE"
					target_tone = "invalid"
		if _drag_hover_zone == "attack":
			_set_action_context_risk("warning", "FALLBACK · ATTACK")
		elif _drag_hover_zone == "move":
			_set_action_context_risk("warning", "FALLBACK · MOVE")
		elif bool(_drag_card_options.get("printed_playable", false)):
			_set_action_context_risk("primary", "PRIMARY · FULL CARD")
		else:
			_set_action_context_risk("neutral", "FALLBACK ONLY")
	elif context_mode == "choice" and _selected_card_index < 0:
		verb_text = "CARD UNAVAILABLE"
		target_text = "CHOOSE ATTACK OR MOVE"
		target_tone = "invalid"
		_set_action_context_risk("neutral", "NO PRINTED TARGET")
	elif context_mode == "resolution":
		verb_text = "RESOLVING · %s" % _action_step_action_name(action).to_upper()
		target_text = "IN MOTION"
		target_tone = "neutral"
		_set_action_context_risk("primary", "CARD COMMITTED")
	else:
		var action_name: String = _action_step_action_name(action).to_upper()
		if not _selected_card_label_override.is_empty():
			action_name = _selected_card_label_override.to_upper()
		if _pending_card_requires_confirmation():
			verb_text = "READY · PLAY CARD"
			target_text = "NO TARGET REQUIRED"
			target_tone = "valid"
		elif _orientation_pending():
			verb_text = "SET DIRECTION · CHOOSE ARROW"
			target_text = "DIRECTION"
			target_tone = "valid"
		elif str(action.get("type", "")) == "aoe" and int(action.get("range", 0)) > 0:
			verb_text = "AIM AREA"
			var aoe_target_state: Dictionary = _action_context_target_state()
			target_text = str(aoe_target_state.get("text", ""))
			target_tone = str(aoe_target_state.get("tone", "neutral"))
		else:
			verb_text = action_name
			var target_state: Dictionary = _action_context_target_state()
			target_text = str(target_state.get("text", ""))
			target_tone = str(target_state.get("tone", "neutral"))
		_update_action_context_risk()
	if _action_context_verb_label != null:
		_action_context_verb_label.text = verb_text
	if _action_context_target_label != null:
		_action_context_target_label.text = target_text
		_action_context_target_label.add_theme_color_override("font_color", _action_context_target_color(target_tone))
	_action_step_tracker.set_meta("action_verb", verb_text)
	_action_step_tracker.set_meta("target_state", target_text)
	_action_step_tracker.set_meta("drag_hover_zone", _drag_hover_zone)

func _action_context_target_state() -> Dictionary:
	var preview: Dictionary = _active_card_preview()
	if preview.is_empty():
		return {"text": "RESOLVE", "tone": "neutral"}
	var target_tiles: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	var shortcut_plans: Dictionary = (_preview_shortcuts_for_current_action(preview).get("plans", {}) as Dictionary)
	if _hovered_board_tile.x >= 0:
		var hovered_valid: bool = target_tiles.has(_hovered_board_tile) or shortcut_plans.has(_hovered_board_tile)
		return {
			"text": "VALID TARGET" if hovered_valid else "INVALID TARGET",
			"tone": "valid" if hovered_valid else "invalid"
		}
	var target_count: int = target_tiles.size()
	for shortcut_tile_var: Variant in shortcut_plans.keys():
		if not target_tiles.has(shortcut_tile_var):
			target_count += 1
	return {
		"text": "%d VALID" % target_count,
		"tone": "valid" if target_count > 0 else "invalid"
	}

func _action_context_valid_target_count_text(preview_variant: Variant) -> String:
	if typeof(preview_variant) != TYPE_DICTIONARY:
		return ""
	var preview: Dictionary = preview_variant as Dictionary
	var target_tiles: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if target_tiles.is_empty():
		return "READY" if bool(preview.get("playable", false)) else "UNAVAILABLE"
	return "%d VALID" % target_tiles.size()

func _action_context_target_color(tone: String) -> Color:
	match tone:
		"valid":
			return Color("9edba0")
		"invalid":
			return Color("f08b72")
		"attack":
			return Color("ef9a7b")
		"move":
			return Color("8ac5d9")
		_:
			return Color("c9b9a3")

func _update_action_context_risk() -> void:
	var summary: Dictionary = _pass_preview_summary()
	if summary.is_empty():
		_set_action_context_risk("neutral", "TURN END · --")
		return
	var tone: String = str(summary.get("tone", "safe"))
	var risk_text: String = "TURN END · SAFE"
	if bool(summary.get("defeat", false)):
		risk_text = "TURN END · DEFEAT"
		tone = "danger"
	elif int(summary.get("defiance_spent", 0)) > 0:
		var projected_hp: int = int(summary.get("projected_hp", -1))
		var projected_hp_text: String = str(projected_hp) if projected_hp >= 0 else "?"
		risk_text = "TURN END · DEFIANCE -%d · %s HP · %d LEFT%s" % [
			int(summary.get("defiance_spent", 0)),
			projected_hp_text,
			int(summary.get("defiance_remaining_after", 0)),
			" · UMBRA ?" if bool(summary.get("umbra_unknown_before_player", false)) else ""
		]
		tone = "danger"
	else:
		var values: PackedStringArray = []
		if int(summary.get("stoneskin_loss", 0)) > 0:
			values.append("-%d SKIN" % int(summary.get("stoneskin_loss", 0)))
		if int(summary.get("block_loss", 0)) > 0:
			values.append("-%d BLOCK" % int(summary.get("block_loss", 0)))
		if int(summary.get("hp_loss", 0)) > 0:
			values.append("-%d HP" % int(summary.get("hp_loss", 0)))
		if bool(summary.get("umbra_unknown_before_player", false)):
			values.append("+ ? UMBRA")
			tone = "warning"
		if not values.is_empty():
			risk_text = "TURN END · %s" % " ".join(values)
		elif bool(summary.get("unrevealed_before_player", false)):
			risk_text = "TURN END · DANGER"
			tone = "warning"
	_set_action_context_risk(tone, risk_text)

func _set_action_context_risk(tone: String, text: String) -> void:
	if _action_context_risk_panel != null:
		_action_context_risk_panel.add_theme_stylebox_override("panel", _action_context_risk_style(tone))
		_action_context_risk_panel.tooltip_text = _pass_preview_tooltip(_pass_preview_summary()) if tone not in ["primary", "neutral"] else ""
	if _action_context_risk_label != null:
		_action_context_risk_label.text = text
		_action_context_risk_label.add_theme_color_override("font_color", _action_context_risk_color(tone))
	if _action_step_tracker != null:
		_action_step_tracker.set_meta("risk_text", text)
		_action_step_tracker.set_meta("risk_tone", tone)

func _action_context_risk_style(tone: String) -> StyleBoxFlat:
	var accent: Color = _action_context_risk_color(tone)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.052, 0.044, 0.96)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.12)
	style.shadow_size = 4
	return style

func _action_context_risk_color(tone: String) -> Color:
	match tone:
		"danger":
			return Color("f08b72")
		"warning":
			return Color("e7be6d")
		"primary":
			return Color("e0b86e")
		"neutral":
			return Color("b6aa99")
		_:
			return Color("9edb91")

func _begin_action_step_resolution_tracker(card_id: String, actions: Array, selected_targets: Array) -> void:
	_action_step_resolution_card_id = card_id
	_action_step_resolution_actions = actions.duplicate(true)
	_action_step_resolution_targets = _vector2i_array(selected_targets)
	_action_step_resolution_index = 0
	_action_step_resolution_active = _action_step_resolution_actions.size() > 1
	_refresh_action_step_tracker()

func _lock_action_step_tracker_position_for_resolution() -> void:
	if _action_step_tracker == null or not _action_step_tracker.visible:
		return
	_layout_action_step_tracker()
	_action_step_tracker_locked_position = _action_step_tracker.global_position
	_action_step_tracker_position_locked = true
	_action_step_tracker.set_meta("position_locked", true)

func _set_action_step_resolution_index(index: int) -> void:
	if not _action_step_resolution_active:
		return
	_action_step_resolution_index = clampi(index, 0, _action_step_resolution_actions.size())
	_refresh_action_step_tracker()

func _clear_action_step_resolution_tracker() -> void:
	_action_step_tracker_position_locked = false
	_action_step_tracker_locked_position = Vector2.ZERO
	_action_step_resolution_active = false
	_action_step_resolution_card_id = ""
	_action_step_resolution_actions.clear()
	_action_step_resolution_index = 0
	_action_step_resolution_targets.clear()
	if _action_step_tracker != null:
		_action_step_tracker.set_meta("position_locked", false)
		_action_step_tracker.visible = false
	if _action_context_connector != null:
		_action_context_connector.visible = false

func _build_action_step_chip(index: int, action: Dictionary, status: String) -> Control:
	var chip := PanelContainer.new()
	chip.name = "ActionStepChip%d" % (index + 1)
	chip.custom_minimum_size = ACTION_STEP_CHIP_SIZE
	chip.size = ACTION_STEP_CHIP_SIZE
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.set_meta("step_index", index)
	chip.set_meta("step_status", status)
	chip.set_meta("action_type", str(action.get("type", "")))
	chip.tooltip_text = _action_step_tooltip(index, action, status)
	chip.add_theme_stylebox_override("panel", _action_step_chip_style(status))

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(content)

	var icon_key: String = _action_step_icon_key(action)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = ACTION_STEP_ICON_INSET
	icon.offset_top = ACTION_STEP_ICON_INSET
	icon.offset_right = -ACTION_STEP_ICON_INSET
	icon.offset_bottom = -ACTION_STEP_ICON_INSET
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture(ActionIcons.icon_path(icon_key))
	icon.modulate = _action_step_icon_tint(status)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var number := Label.new()
	number.name = "StepNumber"
	number.text = str(index + 1)
	number.position = Vector2(3.0, 2.0)
	number.custom_minimum_size = Vector2(16.0, 15.0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(number, 9)
	number.add_theme_color_override("font_color", _action_step_number_color(status))
	number.add_theme_color_override("font_outline_color", Color("100b08"))
	number.add_theme_constant_override("outline_size", 1)
	content.add_child(number)

	if status == "skipped":
		var skipped := Label.new()
		skipped.name = "SkippedLabel"
		skipped.set_anchors_preset(Control.PRESET_FULL_RECT)
		skipped.anchor_right = 1.0
		skipped.anchor_bottom = 1.0
		skipped.text = "SKIP"
		skipped.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skipped.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skipped.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.set_label_size(skipped, 9)
		skipped.add_theme_color_override("font_color", Color("ffd6c6"))
		skipped.add_theme_color_override("font_outline_color", Color("1a0b07"))
		skipped.add_theme_constant_override("outline_size", 2)
		content.add_child(skipped)
	return chip

func _action_step_tooltip(index: int, action: Dictionary, status: String) -> String:
	var state_text: String = status.capitalize()
	if status == "done":
		state_text = "Done"
	var action_name: String = _action_step_action_name(action)
	return "%d. %s\n%s" % [index + 1, action_name, state_text]

func _action_step_action_name(action: Dictionary) -> String:
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"aoe":
			return "Area"
		"move", "move_toward":
			return "Move"
		"move_away":
			return "Retreat"
		"blink":
			return "Blink"
		"melee":
			return "Melee"
		"ranged":
			return "Ranged"
		"push":
			return "Push"
		"pull":
			return "Pull"
		"card_play":
			return "Card Play"
		"health_cost":
			return "Health Cost"
		"heal", "heal_self":
			return "Heal"
		"lightning_strikes":
			return "Lightning"
		"summon_minions":
			return "Summon"
		"raise_terrain":
			return "Raise Worldspines"
		"terrain_burst":
			return "Rupture Worldspines"
		"cinder_marks":
			return "Kindle Ground"
		"detonate_cinders":
			return "Detonate Cinders"
		"gale_force":
			return "Hollow Gale"
		"frost_armor":
			return "Crystal Armor"
		"umbra_eclipse":
			return "Last Eclipse"
	var icon_key: String = _action_step_icon_key(action)
	return ActionIcons.label(icon_key) if not icon_key.is_empty() else action_type.capitalize()

func _action_step_icon_key(action: Dictionary) -> String:
	var mapped_key: String = ActionIcons.action_icon_key(action)
	if not mapped_key.is_empty():
		return mapped_key
	for token_var: Variant in ActionIcons.tokens_for_action(action):
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var as Dictionary
		if str(token.get("kind", "")) == "intensity_requirement":
			continue
		return str(token.get("icon", ""))
	return ""

func _action_step_tracker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.044, 0.038, 0.90)
	style.border_color = Color(0.76, 0.62, 0.42, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	return style

func _action_step_chip_style(status: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match status:
		"current":
			style.bg_color = Color(0.075, 0.115, 0.115, 0.98)
			style.border_color = Color("f4c968")
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.shadow_color = Color(0.12, 0.33, 0.34, 0.46)
			style.shadow_size = 10
		"done":
			style.bg_color = Color(0.060, 0.105, 0.070, 0.90)
			style.border_color = Color("87c879")
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
			style.shadow_size = 5
		"skipped":
			style.bg_color = Color(0.150, 0.060, 0.045, 0.94)
			style.border_color = Color("df8065")
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.shadow_color = Color(0.18, 0.02, 0.01, 0.34)
			style.shadow_size = 7
		_:
			style.bg_color = Color(0.075, 0.066, 0.058, 0.72)
			style.border_color = Color(0.62, 0.55, 0.47, 0.42)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
			style.shadow_size = 3
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

func _action_step_icon_tint(status: String) -> Color:
	match status:
		"current":
			return Color("fff3cf")
		"done":
			return Color("d9ffd6")
		"skipped":
			return Color(1.0, 1.0, 1.0, 0.28)
		_:
			return Color(1.0, 1.0, 1.0, 0.44)

func _action_step_number_color(status: String) -> Color:
	match status:
		"current":
			return Color("fff6ce")
		"done":
			return Color("c5f2bc")
		"skipped":
			return Color("ffbca6")
		_:
			return Color("c9b9a3")

func _displayed_card_play_count() -> int:
	if _card_play_count_override >= 0:
		return _card_play_count_override
	return _combat_engine.cards_remaining_this_turn(_combat_state)

func _displayed_card_play_budget() -> Dictionary:
	if not _card_play_budget_override.is_empty():
		return _card_play_budget_override.duplicate(true)
	return _combat_engine.card_play_budget(_combat_state)

func _card_play_count_for_resolution_state(state: Dictionary) -> int:
	var cards_left: int = _combat_engine.cards_remaining_this_turn(state)
	if _card_play_count_override >= 0:
		cards_left -= maxi(1, _card_play_resolution_spend)
	return maxi(0, cards_left)

func _set_card_play_count_override(cards_left: int) -> void:
	_card_play_count_override = maxi(0, cards_left)
	_refresh_card_play_meter()

func _begin_card_play_meter_spend_preview(plays_spent: int = 1) -> void:
	_card_play_resolution_spend = maxi(1, plays_spent)
	var budget: Dictionary = _combat_engine.card_play_budget(_combat_state)
	var spend_remaining: int = _card_play_resolution_spend
	var ordinary_spent: int = mini(int(budget.get("ordinary_remaining", 0)), spend_remaining)
	budget["ordinary_remaining"] = int(budget.get("ordinary_remaining", 0)) - ordinary_spent
	spend_remaining -= ordinary_spent
	var banked_spent: int = mini(int(budget.get("banked_remaining", 0)), spend_remaining)
	budget["banked_remaining"] = int(budget.get("banked_remaining", 0)) - banked_spent
	budget["total_remaining"] = int(budget.get("ordinary_remaining", 0)) + int(budget.get("banked_remaining", 0))
	_card_play_budget_override = budget
	_set_card_play_count_override(int(budget.get("total_remaining", 0)))

func _refresh_elemental_intensity_bar(display_state: Dictionary = {}) -> void:
	if _intensity_bar == null:
		return
	var state: Dictionary = display_state if not display_state.is_empty() else _combat_state
	var active: bool = str(_run_state.get("mode", "room")) == "combat" and not state.is_empty()
	_intensity_bar.visible = active
	if not active:
		return
	_layout_elemental_intensity_bar()
	var intensities: Dictionary = _combat_engine.elemental_intensities(state)
	for element_id: String in ElementData.all_elements():
		var value: int = int(intensities.get(element_id, 0))
		var label: Label = _intensity_labels.get(element_id, null)
		if label != null:
			label.text = str(value)
		var badge: PanelContainer = _intensity_badges.get(element_id, null)
		if badge != null:
			badge.modulate = Color.WHITE if value > 0 else Color(1.0, 1.0, 1.0, 0.44)
			badge.tooltip_text = _intensity_tooltip(element_id)
			badge.add_theme_stylebox_override("panel", _intensity_badge_style(element_id, value))

func _refresh_umbra_subtitle() -> void:
	if umbra_subtitle == null:
		return
	var active_combat: bool = str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty() and _combat_state.has("umbra")
	if not active_combat:
		umbra_subtitle.visible = false
		umbra_subtitle.text = ""
		umbra_subtitle.tooltip_text = ""
		return
	var stage_id: String = _combat_engine.effective_umbra_stage(_combat_state)
	if stage_id == CombatEngineScript.UMBRA_STAGE_CLEAR:
		umbra_subtitle.visible = false
		umbra_subtitle.text = ""
		umbra_subtitle.tooltip_text = ""
		return
	var radius: int = _combat_engine.effective_umbra_radius(_combat_state)
	var stage_name: String = _combat_engine.umbra_stage_display_name(stage_id)
	var radius_text: String = "unlimited" if radius >= CombatEngineScript.UMBRA_UNLIMITED_RADIUS else "%d tile%s" % [radius, "" if radius == 1 else "s"]
	umbra_subtitle.text = "%s Umbra" % stage_name
	umbra_subtitle.tooltip_text = "%s Umbra\nPersonal vision: %s.\nTiles outside your vision or a light source are obscured. Hidden enemies cannot be targeted and conceal their intents.\nRadiance can reveal them or drive the Umbra back." % [
		stage_name,
		radius_text
	]
	umbra_subtitle.visible = true

func _intensity_tooltip(element_id: String) -> String:
	var element_name: String = ElementData.name(element_id)
	return "The intensity of %s in the room.\n%s effects are stronger when this is higher." % [element_name, element_name]

func _intensity_badge_style(element_id: String, value: int) -> StyleBoxFlat:
	var accent: Color = ElementData.accent(element_id)
	var active: bool = value > 0
	var danger: float = clampf(float(maxi(0, value - 1)) / 4.0, 0.0, 1.0)
	var style := StyleBoxFlat.new()
	var charged_background: Color = Color(0.08, 0.055, 0.045, 0.86 if active else 0.58).lerp(accent.darkened(0.56), danger * 0.72)
	style.bg_color = charged_background
	style.border_color = accent.lightened(lerpf(0.18, 0.42, danger)) if active else Color(accent.r, accent.g, accent.b, 0.42)
	var border_width: int = 2 + int(roundf(danger * 2.0))
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, danger * 0.42) if danger > 0.0 else Color(0.0, 0.0, 0.0, 0.32 if active else 0.12)
	style.shadow_size = 8 + int(roundf(danger * 6.0)) if active else 3
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _displayed_ember_count() -> int:
	if _ember_count_override >= 0:
		return _ember_count_override
	var total: int = _run_engine.held_embers(_run_state)
	if str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty():
		total += int(_combat_state.get("room_embers", 0))
	return total

func _set_stats_label_text(ember_count: int) -> void:
	var level: int = int((_run_state.get("progression", _progression) as Dictionary).get("level", _progression.get("level", 1)))
	stats_label.text = "LV %d  EMBERS %d" % [level, ember_count]

func _deck_piles() -> Dictionary:
	if _combat_state.is_empty():
		return {"draw": [], "discard": [], "burn": []}
	var deck: Dictionary = _combat_state.get("deck", {})
	return {
		"draw": (deck.get("draw", []) as Array).duplicate(),
		"discard": (deck.get("discard", []) as Array).duplicate(),
		"burn": (deck.get("burned", []) as Array).duplicate()
	}

func _refresh_visibility() -> void:
	var mode: String = str(_run_state.get("mode", "room"))
	hand_row.visible = mode == "combat"
	piles_bar.visible = mode == "combat"
	hand_scroll.visible = mode == "combat"
	var action_step_tracker_visible: bool = _action_step_tracker != null and _action_step_tracker.visible
	left_action_stack.visible = action_step_tracker_visible or choice_bar.visible or piles_bar.visible
	bottom_stack.visible = choice_bar.visible or hand_row.visible
	if mode != "combat" and _choice_button_overlay != null:
		_choice_button_overlay.visible = false
	if _context_choice_overlay != null and mode != "campfire":
		_context_choice_overlay.visible = false
	stats_label.visible = mode not in ["victory", "defeat"]
	grimoire_button.visible = mode not in ["victory", "defeat"]
	menu_button.visible = mode not in ["victory", "defeat"]
	if mode != "combat":
		_clear_card_action_choice_state()
		_cancel_drag_play()
		_close_pile_view()
	if not (mode in ["combat", "reward"]) and _card_fx_layer != null and _card_fx_layer.get_child_count() > 0:
		_clear_children_now(_card_fx_layer)
	if mode not in ["room", "campfire", RunEngineScript.MODE_PRE_BATTLE]:
		var read_only_skill_tree_open: bool = (
			_upgrade_scrim != null
			and _upgrade_scrim.visible
			and _progression_overlay_mode == "skills"
		)
		if not read_only_skill_tree_open:
			_close_card_upgrade_overlay()
	if mode == "defeat":
		_close_large_map()
		_close_grimoire_overlay()
	_layout_choice_button_overlay()
	_layout_contextual_combat_prompt_overlay()
	call_deferred("_layout_contextual_combat_prompt_overlay")

func _refresh_choice_bar() -> void:
	_clear_children(choice_bar)
	if _choice_button_overlay != null:
		_clear_children_now(_choice_button_overlay)
		_choice_button_overlay.visible = false
	if _pass_preview_overlay != null:
		_clear_children_now(_pass_preview_overlay)
		_pass_preview_overlay.visible = false
	_clear_context_choice_overlay()
	_clear_relic_choice_overlay()
	_sync_merchant_shop_room()
	var mode: String = str(_run_state.get("mode", "room"))
	if mode not in ["victory", "defeat"] and _run_end_recap != null:
		_run_end_recap.reset()
	choice_bar.custom_minimum_size = Vector2.ZERO
	if _dialogue_active and _dialogue_suppresses_choices:
		choice_bar.visible = false
		return
	if mode == "combat" and (_selected_card_index >= 0 or _card_action_choice_index >= 0):
		pass
	elif mode == "combat" and not _animation_lock and _drag_card_index < 0 and _combat_engine.is_player_turn(_combat_state) and _combat_skill_card_selection_zone.is_empty():
		_add_choice_button("Pass", _on_pass_turn_pressed, _pass_preview_button_tooltip())
		_add_pass_preview_chip()
	match mode:
		"room":
			var merchant_kind: String = _current_room_merchant_kind()
			if not merchant_kind.is_empty():
				if _merchant_shop_open:
					_set_relic_choice_title(_merchant_title_text(merchant_kind))
					_add_merchant_trade_panel(merchant_kind)
				else:
					_add_merchant_return_to_shop_button()
		"campfire":
			_add_campfire_choice(
				"linger",
				CAMPFIRE_CHOICE_LINGER_TEXT,
				CAMPFIRE_CHOICE_LINGER_DESCRIPTION,
				CAMPFIRE_CHOICE_LINGER_ICON_PATH,
				Color("efb35f")
			)
			_add_campfire_choice(
				"embrace",
				CAMPFIRE_CHOICE_EMBRACE_TEXT,
				CAMPFIRE_CHOICE_EMBRACE_DESCRIPTION,
				CAMPFIRE_CHOICE_EMBRACE_ICON_PATH,
				Color("d85d42")
			)
			_add_campfire_choice(
				"strength",
				CAMPFIRE_CHOICE_STRENGTH_TEXT,
				_campfire_strength_description(),
				CAMPFIRE_CHOICE_STRENGTH_ICON_PATH,
				Color("d79a4d"),
				_can_level_at_campfire()
			)
		"reward":
			if _reward_choices_available():
				_set_relic_choice_title(REWARD_CHOICE_TITLE_TEXT)
				_add_reward_choice_stack()
		"treasure":
			var pending_relics: Array = (_run_state.get("pending_relics", []) as Array).duplicate()
			if not pending_relics.is_empty():
				_set_relic_choice_title(RELIC_CHOICE_TITLE_TEXT)
			for relic_id_var: Variant in pending_relics:
				var relic_id: String = str(relic_id_var)
				var relic: Dictionary = GameData.relic_def(relic_id)
				_add_relic_choice(relic_id, relic)
			_configure_relic_choice_focus()
		"victory", "defeat":
			_show_run_end_recap(mode)
	var has_overlay_choices: bool = _choice_button_overlay != null and _choice_button_overlay.get_child_count() > 0
	var has_pass_preview: bool = _pass_preview_overlay != null and _pass_preview_overlay.get_child_count() > 0 and has_overlay_choices
	choice_bar.visible = choice_bar.get_child_count() > 0
	if _choice_button_overlay != null:
		_choice_button_overlay.visible = has_overlay_choices
	if _pass_preview_overlay != null:
		_pass_preview_overlay.visible = has_pass_preview
	if _choice_button_overlay != null or _pass_preview_overlay != null:
		_layout_choice_button_overlay()
		call_deferred("_layout_choice_button_overlay")
	_refresh_action_step_tracker()
	if _context_choice_overlay != null:
		_context_choice_overlay.visible = _context_choice_bar != null and _context_choice_bar.get_child_count() > 0
	if _relic_choice_overlay != null:
		var has_relic_choices: bool = _relic_choice_bar != null and _relic_choice_bar.get_child_count() > 0
		var has_selection_title: bool = _relic_choice_title != null and _relic_choice_title.visible
		if _relic_choice_backdrop != null:
			_relic_choice_backdrop.visible = mode in ["reward", "treasure"] and (has_relic_choices or has_selection_title)
		if _relic_choice_host != null:
			_relic_choice_host.visible = has_relic_choices
		_relic_choice_overlay.visible = has_relic_choices or has_selection_title
		if _relic_choice_overlay.visible:
			_layout_relic_choice_overlay()
			call_deferred("_layout_relic_choice_overlay")

func _add_choice_button(text: String, callback: Callable, tooltip: String = "") -> void:
	var button := UiTooltipButton.new()
	button.text = text
	button.tooltip_text = tooltip
	var large_action_button: bool = _large_action_choice_text(text)
	var variant: String = UiSkin.VARIANT_LARGE if large_action_button else UiSkin.VARIANT_STANDARD
	_ui_skin.apply_button_stylebox_overrides(button, variant)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SECTION if large_action_button else UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_ACTION if large_action_button else UiSkin.BUTTON_HEIGHT_STANDARD, 0.0, true, variant)
	button.pressed.connect(callback)
	if _choice_buttons_use_overlay():
		_choice_button_overlay.add_child(button)
	else:
		choice_bar.add_child(button)

func _on_combat_skill_pressed(skill_id: String) -> void:
	if not _combat_skill_is_activatable(skill_id):
		return
	_close_skill_status_popover(false)
	match SkillTreeLibrary.effect_type(skill_id):
		"discard_draw":
			_begin_quick_wits_card_selection(skill_id)
		"discard_recall":
			_begin_encore_card_selection(skill_id)
		"arm_intensity":
			_begin_prismatic_card_selection(skill_id)
		"preserve_burn":
			_commit_combat_skill_state(_combat_engine.arm_rehearsed_escape(_combat_state), skill_id)
		"preserve_fallback_item":
			_commit_combat_skill_state(_combat_engine.arm_makeshift_tool(_combat_state), skill_id)
		"convert_block":
			_commit_combat_skill_state(_combat_engine.arm_carry_the_guard(_combat_state), skill_id)

func _begin_quick_wits_card_selection(skill_id: String) -> void:
	var hand: Array = ((_combat_state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	var valid_indices: Array[int]
	for index: int in range(hand.size()):
		valid_indices.append(index)
	_begin_hand_skill_card_selection(skill_id, valid_indices, "QUICK WITS  ·  CHOOSE A CARD TO DISCARD")

func _commit_quick_wits(skill_id: String, hand_index: int) -> void:
	var before_state: Dictionary = _combat_state.duplicate(true)
	var before_hand: Array = ((before_state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	if hand_index < 0 or hand_index >= before_hand.size():
		return
	var card_id: String = str(before_hand[hand_index])
	var source_rect: Rect2 = _hand_card_global_rect(hand_index)
	var card_size: Vector2 = source_rect.size if source_rect.size.length() > 0.0 else _hand_card_size(before_hand.size(), false)
	var next_state: Dictionary = _combat_engine.use_quick_wits(before_state, hand_index)
	if next_state == before_state:
		return
	_clear_combat_skill_card_selection()
	_animating_hand_card_index = hand_index
	_animation_lock = true
	_hand_panel_signature = "<unset>"
	_refresh_animation_lock_ui()
	var discard_proxy: Control = null
	if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
		discard_proxy = _spawn_card_proxy(card_id, source_rect)
		_mount_card_proxy(discard_proxy, _card_fx_layer, source_rect)
	if not _stage_combat_skill_state(next_state, skill_id):
		_release_card_proxy(discard_proxy)
		_finish_combat_skill_card_motion()
		return
	await _animate_card_to_pile_fx(card_id, "discard", card_size, discard_proxy)
	await _animate_draw_cards_fx(_draw_entries_between_states(before_state, next_state))
	_finish_combat_skill_card_motion()

func _begin_encore_card_selection(skill_id: String) -> void:
	_combat_skill_card_selection_indices.clear()
	var discard: Array = ((_combat_state.get("deck", {}) as Dictionary).get("discard", []) as Array)
	for index: int in range(discard.size()):
		var card_id: String = str(discard[index])
		if GameData.card_is_item(card_id):
			continue
		_combat_skill_card_selection_indices.append(index)
	if _combat_skill_card_selection_indices.is_empty():
		return
	_combat_skill_card_selection_zone = "discard"
	_combat_skill_card_selection_skill_id = skill_id
	_open_pile_view("discard")

func _commit_encore(skill_id: String, discard_index: int) -> void:
	var before_state: Dictionary = _combat_state.duplicate(true)
	var discard: Array = ((before_state.get("deck", {}) as Dictionary).get("discard", []) as Array)
	if discard_index < 0 or discard_index >= discard.size():
		return
	var source_rect: Rect2 = _combat_skill_discard_selection_rect(discard_index)
	var next_state: Dictionary = _combat_engine.use_encore(before_state, discard_index)
	if next_state == before_state:
		return
	_clear_combat_skill_card_selection()
	if _pile_scrim != null:
		_pile_scrim.visible = false
	_active_pile_kind = ""
	_animation_lock = true
	_refresh_animation_lock_ui()
	if not _stage_combat_skill_state(next_state, skill_id):
		_finish_combat_skill_card_motion()
		return
	await _animate_draw_cards_fx(_draw_entries_between_states(before_state, next_state), source_rect)
	_finish_combat_skill_card_motion()

func _combat_skill_discard_selection_rect(discard_index: int) -> Rect2:
	if _pile_dialog_cards == null:
		return Rect2()
	for child: Node in _pile_dialog_cards.get_children():
		var button: Button = child as Button
		if button != null and int(button.get_meta("source_card_index", -1)) == discard_index:
			return button.get_global_rect()
	return Rect2()

func _begin_prismatic_card_selection(skill_id: String) -> void:
	_begin_hand_skill_card_selection(
		skill_id,
		_combat_engine.prismatic_target_hand_indices(_combat_state),
		"PRISMATIC INSTINCT  ·  CHOOSE A CONDITIONAL CARD"
	)

func _commit_prismatic(skill_id: String, hand_index: int) -> void:
	_clear_combat_skill_card_selection()
	_commit_combat_skill_state(_combat_engine.arm_prismatic_instinct(_combat_state, hand_index), skill_id)

func _begin_hand_skill_card_selection(skill_id: String, valid_indices: Array[int], instruction: String) -> void:
	if valid_indices.is_empty():
		return
	_cancel_drag_play()
	_reset_card_resolution()
	_combat_skill_card_selection_zone = "hand"
	_combat_skill_card_selection_skill_id = skill_id
	_combat_skill_card_selection_indices.clear()
	_combat_skill_card_selection_indices.append_array(valid_indices)
	if _combat_skill_card_selection_label != null:
		_combat_skill_card_selection_label.text = instruction
	if _combat_skill_card_selection_prompt != null:
		_combat_skill_card_selection_prompt.visible = true
	_hand_panel_signature = "<unset>"
	_refresh_hand_panel()
	_refresh_choice_bar()
	_refresh_stage_view()
	_layout_combat_skill_card_selection_prompt()
	call_deferred("_layout_combat_skill_card_selection_prompt")

func _on_combat_skill_hand_card_selected(hand_index: int) -> void:
	if _combat_skill_card_selection_zone != "hand" or not _combat_skill_card_selection_indices.has(hand_index):
		return
	var skill_id: String = _combat_skill_card_selection_skill_id
	match SkillTreeLibrary.effect_type(skill_id):
		"discard_draw":
			_commit_quick_wits(skill_id, hand_index)
		"arm_intensity":
			_commit_prismatic(skill_id, hand_index)

func _cancel_combat_skill_card_selection() -> void:
	var was_discard_selection: bool = _combat_skill_card_selection_zone == "discard"
	_clear_combat_skill_card_selection()
	if was_discard_selection and _pile_scrim != null:
		_pile_scrim.visible = false
		_active_pile_kind = ""
	_hand_panel_signature = "<unset>"
	_refresh_hand_panel()
	_refresh_choice_bar()
	_refresh_stage_view()
	call_deferred("_grab_preferred_gui_focus", _skill_sigil)

func _clear_combat_skill_card_selection() -> void:
	_combat_skill_card_selection_zone = ""
	_combat_skill_card_selection_skill_id = ""
	_combat_skill_card_selection_indices.clear()
	if _combat_skill_card_selection_prompt != null:
		_combat_skill_card_selection_prompt.visible = false

func _commit_combat_skill_state(next_combat_state: Dictionary, skill_id: String) -> void:
	if not _stage_combat_skill_state(next_combat_state, skill_id):
		return
	_refresh_ui()
	call_deferred("_grab_preferred_gui_focus", _skill_sigil)

func _stage_combat_skill_state(next_combat_state: Dictionary, skill_id: String) -> bool:
	if next_combat_state == _combat_state:
		return false
	_combat_state = next_combat_state.duplicate(true)
	_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	_mark_combat_preview_state_changed()
	_persist_committed_boundary("combat_skill_%s" % skill_id)
	return true

func _finish_combat_skill_card_motion() -> void:
	_animation_lock = false
	_animating_hand_card_index = -1
	_hand_panel_signature = "<unset>"
	_refresh_ui()
	call_deferred("_grab_preferred_gui_focus", _skill_sigil)

func _add_pass_preview_chip() -> void:
	var summary: Dictionary = _pass_preview_summary()
	if summary.is_empty():
		return
	var chip := TooltipPanelContainer.new()
	chip.name = "PassPreviewChip"
	var chip_size: Vector2 = PASS_PREVIEW_CHIP_SIZE
	if bool(summary.get("unrevealed_before_player", false)) or bool(summary.get("umbra_unknown_before_player", false)):
		chip_size.y = PASS_PREVIEW_DANGER_CHIP_HEIGHT
	chip.custom_minimum_size = chip_size
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var tooltip_text: String = _pass_preview_tooltip(summary)
	chip.mouse_default_cursor_shape = TOOLTIP_ONLY_CURSOR_SHAPE if not tooltip_text.is_empty() else Control.CURSOR_ARROW
	chip.tooltip_text = tooltip_text
	chip.add_theme_stylebox_override("panel", _pass_preview_chip_style(summary))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 7)
	chip.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	var damage_row := HBoxContainer.new()
	damage_row.name = "PassPreviewDamageRow"
	damage_row.custom_minimum_size = Vector2(chip_size.x - 28.0, 40.0)
	damage_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	damage_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	damage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_row.add_theme_constant_override("separation", 8)
	vbox.add_child(damage_row)
	damage_row.add_child(_pass_preview_title_label())
	if bool(summary.get("defeat", false)):
		damage_row.add_child(_pass_preview_damage_label("DEFEAT", "PassPreviewDefeat", Color("f39779"), true))
	else:
		var entries: Array = summary.get("entries", [])
		if entries.is_empty():
			var unknown_umbra: bool = bool(summary.get("umbra_unknown_before_player", false))
			damage_row.add_child(_pass_preview_damage_label("UNKNOWN" if unknown_umbra else "SAFE", "PassPreviewUmbraUnknown" if unknown_umbra else "PassPreviewSafe", Color("c89be3") if unknown_umbra else Color("8fcf7d"), true))
		else:
			for entry_var: Variant in entries:
				if typeof(entry_var) != TYPE_DICTIONARY:
					continue
				var entry: Dictionary = entry_var
				var entry_color: Color = entry.get("color", Color("d9cdb4"))
				damage_row.add_child(_pass_preview_damage_item(
					str(entry.get("text", "")),
					str(entry.get("name", "PassPreviewLoss")),
					entry_color,
					str(entry.get("icon_path", ""))
				))

	if bool(summary.get("unrevealed_before_player", false)) or bool(summary.get("umbra_unknown_before_player", false)):
		var danger_label := Label.new()
		danger_label.name = "PassPreviewDanger"
		danger_label.text = "UMBRA INTENT UNKNOWN" if bool(summary.get("umbra_unknown_before_player", false)) else "DANGER!"
		danger_label.custom_minimum_size = Vector2(chip_size.x - 28.0, 30.0)
		danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		danger_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		danger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.set_label_size(danger_label, UiTypography.SIZE_BODY_LARGE)
		danger_label.add_theme_color_override("font_color", Color("f39779"))
		danger_label.add_theme_color_override("font_outline_color", Color("200806"))
		danger_label.add_theme_constant_override("outline_size", 2)
		vbox.add_child(danger_label)
	var danger_state: bool = (
		bool(summary.get("defeat", false))
		or bool(summary.get("unrevealed_before_player", false))
		or bool(summary.get("umbra_unknown_before_player", false))
	)
	var accent: Color = _action_context_risk_color("danger" if danger_state else str(summary.get("tone", "safe")))
	chip.set_meta("panel_surface_accent", accent)
	chip.set_meta("panel_selected", danger_state)
	_ui_skin.apply_inset_surface(chip, UiSkin.SURFACE_DANGER if danger_state else UiSkin.SURFACE_HUD)

	if _choice_buttons_use_overlay():
		_pass_preview_overlay.add_child(chip)
	else:
		choice_bar.add_child(chip)

func _pass_preview_title_label() -> Label:
	var label := Label.new()
	label.name = "PassPreviewTitle"
	label.text = "On Turn End:"
	label.custom_minimum_size = Vector2(132.0, 34.0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_BODY_LARGE)
	label.add_theme_color_override("font_color", Color("d9cdb4"))
	label.add_theme_color_override("font_outline_color", Color("21150e"))
	label.add_theme_constant_override("outline_size", 1)
	return label

func _pass_preview_damage_item(text: String, node_name: String, color: Color, icon_path: String) -> Control:
	var item := Control.new()
	item.name = "%sItem" % node_name
	item.custom_minimum_size = PASS_PREVIEW_VALUE_SIZE
	item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not icon_path.is_empty():
		var icon := TextureRect.new()
		icon.name = "%sIcon" % node_name
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 6.0
		icon.offset_top = 2.0
		icon.offset_right = -6.0
		icon.offset_bottom = -2.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = AssetLoader.load_texture(icon_path)
		icon.modulate = Color(color.r, color.g, color.b, 0.22)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)
	var label: Label = _pass_preview_damage_label(text, node_name, color, false)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.custom_minimum_size = PASS_PREVIEW_VALUE_SIZE
	item.add_child(label)
	return item

func _pass_preview_damage_label(text: String, node_name: String, color: Color, large: bool) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.custom_minimum_size = Vector2(maxf(48.0, 16.0 + float(text.length()) * (15.0 if large else 13.0)), 36.0 if large else 34.0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_SECTION if large else UiTypography.SIZE_BODY_LARGE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("200806"))
	label.add_theme_constant_override("outline_size", 3)
	return label

func _pass_preview_button_tooltip() -> String:
	var summary: Dictionary = _pass_preview_summary()
	return "" if summary.is_empty() else _pass_preview_tooltip(summary)

func _pass_preview_source_state() -> Dictionary:
	if _selected_card_index >= 0 and not _preview_combat_state.is_empty():
		var hovered_state: Dictionary = _pass_preview_confirmed_hover_state()
		if not hovered_state.is_empty():
			return hovered_state
		return _preview_combat_state
	if not _combat_state.is_empty():
		return _combat_state
	return {}

func _pass_preview_confirmed_hover_state() -> Dictionary:
	if _selected_card_index < 0 or _pending_action_index < 0 or _pending_action_index >= _pending_actions.size():
		return {}
	if _hovered_board_tile.x < 0:
		return {}
	var pending_action: Dictionary = _pending_actions[_pending_action_index]
	if _umbra_hover_preview_would_reveal_information(_preview_combat_state, pending_action):
		return {}
	if _orientation_pending():
		return _pass_preview_confirmed_orientation_state(_hovered_board_tile)
	var preview: Dictionary = _active_card_preview()
	if preview.is_empty():
		return {}
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	if not shortcut_plan.is_empty():
		return _pass_preview_confirmed_shortcut_state(preview, shortcut_plan, _hovered_board_tile)
	var action: Dictionary = _pending_actions[_pending_action_index]
	if str(action.get("type", "")) == "aoe":
		action = _action_with_aoe_aim_orientation(action)
	elif _target_needs_force_orientation(action, _hovered_board_tile):
		return {}
	if not _pending_target_tiles.has(_hovered_board_tile):
		return {}
	var resolved_state: Dictionary = _combat_engine.apply_player_action(_preview_combat_state, action, _hovered_board_tile)
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, resolved_state, _pending_actions, _pending_action_index + 1)
	return _pass_preview_state_after_pending_preview(next_preview)

func _umbra_hover_preview_would_reveal_information(state: Dictionary, action: Dictionary) -> bool:
	if _combat_engine.effective_umbra_radius(state) >= CombatEngineScript.UMBRA_UNLIMITED_RADIUS:
		return false
	return str(action.get("type", "")) in ["move", "blink", "illuminate"]

func _pass_preview_confirmed_orientation_state(click_tile: Vector2i) -> Dictionary:
	if _pending_orientation_target_tile.x < 0:
		return {}
	var action: Dictionary = _pending_actions[_pending_action_index]
	var direction: Vector2i = _force_direction_for_confirmation(action, _pending_orientation_target_tile, click_tile)
	if direction == Vector2i.ZERO:
		return {}
	var oriented_action: Dictionary = _action_with_pending_orientation(action, direction)
	if not _combat_engine.valid_targets_for_player_action(_preview_combat_state, oriented_action).has(_pending_orientation_target_tile):
		return {}
	var resolved_state: Dictionary = _combat_engine.apply_player_action(_preview_combat_state, oriented_action, _pending_orientation_target_tile)
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, resolved_state, _pending_actions, _pending_action_index + 1)
	return _pass_preview_state_after_pending_preview(next_preview)

func _pass_preview_confirmed_shortcut_state(preview: Dictionary, shortcut_plan: Dictionary, target_tile: Vector2i) -> Dictionary:
	var actions: Array = preview.get("actions", [])
	var action_index: int = int(shortcut_plan.get("action_index", -1))
	if action_index < 0 or action_index >= actions.size():
		return {}
	var action: Dictionary = shortcut_plan.get("action", {})
	var action_state: Dictionary = shortcut_plan.get("state", {}) as Dictionary
	if action_state.is_empty():
		return {}
	if _target_needs_force_orientation_in_state(action_state, action, target_tile):
		return action_state
	if not _combat_engine.valid_targets_for_player_action(action_state, action).has(target_tile):
		return {}
	var resolved_state: Dictionary = _combat_engine.apply_player_action(action_state, action, target_tile)
	var card_id: String = str(preview.get("card_id", _card_id_for_hand_index(_selected_card_index)))
	var next_preview: Dictionary = _card_preview_from_state(card_id, resolved_state, actions, action_index + 1)
	return _pass_preview_state_after_pending_preview(next_preview)

func _pass_preview_state_after_pending_preview(preview: Dictionary) -> Dictionary:
	var resolved_state: Dictionary = preview.get("state", {}) as Dictionary
	if resolved_state.is_empty():
		return {}
	if bool(preview.get("complete", false)):
		return _combat_engine.finish_player_card(
			resolved_state,
			_selected_card_index,
			_combat_engine.card_plays_spent_for_actions(preview.get("actions", []) as Array),
			{"play_mode": _card_action_choice_mode}
		)
	return resolved_state

func _pass_preview_summary() -> Dictionary:
	var cache_key: String = _pass_preview_key()
	if _pass_preview_cache.has(cache_key):
		return _pass_preview_cache.get(cache_key, {}) as Dictionary
	var source_state: Dictionary = _pass_preview_source_state()
	if source_state.is_empty() or not _combat_engine.is_player_turn(source_state):
		_cache_pass_preview(cache_key, {})
		return {}
	var scheduled_state: Dictionary = _combat_engine.finish_player_activation(source_state)
	var phase_result: Dictionary = _combat_engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled_state)
	var after_state: Dictionary = (phase_result.get("state", {}) as Dictionary).duplicate(true)
	if after_state.is_empty():
		_cache_pass_preview(cache_key, {})
		return {}
	var losses: Dictionary = _pass_preview_player_damage_losses(phase_result.get("steps", []) as Array)
	var outcome: String = _combat_engine.combat_outcome(after_state)
	var umbra_unknown_before_player: bool = _pass_preview_has_hidden_umbra_action(phase_result.get("steps", []) as Array)
	var source_player: Dictionary = source_state.get("player", {}) as Dictionary
	var after_player: Dictionary = after_state.get("player", {}) as Dictionary
	if not umbra_unknown_before_player:
		var source_hp: int = maxi(0, int(source_player.get("hp", 0)))
		var projected_hp: int = maxi(0, int(after_player.get("hp", source_hp)))
		losses["source_hp"] = source_hp
		losses["projected_hp"] = projected_hp
		losses["projected_max_hp"] = maxi(1, int(after_player.get("max_hp", source_player.get("max_hp", 1))))
		losses["net_hp_change"] = projected_hp - source_hp
	var defeat: bool = not umbra_unknown_before_player and outcome == "defeat"
	var unrevealed_before_player: bool = bool(phase_result.get("unrevealed_before_player", false))
	var entries: Array[Dictionary] = _pass_preview_damage_entries(losses)
	var tone: String = "safe"
	if defeat or int(losses.get("hp", 0)) > 0 or int(losses.get("defiance_spent", 0)) > 0:
		tone = "danger"
	elif int(losses.get("block", 0)) > 0 or int(losses.get("stoneskin", 0)) > 0 or unrevealed_before_player or umbra_unknown_before_player:
		tone = "warning"
	var summary: Dictionary = {
		"tone": tone,
		"entries": entries,
		"defeat": defeat,
		"hp_loss": int(losses.get("hp", 0)),
		"block_loss": int(losses.get("block", 0)),
		"stoneskin_loss": int(losses.get("stoneskin", 0)),
		"defiance_spent": int(losses.get("defiance_spent", 0)),
		"defiance_restored": int(losses.get("defiance_restored", 0)),
		"defiance_remaining_after": int(losses.get("defiance_remaining_after", 0)),
		"source_hp": int(losses.get("source_hp", -1)),
		"projected_hp": int(losses.get("projected_hp", -1)),
		"projected_max_hp": int(losses.get("projected_max_hp", -1)),
		"net_hp_change": int(losses.get("net_hp_change", 0)),
		"unrevealed_before_player": unrevealed_before_player,
		"umbra_unknown_before_player": umbra_unknown_before_player,
		"outcome": outcome
	}
	_cache_pass_preview(cache_key, summary)
	return summary

func _pass_preview_player_damage_losses(steps: Array) -> Dictionary:
	var losses: Dictionary = {
		"hp": 0,
		"block": 0,
		"stoneskin": 0,
		"defiance_spent": 0,
		"defiance_restored": 0,
		"defiance_remaining_after": 0
	}
	for step_var: Variant in steps:
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		if bool(step.get("hidden_by_umbra", false)):
			continue
		var target_losses: Array = step.get("target_losses", [])
		if target_losses.is_empty():
			if int(step.get("hp_loss", 0)) > 0 or int(step.get("block_loss", 0)) > 0 or int(step.get("stoneskin_loss", 0)) > 0:
				losses["hp"] = int(losses.get("hp", 0)) + maxi(0, int(step.get("hp_loss", 0)))
				losses["block"] = int(losses.get("block", 0)) + maxi(0, int(step.get("block_loss", 0)))
				losses["stoneskin"] = int(losses.get("stoneskin", 0)) + maxi(0, int(step.get("stoneskin_loss", 0)))
			continue
		for loss_var: Variant in target_losses:
			if typeof(loss_var) != TYPE_DICTIONARY:
				continue
			var loss: Dictionary = loss_var
			if str(loss.get("key", "")) != "player" and str(loss.get("kind", "")) != "player":
				continue
			losses["hp"] = int(losses.get("hp", 0)) + maxi(0, int(loss.get("hp_loss", 0)))
			losses["block"] = int(losses.get("block", 0)) + maxi(0, int(loss.get("block_loss", 0)))
			losses["stoneskin"] = int(losses.get("stoneskin", 0)) + maxi(0, int(loss.get("stoneskin_loss", 0)))
			var trigger_count: int = maxi(0, int(loss.get("defiance_trigger_count", 0)))
			if trigger_count > 0:
				losses["defiance_spent"] = int(losses.get("defiance_spent", 0)) + trigger_count
				losses["defiance_restored"] = int(losses.get("defiance_restored", 0)) + maxi(0, int(loss.get("defiance_restored", 0)))
				losses["defiance_remaining_after"] = maxi(0, int(loss.get("defiance_remaining", 0)))
	return losses

func _pass_preview_has_hidden_umbra_action(steps: Array) -> bool:
	for step_var: Variant in steps:
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		if bool(step.get("hidden_by_umbra", false)) and str(step.get("kind", "")) == "intent":
			return true
	return false

func _pass_preview_damage_entries(losses: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var stoneskin_loss: int = int(losses.get("stoneskin", 0))
	var block_loss: int = int(losses.get("block", 0))
	var hp_loss: int = int(losses.get("hp", 0))
	var defiance_spent: int = int(losses.get("defiance_spent", 0))
	if stoneskin_loss > 0:
		entries.append({
			"name": "PassPreviewStoneSkinLoss",
			"text": "-%d" % stoneskin_loss,
			"color": ElementData.accent(ElementData.EARTH),
			"icon_path": PASS_PREVIEW_STONESKIN_ICON_PATH
		})
	if block_loss > 0:
		entries.append({
			"name": "PassPreviewBlockLoss",
			"text": "-%d" % block_loss,
			"color": Color("90d9ff"),
			"icon_path": PASS_PREVIEW_BLOCK_ICON_PATH
		})
	if defiance_spent > 0:
		entries.append({
			"name": "PassPreviewDefianceSpent",
			"text": "-%d" % defiance_spent,
			"color": Color("f6d77d"),
			"icon_path": PASS_PREVIEW_DEFIANCE_ICON_PATH
		})
		var projected_hp: int = int(losses.get("projected_hp", -1))
		if projected_hp >= 0:
			entries.append({
				"name": "PassPreviewHpAfterDefiance",
				"text": "%d" % projected_hp,
				"color": Color("f39779"),
				"icon_path": PASS_PREVIEW_HEALTH_ICON_PATH
			})
	elif hp_loss > 0:
		entries.append({
			"name": "PassPreviewHpLoss",
			"text": "-%d" % hp_loss,
			"color": Color("f39779"),
			"icon_path": PASS_PREVIEW_HEALTH_ICON_PATH
		})
	return entries

func _pass_preview_tooltip(summary: Dictionary) -> String:
	if bool(summary.get("umbra_unknown_before_player", false)):
		return "One or more hidden presences act before your next turn. Their intents and possible damage are unknown."
	if int(summary.get("defiance_spent", 0)) > 0:
		var net_hp_change: int = int(summary.get("net_hp_change", 0))
		var net_text: String = (
			"net +%d HP" % net_hp_change
			if net_hp_change > 0
			else "net -%d HP" % -net_hp_change
			if net_hp_change < 0
			else "no net HP change"
		)
		return "A revealed lethal hit will spend %d Defiance and restore %d HP. You return with %d/%d HP (%s) and %d Defiance." % [
			int(summary.get("defiance_spent", 0)),
			int(summary.get("defiance_restored", 0)),
			int(summary.get("projected_hp", 0)),
			int(summary.get("projected_max_hp", 1)),
			net_text,
			int(summary.get("defiance_remaining_after", 0))
		]
	if bool(summary.get("unrevealed_before_player", false)):
		return "Enemies have unrevealed actions before your next turn, you may take additional damage."
	return ""

func _pass_preview_chip_style(summary: Dictionary) -> StyleBoxFlat:
	var tone: String = str(summary.get("tone", "safe"))
	var accent: Color = Color("8fcf7d")
	if tone == "danger":
		accent = Color("d86654")
	elif tone == "warning":
		accent = Color("d7a95d")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.075, 0.055, 0.95)
	style.border_color = accent.lightened(0.10)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	style.shadow_size = 7
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _choice_buttons_use_overlay() -> bool:
	return str(_run_state.get("mode", "room")) == "combat" and _choice_button_overlay != null

func _large_action_choice_text(text: String) -> bool:
	return text == "Pass" or text == "Skip" or text == "Cancel"

func _add_context_choice_button(text: String, callback: Callable, tooltip: String = "") -> void:
	if _context_choice_bar == null:
		return
	var button := UiTooltipButton.new()
	button.text = text
	button.tooltip_text = tooltip
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_LARGE)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SECTION)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_LARGE, 0.0, true, UiSkin.VARIANT_LARGE)
	button.pressed.connect(callback)
	_context_choice_bar.add_child(button)

func _clear_context_choice_overlay() -> void:
	if _context_choice_bar != null:
		_clear_children_now(_context_choice_bar)
	if _context_choice_overlay != null:
		_context_choice_overlay.visible = false

func _clear_relic_choice_overlay() -> void:
	if _relic_choice_bar != null:
		_clear_children_now(_relic_choice_bar)
	if _relic_choice_backdrop != null:
		_relic_choice_backdrop.visible = false
	if _relic_choice_banner != null:
		_relic_choice_banner.visible = false
	if _relic_choice_host != null:
		_relic_choice_host.visible = false
	if _relic_choice_title != null:
		_relic_choice_title.visible = false
		_relic_choice_title.text = ""
	if _relic_choice_title_effect != null:
		_relic_choice_title_effect.visible = false
	if _relic_choice_overlay != null:
		_relic_choice_overlay.visible = false

func _show_run_end_recap(outcome: String) -> void:
	if _run_end_recap == null:
		return
	var ember_amount: int = _victory_carry_amount if outcome == "victory" else _defeat_lost_amount
	var model: Dictionary = RunEndRecapOverlay.build_model(_run_state, _progression, outcome, ember_amount)
	_run_end_recap.present(model)

func _reward_choices_available() -> bool:
	var reward_state: Dictionary = _run_state.get("pending_reward", {}) as Dictionary
	return (reward_state.get("cards", []) as Array).size() > 0 or int(reward_state.get("heal_amount", 0)) > 0

func _add_reward_choice_stack() -> void:
	if _relic_choice_bar == null:
		return
	var reward_state: Dictionary = _run_state.get("pending_reward", {}) as Dictionary
	var reward_cards: Array = reward_state.get("cards", []) as Array
	var heal_amount: int = maxi(0, int(reward_state.get("heal_amount", 0)))
	var stack := VBoxContainer.new()
	stack.name = "RewardChoiceStack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_theme_constant_override("separation", int(REWARD_CHOICE_STACK_GAP))
	_relic_choice_bar.add_child(stack)
	var focusable_cards: Array[Control] = []
	var action_buttons: Array[Control] = []

	if not reward_cards.is_empty():
		var card_row := HBoxContainer.new()
		card_row.name = "RewardCardRow"
		card_row.alignment = BoxContainer.ALIGNMENT_CENTER
		card_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_row.add_theme_constant_override("separation", int(REWARD_CHOICE_CARD_GAP))
		stack.add_child(card_row)
		var reward_card_size: Vector2 = _reward_choice_card_size(reward_cards.size(), heal_amount > 0)
		for card_id_var: Variant in reward_cards:
			var card_id: String = str(card_id_var)
			var widget = CardWidgetScene.instantiate()
			widget.custom_minimum_size = reward_card_size
			widget.configure(card_id, false, false, true, false, true, true, _card_def(card_id))
			widget.set_hover_pose(REWARD_CARD_HOVER_LIFT, REWARD_CARD_HOVER_SCALE)
			widget.activated.connect(_on_reward_card_pressed.bind(card_id, widget))
			var card_slot: Control = _reward_card_choice_slot(widget, card_id, reward_card_size)
			card_row.add_child(card_slot)
			widget.focus_mode = Control.FOCUS_ALL
			widget.focus_entered.connect(widget.set_external_highlighted.bind(true))
			widget.focus_exited.connect(widget.set_external_highlighted.bind(false))
			widget.gui_input.connect(_on_reward_card_keyboard_input.bind(card_id, widget))
			focusable_cards.append(widget)

	var has_reroll: bool = _run_engine.run_skill_is_ready(_run_state, "discerning_eye")
	if heal_amount <= 0 and not has_reroll:
		_configure_reward_choice_focus(focusable_cards, action_buttons)
		return
	var action_center := CenterContainer.new()
	action_center.name = "RewardSecondaryActionCenter"
	action_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(action_center)
	var action_row := HBoxContainer.new()
	action_row.name = "RewardSecondaryActions"
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 14)
	action_center.add_child(action_row)
	if has_reroll:
		var reroll_button: UiTooltipButton = _reward_secondary_button(
			"RewardRerollButton",
			"REROLL",
			_on_reward_reroll_pressed,
			SkillTreeLibrary.description("discerning_eye"),
			REWARD_REROLL_BUTTON_MIN_WIDTH
		)
		action_row.add_child(reroll_button)
		action_buttons.append(reroll_button)
	if heal_amount > 0:
		var recover_button: UiTooltipButton = _reward_recover_button(heal_amount)
		action_row.add_child(recover_button)
		action_buttons.append(recover_button)
	_configure_reward_choice_focus(focusable_cards, action_buttons)

func _on_reward_card_keyboard_input(event: InputEvent, card_id: String, widget: Control) -> void:
	if not event.is_action_pressed("ui_accept") or event.is_echo():
		return
	if widget != null:
		widget.accept_event()
	_on_reward_card_pressed(card_id, widget)

func _configure_reward_choice_focus(cards: Array[Control], actions: Array[Control]) -> void:
	if cards.is_empty():
		return
	var action_target: Control = actions[actions.size() - 1] if not actions.is_empty() else null
	for index: int in range(cards.size()):
		var card: Control = cards[index]
		_set_skill_status_focus_neighbor(card, "left", cards[posmod(index - 1, cards.size())])
		_set_skill_status_focus_neighbor(card, "right", cards[(index + 1) % cards.size()])
		if action_target != null:
			_set_skill_status_focus_neighbor(card, "up", action_target)
			_set_skill_status_focus_neighbor(card, "down", action_target)
	if actions.is_empty():
		return
	var middle_card: Control = cards[floori(float(cards.size()) * 0.5)]
	for index: int in range(actions.size()):
		var action: Control = actions[index]
		_set_skill_status_focus_neighbor(action, "left", actions[posmod(index - 1, actions.size())])
		_set_skill_status_focus_neighbor(action, "right", actions[(index + 1) % actions.size()])
		_set_skill_status_focus_neighbor(action, "up", middle_card)
		_set_skill_status_focus_neighbor(action, "down", middle_card)

func _reward_choice_card_size(card_count: int, has_secondary_action: bool) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var max_row_width: float = minf(960.0, maxf(540.0, viewport_size.x - 64.0))
	var gaps: float = float(maxi(0, card_count - 1)) * REWARD_CHOICE_CARD_GAP
	var width_from_row: float = (max_row_width - gaps) / float(maxi(1, card_count))
	var estimated_stage_height: float = maxf(360.0, viewport_size.y - 120.0)
	var reserved_height: float = 96.0 + SELECTION_TITLE_TO_OFFERS_GAP + 24.0
	if has_secondary_action:
		reserved_height += UiSkin.BUTTON_HEIGHT_STANDARD + REWARD_CHOICE_STACK_GAP
	var width_from_height: float = maxf(152.0, (estimated_stage_height - reserved_height) / CARD_ASPECT_RATIO)
	return _card_size_from_width(clampf(minf(width_from_row, width_from_height), 152.0, 224.0))

func _reward_secondary_button(
	button_name: String,
	text: String,
	callback: Callable,
	tooltip: String,
	minimum_width: float = REWARD_ACTION_BUTTON_MIN_WIDTH
) -> UiTooltipButton:
	var button := UiTooltipButton.new()
	button.name = button_name
	button.text = text
	button.tooltip_text = tooltip
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_STANDARD)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_BODY_LARGE)
	_ui_skin.apply_button_native_size(
		button,
		UiSkin.BUTTON_HEIGHT_STANDARD,
		minimum_width,
		true,
		UiSkin.VARIANT_STANDARD
	)
	button.pressed.connect(callback)
	return button

func _reward_recover_button(heal_amount: int) -> UiTooltipButton:
	var current_hp: int = maxi(0, int(_run_state.get("player_hp", 0)))
	var max_hp: int = maxi(1, int(_run_state.get("player_max_hp", current_hp)))
	var result_hp: int = mini(max_hp, current_hp + heal_amount)
	var effective_heal: int = maxi(0, result_hp - current_hp)
	var wasted_heal: int = maxi(0, heal_amount - effective_heal)
	var fully_wasted: bool = heal_amount > 0 and effective_heal == 0
	var tooltip: String = "Leave every offered card behind and recover %d HP." % heal_amount
	if _run_engine.has_run_skill(_run_state, "deferred_choice"):
		tooltip = "Recover %d HP, then choose whether one offered card follows you to the next reward." % heal_amount
	elif fully_wasted:
		tooltip = "Leave every offered card behind. Health is already full."
	var button: UiTooltipButton = _reward_secondary_button(
		"RewardRecoverButton",
		"SKIP & RECOVER  +%d HP   %d → %d" % [heal_amount, current_hp, result_hp],
		_on_skip_reward_pressed,
		tooltip
	)
	button.icon = AssetLoader.load_texture(HEALTH_ICON_PATH)
	button.expand_icon = true
	button.set_meta("reward_heal_amount", heal_amount)
	button.set_meta("reward_heal_current_hp", current_hp)
	button.set_meta("reward_heal_max_hp", max_hp)
	button.set_meta("reward_heal_result_hp", result_hp)
	button.set_meta("reward_heal_effective", effective_heal)
	button.set_meta("reward_heal_wasted", wasted_heal)
	button.set_meta("reward_heal_fully_wasted", fully_wasted)
	return button

func _set_relic_choice_title(text: String) -> void:
	if _relic_choice_title == null:
		return
	var should_show: bool = not text.is_empty()
	var mode: String = str(_run_state.get("mode", "room"))
	var selection_mode: bool = mode in ["reward", "treasure"]
	var accent: Color = _relic_choice_title_accent(text)
	UiTypography.set_label_size(
		_relic_choice_title,
		SELECTION_TITLE_FONT_SIZE if selection_mode else RELIC_CHOICE_TITLE_FONT_SIZE
	)
	_relic_choice_title.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER if selection_mode else VERTICAL_ALIGNMENT_TOP
	)
	_apply_relic_choice_title_depth(accent, selection_mode)
	_relic_choice_title.text = text
	_relic_choice_title.visible = should_show
	if _relic_choice_banner != null:
		_relic_choice_banner.visible = should_show and selection_mode
	if _relic_choice_title_effect != null:
		_relic_choice_title_effect.accent = accent
		_relic_choice_title_effect.title_text = text
		_relic_choice_title_effect.visible = should_show and not selection_mode

func _apply_relic_choice_title_depth(accent: Color, restrained: bool) -> void:
	if _relic_choice_title == null:
		return
	var face_color: Color = (
		Color("f6e2b9").lerp(accent.lightened(0.14), 0.16)
		if restrained
		else Color("fff0bd").lerp(accent.lightened(0.18), 0.24)
	)
	_relic_choice_title.add_theme_color_override("font_color", face_color)
	_relic_choice_title.add_theme_color_override("font_outline_color", Color("1a0d08"))
	_relic_choice_title.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.62 if restrained else 0.76)
	)
	_relic_choice_title.add_theme_constant_override("outline_size", 2 if restrained else 9)
	_relic_choice_title.add_theme_constant_override("shadow_offset_x", 0)
	_relic_choice_title.add_theme_constant_override("shadow_offset_y", 2 if restrained else 7)

func _relic_choice_title_accent(text: String) -> Color:
	match text:
		REWARD_CHOICE_TITLE_TEXT:
			return Color("9fdc86")
		RELIC_CHOICE_TITLE_TEXT:
			return Color("f2c86a")
		MERCHANT_TITLE_BLACKSMITH:
			return Color("ef9356")
		MERCHANT_TITLE_ARCANIST:
			return Color("92d8ff")
	return Color("f0c978")

func _add_relic_choice(relic_id: String, relic: Dictionary) -> void:
	if _relic_choice_bar == null:
		return
	var panel := TooltipPanelContainer.new()
	panel.name = "RelicChoice_%s" % relic_id
	panel.custom_minimum_size = RELIC_CHOICE_CARD_SIZE
	panel.clip_contents = false
	panel.z_index = 30
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("relic_id", relic_id)
	panel.set_meta("relic_pointer_hovered", false)
	panel.set_meta("relic_keyboard_focused", false)
	panel.add_theme_stylebox_override("panel", _relic_choice_style(Color(GameData.relic_accent(relic_id)), false))
	panel.gui_input.connect(_on_relic_choice_gui_input.bind(panel, relic_id))
	panel.mouse_entered.connect(_set_relic_choice_hovered.bind(panel, relic, true))
	panel.mouse_exited.connect(_set_relic_choice_hovered.bind(panel, relic, false))
	panel.focus_entered.connect(_set_relic_choice_focused.bind(panel, relic, true))
	panel.focus_exited.connect(_set_relic_choice_focused.bind(panel, relic, false))
	_relic_choice_bar.add_child(panel)

	_add_relic_choice_sparkles(panel, Color(GameData.relic_accent(relic_id)))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.z_index = 2
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(76.0, 76.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture(str(relic.get("icon_path", "")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var label := Label.new()
	label.text = str(relic.get("name", relic_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 32.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", Color("fff1d5"))
	label.add_theme_color_override("font_outline_color", Color("26180f"))
	label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(label)

	var description := Label.new()
	description.text = str(relic.get("description", ""))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 76.0)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(description, UiTypography.SIZE_SMALL)
	description.add_theme_color_override("font_color", Color("dec9a7"))
	description.add_theme_color_override("font_outline_color", Color("21150e"))
	description.add_theme_constant_override("outline_size", 1)
	vbox.add_child(description)

func _configure_relic_choice_focus() -> void:
	if _relic_choice_bar == null:
		return
	var choices: Array[Control] = []
	for child: Node in _relic_choice_bar.get_children():
		var choice: Control = child as Control
		if choice != null and not str(choice.get_meta("relic_id", "")).is_empty():
			choices.append(choice)
	if choices.is_empty():
		return
	for index: int in range(choices.size()):
		var choice: Control = choices[index]
		_set_skill_status_focus_neighbor(choice, "left", choices[posmod(index - 1, choices.size())])
		_set_skill_status_focus_neighbor(choice, "right", choices[(index + 1) % choices.size()])

func _add_relic_choice_sparkles(panel: PanelContainer, accent: Color) -> void:
	if panel == null:
		return
	var sparkle := RelicChoiceSparkleLayer.new()
	sparkle.name = "RelicChoiceSparkle"
	sparkle.accent = accent
	sparkle.halo_texture = AssetLoader.load_texture(RELIC_CHOICE_RUNE_HALO_PATH)
	sparkle.glint_texture = AssetLoader.load_texture(RELIC_CHOICE_GLINT_PATH)
	sparkle.set_anchors_preset(Control.PRESET_FULL_RECT)
	sparkle.anchor_right = 1.0
	sparkle.anchor_bottom = 1.0
	sparkle.z_index = 1
	panel.add_child(sparkle)

func _add_campfire_choice(choice_id: String, title: String, detail: String, icon_path: String, accent: Color, enabled: bool = true) -> void:
	if _relic_choice_bar == null:
		return
	var panel := TooltipPanelContainer.new()
	panel.custom_minimum_size = RELIC_CHOICE_CARD_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = false
	panel.z_index = 30
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	panel.set_meta("choice_enabled", enabled)
	panel.set_meta("choice_accent", accent)
	panel.add_theme_stylebox_override("panel", _campfire_choice_style(accent, false, enabled))
	panel.gui_input.connect(_on_campfire_choice_gui_input.bind(choice_id, panel, accent))
	panel.mouse_entered.connect(_set_campfire_choice_hovered.bind(panel, accent, true))
	panel.mouse_exited.connect(_set_campfire_choice_hovered.bind(panel, accent, false))
	_relic_choice_bar.add_child(panel)

	_add_campfire_choice_background(panel, icon_path, enabled)
	_add_campfire_choice_inner_glow(panel, accent, enabled)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 58.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_SECTION)
	label.add_theme_color_override("font_color", Color("fff1d5") if enabled else Color("d0bea2"))
	label.add_theme_color_override("font_outline_color", Color("150c08"))
	label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(label)

	var chips: Array = _campfire_choice_chips(choice_id, enabled)
	if not chips.is_empty():
		var chip_row := HFlowContainer.new()
		chip_row.alignment = FlowContainer.ALIGNMENT_CENTER
		chip_row.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 38.0)
		chip_row.add_theme_constant_override("h_separation", 6)
		chip_row.add_theme_constant_override("v_separation", 4)
		chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for chip: Dictionary in chips:
			_add_campfire_choice_chip(chip_row, chip, accent, enabled)
		vbox.add_child(chip_row)

	var description := Label.new()
	description.text = detail
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_OFF
	description.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 28.0)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(description, UiTypography.SIZE_BODY)
	description.add_theme_color_override("font_color", Color("dec9a7") if enabled else Color("d98f78"))
	description.add_theme_color_override("font_outline_color", Color("150c08"))
	description.add_theme_constant_override("outline_size", 2)
	vbox.add_child(description)

func _current_room_merchant_kind() -> String:
	return _run_engine.merchant_kind_for_current_room(_run_state)

func _sync_merchant_shop_room() -> void:
	var current_coord: Vector2i = _run_state.get("current_room", Vector2i.ZERO)
	if current_coord == _merchant_shop_room_coord:
		return
	_merchant_shop_room_coord = current_coord
	_merchant_shop_open = true

func _on_merchant_hide_pressed() -> void:
	if not _merchant_shop_open or _current_room_merchant_kind().is_empty():
		return
	_close_pinned_tooltip()
	_merchant_shop_open = false
	_refresh_ui()

func _on_merchant_return_to_shop_pressed() -> void:
	if _merchant_shop_open or _current_room_merchant_kind().is_empty():
		return
	_merchant_shop_open = true
	_refresh_ui()

func _add_merchant_return_to_shop_button() -> void:
	if _relic_choice_bar == null:
		return
	var button := UiTooltipButton.new()
	button.name = "MerchantReturnToShopButton"
	button.text = "Return to Shop"
	button.tooltip_text = "Open the merchant's stock again."
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_LARGE)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SECTION)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_LARGE, 0.0, true, UiSkin.VARIANT_LARGE)
	button.pressed.connect(_on_merchant_return_to_shop_pressed)
	_relic_choice_bar.add_child(button)

func _merchant_title_text(merchant_kind: String) -> String:
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		return MERCHANT_TITLE_BLACKSMITH
	if merchant_kind == RunEngineScript.MERCHANT_ARCANIST:
		return MERCHANT_TITLE_ARCANIST
	if merchant_kind == RunEngineScript.MERCHANT_SCAVENGER:
		return MERCHANT_TITLE_SCAVENGER
	return ""

func _merchant_accent(merchant_kind: String) -> Color:
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		return Color("d9862f")
	if merchant_kind == RunEngineScript.MERCHANT_ARCANIST:
		return Color("8a67d8")
	if merchant_kind == RunEngineScript.MERCHANT_SCAVENGER:
		return Color("a6b85f")
	return Color("c9b9a3")

func _add_merchant_trade_panel(merchant_kind: String) -> void:
	if _relic_choice_bar == null:
		return
	var accent: Color = _merchant_accent(merchant_kind)
	var panel := PanelContainer.new()
	panel.name = "MerchantTradePanel"
	panel.custom_minimum_size = MERCHANT_PANEL_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 35
	panel.add_theme_stylebox_override("panel", _merchant_panel_style(accent))
	_relic_choice_bar.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	var stock_label := Label.new()
	stock_label.text = "Stock"
	UiTypography.set_label_size(stock_label, UiTypography.SIZE_BODY)
	stock_label.add_theme_color_override("font_color", Color("f5ead4"))
	stock_label.add_theme_color_override("font_outline_color", Color("241912"))
	stock_label.add_theme_constant_override("outline_size", 1)
	top_row.add_child(stock_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var ember_label := Label.new()
	ember_label.text = "EMBERS %d" % _run_engine.held_embers(_run_state)
	UiTypography.set_label_size(ember_label, UiTypography.SIZE_BODY)
	ember_label.add_theme_color_override("font_color", Color("f0c978"))
	ember_label.add_theme_color_override("font_outline_color", Color("241912"))
	ember_label.add_theme_constant_override("outline_size", 1)
	top_row.add_child(ember_label)

	var hide_button := UiTooltipButton.new()
	hide_button.name = "MerchantHideButton"
	hide_button.text = "Hide"
	hide_button.tooltip_text = "Hide the merchant interface and reveal every door."
	_ui_skin.apply_button_stylebox_overrides(hide_button, UiSkin.VARIANT_STANDARD)
	_ui_skin.apply_button_text_overrides(hide_button)
	UiTypography.set_button_size(hide_button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(hide_button, UiSkin.BUTTON_HEIGHT_STANDARD, 0.0, true, UiSkin.VARIANT_STANDARD)
	hide_button.pressed.connect(_on_merchant_hide_pressed)
	top_row.add_child(hide_button)

	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	vbox.add_child(columns)
	columns.add_child(_build_merchant_column(merchant_kind, false))
	columns.add_child(_build_merchant_column(merchant_kind, true))

func _build_merchant_column(merchant_kind: String, selling: bool) -> Control:
	var accent: Color = _merchant_accent(merchant_kind)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = MERCHANT_COLUMN_SIZE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _merchant_column_style(accent, selling))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Sell" if selling else "Buy"
	UiTypography.set_label_size(title, UiTypography.SIZE_BODY)
	title.add_theme_color_override("font_color", Color("fff1d5"))
	title.add_theme_color_override("font_outline_color", Color("1d1510"))
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	var item_ids: Array = _run_engine.merchant_sellable_ids(_run_state, merchant_kind) if selling else _run_engine.merchant_offer_ids(_run_state, merchant_kind)
	if item_ids.is_empty():
		rows.add_child(_build_merchant_empty_row("Nothing to sell" if selling else "Sold out"))
		return panel
	for item_id_var: Variant in item_ids:
		rows.add_child(_build_merchant_item_row(merchant_kind, str(item_id_var), selling))
	return panel

func _build_merchant_empty_row(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, MERCHANT_ROW_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _merchant_row_style(Color("6f6251"), false, false))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", Color("b9aa91"))
	panel.add_child(label)
	return panel

func _build_merchant_item_row(merchant_kind: String, item_id: String, selling: bool) -> Control:
	var item_accent: Color = _merchant_item_accent(merchant_kind, item_id)
	var affordable: bool = selling or _run_engine.held_embers(_run_state) >= _run_engine.merchant_buy_cost(merchant_kind, item_id)
	var row: TooltipPanelContainer = null
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		var equipment_row := EquipmentTooltipPanelContainer.new()
		equipment_row.equipment_id = item_id
		equipment_row.host = self
		equipment_row.tooltip_text = "equipment:%s" % item_id
		row = equipment_row
	else:
		var card_row := EquipmentCardBadge.new()
		card_row.card_id = item_id
		card_row.host = self
		card_row.tooltip_text = "card:%s" % item_id
		row = card_row
	row.custom_minimum_size = Vector2(0.0, MERCHANT_ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _merchant_row_style(item_accent, false, affordable))
	row.mouse_entered.connect(_on_merchant_row_mouse_entered.bind(merchant_kind, item_id, row))
	row.mouse_exited.connect(_on_merchant_row_mouse_exited.bind(merchant_kind, item_id, row))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(MERCHANT_ICON_SIZE.x, MERCHANT_ICON_SIZE.y)
	icon_frame.add_theme_stylebox_override("panel", _merchant_icon_style(item_accent))
	hbox.add_child(icon_frame)
	var icon_center := CenterContainer.new()
	icon_frame.add_child(icon_center)
	var icon := TextureRect.new()
	icon.custom_minimum_size = MERCHANT_ICON_SIZE - Vector2(8.0, 8.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture(_merchant_item_icon_path(merchant_kind, item_id))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(icon)
	_make_equipment_tile_content_passive(icon_frame)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	hbox.add_child(text_box)

	var name_label := Label.new()
	name_label.text = _merchant_item_name(merchant_kind, item_id)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTypography.set_label_size(name_label, UiTypography.SIZE_BODY)
	name_label.add_theme_color_override("font_color", Color("fff1d5") if affordable else Color("cdbca2"))
	name_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	name_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = _merchant_item_detail(merchant_kind, item_id)
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTypography.set_label_size(detail_label, UiTypography.SIZE_SMALL)
	detail_label.add_theme_color_override("font_color", Color("cdbca2") if affordable else Color("9f927e"))
	text_box.add_child(detail_label)
	_make_equipment_tile_content_passive(text_box)

	var amount: int = _run_engine.merchant_sell_value(merchant_kind, item_id) if selling else _run_engine.merchant_buy_cost(merchant_kind, item_id)
	var price_chip: Control = _merchant_price_chip("%d" % amount, item_accent, selling, affordable)
	_make_equipment_tile_content_passive(price_chip)
	hbox.add_child(price_chip)
	if not selling and _run_engine.run_skill_is_ready(_run_state, "layaway"):
		var hold_button := Button.new()
		hold_button.name = "Layaway_%s" % item_id
		hold_button.text = "Hold"
		hold_button.tooltip_text = SkillTreeLibrary.description("layaway")
		hold_button.custom_minimum_size = Vector2(64.0, 42.0)
		_ui_skin.apply_button_stylebox_overrides(hold_button, UiSkin.VARIANT_COMPACT)
		_ui_skin.apply_button_text_overrides(hold_button)
		UiTypography.set_button_size(hold_button, UiTypography.SIZE_SMALL)
		hold_button.pressed.connect(_on_merchant_layaway_pressed.bind(item_id))
		hbox.add_child(hold_button)

	var button := Button.new()
	button.text = "Sell" if selling else "Buy"
	button.disabled = not affordable
	button.custom_minimum_size = Vector2(82.0, 42.0)
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_BODY)
	if selling:
		button.pressed.connect(_on_merchant_sell_pressed.bind(merchant_kind, item_id, row))
	else:
		button.pressed.connect(_on_merchant_buy_pressed.bind(merchant_kind, item_id, row))
	hbox.add_child(button)
	return row

func _on_merchant_layaway_pressed(item_id: String) -> void:
	if _merchant_trade_animation_active:
		return
	var before_state: Dictionary = _run_state.duplicate(true)
	_run_state = _run_engine.reserve_merchant_offer(_run_state, item_id)
	if _run_state == before_state:
		return
	_close_pinned_tooltip()
	_persist_committed_boundary("merchant_offer_held")
	_refresh_ui()

func _on_merchant_row_mouse_entered(merchant_kind: String, item_id: String, row: Control = null) -> void:
	_merchant_hovered_kind = merchant_kind
	_merchant_hovered_item_id = item_id
	_merchant_hovered_row = row

func _on_merchant_row_mouse_exited(merchant_kind: String, item_id: String, row: Control = null) -> void:
	if _merchant_hovered_kind == merchant_kind and _merchant_hovered_item_id == item_id:
		_merchant_hovered_kind = ""
		_merchant_hovered_item_id = ""
		if _merchant_hovered_row == row or row == null:
			_merchant_hovered_row = null

func _merchant_price_chip(text: String, accent: Color, selling: bool, enabled: bool) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(62.0, 36.0)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _merchant_chip_style(accent, selling, enabled))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", Color("e1ffd1") if selling else Color("ffe1ad"))
	label.add_theme_color_override("font_outline_color", Color("1b1008"))
	label.add_theme_constant_override("outline_size", 1)
	chip.add_child(label)
	return chip

func _merchant_item_name(merchant_kind: String, item_id: String) -> String:
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		return str(GameData.equipment_def(item_id).get("name", item_id))
	return str(GameData.card_def(item_id).get("name", item_id))

func _merchant_item_detail(merchant_kind: String, item_id: String) -> String:
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		return "%s | %s" % [
			_equipment_slot_label(GameData.equipment_slot(item_id)),
			_equipment_rarity_label(GameData.equipment_rarity(item_id))
		]
	var card: Dictionary = GameData.card_def(item_id)
	if merchant_kind == RunEngineScript.MERCHANT_SCAVENGER:
		return "Item | %s" % _equipment_rarity_label(str(card.get("rarity", "common")))
	var element_name: String = ElementData.name(GameData.card_element(item_id))
	if element_name.is_empty():
		element_name = "Neutral"
	return "%s | %s" % [element_name, _equipment_rarity_label(str(card.get("rarity", "common")))]

func _merchant_item_tooltip(merchant_kind: String, item_id: String) -> String:
	var lines: Array = [_merchant_item_name(merchant_kind, item_id), _merchant_item_detail(merchant_kind, item_id)]
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		for card_id_var: Variant in GameData.equipment_cards(item_id):
			lines.append(str(GameData.card_def(str(card_id_var)).get("name", card_id_var)))
	else:
		lines.append(str(GameData.card_def(item_id).get("description", "")))
	return "\n".join(lines)

func _merchant_item_icon_path(merchant_kind: String, item_id: String) -> String:
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		return str(GameData.equipment_def(item_id).get("icon_path", ""))
	return str(GameData.card_def(item_id).get("art_path", ElementData.icon_path(GameData.card_element(item_id))))

func _merchant_item_accent(merchant_kind: String, item_id: String) -> Color:
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		return Color(GameData.equipment_accent(item_id))
	return _item_card_accent(item_id)

func _item_card_accent(card_id: String) -> Color:
	var card: Dictionary = GameData.card_def(card_id)
	var accent_text: String = str(card.get("accent", ""))
	if not accent_text.is_empty():
		return Color(accent_text)
	return ElementData.accent(GameData.card_element(card_id))

func _merchant_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.052, 0.040, 0.95)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.86)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 8.0)
	return style

func _merchant_column_style(accent: Color, selling: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.050, 0.038, 0.032, 0.88)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.44 if selling else 0.58)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	return style

func _merchant_row_style(accent: Color, hovered: bool, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.075, 0.054, 0.94).lightened(0.05 if hovered else 0.0)
	if not enabled:
		style.bg_color = Color(0.066, 0.058, 0.050, 0.90)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.70 if enabled else 0.32)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _merchant_icon_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.030, 0.027, 0.94)
	style.border_color = accent.darkened(0.10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style

func _merchant_chip_style(accent: Color, selling: bool, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14321a") if selling else Color("342415")
	style.border_color = Color("83d088") if selling else accent.lightened(0.18)
	if not enabled:
		style.bg_color = Color("2a2520")
		style.border_color = Color("8b7b66")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _add_campfire_choice_background(panel: PanelContainer, icon_path: String, enabled: bool) -> void:
	var clip := Control.new()
	clip.name = "CampfireChoiceBackgroundClip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(clip)

	var art := TextureRect.new()
	art.name = "CampfireChoiceBackground"
	art.texture = AssetLoader.load_texture(icon_path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.modulate = Color(1.0, 1.0, 1.0, 0.68 if enabled else 0.50)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = -8.0
	art.offset_top = -8.0
	art.offset_right = 8.0
	art.offset_bottom = 8.0
	clip.add_child(art)

	var wash := ColorRect.new()
	wash.name = "CampfireChoiceWash"
	wash.color = Color(0.055, 0.033, 0.022, 0.40 if enabled else 0.55)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(wash)

func _add_campfire_choice_inner_glow(panel: PanelContainer, accent: Color, enabled: bool) -> void:
	var glow := PanelContainer.new()
	glow.name = "CampfireChoiceInnerGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.add_theme_stylebox_override("panel", _campfire_choice_inner_glow_style(accent, false, enabled))
	panel.add_child(glow)

func _campfire_choice_chips(choice_id: String, enabled: bool) -> Array:
	var chips: Array = []
	match choice_id:
		"linger":
			chips.append({"text": "+%d HP" % CAMPFIRE_LINGER_HEAL_AMOUNT, "tone": "benefit"})
		"strength":
			_sync_progression_from_run()
			var cost: int = ProgressionStore.next_level_cost(_progression)
			if ProgressionStore.is_max_level(_progression):
				chips.append({"text": "MAX LEVEL", "tone": "locked"})
				chips.append({"text": "CAPPED", "tone": "disabled"})
			elif enabled:
				chips.append({"text": "%d EMBERS" % cost, "tone": "cost"})
				chips.append({"text": "NEW SKILL", "tone": "benefit"})
			else:
				chips.append({"text": "NEED %d" % cost, "tone": "locked"})
				chips.append({"text": "HELD %d" % int(_progression.get("embers", 0)), "tone": "disabled"})
	return chips

func _add_campfire_choice_chip(chip_row: HFlowContainer, chip_def: Dictionary, accent: Color, choice_enabled: bool) -> void:
	var chip := PanelContainer.new()
	chip.name = "CampfireChoiceChip"
	chip.custom_minimum_size = CAMPFIRE_CHOICE_CHIP_SIZE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tone: String = str(chip_def.get("tone", "neutral"))
	chip.add_theme_stylebox_override("panel", _campfire_choice_chip_style(tone, accent, choice_enabled))
	chip_row.add_child(chip)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(margin)

	var label := Label.new()
	label.text = str(chip_def.get("text", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", _campfire_choice_chip_text_color(tone, choice_enabled))
	label.add_theme_color_override("font_outline_color", Color("1a100b"))
	label.add_theme_constant_override("outline_size", 2)
	margin.add_child(label)

func _can_level_at_campfire() -> bool:
	_sync_progression_from_run()
	return ProgressionStore.can_level_up(_progression)

func _campfire_strength_description() -> String:
	_sync_progression_from_run()
	if ProgressionStore.is_max_level(_progression):
		return "Maximum level"
	var cost: int = ProgressionStore.next_level_cost(_progression)
	if cost <= 0:
		return CAMPFIRE_CHOICE_STRENGTH_DESCRIPTION
	if ProgressionStore.can_level_up(_progression):
		return CAMPFIRE_CHOICE_STRENGTH_DESCRIPTION
	return "Need %d embers" % cost

func _set_relic_choice_hovered(panel: PanelContainer, relic: Dictionary, hovered: bool) -> void:
	if panel == null:
		return
	panel.set_meta("relic_pointer_hovered", hovered)
	_refresh_relic_choice_emphasis(panel, relic)

func _set_relic_choice_focused(panel: PanelContainer, relic: Dictionary, focused: bool) -> void:
	if panel == null:
		return
	panel.set_meta("relic_keyboard_focused", focused)
	_refresh_relic_choice_emphasis(panel, relic)

func _refresh_relic_choice_emphasis(panel: PanelContainer, relic: Dictionary) -> void:
	var emphasized: bool = (
		bool(panel.get_meta("relic_pointer_hovered", false))
		or bool(panel.get_meta("relic_keyboard_focused", false))
	)
	var accent: String = str(relic.get("accent", GameData.relic_rarity_accent(str(relic.get("rarity", "common")))))
	panel.z_index = 40 if emphasized else 30
	panel.add_theme_stylebox_override("panel", _relic_choice_style(Color(accent), emphasized))

func _set_campfire_choice_hovered(panel: PanelContainer, accent: Color, hovered: bool) -> void:
	if panel == null:
		return
	var enabled: bool = bool(panel.get_meta("choice_enabled", true))
	panel.z_index = 40 if hovered else 30
	panel.add_theme_stylebox_override("panel", _campfire_choice_style(accent, hovered, enabled))
	var glow: PanelContainer = panel.get_node_or_null("CampfireChoiceInnerGlow") as PanelContainer
	if glow != null:
		glow.add_theme_stylebox_override("panel", _campfire_choice_inner_glow_style(accent, hovered, enabled))

func _campfire_choice_style(accent: Color, hovered: bool, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if enabled:
		style.bg_color = Color(0.15, 0.09, 0.055, 0.96) if hovered else Color(0.10, 0.065, 0.045, 0.91)
		style.border_color = accent.lightened(0.32) if hovered else Color(accent.r, accent.g, accent.b, 0.84)
	else:
		style.bg_color = Color(0.075, 0.065, 0.055, 0.96)
		style.border_color = Color("b9664f") if hovered else Color("8f5e4d")
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52 if hovered else 0.40)
	style.shadow_size = 22 if hovered else 16
	style.shadow_offset = Vector2(0.0, 9.0 if hovered else 7.0)
	style.expand_margin_left = 8.0
	style.expand_margin_top = 8.0
	style.expand_margin_right = 8.0
	style.expand_margin_bottom = 14.0
	return style

func _campfire_choice_inner_glow_style(accent: Color, hovered: bool, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var alpha: float = 0.085 if hovered else 0.042
	var border_alpha: float = 0.32 if hovered else 0.16
	if not enabled:
		alpha *= 0.45
		border_alpha *= 0.55
	style.bg_color = Color(accent.r, accent.g, accent.b, alpha)
	style.border_color = Color(1.0, 0.74, 0.34, border_alpha)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _campfire_choice_feedback_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	style.border_color = accent.lightened(0.42)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.46)
	style.shadow_size = 26
	style.shadow_offset = Vector2.ZERO
	return style

func _campfire_choice_chip_style(tone: String, accent: Color, choice_enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(0.14, 0.11, 0.08, 0.96)
	var border := Color(accent.r, accent.g, accent.b, 0.82)
	match tone:
		"benefit":
			bg = Color("15321d")
			border = Color("83d088")
		"cost":
			bg = Color("342415")
			border = Color("e1a158")
		"locked":
			bg = Color("3c211b")
			border = Color("dc745d")
		"disabled":
			bg = Color("25221f")
			border = Color("8b7b66")
	if not choice_enabled and tone != "locked":
		bg = bg.darkened(0.10)
		border = border.darkened(0.12)
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	return style

func _campfire_choice_chip_text_color(tone: String, choice_enabled: bool) -> Color:
	match tone:
		"benefit":
			return Color("d9ffd6") if choice_enabled else Color("a7c9a4")
		"cost":
			return Color("ffe1ad") if choice_enabled else Color("c9ad85")
		"locked":
			return Color("ffd0bd")
		"disabled":
			return Color("d1c1a8")
	return Color("fff1d5") if choice_enabled else Color("c8b69b")

func _relic_choice_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.045, 0.92).lightened(0.08) if hovered else Color(0.09, 0.06, 0.045, 0.86)
	style.border_color = accent.lightened(0.20) if hovered else Color(accent.r, accent.g, accent.b, 0.78)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48 if hovered else 0.38)
	style.shadow_size = 22 if hovered else 16
	style.shadow_offset = Vector2(0.0, 9.0 if hovered else 7.0)
	style.expand_margin_left = 0.0
	style.expand_margin_top = 0.0
	style.expand_margin_right = 0.0
	style.expand_margin_bottom = 0.0
	return style

func _on_relic_choice_gui_input(event: InputEvent, panel: PanelContainer, relic_id: String) -> void:
	var pointer_activation: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var focus_activation: bool = event.is_action_pressed("ui_accept") and not event.is_echo()
	if not pointer_activation and not focus_activation:
		return
	if focus_activation and panel != null:
		panel.accept_event()
	var source_rect: Rect2 = Rect2()
	if panel != null:
		source_rect = panel.get_global_rect()
	await _on_relic_pressed(relic_id, source_rect)

func _on_campfire_choice_gui_input(event: InputEvent, choice_id: String, panel: PanelContainer, accent: Color) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if _campfire_choice_action_pending or str(_run_state.get("mode", "room")) != "campfire":
		return
	if choice_id == "strength" and not _can_level_at_campfire():
		return
	_set_campfire_choice_action_pending(true)
	_show_campfire_choice_feedback_pulse(panel, accent)
	await get_tree().create_timer(0.08).timeout
	if str(_run_state.get("mode", "room")) != "campfire":
		_set_campfire_choice_action_pending(false)
		return
	match choice_id:
		"linger":
			_on_campfire_linger_pressed()
		"embrace":
			_on_campfire_embrace_pressed()
		"strength":
			_open_level_up_overlay()
	_set_campfire_choice_action_pending(false)

func _set_campfire_choice_action_pending(pending: bool) -> void:
	_campfire_choice_action_pending = pending
	if _relic_choice_bar == null:
		return
	for child: Node in _relic_choice_bar.get_children():
		var panel: PanelContainer = child as PanelContainer
		if panel == null:
			continue
		var choice_enabled: bool = bool(panel.get_meta("choice_enabled", true))
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW if pending or not choice_enabled else Control.CURSOR_POINTING_HAND

func _show_campfire_choice_feedback_pulse(panel: PanelContainer, accent: Color) -> void:
	if panel == null or not panel.is_inside_tree():
		return
	var pulse := PanelContainer.new()
	pulse.name = "CampfireChoicePressPulse"
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.set_anchors_preset(Control.PRESET_FULL_RECT)
	pulse.pivot_offset = panel.size * 0.5
	pulse.scale = Vector2(0.985, 0.985)
	pulse.modulate = Color(1.0, 1.0, 1.0, 0.0)
	pulse.z_index = 80
	pulse.add_theme_stylebox_override("panel", _campfire_choice_feedback_style(accent))
	panel.add_child(pulse)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(pulse, "modulate:a", 1.0, 0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "scale", Vector2(1.055, 1.055), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.19).set_delay(0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_queue_free_node_now.bind(pulse))

func _queue_hand_ready_wave(reason: String = "") -> void:
	_hand_ready_wave_indices.clear()
	_hand_ready_wave_reason = ""
	if not _can_queue_hand_ready_wave():
		return
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	var ready_order: int = 0
	for index: int in range(hand.size()):
		var options: Dictionary = _card_play_options_for_index(index)
		if not bool(options.get("any_playable", false)):
			continue
		_hand_ready_wave_indices[index] = ready_order
		ready_order += 1
	if _hand_ready_wave_indices.is_empty():
		return
	_hand_ready_wave_token += 1
	_hand_ready_wave_reason = reason

func _can_queue_hand_ready_wave() -> bool:
	return (
		not _animation_lock
		and str(_run_state.get("mode", "room")) == "combat"
		and _combat_engine.is_player_turn(_combat_state)
		and _selected_card_index < 0
		and _card_action_choice_index < 0
		and _drag_card_index < 0
		and _animating_hand_card_index < 0
	)

func _ready_wave_delay_for_hand_index(index: int, options: Dictionary) -> float:
	if not _can_queue_hand_ready_wave():
		return -1.0
	if not bool(options.get("any_playable", false)):
		return -1.0
	if not _hand_ready_wave_indices.has(index):
		return -1.0
	return float(_hand_ready_wave_indices[index]) * HAND_READY_WAVE_STAGGER_SECONDS

func _consume_hand_ready_wave() -> void:
	_hand_ready_wave_indices.clear()
	_hand_ready_wave_reason = ""

func _refresh_hand_panel() -> void:
	_clear_idle_card_fx_layer()
	var mode: String = str(_run_state.get("mode", "room"))
	var signature: String = "%s|%d|%d|%d|%s|%d|%d|%d|%d|%d|%d|%d|%d|%.1f,%.1f" % [
		mode,
		hash(_combat_state),
		hash(_run_state.get("pending_reward", {})),
		_selected_card_index,
		_card_action_choice_mode,
		_card_action_choice_index,
		_hovered_card_index,
		_drag_card_index,
		_animating_hand_card_index,
		1 if _animation_lock else 0,
		_hand_ready_wave_token,
		hash(_hand_ready_wave_indices),
		_combat_preview_revision,
		hand_scroll.size.x,
		hand_scroll.size.y
	]
	signature += "|skill_select:%s:%s:%d" % [
		_combat_skill_card_selection_zone,
		_combat_skill_card_selection_skill_id,
		hash(_combat_skill_card_selection_indices),
	]
	if signature == _hand_panel_signature:
		return
	_hand_panel_signature = signature
	_clear_children_now(hand_box)
	if mode == "combat":
		var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
		var selecting_skill_card: bool = _combat_skill_card_selection_zone == "hand"
		var skill_selection_buttons: Array[Button]
		var active_hand_index: int = _selected_card_index if _selected_card_index >= 0 else _card_action_choice_index
		hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var card_size: Vector2 = _hand_card_size(hand.size(), false)
		for index: int in range(hand.size()):
			var options: Dictionary = _card_play_options_for_index(index)
			var display: Dictionary = _card_widget_display_for_index(index)
			var valid_skill_target: bool = selecting_skill_card and _combat_skill_card_selection_indices.has(index)
			var widget = CardWidgetScene.instantiate()
			widget.custom_minimum_size = card_size
			widget.configure(
				str(hand[index]),
				index == active_hand_index and not selecting_skill_card,
				(not valid_skill_target if selecting_skill_card else active_hand_index >= 0 and active_hand_index != index) or _animation_lock,
				(valid_skill_target if selecting_skill_card else bool(options.get("any_playable", false))) and not _animation_lock,
				_hovered_card_index == index and active_hand_index < 0
				and _drag_card_index < 0,
				not _animation_lock and not selecting_skill_card,
				valid_skill_target if selecting_skill_card else bool(options.get("printed_playable", false)),
				_card_def(str(hand[index]), _combat_state)
			)
			widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
			var ready_wave_delay: float = _ready_wave_delay_for_hand_index(index, options)
			if ready_wave_delay >= 0.0:
				widget.set_meta("ready_wave_token", _hand_ready_wave_token)
				widget.set_meta("ready_wave_reason", _hand_ready_wave_reason)
				widget.set_meta("ready_wave_order", int(_hand_ready_wave_indices[index]))
				widget.set_meta("ready_wave_delay", ready_wave_delay)
				widget.set_meta("ready_wave_playable", true)
			if index == _drag_card_index:
				widget.modulate = Color(1.0, 1.0, 1.0, 0.20)
			elif index == _animating_hand_card_index:
				widget.visible = false
			if not _animation_lock and not selecting_skill_card:
				widget.activated.connect(_on_card_pressed.bind(index))
				widget.drag_started.connect(_on_card_drag_started.bind(index))
				widget.mouse_entered.connect(_on_card_hover_started.bind(index))
				widget.mouse_exited.connect(_on_card_hover_ended.bind(index))
			var card_slot: Control = _hand_card_slot(widget, card_size)
			if selecting_skill_card:
				var selection_button: Button = _build_skill_hand_selection_card(card_slot, index, card_size, valid_skill_target)
				hand_box.add_child(selection_button)
				if valid_skill_target:
					skill_selection_buttons.append(selection_button)
			else:
				hand_box.add_child(card_slot)
			if ready_wave_delay >= 0.0:
				widget.call_deferred("play_ready_wave", ready_wave_delay)
		hand_box.configure_layout(HAND_CARD_OVERLAP, true)
		if selecting_skill_card:
			_configure_skill_hand_selection_focus(skill_selection_buttons)
			if not skill_selection_buttons.is_empty():
				call_deferred("_focus_skill_hand_selection_card", skill_selection_buttons[0])
		_consume_hand_ready_wave()
	elif mode == "reward":
		hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		hand_box.configure_layout(HAND_CARD_GAP, false)
	else:
		hand_box.configure_layout(HAND_CARD_GAP, false)

func _hand_card_slot(widget: Control, card_size: Vector2) -> Control:
	return _scaled_card_slot(widget, card_size)

func _build_skill_hand_selection_card(card_slot: Control, hand_index: int, card_size: Vector2, valid_target: bool) -> Button:
	var button := Button.new()
	button.name = "SkillHandSelectionCard_%d" % hand_index
	button.custom_minimum_size = card_size
	button.size = card_size
	button.text = ""
	button.disabled = not valid_target
	button.focus_mode = Control.FOCUS_ALL if valid_target else Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if valid_target else Control.CURSOR_ARROW
	button.set_meta("hand_index", hand_index)
	button.add_theme_stylebox_override("normal", _skill_card_selection_frame_style(Color("74538e"), false))
	button.add_theme_stylebox_override("disabled", _skill_card_selection_frame_style(Color(0.0, 0.0, 0.0, 0.0), false))
	for style_name: String in ["hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style_name, _skill_card_selection_frame_style(Color("d6a7ff"), true))
	card_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(card_slot)
	_set_mouse_filter_recursive(card_slot, Control.MOUSE_FILTER_IGNORE)
	if valid_target:
		button.pressed.connect(_on_combat_skill_hand_card_selected.bind(hand_index))
		button.focus_entered.connect(_ensure_skill_hand_selection_card_visible.bind(button))
	else:
		button.modulate = Color(1.0, 1.0, 1.0, 0.42)
	return button

func _skill_card_selection_frame_style(accent: Color, emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.025, 0.05, 0.08 if emphasized else 0.0)
	style.border_color = accent
	style.set_border_width_all(4 if emphasized else 2)
	style.set_corner_radius_all(10)
	style.set_expand_margin_all(5.0 if emphasized else 3.0)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.38 if emphasized else 0.12)
	style.shadow_size = 10 if emphasized else 4
	return style

func _configure_skill_hand_selection_focus(buttons: Array[Button]) -> void:
	if buttons.is_empty():
		return
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		_set_skill_status_focus_neighbor(button, "left", buttons[posmod(index - 1, buttons.size())])
		_set_skill_status_focus_neighbor(button, "right", buttons[(index + 1) % buttons.size()])
		if _combat_skill_card_selection_cancel_button != null:
			_set_skill_status_focus_neighbor(button, "up", _combat_skill_card_selection_cancel_button)
			_set_skill_status_focus_neighbor(button, "down", _combat_skill_card_selection_cancel_button)
	if _combat_skill_card_selection_cancel_button != null:
		_set_skill_status_focus_neighbor(_combat_skill_card_selection_cancel_button, "left", buttons[buttons.size() - 1])
		_set_skill_status_focus_neighbor(_combat_skill_card_selection_cancel_button, "right", buttons[0])
		_set_skill_status_focus_neighbor(_combat_skill_card_selection_cancel_button, "up", buttons[buttons.size() - 1])
		_set_skill_status_focus_neighbor(_combat_skill_card_selection_cancel_button, "down", buttons[0])

func _focus_skill_hand_selection_card(button: Button) -> void:
	if _combat_skill_card_selection_zone != "hand" or not _can_restore_gui_focus(button):
		return
	button.grab_focus()
	_ensure_skill_hand_selection_card_visible(button)

func _ensure_skill_hand_selection_card_visible(button: Button) -> void:
	if hand_scroll != null and button != null and button.is_inside_tree():
		hand_scroll.ensure_control_visible(button)

func _reward_card_choice_slot(widget: Control, card_id: String, card_size: Vector2) -> Control:
	var slot: Control = _hand_card_slot(widget, card_size)
	slot.name = "RewardCardChoiceSlot"
	var context: Dictionary = _reward_card_choice_context(card_id)
	slot.set_meta("reward_card_id", card_id)
	slot.set_meta("reward_status", str(context.get("status", "new")))
	if widget != null:
		_add_reward_card_badge(
			widget,
			"RewardOwnershipBadge",
			str(context.get("status", "new")).to_upper(),
			Vector2(12.0, 62.0),
			Vector2(76.0 if bool(context.get("owned", false)) else 58.0, 26.0),
			Color("e2b86d") if bool(context.get("owned", false)) else Color("a8d98d")
		)
	return slot

func _reward_card_choice_context(card_id: String) -> Dictionary:
	var attuned: Array = _run_state.get("attuned_magic_cards", []) as Array
	var inventory: Array = _run_state.get("magic_inventory", []) as Array
	var history: Array = _run_state.get("reward_cards", []) as Array
	var owned: bool = attuned.has(card_id) or inventory.has(card_id) or history.has(card_id)
	return {
		"status": "owned" if owned else "new",
		"owned": owned
	}

func _add_reward_card_badge(parent: Control, badge_name: String, text: String, position: Vector2, badge_size: Vector2, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.name = badge_name
	panel.position = position
	panel.size = badge_size
	panel.custom_minimum_size = badge_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 40
	panel.add_theme_stylebox_override("panel", _reward_card_badge_style(accent))
	parent.add_child(panel)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, 12)
	label.add_theme_color_override("font_color", accent.lightened(0.20))
	label.add_theme_color_override("font_outline_color", Color("130d0a"))
	label.add_theme_constant_override("outline_size", 1)
	panel.add_child(label)

func _reward_card_badge_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.050, 0.040, 0.94)
	style.border_color = accent.darkened(0.12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
	style.shadow_size = 5
	style.content_margin_left = 5
	style.content_margin_right = 5
	return style

func _scaled_card_slot(widget: Control, card_size: Vector2, interactive: bool = false) -> Control:
	card_size = _normalized_card_size(card_size)
	var slot := Control.new()
	slot.custom_minimum_size = card_size
	slot.size = card_size
	slot.clip_contents = false
	slot.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	var scaler := Control.new()
	scaler.name = "CardScaleFrame"
	scaler.custom_minimum_size = CARD_WIDGET_BASE_SIZE
	scaler.size = CARD_WIDGET_BASE_SIZE
	scaler.scale = Vector2.ONE * _card_widget_scale_for_size(card_size)
	scaler.position = (card_size - CARD_WIDGET_BASE_SIZE * scaler.scale.x) * 0.5
	scaler.clip_contents = false
	scaler.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	slot.add_child(scaler)
	_prepare_native_card_widget(widget)
	scaler.add_child(widget)
	widget.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return slot

func _prepare_native_card_widget(widget: Control) -> void:
	if widget == null:
		return
	widget.anchor_left = 0.0
	widget.anchor_top = 0.0
	widget.anchor_right = 0.0
	widget.anchor_bottom = 0.0
	widget.offset_left = 0.0
	widget.offset_top = 0.0
	widget.custom_minimum_size = CARD_WIDGET_BASE_SIZE
	widget.size = CARD_WIDGET_BASE_SIZE
	widget.position = Vector2.ZERO
	widget.scale = Vector2.ONE

func _card_widget_scale_for_size(card_size: Vector2) -> float:
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return 1.0
	return minf(card_size.x / CARD_WIDGET_BASE_SIZE.x, card_size.y / CARD_WIDGET_BASE_SIZE.y)

func _clear_idle_card_fx_layer() -> void:
	if _animation_lock or _card_fx_layer == null or _card_fx_layer.get_child_count() <= 0:
		return
	for child: Node in _card_fx_layer.get_children():
		if child is Control and bool(child.get_meta("scaled_card_proxy", false)):
			_release_card_proxy(child)
	_clear_children_now(_card_fx_layer)
func _refresh_stage_view() -> void:
	_exit_destinations_by_tile = _exit_tile_lookup()
	var display_state: Dictionary = _board_display_state()
	var visibility_state: Dictionary = _board_visibility_state(display_state)
	var move_tiles: Array[Vector2i] = []
	var attack_tiles: Array[Vector2i] = []
	var ability_tiles: Array[Vector2i] = []
	var presentation: Dictionary = _board_presentation.duplicate(false)
	presentation["board_backdrop_visible"] = _board_backdrop_visible_for_board()
	if str(_run_state.get("mode", "room")) == "combat" and not display_state.is_empty():
		presentation["umbra_stage"] = _combat_engine.effective_umbra_stage(visibility_state)
		presentation["umbra_radius"] = _combat_engine.effective_umbra_radius(visibility_state)
		presentation["umbra_visible_tiles"] = _combat_engine.umbra_visible_tiles(visibility_state)
		presentation["visible_enemy_ids"] = _combat_engine.visible_enemy_ids(visibility_state)
		presentation["umbra_light_sources"] = ((visibility_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).duplicate(true)
		var umbra_state: Dictionary = visibility_state.get("umbra", {}) as Dictionary
		presentation["umbra_truesight_activations"] = int(umbra_state.get("truesight_activations", 0))
		presentation["umbra_truesight"] = int(presentation["umbra_truesight_activations"]) != 0
		presentation["umbra_vision_bonus_activations"] = int(umbra_state.get("vision_bonus_activations", 0))
	var preview: Dictionary = {}
	if str(_run_state.get("mode", "room")) == "combat" and not _animation_lock:
		preview = _active_card_preview()
		if not _preview_combat_state.is_empty():
			var cumulative_damage_preview: Dictionary = _damage_preview_between_states(_combat_state, _preview_combat_state)
			if not cumulative_damage_preview.is_empty():
				presentation["damage_preview"] = cumulative_damage_preview
		if not preview.is_empty() and not bool(preview.get("complete", false)):
			var action: Dictionary = preview.get("action", {})
			var action_type: String = str(action.get("type", ""))
			var target_tiles: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
			if action_type in ["move", "blink"]:
				move_tiles = target_tiles
				var shortcuts: Dictionary = _preview_shortcuts_for_current_action(preview)
				attack_tiles = _vector2i_array(shortcuts.get("tiles", []))
				if not attack_tiles.is_empty():
					presentation["pulse_attack_tiles"] = true
			elif action_type in ["melee", "ranged", "aoe", "push", "pull"]:
				if bool(preview.get("orientation_pending", false)):
					attack_tiles = _vector2i_array([preview.get("orientation_target", INVALID_TARGET_TILE)])
					presentation["ability_tiles"] = _direction_choice_tiles(preview.get("orientation_target", INVALID_TARGET_TILE))
				else:
					attack_tiles = target_tiles
					if action_type != "aoe":
						presentation["pulse_attack_tiles"] = true
			else:
				ability_tiles = target_tiles
				presentation["ability_tiles"] = ability_tiles
			var preview_presentation: Dictionary = _preview_presentation(preview)
			for key: Variant in preview_presentation.keys():
				presentation[key] = preview_presentation[key]
		elif _hovered_board_tile.x >= 0:
			var threat_preview: Dictionary = _hovered_enemy_threat(display_state)
			move_tiles = _vector2i_array(threat_preview.get("move", []))
			attack_tiles = _vector2i_array(threat_preview.get("attack", []))
			presentation["path_tiles"] = _vector2i_array(threat_preview.get("projected_path", []))
			presentation["path_color"] = ENEMY_PATH_PREVIEW_COLOR
			presentation["projected_destination"] = threat_preview.get("projected_destination", INVALID_TARGET_TILE)
			presentation["projected_attack_tiles"] = _vector2i_array(threat_preview.get("projected_attack", []))
			if threat_preview.has("enemy_key"):
				presentation["focus_actor_keys"] = [str(threat_preview.get("enemy_key", ""))]
				presentation["focus_actor_color"] = Color("f2ddb2")
		if not _turn_order_hovered_enemy_key.is_empty():
			presentation["expanded_enemy_actor_keys"] = [_turn_order_hovered_enemy_key]
			presentation["focus_actor_keys"] = [_turn_order_hovered_enemy_key]
			presentation["focus_actor_color"] = Color("f2ddb2")
	if not _animation_lock and str(_run_state.get("mode", "room")) == "room" and _hovered_board_tile.x >= 0 and _exit_destinations_by_tile.has(_hovered_board_tile):
		presentation["focus_tiles"] = [_hovered_board_tile]
	if not _animation_lock and str(_run_state.get("mode", "room")) == "room" and not _exit_destinations_by_tile.is_empty():
		presentation["pulse_exit_tiles"] = true
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, _run_state.get("current_room", Vector2i.ZERO))
	if str(current_room.get("type", "")) == "campfire":
		presentation["scene_props"] = [
			{
				"kind": "campfire_bonfire",
				"tile": Vector2i(4, 4),
				"idle_frame_seconds": 0.10
			}
		]
	elif str(current_room.get("type", "")) == "treasure":
		presentation["scene_props"] = [
			{
				"kind": "relic_chest",
				"tile": Vector2i(4, 4),
				"width_scale": 0.68,
				"baseline_scale": 0.44
			}
		]
	elif str(current_room.get("type", "")) == "blacksmith":
		presentation["scene_props"] = [
			{
				"kind": "blacksmith_forge",
				"tile": Vector2i(5, 4),
				"width_scale": 1.04,
				"baseline_scale": 0.50
			}
		]
	elif str(current_room.get("type", "")) == "arcanist":
		presentation["scene_props"] = [
			{
				"kind": "arcanist_table",
				"tile": Vector2i(5, 4),
				"width_scale": 1.06,
				"baseline_scale": 0.50
			}
		]
	elif str(current_room.get("type", "")) == "scavenger":
		presentation["scene_props"] = [
			{
				"kind": "scavenger_stall",
				"tile": Vector2i(5, 4),
				"width_scale": 1.08,
				"baseline_scale": 0.50
			}
		]
	presentation["active_door_tiles"] = _active_door_tiles_for_board()
	presentation["locked_door_tiles"] = _locked_door_tiles_for_board()
	presentation["equipped_equipment"] = _equipped_equipment_for_board()
	presentation["tile_drag_aiming"] = (
		str(_run_state.get("mode", "room")) == "combat"
		and not _animation_lock
		and _current_action_is_aimed_aoe()
	)
	presentation["reduced_motion"] = _reduced_motion_enabled()
	board_view.set_combat_state(
		display_state,
		move_tiles,
		attack_tiles,
		(display_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)),
		_board_status_label(preview),
		_board_status_detail(preview),
		_exit_labels_for_board() if str(_run_state.get("mode", "room")) == "room" else {},
		_exit_icon_ids_for_board() if str(_run_state.get("mode", "room")) == "room" else {},
		presentation
	)
	_refresh_turn_order_boss_dossier(display_state, presentation)

func _hovered_enemy_threat(display_state: Dictionary) -> Dictionary:
	for enemy_index: int in range((display_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (display_state.get("enemies", []) as Array)[enemy_index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if not _combat_engine.is_enemy_visible_to_player(display_state, enemy):
			continue
		if not _enemy_footprint_tiles(enemy).has(_hovered_board_tile):
			continue
		var threat: Dictionary = _combat_engine.enemy_threat_tiles(display_state, enemy_index)
		threat["enemy_key"] = _enemy_key(enemy)
		return threat
	return {}

func _board_display_state() -> Dictionary:
	if str(_run_state.get("mode", "room")) == "combat":
		if _animation_lock:
			if not _combat_state.is_empty():
				return _combat_state
		elif not _preview_combat_state.is_empty():
			return _visibility_safe_preview_display_state(_combat_preview_display_state(_preview_combat_state))
		if not _combat_state.is_empty():
			return _combat_state
	var layout: Dictionary = _run_state.get("current_room_layout", {}) as Dictionary
	return {
		"room_name": layout.get("name", "Room"),
		"room_coord": layout.get("coord", _run_state.get("current_room", Vector2i.ZERO)),
		"room_type": layout.get("type", "room"),
		"room_element": layout.get("element", ElementData.NONE),
		"grid": layout.get("grid", []),
		"moss": layout.get("moss", {}),
		"player": {
			"pos": layout.get("player_start", RoomGeneratorScript.entry_tile_for_direction(Vector2i.ZERO)),
			"hp": int(_run_state.get("player_hp", 1)),
			"max_hp": int(_run_state.get("player_max_hp", 1)),
			"block": 0
		},
		"npcs": layout.get("npcs", []),
		"enemies": [],
		"traps": layout.get("traps", []),
		"loot": layout.get("loot", []),
		"terrain": layout.get("terrain", []),
		"log": []
	}

func _combat_preview_display_state(preview_state: Dictionary) -> Dictionary:
	if preview_state.is_empty() or _combat_state.is_empty():
		return preview_state
	var display_state: Dictionary = preview_state.duplicate(false)
	var committed_by_id: Dictionary = {}
	for committed_var: Variant in _combat_state.get("enemies", []):
		if typeof(committed_var) != TYPE_DICTIONARY:
			continue
		var committed_enemy: Dictionary = committed_var
		committed_by_id[int(committed_enemy.get("id", -1))] = committed_enemy
	var display_enemies: Array = []
	var projected_ids: Dictionary = {}
	for projected_var: Variant in preview_state.get("enemies", []):
		if typeof(projected_var) != TYPE_DICTIONARY:
			continue
		var projected_enemy: Dictionary = (projected_var as Dictionary).duplicate(true)
		var enemy_id: int = int(projected_enemy.get("id", -1))
		projected_ids[enemy_id] = true
		if committed_by_id.has(enemy_id):
			var committed_enemy: Dictionary = committed_by_id[enemy_id]
			for key: String in ["hp", "block", "stoneskin"]:
				projected_enemy[key] = committed_enemy.get(key, projected_enemy.get(key, 0))
		display_enemies.append(projected_enemy)
	for committed_id: Variant in committed_by_id.keys():
		if projected_ids.has(committed_id):
			continue
		display_enemies.append((committed_by_id[committed_id] as Dictionary).duplicate(true))
	display_state["enemies"] = display_enemies
	return display_state

func _board_visibility_state(display_state: Dictionary) -> Dictionary:
	if _unconfirmed_preview_must_preserve_umbra_information():
		return _combat_state
	return display_state

func _visibility_safe_preview_display_state(preview_state: Dictionary) -> Dictionary:
	if not _unconfirmed_preview_must_preserve_umbra_information():
		return preview_state
	var safe_state: Dictionary = preview_state.duplicate(false)
	for key: String in ["player", "umbra", "traps", "loot", "log"]:
		if not _combat_state.has(key):
			continue
		var committed_value: Variant = _combat_state.get(key)
		if typeof(committed_value) == TYPE_DICTIONARY:
			safe_state[key] = (committed_value as Dictionary).duplicate(true)
		elif typeof(committed_value) == TYPE_ARRAY:
			safe_state[key] = (committed_value as Array).duplicate(true)
		else:
			safe_state[key] = committed_value
	return safe_state

func _unconfirmed_preview_must_preserve_umbra_information() -> bool:
	return (
		_selected_card_index >= 0
		and not _pending_umbra_commit_locked
		and not _combat_state.is_empty()
		and not _preview_combat_state.is_empty()
		and _combat_engine.effective_umbra_radius(_combat_state) < CombatEngineScript.UMBRA_UNLIMITED_RADIUS
	)

func _active_card_preview() -> Dictionary:
	if _combat_skill_card_selection_zone == "hand":
		return {}
	if _drag_card_index >= 0:
		if bool(_drag_card_options.get("printed_playable", false)):
			return _drag_card_options.get("play", {}) as Dictionary
		return {}
	if _selected_card_index >= 0:
		if _pending_action_index < _pending_actions.size():
			var action: Dictionary = _pending_actions[_pending_action_index]
			var target_tiles: Array[Vector2i] = _vector2i_array(_pending_target_tiles)
			var orientation_pending: bool = _orientation_pending()
			if orientation_pending:
				action = _pending_oriented_action()
				target_tiles = _vector2i_array([_pending_orientation_target_tile])
			elif str(action.get("type", "")) == "aoe":
				action = _action_with_aoe_aim_orientation(action)
				target_tiles = _combat_engine.valid_targets_for_player_action(_preview_combat_state, action)
			return {
				"card_id": _card_id_for_hand_index(_selected_card_index),
				"state": _preview_combat_state,
				"actions": _pending_actions,
				"action_index": _pending_action_index,
				"target_tiles": target_tiles,
				"complete": false,
				"playable": true,
				"action": action,
				"skip_allowed": _pending_action_can_skip and not orientation_pending,
				"orientation_pending": orientation_pending,
				"orientation_target": _pending_orientation_target_tile
			}
		return {}
	if _hovered_card_index >= 0:
		return _card_preview_for_index(_hovered_card_index)
	return {}

func _card_preview_for_index(index: int) -> Dictionary:
	if _combat_state.is_empty():
		return {}
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return {"playable": false}
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return {}
	var cache_key: String = _card_preview_cache_key(index)
	if _card_preview_cache.has(cache_key):
		return _card_preview_cache.get(cache_key, {}) as Dictionary
	var card_id: String = str(hand[index])
	var prepared_state: Dictionary = _combat_engine.prepare_player_card(_combat_state, index, "play")
	var preview: Dictionary = _card_preview_from_state(card_id, prepared_state, _combat_engine.card_play_actions(card_id, prepared_state), 0)
	_card_preview_cache[cache_key] = preview
	return preview

func _fallback_preview_for_index(index: int, play_kind: String) -> Dictionary:
	if _combat_state.is_empty():
		return {}
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return {"playable": false}
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return {}
	var cache_key: String = _card_preview_cache_key(index, play_kind)
	if _fallback_preview_cache.has(cache_key):
		return _fallback_preview_cache.get(cache_key, {}) as Dictionary
	# Fallback actions and legality are identical for every card in the hand; only
	# the card id carried into the eventual play differs. Compute one state-scoped
	# template per fallback kind instead of repeating path/target work per card.
	var shared_key: String = _card_preview_cache_key(-1, "shared_%s" % play_kind)
	var shared_preview: Dictionary = _fallback_preview_cache.get(shared_key, {}) as Dictionary
	if shared_preview.is_empty():
		var fallback_actions: Array = _fallback_actions(play_kind)
		shared_preview = {"playable": false} if fallback_actions.is_empty() else _card_preview_from_state("", _combat_state, fallback_actions, 0)
		_fallback_preview_cache[shared_key] = shared_preview
	var preview: Dictionary = shared_preview.duplicate(false)
	preview["card_id"] = str(hand[index])
	_fallback_preview_cache[cache_key] = preview
	return preview

func _card_play_options_for_index(index: int) -> Dictionary:
	var cache_key: String = _card_preview_cache_key(index, "options")
	if _card_play_options_cache.has(cache_key):
		return _card_play_options_cache.get(cache_key, {}) as Dictionary
	var printed: Dictionary = _card_preview_for_index(index)
	var attack: Dictionary = _fallback_preview_for_index(index, "attack")
	var move: Dictionary = _fallback_preview_for_index(index, "move")
	var blink: Dictionary = _fallback_preview_for_index(index, "blink")
	var printed_playable: bool = bool(printed.get("playable", false))
	var attack_playable: bool = bool(attack.get("playable", false))
	var move_playable: bool = bool(move.get("playable", false))
	var blink_available: bool = not _combat_engine.fallback_blink_action(_combat_state, FALLBACK_MOVE_RANGE).is_empty()
	var blink_playable: bool = blink_available and bool(blink.get("playable", false))
	var options: Dictionary = {
		"play": printed,
		"attack": attack,
		"move": move,
		"blink": blink,
		"printed_playable": printed_playable,
		"attack_playable": attack_playable,
		"move_playable": move_playable,
		"blink_available": blink_available,
		"blink_playable": blink_playable,
		"any_playable": printed_playable or attack_playable or move_playable or blink_playable
	}
	_card_play_options_cache[cache_key] = options
	return options

func _show_card_action_choices(index: int, options: Dictionary) -> void:
	if not bool(options.get("any_playable", false)):
		return
	_card_action_choice_index = index
	_card_action_choice_options = options.duplicate(true)
	_card_action_choice_mode = "play"
	_hovered_card_index = index
	_selected_card_label_override = ""

func _clear_card_action_choice_state() -> void:
	_card_action_choice_index = -1
	_card_action_choice_options.clear()
	_card_action_choice_mode = "play"

func _cancel_card_action_choice() -> void:
	if _card_action_choice_index < 0:
		return
	if _selected_card_index >= 0:
		_cancel_card_selection()
		return
	_clear_card_action_choice_state()
	_hovered_card_index = -1
	_refresh_ui()

func _on_card_action_choice_pressed(play_kind: String) -> void:
	if _animation_lock or _card_action_choice_index < 0 or str(_run_state.get("mode", "room")) != "combat":
		return
	var hand_index: int = _card_action_choice_index
	var options: Dictionary = _card_play_options_for_index(hand_index)
	var preview_key: String = "play" if play_kind == "play" else play_kind
	var playable_key: String = "printed_playable" if play_kind == "play" else "%s_playable" % play_kind
	var preview: Dictionary = options.get(preview_key, {})
	if not bool(options.get(playable_key, false)) or not bool(preview.get("playable", false)):
		return
	if _selected_card_index == hand_index and _card_action_choice_mode == play_kind:
		return
	var label_override: String = "" if play_kind == "play" else _fallback_label(play_kind)
	_card_action_choice_mode = play_kind
	_card_action_choice_options = options.duplicate(true)
	_clear_active_card_preview_state()
	await _begin_card_preview(hand_index, preview, label_override)

func _fallback_actions(play_kind: String) -> Array:
	match play_kind:
		"attack":
			return [{"type": "melee", "damage": _fallback_attack_damage(), "range": 1}]
		"move":
			return [_combat_engine.fallback_move_action(_combat_state, FALLBACK_MOVE_RANGE)]
		"blink":
			var blink_action: Dictionary = _combat_engine.fallback_blink_action(_combat_state, FALLBACK_MOVE_RANGE)
			return [] if blink_action.is_empty() else [blink_action]
		_:
			return []

func _fallback_attack_damage() -> int:
	return GameData.fixed_point_amount(FALLBACK_ATTACK_BASE_DAMAGE)

func _fallback_label(play_kind: String) -> String:
	match play_kind:
		"attack":
			return "%d Attack" % _fallback_attack_damage()
		"move":
			return "%d Move" % FALLBACK_MOVE_RANGE
		"blink":
			var action: Dictionary = _combat_engine.fallback_blink_action(_combat_state, FALLBACK_MOVE_RANGE)
			return "%d Blink" % int(action.get("range", FALLBACK_MOVE_RANGE))
		_:
			return ""

func _fallback_command_detail(play_kind: String) -> String:
	match play_kind:
		"attack":
			return "%d Damage" % _fallback_attack_damage()
		"move":
			return "Range %d" % FALLBACK_MOVE_RANGE
		"blink":
			var action: Dictionary = _combat_engine.fallback_blink_action(_combat_state, FALLBACK_MOVE_RANGE)
			return "Blink Range %d" % int(action.get("range", FALLBACK_MOVE_RANGE))
		_:
			return ""

func _card_widget_display_for_index(index: int) -> Dictionary:
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return {}
	var cache_key: String = _card_preview_cache_key(index, "display")
	if _card_widget_display_cache.has(cache_key):
		return _card_widget_display_cache.get(cache_key, {}) as Dictionary
	var display: Dictionary = _card_widget_display(str(hand[index]), _combat_state)
	_card_widget_display_cache[cache_key] = display
	return display

func _card_widget_display(card_id: String, state: Dictionary) -> Dictionary:
	var card: Dictionary = _card_def(card_id, state)
	var summary_rows: Array = _annotate_intensity_spend_rows(ActionIcons.cost_rows_for_card(card), state)
	var modifier_lines: PackedStringArray = []
	var preview_state: Dictionary = state.duplicate(true)
	var previous_action_row_index: int = -1
	for action_var: Variant in card.get("actions", []):
		var action: Dictionary = action_var
		var action_type: String = str(action.get("type", ""))
		var row: Array = []
		match action_type:
			"melee", "ranged", "aoe":
				var attack_final_damage: int = _combat_engine.final_damage_for_player_action(preview_state, action)
				var attack_damage_modifiers: Array[Dictionary] = _combat_engine.damage_modifiers_for_player_action(preview_state, action)
				var attack_visible_modifiers: Array[Dictionary] = _non_intensity_damage_modifiers(attack_damage_modifiers)
				row = ActionIcons.tokens_for_action(action, {
					"final_damage": attack_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(attack_final_damage, attack_visible_modifiers, action),
					"damage_modifiers": attack_visible_modifiers
				})
				_consume_preview_damage_modifiers(preview_state, action)
			"push", "pull":
				var shove_final_damage: int = _combat_engine.final_damage_for_player_action(preview_state, action)
				var shove_damage_modifiers: Array[Dictionary] = _combat_engine.damage_modifiers_for_player_action(preview_state, action)
				var shove_visible_modifiers: Array[Dictionary] = _non_intensity_damage_modifiers(shove_damage_modifiers)
				row = ActionIcons.tokens_for_action(action, {
					"final_damage": shove_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(shove_final_damage, shove_visible_modifiers, action),
					"damage_modifiers": shove_visible_modifiers
				})
				_consume_preview_damage_modifiers(preview_state, action)
			_:
				row = ActionIcons.tokens_for_action(action)
		var annotated_row: Array = _annotate_intensity_condition_row(row, _combat_engine.action_intensity_requirement_met(preview_state, action))
		previous_action_row_index = ActionIcons.append_action_row(summary_rows, action, annotated_row, previous_action_row_index)
		if action_type == "intensity" and _combat_engine.player_action_can_resolve(preview_state, action):
			preview_state = _combat_engine.apply_player_action(preview_state, action)
		var bonus_row: Array = ActionIcons.tokens_for_intensity_bonus(action)
		if not bonus_row.is_empty():
			summary_rows.append(_annotate_intensity_condition_row(bonus_row, _combat_engine.action_intensity_bonus_requirement_met(preview_state, action)))
	var summary_text: String = ActionIcons.plain_text_for_rows(summary_rows)
	if summary_text.is_empty():
		summary_text = str(card.get("description", ""))
	return {
		"summary_bbcode": summary_text,
		"summary_rows": summary_rows,
		"modifier_lines": modifier_lines
	}

func _annotate_intensity_condition_row(row: Array, active: bool) -> Array:
	var annotated: Array = []
	for token_var: Variant in row:
		if typeof(token_var) != TYPE_DICTIONARY:
			annotated.append(token_var)
			continue
		var token: Dictionary = (token_var as Dictionary).duplicate(true)
		if str(token.get("kind", "")) == "intensity_requirement":
			token["condition_active"] = active
		annotated.append(token)
	return annotated

func _annotate_intensity_spend_rows(rows: Array, state: Dictionary) -> Array:
	var annotated_rows: Array = []
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			annotated_rows.append(row_var)
			continue
		var annotated_row: Array = []
		for token_var: Variant in row_var as Array:
			if typeof(token_var) != TYPE_DICTIONARY:
				annotated_row.append(token_var)
				continue
			var token: Dictionary = (token_var as Dictionary).duplicate(true)
			if str(token.get("kind", "")) == "intensity_spend":
				var element_id: String = str(token.get("element", ElementData.NONE))
				token["condition_active"] = _combat_engine.elemental_intensity(state, element_id) >= int(token.get("amount", 0))
			annotated_row.append(token)
		annotated_rows.append(annotated_row)
	return annotated_rows

func _non_intensity_damage_modifiers(modifiers: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for modifier: Dictionary in modifiers:
		if str(modifier.get("kind", "")) == "elemental_intensity":
			continue
		filtered.append(modifier)
	return filtered

func _damage_tone_base_excluding_modifiers(
	final_damage: int,
	visible_modifiers: Array[Dictionary],
	action: Dictionary = {}
) -> int:
	var tone_base: int = final_damage
	for modifier: Dictionary in visible_modifiers:
		tone_base -= int(modifier.get("amount", 0))
	var action_modifiers: Dictionary = action.get("_modifiers", {}) as Dictionary
	for modifier_var: Variant in action_modifiers.get("damage", []):
		if typeof(modifier_var) == TYPE_DICTIONARY:
			tone_base -= int((modifier_var as Dictionary).get("amount", 0))
	return tone_base

func _consume_preview_damage_modifiers(state: Dictionary, action: Dictionary) -> void:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["melee", "ranged", "aoe", "push", "pull"]:
		return
	if int(action.get("damage", 0)) <= 0:
		return
	if _combat_engine.attack_bonus_for_current_turn(state) == 0:
		return
	var turn_flags: Dictionary = (state.get("turn_flags", {}) as Dictionary).duplicate(true)
	turn_flags["first_attack_bonus_used"] = true
	state["turn_flags"] = turn_flags

func _has_playable_combat_card() -> bool:
	if _combat_state.is_empty():
		return false
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return false
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		if bool(_card_preview_for_index(index).get("playable", false)):
			return true
	return false

func _has_any_playable_combat_card() -> bool:
	if _combat_state.is_empty():
		return false
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return false
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		if bool(_card_play_options_for_index(index).get("any_playable", false)):
			return true
	return false

func _mark_combat_preview_state_changed() -> void:
	_combat_preview_revision += 1
	_card_preview_cache.clear()
	_fallback_preview_cache.clear()
	_card_play_options_cache.clear()
	_card_widget_display_cache.clear()
	_invalidate_preview_derived_caches()

func _mark_preview_selection_changed() -> void:
	_preview_selection_revision += 1
	_invalidate_preview_derived_caches()

func _invalidate_preview_derived_caches() -> void:
	_preview_shortcuts_cache_key = ""
	_preview_shortcuts_cache.clear()
	_pass_preview_cache.clear()
	_pass_preview_cache_order.clear()

func _card_preview_cache_key(index: int, play_kind: String = "play") -> String:
	return "%d|%d|%d|%s" % [_combat_preview_revision, hash(_combat_state), index, play_kind]

func _preview_shortcuts_key(preview: Dictionary) -> String:
	return "%d|%d|%d|%d|%s|%d|%d|%d|%d" % [
		_combat_preview_revision,
		_preview_selection_revision,
		_selected_card_index,
		_hovered_card_index,
		str(preview.get("card_id", "")),
		int(preview.get("action_index", -1)),
		hash(preview.get("action", {})),
		hash(preview.get("target_tiles", [])),
		hash(preview.get("state", {}))
	]

func _pass_preview_key() -> String:
	return "%d|%d|%d|%d|%d|%d,%d|%d,%d|%d,%d|%d|%d|%d|%d|%d" % [
		_combat_preview_revision,
		_preview_selection_revision,
		_selected_card_index,
		_hovered_card_index,
		_pending_action_index,
		_hovered_board_tile.x,
		_hovered_board_tile.y,
		_aoe_aim_orientation.x,
		_aoe_aim_orientation.y,
		_pending_orientation_target_tile.x,
		_pending_orientation_target_tile.y,
		hash(_pending_actions),
		hash(_pending_target_tiles),
		hash(_pending_selected_targets),
		hash(_preview_combat_state),
		hash(_combat_state)
	]

func _cache_pass_preview(key: String, summary: Dictionary) -> void:
	if _pass_preview_cache.has(key):
		return
	_pass_preview_cache[key] = summary
	_pass_preview_cache_order.append(key)
	while _pass_preview_cache_order.size() > PASS_PREVIEW_CACHE_LIMIT:
		var expired_key: String = _pass_preview_cache_order.pop_front()
		_pass_preview_cache.erase(expired_key)

func _card_preview_from_state(card_id: String, combat_state: Dictionary, actions: Array, action_index: int, has_effect: bool = false, use_position_only_move_legality: bool = true) -> Dictionary:
	var working_state: Dictionary = combat_state
	var cursor: int = action_index
	var effect_seen: bool = has_effect or action_index > 0
	while cursor < actions.size():
		var action: Dictionary = actions[cursor]
		if not _combat_engine.player_action_can_resolve(working_state, action):
			if str(action.get("type", "")) == "intensity_spend" and bool(action.get("required", false)):
				return {
					"card_id": card_id,
					"state": working_state,
					"actions": actions,
					"action_index": cursor,
					"target_tiles": _vector2i_array([]),
					"complete": true,
					"playable": false,
					"action": action,
					"skip_allowed": false
				}
			cursor += 1
			continue
		if str(action.get("type", "")) == "aoe" and int(action.get("range", 0)) <= 0:
			if _combat_engine.valid_targets_for_player_action(working_state, action).is_empty():
				cursor += 1
				continue
			working_state = _combat_engine.apply_player_action(working_state, action)
			effect_seen = true
			cursor += 1
			continue
		if _combat_engine.player_action_needs_target(action):
			var skip_allowed: bool = _target_action_can_skip(action, actions)
			var skip_playable: bool = false
			if skip_allowed:
				skip_playable = bool(_card_preview_from_state(card_id, working_state, actions, cursor + 1, effect_seen, use_position_only_move_legality).get("playable", false))
			var candidate_targets: Array[Vector2i] = _combat_engine.valid_targets_for_player_action(working_state, action)
			if _umbra_defers_movement_followup_preview(working_state, action, actions, cursor):
				return {
					"card_id": card_id,
					"state": working_state,
					"actions": actions,
					"action_index": cursor,
					"target_tiles": _vector2i_array(candidate_targets),
					"complete": false,
					"playable": not candidate_targets.is_empty(),
					"action": action,
					"skip_allowed": skip_playable
				}
			if _remaining_actions_are_targetless(actions, cursor + 1):
				if candidate_targets.is_empty() and skip_playable:
					cursor += 1
					continue
				return {
					"card_id": card_id,
					"state": working_state,
					"actions": actions,
					"action_index": cursor,
					"target_tiles": _vector2i_array(candidate_targets),
					"complete": false,
					"playable": not candidate_targets.is_empty(),
					"action": action,
					"skip_allowed": skip_playable
				}
			var valid_targets: Array[Vector2i] = []
			var movement_plan: Dictionary = {}
			var can_use_position_only_move: bool = false
			var movement_trap_tiles: Dictionary = {}
			if str(action.get("type", "")) == "move":
				movement_plan = _combat_engine.movement_plan_for_player_action(working_state, action, candidate_targets)
				can_use_position_only_move = (
					use_position_only_move_legality
					and int((working_state.get("player", {}) as Dictionary).get("bleed", 0)) <= 0
				)
				if can_use_position_only_move:
					movement_trap_tiles = _preview_trap_tiles_lookup(working_state)
			for target_tile: Vector2i in candidate_targets:
				var next_state: Dictionary = {}
				if not movement_plan.is_empty():
					var planned_path: Array[Vector2i] = _combat_engine.path_from_player_movement_plan(movement_plan, target_tile)
					if can_use_position_only_move and not _preview_path_hits_lookup(planned_path, movement_trap_tiles):
						next_state = _preview_state_with_player_position(working_state, target_tile)
					else:
						next_state = _combat_engine.apply_prevalidated_player_move(working_state, action, target_tile, planned_path)
				else:
					next_state = _combat_engine.apply_player_action(working_state, action, target_tile)
				var continuation: Dictionary = _card_preview_from_state(card_id, next_state, actions, cursor + 1, true, use_position_only_move_legality)
				if bool(continuation.get("playable", false)):
					valid_targets.append(target_tile)
			if valid_targets.is_empty() and skip_playable:
				cursor += 1
				continue
			return {
				"card_id": card_id,
				"state": working_state,
				"actions": actions,
				"action_index": cursor,
				"target_tiles": _vector2i_array(valid_targets),
				"complete": false,
				"playable": not valid_targets.is_empty(),
				"action": action,
				"skip_allowed": skip_playable
			}
		working_state = _combat_engine.apply_player_action(working_state, action)
		effect_seen = true
		cursor += 1
	return {
		"card_id": card_id,
		"state": working_state,
		"actions": actions,
		"action_index": cursor,
		"target_tiles": _vector2i_array([]),
		"complete": true,
		"playable": effect_seen,
		"action": {},
		"skip_allowed": false
	}

func _umbra_defers_movement_followup_preview(state: Dictionary, action: Dictionary, actions: Array, action_index: int) -> bool:
	if str(action.get("type", "")) not in ["move", "blink"]:
		return false
	if _combat_engine.effective_umbra_radius(state) >= CombatEngineScript.UMBRA_UNLIMITED_RADIUS:
		return false
	for index: int in range(action_index + 1, actions.size()):
		if typeof(actions[index]) == TYPE_DICTIONARY and _combat_engine.player_action_needs_target(actions[index] as Dictionary):
			return true
	return false

func _preview_trap_tiles_lookup(state: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var tile: Vector2i = (trap_var as Dictionary).get("pos", INVALID_TARGET_TILE)
		if tile.x >= 0:
			lookup[tile] = true
	return lookup

func _preview_path_hits_lookup(path_tiles: Array[Vector2i], tile_lookup: Dictionary) -> bool:
	if tile_lookup.is_empty():
		return false
	for index: int in range(1, path_tiles.size()):
		if tile_lookup.has(path_tiles[index]):
			return true
	return false

func _preview_state_with_player_position(state: Dictionary, target_tile: Vector2i) -> Dictionary:
	var preview_state: Dictionary = state.duplicate(false)
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(false)
	player["pos"] = target_tile
	preview_state["player"] = player
	return preview_state

func _remaining_actions_are_targetless(actions: Array, start_index: int) -> bool:
	for index: int in range(maxi(0, start_index), actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		if _combat_engine.player_action_needs_target(actions[index] as Dictionary):
			return false
	return true

func _target_action_can_skip(action: Dictionary, actions: Array) -> bool:
	if bool(action.get("required", false)):
		return false
	if bool(action.get("optional", false)):
		return true
	return actions.size() > 1

func _preview_presentation(preview: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"focus_actor_keys": ["player"]
	}
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	result["focus_actor_color"] = Color("ffe394") if action_type in ["illuminate", "vision", "truesight", "dispel_umbra"] else PLAYER_PREVIEW_FOCUS if action_type in ["move", "blink", "illusion"] else PLAYER_ATTACK_FOCUS
	var focus_tiles: Array[Vector2i] = _focus_tiles_for_preview(preview)
	if not focus_tiles.is_empty():
		result["focus_tiles"] = focus_tiles
		if action_type == "illusion":
			result["focus_color"] = Color(0.42, 0.88, 0.42, 0.22)
		elif action_type == "illuminate":
			result["focus_color"] = Color(1.0, 0.84, 0.38, 0.28)
		else:
			result["focus_color"] = Color(0.42, 0.84, 0.93, 0.24) if action_type in ["move", "blink"] else Color(0.95, 0.62, 0.37, 0.22)
	var path_tiles: Array[Vector2i] = _path_tiles_for_preview(preview)
	if not path_tiles.is_empty():
		result["path_tiles"] = path_tiles
	var effect: Dictionary = _preview_effect_for_action(preview)
	if not effect.is_empty():
		result["effect"] = effect
	var preview_units: Array = _preview_units_for_action(preview)
	if not preview_units.is_empty():
		result["preview_units"] = preview_units
	var movement_risk_chips: Array = _movement_risk_chips_for_preview(preview, path_tiles)
	if not movement_risk_chips.is_empty():
		result["movement_risk_chips"] = movement_risk_chips
	return result

func _preview_units_for_action(preview: Dictionary) -> Array:
	var action: Dictionary = preview.get("action", {})
	if str(action.get("type", "")) != "illusion":
		return []
	if _selected_card_index < 0 or _hovered_board_tile.x < 0:
		return []
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return []
	var health: int = maxi(1, int(action.get("health", action.get("amount", 1))))
	return [{
		"key": "illusion_preview",
		"role": "illusion_preview",
		"type": "player",
		"name": "Illusion preview",
		"pos": _hovered_board_tile,
		"hp": health,
		"max_hp": health,
		"accent": ILLUSION_PREVIEW_FOCUS
	}]

func _focus_tiles_for_preview(preview: Dictionary) -> Array[Vector2i]:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if bool(preview.get("orientation_pending", false)):
		var orientation_target: Vector2i = preview.get("orientation_target", INVALID_TARGET_TILE)
		if action_type == "aoe":
			return _aoe_tiles_for_action(preview.get("state", {}), action, orientation_target)
		if action_type in ["push", "pull"] or int(action.get("push", 0)) > 0 or int(action.get("pull", 0)) > 0:
			var force_tiles: Array[Vector2i] = _combat_engine.forced_movement_tiles_for_player_action(preview.get("state", {}), action, orientation_target)
			force_tiles.push_front(orientation_target)
			return force_tiles
		return _vector2i_array([orientation_target])
	if _hovered_board_tile.x < 0:
		return []
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	if not shortcut_plan.is_empty():
		var path_tiles: Array[Vector2i] = _vector2i_array(shortcut_plan.get("path_tiles", []))
		return path_tiles if not path_tiles.is_empty() else _vector2i_array([_hovered_board_tile])
	if action_type == "aoe" and _aoe_hover_can_show_pattern(preview.get("state", {}), action, _hovered_board_tile):
		return _aoe_tiles_for_action(preview.get("state", {}), action, _hovered_board_tile)
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return []
	if action_type in ["move", "blink"]:
		return _path_tiles_for_preview(preview)
	return _vector2i_array([_hovered_board_tile])

func _path_tiles_for_preview(preview: Dictionary) -> Array[Vector2i]:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if _hovered_board_tile.x < 0:
		return []
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	if not shortcut_plan.is_empty():
		return _vector2i_array(shortcut_plan.get("path_tiles", []))
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return []
	if action_type == "move":
		var preview_state: Dictionary = preview.get("state", {})
		var movement_plan: Dictionary = _preview_shortcuts_for_current_action(preview).get("movement_plan", {}) as Dictionary
		if not movement_plan.is_empty():
			return _combat_engine.path_from_player_movement_plan(movement_plan, _hovered_board_tile)
		return _combat_engine.path_for_player_action(preview_state, action, _hovered_board_tile)
	if action_type == "blink":
		return _vector2i_array([_hovered_board_tile])
	return []

func _preview_effect_for_action(preview: Dictionary) -> Dictionary:
	var action: Dictionary = preview.get("action", {})
	if bool(preview.get("orientation_pending", false)):
		var orientation_target: Vector2i = preview.get("orientation_target", INVALID_TARGET_TILE)
		var orientation_state: Dictionary = preview.get("state", {})
		var orientation_player_tile: Vector2i = (orientation_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		return _preview_effect_for_target(orientation_state, orientation_player_tile, orientation_target, action)
	if _hovered_board_tile.x < 0:
		return {}
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	var preview_state: Dictionary = preview.get("state", {})
	if not shortcut_plan.is_empty():
		return _preview_effect_for_target(
			(shortcut_plan.get("state", preview_state) as Dictionary),
			shortcut_plan.get("move_tile", INVALID_TARGET_TILE),
			_hovered_board_tile,
			shortcut_plan.get("action", {})
		)
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return {}
	var player_tile: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	return _preview_effect_for_target(preview_state, player_tile, _hovered_board_tile, action)

func _preview_effect_for_target(state: Dictionary, from_tile: Vector2i, target_tile: Vector2i, action: Dictionary) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move":
			return {"kind": "move", "from": from_tile, "to": target_tile, "preview": true}
		"blink":
			return {"kind": "blink", "from": from_tile, "to": target_tile, "preview": true}
		"melee", "ranged", "push", "pull":
			var force_tiles: Array[Vector2i] = _combat_engine.forced_movement_tiles_for_player_action(state, action, target_tile)
			return {
				"kind": "ranged" if action_type in ["push", "pull"] else action_type,
				"from": from_tile,
				"to": target_tile,
				"preview": true,
				"element": str(action.get("element", action.get("_card_element", ElementData.NONE))),
				"force_tiles": force_tiles,
				"damage_preview": _preview_damage_for_action(state, action, target_tile)
			}
		"aoe":
			return {
				"kind": "aoe",
				"from": from_tile,
				"to": target_tile,
				"center": target_tile,
				"tiles": _aoe_tiles_for_action(state, action, target_tile),
				"preview": true,
				"element": str(action.get("element", action.get("_card_element", ElementData.NONE))),
				"damage_preview": _preview_damage_for_action(state, action, target_tile)
			}
		_:
			return {}

func _preview_damage_for_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["melee", "ranged", "aoe", "push", "pull"]:
		return {}
	if action_type != "aoe" and target_tile.x < 0:
		return {}
	var after_state: Dictionary = _combat_engine.apply_player_action(state, action, target_tile)
	return _damage_preview_between_states(state, after_state)

func _damage_preview_between_states(before_state: Dictionary, after_state: Dictionary) -> Dictionary:
	var after_by_id: Dictionary = {}
	for after_var: Variant in after_state.get("enemies", []):
		if typeof(after_var) != TYPE_DICTIONARY:
			continue
		var after_enemy: Dictionary = after_var
		after_by_id[int(after_enemy.get("id", -1))] = after_enemy
	var preview: Dictionary = {}
	for before_var: Variant in before_state.get("enemies", []):
		if typeof(before_var) != TYPE_DICTIONARY:
			continue
		var before_enemy: Dictionary = before_var
		var enemy_id: int = int(before_enemy.get("id", -1))
		if int(before_enemy.get("hp", 0)) <= 0:
			continue
		var after_enemy: Dictionary = after_by_id.get(enemy_id, {}) as Dictionary
		var after_hp: int = int(after_enemy.get("hp", 0))
		var after_block: int = int(after_enemy.get("block", 0))
		var after_stoneskin: int = int(after_enemy.get("stoneskin", 0))
		var hp_loss: int = maxi(0, int(before_enemy.get("hp", 0)) - after_hp)
		var block_loss: int = maxi(0, int(before_enemy.get("block", 0)) - after_block)
		var stoneskin_loss: int = maxi(0, int(before_enemy.get("stoneskin", 0)) - after_stoneskin)
		if hp_loss <= 0 and block_loss <= 0 and stoneskin_loss <= 0:
			continue
		preview[_enemy_key(before_enemy)] = {
			"hp": after_hp,
			"hp_loss": hp_loss,
			"block": after_block,
			"block_loss": block_loss,
			"stoneskin": after_stoneskin,
			"stoneskin_loss": stoneskin_loss,
			"lethal": after_hp <= 0
		}
	var after_terrain_by_id: Dictionary = {}
	for after_terrain_var: Variant in after_state.get("terrain", []):
		if typeof(after_terrain_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = after_terrain_var
		after_terrain_by_id[str(after_terrain.get("id", ""))] = after_terrain
	for before_terrain_var: Variant in before_state.get("terrain", []):
		if typeof(before_terrain_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = before_terrain_var
		var terrain_id: String = str(before_terrain.get("id", ""))
		if terrain_id.is_empty() or not after_terrain_by_id.has(terrain_id):
			continue
		var after_terrain: Dictionary = after_terrain_by_id[terrain_id]
		var after_hp: int = int(after_terrain.get("hp", 0))
		var hp_loss: int = maxi(0, int(before_terrain.get("hp", 0)) - after_hp)
		if hp_loss <= 0:
			continue
		preview[_terrain_key(before_terrain)] = {
			"hp": after_hp,
			"hp_loss": hp_loss,
			"lethal": after_hp <= 0
		}
	return preview

func _hovered_shortcut_plan_for_preview(preview: Dictionary) -> Dictionary:
	if _hovered_board_tile.x < 0:
		return {}
	var shortcuts: Dictionary = _preview_shortcuts_for_current_action(preview)
	var plans: Dictionary = shortcuts.get("plans", {})
	return plans.get(_hovered_board_tile, {}) as Dictionary

func _preview_shortcuts_for_current_action(preview: Dictionary, skip_spatial_prefilter: bool = false) -> Dictionary:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["move", "blink"]:
		return {}
	var cache_key: String = _preview_shortcuts_key(preview)
	if not skip_spatial_prefilter and cache_key == _preview_shortcuts_cache_key:
		return _preview_shortcuts_cache
	var actions: Array = preview.get("actions", [])
	var action_index: int = int(preview.get("action_index", -1))
	var card_id: String = str(preview.get("card_id", ""))
	if action_index < 0 or action_index >= actions.size() or card_id.is_empty():
		return {}
	var preview_state: Dictionary = preview.get("state", {}) as Dictionary
	if preview_state.is_empty():
		return {}
	# Under Umbra, simulating movement and then exposing the discovered follow-up
	# target would reveal an enemy before the player commits to moving.
	if _combat_engine.effective_umbra_radius(preview_state) < CombatEngineScript.UMBRA_UNLIMITED_RADIUS:
		return {}
	var player_tile: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var plans: Dictionary = {}
	var move_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	var movement_plan: Dictionary = {}
	if action_type == "move":
		movement_plan = _combat_engine.movement_plan_for_player_action(preview_state, action, move_targets)
	var immediate_attack_tiles: Array[Vector2i] = _vector2i_array([])
	var can_prefilter_immediate_attack: bool = false
	if not skip_spatial_prefilter and action_index + 1 < actions.size() and typeof(actions[action_index + 1]) == TYPE_DICTIONARY:
		var immediate_action: Dictionary = actions[action_index + 1]
		if str(immediate_action.get("type", "")) in SHORTCUT_ATTACK_TYPES and _combat_engine.player_action_can_resolve(preview_state, immediate_action):
			can_prefilter_immediate_attack = true
			immediate_attack_tiles = _shortcut_attackable_tiles_for_action(preview_state, immediate_action)
	for move_target: Vector2i in move_targets:
		if can_prefilter_immediate_attack and not _shortcut_tile_in_attack_range(move_target, immediate_attack_tiles, int((actions[action_index + 1] as Dictionary).get("range", 1))):
			continue
		var path_tiles: Array[Vector2i] = _vector2i_array([])
		var after_move_state: Dictionary = {}
		if action_type == "blink":
			path_tiles = _vector2i_array([move_target])
			after_move_state = _combat_engine.apply_player_action(preview_state, action, move_target)
		else:
			path_tiles = _combat_engine.path_from_player_movement_plan(movement_plan, move_target)
			after_move_state = _combat_engine.apply_prevalidated_player_move(preview_state, action, move_target, path_tiles)
		var move_distance: int = PathUtils.manhattan(player_tile, move_target) if action_type == "blink" else maxi(0, path_tiles.size() - 1)
		var movement_risk_chips: Array = _movement_risk_chips_for_states(preview_state, after_move_state, path_tiles)
		_collect_shortcut_attack_plans(plans, card_id, actions, action_index, after_move_state, move_target, move_target, move_distance, path_tiles, movement_risk_chips)
	if bool(preview.get("skip_allowed", false)):
		_collect_shortcut_attack_plans(plans, card_id, actions, action_index, preview_state, INVALID_TARGET_TILE, player_tile, 0, [])
	var tiles: Array[Vector2i] = []
	for tile_var: Variant in plans.keys():
		if typeof(tile_var) == TYPE_VECTOR2I:
			tiles.append(tile_var)
	var result: Dictionary = {
		"plans": plans,
		"tiles": tiles,
		"movement_plan": movement_plan
	}
	if not skip_spatial_prefilter:
		_preview_shortcuts_cache_key = cache_key
		_preview_shortcuts_cache = result
	return result

func _shortcut_attackable_tiles_for_action(state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = _vector2i_array([])
	var seen: Dictionary = {}
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		if int(enemy.get("hp", 0)) <= 0:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			if not seen.has(tile):
				seen[tile] = true
				result.append(tile)
	if str(action.get("type", "")) not in ["melee", "ranged"]:
		return result
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		var terrain_tile: Vector2i = terrain.get("pos", INVALID_TARGET_TILE)
		if int(terrain.get("hp", 0)) > 0 and terrain_tile.x >= 0 and not seen.has(terrain_tile):
			seen[terrain_tile] = true
			result.append(terrain_tile)
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap_tile: Vector2i = (trap_var as Dictionary).get("pos", INVALID_TARGET_TILE)
		if trap_tile.x >= 0 and not seen.has(trap_tile):
			seen[trap_tile] = true
			result.append(trap_tile)
	return result

func _shortcut_tile_in_attack_range(source_tile: Vector2i, attackable_tiles: Array[Vector2i], attack_range: int) -> bool:
	for attackable_tile: Vector2i in attackable_tiles:
		if PathUtils.manhattan(source_tile, attackable_tile) <= attack_range:
			return true
	return false

func _collect_shortcut_attack_plans(plans: Dictionary, card_id: String, actions: Array, action_index: int, base_state: Dictionary, move_target: Vector2i, move_tile: Vector2i, move_distance: int, path_tiles: Array[Vector2i], movement_risk_chips: Array = []) -> void:
	var followup: Dictionary = _next_shortcut_attack_step(base_state, actions, action_index + 1)
	if followup.is_empty():
		return
	var followup_state: Dictionary = followup.get("state", {})
	var followup_action: Dictionary = followup.get("action", {})
	var followup_index: int = int(followup.get("action_index", -1))
	for enemy_tile: Vector2i in _combat_engine.valid_targets_for_player_action(followup_state, followup_action):
		# A valid final attack already completes the card. Avoid cloning and resolving
		# the full combat state solely to rediscover that the action list has ended.
		if followup_index + 1 < actions.size():
			var after_attack_state: Dictionary = _combat_engine.apply_player_action(followup_state, followup_action, enemy_tile)
			var continuation: Dictionary = _card_preview_from_state(card_id, after_attack_state, actions, followup_index + 1, true)
			if not bool(continuation.get("playable", false)):
				continue
		var existing: Dictionary = plans.get(enemy_tile, {})
		if not existing.is_empty():
			var existing_distance: int = int(existing.get("move_distance", 99999))
			var existing_path_length: int = _vector2i_array(existing.get("path_tiles", [])).size()
			if move_distance > existing_distance:
				continue
			if move_distance == existing_distance and path_tiles.size() >= existing_path_length:
				continue
		plans[enemy_tile] = {
			"state": followup_state,
			"move_target": move_target,
			"move_tile": move_tile,
			"move_distance": move_distance,
			"path_tiles": path_tiles,
			"movement_risk_chips": movement_risk_chips.duplicate(true),
			"action_index": followup_index,
			"action": followup_action
		}

func _shortcut_movement_risk_chips(shortcut_plan: Dictionary) -> Array:
	var chips: Array = []
	for chip_var: Variant in shortcut_plan.get("movement_risk_chips", []):
		if typeof(chip_var) == TYPE_DICTIONARY:
			chips.append((chip_var as Dictionary).duplicate(true))
	return chips

func _movement_risk_chips_for_preview(preview: Dictionary, path_tiles: Array[Vector2i]) -> Array:
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	if not shortcut_plan.is_empty():
		return _shortcut_movement_risk_chips(shortcut_plan)
	if _hovered_board_tile.x < 0 or path_tiles.is_empty():
		return []
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["move", "blink"]:
		return []
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return []
	var before_state: Dictionary = preview.get("state", {}) as Dictionary
	if before_state.is_empty():
		return []
	if _combat_engine.effective_umbra_radius(before_state) < CombatEngineScript.UMBRA_UNLIMITED_RADIUS:
		return []
	var after_state: Dictionary = _combat_engine.apply_player_action(before_state, action, _hovered_board_tile)
	return _movement_risk_chips_for_states(before_state, after_state, path_tiles)

func _movement_risk_chips_for_states(before_state: Dictionary, after_state: Dictionary, path_tiles: Array[Vector2i]) -> Array:
	var chips: Array = []
	var triggered_traps: Array = _movement_triggered_traps_between(before_state, after_state)
	var picked_loot: Array = _movement_picked_loot_between(before_state, after_state)
	var risk_tile: Vector2i = _movement_risk_chip_tile(path_tiles, triggered_traps)
	if not triggered_traps.is_empty():
		chips.append_array(_movement_player_delta_chips(before_state, after_state, risk_tile))
	for loot: Dictionary in picked_loot:
		var pickup_chip: Dictionary = _movement_pickup_chip(loot)
		if not pickup_chip.is_empty():
			chips.append(pickup_chip)
	return chips

func _movement_player_delta_chips(before_state: Dictionary, after_state: Dictionary, tile: Vector2i) -> Array:
	var chips: Array = []
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var hp_loss: int = maxi(0, int(before_player.get("hp", 0)) - int(after_player.get("hp", 0)))
	if hp_loss > 0:
		chips.append({"tile": tile, "label": "-%d HP" % hp_loss, "kind": "danger"})
	var block_loss: int = maxi(0, int(before_player.get("block", 0)) - int(after_player.get("block", 0)))
	if block_loss > 0:
		chips.append({"tile": tile, "label": "-%d Block" % block_loss, "kind": "danger"})
	var stoneskin_loss: int = maxi(0, int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0)))
	if stoneskin_loss > 0:
		chips.append({"tile": tile, "label": "-%d Guard" % stoneskin_loss, "kind": "danger"})
	for label: String in _movement_status_delta_labels(before_state, after_state):
		chips.append({"tile": tile, "label": label, "kind": "status"})
	return chips

func _movement_status_delta_labels(before_state: Dictionary, after_state: Dictionary) -> PackedStringArray:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var labels := PackedStringArray()
	var seen: Dictionary = {}
	for key: String in ["burn", "freeze", "shock"]:
		if int(after_player.get(key, 0)) > int(before_player.get(key, 0)):
			var label: String = key.capitalize()
			labels.append(label)
			seen[label] = true
	if bool(after_player.get("immobilize", false)) and not bool(before_player.get("immobilize", false)):
		labels.append("Immobilize")
		seen["Immobilize"] = true
	var before_poison: Dictionary = before_player.get("poison", {})
	var after_poison: Dictionary = after_player.get("poison", {})
	if int(after_poison.get("damage", 0)) > int(before_poison.get("damage", 0)):
		labels.append("Poison")
		seen["Poison"] = true
	var pending_label: String = str(after_state.get("pending_player_trap_restriction", "")).capitalize()
	if not pending_label.is_empty() and str(after_state.get("pending_player_trap_restriction", "")) != str(before_state.get("pending_player_trap_restriction", "")) and not seen.has(pending_label):
		labels.append(pending_label)
	return labels

func _movement_pickup_chip(loot: Dictionary) -> Dictionary:
	var tile: Vector2i = loot.get("pos", INVALID_TARGET_TILE)
	if tile.x < 0:
		return {}
	var amount: int = int(loot.get("amount", 0))
	var label: String = "Pickup"
	match str(loot.get("kind", "")):
		"healing_vial":
			label = "+%d HP" % amount
		"rusty_shield":
			label = "+%d Block" % amount
		"dropped_embers":
			label = "+%d Embers" % amount
		"equipment":
			label = "Gear"
	return {"tile": tile, "label": label, "kind": "pickup"}

func _movement_risk_chip_tile(path_tiles: Array[Vector2i], triggered_traps: Array) -> Vector2i:
	for trap: Dictionary in triggered_traps:
		var trap_tile: Vector2i = trap.get("pos", INVALID_TARGET_TILE)
		if trap_tile.x >= 0:
			return trap_tile
	if not path_tiles.is_empty():
		return path_tiles[path_tiles.size() - 1]
	return INVALID_TARGET_TILE

func _movement_triggered_traps_between(before_state: Dictionary, after_state: Dictionary) -> Array:
	var after_traps: Dictionary = {}
	for trap_var: Variant in after_state.get("traps", []):
		if typeof(trap_var) == TYPE_DICTIONARY:
			after_traps[_movement_trap_key(trap_var as Dictionary)] = true
	var triggered: Array = []
	for trap_var: Variant in before_state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if not after_traps.has(_movement_trap_key(trap)):
			triggered.append(trap.duplicate(true))
	return triggered

func _movement_picked_loot_between(before_state: Dictionary, after_state: Dictionary) -> Array:
	var after_claimed: Dictionary = {}
	for loot_var: Variant in after_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var after_loot: Dictionary = loot_var
		if bool(after_loot.get("claimed", false)):
			after_claimed[_movement_loot_key(after_loot)] = true
	var picked: Array = []
	for loot_var: Variant in before_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var before_loot: Dictionary = loot_var
		if bool(before_loot.get("claimed", false)):
			continue
		if after_claimed.has(_movement_loot_key(before_loot)):
			picked.append(before_loot.duplicate(true))
	return picked

func _movement_trap_key(trap: Dictionary) -> String:
	var trap_id: String = str(trap.get("id", ""))
	if not trap_id.is_empty():
		return trap_id
	var pos: Vector2i = trap.get("pos", Vector2i.ZERO)
	return "%s:%d:%d" % [str(trap.get("element", "")), pos.x, pos.y]

func _movement_loot_key(loot: Dictionary) -> String:
	var loot_id: String = str(loot.get("id", ""))
	if not loot_id.is_empty():
		return loot_id
	var pos: Vector2i = loot.get("pos", Vector2i.ZERO)
	return "%s:%d:%d" % [str(loot.get("kind", "")), pos.x, pos.y]

func _next_shortcut_attack_step(state: Dictionary, actions: Array, action_index: int) -> Dictionary:
	var working_state: Dictionary = state
	var cursor: int = action_index
	while cursor < actions.size():
		var action: Dictionary = actions[cursor]
		if not _combat_engine.player_action_can_resolve(working_state, action):
			cursor += 1
			continue
		if _combat_engine.player_action_needs_target(action):
			var action_type: String = str(action.get("type", ""))
			if action_type not in SHORTCUT_ATTACK_TYPES:
				return {}
			return {
				"state": working_state,
				"action_index": cursor,
				"action": action
			}
		working_state = _combat_engine.apply_player_action(working_state, action)
		cursor += 1
	return {}

func _aoe_tiles_for_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = INVALID_TARGET_TILE) -> Array[Vector2i]:
	if str(action.get("type", "")) != "aoe":
		return []
	return _combat_engine.aoe_tiles_for_player_action(state, action, target_tile)

func _aoe_hover_can_show_pattern(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> bool:
	if str(action.get("type", "")) != "aoe":
		return false
	if target_tile.x < 0:
		return false
	var grid: Array = state.get("grid", [])
	if int(action.get("range", 0)) <= 0:
		return true
	var player_tile: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	return (
		PathUtils.is_passable(grid, target_tile)
		and PathUtils.manhattan(player_tile, target_tile) <= int(action.get("range", 0))
		and PathUtils.has_line_of_sight(grid, player_tile, target_tile)
	)

func _orientation_pending() -> bool:
	return _selected_card_index >= 0 and _pending_orientation_target_tile.x >= 0 and _pending_action_index < _pending_actions.size()

func _current_action_is_aimed_aoe() -> bool:
	if _selected_card_index < 0 or _pending_action_index < 0 or _pending_action_index >= _pending_actions.size():
		return false
	return str((_pending_actions[_pending_action_index] as Dictionary).get("type", "")) == "aoe"

func _action_with_aoe_aim_orientation(action: Dictionary) -> Dictionary:
	if str(action.get("type", "")) != "aoe":
		return action
	var oriented: Dictionary = action.duplicate(true)
	if _combat_engine.player_action_needs_orientation(action):
		oriented["orientation"] = _aoe_aim_orientation
	else:
		oriented.erase("orientation")
	return oriented

func _reset_aoe_aim_orientation_for_action(action: Dictionary) -> void:
	var direction: Vector2i = _cardinal_direction(action.get("orientation", Vector2i(1, 0)))
	_aoe_aim_orientation = direction if direction != Vector2i.ZERO else Vector2i(1, 0)

func _refresh_pending_aoe_target_tiles() -> void:
	if not _current_action_is_aimed_aoe():
		return
	var action: Dictionary = _action_with_aoe_aim_orientation(_pending_actions[_pending_action_index])
	_pending_target_tiles = _combat_engine.valid_targets_for_player_action(_preview_combat_state, action)

func _set_aoe_aim_orientation(direction: Vector2i) -> void:
	var snapped: Vector2i = _cardinal_direction(direction)
	if snapped == Vector2i.ZERO or snapped == _aoe_aim_orientation:
		return
	_aoe_aim_orientation = snapped
	if _current_action_is_aimed_aoe():
		_refresh_pending_aoe_target_tiles()
		_mark_preview_selection_changed()
		_refresh_stage_view()
		_update_action_context_copy()

func _rotate_aoe_aim(step: int) -> void:
	var current_index: int = ORIENTATION_DIRECTIONS.find(_aoe_aim_orientation)
	if current_index < 0:
		current_index = ORIENTATION_DIRECTIONS.find(Vector2i(1, 0))
	if current_index < 0:
		current_index = 0
	_set_aoe_aim_orientation(ORIENTATION_DIRECTIONS[posmod(current_index + step, ORIENTATION_DIRECTIONS.size())])

func _direction_from_tiles(start_tile: Vector2i, current_tile: Vector2i) -> Vector2i:
	if start_tile.x < 0 or current_tile.x < 0 or start_tile == current_tile:
		return Vector2i.ZERO
	var delta: Vector2i = current_tile - start_tile
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(1 if delta.x >= 0 else -1, 0)
	return Vector2i(0, 1 if delta.y >= 0 else -1)

func _cardinal_direction(direction: Variant) -> Vector2i:
	var raw: Vector2i = Vector2i.ZERO
	match typeof(direction):
		TYPE_VECTOR2I:
			raw = direction
		TYPE_VECTOR2:
			var vector_direction: Vector2 = direction
			raw = Vector2i(int(roundf(vector_direction.x)), int(roundf(vector_direction.y)))
		TYPE_ARRAY:
			var pair: Array = direction
			if pair.size() >= 2:
				raw = Vector2i(int(pair[0]), int(pair[1]))
		TYPE_DICTIONARY:
			var direction_dict: Dictionary = direction
			raw = Vector2i(int(direction_dict.get("x", 0)), int(direction_dict.get("y", 0)))
	if raw == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(raw.x) >= absi(raw.y):
		return Vector2i(1 if raw.x >= 0 else -1, 0)
	return Vector2i(0, 1 if raw.y >= 0 else -1)

func _force_direction_for_action(action: Dictionary, target_tile: Vector2i, hover_tile: Vector2i) -> Vector2i:
	var allowed: Array[Vector2i] = _combat_engine.force_directions_for_player_action(_preview_combat_state, action, target_tile)
	if allowed.is_empty():
		return Vector2i.ZERO
	var candidate: Vector2i = Vector2i.ZERO
	if hover_tile.x >= 0 and hover_tile != target_tile:
		candidate = _direction_from_tiles(target_tile, hover_tile)
	var player_tile: Vector2i = (_preview_combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	if candidate == Vector2i.ZERO and player_tile != target_tile:
		var fallback_delta: Vector2i = target_tile - player_tile
		var action_type: String = str(action.get("type", ""))
		if action_type == "pull" or (int(action.get("pull", 0)) > 0 and int(action.get("push", 0)) <= 0):
			fallback_delta = player_tile - target_tile
		candidate = _cardinal_direction(fallback_delta)
	if allowed.has(candidate):
		return candidate
	return allowed[0]

func _force_direction_for_confirmation(action: Dictionary, target_tile: Vector2i, click_tile: Vector2i) -> Vector2i:
	var allowed: Array[Vector2i] = _combat_engine.force_directions_for_player_action(_preview_combat_state, action, target_tile)
	if allowed.is_empty():
		return Vector2i.ZERO
	if click_tile == target_tile:
		return _force_direction_for_action(action, target_tile, _hovered_board_tile)
	var candidate: Vector2i = _direction_from_tiles(target_tile, click_tile)
	return candidate if allowed.has(candidate) else Vector2i.ZERO

func _action_with_pending_orientation(action: Dictionary, direction: Vector2i) -> Dictionary:
	var oriented: Dictionary = action.duplicate(true)
	var action_type: String = str(oriented.get("type", ""))
	if _combat_engine.player_action_needs_orientation(action) and (
		action_type in ["push", "pull"]
		or int(oriented.get("push", 0)) > 0
		or int(oriented.get("pull", 0)) > 0
	):
		oriented["force_direction"] = direction
	return oriented

func _target_needs_force_orientation(action: Dictionary, target_tile: Vector2i) -> bool:
	return _target_needs_force_orientation_in_state(_preview_combat_state, action, target_tile)

func _target_needs_force_orientation_in_state(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> bool:
	if str(action.get("type", "")) == "aoe":
		return false
	if not _combat_engine.player_action_needs_orientation(action):
		return false
	return not _combat_engine.force_directions_for_player_action(state, action, target_tile).is_empty()

func _pending_oriented_action() -> Dictionary:
	if not _orientation_pending():
		return {}
	var action: Dictionary = _pending_actions[_pending_action_index]
	return _action_with_pending_orientation(action, _force_direction_for_action(action, _pending_orientation_target_tile, _hovered_board_tile))

func _direction_choice_tiles(target_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid: Array = _preview_combat_state.get("grid", [])
	var action: Dictionary = _pending_actions[_pending_action_index] if _pending_action_index >= 0 and _pending_action_index < _pending_actions.size() else {}
	for direction: Vector2i in _combat_engine.force_directions_for_player_action(_preview_combat_state, action, target_tile):
		var tile: Vector2i = target_tile + direction
		if grid.is_empty() or PathUtils.is_in_bounds(grid, tile):
			result.append(tile)
	return result

func _confirm_pending_orientation(click_tile: Vector2i) -> void:
	var action: Dictionary = _pending_actions[_pending_action_index]
	var direction: Vector2i = _force_direction_for_confirmation(action, _pending_orientation_target_tile, click_tile)
	if direction == Vector2i.ZERO:
		_refresh_stage_view()
		return
	var oriented_action: Dictionary = _action_with_pending_orientation(action, direction)
	if not _combat_engine.valid_targets_for_player_action(_preview_combat_state, oriented_action).has(_pending_orientation_target_tile):
		_refresh_stage_view()
		return
	var previous_action_index: int = _pending_action_index
	_pending_actions[_pending_action_index] = oriented_action
	_pending_selected_targets.append(_pending_orientation_target_tile)
	_preview_combat_state = _combat_engine.apply_player_action(_preview_combat_state, oriented_action, _pending_orientation_target_tile)
	_pending_orientation_target_tile = INVALID_TARGET_TILE
	_mark_preview_selection_changed()
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(previous_action_index + 1, int(next_preview.get("action_index", 0)))
	await _apply_pending_preview_result(next_preview)

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _on_card_pressed(index: int) -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "combat":
		return
	if _combat_skill_card_selection_zone == "hand":
		_on_combat_skill_hand_card_selected(index)
		return
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return
	if _drag_card_index >= 0:
		return
	if _pending_umbra_commit_locked and _selected_card_index >= 0:
		return
	if _selected_card_index == index:
		_cancel_card_selection()
		return
	if _card_action_choice_index == index:
		_cancel_card_action_choice()
		return
	if _selected_card_index >= 0 or _card_action_choice_index >= 0:
		_reset_card_resolution()
	var options: Dictionary = _card_play_options_for_index(index)
	_show_card_action_choices(index, options)
	if bool(options.get("printed_playable", false)):
		await _on_card_action_choice_pressed("play")
	else:
		_refresh_ui()

func _on_card_drag_started(index: int) -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "combat":
		return
	if not _combat_skill_card_selection_zone.is_empty():
		return
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return
	if _pending_umbra_commit_locked:
		return
	if _card_action_choice_index >= 0:
		_clear_card_action_choice_state()
	if _selected_card_index >= 0:
		_cancel_card_selection()
	var options: Dictionary = _card_play_options_for_index(index)
	if not bool(options.get("any_playable", false)):
		return
	_complete_active_contextual_combat_prompt(ContextualCombatTutorial.FULL_CARD_FALLBACK)
	var source_rect: Rect2 = _hand_card_global_rect(index)
	_drag_card_index = index
	_drag_card_options = options.duplicate(true)
	_drag_hover_zone = ""
	_drag_card_source_rect = source_rect
	_drag_card_grab_offset = _current_mouse_position() - source_rect.position
	if _drag_card_proxy != null:
		_release_card_proxy(_drag_card_proxy)
	_drag_card_proxy = _spawn_card_proxy(_card_id_for_hand_index(index), source_rect)
	_mount_card_proxy(_drag_card_proxy, _drag_overlay, source_rect)
	_drag_card_base_scale = _drag_card_proxy.scale
	_update_drag_proxy_position(_current_mouse_position())
	_show_drag_overlay()
	_update_drag_overlay_hover(_drag_zone_at(_current_mouse_position()))
	var source_widget: Control = hand_box.get_child(index) as Control
	if source_widget != null:
		source_widget.visible = false

func _begin_card_preview(index: int, preview: Dictionary, label_override: String = "", complete_play_confirmed: bool = false) -> void:
	if not bool(preview.get("playable", false)):
		return
	_complete_active_contextual_combat_prompt(ContextualCombatTutorial.FULL_CARD_FALLBACK)
	_complete_active_contextual_combat_prompt(ContextualCombatTutorial.TIMELINE_READING)
	_hovered_card_index = -1
	_selected_card_label_override = label_override
	if bool(preview.get("complete", false)):
		_selected_card_index = index
		_preview_combat_state = (preview.get("state", {}) as Dictionary).duplicate(true)
		_pending_actions = (preview.get("actions", []) as Array).duplicate(true)
		_pending_action_index = int(preview.get("action_index", 0))
		_pending_action_can_skip = false
		_pending_target_tiles.clear()
		_pending_selected_targets.clear()
		_pending_umbra_commit_locked = false
		_pending_orientation_target_tile = INVALID_TARGET_TILE
		_aoe_aim_orientation = Vector2i(1, 0)
		_append_skipped_target_placeholders(0, _pending_action_index)
		_mark_preview_selection_changed()
		_refresh_ui()
		if complete_play_confirmed:
			await _on_confirm_card_play_pressed()
		return
	_selected_card_index = index
	_preview_combat_state = (preview.get("state", {}) as Dictionary).duplicate(true)
	_pending_actions = (preview.get("actions", []) as Array).duplicate(true)
	_pending_action_index = int(preview.get("action_index", 0))
	_pending_action_can_skip = bool(preview.get("skip_allowed", false))
	_pending_target_tiles = _vector2i_array(preview.get("target_tiles", []))
	_pending_selected_targets.clear()
	_pending_umbra_commit_locked = false
	_pending_orientation_target_tile = INVALID_TARGET_TILE
	if _pending_action_index < _pending_actions.size():
		_reset_aoe_aim_orientation_for_action(_pending_actions[_pending_action_index])
		_refresh_pending_aoe_target_tiles()
	_append_skipped_target_placeholders(0, _pending_action_index)
	_mark_preview_selection_changed()
	_refresh_ui()

func _pending_card_requires_confirmation() -> bool:
	return (
		_selected_card_index >= 0
		and not _pending_actions.is_empty()
		and _pending_action_index >= _pending_actions.size()
		and not _preview_combat_state.is_empty()
	)

func _on_confirm_card_play_pressed() -> void:
	if _animation_lock or not _pending_card_requires_confirmation():
		return
	await _play_player_card(
		_selected_card_index,
		_preview_combat_state.duplicate(true),
		_pending_actions.duplicate(true),
		_vector2i_array(_pending_selected_targets)
	)

func _on_card_hover_started(index: int) -> void:
	if _animation_lock or _selected_card_index >= 0 or _card_action_choice_index >= 0 or _drag_card_index >= 0 or str(_run_state.get("mode", "room")) != "combat":
		return
	_hovered_card_index = index
	_refresh_stage_view()
	_refresh_turn_order_bar()
	_refresh_contextual_combat_tutorial()

func _on_card_hover_ended(index: int) -> void:
	if _selected_card_index >= 0 or _card_action_choice_index >= 0 or _drag_card_index >= 0:
		return
	if _hovered_card_index == index:
		_hovered_card_index = -1
		if _animation_lock:
			return
		_refresh_stage_view()
		_refresh_turn_order_bar()
		_refresh_contextual_combat_tutorial()

func _on_board_tile_hovered(tile: Vector2i) -> void:
	if _dialogue_active or _drag_card_index >= 0:
		return
	_hovered_board_tile = tile
	if _animation_lock:
		return
	if str(_run_state.get("mode", "room")) in ["combat", "room"]:
		_refresh_stage_view()
		if _pass_preview_hover_can_change():
			_update_action_context_copy()
			_layout_action_step_tracker()

func _pass_preview_hover_can_change() -> bool:
	if str(_run_state.get("mode", "room")) != "combat":
		return false
	if _selected_card_index < 0 or _pending_action_index < 0 or _pending_action_index >= _pending_actions.size():
		return false
	if _orientation_pending():
		return _pending_orientation_target_tile.x >= 0
	var preview: Dictionary = _active_card_preview()
	if preview.is_empty():
		return false
	var action: Dictionary = preview.get("action", {})
	if not _combat_engine.player_action_needs_target(action):
		return false
	return not _vector2i_array(preview.get("target_tiles", [])).is_empty()

func _on_board_tile_dragged(start_tile: Vector2i, current_tile: Vector2i) -> void:
	if _dialogue_active or _animation_lock or _drag_card_index >= 0:
		return
	if str(_run_state.get("mode", "room")) != "combat" or not _current_action_is_aimed_aoe():
		return
	var direction: Vector2i = _direction_from_tiles(start_tile, current_tile)
	if direction != Vector2i.ZERO:
		_set_aoe_aim_orientation(direction)
	_hovered_board_tile = current_tile
	_refresh_stage_view()

func _on_board_tile_drag_released(start_tile: Vector2i, current_tile: Vector2i) -> void:
	if _dialogue_active or _animation_lock or _drag_card_index >= 0:
		return
	if str(_run_state.get("mode", "room")) != "combat" or not _current_action_is_aimed_aoe():
		return
	var direction: Vector2i = _direction_from_tiles(start_tile, current_tile)
	if direction != Vector2i.ZERO:
		_set_aoe_aim_orientation(direction)
	_hovered_board_tile = current_tile
	await _on_board_tile_clicked(current_tile)

func _on_board_tile_clicked(tile: Vector2i) -> void:
	if _dialogue_active or _animation_lock or _drag_card_index >= 0:
		return
	var mode: String = str(_run_state.get("mode", "room"))
	if mode == "room" and _exit_destinations_by_tile.has(tile):
		await _on_map_view_room_selected(_exit_destinations_by_tile[tile], tile)
		return
	if mode != "combat" or _selected_card_index < 0:
		return
	if _orientation_pending():
		await _confirm_pending_orientation(tile)
		return
	var preview: Dictionary = _active_card_preview()
	var shortcut_plan: Dictionary = {}
	if not preview.is_empty():
		shortcut_plan = (_preview_shortcuts_for_current_action(preview).get("plans", {}) as Dictionary).get(tile, {}) as Dictionary
	if not _pending_target_tiles.has(tile) and shortcut_plan.is_empty():
		return
	_complete_active_contextual_combat_prompt(ContextualCombatTutorial.SELECT_TARGET)
	if not shortcut_plan.is_empty():
		await _on_pending_shortcut_clicked(tile, shortcut_plan)
		return
	var action: Dictionary = _pending_actions[_pending_action_index]
	var previous_action_index: int = _pending_action_index
	if str(action.get("type", "")) == "aoe":
		action = _action_with_aoe_aim_orientation(action)
		if not _combat_engine.valid_targets_for_player_action(_preview_combat_state, action).has(tile):
			return
		_pending_actions[_pending_action_index] = action
	elif _target_needs_force_orientation(action, tile):
		_pending_orientation_target_tile = tile
		_hovered_board_tile = tile
		_mark_preview_selection_changed()
		_refresh_stage_view()
		return
	_pending_selected_targets.append(tile)
	if _umbra_defers_movement_followup_preview(_preview_combat_state, action, _pending_actions, _pending_action_index):
		_pending_umbra_commit_locked = true
	_preview_combat_state = _combat_engine.apply_player_action(_preview_combat_state, action, tile)
	_mark_preview_selection_changed()
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(previous_action_index + 1, int(next_preview.get("action_index", 0)))
	await _apply_pending_preview_result(next_preview)

func _on_cancel_requested() -> void:
	if _dialogue_active:
		_advance_dialogue()
		return
	if _animation_lock:
		return
	if _drag_card_index >= 0:
		await _animate_drag_cancel_to_source()
		return
	if _upgrade_scrim != null and _upgrade_scrim.visible:
		_close_skill_reset_confirmation() if _skill_reset_confirmation_scrim != null else _close_card_upgrade_overlay()
		return
	if _pre_battle_scrim != null and _pre_battle_scrim.visible:
		return
	if _large_map_scrim != null and _large_map_scrim.visible:
		_close_large_map()
		return
	if _pile_scrim != null and _pile_scrim.visible:
		_close_pile_view()
		return
	if _grimoire_scrim != null and _grimoire_scrim.visible:
		_close_grimoire_overlay()
		return
	if _menu_scrim != null and _menu_scrim.visible:
		if _settings_panel != null and _settings_panel.visible:
			_close_settings_overlay()
		else:
			_close_menu_overlay()
		return
	if _card_action_choice_index >= 0:
		_cancel_card_action_choice()
		return
	if _selected_card_index >= 0:
		_cancel_card_selection()
		return
	if _merchant_shop_open and not _current_room_merchant_kind().is_empty():
		_on_merchant_hide_pressed()
		return
	_open_menu_overlay()

func _on_mini_map_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _dialogue_active or _animation_lock:
			return
		_open_large_map()
		get_viewport().set_input_as_handled()

func _mini_map_cursor_feedback_context(_local_position: Vector2) -> String:
	return "action" if not _dialogue_active and not _animation_lock and _large_map_scrim != null else "inert"

func _open_large_map() -> void:
	if _large_map_scrim == null:
		return
	_close_menu_overlay()
	_close_pile_view()
	_close_card_upgrade_overlay()
	if _large_map_view != null:
		_large_map_view.call("set_run_state", _run_state)
	_close_grimoire_overlay()
	_large_map_scrim.visible = true
	_large_map_scrim.move_to_front()

func _close_large_map() -> void:
	if _large_map_scrim == null:
		return
	_large_map_scrim.visible = false

func _on_large_map_room_selected(coord: Vector2i) -> void:
	_close_large_map()
	await _on_map_view_room_selected(coord)

func _cancel_card_selection() -> void:
	if _selected_card_index < 0:
		return
	if _pending_umbra_commit_locked:
		return
	_complete_active_contextual_combat_prompt(ContextualCombatTutorial.CANCEL_OPTIONAL)
	_reset_card_resolution()
	_refresh_ui()

func _current_action_can_skip() -> bool:
	return _selected_card_index >= 0 and _pending_action_index < _pending_actions.size() and _pending_action_can_skip

func _on_skip_action_pressed() -> void:
	if _animation_lock or not _current_action_can_skip():
		return
	_complete_active_contextual_combat_prompt(ContextualCombatTutorial.CANCEL_OPTIONAL)
	var previous_action_index: int = _pending_action_index
	_pending_selected_targets.append(INVALID_TARGET_TILE)
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(previous_action_index + 1, int(next_preview.get("action_index", 0)))
	await _apply_pending_preview_result(next_preview)

func _on_pending_shortcut_clicked(target_tile: Vector2i, shortcut_plan: Dictionary) -> void:
	var move_target: Vector2i = shortcut_plan.get("move_target", INVALID_TARGET_TILE)
	var previous_action_index: int = _pending_action_index
	_pending_selected_targets.append(move_target)
	if move_target.x >= 0:
		var move_action: Dictionary = _pending_actions[_pending_action_index]
		var planned_path: Array[Vector2i] = _vector2i_array(shortcut_plan.get("path_tiles", []))
		_preview_combat_state = _combat_engine.apply_prevalidated_player_move(_preview_combat_state, move_action, move_target, planned_path)
		_mark_preview_selection_changed()
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var attack_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(previous_action_index + 1, int(attack_preview.get("action_index", 0)))
	if bool(attack_preview.get("complete", false)):
		await _apply_pending_preview_result(attack_preview)
		return
	_load_pending_preview_state(attack_preview)
	if not _pending_target_tiles.has(target_tile):
		_refresh_ui()
		return
	var attack_action_index: int = _pending_action_index
	if _target_needs_force_orientation(_pending_actions[_pending_action_index], target_tile):
		_pending_orientation_target_tile = target_tile
		_hovered_board_tile = target_tile
		_mark_preview_selection_changed()
		_refresh_stage_view()
		return
	_pending_selected_targets.append(target_tile)
	_preview_combat_state = _combat_engine.apply_player_action(_preview_combat_state, _pending_actions[_pending_action_index], target_tile)
	_mark_preview_selection_changed()
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(attack_action_index + 1, int(next_preview.get("action_index", 0)))
	await _apply_pending_preview_result(next_preview)

func _load_pending_preview_state(preview: Dictionary) -> void:
	_preview_combat_state = (preview.get("state", {}) as Dictionary).duplicate(true)
	_pending_action_index = int(preview.get("action_index", 0))
	_pending_action_can_skip = bool(preview.get("skip_allowed", false))
	_pending_target_tiles = _vector2i_array(preview.get("target_tiles", []))
	_pending_orientation_target_tile = INVALID_TARGET_TILE
	if _pending_action_index < _pending_actions.size():
		_reset_aoe_aim_orientation_for_action(_pending_actions[_pending_action_index])
		_refresh_pending_aoe_target_tiles()
	_mark_preview_selection_changed()

func _apply_pending_preview_result(next_preview: Dictionary) -> void:
	var resolved_preview: Dictionary = _resolve_reused_target_preview_actions(next_preview)
	if bool(resolved_preview.get("complete", false)):
		await _play_player_card(
			_selected_card_index,
			(resolved_preview.get("state", {}) as Dictionary).duplicate(true),
			_pending_actions.duplicate(true),
			_vector2i_array(_pending_selected_targets)
		)
		return
	_load_pending_preview_state(resolved_preview)
	_refresh_ui()

func _resolve_reused_target_preview_actions(source_preview: Dictionary) -> Dictionary:
	var preview: Dictionary = source_preview
	while not bool(preview.get("complete", false)):
		var action_index: int = int(preview.get("action_index", -1))
		if action_index < 0 or action_index >= _pending_actions.size():
			break
		var action: Dictionary = _pending_actions[action_index]
		if not bool(action.get("reuse_previous_target", false)):
			break
		var target_tile: Vector2i = _last_resolved_pending_target()
		var state: Dictionary = (preview.get("state", {}) as Dictionary).duplicate(true)
		if target_tile.x >= 0 and _combat_engine.valid_targets_for_player_action(state, action).has(target_tile):
			_pending_selected_targets.append(target_tile)
			state = _combat_engine.apply_player_action(state, action, target_tile)
		else:
			_pending_selected_targets.append(INVALID_TARGET_TILE)
		var card_id: String = _card_id_for_hand_index(_selected_card_index)
		var next_preview: Dictionary = _card_preview_from_state(card_id, state, _pending_actions, action_index + 1)
		_append_skipped_target_placeholders(action_index + 1, int(next_preview.get("action_index", 0)))
		preview = next_preview
	return preview

func _last_resolved_pending_target() -> Vector2i:
	for index: int in range(_pending_selected_targets.size() - 1, -1, -1):
		var tile: Vector2i = _pending_selected_targets[index]
		if tile.x >= 0:
			return tile
	return INVALID_TARGET_TILE

func _append_skipped_target_placeholders(start_action_index: int, end_action_index: int) -> void:
	var safe_start: int = maxi(0, start_action_index)
	var safe_end: int = mini(end_action_index, _pending_actions.size())
	for index: int in range(safe_start, safe_end):
		if _combat_engine.player_action_needs_target(_pending_actions[index]):
			_pending_selected_targets.append(INVALID_TARGET_TILE)

func _play_player_card(hand_index: int, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> void:
	var card_id: String = _card_id_for_hand_index(hand_index)
	var source_rect: Rect2 = _hand_card_global_rect(hand_index)
	var card_size: Vector2 = source_rect.size if source_rect.size.length() > 0.0 else _hand_card_size(5, false)
	var previous_run_state: Dictionary = _run_state.duplicate(true)
	var previous_combat_state: Dictionary = _combat_state.duplicate(true)
	var pre_commit_combat_state: Dictionary = resolved_state.duplicate(true)
	var previous_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var played_instance_id: String = _analytics_hand_instance_id(hand_index)
	var plays_spent: int = _combat_engine.card_plays_spent_for_actions(actions)
	_lock_action_step_tracker_position_for_resolution()
	_animating_hand_card_index = hand_index
	_begin_action_step_resolution_tracker(card_id, actions, selected_targets)
	_animation_lock = true
	_begin_card_play_meter_spend_preview(plays_spent)
	_refresh_animation_lock_ui()
	var committed_combat_state: Dictionary = _combat_engine.finish_player_card(
		resolved_state,
		hand_index,
		plays_spent,
		{"play_mode": _card_action_choice_mode}
	)
	var pile_kind: String = str(committed_combat_state.get("last_card_destination", _card_destination_pile(card_id)))
	var committed_run_state: Dictionary = _run_state.duplicate(true)
	if GameData.card_consumes_on_play(card_id) and pile_kind == "consume":
		committed_run_state = _run_engine.consume_equipped_item_card(committed_run_state, card_id)
	committed_run_state = _run_state_for_combat_checkpoint(committed_run_state, committed_combat_state)
	committed_run_state = _hold_committed_run_state(committed_run_state, "player_card")
	var staged_card_proxy: Control = await _animate_card_play_fx(card_id, source_rect, card_size)
	await _animate_card_to_pile_fx(card_id, pile_kind, card_size, staged_card_proxy)
	await _animate_player_card_resolution(previous_combat_state, card_id, actions, selected_targets)
	await _animate_enemy_loss_feedback_between_states(
		pre_commit_combat_state,
		committed_combat_state,
		GameData.card_element(card_id)
	)
	await _animate_defeats_and_terrain_destruction(pre_commit_combat_state, committed_combat_state)
	var outcome: String = _combat_engine.combat_outcome(committed_combat_state)
	var transition_combat_state: Dictionary = committed_combat_state.duplicate(true)
	if outcome == "victory":
		transition_combat_state = await _animate_missed_equipment_resolution(committed_combat_state, _salvaged_equipment_ids(committed_run_state))
	_board_presentation.clear()
	_set_action_banner("")
	_run_state = committed_run_state
	_sync_combat_state_from_run()
	_release_committed_run_state()
	_analytics_reconcile_combat_tracker(previous_combat_state, _combat_state)
	_analytics_log_card_draws(previous_combat_state, _combat_state, previous_tracker, _analytics_snapshot_combat_tracker(), "card_effect")
	_analytics_log_card_played(card_id, played_instance_id, previous_combat_state, committed_combat_state, actions, selected_targets)
	_analytics_log_playable_cards()
	_analytics_log_combat_transition(previous_run_state, "card_play", transition_combat_state)
	_animation_lock = false
	_animating_hand_card_index = -1
	_card_play_count_override = -1
	_card_play_resolution_spend = 0
	_card_play_budget_override = {}
	_reset_card_resolution()
	_hovered_card_index = -1
	_refresh_ui()
	if str(_run_state.get("mode", "room")) == "combat" and _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		await _resolve_enemy_round()

func _card_destination_pile(card_id: String) -> String:
	if GameData.card_consumes_on_play(card_id):
		return "consume"
	return "burn" if bool(_card_def(card_id, _combat_state).get("burn", false)) else "discard"

func _animate_card_play_fx(card_id: String, source_rect: Rect2, size_hint: Vector2) -> Control:
	if _card_fx_layer == null or card_id.is_empty() or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return null
	var proxy: Control = _spawn_card_proxy(card_id, source_rect)
	proxy.z_index = 1500
	_mount_card_proxy(proxy, _card_fx_layer, source_rect)
	proxy.modulate = Color.WHITE
	var reduced_motion: bool = _reduced_motion_enabled()
	var target_multiplier: float = 1.02 if reduced_motion else 1.08
	var target_rect: Rect2 = _stage_card_rect(size_hint * target_multiplier)
	var duration: float = CARD_PLAY_SECONDS * (0.62 if reduced_motion else 1.0)
	await _animate_card_proxy_arc(
		proxy,
		target_rect,
		0.0 if reduced_motion else CARD_PLAY_ARC_HEIGHT,
		duration,
		0.0,
		Color.WHITE
	)
	if not _node_is_alive(proxy):
		return null
	await get_tree().create_timer(CARD_PLAY_HOLD_SECONDS * (0.55 if reduced_motion else 1.0)).timeout
	return proxy if _node_is_alive(proxy) else null

func _animate_card_to_pile_fx(card_id: String, pile_kind: String, size_hint: Vector2, staged_proxy = null) -> void:
	if _card_fx_layer == null or card_id.is_empty():
		_release_card_proxy(staged_proxy)
		return
	if pile_kind == "consume":
		await _animate_card_consumed_fx(card_id, size_hint, staged_proxy)
		return
	var pile_rect: Rect2 = _pile_global_rect(pile_kind)
	if pile_rect.size.x <= 0.0 or pile_rect.size.y <= 0.0:
		_release_card_proxy(staged_proxy)
		return
	var target_size: Vector2 = Vector2(
		minf(92.0, size_hint.x * 0.38),
		minf(130.0, size_hint.y * 0.38)
	)
	target_size = _normalized_card_size(target_size)
	var target_rect: Rect2 = _rect_from_center(pile_rect.get_center(), target_size)
	var proxy: Control = staged_proxy as Control if _node_is_alive(staged_proxy) else null
	if proxy == null:
		var fallback_rect: Rect2 = _stage_card_rect(size_hint * (1.02 if _reduced_motion_enabled() else 1.08))
		proxy = _spawn_card_proxy(card_id, fallback_rect)
		_mount_card_proxy(proxy, _card_fx_layer, fallback_rect)
	proxy.z_index = 1490
	var duration: float = CARD_PILE_SECONDS * (0.62 if _reduced_motion_enabled() else 1.0)
	var start_center: Vector2 = _card_proxy_visual_rect(proxy).get_center()
	var direction: float = -1.0 if target_rect.get_center().x < start_center.x else 1.0
	await _animate_card_proxy_arc(
		proxy,
		target_rect,
		0.0 if _reduced_motion_enabled() else CARD_PILE_ARC_HEIGHT,
		duration,
		0.0 if _reduced_motion_enabled() else deg_to_rad(11.0 * direction),
		Color(1.0, 0.94, 0.84, 0.08)
	)
	_release_card_proxy(proxy)

func _animate_card_consumed_fx(card_id: String, size_hint: Vector2, staged_proxy = null) -> void:
	if _card_fx_layer == null or card_id.is_empty():
		_release_card_proxy(staged_proxy)
		return
	var proxy: Control = staged_proxy as Control if _node_is_alive(staged_proxy) else null
	if proxy == null:
		var start_rect: Rect2 = _stage_card_rect(size_hint * (1.02 if _reduced_motion_enabled() else 1.08))
		if start_rect.size.x <= 0.0 or start_rect.size.y <= 0.0:
			return
		proxy = _spawn_card_proxy(card_id, start_rect)
		_mount_card_proxy(proxy, _card_fx_layer, start_rect)
	proxy.z_index = 1490
	var start_scale: Vector2 = proxy.scale
	var reduced_motion: bool = _reduced_motion_enabled()
	var duration: float = CARD_PILE_SECONDS * (0.55 if reduced_motion else 1.0)
	var tween: Tween = create_tween().set_parallel(true)
	if reduced_motion:
		tween.tween_property(proxy, "scale", start_scale * 0.54, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(proxy, "position:y", proxy.position.y - 6.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(proxy, "modulate", Color(1.0, 0.90, 0.70, 0.0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_property(proxy, "scale", start_scale * 0.42, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(proxy, "rotation", deg_to_rad(-9.0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(proxy, "position:y", proxy.position.y - 24.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(proxy, "modulate", Color(1.0, 0.84, 0.46, 0.0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	_release_card_proxy(proxy)

func _animate_draw_cards_fx(draw_entries: Array, source_rect_override: Rect2 = Rect2()) -> void:
	if _card_fx_layer == null or draw_entries.is_empty():
		return
	var final_total: int = draw_entries.size()
	for entry_var: Variant in draw_entries:
		if entry_var is Dictionary:
			final_total = maxi(final_total, int((entry_var as Dictionary).get("total", final_total)))
	var size_hint: Vector2 = _hand_card_size(maxi(5, final_total), false)
	var source_rect: Rect2 = source_rect_override
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		source_rect = _rect_from_center(_pile_global_rect("draw").get_center(), size_hint * 0.54)
	var draw_proxies: Array[Control] = []
	var draw_tweens: Array[Tween] = []
	for draw_index: int in range(draw_entries.size()):
		if not _card_fx_can_continue_combat():
			for active_proxy: Control in draw_proxies:
				_release_card_proxy(active_proxy)
			return
		var entry: Variant = draw_entries[draw_index]
		var card_id: String = ""
		var target_index: int = draw_index
		var target_total: int = final_total
		if entry is Dictionary:
			var draw_entry: Dictionary = entry
			card_id = str(draw_entry.get("card_id", ""))
			target_index = int(draw_entry.get("index", draw_index))
			target_total = int(draw_entry.get("total", final_total))
		else:
			card_id = str(entry)
		if card_id.is_empty() or not _card_fx_can_continue_combat():
			return
		var proxy: Control = _spawn_card_proxy(card_id, source_rect)
		_mount_card_proxy(proxy, _card_fx_layer, source_rect)
		var target_rect: Rect2 = _hand_receive_rect(target_index, target_total, size_hint * 0.96)
		var target_rotation: float = HandFanContainer.card_rotation_for_layout(target_index, target_total, true)
		var duration: float = DRAW_FRAME_SECONDS * (0.62 if _reduced_motion_enabled() else 1.0)
		var reduced_motion: bool = _reduced_motion_enabled()
		if not reduced_motion:
			proxy.rotation = deg_to_rad(-9.0 + float(draw_index) * 2.0)
			proxy.modulate = Color(1.0, 1.0, 1.0, 0.82)
		var tween: Tween = _start_card_proxy_arc(
			proxy,
			target_rect,
			0.0 if reduced_motion else CARD_DRAW_ARC_HEIGHT + float(draw_index) * 5.0,
			duration,
			0.0 if reduced_motion else target_rotation,
			Color.WHITE,
			0.0 if reduced_motion else 0.018,
			float(draw_index) * DRAW_STAGGER_SECONDS
		)
		draw_proxies.append(proxy)
		draw_tweens.append(tween)
	if not draw_tweens.is_empty():
		await draw_tweens.back().finished
	for draw_index: int in range(draw_proxies.size()):
		var proxy: Control = draw_proxies[draw_index]
		var tween: Tween = draw_tweens[draw_index]
		if _node_is_alive(proxy) and proxy.has_meta("active_card_proxy_tween") and proxy.get_meta("active_card_proxy_tween") == tween:
			proxy.remove_meta("active_card_proxy_tween")
		if not _card_fx_can_continue_combat():
			_release_card_proxy(proxy)
	# Keep the arrived proxies in their exact fan slots until the authoritative hand
	# refresh replaces them. Releasing each one at arrival caused a blank-frame pop
	# between the flight and the real hand card appearing.

func _card_fx_can_continue_combat() -> bool:
	return _node_is_alive(_card_fx_layer) and str(_run_state.get("mode", "room")) == "combat"

func _draw_entries_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_counts: Dictionary = {}
	for card_id_var: Variant in (before_state.get("deck", {}) as Dictionary).get("hand", []):
		var card_id: String = str(card_id_var)
		before_counts[card_id] = int(before_counts.get(card_id, 0)) + 1
	var after_hand: Array = (after_state.get("deck", {}) as Dictionary).get("hand", [])
	var drawn: Array[Dictionary] = []
	for index: int in range(after_hand.size()):
		var card_id: String = str(after_hand[index])
		var remaining: int = int(before_counts.get(card_id, 0))
		if remaining > 0:
			before_counts[card_id] = remaining - 1
			continue
		drawn.append({
			"card_id": card_id,
			"index": index,
			"total": after_hand.size()
		})
	return drawn

func _death_rewards_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_count: int = (before_state.get("death_rewards", []) as Array).size()
	var after_rewards: Array = after_state.get("death_rewards", [])
	var result: Array[Dictionary] = []
	for index: int in range(before_count, after_rewards.size()):
		if after_rewards[index] is Dictionary:
			result.append((after_rewards[index] as Dictionary).duplicate(true))
	return result

func _animate_death_rewards(before_state: Dictionary, after_state: Dictionary) -> void:
	var rewards: Array[Dictionary] = _death_rewards_between_states(before_state, after_state)
	if rewards.is_empty():
		return
	var displayed_embers: int = _run_engine.held_embers(_run_state) + int(before_state.get("room_embers", 0))
	var displayed_card_plays: int = _card_play_count_for_resolution_state(before_state)
	var gained_embers: int = EmberRewardFeedback.total_amount(rewards)
	_ember_count_override = displayed_embers
	_set_stats_label_text(displayed_embers)
	for reward: Dictionary in rewards:
		if int(reward.get("card_plays", 0)) > 0:
			displayed_card_plays += int(reward.get("card_plays", 0))
			await _animate_card_play_reward(displayed_card_plays)
	if gained_embers > 0:
		await _animate_ember_reward(Vector2i.ZERO, gained_embers, displayed_embers, displayed_embers + gained_embers)
	_ember_count_override = -1

func _animate_card_play_reward(displayed_card_plays: int) -> void:
	if _play_meter == null or _play_meter_count == null:
		return
	var safe_displayed_card_plays: int = maxi(0, displayed_card_plays)
	var budget: Dictionary = _displayed_card_play_budget()
	var current_total: int = int(budget.get("total_remaining", 0))
	var ordinary_gain: int = maxi(0, safe_displayed_card_plays - current_total)
	budget["ordinary_remaining"] = int(budget.get("ordinary_remaining", 0)) + ordinary_gain
	budget["total_remaining"] = safe_displayed_card_plays
	_card_play_budget_override = budget
	_card_play_count_override = safe_displayed_card_plays
	_refresh_card_play_meter()
	_play_meter.pivot_offset = _play_meter.size * 0.5
	_play_meter_count.add_theme_color_override("font_color", Color("ffe27a"))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_play_meter, "scale", Vector2(1.14, 1.14), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_play_meter, "modulate", Color(1.0, 0.84, 0.46, 1.0), 0.11)
	await tween.finished
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(_play_meter, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	settle.tween_property(_play_meter, "modulate", Color.WHITE, 0.18)
	await settle.finished
	_play_meter_count.add_theme_color_override("font_color", Color("fff4dc"))

func _animate_intensity_gain(element_id: String, displayed_value: int) -> void:
	if not ElementData.is_elemental(element_id):
		return
	var badge: PanelContainer = _intensity_badges.get(element_id, null)
	var label: Label = _intensity_labels.get(element_id, null)
	if badge == null or label == null:
		return
	_refresh_elemental_intensity_bar(_combat_state)
	label.text = str(displayed_value)
	badge.pivot_offset = badge.size * 0.5
	label.add_theme_color_override("font_color", Color("fff4dc"))
	var accent: Color = ElementData.accent(element_id).lightened(0.18)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(badge, "scale", Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "modulate", Color(accent.r, accent.g, accent.b, 1.0), 0.11)
	await tween.finished
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(badge, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	settle.tween_property(badge, "modulate", Color.WHITE, 0.20)
	await settle.finished
	label.add_theme_color_override("font_color", Color("fff7df"))

func _animate_ember_reward(_source_tile: Vector2i, amount: int, from_count: int, to_count: int) -> void:
	await EmberRewardFeedback.play(
		self,
		_card_fx_layer,
		stats_label,
		amount,
		from_count,
		to_count,
		_reduced_motion_enabled(),
		Callable(self, "_set_ember_reward_display_count")
	)

func _set_ember_reward_display_count(value: int) -> void:
	_ember_count_override = value
	_set_stats_label_text(value)

func _board_global_position_for_tile(tile: Vector2i) -> Vector2:
	return board_view.global_position + board_view.world_position_for_tile(tile)

func _animate_floating_text_presentation(display_state: Dictionary, base_presentation: Dictionary, frames: int = FLOAT_TEXT_FRAMES, frame_seconds: float = FLOAT_TEXT_FRAME_SECONDS) -> void:
	var base_texts: Array = (base_presentation.get("floating_texts", []) as Array).duplicate(true)
	var base_decals: Array = (base_presentation.get("impact_decals", []) as Array).duplicate(true)
	var trap_effects: Array = (base_presentation.get("trap_effects", []) as Array).duplicate(true)
	if base_texts.is_empty() and base_decals.is_empty() and trap_effects.is_empty():
		_render_board_state(display_state, base_presentation)
		await get_tree().create_timer(frame_seconds * float(maxi(1, frames))).timeout
		return
	var frame_count: int = maxi(1, frames)
	var reduced_motion: bool = _reduced_motion_enabled()
	for frame: int in range(frame_count):
		var t: float = 1.0 if frame_count == 1 else float(frame) / float(frame_count - 1)
		var presentation: Dictionary = base_presentation.duplicate(true)
		presentation["impact_progress"] = 0.18 if reduced_motion else t
		if (presentation.has("effect") or not (presentation.get("trap_effects", []) as Array).is_empty()) and not presentation.has("effect_progress"):
			presentation["effect_progress"] = 1.0 if reduced_motion else t
		var animated_texts: Array[Dictionary] = []
		for text_var: Variant in base_texts:
			var text_entry: Dictionary = (text_var as Dictionary).duplicate(true)
			text_entry["rise"] = 0.0 if reduced_motion else lerpf(0.0, 14.0, t)
			text_entry["alpha"] = 1.0 if reduced_motion or t < 0.72 else clampf(1.0 - ((t - 0.72) / 0.28), 0.0, 1.0)
			animated_texts.append(text_entry)
		presentation["floating_texts"] = animated_texts
		_render_board_state(display_state, presentation)
		await get_tree().create_timer(frame_seconds).timeout

func _animate_defeats_and_terrain_destruction(before_state: Dictionary, after_state: Dictionary, base_presentation: Dictionary = {}) -> void:
	var death_units: Array[Dictionary] = _defeated_enemy_units_between_states(before_state, after_state)
	var destroyed_terrain: Array[Dictionary] = _destroyed_terrain_units_between_states(before_state, after_state)
	if death_units.is_empty() and destroyed_terrain.is_empty():
		return
	var frame_count: int = ENEMY_DEATH_MIN_FRAMES
	var frame_seconds: float = ENEMY_DEATH_FALLBACK_FRAME_SECONDS
	for unit: Dictionary in death_units:
		var unit_frame_count: int = _enemy_death_frame_count_for_unit(unit)
		frame_count = maxi(frame_count, unit_frame_count)
		frame_seconds = minf(frame_seconds, _enemy_death_frame_seconds_for_unit(unit))
	for terrain: Dictionary in destroyed_terrain:
		var terrain_frame_count: int = _terrain_destruction_frame_count_for_unit(terrain)
		frame_count = maxi(frame_count, terrain_frame_count)
		frame_seconds = minf(frame_seconds, _terrain_destruction_frame_seconds_for_unit(terrain))
	frame_count = maxi(1, frame_count)
	for frame: int in range(frame_count):
		var progress: float = 1.0 if frame_count == 1 else float(frame) / float(frame_count - 1)
		var animated_units: Array[Dictionary] = []
		for unit: Dictionary in death_units:
			var animated_unit: Dictionary = unit.duplicate(true)
			var unit_frame_count: int = _enemy_death_frame_count_for_unit(animated_unit)
			var death_frame: int = int(round(progress * float(maxi(1, unit_frame_count) - 1)))
			animated_unit["death_frame"] = clampi(death_frame, 0, maxi(0, unit_frame_count - 1))
			animated_unit["death_progress"] = progress
			animated_units.append(animated_unit)
		var animated_terrain: Array[Dictionary] = []
		for terrain: Dictionary in destroyed_terrain:
			var animated_prop: Dictionary = terrain.duplicate(true)
			var terrain_frame_count: int = _terrain_destruction_frame_count_for_unit(animated_prop)
			var destruction_frame: int = int(round(progress * float(maxi(1, terrain_frame_count) - 1)))
			animated_prop["destruction_frame"] = clampi(destruction_frame, 0, maxi(0, terrain_frame_count - 1))
			animated_prop["destruction_progress"] = progress
			animated_terrain.append(animated_prop)
		var presentation: Dictionary = base_presentation.duplicate(true)
		if not animated_units.is_empty():
			presentation["death_animation_units"] = animated_units
		if not animated_terrain.is_empty():
			presentation["terrain_destruction_units"] = animated_terrain
		_render_board_state(after_state, presentation)
		await get_tree().create_timer(frame_seconds).timeout
	_render_board_state(after_state, {})
	await get_tree().create_timer(0.04).timeout

func _death_hold_presentation(before_state: Dictionary, after_state: Dictionary, base_presentation: Dictionary = {}) -> Dictionary:
	var death_units: Array[Dictionary] = _defeated_enemy_units_between_states(before_state, after_state)
	var destroyed_terrain: Array[Dictionary] = _destroyed_terrain_units_between_states(before_state, after_state)
	if death_units.is_empty() and destroyed_terrain.is_empty():
		return base_presentation
	var presentation: Dictionary = base_presentation.duplicate(true)
	var hold_units: Array[Dictionary] = []
	for unit: Dictionary in death_units:
		var hold_unit: Dictionary = unit.duplicate(true)
		hold_unit["death_frame"] = 0
		hold_unit["death_progress"] = 0.0
		hold_units.append(hold_unit)
	if not hold_units.is_empty():
		presentation["death_animation_units"] = hold_units
	var held_terrain: Array[Dictionary] = []
	for terrain: Dictionary in destroyed_terrain:
		var held_prop: Dictionary = terrain.duplicate(true)
		held_prop["destruction_frame"] = 0
		held_prop["destruction_progress"] = 0.0
		held_terrain.append(held_prop)
	if not held_terrain.is_empty():
		presentation["terrain_destruction_units"] = held_terrain
	return presentation

func _enemy_death_frame_count_for_unit(unit: Dictionary) -> int:
	if board_view != null and board_view.has_method("_unit_death_frame_count"):
		var board_count: int = int(board_view.call("_unit_death_frame_count", unit))
		if board_count > 0:
			return board_count
	var definition: Dictionary = GameData.enemy_def(str(unit.get("type", "")))
	if definition.is_empty():
		return ENEMY_DEATH_FALLBACK_FRAMES
	var columns: int = maxi(1, int(definition.get("death_sheet_columns", 4)))
	var rows: int = maxi(1, int(definition.get("death_sheet_rows", 4)))
	return maxi(1, columns * rows)

func _enemy_death_frame_seconds_for_unit(unit: Dictionary) -> float:
	if board_view != null and board_view.has_method("_unit_death_frame_seconds"):
		return maxf(0.01, float(board_view.call("_unit_death_frame_seconds", unit)))
	var definition: Dictionary = GameData.enemy_def(str(unit.get("type", "")))
	return maxf(0.01, float(definition.get("death_frame_seconds", ENEMY_DEATH_FALLBACK_FRAME_SECONDS)))

func _terrain_destruction_frame_count_for_unit(terrain: Dictionary) -> int:
	if board_view != null and board_view.has_method("_terrain_destruction_frame_count"):
		var board_count: int = int(board_view.call("_terrain_destruction_frame_count", terrain))
		if board_count > 0:
			return board_count
	return TERRAIN_DESTRUCTION_FALLBACK_FRAMES

func _terrain_destruction_frame_seconds_for_unit(terrain: Dictionary) -> float:
	if board_view != null and board_view.has_method("_terrain_destruction_frame_seconds"):
		return maxf(0.01, float(board_view.call("_terrain_destruction_frame_seconds", terrain)))
	return TERRAIN_DESTRUCTION_FALLBACK_FRAME_SECONDS

func _fatigue_damage_events_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_deck: Dictionary = before_state.get("deck", {})
	var after_deck: Dictionary = after_state.get("deck", {})
	var before_cycles: int = int(before_deck.get("cycles", 0))
	var after_cycles: int = int(after_deck.get("cycles", 0))
	var events: Array[Dictionary] = []
	if after_cycles <= before_cycles:
		return events
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var player_tile: Vector2i = after_player.get("pos", before_player.get("pos", Vector2i.ZERO))
	var fatigue_base: int = int(after_deck.get("fatigue_base", before_deck.get("fatigue_base", CombatEngineScript.FATIGUE_BASE_DAMAGE)))
	for cycle: int in range(before_cycles + 1, after_cycles + 1):
		events.append({
			"cycle": cycle,
			"amount": fatigue_base + cycle - 1,
			"tile": player_tile
		})
	return events

func _fatigue_floating_texts_for_events(display_state: Dictionary, fatigue_events: Array[Dictionary]) -> Array[Dictionary]:
	var floats: Array[Dictionary] = []
	if fatigue_events.is_empty():
		return floats
	var player_tile: Vector2i = (display_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var total_damage: int = 0
	for event_var: Variant in fatigue_events:
		var event: Dictionary = event_var
		total_damage += maxi(0, int(event.get("amount", 0)))
		player_tile = event.get("tile", player_tile)
	if total_damage > 0:
		floats.append({
			"tile": player_tile,
			"text": "-%d" % total_damage,
			"color": Color("f39779"),
			"offset": -36.0,
			"x_offset": -34.0,
			"width": 84.0,
			"font_size": 20,
			"outline_size": 2,
			"outline_color": Color("270806")
		})
	floats.append({
		"tile": player_tile,
		"text": "fatigue sets in",
		"color": Color("ff695f"),
		"offset": -4.0,
		"x_offset": 20.0,
		"width": 152.0,
		"font_size": 16,
		"outline_size": 2,
		"outline_color": Color("270806")
	})
	return floats

func _fatigue_damage_presentation_for_progress(display_state: Dictionary, fatigue_events: Array[Dictionary], progress: float) -> Dictionary:
	var base_texts: Array[Dictionary] = _fatigue_floating_texts_for_events(display_state, fatigue_events)
	var animated_texts: Array[Dictionary] = []
	var t: float = clampf(progress, 0.0, 1.0)
	for text_var: Variant in base_texts:
		var text_entry: Dictionary = (text_var as Dictionary).duplicate(true)
		text_entry["rise"] = lerpf(0.0, 18.0, t)
		text_entry["alpha"] = 1.0 if t < 0.66 else clampf(1.0 - ((t - 0.66) / 0.34), 0.0, 1.0)
		animated_texts.append(text_entry)
	return {
		"impact_actor_keys": ["player"],
		"impact_progress": t,
		"impact_strength": 1.35,
		"floating_texts": animated_texts
	}

func _animate_fatigue_damage(display_state: Dictionary, fatigue_events: Array[Dictionary]) -> void:
	if fatigue_events.is_empty():
		return
	var frame_count: int = maxi(1, FATIGUE_EFFECT_FRAMES)
	for frame: int in range(frame_count):
		var t: float = 1.0 if frame_count == 1 else float(frame) / float(frame_count - 1)
		_set_fatigue_edge_progress(minf(t, FATIGUE_EDGE_HOLD_PROGRESS))
		_render_board_state(display_state, _fatigue_damage_presentation_for_progress(display_state, fatigue_events, t))
		await get_tree().create_timer(FATIGUE_EFFECT_FRAME_SECONDS).timeout
	for linger_frame: int in range(FATIGUE_EDGE_LINGER_FRAMES):
		var linger_t: float = float(linger_frame + 1) / float(FATIGUE_EDGE_LINGER_FRAMES)
		_set_fatigue_edge_progress(lerpf(FATIGUE_EDGE_HOLD_PROGRESS, 1.0, linger_t))
		await get_tree().create_timer(FATIGUE_EFFECT_FRAME_SECONDS).timeout
	_set_fatigue_edge_progress(-1.0)
	_render_board_state(display_state, {})

func _set_fatigue_edge_progress(progress: float) -> void:
	if _fatigue_edge_overlay == null:
		return
	_fatigue_edge_overlay.progress = progress

func _animate_player_card_resolution(animated_state: Dictionary, card_id: String, actions: Array, selected_targets: Array[Vector2i]) -> void:
	var target_index: int = 0
	for action_index: int in range(actions.size()):
		var action_var: Variant = actions[action_index]
		var action: Dictionary = action_var
		if not _combat_engine.player_action_can_resolve(animated_state, action):
			_set_action_step_resolution_index(action_index + 1)
			continue
		_set_action_step_resolution_index(action_index)
		var target_tile: Vector2i = INVALID_TARGET_TILE
		if _combat_engine.player_action_needs_target(action):
			if target_index < selected_targets.size():
				target_tile = selected_targets[target_index]
			target_index += 1
		var before_state: Dictionary = animated_state.duplicate(true)
		var after_state: Dictionary = _combat_engine.apply_player_action(animated_state, action, target_tile)
		await _animate_player_action_step(before_state, after_state, card_id, action, target_tile)
		animated_state = after_state
	_set_action_step_resolution_index(actions.size())
	_render_board_state(animated_state, {})
	await get_tree().create_timer(0.04).timeout

func _animate_missed_equipment_resolution(victory_state: Dictionary, salvaged_equipment_ids: Array = []) -> Dictionary:
	var resolved_state: Dictionary = _combat_engine.resolve_missed_equipment_after_victory(victory_state)
	var missed_equipment: Array = (resolved_state.get("missed_equipment", []) as Array).duplicate()
	var presentation_state: Dictionary = victory_state.duplicate(true)
	if not salvaged_equipment_ids.is_empty():
		var resolved_loot: Array = (resolved_state.get("loot", []) as Array).duplicate(true)
		var presentation_loot: Array = (presentation_state.get("loot", []) as Array).duplicate(true)
		for equipment_id: String in salvaged_equipment_ids:
			missed_equipment.erase(equipment_id)
			for loot_entries: Array in [resolved_loot, presentation_loot]:
				for index: int in range(loot_entries.size()):
					if typeof(loot_entries[index]) != TYPE_DICTIONARY:
						continue
					var loot: Dictionary = (loot_entries[index] as Dictionary).duplicate(true)
					if str(loot.get("equipment_id", "")) != equipment_id:
						continue
					loot["claimed"] = true
					loot["resolution"] = "salvaged"
					loot_entries[index] = loot
		resolved_state["loot"] = resolved_loot
		presentation_state["loot"] = presentation_loot
		resolved_state["missed_equipment"] = missed_equipment
		var salvaged_names: Array[String]
		for equipment_id: String in salvaged_equipment_ids:
			salvaged_names.append(str(GameData.equipment_def(equipment_id).get("name", equipment_id)))
		_show_combat_log_message("Salvager recovers %s." % ", ".join(salvaged_names))
		_render_board_state(presentation_state, {})
		await get_tree().create_timer(0.24).timeout
	if missed_equipment.is_empty():
		_render_board_state(resolved_state, {})
		return resolved_state
	_show_combat_log_message(RunEngineScript.MISSED_EQUIPMENT_NOTICE)
	for frame: int in range(MISSED_EQUIPMENT_FRAMES + 1):
		var progress: float = float(frame) / float(MISSED_EQUIPMENT_FRAMES)
		_render_board_state(presentation_state, {
			"missed_equipment_ids": missed_equipment,
			"missed_equipment_progress": progress
		})
		await get_tree().create_timer(MISSED_EQUIPMENT_FRAME_SECONDS).timeout
	_render_board_state(resolved_state, {})
	await get_tree().create_timer(0.08).timeout
	return resolved_state

func _salvaged_equipment_ids(run_state: Dictionary) -> Array[String]:
	var result: Array[String]
	var layout: Dictionary = run_state.get("current_room_layout", {}) as Dictionary
	for loot_var: Variant in layout.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var as Dictionary
		var equipment_id: String = str(loot.get("equipment_id", ""))
		if str(loot.get("resolution", "")) == "salvaged" and not equipment_id.is_empty() and not result.has(equipment_id):
			result.append(equipment_id)
	return result

func _attack_impact_presentation(base_presentation: Dictionary) -> Dictionary:
	var impact_presentation: Dictionary = base_presentation.duplicate(true)
	var effect: Dictionary = impact_presentation.get("effect", {})
	var floating_texts: Array = impact_presentation.get("floating_texts", [])
	var decals: Array[Dictionary] = _impact_decals_for_effect(effect, floating_texts)
	if decals.is_empty():
		impact_presentation.erase("impact_decals")
	else:
		impact_presentation["impact_decals"] = decals
	impact_presentation.erase("effect")
	impact_presentation.erase("effect_progress")
	return impact_presentation

func _impact_decals_for_effect(effect: Dictionary, floating_texts: Array) -> Array[Dictionary]:
	var decals: Array[Dictionary] = []
	if effect.is_empty():
		return decals
	var kind: String = str(effect.get("kind", ""))
	if kind not in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes"]:
		return decals
	var element_id: String = str(effect.get("element", effect.get("_card_element", ElementData.NONE)))
	var tiles: Array[Vector2i] = _impact_decal_tiles(effect, floating_texts)
	var count: int = mini(tiles.size(), IMPACT_DECAL_MAX_TILES)
	for index: int in range(count):
		var tile: Vector2i = tiles[index]
		decals.append({
			"tile": tile,
			"element": element_id,
			"kind": kind,
			"seed": _impact_decal_seed(tile, element_id, kind)
		})
	return decals

func _impact_decal_tiles(effect: Dictionary, floating_texts: Array) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for text_var: Variant in floating_texts:
		if typeof(text_var) != TYPE_DICTIONARY:
			continue
		var text_entry: Dictionary = text_var
		var text_tile_var: Variant = text_entry.get("tile", INVALID_TARGET_TILE)
		if typeof(text_tile_var) == TYPE_VECTOR2I:
			_append_impact_decal_tile(tiles, text_tile_var)
	if not tiles.is_empty():
		return tiles
	var kind: String = str(effect.get("kind", ""))
	if kind in ["aoe", "lightning_strikes"]:
		for tile: Vector2i in _vector2i_array(effect.get("tiles", [])):
			_append_impact_decal_tile(tiles, tile)
	else:
		var target_tile_var: Variant = effect.get("to", effect.get("center", INVALID_TARGET_TILE))
		if typeof(target_tile_var) == TYPE_VECTOR2I:
			_append_impact_decal_tile(tiles, target_tile_var)
	return tiles

func _append_impact_decal_tile(tiles: Array[Vector2i], tile: Vector2i) -> void:
	if tile.x < 0:
		return
	if not tiles.has(tile):
		tiles.append(tile)

func _impact_decal_seed(tile: Vector2i, element_id: String, kind: String) -> int:
	return tile.x * 92821 + tile.y * 68917 + _impact_element_seed(element_id) * 3571 + kind.length() * 197

func _impact_element_seed(element_id: String) -> int:
	match element_id:
		ElementData.FIRE:
			return 11
		ElementData.ICE:
			return 23
		ElementData.LIGHTNING:
			return 37
		ElementData.AIR:
			return 41
		ElementData.EARTH:
			return 53
		_:
			return 7

func _animate_player_trap_result(after_state: Dictionary, before_state: Dictionary, trap_effects: Array[Dictionary], base_presentation: Dictionary) -> void:
	if trap_effects.is_empty():
		return
	var presentation: Dictionary = base_presentation.duplicate(true)
	presentation["trap_effects"] = trap_effects
	presentation["floating_texts"] = _player_action_floating_texts(before_state, after_state)
	presentation["impact_actor_keys"] = _player_action_impact_actor_keys(before_state, after_state)
	presentation = _death_hold_presentation(before_state, after_state, presentation)
	await _animate_floating_text_presentation(after_state, presentation)

func _animate_player_action_step(before_state: Dictionary, after_state: Dictionary, card_id: String, action: Dictionary, target_tile: Vector2i) -> void:
	var action_type: String = str(action.get("type", ""))
	if _combat_engine.player_action_needs_target(action) and target_tile.x < 0:
		return
	var player_before: Dictionary = before_state.get("player", {})
	var player_after: Dictionary = after_state.get("player", {})
	var player_before_tile: Vector2i = player_before.get("pos", Vector2i.ZERO)
	var player_after_tile: Vector2i = player_after.get("pos", player_before_tile)
	var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, after_state)
	var base_presentation: Dictionary = {
		"focus_actor_keys": ["player"],
		"focus_actor_color": PLAYER_PREVIEW_FOCUS if action_type in ["move", "blink"] else PLAYER_ATTACK_FOCUS
	}
	match action_type:
		"move":
			var move_path: Array[Vector2i] = _resolved_movement_animation_path(
				player_before_tile,
				player_after_tile,
				_combat_engine.path_for_player_action(before_state, action, player_after_tile)
			)
			_set_action_banner(_player_action_label(card_id, action, before_state))
			var movement_presentation: Dictionary = base_presentation.duplicate(true)
			movement_presentation["focus_tiles"] = move_path
			movement_presentation["focus_color"] = Color(0.42, 0.84, 0.93, 0.24)
			movement_presentation["path_tiles"] = move_path
			await _animate_actor_along_path(before_state, "player", move_path, movement_presentation)
			_render_board_state(after_state, _death_hold_presentation(before_state, after_state, base_presentation))
			await get_tree().create_timer(0.06).timeout
			await _animate_player_trap_result(after_state, before_state, triggered_traps, base_presentation)
		"blink":
			_set_action_banner(_player_action_label(card_id, action, before_state))
			for frame: int in range(1, ATTACK_FRAMES + 1):
				var t: float = float(frame) / float(ATTACK_FRAMES)
				_render_board_state(before_state, {
					"focus_actor_keys": ["player"],
					"focus_actor_color": PLAYER_PREVIEW_FOCUS,
					"focus_tiles": [player_after_tile],
					"focus_color": Color(0.53, 0.48, 0.92, 0.24),
					"effect": {"kind": "blink", "from": player_before_tile, "to": player_after_tile},
					"effect_progress": t
				})
				await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
			_render_board_state(after_state, _death_hold_presentation(before_state, after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"focus_tiles": [player_after_tile],
				"focus_color": Color(0.53, 0.48, 0.92, 0.24),
				"effect": {"kind": "blink", "from": player_before_tile, "to": player_after_tile},
				"effect_progress": 1.0
			}))
			await get_tree().create_timer(0.14).timeout
			await _animate_player_trap_result(after_state, before_state, triggered_traps, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"focus_tiles": [player_after_tile],
				"focus_color": Color(0.53, 0.48, 0.92, 0.24)
			})
		"illusion":
			var focus_tiles: Array[Vector2i] = _vector2i_array([target_tile])
			_set_action_banner(_player_action_label(card_id, action, before_state))
			for frame: int in range(1, ATTACK_FRAMES + 1):
				var t: float = float(frame) / float(ATTACK_FRAMES)
				_render_board_state(before_state, {
					"focus_actor_keys": ["player"],
					"focus_actor_color": PLAYER_PREVIEW_FOCUS,
					"focus_tiles": focus_tiles,
					"focus_color": Color(0.40, 0.86, 0.94, 0.18 + 0.12 * t)
				})
				await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
			await _animate_floating_text_presentation(after_state, _death_hold_presentation(before_state, after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"focus_tiles": focus_tiles,
				"focus_color": Color(0.40, 0.86, 0.94, 0.26),
				"floating_texts": [{
					"tile": target_tile,
					"text": "+%d illusion" % int(action.get("health", action.get("amount", 0))),
					"color": Color("9beeff"),
					"offset": -6.0
				}]
			}))
		"illuminate":
			_set_action_banner(_player_action_label(card_id, action, before_state))
			for frame: int in range(1, ATTACK_FRAMES + 1):
				var t: float = float(frame) / float(ATTACK_FRAMES)
				_render_board_state(after_state, {
					"focus_actor_keys": ["player"],
					"focus_actor_color": Color("ffe394"),
					"focus_tiles": [target_tile],
					"focus_color": Color(1.0, 0.82, 0.34, 0.16 + 0.22 * sin(t * PI))
				})
				await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
			await _animate_floating_text_presentation(after_state, {
				"focus_tiles": [target_tile],
				"focus_color": Color(1.0, 0.84, 0.42, 0.30),
				"floating_texts": [{
					"tile": target_tile,
					"text": "Light %d" % int(action.get("radius", action.get("amount", 1))),
					"color": Color("ffe394"),
					"offset": -8.0
				}]
			})
		"vision", "truesight", "dispel_umbra":
			_set_action_banner(_player_action_label(card_id, action, before_state))
			var light_text: String = "Truesight" if action_type == "truesight" else "Umbra -%d" % int(action.get("amount", 1)) if action_type == "dispel_umbra" else "Vision +%d" % int(action.get("amount", 0))
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": Color("ffe394"),
				"floating_texts": [{
					"tile": player_after_tile,
					"text": light_text,
					"color": Color("ffe394"),
					"offset": -8.0
				}]
			})
		"melee", "ranged", "aoe", "push", "pull":
			var effect_target_tile: Vector2i = target_tile
			if action_type == "aoe" and int(action.get("range", 0)) <= 0:
				effect_target_tile = player_before_tile
			var focus_tiles: Array[Vector2i] = _vector2i_array([effect_target_tile])
			if action_type == "aoe":
				focus_tiles = _aoe_tiles_for_action(before_state, action, effect_target_tile)
			var effect := {
				"kind": "ranged" if action_type in ["push", "pull"] else action_type,
				"from": player_before_tile,
				"to": effect_target_tile,
				"center": effect_target_tile,
				"tiles": focus_tiles,
				"element": str(action.get("element", action.get("_card_element", ElementData.NONE))),
				"force_tiles": _combat_engine.forced_movement_tiles_for_player_action(before_state, action, target_tile)
			}
			_set_action_banner(_player_action_label(card_id, action, before_state))
			_play_sfx(AttackSfxLibrary.entry_for_player_action(_card_def(card_id, before_state), action))
			var from_point: Vector2 = board_view.world_position_for_tile(player_before_tile)
			var to_point: Vector2 = board_view.world_position_for_tile(effect_target_tile)
			for frame: int in range(1, ATTACK_FRAMES + 1):
				var t: float = float(frame) / float(ATTACK_FRAMES)
				var presentation := {
					"focus_actor_keys": ["player"],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": focus_tiles,
					"focus_color": Color(0.95, 0.62, 0.37, 0.22),
					"effect": effect,
					"effect_progress": t
				}
				if action_type == "melee":
					presentation["unit_world_positions"] = {
						"player": from_point.lerp(to_point, 0.10 + sin(t * PI) * 0.24)
					}
					presentation["unit_draw_tiles"] = {"player": effect_target_tile}
				_render_board_state(before_state, presentation)
				await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
			await _animate_floating_text_presentation(after_state, _death_hold_presentation(before_state, after_state, _attack_impact_presentation({
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_ATTACK_FOCUS,
				"focus_tiles": focus_tiles,
				"focus_color": Color(0.95, 0.62, 0.37, 0.22),
				"effect": effect,
				"effect_progress": 1.0,
				"impact_actor_keys": _player_action_impact_actor_keys(before_state, after_state),
				"trap_effects": triggered_traps,
				"floating_texts": _player_action_floating_texts(before_state, after_state)
			})))
		"block":
			var block_gain: int = int(player_after.get("block", 0)) - int(player_before.get("block", 0))
			_set_action_banner(_player_action_label(card_id, action, before_state))
			_play_sfx(AttackSfxLibrary.entry_for_block_action(_card_def(card_id, before_state), action))
			await _animate_floating_text_presentation(after_state, _death_hold_presentation(before_state, after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"effect": {"kind": "block", "tile": player_after_tile},
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d" % block_gain,
					"color": Color("90d9ff"),
					"offset": -6.0
				}]
			}))
		"stoneskin":
			var skin_gain: int = int(player_after.get("stoneskin", 0)) - int(player_before.get("stoneskin", 0))
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, _death_hold_presentation(before_state, after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"effect": {"kind": "stoneskin", "tile": player_after_tile},
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d S" % skin_gain,
					"color": ElementData.accent(ElementData.EARTH),
					"offset": -6.0
				}]
			}))
		"heal":
			var heal_amount: int = int(player_after.get("hp", 0)) - int(player_before.get("hp", 0))
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, _death_hold_presentation(before_state, after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"effect": {"kind": "heal", "tile": player_after_tile},
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d" % heal_amount,
					"color": Color("9ee27e"),
					"offset": -6.0
				}]
			}))
		"draw":
			var draw_amount: int = int(((after_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size()) - int(((before_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size())
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, _death_hold_presentation(before_state, after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d draw" % maxi(1, draw_amount),
					"color": Color("f1d18b"),
					"offset": -6.0
				}]
			}))
			await _animate_draw_cards_fx(_draw_entries_between_states(before_state, after_state))
			await get_tree().create_timer(0.12).timeout
		"card_play":
			var card_plays_gained: int = maxi(0, _card_play_count_for_resolution_state(after_state) - _card_play_count_for_resolution_state(before_state))
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, _death_hold_presentation(before_state, after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d play" % maxi(1, card_plays_gained),
					"color": Color("ffe27a"),
					"offset": -6.0
				}]
			}))
			await _animate_card_play_reward(_card_play_count_for_resolution_state(after_state))
			await get_tree().create_timer(0.10).timeout
		"intensity":
			var element_id: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
			var before_value: int = _combat_engine.elemental_intensity(before_state, element_id)
			var after_value: int = _combat_engine.elemental_intensity(after_state, element_id)
			var gained: int = maxi(0, after_value - before_value)
			var intensity_text: String = (
				"+%d %s" % [gained, ElementData.name(element_id)]
				if after_value >= before_value
				else "%s %d" % [ElementData.name(element_id), after_value]
			)
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, _death_hold_presentation(before_state, after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"floating_texts": [{
					"tile": player_after_tile,
					"text": intensity_text,
					"color": ElementData.accent(element_id),
					"offset": -6.0
				}]
			}))
			await _animate_intensity_gain(element_id, after_value)
			await get_tree().create_timer(0.08).timeout
	var secondary_enemy_loss_presentation: Dictionary = _secondary_player_action_enemy_loss_presentation(
		before_state,
		after_state,
		card_id,
		action,
		triggered_traps
	)
	if not secondary_enemy_loss_presentation.is_empty():
		await _animate_floating_text_presentation(
			after_state,
			_death_hold_presentation(before_state, after_state, secondary_enemy_loss_presentation)
		)
	await _animate_defeats_and_terrain_destruction(before_state, after_state)
	await _animate_death_rewards(before_state, after_state)
	for loot_var: Variant in _movement_picked_loot_between(before_state, after_state):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if str(loot.get("kind", "")) != "equipment":
			continue
		var loot_tile: Vector2i = loot.get("pos", player_after_tile)
		await _animate_equipment_pickup_acquisition_flair(
			str(loot.get("equipment_id", "")),
			loot_tile
		)

func _resolve_enemy_round() -> void:
	_animation_lock = true
	_refresh_animation_lock_ui()
	var previous_run_state: Dictionary = _run_state.duplicate(true)
	var previous_combat_state: Dictionary = _combat_state.duplicate(true)
	var previous_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var scheduled_state: Dictionary = _combat_engine.finish_player_activation(_combat_state)
	var phase_result: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(scheduled_state)
	var commit_checkpoints: Array = _combat_commit_checkpoints(phase_result.get("steps", []))
	_hold_committed_run_state(
		_run_state_with_combat_checkpoints(
			_run_state_for_combat_checkpoint(previous_run_state, scheduled_state),
			commit_checkpoints
		),
		"player_activation_finished"
	)
	await _animate_enemy_loss_feedback_between_states(_combat_state, scheduled_state)
	await _animate_defeats_and_terrain_destruction(_combat_state, scheduled_state)
	await _animate_turn_order_transition_between_states(_combat_state, scheduled_state)
	_combat_state = scheduled_state.duplicate(true)
	_mark_combat_preview_state_changed()
	var animated_state: Dictionary = scheduled_state.duplicate(true)
	await _animate_enemy_phase_steps(animated_state, phase_result.get("steps", []), previous_run_state, commit_checkpoints)
	var final_combat_state: Dictionary = (phase_result.get("state", {}) as Dictionary).duplicate(true)
	var final_run_state: Dictionary = _run_state_for_combat_checkpoint(previous_run_state, final_combat_state)
	var outcome: String = _combat_engine.combat_outcome(final_combat_state)
	var transition_combat_state: Dictionary = final_combat_state.duplicate(true)
	if outcome == "victory":
		transition_combat_state = await _animate_missed_equipment_resolution(final_combat_state, _salvaged_equipment_ids(final_run_state))
	_board_presentation.clear()
	_set_action_banner("")
	if _committed_run_state_override.is_empty() or _committed_run_state_override != final_run_state:
		final_run_state = _hold_committed_run_state(final_run_state, "enemy_round_complete")
	else:
		final_run_state = _committed_run_state_override.duplicate(true)
	_run_state = final_run_state
	_sync_combat_state_from_run()
	_release_committed_run_state()
	_analytics_log_enemy_status_ticks(phase_result)
	_analytics_log_enemy_actions(phase_result)
	var before_draw_state: Dictionary = (phase_result.get("player_turn_before_state", {}) as Dictionary).duplicate(true)
	if outcome == "" and not before_draw_state.is_empty():
		var fatigue_events: Array[Dictionary] = _fatigue_damage_events_between_states(before_draw_state, _combat_state)
		_analytics_reconcile_combat_tracker(before_draw_state, _combat_state)
		_analytics_log_card_draws(before_draw_state, _combat_state, previous_tracker, _analytics_snapshot_combat_tracker(), "turn_draw")
		_analytics_log_playable_cards()
		if not fatigue_events.is_empty():
			await _animate_fatigue_damage(_combat_state, fatigue_events)
		await _animate_draw_cards_fx(_draw_entries_between_states(before_draw_state, _combat_state))
		outcome = _combat_engine.combat_outcome(_combat_state)
	_analytics_log_combat_transition(previous_run_state, "enemy_round", transition_combat_state)
	_animation_lock = false
	if outcome == "":
		_queue_hand_ready_wave("player_turn_start")
	_refresh_ui()

func _animate_enemy_phase_steps(animated_state: Dictionary, steps: Array, base_run_state: Dictionary, commit_checkpoints: Array) -> void:
	if steps.is_empty():
		return
	var commit_index: int = 0
	for step_var: Variant in steps:
		var step: Dictionary = step_var
		if str(step.get("kind", "")) == "commit":
			var checkpoint_state: Dictionary = (step.get("state", {}) as Dictionary).duplicate(true)
			if not checkpoint_state.is_empty():
				_hold_committed_run_state(
					_run_state_with_combat_checkpoints(
						_run_state_for_combat_checkpoint(base_run_state, checkpoint_state),
						_remaining_combat_checkpoints(commit_checkpoints, commit_index + 1)
					),
					str(step.get("boundary", "enemy_checkpoint"))
				)
			commit_index += 1
			continue
		if bool(step.get("hidden_by_umbra", false)):
			await _animate_hidden_umbra_enemy_step(animated_state, step)
			continue
		var step_actor_key: String = str(step.get("actor_key", ""))
		var step_actor_tile: Vector2i = step.get("tile", step.get("from", Vector2i(-1, -1)))
		match str(step.get("kind", "")):
			"turn_order":
				await _animate_turn_order_transition(_turn_order_array(step.get("before_order", [])), _turn_order_array(step.get("after_order", [])))
			"intent":
				_clear_enemy_block_by_key(animated_state, step_actor_key)
				_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("intent_name", ""))])
				_render_board_state(animated_state, {
					"focus_actor_keys": [step_actor_key],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": [step_actor_tile],
					"focus_color": Color(0.95, 0.62, 0.37, 0.18)
				})
				await get_tree().create_timer(0.20).timeout
			"move":
				await _animate_move_step(animated_state, step)
			"block", "heal", "stoneskin", "status", "status_damage", "intensity":
				var before_status_step_state: Dictionary = animated_state.duplicate(true)
				_apply_animation_step(animated_state, step)
				_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
				if str(step.get("kind", "")) == "block":
					_play_sfx(AttackSfxLibrary.entry_for_enemy_step(step))
				await _animate_floating_text_presentation(
					animated_state,
					_death_hold_presentation(
						before_status_step_state,
						animated_state,
						_enemy_phase_status_presentation(step)
					)
				)
				await _animate_defeats_and_terrain_destruction(before_status_step_state, animated_state)
			"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
				var focus_tiles: Array[Vector2i] = _vector2i_array([step.get("to", Vector2i(-1, -1))])
				if str(step.get("kind", "")) in ["aoe", "lightning_strikes"]:
					focus_tiles = _vector2i_array(step.get("tiles", []))
				_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
				_play_sfx(AttackSfxLibrary.entry_for_enemy_step(step))
				var from_point: Vector2 = board_view.world_position_for_tile(step.get("from", Vector2i.ZERO))
				var to_point: Vector2 = board_view.world_position_for_tile(step.get("to", Vector2i.ZERO))
				for frame: int in range(1, ATTACK_FRAMES + 1):
					var t: float = float(frame) / float(ATTACK_FRAMES)
					var presentation := {
						"focus_actor_keys": [step_actor_key],
						"focus_actor_color": PLAYER_ATTACK_FOCUS,
						"focus_tiles": focus_tiles,
						"focus_color": Color(0.95, 0.62, 0.37, 0.18),
						"effect": step,
						"effect_progress": t
					}
					if str(step.get("kind", "")) == "melee":
						presentation["unit_world_positions"] = {
							step_actor_key: from_point.lerp(to_point, 0.08 + sin(t * PI) * 0.22)
						}
						presentation["unit_draw_tiles"] = {
							step_actor_key: step.get("to", Vector2i.ZERO)
						}
					_render_board_state(animated_state, presentation)
					await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
				var before_attack_step_state: Dictionary = animated_state.duplicate(true)
				_apply_animation_step(animated_state, step)
				var impact_actor_keys: Array = step.get("impact_actor_keys", [])
				if impact_actor_keys.is_empty() and (int(step.get("hp_loss", 0)) > 0 or int(step.get("block_loss", 0)) > 0 or int(step.get("stoneskin_loss", 0)) > 0):
					impact_actor_keys = ["player"]
				await _animate_floating_text_presentation(animated_state, _death_hold_presentation(before_attack_step_state, animated_state, _attack_impact_presentation({
					"focus_actor_keys": [step_actor_key],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": focus_tiles,
					"focus_color": Color(0.95, 0.62, 0.37, 0.18),
					"effect": step,
					"effect_progress": 1.0,
					"trap_effects": step.get("triggered_traps", []),
					"impact_actor_keys": impact_actor_keys,
					"floating_texts": _floating_texts_for_step(step)
				})))
				await _animate_defeats_and_terrain_destruction(before_attack_step_state, animated_state)

func _animate_hidden_umbra_enemy_step(animated_state: Dictionary, step: Dictionary) -> void:
	var kind: String = str(step.get("kind", ""))
	if kind == "intent":
		_clear_enemy_block_by_key(animated_state, str(step.get("actor_key", "")))
		_set_action_banner("Unknown Presence: Hidden Intent")
		_render_board_state(animated_state, {})
		await get_tree().create_timer(0.16).timeout
		return
	var before_step_state: Dictionary = animated_state.duplicate(true)
	_apply_animation_step(animated_state, step)
	if bool(step.get("revealed_after_action", false)):
		_set_action_banner("A presence emerges from the Umbra.")
	else:
		_set_action_banner("A hidden presence attacks." if kind in ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes"] else "Something stirs in the Umbra.")
	var focus_tiles: Array[Vector2i] = []
	for tile: Vector2i in _vector2i_array([step.get("tile", Vector2i(-1, -1)), step.get("to", Vector2i(-1, -1))] + (step.get("tiles", []) as Array)):
		if tile.x >= 0 and _combat_engine.is_tile_visible_to_player(animated_state, tile) and not focus_tiles.has(tile):
			focus_tiles.append(tile)
	var impact_actor_keys: Array = step.get("impact_actor_keys", [])
	if impact_actor_keys.is_empty() and (int(step.get("hp_loss", 0)) > 0 or int(step.get("block_loss", 0)) > 0 or int(step.get("stoneskin_loss", 0)) > 0):
		impact_actor_keys = ["player"]
	await _animate_floating_text_presentation(animated_state, _death_hold_presentation(before_step_state, animated_state, {
		"focus_actor_keys": impact_actor_keys,
		"focus_actor_color": PLAYER_ATTACK_FOCUS,
		"focus_tiles": focus_tiles,
		"focus_color": Color(0.66, 0.42, 0.80, 0.17),
		"impact_actor_keys": impact_actor_keys,
		"floating_texts": _visible_umbra_floating_texts(animated_state, _floating_texts_for_step(step))
	}))
	await _animate_defeats_and_terrain_destruction(before_step_state, animated_state)
	await get_tree().create_timer(0.06).timeout

func _visible_umbra_floating_texts(state: Dictionary, values: Array) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for value: Variant in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
		if tile.x >= 0 and _umbra_information_tile_visible(state, tile):
			visible.append(entry.duplicate(true))
	return visible

func _umbra_information_tile_visible(state: Dictionary, tile: Vector2i) -> bool:
	if _combat_engine.is_tile_visible_to_player(state, tile):
		return true
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		if _combat_engine.is_enemy_visible_to_player(state, enemy) and _enemy_footprint_tiles(enemy).has(tile):
			return true
	return false

func _animate_move_step(animated_state: Dictionary, step: Dictionary) -> void:
	var from_tile: Vector2i = step.get("from", Vector2i.ZERO)
	var to_tile: Vector2i = step.get("to", Vector2i.ZERO)
	var actor_key: String = str(step.get("actor_key", ""))
	var path: Array[Vector2i] = _resolved_movement_animation_path(from_tile, to_tile, step.get("path", []))
	_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await _animate_actor_along_path(animated_state, actor_key, path, {
		"focus_actor_keys": [actor_key],
		"focus_actor_color": PLAYER_ATTACK_FOCUS,
		"focus_color": Color(0.95, 0.62, 0.37, 0.18),
		"path_tiles": path,
		"path_color": ENEMY_PATH_PREVIEW_COLOR
	})
	var before_move_state: Dictionary = animated_state.duplicate(true)
	_apply_animation_step(animated_state, step)
	if not (step.get("triggered_traps", []) as Array).is_empty() or not (step.get("target_losses", []) as Array).is_empty() or not (step.get("enemy_losses", []) as Array).is_empty() or not (step.get("terrain_losses", []) as Array).is_empty():
		await _animate_floating_text_presentation(animated_state, _death_hold_presentation(before_move_state, animated_state, {
			"focus_actor_keys": step.get("impact_actor_keys", [actor_key]),
			"focus_actor_color": PLAYER_ATTACK_FOCUS,
			"focus_tiles": [to_tile],
			"focus_color": Color(0.95, 0.62, 0.37, 0.18),
			"trap_effects": step.get("triggered_traps", []),
			"impact_actor_keys": step.get("impact_actor_keys", []),
			"floating_texts": _floating_texts_for_step(step)
		}))
		await _animate_defeats_and_terrain_destruction(before_move_state, animated_state)
	_render_board_state(animated_state, {})
	await get_tree().create_timer(0.06).timeout

func _resolved_movement_animation_path(from_tile: Vector2i, to_tile: Vector2i, path_values: Array) -> Array[Vector2i]:
	var path: Array[Vector2i] = _vector2i_array(path_values)
	if path.size() < 2 or path[0] != from_tile or path[path.size() - 1] != to_tile:
		return _vector2i_array([from_tile, to_tile])
	return path

func _animate_actor_along_path(display_state: Dictionary, actor_key: String, path: Array[Vector2i], base_presentation: Dictionary) -> void:
	var actor_unit: Dictionary = _animation_actor_unit(display_state, actor_key)
	for path_index: int in range(path.size() - 1):
		var segment_from: Vector2i = path[path_index]
		var segment_to: Vector2i = path[path_index + 1]
		var from_point: Vector2 = board_view.world_position_for_unit_origin(actor_unit, segment_from)
		var to_point: Vector2 = board_view.world_position_for_unit_origin(actor_unit, segment_to)
		var draw_tile: Vector2i = board_view.draw_tile_for_unit_origin(actor_unit, segment_to)
		for frame: int in range(1, MOVE_STEP_FRAMES + 1):
			var t: float = float(frame) / float(MOVE_STEP_FRAMES)
			var presentation: Dictionary = base_presentation.duplicate(true)
			if not presentation.has("focus_tiles"):
				presentation["focus_tiles"] = [segment_to]
			presentation["unit_world_positions"] = {actor_key: from_point.lerp(to_point, t)}
			presentation["unit_draw_tiles"] = {actor_key: draw_tile}
			_render_board_state(display_state, presentation)
			await get_tree().create_timer(MOVE_FRAME_SECONDS).timeout

func _play_sfx(entry: Dictionary) -> void:
	var path: String = str(entry.get("path", ""))
	if path.is_empty():
		return
	var resource: AudioStream = AssetLoader.load_audio_stream(path)
	if resource == null:
		return
	var player: AudioStreamPlayer = _acquire_sfx_player()
	var generation: int = int(player.get_meta("play_generation", 0)) + 1
	player.set_meta("play_generation", generation)
	player.stream = resource
	player.bus = SettingsStore.SFX_BUS
	player.volume_db = float(entry.get("volume_db", 0.0))
	player.play()
	var duration: float = float(entry.get("duration", 0.0))
	if duration > 0.0:
		get_tree().create_timer(duration).timeout.connect(_stop_attack_sfx_player.bind(player, generation))

func _acquire_sfx_player() -> AudioStreamPlayer:
	for player_var: Variant in _sfx_players:
		var pooled_player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if pooled_player != null and not pooled_player.playing:
			return pooled_player
	var player := AudioStreamPlayer.new()
	player.name = "SfxPlayer%d" % _sfx_players.size()
	player.bus = SettingsStore.SFX_BUS
	add_child(player)
	_sfx_players.append(player)
	return player

func _stop_attack_sfx_player(player: AudioStreamPlayer, generation: int = -1) -> void:
	if not is_instance_valid(player):
		return
	if generation >= 0 and int(player.get_meta("play_generation", 0)) != generation:
		return
	player.stop()
	player.stream = null

func _update_music_for_context(room: Dictionary) -> void:
	_play_music(MusicLibrary.entry_for_context(str(_run_state.get("mode", "room")), room, _combat_state))

func _play_music(entry: Dictionary) -> void:
	var track_id: String = str(entry.get("id", ""))
	if track_id == _active_music_id:
		return
	_ensure_music_player()
	if track_id.is_empty():
		_fade_out_music()
		return
	var path: String = str(entry.get("path", ""))
	var resource: AudioStream = AssetLoader.load_audio_stream(path)
	if resource == null:
		_fade_out_music()
		return
	_music_player.stream = resource
	_active_music_id = track_id
	_stop_music_tween()
	_music_player.volume_db = MUSIC_SILENCE_DB
	_music_player.play()
	_fade_music_to(float(entry.get("volume_db", -12.0)))

func _ensure_music_player() -> void:
	if _music_player != null:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = SettingsStore.MUSIC_BUS
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	if _music_player == null or _active_music_id.is_empty() or _music_player.stream == null:
		return
	_music_player.play()

func _fade_music_to(volume_db: float) -> void:
	if _music_player == null:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", volume_db, MUSIC_FADE_SECONDS)

func _fade_out_music() -> void:
	if _music_player == null or _music_player.stream == null:
		_active_music_id = ""
		return
	_active_music_id = ""
	_stop_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", MUSIC_SILENCE_DB, MUSIC_FADE_SECONDS)
	_music_tween.finished.connect(_finish_music_fade_out)

func _finish_music_fade_out() -> void:
	if _music_player == null or not _active_music_id.is_empty():
		return
	_music_player.stop()
	_music_player.stream = null

func _stop_music_tween() -> void:
	if _music_tween == null:
		return
	if _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

func _render_board_state(display_state: Dictionary, presentation: Dictionary) -> void:
	var rendered_presentation: Dictionary = presentation.duplicate(false)
	rendered_presentation["board_backdrop_visible"] = _board_backdrop_visible_for_board()
	rendered_presentation["reduced_motion"] = _reduced_motion_enabled()
	_apply_umbra_board_presentation(display_state, rendered_presentation)
	rendered_presentation["active_door_tiles"] = _active_door_tiles_for_board()
	rendered_presentation["locked_door_tiles"] = _locked_door_tiles_for_board()
	rendered_presentation["equipped_equipment"] = _equipped_equipment_for_board()
	board_view.set_combat_state(
		display_state,
		[],
		[],
		(display_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)),
		"",
		"",
		{},
		{},
		rendered_presentation
	)
	_refresh_turn_order_boss_dossier(display_state, rendered_presentation)

func _board_backdrop_visible_for_board() -> bool:
	return (
		board_backdrop != null
		and board_backdrop.visible
		and board_view != null
		and board_view.visible
	)

func _apply_umbra_board_presentation(display_state: Dictionary, target_presentation: Dictionary) -> void:
	if display_state.is_empty() or not display_state.has("umbra"):
		return
	target_presentation["umbra_stage"] = _combat_engine.effective_umbra_stage(display_state)
	target_presentation["umbra_radius"] = _combat_engine.effective_umbra_radius(display_state)
	target_presentation["umbra_visible_tiles"] = _combat_engine.umbra_visible_tiles(display_state)
	target_presentation["visible_enemy_ids"] = _combat_engine.visible_enemy_ids(display_state)
	target_presentation["umbra_light_sources"] = ((display_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).duplicate(true)
	var umbra_state: Dictionary = display_state.get("umbra", {}) as Dictionary
	target_presentation["umbra_truesight_activations"] = int(umbra_state.get("truesight_activations", 0))
	target_presentation["umbra_truesight"] = int(target_presentation["umbra_truesight_activations"]) != 0
	target_presentation["umbra_vision_bonus_activations"] = int(umbra_state.get("vision_bonus_activations", 0))
	if target_presentation.has("floating_texts"):
		target_presentation["floating_texts"] = _visible_umbra_floating_texts(display_state, target_presentation.get("floating_texts", []) as Array)

func _equipped_equipment_for_board() -> Dictionary:
	return _run_state.get("equipped_equipment", {}) as Dictionary

func _apply_animation_step(animated_state: Dictionary, step: Dictionary) -> void:
	match str(step.get("kind", "")):
		"move":
			_set_enemy_pos_by_key(animated_state, str(step.get("actor_key", "")), step.get("to", Vector2i.ZERO))
			_apply_actor_losses(animated_state, step.get("target_losses", []))
			_apply_enemy_losses(animated_state, step.get("enemy_losses", []))
			_apply_terrain_losses(animated_state, step.get("terrain_losses", []))
			_remove_triggered_traps(animated_state, step.get("triggered_traps", []))
		"block":
			_add_enemy_block_by_key(animated_state, str(step.get("actor_key", "")), int(step.get("amount", 0)))
		"stoneskin":
			_add_enemy_stoneskin_by_key(animated_state, str(step.get("actor_key", "")), int(step.get("amount", 0)))
		"heal":
			_add_enemy_heal_by_key(animated_state, str(step.get("actor_key", "")), int(step.get("amount", 0)))
		"status_damage":
			if step.has("enemies_after"):
				animated_state["enemies"] = (step.get("enemies_after", []) as Array).duplicate(true)
			elif not (step.get("enemy_losses", []) as Array).is_empty():
				_apply_enemy_losses(animated_state, step.get("enemy_losses", []))
			else:
				_apply_enemy_damage_by_key(animated_state, str(step.get("actor_key", "")), int(step.get("amount", 0)))
			if step.has("elemental_intensity_after"):
				animated_state["elemental_intensity"] = (step.get("elemental_intensity_after", {}) as Dictionary).duplicate(true)
			if step.has("player_after"):
				animated_state["player"] = (step.get("player_after", {}) as Dictionary).duplicate(true)
		"status":
			if step.has("terrain_after"):
				animated_state["terrain"] = (step.get("terrain_after", []) as Array).duplicate(true)
			if step.has("traps_after"):
				animated_state["traps"] = (step.get("traps_after", []) as Array).duplicate(true)
			if step.has("enemy_after"):
				_set_enemy_snapshot_by_key(animated_state, str(step.get("actor_key", "")), step.get("enemy_after", {}) as Dictionary)
		"intensity":
			var elemental_intensity: Dictionary = (animated_state.get("elemental_intensity", {}) as Dictionary).duplicate(true)
			elemental_intensity[str(step.get("element", ElementData.NONE))] = int(step.get("value_after", 0))
			animated_state["elemental_intensity"] = elemental_intensity
			_apply_enemy_losses(animated_state, step.get("enemy_losses", []))
		"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
			var target_losses: Array = step.get("target_losses", [])
			if target_losses.is_empty():
				_apply_player_losses(animated_state, int(step.get("hp_loss", 0)), int(step.get("block_loss", 0)), int(step.get("stoneskin_loss", 0)))
			else:
				_apply_actor_losses(animated_state, target_losses)
			if step.has("player_to"):
				_set_player_pos(animated_state, step.get("player_to", Vector2i.ZERO))
			_apply_terrain_losses(animated_state, step.get("terrain_losses", []))
			_remove_triggered_traps(animated_state, step.get("triggered_traps", []))
			if step.has("umbra_after"):
				animated_state["umbra"] = (step.get("umbra_after", {}) as Dictionary).duplicate(true)
			if step.has("enemy_after"):
				_set_enemy_snapshot_by_key(animated_state, str(step.get("actor_key", "")), step.get("enemy_after", {}) as Dictionary)

func _floating_texts_for_step(step: Dictionary) -> Array[Dictionary]:
	match str(step.get("kind", "")):
		"move":
			var movement_floats: Array[Dictionary]
			movement_floats.append_array(_floating_texts_for_target_losses(step.get("target_losses", [])))
			movement_floats.append_array(_floating_texts_for_target_losses(step.get("enemy_losses", [])))
			movement_floats.append_array(_floating_texts_for_terrain_losses(step.get("terrain_losses", [])))
			return movement_floats
		"block":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": "+%d" % int(step.get("amount", 0)),
				"color": Color("90d9ff"),
				"offset": -6.0
			}]
		"stoneskin":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": "+%d S" % int(step.get("amount", 0)),
				"color": ElementData.accent(ElementData.EARTH),
				"offset": -6.0
			}]
		"heal":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": "+%d" % int(step.get("amount", 0)),
				"color": Color("9ee27e"),
				"offset": -6.0
			}]
		"status":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": str(step.get("text", step.get("label", ""))),
				"color": Color("f1d18b"),
				"offset": -6.0
			}]
		"status_damage":
			return _status_damage_floating_texts(step)
		"intensity":
			var intensity_floats: Array[Dictionary] = []
			var intensity_before: int = int(step.get("value_before", 0))
			var intensity_after: int = int(step.get("value_after", intensity_before))
			if intensity_after != intensity_before:
				intensity_floats.append({
					"tile": step.get("tile", Vector2i.ZERO),
					"text": "%s %d" % [ElementData.name(str(step.get("element", ElementData.NONE))), intensity_after],
					"color": ElementData.accent(str(step.get("element", ElementData.NONE))),
					"offset": -6.0
				})
			intensity_floats.append_array(_floating_texts_for_target_losses(step.get("enemy_losses", [])))
			return intensity_floats
		"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
			var target_losses: Array = step.get("target_losses", [])
			var terrain_losses: Array = step.get("terrain_losses", [])
			var floats: Array[Dictionary] = []
			if not target_losses.is_empty():
				floats.append_array(_floating_texts_for_target_losses(target_losses, str(step.get("status_text", "")), step.get("to", Vector2i.ZERO)))
			else:
				if int(step.get("hp_loss", 0)) > 0:
					floats.append({
						"tile": step.get("to", Vector2i.ZERO),
						"text": "-%d" % int(step.get("hp_loss", 0)),
						"color": Color("f39779"),
						"offset": -10.0
					})
				if int(step.get("block_loss", 0)) > 0:
					floats.append({
						"tile": step.get("to", Vector2i.ZERO),
						"text": "-%d B" % int(step.get("block_loss", 0)),
						"color": Color("90d9ff"),
						"offset": 10.0
					})
				if int(step.get("stoneskin_loss", 0)) > 0:
					floats.append({
						"tile": step.get("to", Vector2i.ZERO),
						"text": "-%d S" % int(step.get("stoneskin_loss", 0)),
						"color": ElementData.accent(ElementData.EARTH),
						"offset": 22.0
					})
				if not str(step.get("status_text", "")).is_empty():
					floats.append({
						"tile": step.get("to", Vector2i.ZERO),
						"text": str(step.get("status_text", "")),
						"color": Color("f1d18b"),
						"offset": -24.0
					})
			floats.append_array(_floating_texts_for_terrain_losses(terrain_losses))
			return floats
		_:
			return []

func _enemy_phase_status_presentation(step: Dictionary) -> Dictionary:
	var presentation: Dictionary = {
		"focus_actor_keys": [str(step.get("actor_key", ""))],
		"focus_actor_color": PLAYER_ATTACK_FOCUS,
		"focus_tiles": _vector2i_array(step.get("focus_tiles", [step.get("tile", Vector2i(-1, -1))])),
		"focus_color": Color(0.95, 0.62, 0.37, 0.18),
		"effect": step,
		"impact_actor_keys": step.get("impact_actor_keys", []),
		"floating_texts": _floating_texts_for_step(step)
	}
	if (step.get("enemy_losses", []) as Array).is_empty():
		return presentation
	var element_id: String = _enemy_phase_damage_feedback_element(step)
	presentation["effect"] = {
		"kind": "lightning_strikes" if element_id == ElementData.LIGHTNING else "aoe",
		"element": element_id
	}
	return _attack_impact_presentation(presentation)

func _enemy_phase_damage_feedback_element(step: Dictionary) -> String:
	var element_id: String = str(step.get("damage_feedback_element", step.get("element", ElementData.NONE)))
	if ElementData.is_elemental(element_id):
		return element_id
	match str(step.get("label", "")):
		"Burn":
			return ElementData.FIRE
		"Poison":
			return ElementData.EARTH
		_:
			return ElementData.NONE

func _status_damage_floating_texts(step: Dictionary) -> Array[Dictionary]:
	var enemy_losses: Array = step.get("enemy_losses", [])
	if enemy_losses.is_empty():
		var legacy_float: Dictionary = {
			"tile": step.get("tile", Vector2i.ZERO),
			"text": "-%d" % int(step.get("amount", 0)),
			"color": Color("f39779"),
			"offset": -6.0
		}
		if str(step.get("label", "")) == "Bleed":
			_decorate_bleed_damage_float(legacy_float)
		return [legacy_float]
	var floats: Array[Dictionary] = _floating_texts_for_target_losses(enemy_losses)
	if str(step.get("label", "")) != "Bleed":
		return floats
	var actor_key: String = str(step.get("actor_key", ""))
	var actor_tile: Vector2i = step.get("tile", Vector2i.ZERO)
	for loss_var: Variant in enemy_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		if str(loss.get("key", "")) == actor_key:
			actor_tile = loss.get("tile", actor_tile)
			break
	for float_entry: Dictionary in floats:
		if float_entry.get("tile", Vector2i.ZERO) != actor_tile:
			continue
		_decorate_bleed_damage_float(float_entry)
		break
	return floats

func _decorate_bleed_damage_float(float_entry: Dictionary) -> void:
	float_entry["icon"] = "bleed"
	float_entry["icon_tint"] = Color("ffe9df")
	float_entry["icon_fill"] = Color(0.18, 0.05, 0.05, 0.94)
	float_entry["icon_border"] = Color("ff8a76")
	float_entry["width"] = 70.0
	float_entry["x_offset"] = -26.0

func _floating_texts_for_target_losses(target_losses: Array, status_text: String = "", status_tile: Vector2i = Vector2i.ZERO) -> Array[Dictionary]:
	var floats: Array[Dictionary] = []
	for loss_var: Variant in target_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var tile: Vector2i = loss.get("tile", Vector2i.ZERO)
		if int(loss.get("hp_loss", 0)) > 0:
			floats.append({
				"tile": tile,
				"text": "-%d" % int(loss.get("hp_loss", 0)),
				"color": Color("f39779"),
				"offset": -10.0
			})
		if int(loss.get("block_loss", 0)) > 0:
			floats.append({
				"tile": tile,
				"text": "-%d B" % int(loss.get("block_loss", 0)),
				"color": Color("90d9ff"),
				"offset": 10.0
			})
		if int(loss.get("stoneskin_loss", 0)) > 0:
			floats.append({
				"tile": tile,
				"text": "-%d S" % int(loss.get("stoneskin_loss", 0)),
				"color": ElementData.accent(ElementData.EARTH),
				"offset": 22.0
			})
		if int(loss.get("defiance_restored", 0)) > 0:
			floats.append({
				"tile": tile,
				"text": "DEFIANCE +%d · %d LEFT" % [
					int(loss.get("defiance_restored", 0)),
					int(loss.get("defiance_remaining", 0))
				],
				"color": Color("f6d77d"),
				"offset": -30.0,
				"x_offset": -26.0,
				"width": 184.0,
				"icon": "defiance",
				"icon_tint": Color("fff3c4"),
				"icon_fill": Color(0.14, 0.08, 0.20, 0.96),
				"icon_border": Color("d6aa5e")
			})
		if str(loss.get("kind", "")) == "player":
			status_tile = tile
	if not status_text.is_empty():
		floats.append({
			"tile": status_tile,
			"text": status_text,
			"color": Color("f1d18b"),
			"offset": -24.0
		})
	return floats

func _floating_texts_for_terrain_losses(terrain_losses: Array) -> Array[Dictionary]:
	var floats: Array[Dictionary] = []
	for loss_var: Variant in terrain_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var hp_loss: int = int(loss.get("hp_loss", loss.get("amount", 0)))
		if hp_loss <= 0:
			continue
		floats.append({
			"tile": loss.get("tile", Vector2i.ZERO),
			"text": "-%d" % hp_loss,
			"color": Color("f0c85c"),
			"offset": -4.0
		})
	return floats

func _terrain_target_losses_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_by_id: Dictionary = {}
	for after_terrain_var: Variant in after_state.get("terrain", []):
		if typeof(after_terrain_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = after_terrain_var
		after_by_id[str(after_terrain.get("id", ""))] = after_terrain
	var losses: Array[Dictionary] = []
	for before_terrain_var: Variant in before_state.get("terrain", []):
		if typeof(before_terrain_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = before_terrain_var
		if int(before_terrain.get("hp", 0)) <= 0:
			continue
		var terrain_id: String = str(before_terrain.get("id", ""))
		var after_terrain: Dictionary = after_by_id.get(terrain_id, before_terrain)
		var hp_loss: int = int(before_terrain.get("hp", 0)) - int(after_terrain.get("hp", 0))
		if hp_loss <= 0:
			continue
		losses.append({
			"key": "terrain_%s" % terrain_id,
			"kind": str(before_terrain.get("kind", "terrain")),
			"id": terrain_id,
			"tile": before_terrain.get("pos", Vector2i.ZERO),
			"hp_loss": hp_loss,
			"amount": hp_loss
		})
	return losses

func _triggered_traps_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_ids: Dictionary = {}
	for after_trap_var: Variant in after_state.get("traps", []):
		if typeof(after_trap_var) != TYPE_DICTIONARY:
			continue
		var after_trap: Dictionary = after_trap_var
		after_ids[str(after_trap.get("id", ""))] = true
	var triggered: Array[Dictionary] = []
	for before_trap_var: Variant in before_state.get("traps", []):
		if typeof(before_trap_var) != TYPE_DICTIONARY:
			continue
		var before_trap: Dictionary = (before_trap_var as Dictionary).duplicate(true)
		var trap_id: String = str(before_trap.get("id", ""))
		if trap_id.is_empty() or after_ids.has(trap_id):
			continue
		before_trap["resolved_damage"] = _combat_engine.trap_damage(before_state, before_trap)
		triggered.append(before_trap)
	return triggered

func _set_enemy_pos_by_key(state: Dictionary, actor_key: String, pos: Vector2i) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["pos"] = pos
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _set_enemy_snapshot_by_key(state: Dictionary, actor_key: String, snapshot: Dictionary) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		(state.get("enemies", []) as Array)[enemy_index] = snapshot.duplicate(true)
		return

func _add_enemy_block_by_key(state: Dictionary, actor_key: String, amount: int) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["block"] = int(enemy.get("block", 0)) + amount
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _clear_enemy_block_by_key(state: Dictionary, actor_key: String) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["block"] = 0
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _add_enemy_heal_by_key(state: Dictionary, actor_key: String, amount: int) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["hp"] = mini(int(enemy.get("max_hp", 1)), int(enemy.get("hp", 0)) + amount)
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _add_enemy_stoneskin_by_key(state: Dictionary, actor_key: String, amount: int) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["stoneskin"] = int(enemy.get("stoneskin", 0)) + amount
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _apply_enemy_damage_by_key(state: Dictionary, actor_key: String, amount: int) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - amount)
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _apply_player_losses(state: Dictionary, hp_loss: int, block_loss: int, stoneskin_loss: int = 0) -> void:
	var player: Dictionary = state.get("player", {})
	player["block"] = maxi(0, int(player.get("block", 0)) - block_loss)
	player["stoneskin"] = maxi(0, int(player.get("stoneskin", 0)) - stoneskin_loss)
	player["hp"] = maxi(0, int(player.get("hp", 0)) - hp_loss)
	state["player"] = player

func _apply_actor_losses(state: Dictionary, target_losses: Array) -> void:
	for loss_var: Variant in target_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		match str(loss.get("kind", "")):
			"player":
				_apply_player_losses(state, int(loss.get("hp_loss", 0)), int(loss.get("block_loss", 0)), int(loss.get("stoneskin_loss", 0)))
				var restored_hp: int = maxi(0, int(loss.get("defiance_restored", 0)))
				if restored_hp > 0:
					var player: Dictionary = state.get("player", {})
					player["hp"] = mini(int(player.get("max_hp", 1)), int(player.get("hp", 0)) + restored_hp)
					state["player"] = player
					state["defiance_remaining"] = maxi(0, int(loss.get("defiance_remaining", 0)))
			"illusion":
				_apply_illusion_loss_by_key(state, str(loss.get("key", "")), int(loss.get("hp_loss", 0)))

func _apply_enemy_losses(state: Dictionary, enemy_losses: Array) -> void:
	for loss_var: Variant in enemy_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var actor_key: String = str(loss.get("key", ""))
		for enemy_index: int in range((state.get("enemies", []) as Array).size()):
			var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
			if _enemy_key(enemy) != actor_key:
				continue
			enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - int(loss.get("hp_loss", 0)))
			enemy["block"] = maxi(0, int(enemy.get("block", 0)) - int(loss.get("block_loss", 0)))
			enemy["stoneskin"] = maxi(0, int(enemy.get("stoneskin", 0)) - int(loss.get("stoneskin_loss", 0)))
			(state.get("enemies", []) as Array)[enemy_index] = enemy
			break

func _apply_terrain_losses(state: Dictionary, terrain_losses: Array) -> void:
	if terrain_losses.is_empty():
		return
	var terrain_entries: Array = (state.get("terrain", []) as Array).duplicate(true)
	for loss_var: Variant in terrain_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var terrain_id: String = str(loss.get("id", ""))
		if terrain_id.is_empty():
			continue
		for terrain_index: int in range(terrain_entries.size()):
			var terrain: Dictionary = terrain_entries[terrain_index]
			if str(terrain.get("id", "")) != terrain_id:
				continue
			terrain["hp"] = maxi(0, int(terrain.get("hp", 0)) - int(loss.get("hp_loss", loss.get("amount", 0))))
			terrain_entries[terrain_index] = terrain
			break
	state["terrain"] = terrain_entries

func _remove_triggered_traps(state: Dictionary, triggered_traps: Array) -> void:
	if triggered_traps.is_empty():
		return
	var triggered_ids: Dictionary = {}
	for trap_var: Variant in triggered_traps:
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap_id: String = str((trap_var as Dictionary).get("id", ""))
		if not trap_id.is_empty():
			triggered_ids[trap_id] = true
	if triggered_ids.is_empty():
		return
	var remaining: Array = []
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if triggered_ids.has(str(trap.get("id", ""))):
			continue
		remaining.append(trap)
	state["traps"] = remaining

func _apply_illusion_loss_by_key(state: Dictionary, actor_key: String, hp_loss: int) -> void:
	if actor_key.is_empty() or hp_loss <= 0:
		return
	for illusion_index: int in range((state.get("illusions", []) as Array).size()):
		var illusion: Dictionary = (state.get("illusions", []) as Array)[illusion_index]
		var key: String = "illusion_%d" % int(illusion.get("id", -1))
		if key != actor_key:
			continue
		illusion["hp"] = maxi(0, int(illusion.get("hp", 0)) - hp_loss)
		(state.get("illusions", []) as Array)[illusion_index] = illusion
		return

func _set_player_pos(state: Dictionary, pos: Vector2i) -> void:
	var player: Dictionary = state.get("player", {})
	player["pos"] = pos
	state["player"] = player

func _damaged_enemy_keys(before_state: Dictionary, after_state: Dictionary) -> Array[String]:
	var before_by_id: Dictionary = {}
	for enemy_var: Variant in before_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		before_by_id[int(enemy.get("id", -1))] = enemy
	var keys: Array[String] = []
	for enemy_var: Variant in after_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		var enemy_id: int = int(enemy.get("id", -1))
		if not before_by_id.has(enemy_id):
			continue
		var before_enemy: Dictionary = before_by_id[enemy_id]
		var hp_loss: int = int(before_enemy.get("hp", 0)) - int(enemy.get("hp", 0))
		var block_loss: int = int(before_enemy.get("block", 0)) - int(enemy.get("block", 0))
		var stoneskin_loss: int = int(before_enemy.get("stoneskin", 0)) - int(enemy.get("stoneskin", 0))
		if hp_loss > 0 or block_loss > 0 or stoneskin_loss > 0:
			keys.append(_enemy_key(enemy))
	return keys

func _defeated_enemy_units_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_by_id: Dictionary = {}
	for after_var: Variant in after_state.get("enemies", []):
		if typeof(after_var) != TYPE_DICTIONARY:
			continue
		var after_enemy: Dictionary = after_var
		after_by_id[int(after_enemy.get("id", -1))] = after_enemy
	var units: Array[Dictionary] = []
	for before_var: Variant in before_state.get("enemies", []):
		if typeof(before_var) != TYPE_DICTIONARY:
			continue
		var before_enemy: Dictionary = before_var
		var enemy_id: int = int(before_enemy.get("id", -1))
		if enemy_id < 0 or int(before_enemy.get("hp", 0)) <= 0:
			continue
		var after_enemy: Dictionary = after_by_id.get(enemy_id, {})
		if not after_enemy.is_empty() and int(after_enemy.get("hp", 0)) > 0:
			continue
		var enemy_type: String = str(before_enemy.get("type", ""))
		var definition: Dictionary = GameData.enemy_def(enemy_type)
		if definition.is_empty():
			continue
		var final_enemy: Dictionary = after_enemy if not after_enemy.is_empty() else before_enemy
		units.append({
			"key": _enemy_key(before_enemy),
			"role": "enemy",
			"id": enemy_id,
			"type": enemy_type,
			"name": str(definition.get("name", "Enemy")),
			"pos": final_enemy.get("pos", before_enemy.get("pos", Vector2i.ZERO)),
			"footprint": _enemy_footprint_for_animation(final_enemy, definition),
			"hp": maxi(1, int(before_enemy.get("hp", 1))),
			"max_hp": maxi(1, int(before_enemy.get("max_hp", before_enemy.get("hp", 1)))),
			"death_animation": true
		})
	return units

func _destroyed_terrain_units_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_by_id: Dictionary = {}
	for after_var: Variant in after_state.get("terrain", []):
		if typeof(after_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = after_var
		after_by_id[str(after_terrain.get("id", ""))] = after_terrain
	var destroyed: Array[Dictionary] = []
	for before_var: Variant in before_state.get("terrain", []):
		if typeof(before_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = before_var
		var terrain_id: String = str(before_terrain.get("id", ""))
		if terrain_id.is_empty() or int(before_terrain.get("hp", 0)) <= 0:
			continue
		var after_terrain: Dictionary = after_by_id.get(terrain_id, {})
		if not after_terrain.is_empty() and int(after_terrain.get("hp", 0)) > 0:
			continue
		var terrain_kind: String = str(before_terrain.get("kind", ""))
		if terrain_kind.is_empty():
			continue
		var final_terrain: Dictionary = after_terrain if not after_terrain.is_empty() else before_terrain
		destroyed.append({
			"key": "terrain_%s" % terrain_id,
			"id": terrain_id,
			"kind": terrain_kind,
			"pos": final_terrain.get("pos", before_terrain.get("pos", Vector2i.ZERO)),
			"destruction_frame": 0,
			"destruction_progress": 0.0
		})
	return destroyed

func _enemy_footprint_for_animation(enemy: Dictionary, definition: Dictionary) -> Vector2i:
	var footprint_value: Variant = enemy.get("footprint", Vector2i.ONE)
	if typeof(footprint_value) == TYPE_VECTOR2I:
		return footprint_value
	var definition_value: Variant = definition.get("footprint", [])
	if typeof(definition_value) == TYPE_ARRAY and (definition_value as Array).size() >= 2:
		return Vector2i(int((definition_value as Array)[0]), int((definition_value as Array)[1]))
	return Vector2i.ONE

func _clear_enemy_blocks(state: Dictionary) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		enemy["block"] = 0
		(state.get("enemies", []) as Array)[enemy_index] = enemy

func _animation_actor_unit(state: Dictionary, actor_key: String) -> Dictionary:
	if actor_key == "player":
		return (state.get("player", {}) as Dictionary).duplicate(true)
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if _enemy_key(enemy) == actor_key:
			return enemy.duplicate(true)
	for illusion_var: Variant in state.get("illusions", []):
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = illusion_var as Dictionary
		var illusion_key: String = "illusion_%d" % int(illusion.get("id", -1))
		if illusion_key == actor_key:
			return illusion.duplicate(true)
	return {"footprint": Vector2i.ONE}

func _set_action_banner(text: String) -> void:
	action_banner.visible = not text.is_empty()
	action_banner.text = text

func _board_status_label(preview: Dictionary) -> String:
	var mode: String = str(_run_state.get("mode", "room"))
	if _animation_lock:
		return ""
	if mode == "combat":
		return ""
	if mode == "room":
		return "Choose door"
	if mode == "reward":
		return "Choose reward"
	if mode == "campfire":
		return "Campfire"
	if mode == "treasure":
		return "Relic"
	if mode == "victory":
		return "Victory"
	if mode == "defeat":
		return "Defeat"
	return ""

func _board_status_detail(preview: Dictionary) -> String:
	var mode: String = str(_run_state.get("mode", "room"))
	if _animation_lock:
		return ""
	if mode == "combat":
		return ""
	if mode == "room":
		return _room_hover_hint()
	return ""

func _room_hover_hint() -> String:
	if _hovered_board_tile.x < 0 or not _exit_destinations_by_tile.has(_hovered_board_tile):
		return ""
	var destination: Vector2i = _exit_destinations_by_tile[_hovered_board_tile]
	var room: Dictionary = _run_engine.room_metadata(_run_state, destination)
	var room_element: String = str(room.get("element", ElementData.NONE))
	var prefix: String = "%s " % ElementData.name(room_element) if ElementData.is_elemental(room_element) else ""
	return "%s%s %d" % [prefix, str(room.get("type", "combat")).capitalize(), int(room.get("depth", 1))]

func _action_prompt(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"move", "blink", "illusion", "illuminate":
			return "Tile"
		"aoe":
			return "Tile" if int(action.get("range", 0)) > 0 else "Resolve"
		"melee", "ranged", "push", "pull":
			return "Target"
		_:
			return "Resolve"

func _player_action_label(card_id: String, _action: Dictionary, _state: Dictionary = _combat_state) -> String:
	return str(_card_def(card_id, _state).get("name", card_id))

func _player_action_floating_texts(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var floats: Array[Dictionary] = _player_damage_floating_texts(before_state, after_state)
	floats.append_array(_player_loss_floating_texts(before_state, after_state))
	floats.append_array(_floating_texts_for_terrain_losses(_terrain_target_losses_between(before_state, after_state)))
	return floats

func _secondary_player_action_enemy_loss_presentation(
	before_state: Dictionary,
	after_state: Dictionary,
	card_id: String,
	action: Dictionary,
	triggered_traps: Array
) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	if _player_action_enemy_losses_presented_inline(action_type, triggered_traps):
		return {}
	return _enemy_loss_feedback_presentation_between_states(
		before_state,
		after_state,
		_player_action_feedback_element(card_id, action, before_state)
	)

func _player_action_enemy_losses_presented_inline(action_type: String, triggered_traps: Array) -> bool:
	if action_type in ["melee", "ranged", "aoe", "push", "pull"]:
		return true
	return action_type in ["move", "blink"] and not triggered_traps.is_empty()

func _player_action_feedback_element(card_id: String, action: Dictionary, state: Dictionary) -> String:
	var action_element: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
	if ElementData.is_elemental(action_element):
		return action_element
	var card_element: String = str(_card_def(card_id, state).get("element", ElementData.NONE))
	return card_element if ElementData.is_elemental(card_element) else ElementData.NONE

func _enemy_loss_feedback_presentation_between_states(
	before_state: Dictionary,
	after_state: Dictionary,
	element_id: String = ElementData.NONE
) -> Dictionary:
	var floating_texts: Array[Dictionary] = _player_damage_floating_texts(before_state, after_state)
	var impact_actor_keys: Array[String] = _damaged_enemy_keys(before_state, after_state)
	if floating_texts.is_empty() or impact_actor_keys.is_empty():
		return {}
	return _attack_impact_presentation({
		"focus_actor_keys": impact_actor_keys,
		"focus_actor_color": PLAYER_ATTACK_FOCUS,
		"impact_actor_keys": impact_actor_keys,
		"effect": {
			"kind": "lightning_strikes" if element_id == ElementData.LIGHTNING else "aoe",
			"element": element_id
		},
		"floating_texts": floating_texts
	})

func _animate_enemy_loss_feedback_between_states(
	before_state: Dictionary,
	after_state: Dictionary,
	element_id: String = ElementData.NONE
) -> void:
	var presentation: Dictionary = _enemy_loss_feedback_presentation_between_states(before_state, after_state, element_id)
	if presentation.is_empty():
		return
	await _animate_floating_text_presentation(
		after_state,
		_death_hold_presentation(before_state, after_state, presentation)
	)

func _player_action_impact_actor_keys(before_state: Dictionary, after_state: Dictionary) -> Array[String]:
	var keys: Array[String] = _damaged_enemy_keys(before_state, after_state)
	if _player_took_loss(before_state, after_state):
		keys.append("player")
	return keys

func _player_took_loss(before_state: Dictionary, after_state: Dictionary) -> bool:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	if int(before_player.get("hp", 0)) > int(after_player.get("hp", 0)):
		return true
	if int(before_player.get("block", 0)) > int(after_player.get("block", 0)):
		return true
	return int(before_player.get("stoneskin", 0)) > int(after_player.get("stoneskin", 0))

func _player_loss_floating_texts(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var player_tile: Vector2i = after_player.get("pos", before_player.get("pos", Vector2i.ZERO))
	var hp_loss: int = int(before_player.get("hp", 0)) - int(after_player.get("hp", 0))
	var block_loss: int = int(before_player.get("block", 0)) - int(after_player.get("block", 0))
	var stoneskin_loss: int = int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0))
	var floats: Array[Dictionary] = []
	if hp_loss > 0:
		floats.append({
			"tile": player_tile,
			"text": "-%d" % hp_loss,
			"color": Color("f39779"),
			"offset": -10.0
		})
	if block_loss > 0:
		floats.append({
			"tile": player_tile,
			"text": "-%d B" % block_loss,
			"color": Color("90d9ff"),
			"offset": 10.0
		})
	if stoneskin_loss > 0:
		floats.append({
			"tile": player_tile,
			"text": "-%d S" % stoneskin_loss,
			"color": ElementData.accent(ElementData.EARTH),
			"offset": 22.0
		})
	return floats

func _player_damage_floating_texts(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_by_id: Dictionary = {}
	for enemy_var: Variant in before_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		before_by_id[int(enemy.get("id", -1))] = enemy
	var floats: Array[Dictionary] = []
	for enemy_var: Variant in after_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		var enemy_id: int = int(enemy.get("id", -1))
		if not before_by_id.has(enemy_id):
			continue
		var before_enemy: Dictionary = before_by_id[enemy_id]
		var hp_loss: int = int(before_enemy.get("hp", 0)) - int(enemy.get("hp", 0))
		var block_loss: int = int(before_enemy.get("block", 0)) - int(enemy.get("block", 0))
		var stoneskin_loss: int = int(before_enemy.get("stoneskin", 0)) - int(enemy.get("stoneskin", 0))
		if hp_loss > 0:
			floats.append({
				"tile": enemy.get("pos", Vector2i.ZERO),
				"text": "-%d" % hp_loss,
				"color": Color("f39779"),
				"offset": -60.0,
				"x_offset": -24.0,
				"width": 72.0
			})
		if block_loss > 0:
			floats.append({
				"tile": enemy.get("pos", Vector2i.ZERO),
				"text": "-%d B" % block_loss,
				"color": Color("90d9ff"),
				"offset": -40.0,
				"x_offset": -24.0,
				"width": 72.0
			})
		if stoneskin_loss > 0:
			floats.append({
				"tile": enemy.get("pos", Vector2i.ZERO),
				"text": "-%d S" % stoneskin_loss,
				"color": ElementData.accent(ElementData.EARTH),
				"offset": -20.0,
				"x_offset": -24.0,
				"width": 72.0
			})
	return floats

func _sync_grimoire_discoveries() -> void:
	if _run_state.is_empty():
		return
	var candidates: Array[String] = []
	_append_unique_grimoire_ids(candidates, GrimoireLibrary.entry_ids_for_run_state(_run_state))
	if not _combat_state.is_empty():
		_append_unique_grimoire_ids(candidates, GrimoireLibrary.entry_ids_for_combat_state(_combat_state))
	_unlock_grimoire_entries(candidates)

func _unlock_grimoire_entries(candidate_ids: Array) -> Array[String]:
	var result: Dictionary = GrimoireLibrary.unlock_entries(_run_state, candidate_ids)
	_run_state = result.get("state", _run_state) as Dictionary
	var added: Array[String] = GrimoireLibrary.normalize_entry_ids(result.get("added", []))
	var progression_changed: bool = bool(result.get("progression_changed", false))
	if progression_changed:
		_persist_grimoire_progression_from_run()
	if not added.is_empty():
		_refresh_grimoire_badge()
		if _grimoire_scrim != null and _grimoire_scrim.visible:
			_rebuild_grimoire_overlay()
	return added

func _append_unique_grimoire_ids(target: Array[String], source: Array) -> void:
	for entry_id_var: Variant in source:
		var entry_id: String = str(entry_id_var)
		if not entry_id.is_empty() and not target.has(entry_id):
			target.append(entry_id)

func _log_text() -> String:
	var notice: String = str(_run_state.get("notice", ""))
	var grimoire_notice: String = str(_run_state.get(GrimoireLibrary.NOTICE_KEY, ""))
	if not _combat_state.is_empty():
		var lines: Array = (_combat_state.get("log", []) as Array).duplicate()
		if not notice.is_empty():
			lines.append(notice)
		if not grimoire_notice.is_empty():
			lines.append(grimoire_notice)
		while lines.size() > 2:
			lines.remove_at(0)
		return "\n".join(lines)
	if not notice.is_empty():
		return "%s\n%s" % [notice, grimoire_notice] if not grimoire_notice.is_empty() else notice
	if not grimoire_notice.is_empty():
		return grimoire_notice
	return ""

func _show_combat_log_message(message: String) -> void:
	if log_label == null or log_overlay == null:
		return
	log_label.text = message
	log_overlay.visible = not message.is_empty()

func _pre_battle_preview_for_current_room() -> Dictionary:
	var preview_state: Dictionary = _run_engine.pre_battle_preview_state(_run_state)
	var combat_state: Dictionary = (preview_state.get("combat_state", {}) as Dictionary).duplicate(true)
	if combat_state.is_empty():
		return {}
	return preview_state

func _show_pre_battle_preview() -> bool:
	var preview_state: Dictionary = _pre_battle_preview_for_current_room()
	if preview_state.is_empty():
		return false
	_pre_battle_destination = _run_state.get("current_room", INVALID_TARGET_TILE)
	_pre_battle_door_tile = INVALID_TARGET_TILE
	_pre_battle_preview_run_state = preview_state
	var combat_state: Dictionary = preview_state.get("combat_state", {}) as Dictionary
	_unlock_grimoire_entries(GrimoireLibrary.entry_ids_for_combat_state(combat_state))
	log_label.text = _log_text()
	log_overlay.visible = not log_label.text.is_empty()
	_pre_battle_start_pending = false
	_rebuild_pre_battle_overlay()
	if _pre_battle_scrim == null:
		return false
	_pre_battle_scrim.visible = true
	_sync_pre_battle_overlay_layering()
	_animate_pre_battle_entry()
	return true

func _refresh_pre_battle_preview_if_visible() -> void:
	if _pre_battle_scrim == null or not _pre_battle_scrim.visible or _pre_battle_start_pending:
		return
	if str(_run_state.get("mode", "room")) != RunEngineScript.MODE_PRE_BATTLE:
		_close_pre_battle_preview()
		return
	var preview_state: Dictionary = _pre_battle_preview_for_current_room()
	if preview_state.is_empty():
		_close_pre_battle_preview()
		return
	_pre_battle_preview_run_state = preview_state
	_rebuild_pre_battle_overlay()

func _sync_pre_battle_preview_after_refresh() -> void:
	if _pre_battle_start_pending:
		return
	if str(_run_state.get("mode", "room")) == RunEngineScript.MODE_PRE_BATTLE:
		if _pre_battle_scrim != null and _pre_battle_scrim.visible:
			_refresh_pre_battle_preview_if_visible()
		else:
			_show_pre_battle_preview()
	elif _pre_battle_scrim != null and _pre_battle_scrim.visible:
		_close_pre_battle_preview()

func _close_pre_battle_preview() -> void:
	if _pinned_tooltip_panel != null and str(_pinned_tooltip_panel.get_meta("inspection_kind", "")) in ["enemy", "equipment", "card"]:
		_close_pinned_tooltip()
	if _pre_battle_scrim != null:
		_pre_battle_scrim.visible = false
		_pre_battle_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pre_battle_destination = INVALID_TARGET_TILE
	_pre_battle_door_tile = INVALID_TARGET_TILE
	_pre_battle_preview_run_state.clear()
	_pre_battle_start_pending = false

func _on_pre_battle_equip_pressed() -> void:
	if _pinned_tooltip_panel != null:
		_close_pinned_tooltip()
	_open_character_overlay("equipment")

func _on_pre_battle_start_pressed() -> void:
	if _pre_battle_start_pending:
		return
	if str(_run_state.get("mode", "room")) != RunEngineScript.MODE_PRE_BATTLE:
		_close_pre_battle_preview()
		return
	var previous_run_state: Dictionary = _run_state.duplicate(true)
	_pre_battle_start_pending = true
	_close_pre_battle_preview()
	_run_state = _run_engine.begin_pre_battle_combat(_run_state)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_board_presentation.clear()
	_reset_card_resolution()
	_analytics_log_combat_transition(previous_run_state, "pre_battle_start", _combat_state)
	_persist_committed_boundary("pre_battle_start")
	_pre_battle_start_pending = false
	_queue_hand_ready_wave("combat_start")
	_refresh_ui()

func _on_map_view_room_selected(coord: Vector2i, door_tile: Vector2i = INVALID_TARGET_TILE, skip_pre_battle: bool = false) -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "room":
		return
	if not _run_engine.available_moves(_run_state).has(coord):
		return
	var previous_run_state: Dictionary = _run_state.duplicate(true)
	var previous_coord: Vector2i = previous_run_state.get("current_room", Vector2i(-999, -999))
	var selected_door_tile: Vector2i = door_tile if door_tile.x >= 0 else _door_tile_for_destination(coord)
	var committed_run_state: Dictionary = _run_engine.move_to_room(_run_state, coord) if skip_pre_battle else _run_engine.move_to_pre_battle(_run_state, coord)
	committed_run_state = _hold_committed_run_state(committed_run_state, "room_move")
	var map_travel_started: bool = _begin_map_travel_animation(previous_coord, coord)
	_animation_lock = true
	_reset_card_resolution()
	_hovered_board_tile = selected_door_tile
	_refresh_ui()
	if selected_door_tile.x >= 0:
		await _play_door_opening_animation(selected_door_tile)
	elif map_travel_started:
		await get_tree().create_timer(_map_travel_animation_seconds()).timeout
	_run_state = committed_run_state
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_release_committed_run_state()
	_analytics_log_combat_transition(previous_run_state, "room_move", _combat_state)
	_persist_committed_boundary("room_move_analytics")
	_board_presentation.clear()
	_animation_lock = false
	_reset_card_resolution()
	_hovered_board_tile = Vector2i(-1, -1)
	if str(_run_state.get("mode", "room")) == "combat":
		_queue_hand_ready_wave("combat_start")
	_refresh_ui()

func _begin_map_travel_animation(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	if _reduced_motion_enabled():
		return false
	var started: bool = false
	if mini_map != null and mini_map.has_method("begin_travel_animation"):
		started = bool(mini_map.call("begin_travel_animation", from_coord, to_coord)) or started
	if _large_map_view != null and _large_map_scrim != null and _large_map_scrim.visible and _large_map_view.has_method("begin_travel_animation"):
		started = bool(_large_map_view.call("begin_travel_animation", from_coord, to_coord)) or started
	return started

func _map_travel_animation_seconds() -> float:
	if mini_map != null and mini_map.has_method("travel_animation_seconds"):
		return float(mini_map.call("travel_animation_seconds"))
	return 0.0

func _play_door_opening_animation(door_tile: Vector2i) -> void:
	if _reduced_motion_enabled():
		_board_presentation = {
			"door_opening": {
				"tile": door_tile,
				"frame": maxi(0, DOOR_OPENING_FRAMES - 1),
				"progress": 1.0
			}
		}
		_refresh_stage_view()
		await get_tree().process_frame
		return
	var frame_count: int = maxi(1, DOOR_OPENING_FRAMES)
	for frame: int in range(frame_count):
		var progress: float = 1.0 if frame_count <= 1 else float(frame) / float(frame_count - 1)
		_board_presentation = {
			"door_opening": {
				"tile": door_tile,
				"frame": frame,
				"progress": progress
			}
		}
		_refresh_stage_view()
		await get_tree().create_timer(DOOR_OPENING_FRAME_SECONDS).timeout
	await get_tree().create_timer(DOOR_OPENING_SETTLE_SECONDS).timeout

func _on_reward_card_pressed(card_id: String, source_control: Control = null) -> void:
	if _animation_lock or _loadout_acquisition_in_progress:
		return
	var reward_state: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	if not (reward_state.get("cards", []) as Array).has(card_id):
		return
	_loadout_acquisition_in_progress = true
	_animation_lock = true
	var source_rect: Rect2 = source_control.get_global_rect() if _node_is_alive(source_control) else Rect2()
	var accent: Color = ElementData.accent(GameData.card_element(card_id))
	if _node_is_alive(source_control):
		source_control.modulate = Color(1.0, 1.0, 1.0, 0.18)
	await _animate_magic_reward_acquisition_flair(card_id, source_rect, accent)
	var player_hp_before: int = int(_run_state.get("player_hp", 0))
	_run_state = _run_engine.claim_card_reward(_run_state, card_id)
	_sync_combat_state_from_run()
	_analytics_log_reward_choice("card", reward_state, card_id, player_hp_before, int(_run_state.get("player_hp", player_hp_before)))
	_persist_committed_boundary("reward_card_claimed")
	_refresh_ui()
	await _animate_loadout_acquisition_ray(source_rect.get_center(), accent)
	_animation_lock = false
	_loadout_acquisition_in_progress = false
	_refresh_ui()

func _on_skip_reward_pressed() -> void:
	if _animation_lock or _loadout_acquisition_in_progress:
		return
	var offered_cards: Array = ((_run_state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array)
	if _run_engine.has_run_skill(_run_state, "deferred_choice") and not offered_cards.is_empty():
		var options: Array = [{
			"text": "Heal without saving a card",
			"detail": "Take the healing reward and leave every offered card behind.",
			"callback": _commit_reward_heal.bind("")
		}]
		for card_id_var: Variant in offered_cards:
			var card_id: String = str(card_id_var)
			var card: Dictionary = GameData.card_def(card_id)
			options.append({
				"text": "Heal & save %s" % str(card.get("name", card_id)),
				"detail": "This card will replace one choice in your next combat reward.",
				"callback": _commit_reward_heal.bind(card_id)
			})
		_open_skill_choice_dialog(
			SkillTreeLibrary.display_name("deferred_choice"),
			"Choose whether one offered card should follow you to the next reward.",
			options
		)
		return
	_commit_reward_heal("")

func _commit_reward_heal(deferred_card_id: String) -> void:
	if str(_run_state.get("mode", "room")) != "reward":
		return
	var reward_state: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	var player_hp_before: int = int(_run_state.get("player_hp", 0))
	_run_state = _run_engine.skip_reward_for_heal(_run_state, deferred_card_id)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_analytics_log_reward_choice("heal_skip", reward_state, "", player_hp_before, int(_run_state.get("player_hp", player_hp_before)))
	_persist_committed_boundary("reward_heal_claimed")
	_refresh_ui()

func _on_reward_reroll_pressed() -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "reward":
		return
	var before_state: Dictionary = _run_state.duplicate(true)
	_run_state = _run_engine.reroll_card_reward(_run_state)
	if _run_state == before_state:
		return
	_persist_committed_boundary("reward_rerolled")
	_refresh_ui()

func _on_campfire_sit_pressed() -> void:
	_on_campfire_embrace_pressed()

func _on_campfire_embrace_pressed() -> void:
	_sync_progression_from_run()
	var held: int = _run_engine.held_embers(_run_state)
	var committed_progression: Dictionary = ProgressionStore.set_embers(_progression, held)
	committed_progression = ProgressionStore.mark_rested_at_fire(committed_progression)
	if not ProgressionStore.save_data(committed_progression):
		push_error("Failed to persist campfire Embrace; the run remains resumable.")
		return
	_progression = committed_progression
	ProgressionStore.clear_saved_run()
	_change_scene_to_file("res://scenes/main_menu.tscn")

func _on_campfire_linger_pressed() -> void:
	_run_state = _run_engine.leave_campfire(_run_state, CAMPFIRE_LINGER_HEAL_AMOUNT)
	_persist_committed_boundary("campfire_linger")
	_refresh_ui()

func _on_campfire_leave_pressed() -> void:
	_run_state = _run_engine.leave_campfire(_run_state)
	_persist_committed_boundary("campfire_leave")
	_refresh_ui()

func _on_relic_pressed(relic_id: String, source_rect: Rect2 = Rect2()) -> void:
	if _relic_claim_in_progress:
		return
	var pending_relics: Array = (_run_state.get("pending_relics", []) as Array).duplicate()
	if not pending_relics.has(relic_id):
		return
	if _run_engine.has_run_skill(_run_state, "curators_patience") and pending_relics.size() > 1:
		var options: Array = [{
			"text": "Choose without saving another relic",
			"detail": "Take this relic and leave the remaining choices behind.",
			"callback": _claim_relic_with_deferred.bind(relic_id, "", source_rect)
		}]
		for deferred_id_var: Variant in pending_relics:
			var deferred_id: String = str(deferred_id_var)
			if deferred_id == relic_id or (_run_state.get("relics", []) as Array).has(deferred_id):
				continue
			var deferred_relic: Dictionary = GameData.relic_def(deferred_id)
			options.append({
				"text": "Save %s" % str(deferred_relic.get("name", deferred_id)),
				"detail": "This relic will replace one choice in your next relic offer.",
				"callback": _claim_relic_with_deferred.bind(relic_id, deferred_id, source_rect)
			})
		_open_skill_choice_dialog(
			SkillTreeLibrary.display_name("curators_patience"),
			"After taking %s, choose one unclaimed relic to carry forward." % str(GameData.relic_def(relic_id).get("name", relic_id)),
			options
		)
		return
	await _claim_relic_with_deferred(relic_id, "", source_rect)

func _claim_relic_with_deferred(relic_id: String, deferred_relic_id: String, source_rect: Rect2) -> void:
	if _relic_claim_in_progress:
		return
	var pending_relics: Array = (_run_state.get("pending_relics", []) as Array).duplicate()
	if not pending_relics.has(relic_id):
		return
	_relic_claim_in_progress = true
	var accent := Color(GameData.relic_accent(relic_id))
	_run_state = _run_engine.claim_relic(_run_state, relic_id, deferred_relic_id)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_persist_committed_boundary("relic_claimed")
	_refresh_ui()
	await _animate_relic_acquisition_flourish(relic_id, source_rect, accent)
	await _animate_relic_acquired(relic_id)
	_relic_claim_in_progress = false

func _on_merchant_buy_pressed(merchant_kind: String, item_id: String, source_row: Control = null) -> void:
	if _merchant_trade_animation_active:
		return
	var before_embers: int = _run_engine.held_embers(_run_state)
	var before_state: Dictionary = _run_state.duplicate(true)
	var amount: int = _run_engine.merchant_buy_cost(merchant_kind, item_id)
	_close_pinned_tooltip()
	_run_state = _run_engine.buy_merchant_item(_run_state, merchant_kind, item_id)
	if _run_state == before_state:
		return
	_merchant_trade_animation_active = true
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	var after_embers: int = _run_engine.held_embers(_run_state)
	if after_embers == before_embers:
		_refresh_ui()
		_merchant_trade_animation_active = false
		return
	_persist_committed_boundary("merchant_buy")
	_analytics_log_merchant_trade("buy", merchant_kind, item_id, amount, before_embers, after_embers)
	await _animate_merchant_trade_row(source_row, merchant_kind, item_id, true)
	_refresh_ui()
	_merchant_trade_animation_active = false

func _on_merchant_sell_pressed(merchant_kind: String, item_id: String, source_row: Control = null) -> void:
	if _merchant_trade_animation_active:
		return
	var before_embers: int = _run_engine.held_embers(_run_state)
	var before_state: Dictionary = _run_state.duplicate(true)
	var amount: int = _run_engine.merchant_sell_value(merchant_kind, item_id)
	_close_pinned_tooltip()
	_run_state = _run_engine.sell_merchant_item(_run_state, merchant_kind, item_id)
	if _run_state == before_state:
		return
	_merchant_trade_animation_active = true
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	var after_embers: int = _run_engine.held_embers(_run_state)
	if after_embers == before_embers:
		_refresh_ui()
		_merchant_trade_animation_active = false
		return
	_persist_committed_boundary("merchant_sell")
	_analytics_log_merchant_trade("sell", merchant_kind, item_id, amount, before_embers, after_embers)
	await _animate_merchant_trade_row(source_row, merchant_kind, item_id, false)
	_refresh_ui()
	_merchant_trade_animation_active = false

func _animate_merchant_trade_row(source_row: Control, merchant_kind: String, item_id: String, buying: bool) -> void:
	if not _node_is_alive(source_row):
		return
	var row: Control = source_row
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.pivot_offset = row.size * 0.5
	var start_position: Vector2 = row.position
	var accent: Color = _merchant_item_accent(merchant_kind, item_id)
	var flash_color := Color(
		clampf(accent.r * 1.35 + 0.18, 0.0, 1.0),
		clampf(accent.g * 1.35 + 0.18, 0.0, 1.0),
		clampf(accent.b * 1.35 + 0.18, 0.0, 1.0),
		1.0
	)
	var tween: Tween = create_tween()
	tween.tween_property(row, "modulate", flash_color, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(row, "scale", Vector2(1.025, 1.025), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(row, "modulate", Color(1.0, 1.0, 1.0, 0.16), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(row, "scale", Vector2(0.985, 0.985), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(row, "position", start_position + Vector2(10.0 if buying else -10.0, 0.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

func _animate_magic_reward_acquisition_flair(card_id: String, source_rect: Rect2, accent: Color) -> void:
	if _card_fx_layer == null or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var center: Vector2 = source_rect.get_center()
	var burst: LoadoutAcquisitionBurst = _spawn_loadout_acquisition_burst(center, accent, "magic")
	var banner: Label = _spawn_loadout_acquisition_banner("SPELL LEARNED", center + Vector2(0.0, -source_rect.size.y * 0.58), accent)
	var proxy: Control = _spawn_card_proxy(card_id, source_rect)
	proxy.z_index = 1602
	proxy.pivot_offset = proxy.size * 0.5
	var base_scale: Vector2 = proxy.scale
	proxy.rotation = -0.055
	var burst_tween: Tween = create_tween()
	burst_tween.tween_property(burst, "progress", 1.0, LOADOUT_ACQUISITION_FLAIR_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var banner_tween: Tween = create_tween()
	banner.modulate.a = 0.0
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.10)
	banner_tween.tween_interval(0.22)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.14)
	var tween: Tween = create_tween()
	tween.tween_property(proxy, "scale", base_scale * 1.20, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(proxy, "rotation", 0.035, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(proxy, "modulate", Color(1.20, 1.16, 0.96, 1.0), 0.10)
	tween.tween_property(proxy, "scale", base_scale * 1.03, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(proxy, "rotation", 0.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(proxy, "position", proxy.position + Vector2(0.0, -28.0), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(proxy, "modulate", Color.WHITE, 0.20)
	await tween.finished
	_release_card_proxy(proxy)
	_queue_free_node_now(burst)
	_queue_free_node_now(banner)

func _animate_equipment_pickup_acquisition_flair(equipment_id: String, tile: Vector2i) -> void:
	if _card_fx_layer == null or equipment_id.is_empty():
		return
	var equipment: Dictionary = GameData.equipment_def(equipment_id)
	if equipment.is_empty():
		return
	var center: Vector2 = _board_global_position_for_tile(tile)
	var accent := Color(GameData.equipment_accent(equipment_id))
	var burst: LoadoutAcquisitionBurst = _spawn_loadout_acquisition_burst(center, accent, "equipment")
	var banner: Label = _spawn_loadout_acquisition_banner("GEAR FOUND", center + Vector2(0.0, -92.0), accent)
	var icon := TextureRect.new()
	icon.name = "EquipmentAcquisitionIcon"
	icon.texture = AssetLoader.load_texture(str(equipment.get("icon_path", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(112.0, 112.0)
	icon.position = center - icon.size * 0.5
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2.ONE * 0.36
	icon.rotation = -0.20
	icon.modulate = Color(1.18, 1.10, 0.82, 0.0)
	icon.z_index = 1602
	_card_fx_layer.add_child(icon)
	var burst_tween: Tween = create_tween()
	burst_tween.tween_property(burst, "progress", 1.0, LOADOUT_ACQUISITION_FLAIR_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var banner_tween: Tween = create_tween()
	banner.modulate.a = 0.0
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.08)
	banner_tween.tween_interval(0.24)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.14)
	var tween: Tween = create_tween()
	tween.tween_property(icon, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_property(icon, "scale", Vector2.ONE * 1.24, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "rotation", 0.045, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE * 0.94, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(icon, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(icon, "position", icon.position + Vector2(0.0, -18.0), 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	await _animate_loadout_acquisition_ray(center, accent)
	_queue_free_node_now(icon)
	_queue_free_node_now(burst)
	_queue_free_node_now(banner)

func _spawn_loadout_acquisition_burst(center: Vector2, accent: Color, kind: String) -> LoadoutAcquisitionBurst:
	var burst := LoadoutAcquisitionBurst.new()
	burst.name = "LoadoutAcquisitionBurst"
	burst.size = Vector2(220.0, 220.0)
	burst.position = center - burst.size * 0.5
	burst.accent = accent
	burst.kind = kind
	burst.z_index = 1600
	_card_fx_layer.add_child(burst)
	return burst

func _spawn_loadout_acquisition_banner(text: String, center: Vector2, accent: Color) -> Label:
	var banner := Label.new()
	banner.name = "LoadoutAcquisitionBanner"
	banner.text = text
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.position = center - Vector2(170.0, 24.0)
	banner.size = Vector2(340.0, 48.0)
	UiTypography.apply_label_role(banner, UiTypography.ROLE_TITLE)
	banner.add_theme_color_override("font_color", Color("fff2c7").lerp(accent.lightened(0.32), 0.34))
	banner.add_theme_color_override("font_outline_color", Color("1b0f0a"))
	banner.add_theme_constant_override("outline_size", 7)
	banner.z_index = 1603
	_card_fx_layer.add_child(banner)
	return banner

func _animate_loadout_acquisition_ray(source_global: Vector2, accent: Color) -> void:
	if _card_fx_layer == null or loadout_button == null:
		return
	await get_tree().process_frame
	if not _node_is_alive(_card_fx_layer) or not _node_is_alive(loadout_button):
		return
	var target_global: Vector2 = loadout_button.get_global_rect().get_center()
	var local_start: Vector2 = source_global - _card_fx_layer.global_position
	var local_target: Vector2 = target_global - _card_fx_layer.global_position
	var beam := RelicAcquisitionBeam.new()
	beam.name = "LoadoutAcquisitionBeam"
	beam.texture = AssetLoader.load_texture(RELIC_ACQUISITION_BEAM_PATH)
	beam.accent = accent
	beam.start = local_start
	beam.target = local_target
	beam.modulate = Color(1.0, 1.0, 1.0, 0.76)
	beam.z_index = 1600
	_card_fx_layer.add_child(beam)
	var beam_tween: Tween = create_tween().set_parallel(true)
	beam_tween.tween_property(beam, "progress", 1.0, LOADOUT_ACQUISITION_RAY_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	beam_tween.tween_property(beam, "modulate:a", 0.0, 0.16).set_delay(LOADOUT_ACQUISITION_RAY_SECONDS * 0.72)
	for mote_index: int in range(LOADOUT_ACQUISITION_MOTES):
		_spawn_loadout_acquisition_mote(local_start, local_target, accent, mote_index)
	await get_tree().create_timer(LOADOUT_ACQUISITION_RAY_SECONDS + 0.04).timeout
	_queue_free_node_now(beam)
	await _animate_loadout_button_arrival(accent)

func _spawn_loadout_acquisition_mote(local_start: Vector2, local_target: Vector2, accent: Color, mote_index: int) -> void:
	if _card_fx_layer == null:
		return
	var mote := RelicAcquisitionMote.new()
	mote.name = "LoadoutAcquisitionMote"
	mote.texture = AssetLoader.load_texture(RELIC_ACQUISITION_MOTE_PATH)
	mote.accent = accent
	var mote_size: float = 17.0 + float(mote_index % 4) * 2.5
	mote.size = Vector2(mote_size, mote_size)
	mote.pivot_offset = mote.size * 0.5
	var start_angle: float = -0.95 + 1.9 * (float(mote_index) / float(maxi(1, LOADOUT_ACQUISITION_MOTES - 1)))
	var start_spread: Vector2 = Vector2(cos(start_angle), sin(start_angle)) * (12.0 + float((mote_index * 7) % 16))
	var end_jitter := Vector2(float((mote_index % 5) - 2) * 3.5, float((mote_index % 3) - 1) * 3.0)
	mote.position = local_start + start_spread - mote.size * 0.5
	mote.scale = Vector2.ONE * (0.78 + float(mote_index % 3) * 0.07)
	mote.modulate = Color(1.0, 1.0, 1.0, 0.0)
	mote.z_index = 1601
	_card_fx_layer.add_child(mote)
	var delay: float = float(mote_index) * 0.015
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(mote, "position", local_target + end_jitter - mote.size * 0.5, LOADOUT_ACQUISITION_RAY_SECONDS * 0.88).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mote, "scale", Vector2.ONE * 0.28, LOADOUT_ACQUISITION_RAY_SECONDS * 0.88).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(mote, "modulate:a", 1.0, 0.05).set_delay(delay)
	tween.tween_property(mote, "modulate:a", 0.0, 0.12).set_delay(delay + LOADOUT_ACQUISITION_RAY_SECONDS * 0.66)
	tween.finished.connect(_queue_free_node_now.bind(mote))

func _animate_loadout_button_arrival(accent: Color) -> void:
	if loadout_button == null:
		return
	loadout_button.pivot_offset = loadout_button.size * 0.5
	loadout_button.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(accent.lightened(0.35), 0.34)
	var tween := create_tween()
	tween.set_loops(2)
	tween.tween_property(loadout_button, "scale", Vector2(1.16, 1.16), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(loadout_button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	loadout_button.scale = Vector2.ONE
	loadout_button.modulate = Color.WHITE

func _animate_relic_acquisition_flourish(relic_id: String, source_rect: Rect2, accent: Color) -> void:
	if _card_fx_layer == null:
		return
	await get_tree().process_frame
	if not _node_is_alive(_card_fx_layer):
		return
	var frame: Control = _relic_frame_for_id(relic_id)
	var target: Vector2 = _relic_bar_target_global_position(frame)
	var source: Vector2 = _relic_acquisition_source_global_position(source_rect)
	var local_start: Vector2 = source - _card_fx_layer.global_position
	var local_target: Vector2 = target - _card_fx_layer.global_position
	var beam := RelicAcquisitionBeam.new()
	beam.name = "RelicAcquisitionBeam"
	beam.texture = AssetLoader.load_texture(RELIC_ACQUISITION_BEAM_PATH)
	beam.accent = accent
	beam.start = local_start
	beam.target = local_target
	beam.modulate = Color(1.0, 1.0, 1.0, 0.70)
	beam.z_index = 1600
	_card_fx_layer.add_child(beam)
	var beam_tween: Tween = create_tween().set_parallel(true)
	beam_tween.tween_property(beam, "progress", 1.0, RELIC_ACQUISITION_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	beam_tween.tween_property(beam, "modulate:a", 0.0, 0.16).set_delay(RELIC_ACQUISITION_SECONDS * 0.72)
	for mote_index: int in range(RELIC_ACQUISITION_MOTES):
		_spawn_relic_acquisition_mote(local_start, local_target, accent, mote_index)
	await get_tree().create_timer(RELIC_ACQUISITION_SECONDS + 0.04).timeout
	_queue_free_node_now(beam)

func _spawn_relic_acquisition_mote(local_start: Vector2, local_target: Vector2, accent: Color, mote_index: int) -> void:
	if _card_fx_layer == null:
		return
	var mote := RelicAcquisitionMote.new()
	mote.name = "RelicAcquisitionMote"
	mote.texture = AssetLoader.load_texture(RELIC_ACQUISITION_MOTE_PATH)
	mote.accent = accent
	var mote_size: float = 18.0 + float(mote_index % 3) * 3.0
	mote.size = Vector2(mote_size, mote_size)
	mote.pivot_offset = mote.size * 0.5
	var start_angle: float = -0.85 + 1.7 * (float(mote_index) / float(maxi(1, RELIC_ACQUISITION_MOTES - 1)))
	var start_spread: Vector2 = Vector2(cos(start_angle), sin(start_angle)) * (10.0 + float((mote_index * 7) % 13))
	var end_jitter := Vector2(float((mote_index % 5) - 2) * 4.0, float((mote_index % 3) - 1) * 3.0)
	mote.position = local_start + start_spread - mote.size * 0.5
	mote.scale = Vector2.ONE * (0.74 + float(mote_index % 4) * 0.06)
	mote.modulate = Color(1.0, 1.0, 1.0, 0.0)
	mote.z_index = 1601
	_card_fx_layer.add_child(mote)
	var delay: float = float(mote_index) * 0.018
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(mote, "position", local_target + end_jitter - mote.size * 0.5, RELIC_ACQUISITION_SECONDS * 0.84).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mote, "scale", Vector2.ONE * 0.32, RELIC_ACQUISITION_SECONDS * 0.84).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(mote, "modulate:a", 1.0, 0.06).set_delay(delay)
	tween.tween_property(mote, "modulate:a", 0.0, 0.12).set_delay(delay + RELIC_ACQUISITION_SECONDS * 0.62)
	tween.finished.connect(_queue_free_node_now.bind(mote))

func _relic_acquisition_source_global_position(source_rect: Rect2) -> Vector2:
	if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
		return source_rect.get_center()
	return _board_global_position_for_tile(Vector2i(4, 4))

func _relic_bar_target_global_position(frame: Control) -> Vector2:
	if frame != null:
		return frame.get_global_rect().get_center()
	if relic_bar != null and relic_bar.visible:
		return relic_bar.get_global_rect().get_center()
	return room_title.get_global_rect().get_center()

func _animate_relic_acquired(relic_id: String) -> void:
	await get_tree().process_frame
	var frame: Control = _relic_frame_for_id(relic_id)
	if frame == null:
		return
	frame.pivot_offset = frame.size * 0.5
	frame.scale = Vector2(0.86, 0.86)
	frame.modulate = Color(1.0, 0.92, 0.62, 1.0)
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(frame, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(frame, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(frame, "scale", Vector2.ONE, 0.10)
	settle.tween_property(frame, "modulate", Color.WHITE, 0.10)
	await settle.finished

func _relic_frame_for_id(relic_id: String) -> Control:
	if relic_bar == null:
		return null
	for child: Node in relic_bar.get_children():
		if child is Control and str(child.get_meta("relic_id", "")) == relic_id:
			return child as Control
	return null

func _on_back_to_menu_pressed() -> void:
	if not _is_debug_boss_run():
		ProgressionStore.clear_saved_run()
	_change_scene_to_file("res://scenes/main_menu.tscn")

func _on_restart_pressed() -> void:
	if _is_debug_boss_run():
		_start_debug_boss_run()
		return
	ProgressionStore.clear_saved_run()
	_start_run()

func _on_menu_button_pressed() -> void:
	if _dialogue_active or _animation_lock or _pending_umbra_commit_locked:
		return
	_open_menu_overlay()

func _on_grimoire_button_pressed() -> void:
	if _dialogue_active or _animation_lock:
		return
	_open_grimoire_overlay()

func _on_loadout_button_pressed() -> void:
	if _dialogue_active or _animation_lock or _pending_umbra_commit_locked:
		return
	var mode: String = "equipment"
	if _run_engine.loadout_unread_ids(_run_state, "equipment").is_empty() and not _run_engine.loadout_unread_ids(_run_state, "magic").is_empty():
		mode = "magic"
	_open_character_overlay(mode)

func _on_pass_turn_pressed() -> void:
	if _animation_lock or _pending_umbra_commit_locked or str(_run_state.get("mode", "room")) != "combat":
		return
	if not _combat_engine.is_player_turn(_combat_state):
		return
	_complete_active_contextual_combat_prompt(ContextualCombatTutorial.PASS_CONSEQUENCE)
	if _selected_card_index >= 0:
		_cancel_card_selection()
	await _resolve_enemy_round()

func _open_menu_overlay() -> void:
	if _menu_scrim == null:
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_card_upgrade_overlay()
	_close_grimoire_overlay()
	if _settings_panel != null:
		_settings_panel.visible = false
	if _menu_dialog != null:
		_menu_dialog.visible = true
	_menu_scrim.visible = true

func _close_menu_overlay() -> void:
	if _menu_scrim != null:
		_menu_scrim.visible = false
	if _settings_panel != null:
		_settings_panel.visible = false
	if _menu_dialog != null:
		_menu_dialog.visible = true

func _open_settings_overlay() -> void:
	if _menu_scrim == null or _settings_panel == null:
		return
	_menu_dialog.visible = false
	if _settings_panel.has_method("open"):
		_settings_panel.call("open")
	else:
		_settings_panel.visible = true
	_settings_panel.move_to_front()

func _close_settings_overlay() -> void:
	if _settings_panel != null:
		_settings_panel.visible = false
	if _menu_dialog != null:
		_menu_dialog.visible = true

func _on_settings_changed(settings: Dictionary) -> void:
	_settings = SettingsStore.normalize_settings(settings)
	if _run_end_recap != null:
		_run_end_recap.set_motion_enabled(not _reduced_motion_enabled())

func _reduced_motion_enabled() -> bool:
	return SettingsStore.reduced_motion_enabled(_settings)

func _open_grimoire_overlay() -> void:
	if _grimoire_scrim == null:
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_card_upgrade_overlay()
	_close_large_map()
	_close_menu_overlay()
	_select_first_unread_grimoire_entry()
	_rebuild_grimoire_overlay(true)
	_grimoire_scrim.visible = true
	_grimoire_scrim.move_to_front()
	_refresh_grimoire_badge()
	log_label.text = _log_text()
	log_overlay.visible = not log_label.text.is_empty()

func _close_grimoire_overlay() -> void:
	var was_visible: bool = _grimoire_scrim != null and _grimoire_scrim.visible
	if _grimoire_scrim != null:
		_grimoire_scrim.visible = false
	if not was_visible:
		return
	_run_state = GrimoireLibrary.clear_unread(_run_state)
	_persist_grimoire_progression_from_run()
	_refresh_grimoire_badge()
	log_label.text = _log_text()
	log_overlay.visible = not log_label.text.is_empty()

func _committed_run_state() -> Dictionary:
	if not _committed_run_state_override.is_empty():
		return _committed_run_state_override.duplicate(true)
	var state: Dictionary = _run_state.duplicate(true)
	if str(state.get("mode", "")) == "combat":
		state = _run_engine.set_combat_state(state, _combat_state)
	return state

func _run_state_for_combat_checkpoint(base_run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var base_state: Dictionary = base_run_state.duplicate(true)
	var checkpoint_combat_state: Dictionary = combat_state.duplicate(true)
	base_state.erase(COMBAT_CONTINUATION_KEY)
	var staged_result: Dictionary = _stage_combat_skill_event_analytics_for_state(base_state, checkpoint_combat_state)
	base_state = staged_result.get("run_state", base_state) as Dictionary
	checkpoint_combat_state = staged_result.get("combat_state", checkpoint_combat_state) as Dictionary
	if _combat_engine.combat_outcome(checkpoint_combat_state).is_empty():
		return _run_engine.set_combat_state(base_state, checkpoint_combat_state)
	var finished_state: Dictionary = _run_engine.finish_combat(base_state, checkpoint_combat_state)
	var finished_progression: Dictionary = (finished_state.get("progression", {}) as Dictionary).duplicate(true)
	if (
		not bool(base_state.get("debug_boss_run", false))
		and int(finished_progression.get("progression_revision", 0)) > int(_progression.get("progression_revision", 0))
	):
		var moltshards_before: int = ProgressionStore.moltshard_count(_progression)
		var moltshards_after: int = ProgressionStore.moltshard_count(finished_progression)
		if moltshards_after > moltshards_before:
			var award_id: String = "%s:first_boss_moltshard" % RunEngineScript.run_result_id(finished_state)
			var payload: Dictionary = {
				"amount": moltshards_after - moltshards_before,
				"source": "first_boss_victory",
				"moltshards_before": moltshards_before,
				"moltshards_after": moltshards_after
			}
			finished_progression = ProgressionStore.queue_progression_analytics_event(
				finished_progression,
				MOLTSHARD_GAIN_EVENT_TYPE,
				_moltshard_gain_idempotency_key(award_id),
				_analytics_context_from_states(finished_state, checkpoint_combat_state),
				payload
			)
		_progression = ProgressionStore.normalized_data(finished_progression)
		finished_state["progression"] = _progression.duplicate(true)
		if not ProgressionStore.save_data(_authoritative_profile_progression()):
			push_error("Failed to persist Moltshard award analytics outbox.")
		finished_state["progression"] = _progression.duplicate(true)
	finished_progression = ProgressionStore.merge_progression_analytics_outbox(
		finished_state.get("progression", {}) as Dictionary,
		_progression
	)
	finished_state["progression"] = finished_progression
	return finished_state

func _combat_commit_checkpoints(steps: Array) -> Array:
	var checkpoints: Array = []
	for step_var: Variant in steps:
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		if str(step.get("kind", "")) != "commit":
			continue
		var combat_state: Dictionary = (step.get("state", {}) as Dictionary).duplicate(true)
		if combat_state.is_empty():
			continue
		checkpoints.append({
			"boundary": str(step.get("boundary", "enemy_checkpoint")),
			"state": combat_state
		})
	return checkpoints

func _remaining_combat_checkpoints(checkpoints: Array, start_index: int) -> Array:
	var remaining: Array = []
	for index: int in range(maxi(0, start_index), checkpoints.size()):
		if typeof(checkpoints[index]) == TYPE_DICTIONARY:
			remaining.append((checkpoints[index] as Dictionary).duplicate(true))
	return remaining

func _run_state_with_combat_checkpoints(run_state: Dictionary, checkpoints: Array) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	state.erase(COMBAT_CONTINUATION_KEY)
	if not checkpoints.is_empty() and str(state.get("mode", "")) == "combat":
		state[COMBAT_CONTINUATION_KEY] = checkpoints.duplicate(true)
	return state

func _pending_combat_checkpoints() -> Array:
	var stored: Variant = _run_state.get(COMBAT_CONTINUATION_KEY, [])
	if typeof(stored) != TYPE_ARRAY:
		return []
	var checkpoints: Array = []
	var stored_array: Array = stored as Array
	for checkpoint_var: Variant in stored_array:
		if typeof(checkpoint_var) != TYPE_DICTIONARY:
			continue
		var checkpoint: Dictionary = checkpoint_var as Dictionary
		if typeof(checkpoint.get("state", null)) != TYPE_DICTIONARY:
			continue
		checkpoints.append(checkpoint.duplicate(true))
	return checkpoints

func _has_pending_combat_checkpoints() -> bool:
	return str(_run_state.get("mode", "")) == "combat" and not _pending_combat_checkpoints().is_empty()

func _repair_legacy_empty_actor_transition() -> bool:
	if str(_run_state.get("mode", "")) != "combat" or _has_pending_combat_checkpoints():
		return false
	if not _combat_state.has("current_actor"):
		return false
	var current_actor: Variant = _combat_state.get("current_actor", null)
	if typeof(current_actor) != TYPE_DICTIONARY or not (current_actor as Dictionary).is_empty():
		return false
	var turn_queue: Variant = _combat_state.get("turn_queue", [])
	if typeof(turn_queue) != TYPE_ARRAY or (turn_queue as Array).is_empty() or _combat_engine.combat_outcome(_combat_state) != "":
		return false
	var scheduled_state: Dictionary = _combat_state.duplicate(true)
	scheduled_state["current_actor"] = {"kind": "transition"}
	var phase_result: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(scheduled_state)
	var checkpoints: Array = _combat_commit_checkpoints(phase_result.get("steps", []))
	if checkpoints.is_empty():
		return false
	_run_state = _run_state_with_combat_checkpoints(
		_run_state_for_combat_checkpoint(_run_state, scheduled_state),
		checkpoints
	)
	_combat_state = scheduled_state
	_mark_combat_preview_state_changed()
	_persist_committed_boundary("legacy_empty_actor_transition_repaired")
	return true

func _consume_next_pending_combat_checkpoint() -> bool:
	if not _has_pending_combat_checkpoints():
		return false
	var checkpoints: Array = _pending_combat_checkpoints()
	var checkpoint: Dictionary = checkpoints[0] as Dictionary
	var combat_state: Dictionary = (checkpoint.get("state", {}) as Dictionary).duplicate(true)
	if combat_state.is_empty():
		_run_state = _run_state_with_combat_checkpoints(_run_state, _remaining_combat_checkpoints(checkpoints, 1))
		return true
	var next_run_state: Dictionary = _run_state_with_combat_checkpoints(
		_run_state_for_combat_checkpoint(_run_state, combat_state),
		_remaining_combat_checkpoints(checkpoints, 1)
	)
	next_run_state = _hold_committed_run_state(next_run_state, str(checkpoint.get("boundary", "resumed_enemy_checkpoint")))
	_run_state = next_run_state
	_sync_combat_state_from_run()
	return true

func _resume_pending_combat_checkpoints() -> void:
	if not _has_pending_combat_checkpoints() or _animation_lock:
		return
	_animation_lock = true
	while _consume_next_pending_combat_checkpoint():
		if str(_run_state.get("mode", "")) != "combat":
			break
	_release_committed_run_state()
	_board_presentation.clear()
	_set_action_banner("")
	_animation_lock = false
	_refresh_ui()

func _persist_committed_boundary(boundary: String = "") -> bool:
	return bool(_persist_run_state_snapshot(_committed_run_state(), false, boundary).get("saved", false))

func _hold_committed_run_state(run_state: Dictionary, boundary: String = "") -> Dictionary:
	return (_persist_run_state_snapshot(run_state, true, boundary).get("state", run_state) as Dictionary).duplicate(true)

func _release_committed_run_state() -> void:
	_committed_run_state_override.clear()

func _persist_run_state_snapshot(run_state: Dictionary, hold_for_animation: bool, boundary: String) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	if state.is_empty() or bool(state.get("debug_boss_run", false)):
		return {"state": state, "saved": false}
	if _save_in_progress:
		return {"state": state, "saved": false}
	_save_in_progress = true
	var mode: String = str(state.get("mode", ""))
	var saved: bool = false
	if mode in ["victory", "defeat"]:
		var terminal_resume_state: Dictionary = state.duplicate(true)
		state = _finalize_terminal_committed_state(state)
		saved = ProgressionStore.save_data(_progression)
		if saved:
			ProgressionStore.clear_saved_run()
		else:
			ProgressionStore.save_run_state(terminal_resume_state)
	else:
		saved = ProgressionStore.save_run_state(state)
	if hold_for_animation:
		_committed_run_state_override = state.duplicate(true)
	_save_in_progress = false
	if not saved:
		push_error("Failed to persist committed run boundary: %s" % (boundary if not boundary.is_empty() else "unspecified"))
	return {"state": state, "saved": saved}

func _finalize_terminal_committed_state(run_state: Dictionary) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	var mode: String = str(state.get("mode", ""))
	if mode in ["victory", "defeat"]:
		state = _terminal_state_with_recorded_run_result(state, _progression)
		_progression = (state.get("progression", _progression) as Dictionary).duplicate(true)
	if mode == "victory":
		if not _victory_carry_processed:
			var victory_amount: int = _run_engine.held_embers(state)
			_victory_carry_amount = victory_amount
			_progression = ProgressionStore.set_embers(_progression, victory_amount)
			_victory_carry_processed = true
		state = _run_engine.clear_held_embers(state)
		state["progression"] = _progression.duplicate(true)
	elif mode == "defeat":
		if not _defeat_loss_processed:
			var lost_amount: int = _run_engine.held_embers(state)
			_defeat_lost_amount = lost_amount
			_progression = ProgressionStore.record_lost_embers(
				_progression,
				lost_amount,
				state.get("current_room", Vector2i.ZERO),
				int(state.get("run_index", 0))
			)
			_defeat_loss_processed = true
		state = _run_engine.clear_held_embers(state)
		state["progression"] = _progression.duplicate(true)
	return state

func _is_debug_boss_run() -> bool:
	return bool(_run_state.get("debug_boss_run", false))

func _save_run_progress() -> void:
	if _is_debug_boss_run():
		return
	var committed_state: Dictionary = _committed_run_state()
	var mode: String = str(committed_state.get("mode", ""))
	if mode in ["victory", "defeat"] or committed_state.is_empty():
		if ProgressionStore.save_data(_progression):
			ProgressionStore.clear_saved_run()
		else:
			push_error("Failed to persist terminal progression; the resumable fallback remains intact.")
		return
	var saved_progression: Dictionary = _progression.duplicate(true)
	var run_progression: Dictionary = (committed_state.get("progression", {}) as Dictionary).duplicate(true)
	if not run_progression.is_empty():
		saved_progression["embers"] = int(run_progression.get("embers", 0))
	ProgressionStore.save_data(saved_progression)
	_persist_committed_boundary("explicit_save")

func _on_save_and_quit_pressed() -> void:
	_close_menu_overlay()
	_save_run_progress()
	_change_scene_to_file("res://scenes/main_menu.tscn")

func _on_exit_to_desktop_pressed() -> void:
	_close_menu_overlay()
	_save_run_progress()
	get_tree().quit()

func _on_abandon_run_pressed() -> void:
	_close_menu_overlay()
	_reset_card_resolution()
	_analytics_log_run_ended("abandoned")
	if not _is_debug_boss_run():
		_sync_progression_from_run()
		_progression = ProgressionStore.record_lost_embers(
			_progression,
			_run_engine.held_embers(_run_state),
			_run_state.get("current_room", Vector2i.ZERO),
			int(_run_state.get("run_index", 0))
		)
		ProgressionStore.save_data(_progression)
		ProgressionStore.clear_saved_run()
	_change_scene_to_file("res://scenes/main_menu.tscn")

func _change_scene_to_file(path: String) -> void:
	var cursor_feedback: Node = get_node_or_null("/root/CursorFeedback")
	if cursor_feedback != null and cursor_feedback.has_method("change_scene_to_file"):
		cursor_feedback.call("change_scene_to_file", path)
		return
	get_tree().change_scene_to_file(path)

func _on_pile_gui_input(event: InputEvent, pile_kind: String) -> void:
	if pile_cursor_feedback_context_for_state(_animation_lock, str(_run_state.get("mode", "room")), _selected_card_index, _drag_card_index, _pile_scrim != null) != "action":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_pile_view(pile_kind)

func _pile_cursor_feedback_context(_local_position: Vector2, _pile_kind: String) -> String:
	return pile_cursor_feedback_context_for_state(
		_animation_lock,
		str(_run_state.get("mode", "room")),
		_selected_card_index,
		_drag_card_index,
		_pile_scrim != null
	)

static func pile_cursor_feedback_context_for_state(animation_locked: bool, mode: String, selected_card_index: int, drag_card_index: int, overlay_ready: bool) -> String:
	if animation_locked or mode != "combat" or selected_card_index >= 0 or drag_card_index >= 0 or not overlay_ready:
		return "inert"
	return "action"

func _open_pile_view(pile_kind: String) -> void:
	if _pile_scrim == null:
		return
	_cancel_drag_play()
	_close_card_upgrade_overlay()
	var cards: Array = _cards_for_pile(pile_kind)
	var pile_empty: bool = cards.is_empty()
	_pile_dialog.custom_minimum_size = _pile_dialog_size_for_count(cards.size())
	_active_pile_kind = pile_kind
	var selecting_discard_card: bool = pile_kind == "discard" and _combat_skill_card_selection_zone == "discard"
	_pile_dialog_title.text = (
		"%s  ·  Choose a Card to Return" % SkillTreeLibrary.display_name(_combat_skill_card_selection_skill_id)
		if selecting_discard_card
		else "%s Pile" % _pile_display_name(pile_kind)
	)
	_clear_children_now(_pile_dialog_cards)
	var first_selection_button: Button = null
	var selection_buttons: Array[Button]
	for card_index: int in range(cards.size()):
		var card_id: String = str(cards[card_index])
		var source_card_index: int = cards.size() - 1 - card_index if selecting_discard_card else card_index
		var widget := CardWidgetScene.instantiate() as CardWidget
		var valid_selection: bool = not selecting_discard_card or _combat_skill_card_selection_indices.has(source_card_index)
		widget.configure(card_id, false, not valid_selection, valid_selection, false, false, valid_selection, _card_def(card_id))
		widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot: Control = _scaled_card_slot(widget, PILE_DIALOG_CARD_SIZE)
		if not selecting_discard_card:
			_pile_dialog_cards.add_child(slot)
			continue
		var selection_button := Button.new()
		selection_button.name = "DiscardSelectionCard_%d" % card_index
		selection_button.custom_minimum_size = PILE_DIALOG_CARD_SIZE
		selection_button.focus_mode = Control.FOCUS_ALL
		selection_button.disabled = not valid_selection
		selection_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if valid_selection else Control.CURSOR_ARROW
		selection_button.set_meta("source_card_index", source_card_index)
		selection_button.add_theme_stylebox_override("normal", _skill_card_selection_frame_style(Color("74538e"), false))
		selection_button.add_theme_stylebox_override("disabled", _skill_card_selection_frame_style(Color(0.0, 0.0, 0.0, 0.0), false))
		for style_name: String in ["hover", "pressed", "focus"]:
			selection_button.add_theme_stylebox_override(style_name, _skill_card_selection_frame_style(Color("d6a7ff"), true))
		selection_button.add_child(slot)
		_set_mouse_filter_recursive(slot, Control.MOUSE_FILTER_IGNORE)
		if valid_selection:
			selection_button.pressed.connect(_on_combat_skill_discard_card_selected.bind(source_card_index))
			selection_buttons.append(selection_button)
			if first_selection_button == null:
				first_selection_button = selection_button
		else:
			selection_button.modulate = Color(1.0, 1.0, 1.0, 0.42)
		_pile_dialog_cards.add_child(selection_button)
	if _pile_dialog_scroll != null:
		_pile_dialog_scroll.visible = not pile_empty
	_pile_dialog_empty.text = "No cards in this pile." if pile_empty else ""
	_pile_dialog_empty.visible = pile_empty
	_pile_scrim.visible = true
	_configure_discard_selection_focus(selection_buttons)
	if first_selection_button != null:
		first_selection_button.call_deferred("grab_focus")

func _pile_dialog_size_for_count(card_count: int) -> Vector2:
	if card_count <= 0:
		return UiTypography.modal_size(_pile_dialog, PILE_DIALOG_EMPTY_SIZE, Vector2(320.0, 220.0), 16.0)
	var visible_cards: int = mini(card_count, 5)
	var content_width: float = PILE_DIALOG_CARD_SIZE.x * float(visible_cards) + 12.0 * float(maxi(visible_cards - 1, 0)) + 88.0
	var target_size: Vector2 = PILE_DIALOG_ROW_SIZE if card_count <= 5 else PILE_DIALOG_FULL_SIZE
	var preferred := Vector2(clampf(content_width, PILE_DIALOG_MIN_CARD_WIDTH, target_size.x), target_size.y)
	return UiTypography.modal_size(_pile_dialog, preferred, Vector2(320.0, 360.0), 16.0)

func _configure_discard_selection_focus(buttons: Array[Button]) -> void:
	if buttons.is_empty() or _pile_dialog == null:
		return
	var close_button := _pile_dialog.find_child("CloseButton", true, false) as Button
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		_set_skill_status_focus_neighbor(button, "left", buttons[posmod(index - 1, buttons.size())])
		_set_skill_status_focus_neighbor(button, "right", buttons[(index + 1) % buttons.size()])
		if close_button != null:
			_set_skill_status_focus_neighbor(button, "up", close_button)
			_set_skill_status_focus_neighbor(button, "down", close_button)
	if close_button != null:
		_set_skill_status_focus_neighbor(close_button, "left", buttons[buttons.size() - 1])
		_set_skill_status_focus_neighbor(close_button, "right", buttons[0])
		_set_skill_status_focus_neighbor(close_button, "up", buttons[buttons.size() - 1])
		_set_skill_status_focus_neighbor(close_button, "down", buttons[0])

func _close_pile_view() -> void:
	if _combat_skill_card_selection_zone == "discard":
		_cancel_combat_skill_card_selection()
		return
	if _pile_scrim != null:
		_pile_scrim.visible = false
	_active_pile_kind = ""

func _on_combat_skill_discard_card_selected(discard_index: int) -> void:
	if _combat_skill_card_selection_zone != "discard" or not _combat_skill_card_selection_indices.has(discard_index):
		return
	_commit_encore(_combat_skill_card_selection_skill_id, discard_index)

func _open_card_upgrade_overlay() -> void:
	_open_character_overlay("skills")

func _on_character_pressed() -> void:
	_open_character_overlay("equipment")

func _open_character_overlay(mode: String = "equipment") -> void:
	if _upgrade_scrim == null or _pending_umbra_commit_locked:
		return
	_cancel_drag_play()
	_reset_card_resolution()
	_close_pile_view()
	_close_menu_overlay()
	_progression_overlay_mode = mode if mode in ["equipment", "magic", "skills"] else "equipment"
	_progression_overlay_notice = ""
	_progression_overlay_notice_is_error = false
	_clear_open_loadout_tab_unread(_progression_overlay_mode)
	_rebuild_progression_overlay()
	_upgrade_scrim.visible = true
	_sync_pre_battle_overlay_layering()

func _open_level_up_overlay() -> void:
	if _upgrade_scrim == null or not _can_level_at_campfire():
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_menu_overlay()
	var before_progression: Dictionary = _progression.duplicate(true)
	var candidate: Dictionary = ProgressionStore.purchase_level(_progression)
	if candidate == before_progression:
		return
	if not ProgressionStore.save_data(candidate):
		_progression_overlay_mode = "skills"
		_progression_overlay_notice = "The level could not be saved. No embers were spent; try again."
		_progression_overlay_notice_is_error = true
		_rebuild_progression_overlay()
		_upgrade_scrim.visible = true
		_sync_pre_battle_overlay_layering()
		return
	_progression = candidate
	_run_state = _run_engine.apply_progression_update(_run_state, _progression, false)
	_run_state = _run_engine.leave_campfire(_run_state, 0)
	_persist_committed_boundary("level_up")
	_analytics_log_level_up(before_progression, _progression)
	_refresh_ui()
	_progression_overlay_mode = "skills"
	var defiance_gained: int = (
		ProgressionStore.defiance_capacity_for_level(int(_progression.get("level", 1)))
		- ProgressionStore.defiance_capacity_for_level(int(before_progression.get("level", 1)))
	)
	_progression_overlay_notice = (
		"Skill point gained. Defiance +%d. Spend the point now or save it for later." % defiance_gained
		if defiance_gained > 0
		else "Skill point gained. Spend it now or save it for later."
	)
	_progression_overlay_notice_is_error = false
	_rebuild_progression_overlay()
	_upgrade_scrim.visible = true
	_sync_pre_battle_overlay_layering()

func _close_card_upgrade_overlay() -> void:
	_close_skill_reset_confirmation()
	if _upgrade_scrim != null:
		_upgrade_scrim.visible = false
	_progression_overlay_mode = ""
	_progression_overlay_notice = ""
	_progression_overlay_notice_is_error = false
	_progression_level_label = null
	_progression_skill_points_label = null
	_progression_moltshards_label = null
	_progression_defiance_label = null
	_skill_reset_button = null
	_skill_tree_view = null
	_clear_equipment_drag_state(true)
	_clear_magic_drag_state(true)
	_clear_item_drag_state(true)
	if _skill_hud_refresh_pending:
		_skill_hud_refresh_pending = false
		_refresh_relic_bar()
	_sync_pre_battle_overlay_layering()

func _rebuild_progression_overlay() -> void:
	if _upgrade_dialog == null:
		return
	_sync_progression_from_run()
	_clear_children_now(_upgrade_dialog)
	_layout_progression_dialog()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING))
	margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING))
	_upgrade_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	vbox.add_child(top_row)

	var title := Label.new()
	title.text = "Character"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(title, UiTypography.ROLE_TITLE)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	top_row.add_child(title)

	top_row.add_child(_build_progression_resource_summary())

	var close_button := Button.new()
	close_button.name = "CloseCharacterOverlay"
	close_button.text = "X"
	_apply_progression_icon_button_style(close_button)
	UiTypography.apply_button_role(close_button, UiTypography.ROLE_BODY)
	close_button.custom_minimum_size = Vector2(48.0, 48.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_on_progression_overlay_close_pressed)
	top_row.add_child(close_button)

	if not _progression_overlay_notice.is_empty():
		var notice_label := Label.new()
		notice_label.name = "ProgressionOverlayNotice"
		notice_label.text = _progression_overlay_notice
		notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UiTypography.apply_label_role(notice_label, UiTypography.ROLE_CAPTION)
		notice_label.add_theme_color_override(
			"font_color",
			Color("ef9a8f") if _progression_overlay_notice_is_error else Color("f0c978")
		)
		vbox.add_child(notice_label)

	vbox.add_child(_build_character_overlay_tabs())

	if _progression_overlay_mode == "equipment":
		vbox.add_child(_build_equipment_overlay_body())
	elif _progression_overlay_mode == "magic":
		vbox.add_child(_build_magic_overlay_body())
	else:
		vbox.add_child(_build_skill_tree_overlay_body())
	_ui_skin.apply_outer_panel_frame(_upgrade_dialog, UiSkin.SURFACE_DIALOG)
	# A freshly built auto-wrapping detail panel can briefly report its minimum
	# height before receiving its final width. CenterContainer preserves that
	# transient growth in its offsets, so refit once layout has settled.
	_fit_progression_modal_to_viewport()
	call_deferred("_fit_progression_modal_to_viewport")

func _fit_progression_modal_to_viewport() -> void:
	if _upgrade_scrim == null or _upgrade_center == null:
		return
	_upgrade_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _layout_progression_dialog() -> void:
	if _upgrade_dialog == null:
		return
	var uses_skill_tree: bool = _progression_overlay_mode == "skills"
	var preferred: Vector2 = SKILL_TREE_DIALOG_SIZE if uses_skill_tree else CHARACTER_DIALOG_SIZE
	var minimum: Vector2 = SKILL_TREE_DIALOG_MIN_SIZE if uses_skill_tree else CHARACTER_DIALOG_MIN_SIZE
	var dialog_size: Vector2 = UiTypography.modal_size(_upgrade_dialog, preferred, minimum)
	_upgrade_dialog.custom_minimum_size = dialog_size
	_upgrade_dialog.size = dialog_size

func _on_progression_overlay_close_pressed() -> void:
	_close_card_upgrade_overlay()

func _build_progression_resource_summary() -> Control:
	var row := HBoxContainer.new()
	row.name = "ProgressionOverlaySummary"
	_progression_summary_compact = (
		_upgrade_dialog != null
		and _upgrade_dialog.get_viewport_rect().size.x < PROGRESSION_SUMMARY_COMPACT_VIEWPORT_WIDTH
	)
	row.add_theme_constant_override(
		"separation",
		UiTypography.SPACE_TIGHT if _progression_summary_compact else UiTypography.SPACE_SMALL
	)
	_progression_level_label = _add_progression_resource_chip(
		row,
		"ProgressionLevel",
		Color("e5b95f"),
		68.0 if _progression_summary_compact else 124.0
	)
	_progression_skill_points_label = _add_progression_resource_chip(
		row,
		"ProgressionSkillPoints",
		Color("72d4c6"),
		68.0 if _progression_summary_compact else 124.0
	)
	_progression_moltshards_label = _add_progression_resource_chip(
		row,
		"ProgressionMoltshards",
		Color("b58ae0"),
		76.0 if _progression_summary_compact else 124.0
	)
	_progression_defiance_label = _add_progression_resource_chip(
		row,
		"ProgressionDefiance",
		Color("d6aa5e"),
		160.0 if _progression_summary_compact else 220.0
	)
	_refresh_progression_resource_summary()
	return row

func _add_progression_resource_chip(row: HBoxContainer, chip_name: String, accent: Color, minimum_width: float = 124.0) -> Label:
	var panel := PanelContainer.new()
	panel.name = "%sChip" % chip_name
	panel.custom_minimum_size = Vector2(minimum_width, 36.0 if _progression_summary_compact else 44.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.042, 0.052, 0.96)
	style.border_color = accent.darkened(0.14)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	panel.add_child(margin)
	var label := Label.new()
	label.name = "%sLabel" % chip_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.apply_label_role(
		label,
		UiTypography.ROLE_CAPTION if _progression_summary_compact else UiTypography.ROLE_SECTION
	)
	label.add_theme_color_override("font_color", accent.lightened(0.10))
	label.add_theme_color_override("font_outline_color", Color("21151b"))
	label.add_theme_constant_override("outline_size", 2)
	margin.add_child(label)
	return label

func _refresh_progression_resource_summary() -> void:
	if _progression_level_label != null:
		_progression_level_label.text = (
			"LV %d" % int(_progression.get("level", 1))
			if _progression_summary_compact
			else "LEVEL  %d" % int(_progression.get("level", 1))
		)
	if _progression_skill_points_label != null:
		_progression_skill_points_label.text = (
			"PTS %d" % ProgressionStore.unspent_skill_points(_progression)
			if _progression_summary_compact
			else "POINTS  %d" % ProgressionStore.unspent_skill_points(_progression)
		)
	if _progression_moltshards_label != null:
		_progression_moltshards_label.text = (
			"MOLT %d" % ProgressionStore.moltshard_count(_progression)
			if _progression_summary_compact
			else "MOLTSHARDS  %d" % ProgressionStore.moltshard_count(_progression)
		)
	if _progression_defiance_label != null:
		var level: int = int(_progression.get("level", 1))
		var permanent_capacity: int = ProgressionStore.defiance_capacity_for_level(level)
		var capacity: int = (
			_run_engine.defiance_capacity(_run_state)
			if not _run_state.is_empty()
			else permanent_capacity
		)
		var remaining: int = _run_engine.defiance_remaining(_run_state) if not _run_state.is_empty() else capacity
		var next_level: int = mini(
			GameData.max_progression_level(),
			(permanent_capacity + 1) * ProgressionStore.DEFIANCE_LEVEL_INTERVAL
		)
		_progression_defiance_label.text = (
			(
				"DEFIANCE %d/%d · MAX" % [remaining, capacity]
				if level >= GameData.max_progression_level()
				else "DEFIANCE %d/%d · L%d" % [remaining, capacity, next_level]
			)
			if _progression_summary_compact
			else (
				"DEFIANCE  %d/%d  ·  MAX" % [remaining, capacity]
				if level >= GameData.max_progression_level()
				else "DEFIANCE  %d/%d  ·  NEXT %d" % [remaining, capacity, next_level]
			)
		)

func _build_character_overlay_tabs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	for entry: Dictionary in [
		{"mode": "equipment", "text": "Gear"},
		{"mode": "magic", "text": "Magic"},
		{"mode": "skills", "text": "Skills"}
	]:
		var button := Button.new()
		var mode: String = str(entry.get("mode", ""))
		button.name = "Character%sTab" % mode.capitalize()
		button.text = str(entry.get("text", ""))
		button.toggle_mode = true
		button.button_pressed = _progression_overlay_mode == mode
		button.custom_minimum_size = Vector2(132.0, 42.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_apply_character_tab_style(button, button.button_pressed)
		UiTypography.apply_button_role(button, UiTypography.ROLE_BODY)
		var unread_count: int = _run_engine.loadout_unread_ids(_run_state, mode).size()
		if unread_count > 0:
			_add_loadout_tab_badge(button, mode, unread_count)
		if _progression_overlay_mode != mode:
			button.pressed.connect(_switch_character_overlay_mode.bind(mode))
		row.add_child(button)
	return row

func _add_loadout_tab_badge(button: Button, mode: String, unread_count: int) -> void:
	var badge := PanelContainer.new()
	badge.name = "%sLoadoutTabBadge" % mode.capitalize()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = GRIMOIRE_BADGE_SIZE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -16.0
	badge.offset_top = -5.0
	badge.offset_right = 2.0
	badge.offset_bottom = 13.0
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("d64a3a")
	badge_style.border_color = Color("ffe0a2")
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel", badge_style)
	var label := Label.new()
	label.text = str(mini(9, unread_count))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, 8)
	label.add_theme_color_override("font_color", Color("fff7d8"))
	label.add_theme_color_override("font_outline_color", Color("2b130e"))
	label.add_theme_constant_override("outline_size", 1)
	badge.add_child(label)
	button.add_child(badge)

func _switch_character_overlay_mode(mode: String) -> void:
	if not (mode in ["equipment", "magic", "skills"]):
		return
	_progression_overlay_mode = mode
	_progression_overlay_notice = ""
	_progression_overlay_notice_is_error = false
	_clear_open_loadout_tab_unread(mode)
	_rebuild_progression_overlay()

func _clear_open_loadout_tab_unread(mode: String) -> void:
	if mode not in ["equipment", "magic"]:
		return
	if _run_engine.loadout_unread_ids(_run_state, mode).is_empty():
		return
	_run_state = _run_engine.clear_loadout_unread(_run_state, mode)
	_persist_committed_boundary("loadout_tab_seen")
	_refresh_loadout_badge()

func _add_loadout_new_tag(tile: Control, mode: String, asset_id: String) -> void:
	if not _run_engine.loadout_asset_is_new(_run_state, mode, asset_id):
		return
	var overlay := MarginContainer.new()
	overlay.name = "LoadoutNewTagOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_constant_override("margin_left", 6)
	overlay.add_theme_constant_override("margin_top", 5)
	overlay.add_theme_constant_override("margin_right", 6)
	overlay.add_theme_constant_override("margin_bottom", 5)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var badge := PanelContainer.new()
	badge.name = "LoadoutNewTag"
	badge.set_meta("loadout_mode", mode)
	badge.set_meta("asset_id", asset_id)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(42.0, 19.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("c83f32")
	style.border_color = Color("ffe0a2")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "NEW"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, 9)
	label.add_theme_color_override("font_color", Color("fff7d8"))
	label.add_theme_color_override("font_outline_color", Color("35130e"))
	label.add_theme_constant_override("outline_size", 1)
	badge.add_child(label)
	row.add_child(badge)
	tile.add_child(overlay)
	tile.mouse_entered.connect(_on_loadout_asset_hovered.bind(mode, asset_id))

func _on_loadout_asset_hovered(mode: String, asset_id: String) -> void:
	if not _run_engine.loadout_asset_is_new(_run_state, mode, asset_id):
		return
	_run_state = _run_engine.mark_loadout_asset_seen(_run_state, mode, asset_id)
	if _upgrade_scrim != null:
		for tag_var: Node in _upgrade_scrim.find_children("LoadoutNewTag", "", true, false):
			if str(tag_var.get_meta("loadout_mode", "")) == mode and str(tag_var.get_meta("asset_id", "")) == asset_id:
				tag_var.visible = false
	_persist_committed_boundary("loadout_asset_seen")

func _apply_character_tab_style(button: Button, active: bool) -> void:
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_SELECTED if active else UiSkin.VARIANT_STANDARD)
	_apply_progression_button_text(button, UiTypography.SIZE_SMALL)

func _build_equipment_overlay_body() -> Control:
	_equipment_slot_panels.clear()
	_equipment_inventory_tiles.clear()
	_magic_attuned_tiles.clear()
	_magic_inventory_tiles.clear()
	_magic_attuned_drop_panel = null
	_magic_inventory_drop_panel = null
	_item_equipped_tiles.clear()
	_item_inventory_tiles.clear()
	_item_inventory_drop_panel = null
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	body.add_child(_build_equipment_character_column())
	body.add_child(_build_equipment_inventory_column())
	body.add_child(_build_current_deck_column())
	return _fixed_character_body_frame(body)

func _build_magic_overlay_body() -> Control:
	_equipment_slot_panels.clear()
	_equipment_inventory_tiles.clear()
	_magic_attuned_tiles.clear()
	_magic_inventory_tiles.clear()
	_magic_attuned_drop_panel = null
	_magic_inventory_drop_panel = null
	_item_equipped_tiles.clear()
	_item_inventory_tiles.clear()
	_item_inventory_drop_panel = null
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	body.add_child(_build_magic_attuned_column())
	body.add_child(_build_magic_inventory_column())
	body.add_child(_build_current_deck_column())
	return _fixed_character_body_frame(body)

func _build_skill_tree_overlay_body() -> Control:
	var column := VBoxContainer.new()
	column.name = "SkillTreeOverlayBody"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)

	var owned_ids: Array[String] = ProgressionStore.selected_skill_ids(_progression)
	var earned_points: int = ProgressionStore.skill_points_for_level(int(_progression.get("level", 1)))
	var unspent_points: int = ProgressionStore.unspent_skill_points(_progression)

	_skill_tree_view = SkillTreeView.new()
	_skill_tree_view.name = "CharacterSkillTree"
	_skill_tree_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_tree_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_tree_view.configure({
		"mode": SkillTreeView.MODE_VIEW,
		"owned_ids": owned_ids,
		"required_count": earned_points,
		"unspent_points": unspent_points,
		"editing_enabled": _skill_editing_can_edit(),
		"focused_id": _progression_focused_skill_id,
	})
	_skill_tree_view.skill_focused.connect(_on_skill_tree_focused)
	_skill_tree_view.learn_requested.connect(_on_skill_learn_requested)
	column.add_child(_skill_tree_view)
	_skill_tree_view.call_deferred("grab_tree_focus")
	var skills_tab := _upgrade_dialog.find_child("CharacterSkillsTab", true, false) as Button
	_skill_tree_view.set_external_tab_focus_target(skills_tab)

	var command_row := HBoxContainer.new()
	command_row.name = "SkillTreeViewCommands"
	command_row.alignment = BoxContainer.ALIGNMENT_END
	command_row.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	var unavailable_reason: String = _skill_reset_unavailable_reason()
	var command_spacer := Control.new()
	command_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_row.add_child(command_spacer)
	var reset_button := Button.new()
	reset_button.name = "ResetSkills"
	reset_button.text = _skill_reset_button_text()
	reset_button.custom_minimum_size = Vector2(232.0, 44.0)
	reset_button.disabled = not _skill_reset_can_apply()
	reset_button.tooltip_text = unavailable_reason
	_apply_progression_command_button_style(reset_button)
	UiTypography.apply_button_role(reset_button, UiTypography.ROLE_BODY)
	reset_button.pressed.connect(_open_skill_reset_confirmation)
	command_row.add_child(reset_button)
	_skill_reset_button = reset_button
	column.add_child(command_row)
	_skill_tree_view.set_external_command_focus_target(reset_button)
	return _fixed_character_body_frame(column)

func _on_skill_tree_focused(skill_id: String) -> void:
	_progression_focused_skill_id = skill_id

func _on_skill_learn_requested(skill_id: String) -> void:
	if not _skill_editing_can_edit():
		return
	_reset_card_resolution()
	var persisted_profile: Dictionary = _authoritative_profile_progression()
	if not ProgressionStore.can_learn_skill(persisted_profile, skill_id):
		_progression = persisted_profile
		_run_state = _run_engine.apply_progression_update(_run_state, _progression)
		_sync_combat_state_from_run()
		_progression_overlay_notice = "That skill is no longer available or there are no unspent skill points."
		_progression_overlay_notice_is_error = true
		_rebuild_progression_overlay()
		_refresh_ui()
		return
	var previous_progression: Dictionary = persisted_profile.duplicate(true)
	var candidate: Dictionary = ProgressionStore.learn_skill(persisted_profile, skill_id)
	if not ProgressionStore.save_data(candidate):
		_progression_overlay_notice = "The skill could not be saved. Your point was not spent; try again."
		_progression_overlay_notice_is_error = true
		_rebuild_progression_overlay()
		return
	_progression = candidate
	_run_state = _run_engine.apply_progression_update(_run_state, _progression)
	_sync_combat_state_from_run()
	_persist_committed_boundary("skill_learn")
	_analytics_log_skill_learned(previous_progression, _progression, skill_id)
	_progression_overlay_notice = ""
	_progression_overlay_notice_is_error = false
	var prior_notice := _upgrade_dialog.find_child("ProgressionOverlayNotice", true, false) if _upgrade_dialog != null else null
	if prior_notice != null:
		_queue_free_node_now(prior_notice)
	_refresh_skill_progression_surface(skill_id)
	_skill_hud_refresh_pending = true

func _refresh_skill_progression_surface(focused_id: String = "") -> void:
	_refresh_progression_resource_summary()
	if _skill_tree_view != null:
		var next_focus: String = focused_id if SkillTreeLibrary.has_definition(focused_id) else _progression_focused_skill_id
		_skill_tree_view.configure({
			"mode": SkillTreeView.MODE_VIEW,
			"owned_ids": ProgressionStore.selected_skill_ids(_progression),
			"required_count": ProgressionStore.skill_points_for_level(int(_progression.get("level", 1))),
			"unspent_points": ProgressionStore.unspent_skill_points(_progression),
			"editing_enabled": _skill_editing_can_edit(),
			"focused_id": next_focus,
		})
		_progression_focused_skill_id = _skill_tree_view.focused_skill_id()
	if _skill_reset_button != null:
		var unavailable_reason: String = _skill_reset_unavailable_reason()
		_skill_reset_button.disabled = not _skill_reset_can_apply()
		_skill_reset_button.text = _skill_reset_button_text()
		_skill_reset_button.tooltip_text = unavailable_reason
		_apply_progression_command_button_style(_skill_reset_button)

func _open_skill_reset_confirmation() -> void:
	if not _skill_reset_can_apply() or _upgrade_scrim == null or _skill_reset_confirmation_scrim != null:
		return
	var learned_count: int = ProgressionStore.selected_skill_ids(_progression).size()
	var earned_points: int = ProgressionStore.skill_points_for_level(int(_progression.get("level", 1)))
	_skill_reset_confirmation_scrim = ColorRect.new()
	_skill_reset_confirmation_scrim.name = "SkillResetConfirmationScrim"
	_skill_reset_confirmation_scrim.color = Color(0.01, 0.008, 0.012, 0.78)
	_skill_reset_confirmation_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_reset_confirmation_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skill_reset_confirmation_scrim.z_index = 20
	_upgrade_scrim.add_child(_skill_reset_confirmation_scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skill_reset_confirmation_scrim.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "SkillResetConfirmationPanel"
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	panel.add_theme_stylebox_override("panel", _skill_reset_panel_style(Color("8c6f49")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Reset Skills?"
	UiTypography.apply_label_role(title, UiTypography.ROLE_TITLE)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	column.add_child(title)
	var message := Label.new()
	message.name = "SkillResetConfirmationMessage"
	message.text = "Are you sure you want to clear all %d learned skills?\nAll %d earned skill points will be restored. This costs 1 Moltshard." % [learned_count, earned_points]
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(message, UiTypography.ROLE_BODY)
	message.add_theme_color_override("font_color", Color("d9cdbb"))
	column.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	column.add_child(buttons)
	var cancel_button := Button.new()
	cancel_button.name = "CancelSkillReset"
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(124.0, 44.0)
	_apply_progression_command_button_style(cancel_button)
	cancel_button.pressed.connect(_close_skill_reset_confirmation)
	buttons.add_child(cancel_button)
	var confirm_button := Button.new()
	confirm_button.name = "ConfirmSkillReset"
	confirm_button.text = "Reset Skills"
	confirm_button.custom_minimum_size = Vector2(164.0, 44.0)
	_ui_skin.apply_button_stylebox_overrides(confirm_button, UiSkin.VARIANT_SELECTED)
	_apply_progression_button_text(confirm_button, UiTypography.SIZE_SMALL)
	confirm_button.pressed.connect(_confirm_skill_reset)
	buttons.add_child(confirm_button)
	cancel_button.focus_neighbor_right = cancel_button.get_path_to(confirm_button)
	confirm_button.focus_neighbor_left = confirm_button.get_path_to(cancel_button)
	cancel_button.call_deferred("grab_focus")

func _close_skill_reset_confirmation() -> void:
	if _skill_reset_confirmation_scrim == null:
		return
	_queue_free_node_now(_skill_reset_confirmation_scrim)
	_skill_reset_confirmation_scrim = null
	if _skill_tree_view != null:
		_skill_tree_view.call_deferred("grab_tree_focus")

func _confirm_skill_reset() -> void:
	if not _skill_reset_can_apply():
		_close_skill_reset_confirmation()
		return
	var persisted_profile: Dictionary = _authoritative_profile_progression()
	if not ProgressionStore.can_reset_skills(persisted_profile):
		_close_skill_reset_confirmation()
		_progression = persisted_profile
		_run_state = _run_engine.apply_progression_update(_run_state, _progression)
		_sync_combat_state_from_run()
		_progression_overlay_notice = "Skills could not be reset because the profile changed or no Moltshard is available."
		_progression_overlay_notice_is_error = true
		_rebuild_progression_overlay()
		_refresh_ui()
		return
	var previous_progression: Dictionary = persisted_profile.duplicate(true)
	var candidate: Dictionary = ProgressionStore.reset_skills(persisted_profile)
	if not ProgressionStore.save_data(candidate):
		_close_skill_reset_confirmation()
		_progression_overlay_notice = "Skills could not be reset. Nothing changed and no Moltshard was spent."
		_progression_overlay_notice_is_error = true
		_rebuild_progression_overlay()
		return
	_close_skill_reset_confirmation()
	_reset_card_resolution()
	_progression = candidate
	_run_state = _run_engine.apply_progression_update(_run_state, _progression)
	_sync_combat_state_from_run()
	_persist_committed_boundary("skill_reset")
	_analytics_log_skill_reset(previous_progression, _progression)
	_progression_focused_skill_id = ""
	_progression_overlay_notice = ""
	_progression_overlay_notice_is_error = false
	_refresh_skill_progression_surface()
	_skill_hud_refresh_pending = true

func _skill_editing_can_edit() -> bool:
	if _run_state.is_empty() or _animation_lock or _pending_umbra_commit_locked or _loadout_acquisition_in_progress or _relic_claim_in_progress:
		return false
	return str(_run_state.get("mode", "room")) not in ["combat", "victory", "defeat"]

func _skill_reset_can_apply() -> bool:
	return _skill_editing_can_edit() and ProgressionStore.can_reset_skills(_progression)

func _skill_reset_unavailable_reason() -> String:
	if _run_state.is_empty():
		return "Start a run before resetting your skills."
	if ProgressionStore.selected_skill_ids(_progression).is_empty():
		return "Learn a skill before resetting the tree."
	if ProgressionStore.moltshard_count(_progression) <= 0:
		return "Defeat the first boss of a run to earn one."
	var mode: String = str(_run_state.get("mode", "room"))
	if mode == "combat":
		return "Reset is unavailable during combat."
	if mode in ["victory", "defeat"]:
		return "Reset is unavailable after the run ends."
	if _animation_lock or _pending_umbra_commit_locked or _loadout_acquisition_in_progress or _relic_claim_in_progress:
		return "Finish the current action before resetting your skills."
	return ""

func _skill_reset_button_text() -> String:
	if _skill_reset_can_apply():
		return "Reset Skills  ·  1 Moltshard"
	if _run_state.is_empty():
		return "Reset Skills  ·  Start a Run"
	if ProgressionStore.selected_skill_ids(_progression).is_empty():
		return "Reset Skills  ·  No Skills Learned"
	if ProgressionStore.moltshard_count(_progression) <= 0:
		return "Reset Skills  ·  Need 1 Moltshard"
	var mode: String = str(_run_state.get("mode", "room"))
	if mode == "combat":
		return "Reset Skills  ·  Unavailable in Combat"
	if mode in ["victory", "defeat"]:
		return "Reset Skills  ·  Run Complete"
	return "Reset Skills  ·  Finish Current Action"

func _skill_reset_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171219")
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 7.0)
	return style

func _authoritative_profile_progression() -> Dictionary:
	var persisted_profile: Dictionary = ProgressionStore.load_data()
	var active_progression: Dictionary = ProgressionStore.normalized_data(_progression)
	if int(active_progression.get("progression_revision", 0)) <= int(persisted_profile.get("progression_revision", 0)):
		return persisted_profile
	# Embers belong to the active run until a normal banking/level boundary. A
	# newer embedded revision may repair skills or Moltshards, but must never
	# turn the run's held embers into banked profile currency.
	active_progression = ProgressionStore.set_embers(active_progression, int(persisted_profile.get("embers", 0)))
	return ProgressionStore.normalized_data(active_progression)

func _repair_profile_progression_from_run() -> void:
	if _run_state.is_empty() or bool(_run_state.get("debug_boss_run", false)):
		return
	var persisted_profile: Dictionary = ProgressionStore.load_data()
	var repaired_profile: Dictionary = _authoritative_profile_progression()
	if int(repaired_profile.get("progression_revision", 0)) <= int(persisted_profile.get("progression_revision", 0)):
		return
	if not ProgressionStore.save_data(repaired_profile):
		push_error("Failed to repair profile progression from the newer saved run snapshot.")

func _fixed_character_body_frame(content: Control) -> Control:
	var frame := Control.new()
	frame.name = "CharacterBodyFrame"
	var dialog_height: float = _upgrade_dialog.custom_minimum_size.y if _upgrade_dialog != null else CHARACTER_DIALOG_SIZE.y
	var chrome_height: float = 194.0
	var available_height: float = maxf(240.0, dialog_height - chrome_height)
	frame.custom_minimum_size = Vector2(0.0, minf(CHARACTER_BODY_MIN_HEIGHT, available_height))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(content)
	return frame

func _build_equipment_character_column() -> Control:
	var panel := PanelContainer.new()
	panel.name = "EquipmentLoadoutPanel"
	panel.custom_minimum_size = Vector2(338.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Loadout"
	UiTypography.apply_label_role(title, UiTypography.ROLE_SECTION)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)
	vbox.add_child(_build_equipment_portrait_panel())

	var loadout_scroll := ScrollContainer.new()
	loadout_scroll.name = "EquipmentLoadoutScroll"
	loadout_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(loadout_scroll)

	var loadout := VBoxContainer.new()
	loadout.name = "EquipmentLoadoutList"
	loadout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout.add_theme_constant_override("separation", 6)
	loadout_scroll.add_child(loadout)

	var gear_label := Label.new()
	gear_label.text = "Gear"
	UiTypography.set_label_size(gear_label, UiTypography.SIZE_CAPTION)
	gear_label.add_theme_color_override("font_color", Color("f0c978"))
	gear_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	gear_label.add_theme_constant_override("outline_size", 1)
	loadout.add_child(gear_label)

	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 6)
	loadout.add_child(slots)
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		slots.add_child(_build_equipment_slot_panel(slot, str(equipped.get(slot, ""))))
	loadout.add_child(_build_equipped_items_section())
	return panel

func _build_equipped_items_section() -> Control:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 5)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	section.add_child(title_row)
	var title := Label.new()
	title.text = "Items"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_CAPTION)
	title.add_theme_color_override("font_color", Color("f0c978"))
	title.add_theme_color_override("font_outline_color", Color("1d1510"))
	title.add_theme_constant_override("outline_size", 1)
	title_row.add_child(title)
	var equipped_items: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	var count := Label.new()
	count.text = "%d/%d" % [mini(equipped_items.size(), GameData.item_loadout_limit()), GameData.item_loadout_limit()]
	UiTypography.set_label_size(count, UiTypography.SIZE_CAPTION)
	count.add_theme_color_override("font_color", Color("f0c978"))
	title_row.add_child(count)
	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 5)
	section.add_child(slots)
	for index: int in range(GameData.item_loadout_limit()):
		var card_id: String = str(equipped_items[index]) if index < equipped_items.size() else ""
		slots.add_child(_build_item_card_tile(card_id, "equipped", index, ITEM_EQUIPPED_TILE_SIZE))
	return section

func _build_equipment_portrait_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 124.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(_equipped_equipment_accent(), true))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var art := TextureRect.new()
	art.name = "EquipmentCharacterArt"
	art.texture = AssetLoader.load_texture(PLAYER_UNIT_TEXTURE_PATH)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(150.0, 104.0)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = _equipment_player_art_tint()
	row.add_child(art)

	var icons := HFlowContainer.new()
	icons.custom_minimum_size = Vector2(92.0, 0.0)
	icons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icons.alignment = FlowContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("h_separation", 6)
	icons.add_theme_constant_override("v_separation", 6)
	row.add_child(icons)
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		var equipment_id: String = str(equipped.get(slot, ""))
		if equipment_id.is_empty():
			continue
		icons.add_child(_build_equipment_icon_chip(equipment_id, Vector2(38.0, 38.0)))
	return panel

func _build_equipment_slot_panel(slot: String, equipment_id: String) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var accent: Color = Color(GameData.equipment_accent(equipment_id)) if not equipment_id.is_empty() else Color("6d5a46")
	var panel := EquipmentSlotDrop.new()
	panel.slot_id = slot
	panel.host = self
	panel.equipment_id = equipment_id
	panel.custom_minimum_size = EQUIPMENT_SLOT_SIZE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = "equipment:%s" % equipment_id if not equipment_id.is_empty() else _equipment_slot_label(slot)
	var is_drag_target: bool = not _equipment_drag_id.is_empty() and _equipment_slot_accepts_drag(slot, _equipment_drag_id)
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(accent, is_drag_target))
	if not _equipment_drag_id.is_empty() and not is_drag_target:
		panel.modulate = Color(0.68, 0.68, 0.68, 1.0)
	_equipment_slot_panels[slot] = panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	if not equipment_id.is_empty():
		row.add_child(_build_equipment_icon_chip(equipment_id, EQUIPMENT_ICON_SIZE))
	else:
		var empty_icon := Control.new()
		empty_icon.custom_minimum_size = EQUIPMENT_ICON_SIZE
		row.add_child(empty_icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	var slot_label := Label.new()
	slot_label.text = _equipment_slot_label(slot)
	slot_label.clip_text = true
	UiTypography.set_label_size(slot_label, UiTypography.SIZE_SMALL)
	slot_label.add_theme_color_override("font_color", Color("dcc9a9"))
	slot_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	slot_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(slot_label)
	var name_label := Label.new()
	name_label.text = str(item.get("name", "Empty")) if not item.is_empty() else "Empty"
	name_label.clip_text = true
	UiTypography.set_label_size(name_label, UiTypography.SIZE_BODY)
	name_label.add_theme_color_override("font_color", Color("fff0ce"))
	name_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	name_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(name_label)
	if not _equipment_overlay_can_change():
		panel.modulate = Color(0.78, 0.78, 0.78, 1.0)
	return panel

func _build_equipment_inventory_column() -> Control:
	var panel := PanelContainer.new()
	panel.name = "EquipmentInventoryPanel"
	panel.custom_minimum_size = Vector2(374.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "Inventory"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	title_row.add_child(title)
	var count := Label.new()
	count.text = "%d gear  %d items" % [
		int((_run_state.get("equipment_inventory", []) as Array).size()),
		int((_run_state.get("item_inventory", []) as Array).size())
	]
	UiTypography.set_label_size(count, UiTypography.SIZE_SMALL)
	count.add_theme_color_override("font_color", Color("f0c978"))
	title_row.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 12)
	scroll.add_child(sections)

	var inventory_ids: Array = _equipment_inventory_ids()
	var gear_label := Label.new()
	gear_label.text = "Gear"
	UiTypography.set_label_size(gear_label, UiTypography.SIZE_CAPTION)
	gear_label.add_theme_color_override("font_color", Color("f0c978"))
	gear_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	gear_label.add_theme_constant_override("outline_size", 1)
	sections.add_child(gear_label)
	var gear_grid := HFlowContainer.new()
	gear_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_grid.alignment = FlowContainer.ALIGNMENT_BEGIN
	gear_grid.add_theme_constant_override("h_separation", 8)
	gear_grid.add_theme_constant_override("v_separation", 8)
	sections.add_child(gear_grid)
	if inventory_ids.is_empty():
		var empty := Label.new()
		empty.text = "No spare gear"
		empty.custom_minimum_size = Vector2(0.0, 80.0)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTypography.set_label_size(empty, UiTypography.SIZE_SMALL)
		empty.add_theme_color_override("font_color", Color("cdbca2"))
		gear_grid.add_child(empty)
	else:
		for equipment_id_var: Variant in inventory_ids:
			gear_grid.add_child(_build_equipment_inventory_tile(str(equipment_id_var)))

	var item_title_row := HBoxContainer.new()
	item_title_row.add_theme_constant_override("separation", 8)
	sections.add_child(item_title_row)
	var item_title := Label.new()
	item_title.text = "Items"
	item_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(item_title, UiTypography.SIZE_CAPTION)
	item_title.add_theme_color_override("font_color", Color("f0c978"))
	item_title.add_theme_color_override("font_outline_color", Color("1d1510"))
	item_title.add_theme_constant_override("outline_size", 1)
	item_title_row.add_child(item_title)
	var equipped_items: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	var item_count := Label.new()
	item_count.text = "Equipped %d/%d" % [mini(equipped_items.size(), GameData.item_loadout_limit()), GameData.item_loadout_limit()]
	UiTypography.set_label_size(item_count, UiTypography.SIZE_CAPTION)
	item_count.add_theme_color_override("font_color", Color("f0c978"))
	item_title_row.add_child(item_count)
	var item_grid := HFlowContainer.new()
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.alignment = FlowContainer.ALIGNMENT_BEGIN
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 8)
	sections.add_child(item_grid)
	_item_inventory_drop_panel = item_grid
	var item_ids: Array = _item_inventory_ids()
	if item_ids.is_empty():
		var item_empty := Label.new()
		item_empty.text = "No consumables"
		item_empty.custom_minimum_size = Vector2(0.0, 72.0)
		item_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTypography.set_label_size(item_empty, UiTypography.SIZE_SMALL)
		item_empty.add_theme_color_override("font_color", Color("cdbca2"))
		item_grid.add_child(item_empty)
	else:
		for index: int in range(item_ids.size()):
			item_grid.add_child(_build_item_card_tile(str(item_ids[index]), "inventory", index, ITEM_INVENTORY_TILE_SIZE))
	return panel

func _build_magic_attuned_column() -> Control:
	var panel := PanelContainer.new()
	panel.name = "MagicAttunedPanel"
	_magic_attuned_drop_panel = panel
	panel.custom_minimum_size = Vector2(326.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "Attuned Magic"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	title_row.add_child(title)
	var attuned: Array = (_run_state.get("attuned_magic_cards", []) as Array).duplicate()
	var count := Label.new()
	count.text = "%d/%d" % [mini(attuned.size(), GameData.magic_loadout_limit()), GameData.magic_loadout_limit()]
	UiTypography.set_label_size(count, UiTypography.SIZE_SMALL)
	count.add_theme_color_override("font_color", Color("f0c978"))
	title_row.add_child(count)

	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 8)
	vbox.add_child(slots)
	for index: int in range(GameData.magic_loadout_limit()):
		var card_id: String = str(attuned[index]) if index < attuned.size() else ""
		slots.add_child(_build_magic_card_tile(card_id, "attuned", index, MAGIC_ATTUNED_TILE_SIZE))
	if not _magic_overlay_can_change():
		var locked := Label.new()
		locked.text = "Locked in combat"
		UiTypography.set_label_size(locked, UiTypography.SIZE_CAPTION)
		locked.add_theme_color_override("font_color", Color("d8a06a"))
		vbox.add_child(locked)
	return panel

func _build_magic_inventory_column() -> Control:
	var panel := PanelContainer.new()
	panel.name = "MagicInventoryPanel"
	_magic_inventory_drop_panel = panel
	panel.custom_minimum_size = Vector2(374.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "Learned Magic"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	title_row.add_child(title)
	var reserve: Array = (_run_state.get("magic_inventory", []) as Array).duplicate()
	var count := Label.new()
	count.text = str(reserve.size())
	UiTypography.set_label_size(count, UiTypography.SIZE_SMALL)
	count.add_theme_color_override("font_color", Color("f0c978"))
	title_row.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.alignment = FlowContainer.ALIGNMENT_BEGIN
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	if reserve.is_empty():
		var empty := Label.new()
		empty.text = "No learned magic"
		empty.custom_minimum_size = Vector2(0.0, 80.0)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTypography.set_label_size(empty, UiTypography.SIZE_SMALL)
		empty.add_theme_color_override("font_color", Color("cdbca2"))
		grid.add_child(empty)
	else:
		for index: int in range(reserve.size()):
			var card_id: String = str(reserve[index])
			grid.add_child(_build_magic_card_tile(card_id, "inventory", index, MAGIC_INVENTORY_TILE_SIZE))
	return panel

func _build_current_deck_column() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CurrentDeckPanel"
	panel.custom_minimum_size = Vector2(344.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Deck"
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var attuned_magic: Array = (_run_state.get("attuned_magic_cards", []) as Array).duplicate()
	list.add_child(_build_attuned_magic_deck_group(attuned_magic))
	var equipped_items: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	list.add_child(_build_equipped_items_deck_group(equipped_items))
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		var equipment_id: String = str(equipped.get(slot, ""))
		if equipment_id.is_empty():
			continue
		list.add_child(_build_equipment_deck_group(equipment_id, _equipment_slot_label(slot)))
	return panel

func _build_equipment_inventory_tile(equipment_id: String) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var accent := Color(GameData.equipment_accent(equipment_id))
	var tile := EquipmentInventoryTile.new()
	tile.equipment_id = equipment_id
	tile.host = self
	tile.custom_minimum_size = EQUIPMENT_TILE_SIZE
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.tooltip_text = "equipment:%s" % equipment_id
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if _equipment_overlay_can_change() else Control.CURSOR_ARROW
	tile.add_theme_stylebox_override("panel", _equipment_panel_style(accent, false))
	if _equipment_drag_id == equipment_id:
		tile.modulate = Color(1.0, 1.0, 1.0, 0.34)
	_equipment_inventory_tiles[equipment_id] = tile
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	tile.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	row.add_child(_build_equipment_icon_chip(equipment_id, EQUIPMENT_ICON_SIZE, false))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = str(item.get("name", equipment_id))
	name_label.clip_text = true
	UiTypography.set_label_size(name_label, UiTypography.SIZE_CAPTION)
	name_label.add_theme_color_override("font_color", Color("fff0ce"))
	name_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	name_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(name_label)
	var meta_label := Label.new()
	meta_label.text = "%s | %s" % [_equipment_slot_label(GameData.equipment_slot(equipment_id)), _equipment_rarity_label(GameData.equipment_rarity(equipment_id))]
	meta_label.clip_text = true
	UiTypography.set_label_size(meta_label, UiTypography.SIZE_CAPTION)
	meta_label.add_theme_color_override("font_color", Color("cdbca2"))
	text_box.add_child(meta_label)
	var card_label := Label.new()
	card_label.text = _equipment_card_summary(equipment_id)
	card_label.clip_text = true
	UiTypography.set_label_size(card_label, UiTypography.SIZE_CAPTION)
	card_label.add_theme_color_override("font_color", Color("d7c6aa"))
	text_box.add_child(card_label)
	_make_equipment_tile_content_passive(margin)
	_add_loadout_new_tag(tile, "equipment", equipment_id)
	if not _equipment_overlay_can_change():
		tile.modulate = Color(0.72, 0.72, 0.72, 1.0)
	return tile

func _build_equipment_deck_group(equipment_id: String, heading: String) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = "%s - %s" % [heading, str(item.get("name", equipment_id))]
	label.clip_text = true
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("f0c978"))
	label.add_theme_color_override("font_outline_color", Color("1d1510"))
	label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(label)
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vbox.add_child(row)
	var accent := Color(GameData.equipment_accent(equipment_id))
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		row.add_child(_build_equipment_card_badge(str(card_id_var), accent))
	return vbox

func _build_attuned_magic_deck_group(attuned_card_ids: Array) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Attuned Magic %d/%d" % [mini(attuned_card_ids.size(), GameData.magic_loadout_limit()), GameData.magic_loadout_limit()]
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("f0c978"))
	label.add_theme_color_override("font_outline_color", Color("1d1510"))
	label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(label)
	var attuned_row := HFlowContainer.new()
	attuned_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attuned_row.add_theme_constant_override("h_separation", 6)
	attuned_row.add_theme_constant_override("v_separation", 6)
	vbox.add_child(attuned_row)
	for index: int in range(GameData.magic_loadout_limit()):
		var card_id: String = str(attuned_card_ids[index]) if index < attuned_card_ids.size() else ""
		if card_id.is_empty():
			continue
		attuned_row.add_child(_build_equipment_card_badge(card_id, ElementData.accent(GameData.card_element(card_id))))
	return vbox

func _build_equipped_items_deck_group(item_card_ids: Array) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Items %d/%d" % [mini(item_card_ids.size(), GameData.item_loadout_limit()), GameData.item_loadout_limit()]
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("f0c978"))
	label.add_theme_color_override("font_outline_color", Color("1d1510"))
	label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(label)
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vbox.add_child(row)
	for index: int in range(GameData.item_loadout_limit()):
		var card_id: String = str(item_card_ids[index]) if index < item_card_ids.size() else ""
		if card_id.is_empty():
			continue
		row.add_child(_build_equipment_card_badge(card_id, _item_card_accent(card_id)))
	return vbox

func _build_magic_card_tile(card_id: String, source_kind: String, index: int, tile_size: Vector2 = EQUIPMENT_DECK_BADGE_SIZE) -> Control:
	if card_id.is_empty():
		var empty := PanelContainer.new()
		empty.custom_minimum_size = tile_size
		empty.add_theme_stylebox_override("panel", _equipment_panel_style(Color("4f453b"), false))
		return empty
	var card: Dictionary = GameData.card_def(card_id)
	var accent: Color = ElementData.accent(GameData.card_element(card_id))
	var tile := MagicCardTile.new()
	tile.card_id = card_id
	tile.host = self
	tile.source_kind = source_kind
	tile.magic_index = index
	tile.custom_minimum_size = tile_size
	if tile_size.x > EQUIPMENT_DECK_BADGE_SIZE.x:
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if _magic_overlay_can_change() else Control.CURSOR_ARROW
	tile.tooltip_text = "card:%s" % card_id
	tile.clip_contents = true
	var is_drag_source: bool = _magic_drag_source_kind == source_kind and _magic_drag_index == index
	tile.add_theme_stylebox_override("panel", _equipment_panel_style(accent, is_drag_source))
	if is_drag_source:
		tile.modulate = Color(1.0, 1.0, 1.0, 0.34)
	if source_kind == "attuned":
		_magic_attuned_tiles[index] = tile
	elif source_kind == "inventory":
		_magic_inventory_tiles[index] = tile
	tile.add_child(_build_card_art_badge_content(card, accent, str(card.get("name", card_id))))
	_add_loadout_new_tag(tile, "magic", card_id)
	return tile

func _build_item_card_tile(card_id: String, source_kind: String, index: int, tile_size: Vector2) -> Control:
	if card_id.is_empty():
		var empty := PanelContainer.new()
		empty.custom_minimum_size = tile_size
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL if source_kind == "equipped" else Control.SIZE_SHRINK_CENTER
		empty.add_theme_stylebox_override("panel", _equipment_panel_style(Color("4f453b"), _item_drag_can_drop_on({"source_kind": source_kind, "index": index})))
		if source_kind == "equipped":
			_item_equipped_tiles[index] = empty
		var empty_label := Label.new()
		empty_label.text = "Empty item slot"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiTypography.set_label_size(empty_label, UiTypography.SIZE_CAPTION)
		empty_label.add_theme_color_override("font_color", Color("b9aa91"))
		empty.add_child(empty_label)
		return empty
	var accent: Color = _item_card_accent(card_id)
	var tile := ItemCardTile.new()
	tile.card_id = card_id
	tile.host = self
	tile.source_kind = source_kind
	tile.item_index = index
	tile.custom_minimum_size = tile_size
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL if source_kind == "equipped" else Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if _item_overlay_can_change() else Control.CURSOR_ARROW
	tile.tooltip_text = "card:%s" % card_id
	tile.clip_contents = true
	var can_receive: bool = _item_drag_can_drop_on({"source_kind": source_kind, "index": index})
	tile.add_theme_stylebox_override("panel", _equipment_panel_style(accent, can_receive))
	if _item_drag_source_kind == source_kind and _item_drag_index == index:
		tile.modulate = Color(1.0, 1.0, 1.0, 0.34)
	elif not _item_drag_card_id.is_empty() and not can_receive:
		tile.modulate = Color(0.72, 0.72, 0.72, 1.0)
	if source_kind == "equipped":
		_item_equipped_tiles[index] = tile
	elif source_kind == "inventory":
		_item_inventory_tiles[index] = tile
	tile.add_child(_build_item_card_tile_body(card_id))
	_add_loadout_new_tag(tile, "equipment", card_id)
	return tile

func _build_item_card_tile_body(card_id: String) -> Control:
	var card: Dictionary = GameData.card_def(card_id)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)
	var art_chip: Control = _build_item_card_art_chip(card_id, ITEM_ART_CHIP_SIZE)
	row.add_child(art_chip)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = str(card.get("name", card_id))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTypography.set_label_size(name_label, UiTypography.SIZE_CAPTION)
	name_label.add_theme_color_override("font_color", Color("fff0ce"))
	name_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	name_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(name_label)
	var meta_label := Label.new()
	meta_label.text = "%s item" % _equipment_rarity_label(str(card.get("rarity", "common")))
	meta_label.clip_text = true
	UiTypography.set_label_size(meta_label, UiTypography.SIZE_CAPTION)
	meta_label.add_theme_color_override("font_color", Color("cdbca2"))
	text_box.add_child(meta_label)
	_make_equipment_tile_content_passive(margin)
	return margin

func _build_item_card_art_chip(card_id: String, chip_size: Vector2) -> Control:
	var card: Dictionary = GameData.card_def(card_id)
	var accent: Color = _item_card_accent(card_id)
	var chip := PanelContainer.new()
	chip.name = "ItemCardArtChip"
	chip.custom_minimum_size = chip_size
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.clip_contents = true
	chip.add_theme_stylebox_override("panel", _equipment_icon_style(accent))
	var icon := TextureRect.new()
	icon.name = "ItemCardArtIcon"
	icon.texture = AssetLoader.load_texture(str(card.get("art_path", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = -12.0
	icon.offset_top = -4.0
	icon.offset_right = 12.0
	icon.offset_bottom = 4.0
	chip.add_child(icon)
	return chip

func _build_item_card_proxy_panel(card_id: String, proxy_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = proxy_size
	panel.size = proxy_size
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _equipment_drag_ghost_style(_item_card_accent(card_id)))
	panel.add_child(_build_item_card_tile_body(card_id))
	return panel

func _build_equipment_card_badge(card_id: String, accent: Color) -> Control:
	var card: Dictionary = GameData.card_def(card_id)
	var badge := EquipmentCardBadge.new()
	badge.card_id = card_id
	badge.host = self
	badge.custom_minimum_size = EQUIPMENT_DECK_BADGE_SIZE
	badge.tooltip_text = "card:%s" % card_id
	badge.clip_contents = true
	badge.add_theme_stylebox_override("panel", _equipment_panel_style(accent, false))
	badge.add_child(_build_card_art_badge_content(card, accent, str(card.get("name", card_id))))
	return badge

func _build_card_art_badge_content(card: Dictionary, accent: Color, label_text: String) -> Control:
	var margin := MarginContainer.new()
	margin.name = "CardArtBadgeContent"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 3)

	var stack := Control.new()
	stack.name = "CardArtBadgeStack"
	stack.clip_contents = true
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)

	var element_id: String = GameData.card_element_from_def(card)
	var art_texture: Texture2D = AssetLoader.load_texture(str(card.get("art_path", "")))
	var backing := CardArtBadgeBacking.new()
	backing.name = "CardBadgeBacking"
	backing.base_color = ElementData.card_art_background(element_id)
	backing.accent = accent
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(backing)

	var underpaint := TextureRect.new()
	underpaint.name = "CardBadgeArtFill"
	underpaint.texture = art_texture
	underpaint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	underpaint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	underpaint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	underpaint.modulate = Color(1.0, 1.0, 1.0, 0.22)
	underpaint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underpaint.set_anchors_preset(Control.PRESET_FULL_RECT)
	underpaint.offset_left = -48.0
	underpaint.offset_top = -14.0
	underpaint.offset_right = 48.0
	underpaint.offset_bottom = 14.0
	stack.add_child(underpaint)

	var art := TextureRect.new()
	art.name = "CardBadgeArt"
	art.texture = art_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.modulate = Color.WHITE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(art)

	var wash := CardArtBadgeWash.new()
	wash.name = "CardBadgeWash"
	wash.accent = accent
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(wash)

	var label := Label.new()
	label.name = "CardBadgeName"
	label.text = label_text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("fff6d8"))
	label.add_theme_color_override("font_outline_color", Color("100a07"))
	label.add_theme_constant_override("outline_size", 2)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 6.0
	label.offset_right = -6.0
	stack.add_child(label)
	return margin

func _build_equipment_icon_chip(equipment_id: String, chip_size: Vector2, owns_tooltip: bool = true) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var chip: PanelContainer
	if owns_tooltip:
		var tooltip_chip := EquipmentTooltipPanelContainer.new()
		tooltip_chip.equipment_id = equipment_id
		tooltip_chip.host = self
		tooltip_chip.tooltip_text = "equipment:%s" % equipment_id
		chip = tooltip_chip
	else:
		chip = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.name = "EquipmentIconChip"
	chip.custom_minimum_size = chip_size
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _equipment_icon_style(Color(GameData.equipment_accent(equipment_id))))
	var icon := TextureRect.new()
	icon.texture = AssetLoader.load_texture(str(item.get("icon_path", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chip.add_child(icon)
	return chip

func _build_equipment_icon_proxy_panel(equipment_id: String, icon_size: Vector2) -> PanelContainer:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = icon_size
	panel.size = icon_size
	panel.add_theme_stylebox_override("panel", _equipment_drag_ghost_style(Color(GameData.equipment_accent(equipment_id))))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var texture := TextureRect.new()
	texture.name = "EquipmentGhostTexture"
	texture.texture = AssetLoader.load_texture(str(item.get("icon_path", "")))
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(texture)
	return panel

func _make_equipment_tile_content_passive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_make_equipment_tile_content_passive(child)

func _begin_equipment_overlay_drag(equipment_id: String, source_rect: Rect2, source_control: Control = null, mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if equipment_id.is_empty():
		return
	if not _equipment_drag_id.is_empty():
		_clear_equipment_drag_state(true)
	_equipment_drag_id = equipment_id
	_equipment_drag_source_rect = source_rect
	_equipment_drag_source_control = source_control
	if _node_is_alive(_equipment_drag_source_control):
		_equipment_drag_source_control.modulate = Color(1.0, 1.0, 1.0, 0.34)
	_spawn_equipment_held_proxy(equipment_id, mouse_position)
	_apply_equipment_drag_highlights()

func _end_equipment_overlay_drag() -> void:
	if _equipment_swap_animation_active:
		return
	_clear_equipment_drag_state(true)

func _spawn_equipment_held_proxy(equipment_id: String, mouse_position: Vector2) -> void:
	if _equipment_fx_layer == null:
		return
	if _node_is_alive(_equipment_held_proxy):
		_queue_free_node_now(_equipment_held_proxy)
	_equipment_held_proxy = _build_equipment_icon_proxy_panel(equipment_id, EQUIPMENT_DRAG_GHOST_SIZE)
	_equipment_held_proxy.name = "EquipmentHeldProxy"
	_equipment_held_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_held_proxy.size = EQUIPMENT_DRAG_GHOST_SIZE
	_equipment_held_proxy.pivot_offset = EQUIPMENT_DRAG_GHOST_SIZE * 0.5
	_equipment_held_proxy.modulate = Color(1.0, 1.0, 1.0, 0.82)
	_equipment_held_proxy.z_index = 20
	_equipment_fx_layer.add_child(_equipment_held_proxy)
	_update_equipment_overlay_drag(mouse_position)

func _update_equipment_overlay_drag(mouse_position: Vector2) -> void:
	if _equipment_drag_id.is_empty() or not _node_is_alive(_equipment_held_proxy):
		return
	var local_mouse: Vector2 = mouse_position
	if local_mouse.x < 0.0 or local_mouse.y < 0.0:
		local_mouse = _current_mouse_position()
	_equipment_held_proxy.position = local_mouse + EQUIPMENT_DRAG_CURSOR_OFFSET - EQUIPMENT_DRAG_GHOST_SIZE * 0.5 - _equipment_fx_layer.global_position

func _release_equipment_overlay_drag(mouse_position: Vector2) -> void:
	if _equipment_drag_id.is_empty():
		return
	_update_equipment_overlay_drag(mouse_position)
	var equipment_id: String = _equipment_drag_id
	var slot: String = _equipment_slot_at(mouse_position)
	if not slot.is_empty() and _equipment_slot_accepts_drag(slot, equipment_id):
		var held_rect: Rect2 = _equipment_held_proxy_global_rect()
		if held_rect.size.x > 0.0 and held_rect.size.y > 0.0:
			_equipment_drag_source_rect = held_rect
		if _node_is_alive(_equipment_held_proxy):
			_queue_free_node_now(_equipment_held_proxy)
			_equipment_held_proxy = null
		await _equip_equipment_from_overlay(equipment_id, slot, _equipment_slot_icon_rect(slot))
		return
	await _cancel_equipment_overlay_drag(true)

func _cancel_equipment_overlay_drag(animate: bool = true) -> void:
	if _equipment_drag_id.is_empty():
		return
	var proxy: Control = _equipment_held_proxy
	if animate and _node_is_alive(proxy) and _equipment_drag_source_rect.size.x > 0.0 and _equipment_drag_source_rect.size.y > 0.0:
		var tween: Tween = create_tween().set_parallel(true)
		_animate_equipment_proxy_to_rect(tween, proxy, _equipment_drag_source_rect, 0.14)
		tween.tween_property(proxy, "modulate:a", 0.46, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
	_clear_equipment_drag_state(true)

func _clear_equipment_drag_state(restore_source: bool) -> void:
	if restore_source and _node_is_alive(_equipment_drag_source_control):
		_equipment_drag_source_control.modulate = Color.WHITE
	if _node_is_alive(_equipment_held_proxy):
		_queue_free_node_now(_equipment_held_proxy)
	_equipment_held_proxy = null
	_equipment_drag_id = ""
	_equipment_drag_source_rect = Rect2()
	_equipment_drag_source_control = null
	_apply_equipment_drag_highlights()

func _apply_equipment_drag_highlights() -> void:
	for slot_var: Variant in _equipment_slot_panels.keys():
		var slot: String = str(slot_var)
		var panel_var: Variant = _equipment_slot_panels.get(slot, null)
		if typeof(panel_var) != TYPE_OBJECT or not is_instance_valid(panel_var) or not (panel_var is PanelContainer):
			continue
		var panel: PanelContainer = panel_var as PanelContainer
		var equipment_id: String = str(panel.get("equipment_id"))
		var accent: Color = Color(GameData.equipment_accent(equipment_id)) if not equipment_id.is_empty() else Color("6d5a46")
		var is_drag_target: bool = not _equipment_drag_id.is_empty() and _equipment_slot_accepts_drag(slot, _equipment_drag_id)
		panel.add_theme_stylebox_override("panel", _equipment_panel_style(accent, is_drag_target))
		panel.modulate = Color.WHITE
		if not _equipment_drag_id.is_empty() and not is_drag_target:
			panel.modulate = Color(0.68, 0.68, 0.68, 1.0)

func _equipment_slot_accepts_drag(slot: String, equipment_id: String) -> bool:
	var native_slot: String = GameData.equipment_slot(equipment_id)
	if native_slot == slot:
		return true
	return slot == "trinket" and not native_slot.is_empty() and _run_engine.has_run_skill(_run_state, "open_arsenal")

func _equipment_slot_at(mouse_position: Vector2) -> String:
	for slot_var: Variant in _equipment_slot_panels.keys():
		var slot: String = str(slot_var)
		var panel_var: Variant = _equipment_slot_panels.get(slot, null)
		if typeof(panel_var) != TYPE_OBJECT or not is_instance_valid(panel_var) or not (panel_var is Control):
			continue
		var panel: Control = panel_var as Control
		if panel.get_global_rect().has_point(mouse_position):
			return slot
	return ""

func _equipment_held_proxy_global_rect() -> Rect2:
	if not _node_is_alive(_equipment_held_proxy):
		return Rect2()
	return _equipment_held_proxy.get_global_rect()

func _equipment_icon_rect_for_control(control: Control) -> Rect2:
	if control == null or not control.is_inside_tree():
		return Rect2()
	var icon_node: Node = control.find_child("EquipmentIconChip", true, false)
	if icon_node is Control:
		var icon_control: Control = icon_node as Control
		var icon_rect: Rect2 = icon_control.get_global_rect()
		if icon_rect.size.x > 0.0 and icon_rect.size.y > 0.0:
			return icon_rect
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()
	return _rect_from_center(rect.get_center(), EQUIPMENT_ICON_SIZE)

func _equipment_inventory_icon_rect(equipment_id: String) -> Rect2:
	var tile_var: Variant = _equipment_inventory_tiles.get(equipment_id, null)
	if typeof(tile_var) != TYPE_OBJECT or not is_instance_valid(tile_var) or not (tile_var is Control):
		return Rect2()
	var tile: Control = tile_var as Control
	return _equipment_icon_rect_for_control(tile)

func _equipment_slot_icon_rect(slot: String) -> Rect2:
	var panel_var: Variant = _equipment_slot_panels.get(slot, null)
	if typeof(panel_var) != TYPE_OBJECT or not is_instance_valid(panel_var) or not (panel_var is Control):
		return Rect2()
	var panel: Control = panel_var as Control
	return _equipment_icon_rect_for_control(panel)

func _equipment_fx_local_rect(global_rect: Rect2) -> Rect2:
	if _equipment_fx_layer == null:
		return global_rect
	return Rect2(global_rect.position - _equipment_fx_layer.global_position, global_rect.size)

func _spawn_equipment_icon_proxy(equipment_id: String, global_rect: Rect2, alpha: float = 0.94) -> Control:
	if _equipment_fx_layer == null or equipment_id.is_empty() or global_rect.size.x <= 0.0 or global_rect.size.y <= 0.0:
		return null
	var local_rect: Rect2 = _equipment_fx_local_rect(global_rect)
	var proxy: PanelContainer = _build_equipment_icon_proxy_panel(equipment_id, local_rect.size)
	proxy.name = "EquipmentSwapProxy"
	proxy.position = local_rect.position
	proxy.size = local_rect.size
	proxy.pivot_offset = local_rect.size * 0.5
	proxy.modulate = Color(1.0, 1.0, 1.0, alpha)
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.z_index = 10
	_equipment_fx_layer.add_child(proxy)
	return proxy

func _animate_equipment_proxy_to_rect(tween: Tween, proxy: Control, global_target_rect: Rect2, duration: float, delay: float = 0.0) -> void:
	if proxy == null or global_target_rect.size.x <= 0.0 or global_target_rect.size.y <= 0.0:
		return
	var target_rect: Rect2 = _equipment_fx_local_rect(global_target_rect)
	tween.tween_property(proxy, "position", target_rect.position, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "size", target_rect.size, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "modulate:a", 1.0, duration * 0.72).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_equipment_swap_fx(equipment_id: String, previous_equipment_id: String, slot: String, source_rect: Rect2, previous_slot_rect: Rect2) -> void:
	if _equipment_fx_layer == null:
		_equipment_swap_animation_active = false
		_clear_equipment_drag_state(false)
		return
	var target_slot_rect: Rect2 = _equipment_slot_icon_rect(slot)
	if target_slot_rect.size.x <= 0.0 or target_slot_rect.size.y <= 0.0:
		target_slot_rect = previous_slot_rect
	var new_start_rect: Rect2 = source_rect
	if new_start_rect.size.x <= 0.0 or new_start_rect.size.y <= 0.0:
		new_start_rect = target_slot_rect
	var new_proxy: Control = _spawn_equipment_icon_proxy(equipment_id, new_start_rect, 0.86)
	if new_proxy != null:
		new_proxy.scale = Vector2(1.10, 1.10)
	var old_proxy: Control = null
	var old_target_rect: Rect2 = Rect2()
	if not previous_equipment_id.is_empty():
		old_target_rect = _equipment_inventory_icon_rect(previous_equipment_id)
		if old_target_rect.size.x > 0.0 and old_target_rect.size.y > 0.0:
			old_proxy = _spawn_equipment_icon_proxy(previous_equipment_id, previous_slot_rect, 0.76)
		if old_proxy != null:
			old_proxy.scale = Vector2(0.96, 0.96)
	if new_proxy == null and old_proxy == null:
		_equipment_swap_animation_active = false
		_clear_equipment_drag_state(false)
		return
	_equipment_swap_animation_active = true
	var tween: Tween = create_tween().set_parallel(true)
	_animate_equipment_proxy_to_rect(tween, new_proxy, target_slot_rect, EQUIPMENT_SWAP_SNAP_SECONDS)
	_animate_equipment_proxy_to_rect(tween, old_proxy, old_target_rect, EQUIPMENT_SWAP_RETURN_SECONDS, 0.04)
	await tween.finished
	_queue_free_node_now(new_proxy)
	_queue_free_node_now(old_proxy)
	_equipment_swap_animation_active = false
	_clear_equipment_drag_state(false)
	_pulse_equipment_slot(slot)

func _pulse_equipment_slot(slot: String) -> void:
	var panel_var: Variant = _equipment_slot_panels.get(slot, null)
	if typeof(panel_var) != TYPE_OBJECT or not is_instance_valid(panel_var) or not (panel_var is Control):
		return
	var panel: Control = panel_var as Control
	panel.pivot_offset = panel.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.035, 1.035), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _begin_magic_overlay_drag(source_kind: String, index: int, card_id: String, source_rect: Rect2, source_control: Control = null, mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if card_id.is_empty() or not _magic_overlay_can_change():
		return
	if not (source_kind in ["attuned", "inventory"]):
		return
	if not _magic_drag_card_id.is_empty():
		_clear_magic_drag_state(true)
	_magic_drag_source_kind = source_kind
	_magic_drag_index = index
	_magic_drag_card_id = card_id
	_magic_drag_source_rect = source_rect
	_magic_drag_source_control = source_control
	_magic_drag_last_mouse_position = mouse_position
	if _node_is_alive(_magic_drag_source_control):
		_magic_drag_source_control.modulate = Color(1.0, 1.0, 1.0, 0.34)
	_spawn_magic_held_proxy(card_id, mouse_position)
	_apply_magic_drag_highlights()

func _spawn_magic_held_proxy(card_id: String, mouse_position: Vector2) -> void:
	if _equipment_fx_layer == null:
		return
	if _node_is_alive(_magic_held_proxy):
		_queue_free_node_now(_magic_held_proxy)
	var proxy_size: Vector2 = _magic_drag_source_rect.size if _magic_drag_source_rect.size.x > 0.0 and _magic_drag_source_rect.size.y > 0.0 else EQUIPMENT_DECK_BADGE_SIZE
	_magic_held_proxy = _build_magic_card_proxy_panel(card_id, proxy_size)
	_magic_held_proxy.name = "MagicHeldProxy"
	_magic_held_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_magic_held_proxy.size = proxy_size
	_magic_held_proxy.pivot_offset = proxy_size * 0.5
	_magic_held_proxy.modulate = Color(1.0, 1.0, 1.0, 0.84)
	_magic_held_proxy.z_index = 22
	_equipment_fx_layer.add_child(_magic_held_proxy)
	_update_magic_overlay_drag(mouse_position)

func _build_magic_card_proxy_panel(card_id: String, proxy_size: Vector2) -> PanelContainer:
	var card: Dictionary = GameData.card_def(card_id)
	var accent: Color = ElementData.accent(GameData.card_element(card_id))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = proxy_size
	panel.size = proxy_size
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _equipment_drag_ghost_style(accent))
	panel.add_child(_build_card_art_badge_content(card, accent, str(card.get("name", card_id))))
	return panel

func _update_magic_overlay_drag(mouse_position: Vector2) -> void:
	if _magic_drag_card_id.is_empty() or not _node_is_alive(_magic_held_proxy):
		return
	var local_mouse: Vector2 = mouse_position
	if local_mouse.x < 0.0 or local_mouse.y < 0.0:
		local_mouse = _current_mouse_position()
	_magic_drag_last_mouse_position = local_mouse
	_magic_held_proxy.position = local_mouse + MAGIC_DRAG_CURSOR_OFFSET - _magic_held_proxy.size * 0.5 - _equipment_fx_layer.global_position

func _release_magic_overlay_drag(mouse_position: Vector2) -> void:
	if _magic_drag_card_id.is_empty() or _magic_drag_release_in_progress:
		return
	_magic_drag_release_in_progress = true
	_update_magic_overlay_drag(mouse_position)
	var target: Dictionary = _magic_drop_target_for_release(mouse_position)
	if not target.is_empty() and _magic_drag_can_swap_with(target):
		var inventory_index: int = int(target.get("index", -1)) if str(target.get("source_kind", "")) == "inventory" else _magic_drag_index
		var attuned_index: int = int(target.get("index", -1)) if str(target.get("source_kind", "")) == "attuned" else _magic_drag_index
		var target_rect: Rect2 = _magic_tile_rect(str(target.get("source_kind", "")), int(target.get("index", -1)))
		if _node_is_alive(_magic_held_proxy) and target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
			await _animate_magic_proxy_to_rect(_magic_held_proxy, target_rect, 0.10)
		await _swap_magic_from_overlay(inventory_index, attuned_index)
		return
	await _cancel_magic_overlay_drag(true)

func _cancel_magic_overlay_drag(animate: bool = true) -> void:
	if _magic_drag_card_id.is_empty():
		return
	var proxy: Control = _magic_held_proxy
	if animate and _node_is_alive(proxy) and _magic_drag_source_rect.size.x > 0.0 and _magic_drag_source_rect.size.y > 0.0:
		await _animate_magic_proxy_to_rect(proxy, _magic_drag_source_rect, 0.12)
	_clear_magic_drag_state(true)

func _clear_magic_drag_state(restore_source: bool) -> void:
	_magic_drag_release_in_progress = false
	if restore_source and _node_is_alive(_magic_drag_source_control):
		_magic_drag_source_control.modulate = Color.WHITE
	if _node_is_alive(_magic_held_proxy):
		_queue_free_node_now(_magic_held_proxy)
	_magic_held_proxy = null
	_magic_drag_source_kind = ""
	_magic_drag_index = -1
	_magic_drag_card_id = ""
	_magic_drag_source_rect = Rect2()
	_magic_drag_source_control = null
	_magic_drag_last_mouse_position = Vector2(-1.0, -1.0)
	_apply_magic_drag_highlights()

func _animate_magic_proxy_to_rect(proxy: Control, global_target_rect: Rect2, duration: float) -> void:
	if proxy == null or global_target_rect.size.x <= 0.0 or global_target_rect.size.y <= 0.0:
		return
	var tween: Tween = create_tween().set_parallel(true)
	_animate_equipment_proxy_to_rect(tween, proxy, global_target_rect, duration)
	await tween.finished

func _magic_drag_can_swap_with(target: Dictionary) -> bool:
	var target_kind: String = str(target.get("source_kind", ""))
	var target_index: int = int(target.get("index", -1))
	if _magic_drag_source_kind.is_empty() or target_kind.is_empty() or target_index < 0:
		return false
	if _magic_drag_source_kind == target_kind:
		return false
	return (_magic_drag_source_kind == "inventory" and target_kind == "attuned") or (_magic_drag_source_kind == "attuned" and target_kind == "inventory")

func _magic_tile_at(mouse_position: Vector2) -> Dictionary:
	for index_var: Variant in _magic_attuned_tiles.keys():
		var index: int = int(index_var)
		var tile: Control = _magic_tile_control("attuned", index)
		if tile != null and tile.get_global_rect().has_point(mouse_position):
			return {"source_kind": "attuned", "index": index}
	for index_var: Variant in _magic_inventory_tiles.keys():
		var index: int = int(index_var)
		var tile: Control = _magic_tile_control("inventory", index)
		if tile != null and tile.get_global_rect().has_point(mouse_position):
			return {"source_kind": "inventory", "index": index}
	return {}

func _magic_drop_target_for_release(mouse_position: Vector2) -> Dictionary:
	var target: Dictionary = _magic_tile_at(mouse_position)
	if not target.is_empty():
		return target
	if _magic_drag_last_mouse_position.x >= 0.0 and _magic_drag_last_mouse_position.y >= 0.0:
		target = _magic_tile_at(_magic_drag_last_mouse_position)
		if not target.is_empty():
			return target
	if not _node_is_alive(_magic_held_proxy):
		return {}
	var proxy_rect: Rect2 = _magic_held_proxy.get_global_rect()
	var best_target: Dictionary = {}
	var best_overlap: float = 0.0
	for source_kind: String in ["attuned", "inventory"]:
		var tiles: Dictionary = _magic_attuned_tiles if source_kind == "attuned" else _magic_inventory_tiles
		for index_var: Variant in tiles.keys():
			var index: int = int(index_var)
			var candidate: Dictionary = {"source_kind": source_kind, "index": index}
			if not _magic_drag_can_swap_with(candidate):
				continue
			var tile: Control = _magic_tile_control(source_kind, index)
			if tile == null:
				continue
			var overlap: float = _rect_overlap_area(proxy_rect, tile.get_global_rect())
			if overlap > best_overlap:
				best_overlap = overlap
				best_target = candidate
	if not best_target.is_empty():
		return best_target
	return _magic_panel_fallback_target(mouse_position, proxy_rect)

func _magic_panel_fallback_target(mouse_position: Vector2, proxy_rect: Rect2) -> Dictionary:
	var target_kind: String = "attuned" if _magic_drag_source_kind == "inventory" else "inventory"
	var panel: Control = _magic_attuned_drop_panel if target_kind == "attuned" else _magic_inventory_drop_panel
	if panel == null or not is_instance_valid(panel):
		return {}
	var panel_rect: Rect2 = panel.get_global_rect()
	var overlaps_panel: bool = panel_rect.has_point(mouse_position) or _rect_overlap_area(proxy_rect, panel_rect) > 0.0
	if not overlaps_panel:
		return {}
	return _nearest_magic_tile_target(target_kind, proxy_rect.get_center())

func _nearest_magic_tile_target(source_kind: String, point: Vector2) -> Dictionary:
	var tiles: Dictionary = _magic_attuned_tiles if source_kind == "attuned" else _magic_inventory_tiles
	var best_target: Dictionary = {}
	var best_distance: float = 1.0e20
	for index_var: Variant in tiles.keys():
		var index: int = int(index_var)
		var candidate: Dictionary = {"source_kind": source_kind, "index": index}
		if not _magic_drag_can_swap_with(candidate):
			continue
		var tile: Control = _magic_tile_control(source_kind, index)
		if tile == null:
			continue
		var distance: float = point.distance_squared_to(tile.get_global_rect().get_center())
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var left: float = maxf(a.position.x, b.position.x)
	var top: float = maxf(a.position.y, b.position.y)
	var right: float = minf(a.position.x + a.size.x, b.position.x + b.size.x)
	var bottom: float = minf(a.position.y + a.size.y, b.position.y + b.size.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)

func _magic_tile_rect(source_kind: String, index: int) -> Rect2:
	var tile: Control = _magic_tile_control(source_kind, index)
	return tile.get_global_rect() if tile != null else Rect2()

func _magic_tile_control(source_kind: String, index: int) -> Control:
	var tile_var: Variant = null
	if source_kind == "attuned":
		tile_var = _magic_attuned_tiles.get(index, null)
	else:
		tile_var = _magic_inventory_tiles.get(index, null)
	if typeof(tile_var) != TYPE_OBJECT or not is_instance_valid(tile_var) or not (tile_var is Control):
		return null
	return tile_var as Control

func _apply_magic_drag_highlights() -> void:
	for source_kind: String in ["attuned", "inventory"]:
		var tiles: Dictionary = _magic_attuned_tiles if source_kind == "attuned" else _magic_inventory_tiles
		for index_var: Variant in tiles.keys():
			var index: int = int(index_var)
			var tile: Control = _magic_tile_control(source_kind, index)
			if tile == null:
				continue
			var card_id: String = str(tile.get("card_id"))
			var accent: Color = ElementData.accent(GameData.card_element(card_id))
			var can_receive: bool = not _magic_drag_card_id.is_empty() and _magic_drag_source_kind != source_kind
			tile.add_theme_stylebox_override("panel", _equipment_panel_style(accent, can_receive))
			if _magic_drag_source_kind == source_kind and _magic_drag_index == index:
				tile.modulate = Color(1.0, 1.0, 1.0, 0.34)
			else:
				tile.modulate = Color.WHITE if can_receive or _magic_drag_card_id.is_empty() else Color(0.72, 0.72, 0.72, 1.0)

func _begin_item_overlay_drag(source_kind: String, index: int, card_id: String, source_rect: Rect2, source_control: Control = null, mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if card_id.is_empty() or not _item_overlay_can_change():
		return
	if not (source_kind in ["equipped", "inventory"]):
		return
	if not _item_drag_card_id.is_empty():
		_clear_item_drag_state(true)
	_item_drag_source_kind = source_kind
	_item_drag_index = index
	_item_drag_card_id = card_id
	_item_drag_source_rect = source_rect
	_item_drag_source_control = source_control
	_item_drag_last_mouse_position = mouse_position
	if _node_is_alive(_item_drag_source_control):
		_item_drag_source_control.modulate = Color(1.0, 1.0, 1.0, 0.34)
	_spawn_item_held_proxy(card_id, mouse_position)
	_apply_item_drag_highlights()

func _spawn_item_held_proxy(card_id: String, mouse_position: Vector2) -> void:
	if _equipment_fx_layer == null:
		return
	if _node_is_alive(_item_held_proxy):
		_queue_free_node_now(_item_held_proxy)
	var proxy_size: Vector2 = _item_drag_source_rect.size if _item_drag_source_rect.size.x > 0.0 and _item_drag_source_rect.size.y > 0.0 else ITEM_INVENTORY_TILE_SIZE
	_item_held_proxy = _build_item_card_proxy_panel(card_id, proxy_size)
	_item_held_proxy.name = "ItemHeldProxy"
	_item_held_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_held_proxy.size = proxy_size
	_item_held_proxy.pivot_offset = proxy_size * 0.5
	_item_held_proxy.modulate = Color(1.0, 1.0, 1.0, 0.84)
	_item_held_proxy.z_index = 23
	_equipment_fx_layer.add_child(_item_held_proxy)
	_update_item_overlay_drag(mouse_position)

func _update_item_overlay_drag(mouse_position: Vector2) -> void:
	if _item_drag_card_id.is_empty() or not _node_is_alive(_item_held_proxy):
		return
	var local_mouse: Vector2 = mouse_position
	if local_mouse.x < 0.0 or local_mouse.y < 0.0:
		local_mouse = _current_mouse_position()
	_item_drag_last_mouse_position = local_mouse
	_item_held_proxy.position = local_mouse + ITEM_DRAG_CURSOR_OFFSET - _item_held_proxy.size * 0.5 - _equipment_fx_layer.global_position

func _release_item_overlay_drag(mouse_position: Vector2) -> void:
	if _item_drag_card_id.is_empty() or _item_drag_release_in_progress:
		return
	_item_drag_release_in_progress = true
	_update_item_overlay_drag(mouse_position)
	var target: Dictionary = _item_drop_target_for_release(mouse_position)
	if not target.is_empty() and _item_drag_can_drop_on(target):
		var target_kind: String = str(target.get("source_kind", ""))
		var target_index: int = int(target.get("index", -1))
		var target_rect: Rect2 = _item_tile_rect(target_kind, target_index)
		if _node_is_alive(_item_held_proxy) and target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
			await _animate_magic_proxy_to_rect(_item_held_proxy, target_rect, 0.10)
		if _item_drag_source_kind == "inventory" and target_kind == "equipped":
			await _equip_item_from_overlay(_item_drag_index, target_index)
		elif _item_drag_source_kind == "equipped" and target_kind == "inventory":
			await _unequip_item_from_overlay(_item_drag_index)
		return
	await _cancel_item_overlay_drag(true)

func _cancel_item_overlay_drag(animate: bool = true) -> void:
	if _item_drag_card_id.is_empty():
		return
	var proxy: Control = _item_held_proxy
	if animate and _node_is_alive(proxy) and _item_drag_source_rect.size.x > 0.0 and _item_drag_source_rect.size.y > 0.0:
		await _animate_magic_proxy_to_rect(proxy, _item_drag_source_rect, 0.12)
	_clear_item_drag_state(true)

func _clear_item_drag_state(restore_source: bool) -> void:
	_item_drag_release_in_progress = false
	if restore_source and _node_is_alive(_item_drag_source_control):
		_item_drag_source_control.modulate = Color.WHITE
	if _node_is_alive(_item_held_proxy):
		_queue_free_node_now(_item_held_proxy)
	_item_held_proxy = null
	_item_drag_source_kind = ""
	_item_drag_index = -1
	_item_drag_card_id = ""
	_item_drag_source_rect = Rect2()
	_item_drag_source_control = null
	_item_drag_last_mouse_position = Vector2(-1.0, -1.0)
	_apply_item_drag_highlights()

func _item_drag_can_drop_on(target: Dictionary) -> bool:
	var target_kind: String = str(target.get("source_kind", ""))
	var target_index: int = int(target.get("index", -1))
	if _item_drag_source_kind.is_empty() or target_kind.is_empty():
		return false
	if _item_drag_source_kind == "inventory":
		return target_kind == "equipped" and _item_equipped_slot_can_receive(target_index)
	if _item_drag_source_kind == "equipped":
		return target_kind == "inventory"
	return false

func _item_equipped_slot_can_receive(index: int) -> bool:
	if index < 0 or index >= GameData.item_loadout_limit():
		return false
	var equipped: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	if index < equipped.size():
		return true
	return equipped.size() < GameData.item_loadout_limit() and index == equipped.size()

func _item_tile_at(mouse_position: Vector2) -> Dictionary:
	for index_var: Variant in _item_equipped_tiles.keys():
		var index: int = int(index_var)
		var tile: Control = _item_tile_control("equipped", index)
		if tile != null and tile.get_global_rect().has_point(mouse_position):
			return {"source_kind": "equipped", "index": index}
	for index_var: Variant in _item_inventory_tiles.keys():
		var index: int = int(index_var)
		var tile: Control = _item_tile_control("inventory", index)
		if tile != null and tile.get_global_rect().has_point(mouse_position):
			return {"source_kind": "inventory", "index": index}
	return {}

func _item_drop_target_for_release(mouse_position: Vector2) -> Dictionary:
	var target: Dictionary = _item_tile_at(mouse_position)
	if not target.is_empty() and _item_drag_can_drop_on(target):
		return target
	if _item_drag_last_mouse_position.x >= 0.0 and _item_drag_last_mouse_position.y >= 0.0:
		target = _item_tile_at(_item_drag_last_mouse_position)
		if not target.is_empty() and _item_drag_can_drop_on(target):
			return target
	if not _node_is_alive(_item_held_proxy):
		return {}
	var proxy_rect: Rect2 = _item_held_proxy.get_global_rect()
	var best_target: Dictionary = {}
	var best_overlap: float = 0.0
	for source_kind: String in ["equipped", "inventory"]:
		var tiles: Dictionary = _item_equipped_tiles if source_kind == "equipped" else _item_inventory_tiles
		for index_var: Variant in tiles.keys():
			var index: int = int(index_var)
			var candidate: Dictionary = {"source_kind": source_kind, "index": index}
			if not _item_drag_can_drop_on(candidate):
				continue
			var tile: Control = _item_tile_control(source_kind, index)
			if tile == null:
				continue
			var overlap: float = _rect_overlap_area(proxy_rect, tile.get_global_rect())
			if overlap > best_overlap:
				best_overlap = overlap
				best_target = candidate
	if not best_target.is_empty():
		return best_target
	if _item_drag_source_kind == "equipped" and _item_inventory_drop_panel != null and is_instance_valid(_item_inventory_drop_panel):
		var panel_rect: Rect2 = _item_inventory_drop_panel.get_global_rect()
		if panel_rect.has_point(mouse_position) or _rect_overlap_area(proxy_rect, panel_rect) > 0.0:
			return {"source_kind": "inventory", "index": -1}
	return {}

func _item_tile_rect(source_kind: String, index: int) -> Rect2:
	var tile: Control = _item_tile_control(source_kind, index)
	if tile != null:
		return tile.get_global_rect()
	if source_kind == "inventory" and _item_inventory_drop_panel != null and is_instance_valid(_item_inventory_drop_panel):
		return _item_inventory_drop_panel.get_global_rect()
	return Rect2()

func _apply_item_drag_highlights() -> void:
	for source_kind: String in ["equipped", "inventory"]:
		var tiles: Dictionary = _item_equipped_tiles if source_kind == "equipped" else _item_inventory_tiles
		for index_var: Variant in tiles.keys():
			var index: int = int(index_var)
			var tile: Control = _item_tile_control(source_kind, index)
			if tile == null:
				continue
			var card_id: String = str((tile as EquipmentCardBadge).card_id) if tile is EquipmentCardBadge else ""
			var accent: Color = _item_card_accent(card_id) if not card_id.is_empty() else Color("4f453b")
			var can_receive: bool = _item_drag_can_drop_on({"source_kind": source_kind, "index": index})
			if tile is PanelContainer:
				(tile as PanelContainer).add_theme_stylebox_override("panel", _equipment_panel_style(accent, can_receive))
			if _item_drag_source_kind == source_kind and _item_drag_index == index:
				tile.modulate = Color(1.0, 1.0, 1.0, 0.34)
			elif not _item_drag_card_id.is_empty() and not can_receive:
				tile.modulate = Color(0.72, 0.72, 0.72, 1.0)
			else:
				tile.modulate = Color.WHITE

func _swap_magic_from_overlay(inventory_index: int, attuned_index: int) -> void:
	if not _magic_overlay_can_change():
		_clear_magic_drag_state(true)
		return
	var reserve: Array = (_run_state.get("magic_inventory", []) as Array).duplicate()
	if inventory_index < 0 or inventory_index >= reserve.size():
		_clear_magic_drag_state(true)
		return
	var incoming_card_id: String = str(reserve[inventory_index])
	_run_state = _run_engine.swap_magic_card(_run_state, inventory_index, attuned_index)
	var attuned: Array = _run_state.get("attuned_magic_cards", []) as Array
	if attuned_index < 0 or attuned_index >= attuned.size() or str(attuned[attuned_index]) != incoming_card_id:
		_clear_magic_drag_state(true)
		return
	_persist_committed_boundary("magic_attuned")
	_analytics_log_magic_attuned(inventory_index, attuned_index, incoming_card_id)
	_clear_magic_drag_state(false)
	_refresh_ui()
	_progression_overlay_mode = "magic"
	_rebuild_progression_overlay()
	await get_tree().process_frame
	_pulse_magic_tile("attuned", attuned_index)

func _equip_item_from_overlay(inventory_index: int, equipped_index: int = -1) -> void:
	if _item_swap_animation_active or not _item_overlay_can_change():
		return
	var inventory: Array = (_run_state.get("item_inventory", []) as Array).duplicate()
	if inventory_index < 0 or inventory_index >= inventory.size():
		return
	var card_id: String = str(inventory[inventory_index])
	if card_id.is_empty():
		return
	_item_swap_animation_active = true
	var before_inventory: Array = inventory.duplicate()
	var before_equipped: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	_run_state = _run_engine.equip_item_card(_run_state, inventory_index, equipped_index)
	var after_inventory: Array = (_run_state.get("item_inventory", []) as Array).duplicate()
	var after_equipped: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	if JSON.stringify(before_inventory) == JSON.stringify(after_inventory) and JSON.stringify(before_equipped) == JSON.stringify(after_equipped):
		_clear_item_drag_state(true)
		_item_swap_animation_active = false
		return
	_persist_committed_boundary("item_equipped")
	var actual_equipped_index: int = _equipped_item_index_after_change(card_id, before_equipped, after_equipped, equipped_index)
	_analytics_log_item_equipped("equip", card_id, inventory_index, actual_equipped_index)
	_clear_item_drag_state(false)
	_refresh_ui()
	_progression_overlay_mode = "equipment"
	_rebuild_progression_overlay()
	await get_tree().process_frame
	_pulse_item_tile("equipped", actual_equipped_index)
	_item_swap_animation_active = false

func _unequip_item_from_overlay(equipped_index: int) -> void:
	if _item_swap_animation_active or not _item_overlay_can_change():
		return
	var equipped: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	if equipped_index < 0 or equipped_index >= equipped.size():
		return
	var card_id: String = str(equipped[equipped_index])
	if card_id.is_empty():
		return
	_item_swap_animation_active = true
	var before_inventory: Array = (_run_state.get("item_inventory", []) as Array).duplicate()
	var before_equipped: Array = equipped.duplicate()
	_run_state = _run_engine.unequip_item_card(_run_state, equipped_index)
	var after_inventory: Array = (_run_state.get("item_inventory", []) as Array).duplicate()
	var after_equipped: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	if JSON.stringify(before_inventory) == JSON.stringify(after_inventory) and JSON.stringify(before_equipped) == JSON.stringify(after_equipped):
		_clear_item_drag_state(true)
		_item_swap_animation_active = false
		return
	_persist_committed_boundary("item_stowed")
	var inventory_index: int = max(0, after_inventory.size() - 1)
	_analytics_log_item_equipped("stow", card_id, inventory_index, equipped_index)
	_clear_item_drag_state(false)
	_refresh_ui()
	_progression_overlay_mode = "equipment"
	_rebuild_progression_overlay()
	await get_tree().process_frame
	_pulse_item_tile("inventory", inventory_index)
	_item_swap_animation_active = false

func _equipped_item_index_after_change(card_id: String, before_equipped: Array, after_equipped: Array, preferred_index: int = -1) -> int:
	if preferred_index >= 0 and preferred_index < after_equipped.size() and str(after_equipped[preferred_index]) == card_id:
		return preferred_index
	for index: int in range(after_equipped.size()):
		if str(after_equipped[index]) != card_id:
			continue
		if index >= before_equipped.size() or str(before_equipped[index]) != card_id:
			return index
	return after_equipped.find(card_id)

func _item_tile_control(source_kind: String, index: int) -> Control:
	var tile_var: Variant = _item_equipped_tiles.get(index, null) if source_kind == "equipped" else _item_inventory_tiles.get(index, null)
	if typeof(tile_var) != TYPE_OBJECT or not is_instance_valid(tile_var) or not (tile_var is Control):
		return null
	return tile_var as Control

func _pulse_item_tile(source_kind: String, index: int) -> void:
	var tile: Control = _item_tile_control(source_kind, index)
	if tile == null:
		return
	tile.pivot_offset = tile.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(tile, "scale", Vector2(1.05, 1.05), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _pulse_magic_tile(source_kind: String, index: int) -> void:
	var tile: Control = _magic_tile_control(source_kind, index)
	if tile == null:
		return
	tile.pivot_offset = tile.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(tile, "scale", Vector2(1.05, 1.05), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _build_merchant_item_tooltip_panel(merchant_kind: String, item_id: String, interactive: bool = false) -> Control:
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		return _build_equipment_tooltip_panel(item_id, interactive)
	return _build_card_tooltip_panel(item_id, interactive)

func _build_card_tooltip_panel(card_id: String, interactive: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_TOOLTIP_SIZE + Vector2(18.0, 18.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(ElementData.accent(GameData.card_element(card_id)), true))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	margin.add_child(_build_card_preview_widget(card_id, CARD_TOOLTIP_SIZE, interactive))
	return panel

func _build_equipment_tooltip_panel(equipment_id: String, interactive: bool = false) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var accent := Color(GameData.equipment_accent(equipment_id))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(accent, true))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 9)
	vbox.add_child(header)
	var icon := TextureRect.new()
	icon.texture = AssetLoader.load_texture(str(item.get("icon_path", "")))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(42.0, 42.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)
	var name_label := Label.new()
	name_label.text = str(item.get("name", equipment_id))
	UiTypography.set_label_size(name_label, UiTypography.SIZE_SMALL)
	name_label.add_theme_color_override("font_color", Color("fff0ce"))
	name_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	name_label.add_theme_constant_override("outline_size", 1)
	title_box.add_child(name_label)
	var meta_label := Label.new()
	meta_label.text = "%s | %s" % [_equipment_slot_label(GameData.equipment_slot(equipment_id)), _equipment_rarity_label(GameData.equipment_rarity(equipment_id))]
	UiTypography.set_label_size(meta_label, UiTypography.SIZE_CAPTION)
	meta_label.add_theme_color_override("font_color", Color("d7c6aa"))
	title_box.add_child(meta_label)

	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	card_row.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	vbox.add_child(card_row)
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		card_row.add_child(_build_card_preview_widget(str(card_id_var), EQUIPMENT_TOOLTIP_CARD_SIZE, interactive))
	if not _equipment_overlay_can_change():
		var locked_label := Label.new()
		locked_label.text = "Locked in combat"
		UiTypography.set_label_size(locked_label, UiTypography.SIZE_CAPTION)
		locked_label.add_theme_color_override("font_color", Color("d8a06a"))
		vbox.add_child(locked_label)
	return panel

func _build_card_preview_widget(card_id: String, card_size: Vector2, interactive: bool = false) -> Control:
	card_size = _normalized_card_size(card_size)
	var widget := CardWidgetScene.instantiate() as CardWidget
	widget.focus_mode = Control.FOCUS_NONE
	widget.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	widget.configure(card_id, false, false, true, false, interactive, true, _card_def(card_id))
	return _scaled_card_slot(widget, card_size, interactive)

func _equipment_inventory_ids() -> Array:
	var inventory: Array = (_run_state.get("equipment_inventory", []) as Array).duplicate()
	var sorted_ids: Array = []
	for slot: String in GameData.equipment_slots():
		var slot_ids: Array = []
		for equipment_id_var: Variant in inventory:
			var equipment_id: String = str(equipment_id_var)
			if GameData.equipment_slot(equipment_id) == slot:
				slot_ids.append(equipment_id)
		slot_ids.sort()
		sorted_ids.append_array(slot_ids)
	return sorted_ids

func _item_inventory_ids() -> Array:
	var result: Array = []
	for card_id_var: Variant in _run_state.get("item_inventory", []):
		var card_id: String = str(card_id_var)
		if GameData.card_is_item(card_id):
			result.append(card_id)
	return result

func _equipment_overlay_can_change() -> bool:
	return _run_engine.can_change_equipment(_run_state)

func _item_overlay_can_change() -> bool:
	return _progression_overlay_mode == "equipment" and _run_engine.can_change_items(_run_state)

func _magic_overlay_can_change() -> bool:
	return _progression_overlay_mode == "magic" and _run_engine.can_change_magic(_run_state)

func _magic_overlay_drag_active() -> bool:
	return not _magic_drag_card_id.is_empty()

func _item_overlay_drag_active() -> bool:
	return not _item_drag_card_id.is_empty()

func _can_drop_equipment_data(slot: String, data: Variant) -> bool:
	if not _equipment_overlay_can_change() or typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data as Dictionary
	if str(payload.get("kind", "")) != "equipment":
		return false
	var equipment_id: String = str(payload.get("equipment_id", ""))
	return _equipment_slot_accepts_drag(slot, equipment_id)

func _equip_equipment_from_overlay(equipment_id: String, drop_slot: String = "", drop_rect: Rect2 = Rect2()) -> void:
	if equipment_id.is_empty() or not _equipment_overlay_can_change():
		return
	var native_slot: String = GameData.equipment_slot(equipment_id)
	var slot: String = native_slot if drop_slot.is_empty() else drop_slot
	if native_slot.is_empty() or not _equipment_slot_accepts_drag(slot, equipment_id):
		return
	var before_equipped: Dictionary = (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
	var before_id: String = str(before_equipped.get(slot, ""))
	var source_rect: Rect2 = _equipment_drag_source_rect
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		source_rect = _equipment_inventory_icon_rect(equipment_id)
	var previous_slot_rect: Rect2 = _equipment_slot_icon_rect(slot)
	if previous_slot_rect.size.x <= 0.0 or previous_slot_rect.size.y <= 0.0:
		previous_slot_rect = drop_rect
	_run_state = _run_engine.equip_equipment(_run_state, equipment_id, slot)
	var after_equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	if str(after_equipped.get(slot, "")) == before_id:
		_clear_equipment_drag_state(true)
		return
	_equipment_swap_animation_active = true
	_persist_committed_boundary("equipment_equipped")
	_analytics_log_equipment_equipped(slot, before_id, equipment_id)
	_refresh_ui()
	_progression_overlay_mode = "equipment"
	_rebuild_progression_overlay()
	await get_tree().process_frame
	await get_tree().process_frame
	await _animate_equipment_swap_fx(equipment_id, before_id, slot, source_rect, previous_slot_rect)

func _equipment_tooltip(equipment_id: String) -> String:
	if equipment_id.is_empty():
		return ""
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var lines: Array = [
		str(item.get("name", equipment_id)),
		"%s | %s" % [_equipment_slot_label(GameData.equipment_slot(equipment_id)), _equipment_rarity_label(GameData.equipment_rarity(equipment_id))]
	]
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		var card: Dictionary = GameData.card_def(str(card_id_var))
		lines.append(str(card.get("name", card_id_var)))
	if not _equipment_overlay_can_change():
		lines.append("Locked in combat")
	return "\n".join(lines)

func _equipment_card_summary(equipment_id: String) -> String:
	if equipment_id.is_empty():
		return ""
	var names: Array = []
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		names.append(str(GameData.card_def(str(card_id_var)).get("name", card_id_var)))
	if names.size() <= 1:
		return str(names[0]) if not names.is_empty() else ""
	return "%s, +%d" % [str(names[0]), names.size() - 1]

func _equipment_slot_label(slot: String) -> String:
	match slot:
		"weapon":
			return "Weapon"
		"offhand":
			return "Offhand"
		"armor":
			return "Armor"
		"boots":
			return "Boots"
		"trinket":
			return "Trinket"
	return slot.capitalize()

func _equipment_rarity_label(rarity: String) -> String:
	if rarity == "legendary":
		return "Legendary"
	return rarity.capitalize()

func _equipped_equipment_accent() -> Color:
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	var best_id: String = ""
	var best_rank: int = -1
	for equipment_id_var: Variant in equipped.values():
		var equipment_id: String = str(equipment_id_var)
		var rank: int = _equipment_rarity_rank(GameData.equipment_rarity(equipment_id))
		if rank > best_rank:
			best_rank = rank
			best_id = equipment_id
	if best_id.is_empty():
		return Color("8f6f46")
	return Color(GameData.equipment_accent(best_id))

func _equipment_player_art_tint() -> Color:
	var accent: Color = _equipped_equipment_accent().lightened(0.18)
	return Color(1.0, 0.96, 0.88, 1.0).lerp(accent, 0.16)

func _equipment_rarity_rank(rarity: String) -> int:
	match rarity:
		"legendary":
			return 3
		"epic":
			return 2
		"rare":
			return 1
	return 0

func _equipment_panel_style(accent: Color, active: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.060, 0.045, 0.96).lightened(0.06 if active else 0.0)
	style.border_color = accent.lightened(0.22 if active else 0.04)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _equipment_icon_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.036, 0.032, 0.92)
	style.border_color = accent.lightened(0.18)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

func _equipment_drag_ghost_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.044, 0.038, 0.72)
	style.border_color = accent.lightened(0.34)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 12
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _apply_progression_icon_button_style(button: Button) -> void:
	if button == null:
		return
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_ICON)
	_apply_progression_button_text(button, UiTypography.SIZE_BODY)

func _apply_progression_command_button_style(button: Button) -> void:
	if button == null:
		return
	var variant: String = UiSkin.VARIANT_SELECTED if button.text == "Confirm" else UiSkin.VARIANT_STANDARD
	_ui_skin.apply_button_stylebox_overrides(button, variant)
	_apply_progression_button_text(button, UiTypography.SIZE_SMALL)

func _apply_progression_button_text(button: Button, font_size: int) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_color_override("font_color", Color("ffe8b6"))
	button.add_theme_color_override("font_hover_color", Color("fff4d2"))
	button.add_theme_color_override("font_focus_color", Color("fff4d2"))
	button.add_theme_color_override("font_pressed_color", Color("f5c179"))
	button.add_theme_color_override("font_disabled_color", Color("928a7d"))
	button.add_theme_color_override("font_outline_color", Color("1c120c"))
	button.add_theme_constant_override("outline_size", 2)
	UiTypography.set_button_size(button, font_size)

func _refresh_card_upgrade_overlay() -> void:
	if _upgrade_card_list == null:
		return
	_sync_progression_from_run()
	_upgrade_embers_label.text = "EMBERS %d" % int(_progression.get("embers", 0))
	var card_ids: Array = GameData.upgradeable_card_ids()
	if _upgrade_selected_card_id.is_empty() or not card_ids.has(_upgrade_selected_card_id):
		_upgrade_selected_card_id = str(card_ids[0]) if not card_ids.is_empty() else ""
	_upgrade_refresh_card_list(card_ids)
	_upgrade_refresh_element_list()
	_upgrade_refresh_options()

func _upgrade_refresh_card_list(card_ids: Array) -> void:
	_clear_children(_upgrade_card_list)
	for card_id_var: Variant in card_ids:
		var card_id: String = str(card_id_var)
		var card: Dictionary = GameData.card_def(card_id)
		var label: String = str(card.get("name", card_id))
		var button := _upgrade_list_button(label, card_id == _upgrade_selected_card_id)
		button.pressed.connect(_on_upgrade_card_selected.bind(card_id))
		_upgrade_card_list.add_child(button)

func _upgrade_refresh_element_list() -> void:
	_clear_children(_upgrade_element_list)
	var elements: Array = GameData.upgradeable_elements_for_card(_upgrade_selected_card_id, _progression)
	if elements.is_empty():
		_upgrade_selected_element_key = ""
		return
	var has_selected: bool = false
	for element_var: Variant in elements:
		var element: Dictionary = element_var
		if str(element.get("key", "")) == _upgrade_selected_element_key:
			has_selected = true
			break
	if not has_selected:
		_upgrade_selected_element_key = str((elements[0] as Dictionary).get("key", ""))
	for element_var: Variant in elements:
		var element: Dictionary = element_var
		var selected: bool = str(element.get("key", "")) == _upgrade_selected_element_key
		var button := _upgrade_list_button(str(element.get("label", "Part")), selected)
		button.pressed.connect(_on_upgrade_element_selected.bind(element))
		_upgrade_element_list.add_child(button)

func _upgrade_refresh_options() -> void:
	_clear_children(_upgrade_option_list)
	_clear_children(_upgrade_preview_box)
	if _upgrade_selected_card_id.is_empty():
		return
	var current_card: Dictionary = GameData.card_def_for_progression(_upgrade_selected_card_id, _progression)
	var current_widget := CardWidgetScene.instantiate() as CardWidget
	current_widget.configure(_upgrade_selected_card_id, false, false, true, false, false, true, current_card)
	current_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_preview_box.add_child(_scaled_card_slot(current_widget, UPGRADE_CARD_SIZE))
	var element: Dictionary = _selected_upgrade_element()
	if element.is_empty():
		return
	var options: Array = GameData.upgrade_options_for_element(_upgrade_selected_card_id, element, _progression)
	for option_var: Variant in options:
		var option: Dictionary = option_var
		_upgrade_option_list.add_child(_build_upgrade_option_row(option))

func _selected_upgrade_element() -> Dictionary:
	for element_var: Variant in GameData.upgradeable_elements_for_card(_upgrade_selected_card_id, _progression):
		var element: Dictionary = element_var
		if str(element.get("key", "")) == _upgrade_selected_element_key:
			return element
	return {}

func _build_upgrade_option_row(option: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var preview_card: Dictionary = GameData.preview_card_with_mod(_upgrade_selected_card_id, option, _progression)
	var preview_widget := CardWidgetScene.instantiate() as CardWidget
	preview_widget.configure(_upgrade_selected_card_id, false, false, true, false, false, true, preview_card)
	preview_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_scaled_card_slot(preview_widget, UPGRADE_CARD_SIZE))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)

	var title := Label.new()
	title.text = str(option.get("label", "Upgrade"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 1)
	info.add_child(title)

	var cost_label := Label.new()
	cost_label.text = "Cost %d embers" % int(option.get("cost", 0))
	UiTypography.set_label_size(cost_label, UiTypography.SIZE_CAPTION)
	cost_label.add_theme_color_override("font_color", Color("cdbca2"))
	info.add_child(cost_label)

	var button := Button.new()
	if ProgressionStore.can_purchase_card_mod(_progression, _upgrade_selected_card_id, option):
		button.text = "Confirm"
	else:
		button.text = "Need %d" % int(option.get("cost", 0))
		button.disabled = true
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(button, 42.0, 0.0, true, UiSkin.VARIANT_COMPACT)
	if not button.disabled:
		button.pressed.connect(_on_card_mod_upgrade_pressed.bind(option))
	row.add_child(button)
	return row

func _upgrade_list_button(text: String, selected: bool) -> Button:
	var button := Button.new()
	button.text = text
	var variant: String = UiSkin.VARIANT_SELECTED if selected else UiSkin.VARIANT_STANDARD
	_ui_skin.apply_button_stylebox_overrides(button, variant)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_CAPTION)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_STANDARD, UPGRADE_LIST_BUTTON_MIN_WIDTH, true, variant)
	return button

func _on_upgrade_card_selected(card_id: String) -> void:
	_upgrade_selected_card_id = card_id
	_upgrade_selected_element_key = ""
	_refresh_card_upgrade_overlay()

func _on_upgrade_element_selected(element: Dictionary) -> void:
	_upgrade_selected_element_key = str(element.get("key", ""))
	_refresh_card_upgrade_overlay()

func _on_card_mod_upgrade_pressed(mod: Dictionary) -> void:
	_progression = ProgressionStore.purchase_card_mod(_progression, _upgrade_selected_card_id, mod)
	ProgressionStore.save_data(_progression)
	_run_state["progression"] = _progression.duplicate(true)
	if not _combat_state.is_empty():
		_combat_state["card_upgrades"] = (_progression.get("card_upgrades", {}) as Dictionary).duplicate(true)
		_combat_state["card_mods"] = (_progression.get("card_mods", {}) as Dictionary).duplicate(true)
		_mark_combat_preview_state_changed()
		_run_state["combat_state"] = _combat_state.duplicate(true)
	_persist_committed_boundary("card_upgrade")
	_refresh_card_upgrade_overlay()
	_refresh_ui()

func _cards_for_pile(pile_kind: String) -> Array:
	var piles: Dictionary = _deck_piles()
	var cards: Array = piles.get(pile_kind, []).duplicate()
	if pile_kind == "draw":
		cards.sort_custom(func(a: Variant, b: Variant) -> bool:
			var a_name: String = str(_card_def(str(a)).get("name", str(a)))
			var b_name: String = str(_card_def(str(b)).get("name", str(b)))
			if a_name == b_name:
				return str(a) < str(b)
			return a_name < b_name
		)
		return cards
	cards.reverse()
	return cards

func _pile_display_name(pile_kind: String) -> String:
	return "Exhaust" if pile_kind == "burn" else pile_kind.capitalize()

func _room_title_text(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", "combat"))
	if room_type == "start":
		return "Central Waypoint"
	if room_type == "campfire":
		return "Campfire"
	if room_type == "treasure":
		return "Relic Cache"
	if room_type == "boss":
		return str(room.get("name", "Outer Sanctum"))
	return str(room.get("name", "Chamber"))

func _room_subtitle_text(room: Dictionary) -> String:
	return "Depth %d" % int(room.get("depth", 0))

func _maybe_auto_trigger_room_dialogue() -> void:
	if _dialogue_active or str(_run_state.get("mode", "room")) != "room":
		return
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, _run_state.get("current_room", Vector2i.ZERO))
	var trigger_key: String = _dialogue_trigger_key(current_room)
	if trigger_key == _last_auto_dialogue_key:
		return
	var dialogue: Dictionary = _dialogue_engine.build_room_dialogue(current_room, _run_state, _progression)
	if dialogue.is_empty():
		return
	_last_auto_dialogue_key = trigger_key
	_start_dialogue(dialogue)

func _dialogue_trigger_key(room: Dictionary) -> String:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	return "%d,%d|%d" % [coord.x, coord.y, int(_run_state.get("turns_spent", 0))]

func _new_seed() -> int:
	return int(Time.get_unix_time_from_system()) & 0x7fffffff

func _hand_card_size(card_count: int, reward_mode: bool) -> Vector2:
	var available_width: float = maxf(620.0, hand_scroll.size.x if hand_scroll.size.x > 0.0 else get_viewport_rect().size.x - 280.0)
	var card_gap: float = HAND_CARD_GAP if reward_mode else HAND_CARD_OVERLAP
	var gaps: float = float(maxi(0, card_count - 1)) * card_gap
	var target_width: float = (available_width - gaps) / float(maxi(1, card_count))
	var max_width: float = 224.0 if reward_mode else 204.0
	var min_width: float = 188.0 if reward_mode else 184.0
	var width: float = clampf(target_width, min_width, max_width)
	return _card_size_from_width(width)

func _card_size_from_width(width: float) -> Vector2:
	return Vector2(width, width * CARD_ASPECT_RATIO)

func _normalized_card_size(card_size: Vector2) -> Vector2:
	if card_size.x <= 0.0 and card_size.y <= 0.0:
		return _card_size_from_width(200.0)
	if card_size.x <= 0.0:
		return Vector2(card_size.y / CARD_ASPECT_RATIO, card_size.y)
	if card_size.y <= 0.0:
		return _card_size_from_width(card_size.x)
	var aspect_height: float = card_size.x * CARD_ASPECT_RATIO
	if aspect_height <= card_size.y:
		return Vector2(card_size.x, aspect_height)
	return Vector2(card_size.y / CARD_ASPECT_RATIO, card_size.y)

func _card_id_for_hand_index(index: int) -> String:
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return ""
	return str(hand[index])

func _card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	if not state.is_empty() and (state.has("card_upgrades") or state.has("card_mods") or state.has("skill_ids") or state.has("relics")):
		return GameData.card_def_for_progression(card_id, state)
	if not _progression.is_empty():
		return GameData.card_def_for_progression(card_id, _progression)
	return GameData.card_def(card_id)

func _reset_card_resolution() -> void:
	_clear_action_step_resolution_tracker()
	_clear_active_card_preview_state()
	_clear_card_action_choice_state()

func _clear_active_card_preview_state() -> void:
	_selected_card_index = -1
	_selected_card_label_override = ""
	_hovered_card_index = -1
	_pending_actions.clear()
	_pending_action_index = 0
	_pending_action_can_skip = false
	_pending_target_tiles.clear()
	_pending_selected_targets.clear()
	_pending_umbra_commit_locked = false
	_pending_orientation_target_tile = INVALID_TARGET_TILE
	_aoe_aim_orientation = Vector2i(1, 0)
	_preview_combat_state.clear()
	_hovered_board_tile = Vector2i(-1, -1)
	_mark_preview_selection_changed()

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()

func _clear_children_now(node: Node) -> void:
	for child: Node in node.get_children():
		_prepare_node_for_immediate_free(child)
		node.remove_child(child)
		if _node_is_alive(child):
			child.queue_free()

func _node_is_alive(node) -> bool:
	return node != null and is_instance_valid(node) and node is Node and not (node as Node).is_queued_for_deletion()

func _queue_free_node_now(node) -> void:
	if not _node_is_alive(node):
		return
	_prepare_node_for_immediate_free(node)
	(node as Node).queue_free()

func _prepare_node_for_immediate_free(node) -> void:
	if not _node_is_alive(node):
		return
	if node is CanvasItem:
		var item: CanvasItem = node as CanvasItem
		item.visible = false
		item.top_level = false
	if node is Control:
		var control: Control = node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_prepare_node_for_immediate_free(child)

func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		var control: Control = node as Control
		control.mouse_filter = filter
	for child: Node in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _ensure_run_analytics_metadata(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if next_state.is_empty():
		return next_state
	var analytics: Dictionary = (next_state.get("analytics", {}) as Dictionary).duplicate(true)
	if str(analytics.get("run_id", "")).is_empty():
		analytics["run_id"] = _analytics_random_id("run")
	if not analytics.has("combat_counter"):
		analytics["combat_counter"] = 0
	next_state["analytics"] = analytics
	return next_state

func _analytics_random_id(prefix: String) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return "%s_%d_%08x" % [prefix, Time.get_ticks_usec(), rng.randi()]

func _analytics_context_from_states(run_state: Dictionary, combat_state: Dictionary = {}, card_id: String = "", card_instance_id: String = "") -> Dictionary:
	var room_meta: Dictionary = {}
	if not run_state.is_empty():
		room_meta = _run_engine.room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary) if not combat_state.is_empty() else {}
	var combat_analytics: Dictionary = (combat_state.get("analytics", {}) as Dictionary).duplicate(true)
	var run_analytics: Dictionary = (run_state.get("analytics", {}) as Dictionary).duplicate(true)
	var progression: Dictionary = (run_state.get("progression", _progression) as Dictionary).duplicate(true)
	var context: Dictionary = {
		"run_id": str(run_analytics.get("run_id", "")),
		"combat_id": str(combat_analytics.get("combat_id", "")),
		"turn": int(combat_state.get("turn", 0)),
		"initiative_clock": int(combat_state.get("initiative_clock", 0)),
		"current_actor_kind": str((combat_state.get("current_actor", {}) as Dictionary).get("kind", "")),
		"current_actor_key": str((combat_state.get("current_actor", {}) as Dictionary).get("actor_key", "")),
		"room_depth": int(combat_state.get("room_depth", room_meta.get("depth", 0))),
		"room_element": str(combat_state.get("room_element", room_meta.get("element", ""))),
		"player_hp": int(player.get("hp", run_state.get("player_hp", -1))),
		"player_max_hp": int(player.get("max_hp", run_state.get("player_max_hp", -1))),
		"defiance_capacity": int(combat_state.get(
			RunEngineScript.DEFIANCE_CAPACITY_KEY,
			run_state.get(RunEngineScript.DEFIANCE_CAPACITY_KEY, 0)
		)),
		"defiance_remaining": int(combat_state.get(
			RunEngineScript.DEFIANCE_REMAINING_KEY,
			run_state.get(RunEngineScript.DEFIANCE_REMAINING_KEY, 0)
		)),
		"combat_unit_scale": 1,
		"progression_level": int(progression.get("level", 1)),
		"progression_skills": ProgressionStore.selected_skill_ids(progression),
		"relics": (combat_state.get("relics", run_state.get("relics", [])) as Array).duplicate(true),
		"moltshards": ProgressionStore.moltshard_count(progression),
		"deck_size": int((run_state.get("deck_cards", []) as Array).size()),
		"card_id": card_id,
		"card_instance_id": card_instance_id
	}
	if not combat_state.is_empty():
		context["elemental_intensity"] = _combat_engine.elemental_intensities(combat_state)
		context["umbra_stage"] = _combat_engine.effective_umbra_stage(combat_state)
		context["umbra_radius"] = _combat_engine.effective_umbra_radius(combat_state)
		context["visible_enemy_count"] = _combat_engine.visible_enemy_ids(combat_state).size()
	return context

func _moltshard_gain_idempotency_key(award_id: String) -> String:
	return "%s|%s" % [MOLTSHARD_GAIN_EVENT_TYPE, award_id]

func _reconcile_progression_analytics_outbox() -> bool:
	for entry: Dictionary in ProgressionStore.progression_analytics_outbox(_progression):
		var idempotency_key: String = str(entry.get("idempotency_key", ""))
		var wrote_event: bool = _analytics_store.write_event(
			str(entry.get("event_type", "")),
			entry.get("context", {}) as Dictionary,
			entry.get("payload", {}) as Dictionary,
			idempotency_key
		)
		if not wrote_event:
			return false
		var disk_candidate: Dictionary = ProgressionStore.merge_progression_analytics_outbox(
			_authoritative_profile_progression(),
			_progression
		)
		disk_candidate = ProgressionStore.acknowledge_progression_analytics_event(disk_candidate, idempotency_key)
		if not ProgressionStore.save_data(disk_candidate):
			push_error("Failed to acknowledge progression analytics event: %s" % idempotency_key)
			return false
		var active_candidate: Dictionary = ProgressionStore.acknowledge_progression_analytics_event(
			_progression,
			idempotency_key
		)
		_progression = ProgressionStore.merge_progression_analytics_outbox(active_candidate, disk_candidate)
	return true

func _combat_recovery_marker_amount(combat_state: Dictionary) -> int:
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)):
			continue
		if str(loot.get("kind", "")) == "dropped_embers":
			return maxi(0, int(loot.get("amount", 0)))
	return 0

func _analytics_equipment_loot_ids(combat_state: Dictionary) -> Array:
	var ids: Array = []
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)) or str(loot.get("kind", "")) != "equipment":
			continue
		var equipment_id: String = str(loot.get("equipment_id", ""))
		if not equipment_id.is_empty():
			ids.append(equipment_id)
	return ids

func _analytics_log_run_started() -> void:
	var recovery_marker: Dictionary = ProgressionStore.recovery_marker(_progression)
	_analytics_store.write_event("run_started", _analytics_context_from_states(_run_state, _combat_state), {
		"seed": int(_run_state.get("seed", 0)),
		"run_index": int(_run_state.get("run_index", 0)),
		"player_start_hp": int(_run_state.get("player_hp", 0)),
		"player_max_hp": int(_run_state.get("player_max_hp", 0)),
		"starting_deck": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
		"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
		"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
		"equipped_items": (_run_state.get("equipped_items", []) as Array).duplicate(true),
		"item_inventory": (_run_state.get("item_inventory", []) as Array).duplicate(true),
		"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"collected_equipment": (_run_state.get("collected_equipment", []) as Array).duplicate(true),
		"recovery_marker_active": not recovery_marker.is_empty(),
		"recovery_marker_amount": int(recovery_marker.get("amount", 0)),
		"recovery_marker_coord": ProgressionStore.recovery_coord(_progression) if not recovery_marker.is_empty() else Vector2i(-999, -999)
	})

func _analytics_log_run_resumed() -> void:
	_analytics_store.write_event("run_resumed", _analytics_context_from_states(_run_state, _combat_state), {
		"mode": str(_run_state.get("mode", "room")),
		"turns_spent": int(_run_state.get("turns_spent", 0)),
		"current_room": _run_state.get("current_room", Vector2i.ZERO)
	})
	if str(_run_state.get("mode", "")) == "combat" and not _combat_state.is_empty():
		_analytics_store.write_event("combat_resumed", _analytics_context_from_states(_run_state, _combat_state), {
			"room_name": str(_combat_state.get("room_name", "")),
			"hand": _analytics_zone_cards(_combat_state, "hand")
		})
		_analytics_log_playable_cards()

func _analytics_log_run_ended(outcome: String) -> void:
	if outcome.is_empty() or _run_state.is_empty():
		return
	var run_stats: Dictionary = RunEngineScript.normalized_run_stats(_run_state.get("run_stats", {}))
	_analytics_store.write_event("run_ended", _analytics_context_from_states(_run_state, _combat_state), {
		"outcome": outcome,
		"turns_spent": int(_run_state.get("turns_spent", 0)),
		"held_embers": _run_engine.held_embers(_run_state),
		"mode": str(_run_state.get("mode", "room")),
		"enemies_killed": int(run_stats.get("enemies_killed", 0)),
		"damage_dealt": int(run_stats.get("damage_dealt", 0)),
		"damage_received": int(run_stats.get("damage_received", 0))
	})

func _analytics_log_level_up(before_progression: Dictionary, after_progression: Dictionary) -> void:
	_analytics_store.write_event("progression_level_up", _analytics_context_from_states(_run_state, _combat_state), {
		"level_before": int(before_progression.get("level", 1)),
		"level_after": int(after_progression.get("level", 1)),
		"skill_ids": ProgressionStore.selected_skill_ids(after_progression),
		"unspent_skill_points_before": ProgressionStore.unspent_skill_points(before_progression),
		"unspent_skill_points_after": ProgressionStore.unspent_skill_points(after_progression),
		"cost": ProgressionStore.next_level_cost(before_progression),
		"held_embers_after": int(after_progression.get("embers", 0)),
		"room": _run_state.get("current_room", Vector2i.ZERO)
	})

func _analytics_log_skill_learned(
	before_progression: Dictionary,
	after_progression: Dictionary,
	skill_id: String
) -> void:
	_analytics_store.write_event("progression_skill_learned", _analytics_context_from_states(_run_state, _combat_state), {
		"skill_id": skill_id,
		"skill_ids": ProgressionStore.selected_skill_ids(after_progression),
		"unspent_skill_points_before": ProgressionStore.unspent_skill_points(before_progression),
		"unspent_skill_points_after": ProgressionStore.unspent_skill_points(after_progression),
		"room": _run_state.get("current_room", Vector2i.ZERO)
	})

func _analytics_log_skill_reset(before_progression: Dictionary, after_progression: Dictionary) -> void:
	var skill_ids_before: Array[String] = ProgressionStore.selected_skill_ids(before_progression)
	var skill_ids_after: Array[String] = ProgressionStore.selected_skill_ids(after_progression)
	_analytics_store.write_event("progression_skill_reset", _analytics_context_from_states(_run_state, _combat_state), {
		"skill_ids_before": skill_ids_before,
		"skill_ids_after": skill_ids_after,
		"skill_points_refunded": skill_ids_before.size(),
		"unspent_skill_points_after": ProgressionStore.unspent_skill_points(after_progression),
		"moltshards_before": ProgressionStore.moltshard_count(before_progression),
		"moltshards_after": ProgressionStore.moltshard_count(after_progression),
		"room": _run_state.get("current_room", Vector2i.ZERO)
	})

func _reconcile_skill_event_analytics() -> void:
	var staged_now: bool = false
	if not _combat_state.is_empty():
		var staged_result: Dictionary = _stage_combat_skill_event_analytics_for_state(_run_state, _combat_state)
		if bool(staged_result.get("changed", false)):
			_run_state = staged_result.get("run_state", _run_state) as Dictionary
			_combat_state = staged_result.get("combat_state", _combat_state) as Dictionary
			_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
			staged_now = bool(staged_result.get("staged", false))
		_analytics_skill_event_revision = _combat_skill_event_staged_revision(_combat_state)
	if _is_debug_boss_run() or not _has_pending_combat_skill_event_analytics():
		return
	# Re-prove the gameplay/outbox boundary even when the event was staged by an
	# earlier failed save. A staged cursor means copied into the snapshot, never
	# that the snapshot reached disk or that JSONL may be appended safely.
	if not _persist_committed_boundary("combat_skill_event_outbox"):
		return
	var reconciled_all: bool = _reconcile_progression_analytics_outbox()
	_sync_progression_analytics_outbox_to_run()
	if str(_run_state.get("mode", "")) not in ["victory", "defeat"]:
		_persist_committed_boundary("combat_skill_event_ack")
	if staged_now and not reconciled_all:
		push_warning("Combat skill analytics remain queued for a later retry.")

func _stage_combat_skill_event_analytics_for_state(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var next_run: Dictionary = run_state.duplicate(true)
	var next_combat: Dictionary = combat_state.duplicate(true)
	if next_combat.is_empty():
		return {"run_state": next_run, "combat_state": next_combat, "changed": false, "staged": false}
	var combat_analytics: Dictionary = (next_combat.get("analytics", {}) as Dictionary).duplicate(true)
	var had_staged_cursor: bool = combat_analytics.has(COMBAT_SKILL_EVENT_STAGED_REVISION_KEY)
	var staged_revision: int = int(combat_analytics.get(
		COMBAT_SKILL_EVENT_STAGED_REVISION_KEY,
		next_combat.get("skill_event_revision", 0)
	))
	var latest_staged_revision: int = staged_revision
	var had_defiance_staged_cursor: bool = combat_analytics.has(COMBAT_DEFIANCE_EVENT_STAGED_REVISION_KEY)
	var defiance_staged_revision: int = int(combat_analytics.get(
		COMBAT_DEFIANCE_EVENT_STAGED_REVISION_KEY,
		next_combat.get("defiance_event_revision", 0)
	))
	var latest_defiance_staged_revision: int = defiance_staged_revision
	var progression: Dictionary = ProgressionStore.merge_progression_analytics_outbox(
		next_run.get("progression", _progression) as Dictionary,
		_progression
	)
	for event: Dictionary in _combat_engine.skill_events(next_combat):
		var revision: int = int(event.get("revision", 0))
		if revision <= staged_revision:
			continue
		var skill_id: String = str(event.get("skill_id", ""))
		var idempotency_key: String = _combat_skill_event_idempotency_key(next_run, next_combat, revision, skill_id)
		if idempotency_key.is_empty():
			break
		progression = ProgressionStore.queue_progression_analytics_event(
			progression,
			"skill_triggered",
			idempotency_key,
			_analytics_context_from_states(next_run, next_combat),
			{
				"skill_id": skill_id,
				"activation": SkillTreeLibrary.activation_kind(skill_id),
				"trigger_revision": revision,
				"trigger_scope": "combat",
				"turn": int(event.get("turn", next_combat.get("turn", 0))),
				"message": str(event.get("message", "")),
			}
		)
		latest_staged_revision = maxi(latest_staged_revision, revision)
	for event: Dictionary in _combat_engine.defiance_events(next_combat):
		var revision: int = int(event.get("revision", 0))
		if revision <= defiance_staged_revision:
			continue
		var idempotency_key: String = _combat_defiance_event_idempotency_key(next_combat, revision)
		if idempotency_key.is_empty():
			break
		progression = ProgressionStore.queue_progression_analytics_event(
			progression,
			"defiance_triggered",
			idempotency_key,
			_analytics_context_from_states(next_run, next_combat),
			{
				"trigger_revision": revision,
				"trigger_scope": "combat",
				"turn": int(event.get("turn", next_combat.get("turn", 0))),
				"cause": str(event.get("cause", "")),
				"lethal_hp_loss": int(event.get("lethal_hp_loss", 0)),
				"restored_hp": int(event.get("restored_hp", 0)),
				"charges_before": int(event.get("charges_before", 0)),
				"charges_after": int(event.get("charges_after", 0)),
				"capacity": int(next_combat.get(RunEngineScript.DEFIANCE_CAPACITY_KEY, 0)),
				"combat_unit_scale": 1,
			}
		)
		latest_defiance_staged_revision = maxi(latest_defiance_staged_revision, revision)
	combat_analytics[COMBAT_SKILL_EVENT_STAGED_REVISION_KEY] = latest_staged_revision
	combat_analytics[COMBAT_DEFIANCE_EVENT_STAGED_REVISION_KEY] = latest_defiance_staged_revision
	next_combat["analytics"] = combat_analytics
	next_run["progression"] = progression
	if latest_staged_revision > staged_revision or latest_defiance_staged_revision > defiance_staged_revision:
		_progression = ProgressionStore.merge_progression_analytics_outbox(_progression, progression)
	return {
		"run_state": next_run,
		"combat_state": next_combat,
		"changed": (
			not had_staged_cursor
			or not had_defiance_staged_cursor
			or latest_staged_revision > staged_revision
			or latest_defiance_staged_revision > defiance_staged_revision
		),
		"staged": (
			latest_staged_revision > staged_revision
			or latest_defiance_staged_revision > defiance_staged_revision
		),
	}

func _combat_skill_event_staged_revision(combat_state: Dictionary) -> int:
	if combat_state.is_empty():
		return 0
	var combat_analytics: Dictionary = combat_state.get("analytics", {}) as Dictionary
	return int(combat_analytics.get(
		COMBAT_SKILL_EVENT_STAGED_REVISION_KEY,
		combat_state.get("skill_event_revision", 0)
	))

func _combat_skill_event_idempotency_key(run_state: Dictionary, combat_state: Dictionary, revision: int, skill_id: String) -> String:
	var combat_id: String = str((combat_state.get("analytics", {}) as Dictionary).get("combat_id", ""))
	if combat_id.is_empty() or revision <= 0 or skill_id.is_empty():
		return ""
	return "skill_triggered|combat|%s|%d|%s" % [combat_id, revision, skill_id]

func _combat_defiance_event_idempotency_key(combat_state: Dictionary, revision: int) -> String:
	var combat_id: String = str((combat_state.get("analytics", {}) as Dictionary).get("combat_id", ""))
	if combat_id.is_empty() or revision <= 0:
		return ""
	return "defiance_triggered|combat|%s|%d" % [combat_id, revision]

func _has_pending_combat_skill_event_analytics() -> bool:
	for entry: Dictionary in ProgressionStore.progression_analytics_outbox(_progression):
		var event_type: String = str(entry.get("event_type", ""))
		var payload: Dictionary = entry.get("payload", {}) as Dictionary
		if event_type in ["skill_triggered", "defiance_triggered"] and str(payload.get("trigger_scope", "")) == "combat":
			return true
	return false

func _flush_run_skill_event_analytics(boundary: String = "run_skill_event") -> bool:
	if _run_state.is_empty():
		return true
	var analytics: Dictionary = _run_state.get("analytics", {}) as Dictionary
	var logged_revision: int = int(analytics.get("run_skill_event_revision_logged", 0))
	var pending_revision: int = _run_engine.run_skill_event_revision(_run_state)
	if pending_revision <= logged_revision:
		return true
	if _run_engine.run_skill_event_revision(_committed_run_state()) < pending_revision:
		# An animation may temporarily expose an older committed snapshot. Defer the
		# append until the outbox-bearing state becomes the active save boundary.
		return false
	# The revisioned run event is the outbox. Commit it before touching JSONL so a
	# crash can replay the same stable idempotency key instead of losing the event.
	if not _persist_committed_boundary("%s_outbox" % boundary):
		return false
	if not _reconcile_run_skill_event_analytics():
		return false
	var cursor_revision: int = int((_run_state.get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", 0))
	var cursor_saved: bool = _persist_committed_boundary("%s_cursor" % boundary)
	return cursor_saved and cursor_revision >= pending_revision

func _reconcile_run_skill_event_analytics() -> bool:
	var logged_before: int = int((_run_state.get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", 0))
	_run_state = _reconcile_run_skill_event_analytics_for_state(_run_state, _combat_state)
	var logged_after: int = int((_run_state.get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", 0))
	if logged_after > logged_before and not _committed_run_state_override.is_empty():
		var committed_analytics: Dictionary = (_committed_run_state_override.get("analytics", {}) as Dictionary).duplicate(true)
		committed_analytics["run_skill_event_revision_logged"] = logged_after
		_committed_run_state_override["analytics"] = committed_analytics
	return logged_after > logged_before

func _reconcile_run_skill_event_analytics_for_state(run_state: Dictionary, combat_state: Dictionary = {}) -> Dictionary:
	if run_state.is_empty():
		return run_state
	var next_state: Dictionary = run_state.duplicate(true)
	var analytics: Dictionary = (next_state.get("analytics", {}) as Dictionary).duplicate(true)
	var logged_revision: int = int(analytics.get("run_skill_event_revision_logged", 0))
	var latest_revision: int = logged_revision
	for event: Dictionary in _run_engine.run_skill_events(next_state):
		var revision: int = int(event.get("revision", 0))
		if revision <= logged_revision:
			continue
		var skill_id: String = str(event.get("skill_id", ""))
		var idempotency_key: String = _run_skill_event_idempotency_key(next_state, revision, skill_id)
		var wrote_event: bool = _analytics_store.write_event("skill_triggered", _analytics_context_from_states(next_state, combat_state), {
			"skill_id": skill_id,
			"activation": SkillTreeLibrary.activation_kind(skill_id),
			"trigger_revision": revision,
			"trigger_scope": "run",
			"turn": int(combat_state.get("turn", 0)),
			"message": str(event.get("message", ""))
		}, idempotency_key)
		if not wrote_event:
			break
		latest_revision = maxi(latest_revision, revision)
	if latest_revision > logged_revision:
		analytics["run_skill_event_revision_logged"] = latest_revision
		next_state["analytics"] = analytics
	return next_state

func _run_skill_event_idempotency_key(run_state: Dictionary, revision: int, skill_id: String) -> String:
	var run_id: String = str((run_state.get("analytics", {}) as Dictionary).get("run_id", ""))
	if run_id.is_empty():
		run_id = RunEngineScript.run_result_id(run_state)
	return "skill_triggered|run|%s|%d|%s" % [run_id, revision, skill_id]

func _analytics_log_reward_choice(choice_kind: String, reward_state: Dictionary, selected_card_id: String, player_hp_before: int, player_hp_after: int) -> void:
	_analytics_store.write_event("reward_choice", _analytics_context_from_states(_run_state, _combat_state, selected_card_id), {
		"choice_kind": choice_kind,
		"selected_card_id": selected_card_id,
		"offered_cards": (reward_state.get("cards", []) as Array).duplicate(true),
		"heal_amount": int(reward_state.get("heal_amount", 0)),
		"ember_amount": int(reward_state.get("ember_amount", 0)),
		"player_hp_before": player_hp_before,
		"player_hp_after": player_hp_after
	})

func _analytics_log_equipment_equipped(slot: String, previous_equipment_id: String, equipment_id: String) -> void:
	_analytics_store.write_event("equipment_equipped", _analytics_context_from_states(_run_state, _combat_state), {
		"slot": slot,
		"previous_equipment_id": previous_equipment_id,
		"equipment_id": equipment_id,
		"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true)
	})

func _analytics_log_magic_attuned(inventory_index: int, attuned_index: int, card_id: String) -> void:
	_analytics_store.write_event("magic_attuned", _analytics_context_from_states(_run_state, _combat_state, card_id), {
		"inventory_index": inventory_index,
		"attuned_index": attuned_index,
		"card_id": card_id,
		"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
		"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true)
	})

func _analytics_log_item_equipped(action: String, card_id: String, inventory_index: int, equipped_index: int) -> void:
	_analytics_store.write_event("item_equipped", _analytics_context_from_states(_run_state, _combat_state, card_id), {
		"action": action,
		"card_id": card_id,
		"inventory_index": inventory_index,
		"equipped_index": equipped_index,
		"equipped_items": (_run_state.get("equipped_items", []) as Array).duplicate(true),
		"item_inventory": (_run_state.get("item_inventory", []) as Array).duplicate(true),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true)
	})

func _analytics_log_merchant_trade(action: String, merchant_kind: String, item_id: String, amount: int, held_embers_before: int, held_embers_after: int) -> void:
	_analytics_store.write_event("merchant_trade", _analytics_context_from_states(_run_state, _combat_state, item_id), {
		"action": action,
		"merchant_kind": merchant_kind,
		"item_id": item_id,
		"item_kind": _analytics_merchant_item_kind(merchant_kind),
		"amount": amount,
		"held_embers_before": held_embers_before,
		"held_embers_after": held_embers_after,
		"room": _run_state.get("current_room", Vector2i.ZERO),
		"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"collected_equipment": (_run_state.get("collected_equipment", []) as Array).duplicate(true),
		"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
		"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
		"equipped_items": (_run_state.get("equipped_items", []) as Array).duplicate(true),
		"item_inventory": (_run_state.get("item_inventory", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true)
	})

func _analytics_merchant_item_kind(merchant_kind: String) -> String:
	if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH:
		return "equipment"
	if merchant_kind == RunEngineScript.MERCHANT_SCAVENGER:
		return "item"
	return "magic"

func _analytics_log_combat_transition(previous_run_state: Dictionary, reason: String, transition_combat_state: Dictionary = {}) -> void:
	var previous_mode: String = str(previous_run_state.get("mode", "room"))
	var next_mode: String = str(_run_state.get("mode", "room"))
	if previous_mode != "combat" and next_mode == "combat" and not transition_combat_state.is_empty():
		_run_state = _ensure_run_analytics_metadata(_run_state)
		var analytics: Dictionary = (_run_state.get("analytics", {}) as Dictionary).duplicate(true)
		analytics["combat_counter"] = int(analytics.get("combat_counter", 0)) + 1
		_run_state["analytics"] = analytics
		_combat_state = transition_combat_state.duplicate(true)
		_mark_combat_preview_state_changed()
		var combat_analytics: Dictionary = (_combat_state.get("analytics", {}) as Dictionary).duplicate(true)
		combat_analytics["combat_id"] = "%s_c%03d" % [str(analytics.get("run_id", "")), int(analytics.get("combat_counter", 0))]
		combat_analytics[COMBAT_SKILL_EVENT_STAGED_REVISION_KEY] = 0
		combat_analytics[COMBAT_DEFIANCE_EVENT_STAGED_REVISION_KEY] = 0
		_defiance_event_revision_seen = 0
		_combat_state["analytics"] = combat_analytics
		_run_state["combat_state"] = _combat_state.duplicate(true)
		_analytics_initialize_combat_tracker(_combat_state)
		_analytics_log_combat_started(reason)
		return
	if previous_mode == "combat" and next_mode != "combat" and not transition_combat_state.is_empty():
		_analytics_log_combat_ended(transition_combat_state, reason)
		if next_mode == "reward":
			_analytics_log_reward_offered(transition_combat_state, reason)
		elif next_mode in ["victory", "defeat"]:
			_analytics_log_run_ended(next_mode)
		_reset_analytics_combat_tracker()

func _analytics_log_combat_started(reason: String) -> void:
	_analytics_store.write_event("combat_started", _analytics_context_from_states(_run_state, _combat_state), {
		"reason": reason,
		"room_name": str(_combat_state.get("room_name", "")),
		"room_type": str(_combat_state.get("room_type", "")),
		"room_coord": _combat_state.get("room_coord", Vector2i.ZERO),
		"recovery_marker_present": _combat_recovery_marker_amount(_combat_state) > 0,
		"recovery_marker_amount": _combat_recovery_marker_amount(_combat_state),
		"elemental_intensity": _combat_engine.elemental_intensities(_combat_state),
		"umbra_stage": _combat_engine.effective_umbra_stage(_combat_state),
		"umbra_radius": _combat_engine.effective_umbra_radius(_combat_state),
		"visible_enemy_count": _combat_engine.visible_enemy_ids(_combat_state).size(),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
			"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
			"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
			"equipped_items": (_run_state.get("equipped_items", []) as Array).duplicate(true),
			"item_inventory": (_run_state.get("item_inventory", []) as Array).duplicate(true),
			"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"equipment_drops": _analytics_equipment_loot_ids(_combat_state),
		"opening_hand": _analytics_zone_cards(_combat_state, "hand")
	})
	_analytics_log_card_draws({}, _combat_state, {}, _analytics_snapshot_combat_tracker(), "opening_hand")
	_analytics_log_playable_cards()

func _analytics_log_combat_ended(combat_state: Dictionary, reason: String) -> void:
	_analytics_store.write_event("combat_ended", _analytics_context_from_states(_run_state, combat_state), {
		"reason": reason,
		"outcome": _combat_engine.combat_outcome(combat_state),
		"turn": int(combat_state.get("turn", 0)),
		"room_embers": int(combat_state.get("room_embers", 0)),
		"recovered_embers": int(combat_state.get("recovered_embers_total", 0)),
		"collected_equipment": (combat_state.get("collected_equipment", []) as Array).duplicate(true),
		"missed_equipment": (combat_state.get("missed_equipment", []) as Array).duplicate(true),
		"remaining_player_hp": int((combat_state.get("player", {}) as Dictionary).get("hp", 0)),
		"umbra_tiles_illuminated": int((combat_state.get("umbra", {}) as Dictionary).get("tiles_illuminated_total", 0)),
		"umbra_enemies_revealed": int((combat_state.get("umbra", {}) as Dictionary).get("enemies_revealed_total", 0)),
		"umbra_movement_interruptions": int((combat_state.get("umbra", {}) as Dictionary).get("movement_interrupted_total", 0)),
		"umbra_hidden_attack_damage_received": int((combat_state.get("umbra", {}) as Dictionary).get("hidden_attack_damage_received_total", 0))
	})

func _analytics_log_reward_offered(combat_state: Dictionary, reason: String) -> void:
	var reward_state: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	_analytics_store.write_event("reward_offered", _analytics_context_from_states(_run_state, combat_state), {
		"reason": reason,
		"offered_cards": (reward_state.get("cards", []) as Array).duplicate(true),
		"heal_amount": int(reward_state.get("heal_amount", 0)),
		"ember_amount": int(reward_state.get("ember_amount", 0))
	})

func _sync_analytics_combat_tracker() -> void:
	if str(_run_state.get("mode", "")) != "combat" or _combat_state.is_empty():
		if not _analytics_combat_tracker.is_empty():
			_reset_analytics_combat_tracker()
		return
	var combat_analytics: Dictionary = (_combat_state.get("analytics", {}) as Dictionary).duplicate(true)
	if str(combat_analytics.get("combat_id", "")).is_empty():
		_run_state = _ensure_run_analytics_metadata(_run_state)
		var analytics: Dictionary = (_run_state.get("analytics", {}) as Dictionary).duplicate(true)
		analytics["combat_counter"] = maxi(1, int(analytics.get("combat_counter", 0)))
		_run_state["analytics"] = analytics
		combat_analytics["combat_id"] = "%s_c%03d" % [str(analytics.get("run_id", "")), int(analytics.get("combat_counter", 0))]
		combat_analytics[COMBAT_SKILL_EVENT_STAGED_REVISION_KEY] = 0
		combat_analytics[COMBAT_DEFIANCE_EVENT_STAGED_REVISION_KEY] = 0
		_defiance_event_revision_seen = 0
		_combat_state["analytics"] = combat_analytics
		_run_state["combat_state"] = _combat_state.duplicate(true)
	if _analytics_combat_tracker.is_empty() or str(_analytics_combat_tracker.get("combat_id", "")) != str(combat_analytics.get("combat_id", "")):
		_analytics_initialize_combat_tracker(_combat_state)

func _reset_analytics_combat_tracker() -> void:
	_analytics_combat_tracker = {}
	_analytics_skill_event_revision = 0
	_skill_event_revision_seen = 0

func _analytics_initialize_combat_tracker(combat_state: Dictionary) -> void:
	var tracker: Dictionary = {
		"combat_id": str((combat_state.get("analytics", {}) as Dictionary).get("combat_id", "")),
		"next_instance_seq": 1,
		"playable_logged": {},
		"zones": {}
	}
	var zones: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var zone_cards: Array[String] = _analytics_zone_cards(combat_state, zone)
		var zone_ids: Array[String] = []
		for _card_id: String in zone_cards:
			zone_ids.append(_analytics_next_card_instance_id(tracker))
		zones[zone] = zone_ids
	tracker["zones"] = zones
	_analytics_combat_tracker = tracker
	var combat_analytics: Dictionary = combat_state.get("analytics", {}) as Dictionary
	_analytics_skill_event_revision = int(combat_analytics.get(
		COMBAT_SKILL_EVENT_STAGED_REVISION_KEY,
		combat_state.get("skill_event_revision", 0)
	))
	_skill_event_revision_seen = int(combat_state.get("skill_event_revision", 0))

func _analytics_snapshot_combat_tracker() -> Dictionary:
	return _analytics_combat_tracker.duplicate(true)

func _analytics_zone_cards(state: Dictionary, zone: String) -> Array[String]:
	var cards: Array[String] = []
	var zone_values: Array = ((state.get("deck", {}) as Dictionary).get(zone, []) as Array)
	for card_id_var: Variant in zone_values:
		cards.append(str(card_id_var))
	return cards

func _analytics_zone_ids(tracker: Dictionary, zone: String) -> Array:
	if tracker.is_empty():
		return []
	return ((tracker.get("zones", {}) as Dictionary).get(zone, []) as Array).duplicate(true)

func _analytics_reconcile_combat_tracker(before_state: Dictionary, after_state: Dictionary) -> void:
	if _analytics_combat_tracker.is_empty():
		_analytics_initialize_combat_tracker(after_state)
		return
	var cross_pool: Dictionary = {}
	var same_zone_ids: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var before_cards: Array[String] = _analytics_zone_cards(before_state, zone)
		var before_ids: Array = _analytics_zone_ids(_analytics_combat_tracker, zone)
		var after_cards: Array[String] = _analytics_zone_cards(after_state, zone)
		var same_zone_pool: Dictionary = {}
		for index: int in range(mini(before_cards.size(), before_ids.size())):
			var card_id: String = before_cards[index]
			var instance_id: String = str(before_ids[index])
			if not same_zone_pool.has(card_id):
				same_zone_pool[card_id] = []
			(same_zone_pool[card_id] as Array).append(instance_id)
		var assigned_ids: Array[String] = []
		for card_id: String in after_cards:
			var instance_id: String = _analytics_take_from_pool(same_zone_pool, card_id)
			assigned_ids.append(instance_id)
		same_zone_ids[zone] = assigned_ids
		for pool_card_id_var: Variant in same_zone_pool.keys():
			var pool_card_id: String = str(pool_card_id_var)
			for leftover_id_var: Variant in same_zone_pool[pool_card_id]:
				_analytics_enqueue_instance_id(cross_pool, pool_card_id, str(leftover_id_var))
	_update_analytics_zone_ids_from_pool(after_state, same_zone_ids, cross_pool)

func _update_analytics_zone_ids_from_pool(after_state: Dictionary, zone_ids: Dictionary, cross_pool: Dictionary) -> void:
	var next_zones: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var after_cards: Array[String] = _analytics_zone_cards(after_state, zone)
		var resolved_ids: Array = (zone_ids.get(zone, []) as Array).duplicate(true)
		for index: int in range(resolved_ids.size()):
			if not str(resolved_ids[index]).is_empty():
				continue
			var card_id: String = after_cards[index]
			var instance_id: String = _analytics_take_from_pool(cross_pool, card_id)
			if instance_id.is_empty():
				instance_id = _analytics_next_card_instance_id(_analytics_combat_tracker)
			resolved_ids[index] = instance_id
		next_zones[zone] = resolved_ids
	_analytics_combat_tracker["zones"] = next_zones

func _analytics_enqueue_instance_id(pool: Dictionary, card_id: String, instance_id: String) -> void:
	if not pool.has(card_id):
		pool[card_id] = []
	(pool[card_id] as Array).append(instance_id)

func _analytics_take_from_pool(pool: Dictionary, card_id: String) -> String:
	if not pool.has(card_id) or (pool[card_id] as Array).is_empty():
		return ""
	var queue: Array = pool[card_id]
	var instance_id: String = str(queue[0])
	queue.remove_at(0)
	pool[card_id] = queue
	return instance_id

func _analytics_next_card_instance_id(tracker: Dictionary) -> String:
	var next_seq: int = int(tracker.get("next_instance_seq", 1))
	tracker["next_instance_seq"] = next_seq + 1
	return "%s_i%03d" % [str(tracker.get("combat_id", "combat")), next_seq]

func _analytics_hand_instance_id(hand_index: int) -> String:
	var hand_ids: Array = _analytics_zone_ids(_analytics_combat_tracker, "hand")
	if hand_index < 0 or hand_index >= hand_ids.size():
		return ""
	return str(hand_ids[hand_index])

func _analytics_log_card_draws(before_state: Dictionary, after_state: Dictionary, before_tracker: Dictionary, after_tracker: Dictionary, reason: String) -> void:
	var before_hand_ids: Dictionary = {}
	for instance_id_var: Variant in _analytics_zone_ids(before_tracker, "hand"):
		before_hand_ids[str(instance_id_var)] = true
	var after_hand_ids: Array = _analytics_zone_ids(after_tracker, "hand")
	var after_hand_cards: Array[String] = _analytics_zone_cards(after_state, "hand")
	for index: int in range(mini(after_hand_ids.size(), after_hand_cards.size())):
		var instance_id: String = str(after_hand_ids[index])
		if before_hand_ids.has(instance_id):
			continue
		var card_id: String = after_hand_cards[index]
		_analytics_store.write_event("card_drawn", _analytics_context_from_states(_run_state, after_state, card_id, instance_id), {
			"reason": reason,
			"hand_index": index,
			"hand_size": after_hand_cards.size(),
			"draw_pile_size": _analytics_zone_cards(after_state, "draw").size()
		})

func _analytics_log_playable_cards() -> void:
	if _combat_state.is_empty() or _analytics_combat_tracker.is_empty():
		return
	var playable_logged: Dictionary = (_analytics_combat_tracker.get("playable_logged", {}) as Dictionary).duplicate(true)
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	var hand_ids: Array = _analytics_zone_ids(_analytics_combat_tracker, "hand")
	for index: int in range(mini(hand.size(), hand_ids.size())):
		var instance_id: String = str(hand_ids[index])
		if bool(playable_logged.get(instance_id, false)):
			continue
		var options: Dictionary = _card_play_options_for_index(index)
		if not bool(options.get("any_playable", false)):
			continue
		var card_id: String = str(hand[index])
		playable_logged[instance_id] = true
		_analytics_store.write_event("card_became_playable", _analytics_context_from_states(_run_state, _combat_state, card_id, instance_id), {
			"hand_index": index,
			"printed_playable": bool(options.get("printed_playable", false)),
			"attack_playable": bool(options.get("attack_playable", false)),
			"move_playable": bool(options.get("move_playable", false)),
			"blink_playable": bool(options.get("blink_playable", false))
		})
	_analytics_combat_tracker["playable_logged"] = playable_logged

func _analytics_log_card_played(card_id: String, card_instance_id: String, before_state: Dictionary, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> void:
	if card_id.is_empty():
		return
	_analytics_store.write_event("card_played", _analytics_context_from_states(_run_state, before_state, card_id, card_instance_id), _analytics_card_play_payload(card_id, before_state, resolved_state, actions, selected_targets))

func _analytics_card_play_payload(card_id: String, before_state: Dictionary, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> Dictionary:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = resolved_state.get("player", {})
	var before_pos: Vector2i = before_player.get("pos", Vector2i.ZERO)
	var after_pos: Vector2i = after_player.get("pos", Vector2i.ZERO)
	var enemy_hp_damage: int = 0
	var enemy_block_removed: int = 0
	var enemy_stoneskin_removed: int = 0
	var kills_secured: int = 0
	var enemy_burn_applied: int = 0
	var enemy_bleed_applied: int = 0
	var enemy_expose_applied: int = 0
	var enemy_freeze_applied: int = 0
	var enemy_shock_applied: int = 0
	var enemy_immobilize_applied: int = 0
	var enemy_poison_applied: int = 0
	var terrain_hp_damage: int = 0
	var terrain_destroyed: int = 0
	var before_enemies: Array = before_state.get("enemies", [])
	var after_enemies: Array = resolved_state.get("enemies", [])
	for index: int in range(mini(before_enemies.size(), after_enemies.size())):
		var before_enemy: Dictionary = before_enemies[index]
		var after_enemy: Dictionary = after_enemies[index]
		enemy_hp_damage += maxi(0, int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0)))
		enemy_block_removed += maxi(0, int(before_enemy.get("block", 0)) - int(after_enemy.get("block", 0)))
		enemy_stoneskin_removed += maxi(0, int(before_enemy.get("stoneskin", 0)) - int(after_enemy.get("stoneskin", 0)))
		if int(before_enemy.get("hp", 0)) > 0 and int(after_enemy.get("hp", 0)) <= 0:
			kills_secured += 1
		enemy_burn_applied += maxi(0, int(after_enemy.get("burn", 0)) - int(before_enemy.get("burn", 0)))
		enemy_bleed_applied += maxi(0, int(after_enemy.get("bleed", 0)) - int(before_enemy.get("bleed", 0)))
		enemy_expose_applied += maxi(0, int(after_enemy.get("expose", 0)) - int(before_enemy.get("expose", 0)))
		enemy_freeze_applied += maxi(0, int(after_enemy.get("freeze", 0)) - int(before_enemy.get("freeze", 0)))
		enemy_shock_applied += maxi(0, int(after_enemy.get("shock", 0)) - int(before_enemy.get("shock", 0)))
		if bool(after_enemy.get("immobilize", false)) and not bool(before_enemy.get("immobilize", false)):
			enemy_immobilize_applied += 1
		enemy_poison_applied += maxi(0, int((after_enemy.get("poison", {}) as Dictionary).get("damage", 0)) - int((before_enemy.get("poison", {}) as Dictionary).get("damage", 0)))
	var after_terrain_by_id: Dictionary = {}
	for after_terrain_var: Variant in resolved_state.get("terrain", []):
		if typeof(after_terrain_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = after_terrain_var
		after_terrain_by_id[str(after_terrain.get("id", ""))] = after_terrain
	for before_terrain_var: Variant in before_state.get("terrain", []):
		if typeof(before_terrain_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = before_terrain_var
		if int(before_terrain.get("hp", 0)) <= 0:
			continue
		var terrain_id: String = str(before_terrain.get("id", ""))
		if not after_terrain_by_id.has(terrain_id):
			continue
		var after_terrain: Dictionary = after_terrain_by_id[terrain_id]
		var terrain_loss: int = maxi(0, int(before_terrain.get("hp", 0)) - int(after_terrain.get("hp", 0)))
		terrain_hp_damage += terrain_loss
		if terrain_loss > 0 and int(after_terrain.get("hp", 0)) <= 0:
			terrain_destroyed += 1
	var player_burn_applied: int = maxi(0, int(after_player.get("burn", 0)) - int(before_player.get("burn", 0)))
	var player_bleed_applied: int = maxi(0, int(after_player.get("bleed", 0)) - int(before_player.get("bleed", 0)))
	var player_expose_applied: int = maxi(0, int(after_player.get("expose", 0)) - int(before_player.get("expose", 0)))
	var player_freeze_applied: int = maxi(0, int(after_player.get("freeze", 0)) - int(before_player.get("freeze", 0)))
	var player_shock_applied: int = maxi(0, int(after_player.get("shock", 0)) - int(before_player.get("shock", 0)))
	var player_immobilize_applied: int = 1 if bool(after_player.get("immobilize", false)) and not bool(before_player.get("immobilize", false)) else 0
	var player_poison_applied: int = maxi(0, int((after_player.get("poison", {}) as Dictionary).get("damage", 0)) - int((before_player.get("poison", {}) as Dictionary).get("damage", 0)))
	var before_illusion_ids: Dictionary = {}
	for before_illusion_var: Variant in before_state.get("illusions", []):
		if typeof(before_illusion_var) != TYPE_DICTIONARY:
			continue
		var before_illusion: Dictionary = before_illusion_var
		before_illusion_ids[int(before_illusion.get("id", -1))] = true
	var illusions_created: int = 0
	var illusion_health_created: int = 0
	for after_illusion_var: Variant in resolved_state.get("illusions", []):
		if typeof(after_illusion_var) != TYPE_DICTIONARY:
			continue
		var after_illusion: Dictionary = after_illusion_var
		if before_illusion_ids.has(int(after_illusion.get("id", -1))):
			continue
		if int(after_illusion.get("hp", 0)) <= 0:
			continue
		illusions_created += 1
		illusion_health_created += maxi(0, int(after_illusion.get("max_hp", after_illusion.get("hp", 0))))
	var printed_card: Dictionary = _card_def(card_id, before_state)
	var printed_actions: Array = (printed_card.get("actions", []) as Array).duplicate(true)
	var intensity_before: Dictionary = _combat_engine.elemental_intensities(before_state)
	var intensity_after: Dictionary = _combat_engine.elemental_intensities(resolved_state)
	var intensity_gained: Dictionary = _elemental_intensity_counter_delta(before_state, resolved_state, "elemental_intensity_gained_total")
	if intensity_gained.is_empty():
		intensity_gained = _elemental_intensity_delta(intensity_before, intensity_after)
	var intensity_spent: Dictionary = _elemental_intensity_counter_delta(before_state, resolved_state, "elemental_intensity_spent_total")
	var capacity_delta: int = _card_play_capacity_value(resolved_state) - _card_play_capacity_value(before_state)
	var play_mode: String = "printed"
	var comparable_actions: Array = _analytics_actions_without_runtime_orientation(actions)
	var flurry_plays_spent: int = _combat_engine.card_plays_spent_for_actions(actions)
	if flurry_plays_spent <= 1 and JSON.stringify(comparable_actions) != JSON.stringify(printed_actions):
		play_mode = "attack" if JSON.stringify(comparable_actions) == JSON.stringify(_fallback_actions("attack")) else "move" if JSON.stringify(comparable_actions) == JSON.stringify(_fallback_actions("move")) else "custom"
	var flurry_played: bool = bool(printed_card.get("flurry", false)) and play_mode == "printed"
	var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, resolved_state)
	var before_umbra: Dictionary = before_state.get("umbra", {}) as Dictionary
	var after_umbra: Dictionary = resolved_state.get("umbra", {}) as Dictionary
	return {
		"play_mode": play_mode,
		"flurry": flurry_played,
		"flurry_plays_spent": flurry_plays_spent if flurry_played else 0,
		"printed_health_cost": int(printed_card.get("health_cost", 0)),
		"consume_on_play": GameData.card_consumes_on_play(card_id),
		"item_card": GameData.card_is_item(card_id),
		"enemy_hp_damage": enemy_hp_damage,
		"enemy_block_removed": enemy_block_removed,
		"enemy_stoneskin_removed": enemy_stoneskin_removed,
		"enemy_defense_bypassed": _analytics_enemy_defense_bypassed(before_state, resolved_state, actions),
		"terrain_hp_damage": terrain_hp_damage,
		"terrain_destroyed": terrain_destroyed,
		"traps_triggered": triggered_traps.size(),
		"triggered_trap_damage": _triggered_trap_damage(triggered_traps),
		"pickups_collected": _analytics_picked_loot_count(before_state, resolved_state),
		"embers_recovered": maxi(0, int(resolved_state.get("recovered_embers_total", 0)) - int(before_state.get("recovered_embers_total", 0))),
		"kills_secured": kills_secured,
		"player_hp_delta": int(after_player.get("hp", 0)) - int(before_player.get("hp", 0)),
		"player_heal_gained": maxi(0, int(after_player.get("hp", 0)) - int(before_player.get("hp", 0))),
		"player_block_gained": maxi(0, int(after_player.get("block", 0)) - int(before_player.get("block", 0))),
		"player_stoneskin_gained": maxi(0, int(after_player.get("stoneskin", 0)) - int(before_player.get("stoneskin", 0))),
		"move_distance": absi(after_pos.x - before_pos.x) + absi(after_pos.y - before_pos.y),
		"cards_drawn": _draw_entries_between_states(before_state, resolved_state).size(),
		"card_plays_gained": maxi(0, capacity_delta),
		"card_plays_remaining_before": _combat_engine.cards_remaining_this_turn(before_state),
		"card_plays_remaining_after": _combat_engine.cards_remaining_this_turn(resolved_state),
		"net_card_plays_remaining_delta": _combat_engine.cards_remaining_this_turn(resolved_state) - _combat_engine.cards_remaining_this_turn(before_state),
		"card_plays_spent": maxi(0, int(resolved_state.get("cards_played_this_turn", 0)) - int(before_state.get("cards_played_this_turn", 0))),
		"death_bonus_card_plays_gained": maxi(0, int(resolved_state.get("death_bonus_card_plays_this_turn", 0)) - int(before_state.get("death_bonus_card_plays_this_turn", 0))),
		"card_action_plays_gained": maxi(0, int(resolved_state.get("card_play_bonus_this_turn", 0)) - int(before_state.get("card_play_bonus_this_turn", 0))),
		"card_time": _combat_engine.card_time_cost_from_def(printed_card),
		"turn_time_spent_before": int(before_state.get("player_turn_time_spent", 0)),
		"turn_time_spent_after": int(resolved_state.get("player_turn_time_spent", int(before_state.get("player_turn_time_spent", 0)) + _combat_engine.card_time_cost_from_def(printed_card))),
		"player_base_initiative": _combat_engine.player_base_initiative(before_state),
		"elemental_intensity_before": intensity_before,
		"elemental_intensity_after": intensity_after,
		"elemental_intensity_gained": intensity_gained,
		"elemental_intensity_spent": intensity_spent,
		"pierce_actions": _analytics_pierce_action_count(actions),
		"sunder_actions": _analytics_attack_keyword_action_count(actions, "sunder"),
		"illusions_created": illusions_created,
		"illusion_health_created": illusion_health_created,
		"radiance_card": bool(printed_card.get("radiance", false)),
		"umbra_stage_before": _combat_engine.effective_umbra_stage(before_state),
		"umbra_stage_after": _combat_engine.effective_umbra_stage(resolved_state),
		"umbra_radius_before": _combat_engine.effective_umbra_radius(before_state),
		"umbra_radius_after": _combat_engine.effective_umbra_radius(resolved_state),
		"umbra_tiles_illuminated": maxi(0, int(after_umbra.get("tiles_illuminated_total", 0)) - int(before_umbra.get("tiles_illuminated_total", 0))),
		"umbra_enemies_revealed": maxi(0, int(after_umbra.get("enemies_revealed_total", 0)) - int(before_umbra.get("enemies_revealed_total", 0))),
		"umbra_light_sources_created": maxi(0, (after_umbra.get("light_sources", []) as Array).size() - (before_umbra.get("light_sources", []) as Array).size()),
		"umbra_movement_interruptions": maxi(0, int(after_umbra.get("movement_interrupted_total", 0)) - int(before_umbra.get("movement_interrupted_total", 0))),
		"enemy_status_applied": {
			"burn": enemy_burn_applied,
			"bleed": enemy_bleed_applied,
			"expose": enemy_expose_applied,
			"freeze": enemy_freeze_applied,
			"shock": enemy_shock_applied,
			"immobilize": enemy_immobilize_applied,
			"poison": enemy_poison_applied
		},
		"player_status_applied": {
			"burn": player_burn_applied,
			"bleed": player_bleed_applied,
			"expose": player_expose_applied,
			"freeze": player_freeze_applied,
			"shock": player_shock_applied,
			"immobilize": player_immobilize_applied,
			"poison": player_poison_applied
		},
		"selected_targets": _vector2i_array(selected_targets),
		"actions": actions.duplicate(true)
	}

func _analytics_actions_without_runtime_orientation(actions: Array) -> Array:
	var result: Array = []
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			result.append(action_var)
			continue
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		action.erase("orientation")
		action.erase("force_direction")
		action.erase("_flurry_repeat_index")
		action.erase("_flurry_repeat_count")
		result.append(action)
	return result

func _elemental_intensity_delta(before_intensity: Dictionary, after_intensity: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		var gained: int = int(after_intensity.get(element_id, 0)) - int(before_intensity.get(element_id, 0))
		if gained > 0:
			result[element_id] = gained
	return result

func _elemental_intensity_counter_delta(before_state: Dictionary, after_state: Dictionary, counter_key: String) -> Dictionary:
	var result: Dictionary = {}
	var before_counter: Dictionary = _combat_engine.elemental_intensity_counter(before_state, counter_key)
	var after_counter: Dictionary = _combat_engine.elemental_intensity_counter(after_state, counter_key)
	for element_id: String in ElementData.all_elements():
		var delta: int = int(after_counter.get(element_id, 0)) - int(before_counter.get(element_id, 0))
		if delta > 0:
			result[element_id] = delta
	return result

func _card_play_capacity_value(state: Dictionary) -> int:
	return (
		int(state.get("cards_per_turn", 2))
		+ int(state.get("death_bonus_card_plays_this_turn", 0))
		+ int(state.get("card_play_bonus_this_turn", 0))
	)

func _analytics_pierce_action_count(actions: Array) -> int:
	return _analytics_attack_keyword_action_count(actions, "pierce")

func _analytics_attack_keyword_action_count(actions: Array, keyword: String) -> int:
	var count: int = 0
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if keyword == "pierce" and not bool(action.get(keyword, false)):
			continue
		if keyword != "pierce" and int(action.get(keyword, 0)) <= 0:
			continue
		if str(action.get("type", "")) in ["melee", "ranged", "aoe", "push", "pull"]:
			count += 1
	return count

func _triggered_trap_damage(triggered_traps: Array[Dictionary]) -> int:
	var total: int = 0
	for trap: Dictionary in triggered_traps:
		total += maxi(0, int(trap.get("resolved_damage", trap.get("damage", 0))))
	return total

func _analytics_picked_loot_count(before_state: Dictionary, after_state: Dictionary) -> int:
	var after_claimed: Dictionary = {}
	for after_loot_var: Variant in after_state.get("loot", []):
		if typeof(after_loot_var) != TYPE_DICTIONARY:
			continue
		var after_loot: Dictionary = after_loot_var
		if bool(after_loot.get("claimed", false)):
			after_claimed[_analytics_loot_key(after_loot)] = true
	var picked_count: int = 0
	for before_loot_var: Variant in before_state.get("loot", []):
		if typeof(before_loot_var) != TYPE_DICTIONARY:
			continue
		var before_loot: Dictionary = before_loot_var
		if bool(before_loot.get("claimed", false)):
			continue
		if after_claimed.has(_analytics_loot_key(before_loot)):
			picked_count += 1
	return picked_count

func _analytics_loot_key(loot: Dictionary) -> String:
	var loot_id: String = str(loot.get("id", ""))
	if not loot_id.is_empty():
		return loot_id
	var pos: Vector2i = loot.get("pos", Vector2i.ZERO)
	return "%s:%d:%d" % [str(loot.get("kind", "")), pos.x, pos.y]

func _analytics_enemy_defense_bypassed(before_state: Dictionary, resolved_state: Dictionary, actions: Array) -> int:
	if _analytics_pierce_action_count(actions) <= 0:
		return 0
	var total: int = 0
	var before_enemies: Array = before_state.get("enemies", [])
	var after_enemies: Array = resolved_state.get("enemies", [])
	for index: int in range(mini(before_enemies.size(), after_enemies.size())):
		if typeof(before_enemies[index]) != TYPE_DICTIONARY or typeof(after_enemies[index]) != TYPE_DICTIONARY:
			continue
		var before_enemy: Dictionary = before_enemies[index]
		var after_enemy: Dictionary = after_enemies[index]
		var hp_loss: int = maxi(0, int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0)))
		if hp_loss <= 0:
			continue
		var before_defense: int = maxi(0, int(before_enemy.get("block", 0))) + maxi(0, int(before_enemy.get("stoneskin", 0)))
		total += mini(hp_loss, before_defense)
	return total

func _analytics_log_enemy_status_ticks(phase_result: Dictionary) -> void:
	for step_var: Variant in phase_result.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		var kind: String = str(step.get("kind", ""))
		if kind not in ["status_damage", "status"]:
			continue
		if bool(step.get("boss_mechanic", false)):
			continue
		_analytics_store.write_event("enemy_status_tick", _analytics_context_from_states(_run_state, _combat_state), {
			"kind": kind,
			"actor_key": str(step.get("actor_key", "")),
			"actor_name": str(step.get("actor_name", "")),
			"label": str(step.get("label", "")),
			"amount": int(step.get("amount", 0)),
			"text": str(step.get("text", "")),
			"trigger": str(step.get("trigger", "turn_start")),
			"action_type": str(step.get("action_type", "")),
			"tile": step.get("tile", Vector2i(-1, -1))
		})

func _analytics_log_enemy_actions(phase_result: Dictionary) -> void:
	for step_var: Variant in phase_result.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		var kind: String = str(step.get("kind", ""))
		if kind not in ["move", "melee", "ranged", "aoe", "push", "pull", "lightning_strikes", "block", "stoneskin", "heal", "summon", "intensity"] and not (kind == "status" and bool(step.get("boss_mechanic", false))):
			continue
		var path: Array[Vector2i] = _vector2i_array(step.get("path", []))
		_analytics_store.write_event("enemy_action_resolved", _analytics_context_from_states(_run_state, _combat_state), {
			"action_type": str(step.get("action_type", kind)),
			"presentation_kind": kind,
			"boss_mechanic": bool(step.get("boss_mechanic", false)),
			"actor_key": str(step.get("actor_key", "")),
			"actor_name": str(step.get("actor_name", "")),
			"label": str(step.get("label", "")),
			"from": step.get("from", step.get("tile", Vector2i(-1, -1))),
			"to": step.get("to", step.get("tile", Vector2i(-1, -1))),
			"path": path,
			"path_steps": maxi(0, path.size() - 1),
			"target_key": str(step.get("target_key", "")),
			"target_losses": (step.get("target_losses", []) as Array).duplicate(true),
			"enemy_losses": (step.get("enemy_losses", []) as Array).duplicate(true),
			"terrain_losses": (step.get("terrain_losses", []) as Array).duplicate(true),
			"triggered_traps": (step.get("triggered_traps", []) as Array).duplicate(true),
			"elemental_intensity_gained": (step.get("elemental_intensity_gained", {}) as Dictionary).duplicate(true),
			"elemental_intensity_spent": (step.get("elemental_intensity_spent", {}) as Dictionary).duplicate(true)
		})

func _sync_combat_state_from_run() -> void:
	var entering_combat: bool = _combat_state.is_empty()
	_combat_state = (_run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	if entering_combat and not _combat_state.is_empty():
		# Never let a prior room's cached render signature suppress the first
		# complete Turn Clock render on combat-room entry.
		_turn_order_source_signature = "<room-entry>"
		_turn_order_render_signature = "<room-entry>"
	_mark_combat_preview_state_changed()

func _sync_progression_from_run() -> void:
	var run_progression: Dictionary = (_run_state.get("progression", {}) as Dictionary).duplicate(true)
	if run_progression.is_empty():
		return
	_progression = ProgressionStore.set_embers(run_progression, _run_engine.held_embers(_run_state))

func _sync_progression_analytics_outbox_to_run() -> void:
	if _run_state.is_empty():
		return
	var run_progression: Dictionary = (_run_state.get("progression", {}) as Dictionary).duplicate(true)
	if run_progression.is_empty():
		return
	run_progression[ProgressionStore.PROGRESSION_ANALYTICS_OUTBOX_KEY] = ProgressionStore.progression_analytics_outbox(_progression)
	_run_state["progression"] = ProgressionStore.normalized_data(run_progression)

func _sync_umbra_warning_progression() -> void:
	if _is_debug_boss_run() or _combat_state.is_empty():
		return
	var umbra: Dictionary = _combat_state.get("umbra", {}) as Dictionary
	if str(umbra.get("stage", "clear")) == "clear":
		return
	var previous_available_run: int = int(_progression.get(ProgressionStore.UMBRA_WARNING_AVAILABLE_RUN_KEY, 0))
	var next_progression: Dictionary = ProgressionStore.record_first_umbra_reach(_progression, int(_run_state.get("run_index", 0)))
	if int(next_progression.get(ProgressionStore.UMBRA_WARNING_AVAILABLE_RUN_KEY, 0)) == previous_available_run:
		return
	_progression = next_progression
	_run_state["progression"] = _progression.duplicate(true)
	ProgressionStore.save_data(_progression)
	_persist_committed_boundary("umbra_first_reached")

func _run_state_with_profile_grimoire(next_run_state: Dictionary) -> Dictionary:
	if _progression.is_empty():
		return next_run_state
	var state: Dictionary = next_run_state.duplicate(true)
	var embedded_progression: Dictionary = (state.get("progression", {}) as Dictionary).duplicate(true)
	if embedded_progression.is_empty():
		embedded_progression = _progression.duplicate(true)
	embedded_progression = ProgressionStore.merge_progression_analytics_outbox(embedded_progression, _progression)
	for key: String in [GrimoireLibrary.UNLOCKED_KEY, GrimoireLibrary.UNREAD_KEY]:
		var merged: Array[String] = []
		for entry_id: String in GrimoireLibrary.normalize_entry_ids(embedded_progression.get(key, [])):
			if not merged.has(entry_id):
				merged.append(entry_id)
		for entry_id: String in GrimoireLibrary.normalize_entry_ids(_progression.get(key, [])):
			if not merged.has(entry_id):
				merged.append(entry_id)
		embedded_progression[key] = GrimoireLibrary.ordered_entry_ids(merged)
	for profile_key: String in [ProgressionStore.RUN_BESTS_KEY, ProgressionStore.LAST_RUN_RESULT_KEY]:
		if _progression.has(profile_key) and typeof(_progression.get(profile_key)) == TYPE_DICTIONARY:
			embedded_progression[profile_key] = (_progression.get(profile_key) as Dictionary).duplicate(true)
	if _progression.has(ProgressionStore.RUN_RESULT_LEDGER_KEY) and typeof(_progression.get(ProgressionStore.RUN_RESULT_LEDGER_KEY)) == TYPE_ARRAY:
		embedded_progression[ProgressionStore.RUN_RESULT_LEDGER_KEY] = (_progression.get(ProgressionStore.RUN_RESULT_LEDGER_KEY) as Array).duplicate(true)
	for profile_key: String in [ProgressionStore.UMBRA_WARNING_AVAILABLE_RUN_KEY, ProgressionStore.UMBRA_WARNING_SEEN_KEY]:
		if _progression.has(profile_key):
			embedded_progression[profile_key] = _progression.get(profile_key)
	var prompt_states: Dictionary = ContextualCombatTutorial.merged_states(_progression, embedded_progression)
	if not prompt_states.is_empty():
		embedded_progression[ContextualCombatTutorial.PROGRESSION_KEY] = prompt_states
	state["progression"] = embedded_progression
	return state

func _persist_grimoire_progression_from_run() -> void:
	_sync_progression_from_run()
	if not _progression.is_empty():
		ProgressionStore.save_data(_progression)
	if not _run_state.is_empty():
		_persist_committed_boundary("grimoire_progress")

func _layout_mini_map_overlay() -> void:
	if mini_map_overlay == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var overlay_width: float = clampf(viewport_size.x * 0.15, 184.0, 244.0)
	var overlay_height: float = clampf(viewport_size.y * 0.20, 168.0, 224.0)
	mini_map_overlay.offset_left = -overlay_width - 8.0
	mini_map_overlay.offset_top = 8.0
	mini_map_overlay.offset_right = -8.0
	mini_map_overlay.offset_bottom = 8.0 + overlay_height

func _exit_tile_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	if str(_run_state.get("mode", "room")) != "room":
		return lookup
	for option: Dictionary in _run_engine.exit_options(_run_state):
		lookup[option.get("door_tile", Vector2i(-1, -1))] = option.get("coord", Vector2i.ZERO)
	return lookup

func _door_tile_for_destination(coord: Vector2i) -> Vector2i:
	for option: Dictionary in _run_engine.exit_options(_run_state):
		if option.get("coord", Vector2i.ZERO) == coord:
			return option.get("door_tile", INVALID_TARGET_TILE)
	return INVALID_TARGET_TILE

func _exit_labels_for_board() -> Dictionary:
	var labels: Dictionary = {}
	for option: Dictionary in _run_engine.exit_options(_run_state):
		var dir: Vector2i = option.get("dir", Vector2i.ZERO)
		var marker: String = "N" if dir == Vector2i(0, -1) else "E" if dir == Vector2i(1, 0) else "S" if dir == Vector2i(0, 1) else "W"
		labels[option.get("door_tile", Vector2i(-1, -1))] = marker
	return labels

func _exit_icon_ids_for_board() -> Dictionary:
	var icon_ids: Dictionary = {}
	for option: Dictionary in _run_engine.exit_options(_run_state):
		var room: Dictionary = option.get("room", {})
		icon_ids[option.get("door_tile", Vector2i(-1, -1))] = RoomIcons.icon_id_for_room(room)
	return icon_ids

func _active_door_tiles_for_board() -> Dictionary:
	var active: Dictionary = {}
	for option: Dictionary in _run_engine.exit_options(_run_state):
		var door_tile: Vector2i = option.get("door_tile", INVALID_TARGET_TILE)
		if door_tile.x < 0:
			continue
		active[door_tile] = true
	return active

func _locked_door_tiles_for_board() -> Dictionary:
	var locked: Dictionary = {}
	var current_coord: Vector2i = _run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, current_coord)
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var destination: Vector2i = connection.get("coord", Vector2i(999, 999))
		var destination_room: Dictionary = _run_engine.room_metadata(_run_state, destination)
		if not bool(destination_room.get("visited", false)) or not bool(destination_room.get("sealed", false)):
			continue
		var door_tile: Vector2i = RoomGeneratorScript.door_tile_for_direction(connection.get("door_dir", Vector2i.ZERO))
		if door_tile.x < 0:
			continue
		locked[door_tile] = true
	return locked

func _process_victory_carry() -> void:
	if _is_debug_boss_run():
		_victory_carry_amount = _run_engine.held_embers(_run_state)
		_victory_carry_processed = true
		return
	_record_terminal_run_result()
	var amount: int = _run_engine.held_embers(_run_state)
	_victory_carry_amount = amount
	_progression = ProgressionStore.set_embers(_progression, amount)
	ProgressionStore.save_data(_progression)
	_run_state = _run_engine.clear_held_embers(_run_state)
	_run_state["progression"] = _progression.duplicate(true)
	_victory_carry_processed = true

func _process_defeat_loss() -> void:
	if _is_debug_boss_run():
		_defeat_lost_amount = _run_engine.held_embers(_run_state)
		_defeat_loss_processed = true
		return
	_record_terminal_run_result()
	var lost_amount: int = _run_engine.held_embers(_run_state)
	_defeat_lost_amount = lost_amount
	_progression = ProgressionStore.record_lost_embers(
		_progression,
		lost_amount,
		_run_state.get("current_room", Vector2i.ZERO),
		int(_run_state.get("run_index", 0))
	)
	ProgressionStore.save_data(_progression)
	_run_state = _run_engine.clear_held_embers(_run_state)
	_run_state["progression"] = _progression.duplicate(true)
	_defeat_loss_processed = true

func _record_terminal_run_result() -> void:
	_run_state = _terminal_state_with_recorded_run_result(_run_state, _progression)
	_progression = (_run_state.get("progression", _progression) as Dictionary).duplicate(true)

func _terminal_state_with_recorded_run_result(terminal_state: Dictionary, progression: Dictionary) -> Dictionary:
	var state: Dictionary = terminal_state.duplicate(true)
	if str(state.get("mode", "")) not in ["victory", "defeat"] or bool(state.get("debug_boss_run", false)):
		return state
	var result_stats: Dictionary = RunEndRecapOverlay.result_stats(state)
	var result_id: String = RunEngineScript.run_result_id(state)
	var recorded: Dictionary = ProgressionStore.record_run_result(progression, result_id, result_stats)
	var next_progression: Dictionary = (recorded.get("data", progression) as Dictionary).duplicate(true)
	var result: Dictionary = (recorded.get("result", {}) as Dictionary).duplicate(true)
	state["progression"] = next_progression
	if not result.is_empty():
		state["run_result"] = result
	return state

func _enemy_occupied_tiles(state: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	for enemy_var: Variant in state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if int(enemy.get("hp", 0)) <= 0:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			occupied[tile] = true
	for illusion_var: Variant in state.get("illusions", []):
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = illusion_var
		if int(illusion.get("hp", 0)) <= 0:
			continue
		occupied[illusion.get("pos", Vector2i.ZERO)] = true
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if int(terrain.get("hp", 0)) <= 0:
			continue
		occupied[terrain.get("pos", Vector2i.ZERO)] = true
	return occupied

func _enemy_footprint_tiles(enemy: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _enemy_key(enemy: Dictionary) -> String:
	return "enemy_%d" % int(enemy.get("id", -1))

func _terrain_key(terrain: Dictionary) -> String:
	var terrain_id: String = str(terrain.get("id", ""))
	if terrain_id.is_empty():
		return ""
	return "terrain_%s" % terrain_id
