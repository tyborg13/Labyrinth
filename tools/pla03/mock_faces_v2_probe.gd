extends SceneTree

# Playability mock faces v2 (2026-11-20): blank faces (icon rows hidden) of the
# v2 cards with the art height the engine would lend to their v2 token rows.
# The lend is applied exactly as card_widget._lend_art_height_to_rules does
# (art_frame/details_panel/desc_label/_summary_icon_box minimum heights) from
# the un-lent layout (art 115, details 140). LENDS_JSON = {card_id: lend}.
#   hand_<id>_blank.png / hover_<id>_blank.png + manifest.json
# Run through tools/visual_probe_runner.py; MOCK_OUT = abs dir.

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")

const RESOLUTION := Vector2i(1920, 1080)
const ART_HEIGHT: float = 115.0
const DETAILS_HEIGHT: float = 140.0

var _out: String = ""
var _viewport: SubViewport
var _failed: bool = false
var _manifest: Dictionary = {}
var _lends: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_out = OS.get_environment("MOCK_OUT")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("user://mock_faces")
	DirAccess.make_dir_recursive_absolute(_out)
	ProgressionStore.set_storage_path("user://mock_faces_progression.json")
	ProgressionStore.set_run_storage_path("user://mock_faces_run.save")
	SettingsStore.set_storage_path("user://mock_faces_settings.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("mock faces probe needs a real renderer")
		quit(1)
		return
	_lends = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LENDS_JSON"))) as Dictionary
	_viewport = SubViewport.new()
	_viewport.size = RESOLUTION
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	await _configure_window()
	await _capture_cards()
	_manifest["cel_look"] = OS.get_environment("LABYRINTH_CEL_LOOK")
	var file := FileAccess.open("%s/manifest.json" % _out, FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest, "  "))
	file.close()
	print(_out)
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _configure_window() -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = RESOLUTION
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = RESOLUTION
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _settle()

func _capture_cards() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	_viewport.add_child(instance)
	await _settle()
	for card_id: String in _lends.keys():
		var lend: float = float(_lends[card_id])
		await _load_combat(instance, [card_id])
		var widget: CardWidget = _find_widget(instance, card_id)
		if widget == null:
			push_error("no hand widget for %s" % card_id)
			_failed = true
			continue
		var entry: Dictionary = {"lend": lend}
		entry["hand"] = await _shoot_blank(widget, "hand_%s" % card_id, lend)
		# Hover can miss on a freshly loaded hand; retry until the card is enlarged.
		for attempt: int in range(4):
			instance.call("_on_card_hover_started", 0)
			await _settle()
			await create_timer(0.8).timeout
			await _settle()
			widget = _find_widget(instance, card_id)
			if widget != null and widget.get_global_transform_with_canvas().get_scale().x > 1.0:
				break
			instance.call("_on_card_hover_ended", 0)
			await _settle()
		if widget == null or widget.get_global_transform_with_canvas().get_scale().x <= 1.0:
			push_error("hover did not enlarge %s" % card_id)
			_failed = true
		entry["hover"] = await _shoot_blank(widget, "hover_%s" % card_id, lend)
		instance.call("_on_card_hover_ended", 0)
		await _settle()
		_restore(widget)
		_manifest[card_id] = entry
	instance.queue_free()
	await _settle()

func _apply_lend(widget: CardWidget, lend: float) -> void:
	var rows: Control = widget.get("_summary_icon_box") as Control
	var desc: Control = widget.get("desc_label") as Control
	var art: Control = widget.get("art_frame") as Control
	var details: Control = widget.get("details_panel") as Control
	rows.visible = false
	desc.visible = false
	art.custom_minimum_size.y = ART_HEIGHT - lend
	details.custom_minimum_size.y = DETAILS_HEIGHT + lend
	desc.custom_minimum_size.y = DETAILS_HEIGHT + lend
	rows.custom_minimum_size.y = DETAILS_HEIGHT + lend

func _restore(widget: CardWidget) -> void:
	if widget == null:
		return
	(widget.get("_summary_icon_box") as Control).visible = true

# The card's blank face (rows hidden) at the v2 art lend.
func _shoot_blank(widget: CardWidget, shot: String, lend: float) -> Dictionary:
	_apply_lend(widget, lend)
	await _settle()
	_apply_lend(widget, lend)
	await _settle()
	var info: Dictionary = _widget_info(widget)
	info["details_rect"] = _screen_rect(widget.get("details_panel") as Control)
	info["art_rect"] = _screen_rect(widget.get("art_frame") as Control)
	info["title_rect"] = _screen_rect(widget.get("title_label") as Control)
	info["rows_rect"] = _screen_rect(widget.get("_summary_icon_box") as Control)
	await _shoot(shot + "_blank")
	return info

func _widget_info(widget: CardWidget) -> Dictionary:
	var xform: Transform2D = widget.get_global_transform_with_canvas()
	var origin: Vector2 = xform.origin
	var corner: Vector2 = xform * widget.size
	return {
		"size": [widget.size.x, widget.size.y],
		"scale": [xform.get_scale().x, xform.get_scale().y],
		"rotation": xform.get_rotation(),
		"origin": [origin.x, origin.y],
		"corner": [corner.x, corner.y],
		"modulate_a": widget.modulate.a,
		"self_modulate_a": widget.self_modulate.a,
		"rules_font_size": widget.call("_rules_text_font_size"),
		"rules_text_width": widget.call("_rules_text_width"),
		"summary_icon_size": widget.call("_summary_icon_size"),
	}

func _screen_rect(control: Control) -> Array:
	if control == null:
		return []
	var xform: Transform2D = control.get_global_transform_with_canvas()
	var a: Vector2 = xform.origin
	var b: Vector2 = xform * control.size
	return [a.x, a.y, b.x, b.y]

func _child_rects(control: Control) -> Array:
	var result: Array = []
	if control == null:
		return result
	for child: Node in control.get_children():
		if child is Control and (child as Control).visible:
			result.append(_screen_rect(child as Control))
	return result

func _load_combat(instance: Node, hand: Array) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = {
		"name": "Cinder Crossing",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [
			{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 14, "max_hp": 14, "block": 0},
			{"id": 2, "type": "crawler", "pos": Vector2i(3, 2), "hp": 14, "max_hp": 14, "block": 0},
			{"id": 3, "type": "crawler", "pos": Vector2i(5, 3), "hp": 14, "max_hp": 14, "block": 0},
		],
		"traps": [],
		"terrain": [],
		"loot": [],
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(73101, layout, {
		"hp": 24, "max_hp": 24, "deck_cards": hand.duplicate(), "relics": [], "hand_size": hand.size(), "heal_bonus": 0,
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["traps"] = []
	combat_state["terrain"] = []
	combat_state["log"] = []
	# Each card's precondition in reach: Rubble beside enemy 1, enemy 2 on Ice,
	# a three-tile Electrified network beside enemy 3.
	BoardSurfaceRules.place(combat_state, Vector2i(3, 5), "rubble")
	BoardSurfaceRules.place(combat_state, Vector2i(3, 2), "ice")
	for tile: Vector2i in [Vector2i(4, 5), Vector2i(5, 5), Vector2i(5, 4)]:
		BoardSurfaceRules.place(combat_state, tile, "electrified")
	var progression: Dictionary = ProgressionStore.default_data()
	var tutorial_states: Dictionary = {}
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		tutorial_states[prompt_id] = ContextualCombatTutorial.STATUS_COMPLETED
	progression[ContextualCombatTutorial.PROGRESSION_KEY] = tutorial_states
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	run_state["progression"] = progression
	run_state["notice"] = ""
	instance.call("_load_run_state", run_state)
	instance.set("_animation_lock", false)
	await _settle()
	await create_timer(0.8).timeout
	await _settle()
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _shoot(shot: String) -> void:
	RenderingServer.force_draw(true, 0.0)
	await process_frame
	await create_timer(0.3).timeout
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("no frame for %s" % shot)
		_failed = true
		return
	if image.get_size() != RESOLUTION:
		push_error("%s frame is %s, expected %s" % [shot, image.get_size(), RESOLUTION])
		_failed = true
	image.save_png("%s/%s.png" % [_out, shot])
	print("SHOT %s" % shot)

func _find_widget(node: Node, card_id: String) -> CardWidget:
	if node == null:
		return null
	if node is CardWidget and (node as CardWidget).card_id == card_id and (node as CardWidget).is_visible_in_tree():
		return node as CardWidget
	for child: Node in node.get_children():
		var found: CardWidget = _find_widget(child, card_id)
		if found != null:
			return found
	return null

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	await process_frame
