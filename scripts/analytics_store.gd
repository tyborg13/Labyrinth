extends RefCounted
class_name AnalyticsStore

const SCHEMA_VERSION: int = 1
const DEFAULT_STORAGE_DIR: String = "user://analytics"
const META_FILE_NAME: String = "meta.json"

static var _storage_dir: String = DEFAULT_STORAGE_DIR
static var _storage_generation: int = 0

var _install_id: String = ""
var _session_id: String = ""
var _sequence: int = 0
var _known_idempotency_keys: Dictionary = {}
var _known_idempotency_generation: int = -1

static func set_storage_dir(path: String) -> void:
	var next_storage_dir: String = path if not path.is_empty() else DEFAULT_STORAGE_DIR
	if next_storage_dir != _storage_dir:
		_storage_dir = next_storage_dir
		_storage_generation += 1

static func storage_dir() -> String:
	return _storage_dir

static func clear_storage() -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(_storage_dir)
	if DirAccess.dir_exists_absolute(absolute_dir):
		_remove_dir_contents_recursive(absolute_dir)
	_ensure_storage_dir()
	_storage_generation += 1

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
	_reload_known_idempotency_keys()

func write_event(event_type: String, context: Dictionary = {}, payload: Dictionary = {}, idempotency_key: String = "") -> bool:
	if event_type.is_empty():
		return false
	_ensure_known_idempotency_keys_current()
	if not idempotency_key.is_empty() and _known_idempotency_keys.has(idempotency_key):
		return true
	_sequence += 1
	var wrote_event: bool = _append_jsonl(_event_record(event_type, context, payload, idempotency_key))
	if wrote_event and not idempotency_key.is_empty():
		_storage_generation += 1
		_known_idempotency_keys[idempotency_key] = true
		_known_idempotency_generation = _storage_generation
	elif not wrote_event and not idempotency_key.is_empty():
		# A failed append may still have reached disk before FileAccess surfaced the
		# error. Invalidate peer stores and rebuild this cache so an immediate retry
		# remains idempotent.
		_storage_generation += 1
		_reload_known_idempotency_keys()
	return wrote_event

func write_events(events: Array) -> bool:
	if events.is_empty():
		return true
	_ensure_known_idempotency_keys_current()
	var existing_idempotency_keys: Dictionary = _known_idempotency_keys.duplicate(false)
	var records: Array[Dictionary] = []
	var appended_idempotency_keys: Array[String] = []
	for event_var: Variant in events:
		if typeof(event_var) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_var as Dictionary
		var event_type: String = str(event.get("event_type", ""))
		if event_type.is_empty():
			continue
		var idempotency_key: String = str(event.get("idempotency_key", ""))
		if not idempotency_key.is_empty() and existing_idempotency_keys.has(idempotency_key):
			continue
		_sequence += 1
		records.append(_event_record(
			event_type,
			event.get("context", {}) as Dictionary,
			event.get("payload", {}) as Dictionary,
			idempotency_key
		))
		if not idempotency_key.is_empty():
			existing_idempotency_keys[idempotency_key] = true
			appended_idempotency_keys.append(idempotency_key)
	var wrote_events: bool = _append_jsonl_records(records)
	if wrote_events:
		if not appended_idempotency_keys.is_empty():
			_storage_generation += 1
		for idempotency_key: String in appended_idempotency_keys:
			_known_idempotency_keys[idempotency_key] = true
		_known_idempotency_generation = _storage_generation
	elif not appended_idempotency_keys.is_empty():
		_storage_generation += 1
		_reload_known_idempotency_keys()
	return wrote_events

func _ensure_known_idempotency_keys_current() -> void:
	if _known_idempotency_generation != _storage_generation:
		_reload_known_idempotency_keys()

func _reload_known_idempotency_keys() -> void:
	_known_idempotency_keys.clear()
	for existing_event: Dictionary in load_all_events():
		var existing_key: String = str(existing_event.get("idempotency_key", ""))
		if not existing_key.is_empty():
			_known_idempotency_keys[existing_key] = true
	_known_idempotency_generation = _storage_generation

func _event_record(event_type: String, context: Dictionary, payload: Dictionary, idempotency_key: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"event_id": _random_id("evt"),
		"event_type": event_type,
		"idempotency_key": idempotency_key,
		"timestamp_utc": _timestamp_utc_iso(),
		"install_id": _install_id,
		"session_id": _session_id,
		"sequence": _sequence,
		"run_id": str(context.get("run_id", "")),
		"combat_id": str(context.get("combat_id", "")),
		"turn": int(context.get("turn", 0)),
		"initiative_clock": int(context.get("initiative_clock", 0)),
		"current_actor_kind": str(context.get("current_actor_kind", "")),
		"current_actor_key": str(context.get("current_actor_key", "")),
		"room_depth": int(context.get("room_depth", 0)),
		"room_element": str(context.get("room_element", "")),
		"player_hp": int(context.get("player_hp", -1)),
		"player_max_hp": int(context.get("player_max_hp", -1)),
		"progression_level": int(context.get("progression_level", 1)),
		"progression_stats": _sanitize_variant(context.get("progression_stats", {})),
		"progression_skills": _sanitize_variant(context.get("progression_skills", [])),
		"moltshards": int(context.get("moltshards", 0)),
		"deck_size": int(context.get("deck_size", 0)),
		"elemental_intensity": _sanitize_variant(context.get("elemental_intensity", {})),
		"umbra_stage": str(context.get("umbra_stage", "")),
		"umbra_radius": int(context.get("umbra_radius", -1)),
		"visible_enemy_count": int(context.get("visible_enemy_count", -1)),
		"objective_type": str(context.get("objective_type", "")),
		"card_id": str(context.get("card_id", "")),
		"card_instance_id": str(context.get("card_instance_id", "")),
		"payload": _sanitize_variant(payload)
	}

func session_id() -> String:
	return _session_id

static func _append_jsonl(record: Dictionary) -> bool:
	return _append_jsonl_records([record])

static func _append_jsonl_records(records: Array) -> bool:
	if records.is_empty():
		return true
	_ensure_storage_dir()
	var file: FileAccess = FileAccess.open(_event_file_path(), FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_event_file_path(), FileAccess.WRITE_READ)
	if file == null:
		return false
	file.seek_end()
	for record_var: Variant in records:
		if typeof(record_var) == TYPE_DICTIONARY:
			file.store_line(JSON.stringify(record_var as Dictionary))
	file.flush()
	var write_succeeded: bool = file.get_error() == OK
	file.close()
	return write_succeeded

static func _idempotency_key_exists(idempotency_key: String) -> bool:
	for event: Dictionary in load_all_events():
		if str(event.get("idempotency_key", "")) == idempotency_key:
			return true
	return false

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
