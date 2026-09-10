extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Cutout = preload("res://scripts/bile_bloomer_cutout/renderer.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	tree.root.add_child(board)
	var state: Dictionary = fixture_state()
	_submit(board, state, {})
	await tree.process_frame
	var first: Dictionary = board.bile_bloomer_animation_snapshot("enemy_1")
	var second: Dictionary = board.bile_bloomer_animation_snapshot("enemy_2")
	expect.call(first.get("art", "") == "bile_bloomer_cutout_v01" and first.get("rig_count", 0) == 2, "Production owns both registered Bloomer views")
	expect.call(int(first.get("texture_id", 0)) != 0 and first.get("texture_id") != second.get("texture_id"), "Multiple Bloomers own independent persistent textures")
	expect.call(not board.warden_animation_snapshot("enemy_3").is_empty(), "Warden registration remains live alongside the Bloomer")
	var renderer: Node = (board.get("_bile_bloomer_renderers") as Dictionary)["enemy_1"]
	var texture: Texture2D = renderer.call("texture")
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	for delta: Vector2i in directions:
		var moved: Dictionary = state.duplicate(true)
		moved["player"]["pos"] = Vector2i(3, 3) + delta * 2
		_submit(board, moved, {})
		var expected: Dictionary = Cutout.direction_for_delta(delta)
		var actual: Dictionary = board.bile_bloomer_animation_snapshot("enemy_1")
		expect.call(actual["facing"] == expected["facing"] and actual["mirrored"] == expected["mirrored"], "Idle chooses the completed player's nearest facing")
		_submit(board, moved, {"reduced_motion": true})
		actual = board.bile_bloomer_animation_snapshot("enemy_1")
		expect.call(actual["clip"] == "rest" and actual["facing"] == expected["facing"] and actual["mirrored"] == expected["mirrored"], "Reduced motion uses the same directional cutout still")
		for action: String in ["burst", "mark"]:
			_submit(board, state, {"bile_bloomer_motion": {"enemy_1": {"clip": "attack", "action": action, "direction": delta, "phase": 0.45}}})
			actual = board.bile_bloomer_animation_snapshot("enemy_1")
			expect.call(actual["clip"] == action and actual["facing"] == expected["facing"] and actual["mirrored"] == expected["mirrored"], "Distinct attack family keeps its resolved action facing")
			expect.call(renderer.call("texture") == texture, "The texture survives action and facing changes")
			_submit(board, state, {"bile_bloomer_motion": {"enemy_1": {"clip": "attack", "action": action, "direction": delta, "phase": 1.0}}})
			actual = board.bile_bloomer_animation_snapshot("enemy_1")
			expect.call(actual["clip"] == "idle" and actual["facing"] == "front" and actual["mirrored"], "Both completed attacks return to player-facing idle")
	_verify_idle_and_contacts(renderer, expect)
	var unit: Dictionary = state["enemies"][0].duplicate(true)
	unit.merge({"key": "enemy_1", "role": "enemy"}, true)
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", unit)
	expect.call(str(anchor.get_meta("asset_source_path", "")) == Cutout.REST_PATH, "HUD and static shadow use the registered rest bake")
	expect.call((board.call("_unit_idle_frames", unit) as Array).is_empty(), "No legacy whole-body idle sheet is loaded")
	var logical: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2.ZERO)
	var padded: Rect2 = board.call("_unit_texture_draw_rect", unit, Vector2.ZERO)
	expect.call((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.position), "Transparent canvas padding preserves logical body origin")
	expect.call((padded.size * Cutout.SOURCE_SIZE / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.size), "Canvas padding never shrinks art or grows HUD geometry")
	var echo: Dictionary = unit.duplicate(true)
	echo.merge({"key": "enemy_1_destination_preview", "role": "enemy_move_preview"}, true)
	expect.call(board.call("_texture_for_unit", echo) == texture, "Preview echo shares the actual actor texture")
	_submit(board, state, {"visible_enemy_ids": [2, 3]})
	expect.call(not bool(renderer.call("snapshot")["active"]), "Hidden Bloomer pauses idle updates")
	_submit(board, state, {})
	var frozen: Dictionary = renderer.call("snapshot")
	var dead: Dictionary = state.duplicate(true)
	dead["enemies"][0]["hp"] = 0
	dead["player"]["pos"] = Vector2i(3, 1)
	var dying: Dictionary = unit.duplicate(true)
	dying.merge({"death_animation": true, "death_progress": 0.45}, true)
	_submit(board, dead, {"death_animation_units": [dying]})
	var death: Dictionary = renderer.call("snapshot")
	expect.call(not death["active"] and death["facing"] == frozen["facing"] and death["mirrored"] == frozen["mirrored"], "Death freezes its cutout without turning toward a new player tile")
	expect.call(board.call("_enemy_shadow_dissolve_source_texture", dying) == texture, "Death dissolves the same persistent cutout")
	_submit(board, dead, {})
	await tree.process_frame
	expect.call(board.bile_bloomer_animation_snapshot("enemy_1").is_empty() and board.bile_bloomer_animation_snapshot("enemy_2")["texture_id"] == second["texture_id"], "Death removes only the defeated actor's renderer")
	var definition: Dictionary = GameData.enemy_def("bile_bloomer")
	expect.call(definition["name"] == "Shale Bloomer" and definition["max_hp"] == 14 and definition["base_initiative"] == 14 and definition["reward_embers"] == 12 and definition["element"] == "earth", "Stable enemy rules and mineral identity remain unchanged")
	expect.call(Cutout.uses_attack({"kind": "ranged"}, {"type": "bile_bloomer"}) and Cutout.uses_attack({"kind": "aoe", "range": 0}, {"type": "bile_bloomer"}), "Actual ranged and self-area families use this cutout")
	expect.call(not Cutout.uses_attack({"kind": "melee"}, {"type": "bile_bloomer"}) and not Cutout.uses_attack({"kind": "stoneskin"}, {"type": "bile_bloomer"}) and not Cutout.uses_attack({"kind": "ranged"}, {"type": "acolyte"}), "Routing excludes unsupported actions and unrelated enemies")
	board.queue_free()
	await tree.process_frame

static func _verify_idle_and_contacts(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig: Node2D = renderer.get("rigs")[facing]
		rig.call("apply_pose", "rest", 0.0)
		var neutral: Dictionary = {}
		for name: String in rig.bones:
			neutral[name] = (rig.bones[name] as Node2D).global_transform
		for index: int in range(25):
			rig.call("apply_pose", "idle", float(index) / 24.0)
			var offset: Vector2 = (rig.bones["trunk"] as Node2D).global_position - (neutral["trunk"] as Transform2D).origin
			for name: String in rig.bones:
				var actual: Transform2D = (rig.bones[name] as Node2D).global_transform
				var rest: Transform2D = neutral[name]
				expect.call(actual.x.is_equal_approx(rest.x) and actual.y.is_equal_approx(rest.y), "Idle preserves every painted basis without rippling")
				var fixed: bool = name == "root" or name in ["root_l", "root_c", "root_r"]
				expect.call((actual.origin - rest.origin).is_equal_approx(Vector2.ZERO if fixed else offset), "Idle fixes ground contacts and coordinates the whole upper body")
			if index == 12:
				expect.call(absf(offset.y + 1.2) < 0.001, "Restrained idle bob has its intended source-pixel amplitude within native transform precision")
		for index: int in range(72):
			var phase: float = float(index) / 72.0
			rig.call("apply_pose", "walk", phase)
			var support_count: int = 0
			for foot: String in ["root_l", "root_c", "root_r"]:
				var state: Dictionary = Cutout.Motion.walk_foot_state(phase, foot, rig.layout, facing)
				var transform: Transform2D = rig.global_transform.affine_inverse() * (rig.bones[foot] as Node2D).global_transform
				expect.call(transform.origin.distance_to(state["target"]) < 0.001 and transform.x.is_equal_approx(Vector2.RIGHT) and transform.y.is_equal_approx(Vector2.DOWN), "Moving roots reach their support targets with rigid terminal paint")
				support_count += 1 if state["contact"] else 0
			expect.call(support_count >= 2, "At least two root contacts support every locomotion phase")

static func _submit(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)

static func fixture_state() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {"grid": grid, "room_coord": Vector2i(4, 3), "terrain": [], "traps": [], "loot": [],
		"player": {"pos": Vector2i(4, 3), "hp": 40, "max_hp": 40},
		"enemies": [{"id": 1, "type": "bile_bloomer", "pos": Vector2i(3, 3), "hp": 14, "max_hp": 14},
			{"id": 2, "type": "bile_bloomer", "pos": Vector2i(5, 5), "hp": 14, "max_hp": 14},
			{"id": 3, "type": "warden", "pos": Vector2i(6, 6), "hp": 18, "max_hp": 18}]}
