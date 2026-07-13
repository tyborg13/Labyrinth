extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const OUTPUT_DIR: String = "user://probes/umbra_visual"
const BOARD_PATH: String = "Backdrop/Margin/MainVBox/StageRoot/CombatBoard"
const UMBRA_SUBTITLE_PATH: String = "Backdrop/Margin/MainVBox/TopBar/TitleBox/UmbraSubtitle"
const STAGES: Array[String] = ["clear", "fringe", "advancing", "pressing", "deep", "heart", "eclipse"]
const EXPECTED_VISIBLE: Dictionary = {
	"clear": 6,
	"fringe": 6,
	"advancing": 5,
	"pressing": 4,
	"deep": 3,
	"heart": 2,
	"eclipse": 1
}
const EXPECTED_SUBTITLE: Dictionary = {
	"clear": "",
	"fringe": "Fringe Umbra",
	"advancing": "Advancing Umbra",
	"pressing": "Pressing Umbra",
	"deep": "Deep Umbra",
	"heart": "Heart Umbra",
	"eclipse": "Eclipse Umbra"
}
const RADIANCE_CARDS: Array[String] = [
	"lantern_shot",
	"guiding_flare",
	"dawnstep",
	"prism_sight",
	"storm_beacon",
	"glowstone_ward",
	"daybreak"
]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://umbra_visual_progression.json")
	ProgressionStore.set_run_storage_path("user://umbra_visual_run.save")
	ProgressionStore.clear_saved_run()
	await _capture_umbra_stages_and_cards()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_umbra_stages_and_cards() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "Run scene should load for Umbra visual proof")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	for stage: String in STAGES:
		await _load_stage(instance, stage)
		var board: Control = instance.get_node(BOARD_PATH) as Control
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var visible_enemy_ids: Array = presentation.get("visible_enemy_ids", [])
		_assert(visible_enemy_ids.size() == int(EXPECTED_VISIBLE.get(stage, -1)), "%s should expose exactly %d enemies" % [stage, int(EXPECTED_VISIBLE.get(stage, -1))])
		var umbra_subtitle: Label = instance.get_node(UMBRA_SUBTITLE_PATH) as Label
		var expected_subtitle: String = str(EXPECTED_SUBTITLE.get(stage, ""))
		_assert(umbra_subtitle != null and umbra_subtitle.text == expected_subtitle, "%s should show its dedicated Umbra room subtitle" % stage)
		_assert(umbra_subtitle.visible == not expected_subtitle.is_empty(), "%s should use the expected Umbra subtitle visibility" % stage)
		if stage != "clear":
			_assert(umbra_subtitle.tooltip_text.contains("Hidden enemies cannot be targeted"), "%s should explain its targeting and intent rules on hover" % stage)
		_assert(not (instance.get("_intensity_labels") as Dictionary).has("umbra"), "Umbra should not be represented as an elemental intensity")
		_assert((instance.get("_intensity_bar") as Control).get_child_count() == 5, "Intensity bar should contain only the five elements")
		await _save_root_screenshot("%s/stage_%s.png" % [OUTPUT_DIR, stage])
		if stage == "deep":
			await create_timer(0.65).timeout
			RenderingServer.force_draw()
			await process_frame
			await _save_root_screenshot("%s/stage_deep_billow.png" % OUTPUT_DIR)
	await _capture_grimoire_entries(instance)
	await _capture_active_effect_feedback(instance)
	await _capture_card_gallery(instance)
	instance.queue_free()
	await process_frame

func _load_stage(instance: Node, stage: String) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var combat := CombatEngine.new()
	var layout: Dictionary = _room_layout()
	var combat_state: Dictionary = combat.create_combat(97113, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": RADIANCE_CARDS,
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["lantern_shot", "dawnstep", "prism_sight", "glowstone_ward", "daybreak"]
	deck["draw"] = ["guiding_flare", "storm_beacon"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["traps"] = []
	combat_state["terrain"] = []
	combat_state["elemental_intensity"] = {"fire": 3, "ice": 3, "lightning": 3, "air": 3, "earth": 3}
	var umbra: Dictionary = (combat_state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["stage"] = stage
	umbra["stage_reduction"] = 0
	combat_state["umbra"] = umbra
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle_ui()

func _capture_grimoire_entries(instance: Node) -> void:
	var discovery_ids: Array[String] = GrimoireLibrary.entry_ids_for_card_ids(RADIANCE_CARDS)
	if not discovery_ids.has("combat:umbra"):
		discovery_ids.append("combat:umbra")
	instance.call("_unlock_grimoire_entries", discovery_ids)
	await _capture_grimoire_entry(instance, "combat:umbra", "The Umbra", "Enemies concealed within it", "grimoire_umbra.png")
	await _capture_grimoire_entry(instance, "keyword:radiance", "Radiance", "Illuminate, Vision, Truesight", "grimoire_radiance.png")
	await _capture_grimoire_entry(instance, "keyword:truesight", "Truesight", "permits direct attacks", "grimoire_truesight.png")
	await _capture_grimoire_entry(instance, "magick:lantern_shot", "Lantern Shot", "School: Radiance", "grimoire_lantern_shot.png")

func _capture_grimoire_entry(instance: Node, entry_id: String, expected_title: String, expected_body: String, file_name: String) -> void:
	instance.call("_open_grimoire_overlay")
	await _settle_ui()
	instance.call("_on_grimoire_entry_pressed", entry_id)
	await _settle_ui()
	var title: Label = instance.get("_grimoire_detail_title") as Label
	var body: RichTextLabel = instance.get("_grimoire_detail_body") as RichTextLabel
	_assert(title != null and title.text == expected_title, "%s should render its Grimoire title" % entry_id)
	var definition: Dictionary = GrimoireLibrary.entry_def(entry_id)
	var catalog_body: String = "\n".join(definition.get("body", []) as Array)
	_assert(catalog_body.contains(expected_body), "%s should carry its explanatory Grimoire body" % entry_id)
	if str(definition.get("card_id", "")).is_empty():
		_assert(body != null and body.visible and body.text.contains(expected_body), "%s should render its explanatory Grimoire body" % entry_id)
	else:
		var detail_content: VBoxContainer = instance.get("_grimoire_detail_content") as VBoxContainer
		_assert(detail_content != null and detail_content.get_child_count() > 0, "%s should render its card preview in the Grimoire" % entry_id)
	await _save_root_screenshot("%s/%s" % [OUTPUT_DIR, file_name])
	instance.call("_close_grimoire_overlay")
	await _settle_ui()

func _capture_active_effect_feedback(instance: Node) -> void:
	await _load_stage(instance, "heart")
	var active_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var active_umbra: Dictionary = (active_state.get("umbra", {}) as Dictionary).duplicate(true)
	active_umbra["light_sources"] = [{
		"id": 901,
		"pos": Vector2i(5, 5),
		"radius": 2,
		"remaining_activations": 2
	}]
	active_umbra["truesight_activations"] = 2
	active_state["umbra"] = active_umbra
	_set_combat_state(instance, active_state)
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_assert(int(presentation.get("umbra_truesight_activations", 0)) == 2, "True Sight should expose its remaining activation count to the player HUD")
	_assert((presentation.get("umbra_light_sources", []) as Array).size() == 1, "Active light sources should be exposed to the board presentation")
	var tooltip_regions: Array = board.get("_tooltip_regions") as Array
	_assert(_has_tooltip_containing(tooltip_regions, "Light Source"), "The glowing light-source marker should have a hover tooltip")
	_assert(_has_tooltip_containing(tooltip_regions, "True Sight"), "The player True Sight badge should have a hover tooltip")
	await _save_root_screenshot("%s/active_effect_feedback.png" % OUTPUT_DIR)

	var expired_state: Dictionary = active_state.duplicate(true)
	var expired_umbra: Dictionary = (expired_state.get("umbra", {}) as Dictionary).duplicate(true)
	expired_umbra["light_sources"] = []
	expired_umbra["truesight_activations"] = 0
	expired_state["umbra"] = expired_umbra
	expired_state["turn"] = int(active_state.get("turn", 0)) + 1
	_set_combat_state(instance, expired_state)
	await process_frame
	_assert(not (board.get("_umbra_return_start_by_tile") as Dictionary).is_empty(), "Expired light should start a staggered Umbra return instead of snapping")
	RenderingServer.force_draw()
	await process_frame
	await _save_root_screenshot("%s/umbra_return_start.png" % OUTPUT_DIR)
	await create_timer(0.48).timeout
	RenderingServer.force_draw()
	await process_frame
	await _save_root_screenshot("%s/umbra_return_mid.png" % OUTPUT_DIR)
	await create_timer(0.65).timeout
	RenderingServer.force_draw()
	await process_frame
	_assert((board.get("_umbra_return_start_by_tile") as Dictionary).is_empty(), "Umbra return should finish in about one second")
	await _save_root_screenshot("%s/umbra_return_end.png" % OUTPUT_DIR)

func _set_combat_state(instance: Node, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")

func _has_tooltip_containing(regions: Array, text: String) -> bool:
	for region_var: Variant in regions:
		if typeof(region_var) == TYPE_DICTIONARY and str((region_var as Dictionary).get("tooltip", "")).contains(text):
			return true
	return false

func _capture_card_gallery(instance: Node) -> void:
	(instance as CanvasItem).visible = false
	var background := ColorRect.new()
	background.color = Color("16111d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	root.add_child(background)
	var title := Label.new()
	title.text = "RADIANCE · LIGHT AGAINST THE UMBRA"
	title.position = Vector2(42.0, 18.0)
	title.size = Vector2(1356.0, 38.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f4dfb8"))
	root.add_child(title)
	for index: int in range(RADIANCE_CARDS.size()):
		var card_id: String = RADIANCE_CARDS[index]
		var slot := Control.new()
		slot.position = Vector2(44.0 + float(index % 4) * 342.0, 70.0 + float(index / 4) * 400.0)
		slot.custom_minimum_size = Vector2(250.0, 352.0)
		slot.size = Vector2(250.0, 352.0)
		root.add_child(slot)
		var widget: CardWidget = CardWidgetScene.instantiate()
		widget.custom_minimum_size = slot.size
		widget.size = slot.size
		slot.add_child(widget)
		var display: Dictionary = instance.call("_card_widget_display", card_id, instance.get("_combat_state"))
		widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
		widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	await _settle_ui()
	await _save_root_screenshot("%s/radiance_cards.png" % OUTPUT_DIR)
	background.queue_free()
	title.queue_free()

func _room_layout() -> Dictionary:
	var positions: Array[Vector2i] = _vector2i_array([
		Vector2i(3, 4),
		Vector2i(2, 2),
		Vector2i(4, 3),
		Vector2i(6, 4),
		Vector2i(7, 4),
		Vector2i(7, 3)
	])
	var enemy_types: Array[String] = ["warden", "harrier", "lightning_wisp", "acolyte", "crawler", "grave_surgeon"]
	var enemies: Array = []
	for index: int in range(positions.size()):
		var enemy_def: Dictionary = GameData.enemy_def(enemy_types[index])
		enemies.append({
			"id": index + 1,
			"type": enemy_types[index],
			"pos": positions[index],
			"hp": int(enemy_def.get("max_hp", 20)),
			"max_hp": int(enemy_def.get("max_hp", 20)),
			"block": 0
		})
	return {
		"name": "Umbra Visual Proof",
		"coord": Vector2i(21, 0),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": enemies,
		"traps": [],
		"terrain": [],
		"loot": [{
			"kind": "equipment",
			"equipment_id": "iron_cleaver",
			"pos": Vector2i(6, 5)
		}]
	}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 8 else "ash")
		grid.append(row)
	return grid

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		result.append(value as Vector2i)
	return result

func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	_assert(image.save_png(output_path) == OK, "Could not save %s" % output_path)

func _clear_probe_output(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
