extends RefCounted

const Analytics = preload("res://scripts/analytics_store.gd")
const Store = preload("res://scripts/progression_store.gd")
# Session identifiers and time stamps are expected to differ between takes.
# The remainder includes inventory/RNG, commits, analytics payloads and focus.
const VOLATILE := [
	"analytics_run_id", "run_id", "installation_id", "session_id", "event_id",
	"created_at", "updated_at", "timestamp", "ts", "timestamp_ms", "timestamp_utc",
	"run_seconds", "install_id",
	"elapsed_play_usec", "elapsed_play_seconds", "elapsed_playtime_seconds",
]

static var _generated_run_id := RegEx.create_from_string("run_[0-9]+_[0-9a-f]{8}")

static func snapshot(tree: SceneTree, scene: Node) -> Dictionary:
	var focus := tree.root.gui_get_focus_owner()
	return {"run": normalize(scene.get("_run_state")), "checkpoint": normalize(Store.load_saved_run()),
		"profile": normalize(Store.load_data()), "events": normalize(Analytics.load_all_events()),
		"focus": str(scene.get_path_to(focus)) if focus != null and scene.is_ancestor_of(focus) else "",
		"controller_region": scene.get("_controller_region"), "controller_hand_index": scene.get("_controller_hand_index")}

static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key not in VOLATILE: result[key] = normalize(value[key])
		return result
	if value is Array:
		return value.map(normalize)
	if value is String and value.contains("run_"):
		return _generated_run_id.sub(value, "run_FIXTURE", true)
	return value
