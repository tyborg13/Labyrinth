extends RefCounted
class_name CardDragPlayRules

const OUTCOME_CANCEL: String = "cancel"
const OUTCOME_PLAY_TARGETLESS: String = "play_targetless"
const OUTCOME_PLAY_TARGET: String = "play_target"


static func preview_requires_target(preview: Dictionary) -> bool:
	return bool(preview.get("playable", false)) and not bool(preview.get("complete", false))


static func release_outcome(over_board: bool, preview: Dictionary, hovered_target_is_valid: bool) -> String:
	if not over_board or not bool(preview.get("playable", false)):
		return OUTCOME_CANCEL
	if not preview_requires_target(preview):
		return OUTCOME_PLAY_TARGETLESS
	return OUTCOME_PLAY_TARGET if hovered_target_is_valid else OUTCOME_CANCEL
