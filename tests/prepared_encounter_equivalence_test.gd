extends SceneTree
const EngineScript = preload("res://scripts/run_engine.gd")
const Reference = preload("res://tests/fixtures/pre_battle_factory_reference.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
const GameData = preload("res://scripts/game_data.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
var errors: Array[String]
var cases: int = 0
func _initialize() -> void:
	Parallel.apply_from_environment()
	var engine := EngineScript.new()
	var reference := Reference.new()
	for tutorial: bool in [false, true]:
		var profile: Dictionary = Progression.default_data() if tutorial else Tutorial.complete_tutorial(Progression.default_data())
		if not tutorial:
			var preference: Array[String]
			_append_skill_path("true_bearing", preference)
			var count: int = maxi(preference.size(), Skills.minimum_owned("true_bearing") + 1)
			profile["level"] = count + 1
			profile["skill_ids"] = Skills.repaired_selection([], count, preference)
		for seed: int in [11, 32, 57, 84217]:
			var state: Dictionary = engine.create_new_run(seed, profile)
			if not tutorial: _check(engine.has_run_skill(state, "true_bearing"), "Fixture must grant a legal True Bearing build")
			if tutorial: state = Guided.mark_run_eligible(state)
			var seen: Dictionary = {}
			for room: Dictionary in (state.get("rooms", {}) as Dictionary).values():
				var type: String = str(room.get("type", ""))
				if type not in ["combat", "boss", "guardian"] or seen.has(type): continue
				seen[type] = true
				var input: Dictionary = state.duplicate(true)
				input["current_room"] = room["coord"]
				input["mode"] = EngineScript.MODE_PRE_BATTLE
				input["pre_battle_travel_dir"] = Vector2i.RIGHT
				_test_case(engine, reference, input)
	_check(engine._generated_layout_cache_hits > 0, "Equivalence must exercise actual generated-layout cache hits")
	_check(cases >= 8, "Reference suite must exercise actual generated combat rooms")
	print("PREPARED ENCOUNTER EQUIVALENCE RESULT: " + JSON.stringify({"errors": errors, "cases": cases}))
	quit(0 if errors.is_empty() else 1)
func _test_case(engine: RefCounted, reference: RefCounted, input: Dictionary) -> void:
	var original: Dictionary = input.duplicate(true)
	var prepared: Dictionary = engine.prepare_pre_battle_combat(input)
	_check(engine.pre_battle_preview_state(input, prepared) == reference.pre_battle_preview_state(input), "Prepared preview must equal the original complete state")
	_check(engine.begin_pre_battle_combat(input, prepared) == reference.begin_pre_battle_combat(input), "Prepared Begin must preserve layout, tutorial, deck RNG, loot and drop pity")
	_check(input == original, "Preparing and beginning must not mutate caller input")
	var captured: Dictionary = prepared.duplicate(true)
	var result: Dictionary = engine.begin_pre_battle_combat(input, prepared)
	result["combat_state"]["enemies"].clear()
	_check(prepared == captured, "Committed results must not alias the owned factory")
	for field: String in ["player_hp", "player_max_hp", "hand_size", "seed", "pre_battle_start", "equipped_equipment", "progression"]:
		var changed: Dictionary = input.duplicate(true)
		if field == "pre_battle_start":
			var choices: Array[Vector2i] = engine.pre_battle_start_tiles(input)
			var alternative: Vector2i = Vector2i(1, 1)
			if not choices.is_empty():
				for tile: Vector2i in choices:
					if tile != prepared["combat_state"]["player"]["pos"]:
						alternative = tile
						break
				_check(choices.has(alternative), "True Bearing case must choose a legal alternate entry")
				_check(alternative != prepared["combat_state"]["player"]["pos"], "True Bearing alternative must actually move the player")
			changed[field] = alternative
		elif field == "equipped_equipment": changed[field]["weapon"] = "iron_cleaver"
		elif field == "progression": changed[field]["level"] = int(changed[field].get("level", 1)) + 1
		else: changed[field] = int(changed.get(field, 1)) + 1
		_check(not engine.prepared_pre_battle_matches_input(prepared, changed), "Every changed input must miss the factory")
		var begun: Dictionary = engine.begin_pre_battle_combat(changed, prepared)
		_check(begun == reference.begin_pre_battle_combat(changed), "Changed " + field + " must invalidate the prepared factory")
		if field == "pre_battle_start" and engine.has_run_skill(changed, "true_bearing"):
			_check(begun["combat_state"]["player"]["pos"] == changed[field], "Legal alternate True Bearing entry must be committed")
	# Mutating a current definition must miss the generated-layout cache too.
	var definitions: Dictionary = GameData.enemies()
	var enemy_id: String = str((prepared["combat_state"]["enemies"] as Array)[0].get("type", "crawler"))
	var had_hp: bool = definitions[enemy_id].has("max_hp")
	var old_hp: Variant = definitions[enemy_id].get("max_hp", 1)
	definitions[enemy_id]["max_hp"] = int(old_hp) + 3
	_check(engine.pre_battle_preview_state(input) == reference.pre_battle_preview_state(input), "Changed enemy definitions must invalidate the generated layout")
	_check(not engine.prepared_pre_battle_matches_input(prepared, input), "Current enemy definition changes must invalidate a completed factory")
	_check(engine.pre_battle_preview_state(input, prepared) == reference.pre_battle_preview_state(input), "Changed definitions must invalidate a prepared preview")
	_check(engine.begin_pre_battle_combat(input, prepared) == reference.begin_pre_battle_combat(input), "Changed definitions must invalidate a prepared Begin")
	if had_hp: definitions[enemy_id]["max_hp"] = old_hp
	else: definitions[enemy_id].erase("max_hp")
	_check(engine.prepared_pre_battle_matches_input(prepared, input), "Restored current definitions must match the owned factory")
	var first: Dictionary = engine.prepare_pre_battle_combat(input)
	first["layout"]["enemies"].clear()
	_check(engine.pre_battle_preview_state(input) == reference.pre_battle_preview_state(input), "Caller mutations must not alias the generated layout cache")
	cases += 1
func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _append_skill_path(skill_id: String, preference: Array[String]) -> void:
	for prerequisite: String in Skills.prerequisites(skill_id): _append_skill_path(prerequisite, preference)
	if not preference.has(skill_id): preference.append(skill_id)
