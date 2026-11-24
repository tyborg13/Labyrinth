extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Route = preload("res://tools/eco03/route.gd")
const FIXTURE: String = "res://tools/eco03/native_fixture.json"
const CAPTURE: String = "user://eco03/section_1_scavenger.png"
const SIZE := Vector2i(1920, 1080)
const SETTLE_SECONDS: float = 0.65

func _initialize() -> void:
	Runtime.apply_from_environment()
	assert(OS.get_environment("LABYRINTH_CEL_LOOK") == "all")
	var folder: String = ProjectSettings.globalize_path("user://eco03")
	DirAccess.make_dir_recursive_absolute(folder)
	Store.set_storage_path("user://eco03/progression.json")
	Store.set_run_storage_path("user://eco03/run.save")
	Settings.set_storage_path("user://eco03/settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	assert(Settings.save_settings(settings))
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = SIZE
	root.size = SIZE

	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(int(fixture["seed"]), Store.default_data())
	var first: Dictionary = Route.section_routes(state, 0)["first"]
	assert(int(first["fights"]) >= 2)
	var arrival: Dictionary = Route.enter_path(engine, state, first["path"])
	var held_embers: int = int(fixture["held_embers"])
	arrival = engine.set_held_embers(arrival, held_embers)
	assert(Graph.active_section(arrival) == 0 and engine.merchant_kind_for_current_room(arrival) == Run.MERCHANT_SCAVENGER)
	var offers: Array = engine.merchant_offer_ids(arrival, Run.MERCHANT_SCAVENGER)
	assert(offers == fixture["stock"] and offers != fixture["rolled_stock"])

	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	scene.call("_load_run_state", arrival)
	await create_timer(SETTLE_SECONDS).timeout
	var shop: Control = scene.get("_scavenger_shop_view")
	var expected_categories: Dictionary = {"gear": 3, "magic": 3, "item": 3}
	assert(shop != null and shop.is_visible_in_tree() and not bool(scene.get("_dialogue_active")))
	assert(shop.call("semantic_snapshot")["categories"] == expected_categories)
	var ember_label: Label = shop.find_child("ScavengerEmberCount", true, false)
	assert(ember_label != null and ember_label.text == str(held_embers))
	print("ECO03 REAL SCAVENGER: PASS seed=%d section=1 fights=%d embers=%s size=%dx%d scale=1.0 stock=%s" %
		[int(fixture["seed"]), int(first["fights"]), ember_label.text, SIZE.x, SIZE.y, ",".join(offers)])
	if DisplayServer.get_name() == "headless":
		print("ECO03 NATIVE DRY RUN: PASS expected_png=" + ProjectSettings.globalize_path(CAPTURE))
	else:
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		assert(image.get_size() == SIZE and image.save_png(CAPTURE) == OK)
		print(ProjectSettings.globalize_path(CAPTURE))
	viewport.queue_free()
	await process_frame
	quit()
