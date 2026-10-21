extends RefCounted

# Owned ordered Canvas commands, shared internally by depth layers. Geometry is built
# once per path/layout/colour, then clipped once per tile. Neither ordering nor
# polygon operations change. Public results own nested data and mesh resources.
const CAPACITY: int = 256
const CLIP_CAPACITY: int = 1024
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
	return _path(inputs, build).duplicate(true)

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
	# Entries are caller-owned. Include their commands so a modified returned
	# entry cannot poison a later clip hit for the original entry's id.
	# Internally owned entries have unique monotonic ids and cannot be edited by
	# a caller. Public entry snapshots must validate the supplied commands too.
	var inputs: Array = [entry["id"], clip] if private_entry else [entry["id"], entry["commands"], clip]
	var key: int = hash(inputs)
	var cached: Dictionary = _clips.get(key, {})
	if not cached.is_empty() and cached["inputs"] == inputs: return cached
	var commands: Array[Dictionary]
	for command: Dictionary in entry["commands"]:
		if clip.is_empty():
			commands.append(command.duplicate(true))
			continue
		if command.has("polygon"):
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(command["polygon"], clip):
				if can_draw.call(piece): commands.append({"polygon": piece, "color": command["color"]})
		else:
			for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(command["line"], clip):
				if piece.size() > 1: commands.append({"line": piece, "color": command["color"], "width": command["width"], "antialiased": command["antialiased"]})
	if not _clips.has(key):
		if _clip_order.size() >= CLIP_CAPACITY: _clips.erase(_clip_order.pop_front())
		_clip_order.append(key)
	_clips[key] = {"inputs": inputs.duplicate(true), "commands": commands}
	return _clips[key]

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
		for index: int in Geometry2D.triangulate_polygon(polygon): indices.append(first + index)
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
