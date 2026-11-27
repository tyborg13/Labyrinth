extends RefCounted
## Bind state changes to their retained painter. State changes alone only
## identify candidates. An already-known Light source cannot start a new strip.

const Bounds = preload("res://tools/fel10/draw_bounds.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Pops = preload("res://scripts/status_pop_tracker.gd")
const Game = preload("res://scripts/game_data.gd")
const SURFACES := ["fire", "ice", "electrified", "rubble"]
const INVALID := Vector2i(-1, -1)

var _light_known: Dictionary
var _lights: Dictionary
var _surface_known: Dictionary
var _surfaces: Dictionary
var _badge_counts: Dictionary
var _unit_ids: Dictionary


func reset(board: Control) -> void:
	_light_known = _placed_lights(board)
	_lights = {}
	_surface_known = _surface_tiles(board)
	_surfaces = {}
	_badge_counts = {}
	_unit_ids = _enemies(board)


func sample(scene: Node, emit: Callable) -> void:
	var board: Control = scene.board_view
	_sample_lights(scene, board, emit)
	_sample_surfaces(board, emit)
	_sample_badges(board, emit)
	_sample_split(board, emit)


func _sample_lights(scene: Node, board: Control, emit: Callable) -> void:
	var placed: Dictionary = _placed_lights(board)
	var marker: Control = board._foreground_render_layer
	if not is_instance_valid(marker) or not marker.is_visible_in_tree(): return
	# Selecting an Illuminate target can paint the candidate state. Observe the
	# placement once the targeting preview has been cleared.
	if not board.presentation.get("board_targeting", false) and scene._selected_card_index < 0:
		for key: String in placed:
			if not _light_known.has(key) or int(placed[key]["radius"]) > int(_light_known[key]["radius"]):
				_lights[key] = true
				_light_known[key] = placed[key]
	for source: Dictionary in marker.presentation.get("umbra_light_sources", []):
		var key: String = str(source.get("id", ""))
		if _lights.has(key) and placed.has(key) and source.get("pos") == placed[key].get("pos"):
			emit.call("light_placement", Bounds.light(marker, source), "drawn Light orb, motes and reach", "light:" + key)


static func _placed_lights(board: Control) -> Dictionary:
	var result: Dictionary = {}
	for source: Dictionary in board.combat_state.get("umbra", {}).get("light_sources", []):
		if source.get("owner") != "player" or not source.has("id") or source.get("pos", INVALID) == INVALID: continue
		result[str(source["id"])] = source.duplicate()
	return result


func _sample_surfaces(board: Control, emit: Callable) -> void:
	var next: Dictionary = _surface_tiles(board)
	var ground: Node2D = board._pixel_ground
	if not is_instance_valid(ground) or not ground.is_visible_in_tree():
		_surface_known = next
		return
	for kind: String in SURFACES:
		for tile: Vector2i in next[kind]:
			if not _surface_known[kind].has(tile):
				_surfaces["%s:%s" % [kind, tile]] = [kind, tile]
	_surface_known = next
	for key: String in _surfaces.keys():
		var pair: Array = _surfaces[key]
		var kind: String = pair[0]
		var tile: Vector2i = pair[1]
		if not tile in next[kind]:
			_surfaces.erase(key)
			continue
		if not ground.field.tiles.has(tile): continue
		var rect: Rect2 = Bounds.screen(board, Bounds.points(board._tile_polygon(tile)))
		if kind in ["fire", "electrified"]:
			for depth: int in 2:
				var stamp: Node2D = ground.sheet.stamps.get(Vector3i(tile.x, tile.y, depth))
				if is_instance_valid(stamp) and stamp.is_visible_in_tree():
					rect = rect.merge(Bounds.screen(stamp, stamp._cull_bounds))
		emit.call("surface_" + kind, rect, "live surface field and depth stamps", "ground:" + key)


static func _surface_tiles(board: Control) -> Dictionary:
	var result: Dictionary = {}
	for kind: String in SURFACES: result[kind] = Surfaces.tiles(board.combat_state, kind)
	return result


func _sample_badges(board: Control, emit: Callable) -> void:
	var hud: Control = board._hud_render_layer
	if not is_instance_valid(hud) or not hud.is_visible_in_tree(): return
	var now: Dictionary = {}
	for unit: Dictionary in board._visible_units_cache:
		var actor: String = str(unit.get("key", ""))
		var health: Rect2 = board._hud_health_rects_cache.get(actor, Rect2())
		if not health.has_area(): continue
		var entries: Array = board._unit_status_pill_entries(unit, health)
		entries.append_array(board._unit_defense_plate_entries(unit, health))
		for entry: Dictionary in entries:
			var icon: String = str(entry.get("icon", ""))
			if icon not in ["expose", "shock", "immobilize", "stoneskin", "frost_armor", "kindle"]: continue
			if entry.get("predicted", false) or entry.get("hud_forecast", false): continue
			var status: String = "kindled_bonus" if icon == "kindle" else icon
			var key: String = actor + "|" + icon
			var count: int = int(unit.get(status, entry.get("label", "1")))
			var old: int = _badge_counts.get(key, count)
			now[key] = count
			var progress: float = board.status_pop_tracker.progress(actor, icon)
			var rect: Rect2 = entry["rect"]
			if progress >= 0.0:
				var size: Vector2 = rect.size * Pops.pill_scale(progress)
				rect = Rect2(rect.get_center() - size * 0.5, size)
				emit.call("status_" + status + "_gain", Bounds.screen(hud, rect), "popping status plate", key)
			elif count < old:
				emit.call("status_" + status + "_tick", Bounds.screen(hud, rect), "updated status plate count", key)
	_badge_counts = now


func _sample_split(board: Control, emit: Callable) -> void:
	var enemies: Dictionary = _enemies(board)
	var split: Dictionary = {}
	for unit: Dictionary in board.presentation.get("death_animation_units", []):
		var data: Dictionary = Game.enemy_property(str(unit.get("type", "")), "death_spawn", {})
		if not data.is_empty(): split[data.get("enemy_type")] = true
	for unit: Dictionary in board._visible_units_cache:
		var id: int = int(unit.get("id", -1))
		if enemies.has(id) and not _unit_ids.has(id) and split.has(unit.get("type")):
			emit.call("enemy_split", Bounds.screen(board, board._unit_draw_rect(unit)),
				"new split body draw rect", "split:%d" % id)
	_unit_ids = enemies


static func _enemies(board: Control) -> Dictionary:
	var result: Dictionary = {}
	for unit: Dictionary in board.combat_state.get("enemies", []): result[int(unit["id"])] = true
	return result
