extends SceneTree
## Exercise the production title transition, event choices and Pass playback.

const Geometry = preload("geometry.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Notices = preload("res://scripts/run_notification_queue.gd")
const SEED: int = 127800
const EVENT_ID: String = "bloodletters_basin"
const DISCOVERIES: Array = ["enemy:warden", "enemy:harrier"]
const SETTLE_FRAMES: int = 5
const WAIT_MSEC: int = 16000
const PROOF_FPS: int = 60
const CROP_SIZE := Vector2i(256, 144)
const CROP_SCALE: int = 2
const SIZE := Geometry.VIEW_SIZE

var viewport: SubViewport
var scene: Control
var output: String
var dry_run: bool
var failures: int
var rows: Dictionary = {}
var mirrored_canvases: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	dry_run = args.has("--dry-run")
	if not _check(args.size() >= 2 and dry_run == (DisplayServer.get_name() == "headless"), "Expected output, combat checkpoint and matching renderer"):
		quit(1)
		return
	output = args[0]
	if not _check(not Runtime.apply_from_environment().is_empty() and preload("res://scripts/cel_look.gd").mode == "all", "Isolated Cel Look run"):
		quit(1)
		return
	Engine.max_fps = PROOF_FPS
	if dry_run: process_frame.connect(_submit_headless_frame)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	viewport = SubViewport.new()
	viewport.name = "ProofViewport"
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	Settings.inherit_edge_smoothing(viewport, root)
	if await _fresh_run():
		await _event()
		await _fire(args[1], args.has("--expect-enemy-icon"))
		for canvas: RID in mirrored_canvases:
			RenderingServer.viewport_remove_canvas(viewport.get_viewport_rid(), canvas)
		current_scene = null
		scene.queue_free()
		await _settle()
	print("POL69_RESULT %s" % JSON.stringify(rows))
	print("POL69 gameplay proof: %d failures" % failures)
	quit(int(failures > 0))


func _fresh_run() -> bool:
	if not _check(not FileAccess.file_exists(Store.DEFAULT_STORAGE_PATH) and Store.load_saved_run().is_empty(), "New Run starts without a profile file or checkpoint"):
		return false
	root.set_meta(InitialGraph.SEED_OVERRIDE, SEED)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _settle()
	var start: Button = menu.get_node("MenuColumn/StartButton")
	if not _check(not start.disabled and start.is_visible_in_tree(), "Real New Run button is available"):
		return false
	start.pressed.emit()
	var pending: Dictionary = {}
	if not await _wait(func() -> bool:
		var run: Control = root.get_node_or_null("RunScene")
		if not is_instance_valid(run): return false
		_observe_fresh(run, pending)
		if current_scene != run or not run.initial_presentation_is_ready(): return false
		scene = run
		return true, "Title New Run handed off to the playable first room"):
		return false
	root.remove_meta(InitialGraph.SEED_OVERRIDE)
	# Advance through the live opening lines to the playable room and sample
	# both sides of the handoff. The first shot keeps the opening presentation.
	await _settle()
	var initial: Dictionary = _observe_fresh(scene, pending)
	var lines: Array = scene._dialogue_script.get("lines", [])
	for _index: int in range(lines.size() * 2 + 1):
		if not scene._dialogue_active or scene._has_current_dialogue_options(): break
		scene._advance_dialogue()
		_observe_fresh(scene, pending)
	if scene._large_map_scrim != null and scene._large_map_scrim.visible:
		scene._close_large_map()
	if not await _settle_room_camera(): return false
	var playable: Dictionary = _observe_fresh(scene, pending)
	await _capture("fresh_run")
	var saved: Dictionary = Store.load_saved_run()
	_check(scene._run_state["mode"] == "room" and scene._run_state["current_room"] == Vector2i.ZERO and saved.get("seed") == SEED, "Actual new checkpoint is the first room")
	for sample: Dictionary in pending.values():
		_check(sample["notice"].is_empty(), "No initial Grimoire discovery toast on the New Run path")
	print("POL69 FRESH opening %s" % JSON.stringify(initial))
	print("POL69 FRESH first_room %s" % JSON.stringify(playable))
	rows["fresh_run"]["frames"] = pending.values()
	return true


func _observe_fresh(run: Control, samples: Dictionary) -> Dictionary:
	var state: Dictionary = run._run_state
	var label: Label = run._grimoire_badge_label
	var info: Dictionary = _notice_frame(run)
	info["dialogue"] = run._dialogue_active
	info["unlocked"] = (state.get(Grimoire.UNLOCKED_KEY, []) as Array).size()
	info["unread"] = (state.get(Grimoire.UNREAD_KEY, []) as Array).size()
	info["badge"] = "" if label == null else label.text
	var key: String = JSON.stringify(info)
	if not samples.has(key): samples[key] = info.merged({"frame": Engine.get_process_frames()})
	return samples[key]


func _event() -> void:
	var template: Dictionary = Run.new().create_new_run(SEED, Store.default_data())
	var state: Dictionary = EventFixture.fixture(EVENT_ID, false, template)
	scene._load_run_state(state)
	# On the opening frame, deliver real discovery receipts before UI refresh.
	var added: Array[String] = scene._unlock_grimoire_entries(DISCOVERIES)
	scene._refresh_ui()
	var view: Control = scene._event_view
	if not _check(is_instance_valid(view) and added.size() == DISCOVERIES.size(), "Bloodletter event and two actual discoveries"):
		return
	var notice: String = Grimoire.notice_for_added_entries(added)
	var opening: Dictionary = _event_frame(view)
	if await _wait(func() -> bool: return view.is_visible_in_tree() and not view._busy, "Event opening animation completes"):
		if not await _settle_room_camera(): return
		var opened: Dictionary = _event_frame(view)
		await _capture("event_open")
		view.activate_choice(0)
		if not await _wait(func() -> bool: return view.continue_button != null and not view._busy, "Production event choice opens its result"): return
		var result: Dictionary = _event_frame(view)
		view.continue_button.pressed.emit()
		var closing: Dictionary = _event_frame(view)
		if not await _wait(func() -> bool: return not view.is_visible_in_tree(), "Production Continue closes the event"): return
		var closed: Dictionary = _event_frame(view)
		if scene._large_map_scrim.visible: scene._close_large_map()
		var replayed: Dictionary = _event_frame(view)
		if not await _settle_room_camera(): return
		_check(scene.log_overlay.is_visible_in_tree() and scene.log_label.text == notice, "The replay is visible after the room camera settles")
		await _capture("event_closed")
		var frames: Array = [opening, opened, result, closing, closed, replayed]
		rows["event_open"]["frames"] = frames
		rows["event_open"]["notice"] = notice
		for frame: Dictionary in frames:
			print("POL69 EVENT %s" % JSON.stringify(frame))
			if frame["event_visible"]:
				_check(not frame["visible"] and frame["held"].has(notice), "Discovery is held throughout the event")
		_check(replayed["visible"] and replayed["text"] == notice and is_equal_approx(replayed["remaining_s"], scene.COMBAT_LOG_TRANSIENT_SECONDS), "Discovery replays on the usual timer after the full panels close")


func _notice_frame(run: Control) -> Dictionary:
	return {
		"text": run.log_label.text, "visible": run.log_overlay.is_visible_in_tree(),
		"notice": str(run._run_state.get(Grimoire.NOTICE_KEY, "")),
	}


func _event_frame(view: Control) -> Dictionary:
	var info: Dictionary = _notice_frame(scene)
	var queue: Node = scene.get_node_or_null(Notices.NODE_NAME)
	var held: Array = []
	if queue != null:
		for item: Dictionary in queue.queued: held.append(item["text"])
		if not queue._current.is_empty(): held.push_front(queue._current["text"])
	info.merge({
		"frame": Engine.get_process_frames(), "event_visible": view.is_visible_in_tree(),
		"map_visible": scene._large_map_scrim.visible,
		"held": held, "remaining_s": 0.0 if queue == null else queue._remaining,
	})
	return info


func _fire(checkpoint: String, expect_enemy_icon: bool) -> void:
	if not _check(DirAccess.copy_absolute(checkpoint, ProjectSettings.globalize_path(Store.DEFAULT_RUN_STORAGE_PATH)) == OK, "Install the certified combat checkpoint"):
		return
	var state: Dictionary = Store.load_saved_run()
	var combat: Dictionary = state.get("combat_state", {})
	if not _check(not combat.is_empty() and combat.get("enemies", []).size() >= 2, "Combat checkpoint has a hero and two enemies"):
		return
	var hero: Dictionary = combat["player"]
	var fire_enemy: Dictionary = combat["enemies"][0]
	Surfaces.place(combat, hero["pos"], "fire")
	Surfaces.place(combat, fire_enemy["pos"], "fire")
	scene._load_run_state(state)
	scene._close_dialogue()
	await _settle()
	if not _check(scene._combat_engine.is_player_turn(scene._combat_state), "Combat starts on a real player turn"): return
	var hero_health: int = scene._combat_state["player"]["hp"]
	var enemy_key: String = "enemy_%s" % fire_enemy["id"]
	var icon_texture: Texture2D = Icons.icon_texture("surface_fire")
	_check(icon_texture != null, "Fire's existing icon resolves in the registry")
	var observed: Dictionary = {}
	var fire_sample: Dictionary = {}
	scene._on_pass_turn_pressed()
	# Director proof addition: capture the enemy's turn-start Fire number when it appears (absent on release).
	var enemy_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < enemy_deadline and not observed.has("hero_fire"):
		_record_fire_frame(enemy_key, observed)
		if observed.has("enemy_fire_surface_fire"):
			var enemy_popup: Dictionary = {}
			for popup: Dictionary in scene.board_view._floating_text_screen_layout(scene.board_view.get_theme_default_font()):
				if str(popup["entry"].get("reaction_actor_key", "")) == enemy_key: enemy_popup = popup
			if not enemy_popup.is_empty():
				var enemy_image: Image = await _capture("enemy_fire_peak")
				_save_crop(enemy_image, enemy_popup, "enemy_fire_peak_2x.png")
			break
		await process_frame
	var reached: bool = await _wait(func() -> bool:
		var found: Dictionary = _record_fire_frame(enemy_key, observed)
		if not found.is_empty():
			fire_sample.merge(found)
			return true
		return false, "Pass reaches a hero turn-start Fire damage popup")
	if not reached: return
	var capture: Image = await _capture("hero_fire_peak")
	_save_crop(capture, fire_sample)
	rows["hero_fire_peak"]["frames"] = observed
	rows["hero_fire_peak"]["health_before_pass"] = hero_health
	var enemy_damage: int = 0
	for event: Dictionary in scene._combat_state.get("surface_events", []):
		if event.get("kind") == "surface_damage" and event.get("actor_key") == enemy_key and event.get("trigger") == "start":
			enemy_damage += int(event.get("health_lost", 0))
	var hero_frame: Dictionary = observed["hero_fire"]
	var enemy_frame: Dictionary = observed.get("enemy_fire_surface_fire", {})
	print("POL69 FIRE enemy actor=%s health_lost=%d popup=%s" % [enemy_key, enemy_damage, JSON.stringify(enemy_frame) if not enemy_frame.is_empty() else "absent"])
	print("POL69 FIRE hero %s" % JSON.stringify(hero_frame))
	_check(hero_frame["icon"] == "surface_fire" and hero_frame["health_lost"] > 0, "Hero's real Fire tick keeps the Fire icon")
	_check(enemy_damage > 0 and expect_enemy_icon == (not enemy_frame.is_empty()), "Enemy Fire damage has the expected before/after popup")
	if expect_enemy_icon:
		_check(not enemy_frame.get("extra_impact", true), "The existing Fire ground beat owns the hit feedback")
	# Play an equal loss through the existing status presenter and capture the
	# actual retained board entry, including the production icon scaling.
	if not await _wait(func() -> bool: return not scene._animation_lock, "Pass playback returns control"): return
	var enemy: Dictionary = scene._animation_actor_unit(scene._combat_state, enemy_key)
	var reference_step: Dictionary = {
		"kind": "status_damage", "status_id": "frostbite", "actor_key": enemy_key,
		"tile": enemy["pos"], "amount": hero_frame["health_lost"],
	}
	var reference: Dictionary = scene._enemy_phase_status_presentation(reference_step)
	reference["floating_texts"] = FloatingText.animate_entries(reference["floating_texts"], 0.0, false)
	scene._render_board_state(scene._combat_state, reference)
	for entry: Dictionary in scene.board_view.presentation.get("floating_texts", []):
		if entry.get("icon") != "frostbite": continue
		var reference_peak: Dictionary = _float_frame(entry)
		print("POL69 FIRE Frostbite-style reference %s" % JSON.stringify(reference_peak))
		for field: String in ["icon_size", "width", "x_offset"]:
			_check(hero_frame[field] == reference_peak[field] and (not expect_enemy_icon or enemy_frame.get(field) == reference_peak[field]), "Fire and Frostbite use the same popup " + field)
		return
	_check(false, "Frostbite reference status popup reached the board")


func _record_fire_frame(enemy_key: String, observed: Dictionary) -> Dictionary:
	var board: Control = scene.board_view
	for entry: Dictionary in board.presentation.get("floating_texts", []):
		var actor: String = str(entry.get("reaction_actor_key", ""))
		var icon: String = str(entry.get("icon", ""))
		var sequence: String = str(entry.get("screen_layout_id", ""))
		if actor == enemy_key and not observed.has("enemy_fire_%s" % icon):
			var extra_impact: bool = (board.presentation.get("combat_feel_hits", []) as Array).any(
				func(hit: Dictionary) -> bool: return hit.get("id") == sequence
			)
			observed["enemy_fire_%s" % icon] = _float_frame(entry).merged({"extra_impact": extra_impact})
		if actor == "player" and sequence.ends_with("/damage") and str(entry.get("text", "")).begins_with("−"):
			for event: Dictionary in scene._combat_state.get("surface_events", []):
				if event.get("kind") != "surface_damage" or event.get("actor_kind") != "player" or event.get("trigger") != "start" or event.get("surface") != "fire": continue
				observed["hero_fire"] = _float_frame(entry).merged({
					"surface": "fire", "trigger": "start", "health_lost": event["health_lost"],
				})
				for popup: Dictionary in board._floating_text_screen_layout(board.get_theme_default_font()):
					if str(popup["entry"].get("screen_layout_id", "")) == sequence: return popup
	return {}


func _float_frame(entry: Dictionary) -> Dictionary:
	return {
		"frame": Engine.get_process_frames(), "actor": entry.get("reaction_actor_key"),
		"text": entry.get("text"), "icon": entry.get("icon", ""), "icon_size": entry.get("icon_size"),
		"x_offset": entry.get("x_offset"), "width": entry.get("width"), "progress": entry.get("animation_progress"),
		"font_scale": entry.get("font_scale"), "alpha": entry.get("alpha"),
	}


func _save_crop(image: Image, popup: Dictionary, file_name: String = "hero_fire_peak_2x.png") -> void:
	var path: String = output.path_join(file_name)
	print("POL69 CAPTURE: " + path)
	if dry_run: return
	# The probe runner collects PNGs from bare absolute-path lines.
	print(path)
	if image == null: return
	var board: Control = scene.board_view
	var origin: Vector2 = popup["origin"] + popup.get("layout_offset", Vector2.ZERO)
	var center: Vector2 = board.get_global_transform_with_canvas() * origin
	var top_left: Vector2i = (Vector2i(center.round()) - CROP_SIZE / 2).clamp(Vector2i.ZERO, SIZE - CROP_SIZE)
	var crop: Image = image.get_region(Rect2i(top_left, CROP_SIZE))
	crop.resize(CROP_SIZE.x * CROP_SCALE, CROP_SIZE.y * CROP_SCALE, Image.INTERPOLATE_NEAREST)
	_check(crop.save_png(path) == OK, "Saved the 2x Fire crop")


func _capture(name: String) -> Image:
	# New Run stays mounted directly on the root for the production handoff.
	# Render those same live canvases in the fixed-size proof SubViewport.
	var canvas_target: RID = viewport.get_viewport_rid()
	for child: Node in scene.get_children():
		if child is CanvasLayer:
			var canvas: RID = child.get_canvas()
			if not mirrored_canvases.has(canvas):
				RenderingServer.viewport_attach_canvas(canvas_target, canvas)
				mirrored_canvases[canvas] = true
			RenderingServer.viewport_set_canvas_stacking(canvas_target, canvas, child.layer, child.get_index())
			RenderingServer.viewport_set_canvas_transform(canvas_target, canvas, child.transform)
	var path: String = output.path_join(name + ".png")
	rows[name] = Geometry.capture(viewport, scene).merged({"ok": true, "capped": false, "shot": name})
	print("POL69 CAPTURE: " + path)
	if dry_run: return null
	print(path)
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if not _check(image != null and image.get_size() == SIZE, "Exact 1920x1080 SubViewport image"): return null
	_check(image.save_png(path) == OK, "Saved " + path)
	return image


func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await process_frame


func _settle_room_camera() -> bool:
	await _settle()
	return await _wait(func() -> bool:
		return scene._board_centering_tween == null or not scene._board_centering_tween.is_running(),
		"Room camera completes the production centring tween")


func _wait(predicate: Callable, context: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while not predicate.call():
		if Time.get_ticks_msec() > deadline: return _check(false, context)
		await process_frame
	return true


func _submit_headless_frame() -> void:
	RenderingServer.force_draw(false)


func _check(condition: bool, context: String) -> bool:
	if not condition:
		failures += 1
		push_error(context)
	return condition
