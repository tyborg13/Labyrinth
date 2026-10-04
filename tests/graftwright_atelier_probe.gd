extends SceneTree

const Parallel = preload("res://scripts/parallel_runtime.gd")
const View = preload("res://scripts/graftwright_view.gd")
const Suite = preload("res://tests/suites/graftwright_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT := "user://graftwright_atelier_probe"
const SIZE := Vector2i(1920, 1080)
var failed: bool = false
var viewport: SubViewport
var view: Control

func _initialize() -> void:
	Parallel.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	view = View.new()
	viewport.add_child(view)
	view.size = Vector2(SIZE)
	var state: Dictionary = Suite.fixture()
	view.call("configure", state, false)
	await settle()
	await capture("18_entry_dialogue.png")
	view.call("begin_work")
	view.call("select_donor", "patched_cloak")
	view.call("select_recipient", "undertaker_plate")
	view.call("select_source", 1)
	view.call("select_target", 1)
	await settle()
	await capture("02_preview.png")
	await check_rendered_thread()
	view.call("configure", state, true)
	await settle()
	await capture("26_reduced_motion_thread.png")
	await check_rendered_thread()
	view.call("select_recipient", "iron_cleaver")
	view.call("select_donor", "training_sword")
	view.call("select_source", 0)
	view.call("select_target", 2)
	await settle()
	await capture("10_three_cards.png")
	await check_rendered_thread()
	var empty: Dictionary = Suite.fixture(int(state["seed"]) + 1)
	empty["equipment_inventory"] = []
	view.call("configure", empty, true)
	await settle()
	await capture("22_no_pair_dialogue.png")
	print(ProjectSettings.globalize_path(OUTPUT))
	print("GRAFTWRIGHT ATELIER PROBE: " + ("FAIL" if failed else "PASS"))
	view.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit(1 if failed else 0)

func check_rendered_thread() -> void:
	var thread: Control = view.find_child("GraftPreviewThread", true, false) as Control
	check(thread != null, "Selected cards have a rendered preview thread")
	if thread == null: return
	var elapsed: float = thread.get("elapsed")
	var processing: bool = thread.is_processing()
	var phases := PackedFloat32Array([0.0])
	if not bool(thread.get("reduced_motion")): phases = PackedFloat32Array([-PI / 2.0, 0.0, PI / 2.0])
	for phase: float in phases:
		thread.set("elapsed", (phase + TAU) / 0.9)
		thread.call("_update_preview")
		thread.set_process(false)
		await process_frame
		await check_rendered_thread_phase(thread)
	thread.set("elapsed", elapsed)
	thread.call("_update_preview")
	thread.set_process(processing)

func check_rendered_thread_phase(thread: Control) -> void:
	await RenderingServer.frame_post_draw
	var painted: Image = viewport.get_texture().get_image()
	thread.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var unpainted: Image = viewport.get_texture().get_image()
	thread.show()
	for node: Node in view.find_children("*", "Label", true, false):
		var label := node as Label
		if label.get_parent() != view.get("_content") and label.get_parent() != view.get("_sacrifice_content"): continue
		if label.position.y < 235 or label.position.y >= 480: continue
		var rect := Rect2i(label.get_global_rect())
		check(painted.get_region(rect).get_data() == unpainted.get_region(rect).get_data(), "Thread leaves panel text untouched: " + label.text)
	for property: String in ["origin", "destination"]:
		var point: Vector2 = thread.get(property)
		var rect := Rect2i(roundi(point.x) - 9, roundi(point.y) - 8, 18, 8)
		check(painted.get_region(rect).get_data() != unpainted.get_region(rect).get_data(), "Thread visibly reaches the chosen card edge: " + property)

func settle() -> void:
	await create_timer(0.25).timeout
	await process_frame
	await process_frame

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	check(image.get_size() == SIZE, "Capture is native 1920x1080")
	check(image.save_png(OUTPUT.path_join(filename)) == OK, "Capture saves: " + filename)

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
