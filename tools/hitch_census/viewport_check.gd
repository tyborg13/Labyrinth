extends SceneTree
## Pure boundary checks plus a real headless startup snapshot; never native proof.
const Check = preload("res://tools/hitch_census/viewport.gd")
var checks: int = 0
var errors: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		errors += 1
		push_error(label)

func _case(size: Array, scale: float = 1.15) -> Dictionary:
	return Check.validate({"native": true, "root_pixel_size": size, "content_scale": scale})

func _run() -> void:
	_expect(_case([1280, 800])["status"] == "passed", "Deck target passes")
	_expect(_case([2560, 1600])["status"] == "rejected", "Retina 4x pixel load fails")
	_expect(_case([1280, 880])["status"] == "rejected", "+10% is no longer exact")
	_expect(_case([1280, 881])["status"] == "rejected", "Above +10% fails")
	_expect(_case([1280, 720])["status"] == "rejected", "-10% is no longer exact")
	_expect(_case([1280, 719])["status"] == "rejected", "Below -10% fails")
	_expect(_case([2560, 400])["status"] == "rejected", "Equal pixel count with wrong dimensions fails")
	_expect(_case([1280, 800], 1.0)["status"] == "rejected", "Wrong UI scale fails")
	_expect(_case([1280, 800], 1.14999997615814)["status"] == "passed", "Stored float scale passes")
	_expect(_case([1279, 800])["status"] == "rejected", "One pixel too narrow fails")
	_expect(_case([1280, 801])["status"] == "rejected", "One pixel too tall fails")
	_expect(Check.validate({"native": true, "root_pixel_size": null, "content_scale": 1.15})["status"] == "rejected", "Unavailable readback fails closed")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Check.TARGET_SIZE
	root.content_scale_factor = Check.TARGET_UI_SCALE
	var actual: Dictionary = Check.capture(root)
	actual.merge(Check.validate(actual))
	_expect(actual["root_texture_reported_size"] == [982, 614], "Reproduce round-1 getter dimensions without a window server")
	var stretch: Array = actual["canvas_stretch_scale"]
	_expect(is_equal_approx(float(stretch[0]), 1.15 * 1280.0 / 1920.0), "Getter shrink is the canvas stretch factor")
	var exact: Dictionary = {"native": true, "root_pixel_size": [1280, 800], "content_scale": 1.15, "root_texture_reported_size": [982, 614]}
	_expect(Check.validate(exact)["status"] == "passed", "Gate uses backing pixels, not the transformed texture getter")
	_expect(not bool(actual["native"]), "This proof runs headlessly")
	_expect(actual["root_pixel_size"] == null, "Headless pixels remain unknown")
	_expect(actual["status"] == "headless_render_unverified", "Headless does not claim native proof")
	_expect(actual["hidpi_allowed"] == false, "Copy's startup override disables HiDPI")
	print("HITCH VIEWPORT HEADLESS: " + JSON.stringify(actual))
	print("HITCH VIEWPORT CHECK: checks=%d errors=%d" % [checks, errors])
	quit(0 if errors == 0 else 1)
