extends RefCounted

const Caches = preload("res://scripts/engine_cache_directories.gd")
const SENTINEL: String = "foreign cache bytes must survive"
const SHADER_GROUP: String = "shader_cache/CanvasShaderRD/group"
const CASES: Array = ["dangling", "nested-source", "nested-destination", "cycle"]

static func run(base: String, links_available: bool, expect: Callable, selected_case: String = "") -> void:
	expect.call(selected_case.is_empty() or selected_case in CASES, "Selected cache link case exists")
	if not links_available:
		print("ENGINE CACHE EDGE LINK CHECK: SKIP (OS denied native links)")
		return
	if selected_case.is_empty() or selected_case == "dangling": _dangling(base, expect)
	if selected_case.is_empty() or selected_case == "nested-source": _nested_source(base, expect)
	if selected_case.is_empty() or selected_case == "nested-destination": _nested_destination(base, expect)
	if selected_case.is_empty() or selected_case == "cycle": _cycle(base, expect)

static func _dangling(base: String, expect: Callable) -> void:
	for folder: String in Caches.CACHE_FOLDERS:
		var root: String = base.path_join("matching-dangling/" + folder)
		var source: String = root.path_join("original")
		var target: String = root.path_join("switched")
		DirAccess.make_dir_recursive_absolute(target)
		var directory: DirAccess = DirAccess.open(target)
		var cache: String = source.path_join(folder)
		expect.call(directory.create_link(cache, folder) == OK, "Matching dangling fixture created: " + folder)
		expect.call(not DirAccess.dir_exists_absolute(cache), "Matching dangling source starts missing: " + folder)
		var report: Dictionary = Caches.preserve(source, target)
		expect.call(report["errors"].is_empty(), "Matching dangling link repair succeeds: " + folder)
		expect.call(DirAccess.dir_exists_absolute(cache), "Matching dangling source is created: " + folder)
		expect.call(report["folders"][folder]["mode"] == "linked" and report["folders"][folder]["shared"], "Repaired matching link reports sharing: " + folder)
		_write(target.path_join(folder + "/writable.cache"), expect)
		expect.call(FileAccess.get_file_as_string(cache.path_join("writable.cache")) == SENTINEL, "Repaired matching link is writable: " + folder)
		expect.call(Caches.preserve(source, target) == report, "Repaired matching link is idempotent: " + folder)

		# A matching link to a file cannot be repaired; never claim it is shared.
		var blocked: String = base.path_join("matching-blocked/" + folder)
		var blocked_source: String = blocked.path_join("original")
		var blocked_target: String = blocked.path_join("switched")
		_write(blocked_source.path_join(folder), expect)
		DirAccess.make_dir_recursive_absolute(blocked_target)
		var blocked_dir: DirAccess = DirAccess.open(blocked_target)
		expect.call(blocked_dir.create_link(blocked_source.path_join(folder), folder) == OK, "Blocked matching fixture created: " + folder)
		var failed: Dictionary = Caches.preserve(blocked_source, blocked_target)
		expect.call(_has_error(failed, blocked_source.path_join(folder)), "Matching source creation failure is reported: " + folder)
		expect.call(not failed["folders"][folder]["shared"] and failed["folders"][folder]["mode"] != "linked", "Unusable matching link never reports success: " + folder)
		expect.call(blocked_dir.is_link(folder) and blocked_dir.read_link(folder) == blocked_source.path_join(folder), "Blocked matching link stays untouched: " + folder)
		expect.call(FileAccess.get_file_as_string(blocked_source.path_join(folder)) == SENTINEL, "Blocked matching source bytes stay untouched: " + folder)

static func _nested_source(base: String, expect: Callable) -> void:
	var root: String = base.path_join("nested-source")
	var source: String = root.path_join("original")
	var target: String = root.path_join("switched")
	var foreign: String = root.path_join("foreign")
	_write(foreign.path_join("must-not-mirror/keep.cache"), expect)
	DirAccess.make_dir_recursive_absolute(source.path_join(SHADER_GROUP))
	var directory: DirAccess = DirAccess.open(source.path_join(SHADER_GROUP))
	expect.call(directory.create_link(foreign, "nested") == OK, "Nested source link fixture created")
	var report: Dictionary = Caches.preserve(source, target, _deny_link)
	expect.call(_has_error(report, source.path_join(SHADER_GROUP + "/nested")), "Nested source link is rejected")
	expect.call(not DirAccess.dir_exists_absolute(target.path_join(SHADER_GROUP + "/nested")), "Nested source link is never mirrored")
	expect.call(directory.is_link("nested") and directory.read_link("nested") == foreign, "Nested source link stays untouched")
	expect.call(FileAccess.get_file_as_string(foreign.path_join("must-not-mirror/keep.cache")) == SENTINEL, "Nested source target bytes stay untouched")

static func _nested_destination(base: String, expect: Callable) -> void:
	var root: String = base.path_join("nested-destination")
	var source: String = root.path_join("original")
	var target: String = root.path_join("switched")
	var foreign: String = root.path_join("foreign")
	_write(foreign.path_join("keep.cache"), expect)
	_write(source.path_join(SHADER_GROUP + "/nested/must-not-create/keep.cache"), expect)
	DirAccess.make_dir_recursive_absolute(target.path_join(SHADER_GROUP))
	var directory: DirAccess = DirAccess.open(target.path_join(SHADER_GROUP))
	expect.call(directory.create_link(foreign, "nested") == OK, "Nested destination link fixture created")
	var report: Dictionary = Caches.preserve(source, target, _deny_link)
	expect.call(_has_error(report, target.path_join(SHADER_GROUP + "/nested")), "Nested destination link is rejected")
	expect.call(not DirAccess.dir_exists_absolute(foreign.path_join("must-not-create")), "Foreign nested destination is never populated")
	expect.call(directory.is_link("nested") and directory.read_link("nested") == foreign, "Nested destination link stays untouched")
	expect.call(DirAccess.get_files_at(foreign).size() == 1 and DirAccess.get_directories_at(foreign).is_empty(), "Foreign nested destination entries stay untouched")
	expect.call(FileAccess.get_file_as_string(foreign.path_join("keep.cache")) == SENTINEL, "Foreign nested destination bytes stay untouched")
	expect.call(FileAccess.get_file_as_string(source.path_join(SHADER_GROUP + "/nested/must-not-create/keep.cache")) == SENTINEL, "Nested destination conflict preserves source bytes")

static func _cycle(base: String, expect: Callable) -> void:
	var root: String = base.path_join("cycle")
	var source: String = root.path_join("original")
	var target: String = root.path_join("switched")
	_write(source.path_join(SHADER_GROUP + "/keep.cache"), expect)
	var directory: DirAccess = DirAccess.open(source.path_join(SHADER_GROUP))
	expect.call(directory.create_link(source.path_join("shader_cache"), "back-to-root") == OK, "Source cycle fixture created")
	var report: Dictionary = Caches.preserve(source, target, _deny_link)
	expect.call(_has_error(report, source.path_join(SHADER_GROUP + "/back-to-root")), "Source cycle is rejected without traversal")
	expect.call(not DirAccess.dir_exists_absolute(target.path_join(SHADER_GROUP + "/back-to-root")), "Source cycle creates no recursive destination")
	expect.call(directory.is_link("back-to-root"), "Source cycle link stays untouched")
	expect.call(FileAccess.get_file_as_string(source.path_join(SHADER_GROUP + "/keep.cache")) == SENTINEL, "Source cycle preserves original bytes")

static func _has_error(report: Dictionary, path: String) -> bool:
	for error: Dictionary in report["errors"]:
		if error["path"] == path and error["error"] != OK: return true
	return false

static func _write(path: String, expect: Callable) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	expect.call(file != null, "Link fixture file created: " + path)
	if file != null: file.store_string(SENTINEL)

static func _deny_link(_source: String, _target: String) -> Error:
	return ERR_UNAUTHORIZED
