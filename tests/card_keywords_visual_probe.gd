extends SceneTree

# Director-run ui-03 stills, 1920x1080 at 100% scale. Uses real GUI input
# for the seal tooltip/click, and asserts charge/cursor state before saving.

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardKeywordsSuite = preload("res://tests/suites/card_keywords_suite.gd")
const CaptureViewport = preload("res://tests/helpers/ui03_capture_viewport.gd")
const TooltipProof = preload("res://tests/suites/empower_seal_tooltip_suite.gd")

const OUTPUT_DIR: String = "user://probes/ui03/1920x1080_ui100"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const REST_POINTER := Vector2(1500, 650)
const TOOLTIP_VISIBLE_SECONDS: float = 0.4
const TOOLTIP_TIMEOUT_FRAMES: int = 240
const POINTER_FOLLOW_EPSILON: float = 0.25
const CLIP_FPS: int = 60
const HOLD_FRAMES: int = 30
const POINTER_TRAVEL_FRAMES: int = 36
const PLAY_SETTLE_FRAMES: int = CLIP_FPS * 3
const ART_BY_FIXTURE := {
	"kwtest_follow_strike": "quick_stab",
	"kwtest_empower_time": "bloody_lunge",
	"kwtest_empower_health": "bloody_lunge",
	"kwtest_stonefist": "stone_plate",
	"kwtest_light_strike": "pale_spark",
	"kwtest_empower_block": "brace",
}

var _failed: bool = false
var _capture_host
var _input_only: bool = false

func _initialize() -> void:
	_input_only = OS.get_cmdline_user_args().has("--verify-input")
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://card_keywords_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://card_keywords_probe_run.save")
	ProgressionStore.clear_saved_run()
	SettingsStore.set_storage_path("user://card_keywords_probe_settings.json")
	SettingsStore.clear_storage()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	root.size = VIEWPORT_SIZE
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null: router.call("set_forced_state_for_test", "pointer", "xbox")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_install_fixture_cards()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "RunScene loads for the card keyword proof")
	if packed != null:
		# CursorFeedback creates its production glyph during autoload _ready().
		await process_frame
		await _capture(packed)
	CardKeywordsSuite.remove_fixtures()
	if not _input_only: print(ProjectSettings.globalize_path(OUTPUT_DIR))
	else: print("UI03 CAPTURE INPUT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _install_fixture_cards() -> void:
	CardKeywordsSuite.install_fixtures()
	var cards: Dictionary = GameData.cards()
	for card_id: String in ART_BY_FIXTURE:
		var art_source: Dictionary = cards.get(str(ART_BY_FIXTURE[card_id]), {}) as Dictionary
		var fixture: Dictionary = cards.get(card_id, {}) as Dictionary
		if not art_source.is_empty():
			fixture["art_path"] = art_source.get("art_path", "")
	(cards["kwtest_follow_strike"] as Dictionary)["name"] = "Quick Stab"
	(cards["kwtest_empower_time"] as Dictionary)["name"] = "Overhead Smash"
	(cards["kwtest_stonefist"] as Dictionary)["name"] = "Stonefist"
	(cards["kwtest_light_strike"] as Dictionary)["name"] = "Hallowed Strike"
	(cards["kwtest_empower_block"] as Dictionary)["name"] = "Braced Guard"

func _capture(packed: PackedScene) -> void:
	if OS.get_cmdline_user_args().has("--movie") or _input_only:
		await _capture_movie(packed)
	else:
		await _capture_stills(packed)

func _capture_stills(packed: PackedScene) -> void:
	var viewport: SubViewport = _create_capture_viewport()
	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	_install_combat(instance)
	await _settle()
	_hide_log(instance)
	var hovered_card: Control = instance.call("_hand_card_control", 1)
	await _pointer(viewport, hovered_card.get_global_transform_with_canvas() * (hovered_card.size * 0.5))
	var seal: Button = _seal(instance, 1)
	_assert(seal.visible and not bool(seal.get("charged")), "Hover offers an unlit seal")
	_save(viewport, "hover_unlit.png")
	await _hold_seal_tooltip(viewport, seal, TooltipProof.OFFERED_TEXT)
	_save(viewport, "seal_hover_tooltip.png")
	await _pointer(viewport, _seal_point(seal), true)
	_assert(bool(instance.call("_hand_card_empowered", 1)), "Seal click charges the hovered hand card")
	await _hold_seal_tooltip(viewport, seal, TooltipProof.CHARGED_TEXT)
	_save(viewport, "charged_seal_tooltip.png")
	await _pointer(viewport, REST_POINTER)
	instance.call("_on_card_hover_ended", 1)
	await _settle()
	_assert(_seal(instance, 1).visible, "Charged hand seal remains visible without hover")
	_save(viewport, "charged_hand.png")
	await instance.call("_on_card_pressed", 1)
	var target: Vector2 = _tile_global_position(instance, Vector2i(3, 4))
	await _pointer(viewport, target)
	instance.call("_on_board_tile_hovered", Vector2i(3, 4))
	instance.call("_sync_click_targeting_arrow", target)
	await _settle()
	_assert(bool(instance.call("_selected_card_empowered")), "Targeting retains charge")
	_save(viewport, "charged_targeting.png")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	instance.call("_refresh_controller_prompts")
	await _settle()
	_assert(_seal(instance, 1).get_node("Badge").text == "R3", "Controller focus uses the existing glyph")
	_save(viewport, "charged_controller.png")
	router.call("clear_forced_state_for_test")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	instance.call("_cancel_card_selection")
	var state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	(state["deck"] as Dictionary)["hand"][1] = "kwtest_empower_health"
	(state["player"] as Dictionary)["hp"] = 2
	instance.set("_combat_state", state)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	instance.call("_on_card_hover_started", 1)
	await _settle()
	_assert(bool(_seal(instance, 1).get("blocked")), "Lethal health cost shows the blocked seal")
	_save(viewport, "blocked.png")
	# Reduced motion must be inspected in addition to the five required stills.
	var settings: Dictionary = SettingsStore.load_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.apply_settings(settings, root, false)
	instance.set("_settings", settings)
	(state["player"] as Dictionary)["hp"] = 30
	instance.call("_mark_combat_preview_state_changed")
	await instance.call("_toggle_pending_empower")
	await _settle()
	_assert(_seal(instance, 1).scale == Vector2.ONE, "Reduced motion charges without a scale animation")
	_save(viewport, "charged_reduced_motion.png")
	instance.queue_free()
	_capture_host.close()
	_capture_host.queue_free()
	await process_frame

func _seal(instance: Node, index: int) -> Button:
	return (instance.call("_hand_card_control", index) as Node).get_node("EmpowerSeal") as Button

func _create_capture_viewport() -> SubViewport:
	_capture_host = CaptureViewport.new()
	root.add_child(_capture_host)
	_capture_host.setup(root)
	return _capture_host.viewport

func _motion(viewport: Viewport, point: Vector2, buttons: int = 0) -> void:
	_assert(viewport == _capture_host.viewport, "Synthetic input belongs only to the isolated viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - viewport.get_mouse_position()
	motion.button_mask = buttons
	_capture_host.route(motion)

func _pointer(viewport: Viewport, point: Vector2, click: bool = false) -> void:
	_motion(viewport, point)
	await _settle()
	if click:
		for pressed: bool in [true, false]:
			await _send_button(viewport, point, pressed)
			await _settle()

func _seal_point(seal: Control) -> Vector2:
	return seal.get_global_transform_with_canvas() * (seal.size * 0.5)

func _hold_seal_tooltip(viewport: SubViewport, seal: Button, expected: String) -> void:
	# Follow layout/charge motion without moving the OS mouse. Once settled,
	# leave the synthetic pointer still so Godot's real tooltip timer can fire.
	_motion(viewport, _seal_point(seal))
	for frame: int in range(TOOLTIP_TIMEOUT_FRAMES):
		var point: Vector2 = _seal_point(seal)
		if viewport.get_mouse_position().distance_to(point) > POINTER_FOLLOW_EPSILON:
			_motion(viewport, point)
		var popup: Window = TooltipProof.visible_tooltip(viewport, expected)
		if popup != null:
			_assert(popup.is_embedded() and viewport.get_embedded_subwindows().has(popup), "The player's real tooltip is embedded in the recorded texture")
			var stack: Control = viewport.find_child("CardFocusTooltipStack", true, false) as Control
			_assert(stack != null and TooltipProof.only_seal_tooltip(viewport, stack), "Only the seal tooltip is visible before its capture hold")
			if not _input_only: await RenderingServer.frame_post_draw
			if OS.get_cmdline_user_args().has("--movie") or _input_only:
				await _hold(ceili(TOOLTIP_VISIBLE_SECONDS * CLIP_FPS))
			else:
				await create_timer(TOOLTIP_VISIBLE_SECONDS).timeout
			_assert(TooltipProof.visible_tooltip(viewport, expected) != null, "The complete tooltip remains visible throughout its hold")
			_assert(stack != null and TooltipProof.only_seal_tooltip(viewport, stack), "The keyword stack stays hidden throughout the seal tooltip hold")
			print("UI03 TOOLTIP HOLD: %s" % expected.replace("\n", " / "))
			return
		await process_frame
	_assert(false, "The real seal tooltip must appear before capture: " + expected)

func _install_combat(instance: Node) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var combat := CombatEngine.new()
	var hand: Array = ["kwtest_follow_strike", "kwtest_empower_time", "kwtest_stonefist", "kwtest_light_strike", "kwtest_empower_block"]
	var state: Dictionary = CardKeywordsSuite._state(combat, hand)
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_played_this_turn"] = 1
	(state["player"] as Dictionary)["stoneskin"] = 3
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	var sources: Array = (umbra.get("light_sources", []) as Array).duplicate(true)
	sources.append({"id": "probe_light", "pos": Vector2i(3, 4), "radius": 1, "duration": 3})
	umbra["light_sources"] = sources
	state["umbra"] = umbra
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = Vector2i(2, 2)
	run_state["combat_state"] = state
	instance.set("_guided_tutorial_phase_id", "")
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.set("_animation_lock", false)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")

func _tile_global_position(instance: Node, tile: Vector2i) -> Vector2:
	var board: Control = instance.get("board_view") as Control
	return board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", tile) as Vector2)

func _hide_log(instance: Node) -> void:
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false

func _save(viewport: SubViewport, file_name: String) -> void:
	RenderingServer.force_draw()
	var image: Image = viewport.get_texture().get_image()
	_assert(image != null and image.get_size() == VIEWPORT_SIZE, "%s captures an exact 1920x1080 frame" % file_name)
	if image != null and image.get_size() == VIEWPORT_SIZE:
		image.save_png("%s/%s" % [OUTPUT_DIR, file_name])

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.2).timeout

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

# MovieWriter records the root viewport at fixed 60 fps via ui03_movie_godot.sh.
func _capture_movie(packed: PackedScene) -> void:
	Engine.max_fps = CLIP_FPS
	# Viewport stretch renders the root at exactly 1920x1080 whatever size a
	# HiDPI desktop gives the window; MovieWriter records that root texture.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_factor = 1.0
	root.gui_embed_subwindows = true
	var viewport: SubViewport = _create_capture_viewport()
	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_factor = 1.0
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	_install_combat(instance)
	await _settle()
	_hide_log(instance)
	await _hold(HOLD_FRAMES)
	var card: Control = instance.call("_hand_card_control", 1)
	await _pointer(viewport, card.get_global_transform_with_canvas() * (card.size * 0.5))
	instance.call("_on_card_hover_started", 1)
	await _hold(HOLD_FRAMES)
	var seal: Button = _seal(instance, 1)
	await _hold_seal_tooltip(viewport, seal, TooltipProof.OFFERED_TEXT)
	await _pointer(viewport, _seal_point(seal), true)
	_assert(bool(instance.call("_hand_card_empowered", 1)), "Clip: first seal click charges")
	await _hold_seal_tooltip(viewport, seal, TooltipProof.CHARGED_TEXT)
	card = instance.call("_hand_card_control", 1)
	var start: Vector2 = card.get_global_transform_with_canvas() * (card.size * 0.5)
	var target: Vector2 = _tile_global_position(instance, Vector2i(3, 4))
	await _send_button(viewport, start, true)
	for frame: int in range(1, POINTER_TRAVEL_FRAMES + 1):
		_motion(viewport, start.lerp(target, float(frame) / float(POINTER_TRAVEL_FRAMES)), MOUSE_BUTTON_MASK_LEFT)
		await process_frame
	await _send_button(viewport, target, false)
	await _hold(PLAY_SETTLE_FRAMES)
	_assert(not bool(instance.call("_hand_card_empowered", 1)), "Clip: first charged card is played")
	_assert(int((instance.get("_combat_state") as Dictionary).get("player_turn_time_spent", 0)) == 6, "Clip: drag-play committed Empower")
	# Reinstall the same isolated fixture for the second authored gesture.
	_install_combat(instance)
	await _settle()
	_hide_log(instance)
	card = instance.call("_hand_card_control", 1)
	await _pointer(viewport, card.get_global_transform_with_canvas() * (card.size * 0.5), true)
	await _hold(HOLD_FRAMES)
	await _pointer(viewport, target)
	instance.call("_sync_click_targeting_arrow", target)
	await _hold(HOLD_FRAMES)
	_assert(int(instance.get("_selected_card_index")) == 1, "Clip: second card click enters targeting")
	seal = _seal(instance, 1)
	await _hold_seal_tooltip(viewport, seal, TooltipProof.OFFERED_TEXT)
	await _pointer(viewport, _seal_point(seal), true)
	_assert(bool(instance.call("_selected_card_empowered")), "Clip: seal charges during targeting")
	await _hold_seal_tooltip(viewport, seal, TooltipProof.CHARGED_TEXT)
	await _pointer(viewport, target, true)
	await _hold(PLAY_SETTLE_FRAMES)
	_assert(int((instance.get("_combat_state") as Dictionary).get("player_turn_time_spent", 0)) == 6, "Clip: click-target play committed Empower")
	if not _input_only:
		RenderingServer.force_draw()
		var final_image: Image = root.get_texture().get_image()
		_assert(final_image.get_size() == VIEWPORT_SIZE, "Movie proof uses 1920x1080")
		final_image.save_png("%s/clip_complete.png" % OUTPUT_DIR)
		print("UI03 MOVIE: 1920x1080 at 60 fps; output/ui03/empower-interactions.avi")
	if _input_only:
		_capture_host.close()
		_capture_host.queue_free()
		await process_frame
	# Keep the final recorded scene mounted until _initialize quits.

func _send_button(viewport: Viewport, point: Vector2, pressed: bool) -> void:
	if pressed:
		_motion(viewport, point)
		await process_frame
	var button := InputEventMouseButton.new()
	button.position = point
	button.global_position = point
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	_capture_host.route(button)

func _hold(frames: int) -> void:
	for frame: int in range(frames): await process_frame
