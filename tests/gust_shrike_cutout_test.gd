extends SceneTree

const Motion = preload("res://scripts/gust_shrike_cutout/motion.gd")
const Data = preload("res://scripts/gust_shrike_cutout/motion_data.gd")
const Action = preload("res://scripts/gust_shrike_cutout/action.gd")
const Renderer = preload("res://scripts/gust_shrike_cutout/renderer.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
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
	var tracks: Array = [{"channel": "body_scale_y", "keys": [{"at": 0, "value": 1.0},
		{"at": 1, "value": Data.BREATH_SCALE_Y, "interpolation": "linear"}]}]
	var pose: Dictionary = Motion.sample_tracks("idle", 1, FIXTURE_LAYOUT, "front", tracks)
	_expect(pose["body"]["position"] == Vector2.ZERO, "Idle body pivot never bobs")
	_expect(pose["body"]["scale"] == Vector2(1, 1.02), "Breath is the brief's +2% Y scale")
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
	_expect(not Motion.track_errors([{"channel": "body_y", "keys": [{"at": null, "value": 3}]}]).is_empty(), "Unresolved key times cannot become zero-time poses")
	_expect(not Motion.track_errors([{"channel": "wing_near_span", "keys": [{"at": 0, "value": 0}]}]).is_empty(), "Singular wing transforms are rejected")
	var actor: Dictionary = {"type": "gust_shrike", "pos": Vector2i(2, 2)}
	for definition: Dictionary in [{"effect": {"kind": "ranged", "action_type": "dive_line"}, "clip": "dive"},
		{"effect": {"kind": "melee"}, "clip": "talon_rake"}, {"effect": {"kind": "block"}, "clip": "hover"}]:
		_expect(Action.action_for_effect(definition["effect"], actor) == definition["clip"], "Actual action descriptor routes " + definition["clip"])
		_expect(Action.action_for_effect(definition["effect"], {"type": "crawler"}).is_empty(), "Other enemies retain their rendering path")
	_expect(Action.action_for_effect({"action_type": "dive_line", "cancelled": true}, actor).is_empty(), "Cancelled Dive never triggers flight pose")
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
		pose = Motion.sample_pose("death", 1, FIXTURE_LAYOUT, view)
		_expect(is_equal_approx(rad_to_deg(pose["body"]["rotation"]), 25 * Data.PROJECTION[view]["roll_sign"]), "Collapse tilts toward the projected far side in " + view)
		var leg: Transform2D = Transform2D(pose["legs"]["rotation"], pose["legs"]["position"])
		_expect((leg * Vector2(0, 15)).is_zero_approx(), "Grounded collapse keeps the exported foot contact fixed in " + view)
	scaled_layout["recoil_direction"] = Vector2.RIGHT
	pose = Motion.sample_pose("hit", 0.15, scaled_layout, "front")
	_expect(is_equal_approx(pose["body"]["position"].x * 0.5, 3), "Hit travels 3 screen pixels along the resolved recoil vector")
	var scene: Script = load("res://scripts/run_scene.gd")
	_expect(scene != null, "Production integration parses with the unmodified runtime")
	for error: String in failures: push_error(error)
	print("GUST SHRIKE CUTOUT: %s (%d checks, %d failures; headless logic only)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
