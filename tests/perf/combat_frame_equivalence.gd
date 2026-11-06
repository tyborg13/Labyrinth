extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Reference = preload("res://tests/perf/visual_rects_reference.gd")
const Redraws = preload("res://scripts/board_preview_redraws.gd")
const Arena = preload("res://tests/suites/warband_suite.gd")
const PROOF_SIZE := Vector2(1920, 1080)

class CommandBoard extends Board:
	var curves: Array = []
	func _draw_single_path_marker(center: Vector2, color: Color, tile_width: float) -> void:
		_path_captured_commands.append({"single_marker": [center, color, tile_width]})
	func _draw_ranged_target_preview_curve(effect: Dictionary, from_point: Vector2, to_point: Vector2) -> void:
		curves.append([effect.duplicate(true), from_point, to_point])

class RoutingBoard extends Board:
	var queued: Array = []
	func _queue_render_layer_redraw(layer: Control, _clock_only: bool = false) -> void: queued.append(layer)
	func _queue_dynamic_redraw() -> void: queued.append("all")

class PathRoutingBoard extends Board:
	var queued_tiles: Dictionary = {}
	func _queue_scene_render_layer_for_tile(tile: Vector2i) -> void:
		queued_tiles[tile] = true
		super._queue_scene_render_layer_for_tile(tile)

static func run(tree: SceneTree, expect: Callable) -> void:
	_paths(expect)
	await _path_routing(tree, expect)
	await _rects(tree, expect)
	await preload("res://tests/perf/ui_retention_equivalence.gd").run(tree, expect)

static func _paths(expect: Callable) -> void:
	var board := CommandBoard.new()
	board.combat_state = Arena.arena()
	board.size = PROOF_SIZE
	var states: Array[Dictionary]
	states.assign([{},
		{"path_tiles": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]},
		{"displacement_paths": [[Vector2i(4, 4), Vector2i(4, 3)]], "path_tiles": [Vector2i(3, 4)]},
		{"enemy_threat_previews": [{"projected_path": [Vector2i(5, 4), Vector2i(4, 4)], "projected_destination": Vector2i(4, 4), "projected_attack": [Vector2i(2, 4)], "projected_attack_target": Vector2i(2, 4), "projected_attack_action": {"type": "ranged", "range": 4}}]},
		{"illusion_echo_previews": [{"from": Vector2i(3, 3), "to": Vector2i(6, 3), "element": "light"}]},
		{"path_tiles": [Vector2i(6, 4), Vector2i(5, 4)], "path_color": board.ENEMY_PATH_PREVIEW_COLOR}, {}])
	var comparisons: int = 0
	var stale_detected: bool = false
	for index: int in range(states.size() - 1):
		var previous: Dictionary = states[index]
		var next: Dictionary = states[index + 1]
		var dirty: Dictionary = Redraws.tiles(board, previous, next)
		for tile: Vector2i in board._rendered_tiles_in_draw_order():
			var old_commands: Array = _commands(board, previous, tile)
			var next_commands: Array = _commands(board, next, tile)
			var retained: Array = next_commands if dirty.has(tile) else old_commands
			expect.call(retained == next_commands, "Selective redraw retains exactly the full redraw's commands at " + str(tile))
			if old_commands != next_commands: stale_detected = true
			comparisons += 1
	expect.call(stale_detected, "Mutation: suppressing dirty tiles produces a visible command difference")
	board.free()
	print("PERF03 PATH EQUIVALENCE: %d ordered command comparisons; stale redraw mutation detected" % comparisons)

static func _path_routing(tree: SceneTree, expect: Callable) -> void:
	var board := PathRoutingBoard.new()
	board.size = PROOF_SIZE
	tree.root.add_child(board)
	var state: Dictionary = Arena.arena()
	var old_tile := Vector2i(2, 2)
	var new_tile := Vector2i(5, 3)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"path_tiles": [old_tile]})
	for _frame: int in range(3): await tree.process_frame
	board.reset_render_instrumentation()
	board.queued_tiles.clear()
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"path_tiles": [new_tile]})
	expect.call(board.queued_tiles.has(old_tile) and board.queued_tiles.has(new_tile), "Production set_combat_state routes both old and new path tiles; an empty routing loop fails")
	for _frame: int in range(3): await tree.process_frame
	var draws: Dictionary = board.render_instrumentation_snapshot().get("scene_tile_draw_counts", {})
	for tile: Vector2i in [old_tile, new_tile]:
		expect.call(int(draws.get("%d,%d" % [tile.x, tile.y], 0)) > 0, "Production retained tile actually draws after path replacement: " + str(tile))
	board.reset_render_instrumentation()
	board.queued_tiles.clear()
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	expect.call(board.queued_tiles.has(new_tile), "Production clear redraws the removed path tile")
	for _frame: int in range(3): await tree.process_frame
	draws = board.render_instrumentation_snapshot().get("scene_tile_draw_counts", {})
	expect.call(int(draws.get("%d,%d" % [new_tile.x, new_tile.y], 0)) > 0, "Removed path tile actually draws its cleared commands")
	board.free()
	print("PERF03 PRODUCTION PATH ROUTING: old/new/cleared tiles queued and actually drawn")

static func _commands(board: CommandBoard, source: Dictionary, tile: Vector2i) -> Array:
	board.presentation = source
	board.curves.clear()
	var empty: Array[Dictionary]
	board._path_captured_commands = empty
	board._path_command_capture_active = true
	board._draw_path_depth_pass(tile)
	board._draw_enemy_threat_depth_pass(tile)
	board._path_command_capture_active = false
	return [board._path_captured_commands.duplicate(true), board.curves.duplicate(true)]

static func _rects(tree: SceneTree, expect: Callable) -> void:
	var candidate := Board.new()
	var reference := Reference.new()
	for board: Control in [candidate, reference]:
		board.size = PROOF_SIZE
		tree.root.add_child(board)
		board.set_combat_state(Arena.arena())
	await tree.process_frame
	var comparisons: int = 0
	for mutation: String in ["initial", "warm", "grid", "resize", "pan", "door", "actor", "props", "loot", "trap", "texture"]:
		for board: Control in [candidate, reference]:
			if mutation == "grid": board.combat_state["grid"][3][3] = "pillar"
			if mutation == "resize": board.size = Vector2(1500, 900)
			if mutation == "pan":
				board._navigation_pan += Vector2(10, 5)
				board._invalidate_board_layout_cache(false)
			if mutation == "door":
				board.combat_state["grid"][0][4] = "door"
				board.presentation["active_door_tiles"] = {Vector2i(4, 0): true}
			if mutation == "actor": board.combat_state["player"]["pos"] += Vector2i.RIGHT
			if mutation == "props": board.presentation["scene_props"] = [{"kind": "wooden_crate", "tile": Vector2i(3, 2)}]
			if mutation == "loot": board.combat_state["loot"] = [{"kind": "gold", "pos": Vector2i(5, 3), "amount": 2}]
			if mutation == "trap": board.combat_state["traps"] = [{"id": "proof", "element": "fire", "pos": Vector2i(2, 4), "damage": 8}]
			if mutation == "texture": board._prop_textures["pillar"] = board._prop_textures.get("door", null)
			board._invalidate_board_layout_cache(false)
			board._submission_cache_valid = false
			board._ensure_board_layout_cache()
		# Force the stale entry to have the current hash: equality must reject it.
		candidate._fixed_visual_rects._key = hash(candidate._fixed_visual_rects._inputs(candidate))
		var expected: Array[Rect2] = reference.rendered_visual_rects()
		var actual: Array[Rect2] = candidate.rendered_visual_rects()
		expect.call(actual == expected, "Ordered visual-rect equivalence: " + mutation)
		expect.call(candidate.rendered_visual_bounds() == reference.rendered_visual_bounds(), "Exact combined bound: " + mutation)
		var owned: Dictionary = candidate._fixed_visual_rects.resolve(candidate)
		for tile: Vector2i in owned: owned[tile].clear()
		expect.call(candidate.rendered_visual_rects() == expected, "Cache hits deeply own arrays: " + mutation)
		comparisons += 1
	var cache: RefCounted = candidate._fixed_visual_rects
	var before: Dictionary = cache.resolve(candidate)
	candidate.combat_state["grid"][3][3] = "stone"
	candidate._ensure_board_layout_cache()
	cache._key = hash(cache._inputs(candidate))
	var after: Dictionary = cache.resolve(candidate)
	expect.call(before != after, "Mutation: stale fixed-rect output differs visibly after removing a pillar")
	print("PERF03 RECT EQUIVALENCE: %d ordered rect/bounds/ownership comparisons; forced-hash and stale-geometry mutations detected" % comparisons)
	candidate.queue_free()
	reference.queue_free()
	for frame: int in range(3): await tree.process_frame
