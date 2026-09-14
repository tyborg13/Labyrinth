extends "res://tests/protagonist_cutout_gameplay_probe.gd"

const ILLUSION_OUTPUT: String = "user://probes/illusion_animation_v1"
var _seen_player_clips: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture = DisplayServer.get_name() != "headless"
	root.size = SIZE
	root.content_scale_size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ILLUSION_OUTPUT))
	ProgressionStore.set_storage_path("user://illusion_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://illusion_probe_run.save")
	ProgressionStore.clear_saved_run()
	var surface := SubViewport.new()
	surface.size = SIZE
	surface.disable_3d = true
	surface.world_2d = World2D.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	_render_viewport = surface
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	surface.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	await _fixture(Vector2i(3, 3), Vector2i(6, 6))
	await _capture_illusions("idle")
	await _instance.call("_on_board_tile_clicked", Vector2i(3, 3))
	_instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _observe("walk")
	_assert(_player_pos() == Vector2i(3, 4), "Player movement still commits")
	await _fixture(Vector2i(3, 3), Vector2i(3, 4))
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _observe("attack")
	_assert(int((_instance.get("_combat_state") as Dictionary)["enemies"][0]["hp"]) == 31, "Quick Stab still applies exactly nine damage")
	await _fixture(Vector2i(3, 3), Vector2i(5, 3))
	await _instance.call("_on_card_pressed", 3)
	_instance.call("_on_board_tile_clicked", Vector2i(5, 3))
	await _observe("shoot")
	await _fixture(Vector2i(3, 3), Vector2i(5, 3), false, ["guiding_flare", "brace", "quick_stab", "bone_dart", "patch_up"])
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_clicked", Vector2i(5, 3))
	await _observe("cast")
	await _fixture(Vector2i(3, 3), Vector2i(3, 4), true)
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _observe("reduced_motion")
	# The board's explicit per-illusion channel preserves independent effects.
	await _fixture(Vector2i(3, 3), Vector2i(6, 6))
	var state: Dictionary = (_board.get("combat_state") as Dictionary).duplicate(true)
	for clip: String in ["walk", "attack"]:
		var presentation: Dictionary = (_board.get("presentation") as Dictionary).duplicate(true)
		presentation["illusion_motion"] = {"illusion_71": {"clip": clip, "direction": Vector2i(1, 0), "phase": 0.42}}
		_board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		_assert(_illusion_snapshot(71)["clip"] == clip, "Explicit effect animates its own illusion")
		_assert(_illusion_snapshot(72)["clip"] == "idle", "Unaddressed illusion stays idle")
		_assert(_snapshot()["clip"] == "idle", "Independent illusion action leaves player idle")
		await _capture_illusions("independent_" + clip)
	for clip: String in ["walk", "attack", "cast", "shoot"]:
		_assert(_seen_player_clips.has(clip), "Gameplay actually rendered player " + clip)
	var file := FileAccess.open(ILLUSION_OUTPUT + "/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"errors": _errors, "player_clips": _seen_player_clips.keys(), "size": [1920, 1080], "ui_scale": 1.0}, "\t"))
	file.close()
	_instance.queue_free()
	surface.queue_free()
	await process_frame
	for message: String in _errors:
		push_error(message)
	print("ILLUSION ANIMATION GAMEPLAY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(ILLUSION_OUTPUT))
	quit(0 if _errors.is_empty() else 1)

func _fixture(player_tile: Vector2i, enemy_tile: Vector2i, reduced: bool = false, custom_hand: Array = [], player_hp: int = 24, extra_enemy_tiles: Array = []) -> void:
	await super._fixture(player_tile, enemy_tile, reduced, custom_hand, player_hp, extra_enemy_tiles)
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run["combat_state"]["illusions"] = [
		{"id": 71, "pos": Vector2i(2, 3), "hp": 2, "max_hp": 2},
		{"id": 72, "pos": Vector2i(4, 2), "hp": 2, "max_hp": 2}]
	_instance.set("_run_state", run)
	_instance.call("_sync_combat_state_from_run")
	_instance.call("_refresh_ui")
	await _settle()

func _illusion_snapshot(id: int) -> Dictionary:
	var renderer: Node = _board.call("unit_cutout_renderer", {"type": "player", "role": "illusion", "key": "illusion_%d" % id})
	_assert(is_instance_valid(renderer), "Illusion renderer exists")
	return renderer.call("snapshot") if is_instance_valid(renderer) else {}

func _observe(label: String) -> void:
	var captured: bool = false
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 8000:
		await process_frame
		var clip: String = str(_snapshot().get("clip", ""))
		_seen_player_clips[clip] = true
		for id: int in [71, 72]:
			var illusion: Dictionary = _illusion_snapshot(id)
			_assert(illusion.get("clip", "") == ("rest" if label == "reduced_motion" else "idle"), "Illusion stays idle throughout player " + label)
			_assert(illusion.get("facing", "") == "front" and not bool(illusion.get("mirrored", true)), "Player actions do not turn illusions")
		if not captured and ((clip == label and float(_snapshot().get("phase", 0.0)) >= 0.35) or label == "reduced_motion"):
			await _capture_illusions("player_" + label)
			captured = true
		if not bool(_instance.get("_animation_lock")):
			break
	_assert(captured, "Captured the actual player action " + label)
	_assert(not bool(_instance.get("_animation_lock")), "Action returns input")
	await _capture_illusions("after_" + label)

func _capture_illusions(label: String) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	var image: Image = _render_viewport.get_texture().get_image()
	_assert(image.get_size() == SIZE, "Actual capture is 1920x1080")
	image.save_png(ILLUSION_OUTPUT.path_join(label + ".png"))
