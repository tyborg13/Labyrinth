extends "res://tools/fel30/descent.gd"
## Use the exact fel-30 route and its old action-boundary keys alongside
## the new caption-placement boundaries.

const Placement = preload("res://scripts/action_caption_placement.gd")
const SCRIM = preload("res://scripts/action_caption_scrim.gd")
const LEGACY_KEYS := ["30005-04-04-enemy_action-07", "30003-03-01-enemy_action-01"]

var _caption_index: int = 0
var _round_zero_index: int = 0
var _action_index: int = 0
var _caption_combat: int = -1
var _caption_seed: int = -1

func start(tree: SceneTree) -> void:
	tree.root.set_meta("fel34_caption", _caption)
	super.start(tree)

func _sample(scene: Node, kind: String, turn: int, _action: Dictionary) -> void:
	_moment += 1
	if kind != "enemy_action":
		return
	var key: String = _moment_key({"seed": _seed, "combat": _combat, "turn": turn, "moment": kind, "enemy_action": _enemy_index})
	if key in LEGACY_KEYS:
		var row: Dictionary = {"key": key, "seed": _seed, "text": scene.action_banner.text, "legacy": true}
		if not _require_caption(scene, row):
			return
		if _native:
			_capture_pair_frame(scene, row)
		else:
			_write(_moment_file, row)

func _caption(scene: Node, geometry: Dictionary, placement: Dictionary, step: Dictionary, placed: bool, round_zero: bool) -> void:
	if _seed != _caption_seed or _combat != _caption_combat:
		_caption_seed = _seed
		_caption_combat = _combat
		_caption_index = 0
		_round_zero_index = 0
		_action_index = 0
	_caption_index += 1
	if round_zero: _round_zero_index += 1
	if placed: _action_index = _caption_index
	_moment += 1
	var key: String = "%d-%02d-caption-%04d" % [_seed, _combat, _caption_index]
	var label: Label = scene.action_banner
	var row: Dictionary = {"key": key, "seed": _seed, "combat": _combat, "text": label.text, "kind": step.get("kind", "player"),
		"trigger": step.get("trigger", ""), "fallback": placement.get("fallback", false),
		"placed": placed, "action": _action_index, "round_zero": _round_zero_index}
	if OS.has_environment("FEL34_TRACE_REVIEW") and _seed == 30003 and _combat == 2 and _round_zero_index >= 32 and _round_zero_index <= 34:
		_trace_review(scene, placement, step, row)
	if _native:
		if not _wanted.has(key): return
		await RenderingServer.frame_post_draw
		if _require_caption(scene, row):
			_capture_pair_frame(scene, row)
		return
	var actual: Rect2 = _stage_rect(label)
	row["actual_rect"] = _rect(actual)
	if geometry.is_empty():
		_write(_moment_file, row)
		return
	var before: Rect2 = geometry["caption"]
	var limits: Vector2 = geometry["limits"]
	row["before_rect"] = _rect(before)
	row["shift"] = actual.position.x - before.position.x
	row["hud_overlap"] = Placement.covers(actual, geometry["hud"])
	row["inside"] = actual.position.x >= limits.x and actual.end.x <= limits.y
	var before_counts: Dictionary = {}
	var after_counts: Dictionary = {}
	var severity: float = 0.0
	for subject: String in geometry["subjects"]:
		before_counts[subject] = 0
		after_counts[subject] = 0
		for target: Rect2 in geometry["subjects"][subject]:
			var covered: float = before.grow(Placement.CLEARANCE).intersection(target).get_area()
			if covered >= 1.0:
				before_counts[subject] += 1
				severity += covered
			if actual.grow(Placement.CLEARANCE).intersection(target).get_area() >= 1.0:
				after_counts[subject] += 1
	row["before"] = before_counts
	row["after"] = after_counts
	row["severity"] = severity
	_write(_moment_file, row)

func _trace_review(scene: Node, placement: Dictionary, step: Dictionary, row: Dictionary) -> void:
	var board: Control = scene.board_view
	var units: Dictionary = board._units_by_key(board._visible_units())
	var stage: Control = scene.stage_root
	var to_stage: Transform2D = stage.get_global_transform_with_canvas().affine_inverse() * board.get_global_transform_with_canvas()
	print("FEL34 TRACE ", row["key"], " ", step.get("actor_key"), " ", placement.get("context"))
	for entry: Dictionary in board._hud_layout_entries_cache:
		var key: String = entry["actor_key"]
		var unit: Dictionary = units.get(key, {})
		var frame: Rect2 = entry.get("health_rect", Rect2())
		if unit.is_empty() or not frame.has_area(): continue
		var plates: Array[Rect2] = board._health_bar_collision_rects(unit, frame)
		var projected: Array[Rect2]
		for rect: Rect2 in plates: projected.append(to_stage * rect)
		print("FEL34 TRACE HUD ", key, " tile=", unit.get("pos"), " opacity=", board._plate_opacity(unit), " plates=", projected)

func _stage_rect(label: Label) -> Rect2:
	return Rect2(label.position, label.size).grow_individual(SCRIM.HORIZONTAL_PADDING, SCRIM.VERTICAL_PADDING, SCRIM.HORIZONTAL_PADDING, SCRIM.VERTICAL_PADDING)

func _require_caption(scene: Node, row: Dictionary) -> bool:
	var label: Label = scene.action_banner
	var expected: String = str(_wanted.get(row["key"], {}).get("text", row["text"]))
	if label.is_visible_in_tree() and not expected.is_empty() and label.text == expected:
		return true
	_fail("FEL34 missing caption at %s: expected %s, saw %s" % [row["key"], expected, label.text])
	_end_override = "capture error"
	return false

func _capture_pair_frame(scene: Node, row: Dictionary) -> void:
	var key: String = row["key"]
	if not _wanted.has(key): return
	var label: Label = scene.action_banner
	var image: Image = _tree.root.get_texture().get_image()
	var filename: String = _output.path_join("%02d-%s.png" % [int(_wanted[key]["rank"]), key])
	if image == null or image.get_size() != SIZE or image.save_png(filename) != OK:
		_fail("FEL34 cannot capture 1920x1080 at " + key)
		_end_override = "capture error"
		return
	var extent: Rect2 = (label.get_parent() as Control).get_global_transform_with_canvas() * _stage_rect(label)
	row["actual_rect"] = _rect(extent)
	row["frame"] = filename
	_write(_moment_file, row)
	_capture[key] = filename
	_wanted.erase(key)
	print(filename)

func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
