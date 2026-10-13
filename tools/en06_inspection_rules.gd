extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Capacitor = preload("res://scripts/enemy_mechanics/capacitor.gd")

# Explicit fixture-only CLI data. No production enemy defaults change.
static func apply(builder: SceneTree, state: Dictionary, options: Dictionary) -> Dictionary:
	if not options.has("enemy_charge"): return state
	var amount: int = int(options["enemy_charge"])
	if amount < 0 or amount > Capacitor.MAX_CHARGE:
		builder._fail("--enemy-charge must be between 0 and 3")
		return state
	var found: bool = false
	for enemy: Dictionary in state.get("enemies", []):
		if not Capacitor.is_capacitor(enemy): continue
		found = true
		enemy["charge"] = amount
		enemy["intent"] = Capacitor.choose(enemy, Data.enemy_def("storm_capacitor")["intents"])
	if not found:
		builder._fail("--enemy-charge requires a Storm Capacitor")
		return state
	return builder._combat_engine._initialize_initiative_queue(state)
