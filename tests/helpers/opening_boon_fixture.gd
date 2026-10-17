extends RefCounted

const Rules = preload("res://scripts/opening_boon_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Run = preload("res://scripts/run_engine.gd")
const PROOF_SEED: int = 2
const PROOF_HEIRLOOM: String = "duelist_rapier"
const ALL_PREVIEWS_SEED: int = 5
const BLOOD_PRICE_SEED: int = 1
const RULE_FIXTURE_SECTION_MAPS: bool = false

static func profile(with_heirloom: bool = false) -> Dictionary:
	var result: Dictionary = Tutorial.complete_tutorial(Store.default_data())
	result[Store.EMACIATED_AWAKENING_SEEN_KEY] = true
	result["run_counter"] = 2
	return Store.leave_heirloom(result, PROOF_HEIRLOOM) if with_heirloom else result

static func state(with_heirloom: bool = false, seed: int = PROOF_SEED) -> Dictionary:
	return Run.new().create_new_run(seed, profile(with_heirloom))

static func force_boon(id: String) -> Dictionary:
	var result: Dictionary = Run.new().create_new_run(PROOF_SEED, profile(id == "heirloom"), RULE_FIXTURE_SECTION_MAPS)
	var rng := RandomNumberGenerator.new()
	rng.seed = PROOF_SEED
	var row: Dictionary = Rules.roll(id, result, rng) if id != "heirloom" else {"boon": id, "item": PROOF_HEIRLOOM}
	row["column"] = "Build seed"
	result[Rules.STATE_KEY]["offers"] = [row]
	return result
