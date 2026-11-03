extends SceneTree

const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const Live = preload("res://tests/helpers/card_legibility_contexts.gd")
const Settle = preload("res://tests/helpers/card_legibility_settle.gd")
const ViewportProof = preload("res://tests/helpers/card_legibility_viewport.gd")
const Measure = preload("res://tests/helpers/card_summary_fit_measure.gd")
const CAPTURE_CONTEXTS: Array = ["hand_7_hovered", "deck_view"]
const CAPTURE_VARIANTS: Array = ["base", "upgrade:stat:0:range:0"]
const HALL_UPGRADE: String = "upgrade:stat:0:health:0"
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _argument(name: String, fallback: String = "") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback

func _run() -> void:
	var capture: bool = not OS.get_cmdline_user_args().has("--plan-only")
	var phase: String = _argument("--phase", "after")
	var output: String = _argument("--output", "user://card-01-proof")
	_expect(not capture or DisplayServer.get_name() != "headless", "Windowed proof requires the design owner's window server")
	if not failures.is_empty():
		_finish()
		return
	var audit := Audit.new()
	audit.setup(self)
	var live := Live.new()
	await live.setup(self, 1, true)
	var viewport: SubViewport = live.workers[0]["viewport"]
	ViewportProof.verify(self, viewport, _expect)
	var entries: Array = Audit.definitions().filter(func(e: Dictionary) -> bool:
		return (e["id"] == "worldbreak" and e["variant"] == "base") or (e["id"] == "cloudstep_loop" and CAPTURE_VARIANTS.slice(1).has(e["variant"])) or (e["id"] == "hall_of_mirrors" and ["base", HALL_UPGRADE].has(e["variant"]))
	)
	_expect(entries.size() == 4, "Proof contains Worldbreak, upgraded Cloudstep Loop, and base/upgraded Hall of Mirrors")
	DirAccess.make_dir_recursive_absolute(output)
	var records: Array = []
	for context: Dictionary in audit.contexts():
		if not CAPTURE_CONTEXTS.has(context["id"]): continue
		for entry: Dictionary in entries:
			var faces: Array = await live.open(context)
			_expect(faces.size() == 1, "Production context opens: " + context["id"])
			if faces.size() != 1: continue
			live.configure_face(live.workers[0], entry, context)
			var settled: Dictionary = await Settle.wait_for(self, faces)
			_expect(settled["settled"], "Proof settles: " + context["id"])
			var measured: Dictionary = Measure.measure(faces[0], entry["definition"])
			_expect(measured["floor_errors"].is_empty(), "Proof retains text and icon floors")
			_expect(measured["continuation_errors"].is_empty(), "Proof keeps continuation glyphs with their items")
			_expect(float(measured["overflow_y"]) <= Audit.EPSILON, "Proof contains every item's complete vertical bounds")
			if phase == "after":
				_expect(float(measured["margin_px"]) + Audit.EPSILON >= Measure.EDGE_INSET_PX, "Proof observes after margin for " + entry["id"])
			elif entry["id"] != "hall_of_mirrors":
				_expect(float(measured["margin_px"]) < Measure.EDGE_INSET_PX, "Proof observes the original named overflow for " + entry["id"])
			var variant: String = "base" if entry["variant"] == "base" else "upgraded"
			var image_name: String = "%s_%s_%s.png" % [context["id"], entry["id"], variant]
			var record: Dictionary = {"image": image_name, "context": context["id"], "card": entry["id"], "variant": entry["variant"], "measurement": measured, "ancestors": settled["ancestors"], "image_size": null}
			records.append(record)
			if capture:
				await process_frame
				await RenderingServer.frame_post_draw
				var image: Image = viewport.get_texture().get_image()
				_expect(ViewportProof.image_matches(image), "Capture is exactly 1920x1080")
				if ViewportProof.image_matches(image):
					record["image_size"] = [image.get_width(), image.get_height()]
					_expect(image.save_png(output.path_join(image_name)) == OK, "Save " + image_name)
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase": phase, "ui_scale": 1.0, "viewport": [1920, 1080], "widget_sha256": FileAccess.get_sha256("res://scripts/card_widget.gd"), "captures": records}, "\t") + "\n")
	live.cleanup()
	audit.cleanup()
	print(output)
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("CARD SUMMARY PROOF %s: %s (%d failures)" % ["PLAN" if OS.get_cmdline_user_args().has("--plan-only") else "CAPTURE", "PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
