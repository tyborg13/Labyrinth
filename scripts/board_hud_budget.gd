extends RefCounted

## One immutable HUD budget per encounter/display. Live HUD growth and hand
## focus never feed back into the board solver.
const Fan = preload("res://scripts/hand_fan_container.gd")
const Rail = preload("res://scripts/turn_order_layout.gd")
const RightColumn = preload("res://scripts/combat_hud_right_column.gd")
const RewardSequence = preload("res://scripts/post_combat_reward_sequence.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const EXCLUSION_GAP: float = 12.0
const HAND_BOTTOM_GAP: float = 8.0
var key: Array = []
var exclusions: Array[Rect2]
var collapsed_strip: float = 0.0
var desktop_hand_top: float = 0.0
var _measured_run: Array = []
var _layout_key: Array = []
var _compact: bool = false

func environment(scene: Control) -> Array:
	return [scene.get("_board_encounter_key"), scene.get("_board_encounter_started"),
		scene.get_viewport_rect().size, scene.get_window().content_scale_factor,
		preload("res://scripts/ui_typography.gd").output_size(scene)]

func compact_layout(scene: Control) -> bool:
	# Resolve before the hand's first sort, then retain the output decision with
	# this encounter's HUD budget. Physical size also invalidates scaled windows.
	var current: Array = environment(scene) if scene.is_inside_tree() else []
	if current != _layout_key or current.is_empty():
		_layout_key = current
		_compact = preload("res://scripts/ui_typography.gd").is_handheld_output(scene) \
			or preload("res://scripts/input_router.gd").platform_is_steam_deck()
	return _compact

func capture(scene: Control) -> void:
	key = environment(scene)
	var compact: bool = compact_layout(scene)
	# Published presentations retain this array. Replace it for the next room;
	# mutating it would hide an exclusion change from the board's input diff.
	var next_exclusions: Array[Rect2]
	exclusions = next_exclusions
	collapsed_strip = _collapsed_strip(scene)
	if not compact:
		desktop_hand_top = _desktop_hand_top(scene)
	_capture_visible_exclusions(scene)
	var run: Dictionary = scene.get("_run_state")
	if run.get("mode") != "combat":
		collapsed_strip = 0.0
		return
	_measured_run = [run.get("seed"), run.get("run_index")]
	_capture_combat_exclusions(scene)

func _capture_visible_exclusions(scene: Control, header_growth: float = 0.0) -> void:
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
			if control.get_parent() == scene.top_bar:
				rect.position.y += floorf(header_growth * 0.5)
			_add(rect)
	if scene.relic_bar != null:
		for control: Control in scene.relic_bar.find_children("*", "BaseButton", true, false):
			if control.is_visible_in_tree(): _add(control.get_global_rect())

func _capture_combat_exclusions(scene: Control) -> void:
	if scene.get("_combat_objective_hud") != null and not ((scene.get("_combat_state") as Dictionary).get("objective", {}) as Dictionary).is_empty():
		# The intro's temporary center-screen shell is not its permanent home.
		_add(scene.ui_root.get_global_transform() * scene._combat_objective_hud_target_rect())
	var piles: Rect2 = scene.draw_pile.get_global_rect().merge(scene.discard_pile.get_global_rect())
	var pass_rect: Rect2 = scene._pass_preview_overlay.get_global_rect()
	_capture_rail(scene, scene.get("_combat_state").get("grid", []), minf(piles.position.y, pass_rect.position.y))
	var has_boss: bool = false
	for type: String in scene._board_encounter_types():
		if bool(preload("res://scripts/game_data.gd").enemy_property(type, "boss_bar", false)):
			has_boss = true
	if has_boss:
		scene._layout_boss_health_overlay_content()
		_add(scene._boss_health_overlay.get_global_rect())

func _capture_rail(scene: Control, grid: Array, dock_top: float, header_growth: float = 0.0) -> void:
	var top: float = RightColumn.top(scene) + scene.ui_root.global_position.y + header_growth
	var toggle_space: float = scene.ENEMY_INTENT_TOGGLE_TOP_GAP + scene.ENEMY_INTENT_TOGGLE_HEIGHT
	var available: float = maxf(0.0, dock_top - Rail.DETAILS_PASS_GAP - top - toggle_space)
	# Forecasts can repeat actors and reinforcements can occupy every legal tile.
	var cells: int = 1
	for row: Array in grid:
		cells += row.size()
	var longest: float = maximum_rail_height(scene, maxi(scene.TURN_ORDER_DISCLOSURE_LIMIT, cells * 2 + 2), available)
	var rail_width: float = Rail.column_width(scene)
	_add(Rect2(scene.get_viewport_rect().size.x - scene.TURN_ORDER_RAIL_EDGE_GAP - rail_width,
		top, rail_width, longest + toggle_space))

func can_restore(scene: Control) -> bool:
	var run: Dictionary = scene.get("_run_state")
	if _measured_run == [run.get("seed"), run.get("run_index")]: return false
	return run.get("mode") in ["room", "campfire", "treasure"] \
		or (run.get("mode") == "reward" and not scene._post_combat_board_state().is_empty())

func _source_room(run: Dictionary) -> Vector2i:
	var current: Vector2i = run.get("current_room", Vector2i.ZERO)
	if run.get("mode") in ["campfire", "treasure"] and run.get("guardian_reward", {}).get("room") != current:
		return run.get(RunEngine.SKILL_STATE_KEY, {}).get("previous_room", current)
	return current

func restore(scene: Control) -> void:
	key = environment(scene)
	var next_exclusions: Array[Rect2]
	exclusions = next_exclusions
	collapsed_strip = 0.0
	var run: Dictionary = scene.get("_run_state")
	var source: Vector2i = _source_room(run)
	var room: Dictionary = scene._run_engine.room_metadata(run, source)
	var from_combat: bool = run.get("mode") == "reward" or (
		room.get("cleared", false) and room.get("type") in ["combat", "special", "guardian", "boss"]
		and room.get("npcs", []).is_empty()
	)
	# Godot never sorts the hidden hand into its anchored bottom stack. Use the
	# authored desktop row against the real VBox edge, including the existing
	# victory sink retained by a previously laid-out empty room.
	var hand_parent: Control = scene.bottom_stack.get_parent()
	var hand_bottom: float = floorf(hand_parent.get_global_rect().end.y)
	desktop_hand_top = hand_bottom - scene.DESKTOP_HAND_ROW_HEIGHT
	if not from_combat and not scene._reduced_motion_enabled():
		desktop_hand_top += RewardSequence.HUD_CLEAR_HAND_SINK_PIXELS
	var board: Dictionary = scene._post_combat_board_state()
	if board.is_empty():
		board = run.get("current_room_layout", {})
	var header_growth: float = _combat_header_growth(scene, board) if from_combat else 0.0
	_capture_visible_exclusions(scene, header_growth)
	if from_combat and compact_layout(scene):
		_restore_compact_combat(scene, board, int(run.get("hand_size", RunEngine.BASE_HAND_SIZE)), hand_bottom, header_growth)

func _combat_header_growth(scene: Control, board: Dictionary) -> float:
	# The combat title has an Umbra row. The utility controls center alongside
	# that taller stack, so restore their reservations without showing the row.
	if board.has("umbra") and scene._combat_engine.effective_umbra_stage(board) == scene._combat_engine.UMBRA_STAGE_CLEAR:
		return 0.0
	var title: VBoxContainer = scene.title_box
	var extra: float = scene.umbra_subtitle.get_combined_minimum_size().y + title.get_theme_constant("separation")
	var combat_height: float = title.get_combined_minimum_size().y + extra
	return maxf(0.0, combat_height - scene.top_bar.get_combined_minimum_size().y)

func _restore_compact_combat(scene: Control, board: Dictionary, hand_size: int, row_bottom: float, header_growth: float) -> void:
	# Recover the fan and rail from their live reservations. The hidden hand
	# has no widget to measure, so use the regular card's authored watch badge.
	var card: Control = CardScene.instantiate()
	card.size = scene._hand_card_size(1, false)
	card.call("_ensure_time_badge")
	collapsed_strip = _hand_strip(scene, row_bottom, card, int(board.get("hand_size", hand_size)))
	card.free()
	var viewport_bottom: float = scene.get_viewport_rect().end.y
	var pile_height: float = scene.draw_pile.get_combined_minimum_size().y
	var dock_top: float = viewport_bottom - scene.PILE_HUD_EDGE_MARGIN - pile_height \
		- RightColumn.BOTTOM_DOCK_GAP - scene.PASS_PREVIEW_CHIP_SIZE.y
	_capture_rail(scene, board.get("grid", []), dock_top, header_growth)

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

func _desktop_hand_top(scene: Control) -> float:
	# Measure the full desktop row even if combat begins with a controller or an
	# explicit pointer tuck. Sort synchronously and restore before any frame draws;
	# the frozen board budget must never depend on the current input device/focus.
	var height: float = scene.hand_row.custom_minimum_size.y
	var tuck: int = scene.hand_tuck_margin.get_theme_constant("margin_top")
	scene.hand_row.custom_minimum_size.y = scene.DESKTOP_HAND_ROW_HEIGHT
	scene.hand_tuck_margin.add_theme_constant_override("margin_top", 0)
	scene._sort_targeting_hand_containers()
	var top: float = scene.hand_row.get_global_rect().position.y
	scene.hand_row.custom_minimum_size.y = height
	scene.hand_tuck_margin.add_theme_constant_override("margin_top", tuck)
	scene._sort_targeting_hand_containers()
	return top

func _collapsed_strip(scene: Control) -> float:
	# The CenterContainer grows to the fan's minimum height in SHOW_NEVER mode.
	# Consequently its top is the row top, followed by the authored tuck margin.
	# Measure the real fan rotation and watch overhang, including every smaller
	# hand, without toggling the live hand or depending on its current hover.
	var row_bottom: float = scene.hand_row.get_global_rect().end.y
	var count: int = maxi(1, int((scene.get("_combat_state") as Dictionary).get("hand_size", 5)))
	return _hand_strip(scene, row_bottom, scene._hand_card_control(0), count)

func _hand_strip(scene: Control, row_bottom: float, card: Control, count: int) -> float:
	var row_top: float = row_bottom - scene.CONTROLLER_UNFOCUSED_HAND_ROW_HEIGHT
	var badge: Control = card.get_node_or_null("TimeCostBadge") as Control if card != null else null
	var top: float = scene.get_viewport_rect().end.y
	for total: int in range(1, maxi(1, count) + 1):
		var card_size: Vector2 = scene._hand_card_size(total, false)
		var overhang: float = -minf(0.0, badge.position.y) * card_size.x / card.size.x if badge != null and card.size.x > 0.0 else 0.0
		var extent: Vector2 = Fan.resting_vertical_bounds(total, card_size, overhang)
		top = minf(top, row_top + scene.CONTROLLER_UNFOCUSED_HAND_TOP_MARGIN + extent.x)
	return maxf(0.0, scene.get_viewport_rect().end.y - top)
