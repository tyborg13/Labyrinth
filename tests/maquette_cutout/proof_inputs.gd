extends RefCounted

const RUNTIME_PATHS := ["scripts/maquette_cutout_runtime/motion.gd", "scripts/maquette_cutout_runtime/rig.gd", "scripts/maquette_cutout_runtime/renderer.gd", "scripts/maquette_cutout_runtime/action.gd", "scripts/maquette_cutout_runtime/presentation.gd", "scripts/maquette_cutout_runtime/portrait.gd", "tests/maquette_cutout/native_capture.gd", "tools/maquette_motion/compiler.py", "scripts/run_scene.gd", "scripts/combat_board_view.gd", "scripts/cutout_context.gd", "scripts/actor_presentation.gd", "data/enemies.json"]

static func bindings(directory: String) -> Dictionary:
	var paths: Array[String]
	paths.assign(["cutout.json", "compiled_motion.json", "director_motion.json", "source/spec.json", "motion.gd", "layouts/front.json", "layouts/rear.json"])
	for view: String in ["front", "rear"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("layouts/" + view + ".json")))
		paths.append("source/" + view + "/processed.png")
		for part: Dictionary in layout["parts"]:
			if not paths.has(str(part["file"])): paths.append(str(part["file"]))
	var result: Dictionary = {}
	for path: String in paths: result[path] = FileAccess.get_sha256(directory.path_join(path))
	for path: String in RUNTIME_PATHS: result["runtime:" + path] = FileAccess.get_sha256("res://" + path)
	return result

static func production_bindings(base: String) -> Dictionary:
	var paths: Array[String]
	paths.assign(["compiled_motion.json", "front.json", "rear.json", "front/rest.png", "rear/rest.png"])
	for view: String in ["front", "rear"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join(view + ".json")))
		for part: Dictionary in layout["parts"]:
			if not paths.has(str(part["file"])): paths.append(str(part["file"]))
	var result: Dictionary = {}
	for path: String in paths: result["production:" + path] = FileAccess.get_sha256(base.path_join(path))
	return result
