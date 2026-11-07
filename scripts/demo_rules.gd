extends RefCounted

const DemoBuild = preload("res://scripts/demo_build.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const CONFIG_PATH: String = "res://data/demo.json"
const LINKS_PROMPT_RUN_KEY: String = "demo_links_prompt_run_id"
static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH)) as Dictionary
	return _config.duplicate(true)

static func last_section_index() -> int:
	return int(config()["last_section_index"])

static func is_demo_clear(_run_state: Dictionary, outcome: String) -> bool:
	return DemoBuild.is_demo() and outcome == "victory"

static func is_past_cutoff(run_state: Dictionary) -> bool:
	return Graph.active_section(run_state) > last_section_index()

static func reached_hearth(run_state: Dictionary) -> bool:
	for room: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
		if str(room.get("type", "")) == "campfire" and bool(room.get("visited", false)) and int(room.get("section_index", 0)) <= last_section_index():
			return true
	return false

static func end_panel_kind(run_state: Dictionary, outcome: String, profile: Dictionary) -> String:
	if not DemoBuild.is_demo():
		return "none"
	if is_demo_clear(run_state, outcome):
		return "full"
	if outcome not in ["defeat", "embrace"] or not reached_hearth(run_state):
		return "none"
	var prompted_run_id: String = str(profile.get(LINKS_PROMPT_RUN_KEY, ""))
	# RunEngine.run_result_id delegates to this exact identity format. Keep this
	# predicate pure: calling the engine would stage a Chronicle snapshot and
	# create a preload cycle through progression and scoring.
	var result_id: String = "run:%d:seed:%d" % [int(run_state.get("run_index", 0)), int(run_state.get("seed", 0))]
	return "links" if prompted_run_id.is_empty() or prompted_run_id == result_id else "none"
