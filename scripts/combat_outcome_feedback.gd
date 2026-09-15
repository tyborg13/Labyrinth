extends RefCounted

# These are resolved outcomes, never extra attacks or mutations of combat state.
const Fx = preload("res://scripts/attack_fx_library.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const INVALID := Vector2i(-1,-1)

static func element(event: Dictionary) -> String:
	match str(event.get("kind", "")):
		"terrain_created": return "earth"
		"surface_conducted": return "lightning"
		"surface_created", "surface_replaced", "surface_damage", "status_applied":
			match str(event.get("surface", "")):
				"rubble": return "earth"
				"electrified": return "lightning"
				"fire", "ice": return str(event["surface"])
	return ""

static func prepare(events: Array, primary: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var seen: Dictionary = {}
	# The primary projectile/area renderer places its elemental core at `to`.
	# Conduction and painted area cells beyond that center need their own impact.
	var primary_tiles: Array = []
	if Fx.uses_authored_elemental_attack(primary) and primary.has("to"): primary_tiles.append(primary["to"])
	for original: Dictionary in events:
		var event: Dictionary = original.duplicate(true)
		var id: String = element(event)
		var tile: Vector2i = event.get("tile", INVALID)
		var key: String = "%s:%s" % [tile,id]
		var primary_covers: bool = id == str(primary.get("element", "")) and primary_tiles.has(tile)
		event["feedback_element"] = id if not seen.has(key) and not primary_covers else ""
		if not id.is_empty(): seen[key] = true
		result.append(event)
	return result

static func sounds(events: Array, primary_element: String = "", traps: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var seen: Dictionary = {primary_element:true}
	for trap: Dictionary in traps: seen[str(trap.get("element",""))] = true
	for event: Dictionary in events:
		var id: String = element(event)
		if id.is_empty() or seen.has(id): continue
		seen[id] = true
		result.append(Sfx.entry_for_trap({"element":id}))
	return result

static func outcrop_progress(events: Array, terrain_id: String, progress: float, reduced: bool) -> float:
	if reduced: return 1.0
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "terrain_created" and str(event.get("terrain_id", "")) == terrain_id:
			return smoothstep(0.0,0.85,progress)
	return 1.0

static func sound_element(entry: Dictionary) -> String:
	var id: String = str(entry.get("id", ""))
	return id.trim_prefix("attack.elemental.") if id.begins_with("attack.elemental.") else ""
