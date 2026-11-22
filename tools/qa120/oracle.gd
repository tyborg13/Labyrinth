extends RefCounted
## Read presentation owners first. Recompute after the read, without refreshing UI.

const BadgeModel = preload("res://scripts/intent_badges.gd")
const CardHud = preload("res://scripts/combat_hud_forecast.gd")
const Forecast = preload("res://scripts/pass_forecast_presentation.gd")
const RowPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const Slots = preload("res://scripts/turn_order_slots.gd")
const Model = preload("res://tools/qa110/model.gd")
const CardDisplay = preload("res://scripts/card_display_overrides.gd")
const CardKeywords = preload("res://scripts/card_keyword_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Threats = preload("res://scripts/threat_tiles.gd")
const Bramble = preload("res://scripts/enemy_mechanics/bramble_view.gd")
const Snare = preload("res://scripts/snare_pressure_view.gd")
const Rule = preload("res://scripts/battlefield_rule_view.gd")
const Pattern = preload("res://scripts/pattern_text.gd")

const ALPHA_VISIBLE: float = 0.02

var scene: Node
var forecast_key: Array
var fresh: Dictionary
var source: Dictionary
var ends_turn: bool
var board_key: Array
var board_expected: Dictionary
var rest_key: int = -1
var rest_fresh: Dictionary
var cards_key: Array
var hand_expected: Array

# Private caches used by scene model helpers. Keep freshly calculated values
# away from the live hover publisher and restore the reference after each read.
const SCRATCH: Dictionary = {
	"_hover_resolved_preview_key": "", "_hover_resolved_preview_state": {},
	"_surface_resolution_cache_key": "", "_surface_resolution_cache": {},
	"_surface_preview_cache_key": "", "_surface_preview_cache": {},
	"_board_preview_display_cache_key": "", "_board_preview_display_cache": {},
	"_pending_card_known_forecast_cache": {}, "_pending_card_forecast_cache": {},
	"_preview_shortcuts_cache_key": "", "_preview_shortcuts_cache": {},
	"_preview_shortcuts_content_cache": {}, "_preview_shortcuts_content_order": [],
}

func _init(host: Node) -> void:
	scene = host

func sample() -> Dictionary:
	var result: Dictionary = {"checks": [], "issues": {}}
	if scene._animation_lock or scene._combat_state.is_empty(): return result
	var state: Dictionary = scene._combat_state
	var engine: RefCounted = scene._combat_engine
	if not engine.is_player_turn(state) or not engine.combat_outcome(state).is_empty(): return result
	var board: Control = scene.board_view
	var presentation: Dictionary = board.presentation
	var chip: Button = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip")
	var selected: bool = scene._selected_card_index >= 0 or scene._player_movement_selected or scene._surface_aim.active()
	var details: bool = scene._show_all_enemy_intents
	var pass_view: Dictionary = _read_pass(chip)
	var actual_rail: Array = _read_rail()
	var actual_entries: Array = _rail_entries(scene._turn_order_all_entries)
	var state_hash: int = hash(state)
	var engine_rng: Variant = state.get("rng_state")
	_refresh_expected_pass()
	var expected_rail: Array[Dictionary] = _expected_rail(state, source)
	_check_pass(result, pass_view, selected, expected_rail)
	_check_rail(result, actual_entries, actual_rail, expected_rail)
	_check_board(result, board, presentation, state, selected, details)
	_check_hand(result, state)
	if hash(state) != state_hash or state.get("rng_state") != engine_rng:
		push_error("qa120 oracle mutated committed combat")
	result["pending"] = {
		"worker": scene._selected_pass_work._step,
		"owns_selection": scene._selected_pass_work.active(scene),
		"board_hover": scene._board_hover_refresh_pending,
		"hand_hover": scene._hand_hover_refresh_pending or scene._hand_hover_rest_pending,
		"rail_animation": scene._turn_order_animating,
	}
	return result

func _refresh_expected_pass() -> void:
	var key: Array = [scene._combat_preview_revision, scene._preview_selection_revision, scene._pass_preview_key()]
	if key == forecast_key: return
	forecast_key = key
	var completes_before: bool = scene._pass_preview_source_completes_card
	var movement_before: int = scene._pass_preview_source_movement_left
	var saved: Dictionary = _begin_scratch()
	source = scene._build_pass_preview_source_state_for_tile(scene._hovered_board_tile, false)
	_end_scratch(saved)
	var completes: bool = scene._pass_preview_source_completes_card
	var movement: int = scene._pass_preview_source_movement_left
	scene._pass_preview_source_completes_card = completes_before
	scene._pass_preview_source_movement_left = movement_before
	fresh = {}
	ends_turn = false
	if source.is_empty() or not scene._combat_engine.is_player_turn(source): return
	var engine: RefCounted = scene._combat_engine
	var paid: Dictionary = source.duplicate(false)
	if movement >= 0: paid["player_movement_remaining"] = movement
	ends_turn = completes and engine.player_turn_resources_exhausted(paid)
	var scheduled: Dictionary = Red.schedule(engine, source.duplicate(true))
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
	fresh = scene._pass_preview_summary_for_phase_result(source, phase)

func _read_pass(chip: Button) -> Dictionary:
	if chip == null: return {}
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip")
	var rows: Array = []
	var panel_showing: bool = panel != null and panel.is_visible_in_tree() and panel.modulate.a > ALPHA_VISIBLE
	if panel_showing:
		for row: Control in panel.get_node("ForecastRows").get_children():
			var parts: Array = []
			for child: Node in row.get_children():
				if child is RichTextLabel and child.is_visible_in_tree(): parts.append(child.get_parsed_text())
			rows.append(parts)
	return {
		"visible": chip.is_visible_in_tree(), "active": chip.get_meta("pass_forecast_active", false),
		"focus": chip.has_focus() or chip.get_meta("pass_pointer_hover", false) or chip.get_meta("pass_keyboard_focus", false),
		"label": chip.get_node("PassForecastContent/PassActionLabel").text, "disabled": chip.disabled,
		"tooltip": chip.tooltip_text, "summary": chip.get_meta("pass_forecast_summary", {}),
		"panel_showing": panel_showing, "rows": rows,
	}

func _check_pass(result: Dictionary, shown: Dictionary, selected: bool, expected_rail: Array[Dictionary]) -> void:
	if not Forecast.allowed(scene): return
	var can_pass: bool = scene._pass_preview_action_available()
	var previewed: bool = selected and Forecast.preview_active(scene)
	var show_ends: bool = ends_turn and previewed and not scene._auto_pass_tutorial_hold() and not scene._surface_aim.active()
	var active: bool = not fresh.is_empty() and (previewed or show_ends or (can_pass and shown.get("focus", false)))
	result["checks"].append("pass_dock")
	compare(result, "pass.dock_visibility", not fresh.is_empty(), shown.get("visible", false))
	if not shown.get("visible", false): return
	compare(result, "pass.enabled", can_pass, not shown["disabled"])
	var cost: int = scene._pending_card_defiance_spent()
	compare(result, "pass.label", "CARD COST\nDEFIANCE −%d" % cost if cost > 0 else "PASS", shown["label"])
	result["checks"].append("pass_panel")
	compare(result, "pass.panel_active", active, shown["active"])
	if fresh.is_empty() or (selected and not active and not shown["focus"]): return
	var tooltip: String = scene._pass_preview_tooltip(fresh)
	var with_cost: String = "Playing this card spends %d Defiance.\n%s" % [cost, tooltip]
	if cost <= 0 or shown["tooltip"] != with_cost:
		compare(result, "pass.tooltip", tooltip, shown["tooltip"])
	compare(result, "pass.summary", summary_numbers(fresh), summary_numbers(shown["summary"]))
	if not active or not shown["panel_showing"]: return
	result["checks"].append("pass_visible_rows")
	var colors: Dictionary = {"block": Color.WHITE, "stoneskin": Color.WHITE, "health": Color.WHITE, "defiance": Color.WHITE, "unknown": Color.WHITE}
	var live_rail: Array[Dictionary] = scene._turn_order_all_entries
	scene._turn_order_all_entries = expected_rail
	var portraits: Array[Dictionary] = Slots.pass_repeat_portraits(scene, fresh, source)
	scene._turn_order_all_entries = live_rail
	var rows: Array[Dictionary] = RowPanel.rows(fresh, portraits, colors)
	if fresh.get("terminal_unknown", false):
		rows.assign(rows.filter(func(row: Dictionary) -> bool: return row["parts"][0].get("text", "") != "Safe"))
	if int(fresh.get("skipped_turns", 0)) > 0: rows.push_front(RowPanel.turn_skipped_row(int(fresh["skipped_turns"])))
	if show_ends: rows.push_front(RowPanel.ends_turn_row())
	var expected: Array = []
	for row: Dictionary in rows:
		expected.append(row["parts"].map(func(part: Dictionary) -> String: return part.get("text", "")))
	compare(result, "pass.rows", expected, shown["rows"])

static func summary_numbers(summary: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["hp_loss", "block_loss", "stoneskin_loss", "defiance_spent", "projected_hp", "wait_time", "status_gains", "skipped_turns", "defeat", "unrevealed_before_player", "umbra_unknown_before_player", "unseen_ground_crossed", "terminal_unknown", "forecast_limit_reached"]:
		if summary.has(key): result[key] = summary[key]
	return result

func _read_rail() -> Array:
	var result: Array = []
	for slot: Control in scene._turn_order_bar.get_children():
		if not slot.is_visible_in_tree() or not slot.has_meta("turn_order_actor_key"): continue
		var label: Label = slot.find_child("TurnOrderTimeNumeral", true, false)
		result.append([str(slot.get_meta("turn_order_actor_key")), label.text if label != null else "",
			slot.tooltip_text, str(slot.get_meta("turn_order_projection_card_name", "")),
			int(slot.get_meta("turn_order_projection_wait_time", 0))])
	return result

func _rail_entries(entries: Array) -> Array:
	var result: Array = []
	for entry: Dictionary in entries:
		result.append([scene._turn_order_actor_key(entry), scene._turn_order_relative_time(entry),
			entry.get("projection_kind", ""), entry.get("projected_card_name", ""), int(entry.get("projected_wait_time", 0))])
	return result

func _expected_rail(state: Dictionary, projected: Dictionary) -> Array[Dictionary]:
	var delays: Dictionary = scene._combat_engine.stagger_delays_between(state, projected) if not projected.is_empty() and scene._selected_card_index >= 0 else {}
	var visible_ids: Array = scene._combat_engine.visible_enemy_ids(state)
	for id: Variant in delays.keys():
		if int(delays[id]) <= 0 or not visible_ids.has(int(id)): delays.erase(id)
	var display: Dictionary = scene._turn_order_display_state(delays)
	var limit: int = maxi(scene.TURN_ORDER_DISCLOSURE_LIMIT, (state.get("turn_queue", []) as Array).size() * 2 + 2)
	return scene._combat_engine.current_turn_order(display, limit)

func _check_rail(result: Dictionary, shown_entries: Array, shown_rail: Array, entries: Array[Dictionary]) -> void:
	if not scene._turn_order_bar.is_visible_in_tree() or scene._turn_order_animating: return
	result["checks"].append("rail")
	compare(result, "rail.projection", _rail_entries(entries), shown_entries)
	var count: int = int(scene._combat_hud_layout.right_column.plan.get("visible", 0))
	var slots: Array = []
	for index: int in range(mini(entries.size(), count)):
		var entry: Dictionary = entries[index]
		slots.append([scene._turn_order_actor_key(entry), scene._turn_order_clock_badge_text(entry),
			_rail_tooltip(entry, index), str(entry.get("projected_card_name", "")), int(entry.get("projected_wait_time", 0))])
	compare(result, "rail.widgets", slots, shown_rail)
	var overflow: Control = scene._turn_order_bar.get_node_or_null("TurnOrderOverflowEntry")
	var remaining: Array[Dictionary] = scene._turn_order_array(entries.slice(count))
	compare(result, "rail.overflow", scene._turn_order_overflow_tooltip(remaining),
		overflow.tooltip_text if overflow != null and overflow.is_visible_in_tree() else "")

func _rail_tooltip(entry: Dictionary, index: int) -> String:
	if entry.get("kind", "") != "beat": return scene._turn_order_tooltip(entry, index)
	var sentence: String = entry.get("sentence", "")
	var diagram: String = Pattern.display_rules(sentence)
	return ("%s — %s" if sentence == diagram else "%s\n%s") % [entry.get("name", ""), diagram]

func _check_board(result: Dictionary, board: Control, shown: Dictionary, state: Dictionary, selected: bool, details: bool) -> void:
	if not board.is_visible_in_tree(): return
	var key: Array = [forecast_key, selected, details, scene._hovered_board_tile]
	if key != board_key:
		board_key = key
		board_expected = _board_model(state, selected, details)
	result["checks"].append("board_red")
	compare(result, "board.red", board_expected["red"], _tile_keys(Model._floor_red(board)))
	result["checks"].append("board_intents")
	compare(result, "board.intent_plates", board_expected["plates"], _plates(shown.get("threats_at_rest", {}).get("badges", [])))
	if details:
		result["checks"].append("details")
		compare(result, "details.intents", board_expected["details"], _details(shown.get("enemy_threat_previews", [])))
	if scene._selected_card_index >= 0 or scene._player_movement_selected:
		result["checks"].append("card_damage_and_status")
		compare(result, "card.damage", board_expected["damage"], board._damage_preview_map())
		compare(result, "card.status", board_expected["status"], shown.get("surface_status_preview", {}))
		compare(result, "card.hud_values", board_expected["hud"], shown.get(CardHud.KEY, {}))

func _board_model(state: Dictionary, selected: bool, details: bool) -> Dictionary:
	var saved: Dictionary = _begin_scratch()
	var display: Dictionary = scene._board_display_state() if selected else state
	var intent: Dictionary = source if scene._selected_card_index >= 0 and not source.is_empty() else display
	if scene._player_movement_selected and scene._player_movement_target_tiles.has(scene._hovered_board_tile):
		intent = BadgeModel.movement_preview(scene._combat_engine, state, source)
	# Director rule (gfix-23): an aim with no legal target cannot play the card;
	# plates, pips, danger and red are the no-card view, marked by the at-rest forecast.
	var no_play: bool = scene._selected_aim_has_no_play()
	if no_play: intent = state
	var model: Dictionary = BadgeModel.new().presentation_for_state(scene._combat_engine, state, intent, "",
		scene._surface_preview_information_state.bind(intent, state))
	var marks: Dictionary = Discs.record(_rest_forecast(state) if no_play else fresh, scene._combat_preview_revision)
	var expected: Dictionary = Discs.apply(model, marks, scene._combat_preview_revision, true)
	var floor: Variant = Red.floor_override(model, expected, marks)
	var ground: Dictionary = {"threats_at_rest": {"threats": expected.get("threats", []) if floor == null else floor}}
	var visibility: Dictionary = scene._combat_engine.umbra_visible_tile_lookup(scene._board_visibility_state(display))
	var visible_ids: Array = scene._combat_engine.visible_enemy_ids(scene._board_visibility_state(display))
	ground["umbra_visible_tiles"] = visibility.keys()
	ground["visible_enemy_ids"] = visible_ids
	ground["umbra_stage"] = scene.board_view.presentation.get("umbra_stage", "")
	ground = Rule.presentation_for(display, Snare.presentation_for(display, Bramble.presentation_for(display, ground), true))
	var red: Dictionary = Threats.tile_alphas(ground.get("threats_at_rest", {}).get("threats", []))
	for tile: Vector2i in model.get(Threats.LOB_AIM_KEY, {}):
		if visibility.has(tile): red[tile] = true
	for tile: Vector2i in red.keys():
		if not visibility.has(tile) and not Threats.announced_at(ground, tile): red.erase(tile)
	var result: Dictionary = {"red": _tile_keys(red), "plates": _plates(expected.get("badges", []))}
	if details: result["details"] = _details(scene._visible_enemy_threat_previews(intent))
	if scene._selected_card_index >= 0 or scene._player_movement_selected:
		var preview: Dictionary = scene._active_card_preview()
		var forecast: Dictionary = scene._preview_presentation(preview) if not preview.is_empty() and not preview.get("complete", false) else {}
		var damage: Dictionary = {}
		if not scene._preview_combat_state.is_empty():
			damage = scene._sanitize_damage_preview_for_umbra_information(state,
				scene._damage_preview_between_states(state, scene._pending_card_known_forecast_state()))
		damage.merge(forecast.get("damage_preview", {}), true)
		damage.merge(forecast.get("effect", {}).get("damage_preview", {}), true)
		result["damage"] = damage
		result["status"] = forecast.get("surface_status_preview", {})
		result["hud"] = CardHud.changes(state, display) if scene._selected_card_index >= 0 else {}
	_end_scratch(saved)
	return result

func _rest_forecast(state: Dictionary) -> Dictionary:
	if rest_key == scene._combat_preview_revision: return rest_fresh
	rest_key = scene._combat_preview_revision
	var engine: RefCounted = scene._combat_engine
	var rest: Dictionary = preload("res://scripts/pass_forecast_action_source.gd").rest_source(scene, state)
	var scheduled: Dictionary = Red.schedule(engine, rest.duplicate(true))
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
	rest_fresh = scene._pass_preview_summary_for_phase_result(rest, phase)
	return rest_fresh

func _begin_scratch() -> Dictionary:
	var saved: Dictionary = {}
	for key: String in SCRATCH:
		var value: Variant = scene.get(key)
		saved[key] = value
		if value is Dictionary or value is Array:
			var blank: Variant = value.duplicate(false)
			blank.clear()
			scene.set(key, blank)
		else:
			scene.set(key, SCRATCH[key])
	return saved

func _end_scratch(saved: Dictionary) -> void:
	for key: String in saved: scene.set(key, saved[key])

func _check_hand(result: Dictionary, state: Dictionary) -> void:
	if not scene.hand_box.is_visible_in_tree() or scene._hand_layout_pending_revision >= 0: return
	var hand: Array = state.get("deck", {}).get("hand", [])
	var empowered: Array = []
	for index: int in range(hand.size()): empowered.append(scene._hand_card_empowered(index))
	var key: Array = [scene._combat_preview_revision, empowered]
	if key != cards_key:
		cards_key = key
		hand_expected.clear()
		for index: int in range(hand.size()):
			var card_id: String = hand[index]
			var card: Dictionary = scene._card_def(card_id, state)
			var display_state: Dictionary = state
			if empowered[index]:
				display_state = state.duplicate(false)
				CardKeywords.stamp_card_start(display_state, card_id, card, true)
			var projection: Dictionary = CardDisplay.for_card(card_id, display_state, card)
			var time: int = maxi(1, int(card.get("time", 5))) + maxi(int(projection.get("time_surcharge", 0)),
				int(card.get("_item_time_surcharge", 0)) + int(card.get("_tempo_time_surcharge", 0)))
			hand_expected.append([card_id, time, Icons.plain_text_for_rows(projection["summary_rows"])])
	var actual: Array = []
	for index: int in range(hand.size()):
		var widget: Control = scene._hand_card_control(index)
		if widget == null or not widget.is_visible_in_tree(): return
		var rows: Array = widget._summary_rows
		if rows.is_empty(): rows = Icons.rows_for_card(widget._display_card_def())
		actual.append([widget.card_id, widget._time_badge.value, Icons.plain_text_for_rows(rows)])
	result["checks"].append("hand_card_values")
	compare(result, "card.hand_time_and_rules", hand_expected, actual)

static func _tile_keys(tiles: Dictionary) -> Array:
	var result: Array = tiles.keys().map(func(tile: Vector2i) -> String: return str(tile))
	result.sort()
	return result

static func _plates(badges: Array) -> Dictionary:
	var result: Dictionary = {}
	for badge: Dictionary in badges:
		var fields: Dictionary = {}
		for key: String in ["order", "number", "secondary_number", "acting", "cancelled", "family", "danger"]:
			if badge.has(key): fields[key] = badge[key]
		# Only two or more activations draw the repeat pip.
		if int(badge.get("repeats", 0)) >= 2: fields["repeats"] = badge["repeats"]
		result[str(badge["key"])] = fields
	return result

static func _details(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var fields: Dictionary = {}
		for key: String in ["intent", "projected_attack_action", "projected_target_key", "projected_path", "projected_attack", "attack", "move", "damage", "projected_destination"]:
			if row.has(key): fields[key] = row[key]
		result[str(row["enemy_key"])] = fields
	return result

static func compare(result: Dictionary, key: String, expected: Variant, shown: Variant) -> void:
	if expected != shown: result["issues"][key] = {"expected": expected, "shown": shown}
