extends RefCounted

# Follow literal script dependencies instead of freezing each cutout fixture's
# transitive preload list. Verification still runs with no loose source tree.
static func add_tree(pack: PCKPacker, path: String, packed: Dictionary) -> Error:
	if packed.has(path):
		return OK
	packed[path] = true
	var result: Error = pack.add_file(path, path)
	if result != OK:
		return result
	var references := RegEx.new()
	references.compile('"([^"\\n]+\\.gd)"')
	for reference: RegExMatch in references.search_all(FileAccess.get_file_as_string(path)):
		var dependency: String = reference.get_string(1)
		if not dependency.begins_with("res://"):
			dependency = path.get_base_dir().path_join(dependency).simplify_path()
		if not dependency.begins_with("res://scripts/"):
			continue
		result = add_tree(pack, dependency, packed)
		if result != OK:
			return result
	return OK
