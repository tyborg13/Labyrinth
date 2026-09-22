extends "res://tests/zekarion_cutout_gameplay_probe.gd"

## Real resolver steps and enemy playback with an observing RunScene subclass.
## This checks composited actors, not merely the still-live cutout renderer.
const Harness = preload("res://tests/fixtures/player_defeat_continuity_run_scene_harness.gd")
const GuardianFixtures = preload("res://tests/suites/guardian_suite.gd")
const GuardianRules = preload("res://scripts/guardian_combat_rules.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
var _case_reports: Array[Dictionary]

func _run() -> void:
	_capture = false
	root.size = SIZE
	root.content_scale_size = SIZE
	ProgressionStore.set_storage_path("user://player_defeat_continuity_progression.json")
	ProgressionStore.set_run_storage_path("user://player_defeat_continuity_run.save")
	ProgressionStore.clear_saved_run()
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_instance.set_script(Harness)
	root.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	for reduced: bool in [false, true]:
		for intent: String in ["storm_claw", "tempest_breath", "skybreak"]:
			await _fixture(Vector2i(4, 6), Vector2i(4, 4), reduced, intent)
			var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
			state["player"]["hp"] = 1
			state["player"]["block"] = 0
			state["defiance_remaining"] = 0
			if intent == "skybreak":
				var plan: Dictionary = CombatEngine.new().enemy_intent_plan(state, 0)
				state["player"]["pos"] = plan["projected_attack"][0]
			await _exercise(state, intent + ("_reduced" if reduced else "_normal"), false)
		await _fixture(Vector2i(4, 6), Vector2i(4, 4), reduced)
		await _exercise(_trap_state(), "trap_conduction" + ("_reduced" if reduced else "_normal"), true)
	var report: Dictionary = {"ok": _errors.is_empty(), "errors": _errors, "cases": _case_reports}
	var file := FileAccess.open("user://player_defeat_continuity.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	for message: String in _errors:
		push_error(message)
	print("Saved " + ProjectSettings.globalize_path("user://player_defeat_continuity.json"))
	print("PLAYER DEFEAT CONTINUITY: " + ("PASS" if _errors.is_empty() else "FAIL"))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _exercise(before: Dictionary, label: String, require_trap: bool) -> void:
	var engine := CombatEngine.new()
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0)
	_assert(int(result["state"]["player"]["hp"]) == 0, label + " resolves a real lethal enemy attack")
	var steps: Array = result["steps"]
	var has_trap: bool = false
	for step: Dictionary in steps:
		if not (step.get("triggered_traps", []) as Array).is_empty():
			has_trap = true
	_assert(has_trap == require_trap, label + " uses its intended direct/trap route")
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = before.duplicate(true)
	_instance.set("_run_state", run)
	_instance.call("_sync_combat_state_from_run")
	_instance.call("_refresh_ui")
	await _settle()
	var original: Dictionary = before.duplicate(true)
	var animated: Dictionary = before.duplicate(true)
	_instance.call("begin_continuity_trace")
	await _instance.call("_animate_enemy_phase_steps", animated, steps)
	_instance.set("continuity_trace_enabled", false)
	_assert(before == original, label + " leaves its input state unchanged")
	_assert(animated["player"] == result["state"]["player"], label + " displays exactly the resolver's final player state")
	var samples: Array = (_instance.get("continuity_samples") as Array).duplicate(true)
	var completed: bool = false
	var contact_samples: int = 0
	var hidden_before_completion: int = 0
	var trap_samples: int = 0
	for sample: Dictionary in samples:
		if float(sample["death_progress"]) >= 1.0:
			completed = true
		if not bool(sample["visible"]) and not completed:
			hidden_before_completion += 1
		if bool(sample["visible"]):
			_assert(bool(sample["death_animation"]), label + " retains the resolved player through an explicit defeat descriptor")
			_assert(sample["tile"] == sample["resolved_tile"], label + " holds the body on the actual lethal tile")
		if not str(sample["effect_kind"]).is_empty():
			contact_samples += 1
			_assert(is_zero_approx(float(sample["death_progress"])), label + " holds the intact pose until attack feedback completes")
		if bool(sample["trap_effects"]):
			trap_samples += 1
	_assert(not samples.is_empty(), label + " submits resolved lethal board states")
	_assert(completed, label + " reaches the complete death timeline")
	_assert(hidden_before_completion == 0, label + " must keep player visible on EVERY lethal submission before death completes (hidden=%d)" % hidden_before_completion)
	_assert(trap_samples > 0 if require_trap else contact_samples > 0, label + " observes the real lethal contact/handoff callback")
	var summary: Dictionary = {"label": label, "samples": samples.size(), "contact_samples": contact_samples,
		"trap_samples": trap_samples, "hidden_before_completion": hidden_before_completion, "death_completed": completed}
	_case_reports.append(summary)
	print("CONTINUITY CASE ", JSON.stringify(summary))

func _trap_state() -> Dictionary:
	# Existing production Cantor pattern: Lightning conducts from its declared
	# Fire-trap center to the player, exercising the deferred trap-impact route.
	var state: Dictionary = GuardianFixtures.new().guardian_fixture("storm_cantor")
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()):
			state["grid"][y][x] = "wall" if x == 0 or y == 0 or x == state["grid"][y].size()-1 or y == state["grid"].size()-1 else "stone"
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["umbra"]["vision_bonus"] = 12
	state["player"]["pos"] = Vector2i(6, 4)
	state["player"]["hp"] = 1
	state["player"]["block"] = 0
	state["defiance_remaining"] = 0
	state["enemies"][0]["pos"] = Vector2i(2, 4)
	state["enemies"][1]["pos"] = Vector2i(4, 2)
	state["enemies"][2]["pos"] = Vector2i(6, 2)
	for x: int in range(3, 7):
		Ground.place(state, Vector2i(x, 4), "electrified")
	var peal: Dictionary = GameData.enemy_def("storm_cantor")["intents"][1].duplicate(true)
	peal["actions"].pop_front()
	state["enemies"][0]["intent"] = GuardianRules.commit(CombatEngine.new(), state, 0, peal)
	var center: Vector2i = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"][0]
	state["traps"] = [{"id": "continuity_fire", "pos": center, "element": "fire", "damage": 1, "blast_radius": 0}]
	return state
