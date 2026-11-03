extends SceneTree

# Untimed, native pixel oracle for the exact HUD contours and overlay commands.
# Full-scene idle/hover/action proof remains combat_frame_scenarios.gd --captures.
const Board = preload("res://scripts/combat_board_view.gd")
const Reference = preload("res://tests/perf/hover_board_reference.gd")
const Arena = preload("res://tests/suites/warband_suite.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const DrawCases = preload("res://tests/perf/hover_draw_cases.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_SECONDS: float = 0.3
const SETTLE_FRAMES: int = 3
const OUTPUT: String = "res://output/perf-04/native"
const CONTROLLER_VARIANT: String = "air"
const TORCH_PILLAR_TILE := Vector2i(4, 3)
const OBSTACLE_MARGIN: float = 25.0
var failures: Array[String]
var _setup_only: bool = false

class CandidateCanvas extends Board:
	func _draw() -> void:
		if _is_dynamic_render_layer or _is_static_render_cache_layer: super._draw()

class ReferenceCanvas extends Reference:
	func _draw() -> void:
		if _is_dynamic_render_layer or _is_static_render_cache_layer: super._draw()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_setup_only = OS.get_cmdline_user_args().has("--setup-only")
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not _setup_only:
		print("PERF04 NATIVE EQUIVALENCE: native renderer required")
		quit(1)
		return
	preload("res://scripts/settings_store.gd").set_storage_path("user://perf04-proof-settings.json")
	var settings: Dictionary = preload("res://scripts/settings_store.gd").default_settings()
	settings["ui_scale"] = 1.0
	preload("res://scripts/settings_store.gd").save_settings(settings)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	if not _setup_only: DisplayServer.window_set_size(PROOF_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for variant: String in ["ordinary", "air", "lightning"]:
		for layer: String in ["overlay", "hud", "foreground"]:
			var state: Dictionary = Arena.arena() if variant == "ordinary" else Arena.battle(variant)
			state.erase("umbra")
			state["grid"][TORCH_PILLAR_TILE.y][TORCH_PILLAR_TILE.x] = "pillar"
			var shown: Dictionary = {"reduced_motion": true, "show_all_enemy_intents": true, "threats_proof_seconds": PROOF_SECONDS, "torch_mote_proof_seconds": PROOF_SECONDS,
				"threats_at_rest": Badges.build(Arena.Combat.new(), state, state)}
			await _capture_pair(state, shown, state["enemies"][0]["pos"], layer, variant, variant == CONTROLLER_VARIANT)
	# Exercise the selectors with nonempty content, then move/hide/block/remove it.
	var draw_state: Dictionary = DrawCases.fixture()
	for mutation: int in range(DrawCases.TORCH_CLOCKS.size()):
		var shown: Dictionary = DrawCases.presentation_for(draw_state, DrawCases.TORCH_CLOCKS[mutation])
		DrawCases.mutate_fixture(draw_state, shown, mutation)
		for layer: String in ["overlay", "foreground"]:
			await _capture_pair(draw_state, shown, DrawCases.BURST_TILE if mutation < 2 else Vector2i(-1, -1), layer, "selectors-%d" % mutation)
	for controller: bool in [false, true]:
		var state: Dictionary = Arena.arena()
		await _capture_pair(state, {"reduced_motion": true}, state["enemies"][0]["pos"], "hud", "obstacle-controller" if controller else "obstacle-hover", false, "obstacle-controller" if controller else "obstacle")
	for facing: String in ["front", "rear"]:
		var state: Dictionary = Arena.arena()
		state.erase("objective")
		state["enemies"][0]["type"] = "crawler"
		await _capture_pair(state, {"reduced_motion": true}, state["enemies"][0]["pos"], "hud", "pose-" + facing, false, facing)
	for failure: String in failures: push_error(failure)
	print("PERF04 %s RESULT: %s (%d failures)%s" % ["NATIVE SETUP" if _setup_only else "NATIVE EQUIVALENCE", "PASS" if failures.is_empty() else "FAIL", failures.size(), "; pixels not checked" if _setup_only else ""])
	quit(0 if failures.is_empty() else 1)

func _capture_pair(state: Dictionary, shown: Dictionary, focus: Vector2i, layer: String, label: String, controller: bool = false, mutation: String = "") -> void:
	var viewports: Array[SubViewport]
	var canvases: Array[Control]
	for reference: bool in [false, true]:
		var viewport := SubViewport.new()
		viewport.size = PROOF_SIZE
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var canvas: Control = ReferenceCanvas.new() if reference else CandidateCanvas.new()
		canvas.size = Vector2(PROOF_SIZE)
		viewport.add_child(canvas)
		canvases.append(canvas)
		canvas.set_process(false)
		canvas.set("_controller_focus_tile" if controller else "_hover_tile", focus)
		canvas.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown.duplicate(true))
		_isolate_retained_layer(canvas, layer)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	if mutation.begins_with("obstacle"):
		var intent := Rect2()
		for entry: Dictionary in canvases[1].get("_hud_layout_entries_cache"):
			if entry.get("kind") == "enemy" and entry.get("layout", {}).get("intent_rect", Rect2()).has_area():
				intent = entry["layout"]["intent_rect"]
				break
		_expect(intent.has_area(), "Native obstacle covers an expanded intent")
		shown = shown.duplicate(true)
		shown["hud_obstacle_global_rects"] = [intent.grow(OBSTACLE_MARGIN)]
		for canvas: Control in canvases:
			canvas.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown.duplicate(true))
			if mutation == "obstacle-controller": canvas.call("set_controller_focus_tile", focus)
	elif mutation in ["front", "rear"]:
		for canvas: Control in canvases:
			for unit: Dictionary in canvas.call("_hud_layout_units"):
				if str(unit.get("type", "")) != "crawler": continue
				var renderer: Node = canvas.call("unit_cutout_renderer", unit)
				renderer.set_process(false)
				renderer.set("facing", mutation)
				renderer.set("mirrored", mutation == "rear")
			canvas.call("_queue_hover_redraws")
	for canvas: Control in canvases: _isolate_retained_layer(canvas, layer)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	if not _setup_only:
		await RenderingServer.frame_post_draw
		var candidate: Image = viewports[0].get_texture().get_image()
		var reference: Image = viewports[1].get_texture().get_image()
		_expect(candidate.get_data() == reference.get_data(), "Exact retained native pixels: " + label + "/" + layer)
	if layer == "hud":
		for canvas: Control in canvases:
			_expect(canvas.get("_hud_layout_entries_cache") == canvas.get("_hud_render_layer").get("_hud_layout_entries_cache"), "Native retained HUD matches parent: " + label)
	for index: int in range(viewports.size()):
		if not _setup_only:
			var path: String = ProjectSettings.globalize_path(OUTPUT.path_join("%s-%s-%s.png" % [label, layer, "candidate" if index == 0 else "reference"]))
			_expect(viewports[index].get_texture().get_image().save_png(path) == OK, "Saved capture")
			print(path)
		viewports[index].queue_free()
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _isolate_retained_layer(canvas: Control, layer: String) -> void:
	# Keep production retained layers and synchronization enabled. Isolate only
	# visibility for layer pixels; never substitute a direct draw.
	var retained: Control = canvas.get({"overlay": "_overlay_render_layer", "foreground": "_foreground_render_layer", "hud": "_hud_render_layer"}[layer])
	_expect(retained != null, "Production retained layer exists: " + layer)
	for child: Node in canvas.get_children():
		if child is CanvasItem: child.visible = child == retained
	canvas.call("_queue_render_layer_redraw", retained)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
