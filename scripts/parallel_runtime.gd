extends RefCounted
class_name ParallelRuntime

const TASK_ENV: String = "LABYRINTH_TASK_ID"
const USER_DIR_ENV: String = "LABYRINTH_USER_DIR_NAME"
const DEFAULT_PREFIX: String = "Escape the Umbra Parallel"

static var _applied: bool = false
static var _namespace: String = ""

static func apply_from_environment() -> String:
	if _applied:
		return _namespace
	var requested_name: String = OS.get_environment(USER_DIR_ENV).strip_edges()
	var task_id: String = OS.get_environment(TASK_ENV).strip_edges()
	if requested_name.is_empty() and not task_id.is_empty():
		requested_name = "%s %s" % [DEFAULT_PREFIX, _safe_fragment(task_id)]
	if not requested_name.is_empty():
		_namespace = _safe_user_dir_name(requested_name)
		ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
		ProjectSettings.set_setting("application/config/custom_user_dir_name", _namespace)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	_applied = true
	return _namespace

static func current_namespace() -> String:
	return _namespace

static func _safe_user_dir_name(value: String) -> String:
	var result: String = value.strip_edges()
	result = result.replace("/", "-")
	result = result.replace("\\", "-")
	result = result.replace(":", "-")
	result = result.replace("\n", " ")
	result = result.replace("\r", " ")
	while result.find("  ") >= 0:
		result = result.replace("  ", " ")
	return result.substr(0, 120)

static func _safe_fragment(value: String) -> String:
	var result: String = ""
	for index: int in value.length():
		var ch: String = value.substr(index, 1)
		if ch.is_valid_identifier() or ch.is_valid_int() or ch in ["-", "_", "."]:
			result += ch
		else:
			result += "-"
	while result.find("--") >= 0:
		result = result.replace("--", "-")
	result = result.strip_edges()
	return "task" if result.is_empty() else result.substr(0, 80)
