extends SceneTree
const Run = preload("res://scripts/run_engine.gd")
const Original = preload("res://tests/fixtures/pre_battle_factory_reference.gd")
const Data = preload("res://scripts/game_data.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
var errors: Array[String]
var cases: int = 0
var checks: int = 0
var step_max_usec: int = 0
var step_top: Array[Dictionary]

func _initialize() -> void:
	Parallel.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var engine := Run.new()
	var original := Original.new()
	var inputs: Array[Dictionary]
	for tutorial: bool in [false, true]:
		var profile: Dictionary = Profile.default_data() if tutorial else Tutorial.complete_tutorial(Profile.default_data())
		for seed: int in [11, 32, 57, 84217]:
			var state: Dictionary = engine.create_new_run(seed, profile)
			if tutorial: state = Guided.mark_run_eligible(state)
			var seen: Dictionary = {}
			for room: Dictionary in (state["rooms"] as Dictionary).values():
				var type: String = str(room.get("type", ""))
				if type not in ["combat", "boss", "guardian"] or seen.has(type): continue
				seen[type] = true
				var source: Dictionary = state.duplicate(true)
				source["current_room"] = room["coord"]
				source["mode"] = Run.MODE_PRE_BATTLE
				source["pre_battle_travel_dir"] = Vector2i.RIGHT
				inputs.append(source)
	var relic_ids: Array = Data.relics().keys()
	relic_ids.sort()
	for input: Dictionary in inputs:
		await _compare(engine, original, input)
		for id: String in relic_ids:
			var with_relic: Dictionary = input.duplicate(true)
			with_relic["relics"] = [id]
			await _compare(engine, original, with_relic)
		# The same run engine may service independent future cursors between
		# synchronous work. Shared effect/layout caches cannot own their RNG.
		var a: Dictionary = engine.begin_pre_battle_combat_preparation(input)
		var changed: Dictionary = input.duplicate(true)
		changed["seed"] = int(changed["seed"]) + 31
		changed["player_hp"] = maxi(1, int(changed["player_hp"]) - 1)
		changed["relics"] = [str(relic_ids[0])]
		var b: Dictionary = engine.begin_pre_battle_combat_preparation(changed)
		var ready_a: bool = false
		var ready_b: bool = false
		while not ready_a or not ready_b:
			if not ready_a: ready_a = engine.advance_pre_battle_combat_preparation(a)
			if not ready_b: ready_b = engine.advance_pre_battle_combat_preparation(b)
			await process_frame
		_check(engine.pre_battle_preview_state(input, a) == original.pre_battle_preview_state(input), "Interleaved first cursor must preserve full original state")
		_check(engine.pre_battle_preview_state(changed, b) == original.pre_battle_preview_state(changed), "Interleaved second cursor must preserve its own RNG and effects")
	await _definition_boundaries(engine, inputs[0])
	await _definition_effect_retry(engine, inputs[0])
	await _definition_interleaved_effect_restore(engine, inputs[0])
	var wrong: Dictionary = inputs[0].duplicate(true)
	wrong["mode"] = "room"
	var empty: Dictionary = engine.begin_pre_battle_combat_preparation(wrong)
	_check(empty.is_empty() and engine.advance_pre_battle_combat_preparation(empty), "An ineligible factory must finish without a partial result")
	print("OWNED COMBAT CREATION RESULT: ", JSON.stringify({"cases": cases, "checks": checks, "errors": errors, "step_max_usec": step_max_usec, "step_top": step_top}))
	quit(0 if errors.is_empty() else 1)

func _compare(engine: RefCounted, original: RefCounted, input: Dictionary) -> void:
	var source: Dictionary = input.duplicate(true)
	var expected: Dictionary = original.pre_battle_preview_state(source)
	var owned: Dictionary = engine.begin_pre_battle_combat_preparation(source)
	_check(not owned.is_empty() and not engine.prepared_pre_battle_matches_input(owned, source), "A partial factory cannot become a ready result")
	var captured: Dictionary = source.duplicate(true)
	# Mutate the caller immediately after begin. Every later rule runs against
	# the previously owned state, including nested deck and equipment values.
	source["player_hp"] = int(source["player_hp"]) + 7
	source["equipped_equipment"]["weapon"] = "duelist_rapier"
	source["deck_cards"].clear()
	var steps: int = 0
	while owned.has("combat_creation"):
		_check(not engine.prepared_pre_battle_matches_input(owned, captured), "No enemy boundary may publish partial combat")
		if steps == 0:
			var rng: RandomNumberGenerator = owned["combat_creation"]["rng"]
			var rng_state: int = rng.state
			_check(engine.pre_battle_preview_state(captured, owned) == expected, "Passing a partial result must use the original synchronous fallback")
			_check(rng.state == rng_state, "Synchronous fallback cannot advance the future cursor RNG")
		var creation: Dictionary = owned["combat_creation"]
		var index: int = int(creation["enemy_index"])
		var enemy_type: String = str(creation["state"]["enemies"][index].get("type", "")) if index < int(creation["enemy_count"]) else "finalize"
		var started: int = Time.get_ticks_usec()
		var finished: bool = engine.advance_pre_battle_combat_preparation(owned)
		var elapsed: int = Time.get_ticks_usec() - started
		step_max_usec = maxi(step_max_usec, elapsed)
		if step_top.size() < 8 or elapsed > int(step_top[-1]["usec"]):
			step_top.append({"usec": elapsed, "enemy": enemy_type, "seed": captured["seed"], "relics": captured["relics"], "room_type": creation["state"]["room_type"]})
			step_top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["usec"]) > int(b["usec"]))
			if step_top.size() > 8: step_top.resize(8)
		steps += 1
		if finished: break
		await process_frame
	_check(engine.prepared_pre_battle_matches_input(owned, captured), "Only a fully prepared matching factory may be adopted")
	_check(not engine.prepared_pre_battle_matches_input(owned, source), "Changed caller input cannot adopt an older future")
	_check(engine.pre_battle_preview_state(captured, owned) == expected, "Cooperative creation must preserve complete original preview state")
	_check(engine.begin_pre_battle_combat(captured, owned) == original.begin_pre_battle_combat(captured), "Cooperative Begin must preserve tutorial, RNG, events, loot and pity")
	var state_copy: Dictionary = owned["combat_state"].duplicate(true)
	var committed: Dictionary = engine.begin_pre_battle_combat(captured, owned)
	committed["combat_state"]["enemies"].clear()
	_check(owned["combat_state"] == state_copy, "Committed state cannot alias the owned future")
	_check(input == captured, "Future preparation cannot mutate its original caller")
	_check(engine.advance_pre_battle_combat_preparation(owned), "Completed creation must remain idempotently complete")
	cases += 1

func _definition_boundaries(engine: RefCounted, input: Dictionary) -> void:
	var ready: Dictionary = engine.prepare_pre_battle_combat(input)
	var enemy_type: String = str(ready["combat_state"]["enemies"][0]["type"])
	var definition: Dictionary = Data.enemies()[enemy_type]
	var prior: Variant = definition.get("name")
	var boundaries: int = (ready["combat_state"]["enemies"] as Array).size() + 1
	for boundary: int in range(boundaries):
		var owned: Dictionary = engine.begin_pre_battle_combat_preparation(input)
		for step: int in range(boundary): engine.advance_pre_battle_combat_preparation(owned)
		definition["name"] = "Changed during owned creation"
		_check(engine.advance_pre_battle_combat_preparation(owned) and owned.is_empty(), "Changed definitions must discard every incomplete boundary")
		definition["name"] = prior
		await process_frame

func _definition_effect_retry(engine: RefCounted, input: Dictionary) -> void:
	var source: Dictionary = input.duplicate(true)
	source["relics"] = ["waxen_effigy"]
	var definition: Dictionary = Data.relics()["waxen_effigy"]
	var effect: Dictionary = definition["effects"][0]
	var prior: int = int(effect["health"])
	var ready: Dictionary = engine.prepare_pre_battle_combat(source)
	_check(not (ready["combat_state"]["illusions"] as Array).is_empty(), "Relic retry fixture must create an actual illusion")
	var boundaries: int = (ready["combat_state"]["enemies"] as Array).size() + 1
	for boundary: int in range(boundaries):
		var owned: Dictionary = engine.begin_pre_battle_combat_preparation(source)
		for step: int in range(boundary): engine.advance_pre_battle_combat_preparation(owned)
		effect["health"] = prior + 1
		_check(engine.advance_pre_battle_combat_preparation(owned) and owned.is_empty(), "Changed relic effects must abort every incomplete boundary")
		_check(not engine.prepared_pre_battle_matches_input(ready, source), "Changed effects must also reject an already complete factory")
		var expected: Dictionary = Original.new().pre_battle_preview_state(source)
		var retry: Dictionary = engine.pre_battle_preview_state(source)
		_check(retry == expected, "Retry on the same engine must match a fresh original factory after effect changes")
		_check(int(retry["combat_state"]["illusions"][0]["hp"]) == prior + 1, "Retry must actually use the changed illusion health")
		effect["health"] = prior
		_check(engine.pre_battle_preview_state(source) == Original.new().pre_battle_preview_state(source), "Restored definitions must refresh the same engine again")
		await process_frame

func _definition_interleaved_effect_restore(engine: RefCounted, input: Dictionary) -> void:
	var source: Dictionary = input.duplicate(true)
	source["relics"] = ["reliquary_box"]
	var deck: Array[String]
	for index: int in range(30): deck.append("pale_spark")
	deck.append("thorn_crown_pact")
	source["deck_cards"] = deck
	var unprotected: Dictionary = source.duplicate(true)
	unprotected["relics"] = []
	# Ensure the guaranteed-Rite rule does observable work in this fixture.
	var found: bool = false
	for seed: int in range(1, 20):
		unprotected["seed"] = seed
		if not (Original.new().pre_battle_preview_state(unprotected)["combat_state"]["deck"]["hand"] as Array).has("thorn_crown_pact"):
			source["seed"] = seed
			found = true
			break
	_check(found, "Restored-definition fixture must ordinarily draw no Rite")
	var expected: Dictionary = Original.new().pre_battle_preview_state(source)
	_check((expected["combat_state"]["deck"]["hand"] as Array).has("thorn_crown_pact"), "Original relic must guarantee the fixture Rite")
	var definition: Dictionary = Data.relics()["reliquary_box"]
	var prior_effects: Array = definition["effects"]
	var altered_effects: Array = []
	for effect: Dictionary in prior_effects:
		if str(effect.get("type", "")) != "opening_hand_rite": altered_effects.append(effect)
	var boundaries: int = (expected["combat_state"]["enemies"] as Array).size() + 1
	for boundary: int in range(boundaries):
		var a: Dictionary = engine.begin_pre_battle_combat_preparation(source)
		for step: int in range(boundary): engine.advance_pre_battle_combat_preparation(a)
		definition["effects"] = altered_effects
		var b: Dictionary = engine.begin_pre_battle_combat_preparation(source)
		definition["effects"] = prior_effects
		# A's owned definitions match again. B's shared effects must not leak into
		# A when relic IDs and Rite signatures happen to be identical.
		while not engine.advance_pre_battle_combat_preparation(a): await process_frame
		_check(engine.pre_battle_preview_state(source, a) == expected, "Restored definitions with interleaved cursors must preserve full original state")
		_check((a["combat_state"]["deck"]["hand"] as Array).has("thorn_crown_pact"), "Interleaving cannot omit the guaranteed opening Rite")
		_check(engine.advance_pre_battle_combat_preparation(b) and b.is_empty(), "The cursor that captured altered definitions must abort after restoration")
		await process_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label)
