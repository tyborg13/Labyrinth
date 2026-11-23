extends SceneTree
## Read-only UI extraction. The standard task runner isolates all user:// state.

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

const RESOLUTIONS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const UI_SCALE := 1.0
const FIXTURE_SEED := 321
const OFFER_COUNT := 3
const LAYOUT_FRAMES := 3
const GEOMETRY_TOLERANCE := 0.5
const OUTPUT := "user://txt23_capture.json"
const BINDING_SYNTAX := "\\{([^{}]+)\\}"
const CAPTURE_IDS := ["iron_lung", "ember_lens", "pilgrim_boots"]

var _scene: Control
var _viewport: SubViewport
var _bar: HBoxContainer
var _stack: TooltipStack
var _state: Dictionary
var _failed := false

func _initialize() -> void:
	_collect.call_deferred()

func _collect() -> void:
	Runtime.apply_from_environment()
	Settings.set_storage_path("user://txt23_settings.json")
	Progression.set_storage_path("user://txt23_progression.json")
	Progression.set_run_storage_path("user://txt23_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	var visual: bool = "--capture" in OS.get_cmdline_user_args()
	if visual:
		if DisplayServer.get_name() == "headless":
			_fail("PNG capture requires a windowed renderer")
			quit(1)
			return
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(RESOLUTIONS[0])
	Settings.apply_settings(settings, root, false)
	_viewport = SubViewport.new()
	_viewport.size = RESOLUTIONS[0]
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visual else SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)
	_scene = RUN_SCENE.instantiate() as Control
	# Headless label measurements do not need a loaded combat board or its FX.
	if not visual:
		root.set_meta("labyrinth_resume_saved_run", true)
	_viewport.add_child(_scene)
	await _settle()
	_state = Run.new().create_new_run(FIXTURE_SEED, Progression.default_data())
	if visual:
		_scene.call("_load_run_state", _state)
	_scene.call("_close_dialogue")
	_state["mode"] = "treasure"
	_scene.set("_run_state", _state)
	_bar = _scene.get("_relic_choice_bar") as HBoxContainer
	_stack = _scene.get("_card_focus_tooltip_stack") as TooltipStack
	(_scene.get("_relic_choice_overlay") as Control).show()
	(_scene.get("_relic_choice_host") as Control).show()
	_bar.show()
	_scene.call("_set_relic_choice_title", _scene.RELIC_CHOICE_TITLE_TEXT)
	_clear_offers()
	if visual:
		await _capture_png()
		quit(int(_failed))
		return

	var catalog: Dictionary = Data.relics()
	var shop_kinds: Dictionary = {}
	var engine := Run.new()
	var ids: Array = catalog.keys()
	var rows: Dictionary = {}
	var markup: Dictionary = {}
	var diagrams: Dictionary = {}
	var binding_syntax := RegEx.create_from_string(BINDING_SYNTAX)
	for id: String in ids:
		shop_kinds[id] = engine.merchant_item_kind(id)
		var original: Dictionary = (catalog[id] as Dictionary).duplicate(true)
		var formatted: String = Data._format_relic_description(original)
		var rewrite: String = Inline.Patterns.display_rules(formatted)
		for token: RegExMatch in Inline._tokens(rewrite):
			var spelling: String = token.get_string()
			if markup.has(spelling): continue
			var label := RichTextLabel.new()
			Inline.apply_to(label, spelling)
			var rendered: Dictionary = _rich(label)
			rendered["glossary_name"] = Inline.Glossary.name_for(token.get_string(2))
			rendered["icon_alt"] = Inline.ActionIcons.label(token.get_string(2)) if not rendered["icons"].is_empty() else ""
			markup[spelling] = rendered
			label.free()
		for token: RegExMatch in Inline.Patterns.matches(rewrite):
			var spelling: String = token.get_string()
			if diagrams.has(spelling): continue
			var label := RichTextLabel.new()
			Inline.apply_to(label, spelling)
			var diagram: Dictionary = _rich(label)
			var offsets: Array = []
			for tile: Vector2i in Inline.Patterns.offsets(token.get_string(1), int(token.get_string(2))):
				offsets.append([tile.x, tile.y])
			diagram["offsets"] = offsets
			diagram["origin_marker"] = token.get_string(3)
			diagrams[spelling] = diagram
			label.free()
		var values: Dictionary = Data._relic_description_values(original)
		var bindings: Dictionary = {}
		for token: RegExMatch in binding_syntax.search_all(str(original["description"])):
			var key: String = token.get_string(1)
			if values.has(key): bindings[token.get_string()] = str(values[key])
		rows[id] = {
			"resolved_id": Data.resolve_relic_id(id), "formatted_original": formatted,
			"pattern_rewrite": rewrite, "bindings": bindings, "layouts": {}, "historical_layouts": {},
		}
	for physical: Vector2i in RESOLUTIONS:
		_viewport.size = physical
		await _settle()
		for start: int in range(0, ids.size(), OFFER_COUNT):
			_clear_offers()
			for id: String in ids.slice(start, start + OFFER_COUNT):
				_scene.call("_add_relic_choice", id, Data.relic_def(id))
			_scene.call("_layout_relic_choice_overlay")
			await _settle()
			for panel: Control in _bar.get_children():
				var id: String = str(panel.get_meta("relic_id"))
				var desc := panel.find_child("RelicChoiceDescription_%s" % id, true, false) as RichTextLabel
				if desc == null:
					_fail("Missing live offer label for " + id)
					continue
				var reading: Dictionary = _rich(desc)
				if rows[id].has("treasure") and rows[id]["treasure"] != reading:
					_fail("Offer text differs by viewport for " + id)
				rows[id]["treasure"] = reading
				rows[id]["layouts"]["%dx%d" % [physical.x, physical.y]] = _measure(panel, desc)
		var historical: Array = ids.filter(func(id: String) -> bool: return id != rows[id]["resolved_id"])
		for start: int in range(0, historical.size(), OFFER_COUNT):
			_clear_offers()
			for id: String in historical.slice(start, start + OFFER_COUNT):
				var original: Dictionary = (catalog[id] as Dictionary).duplicate(true)
				original["description"] = rows[id]["formatted_original"]
				_scene.call("_add_relic_choice", id, original)
			_scene.call("_layout_relic_choice_overlay")
			await _settle()
			for panel: Control in _bar.get_children():
				var id: String = str(panel.get_meta("relic_id"))
				var desc := panel.find_child("RelicChoiceDescription_%s" % id, true, false) as RichTextLabel
				if desc == null:
					_fail("Missing archival offer label for " + id)
					continue
				rows[id]["historical_treasure"] = _rich(desc)
				rows[id]["historical_layouts"]["%dx%d" % [physical.x, physical.y]] = _measure(panel, desc)
	_clear_offers()
	_viewport.size = RESOLUTIONS[0]
	await _settle()
	for id: String in ids:
		rows[id]["hud"] = await _hud(Data.resolve_relic_id(id), {})
		var chronicle: Control = Previews.relic_tooltip(id)
		rows[id]["chronicle"] = _panel_body(chronicle)
		chronicle.free()
		if id != rows[id]["resolved_id"]:
			# Exercise the old definition through the same two builders for historical copy.
			var original: Dictionary = (catalog[id] as Dictionary).duplicate(true)
			original["description"] = rows[id]["formatted_original"]
			var owner := TooltipStack.RelicOwner.new()
			_scene.add_child(owner)
			_stack.show_relic(owner, original)
			rows[id]["historical_hud"] = _hud_body()
			_stack.hide_stack(true)
			owner.queue_free()

	for id: String in ["borrowed_hourglass", "winters_hour", "fivefold_knot"]:
		rows[id]["hud_variants"] = {}
	for label: String in ["used", "stored", "three_knots", "four_knots", "five_knots"]:
		var id: String = "fivefold_knot"
		var combat: Dictionary = {}
		if label == "used":
			id = "borrowed_hourglass"
			var effects: Array[Dictionary] = Data.relic_effects_for_ids([id])
			combat = {"relic_flags": {"tempo_used:" + str(effects[0]["relic_id"]): true}}
		elif label == "stored":
			id = "winters_hour"
			combat = {"relic_time_reserve": {id: 3}}
		else:
			var counts := {"three_knots": 3, "four_knots": 4, "five_knots": 5}
			var elements := ["fire", "ice", "lightning", "air", "earth"]
			combat = {"relic_element_knots": elements.slice(0, counts[label])}
		rows[id]["hud_variants"][label] = await _hud(id, combat)

	_state["mode"] = "reward"
	_scene.set("_combat_state", {})
	_scene.set("_run_state", _state)
	for id: String in ids:
		var relic: Dictionary = catalog[id]
		if not relic.has("exclusive_boss"): continue
		_state["pending_reward"] = {"relic_id": id, "boss_id": relic["exclusive_boss"]}
		_scene.call("_add_dragon_reward_stack")
		var rules := _bar.find_child("DragonRewardRules", true, false) as RichTextLabel
		if rules == null:
			_fail("Missing dragon reward rules for " + id)
		else:
			rows[id]["dragon_reward"] = _rich(rules)
		_clear_offers()

	var grimoire_ids: Array = Grimoire.entry_map().keys()
	_scene.set("_grimoire_selected_entry", "basic:relics")
	_scene.call("_refresh_grimoire_detail")
	var general := _scene.get("_grimoire_detail_body") as RichTextLabel
	var payload := {
		"relics": rows, "grimoire_entry_ids": grimoire_ids,
		"grimoire_general": _rich(general), "shop_item_kinds": shop_kinds, "ui_scale": UI_SCALE, "inline_markup": markup, "diagrams": diagrams,
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		_fail("Could not open " + OUTPUT)
	else:
		file.store_string(JSON.stringify(payload, "  ", true, true) + "\n")
		file.close()
		print("TXT23_CAPTURE_JSON=" + ProjectSettings.globalize_path(OUTPUT))
	var historical_count: int = ids.filter(func(id: String) -> bool: return id != rows[id]["resolved_id"]).size()
	print("TXT23 capture %s: %d relic IDs, %d resolved offer layouts, %d archival offer layouts, %d HUD variants" % [
		"FAIL" if _failed else "PASS", rows.size(), rows.size() * RESOLUTIONS.size(),
		historical_count * RESOLUTIONS.size(), 5,
	])
	quit(int(_failed))

func _hud(id: String, combat: Dictionary) -> Dictionary:
	_state["relics"] = [id]
	_scene.set("_run_state", _state)
	_scene.set("_combat_state", combat)
	_scene.call("_refresh_relic_bar")
	var tray := _scene.get("_relic_icon_grid") as GridContainer
	for owner: Control in tray.get_children():
		if str(owner.get_meta("relic_id", "")) != id:
			continue
		_stack.show_relic(owner, owner.get_meta("glossary_relic"))
		var body: Dictionary = _hud_body()
		_stack.hide_stack(true)
		await process_frame
		return body
	_fail("Missing owned badge for " + id)
	return {}

func _hud_body() -> Dictionary:
	var panel := _stack.find_child("CardFocusTooltip_00_Relic", true, false) as PanelContainer
	if panel == null:
		_fail("Missing HUD rules panel")
		return {}
	return _panel_body(panel)

func _panel_body(panel: Control) -> Dictionary:
	var box: Node = panel.get_child(0)
	# The title is first, the description second. Chronicle appends glossary panels.
	var body: Node = box.get_child(1)
	if body is RichTextLabel:
		return _rich(body)
	if body is Label:
		return {"text": body.text, "icons": [], "patterns": 0, "character_count": body.text.length()}
	_fail("Unknown tooltip rules node")
	return {}

func _rich(label: RichTextLabel) -> Dictionary:
	return {
		"text": label.get_parsed_text(), "icons": Array(label.get_meta("inline_icon_keys", [])),
		"patterns": int(label.get_meta("inline_pattern_count", 0)),
		"character_count": label.get_total_character_count(),
	}

func _measure(panel: Control, label: RichTextLabel) -> Dictionary:
	if not label.is_visible_in_tree():
		_fail("Offer label is hidden: " + str(label.name))
	var content := Vector2(label.get_content_width(), label.get_content_height())
	var inside: bool = panel.get_global_rect().grow(GEOMETRY_TOLERANCE).encloses(label.get_global_rect())
	var on_screen: bool = _viewport.get_visible_rect().grow(GEOMETRY_TOLERANCE).encloses(label.get_global_rect())
	return {
		"logical_viewport": [_viewport.size.x, _viewport.size.y],
		"content": [content.x, content.y], "box": [label.size.x, label.size.y],
		"lines": label.get_line_count(), "panel_contains_box": inside, "viewport_contains_box": on_screen,
		"overflow": content.x > label.size.x + GEOMETRY_TOLERANCE or content.y > label.size.y + GEOMETRY_TOLERANCE or not inside or not on_screen,
	}

func _clear_offers() -> void:
	_stack.hide_stack(true)
	_scene.call("_clear_children_now", _bar)

func _settle() -> void:
	for _frame: int in LAYOUT_FRAMES:
		await process_frame

func _capture_png() -> void:
	for id: String in CAPTURE_IDS:
		_scene.call("_add_relic_choice", id, Data.relic_def(id))
	_scene.call("_layout_relic_choice_overlay")
	await _settle()
	await RenderingServer.frame_post_draw
	var path: String = "user://probes/txt23_relic_offers_1920x1080.png"
	var absolute: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if _viewport.get_texture().get_image().save_png(absolute) != OK:
		_fail("Could not save " + path)
	else:
		print(absolute)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
