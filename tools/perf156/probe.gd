extends SceneTree
## Capture and sample in separate processes so readback never enters a timing take.

const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const SectionFixtures = preload("res://tests/suites/section_transition_suite.gd")
const HistoryFixtures = preload("res://tests/chronicle_probe.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const MENU_SCENE = preload("res://scenes/main_menu.tscn")

const SIZE := Vector2i(1920, 1080)
const TOUR_SEED: int = 83
const FRAME_LIMIT: int = 60
const FIRST_VISIT_FRAMES: int = 30
const SETTLE_FRAMES: int = 12
const WATCHDOG_MSEC: int = 20000
const SECTION_COUNT: int = 6

var _output: String
var _capture: bool = false
var _recap_only: bool = false
var _cold_killer: bool = false
var _headless: bool
var _scene: Node
var _telemetry: Node
var _history: Dictionary = {}
var _frames: Array[Dictionary]
var _errors: PackedStringArray
var _scope: String
var _previous_usec: int
var _peak_bytes: int
var _fixtures: SceneTree

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		elif arg == "--capture": _capture = true
		elif arg == "--recap-only": _recap_only = true
		elif arg == "--cold-killer": _cold_killer = true
	_run.call_deferred()

func _run() -> void:
	if _output.is_empty() or (_headless and _capture):
		push_error("PERF156: supply --output=DIR and a renderer for --capture")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	SectionFixtures.prepare_storage()
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	OS.low_processor_usage_mode = false
	if not _headless:
		Engine.max_fps = FRAME_LIMIT
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_telemetry = root.get_node("PerformanceTelemetry")
	_fixtures = Fixtures.new()
	if not _recap_only:
		await _continue_and_grimoire()
		await _chronicle()
	await _recap()
	if not _recap_only:
		await _remaining_visits()
	_fixtures.free()
	_finish()

func _remaining_visits() -> void:
	for index: int in range(SECTION_COUNT - 1):
		await _section_entry(index)
	var checkpoint: Dictionary = Store.load_saved_run()
	var section: Dictionary = Graph.section(checkpoint, Graph.active_section(checkpoint))
	await _repeat_continue(checkpoint, "later-section-repeat", "res://assets/art/backgrounds/sections/%s.png" % section.get("boss_id", ""))
	for boss: String in Bosses.BOSS_ELEMENTS:
		var guardian: String = str(Guardians.DEFINITIONS[boss]["id"])
		await _encounter("dragon", boss, SectionFixtures.fixture(_boss_index(boss), "encounter"))
		await _encounter("guardian", guardian, _fixtures.make("guardian", TOUR_SEED, {"guardian_id": guardian}))
	for room: String in ["campfire", "scavenger", "graftwright", "event", "treasure"]:
		await _room(room)

func _finish() -> void:
	var report := FileAccess.open(_output.path_join("first-visits.json"), FileAccess.WRITE)
	if report == null:
		_errors.append("Could not write first-visits.json")
	else:
		report.store_string(JSON.stringify({
			"schema": 1, "headless": _headless, "capture": _capture,
			"display": DisplayServer.get_name(), "viewport": [SIZE.x, SIZE.y], "ui_scale": 1.0,
			"godot": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(),
			"cpu": OS.get_processor_name(), "adapter": RenderingServer.get_video_adapter_name(),
			"frames": _frames, "load_scopes": _history, "errors": _errors,
			"peak_texture_bytes": null if _headless else _peak_bytes,
			"post_teardown_texture_bytes": null if _headless else _texture_bytes(),
			"post_teardown_asset_cache_paths": Assets._texture_cache.size(),
		}, "\t"))
		report.close()
	for error: String in _errors: push_error(error)
	print("PERF156 FIRST VISITS: %s (%d scopes, %d errors) %s" % [
		"PASS" if _errors.is_empty() else "FAIL", _history.size(), _errors.size(), _output])
	quit(0 if _errors.is_empty() else 1)

func _continue_and_grimoire() -> void:
	var state: Dictionary = _fixtures.make("start", TOUR_SEED)
	if not await _resume(state, "continue_start"): return
	await _finish_visit("continue-start")
	_scene.call("_close_dialogue")
	await _idle(SETTLE_FRAMES)
	_begin("grimoire")
	_scene.call("_open_grimoire_overlay")
	await _idle(FIRST_VISIT_FRAMES)
	_expect(_visible("_grimoire_scrim") and not str(_scene.get("_grimoire_detail_title").text).is_empty(), "Grimoire opened with a detail page")
	await _finish_visit("grimoire", 0)
	_scene.call("_close_grimoire_overlay")
	await _idle(SETTLE_FRAMES)
	await _retire()

func _resume(state: Dictionary, scope: String) -> bool:
	if not _expect(not state.is_empty() and Store.save_run_state(state), scope + " checkpoint saved"): return false
	_install(MENU_SCENE)
	await _idle(SETTLE_FRAMES)
	var button: Button = _scene.get_node("MenuColumn/ContinueButton")
	_expect(not button.disabled, scope + " can Continue with the staged checkpoint")
	_begin(scope)
	button.pressed.emit()
	var deadline: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while (not is_instance_valid(current_scene) or current_scene == _scene or root.gui_disable_input) and Time.get_ticks_msec() < deadline:
		await _frame()
	if not _expect(is_instance_valid(current_scene) and current_scene != _scene and not root.gui_disable_input, scope + " hands off to an interactive run"):
		_end()
		await _retire()
		return false
	_scene = current_scene
	_expect(_scene.get("_run_state").get("seed") == state.get("seed") and _scene.initial_presentation_is_ready(), scope + " restored the requested seed and finished initial UI")
	return true

func _chronicle() -> void:
	Store.save_data(HistoryFixtures.tile_fixture_profile())
	_install(MENU_SCENE)
	await _idle(SETTLE_FRAMES)
	_begin("chronicle")
	_scene.call("_on_chronicle_button_pressed")
	await _idle(FIRST_VISIT_FRAMES)
	_expect(_visible("_chronicle") and _scene.get("_chronicle").get("selected_index") == 0, "Chronicle opened the newest record")
	await _finish_visit("chronicle", 0)
	await _retire()

func _recap() -> void:
	const KILLER: String = "craghide"
	var state: Dictionary = _fixtures.make("guardian", TOUR_SEED, {"guardian_id": KILLER})
	if not await _resume(state, "recap_encounter_continue"): return
	_scene.call("_close_dialogue")
	await _idle(SETTLE_FRAMES)
	_end()
	var before: Dictionary = _scene.get("_combat_state")
	var after: Dictionary = before.duplicate(true)
	after["player"]["hp"] = 0
	after["run_stats"]["killer"] = {"cause": "attack", "enemy_type": KILLER, "damage": before["player"]["hp"]}
	var terminal: Dictionary = _scene.call("_run_state_for_combat_checkpoint", _scene.get("_run_state"), after)
	if not _expect(terminal.get("mode") == "defeat", "Lethal checkpoint reaches the real defeat boundary"):
		await _retire()
		return
	var killer_path: String = _scene.call("_combat_portrait_path", KILLER)
	if _cold_killer: Assets._texture_cache.erase(killer_path)
	_begin("recap_death_cover")
	await _scene.call("_animate_defeats_and_terrain_destruction", before, after)
	if _cold_killer: _expect(Assets._texture_cache.has(killer_path), "The defeat cover prepared a cache-missing killer portrait before reveal")
	# The probe samples the recap after the authored heirloom decision. Use the
	# normal decline rule before committing the terminal checkpoint.
	terminal = preload("res://scripts/opening_boon_rules.gd").leave_heirloom(terminal, "")
	terminal = _scene.call("_hold_committed_run_state", terminal, "perf156_recap_fixture")
	_end()
	_begin("recap")
	_scene.set("_run_state", terminal)
	_scene.call("_sync_combat_state_from_run")
	_scene.call("_release_committed_run_state")
	_scene.call("_refresh_ui")
	await _idle(FIRST_VISIT_FRAMES)
	_expect(_visible("_run_end_recap"), "Defeat recap became visible")
	var recap: Control = _scene.get("_run_end_recap")
	var portrait: Control = recap.find_child("KillerPortrait", true, false)
	_expect(recap.recap_model().get("killer", {}).get("enemy_type", "") == KILLER and is_instance_valid(portrait) and portrait.visible, "Defeat recap preserved the real killer and approved portrait")
	_end()
	if _capture and _visible("_run_end_recap"):
		recap.set_motion_enabled(false)
		_scene.call("_seek_run_end_board_reframe", 1.0)
		await _save("recap")
	await _retire()

func _section_entry(index: int) -> void:
	var label: String = "section-%d-entry" % (index + 2)
	if not await _resume(SectionFixtures.fixture(index), label + "-cover"): return
	await _idle(SETTLE_FRAMES)
	_end()
	var target: Vector2i = Graph.section(_scene.get("_run_state"), index + 1).get("entry", Graph.INVALID)
	var button: Button = _scene.find_child("DragonRewardContinue", true, false)
	if not _expect(is_instance_valid(button), label + " has a Continue button"):
		await _retire()
		return
	_begin(label)
	button.pressed.emit()
	var deadline: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while is_instance_valid(_scene.get("_section_transition")) and Time.get_ticks_msec() < deadline:
		await _frame()
	_expect(_scene.get("_run_state").get("current_room") == target, label + " installed the expected threshold")
	_expect(Store.load_saved_run().get("current_room") == target, label + " persisted the expected threshold")
	await _finish_visit(label)
	await _retire()

func _boss_index(boss: String) -> int:
	for index: int in range(SECTION_COUNT):
		if Bosses.boss_id_for_depth(SectionFixtures.FIXTURE_SEED, (index + 1) * Bosses.DEPTHS_PER_SEQUENCE) == boss: return index
	return -1

func _encounter(kind: String, actor: String, state: Dictionary) -> void:
	if not _expect(not state.is_empty(), kind + " fixture exists for " + actor): return
	_install(RUN_SCENE)
	await _idle(SETTLE_FRAMES)
	var label: String = kind + "-" + actor
	_begin(label)
	_scene.call("_load_run_state", state)
	_scene.call("_close_dialogue")
	await _idle(FIRST_VISIT_FRAMES)
	var combat: Dictionary = _scene.get("_combat_state")
	_expect((combat.get("enemies", []) as Array).any(func(enemy: Dictionary) -> bool: return enemy.get("type") == actor), label + " installed the requested actor")
	await _finish_visit(label, 0)
	await _retire()

func _room(kind: String) -> void:
	var state: Dictionary = _fixtures.make(kind, TOUR_SEED)
	if not _expect(not state.is_empty(), kind + " fixture exists"): return
	_install(RUN_SCENE)
	await _idle(SETTLE_FRAMES)
	_begin(kind)
	_scene.call("_load_run_state", state)
	await _idle(FIRST_VISIT_FRAMES)
	_expect(_scene.get("_run_state").get("current_room") == state.get("current_room"), kind + " installed the requested room")
	await _finish_visit(kind, 0)
	await _retire()
	match kind:
		"campfire":
			await _repeat_continue(state, "campfire-repeat", "res://assets/art/tiles/campfire_bonfire_idle.png")
		"scavenger":
			await _repeat_continue(state, "scavenger-repeat", "res://assets/art/ui/scavenger_shop/inspection_frame_v1.png")

func _repeat_continue(state: Dictionary, label: String, path: String) -> void:
	var retained: Texture2D = Assets._texture_cache.get(path)
	_expect(retained != null, label + " found the visited art after teardown")
	if not await _resume(state, label): return
	_expect(Assets._texture_cache.get(path) == retained, label + " reused the same texture through Continue")
	_end()
	await _retire()

func _install(packed: PackedScene) -> void:
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene

func _retire() -> void:
	if is_instance_valid(_scene): _scene.queue_free()
	_scene = null
	await _idle(SETTLE_FRAMES)
	_peak_bytes = maxi(_peak_bytes, _texture_bytes())

func _visible(field: String) -> bool:
	var control: Control = _scene.get(field)
	return is_instance_valid(control) and control.is_visible_in_tree()

func _expect(ok: bool, message: String) -> bool:
	if not ok: _errors.append(message)
	return ok

func _begin(scope: String) -> void:
	_scope = scope
	_telemetry.take_hitch_events()
	_previous_usec = Time.get_ticks_usec()
	_history[scope] = {}

func _end() -> void:
	_scope = ""

func _finish_visit(label: String, frames: int = FIRST_VISIT_FRAMES) -> void:
	await _idle(frames)
	_end()
	await _save(label)

func _save(label: String) -> void:
	if not _capture: return
	await _idle(SETTLE_FRAMES)
	var image: Image = root.get_texture().get_image()
	if not _expect(image != null and image.get_size() == SIZE, label + " captured at 1920x1080"): return
	var path: String = _output.path_join(label + ".png")
	if _expect(image.save_png(path) == OK, label + " saved"): print(path)

func _idle(count: int) -> void:
	for frame: int in range(count): await _frame()

func _frame() -> void:
	if _headless: await process_frame
	else: await RenderingServer.frame_post_draw
	var now: int = Time.get_ticks_usec()
	var bytes: int = _texture_bytes()
	_peak_bytes = maxi(_peak_bytes, bytes)
	if _scope.is_empty(): return
	var loads: Dictionary = _telemetry.take_hitch_events()
	var scope_loads: Dictionary = _history[_scope]
	for label: String in loads:
		if not label.begins_with("load:"): continue
		var path: String = label.trim_prefix("load:")
		var entry: Dictionary = loads[label]
		scope_loads[path] = int(scope_loads.get(path, 0)) + int(entry.get("total_us", 0))
	_frames.append({"screen": _scope, "ms": float(now - _previous_usec) / 1000.0,
		"texture_bytes": null if _headless else bytes, "focused": null if _headless else DisplayServer.window_is_focused()})
	_previous_usec = now

func _texture_bytes() -> int:
	return 0 if _headless else RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
