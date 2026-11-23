extends RefCounted

const Particle = preload("res://scripts/board_surface_particle.gd")
const LAYERS: PackedStringArray = ["SurfaceFire", "SurfaceIce", "SurfaceElectric", "SurfaceRubble", "SurfaceRubbleFloor"]
static var elapsed: Dictionary = {}
static var calls: Dictionary = {}

## Called only by the temporary instrumented scripts.
static func record(section: String, started_usec: int) -> void:
	var usec: int = Time.get_ticks_usec() - started_usec
	elapsed[section] = int(elapsed.get(section, 0)) + usec
	calls[section] = int(calls.get(section, 0)) + 1

static func take() -> Dictionary:
	var sample: Dictionary = {"usec": elapsed, "calls": calls}
	elapsed = {}
	calls = {}
	return sample

static func inventory(board: Node) -> Dictionary:
	var layers: Dictionary = {}
	for tile: Node in board.get("_scene_render_layers"):
		for child: Node in tile.get_children():
			if child.name in LAYERS:
				var entry: Dictionary = layers.get(child.name, {"roots": 0, "live_nodes": 0,
					"visible_nodes": 0, "particle_quads": 0, "gpu_particles": 0,
					"shader_materials": {}, "shaders": {}})
				entry["roots"] += 1
				_count_subtree(child, entry)
				layers[child.name] = entry
	var pixel: Node = board.get_node_or_null("PixelGround")
	if pixel != null:
		var entry: Dictionary = {"roots": 1 if pixel.visible else 0, "live_nodes": 0,
			"visible_nodes": 0, "particle_quads": 0, "gpu_particles": 0,
			"shader_materials": {}, "shaders": {}}
		_count_subtree(pixel, entry)
		layers[pixel.name] = entry
	var totals: Dictionary = {"board_nodes": _node_count(board), "surface_roots": 0,
		"surface_live_nodes": 0, "surface_visible_nodes": 0, "surface_particle_quads": 0,
		"surface_gpu_particles": 0, "surface_layers": {}}
	var shaders: Dictionary = {}
	var materials: Dictionary = {}
	for kind: String in layers:
		var layer: Dictionary = layers[kind]
		totals["surface_roots"] += layer["roots"]
		totals["surface_live_nodes"] += layer["live_nodes"]
		totals["surface_visible_nodes"] += layer["visible_nodes"]
		totals["surface_particle_quads"] += layer["particle_quads"]
		totals["surface_gpu_particles"] += layer["gpu_particles"]
		shaders.merge(layer["shaders"])
		materials.merge(layer["shader_materials"])
		layer["shaders"] = layer["shaders"].keys()
		layer["shader_materials"] = layer["shader_materials"].size()
		totals["surface_layers"][kind] = layer
	totals["surface_shaders"] = shaders.keys()
	totals["surface_shader_count"] = shaders.size()
	totals["surface_shader_material_count"] = materials.size()
	return totals

static func stats(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: Variant in sorted:
		total += float(value)
	var size: int = sorted.size()
	return {"mean": total / size, "p50": sorted[ceili(size * 0.50) - 1],
		"p95": sorted[ceili(size * 0.95) - 1], "max": sorted[-1]}

static func _node_count(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _node_count(child)
	return count

static func _count_subtree(node: Node, entry: Dictionary) -> void:
	entry["live_nodes"] += 1
	if node is CanvasItem:
		if node.is_visible_in_tree():
			entry["visible_nodes"] += 1
		if node is Particle:
			entry["particle_quads"] += 1
		elif node is GPUParticles2D:
			entry["gpu_particles"] += node.amount
		var material: ShaderMaterial = node.material as ShaderMaterial
		if material != null and material.shader != null:
			entry["shader_materials"][material.get_instance_id()] = true
			entry["shaders"][material.shader.resource_path] = true
	for child: Node in node.get_children():
		_count_subtree(child, entry)
