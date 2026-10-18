extends RefCounted

const RUNTIME_PATHS := ["scripts/maquette_cutout_runtime/motion.gd", "scripts/maquette_cutout_runtime/rig.gd", "scripts/maquette_cutout_runtime/pixel_presentation.gd", "tools/maquette_motion/features.py", "tools/maquette_motion/pixels.py", "tools/maquette_motion/raster.py", "tools/maquette_motion/material_palette.py", "tools/maquette_motion/hidden_material.py", "tools/maquette_motion/material_provenance.py", "tools/maquette_motion/support_seeds.py", "tools/maquette_motion/hidden_support.py", "tools/maquette_motion/socket_edit.py", "tools/maquette_motion/joint_seams.py", "tools/maquette_motion/seam_pose.py", "tools/maquette_motion/seam_builder.py", "tools/maquette_motion/silhouette.py", "tools/maquette_motion/continuity.py", "tools/maquette_motion/bleed.py", "tools/maquette_motion/seam_support.py", "tools/maquette_motion/contract.py", "tools/maquette_motion/continuity_limits.py", "tools/maquette_motion/feature_builder.py", "tests/maquette_cutout/seam_capture.gd", "tests/maquette_cutout/reference_masks.gd", "tests/maquette_cutout/pixel_capture.gd", "tests/maquette_cutout/pixel_samples.gd", "tests/maquette_cutout/proof_inputs.gd", "tools/maquette_cutout_polish.py", "scripts/maquette_cutout_runtime/renderer.gd", "scripts/maquette_cutout_runtime/action.gd", "scripts/maquette_cutout_runtime/presentation.gd", "scripts/maquette_cutout_runtime/portrait.gd", "tests/maquette_cutout/native_capture.gd", "tools/maquette_motion/compiler.py", "scripts/run_scene.gd", "scripts/combat_board_view.gd", "scripts/cutout_context.gd", "scripts/actor_presentation.gd", "data/enemies.json"]

static func bindings(directory: String) -> Dictionary:
	var paths: Array[String]
	paths.assign(["cutout.json", "compiled_motion.json", "director_motion.json", "source/spec.json", "motion.gd", "layouts/front.json", "layouts/rear.json"])
	if FileAccess.file_exists(directory.path_join("seams.json")):
		paths.append("seams.json")
	if FileAccess.file_exists(directory.path_join("seam_parent_decisions.json")):
		paths.append("seam_parent_decisions.json")
	if FileAccess.file_exists(directory.path_join("director_amendments.json")):
		paths.append("director_amendments.json")
	for path: String in ["support_derivation.json", "hidden_fills/index.json", "source/front/processed.json", "source/rear/processed.json"]:
		if FileAccess.file_exists(directory.path_join(path)): paths.append(path)
	for view: String in ["front", "rear"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("layouts/" + view + ".json")))
		paths.append("source/" + view + "/processed.png")
		for part: Dictionary in layout["parts"]:
			if not paths.has(str(part["file"])): paths.append(str(part["file"]))
	if FileAccess.file_exists(directory.path_join("features.json")):
		paths.append("features.json")
		var features: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("features.json")))
		for feature: Dictionary in features["features"]:
			for definition: Dictionary in feature["views"].values():
				var mask: String = str(definition["mask"])
				if not mask.begins_with("TODO_DESIGN_") and not paths.has(mask): paths.append(mask)
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
