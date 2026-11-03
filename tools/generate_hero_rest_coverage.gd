extends SceneTree
## Run only through godot_task_runner.py. No art is generated or modified.
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const Raster = preload("res://tools/hero_rest_coverage_raster.gd")
const Coverage = preload("res://scripts/intent_chip_hero_coverage_resource.gd")
const Shadow = preload("res://scripts/unit_shadow_cache_resource.gd")
const OUTPUT: String = "res://assets/generated/hero_rest_coverage.tres"

func _initialize() -> void:
	var output: String = OUTPUT
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--output": output = args[index + 1]
	var data: Resource = build()
	var error: Error = ResourceSaver.save(data, output)
	if error != OK:
		push_error("HERO REST COVERAGE GENERATION FAILED: " + error_string(error))
		quit(1)
		return
	print("HERO REST COVERAGE GENERATED: %s facings=%d sources=%d" % [output, data.facings.size(), data.source_sha256.size()])
	quit()

static func build() -> Resource:
	var data := Coverage.new()
	data.extraction_signature = Shadow.expected_extraction_signature()
	var paths: Dictionary = {}
	# Hash all rig implementation sources too: pose, skinning or carry changes
	# can alter rest coverage without changing a PNG or layout JSON.
	for file: String in DirAccess.get_files_at("res://scripts/protagonist_cutout"):
		if file.ends_with(".gd"): paths["res://scripts/protagonist_cutout".path_join(file)] = true
	for path: String in ["res://tools/generate_hero_rest_coverage.gd", "res://tools/hero_rest_coverage_raster.gd", "res://scripts/unit_shadow_cache_resource.gd", "res://scripts/asset_loader.gd"]:
		paths[path] = true
	for facing: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.facing = facing
		assert(rig.load_rig(), "Cannot load hero " + facing + " rig")
		rig.apply_gear({})
		rig.apply_pose("rest", 0.0)
		paths[Rig.BASE.path_join(facing + ".json")] = true
		_record_textures(rig, paths)
		var jobs: Array[Dictionary]
		Raster.capture(rig, rig, jobs)
		data.facings[facing] = Raster._build_polygons(jobs)["polygons"]
		assert(data.facings[facing].size() == 1, "Hero rest must have one connected contour: " + facing)
		rig.free()
	var sorted: Array = paths.keys()
	sorted.sort()
	for path: String in sorted:
		var digest: String = FileAccess.get_sha256(path)
		assert(not digest.is_empty(), "Unreadable hero source: " + path)
		data.source_sha256[path] = digest
	return data

static func _record_textures(node: Node, paths: Dictionary) -> void:
	# Include hidden layers too: load_rig read these even if rest hides them.
	if node is Sprite2D or node is Polygon2D:
		var texture: Texture2D = node.get("texture")
		if texture != null:
			paths[texture.get_meta("asset_source_path", texture.resource_path)] = true
	for child: Node in node.get_children(): _record_textures(child, paths)
