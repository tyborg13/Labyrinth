extends RefCounted

const Cutout = preload("res://scripts/lightning_wisp_cutout/renderer.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const PlayerCutout = preload("res://scripts/protagonist_cutout/renderer.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	tree.root.add_child(board)
	await tree.process_frame
	var state: Dictionary = fixture_state()
	_submit(board, state, {})
	await tree.process_frame
	var first: Dictionary = board.lightning_wisp_animation_snapshot("enemy_1")
	var second: Dictionary = board.lightning_wisp_animation_snapshot("enemy_2")
	expect.call(not first.is_empty() and not second.is_empty(), "Every living Lightning Wisp gets a production cutout")
	if first.is_empty() or second.is_empty():
		board.queue_free()
		return
	expect.call((board.get("_lightning_wisp_renderers") as Dictionary).size() == 2, "Other enemy types do not allocate Lightning Wisp renderers")
	expect.call(first["texture_id"] != second["texture_id"], "Two Wisps have independent live textures and motion")
	var texture: Texture2D = board.call("_texture_for_unit", state["enemies"][0])
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for index: int in range(directions.size()):
		for clip: String in ["walk", "attack"]:
			_submit(board, state, {"lightning_wisp_motion": {"enemy_1": {"clip": clip, "direction": directions[index], "phase": 0.42}}})
			var sample: Dictionary = board.lightning_wisp_animation_snapshot("enemy_1")
			expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Lightning Wisp action follows the correct board direction")
			expect.call(sample["texture_id"] == first["texture_id"] and sample["rig_count"] == 2, "All actions retain one texture and two loaded views")
			expect.call(board.lightning_wisp_animation_snapshot("enemy_2")["clip"] == "idle", "Animating one Lightning Wisp never animates a second actor")
			_submit(board, state, {})
			var idle: Dictionary = board.lightning_wisp_animation_snapshot("enemy_1")
			expect.call(idle["clip"] == "idle" and idle["facing"] == "front" and idle["mirrored"], "Idle faces the player even when the preceding action points elsewhere")
	# Repositioning the player changes each observer independently, including
	# diagonal offsets whose closest isometric facing is unambiguous.
	var player_offsets: Array[Vector2i]
	player_offsets.assign([Vector2i(1, 2), Vector2i(2, 1), Vector2i(1, -2), Vector2i(-2, 1)])
	for index: int in range(player_offsets.size()):
		var repositioned: Dictionary = state.duplicate(true)
		repositioned["player"]["pos"] = Vector2i(3, 3) + player_offsets[index]
		_submit(board, repositioned, {})
		var sample: Dictionary = board.lightning_wisp_animation_snapshot("enemy_1")
		expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Idle picks the nearest of four facings toward the player's current tile")
		_submit(board, repositioned, {"reduced_motion": true})
		sample = board.lightning_wisp_animation_snapshot("enemy_1")
		expect.call(sample["clip"] == "rest" and sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Reduced-motion idle also turns toward the player")
	_submit(board, state, {"lightning_wisp_motion": {"enemy_1": {"clip": "attack", "direction": Vector2i(0, -1), "phase": 1.0}}})
	var recovered: Dictionary = board.lightning_wisp_animation_snapshot("enemy_1")
	expect.call(recovered["clip"] == "idle" and recovered["facing"] == "front" and recovered["mirrored"], "A completed attack immediately resumes player-facing idle")
	var renderer: Node = (board.get("_lightning_wisp_renderers") as Dictionary)["enemy_1"]
	_verify_rigid_idle(renderer, expect)
	renderer.call("present", {"clip": "walk", "phase": 2.25}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), 0.25), "Distance-driven walking wraps across complete cycles")
	renderer.call("present", {"clip": "attack", "phase": .42}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), .42), "Spark Dart reaches directed contact at the unchanged melee boundary")
	renderer.call("present", {"clip": "attack", "action": "cast", "phase": 4.0 / 30.0}, false)
	expect.call(renderer.call("snapshot")["clip"] == "cast" and is_equal_approx(float(renderer.call("snapshot")["phase"]), .5), "Electrical release coincides with the existing projectile release")
	renderer.call("present", {"clip": "attack", "action": "cast", "phase": 0.0, "authored_phase": .36}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), .36), "Distinct preparation reaches the fully gathered pose before effects")
	renderer.call("present", {"clip": "attack", "action": "cast", "phase": 1.0}, false)
	expect.call(renderer.call("snapshot")["clip"] == "idle", "Ranged recovery restores idle with the persistent texture")
	expect.call(Cutout.walk_segment_frames(Cutout.walk_cycle_distance()) == 29, "Flight duration follows actual distance at its declared cadence")
	_submit(board, state, {"lightning_wisp_motion": {"enemy_1": {"clip": "walk", "direction": Vector2i(0, -1), "phase": 0.5}}, "reduced_motion": true})
	renderer.call("_process", 0.6)
	var still: Dictionary = renderer.call("snapshot")
	expect.call(still["clip"] == "rest" and still["facing"] == "rear" and float(still["phase"]) == 0.0, "Reduced motion retains the new art and facing without an animated pose")
	_submit(board, state, {"visible_enemy_ids": [2, 3]})
	expect.call(not bool(renderer.call("snapshot")["active"]), "Hidden Wisps stop idle work")
	_submit(board, state, {})
	var unit: Dictionary = state["enemies"][0].duplicate(true)
	unit["key"] = "enemy_1"
	unit["role"] = "enemy"
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", unit)
	expect.call(str(anchor.get_meta("asset_source_path", "")) == Cutout.REST_PATH, "Lightning Wisp HUD and shadows use the baked new silhouette")
	expect.call((board.call("_unit_idle_frames", unit) as Array).is_empty(), "Legacy Lightning Wisp idle sheets are not loaded")
	var logical: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2.ZERO)
	var padded: Rect2 = board.call("_unit_texture_draw_rect", unit, Vector2.ZERO)
	expect.call((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.position), "Padding preserves logical source registration")
	expect.call((padded.size * Cutout.SOURCE_SIZE / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.size), "Action canvas neither shrinks the body nor enlarges its HUD bounds")
	var echo: Dictionary = unit.duplicate(true)
	echo["key"] = "enemy_1_destination_preview"
	echo["role"] = "enemy_move_preview"
	expect.call(board.call("_texture_for_unit", echo) == texture, "Destination preview shares its Lightning Wisp's new art")
	var dead_state: Dictionary = state.duplicate(true)
	dead_state["enemies"][0]["hp"] = 0
	var dying: Dictionary = unit.duplicate(true)
	dying.merge({"death_animation": true, "death_progress": 0.45}, true)
	var frozen: Dictionary = renderer.call("snapshot")
	dead_state["player"]["pos"] = Vector2i(3, 1)
	_submit(board, dead_state, {"death_animation_units": [dying]})
	var death_pose: Dictionary = renderer.call("snapshot")
	expect.call(death_pose["facing"] == frozen["facing"] and death_pose["mirrored"] == frozen["mirrored"], "A death pose stays frozen even if the player's new position would change idle facing")
	expect.call(board.call("_enemy_shadow_dissolve_source_texture", dying) == texture, "Death dissolves the same live cutout instead of switching art")
	expect.call(not bool(renderer.call("snapshot")["active"]), "Death freezes the pose while the existing dissolve runs")
	var dissolves: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key")
	if dissolves.has("enemy_1"):
		expect.call((dissolves["enemy_1"].call("source_rect") as Rect2).is_equal_approx(board.call("_unit_texture_draw_rect", dying, board.call("_unit_center", dying))), "Dissolve geometry respects the padded Lightning Wisp canvas")
	else:
		expect.call(false, "The actual death presentation owns a dissolve effect")
	_submit(board, dead_state, {})
	await tree.process_frame
	expect.call(board.lightning_wisp_animation_snapshot("enemy_1").is_empty() and (board.get("_lightning_wisp_renderers") as Dictionary).size() == 1, "Removed Wisps release their viewport after death presentation")
	expect.call(board.lightning_wisp_animation_snapshot("enemy_2")["texture_id"] == second["texture_id"], "Removing one actor preserves the other's renderer")
	var definition: Dictionary = GameData.enemy_def("lightning_wisp")
	expect.call(int(definition["max_hp"]) == 6 and int(definition["base_initiative"]) == 7 and int(definition["reward_embers"]) == 0, "Production presentation preserves Lightning Wisp combat data")
	expect.call(Cutout.uses_attack({"kind": "ranged"}, {"type": "lightning_wisp"}) and not Cutout.uses_attack({"kind": "surface"}, {"type": "lightning_wisp"}) and not Cutout.uses_attack({"kind": "melee"}, {"type": "crawler"}), "Routing excludes unrelated attacks and enemy types")
	board.queue_free()
	await tree.process_frame

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
		"player": {"pos": Vector2i(4, 3), "hp": 24, "max_hp": 24},
		"enemies": [{"id": 1, "type": "lightning_wisp", "pos": Vector2i(3, 3), "hp": 6, "max_hp": 6},
			{"id": 2, "type": "lightning_wisp", "pos": Vector2i(5, 5), "hp": 6, "max_hp": 6},
			{"id": 3, "type": "crawler", "pos": Vector2i(6, 6), "hp": 9, "max_hp": 9}]}

static func _verify_rigid_idle(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig: Node2D = (renderer.get("rigs") as Dictionary)[facing]
		rig.call("apply_pose", "rest", 0.0)
		var rest: Dictionary = {}
		for name: String in rig.bones:
			rest[name] = (rig.bones[name] as Node2D).global_transform
		var lowest: float = 0.0
		for index: int in range(25):
			rig.call("apply_pose", "idle", float(index) / 24.0)
			var core_offset: Vector2 = (rig.bones["core"] as Node2D).global_position - (rest["core"] as Transform2D).origin
			lowest = minf(lowest, core_offset.y)
			for name: String in rig.bones:
				var actual: Transform2D = (rig.bones[name] as Node2D).global_transform
				var neutral: Transform2D = rest[name]
				expect.call(actual.x.is_equal_approx(neutral.x) and actual.y.is_equal_approx(neutral.y), "Hover preserves every bone basis without surface ripple: " + facing + "/" + name)
				var offset: Vector2 = Vector2.ZERO if name == "root" else core_offset
				expect.call((actual.origin - neutral.origin).distance_to(offset) < .0001, "The complete electrical envelope hovers as one body: " + facing + "/" + name)
		expect.call(absf(lowest + 2.4) < .0001, "The coherent hover has 2.4 source-pixel amplitude")
		rig.call("apply_pose", "attack", .42)
		var offset: Vector2 = (rig.bones["core"] as Node2D).position - Cutout.Motion._bind(rig.layout, "core")
		var expected := Vector2(-18, 9) if facing == "front" else Vector2(18, -9)
		expect.call(offset.is_equal_approx(expected), "Dart contact moves along the painted 2:1 target-facing lane")
