extends "res://tests/biome_gallery_probe.gd"
## Six complete loops through the production board, including its side offset.
## Native: 96 1920x1080 images at 100% UI scale. --headless-check only checks
## fixtures/frame routing; it deliberately produces no renderer evidence.

const LIGHT_PROOF_OUTPUT: String = "user://probes/biome_light_motion"
const LIGHT_FRAME_COUNT: int = 16
const LIGHT_FRAME_SAMPLE_OFFSET: float = 0.25 # Proof-only: avoid float boundary ties.
const LIGHT_CONTRACT: String = "res://tests/biome_light_motion_probe_contract.json"

func _write_proof_contract() -> void:
	# The base gallery calls this before creating its isolated output folder.
	_density_output = LIGHT_PROOF_OUTPUT
	_density_check(FileAccess.file_exists(LIGHT_CONTRACT), "Motion proof contract exists")

func _gallery_capture(scenario: String, label: String, settings: Dictionary, captures: Array[Dictionary]) -> void:
	if _gallery_biome == "stone" or scenario != "props":
		return
	if not await _density_prepare_fixture(scenario, settings):
		return
	var board: Control = _density_scene.get_node("BoardUnderlay/CombatBoard")
	var state: Dictionary = board.get("combat_state")
	var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	presentation["biome_id"] = _gallery_biome
	board.call("set_combat_state", state, [], [], board.get("selected_tile"), board.get("status_label"), board.get("status_detail"), board.get("exit_tiles"), board.get("exit_icon_ids"), presentation)
	_density_scene.get_node("BoardUnderlay/BoardBackdrop").modulate = Biomes.backdrop_modulate(_gallery_biome)
	(_density_scene.get("_combat_atmosphere") as Control).call("set_biome", _gallery_biome)
	_density_check(board.get("_biome_id") == _gallery_biome, label + ": board domain")
	var torch_rects: Array[Rect2i] = _light_torch_rects(board, state)
	_density_check(torch_rects.size() == 4, label + ": both sides of two columns visible")
	var torch_hashes: Array[Dictionary]
	for _rect: Rect2i in torch_rects:
		torch_hashes.append({})
	for index: int in range(LIGHT_FRAME_COUNT):
		var seconds: float = (float(index) + LIGHT_FRAME_SAMPLE_OFFSET) * DensityBoardBase.COLUMN_TORCH_IDLE_FRAME_SECONDS
		board.set("_idle_elapsed", seconds)
		board.call("_sync_dynamic_render_state", false)
		board.call("_queue_active_idle_redraws", board.call("_active_idle_frames_by_source"))
		board.call("_queue_dynamic_redraw")
		board.queue_redraw()
		for _frame: int in range(GALLERY_SETTLE_FRAMES):
			await process_frame
		_density_check(int(board.call("_pillar_torch_idle_frame_index", "left")) == index, label + ": left frame")
		_density_check(int(board.call("_pillar_torch_idle_frame_index", "right")) == (index + 3) % LIGHT_FRAME_COUNT, label + ": right offset")
		var name: String = "%s_%02d.png" % [label, index]
		if not _gallery_headless:
			await RenderingServer.frame_post_draw
			var image: Image = _density_viewport.get_texture().get_image()
			_density_check(image != null and image.get_size() == DENSITY_SIZE, name + ": native 1920x1080")
			if image != null:
				_density_check(image.save_png(_density_output.path_join(name)) == OK, name + ": save capture")
				for torch: int in range(torch_rects.size()):
					torch_hashes[torch][hash(image.get_region(torch_rects[torch]).get_data())] = true
		captures.append({"image": name if not _gallery_headless else "", "biome": _gallery_biome,
			"phase_seconds": seconds, "left_frame": index, "right_frame": (index + 3) % LIGHT_FRAME_COUNT,
			"frame_seconds": DensityBoardBase.COLUMN_TORCH_IDLE_FRAME_SECONDS, "torch_rects": str(torch_rects)})
	if not _gallery_headless:
		for torch: int in range(torch_hashes.size()):
			_density_check(torch_hashes[torch].size() >= 12, label + ": rendered torch %d visibly animates" % torch)
	_density_scene.queue_free()
	await process_frame

func _light_torch_rects(board: Control, state: Dictionary) -> Array[Rect2i]:
	var result: Array[Rect2i]
	var grid: Array = state.get("grid", [])
	var pillar: Texture2D = (board.get("_prop_textures") as Dictionary).get("pillar")
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			if str(grid[y][x]) != "pillar":
				continue
			var pillar_rect: Rect2 = board.call("_prop_draw_rect", pillar, board.call("_prop_rect_for_tile", Vector2i(x, y)))
			for side: String in ["left", "right"]:
				var texture: Texture2D = board.call("_pillar_torch_texture", side)
				_density_check(texture != null, _gallery_biome + ": torch texture " + side)
				var rect: Rect2 = board.call("_pillar_torch_rect", pillar_rect, texture, -1.0 if side == "left" else 1.0)
				var screen_rect: Rect2 = board.get_global_transform() * rect
				_density_check(Rect2(Vector2.ZERO, Vector2(DENSITY_SIZE)).encloses(screen_rect), _gallery_biome + ": entire torch inside capture")
				result.append(Rect2i(screen_rect))
	return result
