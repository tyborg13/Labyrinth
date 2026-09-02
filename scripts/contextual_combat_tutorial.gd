extends RefCounted
class_name ContextualCombatTutorial

## Profile-backed curriculum for the first guided run. RunScene owns transient
## motor phases (a selected card, hovered enemy, or open preview); this class
## stores only action-committed milestones so save/resume never restores an
## impossible UI selection.

const PROGRESSION_KEY: String = "guided_combat_tutorial"
const LEGACY_PROGRESSION_KEY: String = "combat_micro_prompt_states"
const VERSION: int = 2

const STATUS_ACTIVE: String = "active"
const STATUS_COMPLETED: String = "completed"
const STATUS_DISMISSED: String = "dismissed"
const STATUS_LEGACY_EXEMPT: String = "legacy_exempt"
const STATUS_SKIPPED: String = STATUS_DISMISSED

const MILESTONE_MOVE: String = "move_committed"
const MILESTONE_INTENT: String = "enemy_intent_read"
const MILESTONE_PLAYS: String = "card_plays_read"
const MILESTONE_CANCEL: String = "card_preview_cancelled"
const MILESTONE_FIRST_CARD: String = "first_card_committed"
const MILESTONE_FIRST_PLAY: String = "first_card_play_read"
const MILESTONE_KILL_CARD: String = "kill_card_committed"
const MILESTONE_KILL_REFUND: String = "kill_refund_read"
const MILESTONE_REFUND_CARD: String = "refund_card_committed"
# Compatibility name for fixtures that treated the first committed card as the
# entire card lesson in tutorial version 1.
const MILESTONE_CARD: String = MILESTONE_FIRST_CARD
const MILESTONE_CLOCK: String = "turn_clock_read"
const MILESTONE_PASS: String = "turn_passed"
const MILESTONE_CORE: String = "combat_basics_learned"
const MILESTONE_REWARD: String = "reward_chosen"
const MILESTONE_PATH: String = "path_chosen"

const MILESTONE_ORDER: Array = [
	MILESTONE_MOVE,
	MILESTONE_INTENT,
	MILESTONE_PLAYS,
	MILESTONE_CANCEL,
	MILESTONE_FIRST_CARD,
	MILESTONE_FIRST_PLAY,
	MILESTONE_KILL_CARD,
	MILESTONE_KILL_REFUND,
	MILESTONE_REFUND_CARD,
	MILESTONE_CLOCK,
	MILESTONE_PASS,
	MILESTONE_CORE,
	MILESTONE_REWARD,
	MILESTONE_PATH,
]

const PHASE_SELECT_PLAYER: String = "select_player"
const PHASE_CHOOSE_MOVE: String = "choose_move"
const PHASE_INSPECT_ENEMY: String = "inspect_enemy"
const PHASE_CONFIRM_INTENT: String = "confirm_enemy_intent"
const PHASE_CARD_PLAYS: String = "card_plays"
const PHASE_SELECT_CARD_FOR_CANCEL: String = "select_card_for_cancel"
const PHASE_CANCEL_CARD: String = "cancel_card_preview"
const PHASE_SELECT_FIRST_CARD: String = "select_first_card"
const PHASE_SELECT_FIRST_TARGET: String = "select_first_target"
const PHASE_FINISH_FIRST_CARD: String = "finish_first_card"
const PHASE_FIRST_PLAY: String = "first_play_spent"
const PHASE_SELECT_KILL_CARD: String = "select_kill_card"
const PHASE_SELECT_KILL_TARGET: String = "select_kill_target"
const PHASE_FINISH_KILL_CARD: String = "finish_kill_card"
const PHASE_KILL_REFUND: String = "kill_refund"
const PHASE_SELECT_REFUND_CARD: String = "select_refund_card"
const PHASE_FINISH_REFUND_CARD: String = "finish_refund_card"
# Compatibility aliases for older diagnostics.
const PHASE_SELECT_CARD_TO_PLAY: String = PHASE_SELECT_FIRST_CARD
const PHASE_SELECT_TARGET: String = PHASE_SELECT_FIRST_TARGET
const PHASE_FINISH_CARD: String = PHASE_FINISH_FIRST_CARD
const PHASE_TURN_CLOCK: String = "turn_clock"
const PHASE_PASS_TURN: String = "pass_turn"
const PHASE_CORE_COMPLETE: String = "core_complete"
const PHASE_CHOOSE_REWARD: String = "choose_reward"
const PHASE_CHOOSE_PATH: String = "choose_path"
const PHASE_COMPLETE: String = "complete"

# Retired probe names remain as phase aliases so older diagnostic scripts still
# parse while they migrate to the guided curriculum.
const FULL_CARD_FALLBACK: String = PHASE_SELECT_PLAYER
const TIMELINE_READING: String = PHASE_TURN_CLOCK
const SELECT_TARGET: String = PHASE_SELECT_FIRST_TARGET
const CANCEL_OPTIONAL: String = PHASE_CANCEL_CARD
const PASS_CONSEQUENCE: String = PHASE_PASS_TURN

const PHASE_ORDER: Array = [
	PHASE_SELECT_PLAYER,
	PHASE_CHOOSE_MOVE,
	PHASE_INSPECT_ENEMY,
	PHASE_CONFIRM_INTENT,
	PHASE_CARD_PLAYS,
	PHASE_SELECT_CARD_FOR_CANCEL,
	PHASE_CANCEL_CARD,
	PHASE_SELECT_FIRST_CARD,
	PHASE_SELECT_FIRST_TARGET,
	PHASE_FINISH_FIRST_CARD,
	PHASE_FIRST_PLAY,
	PHASE_SELECT_KILL_CARD,
	PHASE_SELECT_KILL_TARGET,
	PHASE_FINISH_KILL_CARD,
	PHASE_KILL_REFUND,
	PHASE_SELECT_REFUND_CARD,
	PHASE_FINISH_REFUND_CARD,
	PHASE_TURN_CLOCK,
	PHASE_PASS_TURN,
	PHASE_CORE_COMPLETE,
	PHASE_CHOOSE_REWARD,
	PHASE_CHOOSE_PATH,
	PHASE_COMPLETE,
]

const PHASES: Dictionary = {
	PHASE_SELECT_PLAYER: {
		"id": PHASE_SELECT_PLAYER, "lesson": 1, "lesson_total": 8,
		"icon": "move", "kicker": "MOVEMENT", "title": "Move the Wanderer",
		"pointer_text": "Click your character to plan a move.",
		"controller_text": "Focus your character, then select.",
		"controller_action": "controller_accept", "action_label": "Select",
	},
	PHASE_CHOOSE_MOVE: {
		"id": PHASE_CHOOSE_MOVE, "lesson": 1, "lesson_total": 8,
		"icon": "move", "kicker": "MOVEMENT", "title": "Choose Your Step",
		"pointer_text": "Click a glowing tile. You can move 2 tiles each turn.",
		"controller_text": "Choose a glowing tile. You can move 2 tiles each turn.",
		"controller_action": "controller_accept", "action_label": "Move",
	},
	PHASE_INSPECT_ENEMY: {
		"id": PHASE_INSPECT_ENEMY, "lesson": 2, "lesson_total": 8,
		"icon": "", "kicker": "ENEMY INTENT", "title": "Read the Enemy",
		"pointer_text": "Point to a foe to reveal its next action.",
		"controller_text": "Focus a foe to reveal its next action.",
		"controller_action": "controller_move", "action_label": "Inspect",
	},
	PHASE_CONFIRM_INTENT: {
		"id": PHASE_CONFIRM_INTENT, "lesson": 2, "lesson_total": 8,
		"icon": "", "kicker": "ENEMY INTENT", "title": "The Enemy's Plan",
		"pointer_text": "The preview shows what this foe will do on its turn.",
		"controller_text": "The preview shows what this foe will do on its turn.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Continue",
	},
	PHASE_SELECT_CARD_FOR_CANCEL: {
		"id": PHASE_SELECT_CARD_FOR_CANCEL, "lesson": 3, "lesson_total": 8,
		"icon": "card_play", "kicker": "CARD PREVIEW", "title": "Plan a Card",
		"pointer_text": "Choose a lit card. Nothing is spent until its action resolves.",
		"controller_text": "Choose a lit card. Nothing is spent until its action resolves.",
		"controller_action": "controller_accept", "action_label": "Preview",
	},
	PHASE_CANCEL_CARD: {
		"id": PHASE_CANCEL_CARD, "lesson": 3, "lesson_total": 8,
		"icon": "", "kicker": "CARD PREVIEW", "title": "Change Your Mind",
		"pointer_text": "Right-click, or use Cancel, to return this card safely.",
		"controller_text": "Press Cancel to return this card safely.",
		"controller_action": "controller_cancel", "action_label": "Cancel",
	},
	PHASE_SELECT_CARD_TO_PLAY: {
		"id": PHASE_SELECT_CARD_TO_PLAY, "lesson": 4, "lesson_total": 8,
		"icon": "card_play", "kicker": "PLAY A CARD", "title": "Choose Your Card",
		"pointer_text": "Select a lit card to preview its action and targets.",
		"controller_text": "Select a lit card to preview its action and targets.",
		"controller_action": "controller_accept", "action_label": "Play",
	},
	PHASE_SELECT_TARGET: {
		"id": PHASE_SELECT_TARGET, "lesson": 4, "lesson_total": 8,
		"icon": "", "kicker": "TARGETING", "title": "Choose a Target",
		"pointer_text": "Choose a glowing target. The board previews the result before you commit.",
		"controller_text": "Choose a glowing target. The board previews the result before you commit.",
		"controller_action": "controller_accept", "action_label": "Target",
	},
	PHASE_FINISH_CARD: {
		"id": PHASE_FINISH_CARD, "lesson": 4, "lesson_total": 8,
		"icon": "card_play", "kicker": "CARD STEPS", "title": "Finish the Card",
		"pointer_text": "Follow its glowing steps. Optional steps may be skipped.",
		"controller_text": "Follow its glowing steps. Optional steps may be skipped.",
		"controller_action": "controller_accept", "action_label": "Resolve",
	},
	PHASE_TURN_CLOCK: {
		"id": PHASE_TURN_CLOCK, "lesson": 5, "lesson_total": 8,
		"icon": "time", "kicker": "TURN CLOCK", "title": "Read the Turn Clock",
		"pointer_text": "Card Time places your next turn. Lower Time means you act sooner.",
		"controller_text": "Card Time places your next turn. Lower Time means you act sooner.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Continue",
	},
	PHASE_PASS_TURN: {
		"id": PHASE_PASS_TURN, "lesson": 6, "lesson_total": 8,
		"icon": "", "kicker": "END TURN", "title": "Let the Enemy Act",
		"pointer_text": "Pass gives up remaining actions. The preview shows what enemies do next.",
		"controller_text": "Pass gives up remaining actions. The preview shows what enemies do next.",
		"controller_action": "controller_pass", "action_label": "Pass",
	},
	PHASE_CORE_COMPLETE: {
		"id": PHASE_CORE_COMPLETE, "lesson": 6, "lesson_total": 8,
		"icon": "", "kicker": "YOUR TURN", "title": "Finish the Fight",
		"pointer_text": "Use movement, cards, enemy intent, and Pass to defeat the remaining enemy.",
		"controller_text": "Use movement, cards, enemy intent, and Pass to defeat the remaining enemy.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Finish the Fight",
	},
	PHASE_CHOOSE_REWARD: {
		"id": PHASE_CHOOSE_REWARD, "lesson": 7, "lesson_total": 8,
		"icon": "", "kicker": "COMBAT REWARD", "title": "Shape Your Deck",
		"pointer_text": "Choose one card, or Skip & Recover to heal instead.",
		"controller_text": "Choose one card, or Skip & Recover to heal instead.",
		"controller_action": "controller_accept", "action_label": "Choose",
	},
	PHASE_CHOOSE_PATH: {
		"id": PHASE_CHOOSE_PATH, "lesson": 8, "lesson_total": 8,
		"icon": "move", "kicker": "CHOOSE A PATH", "title": "Enter the Next Chamber",
		"pointer_text": "Select a glowing doorway. The map previews where each route leads.",
		"controller_text": "Select a glowing doorway. The map previews where each route leads.",
		"controller_action": "controller_accept", "action_label": "Travel",
	},
	PHASE_COMPLETE: {
		"id": PHASE_COMPLETE, "lesson": 8, "lesson_total": 8,
		"icon": "move", "kicker": "GUIDE COMPLETE", "title": "Tutorial Complete",
		"pointer_text": "You know the basic combat controls. Continue to the next room.",
		"controller_text": "You know the basic combat controls. Continue to the next room.",
		"controller_action": "controller_accept", "action_label": "Begin",
		"requires_continue": true, "continue_text": "Begin",
	},
}

# Version 2 is deliberately authored rather than permissive. These definitions
# replace the broad version-1 copy while retaining its ids as test aliases.
const AUTHORED_PHASES: Dictionary = {
	PHASE_SELECT_PLAYER: {
		"id": PHASE_SELECT_PLAYER, "lesson": 1, "lesson_total": 10,
		"icon": "move", "kicker": "MOVEMENT", "title": "Move the Wanderer",
		"pointer_text": "Click the glowing Wanderer to plan a move.",
		"controller_text": "Select the glowing Wanderer to plan a move.",
		"controller_action": "controller_accept", "action_label": "Select", "attention_pulse": true,
	},
	PHASE_CHOOSE_MOVE: {
		"id": PHASE_CHOOSE_MOVE, "lesson": 1, "lesson_total": 10,
		"icon": "move", "kicker": "MOVEMENT", "title": "Take This Step",
		"pointer_text": "Move onto the one glowing tile. You begin each turn with 2 movement.",
		"controller_text": "Move onto the one glowing tile. You begin each turn with 2 movement.",
		"controller_action": "controller_accept", "action_label": "Move", "attention_pulse": true,
	},
	PHASE_INSPECT_ENEMY: {
		"id": PHASE_INSPECT_ENEMY, "lesson": 2, "lesson_total": 10,
		"icon": "", "kicker": "ENEMY INTENT", "title": "Read the Crawler",
		"pointer_text": "Move the pointer over the glowing crawler to reveal its next action.",
		"controller_text": "Focus the glowing crawler to reveal its next action.",
		"controller_action": "controller_move", "action_label": "Inspect", "attention_pulse": true,
	},
	PHASE_CONFIRM_INTENT: {
		"id": PHASE_CONFIRM_INTENT, "lesson": 2, "lesson_total": 10,
		"icon": "", "kicker": "ENEMY INTENT", "title": "Skitter Strike",
		"pointer_text": "This crawler will move up to 3 tiles, then attack for 4 damage.",
		"controller_text": "This crawler will move up to 3 tiles, then attack for 4 damage.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Continue",
	},
	PHASE_CARD_PLAYS: {
		"id": PHASE_CARD_PLAYS, "lesson": 3, "lesson_total": 10,
		"icon": "card_play", "kicker": "CARD PLAYS", "title": "Two Plays Each Turn",
		"pointer_text": "You normally get 2 card plays each turn. The counter tracks what remains.",
		"controller_text": "You normally get 2 card plays each turn. The counter tracks what remains.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Continue",
	},
	PHASE_SELECT_CARD_FOR_CANCEL: {
		"id": PHASE_SELECT_CARD_FOR_CANCEL, "lesson": 3, "lesson_total": 10,
		"icon": "card_play", "kicker": "CARD PREVIEW", "title": "Plan Bone Dart",
		"pointer_text": "Click the glowing Bone Dart. Nothing is spent while you preview it.",
		"controller_text": "Select the glowing Bone Dart. Nothing is spent while you preview it.",
		"controller_action": "controller_accept", "action_label": "Preview", "attention_pulse": true,
	},
	PHASE_CANCEL_CARD: {
		"id": PHASE_CANCEL_CARD, "lesson": 3, "lesson_total": 10,
		"icon": "", "kicker": "CARD PREVIEW", "title": "Change Your Mind",
		"pointer_text": "Right-click, or use Cancel, to return Bone Dart safely.",
		"controller_text": "Press Cancel to return Bone Dart safely.",
		"controller_action": "controller_cancel", "action_label": "Cancel", "attention_pulse": true,
	},
	PHASE_SELECT_FIRST_CARD: {
		"id": PHASE_SELECT_FIRST_CARD, "lesson": 4, "lesson_total": 10,
		"icon": "card_play", "kicker": "FIRST PLAY", "title": "Play Bone Dart",
		"pointer_text": "Click Bone Dart again. This time, you will commit the attack.",
		"controller_text": "Select Bone Dart again. This time, you will commit the attack.",
		"controller_action": "controller_accept", "action_label": "Play", "attention_pulse": true,
	},
	PHASE_SELECT_FIRST_TARGET: {
		"id": PHASE_SELECT_FIRST_TARGET, "lesson": 4, "lesson_total": 10,
		"icon": "", "kicker": "TARGETING", "title": "Aim at the Crawler",
		"pointer_text": "Click the glowing crawler. Bone Dart will deal 6 damage.",
		"controller_text": "Select the glowing crawler. Bone Dart will deal 6 damage.",
		"controller_action": "controller_accept", "action_label": "Target", "attention_pulse": true,
	},
	PHASE_FINISH_FIRST_CARD: {
		"id": PHASE_FINISH_FIRST_CARD, "lesson": 4, "lesson_total": 10,
		"icon": "card_play", "kicker": "COMMIT", "title": "Release Bone Dart",
		"pointer_text": "Confirm the glowing action to commit the card.",
		"controller_text": "Confirm the glowing action to commit the card.",
		"controller_action": "controller_accept", "action_label": "Resolve", "attention_pulse": true,
	},
	PHASE_FIRST_PLAY: {
		"id": PHASE_FIRST_PLAY, "lesson": 4, "lesson_total": 10,
		"icon": "card_play", "kicker": "CARD PLAYS", "title": "One Play Remains",
		"pointer_text": "Bone Dart spent 1 card play. The counter has fallen from 2 to 1.",
		"controller_text": "Bone Dart spent 1 card play. The counter has fallen from 2 to 1.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Continue",
	},
	PHASE_SELECT_KILL_CARD: {
		"id": PHASE_SELECT_KILL_CARD, "lesson": 5, "lesson_total": 10,
		"icon": "card_play", "kicker": "SECOND PLAY", "title": "Finish with Quick Stab",
		"pointer_text": "Click the glowing Quick Stab. Your move put the crawler in reach.",
		"controller_text": "Select the glowing Quick Stab. Your move put the crawler in reach.",
		"controller_action": "controller_accept", "action_label": "Play", "attention_pulse": true,
	},
	PHASE_SELECT_KILL_TARGET: {
		"id": PHASE_SELECT_KILL_TARGET, "lesson": 5, "lesson_total": 10,
		"icon": "", "kicker": "LETHAL", "title": "Strike the Wounded Crawler",
		"pointer_text": "Click the glowing crawler. Quick Stab deals the final 11 damage.",
		"controller_text": "Select the glowing crawler. Quick Stab deals the final 11 damage.",
		"controller_action": "controller_accept", "action_label": "Target", "attention_pulse": true,
	},
	PHASE_FINISH_KILL_CARD: {
		"id": PHASE_FINISH_KILL_CARD, "lesson": 5, "lesson_total": 10,
		"icon": "card_play", "kicker": "LETHAL", "title": "Commit Quick Stab",
		"pointer_text": "Confirm the glowing action to defeat the crawler.",
		"controller_text": "Confirm the glowing action to defeat the crawler.",
		"controller_action": "controller_accept", "action_label": "Resolve", "attention_pulse": true,
	},
	PHASE_KILL_REFUND: {
		"id": PHASE_KILL_REFUND, "lesson": 5, "lesson_total": 10,
		"icon": "card_play", "kicker": "KILL REFUND", "title": "A Play Returns",
		"pointer_text": "Defeating an enemy refunds 1 card play. You still have 1 to spend.",
		"controller_text": "Defeating an enemy refunds 1 card play. You still have 1 to spend.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Use the Refund",
	},
	PHASE_SELECT_REFUND_CARD: {
		"id": PHASE_SELECT_REFUND_CARD, "lesson": 6, "lesson_total": 10,
		"icon": "card_play", "kicker": "REFUNDED PLAY", "title": "Play Brace",
		"pointer_text": "Click the glowing Brace to spend the refunded play and gain 8 Block.",
		"controller_text": "Select the glowing Brace to spend the refunded play and gain 8 Block.",
		"controller_action": "controller_accept", "action_label": "Play", "attention_pulse": true,
	},
	PHASE_FINISH_REFUND_CARD: {
		"id": PHASE_FINISH_REFUND_CARD, "lesson": 6, "lesson_total": 10,
		"icon": "card_play", "kicker": "REFUNDED PLAY", "title": "Raise Your Guard",
		"pointer_text": "Confirm the glowing action to gain 8 Block.",
		"controller_text": "Confirm the glowing action to gain 8 Block.",
		"controller_action": "controller_accept", "action_label": "Resolve", "attention_pulse": true,
	},
	PHASE_TURN_CLOCK: {
		"id": PHASE_TURN_CLOCK, "lesson": 7, "lesson_total": 10,
		"icon": "time", "kicker": "TURN CLOCK", "title": "Read the Turn Clock",
		"pointer_text": "Card Time places your next turn. Lower Time means you act sooner.",
		"controller_text": "Card Time places your next turn. Lower Time means you act sooner.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Continue",
	},
	PHASE_PASS_TURN: {
		"id": PHASE_PASS_TURN, "lesson": 7, "lesson_total": 10,
		"icon": "", "kicker": "END TURN", "title": "Let the Enemy Act",
		"pointer_text": "Your actions are spent. Pass so the crawler attacks into your Block.",
		"controller_text": "Your actions are spent. Pass so the crawler attacks into your Block.",
		"controller_action": "controller_pass", "action_label": "Pass", "attention_pulse": true,
	},
	PHASE_CORE_COMPLETE: {
		"id": PHASE_CORE_COMPLETE, "lesson": 8, "lesson_total": 10,
		"icon": "", "kicker": "BLOCK", "title": "Block Absorbed the Hit",
		"pointer_text": "The crawler's 4-damage attack used 4 Block, so you lost no Health. Defeat it on your own.",
		"controller_text": "The crawler's 4-damage attack used 4 Block, so you lost no Health. Defeat it on your own.",
		"controller_action": "controller_accept", "action_label": "Continue",
		"requires_continue": true, "continue_text": "Finish the Fight",
	},
	PHASE_CHOOSE_REWARD: {
		"id": PHASE_CHOOSE_REWARD, "lesson": 9, "lesson_total": 10,
		"icon": "", "kicker": "COMBAT REWARD", "title": "Shape Your Deck",
		"pointer_text": "Choose one card, or Skip & Recover to heal instead.",
		"controller_text": "Choose one card, or Skip & Recover to heal instead.",
		"controller_action": "controller_accept", "action_label": "Choose",
	},
	PHASE_CHOOSE_PATH: {
		"id": PHASE_CHOOSE_PATH, "lesson": 10, "lesson_total": 10,
		"icon": "move", "kicker": "CHOOSE A PATH", "title": "Enter the Next Chamber",
		"pointer_text": "Select a glowing doorway. The map previews where each route leads.",
		"controller_text": "Select a glowing doorway. The map previews where each route leads.",
		"controller_action": "controller_accept", "action_label": "Travel",
	},
	PHASE_COMPLETE: {
		"id": PHASE_COMPLETE, "lesson": 10, "lesson_total": 10,
		"icon": "move", "kicker": "GUIDE COMPLETE", "title": "Tutorial Complete",
		"pointer_text": "You know the basic combat controls. Continue to the next room.",
		"controller_text": "You know the basic combat controls. Continue to the next room.",
		"controller_action": "controller_accept", "action_label": "Begin",
		"requires_continue": true, "continue_text": "Begin",
	},
}

static func default_state() -> Dictionary:
	return {"version": VERSION, "status": STATUS_ACTIVE, "completed_steps": []}

static func legacy_exempt_state() -> Dictionary:
	return {"version": VERSION, "status": STATUS_LEGACY_EXEMPT, "completed_steps": []}

static func normalized_state(value: Variant, fresh_profile: bool = false, legacy_notes_present: bool = false) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return default_state() if fresh_profile and not legacy_notes_present else legacy_exempt_state()
	var source: Dictionary = value as Dictionary
	var source_version: int = int(source.get("version", 1))
	var status: String = str(source.get("status", STATUS_ACTIVE if fresh_profile else STATUS_LEGACY_EXEMPT))
	if status not in [STATUS_ACTIVE, STATUS_COMPLETED, STATUS_DISMISSED, STATUS_LEGACY_EXEMPT]:
		status = STATUS_ACTIVE if fresh_profile else STATUS_LEGACY_EXEMPT
	var completed: Array[String]
	if typeof(source.get("completed_steps", null)) == TYPE_ARRAY:
		for step_var: Variant in source.get("completed_steps", []) as Array:
			var step_id: String = str(step_var)
			if MILESTONE_ORDER.has(step_id) and not completed.has(step_id):
				completed.append(step_id)
	# The authored scenario changes the meaning and ordering of every early
	# action. An unfinished prototype-v1 guide restarts cleanly at its first rail;
	# completed and dismissed profiles remain respected.
	if source_version < VERSION and status == STATUS_ACTIVE:
		completed.clear()
	completed.sort_custom(func(a: String, b: String) -> bool: return MILESTONE_ORDER.find(a) < MILESTONE_ORDER.find(b))
	if status == STATUS_COMPLETED:
		completed = _typed_string_array(MILESTONE_ORDER)
	return {"version": VERSION, "status": status, "completed_steps": completed}

static func state_from_progression(progression: Dictionary) -> Dictionary:
	return normalized_state(
		progression.get(PROGRESSION_KEY, null),
		int(progression.get("run_counter", 0)) == 0,
		progression.has(LEGACY_PROGRESSION_KEY)
	)

static func is_active(progression: Dictionary) -> bool:
	return str(state_from_progression(progression).get("status", "")) == STATUS_ACTIVE

static func is_completed(progression: Dictionary) -> bool:
	return str(state_from_progression(progression).get("status", "")) == STATUS_COMPLETED

static func has_completed(progression: Dictionary, milestone_id: String) -> bool:
	return (state_from_progression(progression).get("completed_steps", []) as Array).has(milestone_id)

static func completed_steps(progression: Dictionary) -> Array[String]:
	var result: Array[String]
	for step_var: Variant in state_from_progression(progression).get("completed_steps", []) as Array:
		result.append(str(step_var))
	return result

static func complete_milestone(progression: Dictionary, milestone_id: String) -> Dictionary:
	if not MILESTONE_ORDER.has(milestone_id):
		return progression.duplicate(true)
	var result: Dictionary = progression.duplicate(true)
	var state: Dictionary = state_from_progression(result)
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return result
	var completed: Array = state.get("completed_steps", []) as Array
	if completed.has(milestone_id):
		return result
	completed.append(milestone_id)
	completed.sort_custom(func(a: String, b: String) -> bool: return MILESTONE_ORDER.find(a) < MILESTONE_ORDER.find(b))
	state["completed_steps"] = completed
	result[PROGRESSION_KEY] = state
	result["progression_revision"] = int(result.get("progression_revision", 0)) + 1
	result.erase(LEGACY_PROGRESSION_KEY)
	return result

static func complete_tutorial(progression: Dictionary) -> Dictionary:
	var result: Dictionary = progression.duplicate(true)
	var state: Dictionary = state_from_progression(result)
	if str(state.get("status", "")) == STATUS_COMPLETED:
		return result
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return result
	state["status"] = STATUS_COMPLETED
	state["completed_steps"] = MILESTONE_ORDER.duplicate()
	result[PROGRESSION_KEY] = state
	result["progression_revision"] = int(result.get("progression_revision", 0)) + 1
	result.erase(LEGACY_PROGRESSION_KEY)
	return result

static func dismiss_tutorial(progression: Dictionary) -> Dictionary:
	var result: Dictionary = progression.duplicate(true)
	var state: Dictionary = state_from_progression(result)
	if str(state.get("status", "")) == STATUS_DISMISSED:
		return result
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return result
	state["status"] = STATUS_DISMISSED
	result[PROGRESSION_KEY] = state
	result["progression_revision"] = int(result.get("progression_revision", 0)) + 1
	result.erase(LEGACY_PROGRESSION_KEY)
	return result

static func restart_tutorial(progression: Dictionary) -> Dictionary:
	var result: Dictionary = progression.duplicate(true)
	result[PROGRESSION_KEY] = default_state()
	result["progression_revision"] = int(result.get("progression_revision", 0)) + 1
	result.erase(LEGACY_PROGRESSION_KEY)
	return result

static func merged_state(primary_progression: Dictionary, fallback_progression: Dictionary) -> Dictionary:
	var primary: Dictionary = state_from_progression(primary_progression)
	var fallback: Dictionary = state_from_progression(fallback_progression)
	var completed: Array[String]
	for state: Dictionary in [fallback, primary]:
		for step_var: Variant in state.get("completed_steps", []) as Array:
			var step_id: String = str(step_var)
			if MILESTONE_ORDER.has(step_id) and not completed.has(step_id):
				completed.append(step_id)
	completed.sort_custom(func(a: String, b: String) -> bool: return MILESTONE_ORDER.find(a) < MILESTONE_ORDER.find(b))
	var statuses: Array[String]
	statuses.append(str(primary.get("status", "")))
	statuses.append(str(fallback.get("status", "")))
	var status: String = STATUS_LEGACY_EXEMPT
	for candidate: String in [STATUS_COMPLETED, STATUS_DISMISSED, STATUS_ACTIVE, STATUS_LEGACY_EXEMPT]:
		if statuses.has(candidate):
			status = candidate
			break
	return {
		"version": VERSION,
		"status": status,
		"completed_steps": MILESTONE_ORDER.duplicate() if status == STATUS_COMPLETED else completed,
	}

static func phase_definition(phase_id: String) -> Dictionary:
	return (AUTHORED_PHASES.get(phase_id, PHASES.get(phase_id, {})) as Dictionary).duplicate(true)

static func phase_ids() -> Array[String]:
	return _typed_string_array(PHASE_ORDER)

static func milestone_ids() -> Array[String]:
	return _typed_string_array(MILESTONE_ORDER)

# Compatibility helpers used by unrelated visual fixtures to suppress onboarding.
static func prompt_ids() -> Array[String]:
	return milestone_ids()

static func prompt_definition(prompt_id: String) -> Dictionary:
	var phase_by_milestone: Dictionary = {
		MILESTONE_MOVE: PHASE_SELECT_PLAYER,
		MILESTONE_INTENT: PHASE_INSPECT_ENEMY,
		MILESTONE_PLAYS: PHASE_CARD_PLAYS,
		MILESTONE_CANCEL: PHASE_CANCEL_CARD,
		MILESTONE_FIRST_CARD: PHASE_SELECT_FIRST_TARGET,
		MILESTONE_FIRST_PLAY: PHASE_FIRST_PLAY,
		MILESTONE_KILL_CARD: PHASE_SELECT_KILL_TARGET,
		MILESTONE_KILL_REFUND: PHASE_KILL_REFUND,
		MILESTONE_REFUND_CARD: PHASE_FINISH_REFUND_CARD,
		MILESTONE_CLOCK: PHASE_TURN_CLOCK,
		MILESTONE_PASS: PHASE_PASS_TURN,
		MILESTONE_CORE: PHASE_CORE_COMPLETE,
		MILESTONE_REWARD: PHASE_CHOOSE_REWARD,
		MILESTONE_PATH: PHASE_CHOOSE_PATH,
	}
	return phase_definition(str(phase_by_milestone.get(prompt_id, prompt_id)))

static func normalized_states(value: Variant) -> Dictionary:
	var state: Dictionary = normalized_state(value)
	var result: Dictionary = {}
	for step_var: Variant in state.get("completed_steps", []) as Array:
		result[str(step_var)] = STATUS_COMPLETED
	return result

static func states_from_progression(progression: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for step_id: String in completed_steps(progression):
		result[step_id] = STATUS_COMPLETED
	return result

static func resolve_progression(progression: Dictionary, prompt_id: String, skipped: bool = false) -> Dictionary:
	if skipped:
		return dismiss_tutorial(progression)
	var result: Dictionary = complete_milestone(progression, prompt_id)
	if completed_steps(result).size() == MILESTONE_ORDER.size():
		return complete_tutorial(result)
	return result

static func merged_states(primary_progression: Dictionary, fallback_progression: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for step_var: Variant in merged_state(primary_progression, fallback_progression).get("completed_steps", []) as Array:
		result[str(step_var)] = STATUS_COMPLETED
	return result

static func _typed_string_array(values: Array) -> Array[String]:
	var result: Array[String]
	for value: Variant in values:
		result.append(str(value))
	return result
