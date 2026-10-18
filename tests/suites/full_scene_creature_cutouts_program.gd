extends "res://tests/run_tests.gd"

## Invocation-only partition; inherited assertion bodies are unchanged.
func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	_initialize_test_storage(true)
	await process_frame
	_suppress_guided_tutorial_for_legacy_live_scene_tests()
	await preload("res://tests/suites/stone_warden_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/crawler_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/acolyte_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/bile_bloomer_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/chainbound_gaoler_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/cinder_droplet_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/cinder_ooze_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/frostglass_lancer_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/grave_surgeon_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/harrier_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/iskaldra_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/lightning_wisp_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/noctyrax_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/tharokh_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/vaeloryx_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/veilbound_acolyte_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/vyraketh_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/zekarion_cutout_suite.gd").run(self, Callable(self, "_assert"))
	print("MAIN DOMAIN ASSERTIONS full_scene_creature_cutouts_program: %d" % _assertion_count)
	print("MAIN DOMAIN RUNTIME full_scene_creature_cutouts_program: %.3f seconds" % [float(Time.get_ticks_usec() - started) / 1000000.0])
	_finish_test_result()
