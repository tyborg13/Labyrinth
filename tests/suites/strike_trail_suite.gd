extends RefCounted
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Hero = preload("res://scripts/hero_strike_trail.gd")
const Renderer = preload("res://scripts/protagonist_cutout/renderer.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/helpers/strike_trail_fixture.gd")
const Layers = preload("res://scripts/protagonist_cutout/gear_layers.gd")
const LOADOUTS: Dictionary = Fixture.LOADOUTS

static func run(tree: SceneTree, expect: Callable) -> void:
	_check_geometry(expect)
	var renderer := Renderer.new()
	tree.root.add_child(renderer)
	await tree.process_frame
	renderer.set_process(false)
	for motion: String in LOADOUTS:
		renderer.set_gear({"weapon": LOADOUTS[motion]})
		var settings: Dictionary = Trail.motion_settings(motion)
		var window: Vector2 = settings["window"]
		for direction: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			renderer.present({"clip": "attack", "phase": 0.42, "direction": direction}, false)
			var rig: Node2D = renderer.rigs[renderer.facing]
			var before: Dictionary = {}
			for bone: String in rig.bones:
				before[bone] = rig.bones[bone].transform
			var samples: Array[Dictionary] = renderer.strike_samples(direction, window.x, window.y, Trail.SAMPLE_STEP)
			var single: Array[Dictionary] = renderer.strike_samples(direction, 0.42, 0.42, Trail.SAMPLE_STEP)
			var joint: Vector2 = Motion._joint_position(rig.layout, "weapon_r")
			var tip: Vector2 = rig.to_local(rig.bones["weapon_r"].to_global(Motion._gear_vector(rig.layout["weapon_grip"]["tip"]) - joint))
			var grip: Vector2 = renderer.weapon_grip_source()
			if renderer.mirrored:
				tip.x = 255.0 - tip.x
			expect.call((single[0]["tip"] as Vector2).distance_to(tip) <= 0.5, "Contact tip matches live socket for " + motion + "/" + str(direction))
			expect.call((Trail.sample_at(samples, 0.42)["tip"] as Vector2).distance_to(tip) <= 0.5, "240Hz contact interpolation matches live socket for " + motion + "/" + str(direction))
			expect.call((single[0]["inner"] as Vector2).distance_to(tip.lerp(grip, settings["reach"])) <= 0.5, "Inner landmark uses the approved reach for " + motion)
			expect.call(samples[0]["progress"] == window.x and is_equal_approx(samples[-1]["progress"], window.y), "Sampling includes both strike-window endpoints")
			for index: int in range(1, samples.size()):
				expect.call(float(samples[index]["progress"]) - float(samples[index - 1]["progress"]) <= Trail.SAMPLE_STEP + 0.000001, "Sampling cadence is at least 240Hz")
			for bone: String in before:
				expect.call(before[bone] == rig.bones[bone].transform, "Sampling never changes live rig bones")
			var expected_kind: String = "streak" if motion in ["stab", "thrust"] else "sweep"
			expect.call(settings["kind"] == expected_kind, "Motion dispatch: " + motion)
			expect.call(not Trail.geometry(samples, expected_kind, 0.42, 0.42, window, "none", 1.0, 11, settings["length"]).is_empty(), "Every motion emits contact geometry")
			if motion == "thrust":
				for phase: float in [0.0, 0.19, 0.20, 0.42, 0.62, 0.63, 0.85]:
					renderer.present({"clip": "attack", "phase": phase, "direction": direction}, false)
					var wanted: int = 5 if renderer.facing == "rear" else 38 if phase >= 0.20 and phase <= 0.62 else 8
					expect.call(rig._gear_base_parts["weapon_r"]["node"].z_index == wanted, "Spear depth follows level/carry window and preserves rear")
					expect.call(rig._gear_layers.grip.visible and rig._gear_layers.grip.z_index == 66 and rig._gear_layers.fingers.z_index == 67, "Spear grip stays above palm and under fingers")
	renderer.queue_free()
	await tree.process_frame
	await _check_dispatch(tree, expect)
	print("STRIKE TRAIL CONTRACTS: 7 motions, 4 directions; sampling/envelope/palettes/sparks/dispatch/depth checked")

static func _check_geometry(expect: Callable) -> void:
	var window := Vector2(0.33, 0.56)
	var samples: Array[Dictionary] = Trail.arc_samples(Vector2.ZERO, Vector2(80, 20), 1.0, window)
	for kind: String in ["sweep", "streak", "rake", "arc"]:
		for progress: float in [0.0, 0.329, 0.33, 0.62, 0.9]:
			expect.call(Trail.geometry(samples, kind, progress, 0.42, window, "none", 1.0, 11).is_empty(), "No trail before the window or after the fade: " + kind)
		var contact: Array[Dictionary] = Trail.geometry(samples, kind, 0.42, 0.42, window, "none", 1.0, 11)
		expect.call(contact.size() == 2, "Every kind batches glow and core into two triangle submissions")
		expect.call(contact == Trail.geometry(samples, kind, 0.42, 0.42, window, "none", 1.0, 11), "Geometry including sparks is deterministic")
		for batch: Dictionary in contact:
			expect.call(batch["vertices"].size() == batch["colors"].size() and batch["indices"].size() % 3 == 0, "Trail uses vertex-colored triangles")
			for index: int in batch["indices"]:
				expect.call(index >= 0 and index < batch["vertices"].size(), "Triangle topology stays in range")
	expect.call(Trail.envelope(0.42, window) == 1.0, "Envelope peaks at unchanged .42 contact")
	for progress: float in [0.34, 0.36, 0.40, 0.46, 0.52, 0.57, 0.61]:
		expect.call(Trail.envelope(progress, window) > 0.0 and Trail.envelope(progress, window) < 1.0, "Envelope fades toward and away from contact")
	var visible: Array[Dictionary] = Trail.visible_samples(samples, 0.46, window)
	expect.call(is_equal_approx(visible[0]["progress"], 0.36) and is_equal_approx(visible[-1]["progress"], 0.46), "Tail spans exactly .10 effect progress")
	var expected: Dictionary = {
		"none": [Color8(255,244,220), Color8(255,178,92), Color8(150,60,20)],
		"fire": [Color8(255,236,200), Color8(255,128,48), Color8(170,40,10)],
		"ice": [Color8(236,250,255), Color8(140,210,255), Color8(40,90,150)],
		"lightning": [Color8(248,240,255), Color8(186,150,255), Color8(80,50,170)],
		"air": [Color8(240,255,246), Color8(150,230,200), Color8(40,110,90)],
		"earth": [Color8(255,240,214), Color8(214,160,96), Color8(110,70,30)]}
	for element: String in expected:
		expect.call(Trail.palette(element) == expected[element], "Exact owner palette: " + element)
	var sparks: Array[Dictionary] = Trail.sparks(samples, 0.42, window, 1.0, 11)
	expect.call(not sparks.is_empty() and sparks == Trail.sparks(samples, 0.42, window, 1.0, 11), "Identical inputs reproduce ember sparks")
	expect.call(sparks != Trail.sparks(samples, 0.42, window, 1.0, 12), "Effect seed changes ember sparks")
	var scaled: Array[Dictionary] = Trail.arc_samples(Vector2.ZERO, Vector2(160, 40), 2.0, window)
	expect.call((scaled[0]["tip"] as Vector2).distance_to((samples[0]["tip"] as Vector2) * 2.0) < 0.001, "Synthetic arc scales in source pixels")
	expect.call(Trail.motion_settings("sword")["reach"] == 0.55 and Trail.motion_settings("heavy")["reach"] == 0.50 and Trail.motion_settings("lash")["reach"] == 0.09, "Approved crescent reaches")
	expect.call(Trail.motion_settings("stab")["length"] == 48.0 and Trail.motion_settings("thrust")["length"] == 74.0, "Approved streak lengths")

static func _check_dispatch(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	var state: Dictionary = Fixture.state()
	var player: Vector2i = state["player"]["pos"]
	var effect: Dictionary = {"kind": "melee", "protagonist_melee": true, "protagonist_weapon_motion": "sword", "from": player, "to": player + Vector2i(0, 1), "element": "fire"}
	board.set_combat_state(state, [], [], Vector2i(-1,-1), "", "", {}, {}, {"effect": effect, "effect_progress": 0.42})
	expect.call(board.get("_strike_trail_layer") == null, "Detached submissions never create a duplicate root light")
	tree.root.add_child(board)
	await tree.process_frame
	var helper: RefCounted = board.get("_hero_strike_trail")
	var count: int = helper.sample_build_count
	var batches: Array[Dictionary] = helper.prepare(board, effect, 0.46)
	expect.call(not batches.is_empty() and helper.sample_build_count == count, "Retained redraw reuses source samples per effect")
	var retained: Control = board.get("_effects_render_layer")
	expect.call(retained.get("_hero_strike_trail") == helper, "Retained effects layer shares the source cache")
	var light: Node2D = retained.get("_strike_trail_layer")
	expect.call((light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and light.show_behind_parent and light.z_index == 0, "Dedicated additive light stays below floating/status text")
	board.presentation["reduced_motion"] = true
	expect.call(helper.prepare(board, effect, 0.42).is_empty(), "Reduced motion emits no trail")
	board.presentation["reduced_motion"] = false
	var echo: Dictionary = {"kind": "melee", "illusion_echo": true, "from": player, "to": player + Vector2i(0, 1), "element": "ice"}
	expect.call(Hero.handles(echo) and not helper.prepare(board, echo, 0.42).is_empty(), "Illusion echo uses a tinted synthetic arc without an attack rig")
	expect.call(not Hero.handles({"kind": "melee", "crawler_melee": true}) and not Hero.handles({"kind": "push"}), "Enemy and force dispatch stays on legacy paths")
	retained._sync_strike_trail({}, 1.0)
	expect.call(light.get("_batches").is_empty(), "Ending an effect clears retained trail geometry")
	board.queue_free()
	await tree.process_frame
