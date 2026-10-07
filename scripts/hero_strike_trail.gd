extends RefCounted
## Source samples survive retained-layer redraws and camera changes. Only one
## effect is cached; board projection is resolved afresh after zoom/layout edits.
const Trail = preload("res://scripts/strike_trail_fx.gd")
var _effect: Dictionary = {}
var _gear_revision: int = -1
var _renderer_id: int = 0
var _source_samples: Array[Dictionary]
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
		var revision: int = int(renderer.get("_gear_revision"))
		if _effect != effect or revision != _gear_revision or renderer.get_instance_id() != _renderer_id:
			_effect = effect.duplicate(true)
			_gear_revision = revision
			_renderer_id = renderer.get_instance_id()
			_source_samples = renderer.strike_samples(to_tile - from_tile, window.x, window.y, Trail.SAMPLE_STEP)
			sample_build_count += 1
		var unit: Dictionary = {"type": "player", "role": "player", "key": "player", "pos": from_tile}
		var body: Rect2 = board.call("_unit_draw_rect_for_center", unit, board.world_position_for_tile(from_tile))
		for sample: Dictionary in _source_samples:
			samples.append({"progress": sample["progress"], "tip": body.position + (sample["tip"] as Vector2) * body.size / 255.0,
				"inner": body.position + (sample["inner"] as Vector2) * body.size / 255.0})
	var seed: int = int(effect.get("seed", hash(effect)))
	return Trail.geometry(samples, kind, progress, Trail.CONTACT, window, str(effect.get("element", "none")), scale, seed, settings["length"])
