extends RefCounted

## rr-39: real board routing and drawn, snapped rigid-sprite landmarks.
const Board = preload("res://scripts/combat_board_view.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const TYPE: String = "frostglass_lancer"
const BOARD_SIZE := Vector2(1920, 1080)
const SOCKET_TOLERANCE_PX: float = 2.0
const PROOF_TILE := Vector2i(3, 3)
const PROOF_TRAIL_WINDOW := Vector2(0.2, 0.8)
const PROOF_EFFECT_CONTACT: float = 0.42
const PROOF_FALLBACK := Vector2(12, 34)

static func measure(board: Control, renderer: Node, effect: Dictionary) -> Dictionary:
	var actor: Dictionary = Action.actor_for(board.combat_state, "enemy_1").duplicate(false)
	actor["key"] = "enemy_1"
	var rig: Node2D = renderer.rigs[renderer.facing]
	var part: Dictionary
	for row: Dictionary in rig.layout["parts"]:
		if row["name"] == "spear": part = row
	var sprite: Sprite2D = rig.bones[part["bone"]].get_node("spear")
	var native_tip: Vector2 = sprite.global_transform * (Action.Motion.point(rig.layout["strike_points"]["spear"]) - Action.Motion.point(part["offset"]))
	var rect: Rect2 = board._unit_texture_draw_rect(actor, board._unit_center(actor))
	var drawn: Vector2 = rect.position + rect.size * native_tip / Vector2(renderer.canvas_geometry()["size"])
	var socket: Vector2 = board._cutout_launch_point(effect, Vector2.INF)
	return {"socket": [socket.x, socket.y], "drawn_tip": [drawn.x, drawn.y], "board_delta_px": socket.distance_to(drawn)}

static func run(tree: SceneTree, check: Callable) -> void:
	var board := Board.new()
	board.size = BOARD_SIZE
	tree.root.add_child(board)
	var actors: Array[Dictionary]
	actors.assign([Fixtures.enemy(TYPE, 1, PROOF_TILE, "spear_cast")])
	var state: Dictionary = Fixtures.state(actors, Vector2i(4, 3))
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	var jobs: Array[Dictionary] = board.begin_unit_renderer_preparation(state)
	check.call(jobs.size() == 1, "v2 actor prepares exactly one canvas")
	for job: Dictionary in jobs: board.prepare_unit_renderer(job, false)
	var prepared: Node = board._prepared_unit_renderers[jobs[0]["key"]]
	check.call(prepared.get_script() == preload("res://assets/units/frostglass_lancer_cutout/renderer.gd"), "v2 actor never prepares a legacy canvas")
	for delta: Vector2i in directions:
		for pair: Array in [["cast", "spear_cast", "ranged"], ["pin", "frost_pin", "ranged"], ["jab", "spear_advance", "melee"], ["lunge", "glass_lunge", "aoe"]]:
			var clip: String = pair[0]
			var contact: float = Action.data_for(TYPE)["clips"][clip]["contact"]
			var effect: Dictionary = {"kind": pair[2], "intent_id": pair[1], "actor_key": "enemy_1", "from": PROOF_TILE, "to": PROOF_TILE + delta}
			board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {TYPE+"_motion": {"enemy_1": {"clip": clip, "phase": contact, "direction": delta}}})
			var renderer: Node = board.unit_cutout_renderer(actors[0])
			check.call(renderer == prepared, "normal roster adopts the prepared v2 canvas")
			var count: int = 0
			for child: Node in board.get_children():
				if child.has_method("snapshot") and str(child.call("snapshot").get("art", "")) == TYPE+"_maquette": count += 1
			check.call(count == 1, "one renderer per actor: " + clip + str(delta))
			var measured: Dictionary = measure(board, renderer, effect)
			check.call(float(measured["board_delta_px"]) <= SOCKET_TOLERANCE_PX, "socket matches painted tip: " + clip + str(delta) + str(measured))
			var before: Dictionary = renderer.snapshot()
			var node_state: Array[Dictionary] = preload("res://scripts/maquette_cutout_runtime/strike_points.gd").save_nodes(renderer.rigs[renderer.facing])
			var samples: Array[Dictionary] = renderer.strike_samples(actors[0], effect, delta, {"window": PROOF_TRAIL_WINDOW}, PROOF_EFFECT_CONTACT)
			var sample: Dictionary = samples.filter(func(row: Dictionary) -> bool: return is_equal_approx(row["progress"], PROOF_EFFECT_CONTACT))[0]
			var body: Rect2 = board._unit_draw_rect({"type": TYPE, "id": 1, "key": "enemy_1", "pos": PROOF_TILE})
			var trail: Vector2 = body.position + body.size * sample["tip"] / renderer.SOURCE_SIZE
			check.call(trail.distance_to(Vector2(measured["socket"][0], measured["socket"][1])) <= SOCKET_TOLERANCE_PX, "trail uses painted contact: " + clip + str(delta))
			check.call(preload("res://scripts/maquette_cutout_runtime/strike_points.gd").save_nodes(renderer.rigs[renderer.facing]) == node_state, "trail preserves exact painted transforms/textures: " + clip)
			check.call(renderer.snapshot() == before, "trail sampling preserves live pose: " + clip)
			var fallback: Vector2 = PROOF_FALLBACK
			check.call(board._cutout_launch_point(effect.merged({"preview": true}), fallback) == fallback, "preview retains origin")
			check.call(board._cutout_launch_point(effect.merged({"umbra_action_clipped": true}), fallback) == fallback, "clipped action retains origin")
	board.queue_free()
	await tree.process_frame
