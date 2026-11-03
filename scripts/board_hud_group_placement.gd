extends RefCounted

## Director rule: finite candidates, no cascading displacement. Hard boundaries
## and screen UI are never traded for a lower HUD/HUD overlap score.
const MAX_HORIZONTAL: float = 24.0
const HORIZONTAL_STEP: float = 4.0
const ROW_GAP: float = 4.0
# IEEE-754 binary32 epsilon; Rect2 positions are engine float32 vectors.
const FLOAT32_EPSILON: float = 1.1920928955078125e-7
# Internal reuse proof radius; exact placement is solved again at its edge.
const MOTION_CERTIFICATE_RADIUS_PX: float = 4.0
# Feedback 1: screen-space horizontal room and top bar seat.
const BOARD_SIDE_ROOM: float = 160.0
const BOARD_TOP: float = 96.0

# Compatibility for focused callers without a live board constraint.
static func offset_for(pieces: Array[Rect2], obstacles: Array[Rect2]) -> Vector2:
	var reserved: Array[Rect2]
	return choose(pieces, obstacles, Rect2(), reserved, pieces[0].size.y if not pieces.is_empty() else 0.0)["offset"]

static func candidates(bar_height: float) -> Array[Vector2]:
	var result: Array[Vector2]
	for y: float in [0.0, -(bar_height + ROW_GAP), bar_height + ROW_GAP]:
		result.append(Vector2(0.0, y))
		for direction: float in [1.0, -1.0]:
			for step: int in range(1, int(MAX_HORIZONTAL / HORIZONTAL_STEP) + 1):
				result.append(Vector2(direction * step * HORIZONTAL_STEP, y))
	return result

# Build the local obstacle set once, then reduce every rectangle pair to a
# forbidden translation interval. Candidate tests allocate no shifted Rect2s.
# Each row keeps only pairs that can intersect that row, so both cold and warm
# solves have the same small, finite cost; there is no all-motion envelope.
static func near_obstacles(pieces: Array[Rect2], obstacles: Array[Rect2], height: float) -> Array[Rect2]:
	var reach: Rect2 = pieces_bounds(pieces).grow_individual(MAX_HORIZONTAL, height + ROW_GAP, MAX_HORIZONTAL, height + ROW_GAP)
	var result: Array[Rect2]
	for obstacle: Rect2 in obstacles:
		if reach.intersects(obstacle, false): result.append(obstacle)
	return result

static func pieces_bounds(pieces: Array[Rect2]) -> Rect2:
	var bounds := Rect2()
	for piece: Rect2 in pieces: bounds = piece if not bounds.has_area() else bounds.merge(piece)
	return bounds

static func choose(pieces: Array[Rect2], obstacles: Array[Rect2], bounds: Rect2, reserved: Array[Rect2], bar_height: float, prefiltered: bool = false, clear_only: bool = false) -> Dictionary:
	var near: Array[Rect2] = obstacles if prefiltered else near_obstacles(pieces, obstacles, bar_height)
	# The anchored spot is always allowed. Most actors need no search at all.
	if overlap_area(pieces, Vector2.ZERO, near, 1.0) == 0.0:
		return {"offset": Vector2.ZERO, "overlap_area": 0.0, "legal": true}
	var points: Array[Vector2] = candidates(bar_height)
	var columns: int = points.size() / 3
	var group_bounds: Rect2 = pieces_bounds(pieces)
	var ui_pairs: Array[Rect2]
	for piece: Rect2 in pieces:
		for rect: Rect2 in reserved: ui_pairs.append(Rect2(rect.position - piece.end, rect.size + piece.size))
	var rows: Array = [[], [], []]
	for piece: Rect2 in pieces:
		for obstacle: Rect2 in near:
			var left: float = obstacle.position.x - piece.end.x
			var right: float = obstacle.end.x - piece.position.x
			if left >= MAX_HORIZONTAL or right <= -MAX_HORIZONTAL: continue
			var top: float = obstacle.position.y - piece.end.y
			var bottom: float = obstacle.end.y - piece.position.y
			for row: int in range(3):
				var y: float = points[row * columns].y
				var overlap_y: float = minf(minf(y - top, bottom - y), minf(piece.size.y, obstacle.size.y))
				if overlap_y > 0.0: rows[row].append(Vector4(left, right, minf(piece.size.x, obstacle.size.x), overlap_y))
	var best: Dictionary = {}
	for index: int in range(points.size()):
		var offset: Vector2 = points[index]
		if offset != Vector2.ZERO:
			if bounds.has_area() and not bounds.encloses(Rect2(group_bounds.position + offset, group_bounds.size)): continue
			var blocked: bool = false
			for rect: Rect2 in ui_pairs:
				if offset.x > rect.position.x and offset.x < rect.end.x and offset.y > rect.position.y and offset.y < rect.end.y:
					blocked = true
					break
			if blocked: continue
		var area: float = 0.0
		for pair: Vector4 in rows[index / columns]:
			var width: float = minf(minf(offset.x - pair.x, pair.y - offset.x), pair.z)
			if width <= 0.0: continue
			if clear_only:
				area = 1.0
				break
			area += Vector2(width * pair.w, 0.0).x
			if not best.is_empty() and area >= float(best["overlap_area"]): break
		if best.is_empty() or area < float(best["overlap_area"]): best = {"offset": offset, "overlap_area": area, "legal": true}
		if area == 0.0: return best
	return best

static func allowed(pieces: Array[Rect2], offset: Vector2, bounds: Rect2, reserved: Array[Rect2]) -> bool:
	# The director explicitly permits the owner's anchored spot, including when
	# the authored group extends beyond the board rectangle or reserved UI.
	if offset == Vector2.ZERO: return true
	for piece: Rect2 in pieces:
		var shifted := Rect2(piece.position + offset, piece.size)
		if bounds.has_area() and not bounds.encloses(shifted): return false
		for rect: Rect2 in reserved:
			if shifted.intersects(rect, false): return false
	return true

static func overlap_area(pieces: Array[Rect2], offset: Vector2, obstacles: Array[Rect2], ceiling: float = INF) -> float:
	var area: float = 0.0
	for piece: Rect2 in pieces:
		var shifted := Rect2(piece.position + offset, piece.size)
		for obstacle: Rect2 in obstacles:
			if shifted.intersects(obstacle, false):
				area += shifted.intersection(obstacle).get_area()
				if area >= ceiling: return area
	return area

static func board_bounds(view: Control, units: Array[Dictionary]) -> Rect2:
	view._ensure_board_layout_cache()
	var bounds := Rect2()
	var started: bool = false
	for polygon: PackedVector2Array in view._board_layout_cache_tile_polygons.values():
		for point: Vector2 in polygon:
			if not started:
				bounds = Rect2(point, Vector2.ZERO)
				started = true
			else: bounds = bounds.expand(point)
	if not started: return Rect2()
	var scale: float = view.get_window().content_scale_factor if view.is_inside_tree() else 1.0
	var inverse: Transform2D = view.get_global_transform_with_canvas().affine_inverse()
	var top: float = (inverse * Vector2(0.0, BOARD_TOP * scale)).y
	var side: float = BOARD_SIDE_ROOM / view.get_global_transform_with_canvas().get_scale().x
	return Rect2(Vector2(bounds.position.x - side, top), Vector2(bounds.size.x + side * 2.0, bounds.end.y - top))

static func screen_reservations(view: Control) -> Array[Rect2]:
	var result: Array[Rect2]
	var inverse: Transform2D = view.get_global_transform_with_canvas().affine_inverse()
	for rect: Rect2 in view.presentation.get("hud_obstacle_global_rects", []): result.append(inverse * rect)
	var boss: Rect2 = view.presentation.get("boss_health_frame_global_rect", Rect2())
	if boss.has_area(): result.append(inverse * boss)
	# The existing presentation only supplies the hand in boss rooms. Read the
	# live owning scene's controls for ordinary combat too, without changing its
	# framing/obstacle contract used by expanded intents.
	var scene: Node = view.get_parent()
	while scene != null and not scene.has_method("_hand_visual_top"): scene = scene.get_parent()
	if scene == null: return result
	for field: String in ["hand_box", "_battlefield_rule_hud", "_combat_objective_hud", "_turn_order_panel"]:
		var control: Control = scene.get(field) as Control
		if control == null or not control.is_visible_in_tree(): continue
		var rect: Rect2 = control.get_global_rect()
		if field == "hand_box":
			rect.position.y = scene.call("_hand_visual_top")
			rect.size.y = view.get_viewport_rect().end.y - rect.position.y
		if rect.has_area(): result.append(inverse * rect)
	var pass_chip: Control = scene.get_node_or_null("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar/PassPreviewChip") as Control
	var overlay: Control = scene.get("_pass_preview_overlay") as Control
	if overlay != null: pass_chip = overlay.get_node_or_null("PassPreviewChip") as Control
	if pass_chip != null and pass_chip.is_visible_in_tree(): result.append(inverse * pass_chip.get_global_rect())
	return result

static func translate_entries(entries: Array[Dictionary], offset: Vector2) -> void:
	if offset == Vector2.ZERO: return
	for entry: Dictionary in entries:
		var rect: Rect2 = entry["rect"]
		entry["rect"] = Rect2(rect.position + offset, rect.size)

static func translate_rects(rects: Array[Rect2], offset: Vector2) -> Array[Rect2]:
	var result: Array[Rect2]
	for rect: Rect2 in rects: result.append(Rect2(rect.position + offset, rect.size))
	return result

# Reuse a bounded solution only inside a geometric certificate. Normal pills
# need one blocking witness per earlier candidate. Compact fallback uses exact
# current scores plus global overlap slope bounds; tied curves are compared by
# their rectangle-edge events. Building this certificate is a single local pass,
# not a sweep over every possible future position.
static func choose_incremental(pieces: Array[Rect2], obstacles: Array[Rect2], bounds: Rect2, reserved: Array[Rect2], height: float, memo: Dictionary, clear_only: bool = false) -> Dictionary:
	var previous: Array = memo.get("source", [])
	var source: Array = [pieces, obstacles, bounds, reserved, height]
	var choice: Dictionary = choose(pieces, obstacles, bounds, reserved, height, false, clear_only)
	if previous.size() == 5 and previous[2] == bounds and previous[3] == reserved and previous[4] == height:
		var motion: Dictionary = _horizontal_motion(previous, source)
		if not motion.is_empty():
			memo.clear()
			memo["source"] = source.duplicate(true)
			memo["flags"] = motion["flags"]
			memo["direction"] = signf(float(motion["delta"]))
			memo["owner_moves"] = (motion["flags"] as Array).slice(0, pieces.size()).has(1)
			if clear_only: _clear_certificate(memo, pieces, obstacles, bounds, reserved, height, choice)
			else: _minimum_certificate(memo, pieces, obstacles, bounds, reserved, height, choice)
			return choice
	memo.clear()
	memo["source"] = source.duplicate(true)
	return choice

static func _horizontal_motion(previous: Array, current: Array) -> Dictionary:
	var delta: float = 0.0
	var flags: Array[int]
	for field: int in [0, 1]:
		if previous[field].size() != current[field].size(): return {}
		for index: int in range(current[field].size()):
			var old: Rect2 = previous[field][index]
			var next: Rect2 = current[field][index]
			if old.size != next.size or old.position.y != next.position.y: return {}
			var shift: float = next.position.x - old.position.x
			if shift != 0.0:
				if delta != 0.0 and absf(delta - shift) > maxf(absf(old.position.x), absf(next.position.x)) * FLOAT32_EPSILON: return {}
				delta = shift
			flags.append(0 if shift == 0.0 else 1)
	if delta == 0.0: return {}
	return {"delta": delta, "flags": flags}

static func _edge(cell: Dictionary, edge: float, velocity: float) -> void:
	if velocity == 0.0: return
	var crossing: float = edge / velocity
	if crossing == 0.0:
		if float(cell["direction"]) > 0.0: cell["lower"] = maxf(float(cell["lower"]), 0.0)
		else: cell["upper"] = minf(float(cell["upper"]), 0.0)
	elif crossing < 0.0: cell["lower"] = maxf(float(cell["lower"]), crossing)
	else: cell["upper"] = minf(float(cell["upper"]), crossing)

static func _presence(cell: Dictionary, piece: Rect2, obstacle: Rect2, velocity: float) -> void:
	if piece.position.y >= obstacle.end.y or obstacle.position.y >= piece.end.y: return
	_edge(cell, obstacle.position.x - piece.end.x, velocity)
	_edge(cell, obstacle.end.x - piece.position.x, velocity)

static func _hard_edges(cell: Dictionary, pieces: Array[Rect2], offset: Vector2, bounds: Rect2, reserved: Array[Rect2]) -> void:
	if offset == Vector2.ZERO or not cell.get("owner_moves", true): return
	for index: int in range(pieces.size()):
		var piece := Rect2(pieces[index].position + offset, pieces[index].size)
		var velocity: float = float(cell["flags"][index])
		if velocity == 0.0: continue
		if bounds.has_area():
			_edge(cell, bounds.position.x - piece.position.x, velocity)
			_edge(cell, bounds.end.x - piece.end.x, velocity)
		for rect: Rect2 in reserved: _presence(cell, piece, rect, velocity)

static func _clear_certificate(cell: Dictionary, pieces: Array[Rect2], obstacles: Array[Rect2], bounds: Rect2, reserved: Array[Rect2], height: float, choice: Dictionary) -> void:
	cell["lower"] = -INF
	cell["upper"] = INF
	cell["winner"] = {"offset": choice["offset"], "static": float(choice["overlap_area"]), "terms": []}
	var flags: Array = cell["flags"]
	var all_allowed: bool = reserved.is_empty() and bounds.encloses(pieces_bounds(pieces).grow_individual(MAX_HORIZONTAL, height + ROW_GAP, MAX_HORIZONTAL, height + ROW_GAP))
	for offset: Vector2 in candidates(height):
		_hard_edges(cell, pieces, offset, bounds, reserved)
		if not all_allowed and not allowed(pieces, offset, bounds, reserved): continue
		var blocked: bool = false
		for index: int in range(pieces.size()):
			var piece := Rect2(pieces[index].position + offset, pieces[index].size)
			for other: int in range(obstacles.size()):
				if piece.intersects(obstacles[other], false):
					_presence(cell, piece, obstacles[other], float(flags[index]) - float(flags[pieces.size() + other]))
					blocked = true
					break
			if blocked: break
		if blocked: continue
		for index: int in range(pieces.size()):
			var piece := Rect2(pieces[index].position + offset, pieces[index].size)
			for other: int in range(obstacles.size()): _presence(cell, piece, obstacles[other], float(flags[index]) - float(flags[pieces.size() + other]))
		return

static func _motion_rows(pieces: Array[Rect2], obstacles: Array[Rect2], height: float, flags: Array) -> Array:
	var rows: Array = [[], [], []]
	var ys: Array[float]
	ys.assign([0.0, -(height + ROW_GAP), height + ROW_GAP])
	for index: int in range(pieces.size()):
		var piece: Rect2 = pieces[index]
		for other: int in range(obstacles.size()):
			var rect: Rect2 = obstacles[other]
			var left: float = rect.position.x - piece.end.x
			var right: float = rect.end.x - piece.position.x
			var velocity: float = float(flags[index]) - float(flags[pieces.size() + other])
			for row: int in range(3):
				var y: float = minf(piece.end.y + ys[row], rect.end.y) - maxf(piece.position.y + ys[row], rect.position.y)
				if y > 0.0: rows[row].append([left, right, minf(piece.size.x, rect.size.x), y, velocity])
	return rows

static func _row_terms(pairs: Array, x: float) -> Dictionary:
	var result: Dictionary = {"static": 0.0, "terms": [], "events": {}, "slope_left": 0.0, "slope_right": 0.0}
	for pair: Array in pairs:
		var left: float = float(pair[0]) - x
		var right: float = float(pair[1]) - x
		var width: float = pair[2]
		var y: float = pair[3]
		var velocity: float = pair[4]
		if velocity == 0.0:
			result["static"] += Vector2(maxf(0.0, minf(minf(-left, right), width)) * y, 0.0).x
			continue
		result["terms"].append([left, right, width, y, velocity])
		var roots: Array[float]
		roots.assign([left / velocity, (left + width) / velocity, (right - width) / velocity, right / velocity])
		roots.sort()
		for edge: int in range(4):
			var slope: float = y * (1.0 if edge == 0 or edge == 3 else -1.0)
			if roots[edge] < 0.0: result["slope_left"] += slope
			if roots[edge] <= 0.0: result["slope_right"] += slope
			if absf(roots[edge]) <= MOTION_CERTIFICATE_RADIUS_PX:
				result["events"][roots[edge]] = float(result["events"].get(roots[edge], 0.0)) + slope
	return result

static func _terms_score(score: Dictionary, delta: float) -> float:
	var result: float = float(score["static"])
	for term: Array in score["terms"]:
		var x: float = delta * float(term[4])
		result += Vector2(maxf(0.0, minf(minf(x - float(term[0]), float(term[1]) - x), float(term[2]))) * float(term[3]), 0.0).x
	return result

static func _minimum_certificate(cell: Dictionary, pieces: Array[Rect2], obstacles: Array[Rect2], bounds: Rect2, reserved: Array[Rect2], height: float, choice: Dictionary) -> void:
	cell["lower"] = -MOTION_CERTIFICATE_RADIUS_PX
	cell["upper"] = MOTION_CERTIFICATE_RADIUS_PX
	var points: Array[Vector2] = candidates(height)
	var columns: int = points.size() / 3
	var rows: Array = _motion_rows(pieces, obstacles, height, cell["flags"])
	var winner: Dictionary = _row_terms(rows[points.find(choice["offset"]) / columns], choice["offset"].x)
	winner["offset"] = choice["offset"]
	cell["winner"] = winner
	winner["area"] = _terms_score(winner, 0.0)
	var all_allowed: bool = reserved.is_empty() and bounds.encloses(pieces_bounds(pieces).grow_individual(MAX_HORIZONTAL, height + ROW_GAP, MAX_HORIZONTAL, height + ROW_GAP))
	for index: int in range(points.size()):
		var offset: Vector2 = points[index]
		_hard_edges(cell, pieces, offset, bounds, reserved)
		if offset == choice["offset"] or (not all_allowed and not allowed(pieces, offset, bounds, reserved)): continue
		var other: Dictionary = _row_terms(rows[index / columns], offset.x)
		other["area"] = _terms_score(other, 0.0)
		if other["area"] == winner["area"] and other["slope_left"] == winner["slope_left"] and other["slope_right"] == winner["slope_right"] and other["events"] == winner["events"]: continue
		cell["lower"] = maxf(float(cell["lower"]), -_dominance_distance(winner, other, -1.0, -float(cell["lower"])))
		cell["upper"] = minf(float(cell["upper"]), _dominance_distance(winner, other, 1.0, float(cell["upper"])))

# Compare a rival only with the selected candidate. This walks each pair's own
# edge events once; it never builds the Cartesian all-candidate event envelope.
static func _dominance_distance(winner: Dictionary, rival: Dictionary, direction: float, limit: float) -> float:
	var events: Dictionary = {}
	for x: float in winner["events"]: events[x] = -float(winner["events"][x])
	for x: float in rival["events"]: events[x] = float(events.get(x, 0.0)) + float(rival["events"][x])
	var gap: float = float(rival["area"]) - float(winner["area"])
	if gap < 0.0: return 0.0
	var slope: float = (float(rival["slope_right"]) - float(winner["slope_right"])) if direction > 0.0 else -(float(rival["slope_left"]) - float(winner["slope_left"]))
	var edges: Array[float]
	for x: float in events:
		if x * direction > 0.0 and x * direction < limit: edges.append(x * direction)
	edges.sort()
	edges.append(limit)
	var previous: float = 0.0
	for edge: float in edges:
		if slope < 0.0:
			var crossing: float = previous + gap / -slope
			if crossing <= edge: return crossing
		if not is_finite(edge): return limit
		gap += slope * (edge - previous)
		slope += float(events.get(edge * direction, 0.0))
		previous = edge
	return limit

static func motion_score(memo: Dictionary, delta: float) -> float:
	return _terms_score(memo["winner"], delta)
