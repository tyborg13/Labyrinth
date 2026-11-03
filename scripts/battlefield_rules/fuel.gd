extends RefCounted
## Ground is visible immediately, but a beat may use it only after the next
## player activation begins. `turn` is the engine's player-activation index;
## enemy activations and clocks never advance this boundary. Provenance stays
## in the existing ground source record and survives ordinary save snapshots.
const LAID_ACTIVATION: String = "laid_player_activation"

static func stamped(state: Dictionary, source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result[LAID_ACTIVATION] = int(state.get("turn", 1))
	return result

static func eligible(state: Dictionary, source: Dictionary) -> bool:
	# Pre-boundary saves have no timestamp. Keep their already-announced ground
	# usable; every subsequent replacement/placement receives a fresh timestamp.
	return not source.has(LAID_ACTIVATION) or int(state.get("turn", 1)) > int(source[LAID_ACTIVATION])
