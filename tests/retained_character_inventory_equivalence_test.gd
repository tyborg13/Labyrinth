extends SceneTree
const Scene = preload("res://scripts/run_scene.gd")
const Reference = preload("res://tests/fixtures/character_inventory_reference.gd")
const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Rows = preload("res://scripts/character_inventory_rows.gd")
var errors: Array[String]
var scenes: Array[Node]
var cases: int = 0
var differences: int = 0
var preparation_state: Dictionary
var preparation_bindings: Dictionary
var preparation_mode: String
var preparation_frames: int = 0
var cancel_on_present: bool = false
var free_on_present: bool = false
var preparation_active: bool = true
var open_at_preparation_frame: int = -1
var preparation_boundary: int = 0
var preparation_opened: bool = false
var preparation_open_mode: String = "equipment"
var changed_preparation_state: Dictionary = {}
var change_state_on_present: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	Profile.set_storage_path("user://retained_character_profile.json")
	Profile.set_run_storage_path("user://retained_character_run.save")
	Profile.clear_saved_run()
	var profile: Dictionary = Tutorial.complete_tutorial(Profile.default_data())
	Profile.save_data(profile)
	Settings.set_storage_path("user://retained_character_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["fullscreen"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()

func _run() -> void:
	for original: bool in [false, true]:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		if original: scene.set_script(Reference)
		root.add_child(scene)
		scenes.append(scene)
	await _settle(8)
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(84217, Tutorial.complete_tutorial(Profile.default_data()))
	state["equipment_inventory"] = ["iron_cleaver", "duelist_rapier", "iron_cleaver"]
	state["item_inventory"] = Data.item_card_ids()
	var magic: Array = []
	var pools: Dictionary = Data.reward_card_pool_by_rarity("", true)
	for rarity: String in Data.CARD_RARITY_TIERS:
		for id: String in pools.get(rarity, []):
			if not magic.has(id): magic.append(id)
	magic.sort()
	if magic.size() > 64: magic.resize(64)
	state["magic_inventory"] = magic
	state["reward_cards"] = magic.duplicate()
	for scene: Node in scenes:
		scene._load_run_state(state.duplicate(true))
		scene._close_dialogue()
		scene._pre_battle_scrim.hide()
		scene._large_map_scrim.hide()
	state = scenes[0]._run_state.duplicate(true)
	# Capture all observable live inputs before any future context is installed.
	preparation_state = scenes[0]._run_state.duplicate(true)
	preparation_bindings = scenes[0]._character_view_bindings()
	preparation_mode = scenes[0]._progression_overlay_mode
	await Rows.prepare_current_for(scenes[0], scenes[0]._character_row_preparation_revision, _present_preparation, _preparation_alive)
	_check(scenes[0]._character_inventory_rows._views.size() == 2, "Loading must complete only bounded Gear and Magic future dialogs")
	var prepared_gear: Control = scenes[0]._character_inventory_rows._views["equipment"]["node"]
	var prepared_magic: Control = scenes[0]._character_inventory_rows._views["magic"]["node"]
	await _compare(state, "equipment", "initial duplicate gear and items")
	_check(scenes[0]._upgrade_dialog == prepared_gear, "An eligible prepared Gear dialog must become the actual visible dialog")
	await _compare(state, "magic", "prepared Magic adoption")
	_check(scenes[0]._upgrade_dialog == prepared_magic, "An eligible prepared Magic dialog must become the actual visible dialog")
	for scroll: Node in prepared_gear.find_children("*", "ScrollContainer", true, false): scroll.scroll_vertical = 1000
	await _compare(state, "equipment", "return to scrolled parked Gear")
	_check(scenes[0]._upgrade_dialog == prepared_gear, "Returning to unchanged Gear must reuse its own parked dialog")
	var panel: Control = scenes[0]._upgrade_dialog.find_child("EquipmentInventoryPanel", true, false)
	var row: Control = scenes[0]._equipment_inventory_tiles["duelist_rapier"]
	var gear_rows: Node = panel.find_child("EquipmentInventoryRows", true, false)
	_check(gear_rows.get_child_count() == 3 and gear_rows.get_child(0) != gear_rows.get_child(1), "Duplicate equipment occurrences must own distinct rows")
	state["player_hp"] = int(state["player_hp"]) - 1
	await _compare(state, "equipment", "health changes")
	_check(scenes[0]._upgrade_dialog.find_child("EquipmentInventoryPanel", true, false) == panel and scenes[0]._equipment_inventory_tiles["duelist_rapier"] == row, "Unchanged gear rows and panel must survive a health refresh")
	state = engine.equip_equipment(state, "iron_cleaver")
	await _compare(state, "equipment", "actual gear equip")
	_check(scenes[0]._equipment_inventory_tiles["duelist_rapier"] == row, "Equipping another weapon must retain the unchanged row")
	state["equipment_inventory"].reverse()
	await _compare(state, "equipment", "gear input reorder")
	state["mode"] = "combat"
	await _compare(state, "equipment", "combat locked equipment")
	state["mode"] = "room"
	await _compare(state, "equipment", "room equipment unlocked")
	state = engine._mark_loadout_unread(state, "equipment", "duelist_rapier")
	await _compare(state, "equipment", "new equipment marker")
	for scene: Node in scenes: scene._equipment_inventory_tiles["duelist_rapier"].emit_signal("mouse_entered")
	state = engine.mark_loadout_asset_seen(state, "equipment", "duelist_rapier")
	await _compare(state, "equipment", "new equipment marker seen")
	for scene: Node in scenes: scene._animation_lock = true
	await _compare(state, "equipment", "locked action")
	for scene: Node in scenes: scene._animation_lock = false
	await _compare(state, "equipment", "unlocked action")
	row = scenes[0]._equipment_inventory_tiles["duelist_rapier"]
	row.set("_left_pressed", true)
	await _compare(state, "equipment", "held pointer invalidation")
	_check(scenes[0]._equipment_inventory_tiles["duelist_rapier"] != row, "A held pointer row must be replaced by fresh interaction state")
	row = scenes[0]._equipment_inventory_tiles["duelist_rapier"]
	row.grab_focus()
	await _compare(state, "equipment", "focused rebuild")
	_check(not row.has_focus(), "A retained rebuild must release old focus like the original whole rebuild")
	var gear_definition: Dictionary = Data.equipment()["duelist_rapier"]
	var gear_name: Variant = gear_definition["name"]
	gear_definition["name"] = "Revised Rapier"
	await _compare(state, "equipment", "equipment definition change on reopen", true)
	gear_definition["name"] = gear_name
	await _compare(state, "equipment", "equipment definition restored")
	await _compare(state, "magic", "64 learned magic rows")
	var magic_panel: Control = scenes[0]._upgrade_dialog.find_child("MagicInventoryPanel", true, false)
	var unchanged_magic: Control = scenes[0]._magic_inventory_tiles[2]
	state = engine.swap_magic_card(state, 0, 0)
	await _compare(state, "magic", "actual magic swap")
	_check(scenes[0]._upgrade_dialog.find_child("MagicInventoryPanel", true, false) == magic_panel and scenes[0]._magic_inventory_tiles[2] == unchanged_magic, "Magic swap must retain its panel and untouched rows")
	state["magic_inventory"].reverse()
	await _compare(state, "magic", "magic index reorder")
	var card: Dictionary = Data.cards()[str(state["magic_inventory"][2])]
	var card_name: Variant = card["name"]
	card["name"] = "Revised active magic name"
	await _compare(state, "magic", "card definition change on reopen", true)
	card["name"] = card_name
	await _compare(state, "magic", "card definition restored")
	state["mode"] = "combat"
	await _compare(state, "magic", "combat locked magic")
	state["mode"] = "room"
	await _compare(state, "magic", "unlocked magic")
	state["magic_inventory"] = [str(magic[0]), str(magic[0])]
	state["attuned_magic_cards"] = []
	await _compare(state, "magic", "duplicate magic and empty attuned slots")
	_check(scenes[0]._magic_inventory_tiles[0] != scenes[0]._magic_inventory_tiles[1], "Duplicate magic must keep distinct indexed callbacks")
	state["equipment_inventory"] = []
	state["item_inventory"] = []
	state["equipped_items"] = []
	state["magic_inventory"] = []
	await _compare(state, "equipment", "empty gear and items")
	await _compare(state, "magic", "empty learned magic")
	root.size = Vector2i(1600, 900)
	await _compare(state, "magic", "viewport change")
	root.size = Vector2i(1920, 1080)
	await _compare(state, "equipment", "viewport restored")
	await _exercise_preparation_boundaries(state)
	await _exercise_automatic_reload(state)
	# A normal reward changes current inputs while hidden rows are suspended.
	# The operation must finish preparing that latest source, not silently stop
	# with a partially constructed obsolete view.
	for scene: Node in scenes:
		scene._upgrade_scrim.hide()
		scene._run_state["mode"] = "reward"
	_capture_preparation_inputs()
	changed_preparation_state = scenes[0]._run_state.duplicate(true)
	changed_preparation_state["mode"] = "room"
	changed_preparation_state["magic_inventory"] = ["frostbolt", "spark_dart", "frostbolt"]
	change_state_on_present = true
	preparation_boundary = 0
	await Rows.prepare_current_for(scenes[0], scenes[0]._character_row_preparation_revision, _present_preparation, _preparation_alive)
	_check(not change_state_on_present and scenes[0]._character_row_preparation_running_revision == -1, "Changed-source preparation must finish its latest hidden source")
	var changed_views: Dictionary = scenes[0]._character_inventory_rows._views.duplicate()
	_check(changed_views.size() == 2, "Retry must publish both complete views before opening either tab")
	for mode: String in ["equipment", "magic"]:
		var view: Dictionary = changed_views.get(mode, {})
		_check(not view.is_empty() and view.get("input", {}).get("state") == changed_preparation_state, "Retry must publish the latest exact state for " + mode)
		if not view.is_empty():
			var can_retain: bool = scenes[0]._character_view_can_retain(view["node"], mode)
			if not can_retain:
				var frame: Node = view["node"].find_child("CharacterBodyFrame", true, false)
				var columns: Array
				if frame != null and frame.get_child_count() > 0:
					for column: Node in frame.get_child(0).get_children(): columns.append(str(column.name))
				var rejected: Array
				for node: Node in view["node"].find_children("*", "Control", true, false):
					if not scenes[0]._character_row_can_retain(node): rejected.append({"path": str(view["node"].get_path_to(node)), "scale": str(node.scale), "hover": node.get_meta("character_hovered", false)})
				print("CHARACTER RETENTION REJECTION: ", JSON.stringify({"mode": mode, "columns": columns, "rejected": rejected}))
			_check(can_retain, "Latest retry view must be complete and immediately retainable: " + mode)
	await _compare(changed_preparation_state, "equipment", "source changes while hidden", true)
	await _compare(changed_preparation_state, "magic", "latest changed-source Magic", true)
	_exercise_cache_owner_disposal()
	# Reuse the same scene after showing Skills, exactly as restart/load does.
	await _compare(state, "skills", "Skills before reload")
	var skill_tree: Node = scenes[0]._skill_tree_view
	for scene: Node in scenes:
		scene._upgrade_scrim.hide()
		var was_complete: bool = scene._initial_ui_complete
		scene._initial_ui_complete = false
		scene._load_run_state(state.duplicate(true))
		scene._initial_ui_complete = was_complete
		scene._close_dialogue()
		scene._pre_battle_scrim.hide()
		scene._large_map_scrim.hide()
	_capture_preparation_inputs()
	await Rows.prepare_current_for(scenes[0], scenes[0]._character_row_preparation_revision, _present_preparation, _preparation_alive)
	await _compare(state, "equipment", "prepared Gear after Skills and reload")
	_check(is_instance_valid(skill_tree) and scenes[0]._skill_tree_view == skill_tree, "Adoption after reload must preserve the retained skill tree")
	await _compare(state, "equipment", "unchanged Gear reopen after reload", true)
	await _compare(state, "skills", "return to Skills after reload")
	for scene: Node in scenes: scene._upgrade_scrim.hide()
	preparation_state = scenes[0]._run_state.duplicate(true)
	preparation_bindings = scenes[0]._character_view_bindings()
	preparation_mode = scenes[0]._progression_overlay_mode
	preparation_active = true
	cancel_on_present = true
	await Rows.prepare_current_for(scenes[0], scenes[0]._character_row_preparation_revision, _present_preparation, _preparation_alive)
	_check(not preparation_active, "Cancellation fixture must interrupt a rendered preparation boundary")
	preparation_active = true
	await _compare(state, "equipment", "cancelled preparation fallback")
	for scene: Node in scenes: scene._upgrade_scrim.hide()
	preparation_state = scenes[0]._run_state.duplicate(true)
	preparation_bindings = scenes[0]._character_view_bindings()
	preparation_mode = scenes[0]._progression_overlay_mode
	free_on_present = true
	await Rows.prepare_current_for(scenes[0], scenes[0]._character_row_preparation_revision, _present_preparation, _preparation_alive)
	for scene: Node in scenes:
		if is_instance_valid(scene): scene.free()
	await _settle(8)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Character retention teardown must leave no orphan nodes")
	print("CHARACTER RETENTION RESULT: ", JSON.stringify({"cases": cases, "errors": errors, "differences": differences, "preparation_frames": preparation_frames, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _capture_preparation_inputs() -> void:
	preparation_state = scenes[0]._run_state.duplicate(true)
	preparation_bindings = scenes[0]._character_view_bindings()
	preparation_mode = scenes[0]._progression_overlay_mode

func _exercise_automatic_reload(state: Dictionary) -> void:
	# Exercise the production deferred continuation, including interruption while
	# it transfers rows into a dialog. Manual preparation alone misses this path.
	var loaded: Dictionary = state.duplicate(true)
	loaded["equipment_inventory"] = ["iron_cleaver", "duelist_rapier", "iron_cleaver"]
	loaded["item_inventory"] = Data.item_card_ids()
	loaded["magic_inventory"] = Data.reward_card_pool_by_rarity("", true).get("common", []).duplicate()
	for boundary: int in [1, 4, 12, 24, 48]:
		for index: int in scenes.size():
			var scene: Node = scenes[index]
			scene._close_card_upgrade_overlay()
			# Only the candidate uses automatic speculative preparation. The
			# reference stays the original synchronous whole-dialog builder.
			scene._initial_ui_complete = index == 0
			scene._load_run_state(loaded.duplicate(true))
			scene._close_dialogue()
			scene._pre_battle_scrim.hide()
			scene._large_map_scrim.hide()
		await _settle(boundary)
		loaded = scenes[0]._run_state.duplicate(true)
		await _compare(loaded, "equipment", "automatic reload Gear at frame %d" % boundary, true)
		await _compare(loaded, "magic", "automatic reload Magic at frame %d" % boundary, true)
		loaded["equipment_inventory"].reverse()
	# Subsequent explicit preparation fixtures own their continuations again.
	for scene: Node in scenes: scene._initial_ui_complete = false

func _exercise_cache_owner_disposal() -> void:
	var pool := Rows.new()
	var owner := PanelContainer.new()
	root.add_child(owner)
	var row: Control = pool.take("row", [], func() -> Control: return Control.new())
	var panel: PanelContainer = pool.take_panel("panel", [], func() -> PanelContainer: return PanelContainer.new())
	panel.add_child(row)
	owner.add_child(panel)
	pool.store_view("equipment", owner, {}, {})
	pool._discard(owner)
	_check(pool._entries.is_empty() and pool._panels.is_empty() and pool._views.is_empty(), "Discarding a prepared dialog must invalidate all owned cache entries")
	# Existing scene rebuild code may free a cached row independently. Reading
	# that freed Variant must safely build a new control before typed assignment.
	row = pool.take("external", [], func() -> Control: return Control.new())
	row.free()
	row = pool.take("external", [], func() -> Control: return Control.new())
	_check(is_instance_valid(row), "Externally freed cached rows must be reconstructed")
	pool._discard(row)
	var live: Control = pool.take("live", [], func() -> Control: return Control.new())
	var freed: Control = pool.take("freed", [], func() -> Control: return Control.new())
	freed.free()
	var no_keys: Array[String]
	pool.prune(no_keys, Callable())
	_check(pool._entries.is_empty() and live.is_queued_for_deletion(), "Pruning mixed live/freed rows must tolerate disposal invalidating later keys")
	cases += 3

func _exercise_preparation_boundaries(state: Dictionary) -> void:
	# Repeat an already prepared state. Every frame boundary must permit a real
	# open, including column transfer, finish/layout and font preparation.
	for mode: String in ["equipment", "magic"]:
		for target: int in range(1, 65):
			for scene: Node in scenes:
				scene._upgrade_scrim.hide()
				scene._run_state = state.duplicate(true)
			_capture_preparation_inputs()
			preparation_boundary = 0
			preparation_opened = false
			preparation_open_mode = mode
			open_at_preparation_frame = target
			await Rows.prepare_current_for(scenes[0], scenes[0]._character_row_preparation_revision, _present_preparation, _preparation_alive)
			open_at_preparation_frame = -1
			if not preparation_opened: break
			await create_timer(0.2).timeout
			await _settle(8)
			_check(is_instance_valid(scenes[0]._upgrade_dialog) and not scenes[0]._upgrade_dialog.is_queued_for_deletion(), "Cancellation must not free an adopted live dialog at boundary %d" % target)
			if not is_instance_valid(scenes[0]._upgrade_dialog): return
			# Compare the opened result without rebuilding it, which could conceal
			# an incomplete adopted dialog or broken continuation ownership.
			var original: Node = scenes[1]
			original._progression_overlay_mode = mode
			original._clear_open_loadout_tab_unread(mode)
			original._rebuild_progression_overlay()
			original._upgrade_scrim.show()
			await _settle(8)
			var actual: Dictionary = _snapshot(scenes[0]._upgrade_dialog, scenes[0]._upgrade_dialog)
			var expected: Dictionary = _snapshot(original._upgrade_dialog, original._upgrade_dialog)
			var label: String = "open %s at repeated preparation boundary %d" % [mode, target]
			if actual != expected: _print_differences(actual, expected, label)
			_check(actual == expected, "Actual boundary open must match the original complete dialog: " + label)
			_check(scenes[0]._run_state == original._run_state, "Boundary open must preserve original authoritative state")
			cases += 1
			# Leave complete old views for the next repeated preparation attempt.
			scenes[0]._upgrade_scrim.hide()
			_capture_preparation_inputs()
			await Rows.prepare_current_for(scenes[0], scenes[0]._character_row_preparation_revision, _present_preparation, _preparation_alive)

func _compare(state: Dictionary, mode: String, label: String, reopen: bool = false) -> void:
	var before: Dictionary = state.duplicate(true)
	for scene: Node in scenes:
		scene._run_state = state.duplicate(true)
		scene._progression_overlay_mode = mode
		scene._progression_overlay_notice = ""
		if reopen and scene == scenes[0]: scene._open_character_overlay(mode)
		else:
			if reopen: scene._clear_open_loadout_tab_unread(mode)
			scene._rebuild_progression_overlay()
		scene._upgrade_scrim.show()
	if reopen: await create_timer(0.2).timeout
	await _settle(8)
	var actual: Dictionary = _snapshot(scenes[0]._upgrade_dialog, scenes[0]._upgrade_dialog)
	var expected: Dictionary = _snapshot(scenes[1]._upgrade_dialog, scenes[1]._upgrade_dialog)
	if actual != expected: _print_differences(actual, expected, label)
	_check(actual == expected, "Retained UI must match original geometry, fonts, art, controls and callbacks: " + label)
	_check(state == before and scenes[0]._run_state == scenes[1]._run_state, "Presentation must not mutate authoritative state: " + label)
	_check(scenes[0]._character_inventory_rows.retained_count() <= scenes[0]._current_character_row_keys().size(), "Retained rows must be bounded by current inventory identities: " + label)
	cases += 1

func _snapshot(node: Node, origin: Control) -> Dictionary:
	var result: Dictionary = {"class": node.get_class()}
	if node is Control:
		var control: Control = node
		if control.is_visible_in_tree():
			result["position"] = (control.global_position - origin.global_position).snapped(Vector2(0.001, 0.001))
			result["size"] = control.size.snapped(Vector2(0.001, 0.001))
		result["minimum"] = control.custom_minimum_size
		result["visible"] = control.visible
		result["tooltip"] = control.tooltip_text
		result["focus_mode"] = control.focus_mode
		result["mouse_filter"] = control.mouse_filter
		result["cursor"] = control.mouse_default_cursor_shape
		result["modulate"] = control.modulate
		result["scale"] = control.scale
		for signal_name: String in ["mouse_entered", "mouse_exited", "gui_input", "focus_entered", "focus_exited"]:
			result[signal_name] = control.get_signal_connection_list(signal_name).size()
		for style_name: String in ["panel", "normal", "disabled", "focus"]:
			if control.has_theme_stylebox_override(style_name): result["style_" + style_name] = _style(control.get_theme_stylebox(style_name))
	if node is Label:
		var label: Label = node
		result["text"] = label.text
		result["font_size"] = label.get_theme_font_size("font_size")
		result["outline"] = label.get_theme_constant("outline_size")
		result["font"] = label.get_theme_font("font").get_instance_id()
		result["font_color"] = label.get_theme_color("font_color")
	if node is Button:
		var button: Button = node
		result["text"] = button.text
		result["disabled"] = button.disabled
		result["button_pressed"] = button.button_pressed
		result["icon"] = _texture(button.icon)
		result["pressed_connections"] = button.get_signal_connection_list("pressed").size()
		var callbacks: Array[Dictionary]
		for connection: Dictionary in button.get_signal_connection_list("pressed"):
			var callback: Callable = connection["callable"]
			var arguments: Array
			for argument: Variant in callback.get_bound_arguments(): arguments.append(_callback_argument(argument, origin))
			# IDs/indices/colors stay exact; inspect callbacks bind the owning scene
			# and row, whose structural roles match across the two live instances.
			callbacks.append({"method": callback.get_method(), "arguments": arguments})
		result["pressed_callbacks"] = callbacks
	if node is TextureRect: result["texture"] = _texture((node as TextureRect).texture)
	if node.get_script() == preload("res://scripts/ui_card_strip.gd"):
		for property: String in ["card_id", "locked", "selected"]: result[property] = node.get(property)
	if node is Scene.EquipmentInventoryTile:
		result["equipment_id"] = node.equipment_id
		result["owns_host"] = node.host.is_ancestor_of(node)
	elif node is Scene.MagicCardTile:
		result["magic_source"] = node.source_kind
		result["magic_index"] = node.magic_index
		result["magic_card"] = node.card_id
		result["owns_host"] = node.host.is_ancestor_of(node)
	elif node is Scene.ItemCardTile:
		result["item_source"] = node.source_kind
		result["item_index"] = node.item_index
		result["item_card"] = node.card_id
		result["owns_host"] = node.host.is_ancestor_of(node)
	if node is ScrollContainer:
		result["scroll_vertical"] = node.scroll_vertical
		result["scroll_horizontal"] = node.scroll_horizontal
	var children: Array[Dictionary]
	for child: Node in node.get_children(): children.append(_snapshot(child, origin))
	result["children"] = children
	return result

func _callback_argument(value: Variant, origin: Control) -> Variant:
	if value is Node:
		var node: Node = value
		if node.is_ancestor_of(origin): return {"node_role": "owning_scene", "class": node.get_class()}
		if origin.is_ancestor_of(node):
			var indices: Array[int]
			while node != origin:
				indices.push_front(node.get_index())
				node = node.get_parent()
			return {"node_role": "dialog_descendant", "indices": indices}
		return {"node_role": "outside_dialog", "identity": node.get_instance_id()}
	return value

func _style(style: StyleBox) -> Dictionary:
	var result: Dictionary = {"class": style.get_class()}
	if style is StyleBoxFlat:
		for property: String in ["bg_color", "border_color", "border_width_left", "border_width_top", "border_width_right", "border_width_bottom", "corner_radius_top_left", "shadow_color", "shadow_size"]: result[property] = style.get(property)
	return result

func _texture(texture: Texture2D) -> Variant:
	if texture == null: return null
	if texture is AtlasTexture: return {"region": texture.region, "atlas": _texture(texture.atlas)}
	if texture is ViewportTexture: return {"class": "ViewportTexture"}
	return {"class": texture.get_class(), "source": texture.resource_path, "identity": texture.get_instance_id()}

func _settle(frames: int) -> void:
	for frame: int in range(frames): await process_frame
func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _print_differences(actual: Variant, expected: Variant, path: String) -> void:
	if actual == expected: return
	if actual is Dictionary and expected is Dictionary:
		for key: Variant in actual: _print_differences(actual[key], expected.get(key), path + "/" + str(key))
	elif actual is Array and expected is Array and actual.size() == expected.size():
		for index: int in range(actual.size()): _print_differences(actual[index], expected[index], path + "/" + str(index))
	else:
		differences += 1
		if differences <= 45: print("CHARACTER DIFFERENCE ", path, " actual=", actual, " original=", expected)

func _present_preparation() -> void:
	preparation_frames += 1
	preparation_boundary += 1
	if is_instance_valid(scenes[0]):
		_check(scenes[0]._run_state == preparation_state, "Preparation must preserve authoritative run state before every rendered boundary")
		_check(scenes[0]._progression_overlay_mode == preparation_mode and scenes[0]._character_view_bindings() == preparation_bindings, "Preparation must restore all live presentation bindings and mode before every rendered boundary")
		if free_on_present:
			free_on_present = false
			scenes[0].free()
	if change_state_on_present and preparation_boundary == 2:
		change_state_on_present = false
		for scene: Node in scenes: scene._run_state = changed_preparation_state.duplicate(true)
		_capture_preparation_inputs()
	if preparation_boundary == open_at_preparation_frame:
		preparation_opened = true
		scenes[0]._open_character_overlay(preparation_open_mode)
	if cancel_on_present:
		cancel_on_present = false
		preparation_active = false
	await process_frame

func _preparation_alive() -> bool: return preparation_active
