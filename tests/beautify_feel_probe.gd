extends SceneTree

# Real-renderer proof for the Ember & Umbra presentation layer: dialogue
# portrait, combat atmosphere and HUD seating, the flush left dock, turn
# banners, and the board-only impact kick with its crimson edge flush.

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const BossFactory = preload("res://tools/dragon_boss_inspection.gd")
const DEFAULT_CLEAR_GREY := Color8(77, 77, 77)

const OUTPUT_DIR: String = "user://probes/beautify_feel_v1"

var _viewport: SubViewport
var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	SettingsStore.set_storage_path("user://beautify_feel_settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	ProgressionStore.set_storage_path("user://beautify_feel_progression.json")
	ProgressionStore.set_run_storage_path("user://beautify_feel_run.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	call_deferred("_run")

func _run() -> void:
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(instance)
	await process_frame
	await process_frame
	var engine := RunEngine.new()
	instance.call("_load_run_state", engine.create_new_run(123, ProgressionStore.default_data()))
	await _settle(0.35)
	await _save("01_dialogue_portrait")
	var portrait_frame: Control = instance.get("_dialogue_portrait_frame") as Control
	_expect(portrait_frame != null and portrait_frame.visible, "Opening NPC dialogue should show the speaker's bust portrait")
	var dialogue_dialog: Control = instance.get("_dialogue_dialog") as Control
	_expect(dialogue_dialog != null and dialogue_dialog.custom_minimum_size.y <= 160.0, "Dialogue plate should stay compact")
	if bool(instance.get("_dialogue_active")):
		instance.call("_close_dialogue")
	await _settle(0.2)

	var atmosphere: Node = instance.get_node_or_null("BoardUnderlay/CombatAtmosphere")
	_expect(atmosphere != null, "Combat atmosphere should live in the board underlay")
	if atmosphere != null:
		var backdrop: Node = instance.get_node("BoardUnderlay/BoardBackdrop")
		var board: Node = instance.get_node("BoardUnderlay/CombatBoard")
		_expect(atmosphere.get_index() > backdrop.get_index() and atmosphere.get_index() < board.get_index(), "Atmosphere should sit between the hall art and the board")
	var scrim: Node = instance.get_node_or_null("UiLayer/UiRoot/HudSeatScrim")
	_expect(scrim != null and scrim.get_index() == 0, "HUD seat scrim should be drawn beneath every HUD element")

	var combat_coord: Vector2i = _first_room_of_type(instance, "combat")
	_expect(combat_coord != Vector2i.ZERO, "Probe run should offer a combat room")
	if combat_coord == Vector2i.ZERO:
		_finish()
		return
	await instance.call("_on_map_view_room_selected", combat_coord)
	await _settle(0.3)
	var pre_battle_scrim: Control = instance.get("_pre_battle_scrim") as Control
	if pre_battle_scrim != null and pre_battle_scrim.visible:
		await _save("02_pre_battle")
		await instance.call("_on_pre_battle_start_pressed")
	await _settle(2.6)
	await _save("03_combat_idle")
	_expect(scrim != null and bool(scrim.get("show_bottom_band")), "Combat should seat the hand on the bottom scrim band")
	_assert_left_dock(instance)

	instance.call("_show_turn_banner", true)
	await _settle(0.32)
	await _save("04_turn_banner_player")
	var banner: Control = instance.get("_turn_banner") as Control
	var banner_label: Label = banner.get_node_or_null("TurnBannerLabel") as Label if banner != null else null
	_expect(banner != null and banner.visible and banner_label != null and banner_label.text == "YOUR TURN", "Player hand-off should show the YOUR TURN banner")
	await _settle(1.4)
	_expect(banner != null and not banner.visible, "Turn banner should clear itself without input")
	instance.call("_show_turn_banner", false)
	await _settle(0.32)
	await _save("05_turn_banner_enemy")
	_expect(banner_label != null and banner_label.text == "ENEMY TURN", "Enemy hand-off should show the ENEMY TURN banner")
	await _settle(1.4)

	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var underlay: CanvasLayer = instance.get_node("BoardUnderlay") as CanvasLayer
	var presentation: Dictionary = (board_view.get("presentation") as Dictionary).duplicate(false)
	presentation["impact_actor_keys"] = ["player"]
	presentation["impact_progress"] = 0.12
	presentation["impact_strength"] = 1.0
	presentation["reduced_motion"] = false
	board_view.set("presentation", presentation)
	board_view.call("_update_impact_camera_shake")
	await process_frame
	await process_frame
	await _save("06_player_hit_kick")
	_expect(underlay.offset != Vector2.ZERO, "A player hit should kick the board layer")
	_expect(not _edges_show_clear_colour("06_player_hit_kick"), "A camera kick must never uncover the default clear colour at the screen edge")
	var hurt: float = float((atmosphere.get("_material") as ShaderMaterial).get_shader_parameter("hurt")) if atmosphere != null else 0.0
	_expect(hurt > 0.3, "A player hit should flush the screen edge crimson")
	var ui_layer: CanvasLayer = instance.get_node("UiLayer") as CanvasLayer
	_expect(ui_layer.offset == Vector2.ZERO, "The HUD must never shake")
	# Apply one kick sample directly under reduced motion: the live scene may
	# resubmit its own presentation between frames.
	presentation["reduced_motion"] = true
	board_view.set("presentation", presentation)
	board_view.call("_apply_camera_kick", 0.1)
	_expect(underlay.offset == Vector2.ZERO, "Reduced motion keeps the camera still")
	presentation["impact_actor_keys"] = []
	presentation["reduced_motion"] = false
	board_view.set("presentation", presentation)
	board_view.call("_update_impact_camera_shake")
	await _settle(0.5)
	_expect(underlay.offset == Vector2.ZERO, "The camera settles when the impact ends")

	instance.call("_open_menu_overlay")
	await _settle(0.25)
	await _save("07_pause_menu")
	instance.call("_close_menu_overlay")
	await _settle(0.2)
	await _real_enemy_rounds(instance, atmosphere, underlay)
	instance.queue_free()
	await _settle(0.2)
	await _boss_banner_yields()
	_finish()

# Drive real Pass -> enemy round -> player turn cycles until an enemy actually
# damages the player, sampling every rendered frame for shake, flush and any
# overlap between the phase banner and the enemy action label.
func _real_enemy_rounds(instance: Node, atmosphere: Node, underlay: CanvasLayer) -> void:
	var combat := CombatEngine.new()
	var banner: Control = instance.get("_turn_banner") as Control
	var banner_label: Control = banner.get_node("TurnBannerLabel") as Control
	var action_label: Control = instance.get("action_banner") as Control
	var start_hp: int = int(((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("hp", 0))
	var enemy_banner_seen: bool = false
	var player_banner_seen: bool = false
	var real_hit_seen: bool = false
	var peak_offset: float = 0.0
	var overlap_frames: int = 0
	for round_index: int in range(6):
		var state: Dictionary = instance.get("_combat_state")
		if combat.combat_outcome(state) != "" or not combat.is_player_turn(state):
			break
		instance.call("_on_pass_turn_pressed")
		var frames: int = 0
		while frames < 2400:
			await process_frame
			frames += 1
			peak_offset = maxf(peak_offset, underlay.offset.length())
			if banner.visible and banner_label.text == "ENEMY TURN":
				if not enemy_banner_seen:
					enemy_banner_seen = true
					await _save("08_real_enemy_turn")
			if banner.visible and action_label.is_visible_in_tree() and not (action_label as Label).text.is_empty():
				if banner_label.get_global_rect().intersects(action_label.get_global_rect()):
					overlap_frames += 1
			var hurt: float = float((atmosphere.get("_material") as ShaderMaterial).get_shader_parameter("hurt"))
			if hurt > 0.3 and not real_hit_seen:
				real_hit_seen = true
				await _save("09_real_player_hit")
				_expect(not _edges_show_clear_colour("09_real_player_hit"), "A real enemy hit must not uncover the screen edge")
			if not bool(instance.get("_animation_lock")) and combat.is_player_turn(instance.get("_combat_state")):
				break
		for settle_frame: int in range(30):
			await process_frame
			if banner.visible and banner_label.text == "YOUR TURN" and not player_banner_seen:
				player_banner_seen = true
				await _save("10_real_your_turn")
		var hp: int = int(((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("hp", 0))
		if real_hit_seen and hp < start_hp:
			break
	await _settle(1.6)
	_expect(enemy_banner_seen, "A real Pass should raise the ENEMY TURN banner")
	_expect(player_banner_seen, "The real hand-back should raise the YOUR TURN banner")
	_expect(real_hit_seen, "The real enemy rounds should land at least one hit on the player")
	_expect(peak_offset > 0.5, "Real hits should kick the board layer")
	_expect(overlap_frames == 0, "The phase banner must never overlap an enemy action label (%d frames)" % overlap_frames)
	_expect(underlay.offset == Vector2.ZERO, "The board layer returns to rest after a real impact sequence")
	var hurt_after: float = float((atmosphere.get("_material") as ShaderMaterial).get_shader_parameter("hurt"))
	_expect(is_zero_approx(hurt_after), "The crimson flush clears after a real impact sequence")
	for name: String in ["BaseBackdrop", "BoardBackdrop", "CombatAtmosphere"]:
		var backdrop: Control = underlay.get_node_or_null(name) as Control
		_expect(backdrop != null and backdrop.position == Vector2.ZERO, "%s returns to rest after shaking" % name)

# In boss fights the boss health bar owns the top band; banners stand down.
func _boss_banner_yields() -> void:
	var run_engine := RunEngine.new()
	var combat := CombatEngine.new()
	var options := {"dragon_id": "zekarion", "dragon_depth": 20}
	var state: Dictionary = BossFactory.build(run_engine, combat, run_engine.create_new_run(BossFactory.seed_for_options(options), ProgressionStore.default_data()), options)
	ProgressionStore.save_data(state["progression"])
	ProgressionStore.save_run_state(state)
	var boss_scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(boss_scene)
	await process_frame
	boss_scene.set("_progression", state["progression"])
	boss_scene.call("_load_run_state", state)
	await _settle(0.4)
	if bool(boss_scene.get("_dialogue_active")):
		boss_scene.call("_close_dialogue")
	boss_scene.call("_refresh_ui")
	await _settle(1.2)
	var boss_overlay: Control = boss_scene.get("_boss_health_overlay") as Control
	_expect(boss_overlay != null and boss_overlay.is_visible_in_tree(), "Boss proof should show the boss health bar")
	boss_scene.call("_show_turn_banner", false)
	await _settle(0.3)
	await _save("11_boss_combat")
	var banner: Control = boss_scene.get("_turn_banner") as Control
	_expect(banner != null and not banner.visible, "Phase banners stand down while the boss health bar owns the top band")
	boss_scene.queue_free()
	await process_frame

func _edges_show_clear_colour(label: String) -> bool:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, label]))
	if image == null:
		return true
	var hits: int = 0
	for y: int in range(0, image.get_height(), 8):
		for x: int in [0, 1, 2, 3, 4, 5, 6, image.get_width() - 7, image.get_width() - 1]:
			var pixel: Color = image.get_pixel(x, y)
			if absf(pixel.r - DEFAULT_CLEAR_GREY.r) < 0.02 and absf(pixel.g - DEFAULT_CLEAR_GREY.g) < 0.02 and absf(pixel.b - DEFAULT_CLEAR_GREY.b) < 0.02:
				hits += 1
	return hits > 4

func _assert_left_dock(instance: Node) -> void:
	var hud: Control = instance.get("_combat_objective_hud") as Control
	var meter: Control = instance.get("_play_meter") as Control
	if hud == null or meter == null or not hud.visible or not meter.visible:
		_expect(false, "Combat should show the objective above the card-play meter")
		return
	var hud_rect: Rect2 = hud.get_global_rect()
	var meter_rect: Rect2 = meter.get_global_rect()
	var gap: float = meter_rect.position.y - hud_rect.end.y
	_expect(gap >= 8.0 and gap <= 20.0, "Objective should sit directly above the dock (gap %.1f)" % gap)
	var board_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds") as Rect2
	_expect(board_bounds.size.x <= 0.0 or not hud_rect.intersects(board_bounds), "Objective must not cover the board")
	if board_bounds.size.x <= 0.0 or meter_rect.end.x + 12.0 <= board_bounds.position.x:
		_expect(absf(hud_rect.end.x - meter_rect.end.x) <= 1.0, "Objective and meters should share one flush right edge")

func _first_room_of_type(instance: Node, room_type: String) -> Vector2i:
	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	for coord: Vector2i in run_engine.available_moves(run_state):
		if str(run_engine.room_metadata(run_state, coord).get("type", "")) == room_type:
			return coord
	return Vector2i.ZERO

func _settle(seconds: float) -> void:
	await process_frame
	await process_frame
	await create_timer(seconds).timeout
	await process_frame

func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, label]))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("BEAUTIFY FEEL PROBE: PASS")
		quit(0)
	else:
		print("BEAUTIFY FEEL PROBE: FAIL (%d)" % _failures.size())
		quit(1)
