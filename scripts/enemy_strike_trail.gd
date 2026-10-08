extends RefCounted
## Cache authored source points once per effect. Projection remains live for
## camera/floor registration changes; area rakes stay in each target depth layer.
const Points = preload("res://scripts/enemy_strike_points.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Wind = preload("res://scripts/vaeloryx_cutout/wind_feedback.gd")
const Geometry = preload("res://scripts/enemy_strike_geometry.gd")
var _effect: Dictionary = {}
var _renderer_id: int = 0
var _samples: Array[Dictionary]
var _source_span: float = 0.0
var _contact_hold_span: float = 0.0
var resolved: Dictionary = {}
var sample_build_count: int = 0

static func actor(board: Control, effect: Dictionary) -> Dictionary:
	var key: String = str(effect.get("actor_key", ""))
	for enemy: Dictionary in board.combat_state.get("enemies", []):
		if key == "enemy_%d" % int(enemy.get("id", -1)):
			var result: Dictionary = enemy.duplicate(false)
			result["key"] = key
			return result
	return {"type":str(effect.get("enemy_type", "")), "key":key, "pos":effect.get("from", Vector2i.ZERO)}

static func handles(board: Control, effect: Dictionary) -> bool:
	if bool(effect.get("protagonist_melee", false)) or bool(effect.get("illusion_echo", false)) or bool(effect.get("preview", false)):
		return false
	var kind: String = str(effect.get("kind", ""))
	if kind in ["push", "pull"]:
		var from: Vector2i = effect.get("umbra_original_from", effect.get("from", Vector2i(-1,-1)))
		var to: Vector2i = effect.get("umbra_original_to", effect.get("to", Vector2i(-1,-1)))
		return from.x >= 0 and to.x >= 0 and absi(to.x-from.x) + absi(to.y-from.y) <= 1 and not Wind.handles(effect)
	var source: Dictionary = actor(board, effect)
	if str(Points.settings(str(source["type"]), effect)["kind"]) == "bespoke": return false
	return kind == "melee" or (kind == "aoe" and kind in Points.settings(str(source["type"]), effect)["actions"] and not physical_area(effect))

static func physical_area(effect: Dictionary) -> bool:
	return str(effect.get("kind", "")) == "aoe" and str(Dragon.profile(effect).get("geometry", "")) == "physical" and str(effect.get("enemy_type", "")) != "vyraketh"

func prepare(board: Control, effect: Dictionary, progress: float) -> Array[Dictionary]:
	var empty: Array[Dictionary]
	resolved = {}
	if not handles(board, effect) or bool(board.presentation.get("reduced_motion", false)):
		return empty
	var source: Dictionary = actor(board, effect)
	var type: String = str(source["type"])
	var settings_value: Dictionary = Points.settings(type, effect)
	var boundary: float = Points.contact(effect)
	var window: Vector2 = Points.window_for(settings_value, boundary)
	settings_value["window"] = window
	var from: Vector2i = effect.get("from", Vector2i(-1,-1))
	var to: Vector2i = effect.get("to", Vector2i(-1,-1))
	if from.x < 0 or to.x < 0: return empty
	var center: Vector2 = board.call("_unit_center", source)
	var body: Rect2 = board.call("_unit_draw_rect_for_center", source, center)
	var scale: float = Geometry.size_scale(board, source)
	var renderer: Node = board.unit_cutout_renderer(source)
	var kind: String = settings_value["kind"]
	var samples_value: Array[Dictionary]
	resolved = {"kind":kind, "fallback":false}
	if kind == "arc" or not is_instance_valid(renderer):
		kind = "arc"
		samples_value = Geometry.target_arc_samples(board.world_position_for_tile(from), board.world_position_for_tile(to), scale)
	else:
		var delta: Vector2i = Points.direction(effect, source, board.combat_state.get("player", {}).get("pos", to))
		if _effect != effect or _renderer_id != renderer.get_instance_id():
			_effect = effect.duplicate(true)
			_renderer_id = renderer.get_instance_id()
			_samples = Points.samples(renderer, source, effect, delta, settings_value, boundary)
			_source_span = Geometry.path_span(_samples)
			if bool(settings_value.get("contact_hold_arc",false)):
				_contact_hold_span = Geometry.path_span(Geometry.window_samples(_samples,Vector2(boundary,minf(boundary + Trail.TAIL,window.y))))
			sample_build_count += 1
		for sample: Dictionary in _samples:
			var tip: Vector2 = body.position + (sample["tip"] as Vector2) * body.size / 255.0
			samples_value.append({"progress":sample["progress"], "tip":tip,
				"inner":tip + ((sample["inner"] as Vector2) - (sample["tip"] as Vector2)) * scale})
		if bool(settings_value.get("contact_hold_arc",false)) and _contact_hold_span * body.size.x / 255.0 < Geometry.SHORT_PATH * scale:
			kind = "arc"
			resolved = {"kind":kind,"fallback":true,"reason":"held_contact","held_span":_contact_hold_span * body.size.x / 255.0,
				"strike_point":Trail.sample_at(samples_value,boundary)["tip"]}
			samples_value = Geometry.target_arc_samples(board.world_position_for_tile(from), board.world_position_for_tile(to), scale)
		else:
			resolved = Geometry.resolve(samples_value, kind, body.get_center(), target_center(board,to), scale, boundary, window, _source_span * body.size.x / 255.0, float(board.call("_tile_width")))
			samples_value = Geometry.samples_for(resolved)
			kind = resolved["kind"]
			if kind == "claw_marks": window.x = 0.36
	if kind == "arc":
		boundary = Trail.CONTACT
		window = Geometry.ARC_WINDOW
	resolved["window"] = window
	resolved["visual_contact"] = boundary
	return Trail.geometry(samples_value, kind, progress, boundary, window, str(effect.get("element", "none")), scale,
		int(effect.get("seed", hash(effect))), float(settings_value.get("length", 48.0)))

static func target_center(board: Control, tile: Vector2i) -> Vector2:
	var player: Dictionary = board.combat_state.get("player", {})
	if player.get("pos", Vector2i(-1,-1)) == tile:
		var unit: Dictionary = player.duplicate(false)
		unit.merge({"type":"player", "key":"player", "role":"player"}, true)
		var body: Rect2 = board.call("_unit_draw_rect_for_center",unit,board.call("_unit_center",unit))
		return body.get_center()
	return board.world_position_for_tile(tile) - Vector2(0,Trail.ARC_BODY_HEIGHT * board.protagonist_source_pixel_scale())

static func area_rake(board: Control, effect: Dictionary, tile: Vector2i, progress: float) -> Array[Dictionary]:
	var empty: Array[Dictionary]
	if not physical_area(effect) or bool(board.presentation.get("reduced_motion", false)) or not Dragon.tiles(effect).has(tile): return empty
	var source: Dictionary = actor(board, effect)
	var scale: float = Geometry.size_scale(board, source)
	var window := Vector2(0.30, 0.60)
	var samples_value: Array[Dictionary] = Trail.arc_samples(board.world_position_for_tile(effect["from"]), board.world_position_for_tile(tile), scale, window)
	return Trail.geometry(samples_value, "rake", progress, Trail.CONTACT, window, str(effect.get("element", "none")), scale,
		int(effect.get("seed", hash(effect))) ^ (tile.x * 101 + tile.y * 307))
