extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Rules = preload("res://scripts/chronicle_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const OUTPUT_DIR: String = "user://probes/chronicle/1920x1080"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const CAPTURE_SETTLE_FRAMES: int = 4
const CLICK_HOVER_SETTLE_FRAMES: int = 1
const OVERFLOW_SPELL_COUNT: int = 45
const BOTTOM_ROW_DUPLICATE_INDEX: int = 38
const BOTTOM_ROW_DUPLICATE_COUNT: int = 3
const TILE_FIXTURE_DECK := ["chain_bolt", "pale_spark", "quick_stab", "pale_spark", "waning_pulse", "pale_spark"]
const TILE_FIXTURE_UPGRADE_MOD := {"action_index": 0, "field": "damage", "amount": 1}
const CardTile = preload("res://scripts/chronicle_card_tile.gd")
const CardWidgetScript = preload("res://scripts/card_widget.gd")
# Debug fixture values; the seven outcomes, dates, scores and paths are taken
# from the approved mockup. Build icons use existing production starter gear
# and seven existing relics because the source mockup leaves those IDs open.
const PROBE_RELIC_IDS := ["iron_lung", "ember_lens", "pilgrim_boots", "mirror_shard", "coffin_nails", "reinforced_shield", "iron_buckler"]
# Replace the mockup's retired names with existing cards, definitions and art.
const MOCKUP_SPELLS := [["guiding_flare", 1], ["prism_sight", 1], ["pale_spark", 1], ["chain_bolt", 1], ["dawnstep", 1], ["waning_pulse", 1]]
var _failed: bool = false
var _menu: Control
var _canvas: SubViewport

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Store.set_storage_path("user://chronicle_probe_profile.json")
	Store.set_run_storage_path("user://chronicle_probe_run.save")
	Settings.set_storage_path("user://chronicle_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Store.clear_saved_run()
	Store.save_data(seeded_profile())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_run")

static func seeded_profile() -> Dictionary:
	var profile: Dictionary = Store.default_data()
	var specs := [
		["defeat", 2, "Rime Hall", "12 Oct", 41, 567, 2],
		["victory", 5, "", "11 Oct", 96, 1240, 1],
		["defeat", 4, "Tempest Spire", "11 Oct", 74, 902, 1],
		["embrace", 1, "Cinder Crown", "10 Oct", 28, 311, 0],
		["defeat", 0, "Worldspine Roots", "10 Oct", 12, 104, 0],
		["victory", 5, "", "9 Oct", 101, 1108, 0],
		["defeat", 3, "Hollow Gale", "8 Oct", 63, 688, 0]
	]
	var names := ["Worldspine Roots", "Cinder Crown", "Rime Hall", "Hollow Gale", "Tempest Spire", "Heart of the Umbra"]
	var dragons := ["tharokh", "vyraketh", "iskaldra", "vaeloryx", "zekarion", "noctyrax"]
	var gear: Array = GameData.starting_equipped_equipment().values()
	var relics: Array = []
	# Resolve only existing approved assets. Never synthesize placeholder icons.
	for id: String in PROBE_RELIC_IDS:
		if not GameData.relic_def(id).is_empty():
			relics.append(id)
	if relics.size() < 7:
		for id: String in GameData.relics():
			if relics.size() == 7:
				break
			if not relics.has(id):
				relics.append(id)
	var records: Array = []
	for index: int in range(specs.size()):
		var spec: Array = specs[index]
		var path: Array = []
		for section: int in range(int(spec[1]) + 1):
			path.append(["combat", "event", "combat", "combat", "treasure", "combat", "combat", "campfire", "boss"])
		if spec[0] == "embrace":
			path[-1] = ["combat", "event", "combat", "campfire"]
		elif spec[0] == "defeat":
			path[-1] = ["combat", "graftwright", "combat", "combat", "treasure", "combat", "combat"]
		if index == 0:
			path[0] = ["combat", "combat", "event", "combat", "treasure", "combat", "scavenger", "combat", "campfire", "boss"]
		var record: Dictionary = {
			"run_id": "chronicle-probe-%d" % index, "outcome": spec[0], "section_index": spec[1],
			"section_name": spec[2], "ended_at": spec[3], "run_seconds": int(spec[4]) * 60,
			"score_total": spec[5], "umbra_depth": spec[6], "room_index": path[-1].size(), "room_total": 11,
			"path": path, "section_names": names.slice(0, int(spec[1]) + 1), "dragon_ids": dragons.slice(0, int(spec[1]) + 1),
			"killer_text": Rules.killer_text({}, str(spec[0])), "gear": gear, "deck": MOCKUP_SPELLS,
			"relics": relics, "feats": []
		}
		if index == 0:
			record["killer_text"] = "Felled by a Frostglass Lancer's Glass Lunge"
			record["feats"] = [{"title": "Flawless", "detail": "Vyraketh"}, {"title": "Chain Reaction", "detail": "3 foes"}, {"title": "Overkill", "detail": "22 damage"}]
		records.append(record)
	profile[Store.CHRONICLE_RECORDS_KEY] = records
	profile[Store.CHRONICLE_TOTALS_KEY] = {"runs": 24, "escapes": 2, "best_score": 1240, "dragons_slain": 31, "deepest_depth": 3}
	return profile

static func tile_fixture_profile() -> Dictionary:
	var profile: Dictionary = seeded_profile()
	var record: Dictionary = profile[Store.CHRONICLE_RECORDS_KEY][0]
	record["deck"] = Rules.deck_counts(TILE_FIXTURE_DECK)
	# Debug-only upgraded definition uses the production modifier builder. The
	# current CardWidget has no separate upgrade marker to copy onto a tile.
	record["deck_card_definitions"] = {"pale_spark": GameData.card_def_with_card_mods("pale_spark", {"pale_spark": [TILE_FIXTURE_UPGRADE_MOD]})}
	profile[Store.CHRONICLE_RECORDS_KEY][0] = Rules.normalized_record(record)
	return profile

static func five_section_overflow_profile() -> Dictionary:
	var profile: Dictionary = seeded_profile()
	var record: Dictionary = profile[Store.CHRONICLE_RECORDS_KEY][2].duplicate(true)
	record["run_id"] = "chronicle-five-section-overflow"
	record["killer_text"] = Rules.killer_text({"cause": "fatigue"}, "defeat")
	record["deck"] = overflow_deck()
	# Include a duplicate on the final visible row to prove its pill is unclipped.
	record["deck"][BOTTOM_ROW_DUPLICATE_INDEX][1] = BOTTOM_ROW_DUPLICATE_COUNT
	profile[Store.CHRONICLE_RECORDS_KEY][0] = record
	return profile

func _run() -> void:
	_canvas = create_capture_viewport(root)
	_menu = preload("res://scenes/main_menu.tscn").instantiate()
	_canvas.add_child(_menu)
	root.content_scale_size = CAPTURE_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = CAPTURE_SIZE
	root.content_scale_factor = 1.0
	await _settle()
	_require(is_equal_approx(root.content_scale_factor, 1.0) and is_equal_approx(float(Settings.load_settings()["ui_scale"]), 1.0), "100% UI scale")
	await _capture("main_menu")
	await click_button(_menu.get_node("MenuColumn/ChronicleButton"), _canvas)
	await _settle()
	var panel: Control = _menu.get_node("ChroniclePanel")
	_require(panel.records.size() == 7 and panel.selected_index == 0, "Seven mockup records, newest selected")
	_require(panel.get_node("ChronicleFrame").position == Vector2(60, 110), "Panel position follows brief")
	_require((panel.find_child("ChronicleScore", true, false) as Label).text == "567", "Score belongs in selected detail title row")
	await _capture("chronicle")
	await _hover_capture(panel, "Spell_chain_bolt", "hovered_spell")
	await _hover_capture(panel, "Relic_iron_lung", "hovered_relic")
	panel.open(Store.default_data(), false)
	await _settle()
	_require(panel.records.is_empty(), "Empty history")
	await _capture("empty")
	panel.open(seeded_profile(), false)
	panel.select_record(1, true)
	await _settle()
	_require((panel.find_child("ChronicleOutcome", true, false) as Label).text == "ESCAPED", "Victory selected")
	await _capture("victory")
	var overflow: Dictionary = seeded_profile()
	overflow[Store.CHRONICLE_RECORDS_KEY][0]["deck"] = overflow_deck()
	panel.open(overflow, false)
	await _settle()
	var spells := panel.find_child("ChronicleSpells", true, false) as GridContainer
	var overflow_tile: Control = panel.find_child("ChronicleSpellsOverflow", true, false)
	_require(spells.get_child_count() == spells.columns * 2 and overflow_tile.get_node("OverflowCount").text == "+%d" % (OVERFLOW_SPELL_COUNT - spells.get_child_count() + 1), "45 distinct spells fill two rows with an exact overflow count")
	await _capture("spells_overflow")
	await _hover_capture(panel, "ChronicleSpellsOverflow", "hovered_overflow")
	panel.open(five_section_overflow_profile(), false)
	await _settle()
	var detail: Control = panel.find_child("DescentDetail", true, false)
	var scroller: ScrollContainer = panel.get("_detail_scroll")
	_require(scroller.scroll_vertical == 0 and scroller.get_global_rect().encloses(detail.get_global_rect()), "Five-section path and 45-card overflow show all sections without scrolling")
	var last_badge: Label = (panel.find_child("ChronicleSpells", true, false) as GridContainer).get_child(BOTTOM_ROW_DUPLICATE_INDEX).get_node("Badge")
	_require(last_badge.visible and scroller.get_global_rect().encloses(last_badge.get_global_rect()), "Bottom-row duplicate badge is fully visible at rest")
	await _capture("five_section_overflow")
	panel.open(tile_fixture_profile(), false)
	await _settle()
	var duplicate: Control = panel.find_child("Spell_pale_spark", true, false)
	_require(duplicate.get_node("Badge").visible and duplicate.get_node("Badge").text == "×3", "Duplicate badge is visible in the capture")
	await _capture("duplicate_badge")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "xbox")
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	panel._input(down)
	await _settle()
	_require(panel.selected_index == 1 and _canvas.gui_get_focus_owner() == panel.find_child("DescentRow1", true, false), "Controller focus follows selected row")
	_require(panel.get_node("ChronicleControllerPrompts").visible, "Controller Select / Back prompts visible")
	await _capture("controller_focus")
	panel.select_record(0, true)
	await _settle()
	var spell: Control = panel.find_child("Spell_chain_bolt", true, false)
	spell.grab_focus()
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	_canvas.push_input(right, true)
	await _settle()
	_require(_canvas.gui_get_focus_owner() == panel.find_child("Spell_pale_spark", true, false) and panel.selected_index == 0, "Controller D-pad focuses an upgraded spell without changing history")
	_require(panel.get("_focus_tooltip") != null, "Controller spell focus shows the full card preview")
	_require(not (panel.get("_focus_tooltip") as Control).get_global_rect().intersects((panel.get("_focus_anchor") as Control).get_global_rect()), "Controller preview never covers its focused tile")
	await _capture("controller_spell_focus")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	panel._input(back)
	_require(_menu.get_node("MenuColumn/ChronicleButton").has_focus(), "Back restores Chronicle menu focus")
	router.call("clear_forced_state_for_test")
	_menu.queue_free()
	_canvas.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("CHRONICLE PROBE RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

static func create_capture_viewport(parent: Node) -> SubViewport:
	# Capture a fixed render target, independent of the native Retina window.
	var canvas := SubViewport.new()
	canvas.size = CAPTURE_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.gui_embed_subwindows = true
	parent.add_child(canvas)
	# There is no SubViewportContainer to forward the native mouse-enter event.
	# Godot can report a hovered Control without this, but its mouse-motion
	# handler will not start the tooltip timer until the viewport is entered.
	canvas.notify_mouse_entered()
	return canvas

func _settle() -> void:
	for frame: int in range(CAPTURE_SETTLE_FRAMES):
		await process_frame
	await RenderingServer.frame_post_draw

static func overflow_deck() -> Array:
	var deck: Array = []
	for id: String in GameData.cards():
		deck.append([id, 1])
		if deck.size() == OVERFLOW_SPELL_COUNT:
			break
	return deck

func _hover_capture(panel: Control, tile_name: String, state: String) -> void:
	var tile: Control = panel.find_child(tile_name, true, false)
	_require(tile != null, "Hover fixture tile exists: " + tile_name)
	if tile == null:
		return
	var focused: Control = _canvas.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	var scroller: ScrollContainer = panel.get("_detail_scroll")
	scroller.ensure_control_visible(tile)
	await _settle()
	await hover_tile(tile, _canvas)
	await _settle()
	_require(_canvas.gui_get_hovered_control() == tile, "Real pointer hover reaches " + tile_name)
	var tooltip: Control = _visible_custom_tooltip(_canvas)
	_require(tooltip != null, "Native hover creates a custom tooltip: " + tile_name)
	if tooltip != null:
		var popup: Window = tooltip.get_window()
		_require(Rect2(Vector2.ZERO, Vector2(CAPTURE_SIZE)).encloses(Rect2(Vector2(popup.position), Vector2(popup.size))), "Hover tooltip stays inside the capture viewport")
		if tile_name.begins_with("Spell_"):
			_require(card_widgets(tooltip).size() == 1, "Hovered spell shows the full in-run CardWidget")
	await _capture(state)
	move_pointer(_canvas, Vector2.ZERO)
	await _settle()

static func hover_tile(tile: Control, viewport: Viewport) -> void:
	move_pointer(viewport, Vector2.ZERO)
	await tile.get_tree().process_frame
	move_pointer(viewport, tile.get_global_rect().get_center())
	var delay: float = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec"))
	await tile.get_tree().create_timer(delay, true, false, true).timeout
	for frame: int in range(CAPTURE_SETTLE_FRAMES):
		await tile.get_tree().process_frame

static func move_pointer(viewport: Viewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.relative = at - viewport.get_mouse_position()
	# Parse the event to update Input's mouse state as native input does, then
	# forward to this uncontained capture viewport using its own coordinates.
	# Root-window dispatch alone does not reach a standalone SubViewport.
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	viewport.push_input(motion, true)

static func _visible_custom_tooltip(node: Node) -> Control:
	# Embedded native tooltip popups are included in the fixed render target.
	# Godot owns them as internal children; ordinary get_children() omits them.
	if node is Control and node.is_visible_in_tree() and node.get_window() is PopupPanel:
		if node.has_meta("tooltip_surface") or node.has_meta("equipment_tooltip_surface") or not card_widgets(node).is_empty():
			return node as Control
	for child: Node in node.get_children(true):
		var found: Control = _visible_custom_tooltip(child)
		if found != null:
			return found
	return null

static func card_widgets(parent: Node) -> Array[Control]:
	var widgets: Array[Control]
	for child: Node in parent.find_children("*", "Button", true, false):
		if child is CardWidgetScript:
			widgets.append(child as Control)
	return widgets

# Native pointer dispatch is shared by the headless input test and this capture
# probe, so the menu entry is proved through the actual press/release path.
static func click_button(button: Button, viewport: Viewport) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	move_pointer(viewport, at)
	for frame: int in range(CLICK_HOVER_SETTLE_FRAMES):
		await button.get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = at
	press.global_position = at
	press.pressed = true
	viewport.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	viewport.push_input(release, true)

func _capture(state: String) -> void:
	var capture: Image = _canvas.get_texture().get_image()
	_require(capture != null and capture.get_size() == CAPTURE_SIZE, "Real renderer at 1920x1080")
	if capture != null:
		_require(capture.save_png(OUTPUT_DIR.path_join(state + ".png")) == OK, "Screenshot saves")

func _require(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error(message)
