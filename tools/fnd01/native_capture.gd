extends SceneTree
## Shared with the fx-12 project via an absolute --script path for before/after parity.

const Settings = preload("res://scripts/settings_store.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const FRAMEBUFFER := Vector2i(1920, 1080)
const SINK := Vector2i(64, 64)
const CROP := Vector2i(640, 640)
const FPS := 60
const PLAN_FRAME_MSEC := 16
const CLIP_LEAD_FRAMES := 18
const CLIP_TAIL_FRAMES := 30
const ACQUISITION_MOTE_Z := 1601
const CAPTURE_OVERLAY_LAYER := 512
# Delivery scales 1920 to 1280, so 54 source pixels become 36 output pixels.
const CAPTION_SOURCE_SIZE := 54
const CAPTION_SOURCE_MARGIN := Vector2(36.0, 30.0)
const CAPTION_SOURCE_OUTLINE := 5
const SNAP_FRAMES: Array[int] = [0, 4, 8, 14, 22, 30]
const SETUP_FRAMES := 32
const FOCUS_SETTLE_FRAMES := 10
const TAKE_LIMIT := 240
const SEED := 9138
const ROOM := Vector2i(1, 0)
const PICKUP_TILE := Vector2i(3, 4)
const REWARD_CARDS: Array[String] = ["spark_dart", "frost_nova", "threaded_path"]
const CASES := {
	"item": ["ItemAcquisitionIcon", "crimson_draught", "card_id"],
	"gear": ["EquipmentAcquisitionIcon", "ward_kite", "equipment_id"],
	"common": ["CardProxy", "spark_dart", "common"],
	"epic": ["CardProxy", "frost_nova", "epic"],
}

var _run: Control
var _viewport: SubViewport
var _out: String
var _plan: bool
var _clip: bool
var _movie_sync: ColorRect
var _after: bool
var _reduced: bool
var _finished: bool

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_take.call_deferred()

func _arg(key: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _take() -> void:
	var id: String = _arg("--case")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = _arg("--out")
	_plan = args.has("--plan")
	_clip = args.has("--clip")
	_after = args.has("--after")
	_reduced = args.has("--reduced")
	if not CASES.has(id) or _out.is_empty():
		_fail("Provide --case item|gear|common|epic and --out.")
		return
	if not _plan and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty()
			or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all"):
		_fail("Native proof requires the visual probe runner, MovieWriter at 60 fps and cel look all.")
		return
	if _plan:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	elif _clip:
		# The small MovieWriter sink carries an audio sync mark. The game is
		# rendered in its own full-size viewport and never shows the mark.
		_movie_sync = ColorRect.new()
		_movie_sync.color = Color.RED
		_movie_sync.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_attach_capture_overlay(root, _movie_sync)
		_movie_sync.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var is_pickup: bool = id in ["item", "gear"]
	var spec: Array = CASES[id]
	if not await _start(id, spec, is_pickup):
		_fail("The fixture did not open on the production board or reward screen.")
		return
	if _clip and not _plan: _add_clip_caption()
	var widget: Control = null if is_pickup else _reward_widget(spec[1])
	if not is_pickup and (widget == null or GameData.card_rarity(spec[1]) != spec[2]):
		_fail("The requested %s reward card is unavailable." % id)
		return
	if widget != null:
		# Exercise the largest prepared card size and use the real focus path.
		widget.grab_focus()
		for frame: int in FOCUS_SETTLE_FRAMES: await process_frame
	var center: Vector2 = _run._board_global_position_for_tile(PICKUP_TILE) if is_pickup else widget.get_global_rect().get_center()
	var pacing: Dictionary = await _observe(id, spec, widget, center)
	_viewport.queue_free()
	await process_frame
	if pacing.is_empty(): return
	var output: FileAccess = FileAccess.open(_out.path_join("take.json"), FileAccess.WRITE)
	if output == null:
		_fail("Cannot write take.json.")
		return
	output.store_string(JSON.stringify(pacing, "	"))
	print(_out)
	print("FND-01 %s %s" % ["PLAN" if _plan else "NATIVE", JSON.stringify(pacing)])
	print("TEST RESULT: PASS")
	quit(0)

func _attach_capture_overlay(viewport: Viewport, overlay: Control) -> void:
	var layer := CanvasLayer.new()
	layer.layer = CAPTURE_OVERLAY_LAYER
	viewport.add_child(layer)
	layer.add_child(overlay)

func _add_clip_caption() -> void:
	var caption := Label.new()
	caption.text = "Now" if _after else "Before"
	caption.position = CAPTION_SOURCE_MARGIN
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_override("font", Typography.ui_font())
	caption.add_theme_font_size_override("font_size", CAPTION_SOURCE_SIZE)
	caption.add_theme_color_override("font_color", Color("fff4db"))
	caption.add_theme_color_override("font_outline_color", Color("160d0a"))
	caption.add_theme_constant_override("outline_size", CAPTION_SOURCE_OUTLINE)
	_attach_capture_overlay(_viewport, caption)

func _start(id: String, spec: Array, is_pickup: bool) -> bool:
	var profile: Dictionary = ProgressionStore.default_data()
	for prompt: String in Tutorial.prompt_ids():
		profile = Tutorial.resolve_progression(profile, prompt)
	var state: Dictionary = Run.new().create_new_run(SEED, profile)
	if is_pickup:
		var loot: Dictionary = {"kind": "equipment" if id == "gear" else id, "pos": PICKUP_TILE}
		loot[spec[2]] = spec[1]
		state["mode"] = "combat"
		state["combat_state"] = _combat_state(loot, state)
	else:
		state["mode"] = "reward"
		state["pending_reward"] = {"cards": REWARD_CARDS.duplicate(), "intro_pending": false, "heal_amount": Run.REWARD_HEAL}
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = _reduced
	if not Settings.save_settings(settings) or not ProgressionStore.save_data(profile) or not ProgressionStore.save_run_state(state):
		return false
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SINK
	root.content_scale_size = SINK
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = FRAMEBUFFER
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _plan else SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_run = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_run)
	_run._close_dialogue()
	for frame: int in SETUP_FRAMES: await process_frame
	return _run.initial_presentation_is_ready() and _run._run_state["mode"] == state["mode"] and is_equal_approx(root.content_scale_factor, 1.0)

func _combat_state(loot: Dictionary, state: Dictionary) -> Dictionary:
	var grid: Array
	for y: int in 7:
		var row: Array
		for x: int in 9:
			row.append("wall" if x in [0, 8] or y in [0, 6] else "stone")
		grid.append(row)
	var layout: Dictionary = {
		"name": "Acquisition Proof", "coord": ROOM, "type": "combat", "grid": grid,
		"player_start": PICKUP_TILE + Vector2i.LEFT,
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(6, 2), "hp": 14, "max_hp": 14}],
		"loot": [loot],
	}
	return Combat.new().create_combat(SEED, layout, {
		"hp": int(state["player_hp"]), "max_hp": int(state["player_max_hp"]),
		"deck_cards": state["deck_cards"], "hand_size": int(state["hand_size"]),
		"relics": [], "cards_per_turn": 2, "draw_per_turn": 2,
	})

func _reward_widget(card_id: String) -> Control:
	var row: Node = _run.find_child("RewardCardRow", true, false)
	if row == null: return null
	for slot: Node in row.get_children():
		if slot.get_meta("reward_card_id", "") == card_id:
			return slot.find_child("CardWidget", true, false) as Control
	return null

func _launch(widget: Control, card_id: String) -> void:
	if widget != null:
		await _run._on_reward_card_pressed(card_id, widget)
	else:
		_run._begin_player_movement_selection()
		if not _run._player_movement_target_tiles.has(PICKUP_TILE):
			_fail("Cannot walk to pickup tile from %s (available: %s)." % [
				str(_run._combat_state.get("player", {}).get("pos")), str(_run._player_movement_target_tiles),
			])
			return
		await _run._commit_player_movement(PICKUP_TILE)
	_finished = true

func _visible_fx(node_name: String) -> Control:
	var layer: Control = _run._card_fx_layer
	for node: Node in layer.find_children(node_name, "Control", false, false):
		if node.is_visible_in_tree() and not node.is_queued_for_deletion():
			return node
	return null

func _acquisition_fx_active(subject: Control, burst: Node) -> bool:
	if subject != null or burst != null: return true
	for child: Node in _run._card_fx_layer.get_children():
		if child is Control and child.is_visible_in_tree() and not child.is_queued_for_deletion():
			# Sibling motes can receive anonymous names from Godot.
			if child.z_index == ACQUISITION_MOTE_Z or child.name in [
				"LoadoutAcquisitionBanner", "PickupDestinationReceipt", "LoadoutAcquisitionBeam",
			]:
				return true
	return false

func _observe(id: String, spec: Array, widget: Control, center: Vector2) -> Dictionary:
	var pickup: bool = widget == null
	var target: String = spec[0]
	var cut := Rect2i(Vector2i(center.round()) - CROP / 2, CROP)
	cut.position = cut.position.clamp(Vector2i.ZERO, FRAMEBUFFER - CROP)
	var strip: Image
	if not _plan: strip = Image.create_empty(CROP.x * SNAP_FRAMES.size(), CROP.y, false, Image.FORMAT_RGB8)
	var started: int = -1
	var ray: int = -1
	var subject_end: int = -1
	var complete: int = -1
	var burst_end: int = -1
	var captured: int = 0
	var clip_frames: int = 0
	var clip_pickup: int = -1
	var clip_settled: int = -1
	var raw: FileAccess
	if _clip and not _plan:
		raw = FileAccess.open(_out.path_join("frames.rgb"), FileAccess.WRITE)
		if raw == null:
			_fail("Cannot open the full-frame capture stream.")
			return {}
		# Set the mark before the first post-draw readback and let it persist.
		await process_frame
		_movie_sync.color = Color.LIME
	var capture_origin: int = Engine.get_process_frames()
	if not _clip: _launch(widget, spec[1])
	for tick: int in TAKE_LIMIT:
		if _clip and clip_frames == CLIP_LEAD_FRAMES: _launch(widget, spec[1])
		if _plan:
			# Some surrounding combat beats use the wall clock outside MovieWriter.
			OS.delay_msec(PLAN_FRAME_MSEC)
			await process_frame
		else:
			await RenderingServer.frame_post_draw
		var frame: int = Engine.get_process_frames() - capture_origin
		var subject: Control = _visible_fx(target)
		var burst: Node = _run.find_child("AcquisitionBurst" if _after else "LoadoutAcquisitionBurst", true, false)
		if burst != null and burst.is_queued_for_deletion(): burst = null
		var image: Image
		if _clip:
			if raw != null:
				image = _read_frame()
				if image == null: return {}
				raw.store_buffer(image.get_data())
			if subject != null and clip_pickup < 0: clip_pickup = clip_frames
			if clip_pickup >= 0 and _finished and not _acquisition_fx_active(subject, burst):
				if clip_settled < 0: clip_settled = clip_frames
			else:
				clip_settled = -1
			clip_frames += 1
		if started < 0 and subject != null:
			started = frame
			if (burst != null) == (pickup and _reduced):
				_fail("Burst availability at pickup/claim differed from reduced-motion policy.")
				return {}
			if pickup:
				var pickup_center: Vector2 = subject.position + subject.pivot_offset
				# Reduced motion parks the icon at the receipt instead of the board site.
				if not _reduced:
					cut.position = (Vector2i(pickup_center.round()) - CROP / 2).clamp(Vector2i.ZERO, FRAMEBUFFER - CROP)
			if _after and burst != null:
				if burst.get("frame") != 0 or burst.z_index != (1600 if pickup else subject.z_index - 1):
					_fail("The burst must start on frame 0 behind its subject.")
					return {}
		if started >= 0:
			var elapsed: int = frame - started
			if pickup and _reduced and burst != null:
				_fail("A reduced-motion pickup produced a burst.")
				return {}
			if _after and not pickup and subject != null and burst != null:
				if not burst.position.is_equal_approx(subject.position + subject.pivot_offset):
					_fail("Burst stopped tracking the reward card's lift on frame %d." % elapsed)
					return {}
			if ray < 0 and _visible_fx("LoadoutAcquisitionBeam") != null: ray = elapsed
			if subject_end < 0 and subject == null: subject_end = elapsed
			if burst_end < 0 and burst == null: burst_end = elapsed
			if captured < SNAP_FRAMES.size() and elapsed == SNAP_FRAMES[captured]:
				if not _plan:
					if image == null: image = _read_frame()
					if image == null: return {}
					if captured == 0 and not _save(image, "native-evidence.png"): return {}
					strip.blit_rect(image, cut, Vector2i(captured * CROP.x, 0))
				captured += 1
			if _finished and complete < 0: complete = elapsed
			if complete >= 0 and captured == SNAP_FRAMES.size():
				if not _clip or (clip_settled >= 0 and clip_frames == clip_settled + CLIP_TAIL_FRAMES):
					break
		if not _plan: await process_frame
	if raw != null:
		var write_error: Error = raw.get_error()
		raw.close()
		if write_error != OK:
			_fail("Writing full-frame capture failed (%d)." % write_error)
			return {}
	if started < 0 or (not _reduced and ray < 0) or subject_end < 0 or complete < 0 or captured != SNAP_FRAMES.size():
		_fail("Incomplete %s fixture (start=%d ray=%d end=%d complete=%d samples=%d finished=%s locked=%s loot=%s)." % [
			id, started, ray, subject_end, complete, captured, _finished, _run._animation_lock,
			str(_run._combat_state.get("loot", [])),
		])
		return {}
	if _after and not pickup and burst_end <= subject_end:
		_fail("The reward burst must outlive the released proxy.")
		return {}
	if pickup and not bool((_run._combat_state["loot"][0] as Dictionary).get("claimed", false)):
		_fail("The real combat step did not collect the requested loot.")
		return {}
	if not pickup and not (_run._run_state.get("pending_reward", {}) as Dictionary).is_empty():
		_fail("The real reward claim did not settle.")
		return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	var result: Dictionary = {"case": id, "reduced": _reduced, "ray": ray, "subject_end": subject_end, "complete": complete, "burst_end": burst_end}
	if _clip:
		if clip_pickup < CLIP_LEAD_FRAMES or clip_settled < clip_pickup or clip_frames != clip_settled + CLIP_TAIL_FRAMES:
			_fail("Clip needs 18 frames before acquisition and 30 after its last effect.")
			return {}
		result["clip"] = {
			"fps": FPS, "width": FRAMEBUFFER.x, "height": FRAMEBUFFER.y,
			"first_frame": clip_pickup - CLIP_LEAD_FRAMES, "pickup_frame": clip_pickup,
			"settled_frame": clip_settled, "end_frame": clip_frames,
		}
	return result

func _read_frame() -> Image:
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != FRAMEBUFFER:
		_fail("Native framebuffer differs from 1920x1080.")
		return null
	image.convert(Image.FORMAT_RGB8)
	return image

func _save(image: Image, file_name: String) -> bool:
	var error: Error = image.save_png(_out.path_join(file_name))
	if error == OK: return true
	_fail("Could not save %s (%d)." % [file_name, error])
	return false

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
