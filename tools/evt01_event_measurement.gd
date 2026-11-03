extends SceneTree

# Debug-only matched first-section selection and event transaction oracle.
const Events = preload("res://scripts/event_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Fixture = preload("res://tests/suites/event_view_suite.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const SAMPLE_SEEDS: int = 500
const GOLDEN_SEEDS: Array = [1, 19, 421]
const SAMPLE_ROOM: Vector2i = Vector2i(1, 0)
const OUTPUT_DEFAULT: String = "/private/tmp/labyrinth_codex/evt-01/measurement.json"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = OUTPUT_DEFAULT
	if args.has("--output"): output = args[args.find("--output") + 1]
	var api: Script = Events
	if args.has("--rules"): api = load(args[args.find("--rules") + 1])
	if args.has("--catalog"):
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--catalog") + 1]))
		Data.events().clear()
		Data.events().merge(source["events"])
	var recent: Array = []
	var counts: Dictionary = {}
	for seed_value: int in range(1, SAMPLE_SEEDS + 1):
		var state: Dictionary = {"seed": seed_value, "current_room": SAMPLE_ROOM, "rooms": {Graph.key(SAMPLE_ROOM): {"section_index": 0}}, "seen_events": [], "event_memory": recent.duplicate()}
		var id: String = api.select_event(state)
		counts[id] = int(counts.get(id, 0)) + 1
		recent.append(id)
		if recent.size() > 16: recent.pop_front()
	var most: int = 0
	for count: int in counts.values(): most = maxi(most, count)
	var golden: Dictionary = {}
	var engine := Run.new()
	var template: Dictionary = Fixture.fixture("lost_cartographer", true)
	for seed_value: int in GOLDEN_SEEDS:
		var state: Dictionary = template.duplicate(true)
		state["seed"] = seed_value
		var entries: Dictionary = {}
		for id: String in Data.events():
			Graph.room(state, state["current_room"])["event_id"] = id
			state.erase("event_state")
			state = api.enter_event(state)
			var choices: Dictionary = {}
			for choice: Dictionary in Data.event_def(id)["choices"]:
				var cid: String = str(choice["id"])
				if api.choice_available(state, id, cid):
					var result: Dictionary = api.choose_event(state, cid, engine)
					choices[cid] = result["event_state"]
			entries[id] = choices
		golden[str(seed_value)] = entries
	var report: Dictionary = {"seeds": SAMPLE_SEEDS, "protocol": "one first-section event at (1,0) per seed 1..500; sequential profile history, last 16; sorted weighted selection", "counts": counts, "most_common_count": most, "most_common_share": float(most) / SAMPLE_SEEDS, "golden": golden}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(preload("res://scripts/analytics_store.gd")._sanitize_variant(report), "\t") + "\n")
	print("EVT01 DISTRIBUTION: %d/%d = %.2f%%; %d distinct; output=%s" % [most, SAMPLE_SEEDS, float(most) * 100 / SAMPLE_SEEDS, counts.size(), output])
	quit()
