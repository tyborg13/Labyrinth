extends RefCounted
## Source samples depend only on the renderer, its gear and the attack's
## facing, so a loadout samples each direction once (a few ms) instead of on
## every attack. Board projection is resolved afresh after zoom/layout edits.
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
var _cache: Dictionary = {}
var _cache_owner: Array = []
var sample_build_count: int = 0

static func handles(effect: Dictionary) -> bool:
	var kind: String = str(effect.get("kind", ""))
	return (kind in ["melee", "aoe"] and bool(effect.get("protagonist_melee", false))) or (kind == "melee" and bool(effect.get("illusion_echo", false)))

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
	var previous_progress: float = -1.0
	if bool(effect.get("illusion_echo", false)):
		kind = "arc"
		window = Vector2(0.33, 0.56)
		samples = Trail.arc_samples(board.world_position_for_tile(from_tile), board.world_position_for_tile(to_tile), scale, window)
	else:
		var renderer: Node = board.get("_protagonist_renderer")
		if not is_instance_valid(renderer):
			return empty
		# RunScene remaps area attack progress before presenting the body. Sample
		# that same attack timeline; .42 remains contact in clip input space.
		var body_motion: Dictionary = board.presentation.get("protagonist_motion", {})
		previous_progress = previous_attack_progress(effect, progress)
		progress = float(body_motion.get("phase", progress))
		var source_samples: Array[Dictionary] = _source_samples(renderer, motion, window)
		if source_samples.is_empty() or Trail.envelope(progress, window) <= 0.0:
			return empty
		var unit: Dictionary = {"type": "player", "role": "player", "key": "player", "pos": from_tile}
		var body: Rect2 = board.call("_unit_draw_rect_for_center", unit, board.world_position_for_tile(from_tile))
		for sample: Dictionary in source_samples:
			samples.append({"progress": sample["progress"], "tip": body.position + (sample["tip"] as Vector2) * body.size / 255.0,
				"inner": body.position + (sample["inner"] as Vector2) * body.size / 255.0})
	var seed: int = int(effect.get("seed", _effect_seed(effect)))
	return Trail.geometry(samples, kind, progress, Trail.CONTACT, window, str(effect.get("element", "none")), scale, seed, settings["length"], previous_progress)

static func _effect_seed(effect: Dictionary) -> int:
	# Sampling metadata must not change the existing deterministic sparks.
	if not effect.has("protagonist_melee_frames"): return hash(effect)
	var seed_effect: Dictionary = effect.duplicate(false)
	seed_effect.erase("protagonist_melee_frames")
	return hash(seed_effect)

static func previous_attack_progress(effect: Dictionary, progress: float) -> float:
	var frames: int = int(effect.get("protagonist_melee_frames", 0))
	if frames <= 0 or str(effect.get("kind", "")) != "aoe" or effect.get("from") != effect.get("to"): return -1.0
	# Integrate the path traversed since the previous displayed body pose. A
	# six-frame area delivery otherwise skips the entire .42 contact exposure.
	var prior: float = maxf(0.0, progress - 1.0 / float(frames))
	var contact: float = preload("res://scripts/attack_fx_library.gd").feedback_start_progress(effect)
	return Trail.CONTACT * prior / contact if prior <= contact else Trail.CONTACT + (1.0 - Trail.CONTACT) * (prior - contact) / (1.0 - contact)

func _source_samples(renderer: Node, motion: String, window: Vector2) -> Array[Dictionary]:
	var owner: Array = [renderer.get_instance_id(), int(renderer.get("_gear_revision"))]
	if owner != _cache_owner:
		_cache.clear()
		_cache_owner = owner
	var direction: Dictionary = {"facing": renderer.get("facing"), "mirrored": renderer.get("mirrored")}
	var key: String = "%s|%s|%s" % [direction["facing"], direction["mirrored"], motion]
	if _cache.has(key):
		return TypedArrays.dictionaries(_cache[key])
	var samples: Array[Dictionary] = renderer.strike_samples(Vector2i.ZERO, window.x, window.y, Trail.SAMPLE_STEP, float(Trail.motion_settings(motion)["reach"]))
	sample_build_count += 1
	# A renderer without rigs yields nothing; never pin that for the effect.
	if not samples.is_empty():
		_cache[key] = samples
	return samples
