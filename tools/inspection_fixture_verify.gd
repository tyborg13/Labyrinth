extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var run_state: Dictionary = ProgressionStore.load_saved_run()
	if run_state.is_empty():
		_fail("current_run.save is missing or invalid")
		return
	var metadata: Dictionary = run_state.get("inspection_fixture", {}) as Dictionary
	if metadata.is_empty():
		_fail("saved run has no inspection_fixture metadata")
		return
	var expected_namespace: String = ParallelRuntime.current_namespace()
	if expected_namespace.is_empty():
		_fail("verification requires an isolated LABYRINTH_USER_DIR_NAME namespace")
		return
	if str(metadata.get("namespace", "")) != expected_namespace:
		_fail("fixture namespace mismatch: expected %s, got %s" % [expected_namespace, str(metadata.get("namespace", ""))])
		return
	var progression: Dictionary = ProgressionStore.load_data()
	var expected_contract: Dictionary = metadata.get("state_contract", {}) as Dictionary
	if expected_contract.is_empty():
		_fail("fixture metadata has no state contract")
		return
	var actual_contract: Dictionary = _fixture_state_contract(run_state, progression)
	if actual_contract != expected_contract:
		_fail("saved fixture no longer matches its state contract\nexpected=%s\nactual=%s" % [JSON.stringify(expected_contract), JSON.stringify(actual_contract)])
		return
	var payload: Dictionary = {
		"ok": true,
		"scenario": str(metadata.get("scenario", "")),
		"namespace": expected_namespace,
		"mode": str(run_state.get("mode", "")),
		"save_path": ProjectSettings.globalize_path("user://current_run.save"),
		"state_contract": actual_contract
	}
	print("Inspection fixture verified.")
	print("INSPECTION_FIXTURE_VERIFIED %s" % JSON.stringify(payload))
	quit(0)

func _fixture_state_contract(run_state: Dictionary, progression: Dictionary) -> Dictionary:
	var contract_run_state: Dictionary = run_state.duplicate(true)
	contract_run_state.erase("inspection_fixture")
	var combat_state: Dictionary = run_state.get("combat_state", {}) as Dictionary
	var deck: Dictionary = combat_state.get("deck", {}) as Dictionary
	var enemy_types: Array[String] = []
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY:
			enemy_types.append(str((enemy_var as Dictionary).get("type", "")))
	var reward: Dictionary = run_state.get("pending_reward", {}) as Dictionary
	var current_room: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	return {
		"run_state_sha256": _variant_sha256(contract_run_state),
		"progression_sha256": _variant_sha256(progression),
		"mode": str(run_state.get("mode", "")),
		"current_room": "%d,%d" % [current_room.x, current_room.y],
		"hand": _string_array(deck.get("hand", [])),
		"enemy_types": enemy_types,
		"reward_cards": _string_array(reward.get("cards", [])),
		"relic_choices": _string_array(run_state.get("pending_relics", [])),
		"progression_level": int(progression.get("level", 1)),
		"progression_embers": int(progression.get("embers", 0))
	}

func _variant_sha256(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item_var: Variant in value as Array:
		result.append(str(item_var))
	return result

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("INSPECTION FIXTURE VERIFY ERROR: %s" % message)
	quit(1)
