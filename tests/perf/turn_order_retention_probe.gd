extends SceneTree

const Slots = preload("res://scripts/turn_order_slots.gd")
const Original = preload("res://tests/perf/turn_order_reference.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_RAIL_ORIGIN := Vector2(900, 100)
const LAYOUT_SETTLE_FRAMES: int = 3
const SCENE_SETTLE_SECONDS: float = 1.5
const OUTPUT_DIR: String = "res://output/perf-03/turn-order-proof"
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Turn-order pixel proof requires a windowed renderer")
		quit(1)
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	DisplayServer.window_set_size(PROOF_SIZE)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var engine := preload("res://scripts/run_engine.gd").new()
	var state: Dictionary = engine.create_new_run(83, preload("res://scripts/progression_store.gd").default_data())
	scene._load_run_state(engine.move_to_room(state, engine.available_moves(state)[0]))
	await create_timer(SCENE_SETTLE_SECONDS).timeout
	_hide_scene(scene)
	var entries: Array[Dictionary]
	entries.assign(scene._turn_order_all_entries.slice(0, scene.TURN_ORDER_MAX_SLOTS))
	var holder := Control.new()
	holder.position = PROOF_RAIL_ORIGIN
	root.add_child(holder)
	for index: int in range(entries.size()):
		var slot: Control = Original.build(scene, entries[index], index)
		slot.position = scene._turn_order_slot_position(index)
		holder.add_child(slot)
	var before: Image = await _capture("turn_order_before")
	for child: Node in holder.get_children(): child.free()
	for index: int in range(entries.size()):
		var prior: Dictionary = entries[index].duplicate(true)
		prior["eta"] = int(prior.get("eta", 0)) + 1
		if prior.has("hp"): prior["hp"] = int(prior["hp"]) + 1
		var slot: Control = Slots.update(scene, prior, index)
		slot.position = scene._turn_order_slot_position(index)
		holder.add_child(slot)
		Slots.update(scene, entries[index], index, slot)
	var after: Image = await _capture("turn_order_after")
	if before.get_data() != after.get_data(): failures.append("Retained rail pixels differ from original factory")
	for child: Node in holder.get_children(): child.free()
	holder.position = Vector2.ZERO
	for proxy: Control in scene._card_proxy_pool: proxy.free()
	scene._card_proxy_pool.clear()
	scene._combat_state["deck"]["hand"] = ["quick_stab"]
	scene._animation_lock = false
	scene._selected_card_index = -1
	var card_rect := Rect2((Vector2(PROOF_SIZE) - scene.CARD_WIDGET_BASE_SIZE) * 0.5, scene.CARD_WIDGET_BASE_SIZE)
	var cold: Control = scene._spawn_card_proxy("hobnail_drive", card_rect)
	scene._mount_card_proxy(cold, holder, card_rect)
	var cold_image: Image = await _capture("card_proxy_before")
	cold.visible = false
	scene._card_proxy_preparation.prepared = false
	scene._card_proxy_preparation.request(scene)
	for frame: int in range(LAYOUT_SETTLE_FRAMES): await process_frame
	var prepared: Control = scene._spawn_card_proxy("hobnail_drive", card_rect)
	scene._mount_card_proxy(prepared, holder, card_rect)
	_match_proxy_instance_phase(cold, prepared)
	var prepared_image: Image = await _capture("card_proxy_after")
	if cold_image.get_data() != prepared_image.get_data(): failures.append("Prepared card proxy pixels differ from cold factory")
	holder.free()
	scene.queue_free()
	for frame: int in range(LAYOUT_SETTLE_FRAMES): await process_frame
	for failure: String in failures: push_error(failure)
	print("PERF03 TURN ORDER PIXEL EQUIVALENCE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _capture(label: String) -> Image:
	for frame: int in range(LAYOUT_SETTLE_FRAMES): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join(label + ".png"))
	if image.get_size() != PROOF_SIZE or image.save_png(path) != OK: failures.append("Capture " + label)
	print(path)
	return image

func _hide_scene(node: Node) -> void:
	if node is CanvasItem: node.visible = false
	if node is CanvasLayer: node.visible = false
	for child: Node in node.get_children(): _hide_scene(child)

func _match_proxy_instance_phase(reference: Node, candidate: Node) -> void:
	# Use the same rendering input for independent instance-id-seeded gem lights.
	if reference.has_method("refresh_motion") and reference.get("_phase") != null:
		candidate.set("_phase", reference.get("_phase"))
		candidate.call("refresh_motion")
	for index: int in range(mini(reference.get_child_count(), candidate.get_child_count())):
		_match_proxy_instance_phase(reference.get_child(index), candidate.get_child(index))
