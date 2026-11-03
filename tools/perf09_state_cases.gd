extends "res://tools/inspection_fixture.gd"
## Production inspection fixtures complement the continuous Thornmother soak.
## Run headless through godot_task_runner; only writes the requested temp output.
const PROOF_SCENARIOS: Array = ["dragon", "guardian", "combat"]
const PROOF_BIOME: String = "earth"
const PROOF_BOARD_SIZE := Vector2(1920, 1080)
const PROOF_TARGET_A := Vector2i(3, 3)
const PROOF_TARGET_B := Vector2i(4, 3)
const PROOF_PROGRESS: Array = [0.0, 0.25, 0.5, 0.75, 1.0]
const PROOF_NAV_ZOOM: float = 1.2
const PROOF_NAV_PAN := Vector2(28, -18)
var output: String

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run_cases")

func _run_cases() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output = args[args.find("--output-dir") + 1]
	DirAccess.make_dir_recursive_absolute(output)
	var states: Dictionary = {}
	var host: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	for scenario: String in PROOF_SCENARIOS:
		_options = {"scenario": scenario, "seed": DEFAULT_SEED, "dragon_id": "vyraketh", "guardian_id": "craghide", "hero_facing": "persist"}
		var run: Dictionary = _build_run_state(scenario, _build_progression())
		var state: Dictionary = run["combat_state"]
		var shown: Dictionary = {"board_framing_mode": "combat", "biome_id": PROOF_BIOME}
		host.call("_apply_guardian_props", state, shown)
		states[scenario + "/idle"] = _sample(state, shown)
		for index: int in range((state["enemies"] as Array).size()):
			var threat: Dictionary = _combat_engine.enemy_threat_tiles(state, index)
			var preview: Dictionary = shown.duplicate(true)
			preview["enemy_threat_previews"] = [threat]
			preview["path_tiles"] = threat.get("projected_path", [])
			preview["expand_enemy_intents"] = true
			states[scenario + "/hover_" + str(index)] = _sample(state, preview)
		var result: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(_combat_engine.finish_player_activation(state))
		var next: Dictionary = result["state"]
		states[scenario + "/enemy_after"] = _sample(next, shown)
	_revision_cases(states)
	var file := FileAccess.open(output.path_join("states.bin"), FileAccess.WRITE)
	file.store_var(states)
	file.close()
	host.free()
	print("PERF09 FIXTURE STATES: PASS (%d production and explicit transition states)" % states.size())
	quit()

func _sample(state: Dictionary, shown: Dictionary) -> Dictionary:
	return {"state": state.duplicate(true), "presentation": shown.duplicate(true), "move_tiles": [], "attack_tiles": [],
		"selected_tile": Vector2i(-1, -1), "exit_tiles": {}, "exit_icon_ids": {}, "board_size": PROOF_BOARD_SIZE}

func _revision_cases(states: Dictionary) -> void:
	var plain: Dictionary = _build_combat_run(_build_progression())["combat_state"]
	var targeted: Dictionary = plain.duplicate(true)
	targeted["terrain"] = [
		{"id": "target_a", "kind": "crag_outcrop", "pos": PROOF_TARGET_A, "hp": 3, "max_hp": 3},
		{"id": "target_b", "kind": "crag_outcrop", "pos": PROOF_TARGET_B, "hp": 3, "max_hp": 3}]
	states["targets/base"] = _sample(targeted, {})
	var unit: Dictionary = targeted["enemies"][0]
	var preview: Dictionary = {"damage_preview": {"enemy_%d" % int(unit["id"]): {"hp": maxi(0, int(unit["hp"]) - 1), "hp_loss": 1, "lethal": false}}}
	for stage: String in ["enter", "change", "clear"]:
		var sample: Dictionary = _sample(targeted, preview if stage != "clear" else {})
		if stage != "clear": sample["attack_tiles"] = [PROOF_TARGET_A if stage == "enter" else PROOF_TARGET_B]
		states["targets/" + stage] = sample

	var bramble: Dictionary = {"id": "transition_bramble", "kind": "bramble", "pos": PROOF_TARGET_A, "hp": 3, "max_hp": 3, "rounds_left": 3}
	var growing: Dictionary = plain.duplicate(true)
	growing["terrain"] = [bramble]
	states["bramble/before"] = _sample(plain, {})
	var growth: Dictionary = {"kind": "surface", "en04_mechanic": "grow_bramble", "tiles": [PROOF_TARGET_A]}
	var expiry: Dictionary = {"kind": "surface", "en04_mechanic": "bramble_expiry", "expired_bramble": [bramble]}
	for progress: float in PROOF_PROGRESS:
		states["bramble/growth_" + str(progress)] = _sample(growing, preload("res://scripts/enemy_mechanics/bramble_view.gd").presentation_for_step(growth, progress))
	states["bramble/settled"] = _sample(growing, {})
	var expired: Dictionary = plain.duplicate(true)
	expired["terrain"] = []
	for progress: float in PROOF_PROGRESS:
		states["bramble/expiry_" + str(progress)] = _sample(expired, preload("res://scripts/enemy_mechanics/bramble_view.gd").presentation_for_step(expiry, progress))
	states["bramble/cleared"] = _sample(expired, {})

	_options = {"scenario": "warband", "seed": DEFAULT_SEED, "warband_biome": "earth", "warband_tier": 2, "warband_case": "encounter", "hero_facing": "persist"}
	var run: Dictionary = _build_run_state("warband", _build_progression())
	var before: Dictionary = (run["combat_state"] as Dictionary).duplicate(true)
	var captain: Dictionary = preload("res://scripts/warband_combat_rules.gd").captain(before)
	var action: Dictionary = preload("res://scripts/enemy_mechanics/bramble.gd").marking_action(captain)
	var instance: Dictionary = preload("res://scripts/enemy_mechanics/bramble.gd").instance(captain, action)
	preload("res://scripts/battlefield_rules/upheaval.gd").prepare(_combat_engine, before, instance)
	before["turn"] = int(before["turn"]) + 1 # Cross the production fuel boundary.
	states["upheaval/before"] = _sample(before, {})
	var raised: Dictionary = preload("res://scripts/battlefield_rules/upheaval.gd").resolve_beat(_combat_engine, before.duplicate(true), instance)
	var events: Array = (raised.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "terrain_created")
	assert(not events.is_empty(), "Explicit Upheaval fixture must actually raise Outcrops")
	for progress: float in PROOF_PROGRESS:
		states["upheaval/rise_" + str(progress)] = _sample(raised, {"surface_feedback_events": events, "surface_feedback_progress": progress})
	states["upheaval/settled"] = _sample(raised, {})

	var walk_before: Dictionary = preload("res://tests/suites/player_movement_suite.gd")._state(_combat_engine)
	var walked: Dictionary = _combat_engine.apply_player_movement(walk_before, Vector2i(3, 4))
	var undo := preload("res://scripts/movement_undo_rules.gd").new()
	undo.record_walk(walk_before, walked)
	assert(undo.available(walked), "Fixture walk must be reversible by the production undo rules")
	states["undo/before"] = _sample(walk_before, {})
	states["undo/walked"] = _sample(walked, {})
	states["undo/restored"] = _sample(undo.undo(walked)["state"], {})

	ProgressionStore.set_run_storage_path(output.path_join("mid-fight.save"))
	run["combat_state"] = raised
	assert(ProgressionStore.save_run_state(run), "Save the actual mid-fight fixture through production storage")
	var loaded: Dictionary = ProgressionStore.load_saved_run()
	assert(not loaded.is_empty(), "Production load must return the saved fight")
	states["load/before"] = _sample(raised, {})
	states["load/other_state"] = _sample(plain, {})
	states["load/restored"] = _sample(loaded["combat_state"], {})

	for stage: String in ["base", "zoom", "pan", "reset"]:
		var sample: Dictionary = _sample(targeted, {})
		sample["navigation"] = {"reset": true} if stage in ["base", "reset"] else {"zoom": PROOF_NAV_ZOOM, "pan": PROOF_NAV_PAN if stage == "pan" else Vector2.ZERO}
		states["navigation/" + stage] = sample

	var textured: Dictionary = plain.duplicate(true)
	textured["terrain"] = [{"id": "atlas_crate", "kind": "wooden_crate", "pos": PROOF_TARGET_A, "hp": 3, "max_hp": 3}]
	for stage: String in ["base", "region", "margin", "underlying", "reset"]:
		var sample: Dictionary = _sample(textured, {})
		sample["texture_mutation"] = {"stage": stage, "tile": PROOF_TARGET_A}
		states["texture/" + stage] = sample
