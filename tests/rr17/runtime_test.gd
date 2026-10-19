extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Special = preload("res://assets/units/storm_capacitor_cutout/actions.gd")
const TYPE: String = "storm_capacitor"
const EPSILON: float = 0.0001
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	root.add_child(board)
	await process_frame
	var state: Dictionary = Fixture.fixture(TYPE)
	var second: Dictionary = state["enemies"][0].duplicate(true)
	second["id"] = 2
	second["pos"] = Vector2i(2, 3)
	state["enemies"].append(second)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var renderer: Node = board.unit_cutout_renderer(state["enemies"][0])
	var partner: Node = board.unit_cutout_renderer(second)
	_expect(renderer != null and partner != null, "Board registers both Capacitors")
	if renderer == null or partner == null:
		quit(1)
		return
	_expect(not is_equal_approx(renderer._idle_seconds, partner._idle_seconds), "Board retains per-actor idle phase distribution")
	var texture: Texture2D = renderer.texture()
	_expect(not Action.data_for(TYPE)["clips"].has("move"), "Immobile actor has no move clip")
	var death: Script = preload("res://assets/units/storm_capacitor_cutout/death.gd")
	_expect(death.EXISTING_FADE_FRAMES == Board.ENEMY_SHADOW_DISSOLVE_FRAME_COUNT and is_equal_approx(death.EXISTING_FADE_FRAME_SECONDS, Board.ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS), "Death retains existing fade clock")
	var boundary: float = death.clip_seconds() / death.total_seconds()
	_expect(is_equal_approx(death.clip_phase(boundary), 1.0) and is_zero_approx(death.fade_phase(boundary)), "Clip completes before fade begins")
	_expect(is_equal_approx(death.fade_phase(1.0), 1.0), "Existing fade reaches completion")
	_expect(Action.clip_for({"action_type": "gain_charge"}, {"type": TYPE, "intent": {"id": "charge"}}) == "charge", "Exact charge selector")
	_expect(Action.clip_for({"action_type": "chain_discharge"}, {"type": TYPE, "intent": {"id": "discharge"}}) == "discharge", "Exact discharge selector")
	_expect(Action.clip_for({"action_type": "reset_charge"}, {"type": TYPE, "intent": {"id": "discharge"}}).is_empty(), "Reset does not replay discharge")
	for clip: String in ["charge", "discharge"]:
		var data: Dictionary = Action.data_for(TYPE)["clips"][clip]
		var count: int = Action.frames_for(TYPE, clip)
		var frame: int = ceili(float(data["contact"]) * (count - 1)) + 1
		_expect(absf(Special.phase_at(frame, count, data["contact"]) - float(data["contact"])) < EPSILON, clip + " exact contact callback")
	for direction: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		renderer.present({"clip": "charge", "phase": 0.5, "direction": direction, "screen_pixel_scale": 0.5}, false)
		_expect(not renderer.mirrored and renderer.rigs[renderer.facing].scale == Vector2.ONE, "Symmetric painting never mirrors")
		_expect(renderer.texture() == texture, "Persistent viewport texture")
		var rig: Node2D = renderer.rigs[renderer.facing]
		_expect(absf(rig.bones["cap"].position.y - 72.0) < EPSILON, "Lift is in painting pixels, independent of board scale")
		_expect(rig.bones["cap"].get_parent() == rig.bones["column"], "Cap parent is column")
		_expect(rig.bones["column"].get_parent() == rig.bones["root"], "Column parent is whole body")
	for view: String in ["front", "rear"]:
		var rig: Node2D = renderer.rigs[view]
		_expect(rig.layout["parts"][0]["file"] == "paint/column.png", "Same unmirrored front painting in both views")
		for level: int in [-2, -1, 0, 1, 2]:
			var source: Dictionary = Motion.data_for(rig.layout)
			var copy: Dictionary = source.duplicate(true)
			copy["clips"]["proof_glow"] = {"seconds": 1.0}
			copy["view_tracks"][view]["proof_glow"] = [{"bone": "column", "channel": "glow", "forward_mode": "pixels", "keys": [{"at": 0.0, "value": level, "interpolation": "hold"}]}]
			Motion._cache[rig.layout["motion_data"]] = copy
			rig.apply_pose("proof_glow", 0.0)
			_expect(rig.bones["column"].get_node("column").texture == rig._glow_textures[rig.layout["glow_textures"][str(level)]], "Integer glow swaps baked texture")
			Motion._cache[rig.layout["motion_data"]] = source
	var portrait := TextureRect.new()
	preload("res://scripts/maquette_cutout_runtime/portrait.gd").bind(portrait, TYPE, false, true)
	root.add_child(portrait)
	await process_frame
	_expect(portrait.texture is AtlasTexture and (portrait.texture as AtlasTexture).atlas is ViewportTexture, "Portrait shares production renderer")
	_expect(preload("res://scripts/actor_presentation.gd").travel_renderer(TYPE) == Presentation.renderer_script(TYPE), "Pre-battle shares production renderer")
	renderer.present({"clip": "charge", "phase": 0.5}, true)
	_expect(renderer.snapshot()["shown_clip"] == "rest", "Reduced motion retains rig at rest")
	renderer.present({"clip": "hit", "phase": 0.4}, false)
	renderer.present({}, false)
	renderer._process(1.0)
	_expect(renderer.clip == "idle", "Hit returns to seeded idle")
	renderer.present({"clip": "death", "phase": 1.0}, false)
	renderer.present({}, false)
	_expect(renderer.clip == "death" and renderer.phase == 1.0, "Death terminal pose freezes for existing fade")
	portrait.queue_free()
	board.queue_free()
	await process_frame
	print("RR17 RUNTIME: %s (%d checks, %d failures; headless logic only)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
