extends SceneTree
## Report-only observer for the hitch-census tour. QA107_STATE and QA107_HOVER
## select one deterministic snapshot for a native visual_probe_runner replay.

const Tour = preload("res://tools/hitch_census/tour.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Check = preload("res://tools/qa107/layout_geometry.gd")
const Hover = preload("res://tools/qa107/layout_hover.gd")
const Routes = preload("res://tools/qa107/layout_routes.gd")
const ViewportCheck = preload("res://tools/hitch_census/viewport.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")

class Fixtures extends "res://tools/hitch_census/fixtures.gd":
	func make_authored_tutorial(seed_value: int) -> Dictionary:
		_failed = false
		census_error = ""
		_options = {"scenario": "guided_tutorial", "seed": seed_value, "hero_facing": "persist"}
		var state: Dictionary = _build_run_state("guided_tutorial", _build_progression())
		if _failed: return {}
		if not Guided.is_authored(state.get("combat_state", {})):
			census_error = "Inspection fixture did not reach the authored tutorial."
			return {}
		return state

const CONFIGS := {
	"desktop": [Vector2i(1920, 1080), 1.0],
	"deck": [Vector2i(1280, 800), 1.15],
	"deck-100": [Vector2i(1280, 800), 1.0],
}
const FIXTURE_SEED: int = 83
const FIXED_FPS: int = 60
const SETTLE_SECONDS: float = 0.45
const SETTLE_FRAMES: int = 8
const ANIMATION_LIMIT_SECONDS: float = 4.0
const EXTRA_FIXTURES := {
	"graftwright_stocked": ["graftwright", {"equipment_inventory": "boiled_leather,glassbone_cuirass"}],
	"reach_exit": ["reach_exit", {}],
	"character_inventory": ["character", {"item_inventory": "crimson_draught,nail_bomb", "equipped_items": "crimson_draught", "magic_inventory": "pale_spark", "relics": "iron_lung,ember_lens"}],
	"combat_details": ["combat", {"enemy_types": "storm_capacitor", "item_drops": "nail_bomb@6:1", "surfaces": "fire@4:3,rubble@4:3"}],
	"guided_tutorial_authored": ["guided_tutorial", {}],
}
const STATUS_BURN_STACKS: int = 3
const SCOPED_SCREENS := {
	"pre_battle": "_pre_battle_scrim", "scavenger": "_scavenger_shop_view",
	"graftwright": "_graftwright_view", "event": "_event_view",
	"victory": "_run_end_recap", "defeat": "_run_end_recap",
}

var scene: Node
var finished: bool = false
var errors: Array[String]
var run_seed: int = FIXTURE_SEED
var screen: String
var stage: String
var profile: String
var target_state: String
var target_hover: String
var native: bool
var report: FileAccess
var states: int = 0
var opened: int = 0
var issues: int = 0
var captured: bool = false
var hover := Hover.new()

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	profile = OS.get_environment("QA107_PROFILE")
	if profile.is_empty(): profile = "desktop"
	target_state = OS.get_environment("QA107_STATE")
	target_hover = OS.get_environment("QA107_HOVER")
	native = DisplayServer.get_name() != "headless"
	if not CONFIGS.has(profile) or (native and target_state.is_empty()) or (not target_hover.is_empty() and target_state.is_empty()):
		_fail("Use desktop, deck or deck-100, and select QA107_STATE for native capture.")
		return
	if Runtime.current_namespace().is_empty():
		_fail("Requires an isolated task runner.")
		return
	var output: String = OS.get_environment("QA107_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("user://qa107")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create output directory " + output)
		return
	report = FileAccess.open(output.path_join("layout-" + profile + ".jsonl"), FileAccess.WRITE)
	if report == null:
		_fail("Cannot write layout witness in " + output)
		return

	var configuration: Array = CONFIGS[profile]
	Settings.set_storage_path("user://qa107-settings.json")
	Store.set_storage_path("user://qa107-progression.json")
	Store.set_run_storage_path("user://qa107-run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = configuration[1]
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	if not Settings.save_settings(settings):
		_fail("Could not save isolated QA settings.")
		return
	Store.save_data(preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(Store.default_data()))
	root.mode = Window.MODE_WINDOWED
	root.gui_embed_subwindows = true
	root.size = configuration[0]
	root.content_scale_factor = configuration[1]
	root.set_meta("labyrinth_performance_probe_seed", run_seed)
	root.notify_mouse_entered()
	# Runtime scripts that await post-draw still need to advance with the dummy renderer.
	if not native: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	Engine.max_fps = FIXED_FPS if native else 0
	Engine.physics_ticks_per_second = FIXED_FPS
	await _frames(SETTLE_FRAMES)
	var viewport: Dictionary = ViewportCheck.capture(root)
	viewport["logical_rect"] = Check.rect_data(root.get_visible_rect())
	viewport["profile"] = profile
	var backing: Variant = viewport["root_pixel_size"]
	var pixels: Vector2i = configuration[0]
	if root.size != pixels or not is_equal_approx(root.content_scale_factor, float(configuration[1])) or (native and backing != [pixels.x, pixels.y]):
		_fail("Unexpected viewport " + JSON.stringify(viewport))
		return
	record("viewport", viewport)
	print("QA107 VIEWPORT " + JSON.stringify(viewport))
	var state_root: String = target_state.get_slice("/", 0)
	if not EXTRA_FIXTURES.has(state_root): await Tour.new().run(self)
	if not finished: await _extra_fixtures()
	if not target_state.is_empty() and (states == 0 or (not target_hover.is_empty() and opened == 0)):
		errors.append("Requested snapshot was not reproduced: " + target_state + "/" + target_hover)
	if native and not captured: errors.append("No native PNG was written.")
	for error: String in errors: push_error("QA107: " + error)
	record("summary", {"states": states, "opened_tooltips": opened, "candidate_findings": issues, "errors": errors})
	var witness_path: String = report.get_path_absolute()
	report.close()
	print("QA107 WITNESS=" + witness_path)
	print("QA107 RESULT: %s profile=%s states=%d opened=%d candidates=%d errors=%d" % [
		"PASS" if errors.is_empty() else "FAIL", profile, states, opened, issues, errors.size()])
	quit(0 if errors.is_empty() else 1)

func _extra_fixtures() -> void:
	var builder := Fixtures.new()
	for kind: String in EXTRA_FIXTURES:
		if finished: break
		if not target_state.is_empty() and not (target_state == kind or target_state.begins_with(kind + "/")): continue
		var fixture: Array = EXTRA_FIXTURES[kind]
		# The census builder completes the tutorial for its timing survey.
		# Exercise the authored inspection fixture on its own isolated profile.
		var authored: bool = kind == "guided_tutorial_authored"
		var state: Dictionary = builder.make_authored_tutorial(run_seed) if authored else builder.make(fixture[0], run_seed, fixture[1])
		if state.is_empty():
			errors.append(kind + ": " + builder.census_error)
			continue
		if kind == "combat_details":
			var combat: Dictionary = state["combat_state"]
			var enemy: Dictionary = combat["enemies"][0]
			enemy["burn"] = STATUS_BURN_STACKS
		if authored and not Store.save_data(state["progression"]):
			errors.append(kind + ": could not install the isolated tutorial profile")
			continue
		await _enter_scene("res://scenes/run_scene.tscn")
		scene.set("_progression", state["progression"])
		scene.call("_load_run_state", state)
		scene.call("_close_dialogue")
		await settle()
		if authored and not bool(scene.call("_guided_tutorial_is_active")):
			errors.append(kind + ": tutorial was inactive after load")
			continue
		await inspect(kind)
		if not finished: await Routes.visit(self, kind)
	builder.free()

func _enter_scene(path: String) -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	scene = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene

func mark(label: String, step: String = "action") -> void:
	screen = label
	stage = step

func hold(_duration: float) -> void:
	if finished: return
	if stage == "tour_open" and screen == "grimoire":
		await inspect("start/grimoire", scene.get("_grimoire_scrim"))
		if not finished: await Routes.grimoire(self)
		return
	if stage == "tour_open" and screen == "character":
		await inspect("start/character_gear", scene.get("_upgrade_scrim"))
		return
	var name: String = screen
	if stage == "tour_open": name = "start/" + screen
	if screen in ["victory", "defeat"]:
		var recap: Control = scene.get("_run_end_recap")
		if is_instance_valid(recap): recap.call("skip_presentation")
	var field: String = Tour.OVERLAY_FIELDS.get(screen, "") if stage == "tour_open" else SCOPED_SCREENS.get(screen, "")
	var surface: Control = scene.get(field) if not field.is_empty() else null
	if not field.is_empty() and surface == null:
		errors.append(name + ": inspection surface was absent")
		return
	await inspect(name, surface)
	if stage != "tour_open" and not finished: await Routes.visit(self, screen)

func settle() -> void:
	await _frames(SETTLE_FRAMES)
	var limit: int = Time.get_ticks_msec() + int(ANIMATION_LIMIT_SECONDS * 1000.0)
	while scene.get_script().resource_path == "res://scripts/run_scene.gd":
		var centering: Tween = scene.get("_board_centering_tween")
		if not bool(scene.get("_animation_lock")) and (centering == null or not centering.is_running()): break
		if Time.get_ticks_msec() >= limit:
			errors.append(screen + ": layout did not settle")
			break
		await process_frame

func inspect(name: String, surface: Control = null) -> void:
	if finished or (not target_state.is_empty() and target_state != name): return
	await create_timer(SETTLE_SECONDS).timeout
	await _frames(SETTLE_FRAMES)
	if surface != null and not surface.is_visible_in_tree():
		errors.append(name + ": inspection surface did not open")
		return
	states += 1
	if target_hover.is_empty(): await snapshot(name, "", {}, Array([], TYPE_OBJECT, &"Node", null))
	if not captured and (not native or not target_hover.is_empty()):
		await hover.visit(self, name, target_hover, surface)
	print("QA107 STATE " + name)
	if not target_state.is_empty() and not native: finished = true

func snapshot(name: String, key: String, source: Dictionary, surfaces: Array[Node]) -> void:
	var result: Dictionary = Check.scan(scene, root, surfaces)
	result.merge({"state": name, "hover": key, "source": source})
	if scene.get_script().resource_path == "res://scripts/run_scene.gd":
		result["mode"] = scene.get("_run_state").get("mode", "")
		if name.begins_with("guided_tutorial"):
			result["guided_tutorial_active"] = bool(scene.call("_guided_tutorial_is_active"))
	issues += (result["findings"] as Array).size()
	record("snapshot", result)
	if not key.is_empty(): opened += 1
	if native:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var config: Array = CONFIGS[profile]
		var filename: String = "qa107-%s-%s%s.png" % [profile, name.replace("/", "-"), "-" + key if not key.is_empty() else ""]
		var path: String = report.get_path_absolute().get_base_dir().path_join(filename)
		if image == null or image.get_size() != config[0] or image.save_png(path) != OK:
			errors.append("Native PNG failed: " + path)
			return
		print(path)
		captured = true
		finished = true

func record(kind: String, row: Dictionary) -> void:
	row["kind"] = kind
	report.store_line(JSON.stringify(row))
	report.flush()

func _frames(count: int) -> void:
	for frame: int in range(count): await process_frame

func _fail(message: String) -> void:
	push_error("QA107: " + message)
	quit(2)
