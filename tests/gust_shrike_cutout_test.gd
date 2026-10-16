extends SceneTree

const Motion = preload("res://scripts/gust_shrike_cutout/motion.gd")
const Data = preload("res://scripts/gust_shrike_cutout/motion_data.gd")
const Action = preload("res://scripts/gust_shrike_cutout/action.gd")
const Renderer = preload("res://scripts/gust_shrike_cutout/renderer.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const CaptureViewport = preload("res://tests/gust_shrike_capture_viewport.gd")
const CaptureContract = preload("res://tests/helpers/gust_shrike_capture_contract.gd")
const CaptureScene = preload("res://tests/fixtures/gust_shrike_capture_scene.gd")
const FIXTURE_CONTACT: float = 0.5
const FIXTURE_LAYOUT: Dictionary = {"screen_pixel_scale": 1.0, "joints": {
	"root": {"position": [100, 220], "parent": null},
	"body": {"position": [100, 220], "parent": "root"},
	"head": {"position": [70, 150], "parent": "root"},
	"wing_near": {"position": [105, 170], "parent": "root"},
	"wing_far": {"position": [90, 170], "parent": "root"},
	"tail": {"position": [140, 195], "parent": "root"},
	"legs": {"position": [100, 205], "parent": "root"}}}
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var proof_clock := CaptureScene.FixedClock.new()
	proof_clock.controlled = true
	var initial_usec: int = proof_clock.presentation_usec()
	await process_frame
	_expect(proof_clock.presentation_usec() == initial_usec, "Capture IO/process frames cannot advance the proof clock")
	proof_clock.fixed_usec += CaptureScene.PROOF_STEP_USEC
	_expect(proof_clock.presentation_usec() - initial_usec == CaptureScene.PROOF_STEP_USEC, "Capture advances elapsed time by one fixed step")
	proof_clock.controlled = false
	_expect(proof_clock.presentation_usec() > 0, "Uncontrolled proof clock delegates to production time")
	proof_clock.free()
	var director_path: String = "res://experiments/cutouts/gust_shrike/mq2/director_motion.json"
	var director: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(director_path))
	_expect(FileAccess.get_sha256(director_path) == Data.DIRECTOR_SHA256, "Test expectations are bound to the compiled director source")
	var tracks: Array = [{"channel": "body_scale_y", "keys": [{"at": 0, "value": 1.0},
		{"at": 1, "value": Data.BREATH_SCALE_Y, "interpolation": "linear"}]}]
	var pose: Dictionary = Motion.sample_tracks("idle", 1, FIXTURE_LAYOUT, "front", tracks)
	_expect(pose["body"]["position"] == Vector2.ZERO, "Idle body pivot never bobs")
	_expect(pose["body"]["scale"] == Vector2(1, Data.BREATH_SCALE_Y), "Breath uses the current compiled director amplitude")
	_expect(pose["legs"]["position"] == Vector2(0, -15), "Breath leaves feet planted")
	_expect(pose["head"]["position"] == Vector2(-30, -70), "Idle look holds independently of breathing")
	_expect(not pose["head"].has("scale") and pose["wing_near"]["scale"] == Vector2.ONE, "No breathing scale leaks into rigid head or wings")
	tracks = [{"channel": "body_y", "keys": [{"at": 0, "value": 0},
		{"at": 0.5, "value": -Data.MOVE_APEX_PX, "interpolation": "linear"},
		{"at": 1, "value": 0, "interpolation": "linear"}]}]
	pose = Motion.sample_tracks("move", 0.5, FIXTURE_LAYOUT, "rear", tracks)
	_expect(pose["body"]["position"].y == -24 and pose["legs"]["position"].y == -39, "Flight carries feet at the 24px apex")
	var snap: Array = [{"at": 0, "value": -6}, {"at": 0.5, "value": 6, "interpolation": "hold"}, {"at": 1, "value": -6, "interpolation": "linear"}]
	_expect(Motion.track_value(snap, 0.49) == -6 and Motion.track_value(snap, 0.5) == 6, "Hold keys do not drift between look poses")
	_expect(Motion.track_value(snap, 2) == -6, "Terminal key remains held")
	_expect(Data.HEAD_SNAP_FPS == 30 and Data.HEAD_SNAP_PLACEMENT == "start" and is_equal_approx(Data.HEAD_SNAP_SECONDS, 2.0 / 30.0), "Director's explicit 30fps two-frame start clock is retained in motion data")
	var head_keys: Array
	for track: Dictionary in Motion.tracks_for("idle", "front"):
		if track["channel"] == "head_angle": head_keys = track["keys"]
	var snap_start: float = float(head_keys[2]["at"])
	var snap_end: float = float(head_keys[3]["at"])
	_expect(is_equal_approx((snap_end - snap_start) * Data.IDLE_SECONDS, 2.0 / 30.0), "Authored idle snap takes exactly two frames")
	_expect(is_equal_approx(Motion.track_value(head_keys, snap_start), float(head_keys[2]["value"])) and is_equal_approx(Motion.track_value(head_keys, (snap_start + snap_end) / 2), (float(head_keys[2]["value"]) + float(head_keys[3]["value"])) / 2), "Head begins moving at the key and reaches midpoint one frame later")
	_expect(is_equal_approx(Motion.track_value(head_keys, snap_end + 0.01), float(head_keys[3]["value"])), "Completed head snap holds until the next key")
	_expect(not Motion.track_errors([{"channel": "body_y", "keys": [{"at": null, "value": 3}]}]).is_empty(), "Unresolved key times cannot become zero-time poses")
	_expect(not Motion.track_errors([{"channel": "wing_near_span", "keys": [{"at": 0, "value": 0}]}]).is_empty(), "Singular wing transforms are rejected")
	var actor: Dictionary = {"type": "gust_shrike", "pos": Vector2i(2, 2)}
	for definition: Dictionary in [{"effect": {"kind": "ranged", "action_type": "dive_line"}, "clip": "dive"},
		{"effect": {"kind": "melee"}, "clip": "talon_rake"}, {"effect": {"kind": "block"}, "clip": "hover"}]:
		_expect(Action.action_for_effect(definition["effect"], actor) == definition["clip"], "Actual action descriptor routes " + definition["clip"])
		_expect(Action.action_for_effect(definition["effect"], {"type": "crawler"}).is_empty(), "Other enemies retain their rendering path")
	_expect(Action.action_for_effect({"action_type": "dive_line", "cancelled": true}, actor).is_empty(), "Cancelled Dive never triggers flight pose")
	# Feed real effect progress through production routing before sampling the
	# pose. Sampling Motion directly would miss a frozen production hover clock.
	var previous_hover: Dictionary
	for at: float in [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]:
		var hover: Dictionary = Action.motion_for_effect({"kind": "block"}, actor, at)
		_expect(hover["clip"] == "hover" and is_equal_approx(hover["phase"], at), "Production hover advances with elapsed effect progress at " + str(at))
		var applied_hover: Dictionary = Motion.sample_pose(hover["clip"], hover["phase"], FIXTURE_LAYOUT, "front")
		if not previous_hover.is_empty(): _expect(applied_hover != previous_hover, "Consecutive production hover poses change at " + str(at))
		previous_hover = applied_hover
	var contact: float = Fx.feedback_start_progress({"kind": "melee", "element": "air"})
	_expect(is_equal_approx(Action.contact_phase(contact, contact, FIXTURE_CONTACT), FIXTURE_CONTACT), "Talon contact maps to the existing effect impact")
	var sampled_impact: float = Action.effect_contact_boundary({"kind": "melee", "element": "air"}, 6)
	_expect(is_equal_approx(float(Action.motion_for_effect({"kind": "melee", "element": "air"}, actor, sampled_impact, 6)["phase"]), Data.CONTACT_PHASES["talon_rake"]), "Talon's actual first impact frame shows the authored contact pose")
	_expect(is_equal_approx(Action.contact_phase(1, 1, FIXTURE_CONTACT), FIXTURE_CONTACT), "Dive contact maps to flight END, not ranged 0.66")
	var terminal: Dictionary = Motion.sample_pose("dive", Action.dive_recovery_phase(6, Data.CONTACT_PHASES["dive"]), FIXTURE_LAYOUT, "front")
	_expect(is_equal_approx(Action.dive_recovery_phase(1, FIXTURE_CONTACT), FIXTURE_CONTACT) and terminal["body"]["position"].is_zero_approx(), "Six recovery frames include contact and the final recovered pose")
	var move: Dictionary = {"clip": "move", "phase": 0.5, "direction": Vector2i(0, 1)}
	_expect(Facing.with_idle_direction(move, Vector2i.ZERO, Vector2i(-2, 0)) == move, "Player movement cannot turn a mid-step bird")
	var renderer := Renderer.new()
	renderer.present({"clip": "dive", "phase": 1}, false)
	_expect(renderer.snapshot()["clip"] == "dive" and renderer.snapshot()["phase"] == 1, "Explicit recovery endpoint is shown before the next idle presentation")
	renderer.present({"clip": "death", "phase": 1}, false, false)
	var frozen: Dictionary = renderer.snapshot()
	renderer.present({"clip": "idle", "direction": Vector2i(-2, 0)}, false)
	_expect(renderer.snapshot()["clip"] == "death" and renderer.facing == frozen["facing"], "Terminal collapse remains held")
	renderer.free()
	_expect(Motion.design_errors().is_empty() or not Renderer.available(), "Missing design never activates a production rig")
	var scaled_layout: Dictionary = FIXTURE_LAYOUT.duplicate(true)
	scaled_layout["screen_pixel_scale"] = 0.5 # Synthetic draw-scale fixture.
	pose = Motion.sample_pose("move", 0.5, scaled_layout, "front")
	_expect(is_equal_approx(pose["body"]["position"].y * 0.5, -24), "Director lift is 24 screen pixels at non-unit draw scale")
	pose = Motion.sample_pose("move", 0.15, FIXTURE_LAYOUT, "front")
	_expect(pose["legs"]["position"] == Vector2(0, -15), "Crouch compresses the body while feet stay planted")
	for view: String in ["front", "rear"]:
		pose = Motion.sample_pose("dive", 0.35 * Data.CONTACT_PHASES["dive"], FIXTURE_LAYOUT, view)
		_expect(is_equal_approx(rad_to_deg(pose["body"]["rotation"]), 20 * Data.PROJECTION[view]["pitch_sign"]), "Nose-down pitch follows the actual " + view + " projection")
		_expect(pose["wing_near"]["scale"] == Vector2(0.7, 1), "Dive folds the " + view + " rigid wing to 70%")
		pose = Motion.sample_pose("hover", 0.15, FIXTURE_LAYOUT, view)
		_expect(is_equal_approx(pose["body"]["position"].y, -4) and is_zero_approx(pose["body"]["rotation"]), "Hover is level at the director's 4px lift")
		for key: Dictionary in director["death"]["keys"]:
			pose = Motion.sample_pose("death", float(key["t"]), FIXTURE_LAYOUT, view)
			_expect(is_equal_approx(rad_to_deg(pose["body"]["rotation"]), float(key["roll"]) * Data.PROJECTION[view]["roll_sign"]) and is_equal_approx(pose["body"]["position"].y, -float(key["lift"])), "Authored death roll/lift at %s in %s" % [key["t"], view])
			_expect(is_equal_approx(rad_to_deg(pose["legs"]["rotation"] - pose["body"]["rotation"]), float(key["legs"]) * Data.PROJECTION[view]["legs_sign"]), "Death carries authored relative leg reach at %s in %s" % [key["t"], view])
			var body_transform := Transform2D(pose["body"]["rotation"], pose["body"]["position"])
			_expect(pose["legs"]["position"].is_equal_approx(body_transform * Vector2(0, -15)), "Death's legs follow the body at every authored key in " + view)
	scaled_layout["recoil_direction"] = Vector2.RIGHT
	pose = Motion.sample_pose("hit", 0.15, scaled_layout, "front")
	_expect(is_equal_approx(pose["body"]["position"].x * 0.5, float(director["hit"]["keys"][1]["recoil_px"])), "Hit follows the current authored recoil distance")
	# A reduced root window reproduces the Retina clamp without a GUI renderer.
	var original_size: Vector2i = root.size
	root.size = Vector2i(800, 450)
	var viewport: SubViewport = CaptureViewport.create(root)
	var content := Control.new()
	viewport.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	_expect(viewport.size == Vector2i(1920, 1080) and content.size == Vector2(1920, 1080), "Clamped root leaves production capture and content at fixed 1920x1080")
	_expect(viewport.world_2d != root.world_2d and viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Capture owns an independent canvas and updates every frame")
	viewport.free()
	root.size = original_size
	var capture_frames: Array
	for action: String in CaptureContract.ACTIONS:
		var phases: Array = [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]
		for required: float in CaptureContract.required_phases(action):
			if not phases.has(required): phases.append(required)
		phases.sort()
		for at: float in phases:
			capture_frames.append({"stage": action, "snapshot": {"clip": action, "phase": at}, "pose_sha256": action + str(at)})
	var completions: Dictionary = {"hit": {"clip": "idle"}}
	_expect(not CaptureContract.errors(capture_frames).is_empty(), "Hit must retire through production idle")
	_expect(CaptureContract.errors(capture_frames, completions).is_empty(), "Per-action capture contract accepts distinct poses with required phases")
	var short_capture: Array = capture_frames.filter(func(frame: Dictionary) -> bool: return frame["stage"] != "hover" or frame["snapshot"]["phase"] == 0.0)
	for index: int in range(100): short_capture.append({"stage": "idle", "snapshot": {"clip": "idle", "phase": 0}, "pose_sha256": "idle"})
	_expect(not CaptureContract.errors(short_capture, completions).is_empty(), "A large idle/global frame count cannot substitute for hover coverage")
	var frozen_capture: Array = capture_frames.duplicate(true)
	for frame: Dictionary in frozen_capture:
		if frame["stage"] == "move": frame["pose_sha256"] = "unchanged"
	_expect(not CaptureContract.errors(frozen_capture, completions).is_empty(), "Different phase labels without visible pose changes fail capture")
	var no_contact: Array = capture_frames.filter(func(frame: Dictionary) -> bool: return frame["stage"] != "dive" or not is_equal_approx(frame["snapshot"]["phase"], Data.CONTACT_PHASES["dive"]))
	_expect(not CaptureContract.errors(no_contact, completions).is_empty(), "Missing exact Dive contact fails even with six other frames")
	var scene: Script = load("res://scripts/run_scene.gd")
	_expect(scene != null, "Production integration parses with the unmodified runtime")
	for error: String in failures: push_error(error)
	print("GUST SHRIKE CUTOUT: %s (%d checks, %d failures; headless logic only)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
