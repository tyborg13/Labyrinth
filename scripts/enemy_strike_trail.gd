extends RefCounted
## Cache authored source points once per effect. Projection remains live for
## camera/floor registration changes; area rakes stay in each target depth layer.
const Points = preload("res://scripts/enemy_strike_points.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Wind = preload("res://scripts/vaeloryx_cutout/wind_feedback.gd")
var _effect: Dictionary = {}
var _renderer_id: int = 0
var _samples: Array[Dictionary]
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
	var scale: float = body.size.x / 255.0
	var renderer: Node = board.unit_cutout_renderer(source)
	var kind: String = settings_value["kind"]
	var samples_value: Array[Dictionary]
	if kind == "arc" or not is_instance_valid(renderer):
		kind = "arc"
		var original: Dictionary = Points.settings(type, effect)
		samples_value = Trail.arc_samples(board.world_position_for_tile(from), board.world_position_for_tile(to), scale, original["window"])
		for sample: Dictionary in samples_value:
			var time: float = sample["progress"]
			sample["progress"] = time / Trail.CONTACT * boundary if time <= Trail.CONTACT else boundary + (time - Trail.CONTACT) / (1.0 - Trail.CONTACT) * (1.0 - boundary)
	else:
		var delta: Vector2i = Points.direction(effect, source, board.combat_state.get("player", {}).get("pos", to))
		if _effect != effect or _renderer_id != renderer.get_instance_id():
			_effect = effect.duplicate(true)
			_renderer_id = renderer.get_instance_id()
			_samples = Points.samples(renderer, source, effect, delta, settings_value, boundary)
			sample_build_count += 1
		for sample: Dictionary in _samples:
			samples_value.append({"progress":sample["progress"], "tip":body.position + (sample["tip"] as Vector2) * body.size / 255.0,
				"inner":body.position + (sample["inner"] as Vector2) * body.size / 255.0})
	return Trail.geometry(samples_value, kind, progress, boundary, window, str(effect.get("element", "none")), scale,
		int(effect.get("seed", hash(effect))), float(settings_value.get("length", 48.0)))

static func area_rake(board: Control, effect: Dictionary, tile: Vector2i, progress: float) -> Array[Dictionary]:
	var empty: Array[Dictionary]
	if not physical_area(effect) or bool(board.presentation.get("reduced_motion", false)) or not Dragon.tiles(effect).has(tile): return empty
	var source: Dictionary = actor(board, effect)
	var body: Rect2 = board.call("_unit_draw_rect_for_center", source, board.world_position_for_tile(effect["from"]))
	var scale: float = body.size.x / 255.0
	var window := Vector2(0.30, 0.60)
	var samples_value: Array[Dictionary] = Trail.arc_samples(board.world_position_for_tile(effect["from"]), board.world_position_for_tile(tile), scale, window)
	return Trail.geometry(samples_value, "rake", progress, Trail.CONTACT, window, str(effect.get("element", "none")), scale,
		int(effect.get("seed", hash(effect))) ^ (tile.x * 101 + tile.y * 307))
