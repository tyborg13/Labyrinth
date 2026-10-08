extends SceneTree
const Prepared = preload("res://scripts/prepared_equipment_combat.gd")
const Run = preload("res://scripts/run_engine.gd")
const Original = preload("res://tests/fixtures/pre_battle_factory_reference.gd")
const Data = preload("res://scripts/game_data.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
const Library = preload("res://scripts/grimoire_library.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
var errors: Array[String]
var checks: int = 0
var cases: int = 0
var step_max_usec: int = 0

class Owner extends Node:
	var _equipment_factory_preparation: RefCounted
	var _equipment_factory_preparation_generation: int = 1
	var _progression_overlay_mode: String = "equipment"
	var _upgrade_scrim := Control.new()
	var _combat_state: Dictionary = {}
	var _run_state: Dictionary = {}
	var _runtime_performance_instrumentation_enabled: bool = true
	var steps: int = 0
	func _ready() -> void: add_child(_upgrade_scrim)
	func _record_runtime_performance_phase(_phase: String, _started: int) -> void: steps += 1

func _initialize() -> void:
	Parallel.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var engine := Run.new()
	var inputs: Array[Dictionary]
	for tutorial: bool in [false, true]:
		var profile: Dictionary = Profile.default_data() if tutorial else Tutorial.complete_tutorial(Profile.default_data())
		var preference: Array[String]
		_append_skill_path("open_arsenal", preference)
		var owned: int = maxi(preference.size(), Skills.minimum_owned("open_arsenal") + 1)
		profile["level"] = owned + 1
		profile["skill_ids"] = Skills.repaired_selection([], owned, preference)
		for seed: int in [11, 32, 57, 84217]:
			var state: Dictionary = engine.create_new_run(seed, profile)
			if tutorial: state = Guided.mark_run_eligible(state)
			state["equipment_inventory"] = ["iron_cleaver", "duelist_rapier", "ward_kite"]
			state = engine._repair_equipment_state(state)
			var seen: Dictionary = {}
			for room: Dictionary in state["rooms"].values():
				var kind: String = str(room.get("type", ""))
				if kind not in ["combat", "boss", "guardian"] or seen.has(kind): continue
				seen[kind] = true
				var source: Dictionary = state.duplicate(true)
				source["current_room"] = room["coord"]
				source["pre_battle_travel_dir"] = Vector2i.RIGHT
				source["mode"] = Run.MODE_PRE_BATTLE
				inputs.append(source)
				for option: Dictionary in _options(): await _compare(engine, source, option)
	await _guard_cases(engine, inputs[0])
	await _owner_cases(inputs[0])
	print("PREPARED EQUIPMENT COMBAT RESULT: ", JSON.stringify({"cases":cases,"checks":checks,"errors":errors,"step_max_usec":step_max_usec,"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _options() -> Array[Dictionary]:
	var options: Array[Dictionary]
	for id: String in ["iron_cleaver", "duelist_rapier", "ward_kite"]:
		options.append({"id":id,"slot":Data.equipment_slot(id)})
		options.append({"id":id,"slot":"trinket"})
	return options

func _finish(prepared: RefCounted) -> void:
	var steps: int = 0
	while not bool(prepared.snapshot()["complete"]) and steps < 200:
		var started: int = Time.get_ticks_usec()
		prepared.advance()
		step_max_usec = maxi(step_max_usec, Time.get_ticks_usec() - started)
		steps += 1
		await process_frame
	_check(bool(prepared.snapshot()["complete"]), "Finite options must finish within a bounded number of steps")

func _preview_input(committed: Dictionary) -> Dictionary:
	return Library.unlock_entries(committed, Library.entry_ids_for_run_state(committed))["state"]

func _compare(engine: RefCounted, source: Dictionary, option: Dictionary) -> void:
	var caller: Dictionary = source.duplicate(true)
	var captured: Dictionary = caller.duplicate(true)
	var prepared := Prepared.new()
	prepared.begin(caller, [option])
	caller["player_hp"] = int(caller["player_hp"]) + 7
	caller["deck_cards"].clear()
	await _finish(prepared)
	_check(prepared.matches_source(captured) and not prepared.matches_source(caller), "Every future must own its pre-yield caller input")
	var committed: Dictionary = engine.equip_equipment(captured, option["id"], option["slot"])
	var expected_input: Dictionary = _preview_input(committed)
	var result: Dictionary = prepared.take(captured, committed, option["id"], option["slot"])
	_check(not result.is_empty(), "Every legal completed equipment option must be consumable")
	if result.is_empty(): return
	_check(engine.prepared_pre_battle_matches_input(result, expected_input), "Prepared input must include exact post-header Grimoire receipts")
	_check(engine.pre_battle_preview_state(expected_input, result) == Original.new().pre_battle_preview_state(expected_input), "Prepared preview must equal the complete original factory")
	_check(engine.begin_pre_battle_combat(expected_input, result) == Original.new().begin_pre_battle_combat(expected_input), "Prepared Begin must preserve complete original RNG, tutorials, effects and events")
	_check(prepared.snapshot()["ready"] == 0 and not prepared.matches_source(captured), "A click transfers one result and releases the entire old batch")
	var result_before: Dictionary = result.duplicate(true)
	var consumed: Dictionary = engine.begin_pre_battle_combat(expected_input, result)
	consumed["combat_state"]["enemies"].clear()
	_check(result == result_before, "The authoritative Begin result cannot alias prepared state")
	result["definitions"].clear()
	prepared.begin(captured, [option])
	await _finish(prepared)
	_check(not prepared.take(captured, committed, option["id"], option["slot"]).is_empty(), "Transferred catalog mutations cannot poison a subsequent generation")
	_check(source == captured, "Future creation must not mutate its original source")
	cases += 1

func _guard_cases(engine: RefCounted, input: Dictionary) -> void:
	var prepared := Prepared.new()
	var option: Dictionary = _options()[0]
	var committed: Dictionary = engine.equip_equipment(input, option["id"], option["slot"])
	prepared.begin(input, [option])
	prepared.advance()
	_check(prepared.snapshot()["partial"] and prepared.snapshot()["ready"] == 0, "Partial fixture must stop before assigning enemies")
	_check(prepared.take(input, committed, option["id"], option["slot"]).is_empty(), "A partial click must synchronously fall back")
	for step: int in range(10): prepared.advance()
	_check(prepared.snapshot()["ready"] == 0, "Cancelled partial work cannot refill a consumed generation")
	for field: String in ["hp", "deck", "room", "profile", "receipt"]:
		prepared.begin(input, [option])
		await _finish(prepared)
		var changed: Dictionary = input.duplicate(true)
		match field:
			"hp": changed["player_hp"] = int(changed["player_hp"]) - 1
			"deck": changed["deck_cards"].reverse()
			"room": changed["pre_battle_travel_dir"] = Vector2i.LEFT
			"profile": changed["progression"]["level"] = int(changed["progression"]["level"]) + 1
			"receipt": changed["grimoire_notice"] = "Different complete input"
		_check(prepared.take(changed, engine.equip_equipment(changed, option["id"], option["slot"]), option["id"], option["slot"]).is_empty(), field + " source mismatch must reject every prepared result")
	prepared.begin(input, [option])
	await _finish(prepared)
	var changed_commit: Dictionary = committed.duplicate(true)
	changed_commit["player_hp"] = 1
	_check(prepared.take(input, changed_commit, option["id"], option["slot"]).is_empty(), "Unexpected authoritative equip output must reject the future")
	prepared.begin(input, _options())
	while prepared.snapshot()["ready"] == 0: prepared.advance()
	_check(not prepared.take(input, committed, option["id"], option["slot"]).is_empty(), "A ready option may be used while other options remain incomplete")
	var definition: Dictionary = Data.cards()["pale_spark"]
	var prior: Variant = definition["name"]
	for ready: bool in [false, true]:
		prepared.begin(input, [option])
		if ready: await _finish(prepared)
		else: prepared.advance()
		definition["name"] = "Changed equipment-future definitions"
		_check(not prepared.matches_source(input), "Changed catalog content must invalidate source matching")
		_check(prepared.advance() and prepared.snapshot()["ready"] == 0, "Changed definitions must discard both partial and complete work")
		_check(prepared.take(input, committed, option["id"], option["slot"]).is_empty(), "Changed definitions cannot transfer a ready future")
		definition["name"] = prior
	var large: Dictionary = input.duplicate(true)
	large["equipment_inventory"] = Data.equipment().keys()
	var options: Array[Dictionary]
	for id: String in large["equipment_inventory"]: options.append({"id":id,"slot":Data.equipment_slot(id)})
	prepared.begin(large, options)
	_check(prepared.snapshot()["options"] == Prepared.OPTION_LIMIT, "A large inventory must retain only the bounded current options")
	await _finish(prepared)
	_check(prepared.snapshot()["ready"] <= Prepared.OPTION_LIMIT, "Ready factories must remain bounded")
	prepared.reset()

func _owner_cases(input: Dictionary) -> void:
	for reason: String in ["generation", "mode", "hidden", "state", "replacement", "detach", "free"]:
		var owner := Owner.new()
		owner._run_state = input.duplicate(true)
		owner._equipment_factory_preparation = Prepared.new()
		owner._equipment_factory_preparation.begin(owner._run_state, _options())
		var prepared: RefCounted = owner._equipment_factory_preparation
		root.add_child(owner)
		Prepared.prepare_for.call_deferred(owner, prepared, owner._equipment_factory_preparation_generation)
		for frame: int in range(4): await process_frame
		_check(owner.steps > 0, "Lifecycle fixture must enter actual scheduled preparation")
		match reason:
			"generation": owner._equipment_factory_preparation_generation += 1
			"mode": owner._progression_overlay_mode = "magic"
			"hidden": owner._upgrade_scrim.hide()
			"state": owner._run_state["player_hp"] = 1
			"replacement": owner._equipment_factory_preparation = Prepared.new()
			"detach": root.remove_child(owner)
			"free": owner.free()
		for frame: int in range(5): await process_frame
		_check(prepared.snapshot()["ready"] == 0 and not prepared.snapshot()["partial"], reason + " must discard every scheduled partial result")
		if is_instance_valid(owner): owner.free()
	await process_frame
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Owner cancellation and teardown must leave no orphan nodes")

func _append_skill_path(id: String, preference: Array[String]) -> void:
	for prerequisite: String in Skills.prerequisites(id): _append_skill_path(prerequisite, preference)
	if not preference.has(id): preference.append(id)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label)
