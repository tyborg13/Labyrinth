extends "res://tools/inspection_fixture.gd"
## Drives real movement selection and commits in an exact-size combat viewport.

const Fixtures = preload("res://tools/gfix48/fixtures.gd")
const Bump = preload("res://scripts/umbra_movement_view.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const IntentBadges = preload("res://scripts/intent_badges.gd")

const CAPTURE_SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const CAPTURE_FPS: int = 100
const FRAME_MSEC: int = 1000 / CAPTURE_FPS
const SAMPLE_INTERVAL_MSEC: int = 30
const RAIL_CAPTURE_DELAY_MSEC: int = 60
const POPUP_FRAME_TOLERANCE: int = 1
const READY_TIMEOUT_MSEC: int = 12000
const SETTLE_FRAMES: int = 8
const MAX_STRIP_MSEC: int = 5000

var _viewport: SubViewport
var _scene: Control
var _directory: String
var _output: String
var _dry_run: bool
var _playing: bool

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_probe")

func _probe() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_index: int = args.find("--out")
	_output = args[out_index + 1] if out_index >= 0 and out_index + 1 < args.size() else ""
	_dry_run = args.has("--dry-run")
	if not _output.is_absolute_path() or _dry_run != (DisplayServer.get_name() == "headless") or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("expected an absolute --out path, LABYRINTH_CEL_LOOK=all and matching --dry-run mode")
		return
	for first: bool in [true, false]:
		for reduced: bool in [false, true]:
			var label: String = "%s_%s" % ["first" if first else "one_step", "reduced" if reduced else "normal"]
			_directory = _output.path_join(label)
			if not await _open(first, reduced):
				_fail("could not open %s" % label)
				return
			if not await _replay(label, first, reduced):
				_fail("playback proof failed for %s" % label)
				return
			_viewport.queue_free()
			await process_frame
	print("GFIX-48 SCENE STRIPS: 4 cases, 0 failures (%s)" % ("headless dry run" if _dry_run else "native"))
	quit()

func _replay(label: String, first: bool, reduced: bool) -> bool:
	var before: Dictionary = _scene._combat_state.duplicate(true)
	var reached: Vector2i = Fixtures.HERO if first else Fixtures.REACHED
	var target: Vector2i = Fixtures.BLOCKED if first else Fixtures.ONE_STEP_TARGET
	var blocker_id: int = Fixtures.HIDDEN_ACOLYTE_ID if first else Fixtures.BLOCKER_ID
	var blocker_key: String = "enemy_%d" % blocker_id
	var steps: int = 0 if first else 1
	if _scene._reduced_motion_enabled() != reduced or _viewport.size != CAPTURE_SIZE or not is_equal_approx(Typography.ui_scale(_scene), UI_SCALE):
		return _reject("viewport or motion settings")
	var board: Control = _scene.board_view
	if _scene.room_title.text != before["room_name"] or _scene.room_title.text.to_lower().contains("proof"):
		return _reject("encounter title differs from the room")
	await _scene._on_board_tile_clicked(Fixtures.HERO)
	_scene._on_board_tile_hovered(target)
	await process_frame
	await RenderingServer.frame_post_draw
	if not _scene._player_movement_target_tiles.has(target) or not (board.presentation.get("path_tiles", []) as Array).has(Fixtures.BLOCKED):
		return _reject("original Move offer missing")
	if not _save_frame(label + "_offer_before", _read_image()): return false

	var cue_frames: Array[int]
	_scene._sfx_bank.cue_requested.connect(func(cue_id: String, result: String) -> void:
		if cue_id == "push.collision" and result != "unknown": cue_frames.append(Engine.get_process_frames())
	)
	var hero: Dictionary = _scene._animation_actor_unit(before, "player")
	var blocker: Dictionary = _scene._animation_actor_unit(before, blocker_key)
	if _rail_revealed(blocker_key, blocker["hp"]):
		return _reject("blocker rail slot already revealed before the click")
	var origin: Vector2 = board.world_position_for_unit_origin(hero, reached)
	var blocker_origin: Vector2 = board.world_position_for_unit_origin(blocker, blocker["pos"])
	var towards: Vector2 = board.world_position_for_unit_origin(hero, Fixtures.BLOCKED) - origin
	var lunge: Vector2 = towards * Bump.LUNGE_TILES / Vector2(Fixtures.BLOCKED - reached).length()
	var style: Dictionary = FloatingText.resource_entry("card_play", reached, 1, {"offset": -6.0})
	var pictures: Dictionary = {}
	var contact: int = -1
	var contact_process_frame: int = -1
	var rail_capture_frame: int = -1
	var popup_frames: int = 0
	var last_elapsed: float = -1.0
	var lobe_count: int = 0
	var last_sign: float = 0.0
	var stopped: bool = false
	var stride: int = SAMPLE_INTERVAL_MSEC / FRAME_MSEC
	var limit: int = MAX_STRIP_MSEC / FRAME_MSEC
	await process_frame
	var other_rail_entries: Array[Dictionary] = _other_rail_entries(blocker_key)
	_click_target(target)
	for frame: int in range(limit):
		# The authored walk uses wall time. Keep its normal cadence in dry runs.
		if _dry_run: OS.delay_msec(FRAME_MSEC)
		await RenderingServer.frame_post_draw
		var shown: Dictionary = board.presentation
		var popup: Dictionary = _interruption(shown.get("floating_texts", []))
		var visible: bool = (shown.get("visible_enemy_ids", []) as Array).has(blocker_id)
		if contact < 0 and popup.is_empty() and (visible or _rail_revealed(blocker_key, blocker["hp"])):
			return _reject("board or rail revealed the blocker before contact")
		if contact >= 0 or not popup.is_empty():
			if _playing and (not visible or not _contact_visible(board, blocker_key, before["player"]["hp"], blocker["hp"])):
				return _reject("playback missing the blocker, Health bar or laid-out intent chip at %d ms" % (frame * FRAME_MSEC))
			if _playing and (not _rail_revealed(blocker_key, blocker["hp"]) or _other_rail_entries(blocker_key) != other_rail_entries):
				return _reject("playback rail did not reveal only the blocker at %d ms" % (frame * FRAME_MSEC))
		if not popup.is_empty():
			if not visible: return _reject("blocker hidden during popup")
			var positions: Dictionary = shown.get("unit_world_positions", {})
			var hero_position: Vector2 = positions.get("player", Vector2.INF)
			var blocker_position: Vector2 = positions.get(blocker_key, blocker_origin)
			if contact < 0:
				contact = frame
				contact_process_frame = Engine.get_process_frames()
				if not hero_position.is_equal_approx(origin if reduced else origin + lunge):
					return _reject("hero not at the contact position")
				if not _dry_run: pictures["%s_contact" % label] = _read_image()
			if frame == contact + RAIL_CAPTURE_DELAY_MSEC / FRAME_MSEC:
				rail_capture_frame = frame
				if not _dry_run: pictures["%s_contact_plus_%04dms" % [label, RAIL_CAPTURE_DELAY_MSEC]] = _read_image()
			var elapsed: float = float(popup["animation_progress"]) * FloatingText.ANIMATION_DURATION_SECONDS
			if (popup_frames == 0 and elapsed != 0.0) or (reduced and elapsed != 0.0) or (not reduced and elapsed <= last_elapsed):
				return _reject("popup clock did not advance with the motion setting")
			last_elapsed = elapsed
			var expected: Dictionary = FloatingText.animate_entries([style], 0.0 if reduced else elapsed, reduced)[0]
			var style_difference: String = _popup_style_difference(popup, expected)
			if not style_difference.is_empty():
				return _reject("popup style, motion or fade differs from Card Play at %d ms (progress %s): %s" % [roundi(elapsed * 1000.0), popup.get("animation_progress"), style_difference])
			var shake: Vector2 = blocker_position - blocker_origin
			if reduced:
				if not shake.is_zero_approx() or not hero_position.is_equal_approx(origin):
					return _reject("reduced motion moved an actor")
				var popup_error: String = _reduced_popup_error(board, str(popup["screen_layout_key"]))
				if not popup_error.is_empty(): return _reject(popup_error)
				if popup_frames == 0:
					print("GFIX-48 POPUP PAINTER %s: %s" % [label, _floating_text_painter(board).get_path()])
			else:
				var expected_lunge: Vector2 = lunge * Bump._lunge(Bump.OUT_SECONDS + elapsed, false)
				if not is_zero_approx(shake.y) or absf(shake.x) > Bump.SHAKE_PIXELS or not hero_position.is_equal_approx(origin + expected_lunge + shake):
					return _reject("actors did not share the horizontal shake")
				if elapsed >= Bump.SHAKE_SECONDS and not shake.is_zero_approx():
					return _reject("shake extended beyond its contact beat")
				var direction: float = signf(shake.x)
				if direction != 0.0 and direction != last_sign:
					lobe_count += 1
					last_sign = direction
			if _has_hit_feedback(shown, blocker_key): return _reject("collision submitted damage or hit flash")
			popup_frames += 1
		if frame % stride != 0: continue
		if not _dry_run: pictures["%s_strip_%04dms" % [label, frame * FRAME_MSEC]] = _read_image()
		if contact >= 0 and popup.is_empty():
			stopped = true
			break

	var duration: float = Bump.REDUCED_SECONDS if reduced else FloatingText.ANIMATION_DURATION_SECONDS
	if not stopped or rail_capture_frame < 0 or absi(popup_frames - roundi(duration * CAPTURE_FPS)) > POPUP_FRAME_TOLERANCE or lobe_count != (0 if reduced else 6) or cue_frames.size() != 1:
		return _reject("feedback timing, shake or sound: %s" % [str([stopped, popup_frames, lobe_count, cue_frames])])
	# The emulated headless frame_post_draw can observe the previous submission.
	if absi(cue_frames[0] - contact_process_frame) > (1 if _dry_run else 0):
		return _reject("collision cue did not land on the reveal frame")
	for capture_name: String in pictures:
		if not _save_frame(capture_name, pictures[capture_name]): return false
	for frame: int in range(limit):
		if not _playing: break
		await RenderingServer.frame_post_draw
		if _playing and (not _contact_visible(board, blocker_key, before["player"]["hp"], blocker["hp"]) or not _rail_revealed(blocker_key, blocker["hp"])):
			return _reject("post-popup playback lost the blocker chip or rail slot")

	var after: Dictionary = _scene._combat_state
	var outcome: Dictionary = Fixtures.outcome(_combat_engine, before, after, target)
	print("GFIX-48 SCENE ", label, " ", JSON.stringify(outcome))
	if _playing or outcome["destination"] != reached or outcome["spent"] != steps or after["enemies"] != before["enemies"] or after["player"]["hp"] != before["player"]["hp"]:
		return _reject("changed combat outcome")
	var resumed: Dictionary = ProgressionStore.load_checkpoint_for_resume().get("combat_state", {})
	var durable_move: Dictionary = resumed.get("last_player_movement", {})
	if resumed.is_empty() or resumed.has("remembered_umbra_blockers") or resumed["player"]["pos"] != reached or durable_move.get("spent") != steps:
		return _reject("post-bump checkpoint lost the outcome or retained the legacy key")
	await _scene._on_board_tile_clicked(reached)
	_scene._on_board_tile_hovered(Fixtures.BLOCKED)
	await process_frame
	await RenderingServer.frame_post_draw
	if _scene._player_movement_target_tiles.has(Fixtures.BLOCKED) != first:
		return _reject("next Move offer disagrees with ordinary sight")
	if not _save_frame(label + "_offer_after", _read_image()) or not _move_event_logged(first, steps): return false
	print("GFIX-48 STRIP %s: contact=%d ms, popup=%d ms, %d shake half-cycles, 1 collision cue, save/resume PASS" % [
		label, contact * FRAME_MSEC, popup_frames * FRAME_MSEC, lobe_count
	])
	print("GFIX-48 DISCLOSURE %s: %s contact chip and portrait/Health verified through playback, +%d ms frame checked" % [
		label, _scene.room_title.text, RAIL_CAPTURE_DELAY_MSEC
	])
	if reduced: print("GFIX-48 REDUCED PAINT %s: popup opaque and clear of the live caption on the floating-text canvas" % label)
	return true

func _click_target(tile: Vector2i) -> void:
	_playing = true
	await _scene._on_board_tile_clicked(tile)
	_playing = false

func _interruption(entries: Array) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.get("text") == "Interrupted": return entry
	return {}

func _contact_visible(board: Control, blocker_key: String, hero_hp: int, blocker_hp: int) -> bool:
	var rows: Array = board.presentation.get("threats_at_rest", {}).get("badges", [])
	var badges: Array[Dictionary] = IntentBadges.layouts(board, rows)
	if not badges.any(func(badge: Dictionary) -> bool: return badge.get("key") == blocker_key and (badge["rect"] as Rect2).has_area()):
		return false
	var units: Array[Dictionary] = board._visible_units()
	for entry: Dictionary in board._health_bar_draw_entries(units):
		var unit: Dictionary = entry["unit"]
		if unit.get("key") != blocker_key: continue
		return unit["hp"] == blocker_hp and board.combat_state["player"]["hp"] == hero_hp \
			and (is_instance_valid(board.unit_cutout_renderer(unit)) or board._texture_for_unit(unit) != null) \
			and (board.presentation.get("enemy_intent_compasses", {}) as Dictionary).has(blocker_key)
	return false

func _other_rail_entries(blocker_key: String) -> Array[Dictionary]:
	return _scene._turn_order_rendered_entries.filter(func(entry: Dictionary) -> bool: return entry.get("actor_key") != blocker_key)

func _rail_revealed(blocker_key: String, hp: int) -> bool:
	for slot: Control in _scene._turn_order_bar.get_children():
		if slot.get_meta("turn_order_actor_key", "") != "enemy:" + blocker_key: continue
		var portrait: Texture2D = slot.get_meta("turn_order_portrait_texture", null)
		var bar: SegmentedHealthBar = slot.get_node_or_null("TurnOrderHealthBar") as SegmentedHealthBar
		return portrait != null and not portrait.resource_path.ends_with("umbra_presence.png") and bar != null and bar.is_visible_in_tree() and bar.value == hp
	return false

func _reduced_popup_error(board: Control, popup_key: String) -> String:
	var scrim: Control = _scene.action_banner.get_node("ActionCaptionScrim")
	var caption: Rect2 = scrim.get_global_transform_with_canvas() * scrim.caption_scrim_rect()
	if not scrim.is_visible_in_tree() or not caption.has_area(): return "missing live Movement caption scrim"
	var painter: Control = _floating_text_painter(board)
	# Native proof reads the recorded draw on its actual canvas. Headless runs
	# the same placement on that canvas without relying on draw notifications.
	var layout: Array[Dictionary] = painter._floating_text_screen_layout(painter.get_theme_default_font()) if _dry_run else painter._floating_text_last_layout
	for item: Dictionary in layout:
		var entry: Dictionary = item["entry"]
		if entry.get("screen_layout_key") != popup_key: continue
		if float(entry["alpha"]) != 1.0 or (entry["color"] as Color).a != 1.0:
			return "the painted reduced-motion popup lost opacity"
		var placed: Rect2 = item["rendered_rect"]
		placed.position += item["layout_offset"]
		placed = painter.get_global_transform_with_canvas() * placed
		if placed.intersects(caption):
			return "the painted reduced-motion popup %s intersects the live caption scrim %s" % [placed, caption]
		return ""
	return "reduced-motion popup has no placement on %s (layout size %d)" % [painter.name, layout.size()]

func _floating_text_painter(board: Control) -> Control:
	var effects: Control = board._effects_render_layer
	if effects == null: return board
	# The threat-isolation plan paints floating text on its animated child
	# canvas. The effects parent only records layouts when drawing unsliced.
	for canvas: Control in effects._layer_slices.canvases:
		for operation: Array in canvas._render_slice_ops:
			if operation[0] == "_draw_floating_texts": return canvas
	return effects

func _popup_style_difference(popup: Dictionary, expected: Dictionary) -> String:
	for key: String in ["color", "font_size", "outline_size", "alignment", "motion_offset", "font_scale", "alpha", "offset"]:
		var value: Variant = popup.get(key)
		var reference: Variant = expected[key]
		var matches: bool = value == reference
		if value is float: matches = is_equal_approx(value, reference)
		if value is Vector2: matches = value.is_equal_approx(reference)
		if not matches: return "%s was %s, expected %s" % [key, value, reference]
	return ""

func _has_hit_feedback(shown: Dictionary, blocker_key: String) -> bool:
	var flashes: Dictionary = shown.get("combat_feel_flash", {})
	if flashes.has("player") or flashes.has(blocker_key): return true
	for entry: Dictionary in shown.get("floating_texts", []):
		if FloatingText.is_damage_entry(entry): return true
	return false

func _reject(reason: String) -> bool:
	printerr("GFIX-48 PROBE FAILURE ", reason)
	return false

func _read_image() -> Image:
	return null if _dry_run else _viewport.get_texture().get_image()

func _save_frame(label: String, image: Image) -> bool:
	if _dry_run: return true
	var path: String = _output.path_join(label + ".png")
	if image == null or image.get_size() != CAPTURE_SIZE or image.save_png(path) != OK: return false
	print(path)
	return true

func _move_event_logged(first: bool, steps: int) -> bool:
	var directory: String = _directory.path_join("analytics")
	for filename: String in DirAccess.get_files_at(directory):
		if not filename.ends_with(".jsonl"): continue
		var journal: FileAccess = FileAccess.open(directory.path_join(filename), FileAccess.READ)
		if journal == null: continue
		while journal.get_position() < journal.get_length():
			var event: Variant = JSON.parse_string(journal.get_line())
			if not event is Dictionary: continue
			var expected: String = "player_movement_interrupted" if first else "player_moved"
			if event.get("event_type") != expected: continue
			var payload: Dictionary = event.get("payload", {})
			var tile: Dictionary = payload.get("blocked_tile", {})
			if int(payload.get("steps_reached", -1)) == steps and Vector2i(int(tile.get("x", -1)), int(tile.get("y", -1))) == Fixtures.BLOCKED and not str(payload).contains("remembered_umbra_blockers"):
				return true
	print("GFIX-48 missing move event ", first, " ", steps)
	return false

func _open(first: bool, reduced: bool) -> bool:
	DirAccess.make_dir_recursive_absolute(_directory)
	ProgressionStore.set_storage_path(_directory.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(_directory.path_join("run.save"))
	Settings.set_storage_path(_directory.path_join("settings.json"))
	Analytics.set_storage_dir(_directory.path_join("analytics"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = reduced
	if not Settings.save_settings(settings): return false
	if first:
		if not _save_last_eclipse_capture(): return false
	else:
		_options = {"scenario": "combat", "seed": Fixtures.FIXTURE_SEED}
		var progression: Dictionary = Tutorial.complete_tutorial(_build_progression())
		var run: Dictionary = _build_run_state("combat", progression)
		var layout: Dictionary = run["current_room_layout"]
		var collision: Dictionary = Fixtures.layout()
		for field: String in ["umbra_stage", "player_start", "enemies"]:
			layout[field] = collision[field]
		run["combat_state"] = Fixtures.one_step(_combat_engine, layout)
		run["relics"] = [Fixtures.FIXTURE_MOVEMENT_RELIC]
		run["player_hp"] = Fixtures.FIXTURE_HP
		run["player_max_hp"] = Fixtures.FIXTURE_HP
		if not ProgressionStore.save_data(progression) or not ProgressionStore.save_run_state(run): return false
	_viewport = SubViewport.new()
	_viewport.size = CAPTURE_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_2d = root.msaa_2d
	root.content_scale_factor = 1.0
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	var cutoff: int = Time.get_ticks_msec() + READY_TIMEOUT_MSEC
	while not _scene.initial_presentation_is_ready() and Time.get_ticks_msec() < cutoff:
		await process_frame
	_scene._close_dialogue()
	for index: int in range(SETTLE_FRAMES):
		await process_frame
	return _scene.initial_presentation_is_ready() and _scene._run_state.get("mode") == "combat"

func _save_last_eclipse_capture() -> bool:
	var profile: String = "progression.json"
	if DirAccess.copy_absolute(Fixtures.CHECKPOINT_DIR.path_join(profile), _directory.path_join(profile)) != OK:
		return _reject("could not copy the Last Eclipse profile")
	var run: Dictionary = Fixtures.checkpoint()
	if run.is_empty(): return _reject("could not load the Last Eclipse checkpoint")
	# The hunt overrides Health for endurance. Use the production starting
	# values at the saved difficulty for the capture's copy of that checkpoint.
	var max_hp: int = RunEngine.DepthRules.start_max_hp(run, RunEngine.BASE_MAX_HP)
	var hp: int = RunEngine.DepthRules.start_hp(run, max_hp)
	run["player_max_hp"] = max_hp
	run["player_hp"] = hp
	run["combat_state"]["player"]["max_hp"] = max_hp
	run["combat_state"]["player"]["hp"] = hp
	if not ProgressionStore.save_run_state(run): return _reject("could not save the Last Eclipse capture checkpoint")
	print("GFIX-48 CAPTURE HEALTH Last Eclipse: %d/%d" % [hp, max_hp])
	return true
