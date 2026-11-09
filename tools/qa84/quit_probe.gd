extends Node
## Packed into a disposable release app by build_release_probe.py.
## Populate the real scene and the demo driver's static URL interception seams,
## then quit directly, as the failed demo route does. No external URLs are opened.
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const DemoEnd = preload("res://scripts/demo_end_panel.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Data = preload("res://scripts/game_data.gd")
const Recovery = preload("res://scripts/opening_boon_recovery.gd")
const FIXTURE_SEED: int = 83
const READY_FRAME_LIMIT: int = 3600
const SETTLE_FRAMES: int = 3
var root: Window:
	get: return get_tree().root
var _scene: Control
var _intercepted: int = 0

func _ready() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.tree_exiting.connect(_after_root_exit)
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://qa84")
	Store.set_storage_path("user://qa84/profile.json")
	Store.set_run_storage_path("user://qa84/run.save")
	Analytics.set_storage_dir("user://qa84/analytics")
	var profile: Dictionary = Store.default_data()
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, profile)
	if Boons.pending(state): state = Boons.choose(engine, state, "")
	for coord: Vector2i in engine.available_moves(state):
		var candidate: Dictionary = engine.move_to_room(state.duplicate(true), coord)
		if str(candidate.get("mode", "")) == "combat":
			state = candidate
			break
	if state.get("mode") != "combat" or not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		push_error("QA84 fixture could not persist live combat (mode=%s)" % state.get("mode"))
		quit(1)
		return
	# These are the two lambdas retained by hitch_census/demo/session.gd.
	DemoEnd.shell_open = func(_url: String) -> int: _intercepted += 1; return OK
	DemoEnd.store_page_override_for_test = func() -> void: _intercepted += 1
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(_scene)
	get_tree().current_scene = _scene
	var ready: bool = false
	for frame: int in range(READY_FRAME_LIMIT):
		await get_tree().process_frame
		if _scene.call("initial_presentation_is_ready"):
			ready = true
			break
	if not ready:
		push_error("QA84 real scene readiness limit exceeded")
		quit(1)
		return
	_scene.call("_close_dialogue")
	# A lambda identity with no variant is the other retained-callable cache path.
	var resolver: Callable = func(_inputs: Dictionary) -> Dictionary: return Data.card_def_for_progression("quick_stab", state)
	Bindings.projection(Bindings.context(state), "quick_stab", resolver, null, Display.for_card)
	if not OS.get_cmdline_user_args().has("--combat"):
		var combat: Dictionary = state["combat_state"].duplicate(true)
		combat["player"]["hp"] = 0
		state = engine.finish_combat(state, combat)
		if state.get("mode") != "defeat":
			push_error("QA84 fixture did not reach demo-incomplete end state")
			quit(1)
			return
		_scene.set("_run_state", state)
		_scene.set("_combat_state", {})
		_scene.call("_refresh_ui")
	for frame: int in range(SETTLE_FRAMES): await get_tree().process_frame
	# Leave final I/O pending: the actual SceneTree teardown must drain it.
	Store.queue_run_state(state)
	var events := Analytics.new()
	events.deferred_writes = true
	events.write_event("qa84_quit_probe", {}, {"mode": state["mode"]})
	print("QA84 QUIT PROBE: armed mode=%s cached_definitions=%d demo_lambdas=true" % [state["mode"], Bindings.definition_count()])
	quit()

func quit(code: int = 0) -> void:
	get_tree().quit(code)

func _after_root_exit() -> void:
	var released: bool = not Recovery.profile_writer.is_valid() and not DemoEnd.shell_open.is_valid() and not DemoEnd.store_page_override_for_test.is_valid() and Bindings.definition_count() == 0
	var pending: bool = Store._run_writer.busy() or Analytics._writer.busy()
	print("QA84 QUIT CLEANUP: released=%s pending=%s" % [released, pending])
