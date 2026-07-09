extends RefCounted
class_name ContextualCombatTutorial

const PROGRESSION_KEY: String = "combat_micro_prompt_states"
const STATUS_COMPLETED: String = "completed"
const STATUS_SKIPPED: String = "skipped"

const FULL_CARD_FALLBACK: String = "full_card_fallback"
const SELECT_TARGET: String = "select_target"
const CANCEL_OPTIONAL: String = "cancel_optional"
const PASS_CONSEQUENCE: String = "pass_consequence"
const TIMELINE_READING: String = "timeline_reading"

const PROMPT_ORDER: Array[String] = [
	FULL_CARD_FALLBACK,
	SELECT_TARGET,
	CANCEL_OPTIONAL,
	TIMELINE_READING,
	PASS_CONSEQUENCE
]

const PROMPTS: Dictionary = {
	FULL_CARD_FALLBACK: {
		"id": FULL_CARD_FALLBACK,
		"icon": "card_play",
		"text": "Play the full card, or spend it on a basic Attack or Move.",
		"grimoire_entry": "combat:card_plays",
		"accent": "d7a953"
	},
	SELECT_TARGET: {
		"id": SELECT_TARGET,
		"icon": "ranged",
		"text": "Choose a glowing tile to set this step's target.",
		"grimoire_entry": "combat:targeting",
		"accent": "65b7cf"
	},
	CANCEL_OPTIONAL: {
		"id": CANCEL_OPTIONAL,
		"icon": "exhaust",
		"text": "Cancel rewinds the card; Skip leaves this optional step unused.",
		"grimoire_entry": "combat:targeting",
		"accent": "b29ad8"
	},
	PASS_CONSEQUENCE: {
		"id": PASS_CONSEQUENCE,
		"icon": "health",
		"text": "Pass ends the turn; On Turn End previews the consequence.",
		"grimoire_entry": "combat:turn_clock",
		"accent": "d97c62"
	},
	TIMELINE_READING: {
		"id": TIMELINE_READING,
		"icon": "time",
		"text": "Card time adds a future slot; lower numbers act sooner.",
		"grimoire_entry": "combat:turn_clock",
		"accent": "79a9e6"
	}
}

static func prompt_ids() -> Array[String]:
	return PROMPT_ORDER.duplicate()

static func prompt_definition(prompt_id: String) -> Dictionary:
	return (PROMPTS.get(prompt_id, {}) as Dictionary).duplicate(true)

static func normalized_states(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return normalized
	var source: Dictionary = value as Dictionary
	for prompt_id: String in PROMPT_ORDER:
		var status: String = str(source.get(prompt_id, ""))
		if status in [STATUS_COMPLETED, STATUS_SKIPPED]:
			normalized[prompt_id] = status
	return normalized

static func states_from_progression(progression: Dictionary) -> Dictionary:
	return normalized_states(progression.get(PROGRESSION_KEY, {}))

static func merged_states(primary_progression: Dictionary, fallback_progression: Dictionary) -> Dictionary:
	var result: Dictionary = states_from_progression(fallback_progression)
	for prompt_id: String in PROMPT_ORDER:
		var primary_status: String = str(states_from_progression(primary_progression).get(prompt_id, ""))
		if not primary_status.is_empty():
			result[prompt_id] = primary_status
	return result

static func is_resolved(progression: Dictionary, prompt_id: String) -> bool:
	return states_from_progression(progression).has(prompt_id)

static func resolve_progression(progression: Dictionary, prompt_id: String, skipped: bool = false) -> Dictionary:
	var result: Dictionary = progression.duplicate(true)
	if not PROMPT_ORDER.has(prompt_id):
		return result
	var states: Dictionary = states_from_progression(result)
	states[prompt_id] = STATUS_SKIPPED if skipped else STATUS_COMPLETED
	result[PROGRESSION_KEY] = states
	return result

static func next_prompt(context: Dictionary, progression: Dictionary) -> Dictionary:
	if bool(context.get("suppressed", false)):
		return {}
	if str(context.get("mode", "")) != "combat" or int(progression.get("run_counter", 0)) > 1:
		return {}
	if not bool(context.get("player_turn", false)):
		return {}
	for prompt_id: String in PROMPT_ORDER:
		if is_resolved(progression, prompt_id):
			continue
		if _is_relevant(prompt_id, context):
			return prompt_definition(prompt_id)
	return {}

static func _is_relevant(prompt_id: String, context: Dictionary) -> bool:
	var selected: bool = bool(context.get("card_selected", false))
	match prompt_id:
		FULL_CARD_FALLBACK:
			return not selected and int(context.get("hand_count", 0)) > 0
		SELECT_TARGET:
			return selected and bool(context.get("target_required", false)) and int(context.get("target_count", 0)) > 0
		CANCEL_OPTIONAL:
			return selected and bool(context.get("optional_step", false))
		TIMELINE_READING:
			return not selected and bool(context.get("card_time_preview", false)) and bool(context.get("timeline_visible", false))
		PASS_CONSEQUENCE:
			return not selected and bool(context.get("pass_available", false)) and bool(context.get("pass_preview_visible", false))
		_:
			return false
