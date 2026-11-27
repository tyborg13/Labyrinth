extends SceneTree
## Build the generated witnesses once. Both projects receive identical save bytes.

const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Snare = preload("res://tools/snare_inspection.gd")
const DoorWitness = preload("res://tools/fel08/door_witness.gd")
const ObjectiveWitness = preload("res://tools/fel08/objective_witness.gd")
const ORDINARY_SOURCE := "res://tools/fel01/fixtures/02-s0-seed12-0-1_3-t7"


func _initialize() -> void:
	prepare.call_deferred()


func prepare() -> void:
	var destination := OS.get_environment("FEL08_BA_OUTPUT").path_join("fixtures")
	var ordinary: Dictionary = Store._load_run_dictionary(ORDINARY_SOURCE.path_join("run.save"))
	if ordinary.is_empty() or DoorWitness._ordinary_fixture(ordinary).is_empty():
		printerr("FEL08 BA PREPARE FAIL ordinary witness missing")
		quit(1)
		return

	var engine := Run.new()
	var combat := Combat.new()
	var profile: Dictionary = Store.default_data()
	var source: Dictionary = engine.create_new_run(Snare.FIXTURE_SEED, profile)
	var fresh: Dictionary = Snare.pre_battle(engine, combat, source)
	var sealed: Dictionary = Snare.build(engine, combat, source, {"snare_case": "first_seal"})
	sealed["combat_state"]["umbra"]["vision_bonus"] = DoorWitness.VISION_BONUS
	var resumed: Dictionary = sealed.duplicate(true)
	resumed["current_room_layout"]["objective"]["description"] = ObjectiveWitness.LEGACY_DESCRIPTION
	resumed["combat_state"]["objective"]["description"] = ObjectiveWitness.LEGACY_DESCRIPTION
	resumed = engine.set_combat_state(resumed, resumed["combat_state"])

	var states := {"ordinary": ordinary, "sealed-snare": sealed, "resumed-snare": resumed, "pre-battle": fresh}
	for name: String in states:
		var folder := destination.path_join(name)
		if not _write_fixture(folder, states[name], profile):
			printerr("FEL08 BA PREPARE FAIL ", name)
			quit(1)
			return
	print("FEL08 BA PREPARE PASS fixtures=", states.size())
	quit()


func _write_fixture(folder: String, state: Dictionary, profile: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return false
	Store.set_storage_path(folder.path_join("progression.json"))
	Store.set_run_storage_path(folder.path_join("run.save"))
	return Store.save_data(profile) and Store.save_run_state(state)
