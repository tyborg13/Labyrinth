extends SceneTree

# Every authored card, two progression/loadout profiles and nine board/status
# combinations. Query a real seven-card hand; this measures synchronous CPU
# slices, not rendered frame delivery or gameplay animation duration.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const GameData = preload("res://scripts/game_data.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
const Boundary = preload("res://tests/combat_boundary_cpu_benchmark.gd")
const FIXTURES: Array = ["open", "blocked", "dense", "heart", "frozen", "shocked", "immobilized", "surface_ready", "surface_spent"]
const REPETITIONS: int = 3

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var scene := RunScene.new()
	var combat := CombatEngine.new()
	var card_ids: Array = GameData.cards().keys()
	card_ids.sort()
	var profile: Dictionary = ProgressionStore.default_data()
	profile["level"] = 14
	profile["skill_ids"] = Boundary.SKILLS.duplicate()
	var selected_skills: Array[String] = ProgressionStore.selected_skill_ids(profile)
	var results: Dictionary = {}
	var failures: Array[String]
	for fixture: String in FIXTURES:
		for developed: bool in [false, true]:
			var base: Dictionary = Fixture._fixture(combat, fixture)
			if developed:
				base["relics"] = Boundary.RELICS.duplicate()
				base["skill_ids"] = selected_skills.duplicate()
			var cases: Dictionary = {}
			for card_id: String in card_ids:
				var state: Dictionary = base.duplicate(true)
				var hand: Array = Boundary.HAND.duplicate()
				hand[0] = card_id
				Fixture._set_hand(state, hand)
				scene.set("_combat_state", state)
				var before: Dictionary = state.duplicate(true)
				var samples: Array[int]
				var flags: Dictionary
				var display: Dictionary
				# First access loads any card-specific immutable resources outside
				# the repeated slice samples. Cold input remains a separate probe.
				for repeat: int in range(REPETITIONS + 1):
					scene.call("_mark_combat_preview_state_changed")
					var started: int = Time.get_ticks_usec()
					flags = scene.call("_card_playability_for_index", 0)
					display = scene.call("_card_widget_display", card_id, state)
					var elapsed: int = Time.get_ticks_usec() - started
					if repeat > 0: samples.append(elapsed)
				if state != before: failures.append("Mutated input: %s/%s" % [fixture, card_id])
				samples.sort()
				cases[card_id] = {"median_usec": samples[1], "max_usec": samples[2], "samples_usec": samples, "flags": flags, "display_digest": hash(display)}
			results[fixture + ("_developed" if developed else "_plain")] = cases
	scene.free()
	print("CARD QUERY COST MATRIX RESULT: " + JSON.stringify({"workload_id": "all_authored_seven_card_queries_v1", "card_ids": card_ids, "fixtures": FIXTURES, "repetitions": REPETITIONS, "developed_skills": selected_skills, "measurement": "synchronous playability plus display microseconds; not frame time", "cases": results, "semantic_errors": failures}))
	quit(0 if failures.is_empty() else 1)
