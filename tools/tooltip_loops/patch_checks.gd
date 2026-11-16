extends RefCounted
## Recording/rehearsal geometry uses the same board placement as the renderer.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const SpriteMargin = preload("res://tools/tooltip_loops/sprite_margin.gd")
const UpheavalChecks = preload("res://tools/tooltip_loops/tip05_checks.gd")
const TerrainChecks = preload("res://tools/tooltip_loops/terrain_checks.gd")
var upheaval := UpheavalChecks.new()
var terrain := TerrainChecks.new()
const PATCH := Rect2i(0, 0, 4, 3)
var failures: Array[String]
var droplet_rects: Dictionary = {}
var droplet_frames: int = 0
var samples: int = 0
var sprite_margins: Dictionary = {}
var shadow_ghost_seen: bool = false
var shadow_blink_seen: bool = false
var shadow_arrival_seen: bool = false

static func tiles(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var errors: Array[String]
	var states: Array[Dictionary]
	states.append(fixture["state"])
	states.append(result["final"])
	for beat: Dictionary in result["beats"]:
		states.append(beat["before"])
		states.append(beat["after"])
	for state: Dictionary in states:
		var actors: Array[Dictionary]
		actors.append(state["player"])
		actors.append_array(state.get("enemies", []))
		actors.append_array(state.get("illusions", []))
		for actor: Dictionary in actors:
			for tile: Vector2i in Surfaces.footprint_tiles(actor):
				if not PATCH.has_point(tile):
					var message: String = "%s: unit %s start/end footprint leaves patch at %s" % [fixture["id"], actor.get("id", "hero"), tile]
					if not errors.has(message): errors.append(message)
	return errors

static func screen_rect(board: Control, unit: Dictionary) -> Rect2:
	return board.get_global_transform_with_canvas() * board._unit_draw_rect_for_center(unit, board._unit_center(unit))

func _fail(message: String) -> void:
	if not failures.has(message): failures.append(message)

func observe(board: Control, crop: Rect2i, id: String) -> void:
	samples += 1
	terrain.observe(board, crop)
	if id == "rule_upheaval": upheaval.observe(board, samples, failures)
	var units: Array[Dictionary] = board._visible_units()
	var hero := Rect2()
	var droplets: Array[Dictionary]
	for unit: Dictionary in units:
		var sprite: Rect2 = SpriteMargin.screen_rect(board, unit)
		var key: String = str(unit.get("key", unit.get("type", "unit")))
		# A buried or fully dissolved actor has no submitted paint to frame.
		if sprite.has_area():
			var margin: float = SpriteMargin.margin(sprite, crop)
			if not sprite_margins.has(key) or margin < float(sprite_margins[key]["minimum_px"]): sprite_margins[key] = {"minimum_px": margin, "rect": var_to_str(sprite), "sample": samples, "type": unit.get("type", "")}
			if margin < SpriteMargin.REQUIRED_PIXELS: _fail("%s: sprite %s lacks 4 px frame margin" % [id, key])
		if unit.get("role") == "player": hero = screen_rect(board, unit)
		if unit.get("type") == "cinder_droplet" and unit.get("role") == "enemy": droplets.append(unit)
		if id == "rule_shadowstep":
			if unit.get("type") == "umbra_shade" and unit.get("role") == "enemy_move_preview":
				var tile: Vector2i = unit["pos"]
				var hero_tile: Vector2i = board.combat_state["player"]["pos"]
				if absi(tile.x - hero_tile.x) + absi(tile.y - hero_tile.y) != 2: _fail("Shadowstep ghost must warn on a landing 2 tiles from the hero")
				shadow_ghost_seen = true
			if unit.get("role") == "enemy": shadow_arrival_seen = true
	if id == "rule_shadowstep" and samples == 1 and (not shadow_ghost_seen or shadow_arrival_seen): _fail("Shadowstep must start with the ghost and a hidden enemy body")
	if id == "rule_shadowstep" and board.presentation.get("effect", {}).get("kind") == "blink": shadow_blink_seen = true
	if id != "splits_cinder_ooze": return
	if droplets.is_empty():
		if droplet_frames > 0: _fail("Both Droplets must stay drawn from spawn to loop end")
		return
	droplet_frames += 1
	if droplets.size() != 2: _fail("Splits must draw both Droplets from first spawn through the end")
	for unit: Dictionary in droplets:
		var rect: Rect2 = screen_rect(board, unit)
		if not Rect2(crop).encloses(rect): _fail("Droplet screen rect leaves the capture patch: " + str(unit["key"]))
		if hero.intersects(rect): _fail("Droplet screen rect overlaps the hero: " + str(unit["key"]))
		droplet_rects[str(unit["key"])] = {"tile": str(unit["pos"]), "rect": var_to_str(rect), "hero_rect": var_to_str(hero), "inside_patch": Rect2(crop).encloses(rect), "hero_overlap": hero.intersects(rect)}

func drawn_floor(board: Control, state: Dictionary, id: String, boundary: String) -> void:
	var drawn: Array[Vector2i] = board._rendered_tiles_in_draw_order()
	var actors: Array[Dictionary]
	actors.append(state["player"])
	actors.append_array(state.get("enemies", []))
	for actor: Dictionary in actors:
		for tile: Vector2i in Surfaces.footprint_tiles(actor):
			if not PATCH.has_point(tile) or not drawn.has(tile) or not board._tile_drawn_as_floor(state["grid"], tile):
				_fail("%s: unit %s %s tile %s must have drawn patch floor" % [id, actor.get("id", "hero"), boundary, tile])

func finish(id: String) -> Dictionary:
	if id == "splits_cinder_ooze" and droplet_rects.size() != 2: _fail("Both real Droplets must be observed on screen")
	if id == "rule_shadowstep" and not (shadow_ghost_seen and shadow_blink_seen and shadow_arrival_seen): _fail("Shadowstep must show the production ghost, Blink and revealed arrival")
	return {"samples": samples, "sprite_margins": sprite_margins, "required_margin_px": SpriteMargin.REQUIRED_PIXELS, "filter_pad_px": SpriteMargin.FILTER_PAD_PIXELS, "droplet_frames": droplet_frames, "droplets": droplet_rects, "shadow_ghost_seen": shadow_ghost_seen, "shadow_blink_seen": shadow_blink_seen, "shadow_arrival_seen": shadow_arrival_seen, "failures": failures}
