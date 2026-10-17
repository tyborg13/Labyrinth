extends RefCounted

# These runners own a SceneTree, singleton storage paths and, in several cases,
# a dummy-renderer clock. Separate task-runner processes preserve that isolation
# and execute their complete standalone coverage, rather than just pure rules.
const SUITES = [
	"combat_feel_test", # Includes combat_pacing_regression_suite.
	"event_view_test", "event_rules_test", "biome_test", "health_ghost_test",
	"movement_undo_test", "threats_at_rest_test", "encounter_tables_test",
	"run_score_test", "sfx_bank_test", "sfx_sync_bank_test", "sfx_sync_harness", "section_map_v2_test",
	"en01_enemies_test", "en02_enemies_test", "en03_enemies_test",
	"magic_deck_input_test",
	"run_end_recap_tests", "main_menu_resume_test",
	"prepared_other_character_view_test", "retained_character_inventory_equivalence_test",
	"shop_retained_content_test", "static_floor_cache_equivalence_test"
]
const SUITE_TIMEOUT_SECONDS: int = 180
const PROGRAM_BUDGET_SECONDS: int = 900

static func run(expect: Callable, full_suite_started_usec: int) -> void:
	var suites: Array[String]
	suites.assign(SUITES)
	preload("res://tests/helpers/program_sub_suite_batch.gd").run(suites, expect, full_suite_started_usec, SUITE_TIMEOUT_SECONDS, PROGRAM_BUDGET_SECONDS)
	var elapsed: float = float(Time.get_ticks_usec() - full_suite_started_usec) / 1000000.0
	print("FULL SUITE RUNTIME: %.3f seconds (budget 900 seconds)" % elapsed)
	expect.call(elapsed < PROGRAM_BUDGET_SECONDS, "Full suite stays under 15 minutes")
