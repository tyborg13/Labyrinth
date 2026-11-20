extends RefCounted
## Sample the actual fan during joypad transitions and after it settles. Measure
## each catalog title at the floor without changing live hand geometry.
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Geometry = preload("res://tools/qa107/layout_geometry.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const NORMAL_REST: String = "normal-rest"
const NORMAL_MOTION: String = "normal-motion"
const OVERSIZED: String = "oversized"
const OFFSCREEN: String = "offscreen"
const GROUPS := [NORMAL_REST, NORMAL_MOTION, OVERSIZED, OFFSCREEN]
const GEOMETRY_HEADER: String = "hand_size\tslot\tfocus_slot\tpose\ttransition\tframe\tsliding\tlifting\tvisibility\tat_rest\tcard_width_px\tcard_scale\tfloor_font_px\tlabel_width_px\tlabel_available_px\tfit_width_px"

var _catalog: Dictionary
var _poses: Dictionary
var _widths: Dictionary
var _failures: Array[String]
var _motion_frames: int
var _sliding_frames: int
var _rest_samples: int
var _live_title_checks: int
var _live_ellipses: int

func _init() -> void:
	for id: String in Data.cards():
		_catalog[id] = str(Data.card_def(id).get("name", id))
	for id: String in Data.card_upgrade_ids():
		var definition: Dictionary = Data.upgraded_card_def(id)
		if not definition.is_empty():
			_catalog[id] = str(definition.get("name", id))

func sample(run: Node, transition: String, at_rest: bool) -> void:
	var hand: Array = run.get("_combat_state").get("deck", {}).get("hand", [])
	var fan: Control = run.get("hand_box")
	var sliding: bool = fan.call("is_sliding")
	var fan_lifting: bool = _running(fan.get("_emphasis_tween"))
	var emphasis: int = fan.call("emphasized_index")
	var focus: int = run.get("_controller_hand_index") if run.get("_controller_hand_focused") else -1
	var observed_motion: bool = false
	var cards_seen: int = 0
	for slot: int in range(hand.size()):
		var card: Control = run.call("_hand_card_control", slot)
		if card == null or not card.has_method("_title_nameplate_width") or not card.is_visible_in_tree(): continue
		cards_seen += 1
		var card_lifting: bool = _running(card.get("_pose_tween")) or bool(card.get("_ready_wave_active"))
		var lifting: bool = fan_lifting or card_lifting
		var moving: bool = sliding or lifting
		if not at_rest and not moving: continue
		observed_motion = observed_motion or moving
		var label: Label = card.get_node("Margin/VBox/TopRow/Title")
		var floor_size: int = Typography.scaled_size(label, card.call("_title_min_size"))
		var font: Font = label.get_theme_font("font")
		var style: StyleBox = label.get_theme_stylebox("normal")
		var available: float = maxf(0.0, label.size.x - style.get_minimum_size().x)
		var fit_width: float = card.call("_title_nameplate_width")
		var visibility: String = _line_visibility(label, style, font.get_height(floor_size), available)
		var pose: String = "lifted" if slot == emphasis or card.position.y < 0.0 else "resting"
		var row := {
			"count": hand.size(), "slot": slot + 1, "focus": focus + 1, "pose": pose,
			"transition": transition, "frame": Engine.get_process_frames(), "sliding": sliding,
			"lifting": lifting, "visibility": visibility, "at_rest": not moving,
			"card_width": card.size.x, "scale": card.get_global_transform_with_canvas().get_scale().x,
			"floor_size": floor_size, "label_width": label.size.x, "available": available,
			"fit_width": fit_width, "font": font, "language": label.language,
		}
		_record(row)
		if at_rest and not moving:
			_check_live_title(label, row)
	if at_rest:
		_rest_samples += 1
		if cards_seen != hand.size() or hand.is_empty():
			_failures.append("%s: expected %d live hand cards, found %d" % [transition, hand.size(), cards_seen])
		if observed_motion:
			_failures.append("%s: hand was still moving at the resting checkpoint" % transition)
	elif observed_motion:
		_motion_frames += 1
		if sliding: _sliding_frames += 1

static func _running(tween: Tween) -> bool:
	return tween != null and tween.is_running()

func _check_live_title(label: Label, row: Dictionary) -> void:
	var metrics: Dictionary = Geometry.text_data(label)
	var overflow: bool = float(metrics["width"]) > float(row["available"])
	var mode: TextServer.OverrunBehavior = label.text_overrun_behavior
	_live_title_checks += 1
	if overflow:
		_live_ellipses += 1
		if mode == TextServer.OVERRUN_TRIM_ELLIPSIS and label.get_theme_font_size("font_size") == int(row["floor_size"]):
			return
	elif mode == TextServer.OVERRUN_NO_TRIMMING:
		return
	var pose: String = "%d-card hand, slot %d, focus %d" % [row["count"], row["slot"], row["focus"]]
	_failures.append("%s: unexpected title fit for %s" % [pose, label.text])

static func _line_visibility(label: Label, style: StyleBox, height: float, width: float) -> String:
	if not Geometry.painted(label): return "offscreen"
	var top: float = style.get_margin(SIDE_TOP) + (label.size.y - style.get_minimum_size().y - height) * 0.5
	var band := Rect2(style.get_margin(SIDE_LEFT), top, maxf(1.0, width), height)
	var rect: Rect2 = label.get_global_transform_with_canvas() * band
	var clip: Rect2 = Geometry.ancestor_clip(label, label.get_window(), label.get_viewport_rect())
	if clip.encloses(rect): return "visible"
	return "partial" if clip.intersection(rect).has_area() else "offscreen"

func _record(row: Dictionary) -> void:
	# Keep one live frame per state and slot. For an animation that means the
	# tightest measured width, with the geometry and scale from that same frame.
	var key: Array = [row["count"], row["slot"], row["focus"], row["pose"], row["transition"],
		row["sliding"], row["lifting"], row["visibility"], row["at_rest"], row["floor_size"]]
	if not _poses.has(key) or float(row["available"]) < float(_poses[key]["available"]):
		_poses[key] = row

static func _context(row: Dictionary) -> String:
	if int(row["count"]) > Combat.MAX_HAND_SIZE: return OVERSIZED
	if row["visibility"] == "offscreen": return OFFSCREEN
	return NORMAL_REST if row["at_rest"] else NORMAL_MOTION

static func _geometry_line(row: Dictionary) -> String:
	return "%d\t%d\t%d\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%.2f\t%.4f\t%d\t%.2f\t%.2f\t%.2f" % [
		row["count"], row["slot"], row["focus"], row["pose"], row["transition"], row["frame"],
		row["sliding"], row["lifting"], row["visibility"], row["at_rest"], row["card_width"], row["scale"],
		row["floor_size"], row["label_width"], row["available"], row["fit_width"]
	]

func _title_width(id: String, row: Dictionary) -> float:
	var key: Array = [id, row["font"], row["floor_size"], row["language"]]
	if not _widths.has(key):
		var line := TextLine.new()
		line.add_string(_catalog[id], row["font"], row["floor_size"], row["language"])
		_widths[key] = line.get_line_width()
	return _widths[key]

func finish(output: String) -> Array[String]:
	var geometry := FileAccess.open(output.path_join("card-title-geometry.tsv"), FileAccess.WRITE)
	var all_misses := FileAccess.open(output.path_join("card-title-all-overflows.tsv"), FileAccess.WRITE)
	var tables: Dictionary
	for group: String in GROUPS:
		tables[group] = FileAccess.open(output.path_join("card-title-%s.tsv" % group), FileAccess.WRITE)
		if tables[group] == null: _failures.append("Could not write %s title evidence" % group)
	if geometry == null or all_misses == null:
		_failures.append("Could not write title geometry and overflow evidence")
	if not _failures.is_empty(): return _failures
	if _sliding_frames == 0: _failures.append("Title sweep did not observe a fan slide")
	if _live_ellipses == 0: _failures.append("Title sweep did not observe the live ellipsis fallback")
	var header: String = "id\ttitle\tfull_title_width_px\tcontext\t" + GEOMETRY_HEADER
	geometry.store_line(GEOMETRY_HEADER)
	all_misses.store_line(header)
	for group: String in GROUPS:
		tables[group].store_line(header)
	var counts: Dictionary
	var misses: int = 0
	for id: String in _catalog:
		var sightings: Dictionary
		for row: Dictionary in _poses.values():
			var width: float = _title_width(id, row)
			if width <= float(row["available"]): continue
			var group: String = _context(row)
			var line: String = "%s\t%s\t%.2f\t%s\t%s" % [id, _catalog[id], width, group, _geometry_line(row)]
			if not sightings.has(group): sightings[group] = PackedStringArray()
			sightings[group].append(line)
			all_misses.store_line(line)
			misses += 1
		for group: String in GROUPS:
			if not sightings.has(group): continue
			counts[group] = int(counts.get(group, 0)) + 1
			for line: String in sightings[group]: tables[group].store_line(line)
			break
	for row: Dictionary in _poses.values(): geometry.store_line(_geometry_line(row))
	print("UI38 CARD TITLE SWEEP: entries=%d samples=%d overflow_samples=%d normal_rest=%d transient_only=%d oversized_only=%d offscreen_only=%d failures=%d" % [
		_catalog.size(), _catalog.size() * _poses.size(), misses, counts.get(NORMAL_REST, 0), counts.get(NORMAL_MOTION, 0),
		counts.get(OVERSIZED, 0), counts.get(OFFSCREEN, 0), _failures.size()
	])
	print("UI38 TITLE GEOMETRY: rest_checks=%d moving_frames=%d slide_frames=%d hand_limit=%d" % [
		_rest_samples, _motion_frames, _sliding_frames, Combat.MAX_HAND_SIZE
	])
	print("UI38 LIVE TITLES: rest_checks=%d floor_ellipses=%d" % [_live_title_checks, _live_ellipses])
	return _failures
