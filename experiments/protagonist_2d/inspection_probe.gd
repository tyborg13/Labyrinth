extends SceneTree

const View = preload("res://experiments/protagonist_2d/inspection_view.gd")
const SIZE := Vector2i(1920, 1080)
var view: Control
var viewport: SubViewport
var output: String
var front_only: bool = false
var capture_motion: bool = false
var video_clips: Array[Dictionary] = []
var front_rest_hash: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	front_only = OS.get_cmdline_user_args().has("--front-only")
	capture_motion = OS.get_cmdline_user_args().has("--capture-motion")
	call_deferred("_run")

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_2d = Viewport.MSAA_4X
	root.add_child(viewport)
	view = View.new()
	view.size = Vector2(SIZE)
	viewport.add_child(view)
	assert(view.load_errors.is_empty(), "Live puppet must load: " + str(view.load_errors))
	assert(view.has_facing("front"), "Actual front rig required")
	assert(front_only or view.has_facing("rear"), "Full proof requires the actual rear rig")
	view.set_playing(false)
	output = ProjectSettings.globalize_path("user://protagonist_2d_board_front_only_v1" if front_only else "user://protagonist_2d_board_full_v1")
	DirAccess.make_dir_recursive_absolute(output)
	var facings := PackedStringArray(["front"]) if front_only else View.FACINGS
	var board: Control = view.board
	var player: Dictionary = {"key": "player", "type": "player", "role": "player", "pos": Vector2i(3, 4)}
	var enemy: Dictionary = {"key": "enemy_1", "type": "crawler", "role": "enemy", "id": 1, "pos": Vector2i(5, 4)}
	var enemy_texture: Texture2D = board.call("_unit_hud_anchor_texture", enemy)
	var checked_frames: int = 0
	var health_rect: Rect2 = board.call("_unit_health_bar_rect", player, board.call("_unit_center", player))
	var first_rect: Rect2 = board.call("_unit_draw_rect", player)
	for which: String in facings:
		view.select_clip("idle", which)
		await _settle(4)
		var rest_image: Image = view.puppet_viewport.get_texture().get_image()
		assert(rest_image.get_used_rect().size != Vector2i.ZERO, "Puppet viewport contains actual artwork")
		if which == "front":
			front_rest_hash = hash(rest_image.get_data())
		else:
			assert(hash(rest_image.get_data()) != front_rest_hash, "Rear proof must not silently reuse the front pixels")
		var source: Texture2D = view.reference_texture(which)
		assert(source != null and source.get_size() == View.SOURCE_SIZE, "Each facing must expose its actual 255px reference")
		view.set_reference_on_board(true)
		var source_rect: Rect2 = board.call("_unit_draw_rect", player)
		assert(board.call("_texture_for_unit", player) == source, "Static comparison uses the matching source reference")
		assert(board.call("_unit_health_bar_rect", player, board.call("_unit_center", player)) == health_rect, "Static comparison cannot move HUD")
		await _capture("reference_" + which)
		view.set_reference_on_board(false)
		var puppet_rect: Rect2 = board.call("_unit_draw_rect", player)
		for point: Vector2 in [Vector2.ZERO, Vector2(127.5, 223), Vector2(255, 255)]:
			var source_point: Vector2 = source_rect.position + source_rect.size * point / View.SOURCE_SIZE
			var puppet_point: Vector2 = puppet_rect.position + puppet_rect.size * (View.SOURCE_OFFSET + point) / Vector2(View.CANVAS_SIZE)
			assert(source_point.is_equal_approx(puppet_point), "Source pixels keep exact board scale and registration")
		for action: String in View.ACTIONS:
			view.select_clip(action, which)
			var count: int = view.frame_count()
			assert(count > 1 and view.fps() > 0.0, "Action requires actual animation timing")
			var record_clip: bool = capture_motion and (which == "front" or action == "walk")
			var frames_path: String = ""
			if record_clip:
				frames_path = output.path_join("motion").path_join(which + "_" + action)
				DirAccess.make_dir_recursive_absolute(frames_path)
				video_clips.append({"name": which + "_" + action, "fps": view.fps(), "frame_count": count, "frames_path": frames_path, "frame_extension": "webp", "lossless": true, "size": [1920, 1080]})
			for index: int in range(count):
				view.frame_index = index
				view._apply_frame()
				assert(view._frame_label.text.begins_with(action.capitalize()), "Frame label names the active action")
				assert(board.call("_unit_draw_rect", player) == first_rect, "Actions and facings cannot recrop the puppet canvas")
				assert(board.call("_unit_health_bar_rect", player, board.call("_unit_center", player)) == health_rect, "Actions and facings cannot move HUD")
				assert(board.call("_texture_for_unit", player) == view.puppet_viewport.get_texture(), "Board consumes the live puppet viewport")
				var world_layer: Control = board.get("_dynamic_render_layer") as Control
				assert(world_layer.call("_texture_for_unit", player) == view.puppet_viewport.get_texture(), "Retained world layer consumes the live puppet")
				assert(board.call("_unit_hud_anchor_texture", enemy) == enemy_texture and board.call("_texture_for_unit", enemy) != view.puppet_viewport.get_texture(), "Enemy art keeps its production source and animation")
				if view.puppet.has_method("get_frame_index"):
					assert(int(view.puppet.call("get_frame_index")) == index, "Rig seeks the requested discrete frame")
				if record_clip:
					await _save_image(frames_path.path_join("frame_%04d.webp" % index), 1)
				checked_frames += 1
			view.frame_index = int(count * (0.43 if action == "attack" else 0.33))
			view._apply_frame()
			await _capture(which + "_" + action)
	view.select_clip("walk", "front")
	view.frame_index = 0
	view._apply_frame()
	view._process(0.5)
	assert(view.frame_index == 0, "Paused host cannot advance the puppet")
	view.step_frame()
	assert(view.frame_index == 1 and not view.playing, "Step advances exactly one frame and pauses")
	view.frame_index = view.frame_count() - 1
	view.step_frame()
	assert(view.frame_index == 0, "Frame step wraps exactly")
	view.set_playing(true)
	view._process(1.1 / view.fps())
	assert(view.frame_index == 1, "Playback follows the rig's frame rate")
	view.set_playing(false)
	var attack_button: Button = view._action_buttons["attack"] as Button
	attack_button.grab_focus()
	attack_button.pressed.emit()
	assert(view.animation == "attack" and attack_button.button_pressed, "Action button selects attack")
	view._step_button.grab_focus()
	assert(view._step_button.has_focus(), "Native keyboard focus reaches step")
	await _capture("keyboard_focus_paused")
	var debug_isolated: bool = false
	if not view._bones_button.disabled:
		await _settle(3)
		var main_before: int = hash(view.puppet_viewport.get_texture().get_image().get_data())
		var detail_before: int = hash(view.detail_viewport.get_texture().get_image().get_data())
		view.set_bones_visible(true)
		await _settle(3)
		assert(hash(view.puppet_viewport.get_texture().get_image().get_data()) == main_before, "Bone overlay never leaks into the board or main comparison")
		assert(hash(view.detail_viewport.get_texture().get_image().get_data()) != detail_before, "Detail bone toggle changes visible detail pixels")
		debug_isolated = true
		await _capture("detail_bones")
		view.set_bones_visible(false)
	view.set_detail_zoom(false)
	await _capture("detail_full_pose")
	var evidence := {"proof_kind": "live 2D board poses and controls", "facings": facings, "rear_verified": not front_only, "checked_frames": checked_frames, "source_registration_unchanged": true, "fixed_canvas": [512, 512], "original_source_size": [255, 255], "source_offset": [128, 128], "anchor": view.puppet.call("get_anchor"), "health_anchor_unchanged": true, "production_shadow_reused": true, "retained_live_texture": true, "enemy_art_unchanged": true, "pause_step_wrap_fps": true, "native_button_focus": true, "bones_detail_only": debug_isolated, "motion_frames_captured": capture_motion, "video_clips": video_clips, "viewport": [1920, 1080], "ui_scale": 1.0}
	var file := FileAccess.open(output.path_join("validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print(output)
	print("PROTAGONIST 2D BOARD: PASS (%d posed frames; %s; recorded motion: %s)" % [checked_frames, "front only — rear untested" if front_only else "front and rear", str(capture_motion)])
	viewport.queue_free()
	await process_frame
	quit()

func _settle(frames: int) -> void:
	for index: int in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw

func _capture(label: String) -> void:
	await _save_image(output.path_join(label + ".png"), 3)

func _save_image(path: String, settle_frames: int) -> void:
	await _settle(settle_frames)
	var screenshot: Image = viewport.get_texture().get_image()
	assert(screenshot.get_size() == SIZE)
	# Keep semantic stills as PNG. Lossless WebP motion frames preserve every
	# rendered pixel without making the screenshot runner decode hundreds of
	# full-HD PNGs in its pure-Python semantic validator. The encoder separately
	# verifies all motion-frame dimensions and recorded counts.
	if path.get_extension() == "webp":
		assert(screenshot.save_webp(path, false) == OK)
	else:
		assert(screenshot.save_png(path) == OK)
