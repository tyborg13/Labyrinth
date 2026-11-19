extends RefCounted

# Owned ordered Canvas commands, shared internally by depth layers. Geometry is built
# once per path/layout/colour, then clipped once per tile. Neither ordering nor
# polygon operations change. Public results own nested data and mesh resources.
const CAPACITY: int = 256
const CLIP_CAPACITY: int = 1024
# A conservative margin around the clipper’s coordinate snapping.
const CLIP_BOUNDS_PADDING: float = 1.0
var _paths: Dictionary = {}
var _path_order: Array[int]
var _clips: Dictionary = {}
var _clip_order: Array[int]
var _next_id: int = 0
var record_builds: bool = false
var build_records: Array[Dictionary]
# Canvas commands retain mesh RIDs until that canvas's next draw. Keep their
# resources private here; returning a Resource would let a caller mutate it.
var _submitted_meshes: Dictionary = {}

func statistics() -> Dictionary:
	return {"paths": _paths.size(), "clips": _clips.size(), "path_limit": CAPACITY, "clip_limit": CLIP_CAPACITY}

func path(inputs: Array, build: Callable) -> Dictionary:
	var owned: Dictionary = _path(inputs, build).duplicate(true)
	owned.erase("bounds")
	return owned

func _path(inputs: Array, build: Callable) -> Dictionary:
	var key: int = hash(inputs)
	var entry: Dictionary = _paths.get(key, {})
	if not entry.is_empty() and entry["inputs"] == inputs: return entry
	if not _paths.has(key):
		if _path_order.size() >= CAPACITY: _paths.erase(_path_order.pop_front())
		_path_order.append(key)
	_next_id += 1
	var started: int = Time.get_ticks_usec() if record_builds else 0
	entry = {"id": _next_id, "inputs": inputs.duplicate(true), "commands": (build.call() as Array).duplicate(true)}
	if record_builds and build_records.size() < CAPACITY:
		build_records.append({"frame_id": Engine.get_process_frames(), "elapsed_usec": Time.get_ticks_usec() - started, "inputs": inputs.duplicate(true)})
	var bounds: Array[Rect2]
	for command: Dictionary in entry["commands"]:
		bounds.append(_geometry_bounds(command.get("polygon", command.get("line", PackedVector2Array()))))
	entry["bounds"] = bounds
	_paths[key] = entry
	return entry

func clipped(entry: Dictionary, clip: PackedVector2Array, can_draw: Callable) -> Array:
	return (_clipped_entry(entry, clip, can_draw)["commands"] as Array).duplicate(true)

func batches(entry: Dictionary, clip: PackedVector2Array, can_draw: Callable) -> Array:
	var owned: Array = _batches(entry, clip, can_draw).duplicate(true)
	# Dictionary.duplicate(true) copies containers, but keeps Resource references.
	for command: Dictionary in owned:
		if command.has("mesh"): command["mesh"] = (command["mesh"] as ArrayMesh).duplicate(true)
	return owned

func prepare_path(inputs: Array, build: Callable, clips: Array, can_draw: Callable) -> void:
	var entry: Dictionary = _path(inputs, build)
	for clip: PackedVector2Array in clips: _batches(entry, clip, can_draw, true)

func begin_canvas_draw(canvas: CanvasItem) -> void:
	var id: int = canvas.get_instance_id()
	if not _submitted_meshes.has(id): canvas.tree_exited.connect(_forget_canvas.bind(id), CONNECT_ONE_SHOT)
	_submitted_meshes[id] = []

func draw_path(canvas: CanvasItem, inputs: Array, build: Callable, clip: PackedVector2Array, can_draw: Callable) -> void:
	var entry: Dictionary = _path(inputs, build)
	var retained: Array = _submitted_meshes[canvas.get_instance_id()]
	for command: Dictionary in _batches(entry, clip, can_draw, true):
		if command.has("mesh"):
			retained.append(command["mesh"])
			canvas.draw_mesh(command["mesh"], null)
		else: canvas.draw_polyline(command["line"], command["color"], command["width"], command["antialiased"])

func _forget_canvas(id: int) -> void:
	_submitted_meshes.erase(id)

func _batches(entry: Dictionary, clip: PackedVector2Array, can_draw: Callable, private_entry: bool = false) -> Array:
	var result: Dictionary = _clipped_entry(entry, clip, can_draw, private_entry)
	if not result.has("batches"): result["batches"] = make_batches(result["commands"])
	return result["batches"]

func _clipped_entry(entry: Dictionary, clip: PackedVector2Array, can_draw: Callable, private_entry: bool = false) -> Dictionary:
	# Custom validators may depend on mutable caller state. Only the built-in
	# triangulation policy can share validated clips across calls.
	var cacheable: bool = not can_draw.is_valid()
	var inputs: Array
	var key: int
	if cacheable:
		# A caller can edit a public entry, so validate its commands too.
		inputs = [entry["id"], clip] if private_entry else [entry["id"], entry["commands"], clip]
		key = hash(inputs)
		var cached: Dictionary = _clips.get(key, {})
		if not cached.is_empty() and cached["inputs"] == inputs: return cached
	var commands: Array[Dictionary]
	var source: Array = entry["commands"]
	var bounds: Array = entry.get("bounds", []) if private_entry else []
	var clip_bounds: Rect2 = _geometry_bounds(clip).grow(CLIP_BOUNDS_PADDING)
	for index: int in range(source.size()):
		var command: Dictionary = source[index]
		if clip.is_empty():
			commands.append(command.duplicate(true))
			continue
		# The clipper snaps coordinates internally. Test only clearly
		# disjoint bounds, keeping touching and near-boundary commands.
		if not bounds.is_empty() and not clip_bounds.intersects(bounds[index], true):
			continue
		if command.has("polygon"):
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(command["polygon"], clip):
				if can_draw.is_valid():
					if can_draw.call(piece): commands.append({"polygon": piece, "color": command["color"]})
				else:
					# Production clips already validate through this triangulation.
					# Keep the exact indices for the ordered mesh built below.
					var indices: PackedInt32Array = Geometry2D.triangulate_polygon(piece)
					if indices.size() >= 3: commands.append({"polygon": piece, "color": command["color"], "indices": indices})
		else:
			for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(command["line"], clip):
				if piece.size() > 1: commands.append({"line": piece, "color": command["color"], "width": command["width"], "antialiased": command["antialiased"]})
	var result: Dictionary = {"commands": commands}
	if cacheable:
		if not _clips.has(key):
			if _clip_order.size() >= CLIP_CAPACITY: _clips.erase(_clip_order.pop_front())
			_clip_order.append(key)
		result["inputs"] = inputs.duplicate(true)
		_clips[key] = result
	return result

static func _geometry_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty(): return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(point)
	return bounds

# Polygon triangles remain in their original paint order, with constant colour
# per triangle. Lines retain their separate antialiased calls in that same order.
# This is the same ArrayMesh canvas path used by the existing unit shadows.
func make_batches(commands: Array, proof_sink: Callable = Callable()) -> Array:
	var result: Array[Dictionary]
	var polygons: Array[Dictionary]
	for command: Dictionary in commands:
		if command.has("polygon"):
			polygons.append(command)
		else:
			_append_polygon_batch(result, polygons, proof_sink)
			result.append(command)
			if proof_sink.is_valid(): proof_sink.call(command)
	_append_polygon_batch(result, polygons, proof_sink)
	return result

func _append_polygon_batch(result: Array[Dictionary], polygons: Array[Dictionary], proof_sink: Callable) -> void:
	if polygons.is_empty(): return
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for command: Dictionary in polygons:
		var polygon: PackedVector2Array = command["polygon"]
		var first: int = vertices.size()
		for point: Vector2 in polygon:
			vertices.append(Vector3(point.x, point.y, 0.0))
			colors.append(command["color"])
		var triangles: PackedInt32Array = command["indices"] if command.has("indices") else Geometry2D.triangulate_polygon(polygon)
		for index: int in triangles: indices.append(first + index)
	polygons.clear()
	if indices.is_empty(): return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.append({"mesh": mesh})
	if proof_sink.is_valid(): proof_sink.call({"vertices": vertices, "colors": colors, "indices": indices})
