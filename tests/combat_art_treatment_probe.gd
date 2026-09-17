extends "res://tests/pillar_torch_lighting_probe.gd"


class TextureSwatches extends Node2D:
	const Treatment = preload("res://scripts/combat_art_treatment.gd")
	var tagged: bool = false
	var source: Texture2D
	var atlas: AtlasTexture

	func _init() -> void:
		var pixels := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y: int in range(64):
			for x: int in range(64):
				pixels.set_pixel(x, y, Color(float(x) / 63.0, float(y) / 63.0, 0.45, float((x + y) % 4) / 3.0))
		source = ImageTexture.create_from_image(pixels)
		atlas = AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(16, 16, 32, 32)
		atlas.margin = Rect2(4, 6, 12, 12)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var tint := Color(0.7, 0.8, 0.9, 0.6)
		var a := Rect2(10, 10, 90, 90)
		var b := Rect2(120, 10, 90, 90)
		var c := Rect2(230, 10, 90, 90)
		var slice := Rect2(0, 8, 32, 24)
		if tagged:
			Treatment.draw_rect(self, source, a, tint, Treatment.ACTOR)
			Treatment.draw_rect(self, atlas, b, tint, Treatment.ACTOR_ATLAS)
			Treatment.draw_rect(self, atlas, c, tint, Treatment.ACTOR_ATLAS, slice)
		else:
			draw_texture_rect(source, a, false, tint)
			draw_texture_rect(atlas, b, false, tint)
			draw_texture_rect_region(atlas, c, slice, tint)
		# Untagged visual feedback keeps its exact colors and coverage.
		draw_texture_rect(atlas, Rect2(340, 10, 90, 90), false, tint)
		draw_rect(Rect2(450, 10, 50, 90), tint)

# Reuse the live combat fixture and capture plumbing, not its historical floor
# replacement. Every comparison holds pose, UI, camera and motion settings fixed.
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://art_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://art_probe_run.save")
	SettingsStore.set_storage_path("user://art_probe_settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	root.size = VIEWPORT_SIZE
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_load_run_state", RunEngine.new().create_new_run(62001, ProgressionStore.default_data()))
	instance.call("_close_dialogue")
	await _load_combat_fixture(instance, 62001)
	await _settle()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard")
	board.call("set_art_treatment_enabled", false)
	await _capture(viewport, "art_01_before.png")
	var before: Image = viewport.get_texture().get_image()
	board.call("set_art_treatment_enabled", true)
	await _capture(viewport, "art_02_after.png")
	var after: Image = viewport.get_texture().get_image()
	_expect(_difference(before, after, Rect2i(450, 70, 1020, 610)) > 0.004, "World art must visibly change")
	_expect(_difference(before, after, Rect2i(0, 80, 290, 570)) == 0.0, "Backdrop must remain pixel-identical")
	_expect(_difference(before, after, Rect2i(440, 790, 965, 260)) == 0.0, "Cards must remain pixel-identical")
	_expect(_difference(before, after, Rect2i(1590, 0, 325, 100)) == 0.0, "HUD controls must remain pixel-identical")
	var snapshot: Dictionary = board.call("art_treatment_snapshot")
	_expect(int(snapshot["light_count"]) == 5, "Five paired torch columns produce five local fill sources")
	_expect(int(snapshot["light_overflow"]) == 0, "Fixture must exercise all its sources")
	for layer: Control in board.call("_retained_render_layers"):
		_expect(layer.material == snapshot["shared_material"], "Retained layers must share one art material")
	var updates: int = int(board.get("_static_render_cache_update_count"))
	await _settle()
	_expect(int(board.get("_static_render_cache_update_count")) == updates, "Idle lighting must retain the floor cache")
	board.call("set_static_render_cache_enabled", false)
	await _capture(viewport, "art_03_direct_floor.png")
	var direct: Image = viewport.get_texture().get_image()
	_expect(_difference(after, direct, Rect2i(450, 70, 1020, 610)) < 0.005, "Cached and direct world art must agree")
	board.call("set_static_render_cache_enabled", true)
	instance.call("_on_card_pressed", 0)
	await _settle()
	var preview: Dictionary = instance.call("_active_card_preview")
	var targets: Array = preview.get("target_tiles", [])
	_expect(not targets.is_empty(), "Lighting must preserve legal targets")
	if not targets.is_empty():
		instance.call("_on_board_tile_hovered", targets[0])
		board.call("set_controller_focus_tile", targets[0])
		var target_point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile", targets[0]) as Vector2)
		instance.call("_sync_click_targeting_arrow", target_point)
	await _capture(viewport, "art_04_targeting.png")
	instance.call("_on_cancel_requested")
	board.call("clear_controller_focus") if board.has_method("clear_controller_focus") else board.call("set_controller_focus_tile", Vector2i(-1, -1))
	# Interpolation and partial Umbra clipping use the same shader path and alpha.
	var state: Dictionary = (board.get("combat_state") as Dictionary).duplicate(true)
	var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	var player: Dictionary = state["player"]
	var point: Vector2 = board.call("world_position_for_unit_origin", player, player["pos"])
	presentation["unit_world_positions"] = {"player": point + Vector2(33, -16.5)}
	presentation["unit_draw_tiles"] = {"player": Vector2i(3, 4)}
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await _capture(viewport, "art_05_moving_actor.png")
	var moving: Image = viewport.get_texture().get_image()
	presentation = presentation.duplicate(true)
	presentation["umbra_action_actor_clips"] = {"player": {"hidden_tile": Vector2i(2, 3), "visible_tile": Vector2i(2, 4)}}
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	# A frozen pose has no motion submission to refresh its retained actor tile.
	board.call("_queue_dynamic_redraw")
	await _capture(viewport, "art_06_umbra_clip.png")
	_expect(_difference(moving, viewport.get_texture().get_image(), Rect2i(590, 240, 255, 210)) > 0.001, "Umbra clipping must conceal part of the interpolated actor")
	# A populated warm scene exercises source replacement and hot emissive art.
	presentation = presentation.duplicate(true)
	state = state.duplicate(true)
	presentation.erase("umbra_action_actor_clips")
	presentation.erase("unit_world_positions")
	presentation.erase("unit_draw_tiles")
	presentation["scene_props"] = [{"kind": "campfire_bonfire", "tile": Vector2i(4, 3)}]
	state["room_element"] = "fire"
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await _capture(viewport, "art_07_campfire.png")
	_expect((board.get("_scene_props_by_tile") as Dictionary).has(Vector2i(4, 3)), "Campfire must be present in retained art")
	_expect(int((board.call("art_treatment_snapshot") as Dictionary)["light_count"]) == 6, "Campfire contributes to shared actor light")
	presentation = presentation.duplicate(true)
	presentation["reduced_motion"] = false
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	board.process_mode = Node.PROCESS_MODE_ALWAYS
	await _capture(viewport, "art_08_normal_motion.png")
	var animated: Image = viewport.get_texture().get_image()
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	_expect(_difference(animated, viewport.get_texture().get_image(), Rect2i(590, 240, 255, 210)) > 0.0001, "Normal-motion cutout and lighting must continue rendering")
	await _verify_texture_contract()
	for error: String in _errors:
		push_error(error)
	print("ART TREATMENT PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _difference(a: Image, b: Image, region: Rect2i) -> float:
	var total: float = 0.0
	for y: int in range(region.position.y, region.end.y, 2):
		for x: int in range(region.position.x, region.end.x, 2):
			var first: Color = a.get_pixel(x, y)
			var second: Color = b.get_pixel(x, y)
			total += absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)
	return total / float(region.size.x * region.size.y / 4 * 3)

func _verify_texture_contract() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(520, 120)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var swatches := TextureSwatches.new()
	view.add_child(swatches)
	await _settle()
	var baseline: Image = view.get_texture().get_image()
	var treatment := preload("res://scripts/combat_art_treatment.gd").new()
	treatment.set_enabled(false)
	swatches.material = treatment.material
	swatches.tagged = true
	swatches.queue_redraw()
	await _settle()
	var bypass: Image = view.get_texture().get_image()
	_expect(_difference(baseline, bypass, Rect2i(0, 0, 520, 120)) < 0.0001, "Tagged quads must preserve texture regions, atlas margins, clipping and tint")
	treatment.set_enabled(true)
	await _settle()
	var painted: Image = view.get_texture().get_image()
	_expect(_difference(baseline, painted, Rect2i(334, 0, 186, 120)) == 0.0, "Untagged textured and solid feedback must bypass grading exactly")
	var alpha_error: bool = false
	# Grading must preserve the tagged path's alpha exactly. Native rectangle
	# and triangle rasterizers can select opposite sides of an exact texel tie;
	# the baseline color/margin comparison above bounds that separate effect.
	for y: int in range(120):
		for x: int in range(520):
			if painted.get_pixel(x, y).a != bypass.get_pixel(x, y).a:
				alpha_error = true
	_expect(not alpha_error, "Rim and grading must preserve source alpha, including translucent cutout pixels")
	view.queue_free()
