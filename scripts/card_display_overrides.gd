extends RefCounted

## One rules/tooltip projection for hand cards and every run-scoped card preview.
## A supplied definition retains authored upgrade flags/numbers or historical
## snapshots; it must already include the run's definition-level modifiers.
const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CardKeywordRules = preload("res://scripts/card_keyword_rules.gd")
const TempoRules = preload("res://scripts/tempo_rules.gd")
const State = preload("res://scripts/card_display_state.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const ItemText = preload("res://scripts/item_rules_text.gd")
static var _engine := preload("res://scripts/combat_engine.gd").new()

static func apply_projection(widget: Control, card: Dictionary, display: Dictionary) -> void:
	widget.set_card_definition(card)
	# Retain the exact original representation when the definition already
	# renders these rows, including the guardian-rule/Trail row.
	if display["summary_rows"] == ActionIcons.rows_for_card(card) and int(display.get("time_surcharge", 0)) == 0:
		widget.set_display_overrides()
	else:
		widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []), int(display.get("time_surcharge", 0)))

static func bind(widget: Control, state: Dictionary, definition_resolver: Callable = Callable(), variant: Variant = null) -> void:
	Bindings.bind(widget, state, definition_resolver, variant, for_card, apply_projection)

static func refresh(host: Node, state: Dictionary) -> void:
	Bindings.refresh(host, state)

## Pile cache invalidation needs the source identity, never a fresh simulation
## for every copy of every card. Catalog bytes cover test/runtime data edits.
static func definition_signature(cards: Array, state: Dictionary) -> Dictionary:
	var definitions: Dictionary = {}
	for id: Variant in cards:
		if not definitions.has(id): definitions[id] = GameData.cards().get(id, {})
	return {"state": State.inputs(state).duplicate(true), "definitions": definitions.duplicate(true)}

## Item rows and their retention keys use the same projection as card faces.
static func item_rules_snapshot(card_ids: Array, state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: String in card_ids:
		if not id.is_empty() and not result.has(id): result[id] = resolved_rules_text(id, state)
	return result

static func resolved_rules_text(card_id: String, state: Dictionary) -> String:
	if card_id.is_empty(): return ""
	var card: Dictionary = GameData.card_def_for_progression(card_id, State.normalise(state))
	return rules_text(card_id, card, for_card(card_id, state, card)["summary_rows"])

## Items retain authored prose and replace only bound numerals. Other modified
## cards keep their existing text-only inspection representation.
static func rules_text(card_id: String, definition: Dictionary, rows: Array) -> String:
	if bool(definition.get("item", false)):
		return ItemText.resolve(card_id, ActionIcons.card_rules_text(definition), rows)
	var base: Dictionary = for_card(card_id, {})
	if rows == base["summary_rows"]:
		return ActionIcons.card_rules_text(definition)
	return ActionIcons.plain_text_for_rows(rows)

static func for_card(card_id: String, state: Dictionary, definition: Dictionary = {}) -> Dictionary:
	state = State.normalise(state)
	var card: Dictionary = GameData.card_def_for_progression(card_id, state) if definition.is_empty() else definition
	# Follow-up / Empower values are shown honestly once they apply.
	var keyword_state: Dictionary = CardKeywordRules.play_modifiers(state, card_id, card)
	var summary_rows: Array = ActionIcons.cost_rows_for_card(card)
	var modifier_lines: PackedStringArray = []
	# Display simulation replaces only turn_flags (with its own copy). It never
	# mutates the board, decks or history: retain those read-only references.
	var preview_state: Dictionary = state.duplicate(false)
	var previous_action_row_index: int = -1
	for action_var: Variant in CardKeywordRules.actions_with_modifiers(card, keyword_state):
		var action: Dictionary = action_var
		if action.has(CardKeywordRules.KEYWORD_APPENDED_FLAG):
			continue # Shown once, in its active Follow-up / Empower segment.
		var action_type: String = str(action.get("type", ""))
		var row: Array = []
		# Pending next-attack Pierce/Chain shows on the attack that will use it.
		action = TempoRules.display_action(preview_state, action)
		# Reuse combat's duration rule; presentation never changes the definition
		# or spends a skill. Long Dawn also affects items such as Seer's Candle.
		if action_type in ["illuminate", "vision", "truesight"] or action.has("illuminate_duration"):
			action = action.duplicate(false)
			if action_type in ["illuminate", "vision", "truesight"]:
				action["duration"] = _engine._radiance_duration_for_player(state, int(action.get("duration", action.get("amount", 1) if action_type == "truesight" else 1)))
			if action.has("illuminate_duration"):
				action["illuminate_duration"] = _engine._radiance_duration_for_player(state, int(action["illuminate_duration"]))
		match action_type:
			"melee", "ranged", "aoe", "detonate", "convert_surface", "discharge", "all_enemies", "meteor_marks":
				var attack_final_damage: int = _engine.final_damage_for_player_action(preview_state, action)
				var attack_damage_modifiers: Array[Dictionary] = _engine.damage_modifiers_for_player_action(preview_state, action)
				var attack_visible_modifiers: Array[Dictionary] = attack_damage_modifiers
				row = ActionIcons.tokens_for_action(action, {
					"final_damage": attack_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(attack_final_damage, attack_visible_modifiers, action),
					"damage_modifiers": attack_visible_modifiers
				})
				consume_preview_damage_modifiers(preview_state, action)
			"destroy_illusion", "burst_terrain":
				# The blast is a player-card attack on the struck tiles: attack
				# bonuses apply, next-attack buffs do not (spec/card_mechanics_illusions_terrain.md).
				var blast: Dictionary = _engine.blast_action_for_player_action(action)
				var blast_final_damage: int = _engine.final_damage_for_player_action(preview_state, blast)
				var blast_modifiers: Array[Dictionary] = _engine.damage_modifiers_for_player_action(preview_state, blast)
				row = ActionIcons.tokens_for_action(action, {
					"final_damage": blast_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(blast_final_damage, blast_modifiers, blast),
					"damage_modifiers": blast_modifiers
				})
				if blast_final_damage > 0 and _engine.attack_bonus_for_current_turn(preview_state) != 0:
					var blast_flags: Dictionary = (preview_state.get("turn_flags", {}) as Dictionary).duplicate(true)
					blast_flags["first_attack_bonus_used"] = true
					preview_state["turn_flags"] = blast_flags
			"push", "pull":
				var shove_final_damage: int = _engine.final_damage_for_player_action(preview_state, action)
				var shove_damage_modifiers: Array[Dictionary] = _engine.damage_modifiers_for_player_action(preview_state, action)
				var shove_visible_modifiers: Array[Dictionary] = shove_damage_modifiers
				row = ActionIcons.tokens_for_action(action, {
					"final_damage": shove_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(shove_final_damage, shove_visible_modifiers, action),
					"damage_modifiers": shove_visible_modifiers
				})
				consume_preview_damage_modifiers(preview_state, action)
			_:
				row = ActionIcons.tokens_for_action(action)
		var annotated_row: Array = row
		previous_action_row_index = ActionIcons.append_action_row(summary_rows, action, annotated_row, previous_action_row_index)
		var guardian_row: Array = ActionIcons.tokens_for_guardian_rule(action)
		if not guardian_row.is_empty(): summary_rows.append(guardian_row)
		var bonus_row: Array = ActionIcons.tokens_for_surface_bonus(action)
		if not bonus_row.is_empty():
			summary_rows.append(bonus_row)
		summary_rows.append_array(ActionIcons.keyword_rider_rows(action))
	summary_rows.append_array(ActionIcons.keyword_rows_for_card(card, keyword_state))
	summary_rows.append_array(ActionIcons.rules_text_rows_for_card(card))
	var summary_text: String = ActionIcons.plain_text_for_rows(summary_rows)
	if summary_text.is_empty():
		summary_text = ActionIcons.card_rules_text(card)
	var display: Dictionary = {
		"summary_bbcode": summary_text,
		"summary_rows": summary_rows,
		"modifier_lines": modifier_lines
	}
	# A toggled Empower +Time shows on the card's own Time badge, matching the
	# turn-order rail's preview (and its tooltip names the surcharge).
	var time_surcharge: int = CardKeywordRules.empower_time_surcharge(state, card_id, card) + int(card.get("_tempo_time_surcharge", 0)) + int(card.get("_item_time_surcharge", 0))
	if time_surcharge > 0:
		display["time_surcharge"] = time_surcharge
	return display

static func _damage_tone_base_excluding_modifiers(
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

static func consume_preview_damage_modifiers(state: Dictionary, action: Dictionary, engine: RefCounted = null) -> void:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["melee", "ranged", "aoe", "push", "pull", "detonate"]:
		return
	TempoRules.consume_for_preview(state, action)
	if int(action.get("damage", 0)) <= 0:
		return
	# The sequence's resolver owns its effects/cache (including synthetic and
	# legacy effects). card-02's shared display engine may have different inputs.
	var resolver: RefCounted = engine if engine != null else _engine
	if resolver.attack_bonus_for_current_turn(state) == 0:
		return
	var turn_flags: Dictionary = (state.get("turn_flags", {}) as Dictionary).duplicate(true)
	turn_flags["first_attack_bonus_used"] = true
	state["turn_flags"] = turn_flags

