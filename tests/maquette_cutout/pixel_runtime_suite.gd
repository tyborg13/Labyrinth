extends RefCounted

const Pixels = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")
const Samples = preload("pixel_samples.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixtures = preload("runtime_suite.gd")
const FPS: float = 60.0
const EPSILON: float = 0.0001

static func run(tree: SceneTree, expect: Callable, type: String) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	tree.root.add_child(board)
	await tree.process_frame
	var fixture: Dictionary = Fixtures.fixture(type)
	board.set_combat_state(fixture, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var unit: Dictionary = fixture["enemies"][0].duplicate(false)
	unit["key"] = "enemy_1"
	var renderer: Node = board.unit_cutout_renderer(unit)
	renderer.set_process(false)
	renderer.seed_idle_phase(0.0)
	renderer.present({"clip": "idle"}, false)
	var rig: Node2D = renderer.rigs[renderer.facing]
	var anchors: Dictionary = Pixels.shared_anchors(rig.layout)
	var previous: Dictionary = {}
	var count: int = roundi(float(renderer.motion_data()["clips"]["idle"]["seconds"]) * FPS)
	for frame: int in range(count):
		var parts: Dictionary = Samples.parts_for(rig)
		if frame % 6 != 0: expect.call(parts == previous, type + ": complete idle pose held for six 60 Hz frames")
		for part: Dictionary in rig.layout["parts"]:
			var name: String = part["name"]
			var values: Array = parts[name]["transform"]
			var anchor: Dictionary = anchors.get(part["bone"], part)
			var anchor_values: Array = parts[anchor["name"]]["transform"]
			var origin := Vector2(anchor_values[4], anchor_values[5])
			var reference: Array = anchor.get("presentation_anchor", anchor["offset"])
			var reference_delta := Vector2(float(reference[0]) - float(anchor["offset"][0]), float(reference[1]) - float(anchor["offset"][1]))
			origin += Vector2(anchor_values[0], anchor_values[1]) * reference_delta.x + Vector2(anchor_values[2], anchor_values[3]) * reference_delta.y
			var angle: float = atan2(float(values[1]), float(values[0]))
			expect.call(origin.distance_to(origin.round()) < EPSILON, type + ": owner source-pixel translation " + name)
			expect.call(absf(angle - snappedf(angle, Pixels.ROTATION_STEP)) < EPSILON, type + ": 1.5 degree rotation " + name)
			if anchors.has(part["bone"]):
				var owner_transform := Transform2D(Vector2(anchor_values[0], anchor_values[1]), Vector2(anchor_values[2], anchor_values[3]), origin)
				var relative := Vector2(float(part["offset"][0]) - float(reference[0]), float(part["offset"][1]) - float(reference[1]))
				expect.call((owner_transform * relative).distance_to(Vector2(values[4], values[5])) < EPSILON, type + ": painted detail shares owner transform " + name)
		previous = parts
		renderer._process(1.0 / FPS)
	expect.call(absf(renderer.snapshot()["presented_phase"]) < EPSILON, type + ": deterministic loop wrap")
	for direction: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		board.set_combat_state(fixture, [], [], Vector2i(-1, -1), "", "", {}, {}, {type + "_motion": {"enemy_1": {"clip": "move", "phase": 0.37, "direction": direction, "step_distance_px": 96.0}}})
		var rect: Rect2 = board._unit_texture_draw_rect(unit, board._unit_center(unit))
		expect.call(rect.position.distance_to(rect.position.round()) < EPSILON, type + ": board canvas uses integer origin in each facing")
		expect.call(is_equal_approx(renderer.snapshot()["phase"], 0.37), type + ": move retains full-rate action phase")
	var synthetic: Dictionary = {"clips": {"another_loop": {"seconds": 1.0, "loop": true}, "move": {"seconds": 1.0, "loop": false}}}
	expect.call(is_equal_approx(Pixels.phase_for(synthetic, "another_loop", 0.149), 0.1), type + ": all declared looping clips use step clock")
	expect.call(is_equal_approx(Pixels.phase_for(synthetic, "move", 0.149), 0.149), type + ": non-looping actions preserve clock")
	board.queue_free()
	await tree.process_frame
