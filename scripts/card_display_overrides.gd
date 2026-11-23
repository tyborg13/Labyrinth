extends RefCounted

## One rules/tooltip projection for hand cards and every run-scoped card preview.
## A supplied definition retains authored upgrade flags/numbers or historical
## snapshots; it must already include the run's definition-level modifiers.
const Combat = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CardKeywordRules = preload("res://scripts/card_keyword_rules.gd")
const TempoRules = preload("res://scripts/tempo_rules.gd")
const DefenseRules = preload("res://scripts/defense_relic_rules.gd")
const CommonRelics = preload("res://scripts/common_relic_rules.gd")
const State = preload("res://scripts/card_display_state.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const ItemText = preload("res://scripts/item_rules_text.gd")
const CardArea = preload("res://scripts/card_area_presentation.gd")
# Initialize on first use in case CombatEngine is still loading this script.
static var _engine_instance: RefCounted = null

static func _engine() -> RefCounted:
	if _engine_instance == null: _engine_instance = Combat.new()
	return _engine_instance

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
	# Each projected action can affect a later action on the same card. Keep
	# the board, decks and history read-only.
	var preview_state: Dictionary = state.duplicate(false)
	preview_state.erase("pending_card_payment")
	var effects: Array[Dictionary] = GameData.relic_effects_for_state(state)
	var has_state_modifiers: bool = DefenseRules.has_effect(effects, "player_state_action_mod")
	var previous_action_row_index: int = -1
	for action_var: Variant in CardKeywordRules.actions_with_modifiers(card, keyword_state):
		var action: Dictionary = action_var
		if action.has(CardKeywordRules.KEYWORD_APPENDED_FLAG):
			continue # Shown once, in its active Follow-up / Empower segment.
		var original: Dictionary = action
		var action_type: String = str(action.get("type", ""))
		var row: Array = []
		# Keep the original for damage math: the engine applies the same relics
		# and next-attack buffs when computing that total.
		action = TempoRules.display_action(preview_state, action)
		if has_state_modifiers:
			action = _engine()._action_with_player_state_relic_modifiers(preview_state, action, true)
			action = DefenseRules.suppress_card_block(action, effects)
		# Reuse combat's duration rule; presentation never changes the definition
		# or spends a skill. Long Dawn also affects items such as Seer's Candle.
		if action_type == "vision":
			action = action.duplicate(false)
			action["duration"] = _engine().vision_duration_for_player(preview_state, int(action.get("duration", 1)))
		action = _project_card_block(preview_state, action)
		match action_type:
			"melee", "ranged", "aoe", "detonate", "convert_surface", "discharge", "all_enemies", "meteor_marks":
				var attack_final_damage: int = _engine().final_damage_for_player_action(preview_state, original)
				var attack_damage_modifiers: Array[Dictionary] = _engine().damage_modifiers_for_player_action(preview_state, original)
				var attack_visible_modifiers: Array[Dictionary] = attack_damage_modifiers
				row = ActionIcons.tokens_for_action(action, {
					"final_damage": attack_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(attack_final_damage, attack_visible_modifiers, action),
					"damage_modifiers": attack_visible_modifiers
				})
				consume_preview_damage_modifiers(preview_state, original)
			"destroy_illusion", "burst_terrain":
				# The blast is a player-card attack on the struck tiles: attack
				# bonuses apply, next-attack buffs do not (spec/card_mechanics_illusions_terrain.md).
				var blast: Dictionary = _engine().blast_action_for_player_action(original)
				var blast_final_damage: int = _engine().final_damage_for_player_action(preview_state, blast)
				var blast_modifiers: Array[Dictionary] = _engine().damage_modifiers_for_player_action(preview_state, blast)
				row = ActionIcons.tokens_for_action(action, {
					"final_damage": blast_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(blast_final_damage, blast_modifiers, blast),
					"damage_modifiers": blast_modifiers
				})
				if blast_final_damage > 0 and _engine().attack_bonus_for_current_turn(preview_state) != 0:
					var blast_flags: Dictionary = (preview_state.get("turn_flags", {}) as Dictionary).duplicate(true)
					blast_flags["first_attack_bonus_used"] = true
					preview_state["turn_flags"] = blast_flags
			"push", "pull":
				var shove_final_damage: int = _engine().final_damage_for_player_action(preview_state, original)
				var shove_damage_modifiers: Array[Dictionary] = _engine().damage_modifiers_for_player_action(preview_state, original)
				var shove_visible_modifiers: Array[Dictionary] = shove_damage_modifiers
				row = ActionIcons.tokens_for_action(action, {
					"final_damage": shove_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(shove_final_damage, shove_visible_modifiers, action),
					"damage_modifiers": shove_visible_modifiers
				})
				consume_preview_damage_modifiers(preview_state, original)
			_:
				row = ActionIcons.tokens_for_action(action)
		for rider: Dictionary in action.get("_card_block_relic_riders", []):
			row.append_array(ActionIcons.tokens_for_action(rider))
		var annotated_row: Array = row
		annotated_row = CardArea.tokens(annotated_row, action, card.get("actions", []), true)
		previous_action_row_index = ActionIcons.append_action_row(summary_rows, action, annotated_row, previous_action_row_index)
		var guardian_row: Array = ActionIcons.tokens_for_guardian_rule(action)
		if not guardian_row.is_empty(): summary_rows.append(guardian_row)
		var bonus_row: Array = ActionIcons.tokens_for_surface_bonus(action)
		bonus_row = CardArea.tokens(bonus_row, action, card.get("actions", []))
		if not bonus_row.is_empty():
			summary_rows.append(bonus_row)
		for rider: Array in ActionIcons.keyword_rider_rows(action):
			summary_rows.append(CardArea.tokens(rider, action, card.get("actions", [])))
		_advance_face_state(preview_state, action)
	summary_rows.append_array(ActionIcons.keyword_rows_for_card(card, keyword_state, project_empower_actions.bind(state)))
	summary_rows.append_array(ActionIcons.rules_text_rows_for_card(card))
	summary_rows = CardArea.patterns(summary_rows)
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

static func empower_panel(card: Dictionary, state: Dictionary) -> Dictionary:
	var card_id: String = str(card.get("id", ""))
	var keyword_state: Dictionary = CardKeywordRules.play_modifiers(state, card_id, card)
	var spec: Dictionary = preload("res://scripts/card_empower_panel.gd").projected_spec(
		card, card.get("empower", {}), project_empower_actions.bind(state), bool(keyword_state.get("follow_up", false))
	)
	return ActionIcons.empower_copy(card, false, spec)

static func project_empower_actions(actions: Array, state: Dictionary) -> Array:
	var preview_state: Dictionary = state.duplicate(false)
	preview_state.erase("pending_card_payment")
	var projected: Array = []
	for original: Dictionary in actions:
		var action: Dictionary = _engine()._resolved_surface_action(preview_state, original).duplicate(false)
		if action.has("damage") and not bool(action.get("status_only", false)):
			action["damage"] = _engine().final_damage_for_player_action(preview_state, original)
			consume_preview_damage_modifiers(preview_state, original)
		action = _project_card_block(preview_state, action)
		projected.append(action)
		_advance_face_state(preview_state, action)
	return projected

static func _project_card_block(state: Dictionary, action: Dictionary) -> Dictionary:
	var direct: bool = str(action.get("type", "")) == "block"
	var amount: int = int(action.get("amount" if direct else "block_per_tile", 0))
	var effects: Array[Dictionary] = CommonRelics.card_block_effects(_engine(), state, action, amount)
	if effects.is_empty():
		return action
	var payment: Dictionary = (state.get("pending_card_payment", {}) as Dictionary).duplicate()
	var projected: Dictionary = action.duplicate(false)
	var riders: Array[Dictionary]
	for effect: Dictionary in effects:
		var id: String = str(effect.get("relic_id", ""))
		var gain: int = GameData.fixed_point_amount(int(effect.get("amount", 0)))
		if id == "reinforced_shield" and direct:
			projected = GameData._record_relic_action_modifier(projected, effect, "amount", amount, amount + gain)
			projected["amount"] = amount + gain
		else:
			var rider: Dictionary = {"type": "block" if id == "reinforced_shield" else "retaliate", "amount": gain}
			riders.append(GameData._record_relic_action_modifier(rider, effect, "amount", 0, gain))
		# A path can give 0 Block on Stay. A later unconditional Block can
		# still collect the bonus in that case. Target forecasts use the path.
		payment[id] = true
	state["pending_card_payment"] = payment
	projected["_card_block_relic_riders"] = riders
	return projected

static func _advance_face_state(state: Dictionary, action: Dictionary) -> void:
	match str(action.get("type", "")):
		"block", "stoneskin":
			var field: String = str(action["type"])
			var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(false)
			player[field] = int(player.get(field, 0)) + int(action.get("amount", 0))
			state["player"] = player
		"vision":
			var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(false)
			var before: int = int(umbra.get("vision_activations", 0))
			var duration: int = int(action.get("duration", 0))
			umbra["vision_activations"] = -1 if before < 0 or duration < 0 else maxi(before, duration)
			state["umbra"] = umbra

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
	var resolver: RefCounted = engine if engine != null else _engine()
	if resolver.attack_bonus_for_current_turn(state) == 0:
		return
	var turn_flags: Dictionary = (state.get("turn_flags", {}) as Dictionary).duplicate(true)
	turn_flags["first_attack_bonus_used"] = true
	state["turn_flags"] = turn_flags

