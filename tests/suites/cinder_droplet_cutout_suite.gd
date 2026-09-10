extends RefCounted

const Cutout = preload("res://scripts/cinder_droplet_cutout/renderer.gd")
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
	var first: Dictionary = board.cinder_droplet_animation_snapshot("enemy_1")
	var second: Dictionary = board.cinder_droplet_animation_snapshot("enemy_2")
	expect.call(not first.is_empty() and not second.is_empty(), "Every living Cinder Droplet gets a production cutout")
	if first.is_empty() or second.is_empty():
		board.queue_free()
		return
	expect.call((board.get("_cinder_droplet_renderers") as Dictionary).size() == 2, "Other enemy types do not allocate Cinder Droplet renderers")
	expect.call(first["texture_id"] != second["texture_id"], "Two Cinder Droplets have independent live textures and motion")
	var texture: Texture2D = board.call("_texture_for_unit", state["enemies"][0])
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for index: int in range(directions.size()):
		for clip: String in ["walk", "attack"]:
			_submit(board, state, {"cinder_droplet_motion": {"enemy_1": {"clip": clip, "direction": directions[index], "phase": 0.42}}})
			var sample: Dictionary = board.cinder_droplet_animation_snapshot("enemy_1")
			expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Cinder Droplet action follows the correct board direction")
			expect.call(sample["texture_id"] == first["texture_id"] and sample["rig_count"] == 2, "All actions retain one texture and two loaded views")
			expect.call(board.cinder_droplet_animation_snapshot("enemy_2")["clip"] == "idle", "Animating one Cinder Droplet never animates a second actor")
			_submit(board, state, {})
			var idle: Dictionary = board.cinder_droplet_animation_snapshot("enemy_1")
			expect.call(idle["clip"] == "idle" and idle["facing"] == "front" and idle["mirrored"], "Idle faces the player even when the preceding action points elsewhere")
	# Repositioning the player changes each observer independently, including
	# diagonal offsets whose closest isometric facing is unambiguous.
	var player_offsets: Array[Vector2i]
	player_offsets.assign([Vector2i(1, 2), Vector2i(2, 1), Vector2i(1, -2), Vector2i(-2, 1)])
	for index: int in range(player_offsets.size()):
		var repositioned: Dictionary = state.duplicate(true)
		repositioned["player"]["pos"] = Vector2i(3, 3) + player_offsets[index]
		_submit(board, repositioned, {})
		var sample: Dictionary = board.cinder_droplet_animation_snapshot("enemy_1")
		expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Idle picks the nearest of four facings toward the player's current tile")
		_submit(board, repositioned, {"reduced_motion": true})
		sample = board.cinder_droplet_animation_snapshot("enemy_1")
		expect.call(sample["clip"] == "rest" and sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Reduced-motion idle also turns toward the player")
	_submit(board, state, {"cinder_droplet_motion": {"enemy_1": {"clip": "attack", "direction": Vector2i(0, -1), "phase": 1.0}}})
	var recovered: Dictionary = board.cinder_droplet_animation_snapshot("enemy_1")
	expect.call(recovered["clip"] == "idle" and recovered["facing"] == "front" and recovered["mirrored"], "A completed attack immediately resumes player-facing idle")
	var renderer: Node = (board.get("_cinder_droplet_renderers") as Dictionary)["enemy_1"]
	_verify_rigid_idle(renderer, expect)
	renderer.call("present", {"clip": "walk", "phase": 2.25}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), 0.25), "Distance-driven walking wraps across complete cycles")
	for contact: float in [0.42]:
		renderer.call("present", {"clip": "attack", "phase": contact, "contact": contact}, false)
		expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), 0.52), "Spatter reaches its tendril contact pose at their existing result boundary")
		renderer.call("present", {"clip": "attack", "phase": 1.0}, false)
		expect.call(renderer.call("snapshot")["clip"] == "idle", "Completed attacks restore idle during the result hold")
	expect.call(Cutout.spatter_impact_phase(0.41) < 0.0 and is_equal_approx(Cutout.spatter_impact_phase(0.42), 0.08) and Cutout.spatter_impact_phase(0.90) < 0.0, "Spatter fire impact stays absent before the existing contact beat")
	expect.call(is_equal_approx(float(GameData.enemy_def("cinder_droplet")["art_scale"]),0.56), "Cinder Droplet keeps its scale relative to the larger Cinder Ooze")
	_verify_tendril_support(renderer, expect)
	_submit(board, state, {"cinder_droplet_motion": {"enemy_1": {"clip": "walk", "direction": Vector2i(0, -1), "phase": 0.5}}, "reduced_motion": true})
	renderer.call("_process", 0.6)
	var still: Dictionary = renderer.call("snapshot")
	expect.call(still["clip"] == "rest" and still["facing"] == "rear" and float(still["phase"]) == 0.0, "Reduced motion retains the new art and facing without an animated pose")
	_submit(board, state, {"visible_enemy_ids": [2, 3]})
	expect.call(not bool(renderer.call("snapshot")["active"]), "Hidden Cinder Droplets stop idle work")
	_submit(board, state, {})
	var unit: Dictionary = state["enemies"][0].duplicate(true)
	unit["key"] = "enemy_1"
	unit["role"] = "enemy"
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", unit)
	expect.call(str(anchor.get_meta("asset_source_path", "")) == Cutout.REST_PATH, "Cinder Droplet HUD and shadows use the baked new silhouette")
	expect.call((board.call("_unit_idle_frames", unit) as Array).is_empty(), "Legacy Cinder Droplet idle sheets are not loaded")
	var logical: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2.ZERO)
	var padded: Rect2 = board.call("_unit_texture_draw_rect", unit, Vector2.ZERO)
	expect.call((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.position), "Padding preserves logical source registration")
	expect.call((padded.size * Cutout.SOURCE_SIZE / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.size), "Action canvas neither shrinks the body nor enlarges its HUD bounds")
	var echo: Dictionary = unit.duplicate(true)
	echo["key"] = "enemy_1_destination_preview"
	echo["role"] = "enemy_move_preview"
	expect.call(board.call("_texture_for_unit", echo) == texture, "Destination preview shares its Cinder Droplet's new art")
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
		expect.call((dissolves["enemy_1"].call("source_rect") as Rect2).is_equal_approx(board.call("_unit_texture_draw_rect", dying, board.call("_unit_center", dying))), "Dissolve geometry respects the padded Cinder Droplet canvas")
	else:
		expect.call(false, "The actual death presentation owns a dissolve effect")
	_submit(board, dead_state, {})
	await tree.process_frame
	expect.call(board.cinder_droplet_animation_snapshot("enemy_1").is_empty() and (board.get("_cinder_droplet_renderers") as Dictionary).size() == 1, "Removed Cinder Droplets release their viewport after death presentation")
	expect.call(board.cinder_droplet_animation_snapshot("enemy_2")["texture_id"] == second["texture_id"], "Removing one actor preserves the other's renderer")
	var definition: Dictionary = GameData.enemy_def("cinder_droplet")
	expect.call(int(definition["max_hp"]) == 4 and int(definition["base_initiative"]) == 9 and int(definition["reward_embers"]) == 0, "Production presentation preserves Cinder Droplet combat data")
	expect.call(not Cutout.uses_attack({"kind": "ranged"}, {"type": "cinder_droplet"}) and not Cutout.uses_attack({"kind": "melee"}, {"type": "crawler"}), "Routing excludes unrelated attacks and enemy types")
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
		"enemies": [{"id": 1, "type": "cinder_droplet", "pos": Vector2i(3, 3), "hp": 4, "max_hp": 4},
			{"id": 2, "type": "cinder_droplet", "pos": Vector2i(5, 5), "hp": 4, "max_hp": 4},
			{"id": 3, "type": "crawler", "pos": Vector2i(6, 6), "hp": 9, "max_hp": 9}]}

static func _verify_rigid_idle(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig: Node2D = (renderer.get("rigs") as Dictionary)[facing]
		var layout: Dictionary = rig.get("layout")
		var rest: Dictionary = Cutout.Motion.sample_pose("rest", 0.0, layout, facing)
		var lowest: float = 0.0
		for index: int in range(25):
			var pose: Dictionary = Cutout.Motion.sample_pose("idle", float(index) / 24.0, layout, facing)
			var core_offset: Vector2 = Cutout.Motion._world(pose, layout, "core").origin - Cutout.Motion._world(rest, layout, "core").origin
			lowest = minf(lowest, core_offset.y)
			for name: String in layout["joints"]:
				var actual: Transform2D = Cutout.Motion._world(pose, layout, name)
				var neutral: Transform2D = Cutout.Motion._world(rest, layout, name)
				expect.call(actual.x.is_equal_approx(neutral.x) and actual.y.is_equal_approx(neutral.y), "Idle preserves every rigid bone basis without ripple: " + facing + "/" + name)
				var fixed: bool = name == "root" or name.ends_with("_tip")
				var expected_offset: Vector2 = Vector2.ZERO if fixed else core_offset*.5 if name.ends_with("_bend") else core_offset
				expect.call((actual.origin - neutral.origin).distance_to(expected_offset) < .001, "Idle keeps tendrils planted while the complete upper body bobs together: " + facing + "/" + name)
		expect.call(is_equal_approx(lowest, -1.2), "Idle retains the accepted 1.2 source-pixel bob in " + facing)

static func _verify_tendril_support(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front","rear"]:
		var rig: Node2D = (renderer.get("rigs") as Dictionary)[facing]
		var layout: Dictionary = rig.get("layout")
		var travel: Vector2 = Cutout.Motion.walk_cycle_info(layout,facing)["travel_per_cycle"]
		# Verify the painted contact patches, not just abstract bone origins.
		for tendril: String in Cutout.Motion.TENDRILS:
			var tip: String = tendril + "_tip"
			var contact_vertices: int = 0
			var center: Vector2 = Cutout.Motion._point(layout, tip)
			for mesh: Dictionary in layout["joint_meshes"]:
				for index: int in range(mesh["vertices"].size()):
					var value: Array = mesh["vertices"][index]
					if Vector2(float(value[0]),float(value[1])).distance_to(center) <= 6.0:
						contact_vertices += 1
						expect.call(is_equal_approx(float(mesh["weights"][tip][index]),1.0), "Visible toe patches follow the rigid planted terminal exclusively")
			expect.call(contact_vertices >= 15, "Each contact has a complete painted mesh patch")
		for sign_value: float in [1.0,-1.0]:
			var previous: Dictionary = {}
			for index: int in range(161):
				var phase: float = sign_value*float(index)/80.0
				var wrapped: float = fposmod(phase,1.0)
				var pose: Dictionary = Cutout.Motion.sample_pose("walk",wrapped,layout,facing)
				var supports: int = 0
				for tendril: String in Cutout.Motion.TENDRILS:
					var tip: String = tendril+"_tip"
					var state: Dictionary = Cutout.Motion.walk_foot_state(wrapped,tip,layout,facing)
					var world: Transform2D = Cutout.Motion._world(pose,layout,tip)
					expect.call(world.origin.distance_to(state["target"]) < .001,"Tendril meets its projected contact target")
					expect.call(world.x.distance_to(Vector2.RIGHT) < .001 and world.y.distance_to(Vector2.DOWN) < .001,"Every terminal preserves its painted width and rigid basis")
					if state["contact"]:
						supports += 1
						var anchor: Vector2 = world.origin + travel*phase
						if previous.has(tip) and absf(float(previous[tip]["cycle"])-float(state["cycle_phase"])) < .05:
							expect.call(anchor.distance_to(previous[tip]["point"]) < .002,"Forward and backward scuttle contacts stay fixed against actual root travel")
						previous[tip] = {"point":anchor,"cycle":state["cycle_phase"]}
					else:
						previous.erase(tip)
				expect.call(supports >= 3,"The molten core always retains at least three planted supports")
	var split: Dictionary = GameData.enemy_def("cinder_ooze")["death_spawn"]
	expect.call(split["enemy_type"] == "cinder_droplet" and int(split["count"]) == 2 and bool(split["summoned"]),"Ooze split lifecycle and summoned reward policy are unchanged")
