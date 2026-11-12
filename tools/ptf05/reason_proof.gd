extends SceneTree
const Fixture = preload("res://tools/ptf05/fixture.gd")
const Feedback = preload("res://scripts/target_click_feedback.gd")
# Headless viewport mouse getters remain OS-backed even after injected motion.
# Feed that getter explicitly while still dispatching the real viewport event.
class Host:
	extends "res://tests/card_targeting_audit_host.gd"
	var proof_pointer := Vector2.INF
	func _current_mouse_position() -> Vector2:
		return super._current_mouse_position() if proof_pointer == Vector2.INF else proof_pointer

const POINTER_HOLD_SHIFT := Vector2(200, 0)
const OUTPUT_DIR: String = "/private/tmp/labyrinth_codex/ptf-05b"
var failures: Array[String]
var scene: Node

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Host)
	root.size = Fixture.Base.PROOF_SIZE
	root.content_scale_size = Fixture.Base.PROOF_SIZE
	root.add_child(scene)
	await Fixture.Base.settle(self)
	await _floor_hover_cases()
	var expected: Dictionary = Fixture.REASONS
	for id: String in expected:
		Fixture.install(scene, id)
		await Fixture.select(scene, id)
		var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
		await scene.call("_on_board_tile_clicked", Fixture.tile_for(id))
		_check(scene.get("_combat_state") == before, id + " rejection preserves combat state")
		var feedback = scene.call("_click_feedback")
		_check(feedback.reason_label.text == expected[id], "%s => %s (expected %s)" % [id, feedback.reason_label.text, expected[id]])
		_check(feedback.reason_label.visible, id + " reason visible")
		_check_notice(feedback.reason_label, Feedback.REASON_FONT_SIZE, id)
		_check_reason_motion(feedback)
		_check_reason_placement(feedback)

	await _strike_hover()
	for card: String in ["hamstring_shot", "bloody_lunge", "sidestep_slash", "tectonic_maul"]:
		Fixture.install(scene, "floor_hover")
		var card_state: Dictionary = Fixture.state("floor_hover")
		card_state["deck"]["hand"] = [card]
		Fixture.Audit._install(scene, card_state)
		await scene.call("_on_card_pressed", 0)
		var floor_preview: Dictionary = scene.call("_active_card_preview")
		if card == "tectonic_maul":
			_check(not (scene.call("_shortcut_plan_for_tile", floor_preview, Fixture.FLOOR) as Dictionary).is_empty(), "Tectonic Maul floor keeps its existing strike shortcut")
		else:
			_check((floor_preview.get("target_tiles", []) as Array).has(Fixture.FLOOR) and (scene.call("_shortcut_plan_for_tile", floor_preview, Fixture.FLOOR) as Dictionary).is_empty(), card + " fixture hovers a valid movement destination")
		var floor_board: Control = scene.get("board_view")
		floor_board.call("_clear_hover_for_navigation")
		var motion := InputEventMouseMotion.new()
		motion.position = floor_board.get_global_transform_with_canvas() * floor_board.call("_tile_center", Fixture.FLOOR)
		motion.global_position = motion.position
		root.push_input(motion, true)
		await Fixture.Base.settle(self)
		var notice = scene.call("_click_feedback")
		notice._update_labels()
		_check(scene.get("_hovered_board_tile") == Fixture.FLOOR and notice.get_child_count() == 1 and not notice.reason_label.visible, card + " valid floor hover shows no notice")
	Fixture.install(scene, "reach")
	await Fixture.select(scene, "reach")
	var preview: Dictionary = scene.call("_active_card_preview")
	var presentation: Dictionary = scene.call("_preview_presentation", preview)
	_check((presentation.get("attack_reach_tiles", []) as Array).has(Fixture.FLOOR), "reach includes empty tile")
	_check(not (presentation.get("attack_reach_tiles", []) as Array).has(Fixture.ENEMY_FAR), "reach excludes range 4")
	_check(is_equal_approx(presentation["attack_reach_color"].a, 0.18), "reach alpha 18%")
	var blocked_state: Dictionary = Fixture.state("line_of_sight")
	var engine = scene.get("_combat_engine")
	_check(not Feedback.reach_tiles(engine, blocked_state, {"type": "ranged", "range": 3}).has(Fixture.ENEMY_NEAR), "reach excludes blocked line of sight")
	var router: Node = root.get_node("InputRouter")
	router.call("set_modality", "controller")
	scene.set("_controller_board_tile", Fixture.ENEMY_FAR)
	var feedback = scene.call("_click_feedback")
	feedback.show_reason("Out of range", Fixture.ENEMY_FAR)
	var board: Control = scene.get("board_view")
	var anchor: Vector2 = _expected_reason_rest(feedback).position
	feedback._update_labels(feedback.reason_started_usec + 200000)
	_check(feedback.reason_label.position.is_equal_approx(anchor), "controller reason shares the clicked-tile front anchor")
	_check_notice(feedback.reason_label, Feedback.REASON_FONT_SIZE, "reason")
	feedback.show_reason("Blocked", Fixture.CRATE)
	_check(feedback.reason_label.text == "Blocked" and is_zero_approx(feedback.reason_label.modulate.a), "new click replaces reason and restarts in-phase at zero alpha")
	_check(feedback.get_child_count() == 1, "only one reason notice; no stacking")

	router.call("set_modality", "pointer")
	for message: String in failures: push_error(message)
	print("PTF05 REASON PROOF: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _floor_hover_cases() -> void:
	for id: String in Fixture.CASES:
		Fixture.install(scene, id)
		await Fixture.select(scene, id)
		await Fixture.Base.settle(self)
		var board: Control = scene.get("board_view")
		var tile: Vector2i = Fixture.tile_for(id)
		var point: Vector2 = Fixture.Base.pointer_point(board, tile)
		_check(board.call("_tile_at_point", point) == tile, id + " capture point hits intended floor tile")
		var motion := InputEventMouseMotion.new()
		motion.position = board.get_global_transform_with_canvas() * point
		motion.global_position = motion.position
		board.call("_clear_hover_for_navigation")
		root.push_input(motion, true)
		await Fixture.Base.settle(self)
		_check(scene.get("_hovered_board_tile") == tile, id + " capture hover reaches intended floor tile")

func _strike_hover() -> void:
	Fixture.install(scene, "strike")
	await Fixture.select(scene, "strike")
	await Fixture.Base.settle(self)
	var board: Control = scene.get("board_view")
	var point: Vector2 = Fixture.Base.pointer_point(board, Fixture.Base.ENEMY_TILE)
	_check(board.call("_tile_at_point", point) == Fixture.Base.ENEMY_TILE, "strike pointer hits intended floor tile")
	var viewport_point: Vector2 = board.get_global_transform_with_canvas() * point
	board.call("_clear_hover_for_navigation")
	var motion := InputEventMouseMotion.new()
	motion.position = viewport_point
	motion.global_position = viewport_point
	root.push_input(motion, true)
	_check((board.get("_last_pointer_position") as Vector2).is_equal_approx(point), "strike viewport motion reaches board GUI input")
	_check(scene.get("_hovered_board_tile") == Fixture.Base.ENEMY_TILE, "strike real hover reaches RunScene")
	await Fixture.Base.settle(self)
	var presentation: Dictionary = board.get("presentation")
	var damage: Dictionary = board.call("_build_damage_preview_map", presentation)
	_check(damage.has("enemy_1"), "strike real hover produces renderer-consumed enemy damage preview")
	_check((presentation.get("effect", {}) as Dictionary).get("kind", "") == "melee", "strike hover retains melee preview")
	print("PTF05 STRIKE HOVER: top_level=%s effect=%s" % [presentation.get("damage_preview", {}), (presentation.get("effect", {}) as Dictionary).get("damage_preview", {})])

func _check_notice(notice: Control, pixels: int, context: String) -> void:
	var palette = preload("res://scripts/ui_palette.gd")
	_check(not notice is PanelContainer and notice.get_child_count() == 0 and not notice.has_theme_stylebox_override("panel"), context + " is bare text without a panel, stylebox or background")
	_check(notice.get("font") == preload("res://scripts/ui_typography.gd").display_font(), context + " uses display font")
	_check(notice.get("font_size") == pixels, context + " uses decided text size")
	_check(palette.BOARD_TITLE_FILL == Color("fff0cf") and palette.BOARD_TITLE_OUTLINE == Color(0.035, 0.022, 0.025, 0.98), context + " shares intent fill and outline")
	_check(palette.BOARD_TITLE_SHADOW == Color(0.015, 0.01, 0.015, 0.82) and Feedback.Text.SHADOW_OFFSET == Vector2(3.5, 4.5) and Feedback.Text.OUTLINE_SIZE == 2.25, context + " shares intent shadow and 2.25 px contour")
	var width: float = notice.get("font").get_string_size(notice.get("text"), HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	_check(is_equal_approx(notice.size.x, width), context + " bounds contain text only without panel padding")

func _check_reason_motion(feedback: Node) -> void:
	var board: Control = scene.get("board_view")
	var anchor: Vector2 = _expected_reason_rest(feedback).position
	var samples: Array = [[0.0, 0.0, 8.0], [0.07, 0.875, 1.0], [0.14, 1.0, 0.0], [0.59, 1.0, 0.0], [1.04, 1.0, 0.0], [1.18, 0.75, -1.5], [1.32, 0.0, 0.0]]
	var settings: Dictionary = scene.get("_settings")
	var was_reduced: bool = bool(settings.get("reduced_motion", false))
	for reduced: bool in [false, true]:
		settings["reduced_motion"] = reduced
		for sample: Array in samples:
			feedback._update_labels(feedback.reason_started_usec + roundi(float(sample[0]) * 1000000.0))
			_check(is_equal_approx(feedback.reason_label.modulate.a, float(sample[1])), "reason alpha at %.2f reduced=%s" % [sample[0], reduced])
			_check(feedback.reason_label.position.is_equal_approx(anchor + Vector2(0, 0 if reduced else sample[2])), "reason offset at %.2f reduced=%s" % [sample[0], reduced])
	_check(not feedback.reason_label.visible, "reason hides after complete in, hold, out")
	settings["reduced_motion"] = was_reduced
	for phase_time: float in [0.07, 0.59, 1.18]:
		feedback._update_labels(feedback.reason_started_usec + roundi(phase_time * 1000000.0))
		feedback.show_reason(feedback.reason_label.text, feedback.reason_tile)
		_check(is_zero_approx(feedback.reason_label.modulate.a), "restart during %.2f resets alpha" % phase_time)
		_check(feedback.reason_label.position.is_equal_approx(anchor + Vector2(0, 0 if was_reduced else 8)), "restart resets rise")
	var started: int = feedback.reason_started_usec
	feedback._process(999.0)
	_check(feedback.reason_started_usec == started and feedback.reason_label.visible, "presentation clock ignores arbitrary gameplay process delta")

func _expected_reason_rest(feedback: Node) -> Rect2:
	var board: Control = scene.get("board_view")
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var centre: Vector2 = transform * board.call("_tile_center", feedback.reason_tile)
	var bottom: float = -INF
	for point: Vector2 in board.call("_tile_polygon", feedback.reason_tile):
		bottom = maxf(bottom, (transform * point).y)
	return Rect2(Vector2(centre.x - feedback.reason_label.size.x * 0.5, bottom + 10.0), feedback.reason_label.size)

func _check_reason_placement(feedback: Node) -> void:
	var board: Control = scene.get("board_view")
	var hold_time: int = feedback.reason_started_usec + 590000
	feedback._update_labels(hold_time)
	var rest: Rect2 = _expected_reason_rest(feedback)
	_check(feedback.reason_label.get_global_rect().is_equal_approx(rest), "reason rest centres text with its top 10 px below the tile front")
	var pointer: Vector2 = board.get_global_transform_with_canvas() * board.call("_tile_center", feedback.reason_tile)
	scene.set("proof_pointer", pointer)
	var motion := InputEventMouseMotion.new()
	motion.position = pointer + POINTER_HOLD_SHIFT
	motion.global_position = motion.position
	scene.set("proof_pointer", motion.position)
	root.push_input(motion, true)
	_check((scene.call("_current_mouse_position") as Vector2).is_equal_approx(pointer + POINTER_HOLD_SHIFT), "injected pointer getter moves 200 px during hold")
	feedback._update_labels(hold_time)
	_check(feedback.reason_label.get_global_rect().is_equal_approx(rest), "reason rest ignores a 200 px pointer move during hold")
	# Targeting deliberately fits the room instead of using navigation offsets.
	# Exercise normal production pan/zoom presentation without changing combat.
	var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	var old_zoom: float = board.get("_navigation_zoom")
	var old_pan: Vector2 = board.get("_navigation_pan")
	var old_default: bool = board.get("_navigation_uses_default_zoom")
	board.get("presentation")["board_targeting"] = false
	var navigation: Dictionary = board.call("navigation_snapshot")
	board.call("set_navigation_zoom", navigation["max_zoom"])
	feedback._update_labels(hold_time)
	var zoomed: Rect2 = _expected_reason_rest(feedback)
	_check(feedback.reason_label.get_global_rect().is_equal_approx(zoomed), "reason gap follows current board zoom")
	_check(not zoomed.is_equal_approx(rest), "zoom witness moves the reason anchor")
	navigation = board.call("navigation_snapshot")
	var limits: Rect2 = navigation["pan_limits"]
	var target: Vector2 = limits.position if not (navigation["pan"] as Vector2).is_equal_approx(limits.position) else limits.end
	board.call("set_navigation_pan", target, false)
	feedback._update_labels(hold_time)
	var panned: Rect2 = _expected_reason_rest(feedback)
	_check(not panned.is_equal_approx(zoomed), "production board pan moves the clicked tile")
	_check(feedback.reason_label.get_global_rect().is_equal_approx(panned), "reason rest follows production board pan")
	board.set("presentation", presentation)
	board.set("_navigation_zoom", old_zoom)
	board.set("_navigation_pan", old_pan)
	board.set("_navigation_uses_default_zoom", old_default)
	board.call("_navigation_transform_changed", false)
	feedback._update_labels(hold_time)
	motion = InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	root.push_input(motion, true)
	scene.set("proof_pointer", Vector2.INF)

func _check(ok: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures.append(message)
