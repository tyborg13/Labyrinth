extends RefCounted

const Cutout = preload("res://scripts/iskaldra_cutout/renderer.gd")
const Action = preload("res://scripts/iskaldra_cutout/action.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const GameData = preload("res://scripts/game_data.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920,1080)
	tree.root.add_child(board)
	await tree.process_frame
	var state: Dictionary = fixture_state()
	_submit(board,state,{})
	await tree.process_frame
	var first: Dictionary = board.iskaldra_animation_snapshot("enemy_1")
	var second: Dictionary = board.iskaldra_animation_snapshot("enemy_2")
	expect.call(not first.is_empty() and not second.is_empty(), "Both Iskaldras own production cutouts")
	if first.is_empty() or second.is_empty():
		board.queue_free()
		return
	expect.call((board.get("_iskaldra_renderers") as Dictionary).size() == 2, "Iskaldra registration excludes other enemies")
	expect.call(first["texture_id"] != second["texture_id"], "Multiple bosses have independent persistent textures")
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)])
	var facings: Array[String]
	facings.assign(["front","front","rear","rear"])
	var mirrors: Array[bool]
	mirrors.assign([false,true,false,true])
	for index: int in range(4):
		for action: String in ["talon","lance","storm","mantle"]:
			_submit(board,state,{"iskaldra_motion":{"enemy_1":{"clip":"attack","action":action,"phase":0.5,"direction":directions[index]}}})
			var shot: Dictionary = board.iskaldra_animation_snapshot("enemy_1")
			expect.call(shot["clip"] == action and shot["facing"] == facings[index] and shot["mirrored"] == mirrors[index], "Each dragon action follows its resolved direction")
			expect.call(shot["texture_id"] == first["texture_id"] and shot["rig_count"] == 2, "Actions and reflections retain their texture and both views")
			expect.call(board.iskaldra_animation_snapshot("enemy_2")["clip"] == "idle", "Only the acting boss animates")
			if action == "lance":
				_submit(board,state,{"iskaldra_motion":{"enemy_1":{"clip":"attack","action":"lance","phase":0.45,"direction":directions[index]}}})
				var actor: Node = board.get("_iskaldra_renderers")["enemy_1"]
				var rig: Node2D = actor.get("rigs")[facings[index]]
				var maw: Array = rig.layout["landmarks"]["maw"]
				var local_maw: Vector2 = Vector2(float(maw[0]),float(maw[1])) - Cutout.Motion.point(rig.layout,"head")
				var actual_maw: Vector2 = (rig.bones["head"] as Node2D).global_transform * local_maw - Cutout.SOURCE_OFFSET
				expect.call((actor.call("source_socket",true) as Vector2).distance_to(actual_maw) < 0.001,"Lance origin matches the actual released maw in all four views")
		_submit(board,state,{"iskaldra_motion":{"enemy_1":{"clip":"walk","phase":1.25,"direction":directions[index]}}})
		expect.call(is_equal_approx(float(board.iskaldra_animation_snapshot("enemy_1")["phase"]),0.25), "Distance-based walk phase wraps across tiles")
		_submit(board,state,{})
		expect.call(board.iskaldra_animation_snapshot("enemy_1")["clip"] == "idle", "Action completion keeps the cutout and restores idle")
	var offsets: Array[Vector2i]
	offsets.assign([Vector2i(0,3),Vector2i(3,0),Vector2i(0,-3),Vector2i(-3,0)])
	for index: int in range(4):
		var moved: Dictionary = state.duplicate(true)
		moved["player"]["pos"] = Vector2i(3,3) + offsets[index]
		_submit(board,moved,{})
		var idle: Dictionary = board.iskaldra_animation_snapshot("enemy_1")
		expect.call(idle["facing"] == facings[index] and idle["mirrored"] == mirrors[index], "Idle watches the player around all four sides of the boss footprint")
		_submit(board,moved,{"reduced_motion":true})
		var still: Dictionary = board.iskaldra_animation_snapshot("enemy_1")
		expect.call(still["clip"] == "rest" and still["phase"] == 0.0 and still["facing"] == facings[index] and still["mirrored"] == mirrors[index], "Reduced motion uses the same directional still art")
	_submit(board,state,{})
	var renderer: Node = board.get("_iskaldra_renderers")["enemy_1"]
	_verify_motion(renderer,expect)
	_verify_walk_boundaries(board,renderer,expect)
	var fallback := Vector2(30,40)
	var clipped: Dictionary = {"actor_key":"enemy_1","kind":"ranged","umbra_action_clipped":true}
	expect.call(board.call("_iskaldra_launch_point",clipped,fallback) == fallback,"Clipped Umbra projectiles retain their visible geometry without exposing a hidden maw")
	var unit: Dictionary = state["enemies"][0].duplicate(true)
	unit.merge({"key":"enemy_1","role":"enemy"},true)
	var texture: Texture2D = board.call("_texture_for_unit",unit)
	var rest: Texture2D = board.call("_unit_hud_anchor_texture",unit)
	expect.call(str(rest.get_meta("asset_source_path","")) == Cutout.REST_PATH, "HUD/shadow use the baked production silhouette")
	expect.call((board.call("_unit_idle_frames",unit) as Array).is_empty(), "Legacy idle sheets cannot replace the rig")
	var logical: Rect2 = board.call("_unit_draw_rect_for_center",unit,Vector2.ZERO)
	var padded: Rect2 = board.call("_unit_texture_draw_rect",unit,Vector2.ZERO)
	expect.call((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.position), "Viewport padding preserves the logical boss anchor")
	expect.call((padded.size * Cutout.SOURCE_SIZE / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.size), "Padding never resizes logical body/HUD geometry")
	expect.call(board.call("_resolved_unit_footprint",unit) == Vector2i(2,2), "Boss keeps its 2x2 footprint")
	var echo: Dictionary = unit.duplicate(true)
	echo.merge({"key":"enemy_1_destination_preview","role":"enemy_move_preview"},true)
	expect.call(board.call("_texture_for_unit",echo) == texture, "Destination echoes reuse the actual boss texture")
	var dead: Dictionary = state.duplicate(true)
	dead["enemies"][0]["hp"] = 0
	dead["player"]["pos"] = Vector2i(1,3)
	var dying: Dictionary = unit.duplicate(true)
	dying.merge({"death_animation":true,"death_progress":0.45},true)
	var frozen: Dictionary = renderer.call("snapshot")
	_submit(board,dead,{"death_animation_units":[dying]})
	var death: Dictionary = renderer.call("snapshot")
	expect.call(not death["active"] and death["facing"] == frozen["facing"] and death["mirrored"] == frozen["mirrored"], "Death freezes the pose despite player repositioning")
	expect.call(board.call("_enemy_shadow_dissolve_source_texture",dying) == texture, "Death dissolves the same cutout")
	var dissolves: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key")
	expect.call(dissolves.has("enemy_1"), "Real death presentation owns the procedural dissolve")
	if dissolves.has("enemy_1"):
		expect.call((dissolves["enemy_1"].call("source_rect") as Rect2).is_equal_approx(board.call("_unit_texture_draw_rect",dying,board.call("_unit_center",dying))), "Death dissolve retains padded texture registration")
	_submit(board,dead,{})
	await tree.process_frame
	expect.call(board.iskaldra_animation_snapshot("enemy_1").is_empty(), "The defeated actor releases its renderer")
	expect.call(board.iskaldra_animation_snapshot("enemy_2")["texture_id"] == second["texture_id"], "Surviving actor preserves its renderer")
	_verify_routing(expect)
	board.queue_free()
	await tree.process_frame

static func _verify_motion(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front","rear"]:
		var rig: Node2D = renderer.get("rigs")[facing]
		var layout: Dictionary = rig.get("layout")
		var rest: Dictionary = Cutout.Motion.sample_pose("rest",0,layout,facing)
		var maximum_bob: float = 0.0
		for index: int in range(41):
			var t: float = float(index)/40.0
			var pose: Dictionary = Cutout.Motion.sample_pose("idle",t,layout,facing)
			var offset: Vector2 = Cutout.Motion.world(pose,layout,"torso").origin - Cutout.Motion.world(rest,layout,"torso").origin
			maximum_bob = maxf(maximum_bob,-offset.y)
			for name: String in layout["joints"]:
				var actual: Transform2D = Cutout.Motion.world(pose,layout,name)
				var neutral: Transform2D = Cutout.Motion.world(rest,layout,name)
				expect.call(actual.x.is_equal_approx(neutral.x) and actual.y.is_equal_approx(neutral.y), "Idle never rotates, scales or shears any surface")
				var planted: bool = name == "root" or name == "tail" or name.begins_with("hip_") or name.begins_with("knee_") or name.begins_with("foot_")
				var expected: Vector2 = Vector2.ZERO if planted else offset
				expect.call((actual.origin-neutral.origin).distance_to(expected) < 0.0001, "Hind legs/tail stay fixed under the coordinated upper-body bob")
			var walk: Dictionary = Cutout.Motion.sample_pose("walk",t,layout,facing)
			for foot: String in ["foot_near","foot_far"]:
				var support: Dictionary = Cutout.Motion.walk_foot_state(t,foot,layout,facing)
				var actual: Transform2D = Cutout.Motion.world(walk,layout,foot)
				expect.call(actual.origin.distance_to(support["target"]) < 0.001, "Hind paw reaches its actual projected support target")
				expect.call(actual.x.is_equal_approx(Vector2.RIGHT) and actual.y.is_equal_approx(Vector2.DOWN), "Painted paw keeps a rigid basis through the stride")
		expect.call(is_equal_approx(maximum_bob,1.7), "Dragon retains a restrained 1.7px idle bob")

static func _verify_walk_boundaries(board: Control, renderer: Node, expect: Callable) -> void:
	var source_step: float = (Vector2(board.call("world_position_for_tile",Vector2i(4,4))) - Vector2(board.call("world_position_for_tile",Vector2i(4,3)))).length() / float(board.call("iskaldra_source_pixel_scale"))
	for segment_distance: float in [source_step,source_step*2.0,source_step*1.37]:
		var cycles: int = Cutout.walk_segment_cycles(segment_distance)
		var travel: float = segment_distance / float(cycles)
		expect.call(Cutout.walk_segment_frames(segment_distance) == cycles*48,"Finite movement uses whole grounded cycles, including nonstandard path lengths")
		for facing: String in ["front","rear"]:
			var rig: Node2D = renderer.get("rigs")[facing]
			var layout: Dictionary = rig.layout
			var direction: Vector2 = Cutout.Motion.walk_cycle_info(layout,facing)["direction"]
			var rest: Dictionary = Cutout.Motion.sample_pose("rest",0.0,layout,facing)
			for phase: float in [0.0,1.0]:
				var pose: Dictionary = Cutout.Motion.sample_pose("walk",phase,layout,facing,travel)
				for joint: String in layout["joints"]:
					var actual: Transform2D = Cutout.Motion.world(pose,layout,joint)
					var neutral: Transform2D = Cutout.Motion.world(rest,layout,joint)
					expect.call(actual.origin.distance_to(neutral.origin)<0.001 and actual.x.distance_to(neutral.x)<0.001 and actual.y.distance_to(neutral.y)<0.001,"Walk entry and final complete cycle match the accepted resting rig")
			for foot: String in ["foot_near","foot_far"]:
				var sole: Vector2 = Cutout.Motion._sole(layout,foot)
				var entry: Dictionary = Cutout.Motion.walk_foot_state(0.001,foot,layout,facing,travel)
				expect.call(bool(entry["contact"]) and (Vector2(entry["ground_contact"])+direction*travel*0.001).distance_to(sole)<0.001,"Both entry soles stay planted across the first root translation")
			# The far sole supports the last root translation; the near sole lands
			# at cycle completion. Neither is repositioned when idle resumes.
			var before: Dictionary = Cutout.Motion.walk_foot_state(0.999,"foot_far",layout,facing,travel)
			var final: Dictionary = Cutout.Motion.walk_foot_state(1.0,"foot_far",layout,facing,travel)
			expect.call(bool(before["contact"]) and bool(final["contact"]) and (Vector2(before["ground_contact"])+direction*travel*0.999).distance_to(Vector2(final["ground_contact"])+direction*travel)<0.001,"The final supporting sole cancels the last root translation before idle")

static func _verify_routing(expect: Callable) -> void:
	var actor: Dictionary = {"type":"iskaldra","pos":Vector2i(3,3),"footprint":Vector2i(2,2)}
	for pair: Array in [["melee","talon"],["ranged","lance"],["aoe","storm"]]:
		expect.call(Action.clip_for_effect({"kind":pair[0]},actor) == pair[1], "Distinct action families keep their own choreography")
	expect.call(Action.clip_for_effect({"kind":"status","action_type":"frost_armor"},actor) == "mantle", "Crystal Mantle keeps its guard cue")
	expect.call(Action.clip_for_effect({"kind":"melee"},{"type":"warden"}).is_empty(), "Actor-specific routing preserves other enemies")
	var ice: Dictionary = {"kind":"ranged","action_type":"ranged","element":"ice","actor_key":"enemy_1","from":Vector2i(3,3),"to":Vector2i(3,7)}
	expect.call(Fx.style_for_effect(ice) == Fx.STYLE_ICE_SHARDS, "Whiteout Lance retains the existing ice effect")
	var release: Dictionary = Action.motion_for_effect(ice,actor,Fx.ICE_ANTICIPATION_END_PROGRESS,Vector2i(3,7))
	expect.call(is_equal_approx(float(release["phase"]),0.45), "Maw release aligns with ice anticipation boundary")
	var contact: Dictionary = Action.motion_for_effect(ice,actor,Fx.ICE_TRAVEL_END_PROGRESS,Vector2i(3,7))
	expect.call(is_equal_approx(float(contact["phase"]),0.65), "Ranged impact keeps its separate arrival boundary")
	var definition: Dictionary = GameData.enemy_def("iskaldra")
	expect.call(int(definition["max_hp"]) == 62 and int(definition["base_initiative"]) == 14 and int(definition["reward_embers"]) == 80, "Combat numbers remain unchanged")
	expect.call(bool(definition["boss_bar"]) and int(definition["footprint"][0]) == 2 and int(definition["footprint"][1]) == 2 and definition["status_immunities"].size() == 1 and definition["status_immunities"].has("freeze"), "Boss footprint, bar and freeze immunity remain unchanged")

static func _submit(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	board.call("set_combat_state",state,[],[],Vector2i(-1,-1),"","",{},{},presentation)

static func fixture_state() -> Dictionary:
	var grid: Array = []
	for y: int in range(11):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 10 else "stone")
		grid.append(row)
	return {"grid":grid,"room_coord":Vector2i(4,3),"terrain":[],"traps":[],"loot":[],
		"player":{"pos":Vector2i(5,2),"hp":80,"max_hp":80},
		"enemies":[{"id":1,"type":"iskaldra","pos":Vector2i(3,3),"hp":62,"max_hp":62,"footprint":Vector2i(2,2)},
			{"id":2,"type":"iskaldra","pos":Vector2i(7,6),"hp":62,"max_hp":62,"footprint":Vector2i(2,2)},
			{"id":3,"type":"warden","pos":Vector2i(1,6),"hp":18,"max_hp":18}]}
