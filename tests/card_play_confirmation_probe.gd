extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/card_play_confirmation_v2"
const STORAGE_PATH: String = "user://card_play_confirmation_probe_progression.json"
const RUN_STORAGE_PATH: String = "user://card_play_confirmation_probe_run.save"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "Run scene should load for card confirmation proof")
	if packed != null:
		await _capture_confirmation(packed, Vector2i(1920, 1080))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_confirmation(packed: PackedScene, viewport_size: Vector2i) -> void:
	var capture_viewport := SubViewport.new()
	capture_viewport.name = "CardPlayConfirmationViewport"
	capture_viewport.size = viewport_size
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var instance: Node = packed.instantiate()
	capture_viewport.add_child(instance)
	await _settle_ui()
	_install_combat_fixture(instance)
	await _settle_ui()
	var state_before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	instance.call("_on_card_pressed", 0)
	await _settle_ui()

	var context: Control = instance.get("_action_step_tracker") as Control
	var board: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var player_tile: Vector2i = ((state_before.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)))
	var confirmation_tiles: Array = (board.get("presentation") as Dictionary).get("confirmation_target_tiles", []) as Array
	_assert(instance.get_viewport().get_visible_rect().size == Vector2(viewport_size), "%s proof should use the requested logical viewport" % viewport_size)
	_assert((instance.get("_combat_state") as Dictionary) == state_before, "%s card selection should not mutate live combat" % viewport_size)
	_assert(int(instance.get("_selected_card_index")) == 0, "%s should arm the exact selected card" % viewport_size)
	_assert(int(instance.get("_card_action_choice_index")) == -1 and str(instance.get("_card_action_choice_mode")) == "play", "%s should auto-enter the sole legal Printed mode" % viewport_size)
	_assert(int(instance.get("_pending_action_index")) >= (instance.get("_pending_actions") as Array).size(), "%s targetless preview should finish without committing" % viewport_size)
	_assert(context != null and not context.visible, "%s the execution tracker should stay hidden until the play is confirmed" % viewport_size)
	_assert(_button_with_text(context, "Play Card") == null, "%s should not expose a third confirmation control" % viewport_size)
	_assert(confirmation_tiles == [player_tile], "%s should expose only the protagonist tile as the targetless confirmation" % viewport_size)

	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false
	await _settle_ui()
	var output_dir: String = "%s/%dx%d" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var image: Image = capture_viewport.get_texture().get_image()
	_assert(image != null and image.get_size() == viewport_size, "%s proof should capture an exact-size renderer frame" % viewport_size)
	var frame_coverage: float = _non_black_frame_coverage(image)
	_assert(frame_coverage >= 0.08, "%s proof should capture a complete scene frame, got %.3f non-black coverage" % [viewport_size, frame_coverage])
	if image != null and image.get_size() == viewport_size and frame_coverage >= 0.08:
		image.save_png("%s/targetless_confirmation.png" % output_dir)

	var rejected_sfx_generation: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	await instance.call("_on_board_tile_clicked", Vector2i(5, 4))
	_assert((instance.get("_combat_state") as Dictionary) == state_before, "%s a non-player tile should not confirm a targetless card" % viewport_size)
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == rejected_sfx_generation, "%s a rejected board click should stay silent" % viewport_size)
	var sfx_generation_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	instance.call("_on_board_tile_clicked", player_tile)
	await create_timer(0.10).timeout
	_assert(
		_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_generation_before + 1,
		"%s a confirmed play should start exactly one card-take sound" % viewport_size
	)
	_assert(_active_ui_sfx_count(instance.get("_sfx_players") as Array) == 1, "%s the card-take sound should be active on the UI SFX bus during card flight" % viewport_size)
	_assert(_first_card_fx_proxy(instance) != null, "%s the card-take sound should overlap the card-to-center flight" % viewport_size)
	_assert((instance.get("_combat_state") as Dictionary) == state_before, "%s board resolution should not commit before the card-flight sound and animation" % viewport_size)
	RenderingServer.force_draw()
	await process_frame
	var flight_image: Image = capture_viewport.get_texture().get_image()
	_assert(flight_image != null and flight_image.get_size() == viewport_size, "%s confirmed-play flight proof should keep the exact renderer size" % viewport_size)
	if flight_image != null and flight_image.get_size() == viewport_size:
		flight_image.save_png("%s/confirmed_play_card_flight.png" % output_dir)
	await _wait_for_card_resolution(instance, 4.0)
	_assert(int(instance.get("_selected_card_index")) == -1, "%s clicking the protagonist tile should finish the card" % viewport_size)
	instance.queue_free()
	capture_viewport.queue_free()
	await process_frame

func _install_combat_fixture(instance: Node) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _room_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(9811, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["stone_plate", "quick_stab"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["stone_plate", "quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")

func _room_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Cinder Crossing",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 140, "max_hp": 140, "block": 0}],
		"traps": [],
		"terrain": [],
		"loot": []
	}

func _button_with_text(root_node: Node, text: String) -> Button:
	if root_node == null:
		return null
	for node: Node in root_node.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text == text:
			return button
	return null

func _sfx_generation_total(players: Array) -> int:
	var total: int = 0
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null:
			total += int(player.get_meta("play_generation", 0))
	return total

func _active_ui_sfx_count(players: Array) -> int:
	var total: int = 0
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null and player.stream != null and player.bus == SettingsStore.UI_SFX_BUS:
			total += 1
	return total

func _first_card_fx_proxy(instance: Node) -> Control:
	var fx_layer: Control = instance.get("_card_fx_layer") as Control
	if fx_layer == null:
		return null
	for child: Node in fx_layer.get_children():
		if child is Control and bool(child.get_meta("scaled_card_proxy", false)):
			return child as Control
	return null

func _wait_for_card_resolution(instance: Node, timeout_seconds: float) -> void:
	var deadline_msec: int = Time.get_ticks_msec() + roundi(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		if not bool(instance.get("_animation_lock")) and int(instance.get("_selected_card_index")) < 0:
			return
		await process_frame

func _non_black_frame_coverage(image: Image) -> float:
	if image == null or image.is_empty():
		return 0.0
	var sampled: int = 0
	var non_black: int = 0
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			sampled += 1
			var pixel: Color = image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.015:
				non_black += 1
	return float(non_black) / float(maxi(1, sampled))

func _settle_ui() -> void:
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	RenderingServer.force_draw()
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
