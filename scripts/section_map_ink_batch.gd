extends RefCounted

## Retain each static dotted link, then retain the ordered native submissions.
## A changed link never rebuilds its neighbours' circle fans. Native rails still
## delimit flushes; aggregation changes neither vertices nor triangle order.
const TriangleBatch = preload("res://scripts/board_hud_triangle_batch.gd")
var _builder := TriangleBatch.new()
var _links: Dictionary = {}
var _membership: Array = []
var _section: int = -1
var _revision: int = 0
var _pending: Array[Dictionary]
var _submissions: Array[Dictionary]
var _submission_index: int = 0
var _templates: Dictionary = {}
var _topologies: Dictionary = {}
var _fan_indices: PackedInt32Array

func begin_draw(layers: Dictionary, section: int) -> void:
	_pending.clear()
	_submission_index = 0
	if section != _section:
		_section = section
		_links.clear()
		_submissions.clear()
		_topologies.clear()
		_membership.clear()
	var membership: Array = []
	for kind: String in layers:
		for pair: Array in layers[kind]: membership.append(pair)
	if membership != _membership:
		var retained: Dictionary = {}
		for pair: Array in membership:
			if _links.has(pair): retained[pair] = _links[pair]
		_links = retained
		_membership = membership.duplicate(true)

func append_trail(pair: Array, kind: String, points: PackedVector2Array, curve: Curve2D, style: Array, halo_radius: float, halo_colour: Color) -> void:
	var length: float = curve.get_baked_length()
	# Packed points have value/COW semantics; styles need an owned snapshot.
	# Validate values, not a hash or resource id. Layer assignment is explicit.
	var inputs: Array = [kind, points, length, style.duplicate(true), halo_radius, halo_colour]
	var variants: Dictionary = _links.get(pair, {})
	var entry: Dictionary = variants.get(kind, {})
	if entry.is_empty() or entry["inputs"] != inputs:
		entry = _build_link(curve, style, halo_radius, halo_colour, kind)
		_revision += 1
		entry["revision"] = _revision
		entry["inputs"] = inputs
		variants[kind] = entry
		_links[pair] = variants
	_pending.append(entry)

func _build_link(curve: Curve2D, style: Array, halo_radius: float, halo_colour: Color, kind: String) -> Dictionary:
	var spacing: float = style[0]
	var radius: float = style[1]
	var colour := Color(style[2] as Color, float(style[4]))
	var halo := Color(halo_colour, float(style[3]))
	var length: float = curve.get_baked_length()
	var count: int = maxi(1, floori(length / spacing))
	var start: float = (length - float(count) * spacing) * 0.5 + spacing * 0.5
	var points := PackedVector2Array()
	for index: int in range(count): points.append(curve.sample_baked(start + float(index) * spacing))
	var templates: Array = [_circle_template(kind + "/halo", radius + halo_radius, halo), _circle_template(kind + "/dot", radius, colour)]
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	for template: Dictionary in templates:
		var offsets: PackedVector2Array = template["points"]
		for center: Vector2 in points:
			# Canonical offsets already contain the rounded direction * radius.
			# The final addition to the real centre retains its original rounding.
			for index: int in range(offsets.size() - 1): vertices.append(offsets[index] + center)
			vertices.append(center)
			colors.append_array(template["colors"])
	return {"points": vertices, "colors": colors, "indices": _topology_for(vertices.size()), "uvs": PackedVector2Array()}

func _circle_template(slot: String, radius: float, colour: Color) -> Dictionary:
	var inputs: Array = [radius, colour]
	var entry: Dictionary = _templates.get(slot, {})
	if entry.is_empty() or entry["inputs"] != inputs:
		var commands: Array[Array]
		commands.append([Vector2.ZERO, radius, colour, false])
		entry = _builder._build(commands)
		entry["inputs"] = inputs
		_templates[slot] = entry
		_fan_indices = entry["indices"]
	return entry

func _topology_for(vertex_count: int) -> PackedInt32Array:
	if not _topologies.has(vertex_count):
		var indices := PackedInt32Array()
		for first: int in range(0, vertex_count, TriangleBatch.CIRCLE_SEGMENTS + 2):
			for index: int in _fan_indices: indices.append(first + index)
		_topologies[vertex_count] = indices
	return _topologies[vertex_count]

func flush(canvas: CanvasItem) -> void:
	if _pending.is_empty(): return
	var inputs: Array[int]
	for entry: Dictionary in _pending: inputs.append(entry["revision"])
	var entry: Dictionary = _submissions[_submission_index] if _submission_index < _submissions.size() else {}
	if entry.is_empty() or entry["inputs"] != inputs:
		entry = _compose(_pending)
		entry["inputs"] = inputs
		if _submission_index < _submissions.size(): _submissions[_submission_index] = entry
		else: _submissions.append(entry)
	_submission_index += 1
	_pending.clear()
	if not (entry["indices"] as PackedInt32Array).is_empty():
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), entry["indices"], entry["points"], entry["colors"])

func _compose(links: Array[Dictionary]) -> Dictionary:
	# Keep sole ownership while growing these buffers. Putting them into a
	# Dictionary inside the loop makes each append copy the preceding geometry.
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for link: Dictionary in links:
		points.append_array(link["points"])
		colors.append_array(link["colors"])
	return {"points": points, "colors": colors, "indices": _topology_for(points.size()), "uvs": PackedVector2Array()}

func end_draw() -> void:
	_submissions.resize(_submission_index)
	# Bound index-pattern retention to the geometry still retained by this map.
	var retained: Dictionary = {}
	for variants: Dictionary in _links.values():
		for entry: Dictionary in variants.values():
			var count: int = (entry["points"] as PackedVector2Array).size()
			retained[count] = entry["indices"]
	for entry: Dictionary in _submissions:
		retained[(entry["points"] as PackedVector2Array).size()] = entry["indices"]
	_topologies = retained
