extends SceneTree
## Frame arithmetic and exact pixel proof can be checked without a renderer.

const Capture = preload("res://tools/fel10/strip_capture.gd")
const Store = preload("res://tools/fel10/frame_store.gd")


func _initialize() -> void:
	var native := Rect2(100, 150, 96, 120)
	var fit: Rect2i = Capture.fit_crop(native)
	if not _check(fit.size == Vector2i(480, 360) and Rect2(fit).encloses(native), "default and edge-clamped crop"): return
	var wide := Rect2(800.1, 200, 601.2, 200)
	var expanded: Rect2i = Capture.fit_crop(wide)
	if not _check(expanded.size == Vector2i(604, 453) and Rect2(expanded).encloses(wide), "minimal 4:3 crop"): return
	var kept: PackedInt32Array = Capture.sample_indices(61)
	if not _check(kept.size() == 25 and kept[0] == 0 and kept[24] == 60, "even endpoint sampling"): return
	for i: int in range(1, kept.size()):
		if not _check(kept[i] - kept[i-1] in [2, 3], "even strides"): return
	if not _check(Capture.sample_indices(3) == PackedInt32Array([0, 1, 2]), "short lifetime preserves all frames"): return
	var store := Store.new()
	if not _check(store.open_spool("user://fel10_checks.bin"), store.problem): return
	var before := Image.create_empty(Store.SIZE.x, Store.SIZE.y, false, Image.FORMAT_RGBA8)
	before.fill(Color.BLACK)
	store.keep(0, before)
	var rect := Rect2(300, 300, 100, 40)
	var observation: Dictionary = {"rect": rect, "source": "test rect", "instance": "test"}
	var capture := Capture.new(observation, 1, 1)
	var other: Dictionary = {
		"same_draw": {"test": observation},
		"overlap": {"other": {"rect": Rect2(250, 250, 20, 20)}},
		"distant": {"distant": {"rect": Rect2(1500, 900, 20, 20)}},
	}
	for frame: int in range(1, 5):
		var current: Image = before.duplicate()
		# Larger changes outside the effect rectangle must not win peak scoring.
		if frame == 4: current.fill_rect(Rect2i(210, 210, 80, 60), Color.GREEN)
		else: current.fill_rect(Rect2i(300, 300, 10 * frame, 40), Color.WHITE)
		capture.observe(observation, frame, other, "test_effect")
		store.keep(frame, current)
	capture.observe({}, 5, {}, "test_effect")
	capture.finish(store, false)
	store.close()
	if not _check(capture.verdict() == "yes" and capture.frames.size() == 4, "four active framebuffer samples"): return
	if not _check(capture.peak_index == 2 and is_equal_approx(capture.changed, 1200.0 / 172800.0), "exact peak pixel differential"): return
	if not _check(capture.cooccurring == PackedStringArray(["overlap"]), "co-occurrence excludes aliases and distant draws"): return
	var clipped := Capture.new({"rect": Rect2(-200, 200, 250, 80), "instance": "out", "source": "test"}, 1, 1)
	clipped.observe({"rect": clipped.start_rect}, 1, {}, "out")
	clipped.observe({}, 2, {}, "out")
	clipped.finish(null, true)
	if not _check(clipped.reason.contains("minimum 80%") and clipped.reason.contains("minimum 3"), "coverage and active-frame rejection"): return
	print("FEL10 CAPTURE CHECKS PASS crop lifetime stride spool peak cooccurrence thresholds")
	quit()


func _check(condition: bool, message: String) -> bool:
	if condition: return true
	printerr("FEL10 CAPTURE CHECK FAIL " + message)
	quit(1)
	return false
