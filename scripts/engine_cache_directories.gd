extends RefCounted

## Renderer initialization precedes autoloads. ShaderRD keeps user:// paths,
## so changing that root must preserve the directories it already validated.
## Godot 4.6.1 RenderingDevice uses vulkan/ for its common PSO file; Metal's
## currently disabled binary-archive implementation names metal/ instead.
## See tests/shader_01_proof.md for engine source and persistence limitations.
const CACHE_FOLDERS: Array = ["shader_cache", "vulkan", "metal"]

# No cache files are copied, removed, opened for writing, or overwritten here.
# A denied link or existing real directory gets only missing directories. That
# fallback repairs writes, but cannot share next startup's pre-switch reads.
static func preserve(original_user_dir: String, switched_user_dir: String, create_link: Callable = Callable()) -> Dictionary:
	var source_root: String = original_user_dir.simplify_path().trim_suffix("/")
	var target_root: String = switched_user_dir.simplify_path().trim_suffix("/")
	var report: Dictionary = {"source": source_root, "target": target_root, "folders": {}, "errors": []}
	if source_root == target_root: return report
	var error: Error = DirAccess.make_dir_recursive_absolute(target_root)
	if error != OK:
		report["errors"].append({"path": target_root, "error": error})
		return report
	var target_dir: DirAccess = DirAccess.open(target_root)
	if target_dir == null:
		report["errors"].append({"path": target_root, "error": DirAccess.get_open_error()})
		return report
	for folder: String in CACHE_FOLDERS:
		var source: String = source_root.path_join(folder)
		var target: String = target_root.path_join(folder)
		var row: Dictionary = {"mode": "mirror", "shared": false, "created_directories": 0}
		report["folders"][folder] = row
		# Detect even dangling/foreign links before directory/file existence
		# checks. Never replace them or populate their unknown destinations.
		if target_dir.is_link(folder):
			var link: String = target_dir.read_link(folder)
			if not link.is_absolute_path(): link = target_root.path_join(link)
			row["mode"] = "existing_link"
			if link.simplify_path() != source and not target_dir.is_equivalent(source, target):
				report["errors"].append({"path": target, "error": ERR_ALREADY_EXISTS})
				continue
			# A matching link may be dangling, including on a second launch.
			# Only report sharing after its source is a usable directory.
			error = _ensure_cache_directory(source)
			if error != OK:
				report["errors"].append({"path": source, "error": error})
				continue
			row["mode"] = "linked"
			row["shared"] = true
			continue
		if not DirAccess.dir_exists_absolute(target) and not FileAccess.file_exists(target):
			# Include inactive backend folders so any subsequent backend cache
			# write also has a stable root. Creating an empty folder is harmless.
			error = _ensure_cache_directory(source)
			if error == OK:
				error = create_link.call(source, target) if create_link.is_valid() else target_dir.create_link(source, target)
				if error == OK:
					row["mode"] = "linked"
					row["shared"] = true
					continue
			row["link_error"] = error
		_mirror_directories(source, target, row, report["errors"])
	return report

static func _ensure_cache_directory(path: String) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(path)
	if error != OK: return error
	# make_dir_recursive_absolute can return OK for an existing file.
	return OK if DirAccess.dir_exists_absolute(path) else ERR_CANT_CREATE

static func _mirror_directories(source: String, target: String, row: Dictionary, errors: Array) -> void:
	var target_parent: DirAccess = DirAccess.open(target.get_base_dir())
	if target_parent != null and target_parent.is_link(target.get_file()):
		errors.append({"path": target, "error": ERR_ALREADY_EXISTS})
		return
	if not DirAccess.dir_exists_absolute(target):
		var error: Error = DirAccess.make_dir_absolute(target)
		if error != OK:
			errors.append({"path": target, "error": error})
			return
		row["created_directories"] += 1
	var source_dir: DirAccess = DirAccess.open(source)
	if source_dir == null: return
	source_dir.include_hidden = true
	for directory: String in source_dir.get_directories():
		# Engine-generated shader/group directories are real folders. Preserve
		# unusual user links without following cycles or modifying their target.
		if source_dir.is_link(directory):
			errors.append({"path": source.path_join(directory), "error": ERR_ALREADY_EXISTS})
			continue
		_mirror_directories(source.path_join(directory), target.path_join(directory), row, errors)
