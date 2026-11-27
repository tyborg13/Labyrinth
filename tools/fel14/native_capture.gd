extends RefCounted

const Frame = preload("res://tools/fel14/frame.gd")
const Report = preload("res://tools/fel14/report.gd")
const SIZE := Vector2i(1920, 1080)
const THUMB := Vector2i(320, 180)
const COLUMNS := 6
const ROWS := 5
const STROKE := 3
const LOWER := Color("#5af2ff")
const UPPER := Color("#ffb445")

var targets: Array[Dictionary]
var failure: String
var _destination: String
var _written: Dictionary = {}
var _tiles: Dictionary = {}
var round_shots: Array[Dictionary]
var movie: Dictionary = {}
var movie_frames: int = 0
var _movie_started: bool = false
var _side: String

func prepare(headless: bool, destination: String) -> bool:
	_destination = destination
	var plan_path: String = OS.get_environment("FEL14_ROUND1_PLAN")
	if not plan_path.is_empty():
		var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
		if not plan is Dictionary: return _fail("invalid Round 1 plan")
		_side = OS.get_environment("FEL14_PROOF_SIDE")
		if OS.get_environment("FEL14_MOVIE") == "1":
			movie = plan["movie"]
		else:
			round_shots.assign(plan["stills"])
		return not _destination.is_empty() and _side in ["branch", "release"]
	if headless: return true
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(Report.PATH + "census.json"))
	if not payload is Dictionary or _destination.is_empty():
		return _fail("native replay needs a capture directory and a completed census.json")
	targets.assign(payload["worst"])
	return check_replay(targets)

func check_replay(rows: Array[Dictionary]) -> bool:
	if rows.size() != Report.WORST_COUNT: return _fail("expected 15 ranked overlaps for native replay")
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		if int(row["rank"]) != i + 1 or (row["samples"] as Array).is_empty():
			return _fail("invalid native replay target at rank %d" % (i + 1))
		if not _rect(row["lower"]["rect"]).has_area() or not _rect(row["upper"]["rect"]).has_area():
			return _fail("empty native outline at rank %d" % (i + 1))
	return true

func needs_image(sample: Dictionary, candidate: String) -> bool:
	for shot: Dictionary in round_shots:
		if _same_state(shot, sample) and (candidate.is_empty() or (shot["samples"] as Array).has(candidate)): return true
	for target: Dictionary in targets:
		if not _same_state(target, sample): continue
		if candidate.is_empty() or (target["samples"] as Array).has(candidate): return true
	return false

func record(state: Dictionary, image: Image) -> bool:
	for target: Dictionary in targets:
		if not _same_state(target, state): continue
		var tags: Array = state["samples"]
		if not tags.any(func(tag: String) -> bool: return (target["samples"] as Array).has(tag)): continue
		var rank: int = int(target["rank"])
		if _written.has(rank): continue
		if image == null or image.get_size() != SIZE:
			return _fail("rank %d has no 1920x1080 renderer image" % rank)
		var lower: Dictionary = _match(state["labels"], target["lower"])
		var upper: Dictionary = _match(state["labels"], target["upper"], int(lower.get("order", -1)))
		if lower.is_empty() or upper.is_empty() or int(lower["order"]) >= int(upper["order"]):
			return _fail("rank %d ordered labels differ from the headless replay at %s" % [rank, state["fixture"]])
		if not _rect(lower["rect"]).intersects(_rect(upper["rect"])):
			return _fail("rank %d labels do not overlap in the renderer replay at %s" % [rank, state["fixture"]])
		var raw: Image = image.duplicate()
		raw.convert(Image.FORMAT_RGBA8)
		var outlined: Image = raw.duplicate()
		_outline(outlined, _rect(lower["rect"]), LOWER)
		_outline(outlined, _rect(upper["rect"]), UPPER)
		var base: String = "%02d-%s-%s" % [rank, state["fixture"], state["phase"]]
		if not _save(raw, base + "-raw.png") or not _save(outlined, base + "-outlined.png"): return false
		raw.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		outlined.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		_tiles[rank] = [raw, outlined]
		_written[rank] = true
	return true

func finish() -> bool:
	if _written.size() != targets.size(): return _fail("native replay captured %d/%d ranked overlaps" % [_written.size(), targets.size()])
	var sheet: Image = Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i: int in range(targets.size() * 2):
		var thumb: Image = _tiles[i / 2 + 1][i % 2]
		var margin: int = (SIZE.y - ROWS * THUMB.y) / 2
		sheet.blit_rect(thumb, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % COLUMNS) * THUMB.x, margin + (i / COLUMNS) * THUMB.y))
	return _save(sheet, "contact.png")

static func _same_state(target: Dictionary, state: Dictionary) -> bool:
	if target["fixture"] != state["fixture"] or target["phase"] != state["phase"]: return false
	if target["phase"] != "enemy_turn": return true
	var expected: Dictionary = target["beat"]
	var actual: Dictionary = state["beat"]
	return int(expected["number"]) == int(actual["number"]) and expected["kind"] == actual["kind"] and (
		expected["actor"] == actual["actor"] and expected["action"] == actual["action"])

static func _match(labels: Array, wanted: Dictionary, exclude: int = -1) -> Dictionary:
	var nearest: Dictionary = {}
	var cost: float = INF
	var center: Vector2 = _rect(wanted["rect"]).get_center()
	for row: Dictionary in labels:
		if int(row["order"]) == exclude or row["kind"] != wanted["kind"] or not _same_owner(row["owner"], wanted["owner"]):
			continue
		if row["text"] != wanted["text"] or row["detail"] != wanted["detail"]: continue
		var distance: float = center.distance_squared_to(_rect(row["rect"]).get_center())
		if distance < cost:
			nearest = row
			cost = distance
	return nearest

static func _same_owner(a: Dictionary, b: Dictionary) -> bool:
	if a["id"] != b["id"]: return false
	var tile_a: Array = a["tile"]
	var tile_b: Array = b["tile"]
	if tile_a.size() != tile_b.size(): return false
	return tile_a.is_empty() or (int(tile_a[0]) == int(tile_b[0]) and int(tile_a[1]) == int(tile_b[1]))

static func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

static func _outline(image: Image, rect: Rect2, color: Color) -> void:
	var a := Vector2i(rect.position.floor())
	var b := Vector2i(rect.end.ceil())
	for line: Rect2i in [Rect2i(a, Vector2i(b.x - a.x, STROKE)), Rect2i(Vector2i(a.x, b.y - STROKE), Vector2i(b.x - a.x, STROKE)),
		Rect2i(a, Vector2i(STROKE, b.y - a.y)), Rect2i(Vector2i(b.x - STROKE, a.y), Vector2i(STROKE, b.y - a.y))]:
		image.fill_rect(line.intersection(Rect2i(Vector2i.ZERO, SIZE)), color)

func _save(image: Image, name: String) -> bool:
	var path: String = _destination.path_join(name)
	if image.save_png(path) != OK: return _fail("cannot save " + path)
	print(path)
	return true

func _fail(message: String) -> bool:
	failure = message
	return false

func dry_replay(states: Array[Dictionary], rows: Array[Dictionary]) -> bool:
	var serialized: Variant = JSON.parse_string(JSON.stringify(rows))
	var plan: Array[Dictionary]
	plan.assign(serialized)
	if not check_replay(plan): return false
	for target: Dictionary in plan:
		var state: Dictionary = states[int(target["state_index"])]
		if not _same_state(target, state) or state["samples"] != target["samples"]:
			return _fail("rank %d points to a different sampled state" % int(target["rank"]))
		var lower: Dictionary = _match(state["labels"], target["lower"])
		var upper: Dictionary = _match(state["labels"], target["upper"], int(lower.get("order", -1)))
		if lower.is_empty() or upper.is_empty() or int(lower["order"]) != int(target["lower"]["order"]) or int(upper["order"]) != int(target["upper"]["order"]):
			return _fail("rank %d does not resolve to its ordered pair" % int(target["rank"]))
	return true

func record_round(state: Dictionary, image: Image, headless: bool) -> bool:
	for shot: Dictionary in round_shots:
		if not _same_state(shot, state) or not (state["samples"] as Array).any(func(tag: String) -> bool: return (shot["samples"] as Array).has(tag)): continue
		var name: String = shot["name"]
		if _written.has(name): continue
		if shot.has(_side):
			var wanted: Array = shot[_side]
			var lower: Dictionary = _match(state["labels"], wanted[0])
			var upper: Dictionary = _match(state["labels"], wanted[1], int(lower.get("order", -1)))
			if lower.is_empty() or upper.is_empty() or int(lower["order"]) >= int(upper["order"]):
				return _fail("Round 1 %s %s did not resolve its ordered labels" % [_side, name])
		if not headless:
			if image == null or image.get_size() != SIZE: return _fail("Round 1 %s missing its 1920x1080 frame" % name)
			if not _save(image, name + ".png"): return false
		_written[name] = true
	return true

func record_movie(beat: Dictionary, viewport: SubViewport, headless: bool) -> bool:
	if not _movie_started:
		var target: Dictionary = movie["beat"]
		_movie_started = int(beat.get("number", -1)) == int(target["number"]) and beat.get("kind") == target["kind"] and beat.get("actor") == target["actor"]
	if not _movie_started: return true
	movie_frames += 1
	if headless: return true
	var frame: Image = viewport.get_texture().get_image()
	if frame == null or frame.get_size() != SIZE: return _fail("movie frame is not 1920x1080")
	var path: String = _destination.path_join("frame-%06d.png" % movie_frames)
	if frame.save_png(path) != OK: return _fail("cannot write " + path)
	if movie_frames == 1: print(path)
	return true

func finish_round(headless: bool) -> bool:
	var mode: String = "DRY RUN" if headless else "CAPTURE"
	if not movie.is_empty():
		if movie_frames < 2: return _fail("movie did not reach the rank 7 status-damage beat")
		print("FEL14 ROUND 1 MOVIE %s PASS frames=%d fps=30" % [mode, movie_frames])
		return true
	if _written.size() != round_shots.size():
		return _fail("Round 1 %s replay found %d/%d stills" % [_side, _written.size(), round_shots.size()])
	print("FEL14 ROUND 1 %s PASS side=%s stills=%d" % [mode, _side, _written.size()])
	return true
