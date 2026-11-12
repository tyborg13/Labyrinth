extends RefCounted
# Proof route selection, shared by private seed model and independently driven UI.
const Graph = preload("res://scripts/section_map_graph.gd")
const SEARCH_DEPTH_LIMIT: int = 16
const SERVICE_COVERAGE_WEIGHT: float = 100.0
const EVENT_COVERAGE_WEIGHT: float = 100.0
const DRAGON_REACH_WEIGHT: float = 1.0
const OPTIONAL_FIGHT_COST: float = 5.0
const MERCHANT_COST: float = 2.0
const NO_ROUTE_SCORE: float = -1000.0
static func score(state: Dictionary, coord: Vector2i, needs_event: bool, depth: int = 0) -> float:
	if depth > SEARCH_DEPTH_LIMIT: return NO_ROUTE_SCORE
	var room: Dictionary = Graph.room(state, coord)
	var kind: String = str(room.get("mystery_type", "mystery")) if str(room.get("type")) == "mystery" else Graph.display_type(room)
	var value: float = EVENT_COVERAGE_WEIGHT if kind == "event" and needs_event else 0.0
	if kind in ["scavenger", "treasure", "campfire"]:
		var visited: bool = false
		for previous: Dictionary in state.get("rooms", {}).values():
			if str(previous.get("type")) == kind and bool(previous.get("visited", false)): visited = true; break
		if not visited: value += SERVICE_COVERAGE_WEIGHT
	if kind == "boss": return value + DRAGON_REACH_WEIGHT
	if kind in ["guardian", "special"]: value -= OPTIONAL_FIGHT_COST
	if kind in ["scavenger", "graftwright"]: value -= MERCHANT_COST
	var best: float = NO_ROUTE_SCORE
	for link: Dictionary in room.get("connections", []):
		if link.get("kind") != "outward": continue
		if int(Graph.room(state, link["coord"]).get("section_index", 0)) != 0: continue
		best = maxf(best, score(state, link["coord"], needs_event, depth + 1))
	return value + (best if best > NO_ROUTE_SCORE else 0.0)
