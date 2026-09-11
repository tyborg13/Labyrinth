extends RefCounted

const Cutout = preload("res://scripts/tharokh_cutout/renderer.gd")
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
	var first: Dictionary = board.tharokh_animation_snapshot("enemy_1")
	var second: Dictionary = board.tharokh_animation_snapshot("enemy_2")
	expect.call(not first.is_empty() and not second.is_empty(), "Every living Tharokh gets a production cutout")
	if first.is_empty() or second.is_empty():
		board.queue_free()
		return
	expect.call((board.get("_tharokh_renderers") as Dictionary).size() == 2, "Other enemy types do not allocate Tharokh renderers")
	expect.call(first["texture_id"] != second["texture_id"], "Two Tharokhs have independent live textures and motion")
	var texture: Texture2D = board.call("_texture_for_unit", state["enemies"][0])
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for index: int in range(directions.size()):
		for clip: String in ["walk", "attack"]:
			_submit(board, state, {"tharokh_motion": {"enemy_1": {"clip": clip, "direction": directions[index], "phase": 0.42}}})
			var sample: Dictionary = board.tharokh_animation_snapshot("enemy_1")
			expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Tharokh action follows the correct board direction")
			expect.call(sample["texture_id"] == first["texture_id"] and sample["rig_count"] == 2, "All actions retain one texture and two loaded views")
			expect.call(board.tharokh_animation_snapshot("enemy_2")["clip"] == "idle", "Animating one Tharokh never animates a second actor")
			_submit(board, state, {})
			var idle: Dictionary = board.tharokh_animation_snapshot("enemy_1")
			expect.call(idle["clip"] == "idle" and idle["facing"] == "front" and idle["mirrored"], "Idle faces the player even when the preceding action points elsewhere")
	# Repositioning the player changes each observer independently, including
	# diagonal offsets whose closest isometric facing is unambiguous.
	var player_offsets: Array[Vector2i]
	player_offsets.assign([Vector2i(0, 3), Vector2i(3, 0), Vector2i(0, -3), Vector2i(-3, 0)])
	for index: int in range(player_offsets.size()):
		var repositioned: Dictionary = state.duplicate(true)
		repositioned["player"]["pos"] = Vector2i(3, 3) + player_offsets[index]
		_submit(board, repositioned, {})
		var sample: Dictionary = board.tharokh_animation_snapshot("enemy_1")
		expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Idle picks the nearest of four facings toward the player's current tile")
		_submit(board, repositioned, {"reduced_motion": true})
		sample = board.tharokh_animation_snapshot("enemy_1")
		expect.call(sample["clip"] == "rest" and sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Reduced-motion idle also turns toward the player")
	_submit(board, state, {"tharokh_motion": {"enemy_1": {"clip": "attack", "direction": Vector2i(0, -1), "phase": 1.0}}})
	var recovered: Dictionary = board.tharokh_animation_snapshot("enemy_1")
	expect.call(recovered["clip"] == "idle" and recovered["facing"] == "front" and recovered["mirrored"], "A completed attack immediately resumes player-facing idle")
	var renderer: Node = (board.get("_tharokh_renderers") as Dictionary)["enemy_1"]
	_verify_rigid_idle(renderer, expect)
	_verify_dragon_contacts(renderer, expect)
	renderer.call("present", {"clip": "walk", "phase": 2.25}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), 0.25), "Distance-driven walking wraps across complete cycles")
	for contact: float in [0.42, 0.38]:
		renderer.call("present", {"clip": "attack", "phase": contact, "contact": contact}, false)
		expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), 0.55), "Claw and Faultline reach the approved contact pose at their existing result boundary")
		renderer.call("present", {"clip": "attack", "phase": 1.0}, false)
		expect.call(renderer.call("snapshot")["clip"] == "idle", "Completed attacks restore idle during the result hold")
	expect.call(Cutout.attack_trail_phase(0.30) < 0.0 and is_equal_approx(Cutout.attack_trail_phase(0.42), 0.45) and Cutout.attack_trail_phase(0.90) < 0.0, "Melee trail stays absent during claw preparation and follows the contact beat")
	expect.call(Cutout.walk_cycle_distance() > 75.0 and Cutout.WALK_CYCLE_SECONDS >= 0.6, "The four-foot dragon travels a meaningful source distance with a deliberate cadence")
	_submit(board, state, {"tharokh_motion": {"enemy_1": {"clip": "walk", "direction": Vector2i(0, -1), "phase": 0.5}}, "reduced_motion": true})
	renderer.call("_process", 0.6)
	var still: Dictionary = renderer.call("snapshot")
	expect.call(still["clip"] == "rest" and still["facing"] == "rear" and float(still["phase"]) == 0.0, "Reduced motion retains the new art and facing without an animated pose")
	_submit(board, state, {"visible_enemy_ids": [2, 3]})
	expect.call(not bool(renderer.call("snapshot")["active"]), "Hidden Tharokhs stop idle work")
	_submit(board, state, {})
	var unit: Dictionary = state["enemies"][0].duplicate(true)
	unit["key"] = "enemy_1"
	unit["role"] = "enemy"
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", unit)
	expect.call(str(anchor.get_meta("asset_source_path", "")) == Cutout.REST_PATH, "Tharokh HUD and shadows use the baked new silhouette")
	expect.call((board.call("_unit_idle_frames", unit) as Array).is_empty(), "Legacy Tharokh idle sheets are not loaded")
	var logical: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2.ZERO)
	var padded: Rect2 = board.call("_unit_texture_draw_rect", unit, Vector2.ZERO)
	expect.call((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.position), "Padding preserves logical source registration")
	expect.call((padded.size * Cutout.SOURCE_SIZE / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.size), "Action canvas neither shrinks the body nor enlarges its HUD bounds")
	var echo: Dictionary = unit.duplicate(true)
	echo["key"] = "enemy_1_destination_preview"
	echo["role"] = "enemy_move_preview"
	expect.call(board.call("_texture_for_unit", echo) == texture, "Destination preview shares its Tharokh's new art")
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
		expect.call((dissolves["enemy_1"].call("source_rect") as Rect2).is_equal_approx(board.call("_unit_texture_draw_rect", dying, board.call("_unit_center", dying))), "Dissolve geometry respects the padded Tharokh canvas")
	else:
		expect.call(false, "The actual death presentation owns a dissolve effect")
	_submit(board, dead_state, {})
	await tree.process_frame
	expect.call(board.tharokh_animation_snapshot("enemy_1").is_empty() and (board.get("_tharokh_renderers") as Dictionary).size() == 1, "Removed Tharokhs release their viewport after death presentation")
	expect.call(board.tharokh_animation_snapshot("enemy_2")["texture_id"] == second["texture_id"], "Removing one actor preserves the other's renderer")
	var definition: Dictionary = GameData.enemy_def("tharokh")
	expect.call(int(definition["max_hp"]) == 64 and int(definition["base_initiative"]) == 15 and int(definition["reward_embers"]) == 80, "Production presentation preserves Tharokh combat data")
	expect.call(not Cutout.uses_attack({"kind": "ranged"}, {"type": "tharokh"}) and not Cutout.uses_attack({"kind": "melee"}, {"type": "crawler"}), "Routing excludes unrelated attacks and enemy types")
	expect.call(int(definition["footprint"][0]) == 2 and int(definition["footprint"][1]) == 2 and bool(definition["boss_bar"]), "The boss retains its 2x2 footprint and boss bar")
	expect.call(Cutout.action_clip({"kind": "status", "action_type": "raise_terrain"}, {"type": "tharokh"}) == "brace", "Stonewake/Aegis terrain raising selects a grounded brace")
	expect.call(Cutout.action_clip({"kind": "aoe", "action_type": "terrain_burst"}, {"type": "tharokh"}) == "faultline", "Faultline retains its terrain area family and stamp")
	expect.call(Cutout.action_clip({"kind": "stoneskin"}, {"type": "tharokh"}).is_empty(), "Non-attack armor gain keeps its normal status presentation")
	board.queue_free()
	await tree.process_frame

static func _submit(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)

static func fixture_state() -> Dictionary:
	var grid: Array = []
	for y: int in range(10):
		var row: Array = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 9 else "stone")
		grid.append(row)
	return {"grid": grid, "room_coord": Vector2i(4, 3), "terrain": [], "traps": [], "loot": [],
		"player": {"pos": Vector2i(6, 4), "hp": 24, "max_hp": 24},
		"enemies": [{"id": 1, "type": "tharokh", "pos": Vector2i(3, 3), "hp": 64, "max_hp": 64, "footprint": Vector2i(2, 2), "boss_bar": true},
			{"id": 2, "type": "tharokh", "pos": Vector2i(7, 7), "hp": 64, "max_hp": 64, "footprint": Vector2i(2, 2), "boss_bar": true},
			{"id": 3, "type": "crawler", "pos": Vector2i(8, 2), "hp": 9, "max_hp": 9}]}

static func _verify_rigid_idle(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig: Node2D = (renderer.get("rigs") as Dictionary)[facing]
		var layout: Dictionary = rig.get("layout")
		var rest: Dictionary = Cutout.Motion.sample_pose("rest", 0.0, layout, facing)
		var lowest: float = 0.0
		for index: int in range(25):
			var pose: Dictionary = Cutout.Motion.sample_pose("idle", float(index) / 24.0, layout, facing)
			var chest_offset: Vector2 = Cutout.Motion._world(pose, layout, "torso").origin - Cutout.Motion._world(rest, layout, "torso").origin
			lowest = minf(lowest, chest_offset.y)
			for name: String in layout["joints"]:
				var actual: Transform2D = Cutout.Motion._world(pose, layout, name)
				var neutral: Transform2D = Cutout.Motion._world(rest, layout, name)
				expect.call(actual.x.is_equal_approx(neutral.x) and actual.y.is_equal_approx(neutral.y), "Idle preserves every rigid bone basis without ripple: " + facing + "/" + name)
				var fixed: bool = name == "root" or name.begins_with("upper_") or name.begins_with("lower_") or name.begins_with("claw_") or name.begins_with("tail_")
				var expected_offset: Vector2 = Vector2.ZERO if fixed else chest_offset
				expect.call((actual.origin - neutral.origin).distance_to(expected_offset) < 0.0001, "Idle keeps legs planted while the complete upper body bobs together: " + facing + "/" + name)
		expect.call(is_equal_approx(lowest, -1.2), "Idle retains the accepted 1.2 source-pixel bob in " + facing)

static func _verify_dragon_contacts(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var layout: Dictionary = (renderer.get("rigs") as Dictionary)[facing].layout
		expect.call((layout["joints"] as Dictionary).size() == 20 and not layout["joints"].has("weapon_r"), "Tharokh owns a dragon graph without a humanoid weapon chain")
		for index: int in range(80):
			var phase: float = float(index) / 80.0
			var support_count: int = 0
			var walk: Dictionary = Cutout.Motion.sample_pose("walk", phase, layout, facing)
			for leg: String in Cutout.Motion.LEGS:
				var foot: String = "claw_" + leg
				var state: Dictionary = Cutout.Motion.walk_foot_state(phase, foot, layout, facing)
				support_count += 1 if bool(state["contact"]) else 0
				var transform: Transform2D = Cutout.Motion._world(walk, layout, foot)
				expect.call(transform.origin.distance_to(state["target"]) < 0.0001, "Projected dragon foot reaches its grounded/swing target")
				expect.call(absf(transform.x.length()-1.0) < 0.0001 and absf(transform.y.length()-1.0) < 0.0001 and absf(transform.x.dot(transform.y)) < 0.0001, "Crawl preserves rigid claw width and basis")
			expect.call(support_count >= 3, "The massive dragon always has at least three crawl contacts")
		for clip: String in ["claw", "brace", "faultline"]:
			for phase: float in [0.0, 0.32, 0.42, 0.55, 0.65, 1.0]:
				var pose: Dictionary = Cutout.Motion.sample_pose(clip, phase, layout, facing)
				for leg: String in Cutout.Motion.LEGS:
					if leg == "fore_near" and clip != "brace":
						continue
					var foot: String = "claw_" + leg
					expect.call(Cutout.Motion._world(pose, layout, foot).origin.distance_to(Cutout.Motion._point(layout, foot)) < 0.0001, "Attack weight shift preserves supporting claw contacts")
		var prepared: Dictionary = Cutout.Motion.sample_pose("claw", 0.32, layout, facing)
		var claw_bind: Vector2 = Cutout.Motion._point(layout, "claw_fore_near")
		expect.call(Cutout.Motion._world(prepared, layout, "claw_fore_near").origin.y < claw_bind.y - 24.0, "Worldspine Claw has a visible foreleg preparation")
		var stamp: Dictionary = Cutout.Motion.sample_pose("faultline", 0.55, layout, facing)
		expect.call(Cutout.Motion._world(stamp, layout, "claw_fore_near").origin.distance_to(claw_bind) < 0.0001, "Faultline stamps the actual ground at release")
