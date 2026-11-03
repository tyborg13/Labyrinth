extends RefCounted

const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const EngineScript = preload("res://scripts/combat_engine.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const TINT := Color("cfe3f2")
const DIRECTION_NAMES: Dictionary = {Vector2i(0, -1): "toward the upper right", Vector2i(1, 0): "toward the lower right", Vector2i(0, 1): "toward the lower left", Vector2i(-1, 0): "toward the upper left"}
const CHEVRON_STROKE: float = 2.0
const CHIP_ARROW_SIZE: float = 12.0
# Wind gusts (owner, warband-markers-v2: show which way the wind blows and where
# it comes from). Each gust is a brush stroke with the Dive's flight profile,
# thin where it leaves and full where it arrives. Gusts enter at the upwind edge
# of the board and leave at the downwind edge. Grid units unless noted.
const GUST_LENGTH: float = 2.6
const GUST_SPEED: float = 1.5
const GUST_LANE_SPACING: float = 1.35
const GUST_LENGTH_SPREAD: float = 0.4
const GUST_GAP_MIN: float = 1.2
const GUST_GAP_RANGE: float = 2.8
const GUST_SAMPLES: int = 22
const GUST_WAVE: float = 0.07
const GUST_HALF_WIDTH: float = 0.075
const GUST_ALPHA: float = 0.62
const GUST_EDGE_FADE: float = 0.9
# A wind that is called but has not blown yet shows its gusts faintly.
const GUST_FORECAST_ALPHA: float = 0.4
# The ink shadow matches the Dive's swoosh; the glow softens the stroke into air.
const GUST_SHADOW_OFFSET: float = 0.03
const GUST_SHADOW_ALPHA: float = 0.3
const GUST_GLOW_WIDTH: float = 3.2
const GUST_GLOW_ALPHA: float = 0.16
const GUST_CORE_LIFT: float = 0.45
# Each gust runs with a shorter, fainter companion beside it, like the paired
# streams of the wind icon.
const COMPANION_OFFSET: float = 0.17
const COMPANION_LENGTH: float = 0.6
const COMPANION_LAG: float = 0.4
const COMPANION_WIDTH: float = 0.55
const COMPANION_ALPHA: float = 0.75
# The push: one gust front crosses the whole board with the slide.
const FRONT_HALF_WIDTH: float = 1.35
const FRONT_ALPHA: float = 0.95
const FRONT_JITTER: float = 0.7
# The source: three gusts circle the caller's feet.
const WHIRL_RADIUS: float = 0.5
const WHIRL_ARC: float = 1.5
const WHIRL_CURL: float = 0.45
const WHIRL_SPEED: float = 2.2
const WHIRL_ALPHA: float = 0.6
const WHIRL_SAMPLES: int = 14
# Rows across a stroke: the glow fades from its centre; the shadow and core keep
# a solid body with clear edges, the core lit along its spine.
const GLOW_ROWS: PackedFloat32Array = [-1.0, 0.0, 1.0]
const CORE_ROWS: PackedFloat32Array = [-1.0, -0.5, 0.0, 0.5, 1.0]
const PASSES: PackedStringArray = ["glow", "shadow", "core"]
static var _strip_indices: Dictionary = {}
# Slides: a pale ghost of each unit stands where the wind will set it down
# (owner, warband-markers: rings, chevrons and dashes read as amateur). Wind that
# has not blown yet shows fainter ghosts.
const GHOST_ROLE: String = "wind_slide_preview"
const GHOST_TINT := Color(TINT, 0.36)
const GHOST_FORECAST_TINT := Color(TINT, 0.22)
const GHOST_HAZE := Color(Palette.STEEL, 0.10)
const SOURCE_TOOLTIP: String = "Calls the wind. Defeat it and the wind stops."
const CARD_ARROW_HEAD_WIDTH_RATIO: float = 0.405
const CARD_ARROW_HEAD_REACH_RATIO: float = 0.138 + 0.285
static var _engine: RefCounted = EngineScript.new()

class DirectionArrow extends Control:
	var heading := Vector2.ZERO

	func _draw() -> void:
		var length: float = Typography.scaled_value(self, CHIP_ARROW_SIZE)
		var tip: Vector2 = size * 0.5 + heading * length * 0.5
		var tail: Vector2 = tip - heading * length
		var normal := Vector2(-heading.x, heading.y).normalized()
		# Same arrowhead proportions as the existing card push preview.
		var head: Vector2 = tip - heading * length * CARD_ARROW_HEAD_REACH_RATIO
		var half_width: float = length * CARD_ARROW_HEAD_WIDTH_RATIO * 0.5
		draw_line(tail, tip, Palette.TEXT, CHEVRON_STROKE, true)
		draw_polyline(PackedVector2Array([head - normal * half_width, tip, head + normal * half_width]), Palette.TEXT, CHEVRON_STROKE, true)

static func screen_direction(axis: Vector2i) -> Vector2:
	# Isometric tile centers: x-y horizontally, half of x+y vertically.
	return Vector2(axis.x - axis.y, float(axis.x + axis.y) * 0.5).normalized()

static var _forecast_memo := preload("res://scripts/combat_preview_memo.gd").new()

static func forecast(view: Control) -> Dictionary:
	return _forecast_entry(view).duplicate(true)

static func has_forecast(view: Control) -> bool:
	return not (_forecast_entry(view).get("wind", {}) as Dictionary).is_empty()

static func tile_layers(view: Control) -> Array[Dictionary]:
	var layers: Array[Dictionary]
	for layer: Dictionary in _forecast_entry(view).get("layers", []):
		layers.append({"wind": (layer["wind"] as Dictionary).duplicate(true), "dashed": bool(layer["dashed"])})
	return layers

# Only private drawing/query helpers read this entry. Public data APIs copy
# their outputs, including nested resolver states, paths and collision markers.
static func _forecast_entry(view: Control) -> Dictionary:
	var state: Dictionary = view.combat_state
	# This predicate reads the live inputs on every query. Empty forecasts need
	# neither catalog scaling nor a stored snapshot, and still return owned data.
	if not _has_wind_source(state): return {"wind": {}, "dashed": false, "layers": []}
	var definitions: Array
	# Scaling is pure, so exact raw definitions identify the same dependency
	# without copying/scaling a full public definition for every depth layer.
	for enemy: Dictionary in state.get("enemies", []): definitions.append(_engine.GameData.enemies().get(str(enemy.get("type", "")), {}))
	var inputs: Array = [state, definitions, _engine._relic_effects(state)]
	# Always compare complete owned inputs. Equal hashes are never evidence that
	# hero displacement, definitions or relic effects are unchanged.
	if view.get_meta("en02_wind_inputs", []) == inputs:
		return view.get_meta("en02_wind_forecast", {})
	var result: Dictionary = _forecast_memo.resolve(inputs, func() -> Dictionary: return _forecast_for_state(state))
	view.set_meta("en02_wind_inputs", inputs.duplicate(true))
	view.set_meta("en02_wind_forecast", result)
	return result

static func _has_wind_source(state: Dictionary) -> bool:
	if not (state.get("wind", {}) as Dictionary).is_empty(): return true
	for enemy: Dictionary in state.get("enemies", []):
		for action: Dictionary in enemy.get("intent", {}).get("actions", []):
			if str(action.get("type", "")) == "call_wind": return true
	return false

static func _forecast_for_state(state: Dictionary) -> Dictionary:
	if not _has_wind_source(state): return {"wind": {}, "dashed": false, "layers": []}
	var layers: Array[Dictionary]
	var value: Dictionary = Wind.active(_engine, state)
	if not value.is_empty():
		var current: Dictionary = {"wind": value, "dashed": false}
		if Wind.room_sourced(state, value):
			var pressure = preload("res://scripts/snare_pressure_rules.gd")
			current.merge(pressure.presentation_projection(pressure.preview(_engine, state)))
		else:
			current.merge(Wind.preview(_engine, state, value))
		layers.append(current)
	for index: int in range(state.get("enemies", []).size()):
		var enemy: Dictionary = state["enemies"][index]
		if int(enemy.get("hp", 0)) <= 0 or int(enemy.get("freeze", 0)) > 0 or int(enemy.get("shock", 0)) > 0 or _engine.ManeuverRules.is_petrified(enemy) or not _engine.is_enemy_visible_to_player(state, enemy): continue
		var plan: Dictionary = Wind.plan(_engine, state, index, enemy.get("intent", {}), false)
		if plan.is_empty(): continue
		var call: Dictionary = {"wind": plan["wind"], "dashed": true}
		call.merge(plan["wind_preview"])
		layers.append(call)
	var result: Dictionary = layers[0].duplicate(false) if not layers.is_empty() else {"wind": {}, "dashed": false}
	result["layers"] = layers
	return result

# Drawn once over the floor in the overlay pass, under every actor. Wind that is
# blowing shows full gusts; a called wind shows faint ones until it first blows.
# Returns the number of triangle submissions, one per stroke and pass.
static func draw_field(view: Control, server: Object = null) -> int:
	return submit_batches(view.get_canvas_item(), field_batches(view), server)

# Submits to the renderer; tests pass a recorder with the same method.
static func submit_batches(item: RID, batches: Array[Dictionary], server: Object = null) -> int:
	var target: Object = server if server != null else RenderingServer
	for batch: Dictionary in batches:
		target.canvas_item_add_triangle_array(item, batch["indices"], batch["vertices"], batch["colors"])
	return batches.size()

# Glow, ink shadow and pale core, each pass under the next. A stroke is sampled
# once and trimmed to its visible span; fully hidden strokes submit nothing.
static func field_batches(view: Control) -> Array[Dictionary]:
	var batches: Array[Dictionary]
	var strokes: Array[Dictionary] = field_strokes(view)
	if strokes.is_empty(): return batches
	var scale: float = view._tile_center(Vector2i(1, 0)).distance_to(view._tile_center(Vector2i.ZERO))
	var shadow := Vector2(0.0, GUST_SHADOW_OFFSET * scale)
	var shapes: Array[Dictionary]
	for stroke: Dictionary in strokes:
		var shape: Dictionary = _stroke_shape(stroke, scale)
		if not shape.is_empty(): shapes.append(shape)
	for pass_kind: String in PASSES:
		for shape: Dictionary in shapes: batches.append(_stroke_pass(shape, pass_kind, shadow))
	return batches

static func field_strokes(view: Control) -> Array[Dictionary]:
	var strokes: Array[Dictionary]
	var layer: Dictionary = _field_layer(view)
	var grid: Array = view.combat_state.get("grid", [])
	if layer.is_empty() or grid.is_empty(): return strokes
	var forecast: bool = bool(layer["dashed"])
	var wind: Dictionary = layer["wind"]
	var frame: Dictionary = _field_frame(view, Vector2(wind["direction"]))
	var time: float = field_clock(view.presentation)
	var alpha: float = GUST_FORECAST_ALPHA if forecast else GUST_ALPHA
	var lanes: int = maxi(1, int(floor(frame["breadth"] / GUST_LANE_SPACING)))
	for lane: int in range(lanes):
		# Fixed per-lane phase, gap and offset so gusts never march in step.
		var lateral: float = (float(lane) - float(lanes - 1) * 0.5) * GUST_LANE_SPACING + (_hash01(lane, 1) - 0.5) * 0.5
		var cycle: float = frame["reach"] + GUST_LENGTH + GUST_GAP_MIN + _hash01(lane, 2) * GUST_GAP_RANGE
		var head: float = fposmod(_hash01(lane, 3) * cycle + time * GUST_SPEED, cycle)
		_append_gust(view, grid, frame, strokes, head, lateral, lane, alpha, 1.0, "gust")
	if not forecast: _append_push_front(view, grid, frame, strokes)
	_append_whirl(view, wind, time, WHIRL_ALPHA, strokes)
	return strokes

# The blowing wind wins; otherwise the first called wind is previewed.
static func _field_layer(view: Control) -> Dictionary:
	var layers: Array = _forecast_entry(view).get("layers", [])
	for layer: Dictionary in layers:
		if not bool(layer["dashed"]): return layer
	return layers[0] if not layers.is_empty() else {}

static func _field_frame(view: Control, axis: Vector2) -> Dictionary:
	var grid: Array = view.combat_state.get("grid", [])
	var size := Vector2(float((grid[0] as Array).size()), float(grid.size()))
	var origin: Vector2 = view._tile_center(Vector2i.ZERO)
	var step_x: Vector2 = view._tile_center(Vector2i(1, 0)) - origin
	var step_y: Vector2 = view._tile_center(Vector2i(0, 1)) - origin
	return {"axis": axis, "across": Vector2(-axis.y, axis.x), "reach": absf(axis.x) * size.x + absf(axis.y) * size.y,
		"breadth": absf(axis.y) * size.x + absf(axis.x) * size.y, "middle": (size - Vector2.ONE) * 0.5,
		"origin": origin, "step_x": step_x, "step_y": step_y, "scale": step_x.length(), "shown": {}}

static func _hash01(lane: int, salt: int) -> float:
	return fposmod(float(lane) * (0.618034 + float(salt) * 0.271) + float(salt) * 0.137, 1.0)

static func _append_gust(view: Control, grid: Array, frame: Dictionary, strokes: Array[Dictionary], head: float, lateral: float, lane: int, alpha: float, width: float, kind: String) -> void:
	var length: float = GUST_LENGTH * (1.0 + (_hash01(lane, 6) - 0.5) * GUST_LENGTH_SPREAD)
	var side: float = 1.0 if lane % 2 == 0 else -1.0
	var main: Dictionary = _gust_stroke(view, grid, frame, head, lateral, float(lane), alpha, width, length)
	var companion: Dictionary = _gust_stroke(view, grid, frame, head - COMPANION_LAG, lateral + side * COMPANION_OFFSET, float(lane), alpha * COMPANION_ALPHA, width * COMPANION_WIDTH, length * COMPANION_LENGTH)
	main["kind"] = kind
	companion["kind"] = kind + "_companion"
	strokes.append(main)
	strokes.append(companion)

# One gust with its head `head` tiles in from the upwind edge. Samples off the
# floor or out of sight fade to nothing, so walls and the Umbra cut it softly.
static func _gust_stroke(view: Control, grid: Array, frame: Dictionary, head: float, lateral: float, seed: float, alpha: float, width: float, length: float) -> Dictionary:
	var points := PackedVector2Array()
	var alphas := PackedFloat32Array()
	var reach: float = frame["reach"]
	for sample: int in range(GUST_SAMPLES + 1):
		var t: float = float(sample) / float(GUST_SAMPLES)
		var along: float = head - length * (1.0 - t)
		var sway: float = sin(along * 2.1 + seed * 1.7) * GUST_WAVE
		var at: Vector2 = frame["middle"] + frame["axis"] * (along - reach * 0.5) + frame["across"] * (lateral + sway)
		points.append(frame["origin"] + frame["step_x"] * at.x + frame["step_y"] * at.y)
		var tile := Vector2i(roundi(at.x), roundi(at.y))
		var shown_tiles: Dictionary = frame["shown"]
		if not shown_tiles.has(tile): shown_tiles[tile] = Paths.is_passable(grid, tile) and view._board_tile_is_visible_to_player(tile)
		var shown: bool = shown_tiles[tile]
		var edge: float = smoothstep(-0.2, GUST_EDGE_FADE, along) * (1.0 - smoothstep(reach - GUST_EDGE_FADE, reach + 0.2, along))
		alphas.append(alpha * edge if shown else 0.0)
	return {"points": points, "alphas": alphas, "width": width}

# The slide itself: every lane fires one gust whose head crosses the board as
# the units move, so the push visibly comes with the wind.
static func _append_push_front(view: Control, grid: Array, frame: Dictionary, strokes: Array[Dictionary]) -> void:
	var effect: Dictionary = view.presentation.get("effect", {})
	if str(effect.get("en02_mechanic", "")) != "wind_push": return
	var progress: float = ease(clampf(float(view.presentation.get("effect_progress", 0.0)), 0.0, 1.0), 0.8)
	var lanes: int = maxi(1, int(floor(frame["breadth"])))
	for lane: int in range(lanes):
		var lateral: float = float(lane) - float(lanes - 1) * 0.5 + (_hash01(lane, 4) - 0.5) * 0.4
		var head: float = lerpf(0.0, frame["reach"] + GUST_LENGTH, progress) - _hash01(lane, 5) * FRONT_JITTER
		_append_gust(view, grid, frame, strokes, head, lateral, lane + 11, FRONT_ALPHA, FRONT_HALF_WIDTH, "front")

# Three gusts circle the caller's feet: the wind visibly comes from it.
static func _append_whirl(view: Control, wind: Dictionary, time: float, alpha: float, strokes: Array[Dictionary]) -> void:
	var source: Dictionary = {}
	for enemy: Dictionary in view.combat_state.get("enemies", []):
		if int(enemy.get("id", -2)) == int(wind.get("source_id", -1)) and int(enemy.get("hp", 0)) > 0: source = enemy
	if source.is_empty() or not view._board_tile_is_visible_to_player(source["pos"]): return
	var centre: Vector2 = view._tile_center(source["pos"])
	var step_x: Vector2 = view._tile_center(Vector2i(1, 0)) - view._tile_center(Vector2i.ZERO)
	var step_y: Vector2 = view._tile_center(Vector2i(0, 1)) - view._tile_center(Vector2i.ZERO)
	for arm: int in range(3):
		var points := PackedVector2Array()
		var alphas := PackedFloat32Array()
		var start: float = time * WHIRL_SPEED + float(arm) * TAU / 3.0
		for sample: int in range(WHIRL_SAMPLES + 1):
			var t: float = float(sample) / float(WHIRL_SAMPLES)
			var angle: float = start + WHIRL_ARC * t
			# Each arm curls inward toward its head, like a gust caught in a vortex.
			var radius: float = WHIRL_RADIUS * (1.0 - WHIRL_CURL * t * t)
			points.append(centre + (step_x * cos(angle) + step_y * sin(angle)) * radius)
			alphas.append(alpha)
		strokes.append({"points": points, "alphas": alphas, "width": 1.0, "kind": "whirl"})

# The Dive flight's profile: a long thin tail, full near the head. Samples that
# carry no ink are trimmed, keeping one clear sample at each cut so it fades in.
static func _stroke_shape(stroke: Dictionary, scale: float) -> Dictionary:
	var points: PackedVector2Array = stroke["points"]
	var alphas: PackedFloat32Array = stroke["alphas"]
	var count: int = points.size()
	if count < 2: return {}
	var first: int = -1
	var last: int = -1
	for index: int in range(count):
		if alphas[index] > 0.0 and index > 0:
			if first < 0: first = index
			last = index
	if first < 0: return {}
	first -= 1
	last = mini(last + 1, count - 1)
	var kept := PackedVector2Array()
	var normals := PackedVector2Array()
	var widths := PackedFloat32Array()
	var strengths := PackedFloat32Array()
	var width_scale: float = GUST_HALF_WIDTH * scale * float(stroke["width"]) * 1.9
	for index: int in range(first, last + 1):
		var t: float = float(index) / float(count - 1)
		kept.append(points[index])
		normals.append((points[mini(index + 1, count - 1)] - points[maxi(index - 1, 0)]).normalized().orthogonal())
		widths.append(width_scale * pow(t, 1.4) * pow(1.0 - t, 0.3))
		strengths.append(alphas[index] * smoothstep(0.0, 0.35, t))
	return {"points": kept, "normals": normals, "widths": widths, "strengths": strengths, "kind": str(stroke.get("kind", ""))}

static func _stroke_pass(shape: Dictionary, pass_kind: String, shadow: Vector2) -> Dictionary:
	var rows: PackedFloat32Array = GLOW_ROWS if pass_kind == "glow" else CORE_ROWS
	var points: PackedVector2Array = shape["points"]
	var normals: PackedVector2Array = shape["normals"]
	var widths: PackedFloat32Array = shape["widths"]
	var strengths: PackedFloat32Array = shape["strengths"]
	var row_count: int = rows.size()
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	vertices.resize(points.size() * row_count)
	colors.resize(points.size() * row_count)
	var spread: float = GUST_GLOW_WIDTH if pass_kind == "glow" else 1.0
	var offset: Vector2 = shadow if pass_kind == "shadow" else Vector2.ZERO
	# Per-row colour and alpha scale; edge rows stay clear in every pass.
	var row_colors: Array[Color]
	var row_alpha := PackedFloat32Array()
	for row: float in rows:
		match pass_kind:
			"glow":
				row_colors.append(TINT)
				row_alpha.append(GUST_GLOW_ALPHA * (1.0 - absf(row)))
			"shadow":
				row_colors.append(Palette.INK_0)
				row_alpha.append(0.0 if absf(row) == 1.0 else GUST_SHADOW_ALPHA)
			_:
				row_colors.append(TINT.lightened(GUST_CORE_LIFT) if row == 0.0 else TINT)
				row_alpha.append(0.0 if absf(row) == 1.0 else 1.0)
	var at: int = 0
	for index: int in range(points.size()):
		var strength: float = strengths[index]
		var centre: Vector2 = points[index] + offset
		var across: Vector2 = normals[index] * widths[index] * spread
		for row: int in range(row_count):
			vertices[at] = centre + across * rows[row]
			colors[at] = Color(row_colors[row], strength * row_alpha[row])
			at += 1
	return {"vertices": vertices, "colors": colors, "indices": strip_indices(points.size(), row_count), "pass": pass_kind, "kind": shape["kind"]}

# Triangle indices for a strip of `samples` x `rows` vertices, shared by every
# stroke of that size.
static func strip_indices(samples: int, rows: int) -> PackedInt32Array:
	var key: int = samples * 16 + rows
	if _strip_indices.has(key): return _strip_indices[key]
	var indices := PackedInt32Array()
	for index: int in range(samples - 1):
		for row: int in range(rows - 1):
			var a: int = index * rows + row
			var b: int = a + rows
			indices.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b]))
	_strip_indices[key] = indices
	return indices

# Reduced motion holds the gusts still.
static func field_clock(presentation: Dictionary) -> float:
	return 0.0 if bool(presentation.get("reduced_motion", false)) else float(presentation.get("en02_wind_time_seconds", Time.get_ticks_msec() / 1000.0))

# Preview units for the board's own echo pipeline, so each ghost depth-sorts
# with the actors. Paths the presentation already previews are skipped, and one
# actor gets one ghost per landing tile even when wind layers agree.
static func landing_ghosts(view: Control) -> Array[Dictionary]:
	var ghosts: Array[Dictionary]
	var state: Dictionary = view.combat_state
	var shown: Array = view.presentation.get("displacement_paths", []) as Array
	# Umbra privacy: an enemy the board doesn't show never gets a ghost.
	var filter_enemies: bool = view.presentation.has("visible_enemy_ids")
	var visible_enemy_ids: Array = view.presentation.get("visible_enemy_ids", []) as Array
	var emitted: Dictionary = {}
	for layer: Dictionary in _ghost_layers(view):
		for path: Array in layer.get("displacement_paths", []):
			if path.size() < 2 or shown.has(path): continue
			var visible: bool = true
			for tile: Vector2i in path:
				if not view._board_tile_is_visible_to_player(tile): visible = false
			if not visible: continue
			var source: Dictionary = _unit_at(state, path[0])
			if source.is_empty(): continue
			if str(source["key"]).begins_with("enemy_") and filter_enemies and not visible_enemy_ids.has(int(source["id"])): continue
			var landing: Vector2i = path[-1]
			var key: String = "wind_ghost_%s_%d_%d" % [source["key"], landing.x, landing.y]
			if emitted.has(key): continue
			emitted[key] = true
			source.merge({"role": GHOST_ROLE, "pos": landing, "key": key, "wind_forecast": bool(layer.get("dashed", false)), "hp": 1, "max_hp": 1, "block": 0, "stoneskin": 0, "bleed": 0, "freeze": 0, "shock": 0, "immobilize": false, "intent": {}, "preview": true}, true)
			ghosts.append(source)
	return ghosts

# The Snare's room headwind resolves after end-turn preparation, so its prepared
# projection (spx-06) is where units land; enemy wind calls keep their forecasts.
static func _ghost_layers(view: Control) -> Array:
	var layers: Array = _forecast_entry(view).get("layers", [])
	var state: Dictionary = view.combat_state
	if not (Wind.room_sourced(state, state.get("wind", {})) and view.presentation.has("snare_pressure_preview")): return layers
	var result: Array = [view.presentation["snare_pressure_preview"]]
	for layer: Dictionary in layers:
		if bool(layer["dashed"]): result.append(layer)
	return result

static func _unit_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	if (state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)) == tile:
		return {"key": "player", "id": -1, "type": "player", "name": "Player", "footprint": Vector2i.ONE}
	for illusion: Dictionary in state.get("illusions", []):
		if int(illusion.get("hp", 0)) > 0 and illusion.get("pos", Vector2i(-1, -1)) == tile:
			return {"key": "illusion_%d" % int(illusion.get("id", -1)), "id": int(illusion.get("id", -1)), "type": "player", "name": "Illusion", "footprint": Vector2i.ONE}
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0 and enemy.get("pos", Vector2i(-1, -1)) == tile:
			return {"key": "enemy_%d" % int(enemy["id"]), "id": int(enemy["id"]), "type": str(enemy["type"]), "name": str(enemy.get("name", "")), "footprint": enemy.get("footprint", Vector2i.ONE)}
	return {}

static func ghost_tint(unit: Dictionary) -> Color:
	return GHOST_FORECAST_TINT if bool(unit.get("wind_forecast", false)) else GHOST_TINT

static func collision_identity(marker: Dictionary) -> String:
	return "%s|%s|%s|%d" % [str(marker.get("actor_key", "")), str(marker.get("tile", "")), str(marker.get("blocked_tile", "")), int(marker.get("damage", 0))]

static func collision_markers(view: Control) -> Array[Dictionary]:
	var markers: Array[Dictionary]
	var seen: Dictionary = {}
	for marker: Dictionary in view.presentation.get("collision_markers", []): seen[collision_identity(marker)] = true
	for layer: Dictionary in _forecast_entry(view).get("layers", []):
		for marker: Dictionary in layer.get("collision_markers", []):
			var key: String = collision_identity(marker)
			if seen.has(key): continue
			seen[key] = true
			markers.append(marker.duplicate(true))
	return markers

static func draw_collisions(view: Control) -> void:
	var markers: Array[Dictionary] = collision_markers(view)
	if markers.is_empty(): return
	var original: Array = view.presentation.get("collision_markers", [])
	view.presentation["collision_markers"] = markers
	view._draw_collision_markers()
	view.presentation["collision_markers"] = original

static func status_badges(unit: Dictionary) -> Array[Dictionary]:
	var badges: Array[Dictionary]
	if str(unit.get("type", "")) != "gale_herald": return badges
	# The wind's source carries the wind sigil (owner, warband-markers-v2).
	badges.append({"status_class": "trait", "icon": "wind", "count": 0, "fill": Palette.STEEL, "border": Palette.STEEL, "icon_tint": Color.WHITE, "tooltip": SOURCE_TOOLTIP})
	var anchored: Array[Dictionary] = _engine.ManeuverRules.player_badges({"self_flags": {"anchored": {}}})
	for badge: Dictionary in anchored:
		badge["tooltip"] = "Anchored: the wind does not move it."
		badge["status_class"] = "trait"
	badges.append_array(anchored)
	return badges

static func damage_texts(scene: Control, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = scene._floating_texts_for_step(step)
	result.append_array(scene._floating_texts_for_target_losses(step.get("enemy_losses", [])))
	return result

static func direction_name(axis: Vector2i) -> String:
	return str(DIRECTION_NAMES.get(axis, ""))

# The wind chip became the battlefield rule panel (el-04). Older callers, such as the
# bound Seer cutout actions, refresh the panel through this name.
static func refresh_chip(scene: Control, display_state: Dictionary = {}) -> void:
	scene._refresh_battlefield_rule_hud(display_state)

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var before: Dictionary = step.get("en02_state_before", state).duplicate(true)
	var after: Dictionary = step["en02_state_after"]
	# Both room Headwind and a caller's Gust arrive here before the defeat
	# wrapper. Own synchronous arrival Bursts before submitting resolved Health.
	scene._burst_playback.prepare(before, after)
	if str(step["en02_mechanic"]) == "wind_push":
		var value: Dictionary = before.get("wind", {})
		var reduced: bool = scene._reduced_motion_enabled()
		scene._play_sfx(Sfx.entry_for_enemy_step(step))
		await scene._play_timed_animation_frames(1 if reduced else scene.MOVE_STEP_FRAMES, 0.0 if reduced else scene.MOVE_FRAME_SECONDS, func(frame: int) -> void:
			var progress: float = 1.0 if reduced else float(frame) / float(scene.MOVE_STEP_FRAMES)
			var positions: Dictionary = {}
			for actor: Dictionary in Wind.actors(before, value["direction"]):
				var key: String = _engine._surface_actor_key(str(actor["kind"]), int(actor["id"]))
				var start: Vector2 = scene.board_view._tile_center(actor["unit"]["pos"])
				var finish: Vector2 = scene.board_view._tile_center(_engine._surface_actor(after, str(actor["kind"]), int(actor["id"])).get("pos", actor["unit"]["pos"]))
				positions[key] = start.lerp(finish, progress)
			scene._render_board_state(before, {"effect": step, "effect_progress": progress, "unit_world_positions": positions}))
	state.clear()
	state.merge(after.duplicate(true), true)
	scene._render_board_state(state, {})
	scene._refresh_battlefield_rule_hud(state)
	var feedback_step: Dictionary = preload("res://scripts/enemy_mechanics/burst_playback.gd").without_burst_losses(_engine, step, before, after)
	var feedback: Array[Dictionary] = damage_texts(scene, feedback_step)
	if not feedback.is_empty(): await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, {"floating_texts": feedback}))
	await scene._animate_turn_order_alongside_defeats(before, state)

static func animate_room_completion(scene: Control, before: Dictionary, after: Dictionary) -> bool:
	if not Wind.room_sourced(before, before.get("wind", {})) or before == after: return false
	var step: Dictionary = Wind.animation_step(_engine, before, after, -1, {"type": "wind_push"})
	step["en02_state_before"] = before
	await animate(scene, before.duplicate(true), step)
	return true
