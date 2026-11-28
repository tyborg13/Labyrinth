extends RefCounted
## Screen-pixel alpha compositing, with separate visibility and HUD clipping.

const SCREEN := Rect2(0, 0, 1920, 1080)
const TILE_KINDS := ["pickup", "trap", "surface", "hazard", "marked", "telegraph", "telegraph_icon", "objective", "objective_floor", "summon"]
const TEXT_KINDS := ["intent_label", "name_label", "floating_number", "status_chip", "tag_chip", "tile_number"]
const UI_KINDS := ["health_bar", "intent_icon", "intent_label"]
const WEIGHTS := {"text": 3, "tile_content": 2, "unit": 1, "unit_ui": 1, "clip": 1}
const THRESHOLDS := {"tile_content": 0.40, "unit": 0.40, "unit_ui": 0.25}
const PIXEL_CENTER := Vector2(0.5, 0.5)
const VISUAL_TILE_RESTORE := {"pickup": "loot", "trap": "trap", "surface": "surface", "hazard": "refuge", "objective": "exit", "objective_floor": "exit", "telegraph": "danger"}
const OCCLUDERS := ["unit", "prop", "edge"]


func inspect(paint: Array[Dictionary], reach: Array) -> Dictionary:
	var groups: Dictionary = {}
	var props: Dictionary = {}
	for row: Dictionary in paint:
		var kind: String = row["kind"]
		var group: String = _key(row)
		row["group"] = group
		if kind == "prop":
			props[group] = {"kind": row["what"], "tile": [row["tile"].x, row["tile"].y]}
		if kind not in TILE_KINDS and kind not in UI_KINDS and kind != "unit" and not _is_text(row): continue
		if not groups.has(group): groups[group] = []
		groups[group].append(row)
	var flags: Array[Dictionary]
	var intent_count: int = 0
	var subjects: Array[Dictionary]
	for group: Array in groups.values():
		var target: Dictionary = group.front()
		var bounds: Rect2 = _bounds(group)
		var kind: String = _semantic_kind(target)
		if kind == "intent_label" and _is_text(target): intent_count += 1
		subjects.append({"kind": kind, "what": target.get("text", target["what"]), "actor": target["actor"], "is_text": _is_text(target),
			"tile": [target["tile"].x, target["tile"].y], "rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
		_measure(group, bounds, paint, reach, flags)
	var severity: int = 0
	for flag: Dictionary in flags: severity += WEIGHTS[flag["category"]]
	flags.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["urgent"] != b["urgent"]: return a["urgent"]
		if WEIGHTS[a["category"]] != WEIGHTS[b["category"]]: return WEIGHTS[a["category"]] > WEIGHTS[b["category"]]
		return a["covered_fraction"] > b["covered_fraction"])
	return {"flags": flags, "severity": severity, "props": props.values(), "intent_labels": intent_count,
		"paint_groups": groups.size(), "paint_primitives": paint.size(), "subjects": subjects}


func _bounds(group: Array) -> Rect2:
	var bounds: Rect2 = group.front()["bounds"]
	for part: Dictionary in group: bounds = bounds.merge(part["bounds"])
	return bounds


func _measure(group: Array, bounds: Rect2, paint: Array[Dictionary], reach: Array, flags: Array[Dictionary]) -> void:
	var target: Dictionary = group.front()
	var kind: String = _semantic_kind(target)
	var text: bool = _is_text(target)
	var tile: bool = kind in TILE_KINDS
	var first: int = target["order"]
	var front: Array[Dictionary]
	var hud: Array[Dictionary]
	var clipped: bool = not SCREEN.encloses(bounds)
	for other: Dictionary in paint:
		if int(other["order"]) <= first or other["group"] == target["group"] or not bounds.intersects(other["bounds"]): continue
		if other["kind"] == "hud":
			hud.append(other)
			continue
		if _same_widget(target, other): continue
		if kind == "unit" and other["kind"] == "edge" and target["actor"] == other["actor"] and not other.has("xray"): continue
		if _restores(target, other) or (other["kind"] == "show_through" or text or kind in UI_KINDS or other["kind"] in OCCLUDERS):
			front.append(other)
	if front.is_empty() and hud.is_empty() and not clipped: return
	front.reverse()
	hud.reverse()
	var mass: float = 0.0
	var covered: float = 0.0
	var lost_to_edge: float = 0.0
	var lost_to_hud: float = 0.0
	var causes: Dictionary = {}
	var hud_causes: Dictionary = {}
	var start := Vector2i(bounds.position.floor())
	var end := Vector2i(bounds.end.ceil())
	for y: int in range(start.y, end.y):
		for x: int in range(start.x, end.x):
			var point := Vector2(x, y) + PIXEL_CENTER
			var target_alpha: float = 0.0
			var target_order: int = -1
			for part: Dictionary in group:
				var opacity: float = _alpha(part, point)
				if opacity <= 0.0: continue
				target_alpha += (1.0 - target_alpha) * opacity
				target_order = part["order"]
			if target_alpha <= 0.0: continue
			mass += target_alpha
			if not SCREEN.has_point(point):
				lost_to_edge += target_alpha
				continue
			var remaining_hud: float = target_alpha
			for cover: Dictionary in hud:
				var loss: float = remaining_hud * _alpha(cover, point)
				if loss <= 0.0: continue
				lost_to_hud += loss
				_add_cause(hud_causes, cover, loss)
				remaining_hud -= loss
				if remaining_hud <= 0.0: break
			var remaining: float = target_alpha
			for cover: Dictionary in front:
				if int(cover["order"]) <= target_order: break
				var loss: float = remaining * _alpha(cover, point)
				if loss <= 0.0: continue
				remaining -= loss
				if not _restores(target, cover):
					covered += loss
					_add_cause(causes, cover, loss)
				if remaining <= 0.0: break
	if mass <= 0.0: return
	var fraction: float = covered / mass
	if text and covered > 0.0: flags.append(_flag("text", target, bounds, fraction, causes, mass, reach))
	if tile and fraction >= THRESHOLDS["tile_content"]:
		flags.append(_flag("tile_content", target, bounds, fraction, causes, mass, reach))
	if kind == "unit" and fraction > THRESHOLDS["unit"]:
		flags.append(_flag("unit", target, bounds, fraction, causes, mass, reach))
	if kind in UI_KINDS and fraction >= THRESHOLDS["unit_ui"]:
		flags.append(_flag("unit_ui", target, bounds, fraction, causes, mass, reach))
	if lost_to_edge + lost_to_hud > 0.0:
		var flag: Dictionary = _flag("clip", target, bounds, (lost_to_edge + lost_to_hud) / mass, hud_causes, mass, reach)
		flag["screen_edge_fraction"] = lost_to_edge / mass
		flag["hud_fraction"] = lost_to_hud / mass
		if lost_to_edge > 0.0: flag["by"].append({"kind": "screen_edge", "what": "screen edge", "fraction": lost_to_edge / mass})
		flags.append(flag)


func _same_widget(target: Dictionary, other: Dictionary) -> bool:
	if target["kind"] == other["kind"] and target["what"] == other["what"] and target["actor"] == other["actor"]:
		if target["tile"] == other["tile"] and (not target.has("text") or not other.has("text")): return true
	return false


func _key(row: Dictionary) -> String:
	var identity: Array = [row["kind"], row["what"], row["tile"], row["actor"]]
	if _is_text(row):
		identity.append(row["text"])
		identity.append((row["bounds"] as Rect2).position)
	return JSON.stringify(identity)


func _semantic_kind(row: Dictionary) -> String:
	return "intent_label" if row["kind"] == "intent_icon" and row.has("text") else row["kind"]


func _is_text(row: Dictionary) -> bool:
	return row.has("text") and _semantic_kind(row) in TEXT_KINDS


func _restores(target: Dictionary, cover: Dictionary) -> bool:
	if cover["kind"] == "show_through":
		return cover["tile"] == target["tile"] and cover["restores"] == VISUAL_TILE_RESTORE.get(target["kind"], "")
	return cover.has("xray") and target["kind"] == "unit" and cover["actor"] == target["actor"]


func _add_cause(causes: Dictionary, row: Dictionary, contribution: float) -> void:
	var id: String = row["group"]
	if not causes.has(id):
		causes[id] = {"kind": _semantic_kind(row), "what": row.get("text", row["what"]), "actor": row["actor"],
			"tile": [row["tile"].x, row["tile"].y], "fraction": 0.0, "is_text": _is_text(row)}
	causes[id]["fraction"] += contribution


func _flag(category: String, target: Dictionary, rect: Rect2, covered: float, causes: Dictionary, mass: float, reach: Array) -> Dictionary:
	var by: Array = causes.values()
	for cause: Dictionary in by: cause["fraction"] /= mass
	by.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["fraction"] != b["fraction"]: return a["fraction"] > b["fraction"]
		return str(a["what"]) < str(b["what"]))
	var kind: String = _semantic_kind(target)
	var urgent: bool = kind in ["telegraph", "telegraph_icon", "intent_label", "intent_icon"] or (kind == "pickup" and target["tile"] in reach)
	return {"category": category, "kind": kind, "what": target.get("text", target["what"]), "actor": target["actor"],
		"tile": [target["tile"].x, target["tile"].y], "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"covered_fraction": covered, "by": by, "urgent": urgent}


func _alpha(row: Dictionary, screen_point: Vector2) -> float:
	if not (row["bounds"] as Rect2).has_point(screen_point): return 0.0
	var local: Vector2 = (row["inverse"] as Transform2D) * screen_point
	var alpha: float = row["alpha"]
	if row.has("mask_planes"): return alpha * _show_alpha(row, local)
	if row.has("polygon"): return alpha * _polygon_alpha(row, local)
	if row.has("rim"): return _edge_alpha(row, local, screen_point)
	var rect: Rect2 = row["rect"]
	if not rect.abs().has_point(local): return 0.0
	if not row.has("image"): return alpha
	return alpha * _texture_alpha(row, local)


func _texture_alpha(row: Dictionary, local: Vector2) -> float:
	var rect: Rect2 = row["rect"]
	if not rect.abs().has_point(local): return 0.0
	var uv: Vector2 = (local - rect.position) / rect.size
	if row.get("transpose", false): uv = Vector2(uv.y, uv.x)
	var image: Image = row["image"]
	var region: Rect2 = row.get("region", Rect2())
	return _texel(image, region.position + uv * region.size if absf(region.get_area()) > 0.0 else uv * Vector2(image.get_size()))


func _texel(image: Image, at: Vector2) -> float:
	var point := Vector2i(at.floor())
	return image.get_pixelv(point).a if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point) else 0.0


func _polygon_alpha(row: Dictionary, at: Vector2) -> float:
	var points: PackedVector2Array = row["polygon"]
	if bool(row.get("diamond", false)): return float(Geometry2D.is_point_in_polygon(at, points))
	var triangles: PackedInt32Array = row["triangles"]
	var colors: PackedColorArray = row.get("colors", PackedColorArray())
	var uv: PackedVector2Array = row.get("uv", PackedVector2Array())
	for index: int in range(0, triangles.size(), 3):
		var a: int = triangles[index]
		var b: int = triangles[index + 1]
		var c: int = triangles[index + 2]
		var x: Vector2 = points[b] - points[a]
		var y: Vector2 = points[c] - points[a]
		var determinant: float = x.cross(y)
		if is_zero_approx(determinant): continue
		var delta: Vector2 = at - points[a]
		var u: float = delta.cross(y) / determinant
		var v: float = x.cross(delta) / determinant
		var w: float = 1.0 - u - v
		if minf(u, minf(v, w)) < 0.0: continue
		var alpha: float = colors[a].a * w + colors[b].a * u + colors[c].a * v if colors.size() == points.size() else 1.0
		if row.has("image") and uv.size() == points.size():
			alpha *= _texel(row["image"], uv[a] * w + uv[b] * u + uv[c] * v)
		return alpha
	return 0.0


func _show_alpha(row: Dictionary, local: Vector2) -> float:
	var grid: Vector4 = row["mask_grid"]
	if not _on_checker(local, grid): return 0.0
	var bounds: Rect2 = row["rect"]
	var pixel := Vector2i((local - bounds.position).floor())
	var planes: Array = row["mask_planes"]
	var factors: PackedFloat32Array = row["mask_factors"]
	var factor_width: int = factors.size() / 2
	var own: float = 0.0
	for index: int in range(planes.size() - 1, -1, -1):
		var mask: Image = planes[index]
		var blocker: int = int(mask.get_pixelv(pixel).r)
		if blocker == 0: continue
		var coverage: float = factors[index] * factors[factor_width + blocker - 1]
		if coverage <= 0.0: continue
		if index >= int(row["floor_count"]): return coverage if index == int(row["mask_index"]) else 0.0
		if index == int(row["mask_index"]): own = coverage
	return own


func _on_checker(point: Vector2, grid: Vector4) -> bool:
	if is_zero_approx(grid.z) or is_zero_approx(grid.w): return false
	return posmod(floori((point.x - grid.x) / grid.z) + floori((point.y - grid.y) / grid.w), 2) == 0


func _edge_alpha(row: Dictionary, local: Vector2, screen: Vector2) -> float:
	var center: float = _texture_alpha(row, local)
	var outside: float = center
	var radius: Vector2 = row["radius"]
	if center < 1.0:
		for i: int in 24:
			var angle: float = TAU * float(i) / (16.0 if i < 16 else 8.0)
			var sample: Vector2 = local + Vector2.from_angle(angle) * radius * (1.0 if i < 16 else 0.5)
			outside = maxf(outside, _texture_alpha(row, sample))
			if outside >= 1.0: break
	var mask: float = maxf(0.0, outside - center)
	var base: float = float(row["rim_alpha"]) * float(row["alpha"])
	var over: float = row["over_alpha"]
	var rim: float = maxf(0.0, (base - over) * mask) / maxf(0.00001, 1.0 - over * mask)
	var xray: Dictionary = row.get("xray", {})
	if xray.is_empty() or center <= 0.0 or float(xray["alpha"]) <= 0.0: return rim
	var board: Vector2 = (xray["screen_to_board"] as Transform2D) * screen
	if not _on_checker(board, xray["grid"]): return rim
	var cover: float = 0.0
	for prop: Dictionary in xray.get("parts", []):
		if (prop["rect"] as Rect2).has_point(board) and _texture_alpha(prop, board) > 0.5:
			cover = maxf(cover, prop["alpha"])
	var fill: float = center * cover * float(xray["alpha"]) * float(row["alpha"])
	return rim + fill * (1.0 - rim)
