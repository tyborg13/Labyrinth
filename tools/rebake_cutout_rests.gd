extends SceneTree

## Use the production rig and the asset probes' fixed native region. Validate
## every alpha channel before writing any production rest or layout fingerprint.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const REGISTRY: String = "res://spec/assets/board_pixel_density/registry.json"
const SOURCES: String = "res://spec/assets/board_pixel_density/sources/"
const OUTPUT: String = "user://probes/board_density_rests"
const NATIVE_REGION := Rect2i(128, 128, 255, 255)
var _pending: Array[Dictionary]
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY)) as Dictionary
	if registry.is_empty():
		_fail("Could not read board density registry")
		_finish()
		return
	var only: String = ""
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(arguments.size()):
		if arguments[index] == "--only" and index + 1 < arguments.size():
			only = arguments[index + 1]
	var matched: bool = only.is_empty()
	for entry_var: Variant in registry["entries"]:
		var entry: Dictionary = entry_var as Dictionary
		if entry["kind"] != "rig" or (not only.is_empty() and entry["id"] != only):
			continue
		matched = true
		for facing_var: Variant in entry["rest_paths"]:
			var facing: String = str(facing_var)
			if not _parts_changed(entry, facing):
				continue
			await _stage_rest(entry, facing)
	if not matched:
		_fail("Unknown rig id: " + only)
	if not _errors.is_empty():
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for job: Dictionary in _pending:
		var image: Image = job["image"] as Image
		for path_var: Variant in job["paths"]:
			var path: String = "res://" + str(path_var)
			if image.save_png(path) != OK:
				_fail("Could not save " + path)
				continue
			_update_rest_fingerprint(str(job["layout"]), path)
		var proof: String = OUTPUT.path_join(str(job["id"]) + "_" + str(job["facing"]) + ".png")
		if image.save_png(proof) != OK:
			_fail("Could not save " + proof)
		print("Saved " + ProjectSettings.globalize_path(proof))
	_finish()

func _parts_changed(entry: Dictionary, facing: String) -> bool:
	var changed: bool = false
	for path_var: Variant in entry["paths"]:
		var path: String = str(path_var)
		if path.get_base_dir().get_file() != facing:
			continue
		var source: Image = Image.load_from_file(SOURCES + path)
		var current: Image = Image.load_from_file("res://" + path)
		if source == null or current == null:
			_fail("Missing density source/output: " + path)
			continue
		source.convert(Image.FORMAT_RGBA8)
		current.convert(Image.FORMAT_RGBA8)
		changed = changed or source.get_data() != current.get_data()
	return changed

func _stage_rest(entry: Dictionary, facing: String) -> void:
	var rig_script: Script = load("res://" + str(entry["rig_script"])) as Script
	if rig_script == null:
		_fail("Could not load rig script for " + str(entry["id"]))
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rig: Node2D = rig_script.new() as Node2D
	rig.set("facing", facing)
	if str(entry["dir"]).begins_with("assets/units/guardians/"):
		rig.set("character_id", str(entry["id"]))
	rig.position = Vector2(NATIVE_REGION.position)
	viewport.add_child(rig)
	if not bool(rig.call("load_rig")):
		_fail("Could not load rig: " + str(entry["id"]) + "/" + facing)
		viewport.free()
		return
	rig.call("apply_pose", "rest", 0.0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = viewport.get_texture().get_image().get_region(NATIVE_REGION)
	rendered.convert(Image.FORMAT_RGBA8)
	for path_var: Variant in entry["rest_paths"][facing]:
		var path: String = "res://" + str(path_var)
		var before: Image = Image.load_from_file(path)
		if before == null:
			_fail("Missing shipped rest: " + path)
			continue
		before.convert(Image.FORMAT_RGBA8)
		if not _same_alpha(before, rendered):
			_fail("Rebaked rest alpha differs from shipped rest: " + path)
		var baseline: Image = Image.load_from_file(SOURCES + str(path_var))
		if baseline == null:
			_fail("Missing untouched rest baseline: " + str(path_var))
		elif not _same_alpha(baseline, rendered):
			_fail("Rebaked rest alpha differs from untouched baseline: " + path)
	_pending.append({"id": entry["id"], "facing": facing, "image": rendered,
		"paths": entry["rest_paths"][facing], "layout": "res://" + str(entry["dir"]) + "/" + facing + ".json"})
	viewport.free()

func _same_alpha(before: Image, after: Image) -> bool:
	if before.get_size() != after.get_size():
		return false
	var a: Image = before.duplicate() as Image
	var b: Image = after.duplicate() as Image
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var original: PackedByteArray = a.get_data()
	var rendered: PackedByteArray = b.get_data()
	for index: int in range(3, original.size(), 4):
		if original[index] != rendered[index]:
			return false
	return true

func _update_rest_fingerprint(layout_path: String, rest_path: String) -> void:
	var text: String = FileAccess.get_file_as_string(layout_path)
	var layout: Dictionary = JSON.parse_string(text) as Dictionary
	if not layout.has("rest_source_sha256"):
		return
	var declared: String = str(layout.get("rest_source", ""))
	var resolved: String = declared if declared.begins_with("res://") else layout_path.get_base_dir().path_join(declared)
	if resolved != rest_path:
		return
	var pattern := RegEx.new()
	pattern.compile('("rest_source_sha256"\\s*:\\s*")[a-f0-9]+(")')
	var updated: String = pattern.sub(text, '${1}' + FileAccess.get_sha256(rest_path) + '${2}')
	var file := FileAccess.open(layout_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not update rest fingerprint: " + layout_path)
		return
	file.store_string(updated)
	file.close()

func _fail(message: String) -> void:
	_errors.append(message)

func _finish() -> void:
	for message: String in _errors:
		push_error(message)
	print("BOARD DENSITY REST REBAKE: " + ("PASS" if _errors.is_empty() else "FAIL") + " (%d views)" % _pending.size())
	quit(0 if _errors.is_empty() else 1)
