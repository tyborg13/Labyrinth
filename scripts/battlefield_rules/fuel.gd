extends RefCounted
## Saved placement provenance and legacy age compatibility. Committed rule beats
## select fuel from the live board, regardless of when it was laid.
## The age predicate remains for legacy direct conduction callers; stamping is
## additive and survives ordinary save snapshots.
const LAID_ACTIVATION: String = "laid_player_activation"

static func stamped(state: Dictionary, source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result[LAID_ACTIVATION] = int(state.get("turn", 1))
	return result

static func eligible(state: Dictionary, source: Dictionary) -> bool:
	# Pre-boundary saves have no timestamp. Keep their already-announced ground
	# usable; every subsequent replacement/placement receives a fresh timestamp.
	return not source.has(LAID_ACTIVATION) or int(state.get("turn", 1)) > int(source[LAID_ACTIVATION])
