extends SceneTree

# Proof tooling only: deliberately absent from the permanent suite registries.
const Proof = preload("res://spec/peer_benchmark/roar-01/proof_data.gd")
const Arrival = preload("res://scripts/dragon_arrival.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Host = preload("res://spec/peer_benchmark/roar-01/opening_host.gd")
const EPSILON: float = 0.001
const TIMING_TOLERANCE: float = 0.12
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Engine.time_scale = float(Proof.value("time-scale", "1.0"))
	call_deferred("_run")

func _run() -> void:
	var backing := Image.create(3024, 1898, false, Image.FORMAT_RGBA8)
	backing.fill(Color(0.25, 0.5, 0.75, 1.0))
	var saved: Image = preload("res://spec/peer_benchmark/roar-01/fight_opening_probe.gd").normalize_capture(backing)
	_check(saved.get_size() == Proof.SCREEN, "Retina backing capture normalizes to 1920x1080")
	for id: String in Proof.IDS:
		var actor: Node = Proof.renderer(id)
		root.add_child(actor)
		actor.set_process(false)
		for hero: Vector2i in Proof.HERO_TILES:
			var state: Dictionary = Proof.state(id, hero)
			var enemy: Dictionary = state["enemies"][0]
			for reduced: bool in [false, true]:
				for phase: float in Proof.PHASES:
					var motion: Dictionary = Arrival.opening_motion(state, enemy, phase)
					motion = Facing.with_idle_direction(motion, Proof.ENEMY_TILE * 2 + Vector2i.ONE, hero * 2)
					actor.call("present", motion, reduced)
					var snapshot: Dictionary = actor.call("snapshot")
					_check(snapshot["facing"] == "front" and snapshot["clip"] == "roar", id + " holds front through phase " + str(phase))
					_check(is_equal_approx(float(snapshot["phase"]), phase), id + " uses authored phase even in reduced motion")
					_check(bool(snapshot["mirrored"]) == (hero.x >= hero.y), id + " mirrors toward hero screen side, with equality right")
					_check((actor.get("rigs")["front"] as Node2D).visible, id + " shows the front rig")
					_check_pose(actor, id, phase, reduced)
				var idle: Dictionary = Facing.with_idle_direction({}, Proof.ENEMY_TILE * 2 + Vector2i.ONE, hero * 2)
				actor.call("present", idle, reduced)
				var after: Dictionary = actor.call("snapshot")
				var expected: Dictionary = Facing.direction_for_delta(hero * 2 - (Proof.ENEMY_TILE * 2 + Vector2i.ONE))
				_check(after["facing"] == expected["facing"] and after["mirrored"] == expected["mirrored"], id + " restores today's idle facing")
				_check(after["clip"] == ("rest" if reduced else "idle"), id + " restores idle after the clip")
		actor.free()
		print("ROAR POSES ", id, ": sampled 8 phases, front/mirror/equal-screen-x, normal/reduced, idle recovery")
	await _timing(false, -1.0)
	await _timing(true, -1.0)
	await _timing(false, 0.10)
	await _timing(false, 0.65)
	for failure: String in failures: push_error(failure)
	print("ROAR POSE CHECK: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check_pose(actor: Node, id: String, phase: float, reduced: bool) -> void:
	var rig: Node = actor.get("rigs")["front"]
	var layout: Dictionary = rig.get("layout")
	var motion: Script = load("res://scripts/%s_cutout/motion.gd" % id)
	var pose: Dictionary = motion.sample_pose("roar", phase, layout, "front", 0.0, reduced) if id == "iskaldra" else motion.sample_pose("roar", phase, layout, "front", reduced)
	var clamps: Dictionary = motion.ROAR_CLAMPS
	var rest: Dictionary = motion.sample_pose("rest", 0.0, layout, "front")
	for bone: String in pose:
		var value: Dictionary = pose[bone]
		_check((value["position"] as Vector2).is_finite() and is_finite(float(value["rotation"])), id + " finite bone " + bone)
		var actual: Transform2D = (rig.get("bones")[bone] as Node2D).transform
		var expected := Transform2D(float(value["rotation"]), value["scale"], float(value["skew"]), value["position"])
		_check(actual.is_equal_approx(expected), id + " renderer applies roar to " + bone)
		if phase in [0.0, 1.0]:
			_check(_world(pose, layout, bone).is_equal_approx(_world(rest, layout, bone)), id + " neutral roar endpoints")
		if (bone.begins_with("claw_") or bone.begins_with("foot_") or bone.begins_with("talon_")) and id != "vaeloryx" and not (id == "iskaldra" and bone.begins_with("talon_")):
			_check(_world(pose, layout, bone).is_equal_approx(_world(rest, layout, bone)), id + " planted contact " + bone)
	var gather: float = _envelope(phase, 0.0, 0.21, 0.21, 0.27)
	var roar: float = _envelope(phase, 0.21, 0.27, 0.79, 1.0)
	var torso: String = "torso" if id in ["tharokh", "iskaldra", "zekarion"] else "body"
	var displacement := Vector2(float(clamps.get("back_px", 1.5)) * float(clamps.get("gather_scale", 1.0)) * gather - float(clamps.get("forward_px", 1.0)) * roar, float(clamps.get("down_px", 2.0)) * float(clamps.get("gather_scale", 1.0)) * gather - float(clamps.get("up_px", 4.0)) * roar)
	# World coordinates are float32 source pixels; subtracting bind origins
	# loses more precision than comparing the small analytic offset directly.
	var trunk_delta: Vector2 = _world(pose, layout, torso).origin - _world(rest, layout, torso).origin
	_check(trunk_delta.distance_to(displacement) < EPSILON, id + " authored torso envelopes")
	var tail: String = "tail_base" if pose.has("tail_base") else "tail"
	_check((_world(pose, layout, tail).origin - _world(rest, layout, tail).origin).distance_to(trunk_delta) < EPSILON, id + " tail follows the trunk attachment")
	var tremble: float = 0.0
	if not reduced and phase >= 0.27 and phase <= 0.79:
		tremble = 0.02 * sin(TAU * 14.0 * (phase * 1.90 - 0.40)) * (0.79 - phase) / (0.79 - 0.27)
	var neck: String = "head" if id == "iskaldra" else "neck"
	_check(absf(float(pose[neck]["rotation"]) - (-0.10 * gather + 0.30 * roar + tremble) * float(clamps.get(neck, 1.0))) < EPSILON, id + " neck envelope and game-time tremble")
	if id != "iskaldra":
		_check(absf(float(pose["head"]["rotation"]) - (-1.0 if id == "noctyrax" else 1.0) * 0.12 * roar * float(clamps.get("head", 1.0))) < EPSILON, id + " own head-up sign")
	if id in ["vyraketh", "zekarion"]:
		_check(absf(float(pose["jaw"]["rotation"]) + 0.28 * roar * float(clamps.get("jaw", 1.0))) < EPSILON, id + " jaw closes in gather and opens in roar")
	if id != "tharokh":
		_check(absf(float(pose["wing_near"]["rotation"]) - (-1.0 if id == "noctyrax" else 1.0) * (0.06 * float(clamps.get("wing_near_gather", 1.0)) * gather - 0.24 * roar) * float(clamps.get("wing_near", 1.0))) < EPSILON, id + " near wing envelope")
		_check(absf(float(pose["wing_far"]["rotation"]) - (-1.0 if id == "noctyrax" else 1.0) * (-0.05 * gather + 0.23 * roar) * float(clamps.get("wing_far", 1.0))) < EPSILON, id + " far wing envelope")
	if reduced and phase == 0.50:
		_check(absf(float(pose[neck]["rotation"]) - 0.30 * float(clamps.get(neck, 1.0))) < EPSILON, id + " reduced roar retains peak, without tremble")

func _envelope(t: float, start: float, peak: float, hold_end: float, end: float) -> float:
	if t <= start or t >= end: return 0.0
	if t < peak: return smoothstep(start, peak, t)
	if t <= hold_end: return 1.0
	return 1.0 - smoothstep(hold_end, end, t)

func _world(pose: Dictionary, layout: Dictionary, bone: String) -> Transform2D:
	var value: Dictionary = pose[bone]
	var local := Transform2D(float(value["rotation"]), value["scale"], float(value["skew"]), value["position"])
	var parent: Variant = layout["joints"][bone]["parent"]
	return local if parent == null else _world(pose, layout, str(parent)) * local

func _timing(reduced: bool, cancel_after: float) -> void:
	var host := Host.new()
	root.add_child(host)
	host.configure("vyraketh", Vector2i(1, 3))
	host.reduced = reduced
	var before: Dictionary = host._combat_state.duplicate(true)
	Arrival.prepare(host)
	host._refresh_stage_view()
	_check(host.last["facing"] == "front", "Front before the opening layout wait")
	if cancel_after >= 0.0:
		create_timer(cancel_after).timeout.connect(func() -> void: host.can_continue = false)
	var clock: SceneTreeTimer = create_timer(100.0)
	host._sfx_router.clock = clock
	var start: int = Time.get_ticks_usec()
	await Arrival.play(host)
	var wall_seconds: float = float(Time.get_ticks_usec() - start) / 1000000.0
	var elapsed: float = 100.0 - clock.time_left
	_check(host.last["clip"] == ("rest" if reduced else "idle"), "Completion/cancellation restores idle")
	_check(host._combat_state == before and host._board_presentation == {"proof_unrelated": true}, "No combat/save/RNG mutation; no stale presentation")
	_check(float(host.transition[1]) == 0.40 and float(host.transition[2]) == 1.8, "Unchanged music transition")
	var roar_count: int = host._sfx_router.cues.count("dragon.roar")
	_check(roar_count == (0 if cancel_after >= 0.0 and cancel_after < 0.40 else 1), "Arrival cue exactly once, never after early cancellation")
	_check(host.board_view.rumbles == (0 if reduced or (cancel_after >= 0.0 and cancel_after < 0.40) else 1), "Reduced motion skips rumble")
	if cancel_after < 0.0:
		_check(absf(elapsed - 1.90) < TIMING_TOLERANCE, "Opening follows game time, 1.90 seconds")
		var cue_elapsed: float = host._sfx_router.arrival_game_seconds
		_check(absf(cue_elapsed - 0.40) < TIMING_TOLERANCE, "Cue at hold boundary")
		_check(host.phases.size() > 2 and host.phases[-1] == 1.0, "Game-time phase reaches recovery")
		var actor: Dictionary = host._combat_state["enemies"][0]
		host._sfx_router.begin_action(before, {"type": "melee", "actor_key": "enemy_1"}, actor)
		_check(host._sfx_router.cues.count("dragon.roar") == 1, "First action never repeats arrival roar")
		host._sfx_router.begin_action(before, {"type": "aoe", "actor_key": "enemy_1"}, actor)
		_check(host._sfx_router.cues.count("dragon.roar") == 2, "Big area attack still roars")
	print("ROAR TIMING reduced=%s cancel=%.2f game_seconds=%.3f wall_seconds=%.3f scale=%.2f cues=%d rumble=%d" % [reduced, cancel_after, elapsed, wall_seconds, Engine.time_scale, roar_count, host.board_view.rumbles])
	host.free()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
