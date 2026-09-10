extends RefCounted

const Cutout = preload("res://scripts/cinder_ooze_cutout/renderer.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const ActionFx = preload("res://scripts/cinder_ooze_cutout/action_fx.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	tree.root.add_child(board)
	await tree.process_frame
	var state: Dictionary = fixture_state()
	_submit(board, state, {})
	await tree.process_frame
	var first: Dictionary = board.cinder_ooze_animation_snapshot("enemy_1")
	var second: Dictionary = board.cinder_ooze_animation_snapshot("enemy_2")
	expect.call(not first.is_empty() and not second.is_empty(), "Every living Cinder Ooze gets a production cutout")
	if first.is_empty() or second.is_empty():
		board.queue_free()
		return
	expect.call((board.get("_cinder_ooze_renderers") as Dictionary).size() == 2, "Other enemy types do not allocate Cinder Ooze renderers")
	expect.call(first["texture_id"] != second["texture_id"], "Two Cinder Oozes have independent live textures and motion")
	var texture: Texture2D = board.call("_texture_for_unit", state["enemies"][0])
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for index: int in range(directions.size()):
		for clip: String in ["walk", "attack", "bloom"]:
			_submit(board, state, {"cinder_ooze_motion": {"enemy_1": {"clip": "attack" if clip == "bloom" else clip, "action": clip, "direction": directions[index], "phase": 0.42}}})
			var sample: Dictionary = board.cinder_ooze_animation_snapshot("enemy_1")
			expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Cinder Ooze action follows the correct board direction")
			expect.call(sample["texture_id"] == first["texture_id"] and sample["rig_count"] == 2, "All actions retain one texture and two loaded views")
			expect.call(board.cinder_ooze_animation_snapshot("enemy_2")["clip"] == "idle", "Animating one Cinder Ooze never animates a second actor")
			_submit(board, state, {})
			var idle: Dictionary = board.cinder_ooze_animation_snapshot("enemy_1")
			expect.call(idle["clip"] == "idle" and idle["facing"] == "front" and idle["mirrored"], "Idle faces the player even when the preceding action points elsewhere")
	# Repositioning the player changes each observer independently, including
	# diagonal offsets whose closest isometric facing is unambiguous.
	var player_offsets: Array[Vector2i]
	player_offsets.assign([Vector2i(1, 2), Vector2i(2, 1), Vector2i(1, -2), Vector2i(-2, 1)])
	for index: int in range(player_offsets.size()):
		var repositioned: Dictionary = state.duplicate(true)
		repositioned["player"]["pos"] = Vector2i(3, 3) + player_offsets[index]
		_submit(board, repositioned, {})
		var sample: Dictionary = board.cinder_ooze_animation_snapshot("enemy_1")
		expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Idle picks the nearest of four facings toward the player's current tile")
		_submit(board, repositioned, {"reduced_motion": true})
		sample = board.cinder_ooze_animation_snapshot("enemy_1")
		expect.call(sample["clip"] == "rest" and sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Reduced-motion idle also turns toward the player")
	_submit(board, state, {"cinder_ooze_motion": {"enemy_1": {"clip": "attack", "direction": Vector2i(0, -1), "phase": 1.0}}})
	var recovered: Dictionary = board.cinder_ooze_animation_snapshot("enemy_1")
	expect.call(recovered["clip"] == "idle" and recovered["facing"] == "front" and recovered["mirrored"], "A completed attack immediately resumes player-facing idle")
	var renderer: Node = (board.get("_cinder_ooze_renderers") as Dictionary)["enemy_1"]
	_verify_rigid_idle(renderer, expect)
	renderer.call("present", {"clip": "walk", "phase": 2.25}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), 0.25), "Distance-driven walking wraps across complete cycles")
	for action: String in ["attack", "bloom"]:
		var contact: float = 0.38 if action == "bloom" else 0.42
		renderer.call("present", {"clip": "attack", "action": action, "phase": contact, "contact": contact}, false)
		expect.call(renderer.call("snapshot")["clip"] == action and is_equal_approx(float(renderer.call("snapshot")["phase"]), contact), "Each distinct action reaches its release at the existing result boundary")
		expect.call(ActionFx.contact_progress(contact - 0.01, contact, false) < 0.0 and is_zero_approx(ActionFx.contact_progress(contact, contact, false)), "Molten contact/eruption cannot precede damage")
		renderer.call("present", {"clip": "attack", "action": action, "phase": 1.0}, false)
		expect.call(renderer.call("snapshot")["clip"] == "idle", "Completed actions restore idle during the result hold")
	expect.call(Cutout.attack_frame_count({"kind":"melee"}) == 42 and Cutout.attack_frame_count({"kind":"aoe"}) == 48, "Smolder Slide and Cinder Bloom use their own authored durations")
	_verify_support(renderer, expect)
	_submit(board, state, {"cinder_ooze_motion": {"enemy_1": {"clip": "walk", "direction": Vector2i(0, -1), "phase": 0.5}}, "reduced_motion": true})
	renderer.call("_process", 0.6)
	var still: Dictionary = renderer.call("snapshot")
	expect.call(still["clip"] == "rest" and still["facing"] == "rear" and float(still["phase"]) == 0.0, "Reduced motion retains the new art and facing without an animated pose")
	_submit(board, state, {"visible_enemy_ids": [2, 3]})
	expect.call(not bool(renderer.call("snapshot")["active"]), "Hidden Cinder Oozes stop idle work")
	_submit(board, state, {})
	var unit: Dictionary = state["enemies"][0].duplicate(true)
	unit["key"] = "enemy_1"
	unit["role"] = "enemy"
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", unit)
	expect.call(str(anchor.get_meta("asset_source_path", "")) == Cutout.REST_PATH, "Cinder Ooze HUD and shadows use the baked new silhouette")
	expect.call((board.call("_unit_idle_frames", unit) as Array).is_empty(), "Legacy Cinder Ooze idle sheets are not loaded")
	var logical: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2.ZERO)
	var padded: Rect2 = board.call("_unit_texture_draw_rect", unit, Vector2.ZERO)
	expect.call((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.position), "Padding preserves logical source registration")
	expect.call((padded.size * Cutout.SOURCE_SIZE / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.size), "Action canvas neither shrinks the body nor enlarges its HUD bounds")
	var echo: Dictionary = unit.duplicate(true)
	echo["key"] = "enemy_1_destination_preview"
	echo["role"] = "enemy_move_preview"
	expect.call(board.call("_texture_for_unit", echo) == texture, "Destination preview shares its Cinder Ooze's new art")
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
		expect.call((dissolves["enemy_1"].call("source_rect") as Rect2).is_equal_approx(board.call("_unit_texture_draw_rect", dying, board.call("_unit_center", dying))), "Dissolve geometry respects the padded Cinder Ooze canvas")
	else:
		expect.call(false, "The actual death presentation owns a dissolve effect")
	_submit(board, dead_state, {})
	await tree.process_frame
	expect.call(board.cinder_ooze_animation_snapshot("enemy_1").is_empty() and (board.get("_cinder_ooze_renderers") as Dictionary).size() == 1, "Removed Cinder Oozes release their viewport after death presentation")
	expect.call(board.cinder_ooze_animation_snapshot("enemy_2")["texture_id"] == second["texture_id"], "Removing one actor preserves the other's renderer")
	var definition: Dictionary = GameData.enemy_def("cinder_ooze")
	expect.call(int(definition["max_hp"]) == 12 and int(definition["base_initiative"]) == 13 and int(definition["reward_embers"]) == 12, "Production presentation preserves Cinder Ooze combat data")
	expect.call(not Cutout.uses_attack({"kind": "ranged"}, {"type": "cinder_ooze"}) and not Cutout.uses_attack({"kind": "melee"}, {"type": "crawler"}), "Routing excludes unrelated attacks and enemy types")
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
		"enemies": [{"id": 1, "type": "cinder_ooze", "pos": Vector2i(3, 3), "hp": 12, "max_hp": 12},
			{"id": 2, "type": "cinder_ooze", "pos": Vector2i(5, 5), "hp": 12, "max_hp": 12},
			{"id": 3, "type": "crawler", "pos": Vector2i(6, 6), "hp": 9, "max_hp": 9}]}

static func _verify_rigid_idle(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig: Node2D = (renderer.get("rigs") as Dictionary)[facing]
		var layout: Dictionary = rig.get("layout")
		expect.call((rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 14, "Each view loads its own complete nonhumanoid skeleton")
		var rest: Dictionary = Cutout.Motion.sample_pose("rest", 0.0, layout, facing)
		var lowest: float = 0.0
		for index: int in range(25):
			var pose: Dictionary = Cutout.Motion.sample_pose("idle", float(index) / 24.0, layout, facing)
			var mass_offset: Vector2 = Cutout.Motion._world(pose, layout, "mass").origin - Cutout.Motion._world(rest, layout, "mass").origin
			lowest = minf(lowest, mass_offset.y)
			for name: String in layout["joints"]:
				var actual: Transform2D = Cutout.Motion._world(pose, layout, name)
				var neutral: Transform2D = Cutout.Motion._world(rest, layout, name)
				expect.call(actual.x.is_equal_approx(neutral.x) and actual.y.is_equal_approx(neutral.y), "Idle keeps every bone basis rigid without plate shimmer: " + facing + "/" + name)
				var expected: Vector2 = mass_offset if name == "mass" else mass_offset * 0.65 if name.begins_with("bend_") else Vector2.ZERO
				# Source-coordinate subtraction rounds at float32 precision;
				# compare in pixels instead of relative epsilon near zero.
				expect.call((actual.origin - neutral.origin).distance_to(expected) < 0.0001, "Idle fixes all contacts and coordinates the soft roots with the rigid mass: " + facing + "/" + name)
		expect.call(is_equal_approx(lowest, -1.1), "Idle has the authored 1.1 source-pixel settle in " + facing)

static func _verify_support(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig: Node2D = (renderer.get("rigs") as Dictionary)[facing]
		var layout: Dictionary = rig.get("layout")
		var anchors: Dictionary = {}
		var drift: float = 0.0
		var travel: Vector2 = Cutout.Motion.walk_cycle_info(layout, facing)["travel_per_cycle"]
		expect.call(is_equal_approx(travel.length(), 50.0) and is_equal_approx(absf(travel.x/travel.y), 2.0), "Crawl has meaningful 50px displacement on the 2:1 board plane")
		for i: int in range(121):
			var t: float = float(i)/120.0
			rig.call("apply_pose", "walk", t)
			var count: int = 0
			for name: String in Cutout.Motion.CONTACT_NAMES:
				var foot: String = "contact_" + name
				var sample: Dictionary = Cutout.Motion.walk_foot_state(t, foot, layout, facing)
				var actual: Vector2 = rig.to_local((rig.get("bones")[foot] as Bone2D).global_position)
				expect.call(actual.distance_to(sample["target"]) < 0.001, "Native skeleton reaches its source-space support target")
				if sample["contact"]:
					count += 1
					var point: Vector2 = actual + travel*t
					if anchors.has(foot) and float(sample["cycle_phase"]) >= float(anchors[foot]["phase"]):
						drift = maxf(drift, point.distance_to(anchors[foot]["point"]))
					anchors[foot] = {"point":point,"phase":sample["cycle_phase"]}
				else:
					anchors.erase(foot)
			expect.call(count >= 4, "At least four distributed tendril contacts support every crawl phase")
		expect.call(drift < 0.002, "Root travel and contact timing prevent world-space skating")
