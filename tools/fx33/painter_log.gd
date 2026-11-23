extends RefCounted

# Hooks are inserted into staged copies. Gameplay source has no proof hooks.
static var active: bool
static var calls: Dictionary
static var stamp_requests: Array[Dictionary]
static var hop_feedback: Array[Dictionary]

static func record(site: String) -> void:
	if not active: return
	var frames: Dictionary = calls.get_or_add(site, {})
	var frame: int = Engine.get_process_frames()
	frames[frame] = int(frames.get(frame, 0)) + 1

static func submit(board: Control, specs: Array) -> void:
	if not active: return
	for spec: Dictionary in specs:
		stamp_requests.append({"frame": Engine.get_process_frames(), "name": spec["name"],
			"center": str(spec["center"]), "tiles": spec["tiles"].map(str),
			"effect": board.presentation.get("effect", {}).get("kind", ""),
			"burst": board.presentation.get("en01_burst", {}).get("id", -1)})


static func hop(board: Control, losses: Array) -> void:
	if active:
		hop_feedback.append({"engine_frame": Engine.get_process_frames(), "losses": losses.duplicate(true),
			"visible": board.presentation.get("umbra_visible_tiles", []).duplicate()})
