extends "res://tools/inspection_fixture.gd"

const Rooms = preload("res://tests/suites/en03_enemies_suite.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Settings = preload("res://scripts/settings_store.gd")
const ProbeRun = preload("res://tools/fx29/probe_scene.gd")
const Adapter = preload("res://assets/units/glacial_mirror_cutout/actions.gd")
const View = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const Bursts = preload("res://scripts/tile_burst_fx.gd")
const SEED: int = 131011
const SIZE := Vector2i(1920, 1080)
const MIRROR := Vector2i(6, 4)
const HERO := Vector2i(2, 4)
const NEAR_HERO := Vector2i(3, 4)
const FRONT := Vector2i(5, 4)
const MID := Vector2i(4, 4)
const SURVIVOR := Vector2i(7, 7)
const HERO_HP: int = 30
const CRATE_HP: int = 10
const CRATE_RESOLVED_LOSS: int = 1
const READY_SECONDS: float = 12.0
const SETTLE_FRAMES: int = 8

var _scene: Node
var _viewport: SubViewport
var _base: String
var _view: Script
var _adapter: Script
var _before: Dictionary
var _after: Dictionary
var _step: Dictionary
var _checks: int
var _failures: int

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_take")

func _take() -> void:
	quit(2)

func _arg(flag: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(flag)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _layout(label: String) -> Dictionary:
	var roster: Array[Dictionary] = [Rooms.enemy("glacial_mirror", 1, MIRROR, "refraction"),
		Rooms.enemy("crawler", 2, FRONT if label == "two_units" else SURVIVOR)]
	var layout: Dictionary = Rooms.layout(roster, NEAR_HERO if label == "past_hero" else HERO, "ice")
	if label == "crate":
		layout["terrain"] = [{"id": "proof_crate", "kind": "wooden_crate", "pos": MID, "hp": CRATE_HP, "max_hp": CRATE_HP}]
	return layout

func _open(base: String) -> bool:
	_base = base
	_view = View if base.is_empty() else load(base.path_join("reflect_view.gd"))
	_adapter = Adapter if base.is_empty() else load(base.path_join("actions.gd"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["master_volume"] = 0.0
	Settings.save_settings(settings)
	_options = {"scenario": "combat", "seed": SEED}
	var profile: Dictionary = Tutorial.complete_tutorial(_build_progression())
	var run: Dictionary = _build_run_state("combat", profile)
	if not _expect(not run.is_empty(), "inspection room builds"): return false
	var layout: Dictionary = _layout("two_units")
	layout["coord"] = run["current_room"]
	run["combat_state"] = _combat_state_for(layout)
	run["current_room_layout"] = layout
	run["player_hp"] = HERO_HP
	run["player_max_hp"] = HERO_HP
	if not _expect(ProgressionStore.save_data(profile) and ProgressionStore.save_run_state(run), "fixture saves"): return false

	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_scene.set_script(ProbeRun)
	if not base.is_empty():
		_scene.get_node("BoardUnderlay/CombatBoard").set_script(load(base.path_join("combat_board_view.gd")))
	_viewport.add_child(_scene)
	var cutoff: int = Time.get_ticks_msec() + int(READY_SECONDS * 1000.0)
	while Time.get_ticks_msec() < cutoff:
		var centering: Tween = _scene._board_centering_tween
		if _scene.initial_presentation_is_ready() and (centering == null or not centering.is_running()): break
		await process_frame
	_scene._close_dialogue()
	for frame: int in SETTLE_FRAMES: await process_frame
	return _expect(_scene.initial_presentation_is_ready() and _scene.hand_scroll.is_visible_in_tree()
			and _viewport.size == SIZE and is_equal_approx(_scene._settings.get("ui_scale", 0.0), 1.0),
			"1920x1080 RunScene and HUD at 100%")

func _combat_state_for(layout: Dictionary) -> Dictionary:
	var state: Dictionary = _combat_engine.create_combat(SEED, layout, {
		"hp": HERO_HP, "max_hp": HERO_HP, "deck_cards": ["quick_stab", "brace"], "hand_size": 2,
	})
	var authored: Dictionary = layout["enemies"][0]["intent"]
	var mirror: Dictionary = state["enemies"][0]
	mirror["intent"] = _combat_engine._surface_prepare_enemy_intent(state, mirror, authored)
	return state

func _prepare(label: String, reduced: bool) -> void:
	var layout: Dictionary = _layout(label)
	layout["coord"] = _scene._run_state["current_room"]
	_before = _combat_state_for(layout)
	var action: Dictionary = _before["enemies"][0]["intent"]["actions"][0]
	var context: Dictionary = {"refraction_started": false}
	_after = _before.duplicate(true)
	if label != "cancelled":
		var reserved_status_steps: Array[Dictionary]
		_after = _combat_engine._resolve_enemy_action(_after, 0, action, null, {}, reserved_status_steps, context)
	if label == "crate":
		# The resolver's direct line damages actors. Supply a surviving terrain
		# loss in the resolved snapshot to exercise the presentation row.
		_after["terrain"][0]["hp"] -= CRATE_RESOLVED_LOSS
	_step = _combat_engine._enemy_action_step(_before, _after, 0, action, context)
	if label == "hidden":
		_before["umbra"]["stage"] = "eclipse"
		_before["umbra"]["stage_reduction"] = 0
		_before["umbra"]["light_sources"] = []
		_after["umbra"] = _before["umbra"].duplicate(true)
	_scene._settings["reduced_motion"] = reduced
	_scene.proof_clock = Vector2.ZERO
	_scene.proof_frame = 1
	_scene.proof_contact = 0
	_scene.proof_contact_at_end = false
	_scene.proof_floating = {}
	_scene._combat_state = _before.duplicate(true)
	_scene._run_state["combat_state"] = _scene._combat_state
	_scene._run_state["current_room_layout"] = layout
	_scene.board_view.clear_tile_bursts()
	_scene._render_board_state(_before, {})

func _play(fallback: bool) -> Dictionary:
	var state: Dictionary = _before.duplicate(true)
	if fallback:
		await _view.animate_beam(_scene, state, _step)
	else:
		_scene._tile_burst_adapter_contact = Bursts.adapter_contact(_step, state)
		await _adapter.animate(_scene, state, _step, state["enemies"][0])
		_scene._tile_burst_adapter_contact.clear()
	return state

func _close() -> void:
	if is_instance_valid(_viewport):
		_viewport.queue_free()
		await process_frame
		await process_frame

func _expect(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("FX-29: " + label)
	return ok
