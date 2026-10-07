extends RefCounted
const Points = preload("res://scripts/enemy_strike_points.gd")
const EnemyTrail = preload("res://scripts/enemy_strike_trail.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/helpers/enemy_strike_fixture.gd")
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
const DIRECTIONS: Array = [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]

static func run(tree: SceneTree, expect: Callable) -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for type: String in definitions:
		for intent: Dictionary in definitions[type].get("intents", []):
			for action: Dictionary in intent.get("actions", []):
				if str(action.get("type", "")) == "melee":
					expect.call(Points.REGISTRY.has(type) or type in Points.BESPOKE, "Every known melee type has an explicit registry decision: " + type)
					var settings_value: Dictionary = Points.settings(type, {"kind":"melee", "intent_id":intent["id"]})
					expect.call(str(settings_value["kind"]) in ["sweep","streak","rake","arc","bespoke"], "Melee intent resolves to a trail or retained bespoke effect: " + type)
	for type: String in Guardian.ACTOR_IDS:
		expect.call(Points.REGISTRY.has(type) and not str(Points.REGISTRY[type].get("reason", "")).is_empty(), "Every guardian has an explicit art-based choice and reason: " + type)
	for type: String in Points.REGISTRY:
		if Points.REGISTRY[type]["kind"] == "arc": continue
		var model: Script = Guardian if Guardian.handles(type) else Points.MODELS[type]
		var renderer: Node = model.new()
		if Guardian.handles(type): renderer.character_id = type
		tree.root.add_child(renderer)
		await tree.process_frame
		for delta: Vector2i in DIRECTIONS:
			var state_value: Dictionary = Fixture.state(type, delta)
			var effect: Dictionary = Fixture.effect(type, state_value)
			var source: Dictionary = state_value["enemies"][0]
			var settings_value: Dictionary = Points.settings(type, effect)
			var samples: Array[Dictionary] = Points.samples(renderer, source, effect, delta, settings_value, 0.42)
			var at_contact: Dictionary = Trail.sample_at(samples, 0.42)
			var motion: Dictionary = Fixture.presentation(type,state_value,effect,0.42)[Fixture.motion_field(type)]["enemy_1"]
			renderer.present(motion, false)
			var rig: Node2D = renderer.rigs[renderer.facing]
			var bone: Bone2D = rig.bones[settings_value["bone"]]
			# Compare with the actual displayed Bone2D, not another sampler call.
			var bind: Array = rig.layout["joints"][settings_value["bone"]]["position"]
			var point: Vector2 = Points.bind_point(rig.layout,settings_value,renderer.facing)
			var live: Vector2 = rig.global_transform.affine_inverse() * bone.global_transform * (point - Vector2(bind[0],bind[1]))
			if renderer.mirrored: live.x = 255.0-live.x
			if (at_contact["tip"] as Vector2).distance_to(live) >= 0.25:
				print("STRIKE CONTACT MISMATCH %s %s: sampled=%s live=%s error=%.4f" % [type,delta,at_contact["tip"],live,(at_contact["tip"] as Vector2).distance_to(live)])
			expect.call((at_contact["tip"] as Vector2).distance_to(live) < 0.25, "Strike contact follows the displayed bone, facing and mirror: " + type)
			var batches: Array[Dictionary] = Trail.geometry(samples,settings_value["kind"],0.42,0.42,settings_value["window"],"none",1.0,11,float(settings_value.get("length",48.0)))
			expect.call(not batches.is_empty() and _area(batches[1]) > 0.0, "Contact has luminous triangles: " + type)
			var visible: Array[Dictionary] = Trail.visible_samples(samples,0.42,settings_value["window"])
			var path := PackedVector2Array()
			for sample: Dictionary in visible: path.append(sample["tip"])
			expect.call((path[-1]-path[0]).length() > 0.5, "The real strike path moves independently of the glint: " + type)
			expect.call(Trail.geometry(samples,settings_value["kind"],0.20,0.42,settings_value["window"],"none",1.0,11).is_empty(), "No trail during preparation: " + type)
			expect.call(Trail.geometry(samples,settings_value["kind"],0.90,0.42,settings_value["window"],"none",1.0,11).is_empty(), "Trail fades before recovery: " + type)
		renderer.queue_free()
		await tree.process_frame
	await _check_board(tree, expect)
	print("ENEMY STRIKE TRAIL CONTRACTS: registry, live front/rear/mirrored contacts, cache, bespoke exclusions, reduced motion and per-tile area rakes checked")

static func _area(batch: Dictionary) -> float:
	var total: float = 0.0
	var points: PackedVector2Array = batch["vertices"]
	var indices: PackedInt32Array = batch["indices"]
	for i: int in range(0,indices.size(),3):
		total += absf((points[indices[i+1]]-points[indices[i]]).cross(points[indices[i+2]]-points[indices[i]])) * 0.5
	return total

static func _check_board(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920,1080)
	tree.root.add_child(board)
	await tree.process_frame
	for type: String in ["harrier","crawler","warden","chainbound_gaoler","ashen_reaver","storm_cantor","craghide","zekarion","lightning_wisp","acolyte","frostglass_lancer"]:
		var state_value: Dictionary = Fixture.state(type, Vector2i(0,1))
		var effect: Dictionary = Fixture.effect(type,state_value,"advance" if type == "frostglass_lancer" else "")
		board.set_combat_state(state_value,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation(type,state_value,effect,0.42))
		var cache: RefCounted = board.get("_enemy_strike_trail")
		var batches: Array[Dictionary] = cache.prepare(board,effect,0.42)
		expect.call(not batches.is_empty(), "Board dispatch draws enemy trail: " + type)
		var builds: int = cache.sample_build_count
		var repeated: Array[Dictionary] = cache.prepare(board,effect,0.42)
		expect.call(batches == repeated and cache.sample_build_count == builds, "Retained redraw reuses deterministic source samples: " + type)
		board.presentation["reduced_motion"] = true
		expect.call(cache.prepare(board,effect,0.42).is_empty(), "Reduced motion draws no enemy trail: " + type)
	for type: String in Points.BESPOKE:
		expect.call(not EnemyTrail.handles(board,{"kind":"melee","enemy_type":type}), "Bespoke enemy FX remain excluded: " + type)
	var state_value: Dictionary = Fixture.state("warden",Vector2i(0,1))
	var force: Dictionary = Fixture.effect("warden",state_value,"push")
	board.set_combat_state(state_value,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation("warden",state_value,force,0.42))
	expect.call(EnemyTrail.handles(board,force) and Points.settings("warden",force)["kind"] == "arc", "Adjacent enemy push uses an arc")
	force["to"] += Vector2i(0,2)
	expect.call(not EnemyTrail.handles(board,force), "Distant push preserves its ranged effect")
	state_value = Fixture.state("tharokh",Vector2i(0,1))
	var area: Dictionary = Fixture.effect("tharokh",state_value,"area")
	board.set_combat_state(state_value,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation("tharokh",state_value,area,0.42))
	await tree.process_frame
	expect.call(not EnemyTrail.handles(board,area), "Physical areas do not also draw in the global overlay")
	var prior: Array[Dictionary]
	var layers: Dictionary = board.get("_scene_front_effect_render_layers_by_tile")
	for tile: Vector2i in area["tiles"]:
		var batches: Array[Dictionary] = EnemyTrail.area_rake(board,area,tile,0.42)
		expect.call(not batches.is_empty() and _area(batches[1]) > 0.0 and batches != prior, "Dragon physical area gets a distinct luminous rake per tile")
		if not prior.is_empty():
			expect.call(batches[1]["vertices"][0] != prior[1]["vertices"][0], "Each area target changes the rake path itself, independently of spark seeds")
		var layer: Control = layers.get(tile)
		expect.call(is_instance_valid(layer), "Physical area retains its per-target depth layer")
		if is_instance_valid(layer):
			layer.call("_draw_elemental_scene_depth_pass",tile,true)
			var light: Node2D = layer.get("_strike_trail_layer")
			expect.call(is_instance_valid(light) and light.get("_batches") == batches, "Production target depth layer submits its own rake")
			if is_instance_valid(light):
				expect.call((light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Area rake uses the approved additive pass")
		prior = batches
	expect.call(EnemyTrail.area_rake(board,area,Vector2i(0,0),0.42).is_empty(), "Dragon area does not draw outside its declared tiles")
	board.presentation["reduced_motion"] = true
	expect.call(EnemyTrail.area_rake(board,area,area["to"],0.42).is_empty(), "Reduced motion draws no area rake")
	for tile: Vector2i in area["tiles"]:
		var layer: Control = layers.get(tile)
		if is_instance_valid(layer):
			layer.presentation["effect"] = {}
			layer.call("_draw_elemental_scene_depth_pass",tile,true)
			var light: Node2D = layer.get("_strike_trail_layer")
			expect.call(not is_instance_valid(light) or light.get("_batches").is_empty(), "A completed area clears its retained light")
	board.queue_free()
	await tree.process_frame
