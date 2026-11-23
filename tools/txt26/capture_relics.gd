extends SceneTree
## TXT-23 label measurement through the real treasure-room offer builder.

const Data = preload("res://scripts/game_data.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Previews = preload("res://scripts/item_preview_builders.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const TooltipStack = preload("res://scripts/card_focus_tooltip_stack.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const PROFILE = preload("res://scripts/contextual_combat_tutorial.gd")
const EDITS_PATH := "res://spec/peer_benchmark/staged/txt-26/text_edits.json"
const EDITED: Array = [
	"iron_lung", "worldheart", "overflow_censer", "crowncoal_heart", "waxen_effigy",
	"hollow_puppet", "mirror_shard", "frost_prism", "cold_mirror", "rimecatcher_vial",
	"funeral_bell", "battering_yoke", "breaking_wheel", "hollow_die", "worldroot_idol", "fivefold_knot",
]
const OFFER_COUNT := 3
const DIRECTOR_IDS: Array = ["worldheart", "crowncoal_heart", "iron_lung", "hollow_puppet", "overflow_censer", "waxen_effigy"]
const RESOLUTIONS: Array = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const UI_SCALE := 1.0
const FIXTURE_SEED := 7321
const LAYOUT_FRAMES := 3
const REVEAL_TIMEOUT_MS := 4000
const GEOMETRY_TOLERANCE := 0.5
const RAW_MARKUP := "@(?:kw|term|icon|pattern)\\(|\\{[0-9][^}]*\\}|\\[/?(?:img|url|color|font)[^\\]]*\\]"
const OUTPUT := "user://txt26_text_fit.json"

var _scene: Control
var _viewport: SubViewport
var _bar: HBoxContainer
var _stack: TooltipStack
var _state: Dictionary
var _visual: bool
var _failed := false
var _layouts: Array[Dictionary]
var _surfaces: Dictionary = {}


func _initialize() -> void:
	_collect.call_deferred()


func _collect() -> void:
	Runtime.apply_from_environment()
	_visual = OS.get_environment("TXT26_CAPTURE") == "1"
	if _visual and DisplayServer.get_name() == "headless":
		_fail("PNG capture requires a windowed renderer")
		quit(1)
		return
	Settings.set_storage_path("user://txt26_settings.json")
	Progression.set_storage_path("user://txt26_progression.json")
	Progression.set_run_storage_path("user://txt26_run.save")
	var profile: Dictionary = PROFILE.complete_tutorial(Progression.default_data())
	Progression.save_data(profile)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.set_meta("labyrinth_resume_saved_run", true)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")

	_viewport = SubViewport.new()
	_viewport.size = RESOLUTIONS[0]
	_viewport.msaa_2d = get_root().msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _visual else SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)
	_scene = RUN_SCENE.instantiate() as Control
	_viewport.add_child(_scene)
	await _settle()
	_bar = _scene.get("_relic_choice_bar") as HBoxContainer
	_stack = _scene.get("_card_focus_tooltip_stack") as TooltipStack
	_state = _treasure_state(profile)
	if _state.is_empty():
		_fail("Treasure fixture lacks a treasure room")
		quit(1)
		return
	var before: bool = OS.get_environment("TXT26_PHASE") == "before"
	var director: bool = OS.get_environment("TXT26_BATCH") == "director"
	var ids: Array = DIRECTOR_IDS if director else EDITED
	if not before:
		_check_director_text()
	for physical: Vector2i in RESOLUTIONS:
		if before and physical != RESOLUTIONS[0]:
			continue
		_viewport.size = physical
		await _settle()
		for start: int in range(0, ids.size(), OFFER_COUNT):
			var batch: Array = ids.slice(start, start + OFFER_COUNT)
			if batch.size() < OFFER_COUNT:
				batch.append_array(ids.slice(0, OFFER_COUNT - batch.size()))
			await _show_room(batch)
			_measure_offers(batch, physical)
			if _visual:
				await _capture(physical, batch, int(start / OFFER_COUNT) + 1)
	if not before and not director:
		await _check_other_surfaces()
	_write_measurements()
	print("TXT26 text fit %s: %d offer layouts, %d checked relic surface sets" % [
		"FAIL" if _failed else "PASS", _layouts.size(), _surfaces.size(),
	])
	quit(int(_failed))


func _treasure_state(profile: Dictionary) -> Dictionary:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, profile)
	for key: String in state["rooms"]:
		var room: Dictionary = state["rooms"][key]
		if str(room.get("type", "")) != "treasure":
			continue
		var parts: PackedStringArray = key.split(",")
		var coord := Vector2i(int(parts[0]), int(parts[1]))
		room["revealed"] = true
		room["visited"] = true
		state["current_room"] = coord
		state["current_room_layout"] = engine.call("_display_layout_for_room", FIXTURE_SEED, room, Vector2i(1, 0))
		state["mode"] = "treasure"
		state["combat_state"] = {}
		state["pending_reward"] = {}
		return state
	return {}


func _show_room(batch: Array) -> void:
	var treasure: Dictionary = _state.duplicate(true)
	treasure["pending_relics"] = batch.duplicate()
	_scene.call("_load_run_state", treasure)
	_scene.call("_close_dialogue")
	_scene.call("_close_large_map")
	var start: int = Time.get_ticks_msec()
	while bool(_scene.get("_treasure_reveal_active")) and Time.get_ticks_msec() - start < REVEAL_TIMEOUT_MS:
		await process_frame
	if bool(_scene.get("_treasure_reveal_active")):
		_fail("Treasure room reveal did not settle")
	if batch.any(func(id: String) -> bool: return Data.resolve_relic_id(id) != id):
		# Retired Open-Eyed Pin is correctly migrated on load. Its historical
		# description still goes through the live builder for this fit check.
		_scene.call("_clear_children_now", _bar)
		for id: String in batch:
			_scene.call("_add_relic_choice", id, _authored_definition(id))
		_scene.call("_layout_relic_choice_overlay")
	await _settle()


func _measure_offers(batch: Array, size: Vector2i) -> void:
	if _bar.get_child_count() != batch.size():
		_fail("Treasure room did not show all offers: " + str(batch))
	for id: String in batch:
		var desc := _bar.find_child("RelicChoiceDescription_%s" % id, true, false) as RichTextLabel
		if desc == null:
			_fail("Missing treasure offer: " + id)
			continue
		var panel: Control = desc
		while panel.get_parent() != _bar:
			panel = panel.get_parent() as Control
		var label_rect: Rect2 = desc.get_global_rect()
		var content := Vector2(desc.get_content_width(), desc.get_content_height())
		var overflow: bool = (
			not desc.is_visible_in_tree()
			or content.x > desc.size.x + GEOMETRY_TOLERANCE
			or content.y > desc.size.y + GEOMETRY_TOLERANCE
			or not panel.get_global_rect().grow(GEOMETRY_TOLERANCE).encloses(label_rect)
			or not _viewport.get_visible_rect().grow(GEOMETRY_TOLERANCE).encloses(label_rect)
		)
		if overflow:
			_fail("Overflow for %s at %s: %s in %s" % [id, size, content, desc.size])
		_check_rules(id, "treasure", desc)
		_layouts.append({"id": id, "width": size.x, "height": size.y, "height_used": content.y, "height_available": desc.size.y, "overflow": overflow, "text": desc.get_parsed_text()})


func _check_director_text() -> void:
	var edits: Variant = JSON.parse_string(FileAccess.get_file_as_string(EDITS_PATH))
	if not edits is Array or edits.size() != EDITED.size():
		_fail("Missing director text edits")
		return
	for edit: Dictionary in edits:
		var id: String = edit["id"]
		var authored: String = Data.relics()[id]["description"]
		if not EDITED.has(id) or not authored.contains(str(edit["new"])) or authored.contains(str(edit["old"])):
			_fail("Relic catalog differs from director copy: " + id)


func _check_other_surfaces() -> void:
	for id: String in EDITED:
		var checks: Dictionary = {}
		var owned: Dictionary = _state.duplicate(true)
		owned["relics"] = [id]
		_scene.set("_run_state", owned)
		_scene.set("_combat_state", {})
		_scene.call("_refresh_relic_bar")
		var tray := _scene.get("_relic_icon_grid") as GridContainer
		for owner: Control in tray.get_children():
			if owner.get_meta("relic_id", "") != id:
				continue
			_stack.show_relic(owner, owner.get_meta("glossary_relic"))
			var tooltip := _stack.find_child("CardFocusTooltip_00_Relic", true, false) as PanelContainer
			checks["hud"] = _check_rules(Data.resolve_relic_id(id), "HUD", _panel_body(tooltip), id == "fivefold_knot")
			_stack.hide_stack(true)
			break
		if Data.resolve_relic_id(id) != id:
			var history_owner := TooltipStack.RelicOwner.new()
			_scene.add_child(history_owner)
			_stack.show_relic(history_owner, _authored_definition(id))
			var historical := _stack.find_child("CardFocusTooltip_00_Relic", true, false) as PanelContainer
			checks["historical_hud"] = _check_rules(id, "historical HUD", _panel_body(historical))
			_stack.hide_stack(true)
			history_owner.queue_free()
		elif not checks.has("hud"):
			_fail("Missing HUD badge: " + id)
		var chronicle: Control = Previews.relic_tooltip(id) if Data.resolve_relic_id(id) == id else Previews.text_tooltip("%s\n%s" % [_authored_definition(id)["name"], _authored_definition(id)["description"]], id)
		checks["chronicle"] = _check_rules(id, "Chronicle", _panel_body(chronicle))
		chronicle.free()
		var boss_id: String = str(Data.relic_def(id).get("exclusive_boss", ""))
		if not boss_id.is_empty():
			owned["mode"] = "reward"
			owned["pending_reward"] = {"relic_id": id, "boss_id": boss_id}
			_scene.set("_run_state", owned)
			_scene.call("_clear_children_now", _bar)
			_scene.call("_add_dragon_reward_stack")
			checks["dragon_reward"] = _check_rules(id, "dragon reward", _bar.find_child("DragonRewardRules", true, false) as RichTextLabel)
		_surfaces[id] = checks
		await process_frame
	for key: String in Grimoire.entry_map():
		if key.begins_with("relic:"):
			_fail("Grimoire has a relic article requiring copy verification: " + key)


func _check_rules(id: String, surface: String, body: Control, allows_detail: bool = false) -> String:
	if body == null:
		_fail("Missing %s rules for %s" % [surface, id])
		return ""
	# TXT-23's extraction compares parsed text after the real icon renderer.
	var expected := RichTextLabel.new()
	Inline.apply_to(expected, str(_authored_definition(id)["description"]))
	var reading: String = body.get_parsed_text() if body is RichTextLabel else body.text
	var canonical: String = expected.get_parsed_text()
	if (reading != canonical and not (allows_detail and reading.begins_with(canonical))) or RegEx.create_from_string(RAW_MARKUP).search(reading) != null:
		_fail("%s rules for %s differ or leak markup: %s" % [surface, id, reading])
	expected.free()
	return reading


func _authored_definition(id: String) -> Dictionary:
	if Data.resolve_relic_id(id) == id:
		return Data.relic_def(id)
	var original: Dictionary = (Data.relics()[id] as Dictionary).duplicate(true)
	original["description"] = Data._format_relic_description(original)
	return original


func _panel_body(panel: Control) -> Control:
	return panel.get_child(0).get_child(1) as Control if panel != null else null


func _settle() -> void:
	for _frame: int in LAYOUT_FRAMES:
		await process_frame


func _capture(size: Vector2i, batch: Array, index: int) -> void:
	await RenderingServer.frame_post_draw
	var name: String = "%02d_%dx%d_%s.png" % [index, size.x, size.y, "_".join(batch)]
	var path: String = OS.get_environment("TXT26_OUTPUT").path_join(name)
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != size or image.save_png(path) != OK:
		_fail("Could not save exact-size image: " + path)
	else:
		print(path)


func _write_measurements() -> void:
	var path: String = OUTPUT
	var directory: String = OS.get_environment("TXT26_OUTPUT")
	if not directory.is_empty():
		path = directory.path_join("text_fit.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write " + path)
	else:
		file.store_string(JSON.stringify({"ui_scale": UI_SCALE, "offers": _layouts, "surfaces": _surfaces}, "  ") + "\n")
		print("TXT26_CAPTURE_JSON=" + ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
