extends RefCounted

# Only standalone proof scenes call this helper. Asset shaders stay immutable;
# materials using TIME receive an in-memory shader copy and a fixed uniform.
const UNIFORM: StringName = &"bug_01_proof_shader_seconds"
const PIN_SECONDS: float = 12.0
const ORIGINAL: StringName = &"bug_01_original_shader"
static var _copies: Dictionary = {}

static func pin_tree(root: Node) -> Dictionary:
	return _inspect_tree(root, true)

static func inspect_tree(root: Node) -> Dictionary:
	return _inspect_tree(root, false)

static func _inspect_tree(root: Node, apply_pin: bool) -> Dictionary:
	var materials: Dictionary = {}
	_collect(root, materials)
	var entries: Array[Dictionary]
	var errors: Array[String]
	for material: ShaderMaterial in materials.values():
		var shader: Shader = material.shader
		if shader == null: continue
		var original: Shader = shader.get_meta(ORIGINAL, shader)
		var dependencies: Dictionary = {}
		var source: String = expanded_source(original.code, original.resource_path, dependencies, errors)
		var uses_time: bool = uses_builtin_time(source)
		if uses_time and apply_pin:
			if not _copies.has(original):
				var copy := Shader.new()
				copy.code = proof_source(source)
				copy.set_meta(ORIGINAL, original)
				_copies[original] = copy
			var parameters: Dictionary = {}
			for field: Dictionary in original.get_shader_uniform_list():
				var name: StringName = field["name"]
				parameters[name] = material.get_shader_parameter(name)
			material.shader = _copies[original]
			for name: StringName in parameters:
				if parameters[name] != null: material.set_shader_parameter(name, parameters[name])
			material.set_shader_parameter(UNIFORM, PIN_SECONDS)
		entries.append({"source": original.resource_path, "source_sha256": source.sha256_text(), "includes": dependencies.keys(), "uses_builtin_TIME": uses_time, "pinned": uses_time and material.shader.has_meta(ORIGINAL)})
	return {"mode": "proof-only shader copies with controllable uniform" if apply_pin else "unmodified shader audit", "uniform": str(UNIFORM), "seconds": PIN_SECONDS if apply_pin else null, "materials": entries, "errors": errors}

static func _collect(node: Node, result: Dictionary) -> void:
	if node is CanvasItem and (node as CanvasItem).material is ShaderMaterial:
		var material: ShaderMaterial = (node as CanvasItem).material
		result[material.get_instance_id()] = material
	var treatment: Variant = node.get("_art_treatment")
	if treatment != null:
		for field: String in ["material", "cache_bake_material", "floor_material"]:
			var material: ShaderMaterial = treatment.get(field)
			if material != null: result[material.get_instance_id()] = material
	for child: Node in node.get_children(): _collect(child, result)

static func uses_builtin_time(source: String) -> bool:
	var token := RegEx.create_from_string("\\bTIME\\b")
	return token.search(_without_comments(source, false)) != null

static func proof_source(source: String) -> String:
	source = _without_comments(source)
	var token := RegEx.create_from_string("\\bTIME\\b")
	source = token.sub(source, str(UNIFORM), true)
	var declaration := RegEx.create_from_string("shader_type\\s+\\w+\\s*;")
	var found: RegExMatch = declaration.search(source)
	assert(found != null)
	var prefix: String = "\nuniform float %s = %s;\n" % [str(UNIFORM), str(PIN_SECONDS)]
	return source.insert(found.get_end(), prefix)

static func expanded_source(source: String, path: String, seen: Dictionary, errors: Array[String]) -> String:
	source = _without_comments(source)
	var includes := RegEx.create_from_string("(?m)^\\s*#include\\s+\"([^\"]+)\"")
	var result: String = source
	for include: RegExMatch in includes.search_all(source):
		var target: String = include.get_string(1)
		if not target.begins_with("res://"): target = path.get_base_dir().path_join(target).simplify_path()
		if not FileAccess.file_exists(target):
			errors.append("Missing proof shader include: " + target)
			continue
		if seen.has(target):
			result = result.replace(include.get_string(), "")
			continue
		seen[target] = true
		result = result.replace(include.get_string(), expanded_source(FileAccess.get_file_as_string(target), target, seen, errors))
	return result

static func _without_comments(source: String, keep_strings: bool = true) -> String:
	# Quoted res:// paths are not // comments. Keep include strings intact while
	# expanding sources, but ignore their contents when detecting the TIME token.
	var tokens := RegEx.create_from_string('(?s)"(?:\\\\.|[^"\\\\])*"|/\\*.*?\\*/|//[^\\n]*')
	var found: Array[RegExMatch] = tokens.search_all(source)
	var result: String = source
	for index: int in range(found.size() - 1, -1, -1):
		var item: RegExMatch = found[index]
		if keep_strings and item.get_string().begins_with('"'): continue
		result = result.substr(0, item.get_start()) + " " + result.substr(item.get_end())
	return result
