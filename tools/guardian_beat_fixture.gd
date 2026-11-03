extends RefCounted
## Proof-only boundary selection: walk the normal clock without changing HP,
## initiatives, intents, positions, fuel, dials or the authored inspection loadout.
const MAX_PROOF_ACTIVATIONS: int = 8
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
static func before_beat(combat: RefCounted, opening: Dictionary) -> Dictionary:
	var state: Dictionary = opening
	for activation: int in range(MAX_PROOF_ACTIVATIONS):
		assert(combat.is_player_turn(state) and combat.combat_outcome(state).is_empty(),"Guardian beat fixture must remain a real playable fight")
		var previous: Dictionary = state.duplicate(true)
		var beats: int = int(state.get("battlefield_rule",{}).get("beats_fired",0))
		state = Committed.advance_to_player(combat,Committed.finish_player_activation(combat,state))["state"]
		if int(state.get("battlefield_rule",{}).get("beats_fired",0)) > beats:
			return previous
	assert(false,"Guardian beat fixture exhausted its proof-only activation bound")
	return {}
