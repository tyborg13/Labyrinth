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


static func visual_cue(over_board: bool, preview: Dictionary, hovered_target_is_valid: bool) -> Dictionary:
	if not bool(preview.get("playable", false)):
		return {
			"verb": "CARD UNAVAILABLE",
			"target": "NO LEGAL PLAY",
			"tone": "invalid",
			"risk": "CARD UNAVAILABLE",
			"risk_tone": "neutral",
			"proxy_state": "cancel",
		}
	if not over_board:
		return {
			"verb": "DRAG TO BOARD",
			"target": _valid_target_count_text(preview),
			"tone": "neutral",
			"risk": "RELEASE CANCELS",
			"risk_tone": "neutral",
			"proxy_state": "held",
		}
	if not preview_requires_target(preview):
		return {
			"verb": "RELEASE TO PLAY",
			"target": "BOARD",
			"tone": "valid",
			"risk": "BOARD PLAY",
			"risk_tone": "primary",
			"proxy_state": "ready",
		}
	if hovered_target_is_valid:
		return {
			"verb": "RELEASE TO PLAY",
			"target": "VALID TARGET",
			"tone": "valid",
			"risk": "TARGETED PLAY",
			"risk_tone": "primary",
			"proxy_state": "target",
		}
	return {
		"verb": "RELEASE CANCELS",
		"target": "INVALID TARGET",
		"tone": "invalid",
		"risk": "CHOOSE HIGHLIGHT",
		"risk_tone": "invalid",
		"proxy_state": "cancel",
	}


static func _valid_target_count_text(preview: Dictionary) -> String:
	var target_tiles: Array = preview.get("target_tiles", []) as Array
	if target_tiles.is_empty():
		return "READY" if bool(preview.get("complete", false)) else "NO VALID TARGET"
	return "%d VALID" % target_tiles.size()
