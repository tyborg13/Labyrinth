extends SceneTree

# v5 production-scene proof. Headless mode asserts semantics/geometry only.
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Run = preload("res://scripts/run_engine.gd")
const Dialogue = preload("res://scripts/dialogue_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const View = preload("res://scripts/dialogue_box_view.gd")
const Paint = preload("res://scripts/dialogue_ink_paint.gd")
const Portrait = preload("res://scripts/dialogue_portrait_paint.gd")
const Cel = preload("res://scripts/cel_look.gd")
const ControllerSuite = preload("res://tests/suites/controller_input_suite.gd")
const NATIVE_SIZE := Vector2i(1920, 1080)
const DECK_SIZE := Vector2i(1280, 800)
const OUTPUT: String = "res://output/dlg-01-v5"
const MOCK_ROOT: String = "res://spec/design/dialogue_v4/"
const FIXTURE_SEED: int = 2926
const SETTLE_FRAMES: int = 3
const OPEN_FPS: float = 30.0
const OPEN_LAST_FRAME: int = 12 # 0.4 seconds, including the head's final settle.
const SHEET_CELL := Vector2i(640, 360)
const SHEET_COLUMNS: int = 5
var scene: Node
var canvas: SubViewport
var view: Control
var failed: int = 0
var check_only: bool = false
var deck: bool = false
var raw_only: bool = false
var physical: Vector2i
var output: String
var settings: Dictionary
var profile: Dictionary
var state: Dictionary
var dialogue := Dialogue.new()
var geometry: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	check_only = args.has("--check-only") or DisplayServer.get_name() == "headless"
	deck = args.has("--deck")
	raw_only = args.has("--raw")
	physical = DECK_SIZE if deck else NATIVE_SIZE
	output = OUTPUT.path_join("deck" if deck else ("raw" if raw_only else "native"))
	if DisplayServer.get_name() == "headless":
		print("HEADLESS SEMANTICS ONLY: no renderer captures")
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	ControllerSuite.run(_expect)
	print("CONTROLLER INPUT SUITE: ", "PASS" if failed == 0 else "FAIL")
	_expect((Cel.mode == "off") == raw_only, "Proof launch explicitly selects cel-on or raw-off mode")
	root.get_node("InputRouter").call("set_forced_state_for_test", "controller" if deck else "pointer", "steam_deck" if deck else "xbox")
	Store.set_storage_path("user://dlg01_profile.json")
	Store.set_run_storage_path("user://dlg01_run.save")
	Settings.set_storage_path("user://dlg01_settings.json")
	settings = Settings.default_settings()
	settings["ui_scale"] = Settings.default_ui_scale(true) if deck else 1.0
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_STANDARD
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = NATIVE_SIZE
	root.size = physical
	Settings.apply_settings(settings, root, false)
	profile = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	profile["moltshards"] = 1
	profile["embers"] = 100
	profile["run_counter"] = 8
	Store.save_data(profile)
	canvas = SubViewport.new()
	canvas.size = physical
	var fit: float = minf(float(physical.x) / NATIVE_SIZE.x, float(physical.y) / NATIVE_SIZE.y) * float(settings["ui_scale"])
	canvas.size_2d_override = Vector2i(Vector2(physical) / fit)
	canvas.size_2d_override_stretch = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await _settle()
	state = Run.new().create_new_run(FIXTURE_SEED, profile)
	scene.set("_progression", profile)
	scene.call("_load_run_state", state)
	await _settle()
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	view = scene.get("_dialogue_overlay")
	var intro: Dictionary = dialogue.build_room_dialogue({"coord": Vector2i.ZERO, "npcs": [{"id": "emaciated_man"}]}, state, profile)
	await _open_complete(intro)
	_assert_portrait("emaciated_man")
	_measure("emaciated_man")
	if not deck:
		_expect(scene.get("_dialogue_dialog").get_global_rect() == Rect2(190, 834, 1500, 220), "Line uses the v5 1500x220 band at (190,834)")
		_expect(scene.get("_dialogue_portrait_frame").get_global_rect() == Rect2(250, 794, 340, 236), "Frame is 340x236 and ends at y=1030")
		_expect(is_equal_approx(scene.get("_dialogue_text_label").global_position.x, 646.0), "Native text column begins at x=646")
	await _capture("emaciated_man_line", "dlg5_emac_line.png" if not deck and not raw_only else "")
	if raw_only:
		await _finish()
		return
	var scavenger: Dictionary = dialogue.build_room_dialogue({"coord": Vector2i.ZERO, "npcs": [{"id": "scavenger"}]}, state, profile)
	await _open_complete(scavenger)
	_assert_portrait("scavenger")
	_measure("scavenger")
	await _capture("scavenger_line", "dlg5_scav_line.png" if not deck else "")
	if deck:
		await _finish()
		return
	var service: Dictionary = dialogue.emaciated_service_dialogue(profile)
	await _open_complete(service)
	_expect(scene.get("_dialogue_dialog").size.y == 262.0, "Two-line service retains the 262px band")
	_expect(scene.get("_dialogue_portrait_frame").get_global_rect().end.y == 1030.0, "Service keeps the frame's fixed bottom")
	var choices: HBoxContainer = scene.get("_dialogue_choice_bar")
	var trade: Button = choices.get_child(0)
	_expect(trade.get_meta("dialogue_action") == "exchange_moltshard", "Proof focuses the real Trade action")
	trade.grab_focus()
	await _settle()
	_expect(trade.has_focus(), "Trade has native keyboard focus")
	await _capture("service_trade_focus", "dlg5_emac_choice.png")
	trade.release_focus()
	var motion := InputEventMouseMotion.new()
	motion.position = trade.get_global_rect().get_center()
	motion.global_position = motion.position
	canvas.push_input(motion, true)
	await _settle()
	_expect(trade.is_hovered(), "Trade has native pointer hover")
	await _capture("service_trade_hover", "dlg5_emac_choice.png")
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(10, 10)
	canvas.push_input(motion, true)
	await _opening(intro, 1)
	await _opening(intro, 3)
	await _reveal(intro)
	# Missing bust data must remove the whole portrait family, not crop by guess.
	await _open_complete(intro)
	view.call("set_portrait", "")
	view.call("sync_layout")
	_expect(not scene.get("_dialogue_portrait_frame").visible and not scene.get("_dialogue_portrait").visible and scene.get("_dialogue_text_label").position.x == 120.0, "Missing portrait_bust uses the v3 no-art column without a frame")
	settings["reduced_motion"] = true
	scene.set("_settings", settings)
	await _open_complete(intro)
	_expect(scene.get("_dialogue_portrait_frame").get_global_rect() == Rect2(250, 794, 340, 236), "Reduced motion has no frame rise")
	_expect(scene.get("_dialogue_portrait").modulate.a == 1.0, "Reduced motion makes the bust instant")
	await _capture("reduced_motion")
	scene.call("_close_dialogue")
	_expect(not view.visible, "Reduced motion closes instantly")
	settings["reduced_motion"] = false
	scene.set("_settings", settings)
	await _choice_input(service)
	await _finish()

func _assert_portrait(npc_id: String) -> void:
	var definition: Dictionary = Data.npc_def(npc_id)
	var texture: Texture2D = scene.get("_dialogue_portrait").texture
	_expect(texture != null, npc_id + " has an explicit bust")
	if texture == null: return
	_expect(texture.get_size() == Vector2(765, 300), npc_id + " keeps all 255 source columns at nearest scale 3")
	_expect(texture.get_meta("portrait_bust") == definition["portrait_bust"], "Bust reads the director's new dictionary data")
	var expected_source: String = str(definition["art_path"]) if Cel.mode == "off" else Cel.variant_path(str(definition["art_path"]))
	_expect(not expected_source.is_empty() and texture.get_meta("portrait_source_path") == expected_source, "Bust uses the exact shared cel variant or explicit raw fallback")
	var source: Image = Portrait.source_texture(str(definition["art_path"])).get_image()
	var crop: Dictionary = definition["portrait_bust"]
	_expect(texture.get_image().get_pixel(int(crop["center_x"]) * 3 + 1, 61) == source.get_pixel(int(crop["center_x"]), int(crop["top"]) + 20), "Bust pixels match the selected source with nearest filtering")
	var frame: Control = scene.get("_dialogue_portrait_frame")
	var bust: Control = scene.get("_dialogue_portrait")
	_expect(is_equal_approx(bust.position.y + bust.size.y, frame.position.y + frame.size.y), "Bust ends at frame bottom")
	_expect(is_equal_approx(frame.position.y - bust.position.y, 64.0), "Head rises 64px above frame")
	_expect(is_equal_approx(bust.position.x + float(crop["center_x"]) * 3.0, frame.position.x + frame.size.x * 0.5), "Authored center_x meets the frame centre")
	var window: Vector4 = view.get("_portrait_clip").get_shader_parameter("frame_window")
	_expect(window.x == frame.position.x + 3.0 - bust.position.x and window.z - window.x == 334.0, "Lower bust clip meets the inner side edges")
	_expect(window.y == 64.0, "Upper bust is outside the side clip")
	var layers: Array = [view.get("_band_wipe"), view.get("_portrait_shadow"), frame, view.get("_hood_clip"), view.get("_portrait_rim"), bust, view.get("_wipe")]
	for index: int in range(layers.size() - 1): _expect(layers[index].get_index() < layers[index + 1].get_index(), "Portrait layer order follows recipe")

func _measure(label: String) -> void:
	var frame: Control = scene.get("_dialogue_portrait_frame")
	var bust: Control = scene.get("_dialogue_portrait")
	var visible: Rect2i = bust.texture.get_meta("portrait_visible_bounds")
	var painted := Rect2(bust.global_position + Vector2(visible.position), Vector2(visible.size))
	var bounds := Rect2(Vector2.ZERO, Vector2(canvas.size_2d_override))
	var title: Control = scene.get("title_box")
	var fits: bool = bounds.encloses(frame.get_global_rect()) and bounds.encloses(painted)
	var covers_hud: bool = painted.intersects(title.get_global_rect())
	var factor: Vector2 = Vector2(physical) / Vector2(canvas.size_2d_override)
	var row: Dictionary = {"speaker":label,"physical_size":[physical.x,physical.y],"logical_size":[canvas.size_2d_override.x,canvas.size_2d_override.y],"ui_scale":settings["ui_scale"],"frame_logical":_rect(frame.get_global_rect()),"painted_bust_logical":_rect(painted),"frame_physical":_rect(Rect2(frame.global_position * factor, frame.size * factor)),"painted_bust_physical":_rect(Rect2(painted.position * factor,painted.size * factor)),"fits":fits,"covers_top_hud":covers_hud}
	geometry.append(row)
	print("DIALOGUE GEOMETRY: ", JSON.stringify(row))
	if not deck: _expect(fits and not covers_hud, "Native frame/bust stay on screen and below the top HUD")
	else: print("DECK FIT: ", "FITS" if fits and not covers_hud else "CLIPPED — measurements recorded; no redesign")

func _rect(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _opening(script: Dictionary, speed_divisor: int) -> void:
	await _open_complete(script)
	view.call("open")
	view.call("show_speaker", str(script["speaker"]))
	view.set_process(false)
	scene.set_process(false)
	var prefix: String = "opening_1x" if speed_divisor == 1 else "opening_third_speed"
	var count: int = OPEN_LAST_FRAME * speed_divisor + 1
	var sheet: Image
	if not check_only: sheet = Image.create(SHEET_CELL.x * SHEET_COLUMNS, SHEET_CELL.y * ceili(float(count) / SHEET_COLUMNS), false, Image.FORMAT_RGB8)
	var bakes: int = Paint.band_bakes
	for index: int in range(count):
		var seconds: float = float(index) / OPEN_FPS / speed_divisor
		view.set("_open_elapsed", seconds)
		view.set("_speaker_elapsed", seconds)
		view.call("sync_layout")
		if index == 0:
			_expect(scene.get("_dialogue_portrait_frame").global_position.y == 806.0, "Frame starts 12px low")
			_expect(scene.get("_dialogue_portrait").global_position.y == 750.0 and scene.get("_dialogue_portrait").modulate.a == 0.0, "Bust starts 20px low and transparent")
		if seconds < View.BUST_DELAY: _expect(scene.get("_dialogue_portrait").modulate.a == 0.0, "Bust waits 0.06s before its fade/rise")
		if seconds >= View.OPEN_END: _expect(scene.get("_dialogue_portrait").global_position.y == 730.0 and scene.get("_dialogue_portrait").modulate.a == 1.0, "Head lands last at 0.32s")
		var frame: Image = await _capture("%s_%02d" % [prefix,index])
		if sheet != null:
			frame.resize(SHEET_CELL.x,SHEET_CELL.y,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(frame,Rect2i(Vector2i.ZERO,SHEET_CELL),Vector2i(index % SHEET_COLUMNS,index / SHEET_COLUMNS) * SHEET_CELL)
	_expect(Paint.band_bakes == bakes, "Opening never rebuilds the band texture")
	if sheet != null: _save(sheet,prefix + "_sheet")
	view.call("finish_open")

# Director, 2026-11-16 (owner: "can we still scroll out the text?"): drive the real
# RunScene reveal at 30 fps from a fresh line; the text waits until the box settles.
func _reveal(script: Dictionary) -> void:
	await _open_complete(script)
	scene.call("_show_dialogue_line", 0)
	view.call("open")
	view.call("show_speaker", str(script["speaker"]))
	view.set_process(false)
	scene.set_process(false)
	var step: float = 1.0 / OPEN_FPS
	var index: int = 0
	var hold: int = 0
	while hold < 15 and index < 240:
		var seconds: float = index * step
		view.set("_open_elapsed", minf(View.OPEN_END, seconds))
		view.set("_speaker_elapsed", seconds)
		view.call("sync_layout")
		if index > 0: scene.call("_process", step)
		if seconds < View.OPEN_END: _expect(int(scene.get("_dialogue_text_label").visible_characters) <= 1, "Text waits until the box settles")
		await _capture("reveal_1x_%03d" % index)
		if bool(scene.get("_dialogue_text_complete")): hold += 1
		index += 1
	_expect(bool(scene.get("_dialogue_text_complete")), "The line scrolls out to completion")
	view.call("finish_open")

func _choice_input(script: Dictionary) -> void:
	var router: Node = root.get_node("InputRouter")
	for modality: String in ["pointer", "keyboard", "controller"]:
		router.call("set_forced_state_for_test", "controller" if modality == "controller" else "pointer", "xbox")
		await _open_complete(script)
		var button: Button = scene.get("_dialogue_choice_bar").get_child(2)
		if modality == "controller": scene.call("_controller_set_focus_candidate", scene.call("_controller_candidate_for_control", button), true)
		elif modality == "keyboard": button.grab_focus()
		for down: bool in [true, false]:
			var event: InputEvent
			if modality == "pointer":
				var pointer := InputEventMouseButton.new()
				pointer.position = button.get_global_rect().get_center()
				pointer.global_position = pointer.position
				pointer.button_index = MOUSE_BUTTON_LEFT
				pointer.pressed = down
				event = pointer
			elif modality == "keyboard":
				var key := InputEventKey.new()
				key.keycode = KEY_ENTER
				key.pressed = down
				event = key
			else:
				var joy := InputEventJoypadButton.new()
				joy.button_index = JOY_BUTTON_A
				joy.pressed = down
				event = joy
			canvas.push_input(event,true)
			await process_frame
		_expect(not bool(scene.get("_dialogue_active")), "Native " + modality + " activates original Leave action")
	router.call("clear_forced_state_for_test")

func _open_complete(script: Dictionary) -> void:
	# Only this view is under inspection; keep the shop's separate routing intact.
	var shop: Variant = scene.get("_scavenger_shop_view")
	if script.get("npc_id", "") == "scavenger": scene.set("_scavenger_shop_view", null)
	scene.call("_start_dialogue",script)
	scene.set("_scavenger_shop_view",shop)
	scene.call("_close_large_map")
	scene.call("_complete_current_dialogue_line")
	view.call("finish_open")
	scene.set_process(false)
	view.set_process(false)
	view.set("_bob_elapsed",0.0)
	await _settle()
	view.call("sync_layout")

func _settle() -> void:
	for index: int in range(SETTLE_FRAMES): await process_frame

func _capture(label: String, mockup: String = "") -> Image:
	await process_frame
	if check_only: return null
	await RenderingServer.frame_post_draw
	var frame: Image = canvas.get_texture().get_image()
	_expect(frame.get_size() == physical,"Exact requested physical capture dimensions")
	frame.convert(Image.FORMAT_RGB8)
	_save(frame,label)
	if not mockup.is_empty():
		var reference: Image = Image.load_from_file(MOCK_ROOT.path_join(mockup))
		var pair := Image.create(NATIVE_SIZE.x * 2,NATIVE_SIZE.y,false,Image.FORMAT_RGB8)
		frame.convert(Image.FORMAT_RGB8)
		reference.convert(Image.FORMAT_RGB8)
		pair.blit_rect(frame,Rect2i(Vector2i.ZERO,NATIVE_SIZE),Vector2i.ZERO)
		pair.blit_rect(reference,Rect2i(Vector2i.ZERO,NATIVE_SIZE),Vector2i(NATIVE_SIZE.x,0))
		_save(pair,label + "_beside_mockup")
	return frame

func _save(frame: Image, label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var path: String = output.path_join(label + ".png")
	_expect(frame.save_png(path) == OK,"PNG saved")
	print(ProjectSettings.globalize_path(path))

func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(geometry,"\t") + "\n")
	print("DLG-01 V5 SEMANTICS: ","PASS" if failed == 0 else "FAIL")
	canvas.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _expect(ok: bool, message: String) -> void:
	if ok: return
	failed += 1
	push_error(message)
