extends SceneTree

## Headless byte oracle: hash every actual Polygon2D buffer, including hidden
## paint. The frozen baseline adapter runs the exact 2bd5ea39a scalar skin path.
const Pixels = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")
const Production = preload("res://assets/units/chainbound_gaoler_cutout/rig.gd")
const MUTATION_VERTEX_STEP: float = 1.0 / 256.0
var _rigs: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--input") + 1]))
	var adapter: Script = load(args[args.find("--rig") + 1]) if args.has("--rig") else Production
	var rows: Array
	var paths: Dictionary = {}
	var buffers: int = 0
	for entry: Array in input["cases"]:
		var view: String = entry[0]
		if not _rigs.has(view):
			var instance: Node2D = adapter.new()
			instance.facing = view
			root.add_child(instance)
			assert(instance.load_rig())
			_rigs[view] = instance
		var rig: Node2D = _rigs[view]
		var context: Dictionary = input["configs"][entry[3]]
		var origin: Array = context.get("origin", [0, 0])
		rig.transform = Pixels.canvas_transform(Vector2(origin[0], origin[1]), Vector2(255, 255), context.get("mirrored", false))
		for field: String in ["screen_pixel_scale", "step_distance_px"]: rig.layout.erase(field)
		if context.has("scale"): rig.layout["screen_pixel_scale"] = context["scale"]
		if context.has("step"): rig.layout["step_distance_px"] = context["step"]
		rig.apply_pose(str(entry[1]), float(entry[2]))
		var nodes: Array[Node] = rig.find_children("*", "Polygon2D", true, false)
		var names: Array[String]
		var hashes: Array[String]
		for node: Polygon2D in nodes:
			names.append(str(rig.get_path_to(node)))
			if args.has("--mutate-vertex") and rows.is_empty() and hashes.is_empty():
				var changed: PackedVector2Array = node.polygon
				changed[0] += Vector2(MUTATION_VERTEX_STEP, 0.0)
				node.polygon = changed
			var data: PackedByteArray = node.polygon.to_byte_array()
			var sha := HashingContext.new()
			sha.start(HashingContext.HASH_SHA256)
			sha.update(data)
			hashes.append(sha.finish().hex_encode())
			buffers += 1
		if paths.has(view): assert(paths[view] == names)
		else: paths[view] = names
		rows.append(hashes)
		if rows.size() % 500 == 0: print("RR49 HASH PROGRESS: ", rows.size())
	for rig: Node2D in _rigs.values(): rig.free()
	var result: Dictionary = {"paths": paths, "rows": rows, "poses": rows.size(), "buffers": buffers}
	FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(JSON.stringify(result))
	print("RR49 SUBMISSION HASHES: ", rows.size(), " poses; ", buffers, " buffers")
	quit()
