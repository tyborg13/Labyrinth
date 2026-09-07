extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Widget = preload("res://scenes/card_widget.tscn")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const OUTPUT := "user://probes/surface_feedback_ui"
const CARD_IDS: Array = ["wildfire_halo", "firebrand_volley", "static_lash", "storm_relay", "storm_beacon", "polar_guard"]
var view: SubViewport
var scene: Node
var failures: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	Progression.set_storage_path("user://surface_feedback_ui_progression.json")
	Progression.set_run_storage_path("user://surface_feedback_ui_run.save")
	Progression.clear_saved_run()
	Settings.set_storage_path("user://surface_feedback_ui_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	if _capture_requested(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_2d = Viewport.MSAA_4X
	root.add_child(view)
	_test_patterns()
	await _test_cards()
	await _test_all_condition_cards()
	await _test_shale_intent()
	await _test_drag()
	for failure: String in failures: push_error(failure)
	print("SURFACE FEEDBACK UI TEST RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	if _capture_requested(): print(ProjectSettings.globalize_path(OUTPUT))
	view.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_patterns() -> void:
	_expect(str(Icons.surface_condition_token({"surface": "fire", "subject": "consumed"}).get("suffix")) == "consumed:", "Fire fuel condition names consumption")
	_expect(str(Icons.surface_condition_token({"surface": "electrified", "subject": "conducted"}).get("suffix")) == "used:", "Reusable conductor condition names use, not consumption")
	var halo: Dictionary = Data.card_def("wildfire_halo")
	_expect(_pattern_count(Icons.rows_for_actions(halo.get("actions", []))) == 1, "Wildfire Halo shares one target pattern")
	var cross: Array = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]
	var actions: Array = [{"type": "aoe", "damage": 2, "range": 4, "pattern": cross}, {"type": "detonate", "damage": 8, "range": 4, "pattern": cross, "reuse_previous_target": true}]
	_expect(_pattern_count(Icons.rows_for_actions(actions)) == 1, "Equivalent shared-target followups share geometry")
	actions[1]["pattern"] = [[0, 0], [1, 0]]
	_expect(_pattern_count(Icons.rows_for_actions(actions)) == 2, "Different followup geometry remains visible")
	actions[1]["pattern"] = cross
	actions[1]["reuse_previous_target"] = false
	_expect(_pattern_count(Icons.rows_for_actions(actions)) == 2, "Independent target choices retain their own pattern")
	var surface_action: Dictionary = {"type": "aoe", "damage": 2, "range": 3, "pattern": cross, "surface": "rubble", "surface_pattern": cross}
	_expect(_pattern_count([Icons.tokens_for_action(surface_action)]) == 1, "Equal attack and surface footprints show one pattern")
	surface_action["surface_pattern"] = [[0, 0], [0, 1]]
	_expect(_pattern_count([Icons.tokens_for_action(surface_action)]) == 2, "Different surface footprint retains its pattern")

func _test_cards() -> void:
	var canvas := Control.new()
	canvas.size = Vector2(1920, 1080)
	view.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("30251e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	for index: int in range(CARD_IDS.size()):
		var id: String = CARD_IDS[index]
		var card: Dictionary = Data.card_def(id)
		_expect(not card.is_empty(), "Actual card fixture exists: %s" % id)
		var widget: Control = Widget.instantiate()
		widget.custom_minimum_size = Vector2(240, 336)
		widget.size = Vector2(240, 336)
		var slot := Control.new()
		slot.position = Vector2(155 + index * 263, 75)
		slot.size = widget.size
		canvas.add_child(slot)
		slot.add_child(widget)
		widget.call("configure", id, false, false, true, false, false, true, card)
		if id in ["firebrand_volley", "storm_beacon"]:
			var tokens: Array = Icons.tokens_for_action((card.get("actions", []) as Array)[0])
			var segments: Array = widget.call("_summary_token_segments", tokens)
			_expect(segments.size() == 2, "Ground-and-Light attacks use two compact rows")
			_expect(str(segments[0].back().get("icon", "")).begins_with("surface_"), "The created surface stays with the attack")
			_expect(segments[1].size() == 2 and str(segments[1][0].get("icon", "")) == "illuminate" and str(segments[1][1].get("icon", "")) == "time", "Light radius and duration stay together")
		await _settle()
		_expect(widget.size.is_equal_approx(Vector2(240, 336)), "Card keeps its authored size: %s" % id)
		var summary: Control = widget.get("_summary_icon_box") as Control
		_expect(widget.get_global_rect().grow(1).encloses(summary.get_global_rect()), "Summary stays within actual card: %s" % id)
		for descendant: Node in summary.find_children("*", "PanelContainer", true, false):
			_expect(false, "Surface condition must not restore the old colored panel: %s" % id)
		_check_summary_bounds(summary, _parchment_bounds(widget), id)
	for index: int in range(6):
		var key: String = ["surface_fire", "surface_ice", "surface_electrified", "surface_rubble", "chilled", "detonate"][index]
		var tooltip: Control = Tooltip.make_text(Icons.tooltip(key))
		tooltip.position = Vector2(155 + (index % 3) * 530, 480 + (index / 3) * 190)
		canvas.add_child(tooltip)
	await _settle()
	await _capture("cards_and_tooltips.png")
	canvas.queue_free()
	await process_frame

func _test_all_condition_cards() -> void:
	var canvas := Control.new()
	canvas.size = Vector2(1920, 1080)
	view.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("30251e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var ids: Array = ["static_lash", "storm_relay", "thunderline", "thorn_skewer", "spike_mantle", "tectonic_maul", "polar_guard", "worldroot_stride", "storm_jar"]
	for index: int in range(ids.size()):
		var widget: Control = Widget.instantiate()
		widget.custom_minimum_size = Vector2(220, 308)
		widget.size = Vector2(220, 308)
		var slot := Control.new()
		slot.position = Vector2(260 + (index % 5) * 278, 130 + (index / 5) * 450)
		slot.size = widget.size
		canvas.add_child(slot)
		slot.add_child(widget)
		widget.call("configure", ids[index], false, false, true, false, false, true, Data.card_def(ids[index]))
		await _settle()
		_expect(widget.size.is_equal_approx(Vector2(220, 308)), "Conditional card does not grow to fit text: %s" % ids[index])
		_check_summary_bounds(widget.get("_summary_icon_box") as Node, _parchment_bounds(widget), ids[index])
	await _capture("conditional_cards.png")
	canvas.queue_free()
	await process_frame

func _test_shale_intent() -> void:
	var combat := preload("res://scripts/combat_engine.gd").new()
	var state: Dictionary = preload("res://tests/suites/chain_attack_suite.gd").fixture(combat)
	var definition: Dictionary = Data.enemy_def("bile_bloomer")
	var enemy: Dictionary = (state["enemies"][0] as Dictionary).duplicate(true)
	enemy["type"] = "bile_bloomer"
	enemy["intent"] = definition["intents"][0].duplicate(true)
	enemy["hp"] = definition["max_hp"]
	enemy["max_hp"] = definition["max_hp"]
	enemy["pos"] = Vector2i(5, 4)
	state["enemies"] = [enemy]
	var board := preload("res://scripts/combat_board_view.gd").new()
	board.size = Vector2(1920, 1080)
	view.add_child(board)
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"show_all_enemy_intents": true})
	_expect(_pattern_count(board.call("_intent_rows_for_unit", enemy, enemy["intent"])) == 1, "Actual Shale Burst intent shows one shared damage-and-Rubble pattern")
	await _settle()
	await _capture("shale_burst_intent.png")
	board.queue_free()
	await process_frame

func _test_drag() -> void:
	scene = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(scene)
	await _settle()
	_expect(bool(scene.call("_shortcut_move_bleed_is_survivable", {"player": {"hp": 5, "bleed": 3, "freeze": 1, "chilled": true}})), "Movement shortcut does not multiply passive Bleed by Frozen or Chilled")
	_expect(not bool(scene.call("_shortcut_move_bleed_is_survivable", {"player": {"hp": 3, "bleed": 3}})), "Movement shortcut still rejects lethal Bleed")
	var state: Dictionary = Run.new().create_new_run(9142, Progression.default_data())
	state["mode"] = "room"
	state["equipment_inventory"] = ["duelist_rapier"]
	state["magic_inventory"] = ["firebrand_volley"]
	state["item_inventory"] = ["grave_dust_satchel", "mossglass_elixir", "bone_ward_charm"]
	state["equipped_items"] = ["crimson_draught"]
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	scene.call("_open_character_overlay", "equipment")
	await _settle()
	await _capture("inventory_before_drag.png")
	var tile: Control = (scene.get("_item_inventory_tiles") as Dictionary)[0] as Control
	var before_cancel: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	var source: Rect2 = tile.get_global_rect()
	scene.call("_begin_item_overlay_drag", "inventory", 0, "grave_dust_satchel", source, tile, Vector2(1080, 540))
	for frame: int in range(12):
		await process_frame
		var proxy: Control = scene.get("_item_held_proxy") as Control
		_expect(proxy.size.is_equal_approx(source.size), "Held item keeps source bounds on frame %d" % frame)
	await _capture("item_drag_compact.png")
	await scene.call("_cancel_item_overlay_drag", true)
	_expect(str(scene.get("_item_drag_card_id")).is_empty(), "Animated cancel clears held item")
	_expect(tile.modulate == Color.WHITE, "Cancel restores source opacity")
	_expect(scene.get("_run_state") == before_cancel, "Cancel does not equip or consume the item")
	scene.call("_begin_item_overlay_drag", "inventory", 0, "grave_dust_satchel", source, tile, source.get_center())
	var destination: Control = (scene.get("_item_equipped_tiles") as Dictionary)[1] as Control
	await scene.call("_release_item_overlay_drag", destination.get_global_rect().get_center())
	await _settle()
	_expect(((scene.get("_run_state") as Dictionary).get("equipped_items", []) as Array).has("grave_dust_satchel"), "Drag to empty slot equips the item")
	_expect(str(scene.get("_item_drag_card_id")).is_empty(), "Successful drop clears held item")
	await _capture("item_after_drop.png")
	var gear: Control = (scene.get("_equipment_inventory_tiles") as Dictionary)["duelist_rapier"] as Control
	var gear_rect: Rect2 = scene.call("_equipment_inventory_icon_rect", "duelist_rapier")
	scene.call("_begin_equipment_overlay_drag", "duelist_rapier", gear_rect, gear, Vector2(1080, 540))
	await _settle()
	_expect((scene.get("_equipment_held_proxy") as Control).size == Vector2(78, 78), "Equipment icon drag stays compact")
	await _capture("equipment_drag_compact.png")
	await scene.call("_cancel_equipment_overlay_drag", false)
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	gear.call("_gui_input", accept)
	await create_timer(0.5).timeout
	await _settle()
	_expect(str(((scene.get("_run_state") as Dictionary).get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "duelist_rapier", "Controller accept still equips gear")
	await _capture("equipment_after_accept.png")
	var resize_proxy: Control = scene.call("_build_item_card_proxy_panel", "grave_dust_satchel", Vector2(336, 68))
	var fx: Control = scene.get("_equipment_fx_layer") as Control
	fx.add_child(resize_proxy)
	await _settle()
	await scene.call("_animate_magic_proxy_to_rect", resize_proxy, Rect2(fx.global_position + Vector2(600, 400), Vector2(300, 64)), 0.1)
	_expect(resize_proxy.size.is_equal_approx(Vector2(300, 64)), "Shared proxy animation reaches smaller slot bounds")
	resize_proxy.queue_free()
	scene.call("_open_character_overlay", "magic")
	await _settle()
	var magic: Control = (scene.get("_magic_inventory_tiles") as Dictionary)[0] as Control
	var magic_rect: Rect2 = magic.get_global_rect()
	scene.call("_begin_magic_overlay_drag", "inventory", 0, "firebrand_volley", magic_rect, magic, Vector2(1080, 540))
	await _settle()
	_expect((scene.get("_magic_held_proxy") as Control).size.is_equal_approx(magic_rect.size), "Shared magic proxy stays within source bounds")
	await _capture("magic_drag_compact.png")
	await scene.call("_cancel_magic_overlay_drag", true)
	_expect(magic.modulate == Color.WHITE and str(scene.get("_magic_drag_card_id")).is_empty(), "Magic drag cancel restores the source")
	scene.call("_begin_magic_overlay_drag", "inventory", 0, "firebrand_volley", magic_rect, magic, magic_rect.get_center())
	var magic_destination: Control = (scene.get("_magic_attuned_tiles") as Dictionary)[0] as Control
	await scene.call("_release_magic_overlay_drag", magic_destination.get_global_rect().get_center())
	await _settle()
	_expect(((scene.get("_run_state") as Dictionary).get("attuned_magic_cards", []) as Array).has("firebrand_volley"), "Shared magic proxy still drops into attunement")
	await _capture("magic_after_drop.png")
	scene.queue_free()
	await process_frame

func _check_summary_bounds(node: Node, bounds: Rect2, id: String) -> void:
	if node is Control and node.get_child_count() == 0:
		_expect(bounds.grow(1).encloses((node as Control).get_global_rect()), "Every summary glyph fits the parchment of %s (%s)" % [id, node.name])
	for child: Node in node.get_children(): _check_summary_bounds(child, bounds, id)

func _parchment_bounds(widget: Control) -> Rect2:
	var bounds: Rect2 = widget.get_global_rect()
	var inset: float = 34.0 * minf(widget.size.x / 250.0, widget.size.y / 352.0)
	return Rect2(bounds.position + Vector2(inset, 0.0), bounds.size - Vector2(inset * 2.0, 0.0))

func _pattern_count(rows: Array) -> int:
	var total: int = 0
	for row: Array in rows:
		for token: Dictionary in row:
			if str(token.get("kind", "")) == "aoe_pattern": total += 1
	return total

func _settle() -> void:
	for frame: int in range(8): await process_frame

func _capture(filename: String) -> void:
	if not _capture_requested(): return
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	_expect(image.save_png("%s/%s" % [OUTPUT, filename]) == OK, "Native screenshot saves")

func _expect(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _capture_requested() -> bool:
	return false
