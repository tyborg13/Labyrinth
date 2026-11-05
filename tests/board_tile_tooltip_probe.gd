extends "res://tests/board_surface_visual_probe.gd"

const TileTooltip = preload("res://scripts/board_tile_tooltip.gd")
const SurfaceArt = preload("res://scripts/board_surface_presentation.gd")
const PROOF_TILES: Array = [Vector2i(3, 4), Vector2i(4, 4), Vector2i(6, 4)]
const PROOF_KINDS: Array = ["fire", "ice", "electrified"]
const PROOF_ENEMY_TILES: Array = [Vector2i(7, 2), Vector2i(8, 2), Vector2i(7, 3), Vector2i(8, 3)]
const PROOF_EDGE_TILES: Array = [Vector2i(1, 1), Vector2i(9, 1), Vector2i(1, 8), Vector2i(9, 8)]
const TOOLTIP_WAIT_SECONDS: float = 1.5
const PROOF_TRAP_DAMAGE: int = 7
const PROOF_CLEAR_POINTER := Vector2(960, 20)
const PROOF_SETTLE_FRAMES: int = 8
const EXPECTED_CAPTURE_STATES: int = 12
var headless_routes: bool = false
var _capture_states: int = 0

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--plan-only"):
		preload("res://scripts/parallel_runtime.gd").apply_from_environment()
		var planned: Dictionary = _mixed_state(Fixture.fixture(Combat.new()))
		for index: int in range(PROOF_TILES.size()):
			assert(Ground.has_rubble(planned, PROOF_TILES[index]))
			assert(Ground.element_at(planned, PROOF_TILES[index]) == PROOF_KINDS[index])
		assert((load("res://tests/steam_deck_compat_probe.gd") as Script).can_instantiate())
		assert((load("res://tests/dragon_reward_tooltip_probe.gd") as Script).can_instantiate())
		assert((load("res://tests/board_surface_cache_equivalence_probe.gd") as Script).can_instantiate())
		print("BOARD TILE TOOLTIP PROBE PLAN: PASS (1920x1080, UI scale 1.0; three pairs; mouse/controller; native edge bounds; normal/reduced)")
		quit()
		return
	ground_loop_only = true
	await super._initialize()

func _mixed_state(original: Dictionary) -> Dictionary:
	var mixed: Dictionary = original.duplicate(true)
	mixed["surfaces"] = {}
	mixed["surface_rule_overrides"] = {}
	for index: int in range((mixed["enemies"] as Array).size()):
		mixed["enemies"][index]["pos"] = PROOF_ENEMY_TILES[index]
	for index: int in range(PROOF_TILES.size()):
		Ground.place(mixed, PROOF_TILES[index], "rubble")
		Ground.place(mixed, PROOF_TILES[index], PROOF_KINDS[index])
	return mixed

func _capture(label: String, _settle_frames: int = 8) -> void:
	if label != "01_mixed_ground": return
	state = _mixed_state(state)
	var board: Control = scene.get("board_view")
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	var router: Node = root.get_node("InputRouter")
	for reduced: bool in [false, true]:
		var settings: Dictionary = Settings.load_settings()
		settings["reduced_motion"] = reduced
		Settings.save_settings(settings)
		scene.set("_settings", settings)
		scene.set("_combat_state", state)
		(scene.get("_run_state") as Dictionary)["combat_state"] = state
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_refresh_ui")
		var mode: String = "reduced" if reduced else "normal"
		router.call("set_forced_state_for_test", "pointer", "xbox")
		await _capture_state("srf01_" + mode + "_pairs")
		await _hover(board, PROOF_TILES[1], 2)
		await _capture_state("srf01_" + mode + "_mouse_ice")
		await _hover(board, Vector2i(-1, -1), 0)
		router.call("set_forced_state_for_test", "controller", "xbox")
		await _settle_controls()
		# Changing a selected tile does not change navigation regions. Use the
		# same X / Unfocus Hand input the player uses before choosing the proof tile.
		if str(scene.get("_controller_region")) != "hand" or not bool(scene.get("_controller_hand_focused")):
			await _press_controller_button(JOY_BUTTON_X)
		assert(str(scene.get("_controller_region")) == "hand" and bool(scene.get("_controller_hand_focused")), "Player route starts in the focused hand")
		await _press_controller_button(JOY_BUTTON_X)
		assert(str(scene.get("_controller_region")) == "board" and not bool(scene.get("_controller_hand_focused")), "Player X input enters board focus")
		var keywords: Control = scene.get("_card_focus_tooltip_stack")
		assert(keywords == null or not keywords.visible, "Unfocus Hand dismisses the card's keyword stack")
		scene.call("_controller_set_board_tile", PROOF_TILES[1])
		await _capture_state("srf01_" + mode + "_controller_ice")
		var cursor: Control = scene.get("_controller_analog_cursor")
		assert(cursor.visible and cursor.get("_detail_panel") != null, "Real controller path presents the stack")
		var detail: Control = cursor.get("_detail_panel")
		assert(detail.has_meta("tile_tooltip_stack") and detail.get_child_count() == 2)
		_assert_panels(detail, Rect2(Vector2.ZERO, Vector2(view.size)))
		router.call("set_forced_state_for_test", "pointer", "xbox")
		state["traps"] = [{"pos": PROOF_TILES[0], "element": "earth", "damage": PROOF_TRAP_DAMAGE}]
		scene.set("_combat_state", state)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_refresh_ui")
		await _hover(board, PROOF_TILES[0], 3)
		await _capture_state("srf01_" + mode + "_mouse_fire_trap")
		state["traps"] = []
		await _hover(board, Vector2i(-1, -1), 0)
	# Actual native popup placement at the board's four outer floor corners.
	var edges: Array = PROOF_EDGE_TILES
	for tile: Vector2i in edges:
		Ground.place(state, tile, "rubble")
		Ground.place(state, tile, "ice")
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	for index: int in range(edges.size()):
		await _hover(board, edges[index], 2)
		await _capture_state("srf01_edge_%d" % index)
	await _hover(board, Vector2i(-1, -1), 0)
	router.call("clear_forced_state_for_test")
	assert(_capture_states == EXPECTED_CAPTURE_STATES, "The route must reach all twelve capture states")
	if headless_routes:
		print("BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)")
	else:
		print("BOARD TILE TOOLTIP VISUAL PROBE: PASS (12 images)")
		print(ProjectSettings.globalize_path(OUTPUT))

func _capture_state(label: String) -> void:
	_capture_states += 1
	if headless_routes: await _settle_controls()
	else: await super._capture(label)

func _settle_controls() -> void:
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame

func _press_controller_button(button: int) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button
	press.device = 0
	press.pressed = true
	view.push_input(press, true)
	await _settle_controls()
	var release := InputEventJoypadButton.new()
	release.button_index = button
	release.device = 0
	release.pressed = false
	view.push_input(release, true)
	await _settle_controls()

func _hover(board: Control, tile: Vector2i, count: int) -> void:
	# Eight uncapped headless frames do not finish the scene's wall-clock
	# centering tween. Aim only once the board has reached its final transform;
	# otherwise the recorded point can move off the intended tile during hover.
	var centering: Tween = scene.get("_board_centering_tween")
	while centering != null and centering.is_valid() and centering.is_running():
		await process_frame
		centering = scene.get("_board_centering_tween")
	var motion := InputEventMouseMotion.new()
	motion.position = board.get_global_transform_with_canvas() * board.call("_tile_center", tile) if tile.x >= 0 else PROOF_CLEAR_POINTER
	motion.global_position = motion.position
	view.push_input(motion, true)
	await create_timer(TOOLTIP_WAIT_SECONDS).timeout
	if count == 0: return
	assert(view.gui_get_hovered_control() == board, "Native hover reaches the real board")
	var popup: Window = _popup(board)
	if popup == null:
		print("TILE TOOLTIP MISSING: ", {"tile": tile, "position": board.position, "target": scene.get("_board_centering_target"), "pointer": board.get("_last_pointer_position"), "enabled": board.get("_tooltips_enabled"), "text": board.call("_get_tooltip", board.get("_last_pointer_position")), "other_popup": _popup(view)})
	assert(popup != null, "Native tile tooltip opens")
	assert(Rect2(Vector2.ZERO, Vector2(view.size)).encloses(Rect2(Vector2(popup.position), Vector2(popup.size))), "Native stack stays on-screen")
	var stack: Control = _stack(popup)
	assert(stack != null and stack.get_child_count() == count, "Native popup has one shared panel per tile effect")
	_assert_panels(stack, Rect2(Vector2.ZERO, Vector2(popup.size)), Vector2(popup.position))

func _assert_panels(stack: Control, containing_bounds: Rect2, screen_offset: Vector2 = Vector2.ZERO) -> void:
	assert(containing_bounds.encloses(stack.get_global_rect()), "Real tooltip bounds contain the complete stack")
	var previous := Rect2()
	for panel: Control in stack.get_children():
		var bounds: Rect2 = panel.get_global_rect()
		assert(panel.is_visible_in_tree() and panel.modulate.a > 0.0 and bounds.has_area(), "Every real tooltip panel is visible")
		assert(containing_bounds.encloses(bounds), "Real tooltip bounds fully contain each panel")
		assert(Rect2(Vector2.ZERO, Vector2(view.size)).encloses(Rect2(bounds.position + screen_offset, bounds.size)), "Every real tooltip panel is fully on screen")
		if previous.has_area(): assert(is_equal_approx(bounds.position.y - previous.end.y, 6.0), "Real tooltip panels retain the specified six-pixel gap")
		previous = bounds

func _stack(parent: Node) -> Control:
	if parent is Control and parent.has_meta("tile_tooltip_stack"): return parent
	for child: Node in parent.get_children():
		var found: Control = _stack(child)
		if found != null: return found
	return null

func _popup(parent: Node) -> Window:
	for child: Node in parent.get_children():
		if child is Window and child.visible and child.theme_type_variation == &"TooltipPanel": return child
		var found: Window = _popup(child)
		if found != null: return found
	return null
