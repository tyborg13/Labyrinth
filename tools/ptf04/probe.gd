extends SceneTree

const Fixtures = preload("res://tools/ptf04/fixtures.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Map = preload("res://scripts/section_map_panel.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const TOOLTIP_WAIT_SECONDS: float = 1.0
const SETTLE_SECONDS: float = 0.35
const DEATH_SETTLE_SECONDS: float = 2.5
const PROOF_CONTRACT: String = "res://tools/ptf04/proof.json"
var failed: bool = false
var logic_only: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_storage_path("user://ptf04_probe_progression.json")
	Store.set_run_storage_path("user://ptf04_probe_run.save")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://ptf04_probe_analytics")
	Settings.set_storage_path("user://ptf04_probe_settings.json")
	_run.call_deferred()

func _run() -> void:
	logic_only = OS.get_cmdline_user_args().has("--logic-only")
	if DisplayServer.get_name() == "headless" and not logic_only:
		push_error("PTF04 proof requires the windowed visual probe runner")
		quit(1)
		return
	if not logic_only:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Fixtures.PROOF_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Fixtures.PROOF_SIZE
	root.content_scale_factor = 1.0
	root.size = Fixtures.PROOF_SIZE
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	if not logic_only:
		check(preload("res://scripts/cel_look.gd").mode == "all", "Cel look must be enabled")
		check(FileAccess.file_exists("res://cel_look_variants/manifest.json"), "Prepare approved cel-look variants before capture")
		for filename: String in ["02_map_legend_hover.png", "03_graftwright_node_hover.png"]:
			var path: String = Fixtures.OUTPUT.path_join(filename)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await settle()
	var guided: Dictionary = Fixtures.combat_run(true)
	check(Guided.is_authored(guided["combat_state"]), "Generated first fight must use guided setup")
	scene.call("_load_run_state", guided)
	scene.call("_close_dialogue")
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")
	await settle()
	var combat: Dictionary = scene.get("_combat_state")
	await scene.call("_on_board_tile_clicked", combat["player"]["pos"])
	await settle()
	await scene.call("_on_board_tile_clicked", Guided.move_tile(combat))
	await settle()
	scene.call("_on_board_tile_hovered", Guided.support_tile(combat))
	await settle()
	check(str(scene.get("_guided_tutorial_phase_id")) == Tutorial.PHASE_CONFIRM_INTENT, "Tutorial must show step-two intent confirmation")
	await capture("01_tutorial_step_2.png")
	# Load a separate non-tutorial fixture, then open the actual RunScene map.
	# A detached panel can exist and answer queries while another surface renders.
	var state: Dictionary = Fixtures.combat_run()
	var current: Vector2i = state["current_room"]
	Graph.room(state, current)["type"] = "graftwright"
	Graph.room(state, current)["revealed"] = true
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")
	scene.call("_open_large_map")
	await settle()
	var panel: Control = scene.get("_large_map_view")
	check(_map_is_open(scene, panel), "Normal map-opening path must expose the section map")
	panel.call("reset_interaction")
	await hover(Vector2.ZERO)
	var legend_icon: Control = panel.find_child("Legend_graftwright", true, false)
	check(legend_icon != null, "Fixture map must have a Graftwright legend entry")
	if legend_icon == null:
		quit(1)
		return
	var legend: Control = legend_icon.get_parent()
	await hover(legend.get_global_rect().get_center())
	await capture_map("02_map_legend_hover.png", scene, panel, legend)
	var node: Control = panel.node_buttons[current]
	await hover(node.get_global_rect().get_center())
	await capture_map("03_graftwright_node_hover.png", scene, panel, node)
	scene.call("_close_large_map")
	await process_frame
	state = Fixtures.combat_run()
	combat = state["combat_state"].duplicate(true)
	var pickup_tile: Vector2i = combat["player"]["pos"]
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var candidate: Vector2i = pickup_tile + direction
		if preload("res://scripts/path_utils.gd").is_passable(combat["grid"], candidate):
			pickup_tile = candidate
			break
	combat["loot"] = [{"id": "ptf04_gear", "kind": "equipment", "equipment_id": "training_sword", "pos": pickup_tile}]
	state["combat_state"] = combat
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")
	await settle()
	var board: Control = scene.get("board_view")
	var pickup_point: Vector2 = board.get_global_transform() * Vector2(board.call("_tile_center", pickup_tile))
	await hover(pickup_point)
	check(str(board.call("_get_tooltip", board.get_global_transform().affine_inverse() * pickup_point)).contains("equipment:"), "Pointer must hover real board gear")
	await capture("04_board_gear_hover.png")

	combat = Fixtures.fatal_combat(state)
	state["combat_state"] = combat
	scene.set("_run_state", state)
	scene.set("_combat_state", combat)
	check(int(scene.call("_displayed_ember_count")) == 34, "Fatal-fight HUD must show 34")
	var terminal: Dictionary = Fixtures.Run.new().finish_combat(state, combat)
	check(Fixtures.Run.new().held_embers(terminal) == 34, "Terminal wallet must preserve HUD amount")
	scene.call("_load_run_state", terminal)
	scene.call("_close_dialogue")
	scene.call("_refresh_ui")
	await create_timer(DEATH_SETTLE_SECONDS).timeout
	check(int(scene.get("_defeat_lost_amount")) == 34, "Death recap must lose 34")
	check(int(Store.recovery_marker(scene.get("_progression")).get("amount", 0)) == 34, "Recovery marker must contain 34")
	await hover(Vector2.ZERO)
	await capture("05_death_midfight_embers.png")
	print(Fixtures.OUTPUT)
	print("PTF04 %s: %s" % ["PROBE LOGIC" if logic_only else "VISUAL PROBE", "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)

func settle() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame

func hover(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await create_timer(TOOLTIP_WAIT_SECONDS).timeout

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func capture(filename: String) -> void:
	if logic_only: return
	await RenderingServer.frame_post_draw
	_save_capture(filename)

func _save_capture(filename: String) -> void:
	var image: Image = root.get_texture().get_image()
	check(image.get_size() == Fixtures.PROOF_SIZE, "Proof must be 1920x1080")
	DirAccess.make_dir_recursive_absolute(Fixtures.OUTPUT)
	check(image.save_png(Fixtures.OUTPUT.path_join(filename)) == OK, "Save " + filename)

func _map_is_open(scene: Node, panel: Control) -> bool:
	var scrim: Control = scene.get("_large_map_scrim")
	return scene.is_visible_in_tree() and scrim.is_visible_in_tree() and not is_zero_approx(scrim.modulate.a) and scrim.is_ancestor_of(panel) and panel.get_viewport() == root and panel.is_visible_in_tree() and panel.get_global_rect().has_area()

func _visible_native_tooltip(source: Control) -> Window:
	for child: Node in source.find_children("*", "Window", true, false):
		var popup := child as Window
		if popup.visible and not popup.is_queued_for_deletion() and popup.theme_type_variation == &"TooltipPanel":
			return popup
	return null

func _displayed_text(node: Node) -> String:
	var parts := PackedStringArray()
	if node is Label and not node.text.is_empty(): parts.append(node.text)
	elif node is RichTextLabel and not node.get_parsed_text().is_empty(): parts.append(node.get_parsed_text())
	for child: Node in node.get_children():
		var text: String = _displayed_text(child)
		if not text.is_empty(): parts.append(text)
	return "\n".join(parts)

func capture_map(filename: String, scene: Node, panel: Control, source: Control) -> void:
	if not logic_only: await RenderingServer.frame_post_draw
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROOF_CONTRACT)) as Dictionary
	var requirement: Dictionary = contract.get("runtime_assertions", {}).get(filename, {})
	var expected: String = str(requirement.get("tooltip_text", ""))
	var rendered: String = str(requirement.get("displayed_tooltip_text", ""))
	check(str(requirement.get("surface", "")) == "section_map", filename + ": contract must require the section map")
	var map_open: bool = _map_is_open(scene, panel)
	check(map_open, filename + ": section map panel and scrim must be visible in the captured viewport")
	check(not expected.is_empty() and not rendered.is_empty(), filename + ": exact tooltip contract must exist")
	if not map_open or expected.is_empty() or rendered.is_empty(): return
	var hovered: bool = root.gui_get_hovered_control() == source
	check(hovered, filename + ": pointer must hover the actual map source")
	if not hovered: return
	var tooltip: Node
	var temporary_factory_content: bool = false
	var actual: String
	if str(requirement.get("tooltip_kind")) == "native_legend":
		actual = source.tooltip_text
		if logic_only:
			# Headless checks validate the real factory content; only the windowed
			# path can prove that Godot actually opened its native tooltip popup.
			tooltip = source.call("_make_custom_tooltip", actual)
			temporary_factory_content = true
		else:
			tooltip = _visible_native_tooltip(source)
	else:
		actual = str(panel.get("_preview_text"))
		tooltip = panel.get("_preview")
	var text_matches: bool = actual == expected
	check(text_matches, filename + ": tooltip text must equal the approved contract")
	var tooltip_visible: bool = is_instance_valid(tooltip) and (temporary_factory_content or (tooltip.visible if tooltip is Window else tooltip.is_visible_in_tree()))
	check(tooltip_visible, filename + ": hovered tooltip must actually be visible")
	var rendered_matches: bool = is_instance_valid(tooltip) and _displayed_text(tooltip) == rendered
	check(rendered_matches, filename + ": displayed tooltip labels must equal the approved contract")
	if temporary_factory_content: tooltip.free()
	if not text_matches or not tooltip_visible or not rendered_matches: return
	# Assertions and pixel read occur in the same rendered frame. Invalid
	# surface or tooltip state cannot save an image or produce a passing run.
	if not logic_only: _save_capture(filename)
