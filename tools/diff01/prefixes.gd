extends RefCounted
## Reachable fight numbers on the production DAG, without inventing a route.
## Each k retains one actual incoming direction witnessing that prefix count.
const Plan = preload("res://tools/diff01/plan.gd")

static func cases(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for section: int in range(6):
		var nodes: Array[Dictionary]
		var lookup: Dictionary = {}
		for room: Dictionary in state["rooms"].values():
			if int(room.get("section_index", -1)) != section: continue
			nodes.append(room)
			lookup[str(room["coord"])] = room
		nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["map_step"]) < int(b["map_step"]) if int(a["map_step"]) != int(b["map_step"]) else float(a["map_lane"]) < float(b["map_lane"]))
		var prefixes: Dictionary = {}
		for room: Dictionary in nodes:
			var key: String = str(room["coord"])
			if int(room["map_step"]) == 0: prefixes[key] = {0: Plan.FALLBACK_TRAVEL_DIRECTION}
			assert(prefixes.has(key), "Native graph node needs an incoming prefix")
			var values: Dictionary = prefixes[key]
			var counters: Array = values.keys()
			counters.sort()
			var room_cases: Array[Dictionary]
			for before: int in counters:
				room_cases.append({"scenario": "native_prefix", "fight_number": before + 1, "travel": values[before]})
			result[key] = room_cases
			var fight: bool = str(room["type"]) in ["combat", "special", "guardian"] or (str(room["type"]) == "mystery" and str(room.get("mystery_type", "")) == "combat")
			for link: Dictionary in room.get("connections", []):
				var target: String = str(link["coord"])
				if not lookup.has(target): continue
				assert(int(lookup[target]["map_step"]) > int(room["map_step"]), "Section map must be a DAG")
				if not prefixes.has(target): prefixes[target] = {}
				for before: int in counters:
					var after: int = before + int(fight)
					if not prefixes[target].has(after): prefixes[target][after] = link["door_dir"]
	return result
