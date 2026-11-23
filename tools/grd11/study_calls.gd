extends SceneTree
## Run on the same study fixture before and after the atlas change.

const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tools/grd07/fixture.gd")
const SAMPLE_SECONDS: float = 0.5
const SETTLE_FRAMES: int = 4
const FIXTURE_SEED: int = 617

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() in [1, 2] and args[0].is_absolute_path(), "Pass an absolute report path and optional baseline report")
	var dry: bool = DisplayServer.get_name() == "headless"
	var report: Dictionary = {"native": not dry}
	var output: String = args[0].get_base_dir()
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var view: SubViewport = Fixture.Gallery.make_view(Fixture.SIZE, Fixture.SIZE, Viewport.MSAA_4X)
	root.add_child(view)
	if not dry:
		var preview := Sprite2D.new()
		preview.centered = false
		preview.texture = view.get_texture()
		root.add_child(preview)
	for mode: String in ["off", "pixel"]:
		OS.set_environment("LABYRINTH_GROUND_FX", mode)
		var columns: Dictionary = {}
		for column: int in Fixture.GROUNDS.size():
			seed(FIXTURE_SEED)
			var state: Dictionary = Fixture.state_for(column)
			var board := Board.new()
			board.size = Vector2(Fixture.SIZE)
			board.process_mode = Node.PROCESS_MODE_DISABLED
			view.add_child(board)
			Fixture.frame_room(board, state)
			Fixture.submit(board, state)
			_hold_release_clock(board, state)
			var pixel: Node = board.get_node_or_null("PixelGround")
			if pixel != null and pixel.visible:
				pixel.set_motion_time(SAMPLE_SECONDS)
			for frame: int in SETTLE_FRAMES:
				await process_frame
			if not dry:
				await RenderingServer.frame_post_draw
			var result: Dictionary = {}
			if pixel != null:
				var raised: int = 0
				if "sheet" in pixel:
					raised = pixel.sheet.stamps.size()
				else:
					for key: Array in pixel.depth.stamps:
						var stamp: CanvasItem = pixel.depth.stamps[key]
						if stamp.is_visible_in_tree() and key[1] in [1, 3]:
							raised += 1
				result["raised_quad_commands"] = raised
			else:
				assert(not board.get("_pixel_ground_enabled"))
				var commands: Array = _release_commands(board)
				# Canonical encoding avoids padding in Godot's variant binary format.
				var bytes: PackedByteArray = JSON.stringify(_command_value(commands), "", true, true).to_utf8_buffer()
				result["release_surface_commands"] = _digest(bytes)
			if not dry:
				result["draw_calls"] = view.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
				var image_path: String = args[0].get_file().get_basename() + "-" + mode + "-" + Fixture.GROUNDS[column] + ".png"
				var image: Image = view.get_texture().get_image()
				assert(image.get_size() == Fixture.SIZE)
				assert(image.save_png(output.path_join(image_path)) == OK)
				if mode == "off":
					result["rgba_sha256"] = _digest(image.get_data())
			columns[Fixture.GROUNDS[column]] = result
			board.free()
		report[mode] = columns
	if args.size() == 2:
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		report["comparison"] = _compare(baseline, report, dry)
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	assert(file != null, "Cannot write study report")
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print(output)
	print("GRD-11 STUDY COUNTS: %s" % args[0])
	quit()

func _compare(before: Dictionary, after: Dictionary, dry: bool) -> Dictionary:
	assert(before["native"] == after["native"])
	var comparison: Dictionary = {}
	for column: String in Fixture.GROUNDS:
		var old_release: Dictionary = before["off"][column]
		var new_release: Dictionary = after["off"][column]
		assert(old_release["release_surface_commands"] == new_release["release_surface_commands"], column + " release surface command inputs")
		var old_pixel: Dictionary = before["pixel"][column]
		var new_pixel: Dictionary = after["pixel"][column]
		var counts: Dictionary = {"raised_quad_commands": [int(old_pixel["raised_quad_commands"]), new_pixel["raised_quad_commands"]]}
		if not dry:
			assert(old_release["rgba_sha256"] == new_release["rgba_sha256"], column + " release RGBA")
			counts["draw_calls"] = [int(old_pixel["draw_calls"]), new_pixel["draw_calls"]]
		comparison[column] = counts
		print("GRD-11 STUDY %s: %s" % [column, counts])
	print("GRD-11 FLAG OFF: PASS (7 release surface command-input byte hashes%s)" % ("" if dry else ", 7 release RGBA byte hashes"))
	return comparison

static func _hold_release_clock(board: Control, state: Dictionary) -> void:
	var layers: Dictionary = board.get("_scene_render_layers_by_tile")
	for tile: Vector2i in Fixture.Ground.tiles(state):
		var layer: Control = layers[tile]
		layer.get("presentation")["ambient_time_seconds"] = Fixture.Gallery.PROOF_SECONDS + SAMPLE_SECONDS
		layer.queue_redraw()

func _release_commands(board: Control) -> Array:
	# Godot exposes no native CanvasItem command readback. Hash the ordered
	# retained surface inputs, including transforms and electric geometry.
	var commands: Array = []
	for layer: Node in board.get("_scene_render_layers"):
		for child: Node in layer.get_children():
			if child.name not in [&"SurfaceFire", &"SurfaceIce", &"SurfaceRubble", &"SurfaceElectric"]:
				continue
			var row: Array = [board.get_path_to(child), child.transform, child.modulate,
				child.is_visible_in_tree(), child.show_behind_parent, child.get("_width"), child.get("_seed")]
			for field: String in ["_phase", "_tick", "_anchors", "_endpoints", "_angles", "_intensities"]:
				if field in child:
					row.append(child.get(field))
			commands.append(row)
	return commands

static func _command_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(_command_value(item))
			return items
		TYPE_COLOR:
			return [value.r, value.g, value.b, value.a]
		TYPE_TRANSFORM2D:
			return [_command_value(value.x), _command_value(value.y), _command_value(value.origin)]
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_VECTOR4:
			return [value.x, value.y, value.z, value.w]
		TYPE_NODE_PATH:
			return str(value)
	return value

static func _digest(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()
