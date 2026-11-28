extends SceneTree
## Focused regression check for raster, alpha union, order, and the fel-25 pairs.

const Coverage = preload("res://tools/fel30/coverage.gd")
const NO_TILE := Vector2i(-1, -1)
var _failures: int


func _initialize() -> void:
	var algorithm := Coverage.new()
	var hole := Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)
	hole.fill(Color.TRANSPARENT)
	hole.fill_rect(Rect2i(0, 0, 4, 10), Color.WHITE)
	var target: Dictionary = _rect("pickup", "item", Rect2(100, 100, 10, 10), 1)
	target["tile"] = Vector2i(1, 1)
	var prop: Dictionary = _rect("prop", "pillar", Rect2(100, 100, 10, 10), 2)
	prop["image"] = hole
	var trace: Array[Dictionary] = [target, prop]
	var result: Dictionary = algorithm.inspect(trace, [Vector2i(1, 1)])
	var flags: Array = result["flags"]
	_expect(flags.size() == 1, "40% pickup threshold")
	if flags.size() == 1:
		_expect(is_equal_approx(float(flags[0]["covered_fraction"]), 0.4), "transparent texture pixels")
		_expect(bool(flags[0]["urgent"]), "reachable pickup priority")
		_expect(str(flags[0]["by"][0]["what"]) == "pillar", "front cause")
	prop["order"] = 0
	trace.assign([prop, target])
	_expect(algorithm.inspect(trace, [])["flags"].is_empty(), "behind target does not cover")
	prop["order"] = 2
	var prop2: Dictionary = prop.duplicate()
	prop2["what"] = "second pillar"
	prop2["order"] = 3
	trace.assign([target, prop, prop2])
	flags = algorithm.inspect(trace, [])["flags"]
	_expect(flags.size() == 1 and is_equal_approx(float(flags[0]["covered_fraction"]), 0.4), "overlapping blocker union")

	var sheet := Image.create_empty(10, 10, false, Image.FORMAT_RF)
	sheet.fill(Color(1, 0, 0, 1))
	var restore: Dictionary = _rect("show_through", "loot", Rect2(100, 100, 10, 10), 3)
	restore.merge({"tile": target["tile"], "restores": "loot", "mask_planes": [sheet],
		"mask_factors": PackedFloat32Array([1, 1]), "mask_grid": Vector4(100, 100, 1, 1),
		"mask_index": 0, "floor_count": 0, "alpha": 0.75}, true)
	trace.assign([target, prop, restore])
	_expect(algorithm.inspect(trace, [])["flags"].is_empty(), "checker show-through reduces foreground coverage")

	var intent: Dictionary = _rect("intent_label", "strike", Rect2(10, 10, 10, 10), 0)
	intent["text"] = "Strike"
	intent["actor"] = "enemy_1"
	var label: Dictionary = _rect("status_chip", "buff", Rect2(15, 10, 10, 10), 1)
	label["text"] = "4"
	label["actor"] = "enemy_2"
	var hud: Dictionary = _rect("hud", "rail", Rect2(10, 10, 2, 10), 2)
	var repeated: Dictionary = _rect("intent_label", "strike", Rect2(40, 40, 10, 10), 3)
	repeated["text"] = intent["text"]
	repeated["actor"] = intent["actor"]
	trace.assign([intent, label, hud, repeated])
	result = algorithm.inspect(trace, [])
	_expect(result["intent_labels"] == 2, "separate occurrences of identical text")
	flags = result["flags"]
	_expect(result["severity"] == 5, "text, unit UI, and HUD clip severity")
	_expect(flags.any(func(flag: Dictionary) -> bool:
		return flag["category"] == "text" and flag["by"][0]["what"] == "4" and flag["by"][0]["is_text"]), "fel-25 foreground text")
	var clip: Dictionary = {}
	for flag: Dictionary in flags:
		if flag["category"] == "clip": clip = flag
	_expect(not clip.is_empty() and is_equal_approx(float(clip["hud_fraction"]), 0.2), "HUD intersection fraction")
	var bar: Dictionary = _rect("health_bar", "health bar", Rect2(40, 20, 50, 10), 0)
	bar["actor"] = "player"
	var bar_text: Dictionary = _rect("health_bar", "health bar", Rect2(60, 20, 20, 10), 1)
	bar_text["actor"] = bar["actor"]
	bar_text["text"] = "20/24"
	var bar_contour: Dictionary = bar_text.duplicate()
	bar_contour["order"] = 2
	trace.assign([bar, bar_text, bar_contour])
	_expect(algorithm.inspect(trace, [])["flags"].is_empty(), "a bar's own text and frame share one subject")

	_expect(_failures == 0, "all focused checks")
	if _failures == 0: print("FEL30 GEOMETRY OK texture alpha, front order, union, checker restoration, thresholds, HUD and intent pairs")
	quit(int(_failures != 0))


func _rect(kind: String, what: String, rect: Rect2, order: int) -> Dictionary:
	return {"kind": kind, "what": what, "tile": NO_TILE, "actor": "", "rect": rect, "bounds": rect,
		"alpha": 1.0, "inverse": Transform2D.IDENTITY, "order": order}


func _expect(requirement: bool, label: String) -> void:
	if requirement: return
	_failures += 1
	push_error("FEL30 geometry: " + label)
