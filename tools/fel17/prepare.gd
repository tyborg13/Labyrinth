extends "res://tools/fel08/before_after/prepare.gd"
## Stage the same production encounter states for both revisions.

const Warband = preload("res://tools/warband_inspection.gd")
const SNARE_CASE := "first_seal"


func prepare() -> void:
	var destination := OS.get_environment("FEL08_BA_OUTPUT").path_join("fixtures")
	var ordinary: Dictionary = Store._load_run_dictionary(ORDINARY_SOURCE.path_join("run.save"))
	if ordinary.is_empty() or DoorWitness._ordinary_fixture(ordinary).is_empty():
		printerr("FEL17 PREPARE FAIL ordinary exit fixture missing")
		quit(1)
		return
	var engine := Run.new()
	var combat := Combat.new()
	var profile: Dictionary = Store.default_data()
	var snare: Dictionary = Snare.build(engine, combat, engine.create_new_run(Snare.FIXTURE_SEED, profile), {"snare_case": SNARE_CASE})
	snare["combat_state"]["umbra"]["vision_bonus"] = DoorWitness.VISION_BONUS
	snare = engine.set_combat_state(snare, snare["combat_state"])
	var warband: Dictionary = Warband.build(engine, combat, engine.create_new_run(Warband.FIXTURE_SEED, profile), {})
	var states := {"one-exit": ordinary, "two-exits": snare, "warband": warband}
	for name: String in states:
		if not _write_fixture(destination.path_join(name), states[name], profile):
			printerr("FEL17 PREPARE FAIL ", name)
			quit(1)
			return
	print("FEL17 PREPARE PASS fixtures=", states.size())
	quit()
