extends SceneTree

# Real-renderer combat proof for the card pool polish pass at 1920x1080 / 100%
# UI scale: live Rite and condition cards in the real hand, a Rite's focus
# tooltips, and the selected card's Time badge with Empower +Time off and on.
# Run through tools/visual_probe_runner.py; LABYRINTH_PROBE_TAG versions output.

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardKeywordsSuite = preload("res://tests/suites/card_keywords_suite.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const HAND: Array[String] = ["rite_of_the_pyre", "thorn_crown_pact", "hallowed_strike", "overhead_smash", "tectonic_maul", "butcher_chop", "polar_guard"]
const EMPOWER_INDEX: int = 3

var _failed: bool = false
var _output_dir: String = ""


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var tag: String = OS.get_environment("LABYRINTH_PROBE_TAG").strip_edges()
	_output_dir = "user://probes/card_pool_polish_combat/%s" % (tag if not tag.is_empty() else "v1")
	ProgressionStore.set_storage_path("user://card_polish_combat_progression.json")
	ProgressionStore.set_run_storage_path("user://card_polish_combat_run.save")
	ProgressionStore.clear_saved_run()
	SettingsStore.set_storage_path("user://card_polish_combat_settings.json")
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	CardKeywordsSuite.install_fixtures()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "RunScene loads for the polish combat proof")
	if packed != null:
		await _capture(packed)
	CardKeywordsSuite.remove_fixtures()
	ProgressionStore.clear_saved_run()
	print(ProjectSettings.globalize_path(_output_dir))
	quit(1 if _failed else 0)


func _capture(packed: PackedScene) -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	_install_combat(instance)
	await _settle()
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false
	await _settle()
	_save(viewport, "01_hand_rite_and_condition_rows.png")
	instance.call("_on_card_hover_started", 1)
	await _settle()
	_save(viewport, "02_hover_rite_focus_tooltips.png")
	instance.call("_on_card_hover_ended", 1)
	await _settle()
	await instance.call("_on_card_pressed", EMPOWER_INDEX)
	await _settle()
	_aim_at(instance, Vector2i(3, 4))
	await _settle()
	var printed_time: int = int(GameData.card_def(HAND[EMPOWER_INDEX]).get("time", 0))
	_assert(_badge_value(instance) == printed_time, "Before Empower the selected badge shows the printed %d Time" % printed_time)
	_save(viewport, "03_empower_off_time_badge.png")
	await instance.call("_toggle_pending_empower")
	await _settle()
	_aim_at(instance, Vector2i(3, 4))
	await _settle()
	_assert(bool(instance.call("_selected_card_empowered")), "Empower toggles on for the selected card")
	var preview: Dictionary = instance.call("_turn_order_card_time_preview")
	_assert(_badge_value(instance) == printed_time + 2, "With Empower +2 Time the badge shows %d" % (printed_time + 2))
	_assert(int(preview.get("time", -1)) == _badge_value(instance), "The card badge and turn-order preview agree on the Empowered Time")
	var badge: Control = _badge(instance)
	_assert(badge != null and str(badge.tooltip_text).contains("Empower: +2"), "The badge detail names the Empower surcharge")
	_save(viewport, "04_empower_on_time_badge.png")
	await instance.call("_toggle_pending_empower")
	await _settle()
	_assert(_badge_value(instance) == printed_time, "Turning Empower off restores the printed Time badge")
	await instance.call("_cancel_card_selection")
	await _settle()
	instance.queue_free()
	viewport.queue_free()
	await process_frame


func _aim_at(instance: Node, tile: Vector2i) -> void:
	var board: Control = instance.get("board_view") as Control
	instance.call("_on_board_tile_hovered", tile)
	instance.call("_refresh_board_hover_presentation")
	instance.call("_sync_click_targeting_arrow", board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", tile) as Vector2))


func _badge(instance: Node) -> Control:
	var widget: Node = instance.call("_hand_card_control", EMPOWER_INDEX)
	return widget.get("_time_badge") as Control if widget != null else null


func _badge_value(instance: Node) -> int:
	var badge: Control = _badge(instance)
	return int(badge.get("value")) if badge != null else -1


func _install_combat(instance: Node) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var combat := CombatEngine.new()
	var state: Dictionary = CardKeywordsSuite._state(combat, HAND)
	state["current_actor"] = {"kind": "player", "key": "player"}
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	var sources: Array = (umbra.get("light_sources", []) as Array).duplicate(true)
	sources.append({"id": "probe_light", "pos": Vector2i(3, 4), "radius": 1, "duration": 3})
	umbra["light_sources"] = sources
	state["umbra"] = umbra
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = Vector2i(2, 2)
	run_state["combat_state"] = state
	instance.set("_guided_tutorial_phase_id", "")
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.set("_animation_lock", false)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")


func _save(viewport: SubViewport, file_name: String) -> void:
	RenderingServer.force_draw()
	var image: Image = viewport.get_texture().get_image()
	_assert(image != null and image.get_size() == VIEWPORT_SIZE, "%s captures an exact 1920x1080 frame" % file_name)
	if image != null and image.get_size() == VIEWPORT_SIZE:
		image.save_png("%s/%s" % [_output_dir, file_name])


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.2).timeout


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
