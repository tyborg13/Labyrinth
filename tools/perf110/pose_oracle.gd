extends SceneTree
## Submitted buffers at exact debug-only replay points; no rendered-pixel claim.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Paint = preload("res://scripts/maquette_cutout_runtime/stable_paint.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const FIXTURE_TYPES := ["hoarfrost_seer", "arc_thrall", "glacial_mirror", "frostglass_lancer", "chainbound_gaoler"]
const FIXTURE_PHASES := [0.0, 0.1, 0.25, 0.5, 0.75, 1.0, 0.5, 0.5]
var _output: String
var _texture_hashes: Dictionary = {}

func _initialize() -> void:
	_output = OS.get_environment("PERF110_POSE_OUTPUT")
	if _output.is_empty():
		push_error("PERF110_POSE_OUTPUT is required")
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	var records: Array = []
	for type: String in FIXTURE_TYPES:
		for facing: String in ["front", "rear"]:
			var rig: Node2D = load("res://assets/units/%s_cutout/rig.gd" % type).new()
			rig.facing = facing
			root.add_child(rig)
			if not rig.load_rig():
				push_error(str(rig.load_errors))
				quit(1)
				return
			for clip: String in Motion.data_for(rig.layout)["clips"]:
				for phase: float in FIXTURE_PHASES:
					rig.apply_pose(clip, phase)
					records.append({"type": type, "facing": facing, "clip": clip,
						"phase": phase, "geometry": Paint.geometry(rig), "nodes": _nodes(rig)})
			rig.free()
	var file := FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(JSON.stringify(records))
	file.close()
	print("PERF110 POSE ORACLE: samples=%d" % records.size())
	quit()

func _nodes(rig: Node) -> Array:
	var result: Array = []
	for node: Node in rig.find_children("*", "Node2D", true, false):
		var row: Dictionary = {"path": str(rig.get_path_to(node)), "transform": str(node.transform),
			"visible": node.visible, "modulate": str(node.modulate), "self_modulate": str(node.self_modulate),
			"z_index": node.z_index, "z_as_relative": node.z_as_relative}
		var transform: Transform2D = node.transform
		row["transform_sha256"] = _digest(PackedFloat64Array([transform.x.x, transform.x.y,
			transform.y.x, transform.y.y, transform.origin.x, transform.origin.y]).to_byte_array())
		row["tint_sha256"] = _digest(PackedColorArray([node.modulate, node.self_modulate]).to_byte_array())
		if node is Polygon2D or node is Sprite2D:
			row["texture_sha256"] = _texture_digest(node.texture)
		if node is Polygon2D:
			row["uv_sha256"] = _digest(node.uv.to_byte_array())
			var indices := PackedInt32Array()
			for polygon: PackedInt32Array in node.polygons:
				indices.append(polygon.size())
				indices.append_array(polygon)
			row["polygons_sha256"] = _digest(indices.to_byte_array())
			row["polygon_sha256"] = _digest(node.polygon.to_byte_array())
			row["vertex_colors_sha256"] = _digest(node.vertex_colors.to_byte_array())
			row["skeleton"] = str(node.skeleton)
		result.append(row)
	return result

func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()

func _texture_digest(texture: Texture2D) -> String:
	if texture == null: return "none"
	var id: int = texture.get_instance_id()
	if not _texture_hashes.has(id):
		var image: Image = texture.get_image()
		_texture_hashes[id] = "unavailable" if image == null else _digest(image.get_data())
	return _texture_hashes[id]
