extends RefCounted
class_name AnalyticsStore

const SCHEMA_VERSION: int = 1
const DEFAULT_STORAGE_DIR: String = "user://analytics"
const META_FILE_NAME: String = "meta.json"

static var _storage_dir: String = DEFAULT_STORAGE_DIR
static var _storage_generation: int = 0
static var _write_failure_generation: int = 0
static var _writer := preload("res://scripts/ordered_background_writer.gd").new()
static var _writers_by_directory: Dictionary = {}
static var _open_batch: Dictionary = {}
static var _pending_batches: Array[Dictionary]
static var _append_ready_paths: Dictionary = {}
var deferred_writes: bool = false

var _install_id: String = ""
var _session_id: String = ""
var _sequence: int = 0
var _known_idempotency_keys: Dictionary = {}
var _known_idempotency_generation: int = -1

static func set_storage_dir(path: String) -> void:
	flush_pending_events()
	_writers_by_directory[ProjectSettings.globalize_path(_storage_dir).simplify_path()] = _writer
	var next_storage_dir: String = path if not path.is_empty() else DEFAULT_STORAGE_DIR
	if next_storage_dir != _storage_dir:
		_storage_dir = next_storage_dir
		var directory: String = ProjectSettings.globalize_path(_storage_dir).simplify_path()
		if not _writers_by_directory.has(directory):
			_writers_by_directory[directory] = preload("res://scripts/ordered_background_writer.gd").new()
		_writer = _writers_by_directory[directory]
		_storage_generation += 1

static func storage_dir() -> String:
	return _storage_dir

static func clear_storage() -> void:
	if not flush_pending_events(): return
	var absolute_dir: String = ProjectSettings.globalize_path(_storage_dir)
	if DirAccess.dir_exists_absolute(absolute_dir):
		_remove_dir_contents_recursive(absolute_dir)
	_ensure_storage_dir()
	_storage_generation += 1

static func load_all_events() -> Array[Dictionary]:
	flush_pending_events()
	return _read_all_events()

static func _read_all_events() -> Array[Dictionary]:
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
			var parser := JSON.new()
			if parser.parse(line) == OK and parser.data is Dictionary:
				events.append((parser.data as Dictionary).duplicate(true))
	return events

func _init() -> void:
	_install_id = _ensure_installation_id()
	_session_id = _random_id("session")
	flush_pending_events()
	_reload_known_idempotency_keys()

func write_event(event_type: String, context: Dictionary = {}, payload: Dictionary = {}, idempotency_key: String = "") -> bool:
	if event_type.is_empty():
		return false
	_ensure_known_idempotency_keys_current()
	if not idempotency_key.is_empty() and _known_idempotency_keys.has(idempotency_key):
		return true if deferred_writes else flush_pending_events()
	_sequence += 1
	var wrote_event: bool = _append_records([_event_record(event_type, context, payload, idempotency_key)])
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
	var wrote_events: bool = _append_records(records)
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

# Replay-safe outboxes acknowledge only completed appends. These barriers are
# used by their existing deferred protocol and terminal/explicit checkpoints.
func write_event_durable(event_type: String, context: Dictionary = {}, payload: Dictionary = {}, idempotency_key: String = "") -> bool:
	return write_event(event_type, context, payload, idempotency_key) and flush_pending_events()

func write_events_durable(events: Array) -> bool:
	return write_events(events) and flush_pending_events()

func has_idempotency_key(key: String) -> bool:
	_ensure_known_idempotency_keys_current()
	# Receipt owners may acknowledge only completed appends. Queue reservations
	# deduplicate emitters, but must never impersonate a durable receipt.
	for batch: Dictionary in _pending_batches:
		if str(batch["path"]).get_base_dir() != ProjectSettings.globalize_path(_storage_dir): continue
		for record: Dictionary in batch["records"]:
			if str(record.get("idempotency_key", "")) == key: return false
	return _known_idempotency_keys.has(key)

static func write_failure_generation() -> int:
	return _write_failure_generation

func _ensure_known_idempotency_keys_current() -> void:
	if _known_idempotency_generation != _storage_generation:
		_reload_known_idempotency_keys()

func _reload_known_idempotency_keys() -> void:
	_known_idempotency_keys.clear()
	# Refreshing deduplication during an emitter is not a write barrier. In
	# particular, failure invalidation must not force an append on a commit frame.
	for existing_event: Dictionary in _read_all_events():
		var existing_key: String = str(existing_event.get("idempotency_key", ""))
		if not existing_key.is_empty():
			_known_idempotency_keys[existing_key] = true
	# Failed batches still own their reservations. A replay cannot manufacture a
	# second record while the original queued append is waiting to retry.
	for batch: Dictionary in _pending_batches:
		if str(batch["path"]).get_base_dir() != ProjectSettings.globalize_path(_storage_dir): continue
		for record: Dictionary in batch["records"]:
			var key: String = str(record.get("idempotency_key", ""))
			if not key.is_empty(): _known_idempotency_keys[key] = true
	_known_idempotency_generation = _storage_generation

func _event_record(event_type: String, context: Dictionary, payload: Dictionary, idempotency_key: String) -> Dictionary:
	return {
		"balance_revision": preload("res://scripts/game_data.gd").BALANCE_REVISION,
		"balance_transition": _sanitize_variant(context.get("balance_transition", {})),
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
		"room_type": str(context.get("room_type", "")),
		"guardian_id": str(context.get("guardian_id", "")),
		"encounter_id": str(context.get("encounter_id", "")),
		"biome": str(context.get("biome", "")),
		"special_type": str(context.get("special_type", "")),
		"special_variant": str(context.get("special_variant", "")),
		"section_index": int(context.get("section_index", -1)),
		"player_hp": int(context.get("player_hp", -1)),
		"player_max_hp": int(context.get("player_max_hp", -1)),
		"progression_level": int(context.get("progression_level", 1)),
		"progression_stats": _sanitize_variant(context.get("progression_stats", {})),
		"progression_skills": _sanitize_variant(context.get("progression_skills", [])),
		"moltshards": int(context.get("moltshards", 0)),
		"deck_size": int(context.get("deck_size", 0)),
		"rules_version": int(context.get("rules_version", 5)),
		"surface_revision": int(context.get("surface_revision", 0)),
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

func _append_records(records: Array) -> bool:
	if not deferred_writes: return _append_jsonl_records(records)
	if records.is_empty(): return true
	_ensure_storage_dir()
	var path: String = _event_file_path()
	if bool(_open_batch.get("pending", false)) and str(_open_batch["path"]) == path:
		(_open_batch["records"] as Array).append_array(records.duplicate(true))
	else:
		_open_batch = {"pending": true, "path": path, "records": records.duplicate(true)}
		_pending_batches.append(_open_batch)
		_writer.submit(_append_queued_batch.bind(_open_batch))
	return true

static func _append_queued_batch(batch: Dictionary) -> bool:
	var succeeded: bool = _append_jsonl_at(str(batch["path"]), batch["records"])
	if succeeded:
		batch["pending"] = false
		_pending_batches.erase(batch)
	return succeeded

static func poll_pending_events(idle: bool = true) -> void:
	_writer.poll(idle)
	if _writer.take_failure():
		_write_failure_generation += 1
		_storage_generation += 1
		push_error("Failed to append queued analytics events.")

static func flush_pending_events(all_directories: bool = false) -> bool:
	var writers: Array[RefCounted]
	writers.append(_writer)
	if all_directories:
		for writer: RefCounted in _writers_by_directory.values():
			if not writers.has(writer): writers.append(writer)
	var succeeded: bool = true
	for writer: RefCounted in writers:
		if not writer.flush(): succeeded = false
		writer.take_failure()
	if not succeeded:
		_write_failure_generation += 1
		_storage_generation += 1
		push_error("Failed to flush queued analytics events.")
	return succeeded

static func _append_jsonl_records(records: Array) -> bool:
	if not flush_pending_events(): return false
	_ensure_storage_dir()
	return _append_jsonl_at(_event_file_path(), records)

static func _append_jsonl_at(path: String, records: Array) -> bool:
	if records.is_empty():
		return true
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE_READ)
	if file == null:
		return _append_failed(path)
	var recovered: Dictionary = {}
	if not _append_ready_paths.has(path):
		# Preserve every byte, including an interrupted tail, but put the next
		# record on its own line. Complete records from a failed batch are skipped
		# on retry using their original event IDs (even without idempotency keys).
		while file.get_position() < file.get_length():
			var parser := JSON.new()
			if parser.parse(file.get_line()) == OK and parser.data is Dictionary:
				var event: Dictionary = parser.data
				if not str(event.get("event_id", "")).is_empty(): recovered["event:" + str(event["event_id"])] = true
				if not str(event.get("idempotency_key", "")).is_empty(): recovered["key:" + str(event["idempotency_key"])] = true
		if file.get_length() > 0:
			file.seek(file.get_length() - 1)
			if file.get_8() != 10:
				file.seek_end()
				file.store_8(10)
		_append_ready_paths[path] = true
	file.seek_end()
	for record_var: Variant in records:
		if typeof(record_var) == TYPE_DICTIONARY:
			var record: Dictionary = record_var
			if recovered.has("event:" + str(record.get("event_id", ""))) or recovered.has("key:" + str(record.get("idempotency_key", ""))): continue
			file.store_line(JSON.stringify(record))
			if not str(record.get("event_id", "")).is_empty(): recovered["event:" + str(record["event_id"])] = true
			if not str(record.get("idempotency_key", "")).is_empty(): recovered["key:" + str(record["idempotency_key"])] = true
	file.flush()
	var write_succeeded: bool = file.get_error() == OK
	file.close()
	return true if write_succeeded else _append_failed(path)

static func _append_failed(path: String) -> bool:
	_append_ready_paths.erase(path)
	return false

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
