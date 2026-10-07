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
	_check_streak_energy(expect)
	_check_arc_geometry(expect)
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
	expect.call(Trail.motion_settings("bow")["reach"] == 0.25 and Trail.motion_settings("repeater")["reach"] == 0.25, "Ranged-weapon bashes hug the limb tip")
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

static func _alpha_area(batch: Dictionary) -> float:
	# Exact integral of the linearly interpolated vertex alpha over each
	# triangle. This measures visible geometry, independently of its profile.
	var points: PackedVector2Array = batch["vertices"]
	var colors: PackedColorArray = batch["colors"]
	var indices: PackedInt32Array = batch["indices"]
	var total: float = 0.0
	for triangle: int in range(0, indices.size(), 3):
		var a: int = indices[triangle]
		var b: int = indices[triangle + 1]
		var c: int = indices[triangle + 2]
		var area: float = absf((points[b] - points[a]).cross(points[c] - points[a])) * 0.5
		total += area * (colors[a].a + colors[b].a + colors[c].a) / 3.0
	return total

static func _check_streak_energy(expect: Callable) -> void:
	for motion: String in ["stab", "thrust"]:
		var settings: Dictionary = Trail.motion_settings(motion)
		var window: Vector2 = settings["window"]
		var length: float = settings["length"]
		# A stationary point isolates axial speed lines from the tip-path ribbon.
		# The collinear sweep has zero area; subtracting it removes the identical
		# shared sparks/glint, so those cannot hide a faint streak regression.
		var samples: Array[Dictionary]
		samples.append({"progress": window.x, "tip": Vector2(120, 80), "inner": Vector2(70, 80)})
		samples.append({"progress": window.y, "tip": Vector2(120, 80), "inner": Vector2(70, 80)})
		var streak: Array[Dictionary] = Trail.geometry(samples, "streak", 0.42, 0.42, window, "none", 1.0, 11, length)
		var accents: Array[Dictionary] = Trail.geometry(samples, "sweep", 0.42, 0.42, window, "none", 1.0, 11)
		var energy: float = _alpha_area(streak[1]) - _alpha_area(accents[1])
		var edge_points := PackedVector2Array()
		for index: int in range(19):
			edge_points.append(Vector2(120.0 - length + length * float(index) / 18.0, 80))
		var edge: Dictionary = Trail._ribbon(edge_points, Trail.palette("none"), 1.0, 1.6, false)
		var edge_energy: float = _alpha_area(edge)
		expect.call(edge_energy > 0.0 and energy >= edge_energy * 4.0, "Streak core alpha-area must exceed the leading-edge ribbon by at least 4x: " + motion)
		expect.call(streak == Trail.geometry(samples, "streak", 0.42, 0.42, window, "none", 1.0, 11, length), "Streak energy geometry is deterministic: " + motion)
		print("STRIKE STREAK ENERGY %s: core=%.3f edge=%.3f ratio=%.3f" % [motion, energy, edge_energy, energy / edge_energy])

static func _check_arc_geometry(expect: Callable) -> void:
	var window := Vector2(0.33, 0.56)
	for scale: float in [0.6, 1.0]:
		var target := Vector2(100, 160)
		var samples: Array[Dictionary] = Trail.arc_samples(Vector2(100, 60), target, scale, window)
		var visible: Array[Dictionary] = Trail.visible_samples(samples, 0.42, window)
		var sweep: Dictionary = Trail._sweep(visible, Trail.palette("ice"), 1.0, scale, false)
		expect.call(visible.size() >= 2 and not sweep["indices"].is_empty() and _alpha_area(sweep) > 0.0, "Arc at .42 has non-empty luminous sweep geometry, independently of its glint")
		var center: Vector2 = target - Vector2(0, 80.0 * scale)
		for sample: Dictionary in samples:
			expect.call(absf((sample["tip"] as Vector2).distance_to(center) - 44.0 * scale) < 0.01, "Arc radius remains 44 source pixels at target body height")
		var first: Vector2 = visible[0]["tip"]
		var last: Vector2 = visible[-1]["tip"]
		expect.call(absf((first - center).angle_to(last - center)) > 2.4, "Synthetic arc presents a clear crescent by contact")
		expect.call((target.y - last.y) / scale > 36.0, "Echo contact sits on the target body rather than its floor anchor")
	for motion: String in ["stab", "thrust"]:
		var settings: Dictionary = Trail.motion_settings(motion)
		expect.call(is_equal_approx(Trail._streak_envelope(0.40, settings["window"]), 1.0) and is_equal_approx(Trail._streak_envelope(0.42, settings["window"]), 1.0), "Axial streak reaches full drive strength by .40: " + motion)
	var points := PackedVector2Array([Vector2.ZERO, Vector2(15, 0), Vector2(50, 0)])
	var core: Dictionary = Trail._streak(points, Trail.palette("none"), 1.0, 4.4, false)
	var glow: Dictionary = Trail._streak(points, Trail.palette("none"), 1.0, 4.4, true)
	var side: Dictionary = Trail._streak(points, Trail.palette("none"), 0.6, 1.6, false)
	expect.call(is_equal_approx((core["vertices"][2] as Vector2).distance_to(core["vertices"][3]), 4.4) and core["colors"][2].a == 1.0, "Streak core keeps its full width and alpha behind the tip")
	expect.call(is_equal_approx((glow["vertices"][3] as Vector2).distance_to(glow["vertices"][5]), 13.2) and is_equal_approx(glow["colors"][4].a, 0.35), "Streak glow is 3x the core width at .35 alpha")
	expect.call(is_equal_approx((side["vertices"][2] as Vector2).distance_to(side["vertices"][3]), 1.6) and is_equal_approx(side["colors"][2].a, 0.6), "Streak side line keeps 1.6px width and .6 alpha")

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
