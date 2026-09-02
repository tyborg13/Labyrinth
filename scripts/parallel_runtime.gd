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
		var initial_shader_cache: String = ProjectSettings.globalize_path("user://shader_cache")
		_namespace = _safe_user_dir_name(requested_name)
		ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
		ProjectSettings.set_setting("application/config/custom_user_dir_name", _namespace)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
		# Native rendering initializes built-in shader directories before script
		# startup. Preserve those empty directories after user:// is namespaced;
		# otherwise newly compiled variants fail to save their cache files. Never
		# copy compiled binaries, so isolated cold benchmarks remain cold.
		_mirror_cache_directories(initial_shader_cache, ProjectSettings.globalize_path("user://shader_cache"))
	_applied = true
	return _namespace

static func current_namespace() -> String:
	return _namespace

static func _mirror_cache_directories(source: String, destination: String) -> void:
	if source == destination or not DirAccess.dir_exists_absolute(source):
		return
	DirAccess.make_dir_recursive_absolute(destination)
	for directory: String in DirAccess.get_directories_at(source):
		_mirror_cache_directories(source.path_join(directory), destination.path_join(directory))

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
