extends RefCounted

## Draw-owned cache: callers can replace dictionaries or mutate them in place.
## Compare value snapshots rather than object identity or a hash alone. Nothing
## is prepared until the visible ink canvas asks for its layers or a trail.
const Graph = preload("res://scripts/section_map_graph.gd")
var _graph_inputs: Array = []
var _state_revision: int = 0
var _current: Vector2i = Graph.INVALID
var _section: int = -1
var _descendants: Dictionary = {}
var _layer_inputs: Array = []
var _layers: Dictionary = {}
var _trails: Dictionary = {}

func layers_for(state: Dictionary, positions: Dictionary, section: int, selected: Vector2i) -> Dictionary:
	# Descendants can cross rooms outside positions (including unrevealed ones).
	# Keep every dependency used by Graph.descendants and link classification,
	# preserving connection order, without copying unrelated combat/save data.
	var graph_inputs: Array = []
	var rooms: Dictionary = state.get("rooms", {})
	for key: Variant in rooms:
		var node: Dictionary = rooms[key]
		var targets: Array = []
		for link: Dictionary in node.get("connections", []):
			targets.append(link.get("coord", Graph.INVALID))
		graph_inputs.append([key, node.has("section_index"), node.get("section_index", -2), bool(node.get("visited", false)), targets])
	var current: Vector2i = state.get("current_room", Graph.INVALID)
	if graph_inputs != _graph_inputs or current != _current or section != _section:
		_graph_inputs = graph_inputs
		_state_revision += 1
		_current = current
		_descendants.clear()
		_layer_inputs.clear()
	if section != _section:
		_section = section
		_trails.clear()
	var layer_inputs: Array = [_state_revision, current, selected, positions.keys()]
	if layer_inputs == _layer_inputs:
		return _layers
	if not _descendants.has(current):
		_descendants[current] = Graph.descendants(state, current)
	var future: Dictionary = _descendants[current]
	if future.has(selected) and not _descendants.has(selected):
		_descendants[selected] = Graph.descendants(state, selected)
	var planned: Dictionary = _descendants[selected] if future.has(selected) else {}
	_layers = {"bypassed": [], "ahead": [], "planned": [], "walked": [], "choice": [], "chosen": []}
	for source: Vector2i in positions:
		var node: Dictionary = Graph.room(state, source)
		for link: Dictionary in node.get("connections", []):
			var target: Vector2i = link.get("coord", Graph.INVALID)
			if not positions.has(target): continue
			var destination: Dictionary = Graph.room(state, target)
			var kind: String = "ahead"
			if bool(node.get("visited", false)) and bool(destination.get("visited", false)): kind = "walked"
			elif source == current: kind = "chosen" if target == selected else "choice"
			elif not future.has(source) or not future.has(target): kind = "bypassed"
			elif (planned.has(source) or source == selected) and planned.has(target): kind = "planned"
			(_layers[kind] as Array).append([source, target])
	_layer_inputs = layer_inputs
	# Bound geometry to the displayed links when knowledge/section changes.
	var retained: Dictionary = {}
	for kind: String in _layers:
		for pair: Array in _layers[kind]:
			if _trails.has(pair): retained[pair] = _trails[pair]
	_trails = retained
	return _layers

func trail_for(source: Vector2i, target: Vector2i, positions: Dictionary, radii: Dictionary) -> Dictionary:
	var pair: Array = [source, target]
	var inputs: Array = [positions[source], positions[target], float(radii.get(source, 37.0)), float(radii.get(target, 37.0))]
	var entry: Dictionary = _trails.get(pair, {})
	if entry.is_empty() or entry["inputs"] != inputs:
		var a: Vector2 = positions[source] + Vector2(inputs[2], 0)
		var b: Vector2 = positions[target] - Vector2(inputs[3], 0)
		var curve: Curve2D = make_trail(a, b)
		entry = {"inputs": inputs, "curve": curve, "points": curve.get_baked_points()}
		_trails[pair] = entry
	return entry

static func make_trail(a: Vector2, b: Vector2) -> Curve2D:
	# Trails leave and enter each room sideways and bend between, as before.
	var curve := Curve2D.new()
	var reach: float = maxf(20, (b.x - a.x) * 0.52)
	curve.add_point(a, Vector2.ZERO, Vector2(reach, 0))
	curve.add_point(b, Vector2(-reach, 0), Vector2.ZERO)
	return curve
