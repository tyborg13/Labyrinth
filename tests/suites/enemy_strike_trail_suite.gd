extends RefCounted
const Points = preload("res://scripts/enemy_strike_points.gd")
const EnemyTrail = preload("res://scripts/enemy_strike_trail.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/helpers/enemy_strike_fixture.gd")
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
const Geometry = preload("res://scripts/enemy_strike_geometry.gd")
const ClawMarks = preload("res://scripts/enemy_claw_marks.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const SourceCache = preload("res://scripts/enemy_strike_cache.gd")
const HeroTrail = preload("res://scripts/hero_strike_trail.gd")
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
	await _check_target_effects(tree, expect)
	await _check_cache(tree,expect)
	_check_feedback_boundaries(expect)
	_check_claw_profile(expect)
	print("ENEMY STRIKE TRAIL CONTRACTS: registry, live front/rear/mirrored contacts, cache, bespoke exclusions, reduced motion and per-tile area rakes checked")

static func _check_claw_profile(expect: Callable) -> void:
	var colors: Array = Trail.palette("none")
	var contact: Dictionary = ClawMarks.geometry(Vector2.ZERO,Vector2.RIGHT,colors,1.0,0.9,false,0.42)
	var full: Dictionary = ClawMarks.geometry(Vector2.ZERO,Vector2.RIGHT,colors,1.0,0.9,false,0.44)
	expect.call(is_equal_approx(_core_energy(contact) / (0.9 * 0.9),228.2175), "Three contact claws have the specified integrated alpha and tapered area")
	expect.call(is_equal_approx(_core_energy(full) / (0.9 * 0.9),260.82), "The middle claw is 15 percent longer; each middle width is 3.6 source px")
	expect.call(_core_energy(ClawMarks.geometry(Vector2.ZERO,Vector2.RIGHT,colors,1.0,0.9,false,0.36)) == 0.0, "Rake reveal starts at .36")
	expect.call(_core_energy(ClawMarks.geometry(Vector2.ZERO,Vector2.RIGHT,colors,1.0,0.9,false,0.40)) < _core_energy(contact), "Rake geometry reveals progressively through .44")
	expect.call(full == ClawMarks.geometry(Vector2.ZERO,Vector2.RIGHT,colors,1.0,0.9,false,0.48), "Rake holds its full geometry after .44")
	var glow: Dictionary = ClawMarks.geometry(Vector2.ZERO,Vector2.RIGHT,colors,1.0,0.9,true,0.44)
	expect.call(is_equal_approx(_area(glow) / _area(full),3.0) and is_equal_approx(_core_energy(glow) / _core_energy(full),0.525), "Rake glow is three times the width with .35 centre alpha and clear edges")

static func _area(batch: Dictionary) -> float:
	var total: float = 0.0
	var points: PackedVector2Array = batch["vertices"]
	var indices: PackedInt32Array = batch["indices"]
	for i: int in range(0,indices.size(),3):
		total += absf((points[indices[i+1]]-points[indices[i]]).cross(points[indices[i+2]]-points[indices[i]])) * 0.5
	return total

static func _core_energy(batch: Dictionary) -> float:
	var total: float = 0.0
	var points: PackedVector2Array = batch["vertices"]
	var colors: PackedColorArray = batch["colors"]
	var indices: PackedInt32Array = batch["indices"]
	for i: int in range(0,indices.size(),3):
		var a: int = indices[i]
		var b: int = indices[i+1]
		var c: int = indices[i+2]
		total += absf((points[b]-points[a]).cross(points[c]-points[a])) * 0.5 * (colors[a].a+colors[b].a+colors[c].a) / 3.0
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
		var source: Dictionary = EnemyTrail.actor(board,effect)
		expect.call(is_equal_approx(Geometry.size_scale(board,source),board.protagonist_source_pixel_scale() * clampf(float(board.call("_unit_art_scale",source)),0.9,1.6)), "Enemy light uses the specified art-scale clamp: " + type)
		if type == "crawler":
			var scale: float = board.protagonist_source_pixel_scale() * 0.9
			var energy: float = _core_energy(batches[1]) / (scale * scale)
			print("CRAWLER CONTACT CORE ALPHA AREA: %.3f source px squared (minimum 180)" % energy)
			expect.call(energy > 180.0, "Small Crawler rake has bold contact geometry, independently of the glint")
			expect.call(Trail.geometry(Geometry.samples_for(cache.resolved),"claw_marks",0.35,0.42,Vector2(0.36,0.66),"none",scale,11).is_empty(), "Claw swipe is hidden before .36")
		if type in ["chainbound_gaoler","ashen_reaver","storm_cantor"]:
			_check_fallback(board,effect,expect)
		for progress: float in [0.40,0.42,0.48]:
			board.set_combat_state(state_value,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation(type,state_value,effect,progress))
			expect.call(Fixture.check_pose(board.unit_cutout_renderer(EnemyTrail.actor(board,effect)),type,effect,state_value,progress), "Probe motion matches the gameplay action and authored phase: %s at %.2f" % [type,progress])
		batches = cache.prepare(board,effect,0.42)
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
			var children: int = layer.get_child_count()
			var light_id: int = (layer.get("_strike_trail_layer") as Node2D).get_instance_id()
			layer.call("_draw_elemental_scene_depth_pass",tile,true)
			var light: Node2D = layer.get("_strike_trail_layer")
			expect.call(layer.get_child_count() == children and light.get_instance_id() == light_id, "Area drawing reuses the light created with its front-effect layer")
			expect.call(light.instrumentation_section == "scene_tile_effects", "Area light draw time belongs to scene-tile effects")
			expect.call(is_instance_valid(light) and light.get("_batches") == batches, "Production target depth layer submits its own rake")
			if is_instance_valid(light):
				expect.call((light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Area rake uses the approved additive pass")
		prior = batches
	expect.call(EnemyTrail.area_rake(board,area,Vector2i(0,0),0.42).is_empty(), "Dragon area does not draw outside its declared tiles")
	board.presentation["reduced_motion"] = true
	var static_mark: Array[Dictionary] = EnemyTrail.area_rake(board,area,area["to"],0.42)
	expect.call(not static_mark.is_empty() and _core_energy(static_mark[1]) > 0.0, "Reduced physical area retains a fully revealed static claw mark")
	for progress: float in [0.0,0.20,0.48,0.90,1.0]:
		expect.call(EnemyTrail.area_rake(board,area,area["to"],progress) == static_mark, "Reduced physical claw marks do not animate or fade")
	print("REDUCED DRAGON AREA: static fully revealed claw marks; PASS")
	for tile: Vector2i in area["tiles"]:
		var layer: Control = layers.get(tile)
		if is_instance_valid(layer):
			layer.call("_draw_elemental_scene_depth_pass",tile,true)
			expect.call((layer.get("_strike_trail_layer") as Node2D).get("_batches") == EnemyTrail.area_rake(board,area,tile,0.42), "Reduced physical-area depth layer submits its static mark")
	for tile: Vector2i in area["tiles"]:
		var layer: Control = layers.get(tile)
		if is_instance_valid(layer):
			layer.presentation["effect"] = {}
			layer.call("_draw_elemental_scene_depth_pass",tile,true)
			var light: Node2D = layer.get("_strike_trail_layer")
			expect.call(not is_instance_valid(light) or light.get("_batches").is_empty(), "A completed area clears its retained light")
	board.queue_free()
	await tree.process_frame

static func _check_fallback(board: Control, effect: Dictionary, expect: Callable) -> void:
	var source: Dictionary = EnemyTrail.actor(board,effect)
	var type: String = source["type"]
	var renderer: Node = board.unit_cutout_renderer(source)
	var body: Rect2 = board.call("_unit_draw_rect_for_center",source,board.call("_unit_center",source))
	var scale: float = Geometry.size_scale(board,source)
	var settings_value: Dictionary = Points.settings(type,effect)
	var samples: Array[Dictionary] = Points.samples(renderer,source,effect,Vector2i(0,1),settings_value,0.42)
	var target: Vector2 = EnemyTrail.target_center(board,effect["to"])
	if type == "storm_cantor":
		var cache: RefCounted = board.get("_enemy_strike_trail")
		for delta: Vector2i in DIRECTIONS:
			var state_value: Dictionary = Fixture.state(type,delta)
			var facing_effect: Dictionary = Fixture.effect(type,state_value)
			board.set_combat_state(state_value,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation(type,state_value,facing_effect,0.42))
			for progress: float in [0.40,0.42,0.48]:
				cache.prepare(board,facing_effect,progress)
				var resolved: Dictionary = cache.resolved
				expect.call(rad_to_deg(absf((resolved["direction"] as Vector2).angle_to(resolved["target_direction"]))) <= Geometry.AXIS_LIMIT, "Storm Cantor streak points within 50 degrees of its target in every view")
		# Restore the caller's board fixture.
		var state_value: Dictionary = Fixture.state(type,Vector2i(0,1))
		board.set_combat_state(state_value,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation(type,state_value,effect,0.42))
		return
	# Real attack motion is much longer than the almost stationary review art:
	# the replacement Gaoler fist spans 87px, and Ashen's blade spans 158px.
	# Preserve those paths; exercise the fallback with the old Gaoler chain
	# fixture and an Ashen held-contact fixture rather than forcing a false hit.
	var real_span: float = Geometry.path_span(samples) * body.size.x / 255.0 / scale
	expect.call(real_span > Geometry.SHORT_PATH, "The moving authored strike is not incorrectly classified as short: " + type)
	var short_samples: Array[Dictionary]
	if type == "chainbound_gaoler":
		var chain: Dictionary = {"kind":"streak","bone":"hook","landmark":"chain_tip","inner_bone":"hand_hook","window":settings_value["window"],"reach":0.09}
		short_samples = Points.samples(renderer,source,effect,Vector2i(0,1),chain,0.42)
	else:
		var point: Dictionary = Trail.sample_at(samples,0.42)
		for sample: Dictionary in samples:
			short_samples.append({"progress":sample["progress"],"tip":point["tip"],"inner":point["inner"]})
	for sample: Dictionary in short_samples:
		sample["tip"] = body.position + (sample["tip"] as Vector2) * body.size / 255.0
		sample["inner"] = body.position + (sample["inner"] as Vector2) * body.size / 255.0
	var resolved: Dictionary = Geometry.resolve(short_samples,settings_value["kind"],body.get_center(),target,scale,0.42,settings_value["window"])
	expect.call(resolved["fallback"], "Short-path fallback triggers for the review fixture: " + type)
	var adapted: Array[Dictionary] = Geometry.samples_for(resolved)
	expect.call((Trail.sample_at(adapted,0.42)["tip"] as Vector2).distance_to(Trail.sample_at(short_samples,0.42)["tip"]) < 0.0001, "Fallback retains the real contact landmark anchor: " + type)
	expect.call(resolved["kind"] == ("streak" if type == "chainbound_gaoler" else "arc"), "Short streak stays a streak; short sweep becomes an arc: " + type)
	if type == "chainbound_gaoler":
		expect.call((resolved["direction"] as Vector2).dot(resolved["target_direction"]) > 0.999, "Short punch aims from its contact anchor toward the target body")
	else:
		expect.call(_area(Trail.geometry(adapted,"arc",0.42,0.42,settings_value["window"],"none",scale,11)[1]) > 0.0, "Stationary Ashen landmark still draws a visible sweep arc")
	print("ENEMY SHORT-PATH FIXTURE %s: %.3f source px; authored strike %.3f source px" % [type,resolved["span"] / scale,real_span])

static func _check_target_effects(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920,1080)
	tree.root.add_child(board)
	await tree.process_frame
	for type: String in ["harrier","frostglass_lancer","bell_tender","storm_cantor","chainbound_gaoler"]:
		for delta: Vector2i in DIRECTIONS:
			var state_value: Dictionary = Fixture.state(type,delta)
			var effect: Dictionary = Fixture.effect(type,state_value)
			board.set_combat_state(state_value,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation(type,state_value,effect,0.42))
			var cache: RefCounted = board.get("_enemy_strike_trail")
			cache.prepare(board,effect,0.42)
			var resolved: Dictionary = cache.resolved
			var target: Vector2 = EnemyTrail.target_center(board,effect["to"])
			var width: float = board.call("_tile_width")
			var far: bool = (resolved["strike_point"] as Vector2).distance_to(target) > 0.6 * width
			expect.call(resolved["target_anchor"] == far, "Every enemy streak applies the .6-tile contact-distance rule: " + type)
			var adapted: Array[Dictionary] = Geometry.samples_for(resolved)
			var tip: Vector2 = Trail.sample_at(adapted,Points.contact(effect))["tip"]
			expect.call(tip.distance_to(target if far else resolved["strike_point"]) < 0.0001, "Streak contact leads at the target when far; near landmarks stay unchanged: " + type)
			if far:
				var source: Dictionary = EnemyTrail.actor(board,effect)
				var body: Rect2 = board.call("_unit_draw_rect_for_center",source,board.call("_unit_center",source))
				expect.call((resolved["direction"] as Vector2).dot((target-body.get_center()).normalized()) > 0.999, "Relocated streak aims attacker to target: " + type)
			if type == "storm_cantor" and delta == Vector2i(0,1):
				expect.call(far and tip.distance_to(target) < 0.0001, "Storm Cantor's raised front spear produces a streak on the hero")
	for entry: Array in [["lightning_wisp",""],["warden","push"],["ashen_reaver","guardian_area"]]:
		for delta: Vector2i in DIRECTIONS:
			var state_value: Dictionary = Fixture.state(entry[0],delta)
			var effect: Dictionary = Fixture.effect(entry[0],state_value,entry[1])
			var live_tips: Array[Dictionary]
			for progress: float in [0.40,0.42,0.48]:
				board.set_combat_state(state_value,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation(entry[0],state_value,effect,progress))
				var cache: RefCounted = board.get("_enemy_strike_trail")
				var batches: Array[Dictionary] = cache.prepare(board,effect,progress)
				var echo: Dictionary = {"kind":"melee","illusion_echo":true,"from":effect["from"],"to":effect["to"],"element":"none","seed":11}
				var reference: Array[Dictionary] = HeroTrail.new().prepare(board,echo,progress)
				var ratio: float = _core_energy(batches[1]) / _core_energy(reference[1])
				expect.call(ratio >= 0.8, "Enemy arc has at least .8 times the echo's integrated core alpha/area: " + entry[0])
				var source: Dictionary = EnemyTrail.actor(board,effect)
				var scale: float = Geometry.size_scale(board,source)
				var samples: Array[Dictionary] = Trail.arc_samples(board.world_position_for_tile(effect["from"]),board.world_position_for_tile(effect["to"]),scale,Geometry.ARC_WINDOW)
				var exact: Array[Dictionary] = Trail.geometry(samples,"arc",progress,Trail.CONTACT,Geometry.ARC_WINDOW,"none",scale,11)
				expect.call(batches == exact, "Enemy target arc uses exactly the echo construction, brightness and fade: " + entry[0])
				if progress == 0.42 and delta == Vector2i(0,1): print("ENEMY/ECHO ARC CORE ALPHA AREA %s: %.3fx (minimum .8x)" % [entry[0],ratio])
				if entry[0] == "ashen_reaver":
					var renderer: Node = board.unit_cutout_renderer(source)
					expect.call(Fixture.check_pose(renderer,entry[0],effect,state_value,progress), "Ashen area capture uses the gameplay strike pose")
					var rig: Node = renderer.rigs[renderer.facing]
					var settings_value: Dictionary = Points.settings(entry[0],effect)
					var bind: Array = rig.layout["joints"]["blade"]["position"]
					var tip: Vector2 = (rig.global_transform as Transform2D).affine_inverse() * (rig.bones["blade"] as Bone2D).global_transform * (Points.bind_point(rig.layout,settings_value,renderer.facing)-Vector2(bind[0],bind[1]))
					live_tips.append({"tip":tip})
					expect.call(cache.resolved.get("reason","") == "held_contact" and cache.resolved["kind"] == "arc", "Ashen's held area-contact blade gets a visible arc at the target")
			if entry[0] == "ashen_reaver":
				var span: float = Geometry.path_span(live_tips)
				expect.call(span > 0.0 and span < Geometry.SHORT_PATH, "Displayed Ashen blade moves slightly, but its reviewed contact/follow-through is short")
				if delta in [Vector2i(0,1),Vector2i(0,-1)]: print("ASHEN DISPLAYED AREA BLADE SPAN %s: %.3f source px" % [delta,span])
	board.queue_free()
	await tree.process_frame

class UnreadyRenderer:
	extends Node
	var rigs: Dictionary = {}
	static func direction_for_delta(delta: Vector2i) -> Dictionary:
		return preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(delta)

static func _check_cache(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920,1080)
	tree.root.add_child(board)
	await tree.process_frame
	for type: String in ["harrier","crawler","warden","chainbound_gaoler","ashen_reaver","storm_cantor","zekarion","iskaldra"]:
		var state: Dictionary = Fixture.state(type,Vector2i(0,1))
		var effect: Dictionary = Fixture.effect(type,state)
		board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},Fixture.presentation(type,state,effect,0.42))
		var cache: RefCounted = board.get("_enemy_strike_trail")
		cache.prepare(board,effect,0.42)
		var builds: int = cache.sample_build_count
		var resolutions: int = cache.resolution_build_count
		var again: Dictionary = effect.duplicate(false)
		again["element"] = "ice"
		again["seed"] = 99
		cache.prepare(board,again,0.42)
		expect.call(cache.sample_build_count == builds, "Same facing with a new element/seed must not resample: " + type)
		expect.call(cache.resolution_build_count == resolutions, "Same source/target reuses resolved source geometry: " + type)
		var repeat: Array[Dictionary] = cache.prepare(board,again,0.48)
		expect.call(repeat == cache.prepare(board,again,0.48) and cache.resolution_build_count == resolutions, "Per-frame geometry is deterministic without re-resolving: " + type)
		var rear_state: Dictionary = Fixture.state(type,Vector2i(0,-1))
		var rear: Dictionary = Fixture.effect(type,rear_state)
		rear["action_direction"] = Vector2i(0,-1)
		# Sampling follows the requested renderer direction, not its last pose.
		cache.prepare(board,rear,0.42)
		expect.call(cache.sample_build_count == builds+1, "A new enemy facing samples once: " + type)
		cache.prepare(board,rear,0.48)
		expect.call(cache.sample_build_count == builds+1, "Enemy rear cache survives follow-through: " + type)
		var hidden: RefCounted = EnemyTrail.new()
		for progress: float in [0.0,0.20,0.90,1.0]:
			expect.call(hidden.prepare(board,effect,progress).is_empty(), "Zero envelope returns no enemy geometry: " + type)
		expect.call(hidden.sample_build_count == 0 and hidden.resolution_build_count == 0, "Zero envelope skips sampling and resolution: " + type)
		# Framing invalidates projection without resampling authored motion.
		board._navigation_zoom *= 0.9
		board._navigation_pan += Vector2(8,-5)
		board._invalidate_board_layout_cache()
		var projected: Array[Dictionary] = cache.prepare(board,effect,0.42)
		var fresh: RefCounted = EnemyTrail.new()
		expect.call(projected == fresh.prepare(board,effect,0.42), "Cached source resolution reprojects identically to a fresh attack after framing: " + type)
		expect.call(cache.sample_build_count == builds+1, "Zoom/pan never resamples enemy poses: " + type)
		if type == "crawler":
			expect.call(hidden.prepare(board,effect,0.35).is_empty() and hidden.sample_build_count == 0, "Claw's effective .36 start skips sampling")
			again = effect.duplicate(false)
			again["intent_id"] = "lunge"
			cache.prepare(board,again,0.42)
			expect.call(cache.sample_build_count == builds+2, "Crawler attack variants retain separate authored samples")
		if type == "iskaldra":
			var source: Dictionary = EnemyTrail.actor(board,effect)
			var far: Dictionary = effect.duplicate(false)
			far["to"] = source["pos"]+Vector2i(2,4)
			var renderer: Node = board.unit_cutout_renderer(source)
			var delta: Vector2i = Points.direction(effect,source,state["player"]["pos"])
			var far_delta: Vector2i = Points.direction(far,source,state["player"]["pos"])
			expect.call(renderer.direction_for_delta(delta) == renderer.direction_for_delta(far_delta), "Iskaldra distance fixture shares the same facing")
			var settings: Dictionary = Points.settings(type,effect)
			expect.call(Points.samples(renderer,source,effect,delta,settings,0.42) == Points.samples(renderer,source,far,far_delta,settings,0.42), "Iskaldra's talon authored pose is independent of target distance")
			cache.prepare(board,far,0.42)
			expect.call(cache.sample_build_count == builds+1, "Iskaldra target distance does not resample an unchanged authored pose")
	# Never cache a temporary empty result from a renderer still loading rigs.
	var unready := UnreadyRenderer.new()
	var source_cache := SourceCache.new()
	var source: Dictionary = {"type":"harrier"}
	var effect: Dictionary = {"kind":"melee"}
	var settings: Dictionary = Points.settings("harrier",effect)
	for i: int in range(2):
		expect.call(source_cache.entry(unready,source,effect,Vector2i(0,1),settings,0.42).is_empty(), "Unready rig returns no samples")
	expect.call(source_cache.sample_build_count == 2, "Empty samples remain retryable instead of entering the cache")
	unready.free()
	board.queue_free()
	await tree.process_frame
	print("ENEMY SOURCE CACHE: palettes/seeds, facing, variants, target distance, resolved reuse, zero envelopes and empty retries; PASS")

static func _check_feedback_boundaries(expect: Callable) -> void:
	var scene := RunScene.new()
	var effects: Array[Dictionary]
	var kinds: Array = ["","melee","ranged","aoe","lightning_strikes","push","pull","move","intent","intent_refresh","status","status_damage","heal","block","terrain_burst","summon","cinder_marks","detonate_cinders","raise_terrain","blink","chain","draw","discard","pickup","detonate","stoneskin","status_applied","surface_damage","terrain_created","actor_death","trap_triggered","surface_conducted","reinforcement_spawn","transition"]
	for kind: String in kinds:
		for element: String in ["none","fire","earth","air","lightning","ice"]:
			effects.append({"kind":kind,"element":element})
			effects.append({"kind":kind,"action_type":"ranged","range":2,"element":element})
	for type: String in ["vyraketh","tharokh","vaeloryx","iskaldra","zekarion","noctyrax"]:
		for kind: String in ["melee","ranged","aoe","lightning_strikes","terrain_burst"]:
			effects.append({"enemy_type":type,"kind":kind,"action_type":kind,"element":"fire"})
	for effect: Dictionary in effects:
		var expected: float = _previous_feedback_boundary(effect)
		expect.call(is_equal_approx(scene.call("_attack_feedback_start_progress",effect),expected), "Shared feedback preserves RunScene's previous boundary and precedence for " + str(effect))
		expect.call(is_equal_approx(Points.contact(effect),expected) and is_equal_approx(Fx.feedback_start_progress(effect),expected), "Enemy and RunScene feedback agree for every kind and dragon area")
	scene.free()
	print("SHARED ATTACK FEEDBACK: %d kind/element/dragon fixtures; PASS" % effects.size())

static func _previous_feedback_boundary(effect: Dictionary) -> float:
	# Frozen pre-refactor oracle, including the .52 dragon-area precedence.
	var dragon: Script = preload("res://scripts/dragon_presentation.gd")
	if dragon.area_fx(effect): return dragon.CONTACT
	if str(dragon.profile(effect).get("geometry","")) == "physical": return 0.42
	var style: String = Fx.style_for_effect(effect)
	if style != Fx.STYLE_DEFAULT: return Fx.travel_end_progress(style)
	match str(effect.get("kind","")):
		"melee": return 0.42
		"ranged": return 0.66
		"aoe", "lightning_strikes": return 0.38
		_: return 0.50
