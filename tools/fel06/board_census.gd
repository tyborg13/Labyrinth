extends RefCounted
## Read committed contents independently of the hover presentation.

const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Surface = preload("res://scripts/board_surface_presentation.gd")
const Data = preload("res://scripts/game_data.gd")
const Marks = preload("res://tools/fel06/marks.gd")

const CATEGORIES := ["A", "B", "C", "D", "E"]
const MIN_COVERAGE := 0.5
const CRATES := ["wooden_box", "wooden_crate", "crate"]
const STATUS_FIELDS := ["stoneskin", "expose", "freeze", "petrify", "shock", "frost_armor",
	"charge", "kindled_bonus", "reflect", "retaliate", "wind", "chilled", "immobilize",
	"burrowed", "flying", "stagger", "keyword_badges", "statuses"]
const OBJECT_GROUPS := ["terrain", "loot", "traps", "guardian_braziers"]
const UNIT_GROUPS := ["enemies", "illusions", "summons", "allies", "npcs"]


static func center(board: Control, tile: Vector2i) -> Vector2:
	return board.get_global_transform_with_canvas() * (board.call("_tile_center", tile) as Vector2)


static func pick(scene: Node, board: Control, bounds: Rect2) -> Array[Dictionary]:
	var state: Dictionary = scene.get("_combat_state")
	var shown: Dictionary = board.get("presentation")
	var engine: RefCounted = scene.get("_combat_engine")
	var grid: Array = state["grid"]
	var marks: Dictionary = Marks.collect(scene, board, state)
	var covered: Dictionary = _covered_units(board)
	var units: Dictionary = _units_by_tile(board, engine, state)
	var lights: Array = engine.effective_light_sources(state)
	var stage: String = engine.effective_umbra_stage(state)
	var picks: Dictionary = {}
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		if not board.call("_tile_in_grid", grid, tile) or not board.call("_board_tile_is_visible_to_player", tile): continue
		var screen: Vector2 = center(board, tile)
		if not bounds.has_point(screen): continue
		var tile_units: Array = units.get(tile, [])
		var objects: Array = _objects(board, state, shown, tile)
		var surfaces: Array = _surfaces(state, tile)
		var tile_marks: Array = marks.get(tile, [])
		var hidden: Dictionary = covered.get(tile, {})
		var categories := {
			"A": not surfaces.is_empty() and tile_units.is_empty() and objects.is_empty(),
			"B": not tile_units.is_empty() and not surfaces.is_empty(),
			"C": not objects.is_empty(),
			"D": tile_units.is_empty() and tile_marks.any(func(mark: Dictionary) -> bool: return not mark["hazard"]),
			"E": not hidden.is_empty(),
		}
		for category: String in CATEGORIES:
			if not categories[category] or not _in_front(screen, picks.get(category, {})): continue
			picks[category] = {
				"category": category, "tile": tile, "center": screen, "grid": grid[tile.y][tile.x],
				"units": tile_units, "objects": objects, "surfaces": surfaces, "marks": tile_marks,
				"covered": hidden, "light": _light_at(tile, lights),
				"umbra": {"stage": stage, "visible": true, "sight_radius": engine.effective_umbra_radius(state)},
				"other": _other_entries(board, state, shown, tile),
			}
	var result: Array[Dictionary]
	for category: String in CATEGORIES:
		if picks.has(category): result.append(picks[category])
	return result


static func _in_front(screen: Vector2, previous: Dictionary) -> bool:
	if previous.is_empty(): return true
	var other: Vector2 = previous["center"]
	if is_equal_approx(screen.y, other.y): return screen.x < other.x
	return screen.y > other.y


static func _units_by_tile(board: Control, engine: RefCounted, state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var visible: Dictionary = {}
	for unit: Dictionary in board.call("_visible_units"):
		visible[str(unit.get("key", ""))] = unit
	_add_unit(result, engine, state.get("player", {}), "player", "player", visible)
	for group: String in UNIT_GROUPS:
		for unit: Dictionary in state.get(group, []):
			var role: String = {"enemies": "enemy", "illusions": "illusion", "summons": "summon", "allies": "ally", "npcs": "npc"}[group]
			_add_unit(result, engine, unit, "%s_%s" % [role, unit.get("id", "")], role, visible)
	return result


static func _add_unit(result: Dictionary, engine: RefCounted, unit: Dictionary, key: String, role: String, visible: Dictionary) -> void:
	if unit.is_empty() or int(unit.get("hp", 1 if role == "npc" else 0)) <= 0: return
	var rendered: Dictionary = visible.get(key, {})
	var name_value: String = str(rendered.get("name", unit.get("name", "")))
	if name_value.is_empty():
		name_value = str(engine.call("_enemy_display_name", unit)) if role == "enemy" else str(unit.get("type", role)).capitalize()
	var team: String = str(unit.get("team", "enemy" if role == "enemy" else "player" if role != "npc" else "neutral"))
	var statuses: Dictionary = {}
	for field: String in STATUS_FIELDS:
		var value: Variant = unit.get(field)
		if value == null or not value: continue
		statuses[field] = value
	var entry: Dictionary = {"key": key, "name": name_value, "team": team, "role": role,
		"hp": unit.get("hp"), "max_hp": unit.get("max_hp"), "block": unit.get("block", 0),
		"statuses": statuses, "drawn": not rendered.is_empty(), "raw": unit}
	for tile: Vector2i in Ground.footprint_tiles(unit):
		(result.get_or_add(tile, []) as Array).append(entry)


static func _objects(board: Control, state: Dictionary, shown: Dictionary, tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var grid: Array = state["grid"]
	var id: String = board.call("_display_tile_id", str(grid[tile.y][tile.x]), tile)
	if id == "wall" and not board.call("_is_outer_boundary_tile", grid, tile): id = "pillar"
	if id in ["pillar", "door", "wall"]:
		result.append(_object(id, id.capitalize(), "", {"kind": id}))
	for group: String in OBJECT_GROUPS:
		for object: Dictionary in state.get(group, []):
			if object.get("pos") != tile or bool(object.get("claimed", false)): continue
			if group == "terrain" and not Ground.terrain_is_live(object): continue
			var kind: String = str(object.get("kind", group))
			var title: String = ""
			match group:
				"terrain": title = str(board.call("_terrain_tooltip_text", object)).get_slice("\n", 0)
				"traps":
					kind = "trap"
					title = str(board.call("_trap_tooltip_text", object)).get_slice("\n", 0)
				"loot":
					match kind:
						"item": title = str(Data.card_def(str(object.get("card_id", ""))).get("name", ""))
						"equipment": title = str(Data.equipment_def(str(object.get("equipment_id", ""))).get("name", ""))
						"dropped_embers": title = str(board.call("_loot_tooltip_text", object))
				"guardian_braziers": kind = "brazier"
			var name_value: String = str(object.get("name", title if not title.is_empty() else kind.capitalize()))
			result.append(_object(kind, name_value, title, object, group))
	for prop: Dictionary in shown.get("scene_props", []):
		if prop.get("tile") != tile: continue
		var kind: String = str(prop.get("kind", "prop"))
		result.append(_object(kind, str(prop.get("name", kind.capitalize())), "", prop))
	return result


static func _object(kind: String, name_value: String, title: String, raw: Dictionary, group: String = "") -> Dictionary:
	return {"kind": kind, "name": name_value, "title": title, "group": group, "raw": raw}


static func _surfaces(state: Dictionary, tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var raw: Dictionary = Ground.surface_at(state, tile)
	var elemental: String = Ground.element_at(state, tile)
	if not elemental.is_empty():
		result.append({"kind": elemental, "title": Surface.title_for(elemental), "raw": raw})
	if Ground.has_rubble(state, tile):
		result.append({"kind": "rubble", "title": Surface.title_for("rubble"), "raw": raw})
	return result


static func _covered_units(board: Control) -> Dictionary:
	var result: Dictionary = {}
	var silhouettes: Node = board.get("_occlusion_silhouettes")
	var sources: Array = silhouettes.current_sources()
	for index: int in range(sources.size()):
		var unit: Dictionary = sources[index]
		if unit["kind"] != "unit" or not unit.get("eligible", false): continue
		var blockers: Array[Dictionary]
		var identities: Array[Dictionary]
		for later: int in range(index + 1, sources.size()):
			var blocker: Dictionary = sources[later]
			var kind: String = blocker["kind"]
			if kind != "unit" and str(blocker.get("prop_kind", "")) not in ["pillar", "door"] and not (kind == "terrain" and str(blocker["data"].get("kind", "")) in CRATES): continue
			if not (unit["rect"] as Rect2).intersects(blocker["rect"]) or Alpha.coverage(unit, [blocker]) <= 0.0: continue
			blockers.append(blocker)
			var category: String = str(blocker.get("prop_kind", kind))
			var cell: Vector2i = blocker["tile"]
			var actor_key: String = str(blocker.get("key", category)) if kind == "unit" else category
			var reveal_id: String = "unit:" + actor_key if kind == "unit" else "%s:%d,%d" % [category, cell.x, cell.y]
			identities.append({"name": actor_key, "tile": cell, "reveal_id": reveal_id})
		var fraction: float = Alpha.coverage(unit, blockers)
		if fraction < MIN_COVERAGE: continue
		for tile: Vector2i in board.call("_unit_footprint_tiles", unit["data"]):
			var covered: Dictionary = result.get_or_add(tile, {})
			covered[unit["key"]] = {"fraction": fraction, "blockers": identities}
	return result


static func _light_at(tile: Vector2i, sources: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for source: Dictionary in sources:
		var offset: Vector2i = source["pos"] - tile
		if abs(offset.x) + abs(offset.y) <= int(source.get("radius", 0)):
			result.append(source)
	return result


static func _other_entries(board: Control, state: Dictionary, shown: Dictionary, tile: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	var key: String = Ground.tile_key(tile)
	for field: String in ["moss", "objective", "battlefield_rule", "battlefield_rules", "snare_pressure", "wind"]:
		var values: Variant = state.get(field)
		if not values is Dictionary: continue
		var local: Dictionary = _local_fields(values, tile, key)
		if not local.is_empty(): result[field] = local
	var exits: Dictionary = board.get("exit_tiles")
	if exits.has(tile): result["exit"] = true
	for field: String in ["active_door_tiles", "locked_door_tiles", "death_site_embers"]:
		var local: Dictionary = _local_fields(shown.get(field, {}), tile, key)
		if not local.is_empty(): result[field] = local
	return result


static func _local_fields(values: Dictionary, tile: Vector2i, key: String) -> Dictionary:
	for field: String in ["pos", "tile", "target_tile"]:
		if values.get(field) is Vector2i and values[field] == tile: return values
	if values.has(tile): return {"value": values[tile]}
	if values.has(key): return {"value": values[key]}
	var result: Dictionary = {}
	for field: Variant in values:
		var value: Variant = values[field]
		if value is Array:
			var entries: Array = []
			for entry: Variant in value:
				if entry is Vector2i and entry == tile:
					entries.append(entry)
				elif entry is Dictionary:
					var local: Dictionary = _local_fields(entry, tile, key)
					if not local.is_empty(): entries.append(local)
			if not entries.is_empty(): result[field] = entries
		elif value is Dictionary:
			var nested: Dictionary = _local_fields(value, tile, key)
			if not nested.is_empty(): result[field] = nested
	return result
