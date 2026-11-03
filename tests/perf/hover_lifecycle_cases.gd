extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Reference = preload("res://tests/perf/hover_board_reference.gd")
const Arena = preload("res://tests/suites/warband_suite.gd")
const PROOF_SIZE := Vector2(1920, 1080)
const SETTLE_FRAMES: int = 3
const OBSTACLE_MARGIN: float = 25.0
const NO_TILE := Vector2i(-1, -1)

static func run(tree: SceneTree, expect: Callable) -> void:
	var candidate := Board.new()
	var reference := Reference.new()
	var state: Dictionary = Arena.arena()
	var shown: Dictionary = {"reduced_motion": true}
	var first: Vector2i = state["enemies"][0]["pos"]
	var second: Vector2i = state["enemies"][1]["pos"]
	for board: Control in [candidate, reference]:
		board.size = PROOF_SIZE
		tree.root.add_child(board)
		board.set_process(false)
		board._hover_tile = first
		board.set_combat_state(state, [], [], NO_TILE, "", "", {}, {}, shown)
		expect.call(board._hover_tile == first and board._controller_focus_tile == NO_TILE, "Warmup restores hover/focus before submission returns")
	await _settle(tree)
	_assert_hud(candidate, reference, expect, "initial hovered submission")
	var intent := Rect2()
	for entry: Dictionary in reference._hud_layout_entries_cache:
		if entry.get("kind") == "enemy" and (entry.get("layout", {}) as Dictionary).get("intent_rect", Rect2()).has_area():
			intent = entry["layout"]["intent_rect"]
			break
	expect.call(intent.has_area(), "Obstacle regression covers a real expanded intent rectangle")
	shown = shown.duplicate(true)
	shown["hud_obstacle_global_rects"] = [intent.grow(OBSTACLE_MARGIN)]
	for board: Control in [candidate, reference]:
		board.set_combat_state(state, [], [], NO_TILE, "", "", {}, {}, shown.duplicate(true))
		expect.call(board._hover_tile == first, "Obstacle warmup preserves the pointer tile")
	await _settle(tree)
	_assert_hud(candidate, reference, expect, "obstacle warmup")
	for board: Control in [candidate, reference]: board.set_controller_focus_tile(first)
	await _settle(tree)
	_assert_hud(candidate, reference, expect, "same enemy controller focus after obstacle warmup")
	# Restore a collapsed second enemy before testing a deferred update across exit.
	for board: Control in [candidate, reference]:
		board.set_controller_focus_tile(NO_TILE)
		board._hover_tile = first
		board._queue_hover_redraws()
	await _settle(tree)
	for board: Control in [candidate, reference]:
		board._update_hover_at(board.world_position_for_tile(second))
		tree.root.remove_child(board)
	await _settle(tree)
	expect.call(candidate._hover_hud_refresh_pending, "Detached hover stays dirty after its deferred flush")
	for board: Control in [candidate, reference]: tree.root.add_child(board)
	await _settle(tree)
	expect.call(candidate._hover_tile == second and not candidate._hover_hud_refresh_pending, "Re-entry flushes enemy 2 without another input event")
	_assert_hud(candidate, reference, expect, "detached deferred hover re-entry")
	# Also reattach before the original deferred call executes (two scheduled calls).
	for board: Control in [candidate, reference]:
		board._update_hover_at(board.world_position_for_tile(first))
		tree.root.remove_child(board)
		tree.root.add_child(board)
	await _settle(tree)
	_assert_hud(candidate, reference, expect, "same-frame detach/re-entry")
	candidate.queue_free()
	reference.queue_free()
	await _settle(tree)
	print("PERF04 HOVER LIFECYCLE RESULT: obstacle/controller and both detach/re-entry regressions exercised")

static func _assert_hud(candidate: Control, reference: Control, expect: Callable, label: String) -> void:
	expect.call(candidate._hud_layout_entries_cache == reference._hud_layout_entries_cache, "Independent HUD oracle: " + label)
	for board: Control in [candidate, reference]:
		expect.call(board._hud_render_layer != null, "Real retained HUD exists: " + label)
		expect.call(board._hud_layout_entries_cache == board._hud_render_layer.get("_hud_layout_entries_cache"), "Retained HUD equals its parent: " + label)
		expect.call(board._hud_health_rects_cache == board._effects_render_layer.get("_hud_health_rects_cache"), "Retained effects receive current HUD geometry: " + label)
	expect.call(candidate._hud_render_layer.get("_hud_layout_entries_cache") == reference._hud_render_layer.get("_hud_layout_entries_cache"), "Independent retained HUD oracle: " + label)

static func _settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
