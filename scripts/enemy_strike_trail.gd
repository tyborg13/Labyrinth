extends RefCounted
## Cache authored and resolved source points per motion/facing. Projection follows
## camera/floor registration changes; area rakes stay in each target depth layer.
const Points = preload("res://scripts/enemy_strike_points.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Wind = preload("res://scripts/vaeloryx_cutout/wind_feedback.gd")
const Geometry = preload("res://scripts/enemy_strike_geometry.gd")
const SourceCache = preload("res://scripts/enemy_strike_cache.gd")
const ClawMarks = preload("res://scripts/enemy_claw_marks.gd")
var _source_cache: RefCounted = SourceCache.new()
var resolved: Dictionary = {}
var sample_build_count: int:
	get: return _source_cache.sample_build_count
var resolution_build_count: int:
	get: return _source_cache.resolution_build_count

static func actor(board: Control, effect: Dictionary) -> Dictionary:
	var key: String = str(effect.get("actor_key", ""))
	for enemy: Dictionary in board.combat_state.get("enemies", []):
		if key == "enemy_%d" % int(enemy.get("id", -1)):
			var result: Dictionary = enemy.duplicate(false)
			result["key"] = key
			return result
	return {"type":str(effect.get("enemy_type", "")), "key":key, "pos":effect.get("from", Vector2i.ZERO)}

static func handles(board: Control, effect: Dictionary) -> bool:
	return not _context(board,effect).is_empty()

static func _context(board: Control, effect: Dictionary) -> Dictionary:
	if bool(effect.get("protagonist_melee",false)) or bool(effect.get("illusion_echo",false)) or bool(effect.get("preview",false)):
		return {}
	var kind: String = str(effect.get("kind",""))
	if kind not in ["melee","aoe","push","pull"]: return {}
	if kind in ["push","pull"]:
		var from: Vector2i = effect.get("umbra_original_from",effect.get("from",Vector2i(-1,-1)))
		var to: Vector2i = effect.get("umbra_original_to",effect.get("to",Vector2i(-1,-1)))
		if from.x < 0 or to.x < 0 or absi(to.x-from.x)+absi(to.y-from.y) > 1 or Wind.handles(effect): return {}
	var source: Dictionary = actor(board,effect)
	var settings: Dictionary = Points.settings(str(source["type"]),effect)
	if str(settings["kind"]) == "bespoke" or (kind == "aoe" and (kind not in settings["actions"] or physical_area(effect))): return {}
	return {"actor":source,"settings":settings}

static func physical_area(effect: Dictionary) -> bool:
	return str(effect.get("kind", "")) == "aoe" and str(Dragon.profile(effect).get("geometry", "")) == "physical" and str(effect.get("enemy_type", "")) != "vyraketh"

func prepare(board: Control, effect: Dictionary, progress: float) -> Array[Dictionary]:
	var empty: Array[Dictionary]
	resolved = {}
	if bool(board.presentation.get("reduced_motion",false)): return empty
	var context: Dictionary = _context(board,effect)
	if context.is_empty(): return empty
	var source: Dictionary = context["actor"]
	var settings: Dictionary = context["settings"]
	var boundary: float = Points.contact(effect)
	var window: Vector2 = Points.window_for(settings,boundary)
	settings["window"] = window
	var kind: String = settings["kind"]
	var preliminary: Vector2 = window
	if kind == "arc": preliminary = Geometry.ARC_WINDOW
	elif kind == "rake": preliminary.x = 0.36
	# A short sweep can use the arc window. Gate their union before sampling,
	# then gate the exact resolved window below, including held-contact arcs.
	elif kind == "sweep": preliminary = Vector2(minf(window.x,Geometry.ARC_WINDOW.x),maxf(window.y,Geometry.ARC_WINDOW.y))
	if Trail.envelope(progress,preliminary,Trail.CONTACT if kind == "arc" else boundary) <= 0.0: return empty
	var from: Vector2i = effect.get("from",Vector2i(-1,-1))
	var to: Vector2i = effect.get("to",Vector2i(-1,-1))
	if from.x < 0 or to.x < 0: return empty
	var scale: float = Geometry.size_scale(board,source)
	var renderer: Node = board.unit_cutout_renderer(source)
	var samples: Array[Dictionary]
	if kind == "arc" or not is_instance_valid(renderer):
		kind = "arc"
		samples = Geometry.target_arc_samples(board.world_position_for_tile(from),board.world_position_for_tile(to),scale)
		resolved = {"kind":kind,"fallback":false}
	else:
		var delta: Vector2i = Points.direction(effect,source,board.combat_state.get("player",{}).get("pos",to))
		var entry_value: Dictionary = _source_cache.entry(renderer,source,effect,delta,settings,boundary)
		if entry_value.is_empty(): return empty
		var body: Rect2 = board.call("_unit_draw_rect_for_center",source,board.call("_unit_center",source))
		var unit_scale: float = body.size.x/255.0
		var source_result: Dictionary = _source_cache.resolve_entry(entry_value,settings,boundary,scale/unit_scale,
			(target_center(board,to)-body.position)/unit_scale,float(board.call("_tile_width"))/unit_scale)
		kind = source_result["kind"]
		if kind == "claw_marks": window.x = 0.36
		if kind == "arc": window = Geometry.ARC_WINDOW
		if Trail.envelope(progress,window,Trail.CONTACT if kind == "arc" else boundary) <= 0.0: return empty
		resolved = _source_cache.project(entry_value,source_result,body,board.world_position_for_tile(from),board.world_position_for_tile(to),scale)
		samples = resolved["samples"]
	if kind == "arc":
		boundary = Trail.CONTACT
		window = Geometry.ARC_WINDOW
	resolved["window"] = window
	resolved["visual_contact"] = boundary
	return Trail.geometry(samples,kind,progress,boundary,window,str(effect.get("element","none")),scale,
		int(effect.get("seed",hash(effect))),float(settings.get("length",48.0)))

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
	if not physical_area(effect) or not Dragon.tiles(effect).has(tile): return empty
	var source: Dictionary = actor(board, effect)
	var scale: float = Geometry.size_scale(board, source)
	if bool(board.presentation.get("reduced_motion",false)):
		var anchor: Vector2 = board.world_position_for_tile(tile)-Vector2(0,Trail.ARC_BODY_HEIGHT*scale)
		var direction: Vector2 = board.world_position_for_tile(tile)-board.world_position_for_tile(effect["from"])
		var result: Array[Dictionary]
		for glow: bool in [true,false]:
			result.append(ClawMarks.geometry(anchor,direction,Trail.palette(str(effect.get("element","none"))),1.0,scale,glow,0.44))
		return result
	var window := Vector2(0.30, 0.60)
	if Trail.envelope(progress,window) <= 0.0: return empty
	var samples_value: Array[Dictionary] = Trail.arc_samples(board.world_position_for_tile(effect["from"]), board.world_position_for_tile(tile), scale, window)
	return Trail.geometry(samples_value, "rake", progress, Trail.CONTACT, window, str(effect.get("element", "none")), scale,
		int(effect.get("seed", hash(effect))) ^ (tile.x * 101 + tile.y * 307))
