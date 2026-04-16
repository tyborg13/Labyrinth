extends RefCounted
class_name AnalyticsStore

const SCHEMA_VERSION: int = 1
const DEFAULT_STORAGE_DIR: String = "user://analytics"
const META_FILE_NAME: String = "meta.json"

static var _storage_dir: String = DEFAULT_STORAGE_DIR

var _install_id: String = ""
var _session_id: String = ""
var _sequence: int = 0

static func set_storage_dir(path: String) -> void:
	_storage_dir = path if not path.is_empty() else DEFAULT_STORAGE_DIR

static func storage_dir() -> String:
	return _storage_dir

static func clear_storage() -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(_storage_dir)
	if DirAccess.dir_exists_absolute(absolute_dir):
		_remove_dir_contents_recursive(absolute_dir)
	_ensure_storage_dir()

static func load_all_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var absolute_dir: String = ProjectSettings.globalize_path(_storage_dir)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		return events
	var filenames: Array[String] = []
	var dir: DirAccess = DirAccess.open(absolute_dir)
	if dir == null:
		return events
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if name.get_extension() != "jsonl":
			continue
		filenames.append(name)
	dir.list_dir_end()
	filenames.sort()
	for filename: String in filenames:
		var file: FileAccess = FileAccess.open(absolute_dir.path_join(filename), FileAccess.READ)
		if file == null:
			continue
		while not file.eof_reached():
			var line: String = file.get_line()
			if line.strip_edges().is_empty():
				continue
			var parsed: Variant = JSON.parse_string(line)
			if typeof(parsed) == TYPE_DICTIONARY:
				events.append((parsed as Dictionary).duplicate(true))
	return events

func _init() -> void:
	_install_id = _ensure_installation_id()
	_session_id = _random_id("session")

func write_event(event_type: String, context: Dictionary = {}, payload: Dictionary = {}) -> bool:
	if event_type.is_empty():
		return false
	_sequence += 1
	var record: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"event_id": _random_id("evt"),
		"event_type": event_type,
		"timestamp_utc": _timestamp_utc_iso(),
		"install_id": _install_id,
		"session_id": _session_id,
		"sequence": _sequence,
		"run_id": str(context.get("run_id", "")),
		"combat_id": str(context.get("combat_id", "")),
		"turn": int(context.get("turn", 0)),
		"room_depth": int(context.get("room_depth", 0)),
		"room_element": str(context.get("room_element", "")),
		"player_hp": int(context.get("player_hp", -1)),
		"player_max_hp": int(context.get("player_max_hp", -1)),
		"deck_size": int(context.get("deck_size", 0)),
		"card_id": str(context.get("card_id", "")),
		"card_instance_id": str(context.get("card_instance_id", "")),
		"payload": _sanitize_variant(payload)
	}
	return _append_jsonl(record)

func session_id() -> String:
	return _session_id

static func _append_jsonl(record: Dictionary) -> bool:
	_ensure_storage_dir()
	var file: FileAccess = FileAccess.open(_event_file_path(), FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_event_file_path(), FileAccess.WRITE_READ)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(record))
	return true

static func _event_file_path() -> String:
	return ProjectSettings.globalize_path(_storage_dir).path_join("events-%s.jsonl" % _utc_date_string())

static func _meta_file_path() -> String:
	return ProjectSettings.globalize_path(_storage_dir).path_join(META_FILE_NAME)

static func _ensure_storage_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_storage_dir))

static func _ensure_installation_id() -> String:
	_ensure_storage_dir()
	var meta_path: String = _meta_file_path()
	if FileAccess.file_exists(meta_path):
		var file: FileAccess = FileAccess.open(meta_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var stored_install_id: String = str((parsed as Dictionary).get("install_id", ""))
				if not stored_install_id.is_empty():
					return stored_install_id
	var install_id: String = _random_id("install")
	var write_file: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(JSON.stringify({
			"schema_version": SCHEMA_VERSION,
			"install_id": install_id,
			"created_at_utc": _timestamp_utc_iso()
		}, "\t"))
	return install_id

static func _random_id(prefix: String) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return "%s_%d_%08x" % [prefix, Time.get_ticks_usec(), rng.randi()]

static func _timestamp_utc_iso() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(now.get("year", 1970)),
		int(now.get("month", 1)),
		int(now.get("day", 1)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0))
	]

static func _utc_date_string() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [
		int(now.get("year", 1970)),
		int(now.get("month", 1)),
		int(now.get("day", 1))
	]

static func _sanitize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key_var: Variant in (value as Dictionary).keys():
				result[str(key_var)] = _sanitize_variant((value as Dictionary)[key_var])
			return result
		TYPE_ARRAY:
			var result_array: Array = []
			for item: Variant in value:
				result_array.append(_sanitize_variant(item))
			return result_array
		TYPE_VECTOR2I:
			var vector2i_value: Vector2i = value
			return {"x": vector2i_value.x, "y": vector2i_value.y}
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			return {"x": vector2_value.x, "y": vector2_value.y}
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_NIL:
			return value
		_:
			return str(value)

static func _remove_dir_contents_recursive(absolute_dir: String) -> void:
	var dir: DirAccess = DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_remove_dir_contents_recursive(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
