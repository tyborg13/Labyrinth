extends RefCounted

const Cutout = preload("res://scripts/vaeloryx_cutout/renderer.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Wind = preload("res://scripts/vaeloryx_cutout/wind_feedback.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	_verify_routes(expect)
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	tree.root.add_child(board)
	await tree.process_frame
	var state: Dictionary = fixture_state()
	_submit(board, state, {})
	await tree.process_frame
	var first: Dictionary = board.vaeloryx_animation_snapshot("enemy_1")
	var second: Dictionary = board.vaeloryx_animation_snapshot("enemy_2")
	expect.call(not first.is_empty() and not second.is_empty(), "Each Vaeloryx receives a production renderer")
	if first.is_empty() or second.is_empty():
		board.queue_free()
		return
	expect.call((board.get("_vaeloryx_renderers") as Dictionary).size() == 2, "Other actors do not allocate dragon rigs")
	expect.call(not board.warden_animation_snapshot("enemy_3").is_empty(), "Existing Warden registration coexists with Vaeloryx")
	expect.call(first["texture_id"] != second["texture_id"], "Multiple dragons have independent textures")
	var renderer: Node = (board.get("_vaeloryx_renderers") as Dictionary)["enemy_1"]
	_verify_motion(renderer, expect)
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for index: int in range(directions.size()):
		for action: String in ["walk", "dive", "gale", "pull", "guard"]:
			var motion: Dictionary = {"clip": "walk" if action == "walk" else "attack", "action": action, "direction": directions[index], "phase": 0.42}
			_submit(board, state, {"vaeloryx_motion": {"enemy_1": motion}})
			var sample: Dictionary = board.vaeloryx_animation_snapshot("enemy_1")
			expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Every dragon action faces its resolved direction")
			expect.call(sample["clip"] == action, "The specific dragon action reaches its own sampler")
			expect.call(sample["texture_id"] == first["texture_id"] and sample["rig_count"] == 2, "Actions and facing changes retain one texture and both rigs")
			expect.call(board.vaeloryx_animation_snapshot("enemy_2")["clip"] == "idle", "One action never animates the other dragon")
			_submit(board, state, {})
			var idle: Dictionary = board.vaeloryx_animation_snapshot("enemy_1")
			expect.call(idle["clip"] == "idle" and idle["facing"] == "front" and idle["mirrored"], "Actions recover to player-facing idle")
	var positions: Array[Vector2i]
	positions.assign([Vector2i(3, 6), Vector2i(6, 3), Vector2i(4, 1), Vector2i(1, 4)])
	for index: int in range(positions.size()):
		var repositioned: Dictionary = state.duplicate(true)
		repositioned["player"]["pos"] = positions[index]
		_submit(board, repositioned, {})
		var sample: Dictionary = board.vaeloryx_animation_snapshot("enemy_1")
		expect.call(sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Idle faces from the 2x2 footprint center toward the completed player tile")
		_submit(board, repositioned, {"reduced_motion": true})
		sample = board.vaeloryx_animation_snapshot("enemy_1")
		expect.call(sample["clip"] == "rest" and sample["phase"] == 0.0 and sample["facing"] == facings[index] and sample["mirrored"] == mirrors[index], "Reduced motion preserves the new art and player-facing still pose")
	_submit(board, state, {"vaeloryx_motion": {"enemy_1": {"clip": "attack", "action": "gale", "phase": 1.0, "direction": Vector2i(0, -1)}}})
	expect.call(board.vaeloryx_animation_snapshot("enemy_1")["clip"] == "idle" and board.vaeloryx_animation_snapshot("enemy_1")["mirrored"], "A completed action immediately returns to player-facing idle")
	for contact: float in [0.42, 0.50]:
		for action: String in ["dive", "gale", "pull"]:
			renderer.call("present", {"clip": "attack", "action": action, "phase": contact, "contact": contact}, false)
			expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), Cutout.Motion.CONTACT), "Contact/release maps to the existing effect boundary")
	renderer.call("present", {"clip": "walk", "phase": 2.25}, false)
	expect.call(is_equal_approx(float(renderer.call("snapshot")["phase"]), 0.25), "Distance-driven travel wraps across cycles")
	_submit(board, state, {})
	var unit: Dictionary = state["enemies"][0].duplicate(true)
	unit.merge({"key": "enemy_1", "role": "enemy"}, true)
	var texture: Texture2D = board.call("_texture_for_unit", unit)
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", unit)
	expect.call(str(anchor.get_meta("asset_source_path", "")) == Cutout.REST_PATH, "HUD and shadow use the baked neutral dragon")
	expect.call((board.call("_unit_idle_frames", unit) as Array).is_empty(), "Legacy whole-body idle sheets are not loaded")
	expect.call((board.call("_unit_footprint_tiles", unit) as Array).size() == 4, "The dragon retains four logical occupied tiles")
	var logical: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2.ZERO)
	var padded: Rect2 = board.call("_unit_texture_draw_rect", unit, Vector2.ZERO)
	expect.call((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.position), "Canvas padding preserves logical registration")
	expect.call((padded.size * Cutout.SOURCE_SIZE / Vector2(Cutout.CANVAS_SIZE)).is_equal_approx(logical.size), "The action canvas neither shrinks the dragon nor expands its HUD")
	var echo: Dictionary = unit.duplicate(true)
	echo.merge({"key": "enemy_1_destination_preview", "role": "enemy_move_preview"}, true)
	expect.call(board.call("_texture_for_unit", echo) == texture, "Preview echoes share the actual actor texture")
	_submit(board, state, {"visible_enemy_ids": [2, 3, 4]})
	expect.call(not bool(renderer.call("snapshot")["active"]), "Hidden actors stop idle work")
	_submit(board, state, {})
	var dead: Dictionary = state.duplicate(true)
	dead["enemies"][0]["hp"] = 0
	dead["player"]["pos"] = Vector2i(1, 3)
	var dying: Dictionary = unit.duplicate(true)
	dying.merge({"death_animation": true, "death_progress": 0.45}, true)
	var frozen: Dictionary = renderer.call("snapshot")
	_submit(board, dead, {"death_animation_units": [dying]})
	var death: Dictionary = renderer.call("snapshot")
	expect.call(death["facing"] == frozen["facing"] and death["mirrored"] == frozen["mirrored"] and death["phase"] == frozen["phase"], "Death freezes the same pose even when the player changes sides")
	expect.call(not death["active"] and board.call("_enemy_shadow_dissolve_source_texture", dying) == texture, "Existing dissolve consumes the frozen cutout")
	var dissolves: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key")
	expect.call(dissolves.has("enemy_1"), "Death creates the actual shared dissolve effect")
	if dissolves.has("enemy_1"):
		expect.call((dissolves["enemy_1"].call("source_rect") as Rect2).is_equal_approx(board.call("_unit_texture_draw_rect", dying, board.call("_unit_center", dying))), "Death keeps padded geometry centered on the logical 2x2 body")
	_submit(board, dead, {})
	await tree.process_frame
	expect.call(board.vaeloryx_animation_snapshot("enemy_1").is_empty() and (board.get("_vaeloryx_renderers") as Dictionary).size() == 1, "Removal frees only the completed actor")
	expect.call(board.vaeloryx_animation_snapshot("enemy_2")["texture_id"] == second["texture_id"], "The surviving dragon retains its independent renderer")
	board.queue_free()
	await tree.process_frame

static func _verify_routes(expect: Callable) -> void:
	var wind_effect: Dictionary = {"kind": "pull", "enemy_type": "vaeloryx", "from": Vector2i(4, 4), "to": Vector2i(3, 4), "player_from": Vector2i(1, 4)}
	expect.call(Wind.handles(wind_effect), "An adjacent resolved pull retains wind feedback instead of a melee slash")
	expect.call(not Wind.handles(wind_effect.merged({"enemy_type": "warden"}, true)) and not Wind.handles(wind_effect.merged({"umbra_action_clipped": true}, true)), "Wind specialization preserves other actors and existing Umbra clipping")
	var dragon := Vector2(100, 100)
	var player := Vector2(300, 200)
	expect.call(Wind.endpoints(wind_effect, dragon, player) == {"start": player, "end": dragon}, "Skyhook wind travels inward")
	expect.call(Wind.endpoints({"kind": "push"}, dragon, player) == {"start": dragon, "end": player}, "Hollow Gale wind travels outward")
	expect.call(is_zero_approx(Wind.travel_phase(0.40)) and is_equal_approx(Wind.travel_phase(0.50), 1.0), "Wind arrives at the unchanged 50 percent result boundary")
	var actor: Dictionary = {"type": "vaeloryx", "pos": Vector2i(3, 3)}
	for entry: Dictionary in [{"kind": "push", "action_type": "gale_force", "clip": "gale"}, {"kind": "pull", "clip": "pull"}, {"kind": "melee", "clip": "dive"}, {"kind": "block", "clip": "guard"}]:
		expect.call(Cutout.action_for_effect(entry, actor) == entry["clip"], "Existing Vaeloryx intent family routes to its own anatomy")
	expect.call(Cutout.action_for_effect({"kind": "ranged"}, actor).is_empty() and Cutout.action_for_effect({"kind": "melee"}, {"type": "warden"}).is_empty(), "Routing leaves unrelated action families and actors alone")
	expect.call(not Cutout.uses_attack({"kind": "block"}, actor), "Guard keeps its ordinary support-result presentation")
	expect.call(Cutout.effect_direction({"kind": "push", "player_from": Vector2i(3, 6), "to": Vector2i(8, 8)}, actor, Vector2i(8, 8)) == Vector2i(-1, 5), "Gale faces the resolved original player target from the boss center")
	var definition: Dictionary = GameData.enemy_def("vaeloryx")
	expect.call(int(definition["max_hp"]) == 58 and int(definition["base_initiative"]) == 12 and int(definition["reward_embers"]) == 80, "Presentation preserves boss HP, initiative and rewards")
	expect.call(int(definition["footprint"][0]) == 2 and int(definition["footprint"][1]) == 2 and bool(definition["boss_bar"]), "Boss footprint and bar stay intact")
	expect.call((definition["status_immunities"] as Array).size() == 1 and str(definition["status_immunities"][0]) == "immobilize", "The boss retains only its existing Immobilize immunity")
	expect.call((definition["intents"] as Array).size() == 4, "The existing four-intent kit remains intact")
	expect.call(RunScene.TURN_ORDER_PORTRAITS["vaeloryx"] == "res://assets/art/portraits/vaeloryx.png", "The dedicated turn-clock portrait remains registered")
	expect.call(Cutout.attack_trail_phase(0.20) < 0.0 and is_equal_approx(Cutout.attack_trail_phase(0.42), 0.45), "The melee trail follows claw release rather than windup")

static func _verify_motion(renderer: Node, expect: Callable) -> void:
	for facing: String in ["front", "rear"]:
		var rig: Node2D = renderer.get("rigs")[facing]
		expect.call((rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 15, "Each view loads its complete dragon skeleton")
		var layout: Dictionary = rig.get("layout")
		var rest: Dictionary = Cutout.Motion.sample_pose("rest", 0.0, layout, facing)
		for index: int in range(25):
			var phase: float = float(index) / 24.0
			var pose: Dictionary = Cutout.Motion.sample_pose("idle", phase, layout, facing)
			var offset: Vector2 = Vector2(0, -2.4 * (0.5 - 0.5 * cos(TAU * phase)))
			for name: String in layout["joints"]:
				var actual: Transform2D = _world(pose, layout, name)
				var neutral: Transform2D = _world(rest, layout, name)
				expect.call(actual.x.is_equal_approx(neutral.x) and actual.y.is_equal_approx(neutral.y), "Idle does not ripple any wing/body/claw basis")
				expect.call((actual.origin - neutral.origin).is_equal_approx(offset), "Every idle part shares one coherent hover translation")
		for clip: String in ["walk", "dive", "gale", "pull", "guard"]:
			for index: int in range(49):
				var pose: Dictionary = Cutout.Motion.sample_pose(clip, float(index) / 48.0, layout, facing)
				for name: String in ["head", "wing_far", "wing_near", "claw_far", "claw_near", "claw_hind"]:
					var basis: Transform2D = _world(pose, layout, name)
					expect.call(basis.is_finite() and is_equal_approx(basis.x.length(), 1.0) and is_equal_approx(basis.y.length(), 1.0) and absf(basis.x.dot(basis.y)) < 0.001, "Rigid terminal paint preserves width through the entire action")
			if clip != "walk":
				expect.call(Cutout.Motion.sample_pose(clip, 0.0, layout, facing) == rest and Cutout.Motion.sample_pose(clip, 1.0, layout, facing) == rest, "Every action prepares from and recovers to its registered rest")
		var travel: Vector2 = Cutout.Motion.walk_cycle_info(layout, facing)["travel_per_cycle"]
		expect.call(travel.length() > 100.0 and is_equal_approx(absf(travel.x / travel.y), 2.0), "Travel uses meaningful displacement along the 2:1 projection")

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	var parent: Variant = layout["joints"][name].get("parent")
	var before: Transform2D = Transform2D.IDENTITY if parent == null else _world(pose, layout, str(parent))
	var data: Dictionary = pose[name]
	return before * Transform2D(float(data["rotation"]), Vector2(data["scale"]), float(data["skew"]), Vector2(data["position"]))

static func _submit(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)

static func fixture_state() -> Dictionary:
	var grid: Array = []
	for y: int in range(12):
		var row: Array = []
		for x: int in range(12):
			row.append("wall" if x == 0 or y == 0 or x == 11 or y == 11 else "stone")
		grid.append(row)
	return {"grid": grid, "room_coord": Vector2i(4, 3), "terrain": [], "traps": [], "loot": [],
		"player": {"pos": Vector2i(5, 4), "hp": 100, "max_hp": 100},
		"enemies": [{"id": 1, "type": "vaeloryx", "pos": Vector2i(3, 3), "footprint": Vector2i(2, 2), "hp": 58, "max_hp": 58},
			{"id": 2, "type": "vaeloryx", "pos": Vector2i(8, 6), "footprint": Vector2i(2, 2), "hp": 58, "max_hp": 58},
			{"id": 3, "type": "warden", "pos": Vector2i(5, 8), "hp": 18, "max_hp": 18},
			{"id": 4, "type": "crawler", "pos": Vector2i(1, 8), "hp": 9, "max_hp": 9}]}
