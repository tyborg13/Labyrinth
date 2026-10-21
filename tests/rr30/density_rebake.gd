extends "res://tests/rr22/density_rebake.gd"

## Keep the rr22 1920x1080 proof contract independent of the OS window size,
## fullscreen state and backing scale. Production rests remain native 255x255.
func _run() -> void:
	if "--validate-only" not in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			push_error("RR30 density pixels require the director's windowed renderer")
			quit(1)
			return
		await super._run()
		return
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var only_index: int = arguments.find("--only")
	assert(only_index >= 0 and only_index + 1 < arguments.size())
	assert(arguments[only_index + 1] == "slag_mortar_cutout")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY)) as Dictionary
	for entry: Dictionary in registry["entries"]:
		if entry["id"] != "slag_mortar_cutout": continue
		for facing: String in entry["rest_paths"]:
			var image: Image = Image.load_from_file("res://" + str(entry["rest_paths"][facing][0]))
			assert(image != null and image.get_size() == NATIVE_REGION.size)
			_pending.append({"image": image})
	assert(_pending.size() == 2)
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/rr22/density_contract.json")) as Dictionary
	assert(contract["expected_sizes"] == ["1920x1080"])
	assert(int(contract["required_images"][0]["width"]) == PROOF_SIZE.x)
	assert(int(contract["required_images"][0]["height"]) == PROOF_SIZE.y)
	var proof: SubViewport = _proof_viewport()
	assert(proof.size == PROOF_SIZE)
	assert(proof.get_child_count() == 1 + _pending.size())
	assert(NATIVE_REGION.size == Vector2i(255, 255))
	print("RR30 DENSITY PROBE LOAD: PASS (1920x1080 summary; 255x255 rests; headless structure only)")
	proof.free()
	quit(0)

func _proof_viewport() -> SubViewport:
	var proof := SubViewport.new()
	proof.size = PROOF_SIZE
	proof.disable_3d = true
	proof.world_2d = World2D.new()
	proof.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(proof)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(PROOF_SIZE)
	backdrop.color = Color("1e1e24")
	proof.add_child(backdrop)
	for index: int in range(_pending.size()):
		var paint := TextureRect.new()
		paint.texture = ImageTexture.create_from_image(_pending[index]["image"])
		paint.size = Vector2(255, 255) * PROOF_PAINT_SCALE
		paint.position = Vector2(PROOF_SIZE.x * (0.25 if index == 0 else 0.75), PROOF_SIZE.y * 0.5) - paint.size * 0.5
		paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		proof.add_child(paint)
	return proof

func _summary() -> void:
	var proof: SubViewport = _proof_viewport()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = proof.get_texture().get_image()
	if image == null or image.get_size() != PROOF_SIZE:
		_fail("RR30 density summary must be 1920x1080")
	else:
		var path: String = OUTPUT.path_join("rr22_density_pair.png")
		if image.save_png(path) != OK:
			_fail("Could not save " + path)
		else:
			print(ProjectSettings.globalize_path(path))
	proof.free()
	# The parent _finish schedules _summary; call the base completion directly.
	for message: String in _errors:
		push_error(message)
	print("BOARD DENSITY REST REBAKE: " + ("PASS" if _errors.is_empty() else "FAIL") + " (%d views)" % _pending.size())
	quit(0 if _errors.is_empty() else 1)
