extends "res://tests/loadout_material_polish_probe.gd"

const CHARACTER_OUTPUT: String = "user://probes/character_menu_polish_v2"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_output_dir = CHARACTER_OUTPUT
	_physical_size = Vector2i(1920, 1080)
	_logical_size = _physical_size
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHARACTER_OUTPUT))
	_router = root.get_node("InputRouter")
	_build_handheld_viewport()
	_instance = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_instance)
	await create_timer(0.4).timeout
	var engine := RunEngineScript.new()
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	var base: Dictionary = engine.create_new_run(127800, profile)
	_router.call("set_forced_state_for_test", "controller", "xbox")
	# Existing logical proof covers native gear/item activation, two-step Magic
	# swap, tooltip handoff and controller prompt state on the finished menu.
	await _exercise_loadout_material(_instance, base)
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	_instance.call("_open_character_overlay", "equipment")
	await create_timer(0.2).timeout
	await _settle()
	_viewport.gui_release_focus()
	await _save_screenshot("01_gear_idle.png")
	await _assert_menu_edge_alignment(_instance.get("_upgrade_dialog") as Control)
	var dialog: Control = _instance.get("_upgrade_dialog") as Control
	var bounds: Rect2 = dialog.get_global_rect()
	_require(dialog.scale == Vector2.ONE, "Character keeps native scale")
	var section: PanelContainer = dialog.find_child("EquipmentInventoryPanel", true, false) as PanelContainer
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_require(is_equal_approx(section.get_theme_stylebox("panel").get_margin(side), 2.0), "Broad Character sections preserve their two-pixel native style margins")
	var finish: Node = section.get_node("SurfaceFinish")
	_require(not finish.is_processing(), "Retained menu material performs no idle processing")
	var layout_before: Dictionary = _control_bounds(dialog)
	_instance.call("_close_card_upgrade_overlay")
	_instance.call("_open_character_overlay", "equipment")
	var opening: Tween = _instance.get("_character_menu_arrival_tween") as Tween
	_require(opening != null and dialog.modulate.a < 1.0, "Explicit opening begins a bounded opacity settle")
	opening.pause()
	opening.custom_step(0.04)
	await _capture_frame("02_gear_opening_mid.png")
	_require(_control_bounds(dialog) == layout_before, "Opening opacity does not alter any existing control or hit rectangle")
	opening.custom_step(0.2)
	_require(_instance.get("_character_menu_arrival_tween") == null and dialog.modulate.a == 1.0, "Opening settles fully and releases its tween")
	# Pointer tab activation is sampled before another rendered frame can finish
	# the response; input remains live throughout presentation.
	_click_now(dialog.find_child("CharacterMagicTab", true, false) as Control)
	_require(str(_instance.get("_progression_overlay_mode")) == "magic", "Pointer tab activation changes the live tab immediately")
	var tab_arrival: Tween = _instance.get("_character_menu_arrival_tween") as Tween
	var body: Control = dialog.find_child("CharacterBodyFrame", true, false) as Control
	_require(tab_arrival != null and _instance.get("_character_menu_arrival_target") == body, "Tab settle affects only new body content")
	tab_arrival.pause()
	await _settle()
	var magic_bounds: Dictionary = _control_bounds(dialog)
	tab_arrival.custom_step(0.035)
	await _capture_frame("03_magic_tab_mid.png")
	tab_arrival.custom_step(0.2)
	_require(_control_bounds(dialog) == magic_bounds and dialog.get_global_rect() == bounds, "Tab settle preserves content geometry and outer bounds")
	_viewport.gui_release_focus()
	await _save_screenshot("04_magic_idle.png")
	await _assert_menu_edge_alignment(dialog)
	_router.call("set_forced_state_for_test", "controller", "xbox")
	await _press_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	await create_timer(0.2).timeout
	_require(str(_instance.get("_progression_overlay_mode")) == "skills", "Native controller shoulder tab traversal remains intact")
	var tree: Control = _instance.get("_skill_tree_view") as Control
	var retained_tree_id: int = tree.get_instance_id()
	_require(tree.is_ancestor_of(_viewport.gui_get_focus_owner()), "Skills still hands controller focus to its native graph")
	await _save_screenshot("05_skills_controller.png")
	await _assert_menu_edge_alignment(dialog)
	await _press_controller_button(JOY_BUTTON_B)
	_require(not (_instance.get("_upgrade_scrim") as Control).visible, "Native controller Back closes Character")
	_instance.call("_open_character_overlay", "skills")
	_require((_instance.get("_skill_tree_view") as Control).get_instance_id() == retained_tree_id, "Cached opening retains the same skill tree")
	await _settle()
	await create_timer(0.2).timeout
	var skills_tab: Button = dialog.find_child("CharacterSkillsTab", true, false) as Button
	skills_tab.grab_focus()
	await _key_event(KEY_TAB)
	_require(_viewport.gui_get_focus_owner() != skills_tab and dialog.is_ancestor_of(_viewport.gui_get_focus_owner()), "Native keyboard traversal remains inside Character")
	await _key_event(KEY_ESCAPE)
	_require(not (_instance.get("_upgrade_scrim") as Control).visible, "Native keyboard Escape closes Character")
	await _interruption_states(settings)
	await _load_combat_fixture(_instance)
	_instance.call("_open_character_overlay", "magic")
	await create_timer(0.2).timeout
	_viewport.gui_release_focus()
	_require(not bool(_instance.call("_magic_overlay_can_change")), "Combat Magic remains locked")
	await _save_screenshot("08_magic_combat_locked.png")
	_instance.call("_close_card_upgrade_overlay")
	_instance.queue_free()
	await process_frame
	_cleanup_storage()
	print(ProjectSettings.globalize_path(CHARACTER_OUTPUT))
	print("CHARACTER MENU POLISH: PASS")
	quit(0)

func _interruption_states(settings: Dictionary) -> void:
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	_instance.call("_open_character_overlay", "equipment")
	var dialog: Control = _instance.get("_upgrade_dialog") as Control
	var old: Tween = _instance.get("_character_menu_arrival_tween") as Tween
	_instance.call("_rebuild_progression_overlay")
	_require(not old.is_valid() and _instance.get("_character_menu_arrival_tween") == null and dialog.modulate.a == 1.0, "Ordinary content rebuild cancels and snaps without replay")
	_instance.call("_switch_character_overlay_mode", "magic")
	old = _instance.get("_character_menu_arrival_tween") as Tween
	_instance.call("_switch_character_overlay_mode", "equipment")
	_require(not old.is_valid(), "Rapid tab switching kills the previous response before replacing its body")
	var scrim: Control = _instance.get("_upgrade_scrim") as Control
	scrim.hide()
	_require(_instance.get("_character_menu_arrival_tween") == null, "Direct hide cancels active menu motion synchronously")
	_instance.call("_open_character_overlay", "magic")
	old = _instance.get("_character_menu_arrival_tween") as Tween
	var reduced: Dictionary = settings.duplicate(true)
	reduced["reduced_motion"] = true
	_instance.call("_on_settings_changed", reduced)
	# Preference can change during a running tween; its next update must snap.
	old.custom_step(0.001)
	_require(_instance.get("_character_menu_arrival_tween") == null and dialog.modulate.a == 1.0, "Live Reduced Motion cancels and restores inherited opacity")
	_instance.call("_close_card_upgrade_overlay")
	_instance.call("_open_character_overlay", "magic")
	_require(_instance.get("_character_menu_arrival_tween") == null and dialog.modulate.a == 1.0, "Reduced Motion opening is fully static")
	await _settle()
	_viewport.gui_release_focus()
	await _save_screenshot("06_magic_reduced_motion.png")
	_instance.call("_switch_character_overlay_mode", "equipment")
	_require(_instance.get("_character_menu_arrival_tween") == null, "Reduced Motion tab switching is static")
	_instance.call("_on_settings_changed", settings)
	_instance.call("_switch_character_overlay_mode", "magic")
	_instance.call("_close_card_upgrade_overlay")
	_instance.call("_open_character_overlay", "equipment")
	await create_timer(0.2).timeout
	await _settle()
	_require(dialog.modulate.a == 1.0 and _instance.get("_character_menu_arrival_target") == null, "Rapid close/reopen leaves no inherited transparency or retained animation target")
	await _save_screenshot("07_gear_reopened.png")
	_instance.call("_close_card_upgrade_overlay")

func _assert_menu_edge_alignment(dialog: Control) -> void:
	# Exercise the actual Character hosts, including every resource chip and
	# broad panel on each tab. Pixel differences prove paint reaches the native
	# face; a geometry-only test could miss an unrelated inset in the draw path.
	var layout_before: Dictionary = _control_bounds(dialog)
	var panels: Array[PanelContainer]
	_collect_menu_panels(dialog, panels)
	_require(panels.size() >= 7, "Character tab exposes its outer face, four resource chips and grouped surfaces")
	for panel: PanelContainer in panels:
		var finish: Node2D = panel.get_node("SurfaceFinish") as Node2D
		var outer: bool = panel == dialog
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		_require(style != null, "Character material keeps its native StyleBoxFlat host")
		_require(finish.position == Vector2.ZERO and finish.scale == Vector2.ONE and finish.get_index() == 0, "Menu paint stays aligned with its host beneath existing content")
		_require(not finish.is_processing(), "Aligned material has no idle processing")
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_require(style.get_border_width(side) == (0 if outer else 2), "Character native rim width remains unchanged")
		for corner: int in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, CORNER_BOTTOM_LEFT]:
			_require(style.get_corner_radius(corner) == (14 if outer else 8), "Character native corner silhouette remains unchanged")
		var geometry: Dictionary = finish.call("menu_face_geometry")
		var face: Rect2 = geometry.get("rect", Rect2())
		var expected: Rect2 = Rect2(Vector2.ZERO, panel.size) if outer else Rect2(Vector2(2.0, 2.0), panel.size - Vector2(4.0, 4.0))
		_require(face == expected, "Material reaches the full native face without a detached inset slab")
		var radii: PackedVector2Array = geometry.get("radii", PackedVector2Array())
		_require(radii.size() == 4, "Material has a contour for all four native corners")
		for radius: Vector2 in radii:
			_require(radius == Vector2.ONE * (14.0 if outer else 6.0), "Material follows Character rounded inner corners")
		print("CHARACTER FACE ", panel.name, " global=", panel.get_global_rect(), " local=", face, " radii=", radii)
		if DisplayServer.get_name() != "headless":
			await _assert_material_reaches_rim(panel, finish, outer)
	_require(_control_bounds(dialog) == layout_before, "Contour rendering leaves all content and hit rectangles unchanged")

func _collect_menu_panels(node: Node, panels: Array[PanelContainer]) -> void:
	if node is PanelContainer:
		var panel: PanelContainer = node as PanelContainer
		var finish: Node = panel.get_node_or_null("SurfaceFinish")
		if panel.is_visible_in_tree() and finish != null and str(finish.get("_kind")).begins_with("menu_"):
			panels.append(panel)
	for child: Node in node.get_children():
		_collect_menu_panels(child, panels)

func _assert_material_reaches_rim(panel: PanelContainer, finish: Node2D, outer: bool) -> void:
	# Raster rails normally cover the first outer-face pixels. Temporarily hide
	# that decorative child for internal measurement only, then restore it.
	var ornament: CanvasItem = panel.get_node_or_null("ThemedPanelOrnament") as CanvasItem if outer else null
	if ornament != null:
		ornament.hide()
		await process_frame
	await RenderingServer.frame_post_draw
	var painted: Image = _viewport.get_texture().get_image()
	finish.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var unpainted: Image = _viewport.get_texture().get_image()
	finish.show()
	await process_frame
	await RenderingServer.frame_post_draw
	var origin: Vector2i = Vector2i(panel.get_global_rect().position.round())
	var extent: Vector2i = Vector2i(panel.size.round())
	var top_delta: float = 0.0
	var left_delta: float = 0.0
	var bottom_delta: float = 0.0
	var right_delta: float = 0.0
	var edge: int = 1 if outer else 3
	# Three pixels from the host edge is inside its 2px native rim, and outside
	# the rejected fixed 5px inset. Avoid corners and text when sampling bands.
	for x: int in range(12, extent.x - 12, 7):
		top_delta = maxf(top_delta, _pixel_delta(painted, unpainted, origin + Vector2i(x, edge)))
		bottom_delta = maxf(bottom_delta, _pixel_delta(painted, unpainted, origin + Vector2i(x, extent.y - edge - 1)))
	for y: int in range(12, extent.y - 12, 7):
		left_delta = maxf(left_delta, _pixel_delta(painted, unpainted, origin + Vector2i(edge, y)))
		right_delta = maxf(right_delta, _pixel_delta(painted, unpainted, origin + Vector2i(extent.x - edge - 1, y)))
	_require(top_delta > 0.004 and left_delta > 0.004 and bottom_delta > 0.004 and right_delta > 0.004, "Native material reaches all four inner edges on " + str(panel.name))
	if not outer:
		_require(_pixel_delta(painted, unpainted, origin + Vector2i(extent.x / 2, 0)) <= 0.005, "Finish preserves the sole native top border on " + str(panel.name))
	var corner: int = 0 if outer else 2
	for point: Vector2i in [Vector2i(corner, corner), Vector2i(extent.x - corner - 1, corner), Vector2i(extent.x - corner - 1, extent.y - corner - 1), Vector2i(corner, extent.y - corner - 1)]:
		_require(_pixel_delta(painted, unpainted, origin + point) <= 0.005, "Finish does not square off a rounded native corner on " + str(panel.name))
	if ornament != null:
		ornament.show()
		await process_frame
		await RenderingServer.frame_post_draw

func _pixel_delta(first: Image, second: Image, point: Vector2i) -> float:
	var a: Color = first.get_pixelv(point)
	var b: Color = second.get_pixelv(point)
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))

func _click_now(control: Control) -> void:
	_require(control != null, "Pointer target exists")
	var point: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		_viewport.push_input(event, true)

func _key_event(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		_viewport.push_input(event, true)
		await process_frame

func _control_bounds(control: Control) -> Dictionary:
	var result: Dictionary = {str(control.get_path()): control.get_global_rect()}
	for node: Node in control.get_children():
		if node is Control:
			result.merge(_control_bounds(node as Control))
	return result

func _save_screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await _settle()
	await _capture_frame(filename)

func _capture_frame(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_require(frame.get_size() == Vector2i(1920, 1080), "Character proof remains native 1920×1080")
	_require(frame.save_png(ProjectSettings.globalize_path(CHARACTER_OUTPUT.path_join(filename))) == OK, "Native Character image saved")
