extends "res://tools/inspection_fixture.gd"

const BoardFixture = preload("res://tests/suites/en03_enemies_suite.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Reflection = preload("res://scripts/enemy_mechanics/reflect.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const View = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const ProbeRun = preload("res://tools/gfix34/probe_scene.gd")
const SHOT_CARD: String = "hurl_spear"
const PUSH_CARD: String = "updraft"
const SEED: int = 131011
const HERO := Vector2i(4, 4)
const MIRROR := Vector2i(6, 4)
const SURVIVOR := Vector2i(7, 7)
const REMOTE_ORIGIN := Vector2i(4, 5)
const SIZE := Vector2i(1920, 1080)
const HERO_HP: int = 30
const READY_SECONDS: float = 12.0
const SETTLE_FRAMES: int = 8

var _scene: Node
var _viewport: SubViewport
var _view_script: Script
var _before: Dictionary
var _after: Dictionary
var _action: Dictionary
var _chain_hits: Array
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

func _open(card: String, base: String, hidden: bool, reduced: bool, remote: bool = false) -> bool:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = reduced
	settings["master_volume"] = 0.0
	Settings.save_settings(settings)
	_options = {"scenario": "combat", "seed": SEED}
	var profile: Dictionary = Tutorial.complete_tutorial(_build_progression())
	var run: Dictionary = _build_run_state("combat", profile)
	if not _expect(not run.is_empty(), "inspection room builds"): return false
	var layout: Dictionary = BoardFixture.layout([
		BoardFixture.enemy("glacial_mirror", 1, MIRROR),
		BoardFixture.enemy("crawler", 2, SURVIVOR),
	], HERO, "ice")
	layout["coord"] = run["current_room"]
	var hand: Array[String] = [card, "brace"]
	var state: Dictionary = _combat_engine.create_combat(SEED, layout, {
		"hp": HERO_HP, "max_hp": HERO_HP, "deck_cards": hand, "hand_size": hand.size(),
	})
	state["deck"]["hand"] = hand
	run["combat_state"] = state
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
	_view_script = View
	_scene.set_script(ProbeRun if base.is_empty() else load(base.path_join("probe_scene.gd")))
	if not base.is_empty():
		_scene.get_node("BoardUnderlay/CombatBoard").set_script(load(base.path_join("combat_board_view.gd")))
		_view_script = load(base.path_join("reflect_view.gd"))
	_viewport.add_child(_scene)
	var cutoff: int = Time.get_ticks_msec() + int(READY_SECONDS * 1000.0)
	while Time.get_ticks_msec() < cutoff:
		var centering: Tween = _scene._board_centering_tween
		if _scene.initial_presentation_is_ready() and (centering == null or not centering.is_running()): break
		await process_frame
	_scene._close_dialogue()
	for frame: int in SETTLE_FRAMES: await process_frame
	if not _expect(_scene.initial_presentation_is_ready() and _scene.hand_scroll.is_visible_in_tree()
			and _viewport.size == SIZE and is_equal_approx(_scene._settings.get("ui_scale", 0.0), 1.0),
			"1920x1080 RunScene and HUD are ready at 100%"):
		return false

	_before = _scene._combat_state.duplicate(true)
	_action = GameData.card_def(card)["actions"][0].duplicate(true)
	_action["_card_id"] = card
	if remote:
		_before["relics"] = ["worldroot_idol"]
		BoardSurfaceRules.place(_before, HERO, "rubble")
		BoardSurfaceRules.place(_before, REMOTE_ORIGIN, "rubble")
		_action["_surface_relic_modes"] = ["remote"]
		_action = _scene._combat_engine.action_with_automatic_origin(_before, _action, MIRROR)
		if not _expect(_action.get("_origin_tile") == REMOTE_ORIGIN, "Worldroot resolves the remote launch"): return false
	var result: Dictionary = _scene._combat_engine.resolve_player_action_for_presentation(_before, _action, MIRROR)
	_after = result["state"]
	_chain_hits = result["chain_hits"]
	if hidden:
		# Reuse the committed step under Eclipse to exercise the renderer with a
		# concealed destination, independent of the aim UI's targeting rules.
		for snapshot: Dictionary in [_before, _after]:
			snapshot["umbra"]["stage"] = "eclipse"
			snapshot["umbra"]["stage_reduction"] = 0
			snapshot["umbra"]["light_sources"] = []
	return _expect(Reflection.bounces_between(_before, _after).size() == 1, card + " resolves one Mirror bounce")

func _drive(card: String) -> void:
	_scene._animation_lock = true
	_scene._begin_action_step_resolution_tracker(card, [_action], TypedArrays.vector2i([MIRROR]), false)
	_scene._combat_pacing.begin_card()
	await _scene._animate_player_action_step(_before, _after, card, _action, MIRROR, _chain_hits)
	_scene._combat_pacing.end_scope()
	_scene._animation_lock = false

func _close() -> void:
	if is_instance_valid(_viewport):
		_viewport.queue_free()
		await process_frame
		await process_frame

func _expect(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("GFIX-34: " + label)
	return ok
