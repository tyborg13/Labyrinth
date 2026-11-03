extends RefCounted

# Mirrors gates.py; isolated-probe preload/extends closure, checked in Python.
const RUNTIME_PATHS := [
	"assets/units/hoarfrost_seer_cutout/precision.gd",
	"scripts/asset_loader.gd",
	"scripts/cel_look.gd",
	"scripts/enemy_cutout_facing.gd",
	"scripts/maquette_cutout_runtime/humanoid_anatomy.gd",
	"scripts/maquette_cutout_runtime/humanoid_continuations.gd",
	"scripts/maquette_cutout_runtime/humanoid_elbows.gd",
	"scripts/maquette_cutout_runtime/humanoid_held_follow.gd",
	"scripts/maquette_cutout_runtime/humanoid_joint_caps.gd",
	"scripts/maquette_cutout_runtime/humanoid_gait.gd",
	"scripts/maquette_cutout_runtime/humanoid_motion.gd",
	"scripts/maquette_cutout_runtime/humanoid_presentation.gd",
	"scripts/maquette_cutout_runtime/motion.gd",
	"scripts/maquette_cutout_runtime/pixel_presentation.gd",
	"scripts/maquette_cutout_runtime/renderer.gd",
	"scripts/maquette_cutout_runtime/rig.gd",
	"scripts/maquette_cutout_runtime/stable_paint.gd",
	"scripts/maquette_cutout_runtime/stable_skin.gd",
	"scripts/parallel_runtime.gd",
	"scripts/protagonist_cutout/full_gear_motion.gd",
	"scripts/protagonist_cutout/gear_carry.gd",
	"scripts/protagonist_cutout/gear_layers.gd",
	"scripts/protagonist_cutout/motion.gd",
	"scripts/protagonist_cutout/rig.gd",
	"scripts/protagonist_cutout/rig_data.gd",
	"tests/maquette_cutout/capture_storage.gd",
	"tests/maquette_cutout/native_capture.gd",
	"tests/maquette_cutout/pixel_capture.gd",
	"tests/maquette_cutout/pixel_samples.gd",
	"tests/maquette_cutout/proof_inputs.gd",
	"tests/maquette_cutout/reference_masks.gd",
	"tests/maquette_cutout/render_settings.gd",
	"tests/maquette_cutout/seam_capture.gd",
]
const PRODUCTION_RUNTIME_PATHS := [
	"scripts/run_scene.gd",
	"scripts/combat_board_view.gd",
	"scripts/cutout_context.gd",
	"scripts/actor_presentation.gd",
	"data/enemies.json",
	"scripts/combat_engine.gd",
	"scripts/maquette_cutout_runtime/action.gd",
	"scripts/maquette_cutout_runtime/presentation.gd",
	"scripts/maquette_cutout_runtime/portrait.gd",
]

static func bindings(directory: String) -> Dictionary:
	# motion.gd is authoring provenance only. These probes execute the shared
	# sampler with compiled_motion.json, never the case's motion.gd script.
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
	var result: Dictionary = {"cel_look_mode": preload("res://scripts/cel_look.gd").mode}
	for path: String in paths: result[path] = FileAccess.get_sha256(directory.path_join(path))
	_bind_layout_resources(directory, result)
	for path: String in RUNTIME_PATHS: result["runtime:" + path] = FileAccess.get_sha256("res://" + path)
	return result

static func _bind_layout_resources(directory: String, result: Dictionary) -> void:
	var pending: Array = []
	for path: String in ["layouts/front.json", "layouts/rear.json", "compiled_motion.json"]:
		pending.append(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(path))))
	var base: String = ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/") + "/"
	while not pending.is_empty():
		var value: Variant = pending.pop_back()
		if value is Dictionary:
			pending.append_array(value.values())
		elif value is Array:
			pending.append_array(value)
		elif value is String and not value.begins_with("TODO_DESIGN_"):
			var path: String = value if value.begins_with("res://") or value.is_absolute_path() else directory.path_join(value)
			if FileAccess.file_exists(path):
				var absolute: String = ProjectSettings.globalize_path(path).simplify_path()
				var key: String = absolute.trim_prefix(base) if absolute.begins_with(base) else "resource:" + value
				result[key] = FileAccess.get_sha256(path)

static func production_bindings(base: String) -> Dictionary:
	var paths: Array[String]
	paths.assign(["compiled_motion.json", "front.json", "rear.json", "front/rest.png", "rear/rest.png"])
	for view: String in ["front", "rear"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join(view + ".json")))
		for part: Dictionary in layout["parts"]:
			if not paths.has(str(part["file"])): paths.append(str(part["file"]))
	var result: Dictionary = {"cel_look_mode": preload("res://scripts/cel_look.gd").mode}
	for path: String in paths: result["production:" + path] = FileAccess.get_sha256(base.path_join(path))
	for path: String in PRODUCTION_RUNTIME_PATHS: result["runtime:" + path] = FileAccess.get_sha256("res://" + path)
	# Case runtime extensions include production adapters, not isolated rig inputs.
	var integration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("integration.json")))
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + str(integration["case"]) + "/cutout.json"))
	for path: String in config.get("runtime_paths", []): result["runtime:" + path] = FileAccess.get_sha256("res://" + path)
	return result
