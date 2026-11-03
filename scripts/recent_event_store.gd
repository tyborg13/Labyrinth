extends RefCounted

# Best-effort rotation convenience, deliberately separate from progression,
# run checkpoints, revisions and recovery. Failure only loses this memory.
const DEFAULT_STORAGE_PATH: String = "user://recent_events.json"
const RECENT_EVENTS_LIMIT: int = 16
static var _storage_path: String = DEFAULT_STORAGE_PATH

static func set_storage_path(path: String) -> void:
	_storage_path = path if not path.is_empty() else DEFAULT_STORAGE_PATH

static func load_recent_events() -> Array[String]:
	var empty: Array[String]
	if not FileAccess.file_exists(_storage_path): return empty
	var file := FileAccess.open(_storage_path, FileAccess.READ)
	if file == null: return empty
	var source: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(source) != OK or typeof(parser.data) != TYPE_DICTIONARY: return empty
	var raw: Variant = parser.data.get("recent_events", [])
	if typeof(raw) != TYPE_ARRAY: return empty
	var ids: Array[String]
	for value: Variant in raw:
		if typeof(value) != TYPE_STRING or str(value).is_empty(): return empty
		ids.append(value)
	return ids.slice(maxi(0, ids.size() - RECENT_EVENTS_LIMIT))

static func save_recent_events(ids: Array[String]) -> bool:
	var path: String = ProjectSettings.globalize_path(_storage_path)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"recent_events": ids.slice(maxi(0, ids.size() - RECENT_EVENTS_LIMIT))}) + "\n")
	file.flush()
	var written: bool = file.get_error() == OK
	file.close()
	if not written or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true

static func record_resolution(before: Dictionary, after: Dictionary) -> bool:
	# Call only from the live/console flow after resolution. Rules and previews
	# remain pure. Rejected input, Continue and already resolved pages do nothing.
	if str(before.get("mode", "")) != "event" or str(before.get("event_state", {}).get("page", "choices")) != "choices": return true
	var event: Dictionary = after.get("event_state", {})
	if str(after.get("mode", "")) != "event" or str(event.get("page", "")) != "result": return true
	var id: String = str(event.get("event_id", ""))
	if id.is_empty(): return true
	var ids: Array[String] = load_recent_events()
	ids.append(id)
	return save_recent_events(ids)
