extends RefCounted
## Source samples depend only on the renderer, its gear and the attack's
## facing, so a loadout samples each direction once (a few ms) instead of on
## every attack. Board projection is resolved afresh after zoom/layout edits.
const Trail = preload("res://scripts/strike_trail_fx.gd")
var _cache: Dictionary = {}
var _cache_owner: Array = []
var sample_build_count: int = 0

static func handles(effect: Dictionary) -> bool:
	return str(effect.get("kind", "")) == "melee" and (bool(effect.get("protagonist_melee", false)) or bool(effect.get("illusion_echo", false)))

func prepare(board: Control, effect: Dictionary, progress: float) -> Array[Dictionary]:
	var empty: Array[Dictionary]
	if not handles(effect) or bool(board.presentation.get("reduced_motion", false)):
		return empty
	var from_tile: Vector2i = effect.get("from", Vector2i(-1, -1))
	var to_tile: Vector2i = effect.get("to", Vector2i(-1, -1))
	if from_tile.x < 0 or to_tile.x < 0:
		return empty
	var motion: String = str(effect.get("protagonist_weapon_motion", "sword"))
	var settings: Dictionary = Trail.motion_settings(motion)
	var window: Vector2 = settings["window"]
	var scale: float = board.protagonist_source_pixel_scale()
	var samples: Array[Dictionary]
	var kind: String = settings["kind"]
	if bool(effect.get("illusion_echo", false)):
		kind = "arc"
		window = Vector2(0.33, 0.56)
		samples = Trail.arc_samples(board.world_position_for_tile(from_tile), board.world_position_for_tile(to_tile), scale, window)
	else:
		var renderer: Node = board.get("_protagonist_renderer")
		if not is_instance_valid(renderer):
			return empty
		var source_samples: Array[Dictionary] = _source_samples(renderer, to_tile - from_tile, motion, window)
		if source_samples.is_empty() or Trail.envelope(progress, window) <= 0.0:
			return empty
		var unit: Dictionary = {"type": "player", "role": "player", "key": "player", "pos": from_tile}
		var body: Rect2 = board.call("_unit_draw_rect_for_center", unit, board.world_position_for_tile(from_tile))
		for sample: Dictionary in source_samples:
			samples.append({"progress": sample["progress"], "tip": body.position + (sample["tip"] as Vector2) * body.size / 255.0,
				"inner": body.position + (sample["inner"] as Vector2) * body.size / 255.0})
	var seed: int = int(effect.get("seed", hash(effect)))
	return Trail.geometry(samples, kind, progress, Trail.CONTACT, window, str(effect.get("element", "none")), scale, seed, settings["length"])

func _source_samples(renderer: Node, delta: Vector2i, motion: String, window: Vector2) -> Array[Dictionary]:
	var owner: Array = [renderer.get_instance_id(), int(renderer.get("_gear_revision"))]
	if owner != _cache_owner:
		_cache.clear()
		_cache_owner = owner
	var direction: Dictionary = renderer.direction_for_delta(delta)
	var key: String = "%s|%s|%s" % [direction["facing"], direction["mirrored"], motion]
	if _cache.has(key):
		return _cache[key]
	var samples: Array[Dictionary] = renderer.strike_samples(delta, window.x, window.y, Trail.SAMPLE_STEP, float(Trail.motion_settings(motion)["reach"]))
	sample_build_count += 1
	# A renderer without rigs yields nothing; never pin that for the effect.
	if not samples.is_empty():
		_cache[key] = samples
	return samples
