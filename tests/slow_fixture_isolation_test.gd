extends SceneTree

const Events = preload("res://tests/suites/event_rules_suite.gd")
const Rules = preload("res://scripts/event_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Transition = preload("res://tests/suites/section_transition_suite.gd")
const View = preload("res://tests/suites/event_view_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const MUTATION_SENTINEL: String = "fixture mutation"
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var engine := Run.new()
	Events._clear_event_fixture()
	for legacy: bool in [false, true]:
		for id: String in ["lost_cartographer", "bloodletters_basin", "hanged_knight"]:
			var expected: Dictionary = _fresh_event(engine, id, legacy)
			var first: Dictionary = Events._event_state(engine, id, legacy)
			_expect(first == expected, "Reused event fixture equals fresh production construction: %s/%s" % [id, legacy])
			first["progression"].clear()
			first["rooms"].clear()
			first["map_sections"].clear()
			first["event_state"].clear()
			first["relics"].append(MUTATION_SENTINEL)
			_expect(Events._event_state(engine, id, legacy) == expected, "Nested case mutations cannot leak into the event template: %s/%s" % [id, legacy])
	var other := Run.new()
	Events._event_state(other)
	_expect(is_same(Events._event_fixture_engine, other), "A different engine owns a fresh event template")
	Events._clear_event_fixture()
	_expect(Events._event_fixture_base.is_empty() and Events._event_fixture_engine == null, "Suite teardown releases its event template and engine")
	var template: Dictionary = Run.new().create_new_run(View.FIXTURE_SEED, Store.default_data())
	var pristine: PackedByteArray = var_to_bytes(template)
	for rich: bool in [false, true]:
		for id: String in Data.events():
			var expected: Dictionary = View.fixture(id, rich)
			var first: Dictionary = View.fixture(id, rich, template)
			_expect(first == expected, "Reused fit fixture equals fresh production construction: %s/%s" % [id, rich])
			for key: String in ["progression", "rooms", "event_state", "equipped_equipment"]: first[key].clear()
			first["relics"].append(MUTATION_SENTINEL)
			_expect(View.fixture(id, rich, template) == expected and var_to_bytes(template) == pristine, "Fit cases cannot mutate each other or their original template: %s/%s" % [id, rich])
	Transition.prepare_storage()
	for index: int in range(Graph.ROOM_COUNTS.size()):
		for study: String in Transition.Factory.CASES:
			var expected: Dictionary = Transition._fresh_fixture(index, study)
			var first: Dictionary = Transition.fixture(index, study)
			_expect(first == expected, "Reused transition fixture equals fresh production construction: %d/%s" % [index, study])
			for key: String in ["progression", "rooms", "map_sections", "combat_state", "pending_reward"]: first[key].clear()
			_expect(Transition.fixture(index, study) == expected, "Nested recovery mutations cannot leak into the boss template: %d/%s" % [index, study])
	Transition._fixture_cache.clear()
	for failure: String in failures: push_error(failure)
	print("SLOW FIXTURE ISOLATION: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _fresh_event(engine: RefCounted, id: String, legacy: bool) -> Dictionary:
	var state: Dictionary = engine.create_new_run(Events.TEST_SEED, Store.default_data())
	if legacy: Graph._initialize_revision_3(state)
	for room: Dictionary in state["rooms"].values():
		if str(room.get("type", "")) != "event": continue
		state["current_room"] = room["coord"]
		room["event_id"] = id
		state["mode"] = "event"
		return Rules.enter_event(state)
	return {}

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
