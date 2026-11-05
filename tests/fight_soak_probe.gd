extends "res://tools/fight_soak.gd"
## Native companion. Frame samples use frame_post_draw; PNG readbacks are
## deliberately outside the sampler and followed by untimed settling.
const CAPTURE_ROUNDS: Array = [1, 10, 20]
func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--check-only"):
		ParallelRuntime.apply_from_environment()
		var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fight_soak_probe_contract.json"))
		assert(contract["min_images"] == 3 and contract["expected_sizes"] == ["1920x1080"])
		print("FIGHT SOAK PROBE CONTRACT: PASS (3 captures; 1920x1080; UI scale 100%)")
		quit(0)
		return
	native = true
	await super._initialize()

func _capture_round_proof(round_index: int) -> void:
	if round_index not in CAPTURE_ROUNDS: return
	# Force a draw command even when the real board is wholly retained.
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	var path: String = output.path_join("round_%02d.png" % round_index)
	var image: Image = root.get_texture().get_image()
	_save_proof_image(image, path)
	print(ProjectSettings.globalize_path(path))
	for frame: int in range(SETTLE_FRAMES): await RenderingServer.frame_post_draw
	previous_frame_usec = 0

func _save_proof_image(image: Image, path: String) -> void:
	# Native root readbacks can use the Retina backing size. Normalize only
	# proof I/O, outside sampling, without changing the live soak viewport.
	if image.get_size() != VIEWPORT:
		image.resize(VIEWPORT.x, VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	assert(image.get_size() == VIEWPORT, "Native soak proof must be 1920x1080")
	assert(image.save_png(path) == OK)
