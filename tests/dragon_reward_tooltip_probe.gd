extends SceneTree

const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/dragon_reward_tooltip_v1"
const SIZE := Vector2i(1920, 1080)
var scene: Node
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Store.set_storage_path("user://tooltip_profile.json")
	Store.set_run_storage_path("user://tooltip_run.save")
	Settings.set_storage_path("user://tooltip_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.gui_embed_subwindows = true
	scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = SIZE
	root.content_scale_size = SIZE
	await process_frame
	var engine := Run.new()
	var combat := Combat.new()
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version":Tutorial.VERSION,"status":"dismissed","completed_steps":[]}
	var options := {"dragon_id":"tharokh", "dragon_depth":8, "dragon_case":"encounter"}
	var original: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), profile), options)
	var battle: Dictionary = original["combat_state"]
	battle["terrain"].append({"id":"tooltip_witness", "kind":"wooden_crate", "pos":Vector2i(2,5), "hp":3, "max_hp":3})
	var dead: Dictionary = combat._damage_enemy(battle.duplicate(true), 0, 999, true, true)
	var reward: Dictionary = engine.finish_combat(original, dead)
	reward["pending_reward"]["intro_pending"] = false
	_expect(str(reward.get("mode", "")) == "reward", "Production finish produces a reward")
	for reduced: bool in [false, true]:
		var label: String = "reduced" if reduced else "normal"
		settings["reduced_motion"] = reduced
		scene.set("_settings", settings.duplicate(true))
		await _load(original)
		_expect(int((scene.get("_combat_state") as Dictionary)["enemies"][0]["hp"]) > 0, label + ": combat witness retains a living boss")
		var board: Control = scene.get("board_view")
		var texture: Texture2D = (board.get("_terrain_textures") as Dictionary)["wooden_crate"]
		var rect: Rect2 = board.call("_terrain_rect_for_tile", Vector2i(2,5), texture, "wooden_crate")
		var point: Vector2 = board.get_global_transform_with_canvas() * rect.get_center()
		await _hover(point)
		_expect(root.gui_get_hovered_control() == board, label + ": pointer reaches the actual board")
		_expect(str(board.call("_get_tooltip", rect.get_center())).begins_with("Wooden crate\n3/3 HP"), label + ": hovered subject is the living crate")
		_expect(_visible_tooltips(board) == 1, label + ": actual crate tooltip exists before transition")
		await _capture(label + "_combat_crate")
		# Keep the pointer stationary through the live victory overlay and reward view.
		scene.call("_play_post_combat_victory", reward["pending_reward"]["board_state"])
		_expect(_visible_tooltips(board) == 0, label + ": victory beat synchronously hides the old tooltip")
		await _capture(label + "_victory_stationary_pointer")
		await create_timer(1.0).timeout
		scene.set("_run_state", reward.duplicate(true))
		scene.call("_sync_combat_state_from_run")
		scene.call("_refresh_ui")
		await process_frame
		_expect(_visible_tooltips(board) == 0, label + ": reward immediately dismisses the stale board tooltip")
		await _capture(label + "_reward_stationary_pointer")
		await create_timer(1.5).timeout
		_expect(_visible_tooltips(board) == 0, label + ": pending hover timer cannot resurrect board tooltip")
		await _hover(point)
		_expect(str(board.call("_get_tooltip", rect.get_center())).is_empty(), label + ": background source returns no tooltip while reward is active")
		_expect(_visible_tooltips(board) == 0, label + ": reward blocks new background board tooltips")
		var button: Button = scene.find_child("DragonRewardContinue", true, false)
		_expect(button != null and not button.disabled, label + ": reward Continue remains available")
		button.grab_focus()
		_expect(root.gui_get_focus_owner() == button, label + ": keyboard focus still reaches Continue")
		await _hover(button.get_global_rect().get_center())
		_expect(_visible_tooltips(button) == 1, label + ": reward control retains its own tooltip")
		await _capture(label + "_reward_button_tooltip")
		await _load(original)
		await _hover(point)
		_expect(_visible_tooltips(board) == 1, label + ": next combat restores board inspection")
		await _capture(label + "_combat_restored")
	print("DRAGON REWARD TOOLTIP PROOF: ", "PASS" if failures.is_empty() else "FAIL", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _load(state: Dictionary) -> void:
	Store.save_data(state["progression"])
	Store.save_run_state(state)
	scene.set("_progression", state["progression"])
	scene.call("_load_run_state", state.duplicate(true))
	await process_frame
	await process_frame
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await create_timer(0.4).timeout

func _hover(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(8,8)
	motion.global_position = motion.position
	root.warp_mouse(motion.position)
	root.push_input(motion, true)
	await process_frame
	motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.warp_mouse(point)
	root.push_input(motion, true)
	await create_timer(1.5).timeout

func _visible_tooltips(parent: Node) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is Window and str(child.get("theme_type_variation")) == "TooltipPanel" and (child as Window).visible:
			count += 1
		count += _visible_tooltips(child)
	return count

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.get_size() == SIZE, "Native proof uses exact 1920x1080")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = "%s/%s.png" % [OUTPUT, label]
	_expect(image.save_png(path) == OK, "Screenshot saved")
	print(ProjectSettings.globalize_path(path))

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
