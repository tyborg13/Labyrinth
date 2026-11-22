extends SceneTree

const ConfirmFixtures = preload("res://tools/perf_162/confirm_fixtures.gd")
const Run = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const GraftView = preload("res://scripts/graftwright_view.gd")
const SHOP_SEED: int = 4
const FIRST_SHOP := Vector2i(17, -12)
const SECOND_SHOP := Vector2i(17, -7)
const WALLET: int = 25
const CHEAP: String = "crimson_draught"
const DEAR: String = "duelist_rapier"
const OLD_SHORTFALL: String = "need 215 more"
const NEW_SHORTFALL: String = "need 240 more"
const TIMEOUT_MSEC: int = 20000
const SIZE := Vector2i(1920, 1080)
var _failures: Array[String]
var _run_scene: Node
var _capture_dir: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 60
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var native: bool = DisplayServer.get_name() != "headless"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	if not _capture_dir.is_empty() and (not native or DirAccess.make_dir_recursive_absolute(_capture_dir) != OK):
		print("TEST RESULT: FAIL — feedback captures require a native renderer and writable output")
		quit(1)
		return
	if not native:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	Store.set_storage_path("user://feedback-profile.json")
	Store.set_run_storage_path("user://feedback-run.save")
	Settings.set_storage_path("user://feedback-settings.json")
	await _check_second_shop()
	await _check_purchase_tooltip()
	await _check_graft_reveal()
	if _failures.is_empty():
		print("TEST RESULT: PASS — second Scavenger entry, purchase tooltip, and graft reveal")
	else:
		print("TEST RESULT: FAIL — ", _failures.size(), " feedback UI checks")
	quit(int(not _failures.is_empty()))

func _check_second_shop() -> void:
	var engine := Run.new()
	var profile: Dictionary = Store.default_data()
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var state: Dictionary = engine.create_new_run(SHOP_SEED, profile)
	if Boons.pending(state): state = Boons.choose(engine, state, "")
	var first: Dictionary = Graph.room(state, FIRST_SHOP)
	Graph.resolve_mystery(state, first)
	first.merge({"revealed": true, "visited": true, "cleared": true}, true)
	Graph.room(state, SECOND_SHOP)["revealed"] = true
	state["current_room"] = FIRST_SHOP
	state["current_room_layout"] = engine._display_layout_for_room(SHOP_SEED, first, Vector2i.RIGHT)
	if not await _install(engine.repair_loaded_run_state(state), false): return
	var shop: Control = _run_scene._scavenger_shop_view
	await create_timer(0.8).timeout
	_expect(shop.visible and shop._canvas.scale.is_equal_approx(Vector2.ONE), "Finding 1 starting shop must be settled at 1.0")
	_key(KEY_M, true)
	_key(KEY_M, false)
	await process_frame
	if _run_scene._large_map_scrim.visible and _run_scene._large_map_view.can_activate_room(SECOND_SHOP):
		_run_scene._large_map_view.activate_room(SECOND_SHOP)
		if await _until(func() -> bool: return _run_scene._run_state["current_room"] == SECOND_SHOP and shop._entry_played_for_room):
			var start_scale: float = shop._canvas.scale.x
			await create_timer(0.8).timeout
			_expect(start_scale < 1.0 and is_equal_approx(shop._canvas.scale.x, 1.0),
				"Finding 1 second shop entry scale, starting %.6f, settled %.6f (expected 1.0)" % [start_scale, shop._canvas.scale.x])
			await _capture("second_shop_settled")
		else:
			_expect(false, "Finding 1 second shop did not arrive")
	else:
		_expect(false, "Finding 1 map route to the second shop is unavailable")
	await _clear_run()

func _check_purchase_tooltip() -> void:
	var state: Dictionary = ConfirmFixtures.state_for("scavenger_buy", 0)
	state["held_embers"] = WALLET
	state["unbanked_embers"] = WALLET
	state["progression"] = Store.set_embers(state["progression"], WALLET)
	if not await _install(state, true): return
	var shop: Control = _run_scene._scavenger_shop_view
	await process_frame
	var cheap: Button = shop._offer_sources["buy:" + CHEAP]
	var dear: Button = shop._offer_sources["buy:" + DEAR]
	cheap.grab_focus()
	shop._detail_action.grab_focus()
	await process_frame
	_move_pointer(dear.get_global_rect().get_center())
	if _expect(await _until(func() -> bool: return _visible_tooltip(root, OLD_SHORTFALL)), "Finding 2 original 215-Ember tooltip opened"):
		await _capture("scavenger_shortfall_before")
		_key(KEY_ENTER, true)
		_key(KEY_ENTER, false)
		var spent: bool = await _until(func() -> bool: return _run_scene._run_engine.held_embers(_run_scene._run_state) == 0)
		await process_frame
		_expect(spent and not _visible_tooltip(root, OLD_SHORTFALL) and NEW_SHORTFALL in dear.tooltip_text,
			"Finding 2 purchase must clear the old 215-Ember tooltip; stale=%s, current offer=%s" % [_visible_tooltip(root, OLD_SHORTFALL), dear.tooltip_text])
		_move_pointer(Vector2.ZERO)
		await process_frame
		_move_pointer(dear.get_global_rect().get_center())
		_expect(await _until(func() -> bool: return _visible_tooltip(root, NEW_SHORTFALL)), "Finding 2 rehover opens the 240-Ember tooltip")
		await _capture("scavenger_shortfall_after")
	await _clear_run()

func _check_graft_reveal() -> void:
	var view := GraftView.new()
	root.add_child(view)
	var state: Dictionary = ConfirmFixtures.state_for("graft_commit", 0)
	view.configure(state, false)
	view.present()
	view.begin_work()
	view.select_recipient(ConfirmFixtures.RECIPIENT)
	view.select_donor(ConfirmFixtures.DONOR)
	view.select_source(ConfirmFixtures.GRAFT_CARD_INDEX)
	view.select_target(ConfirmFixtures.GRAFT_CARD_INDEX)
	var completed: Dictionary = Run.new().graft_equipment(state, view.recipient, view.donor, view.donor_index, view.target_index)
	await view.present_result(completed)
	var inherited: Button = view.find_child("ResultCard_1", true, false)
	if _expect(is_instance_valid(inherited) and inherited.is_visible_in_tree(), "Finding 5 inherited result card is mounted for its reveal"):
		_expect(is_zero_approx(inherited._lift) and is_zero_approx(inherited.artwork.position.y),
			"Finding 5 inherited card starts at zero, observed lift %.6f and art y %.6f" % [inherited._lift, inherited.artwork.position.y])
		await _capture("graft_first_fade", func() -> bool: return view._content.modulate.a > 0.0)
		await create_timer(0.10).timeout
		_expect(inherited._lift > 0.0, "Finding 5 inherited lift advances during the reveal")
	view.queue_free()
	await process_frame

func _install(state: Dictionary, reduced: bool) -> bool:
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0, "reduced_motion": reduced}, true)
	Settings.save_settings(settings)
	if not _expect(Store.save_data(state["progression"]) and Store.save_run_state(state), "Saved feedback fixture"): return false
	_run_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(_run_scene)
	current_scene = _run_scene
	if not _expect(await _until(_run_scene.has_installed_run), "Installed feedback fixture"): return false
	_run_scene._load_run_state(state)
	_run_scene._close_dialogue()
	_run_scene._close_large_map()
	return true

func _clear_run() -> void:
	_run_scene.queue_free()
	await process_frame
	await _until(func() -> bool: return not Assets.has_preparation_drains(root))

func _until(ready: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while not bool(ready.call()) and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(ready.call())

func _key(code: Key, pressed: bool) -> void:
	var input := InputEventKey.new()
	input.keycode = code
	input.pressed = pressed
	root.push_input(input, true)

func _move_pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = Vector2.ONE
	root.push_input(event, true)

func _capture(stem: String, ready: Callable = Callable()) -> void:
	if _capture_dir.is_empty(): return
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	await RenderingServer.frame_post_draw
	while ready.is_valid() and not bool(ready.call()):
		if not _expect(Time.get_ticks_msec() < deadline, stem + " reached the capture frame"): return
		await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _capture_dir.path_join(stem + ".png")
	if _expect(image != null and image.get_size() == SIZE and image.save_png(path) == OK, "Captured " + stem):
		print(path)

func _visible_tooltip(node: Node, text: String) -> bool:
	if node is Label and node.is_visible_in_tree() and text in node.text: return true
	for child: Node in node.get_children(true):
		if _visible_tooltip(child, text): return true
	return false

func _expect(ok: bool, message: String) -> bool:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: _failures.append(message)
	return ok
