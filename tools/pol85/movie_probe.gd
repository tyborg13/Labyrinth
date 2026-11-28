extends "res://tests/controller_screen_sweep.gd"
## This entry point also runs as an external script against release game code.

const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const CHECKPOINT_ID := "04-s0-seed8-0--3_2-t5"
const CHECKPOINT_PATH := "res://tools/fel01/fixtures/" + CHECKPOINT_ID
const GRIMOIRE_ROOM := "Central Waypoint"
const GRIMOIRE_ENTRY := "keyword:shock"
const FPS := 60
const HAND_HOLD_FRAMES := 90
const GRIMOIRE_HOLD_FRAMES := 120
const MOVIE_SETTLE_FRAMES := 30
const TAIL_FRAMES := 15
const HAND_STEPS := 4
const GRIMOIRE_STEPS := 15

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	quit(0 if await capture(self) else 1)

static func capture(driver: SceneTree) -> bool:
	var take := Take.new()
	return await take.run(driver)

class Take extends RefCounted:
	var _driver: SceneTree
	var _viewport: SubViewport
	var _scene: Control
	var _build: String
	var _record: bool
	var _output: String
	var _checkpoint: String
	var _parts: Dictionary

	func run(driver: SceneTree) -> bool:
		_driver = driver
		var args: PackedStringArray = OS.get_cmdline_user_args()
		_record = args.has("--movie")
		_build = _argument(args, "--build", "after")
		_output = _argument(args, "--proof-output", "")
		_checkpoint = _argument(args, "--checkpoint", CHECKPOINT_PATH)
		if _build not in ["before", "after"] or (_record and (_output.is_empty() or DisplayServer.get_name() == "headless")):
			return _error("invalid build, output directory, or renderer")
		Runtime.apply_from_environment()
		if DisplayServer.get_name() == "headless":
			driver.process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
		if not _setup():
			return _error("could not stage isolated settings or the saved fight")
		var accepted: bool = await _hand()
		# An invalid starting fight stops the take. The before side's one-step
		# result is recorded by _check_steps and still reaches this second part.
		if not _parts.has("hand"):
			await _release_scene()
			return false
		var grimoire_accepted: bool = await _grimoire()
		await _release_scene()
		if not _output.is_empty():
			var file := FileAccess.open(_output.path_join("take.json"), FileAccess.WRITE)
			if file == null: return _error("could not write the take timeline")
			file.store_line(JSON.stringify({
				"build": _build, "fps": FPS, "parts": _parts,
				"last_process_frame": Engine.get_process_frames(),
			}, "\t"))
		if accepted and grimoire_accepted:
			print("POL85 NATIVE TAKE PASS %s" % _build)
			return true
		return false

	func _setup() -> bool:
		Settings.set_storage_path("user://pol85_settings.json")
		Analytics.set_storage_dir("user://pol85_analytics")
		var settings: Dictionary = Settings.default_settings()
		settings["ui_scale"] = 1.0
		if not Settings.save_settings(settings) or not Checkpoint.stage(_checkpoint, ProjectSettings.globalize_path("user://pol85_checkpoint")):
			return false
		Router.ensure_input_map()
		_driver.root.get_node("InputRouter").call("set_forced_state_for_test", "controller", Router.FAMILY_STEAM_DECK)
		_driver.root.size = PROOF_SIZE
		_driver.root.content_scale_size = PROOF_SIZE
		_driver.root.content_scale_factor = 1.0
		_viewport = SubViewport.new()
		_viewport.size = PROOF_SIZE
		_viewport.gui_embed_subwindows = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_driver.root.add_child(_viewport)
		_driver.set("_viewport", _viewport)
		if _record:
			var display := TextureRect.new()
			display.texture = _viewport.get_texture()
			display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			display.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_driver.root.add_child(display)
		return true

	func _hand() -> bool:
		# Same production resume path and saved-state witness as fel-19/fel-22.
		_driver.root.set_meta("labyrinth_resume_saved_run", true)
		_install_scene(false)
		var deadline: int = Time.get_ticks_msec() + READY_TIMEOUT_MSEC
		while not _fight_ready() and Time.get_ticks_msec() < deadline:
			await _driver.process_frame
		if not _fight_ready(): return _error("the saved fight never offered player input")
		var differences: Dictionary = Checkpoint.compare(_scene, _checkpoint)
		if not differences.is_empty():
			return _error("Continue witness differs in " + ", ".join(differences.keys()))
		var run_state: Dictionary = _scene.get("_run_state")
		var combat: Dictionary = _scene.get("_combat_state")
		var hand: Array = combat.get("deck", {}).get("hand", [])
		var enemies: Array = combat.get("enemies", [])
		var room: String = str(run_state.get("current_room_layout", {}).get("name", ""))
		if room.is_empty() or hand.size() != HAND_STEPS + 1 or enemies.is_empty():
			return _error("the saved fight must have a named room, enemies, and five cards")
		if _scene.get("_controller_region") == "hand" and _hand_index() < 0:
			await _tap(JOY_BUTTON_X)
		if _scene.get("_controller_region") != "hand":
			await _tap(JOY_BUTTON_X)
		for step: int in maxi(0, _hand_index()):
			await _tap(JOY_BUTTON_LEFT_SHOULDER)
		if _scene.get("_controller_region") != "hand" or _hand_index() != 0:
			return _error("could not focus the first saved card (region=%s index=%d)" % [_scene.get("_controller_region"), _hand_index()])
		print("POL85 CHECKPOINT %s room=%s cards=%d enemies=%d" % [_build, room, hand.size(), enemies.size()])
		var start: int = Engine.get_process_frames()
		await _frames(MOVIE_SETTLE_FRAMES)
		var indices: Array[int]
		var prior: int = _hand_index()
		_press(JOY_BUTTON_DPAD_RIGHT)
		for frame: int in HAND_HOLD_FRAMES:
			var index: int = _hand_index()
			if index != prior:
				indices.append(index)
				prior = index
			await _driver.process_frame
		_press(JOY_BUTTON_DPAD_RIGHT, false)
		var accepted: bool = _check_steps("hand", indices.size(), HAND_STEPS, indices == [1, 2, 3, 4])
		var still_ok: bool = await _finish_part("hand", start)
		return accepted and still_ok

	func _grimoire() -> bool:
		await _release_scene()
		# Preserve the original fully unlocked Central Waypoint setup.
		Store.set_storage_path("user://pol85_profile.json")
		Store.set_run_storage_path("user://pol85_run.save")
		Store.save_data(Store.default_data())
		_install_scene(true)
		await _driver.call("_settle")
		var state: Dictionary = _driver.call("_base_state")
		var unlocked: Array[String]
		for entry: Dictionary in Grimoire.entries(): unlocked.append(str(entry["id"]))
		state[Grimoire.UNLOCKED_KEY] = unlocked
		var unread: Array[String] = [GRIMOIRE_ENTRY]
		state[Grimoire.UNREAD_KEY] = unread
		await _driver.call("_load", state)
		_scene.call("_open_grimoire_overlay")
		await _driver.call("_settle")
		var room: String = (_scene.get("room_title") as Label).text
		var grimoire: Control = _scene.get("_grimoire_scrim")
		var rows: Array = grimoire.get("_grimoire_nav_buttons")
		if room != GRIMOIRE_ROOM or grimoire.get("_grimoire_selected_entry") != GRIMOIRE_ENTRY or rows.size() <= GRIMOIRE_STEPS:
			return _error("unexpected Grimoire setup (room=%s rows=%d)" % [room, rows.size()])
		(rows.front() as Control).grab_focus()
		var start: int = Engine.get_process_frames()
		await _frames(MOVIE_SETTLE_FRAMES)
		var seen: Array = []
		_press(JOY_BUTTON_DPAD_DOWN)
		for frame: int in GRIMOIRE_HOLD_FRAMES:
			var focus: Control = _viewport.gui_get_focus_owner()
			if focus is Button and rows.has(focus) and not seen.has(focus): seen.append(focus)
			await _driver.process_frame
		_press(JOY_BUTTON_DPAD_DOWN, false)
		var accepted: bool = _check_steps("grimoire", seen.size(), GRIMOIRE_STEPS, seen == rows.slice(1, GRIMOIRE_STEPS + 1))
		var still_ok: bool = await _finish_part("grimoire", start)
		_scene.call("_close_grimoire_overlay")
		return accepted and still_ok

	func _install_scene(defer_presentation: bool) -> void:
		_scene = load("res://scenes/run_scene.tscn").instantiate()
		_scene.set("_defer_initial_run_presentation", defer_presentation)
		_viewport.add_child(_scene)
		_scene.set("_defer_initial_run_presentation", false)
		_driver.set("_scene", _scene)

	func _release_scene() -> void:
		if not is_instance_valid(_scene): return
		_scene.queue_free()
		await _driver.call("_settle")

	func _fight_ready() -> bool:
		var pass_button := _scene.find_child("PassPreviewChip", true, false) as Button
		return _scene.has_installed_run() and not _scene.get("_animation_lock") and pass_button != null and pass_button.is_visible_in_tree() and not pass_button.disabled

	func _finish_part(part: String, start: int) -> bool:
		var saved: bool = true
		if _record:
			await RenderingServer.frame_post_draw
			var image: Image = _viewport.get_texture().get_image()
			var path: String = _output.path_join(part + ".png")
			saved = image.get_size() == PROOF_SIZE and image.save_png(path) == OK
			if saved: print(path)
			else: _error("could not save the %s still" % part)
		await _frames(TAIL_FRAMES)
		_parts[part] = {"first_frame": start, "end_frame": Engine.get_process_frames()}
		return saved

	func _frames(count: int) -> void:
		for frame: int in count: await _driver.process_frame

	func _press(button: JoyButton, pressed: bool = true) -> void:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_viewport.push_input(event, true)

	func _tap(button: JoyButton) -> void:
		_press(button)
		_press(button, false)
		await _driver.call("_settle")

	func _hand_index() -> int:
		return int(_scene.get("_controller_hand_index"))

	func _check_steps(part: String, actual: int, expected: int, order_matches: bool) -> bool:
		print("POL85 NATIVE %s %s steps=%d expected=%d" % [part, _build, actual, expected])
		if _build == "before" or (actual == expected and order_matches): return true
		return _error(part + " did not follow the expected focus path")

	func _argument(args: PackedStringArray, option: String, fallback: String) -> String:
		var index: int = args.find(option)
		return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback

	func _error(message: String) -> bool:
		print("POL85 NATIVE ERROR %s %s" % [_build, message])
		return false
