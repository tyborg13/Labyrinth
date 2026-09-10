extends RefCounted

const Cutout = preload("res://scripts/harrier_cutout/renderer.gd")
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
	var first: Dictionary = board.harrier_animation_snapshot("enemy_1")
	var second: Dictionary = board.harrier_animation_snapshot("enemy_2")
	expect.call(not first.is_empty() and not second.is_empty(), "Every living Harrier gets a production cutout")
	if first.is_empty() or second.is_empty():
		board.queue_free()
		return
	expect.call((board.get("_harrier_renderers") as Dictionary).size() == 2, "Other enemy types do not allocate Harrier renderers")
	expect.call(first["texture_id"] != second["texture_id"], "Two Harriers have independent live textures and motion")
	var texture: Texture2D = board.call("_texture_for_unit", state["enemies"][0])
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for index: int in range(directions.size()):
		for clip: String in ["walk", "attack"]:
			_submit(board, state, {"harrier_motion": {"enemy_1": {"clip": clip, "direction": directions[index], "phase": 0.42}}})
			var sample: Dictionary = board.harrier_animation_snapshot("enemy_1")
			expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Harrier action follows the correct board direction")
			expect.call(sample["texture_id"] == first["texture_id"] and sample["rig_count"] == 2, "All actions retain one texture and two loaded views")
			expect.call(board.harrier_animation_snapshot("enemy_2")["clip"] == "idle", "Animating one Harrier never animates a second actor")
			_submit(board, state, {})
			var idle: Dictionary = board.harrier_animation_snapshot("enemy_1")
			expect.call(idle["clip"] == "idle" and idle["facing"] == "front" and idle["mirrored"], "Idle faces the player even when the preceding action points elsewhere")
	# Repositioning the player changes each observer independently, including
	# diagonal offsets whose closest isometric facing is unambiguous.
	var player_offsets: Array[Vector2i]
	player_offsets.assign([Vector2i(1, 2), Vector2i(2, 1), Vector2i(1, -2), Vector2i(-2, 1)])
	for index: int in range(player_offsets.size()):
		var repositioned: Dictionary = state.duplicate(true)
		repositioned["player"]["pos"] = Vector2i(3, 3) + player_offsets[index]
		_submit(board, repositioned, {})
		var sample: Dictionary = board.harrier_animation_snapshot("enemy_1")
		expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Idle picks the nearest of four facings toward the player's current tile")
		_submit(board, repositioned, {"reduced_motion": true})
		sample = board.harrier_animation_snapshot("enemy_1")
		expect.call(sample["clip"] == "rest" and sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Reduced-motion idle also turns toward the player")
	_submit(board, state, {"harrier_motion": {"enemy_1": {"clip": "attack", "direction": Vector2i(0, -1), "phase": 1.0}}})
	var recovered: Dictionary = board.harrier_animation_snapshot("enemy_1")
	expect.call(recovered["clip"] == "idle" and recovered["facing"] == "front" and recovered["mirrored"], "A completed attack immediately resumes player-facing idle")
	var renderer: Node = (board.get("_harrier_renderers") as Dictionary)["enemy_1"]
	_verify_rigid_idle(renderer, expect)
	renderer.call("present", {"clip": "walk", "phase": 2.25}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), 0.25), "Distance-driven walking wraps across complete cycles")
	renderer.call("present", {"clip":"attack","phase":0.42,"contact":0.42}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]),0.55),"Rush thrust lands at the existing melee feedback boundary")
	var actions = preload("res://scripts/harrier_cutout/action.gd")
	for element: String in ["none","fire","earth","air","lightning","ice"]:
		var effect: Dictionary = {"kind":"ranged","element":element,"from":Vector2i(3,3),"to":Vector2i(3,5)}
		var fx = preload("res://scripts/attack_fx_library.gd")
		var release: float = 0.18 if element == "none" else fx.anticipation_end_progress(fx.style_for_effect(effect))
		var motion: Dictionary = actions.motion_for_effect(effect,release)
		expect.call(is_equal_approx(float(motion["phase"]),0.55),"Each ranged style reaches forward casting pose at its own unchanged projectile release")
		renderer.call("present",motion,false)
		expect.call(renderer.call("snapshot")["clip"] == "cast","Ranged actions select casting, not the melee thrust")
		renderer.call("present",actions.motion_for_effect(effect,1.0),false)
		expect.call(renderer.call("snapshot")["clip"] == "idle","Ranged recovery returns to idle")
	renderer.call("present",{"clip":"walk","travel_variant":"retreat","phase":0.3},false)
	expect.call(renderer.call("snapshot")["clip"] == "retreat","Retreat Step selects guarded withdrawal")
	expect.call(Cutout.attack_trail_phase(0.20)<0 and Cutout.attack_trail_phase(0.42)>0 and Cutout.attack_trail_phase(0.9)<0,"Spear trail only accompanies the forward contact beat")
	_submit(board, state, {"harrier_motion": {"enemy_1": {"clip": "walk", "direction": Vector2i(0, -1), "phase": 0.5}}, "reduced_motion": true})
	renderer.call("_process", 0.6)
	var still: Dictionary = renderer.call("snapshot")
	expect.call(still["clip"] == "rest" and still["facing"] == "rear" and float(still["phase"]) == 0.0, "Reduced motion retains the new art and facing without an animated pose")
	_submit(board, state, {"visible_enemy_ids": [2, 3]})
	expect.call(not bool(renderer.call("snapshot")["active"]), "Hidden Harriers stop idle work")
	_submit(board, state, {})
	var unit: Dictionary = state["enemies"][0].duplicate(true)
	unit["key"] = "enemy_1"
	unit["role"] = "enemy"
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", unit)
	expect.call(str(anchor.get_meta("asset_source_path", "")) == Cutout.REST_PATH, "Harrier HUD and shadows use the baked new silhouette")
	expect.call((board.call("_unit_idle_frames", unit) as Array).is_empty(), "Legacy Harrier idle sheets are not loaded")
	var logical: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2.ZERO)
	var padded: Rect2 = board.call("_unit_texture_draw_rect", unit, Vector2.ZERO)
	expect.call((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.position), "Padding preserves logical source registration")
	expect.call((padded.size * Cutout.SOURCE_SIZE / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.size), "Action canvas neither shrinks the body nor enlarges its HUD bounds")
	var echo: Dictionary = unit.duplicate(true)
	echo["key"] = "enemy_1_destination_preview"
	echo["role"] = "enemy_move_preview"
	expect.call(board.call("_texture_for_unit", echo) == texture, "Destination preview shares its Harrier's new art")
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
		expect.call((dissolves["enemy_1"].call("source_rect") as Rect2).is_equal_approx(board.call("_unit_texture_draw_rect", dying, board.call("_unit_center", dying))), "Dissolve geometry respects the padded Harrier canvas")
	else:
		expect.call(false, "The actual death presentation owns a dissolve effect")
	_submit(board, dead_state, {})
	await tree.process_frame
	expect.call(board.harrier_animation_snapshot("enemy_1").is_empty() and (board.get("_harrier_renderers") as Dictionary).size() == 1, "Removed Harriers release their viewport after death presentation")
	expect.call(board.harrier_animation_snapshot("enemy_2")["texture_id"] == second["texture_id"], "Removing one actor preserves the other's renderer")
	var definition: Dictionary = GameData.enemy_def("harrier")
	expect.call(int(definition["max_hp"]) == 10 and int(definition["base_initiative"]) == 9 and int(definition["reward_embers"]) == 9, "Production presentation preserves Harrier combat data")
	expect.call(Cutout.uses_attack({"kind": "ranged"}, {"type": "harrier"}) and not Cutout.uses_attack({"kind":"aoe"},{"type":"harrier"}) and not Cutout.uses_attack({"kind": "melee"}, {"type": "crawler"}), "Routing excludes unrelated attacks and enemy types")
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
		"enemies": [{"id": 1, "type": "harrier", "pos": Vector2i(3, 3), "hp": 10, "max_hp": 10},
			{"id": 2, "type": "harrier", "pos": Vector2i(5, 5), "hp": 10, "max_hp": 10},
			{"id": 3, "type": "crawler", "pos": Vector2i(6, 6), "hp": 9, "max_hp": 9}]}

static func _verify_rigid_idle(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig: Node2D = (renderer.get("rigs") as Dictionary)[facing]
		var layout: Dictionary = rig.get("layout")
		var rest: Dictionary = Cutout.Motion.sample_pose("rest", 0.0, layout, facing)
		var registration: Vector2 = Cutout.Motion.registration_offset(layout)
		var ground_midpoint: Vector2 = (Cutout.Motion._sole(layout, "foot_r") + Cutout.Motion._sole(layout, "foot_l")) * 0.5 + registration
		expect.call(ground_midpoint.is_equal_approx(Vector2(127.5, 209.5)), "All painted views use one ground anchor at the horizontal reflection pivot")
		for phase: float in [0.0, 0.1, 0.4, 0.65, 0.85]:
			var walk: Dictionary = Cutout.Motion.sample_pose("walk", phase, layout, facing)
			for foot: String in ["foot_r", "foot_l"]:
				var support: Dictionary = Cutout.Motion.walk_foot_state(phase, foot, layout, facing)
				expect.call(Cutout.Motion._world(walk, layout, foot).origin.is_equal_approx(support["target"]), "Registered walking preserves each solved foot target")
		var lowest: float = 0.0
		for index: int in range(25):
			var pose: Dictionary = Cutout.Motion.sample_pose("idle", float(index) / 24.0, layout, facing)
			var chest_offset: Vector2 = Cutout.Motion._world(pose, layout, "torso").origin - Cutout.Motion._world(rest, layout, "torso").origin
			lowest = minf(lowest, chest_offset.y)
			for name: String in layout["joints"]:
				var actual: Transform2D = Cutout.Motion._world(pose, layout, name)
				var neutral: Transform2D = Cutout.Motion._world(rest, layout, name)
				expect.call(actual.x.is_equal_approx(neutral.x) and actual.y.is_equal_approx(neutral.y), "Idle preserves every rigid bone basis without ripple: " + facing + "/" + name)
				var fixed: bool = name == "root" or name.begins_with("thigh_") or name.begins_with("shin_") or name.begins_with("foot_")
				var expected_offset: Vector2 = Vector2.ZERO if fixed else chest_offset
				expect.call((actual.origin - neutral.origin).is_equal_approx(expected_offset), "Idle keeps legs planted while the complete upper body bobs together: " + facing + "/" + name)
		expect.call(is_equal_approx(lowest, -1.15), "Idle retains the accepted 1.15 source-pixel bob in " + facing)
