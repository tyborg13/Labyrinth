extends SceneTree
## Real pointer hover and held states, including the automatically focused item.
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/graftwright_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const OUTPUT := "user://graftwright_feedback"
var viewport: SubViewport
var view: Control
var failed: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	root.size = Vector2i(1920, 1080)
	Store.set_storage_path("user://feedback_profile.json")
	Store.set_run_storage_path("user://feedback_run.save")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await create_timer(0.7).timeout
	scene.call("_load_run_state", Suite.fixture())
	await create_timer(0.5).timeout
	view = scene.find_child("GraftwrightView", true, false)
	view.set_process(false)
	await feedback("GraftBrowse", "01_browse")
	await feedback("GraftSkip", "02_dialogue_skip")
	await click("GraftBrowse")
	await feedback("ChooseSacrifice", "03_empty_sacrifice")
	await feedback("ChooseRecipient", "04_empty_improve")
	await click("ChooseSacrifice")
	await feedback("Category_armor", "05_category")
	await feedback("PickerBack", "06_back")
	await feedback("Pick_undertaker_plate", "07_equipment")
	await click("Pick_undertaker_plate")
	await click("ChooseRecipient")
	await click("Pick_patched_cloak")
	await feedback("SourceCard_0", "08_undertaker_stand")
	await feedback("SourceCard_1", "09_coffin_brace")
	await click("SourceCard_0")
	await feedback("SourceCard_0", "10_selected_source")
	await feedback("TargetCard_0", "11_replacement")
	await click("TargetCard_0")
	await feedback("GraftCommit", "12_graft")
	await feedback("GraftLeave", "13_skip")
	view.call("configure", view.get("state"), true)
	await feedback("SourceCard_0", "14_reduced_motion", true)
	await click("GraftCommit")
	await create_timer(0.6).timeout
	check(bool(view.call("semantic_snapshot")["used"]), "Held-state cancellation never accidentally commits; deliberate click grafts")
	view.call("configure", view.get("state"), false)
	view.set("_elapsed", 0.0)
	view.call("_process", 0.0)
	var icon: Control = view.get("_result_icon")
	var local: Vector2 = icon.position
	var mount: Control = view.get("_result_mount")
	var start: Vector2 = mount.position
	await capture("15_result_low.png")
	view.set("_elapsed", PI / 3.2)
	view.call("_process", 0.0)
	await capture("16_result_high.png")
	check(icon.position == local and mount.position != start, "Result frame and gear move together")
	var rim: Control = mount.get_node("EquipmentRim")
	check(rim.get_index() > icon.get_index(), "Painted cradle lip occludes result gear")
	var rig: Node = view.get("_portrait")
	check((rig.get("load_errors") as PackedStringArray).is_empty(), "Production cutout loads all paint")
	var before: Transform2D = rig.get("bones")["head"].transform
	rig.call("apply_pose", "idle", 0.5)
	check(rig.get("bones")["head"].transform != before, "Head has independent skeletal idle")
	view.call("configure", view.get("state"), true)
	view.call("_process", 0.0)
	check(rig.get("bones")["head"].transform == rig.get("rest_transforms")["head"], "Reduced motion restores bind pose")
	await capture("17_reduced_result.png")
	print(ProjectSettings.globalize_path(OUTPUT))
	print("GRAFTWRIGHT FEEDBACK: " + ("FAIL" if failed else "PASS"))
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)

func feedback(name: String, prefix: String, still: bool = false) -> void:
	var button: Button = view.find_child(name, true, false)
	check(button != null and not button.disabled, name + " is actionable")
	if button == null or button.disabled: return
	await move(Vector2(1890, 1040))
	button.grab_focus()
	await create_timer(0.15).timeout
	check(not button.call("interaction_active"), name + " automatic focus does not pre-light pointer hover")
	await capture(prefix + "_rest.png")
	var point: Vector2 = button.get_global_rect().get_center()
	await move(point)
	check(button.is_hovered() and button.call("interaction_active"), name + " pointer hover is visible")
	check(float(button.get("_lift")) > 4.0 if not still else is_zero_approx(float(button.get("_lift"))), name + " hover respects motion setting")
	await capture(prefix + "_hover.png")
	await mouse(point, true)
	await create_timer(0.15).timeout
	check(button.is_pressed() and button.get("_pressed_visual"), name + " has held state")
	check((button.get("artwork") as Control).modulate.r < 0.85, name + " press visibly shades artwork")
	await capture(prefix + "_held.png")
	await move(Vector2(1890, 1040), MOUSE_BUTTON_MASK_LEFT)
	await mouse(Vector2(1890, 1040), false)

func move(point: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = Vector2(12, 8)
	event.button_mask = mask
	viewport.push_input(event, true)
	await create_timer(0.20).timeout

func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	viewport.push_input(event, true)
	await process_frame

func click(name: String) -> void:
	var button: Button = view.find_child(name, true, false)
	var point: Vector2 = button.get_global_rect().get_center()
	await move(point)
	await mouse(point, true)
	await mouse(point, false)
	await create_timer(0.10).timeout

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	check(image.get_size() == Vector2i(1920, 1080), "Native resolution")
	image.save_png(OUTPUT.path_join(name))

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
