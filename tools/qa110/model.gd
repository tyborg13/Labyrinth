extends RefCounted
## Compare displayed widgets with engine state and newly computed forecasts.

const Cards = preload("res://scripts/card_widget.gd")
const Fan = preload("res://scripts/hand_fan_container.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const BoardAudit = preload("res://tools/atk06/audit.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const RuleView = preload("res://scripts/battlefield_rule_view.gd")
const BrambleView = preload("res://scripts/enemy_mechanics/bramble_view.gd")
const SnareView = preload("res://scripts/snare_pressure_view.gd")
const ThreatTiles = preload("res://scripts/threat_tiles.gd")
const ForecastPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const SLOT_TOLERANCE_PX: float = 2.0

static func hand(scene: Node, checks: Dictionary) -> void:
	var issues: Array[Dictionary]
	checks["hand"] = issues
	var fan: Control = scene.hand_box
	if not fan.is_visible_in_tree():
		checks.erase("hand")
		return
	var expected: Array[String] = scene._combat_hand_cards(scene._combat_state)
	var actual: Array[String]
	var slots: Array[Control] = fan._layout_children()
	for index: int in range(slots.size()):
		var slot: Control = slots[index]
		var widget: Control = scene._hand_card_control(index)
		actual.append(widget.card_id if widget is Cards else "")
		var expected_rect: Rect2 = Fan.emphasized_card_rect_for_layout(
			index, slots.size(), fan._child_layout_size(slot), fan._card_gap,
			fan._fan_enabled, fan._emphasized_index, fan._emphasis_strength,
			fan._arch_height, fan._emphasis_scale, fan._emphasis_extra_lift)
		var offset: Vector2 = slot.position - expected_rect.position
		if offset.length() > SLOT_TOLERANCE_PX:
			issues.append({"kind": "slot_offset", "index": index, "offset": offset, "card": actual.back()})
		if widget is Cards and widget.is_visible_in_tree():
			var expected_center: Vector2 = card_center(scene, slot, widget)
			var actual_center: Vector2 = widget.get_global_transform_with_canvas() * (widget.size * 0.5)
			if expected_center.distance_to(actual_center) > SLOT_TOLERANCE_PX:
				issues.append({"kind": "card_offset", "index": index, "offset": actual_center - expected_center,
					"card": widget.card_id, "slot_size": slot.size, "widget_size": widget.size,
					"widget_position": widget.position, "expected_center": expected_center, "card_center": actual_center})
	if actual != expected:
		issues.append({"kind": "hand_ids", "expected": expected, "actual": actual})

static func card_center(scene: Node, slot: Control, widget: Control) -> Vector2:
	# The scale frame centers a native-size card. The CardWidget then applies
	# its own authored hover/selected lift, independently of the fan's pose.
	var native_size: Vector2 = scene.CARD_WIDGET_BASE_SIZE
	var scale_factor: float = scene._card_widget_scale_for_size(slot.size)
	var scaler_position: Vector2 = (slot.size - native_size * scale_factor) * 0.5
	var pose: Dictionary = widget._pose_target()
	var target_scale: Vector2 = pose.get("scale", Vector2.ONE)
	var lift := Vector2(0.0, pose.get("lift", 0.0))
	var card_point: Vector2 = lift + widget.pivot_offset + (native_size * 0.5 - widget.pivot_offset) * target_scale
	return slot.get_global_transform_with_canvas() * (scaler_position + scale_factor * card_point)

static func rail(scene: Node, _selected: bool, checks: Dictionary) -> void:
	if not scene._turn_order_bar.is_visible_in_tree(): return
	var state: Dictionary = scene._turn_order_display_state()
	var limit: int = maxi(scene.TURN_ORDER_DISCLOSURE_LIMIT, state.get("turn_queue", []).size() * 2 + 2)
	var entries: Array[Dictionary] = scene._combat_engine.current_turn_order(state, limit)
	var actual: Array[String]
	var expected: Array[String]
	var visible: int = int(scene._combat_hud_layout.right_column.plan.get("visible", 0))
	var overflow: Control
	for slot: Control in scene._turn_order_bar.get_children():
		if slot.is_visible_in_tree() and slot.has_meta("turn_order_actor_key"):
			actual.append(str(slot.get_meta("turn_order_actor_key")))
		if slot.is_visible_in_tree() and slot.name == &"TurnOrderOverflowEntry": overflow = slot
	for entry: Dictionary in entries.slice(0, visible):
		expected.append("%s:%s" % [entry.get("kind", ""), entry.get("actor_key", "")])
	checks["rail"] = []
	if expected != actual:
		checks["rail"].append({"kind": "actor_order", "expected": expected, "actual": actual})

	var remaining: Array[Dictionary] = scene._turn_order_array(entries.slice(visible))
	var expected_overflow: String = scene._turn_order_overflow_tooltip(remaining) if not remaining.is_empty() else ""
	var actual_overflow: String = overflow.tooltip_text if is_instance_valid(overflow) else ""
	if expected_overflow != actual_overflow:
		checks["rail"].append({"kind": "overflow_order", "expected": expected_overflow, "actual": actual_overflow})

static func forecasts(scene: Node, board: Control, selected: bool, checks: Dictionary) -> void:
	var state: Dictionary = scene._combat_state
	var engine: RefCounted = scene._combat_engine
	if not engine.is_player_turn(state) or not engine.combat_outcome(state).is_empty(): return
	present_red(scene, board, state, selected, checks)
	var chip: Button = scene.find_child("PassPreviewChip", true, false)
	var can_pass: bool = not scene._animation_lock and not scene._surface_aim.active() and scene._selected_card_index < 0 and scene._drag_card_index < 0 and scene._card_action_choice_index < 0 and scene._combat_skill_card_selection_zone.is_empty()
	checks["pass"] = []
	if chip == null or not chip.is_visible_in_tree():
		if can_pass and scene._pass_preview_overlay.is_visible_in_tree():
			checks["pass"].append({"kind": "missing_button"})
		return
	if chip.disabled == can_pass:
		checks["pass"].append({"kind": "disabled", "disabled": chip.disabled, "expected": not can_pass})
	# An unowned forecast panel may retain cached rows while hidden. Only the
	# provided button tooltip and currently shown numbers are evidence.
	if selected and not scene._selected_card_forecast_needed(chip): return
	var source: Dictionary = scene._pass_preview_source_state().duplicate(true)
	if source.is_empty() or not engine.is_player_turn(source): return
	var scheduled: Dictionary = Red.schedule(engine, source)
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
	var fresh: Dictionary = scene._pass_preview_summary_for_phase_result(source, phase)
	var shown: Dictionary = chip.get_meta("pass_forecast_summary", {})
	var label: Label = chip.find_child("PassActionLabel", true, false)
	var cost: int = scene._pending_card_defiance_spent()
	var text: String = "CARD COST\nDEFIANCE -%d" % cost if cost > 0 else "PASS"
	var tooltip: String = scene._pass_preview_tooltip(fresh)
	var with_cost: String = "Playing this card spends %d Defiance.\n%s" % [cost, tooltip] if cost > 0 else tooltip
	var fields: Dictionary = {}
	for key: String in ["hp_loss", "block_loss", "stoneskin_loss", "defiance_spent", "skipped_turns", "defeat", "umbra_unknown_before_player", "terminal_unknown", "unrevealed_before_player"]:
		if fresh.get(key) != shown.get(key): fields[key] = [shown.get(key), fresh.get(key)]
	if label == null or label.text != text or chip.tooltip_text not in [tooltip, with_cost] or not fields.is_empty():
		checks["pass"].append({"kind": "forecast", "label": label.text if label != null else "", "actual_tooltip": chip.tooltip_text, "expected_tooltip": tooltip, "fields": fields})
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip")
	if panel == null or not panel.is_visible_in_tree() or panel.modulate.a <= 0.02: return
	var inks: Dictionary = {"block": Color.WHITE, "stoneskin": Color.WHITE, "health": Color.WHITE, "defiance": Color.WHITE, "unknown": Color.WHITE}
	var portraits: Array[Dictionary] = preload("res://scripts/turn_order_slots.gd").pass_repeat_portraits(scene, fresh, source)
	var rows: Array[Dictionary] = ForecastPanel.rows(fresh, portraits, inks)
	if bool(fresh.get("terminal_unknown", false)):
		rows.assign(rows.filter(func(row: Dictionary) -> bool: return row.get("parts", [])[0].get("text", "") != "Safe"))
	if int(fresh.get("skipped_turns", 0)) > 0: rows.push_front(ForecastPanel.turn_skipped_row(int(fresh["skipped_turns"])))
	if bool(chip.get_meta("pass_ends_turn_preview", false)): rows.push_front(ForecastPanel.ends_turn_row())
	var expected_rows: Array = []
	for row: Dictionary in rows:
		var parts: Array = []
		for part: Dictionary in row.get("parts", []): parts.append(part.get("text", ""))
		expected_rows.append(parts)
	var actual_rows: Array = []
	var column: Control = panel.get_node_or_null("ForecastRows")
	if column != null:
		for row: Control in column.get_children():
			var parts: Array = []
			for child: Node in row.get_children():
				if child is RichTextLabel and child.is_visible_in_tree(): parts.append(child.get_parsed_text())
			actual_rows.append(parts)
	if actual_rows != expected_rows:
		checks["pass"].append({"kind": "forecast_rows", "actual": actual_rows, "expected": expected_rows})

static func present_red(scene: Node, board: Control, state: Dictionary, selected: bool, checks: Dictionary) -> void:
	var snapshot: Dictionary = state.duplicate(true)
	var display: Dictionary = scene._board_display_state().duplicate(true) if selected else snapshot
	var preview: Dictionary = scene._enemy_intent_preview_state(display).duplicate(true) if selected else snapshot
	var known: Callable = scene._surface_preview_information_state.bind(preview, snapshot)
	var fresh: Dictionary = Badges.new().presentation_for_state(scene._combat_engine, snapshot, preview, "", known)
	# In-world telegraphs also contribute red; preserve the rule and lob
	# treatments while leaving sequential Pass corrections out of this oracle.
	var live: Dictionary = board.presentation
	var base: Dictionary = {}
	for key: String in ["umbra_visible_tiles", "umbra_stage", "visible_enemy_ids"]:
		if live.has(key): base[key] = live[key]
	base["threats_at_rest"] = fresh
	var decorated: Dictionary = BrambleView.presentation_for(display, base)
	decorated = SnareView.presentation_for(display, decorated, true)
	decorated = RuleView.presentation_for(display, decorated)
	var expected: Dictionary = ThreatTiles.tile_alphas(decorated.get("threats_at_rest", fresh).get("threats", []))
	var lob: Dictionary = preload("res://scripts/enemy_mechanics/lob_view.gd").marks(board)
	for tile: Vector2i in lob: expected[tile] = true
	var actual: Dictionary = BoardAudit.board_red(board)
	for tile: Vector2i in board._rest_threat_tile_alphas:
		if not actual.has(tile) and ThreatTiles.announced_at(live, tile): actual[tile] = ["public_announcement"]
	var missing: Array = []
	var extra: Array = []
	for tile: Vector2i in expected:
		if (board._board_tile_is_visible_to_player(tile) or ThreatTiles.announced_at(decorated, tile)) and not actual.has(tile):
			missing.append(str(tile))
	for tile: Vector2i in actual:
		if not expected.has(tile): extra.append(str(tile))
	checks["red"] = []
	if not missing.is_empty() or not extra.is_empty():
		var adjusted: Dictionary = Red.adjust_from_summary(fresh, scene._rest_pass_disc_marks)
		var adjusted_set: Dictionary = ThreatTiles.tile_alphas(adjusted.get("threats", []))
		var expected_owners: Dictionary = {}
		for threat: Dictionary in fresh.get("threats", []):
			for tile: Vector2i in threat.get("tiles", []):
				if not missing.has(str(tile)): continue
				var owners: Array = expected_owners.get(str(tile), [])
				owners.append(threat["key"])
				expected_owners[str(tile)] = owners
		var sequential_positions: Array = []
		for tile: Vector2i in adjusted_set:
			if actual.has(tile) and extra.has(str(tile)): sequential_positions.append(str(tile))
		checks["red"].append({"kind": "tile_set", "missing": missing, "extra": extra, "actual": actual, "selected": selected,
			"missing_owners": expected_owners, "extra_from_pass_correction": sequential_positions,
			"removed_before_acting": scene._rest_pass_disc_marks.get("died_first_keys", {})})
