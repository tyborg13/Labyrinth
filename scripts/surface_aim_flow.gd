extends RefCounted

## Selection state only. The combat engine owns legality, previews and spending.
const Surface = preload("res://scripts/board_surface_rules.gd")
const INVALID := Vector2i(-1, -1)
var skill_id: String = ""
var relocating: bool = false
var kind: String = "fire"
var origin: Vector2i = INVALID

func active() -> bool:
	return not skill_id.is_empty()

func begin(id: String, relocation: bool) -> void:
	skill_id = id
	relocating = relocation
	kind = "elemental" if relocation else "fire"
	origin = INVALID

func cancel() -> void:
	skill_id = ""
	origin = INVALID

func choose(value: String) -> void:
	kind = value
	origin = INVALID

func instruction() -> String:
	if not relocating:
		return "PRISMATIC INSTINCT · PLACE %s" % kind.to_upper()
	return "CONFLUENCE · CHOOSE A DESTINATION" if origin != INVALID else "CONFLUENCE · CHOOSE %s GROUND TO MOVE" % kind.to_upper()

func action() -> Dictionary:
	return {"type": "surface", "surface": kind, "range": 4}

func targets(engine: RefCounted, state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var player: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var visible: Array = engine.call("umbra_visible_tiles", state) as Array
	var grid: Array = state.get("grid", []) as Array
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile := Vector2i(x, y)
			if absi(tile.x - player.x) + absi(tile.y - player.y) > 4: continue
			if not visible.is_empty() and not visible.has(tile): continue
			if relocating and origin == INVALID:
				if kind == "rubble" and Surface.has_rubble(state, tile): result.append(tile)
				elif kind == "elemental" and not Surface.element_at(state, tile).is_empty(): result.append(tile)
			else:
				var next: Dictionary = resolved(engine, state, tile)
				if next != state: result.append(tile)
	return result

func resolved(engine: RefCounted, state: Dictionary, tile: Vector2i) -> Dictionary:
	if not active(): return state
	if relocating:
		if origin == INVALID: return state
		var source_kind: String = Surface.element_at(state, origin) if kind == "elemental" else kind
		return engine.call("use_surface_skill", state, skill_id, source_kind, tile, origin) as Dictionary
	return engine.call("use_surface_skill", state, skill_id, kind, tile) as Dictionary

func pick(engine: RefCounted, state: Dictionary, tile: Vector2i) -> Dictionary:
	if not targets(engine, state).has(tile): return {}
	if relocating and origin == INVALID:
		origin = tile
		return {"selecting": true}
	var next: Dictionary = resolved(engine, state, tile)
	return {"state": next, "skill_id": skill_id} if next != state else {}
