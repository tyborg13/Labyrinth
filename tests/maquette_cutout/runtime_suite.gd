extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const GameData = preload("res://scripts/game_data.gd")
const Settings = preload("res://scripts/settings_store.gd")

static func run(tree: SceneTree, expect: Callable, type: String) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	tree.root.add_child(board)
	await tree.process_frame
	var state: Dictionary = fixture(type)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	await tree.process_frame
	var renderer: Node = board.unit_cutout_renderer(state["enemies"][0])
	expect.call(renderer != null, type + ": persistent production renderer")
	if renderer == null:
		board.queue_free()
		return
	var texture: Texture2D = renderer.texture()
	var data: Dictionary = Action.data_for(type)
	for clip: String in data["clips"]:
		for selector: String in data["clips"][clip].get("intents", []):
			var fields: PackedStringArray = selector.split(":")
			var actor: Dictionary = {"type": type, "intent": {"id": fields[0]}}
			var effect: Dictionary = {"action_type": fields[1] if fields.size() > 1 else "move_toward"}
			expect.call(Action.clip_for(effect, actor) == clip, type + ": exact selector " + selector)
		for view: String in ["front", "rear"]:
			var rig: Node2D = renderer.rigs[view]
			var before: Dictionary = {}
			rig.apply_pose(clip, 0.0)
			for bone: String in rig.bones: before[bone] = (rig.bones[bone] as Bone2D).transform
			var changed: bool = false
			for sample: float in [0.15, 0.3, 0.5, 0.7, 0.9]:
				rig.apply_pose(clip, sample)
				for bone: String in rig.bones:
					var node: Bone2D = rig.bones[bone]
					changed = changed or node.transform != before[bone]
					expect.call(node.transform.is_finite(), type + ": finite " + view + "/" + clip + "/" + bone)
			expect.call(changed, type + ": independently articulated " + view + "/" + clip)
		if data["clips"][clip].has("contact"):
			var contact: float = float(data["clips"][clip]["contact"])
			expect.call(is_equal_approx(Action.contact_phase(0.4, 0.4, contact), contact), type + ": gameplay contact remaps exactly")
	for delta: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		renderer.present({"clip": "move", "phase": 0.5, "direction": delta, "step_distance_px": 96.0}, false)
		var expected: Dictionary = renderer.Facing.direction_for_delta(delta)
		expect.call(renderer.facing == expected["facing"] and renderer.mirrored == expected["mirrored"], type + ": correct front/rear/reflection")
		expect.call(renderer.texture() == texture, type + ": facing/action retains live texture")
		expect.call(renderer.snapshot()["rig_count"] == 2, type + ": same renderer owns front/rear")
	renderer.present({}, false)
	var before_phase: float = renderer.snapshot()["phase"]
	var idle_rig: Node2D = renderer.rigs[renderer.facing]
	var before_bones: Dictionary = {}
	for bone: String in idle_rig.bones: before_bones[bone] = idle_rig.bones[bone].transform
	renderer._process(float(data["clips"]["idle"]["seconds"]) * 0.25)
	expect.call(float(renderer.snapshot()["phase"]) > before_phase, type + ": production idle advances elapsed phase")
	var idle_changed: bool = false
	for bone: String in idle_rig.bones: idle_changed = idle_changed or idle_rig.bones[bone].transform != before_bones[bone]
	expect.call(idle_changed, type + ": production idle applies changing bone poses")
	renderer.present({"clip": "strike" if type == "lightning_wisp" else "burst", "phase": 0.4}, true)
	var shown: Node2D = renderer.rigs[renderer.facing]
	var still: Dictionary = {}
	for bone: String in shown.bones: still[bone] = shown.bones[bone].transform
	renderer._process(1.0)
	for bone: String in shown.bones: expect.call(shown.bones[bone].transform == still[bone], type + ": reduced motion freezes " + bone)
	var anchor: Texture2D = board._unit_hud_anchor_texture(state["enemies"][0])
	var creature: String = Action.Presentation.CREATURES[type]
	expect.call(str(anchor.get_meta("asset_source_path", "")) == "res://assets/units/" + creature + "_cutout/front/rest.png", type + ": HUD/shadow use approved rest")
	# Build before tree entry, as RunScene does, then observe deferred renderer
	# readiness. Defeat must dissolve the same live portrait that was displayed.
	var portrait_host := Control.new()
	var portrait := TextureRect.new()
	portrait_host.add_child(portrait)
	portrait_host.set_meta("turn_order_portrait_texture", anchor)
	preload("res://scripts/maquette_cutout_runtime/portrait.gd").bind(portrait, type, false, true)
	tree.root.add_child(portrait_host)
	await tree.process_frame
	expect.call(portrait.texture is AtlasTexture and (portrait.texture as AtlasTexture).atlas is ViewportTexture, type + ": portrait uses production renderer")
	expect.call(portrait_host.get_meta("turn_order_portrait_texture") == portrait.texture, type + ": deferred portrait defeat retains the live atlas")
	portrait_host.queue_free()
	var rig: Node2D = renderer.rigs["front"]
	_check_channel_math(rig, renderer, type, expect)
	if type == "lightning_wisp":
		for part: Dictionary in rig.layout["parts"]:
			if part.get("logical_part", "") in ["arc_left", "arc_right", "crown"]: expect.call(part["bone"] == "core", "Wisp painted veins remain on core")
	else:
		rig.apply_pose("idle", 0.5)
		expect.call((rig.bones["root"] as Bone2D).transform == rig.rest_transforms["root"], "Shale idle root remains planted")
	var dying: Dictionary = state["enemies"][0].duplicate(true)
	dying.merge({"death_animation": true, "death_progress": 0.6}, true)
	state["enemies"][0]["hp"] = 0
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"death_animation_units": [dying], type + "_motion": {"enemy_1": {"clip": "death", "phase": 0.6}}})
	expect.call(renderer.snapshot()["clip"] == "death", type + ": terminal death uses same renderer")
	var facing: String = renderer.facing
	renderer.present({"clip": "idle", "direction": Vector2i(1, 0)}, false)
	expect.call(renderer.snapshot()["clip"] == "death" and renderer.facing == facing, type + ": terminal pose/orientation held")
	board.queue_free()
	await tree.process_frame
	await preload("movement_suite.gd").run(tree, expect, type)

static func fixture(type: String) -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8): row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var definition: Dictionary = GameData.enemy_def(type)
	var hp: int = int(definition.get("max_hp", 20))
	return {"grid": grid, "room_coord": Vector2i(4, 3), "terrain": [], "traps": [], "loot": [],
		"player": {"pos": Vector2i(4, 3), "hp": 40, "max_hp": 40},
		"enemies": [{"id": 1, "type": type, "pos": Vector2i(3, 3), "hp": hp, "max_hp": hp}]}

static func _check_channel_math(rig: Node2D, renderer: Node, type: String, expect: Callable) -> void:
	var path: String = "res://assets/units/" + str(Action.Presentation.CREATURES[type]) + "_cutout/compiled_motion.json"
	var original: Dictionary = Motion._cache[path]
	var fixture: Dictionary = original.duplicate(true)
	fixture["clips"]["proof_channels"] = {"seconds": 1.0}
	for view: String in ["front", "rear"]:
		var tracks: Array = []
		for item: Array in [["root", "alpha", 0.5], ["core", "alpha", 0.4], ["core", "squash", 0.8], ["core", "scale", 1.1]]:
			tracks.append({"bone": item[0], "channel": item[1], "forward_mode": "pixels", "keys": [{"at": 0.0, "value": item[2], "interpolation": "hold"}]})
		fixture["view_tracks"][view]["proof_channels"] = tracks
	Motion._cache[path] = fixture
	rig.apply_pose("proof_channels", 0.5)
	expect.call(is_equal_approx(rig.bones["root"].modulate.a, 0.5) and is_equal_approx(rig.bones["core"].modulate.a, 0.4), type + ": body and part alpha reach actual bones")
	expect.call(is_equal_approx((rig.bones["core"] as Bone2D).transform.determinant(), 1.21), type + ": squash preserves area before uniform scale")
	Motion._cache[path] = original
	rig.apply_pose("rest", 0.0)
