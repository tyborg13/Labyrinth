extends SceneTree

const Caches = preload("res://scripts/engine_cache_directories.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const LinkCases = preload("res://tests/helpers/engine_cache_link_cases.gd")
const TEST_ROOT: String = "user://engine-cache-directory-tests"
const SENTINEL: String = "existing cache bytes must survive"
var failures: Array[String]
var assertions: int = 0
var _base: String
var _links_available: bool = true

func _initialize() -> void:
	Parallel.apply_from_environment()
	_base = ProjectSettings.globalize_path(TEST_ROOT)
	_links()
	var selected_case: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): selected_case = argument.trim_prefix("--case=")
	if selected_case.is_empty():
		_fallback()
		_conflicts()
	LinkCases.run(_base, _links_available, Callable(self, "_expect"), selected_case)
	for failure: String in failures: push_error(failure)
	print("ENGINE CACHE DIRECTORIES TEST RESULT: %s (%d assertions)" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)

func _links() -> void:
	var source: String = _base.path_join("links/original")
	var target: String = _base.path_join("links/switched")
	_seed(source)
	var report: Dictionary = Caches.preserve(source, target)
	_expect(report["errors"].is_empty(), "Native link creation succeeds")
	for row: Dictionary in report["folders"].values(): _links_available = _links_available and bool(row["shared"])
	if not _links_available:
		print("ENGINE CACHE LINK CHECK: SKIP (OS denied native links; forced mirror fallback is tested separately)")
		return
	var directory: DirAccess = DirAccess.open(target)
	for folder: String in Caches.CACHE_FOLDERS:
		_expect(directory.is_link(folder), "New cache folder links to original: " + folder)
		_expect(directory.is_equivalent(source.path_join(folder), target.path_join(folder)), "Linked cache has the same filesystem identity")
		_write(target.path_join(folder + "/through-link.cache"), SENTINEL)
		_expect(FileAccess.get_file_as_string(source.path_join(folder + "/through-link.cache")) == SENTINEL, "Post-switch writes are visible at next startup")
	var again: Dictionary = Caches.preserve(source, target)
	_expect(again == report, "A second launch preserves all existing links")
	_expect(FileAccess.get_file_as_string(source.path_join("shader_cache/CanvasShaderRD/group/keep.cache")) == SENTINEL, "Original shader bytes were not overwritten")
	# Different namespace links may still identify the same original cache.
	var alias_root: String = _base.path_join("links/alias")
	var alias_report: Dictionary = Caches.preserve(source, alias_root)
	_expect(alias_report["errors"].is_empty() and Caches.preserve(alias_root, target)["errors"].is_empty(), "Equivalent link chains are recognized without replacement")
	_expect(Caches.preserve(source, source)["folders"].is_empty(), "Same user directory is a no-op")

func _fallback() -> void:
	var source: String = _base.path_join("fallback/original")
	var target: String = _base.path_join("fallback/switched")
	_seed(source)
	var report: Dictionary = Caches.preserve(source, target, _deny_link)
	_expect(report["errors"].is_empty(), "Denied symlink permission falls back to directory mirroring")
	for folder: String in Caches.CACHE_FOLDERS:
		_expect(report["folders"][folder]["mode"] == "mirror" and not report["folders"][folder]["shared"], "Fallback explicitly reports separate persistence")
	_expect(DirAccess.dir_exists_absolute(target.path_join("shader_cache/CanvasShaderRD/group")), "Fallback mirrors shader/group directories")
	_expect(not FileAccess.file_exists(target.path_join("shader_cache/CanvasShaderRD/group/keep.cache")), "Fallback never copies binaries")
	_write(target.path_join("shader_cache/CanvasShaderRD/group/keep.cache"), "destination cache bytes")
	DirAccess.make_dir_recursive_absolute(source.path_join("shader_cache/AnotherShaderRD/new-group"))
	var second: Dictionary = Caches.preserve(source, target)
	_expect(second["errors"].is_empty(), "Existing real cache directories remain usable")
	_expect(DirAccess.dir_exists_absolute(target.path_join("shader_cache/AnotherShaderRD/new-group")), "Later launches mirror newly initialized shader groups")
	_expect(FileAccess.get_file_as_string(target.path_join("shader_cache/CanvasShaderRD/group/keep.cache")) == "destination cache bytes", "Existing fallback cache bytes were not overwritten")
	_expect(FileAccess.get_file_as_string(source.path_join("shader_cache/CanvasShaderRD/group/keep.cache")) == SENTINEL, "Mirroring preserves original cache bytes")
	_expect(not DirAccess.open(target).is_link("shader_cache"), "Existing real folder is never replaced by a link")

func _conflicts() -> void:
	var source: String = _base.path_join("conflicts/original")
	var target: String = _base.path_join("conflicts/switched")
	_seed(source)
	_write(target.path_join("shader_cache/CanvasShaderRD"), SENTINEL)
	_write(target.path_join("vulkan"), SENTINEL)
	var foreign: String = _base.path_join("conflicts/foreign")
	DirAccess.make_dir_recursive_absolute(foreign)
	var directory: DirAccess = DirAccess.open(target)
	if _links_available: _expect(directory.create_link(foreign, "metal") == OK, "Foreign-link fixture created")
	var report: Dictionary = Caches.preserve(source, target)
	_expect(report["errors"].size() == (3 if _links_available else 2), "File collisions and foreign links are reported")
	_expect(FileAccess.get_file_as_string(target.path_join("vulkan")) == SENTINEL, "A file occupying a cache root is never overwritten")
	_expect(FileAccess.get_file_as_string(target.path_join("shader_cache/CanvasShaderRD")) == SENTINEL, "A file occupying a shader directory is never overwritten")
	if _links_available: _expect(directory.is_link("metal") and directory.read_link("metal") == foreign, "A foreign link is preserved")
	_expect(DirAccess.get_directories_at(foreign).is_empty() and DirAccess.get_files_at(foreign).is_empty(), "Foreign link destination is never populated")
	if not _links_available: return
	var dangling_root: String = _base.path_join("dangling")
	DirAccess.make_dir_recursive_absolute(dangling_root)
	var dangling: DirAccess = DirAccess.open(dangling_root)
	var missing: String = dangling_root.path_join("absent")
	_expect(dangling.create_link(missing, "shader_cache") == OK, "Dangling-link fixture created")
	Caches.preserve(source, dangling_root)
	_expect(dangling.is_link("shader_cache") and not DirAccess.dir_exists_absolute(missing), "Dangling foreign link and its missing target remain untouched")

func _seed(source: String) -> void:
	_write(source.path_join("shader_cache/CanvasShaderRD/group/keep.cache"), SENTINEL)
	_write(source.path_join("vulkan/pipelines.fixture.cache"), SENTINEL)
	_write(source.path_join("metal/pipelines.fixture.cache"), SENTINEL)

func _write(path: String, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Fixture file created: " + path)
	if file != null: file.store_string(value)

func _deny_link(_source: String, _target: String) -> Error:
	return ERR_UNAUTHORIZED

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition: failures.append(message)
