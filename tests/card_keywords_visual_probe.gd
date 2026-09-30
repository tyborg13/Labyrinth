extends SceneTree

# Real-renderer proof for card keywords at 1920x1080 / 100% UI scale:
# hand rows (active Follow-up, Empower, state and scale bonuses), the Empower
# command-host toggle with the Stagger turn-order preview, and a targetless
# Empower confirmation. Run through tools/visual_probe_runner.py.

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardKeywordsSuite = preload("res://tests/suites/card_keywords_suite.gd")

const OUTPUT_DIR: String = "user://probes/card_keywords_v1/1920x1080"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const ART_BY_FIXTURE := {
	"kwtest_follow_strike": "quick_stab",
	"kwtest_empower_time": "bloody_lunge",
	"kwtest_stonefist": "stone_plate",
	"kwtest_light_strike": "pale_spark",
	"kwtest_empower_block": "brace",
}

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://card_keywords_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://card_keywords_probe_run.save")
	ProgressionStore.clear_saved_run()
	SettingsStore.set_storage_path("user://card_keywords_probe_settings.json")
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_install_fixture_cards()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "RunScene loads for the card keyword proof")
	if packed != null:
		await _capture(packed)
	CardKeywordsSuite.remove_fixtures()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _install_fixture_cards() -> void:
	CardKeywordsSuite.install_fixtures()
	var cards: Dictionary = GameData.cards()
	for card_id: String in ART_BY_FIXTURE:
		var art_source: Dictionary = cards.get(str(ART_BY_FIXTURE[card_id]), {}) as Dictionary
		var fixture: Dictionary = cards.get(card_id, {}) as Dictionary
		if not art_source.is_empty():
			fixture["art_path"] = art_source.get("art_path", "")
	(cards["kwtest_follow_strike"] as Dictionary)["name"] = "Quick Stab"
	(cards["kwtest_empower_time"] as Dictionary)["name"] = "Overhead Smash"
	(cards["kwtest_stonefist"] as Dictionary)["name"] = "Stonefist"
	(cards["kwtest_light_strike"] as Dictionary)["name"] = "Hallowed Strike"
	(cards["kwtest_empower_block"] as Dictionary)["name"] = "Braced Guard"

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
	_hide_log(instance)
	await _settle()
	_save(viewport, "hand_keyword_rows.png")
	# Enlarge the active Follow-up card to inspect its rows.
	instance.call("_on_card_hover_started", 0)
	await _settle()
	_save(viewport, "hover_follow_up_active.png")
	instance.call("_on_card_hover_ended", 0)
	await _settle()
	# Targeted Empower: toggle, then hover the Stagger target.
	await instance.call("_on_card_pressed", 1)
	await _settle()
	await instance.call("_toggle_pending_empower")
	await _settle()
	_assert(bool(instance.call("_selected_card_empowered")), "Empower toggles on for the targeted card")
	instance.call("_on_board_tile_hovered", Vector2i(3, 4))
	instance.call("_refresh_board_hover_presentation")
	instance.call("_sync_click_targeting_arrow", _tile_global_position(instance, Vector2i(3, 4)))
	await _settle()
	var delays: Dictionary = instance.call("_turn_order_stagger_preview_delays")
	_assert(int(delays.get(1, 0)) == 4, "The hovered Stagger target previews its delay")
	var bar: Node = instance.get("_action_context_command_bar") as Node
	_assert(bar != null and bar.get_node_or_null("ActionContextEmpower") != null, "The command host shows the Empower toggle")
	var selected_widget: Node = instance.call("_hand_card_control", 1)
	var shown_rows: Array = selected_widget.get("_summary_rows") if selected_widget != null else []
	var empower_active_shown: bool = false
	for row_var: Variant in shown_rows:
		for token_var: Variant in row_var as Array:
			empower_active_shown = empower_active_shown or (str((token_var as Dictionary).get("keyword_segment", "")) == "empower" and bool((token_var as Dictionary).get("active", false)))
	_assert(empower_active_shown, "The selected hand card marks its Empower segment active")
	_save(viewport, "empower_on_stagger_preview.png")
	await instance.call("_cancel_card_selection")
	await _settle()
	# Targetless Empower at its confirmation stage.
	await instance.call("_on_card_pressed", 4)
	await _settle()
	_assert(bool(instance.call("_pending_card_requires_confirmation")), "The targetless card reaches confirmation")
	_save(viewport, "targetless_empower_offered.png")
	await instance.call("_toggle_pending_empower")
	await _settle()
	_save(viewport, "targetless_empower_on.png")
	instance.queue_free()
	viewport.queue_free()
	await process_frame

func _install_combat(instance: Node) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var combat := CombatEngine.new()
	var hand: Array = ["kwtest_follow_strike", "kwtest_empower_time", "kwtest_stonefist", "kwtest_light_strike", "kwtest_empower_block"]
	var state: Dictionary = CardKeywordsSuite._state(combat, hand)
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_played_this_turn"] = 1
	(state["player"] as Dictionary)["stoneskin"] = 3
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

func _tile_global_position(instance: Node, tile: Vector2i) -> Vector2:
	var board: Control = instance.get("board_view") as Control
	return board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", tile) as Vector2)

func _hide_log(instance: Node) -> void:
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false

func _save(viewport: SubViewport, file_name: String) -> void:
	RenderingServer.force_draw()
	var image: Image = viewport.get_texture().get_image()
	_assert(image != null and image.get_size() == VIEWPORT_SIZE, "%s captures an exact 1920x1080 frame" % file_name)
	if image != null and image.get_size() == VIEWPORT_SIZE:
		image.save_png("%s/%s" % [OUTPUT_DIR, file_name])

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.2).timeout

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
