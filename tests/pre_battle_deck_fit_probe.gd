extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://pre_battle_deck_fit_probe_v9"
const INVALID_COORD: Vector2i = Vector2i(999, 999)
const TARGET_VIEWPORTS: Array = [
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const DECK_VARIANTS: Array = ["small", "normal", "large"]
const LARGE_ATTUNEMENT: Array = [
	"pale_spark",
	"dull_bolt",
	"waning_pulse",
	"bone_dart",
	"static_lash",
	"threaded_path",
]
const LARGE_ITEMS: Array = ["crimson_draught", "mossglass_elixir"]

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_pre_battle_deck_fit_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_pre_battle_deck_fit_probe.save")
	ProgressionStore.clear_saved_run()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for viewport_var: Variant in TARGET_VIEWPORTS:
		var viewport_size: Vector2i = viewport_var as Vector2i
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await process_frame
		await process_frame
		root.size = viewport_size
		await process_frame
		var logical_size: Vector2 = root.get_viewport().get_visible_rect().size
		if not logical_size.is_equal_approx(Vector2(viewport_size)):
			_fail("Requested viewport %s should produce logical viewport %s, got %s" % [str(viewport_size), str(viewport_size), str(logical_size)])
		for variant_var: Variant in DECK_VARIANTS:
			var variant: String = str(variant_var)
			await _capture_variant(variant, viewport_size, false)
			await _capture_variant(variant, viewport_size, true)
			_prefer_complete_capture(variant, viewport_size)
	if _failed:
		print("TEST RESULT: FAIL")
		quit(1)
		return
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: PASS")
	quit()

func _capture_variant(variant: String, viewport_size: Vector2i, keep_screenshot: bool = true) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for pre-battle deck fit proof")
		return
	var probe_run_engine := RunEngine.new()
	var run_state: Dictionary = _run_with_available_combat(probe_run_engine)
	var combat_coord: Vector2i = _first_available_combat_coord(probe_run_engine, run_state)
	if combat_coord == INVALID_COORD:
		_fail("Pre-battle deck fit proof needs an available combat room")
		return
	run_state = _pre_battle_state_for_room(probe_run_engine, run_state, combat_coord)
	run_state = _apply_deck_variant(run_state, variant)

	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_load_run_state", run_state)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	await _settle()
	var loaded_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var expected_deck: Array = (loaded_state.get("deck_cards", []) as Array).duplicate()
	var expected_attuned: Array = (loaded_state.get("attuned_magic_cards", []) as Array).duplicate()
	var expected_variant_size: int = {"small": 16, "normal": 18, "large": 19}.get(variant, 0)
	if expected_deck.size() != expected_variant_size:
		_fail("%s representative fixture should compile to %d cards, got %d" % [variant, expected_variant_size, expected_deck.size()])

	var panel: Control = instance.get("_pre_battle_panel") as Control
	var scrim: Control = instance.get("_pre_battle_scrim") as Control
	if panel == null or scrim == null or not scrim.visible:
		_fail("%s %s pre-battle preview should be visible" % [variant, str(viewport_size)])
	else:
		_assert_inside(Rect2(Vector2.ZERO, Vector2(viewport_size)), panel, "%s %s dialog" % [variant, str(viewport_size)])
		_check_action_visibility(panel, viewport_size, variant)
		_check_enemy_visibility(panel, variant, viewport_size)
		_check_equipment_visibility(panel, loaded_state, variant, viewport_size)
		_check_counted_cards(panel, "attuned", expected_attuned, variant, viewport_size)
		_check_deck_fit(panel, expected_deck, variant, viewport_size)
		_check_inspection_sources(panel, variant, viewport_size)

	var screenshot_path: String = "%s/%s_%dx%d_v9.png" % [OUTPUT_DIR, variant, viewport_size.x, viewport_size.y]
	if not keep_screenshot:
		screenshot_path = "%s/_renderer_warmup.png" % OUTPUT_DIR
	await _save_root_screenshot(screenshot_path, viewport_size)
	instance.queue_free()
	await process_frame
	await process_frame

func _prefer_complete_capture(variant: String, viewport_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var warmup_path: String = ProjectSettings.globalize_path("%s/_renderer_warmup.png" % OUTPUT_DIR)
	var final_path: String = ProjectSettings.globalize_path("%s/%s_%dx%d_v9.png" % [OUTPUT_DIR, variant, viewport_size.x, viewport_size.y])
	var warmup_metrics: Dictionary = _capture_completeness_metrics(warmup_path)
	var final_metrics: Dictionary = _capture_completeness_metrics(final_path)
	if int(warmup_metrics.get("score", 0)) > int(final_metrics.get("score", 0)):
		DirAccess.remove_absolute(final_path)
		var copy_error: Error = DirAccess.copy_absolute(warmup_path, final_path)
		if copy_error != OK:
			_fail("Could not preserve the complete renderer capture for %s %s (error %d)" % [variant, str(viewport_size), copy_error])
	DirAccess.remove_absolute(warmup_path)
	var selected_metrics: Dictionary = _capture_completeness_metrics(final_path)
	var coverage: float = float(selected_metrics.get("score", 0)) / maxf(1.0, float(selected_metrics.get("samples", 0)))
	print("Capture selection %s %dx%d warm=%d final=%d coverage=%.3f" % [variant, viewport_size.x, viewport_size.y, int(warmup_metrics.get("score", 0)), int(final_metrics.get("score", 0)), coverage])
	if coverage < 0.012:
		_fail("%s %s renderer proof should include the complete header/enemy region (coverage %.3f)" % [variant, str(viewport_size), coverage])

func _capture_completeness_metrics(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"score": 0, "samples": 0}
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return {"score": 0, "samples": 0}
	var score: int = 0
	var samples: int = 0
	var x_end: int = maxi(1, int(float(image.get_width()) * 0.60))
	var y_end: int = maxi(1, int(float(image.get_height()) * 0.82))
	for y: int in range(0, y_end, 8):
		for x: int in range(0, x_end, 8):
			samples += 1
			if image.get_pixel(x, y).get_luminance() >= 0.055:
				score += 1
	return {"score": score, "samples": samples}

func _apply_deck_variant(run_state: Dictionary, variant: String) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	if variant == "small":
		return state
	var equipped: Dictionary = {
		"weapon": "grave_greatsword",
		"offhand": "witchglass_aegis",
		"armor": "voidsilk_carapace",
		"boots": "worldroot_greaves",
		"trinket": "crown_of_thorns",
	}
	var attuned: Array = (state.get("attuned_magic_cards", []) as Array).duplicate()
	var equipped_items: Array = ["crimson_draught"]
	if variant == "large":
		attuned = LARGE_ATTUNEMENT.duplicate()
		equipped_items = LARGE_ITEMS.duplicate()
	state["equipped_equipment"] = equipped
	state["attuned_magic_cards"] = attuned
	state["equipped_items"] = equipped_items
	state["deck_cards"] = GameData.compile_deck_cards(equipped, attuned, equipped_items)
	return state

func _check_action_visibility(panel: Control, viewport_size: Vector2i, variant: String) -> void:
	for button_name: String in ["PreBattleEquipButton", "PreBattleStartButton"]:
		var button: Control = panel.find_child(button_name, true, false) as Control
		if button == null:
			_fail("%s %s should keep %s visible" % [variant, str(viewport_size), button_name])
			continue
		_assert_inside(Rect2(Vector2.ZERO, Vector2(viewport_size)), button, "%s %s %s" % [variant, str(viewport_size), button_name])

func _check_enemy_visibility(panel: Control, variant: String, viewport_size: Vector2i) -> void:
	var enemy_scroll: ScrollContainer = panel.find_child("PreBattleEnemyScroll", true, false) as ScrollContainer
	var enemy_flow: HFlowContainer = panel.find_child("PreBattleEnemyFlow", true, false) as HFlowContainer
	if enemy_scroll == null or enemy_flow == null or enemy_flow.get_child_count() == 0:
		_fail("%s %s should keep enemy cards visible" % [variant, str(viewport_size)])
		return
	var visible_rect: Rect2 = enemy_scroll.get_global_rect().grow(1.0)
	for enemy_var: Variant in enemy_flow.get_children():
		var enemy_card: Control = enemy_var as Control
		if enemy_card == null:
			continue
		_assert_inside(visible_rect, enemy_card, "%s %s enemy card" % [variant, str(viewport_size)])
		if enemy_card.find_child("PreBattleThreatSummary", true, false) == null:
			_fail("%s %s enemy cards should retain known threat summaries" % [variant, str(viewport_size)])
	var first_enemy: Control = enemy_flow.get_child(0) as Control
	var inspection_var: Variant = first_enemy.call("_make_custom_tooltip", first_enemy.tooltip_text)
	if not (inspection_var is Control):
		_fail("%s %s enemy hover should expose known moves" % [variant, str(viewport_size)])
	elif inspection_var is Control:
		var inspection: Control = inspection_var as Control
		if inspection.find_child("PreBattleKnownMoves", true, false) == null:
			_fail("%s %s enemy inspection should retain known moves" % [variant, str(viewport_size)])
		inspection.free()

func _check_equipment_visibility(panel: Control, run_state: Dictionary, variant: String, viewport_size: Vector2i) -> void:
	var equipment_row: HFlowContainer = panel.find_child("PreBattleEquipmentRow", true, false) as HFlowContainer
	if equipment_row == null:
		_fail("%s %s should keep equipment visible" % [variant, str(viewport_size)])
		return
	var expected_count: int = 0
	var equipped: Dictionary = run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		if not str(equipped.get(slot, "")).is_empty():
			expected_count += 1
	if equipment_row.get_child_count() != expected_count:
		_fail("%s %s should render all %d equipped items, got %d" % [variant, str(viewport_size), expected_count, equipment_row.get_child_count()])
	for child_var: Variant in equipment_row.get_children():
		var equipment_chip: Control = child_var as Control
		if equipment_chip != null:
			_assert_inside(equipment_row.get_global_rect().grow(1.0), equipment_chip, "%s %s equipment chip" % [variant, str(viewport_size)])

func _check_counted_cards(panel: Control, source_kind: String, expected_cards: Array, variant: String, viewport_size: Vector2i) -> void:
	var represented_count: int = 0
	var container_name: String = "PreBattleAttunedRow" if source_kind == "attuned" else "PreBattleDeckFlow"
	var source_container: Control = panel.find_child(container_name, true, false) as Control
	var source_cards: Array = source_container.get_children() if source_container != null else []
	for badge_var: Variant in source_cards:
		var badge: Control = badge_var as Control
		if badge == null or str(badge.get_meta("source_kind", "")) != source_kind:
			continue
		var card_count: int = maxi(1, int(badge.get_meta("card_count", 1)))
		represented_count += card_count
		var card_id: String = str(badge.get_meta("card_id", ""))
		var label: Label = badge.find_child("CardBadgeName", true, false) as Label
		if card_id.is_empty() or label == null or label.text.strip_edges().is_empty():
			_fail("%s %s %s tiles should retain readable card identity" % [variant, str(viewport_size), source_kind])
			continue
		if card_count > 1 and not label.text.ends_with("x%d" % card_count):
			_fail("%s %s counted %s tiles should show x%d" % [variant, str(viewport_size), source_kind, card_count])
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		if font != null and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > label.size.x + 1.0:
			if label.get_line_count() > 2 or label.get_visible_line_count() < label.get_line_count():
				_fail("%s %s %s tile label '%s' should fit within two visible lines (lines=%d visible=%d size=%s font=%d)" % [variant, str(viewport_size), source_kind, label.text, label.get_line_count(), label.get_visible_line_count(), str(label.size), font_size])
	if represented_count != expected_cards.size():
		_fail("%s %s %s tiles should represent all %d entries, got %d" % [variant, str(viewport_size), source_kind, expected_cards.size(), represented_count])

func _check_deck_fit(panel: Control, expected_deck: Array, variant: String, viewport_size: Vector2i) -> void:
	var deck_scroll: ScrollContainer = panel.find_child("PreBattleDeckScroll", true, false) as ScrollContainer
	var deck_flow: HFlowContainer = panel.find_child("PreBattleDeckFlow", true, false) as HFlowContainer
	if deck_scroll == null or deck_flow == null:
		_fail("%s %s should render the Active Deck grid" % [variant, str(viewport_size)])
		return
	_check_counted_cards(panel, "deck", expected_deck, variant, viewport_size)
	var scroll_bar: VScrollBar = deck_scroll.get_v_scroll_bar()
	if scroll_bar.visible or scroll_bar.max_value > scroll_bar.page + 1.0 or deck_scroll.scroll_vertical != 0:
		_fail("%s %s standard fixture should not need Active Deck scrolling (max=%.1f page=%.1f value=%d visible=%s)" % [variant, str(viewport_size), scroll_bar.max_value, scroll_bar.page, deck_scroll.scroll_vertical, str(scroll_bar.visible)])
	var visible_rect: Rect2 = deck_scroll.get_global_rect().grow(1.0)
	for badge_var: Variant in deck_flow.get_children():
		var badge: Control = badge_var as Control
		if badge != null:
			_assert_inside(visible_rect, badge, "%s %s Active Deck tile" % [variant, str(viewport_size)])
	print("Deck fit %s %dx%d entries=%d groups=%d viewport=%.0fx%.0f" % [variant, viewport_size.x, viewport_size.y, expected_deck.size(), deck_flow.get_child_count(), deck_scroll.size.x, deck_scroll.size.y])

func _check_inspection_sources(panel: Control, variant: String, viewport_size: Vector2i) -> void:
	for source_name: String in ["PreBattleEquipmentChip", "PreBattleAttunedBadge", "PreBattleDeckBadge"]:
		var source: Control = panel.find_child(source_name, true, false) as Control
		if source == null:
			continue
		var tooltip_var: Variant = source.call("_make_custom_tooltip", source.tooltip_text)
		if not (tooltip_var is Control):
			_fail("%s %s %s should remain hover-inspectable" % [variant, str(viewport_size), source_name])
		elif tooltip_var is Control:
			(tooltip_var as Control).free()
		if source.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			_fail("%s %s %s should remain clickable" % [variant, str(viewport_size), source_name])

func _run_with_available_combat(probe_run_engine: RunEngine) -> Dictionary:
	var progression: Dictionary = ProgressionStore.default_data()
	for seed: int in range(1, 120):
		var state: Dictionary = probe_run_engine.create_new_run(seed, progression)
		if _first_available_combat_coord(probe_run_engine, state) != INVALID_COORD:
			return state
	return {}

func _first_available_combat_coord(probe_run_engine: RunEngine, run_state: Dictionary) -> Vector2i:
	if run_state.is_empty():
		return INVALID_COORD
	for coord_var: Variant in probe_run_engine.available_moves(run_state):
		if typeof(coord_var) != TYPE_VECTOR2I:
			continue
		var coord: Vector2i = coord_var
		var preview_state: Dictionary = probe_run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat" and not (preview_state.get("combat_state", {}) as Dictionary).is_empty():
			return coord
	return INVALID_COORD

func _pre_battle_state_for_room(probe_run_engine: RunEngine, run_state: Dictionary, coord: Vector2i) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	var travel_dir: Vector2i = _travel_dir_for_coord(coord)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = RunEngine.MODE_PRE_BATTLE
	state["combat_state"] = {}
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = travel_dir
	return state

func _travel_dir_for_coord(coord: Vector2i) -> Vector2i:
	if coord == Vector2i.ZERO:
		return Vector2i(1, 0)
	if absi(coord.x) >= absi(coord.y) and coord.x != 0:
		return Vector2i(1, 0) if coord.x > 0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if coord.y > 0 else Vector2i(0, -1)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _assert_inside(container_rect: Rect2, child: Control, label: String) -> void:
	if child == null:
		_fail("%s should exist" % label)
		return
	if not child.visible or not container_rect.grow(1.0).encloses(child.get_global_rect()):
		_fail("%s should be fully visible; child=%s container=%s" % [label, str(child.get_global_rect()), str(container_rect)])

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.40).timeout
	await process_frame
	await process_frame

func _save_root_screenshot(output_path: String, viewport_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	await create_timer(0.10).timeout
	await process_frame
	RenderingServer.force_draw(true)
	var warm_image: Image = root.get_viewport().get_texture().get_image()
	if warm_image != null:
		if warm_image.get_width() != viewport_size.x or warm_image.get_height() != viewport_size.y:
			warm_image.resize(viewport_size.x, viewport_size.y, Image.INTERPOLATE_LANCZOS)
		warm_image.save_png(output_path)
	await create_timer(0.35).timeout
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	if image.get_width() != viewport_size.x or image.get_height() != viewport_size.y:
		image.resize(viewport_size.x, viewport_size.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if not dir.current_is_dir():
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
