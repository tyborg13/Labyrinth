extends RefCounted

## One immutable HUD budget per encounter/display. Live HUD growth and hand
## focus never feed back into the board solver.
const Fan = preload("res://scripts/hand_fan_container.gd")
const Rail = preload("res://scripts/turn_order_layout.gd")
const RightColumn = preload("res://scripts/combat_hud_right_column.gd")
const EXCLUSION_GAP: float = 12.0
const HAND_BOTTOM_GAP: float = 8.0
var key: Array = []
var exclusions: Array[Rect2]
var collapsed_strip: float = 0.0

func environment(scene: Control) -> Array:
	return [scene.get("_board_encounter_key"), scene.get("_board_encounter_started"),
		scene.get_viewport_rect().size, scene.get_window().content_scale_factor]

func capture(scene: Control) -> void:
	key = environment(scene)
	# Published presentations retain this array. Replace it for the next room;
	# mutating it would hide an exclusion change from the board's input diff.
	var next_exclusions: Array[Rect2]
	exclusions = next_exclusions
	collapsed_strip = _collapsed_strip(scene)
	# ui-28 may remove this node entirely. Its Control geometry is the only
	# dependency; no glyph construction, prompt methods or class constants.
	var prompt: Control = scene.get("_controller_prompt_bar") as Control
	if is_instance_valid(prompt) and prompt.is_visible_in_tree(): _add(prompt.get_global_rect())
	for field: String in ["room_title", "room_subtitle", "umbra_subtitle", "stats_label", "_section_map_hud_button", "loadout_button", "grimoire_button", "menu_button", "draw_pile", "discard_pile", "_play_meter", "_movement_meter", "_pass_preview_overlay"]:
		var control: Control = scene.get(field) as Control
		if control != null and control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			if control is Label:
				rect.size.x = minf(rect.size.x, control.get_combined_minimum_size().x)
			elif control is BaseButton:
				# Header notification badges deliberately overhang their button.
				for child: Control in control.find_children("*", "Control", true, false):
					if child.is_visible_in_tree(): rect = rect.merge(child.get_global_rect())
			_add(rect)
	if scene.relic_bar != null:
		for control: Control in scene.relic_bar.find_children("*", "BaseButton", true, false):
			if control.is_visible_in_tree(): _add(control.get_global_rect())
	if str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat":
		collapsed_strip = 0.0
		return
	if scene.get("_combat_objective_hud") != null and not ((scene.get("_combat_state") as Dictionary).get("objective", {}) as Dictionary).is_empty():
		# The intro's temporary center-screen shell is not its permanent home.
		_add(scene.ui_root.get_global_transform() * scene._combat_objective_hud_target_rect())
	var viewport: Vector2 = scene.get_viewport_rect().size
	var piles: Rect2 = scene.draw_pile.get_global_rect().merge(scene.discard_pile.get_global_rect())
	var pass_rect: Rect2 = scene._pass_preview_overlay.get_global_rect()
	var top: float = RightColumn.top(scene) + scene.ui_root.global_position.y
	var available: float = maxf(0.0, minf(piles.position.y, pass_rect.position.y) - Rail.DETAILS_PASS_GAP - top - scene.ENEMY_INTENT_TOGGLE_TOP_GAP - scene.ENEMY_INTENT_TOGGLE_HEIGHT)
	# Forecasts can repeat actors; summons/reinforcements can occupy every legal
	# tile. Compression makes rail height non-monotonic before overflow.
	var cells: int = 1
	for row: Array in (scene.get("_combat_state") as Dictionary).get("grid", []):
		cells += row.size()
	var longest: float = maximum_rail_height(scene, maxi(scene.TURN_ORDER_DISCLOSURE_LIMIT, cells * 2 + 2), available)
	var rail_width: float = Rail.column_width(scene)
	_add(Rect2(viewport.x - scene.TURN_ORDER_RAIL_EDGE_GAP - rail_width, top,
		rail_width, longest + scene.ENEMY_INTENT_TOGGLE_TOP_GAP + scene.ENEMY_INTENT_TOGGLE_HEIGHT))
	var has_boss: bool = false
	for type: String in scene._board_encounter_types():
		if bool(preload("res://scripts/game_data.gd").enemy_property(type, "boss_bar", false)):
			has_boss = true
	if has_boss:
		scene._layout_boss_health_overlay_content()
		_add(scene._boss_health_overlay.get_global_rect())

static func maximum_rail_height(scene: Node, count_limit: int, available: float) -> float:
	var longest: float = 0.0
	for count: int in range(1, count_limit + 1):
		var plan: Dictionary = Rail.solve(scene, count, available)
		longest = maxf(longest, float(plan.height))
		# Once MIN_SCALE cannot fit this count, solve removes trailing slots.
		# Its measured slots are a count-independent prefix: all larger counts
		# therefore keep that same prefix at MIN_SCALE and the same height.
		# Overflow only moves the last portrait horizontally. Keep auditing all
		# compressed fits before this boundary; their heights can rise and fall.
		if int(plan.overflow) > 0: break
	return longest

func _add(rect: Rect2) -> void:
	if rect.has_area(): exclusions.append(rect.grow(EXCLUSION_GAP))

func _collapsed_strip(scene: Control) -> float:
	# The CenterContainer grows to the fan's minimum height in SHOW_NEVER mode.
	# Consequently its top is the row top, followed by the authored tuck margin.
	# Measure the real fan rotation and watch overhang, including every smaller
	# hand, without toggling the live hand or depending on its current hover.
	var row_bottom: float = scene.hand_row.get_global_rect().end.y
	var row_top: float = row_bottom - scene.CONTROLLER_UNFOCUSED_HAND_ROW_HEIGHT
	var card: Control = scene._hand_card_control(0)
	var badge: Control = card.get_node_or_null("TimeCostBadge") as Control if card != null else null
	var top: float = scene.get_viewport_rect().end.y
	var count: int = maxi(1, int((scene.get("_combat_state") as Dictionary).get("hand_size", 5)))
	for total: int in range(1, count + 1):
		var card_size: Vector2 = scene._hand_card_size(total, false)
		var overhang: float = -minf(0.0, badge.position.y) * card_size.x / card.size.x if badge != null and card.size.x > 0.0 else 0.0
		var extent: Vector2 = Fan.resting_vertical_bounds(total, card_size, overhang)
		top = minf(top, row_top + scene.CONTROLLER_UNFOCUSED_HAND_TOP_MARGIN + extent.x)
	return maxf(0.0, scene.get_viewport_rect().end.y - top)
