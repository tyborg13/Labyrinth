extends RefCounted

const Capture = preload("res://tests/fixtures/static_floor_diff_capture.gd")
const CaptureIO = preload("res://tests/fixtures/static_floor_capture_io.gd")
const Dump = preload("res://tests/fixtures/static_floor_diff_dump.gd")
const ShaderTime = preload("res://tests/fixtures/static_floor_shader_time.gd")
const OUTPUT: String = "user://bug_01_capture_smoke"
const CASE_ID: int = 900
const IMAGE_SIZE := Vector2i(8, 6)
const CHANGED_PIXEL := Vector2i(2, 2)
const PARAMETER_VALUE: float = 0.73
const SHADER_FIXTURE: String = "shader_type canvas_item;\nuniform float retained_value;\nvoid fragment() { COLOR = vec4(sin(TIME) + retained_value); }"

class HeadlessIO:
	extends CaptureIO
	var waits: Array[float]
	var phase: int = 0
	func frame(tree: SceneTree) -> void:
		await tree.process_frame
	func wait_seconds(tree: SceneTree, seconds: float) -> void:
		waits.append(seconds)
		phase += 1
		await tree.process_frame
	func image(view: SubViewport) -> Image:
		var result: Image = Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
		result.fill(Color.BLACK)
		if phase > 0 and view.get_child_count() > 0 and view.get_child(0).get_meta("bug_01_raw_time_probe", false):
			result.set_pixelv(CHANGED_PIXEL, Color.WHITE)
		return result
	func tag() -> String:
		return "headless smoke mock pixels; not native evidence"

static func run(tree: SceneTree, actual: Control, reference: Control, expect: Callable) -> bool:
	expect.call(not reference.has_method("_resolved_board_geometry_inputs"), "Smoke must exercise the older reference API that broke the native dump")
	var io := HeadlessIO.new()
	var dump := Dump.new()
	var written: Dictionary = await Capture.record(tree, dump, actual, reference, io.image(actual.get_viewport()), io.image(reference.get_viewport()), CASE_ID, "headless full capture smoke", io, OUTPUT, false)
	expect.call(written.has("errors") and written.get("errors", ["incomplete capture"]).is_empty(), "End-to-end capture must return a complete result")
	if not written.has("path"): return false
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(written["path"]))
	var expected_geometry: Dictionary = JSON.parse_string(JSON.stringify(Capture.geometry(reference)))
	expect.call(report["metadata"]["original_geometry"] == expected_geometry, "End-to-end capture must read complete reference geometry without current-only methods")
	expect.call(report["images"].size() == 12 and report["comparisons"].size() == 5, "End-to-end capture writes base and TIME evidence images, masks and JSON")
	expect.call(report["comparisons"]["time_raw_0_25s"]["differing_pixel_count"] == 1, "End-to-end capture detects mocked free shader-time motion")
	expect.call(report["comparisons"]["time_pinned_0_25s"]["differing_pixel_count"] == 0, "End-to-end capture distinguishes the pinned comparison")
	expect.call(report["metadata"]["time_independence"]["state_unchanged"], "Temporal capture must preserve complete state and presentation")
	for field: String in ["raw_shaders_unmodified", "raw_shader_audit_unchanged", "raw_actors_unchanged", "pinned_actors_unchanged"]:
		expect.call(report["metadata"]["time_independence"][field], "Temporal control must record unchanged inputs: " + field)
	expect.call(io.waits.size() == 1 and io.waits[0] == Capture.TIME_EVIDENCE_SECONDS, "Temporal capture requests the exact 0.25-second interval")
	for path: String in report["images"].values():
		var crop: Dictionary = report["crop_viewport"]
		expect.call(Image.load_from_file(path).get_size() == Vector2i(int(crop["width"]), int(crop["height"])), "End-to-end capture saves a readable image with the reported crop: " + path)
	var directory: String = OUTPUT.path_join("case_%03d" % CASE_ID)
	for file: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	DirAccess.remove_absolute(OUTPUT.path_join("index.json"))
	DirAccess.remove_absolute(OUTPUT)
	expect.call(not DirAccess.dir_exists_absolute(OUTPUT), "Headless smoke images must never become native proof")
	return shader_checks(expect)

static func shader_checks(expect: Callable) -> bool:
	var node := ColorRect.new()
	var original := Shader.new()
	original.code = SHADER_FIXTURE
	var material := ShaderMaterial.new()
	material.shader = original
	material.set_shader_parameter("retained_value", PARAMETER_VALUE)
	node.material = material
	var unpinned: Dictionary = ShaderTime.inspect_tree(node)
	expect.call(unpinned["materials"][0]["uses_builtin_TIME"] and not unpinned["materials"][0]["pinned"] and material.shader == original, "Raw TIME audit must leave shaders unmodified")
	var audit: Dictionary = ShaderTime.pin_tree(node)
	expect.call(audit["errors"].is_empty() and audit["materials"][0]["pinned"], "Proof TIME pin must audit and replace a real TIME material")
	expect.call(ShaderTime.inspect_tree(node)["materials"][0]["pinned"], "Read-only shader audit must detect an already pinned material")
	expect.call(original.code == SHADER_FIXTURE and material.shader != original, "Proof shader pin must preserve the source resource")
	expect.call(material.shader.code.contains("sin(" + str(ShaderTime.UNIFORM) + ")") and not ShaderTime.uses_builtin_time(material.shader.code), "Proof shader copy must replace TIME with the controllable uniform")
	expect.call(material.get_shader_parameter(ShaderTime.UNIFORM) == ShaderTime.PIN_SECONDS, "Proof shader time must be exactly pinned")
	expect.call(is_equal_approx(float(material.get_shader_parameter("retained_value")), PARAMETER_VALUE), "Proof shader copy must preserve existing material parameters")
	expect.call(not ShaderTime.uses_builtin_time("// TIME\n/* TIME */ float lifetime;"), "Shader audit must ignore comments and longer identifiers")
	expect.call(not ShaderTime.uses_builtin_time('#include "res://TIME.inc"\n'), "Shader audit must ignore TIME inside quoted paths")
	var includes: Dictionary = {}
	var include_errors: Array[String]
	var expanded: String = ShaderTime.expanded_source('#include "res://assets/shaders/combat_art_palette.gdshaderinc"\n', "", includes, include_errors)
	expect.call(include_errors.is_empty() and includes.has("res://assets/shaders/combat_art_palette.gdshaderinc") and expanded.contains("art_finish") and not expanded.contains("#include"), "Shader TIME audit must expand real res:// includes without treating paths as comments")
	node.free()
	return true
