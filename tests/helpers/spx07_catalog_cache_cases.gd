extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const PROOF_ENEMY: String = "crawler"
const INVALID_PROOF_ENEMY: String = "spx07-invalid-definition-proof"

static func run(expect: Callable) -> void:
	var catalog: Dictionary = Data.enemies()
	for type: String in catalog:
		# The original public enemy_def implementation, retained as the oracle.
		var expected: Dictionary = Data._scale_enemy_fixed_point(Data._duplicate_dict(catalog[type]))
		var actual: Dictionary = Data.enemy_def(type)
		expect.call(actual == expected, "Memoized enemy definition equals original scaler: " + type)
		actual["intents"] = []
		expect.call(Data.enemy_def(type) == expected, "Every enemy definition has private nested caller data: " + type)
	var original: Dictionary = catalog[PROOF_ENEMY].duplicate(true)
	var expected: Dictionary = Data.enemy_def(PROOF_ENEMY)
	catalog[PROOF_ENEMY]["max_hp"] += 1
	expect.call(Data.enemy_def(PROOF_ENEMY)["max_hp"] != expected["max_hp"], "Definition memo invalidates in-place catalog edits")
	catalog[PROOF_ENEMY] = original
	expect.call(Data.enemy_def(PROOF_ENEMY) == expected, "Definition memo invalidates restored catalog data")
	catalog[INVALID_PROOF_ENEMY] = 0
	expect.call(Data.enemy_def(INVALID_PROOF_ENEMY).is_empty(), "Malformed source definition preserves the original empty result")
	catalog.erase(INVALID_PROOF_ENEMY)
	print("SPX07 CATALOG CACHE RESULT: %d exact definitions; private copies and in-place invalidation checked" % catalog.size())
