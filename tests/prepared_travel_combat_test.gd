extends SceneTree

const Preparation = preload("res://scripts/encounter_asset_preparation.gd")
const Run = preload("res://scripts/run_engine.gd")
const Reference = preload("res://tests/fixtures/pre_battle_factory_reference.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
const Data = preload("res://scripts/game_data.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")

class Owner extends Node:
	var _run_engine := Run.new()
	var _encounter_preparation_generation: int = 0
	var _runtime_performance_instrumentation_enabled: bool = false
	var _prepared_pre_battle_factory: Dictionary = {"sentinel": true}
	var steps: int = 0
	func _record_runtime_performance_phase(_phase: String, _started: int) -> int:
		steps += 1
		return 0

var errors: Array[String]
var checks: int = 0
var cases: int = 0

func _initialize() -> void:
	Parallel.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var reference := Reference.new()
	for tutorial: bool in [false, true]:
		var profile: Dictionary = Progression.default_data() if tutorial else Tutorial.complete_tutorial(Progression.default_data())
		for seed: int in [11, 32, 57, 84217]:
			var run: Dictionary = Run.new().create_new_run(seed, profile)
			if tutorial: run = Guided.mark_run_eligible(run)
			var seen: Dictionary = {}
			for room: Dictionary in run["rooms"].values():
				var kind: String = str(room.get("type", ""))
				if kind not in ["combat", "boss", "guardian"] or seen.has(kind): continue
				seen[kind] = true
				var input: Dictionary = run.duplicate(true)
				input["mode"] = Run.MODE_PRE_BATTLE
				input["current_room"] = room["coord"]
				input["pre_battle_travel_dir"] = Vector2i.RIGHT
				await _case(input, reference)
	await process_frame
	_check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == 0, "Travel preparation must release every owner")
	print("PREPARED TRAVEL COMBAT RESULT: " + JSON.stringify({"cases": cases, "checks": checks, "errors": errors, "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}))
	quit(0 if errors.is_empty() else 1)

func _capture(owner: Node, input: Dictionary, generation: int, result: Dictionary) -> void:
	result["factory"] = await Preparation.prepare_combat_factory_for(owner, input, generation)
	result["complete"] = true

func _finish(result: Dictionary) -> void:
	for frame: int in range(100):
		if bool(result.get("complete", false)): return
		await process_frame
	_check(false, "Owned travel preparation must finish without a caller wait")

func _case(input: Dictionary, reference: RefCounted) -> void:
	var original: Dictionary = input.duplicate(true)
	var owner := Owner.new()
	root.add_child(owner)
	var result: Dictionary = {}
	_capture(owner, input, 0, result)
	_check(not bool(result.get("complete", false)) and owner.steps == 1, "Beginning must yield after the owned initial step")
	input["player_hp"] = int(input["player_hp"]) + 1
	await _finish(result)
	var factory: Dictionary = result.get("factory", {})
	_check(not factory.is_empty(), "A valid travel input must finish its private factory")
	_check(owner._run_engine.prepared_pre_battle_matches_input(factory, original), "A completed travel factory must be directly adoptable without fallback")
	_check(owner._prepared_pre_battle_factory == {"sentinel": true}, "Preparation must not publish any partial scene state")
	_check(owner._run_engine.pre_battle_preview_state(original, factory) == reference.pre_battle_preview_state(original), "Travel preview must equal the independent original")
	_check(owner._run_engine.begin_pre_battle_combat(original, factory) == reference.begin_pre_battle_combat(original), "Travel Begin must preserve the whole original encounter")
	_check(not owner._run_engine.prepared_pre_battle_matches_input(factory, input), "Caller changes must be rejected by the ordinary adoption guard")
	_check(owner._run_engine.begin_pre_battle_combat(input, factory) == reference.begin_pre_battle_combat(input), "Changed caller input must use the exact synchronous fallback")
	var captured: Dictionary = factory.duplicate(true)
	var committed: Dictionary = owner._run_engine.begin_pre_battle_combat(original, factory)
	committed["combat_state"]["enemies"].clear()
	_check(factory == captured, "Commit must not alias the prepared travel factory")
	input = original.duplicate(true)
	for boundary: int in range(owner.steps):
		var canceled: Dictionary = {}
		_capture(owner, input, 0, canceled)
		for step: int in range(boundary): await process_frame
		if bool(canceled.get("complete", false)): continue
		owner._encounter_preparation_generation += 1
		await _finish(canceled)
		_check((canceled.get("factory", {}) as Dictionary).is_empty(), "Every in-flight boundary must cancel without publication")
		owner._encounter_preparation_generation = 0
	var changed: Dictionary = {}
	_capture(owner, input, 0, changed)
	var enemies: Dictionary = Data.enemies()
	var enemy_id: String = str(factory["combat_state"]["enemies"][0]["type"])
	var prior_name: Variant = enemies[enemy_id].get("name", null)
	enemies[enemy_id]["name"] = "Changed preparation catalog"
	await _finish(changed)
	_check((changed.get("factory", {}) as Dictionary).is_empty(), "A changed catalog must discard the incomplete factory")
	if prior_name == null: enemies[enemy_id].erase("name")
	else: enemies[enemy_id]["name"] = prior_name
	var retry: Dictionary = {}
	_capture(owner, input, 0, retry)
	await _finish(retry)
	_check(owner._run_engine.prepared_pre_battle_matches_input(retry["factory"], input), "A restored-catalog retry must be directly adoptable")
	_check(owner._run_engine.begin_pre_battle_combat(input, retry["factory"]) == Reference.new().begin_pre_battle_combat(input), "Restored definitions must support an exact fresh retry")
	_check(input == original, "Travel preparation must never mutate its source")
	owner.free()
	for teardown: String in ["detach", "free", "queue_free"]:
		var retiring := Owner.new()
		root.add_child(retiring)
		var abandoned: Dictionary = {}
		_capture(retiring, original, 0, abandoned)
		if teardown == "detach": root.remove_child(retiring)
		elif teardown == "free": retiring.free()
		else: retiring.queue_free()
		await _finish(abandoned)
		_check((abandoned.get("factory", {}) as Dictionary).is_empty(), "A " + teardown + " owner must discard private work")
		if is_instance_valid(retiring): retiring.free()
	cases += 1

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
