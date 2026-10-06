extends SceneTree
const Board = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
class FreshBoard:
	extends "res://scripts/combat_board_view.gd"
	func _take_prepared_unit_renderer(_type: String, _unit_id: int, script: Script) -> Node:
		return script.new()
var _errors: Array[String]
var _checks: int = 0
var _cases: int = 0
var _differences: Array[Dictionary]
var _native: bool = false
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_native = DisplayServer.get_name() != "headless"
	if _native: DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await process_frame
	for reduced: bool in [false, true]:
		for offset: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			for reaction: String in ["", "hit", "block", "death"]:
				await _case(reduced, offset, reaction)
	print("PREPARED UNIT CANVAS RESULT: " + JSON.stringify({"cases": _cases, "checks": _checks, "pixel_differences": _differences, "native": _native, "errors": _errors, "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if _errors.is_empty() else 1)
func _case(reduced: bool, offset: Vector2i, reaction: String) -> void:
	_cases += 1
	var actual_view := SubViewport.new()
	var fresh_view := SubViewport.new()
	for view: SubViewport in [actual_view, fresh_view]:
		view.size = Vector2i(1920, 1080)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
	var actual := Board.new()
	var fresh := FreshBoard.new()
	actual_view.add_child(actual)
	fresh_view.add_child(fresh)
	for board: Control in [actual, fresh]:
		board.size = Vector2(1920, 1080)
		board.set_process(false)
	await _frame()
	var state: Dictionary = _state(offset)
	var jobs: Array[Dictionary] = actual.begin_unit_renderer_preparation(state)
	var prepared_ids: Dictionary = {}
	for job: Dictionary in jobs:
		actual.prepare_unit_renderer(job, reduced)
		var node: Node = actual._prepared_unit_renderers[job["key"]]
		prepared_ids[job["type"]] = node.get_instance_id()
		_check(not node.is_processing(), "Prepared renderer must pause at the original phase")
		await _frame()
	_check(actual.combat_state.is_empty(), "Preparation must not replace the live board state")
	var presentation: Dictionary = {"reduced_motion": reduced, "board_framing_mode": "combat"}
	if not reaction.is_empty():
		for family: String in ["crawler", "harrier", "frostglass"]:
			var motions: Dictionary = {}
			for index: int in range(1, 4): motions["enemy_%d" % index] = {"clip": reaction, "phase": 0.04}
			presentation[family + "_motion"] = motions
	actual.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	fresh.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	var pairs: Array[Dictionary]
	for type: String in ["crawler", "harrier", "frostglass_lancer"]:
		var pool_name: String = {"crawler": "_crawler_renderers", "harrier": "_harrier_renderers", "frostglass_lancer": "_frostglass_renderers"}[type]
		var actual_pool: Dictionary = actual.get(pool_name)
		var fresh_pool: Dictionary = fresh.get(pool_name)
		var index: int = ["crawler", "harrier", "frostglass_lancer"].find(type) + 1
		var actual_node: Node = actual_pool["enemy_%d" % index]
		var fresh_node: Node = fresh_pool["enemy_%d" % index]
		pairs.append({"type": type, "actual": actual_node, "fresh": fresh_node})
		_check(actual_node.get_instance_id() == prepared_ids[type], "The normal roster must adopt its actual prepared canvas")
		_check(actual_node.is_processing(), "Adopted canvas must resume its original processing")
		actual_node.set_process(false)
		fresh_node.set_process(false)
		var a: Dictionary = actual_node.snapshot()
		var b: Dictionary = fresh_node.snapshot()
		a.erase("texture_id"); b.erase("texture_id")
		_check(a == b, "Prepared canvas must preserve facing, mirroring, clip, phase, activity and rig count")
	_check(actual._prepared_unit_renderers.is_empty(), "Adoption must remove transferred nodes from preparation ownership")
	for board: Control in [actual, fresh]:
		if is_instance_valid(board._protagonist_renderer): board._protagonist_renderer.set_process(false)
	await _frame()
	await _frame()
	if _native:
		for pair: Dictionary in pairs:
			_check(pair["actual"].texture().get_image().get_data() == pair["fresh"].texture().get_image().get_data(), "Every prepared actor canvas must match its fresh pixels, including occluded bodies")
		var a: Image = actual_view.get_texture().get_image()
		var b: Image = fresh_view.get_texture().get_image()
		if a.get_data() != b.get_data():
			_differences.append({"case": _cases, "reduced": reduced, "offset": str(offset), "reaction": reaction})
			_check(false, "Prepared and fresh board pixels must match exactly")
		if _cases == 1:
			var destination: String = "user://prepared_unit_canvas.png"
			a.save_png(destination)
			print("PREPARED UNIT CANVAS IMAGE: " + ProjectSettings.globalize_path(destination))
	# A replacement generation and a canceled partial generation retain no node.
	jobs = actual.begin_unit_renderer_preparation(state)
	for job: Dictionary in jobs: actual.prepare_unit_renderer(job, reduced)
	var partial: Array[Node]
	for node: Node in actual._prepared_unit_renderers.values(): partial.append(node)
	actual.begin_unit_renderer_preparation({"enemies": []})
	_check(actual._prepared_unit_renderers.is_empty(), "Replacement generation must discard prior canvases")
	for node: Node in partial: _check(node.is_queued_for_deletion(), "Discarded canvas must be retired")
	actual.cancel_unit_renderer_preparation()
	actual_view.queue_free(); fresh_view.queue_free()
	await process_frame
	await process_frame
func _frame() -> void:
	if _native: await RenderingServer.frame_post_draw
	else: await process_frame
func _state(offset: Vector2i) -> Dictionary:
	var grid: Array = []
	for _row: int in range(9): grid.append(["floor","floor","floor","floor","floor","floor","floor","floor","floor"])
	var enemies: Array[Dictionary]
	var index: int = 1
	for type: String in ["crawler", "harrier", "frostglass_lancer"]:
		enemies.append({"id": index, "type": type, "pos": Vector2i(4, 4) + offset + Vector2i(-offset.y, offset.x) / 2 * (index - 2), "hp": 12, "max_hp": 12, "team": "enemy"})
		index += 1
	return {"grid": grid, "enemies": enemies, "player": {"pos": Vector2i(4, 4), "hp": 24, "max_hp": 24, "team": "player"}, "room_type": "combat", "room_element": "none", "moss": {}, "surfaces": {}, "terrain": [], "traps": [], "loot": [], "illusions": [], "npcs": []}
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _errors.append(message)
