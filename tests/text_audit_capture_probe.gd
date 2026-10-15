extends SceneTree

# Inventory-only probe. --export-json is a deterministic, headless data/font
# measurement pass; --validate-only exercises the same fixtures without images.
# The design owner runs the default mode with visual_probe_runner (windowed).
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const Elements = preload("res://scripts/element_data.gd")
const Card = preload("res://scripts/card_widget.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const ChronicleFixture = preload("res://tests/chronicle_probe.gd")
const Recap = preload("res://scripts/run_end_recap_overlay.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/text_audit/1920x1080"
# Chosen defaults: debug-only seed, settling budget and manual-tooltip position.
const FIXTURE_SEED: int = 321
const READY_FRAMES: int = 600
const SETTLE_FRAMES: int = 5
const TOOLTIP_POSITION := Vector2(1200, 350)
const TOOLTIP_SAFE_MARGIN: float = 24.0
const TOOLTIP_Z_INDEX: int = 4095
const PROOF_STATUS_STACKS: int = 2
const SHOP_FIXTURE_SEED: int = 73491
const SHOP_FIXTURE_EMBERS: int = 720
const SHOP_FIXTURE_STOCK: Array = ["grave_mortar", "icicle_lance", "dawnstep", "boiled_leather", "dust_tabi", "duelist_rapier", "crimson_draught", "nail_bomb", "jaw_trap"]
const PROOF_HAND: Array = ["quick_stab", "bone_dart", "sidestep_slash"]
const PROOF_RELICS: Array = ["ember_lens", "pilgrim_boots", "mirror_shard"]
const PRESENTATION_WAIT_SECONDS: float = 1.2
const MEASUREMENT_HAND_COUNTS: Array = [3, 8]
const DISABLED_EVENT_EMBERS: int = 0
const NATIVE_TOOLTIP_WAIT_SECONDS: float = 0.6
const TREASURE_POLL_SECONDS: float = 0.025
const CAPTURES: Array = [
	"01_card_hand", "02_card_reward", "03_relic_choice", "04_owned_relic",
	"05_status", "06_intent", "07_map_node", "08_event", "09_shop",
	"10_chronicle", "11_run_end", "12_settings", "13_keyword",
	"14_enemy", "15_equipment", "16_grimoire", "17_tutorial",
	"18_confirmation", "19_empty_chronicle", "20_main_menu",
	"21_omen", "22_event_disabled", "23_skill_tree", "24_character",
	"25_campfire", "26_pre_battle", "27_pause", "28_item",
]

var _failed: bool = false
var _headless: bool = false
var _viewport: SubViewport
var _scene: Node
var _tooltip: Control
var _observations: Array = []
var _inventory_ids_by_text: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	Settings.set_storage_path("user://text_audit_settings.json")
	Store.set_storage_path("user://text_audit_progression.json")
	Store.set_run_storage_path("user://text_audit_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	if OS.get_cmdline_user_args().has("--export-json"):
		call_deferred("_export_json")
	else:
		call_deferred("_run")

func _export_json() -> void:
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	root.add_child(_viewport)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	for frame: int in range(READY_FRAMES):
		if bool(_scene.call("initial_presentation_is_ready")): break
		await process_frame
	_expect(bool(_scene.call("initial_presentation_is_ready")), "Layout measurement scene is ready")
	var engine := Run.new()
	await _load(_combat_fixture(engine, engine.create_new_run(FIXTURE_SEED, Store.default_data())))
	var layout_profiles: Dictionary = {"base": Card.BASE_CARD_SIZE,
		"equipment_tooltip": _scene.EQUIPMENT_TOOLTIP_CARD_SIZE,
		"reward_three_choices": _scene.call("_reward_choice_card_size", PROOF_HAND.size(), true)}
	for count: int in MEASUREMENT_HAND_COUNTS:
		layout_profiles["hand_%d" % count] = _scene.call("_hand_card_size", count, false)
	var result: Dictionary = {"icons": {}, "room_icons": {}, "elements": Elements.ELEMENTS,
		"action_aliases": Icons.ACTION_ICON_ALIASES, "self_flag_aliases": Icons.SELF_FLAG_ICON_KEYS,
		"card_role_icons": Icons.CARD_ROLE_EMBLEM_PATHS, "cards": {}, "relics": {}, "layout_profiles": {}, "room_labels": {}}
	for profile: String in layout_profiles:
		var profile_size: Vector2 = layout_profiles[profile]
		result.layout_profiles[profile] = [profile_size.x, profile_size.y]
	for key: String in Icons.all_icon_keys():
		result.icons[key] = {"label": Icons.label(key), "description": Icons.description(key),
			"tooltip": Icons.tooltip(key), "path": Icons.icon_path(key)}
	for key: String in RoomIcons.all_icon_ids():
		result.room_icons[key] = RoomIcons.icon_path(key)
		var map: Control = _scene.get("_large_map_view") as Control
		var node: Dictionary = {"type": key, "revealed": true}
		if key.begins_with("guardian_"):
			node = {"type": "guardian", "guardian_id": key.trim_prefix("guardian_"), "revealed": true}
		elif key.begins_with("boss_"):
			node = {"type": "boss", "boss_id": key.trim_prefix("boss_"), "revealed": true}
		result.room_labels[key] = Elements.name(key) if Elements.is_elemental(key) else map.call("_room_label", node)
	for id: String in Data.relics():
		result.relics[id] = Data.relic_def(id)
	# Use the actual CardWidget width/font helpers and Godot's text shaper. These
	# are layout measurements, never substitutes for inspected renderer proof.
	var widget := Card.new()
	widget.size = Card.BASE_CARD_SIZE
	var font: Font = Typography.text_font()
	_expect(font != null, "Production card text font resolves")
	for id: String in Data.cards():
		var card: Dictionary = Data.card_def(id)
		var rows: Array = Icons.rows_for_card(card)
		rows.append_array(Icons.keyword_rows_for_card(card))
		rows.append_array(Icons.cost_rows_for_card(card))
		rows.append_array(Icons.rules_text_rows_for_card(card))
		var text: String = Icons.rite_face_rules_text(card) if Icons.card_is_rite(card) else Icons.card_rules_text(card)
		var font_size: int = widget.call("_rules_text_font_size")
		var width: float = widget.call("_rules_text_width")
		var paragraph := TextParagraph.new()
		paragraph.width = width
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.add_string(text, font, font_size)
		var measurements: Dictionary = {}
		for profile: String in layout_profiles:
			widget.size = layout_profiles[profile]
			var measured := TextParagraph.new()
			measured.width = float(widget.call("_rules_text_width"))
			measured.break_flags = paragraph.break_flags
			var measured_size: int = widget.call("_rules_text_font_size")
			measured.add_string(text, font, measured_size)
			measurements[profile] = {"font_size": measured_size, "width": measured.width, "line_count": measured.get_line_count()}
		widget.size = Card.BASE_CARD_SIZE
		var entries: Array = []
		for entry: Dictionary in Icons.tooltip_entries_for_rows(rows):
			entries.append({"icon": entry.get("icon", ""), "title": entry.get("title", ""),
				"description": entry.get("description", ""), "tooltip": entry.get("tooltip", "")})
		result.cards[id] = {"name": card.get("name", id), "rules": Icons.card_rules_text(card),
			"face_text": text, "face_uses_prose": Icons.card_is_rite(card),
			"font_size": font_size, "width": width, "line_count": paragraph.get_line_count(),
			"measurements": measurements,
			"rows": rows, "role_icon": Icons.card_role_emblem_key(card),
			"tooltip_entries": entries}
	widget.free()
	_scene.queue_free()
	_viewport.queue_free()
	await process_frame
	print("TEXT_AUDIT_JSON:" + JSON.stringify(result))
	quit(1 if _failed else 0)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("TEXT AUDIT: " + message)

func _run() -> void:
	_expect(not _headless or OS.get_cmdline_user_args().has("--validate-only"), "Headless requires --validate-only; it cannot prove captures")
	if _failed:
		quit(1)
		return
	_load_inventory_index()
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _capture_fixtures()
	_expect(_observations.size() == CAPTURES.size(), "Every numbered fixture was exercised")
	var file := FileAccess.open(OUTPUT.path_join("observations.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "captures": _observations}, "\t") + "\n")
	print(ProjectSettings.globalize_path(OUTPUT))
	print("TEXT AUDIT CAPTURE %s RESULT: %s (%d fixtures)" % ["HEADLESS VALIDATION" if _headless else "RENDERER", "FAIL" if _failed else "PASS", _observations.size()])
	quit(1 if _failed else 0)

func _capture_fixtures() -> void:
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	for frame: int in range(READY_FRAMES):
		if bool(_scene.call("initial_presentation_is_ready")):
			break
		await process_frame
	_expect(bool(_scene.call("initial_presentation_is_ready")), "Run scene finishes initial preparation")
	var engine := Run.new()
	var base: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
	await _load(base, false)
	if bool(_scene.get("_dialogue_active")):
		_scene.call("_complete_current_dialogue_line")
	await _capture("17_tutorial", bool(_scene.get("_dialogue_active")), "Production initial dialogue is visible and complete")
	_scene.call("_close_dialogue")
	var combat_run: Dictionary = _combat_fixture(engine, base)
	_expect(not (combat_run.get("combat_state", {}) as Dictionary).is_empty(), "Combat fixture is populated")
	await _load(combat_run)
	_scene.call("_on_card_hover_started", 0)
	_scene.call("_show_card_focus_tooltips", 0)
	await _settle()
	var hand: Control = _scene.call("_hand_card_control", 0)
	await _capture("01_card_hand", hand != null and hand.is_visible_in_tree(), "Production hand card and its keyword stack")
	_scene.call("_on_card_hover_ended", 0)
	_clear_tooltip()
	var board: Control = _scene.get("board_view") as Control
	var combat_state: Dictionary = _scene.get("_combat_state")
	var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[0]
	var badges: Array = board.call("_unit_status_badges", enemy)
	var status_text: String = ""
	for badge: Dictionary in badges:
		if str(badge.get("icon", "")) == "bleed":
			status_text = Icons.tooltip("bleed")
	_show_tooltip(board.call("_make_custom_tooltip", status_text))
	await _capture("05_status", not status_text.is_empty() and _tooltip != null, "Live enemy Bleed badge and production tooltip")
	_clear_tooltip()
	var intent_rows: Array = board.call("_intent_rows_for_unit", enemy, enemy.get("intent", {}))
	var intent_text: String = ""
	for row: Array in intent_rows:
		for token: Dictionary in row:
			intent_text = Icons.token_tooltip(token)
			if not intent_text.is_empty(): break
		if not intent_text.is_empty(): break
	_show_tooltip(board.call("_make_custom_tooltip", intent_text))
	await _capture("06_intent", not intent_text.is_empty() and _tooltip != null, "Live enemy intent token and its exact tooltip")
	_clear_tooltip()
	_show_tooltip(_scene.call("_build_pre_battle_enemy_inspection_panel", enemy))
	await _capture("14_enemy", _tooltip != null and _tooltip.find_child("PreBattleKnownMoves", true, false) != null, "Production enemy inspection with known moves")
	_clear_tooltip()
	_show_tooltip(_scene.call("_build_equipment_tooltip_panel", "training_sword"))
	await _capture("15_equipment", _tooltip != null, "Production starter equipment tooltip")
	_clear_tooltip()
	_show_tooltip(_scene.call("_build_card_tooltip_panel", "crimson_draught", false, true))
	await _capture("28_item", _tooltip != null and bool(_tooltip.get_meta("item_pickup_tooltip_surface", false)), "Production item pickup tooltip and destination line")
	_clear_tooltip()
	_show_tooltip(Tooltip.make_text(Icons.tooltip("bleed")))
	await _capture("13_keyword", _tooltip != null, "Shared keyword tooltip type, verbatim Bleed definition")
	_clear_tooltip()
	var relic_frame: Control = _scene.call("_relic_frame_for_id", "ember_lens")
	if relic_frame != null:
		await _pointer(relic_frame.get_global_rect().get_center())
		_show_tooltip(relic_frame.call("_make_custom_tooltip", relic_frame.tooltip_text))
	await _capture("04_owned_relic", relic_frame != null and not relic_frame.tooltip_text.is_empty() and _tooltip != null, "Owned relic parent has a tooltip; inline symbols have no independent targets")
	_clear_tooltip()
	var reward: Dictionary = combat_run.duplicate(true)
	reward["mode"] = "reward"
	reward["pending_reward"] = {"cards": PROOF_HAND.duplicate(), "heal_amount": Run.REWARD_HEAL, "ember_amount": 0}
	await _load(reward)
	var reward_card: Control = _first_card(_scene)
	if reward_card != null:
		await _pointer(reward_card.get_global_rect().get_center())
	await _capture("02_card_reward", str((_scene.get("_run_state") as Dictionary).get("mode")) == "reward" and reward_card != null, "Live card reward and hovered production CardWidget")
	var treasure: Dictionary = _room_fixture(engine, base, "treasure")
	treasure["mode"] = "treasure"
	treasure["pending_relics"] = PROOF_RELICS.duplicate()
	await _load(treasure)
	for frame: int in range(READY_FRAMES):
		if not bool(_scene.get("_treasure_reveal_active")): break
		await create_timer(TREASURE_POLL_SECONDS).timeout
	await _settle()
	var choice: Control = _scene.find_child("RelicChoice_ember_lens", true, false) as Control
	if choice != null:
		await _pointer(choice.get_global_rect().get_center())
		choice.mouse_entered.emit()
	await _capture("03_relic_choice", choice != null and choice.visible and choice.tooltip_text.is_empty(), "Hovered relic choice has inline copy and no tooltip")
	await _load(base)
	_scene.call("_open_large_map")
	await _settle()
	var map: Control = _scene.get("_large_map_view") as Control
	var destinations: Array = map.call("available_destinations")
	if not destinations.is_empty():
		var target: Control = (map.get("node_buttons") as Dictionary).get(destinations[0]) as Control
		await _pointer(target.get_global_rect().get_center())
		map.call("_show_preview", destinations[0])
	await _capture("07_map_node", map.is_visible_in_tree() and map.get("_preview") != null, "Map hover shows production room identity and state")
	_scene.call("_close_large_map")
	await _load(EventFixture.fixture("hanged_knight"))
	await create_timer(PRESENTATION_WAIT_SECONDS).timeout
	var event_view: Control = _scene.get("_event_view") as Control
	await _capture("08_event", event_view != null and event_view.is_visible_in_tree(), "Existing hanged_knight event fixture")
	var disabled_event: Dictionary = EventFixture.fixture("frozen_champion")
	disabled_event["held_embers"] = DISABLED_EVENT_EMBERS
	disabled_event["unbanked_embers"] = DISABLED_EVENT_EMBERS
	await _load(disabled_event)
	await create_timer(PRESENTATION_WAIT_SECONDS).timeout
	event_view = _scene.get("_event_view") as Control
	var disabled_choice: Control = event_view.choices[1]
	await _pointer(disabled_choice.get_global_rect().get_center())
	# This button uses Godot's native tooltip, not UiTooltipPanel. Embedded
	# subwindows keep that actual popup inside the capture target.
	await create_timer(NATIVE_TOOLTIP_WAIT_SECONDS).timeout
	await _capture("22_event_disabled", not bool(disabled_choice.get("available")) and not disabled_choice.tooltip_text.is_empty(), "Existing disabled event choice reports its requirement")
	_clear_tooltip()
	await _load(EventFixture.combat_fixture())
	var omen_manager: RefCounted = _scene.get("_omen_badges")
	var omen: Control = omen_manager.badges.get("hunted") as Control
	if omen != null: omen.grab_focus()
	await _capture("21_omen", omen != null and omen.has_focus(), "Existing omen fixture exposes its production focus tooltip")
	var shop_base: Dictionary = engine.create_new_run(SHOP_FIXTURE_SEED, Store.default_data())
	var shop_state: Dictionary = _room_fixture(engine, shop_base, "scavenger")
	var room: Dictionary = engine.room_metadata(shop_state, shop_state["current_room"])
	room[Run.MERCHANT_STOCK_KEY] = SHOP_FIXTURE_STOCK.duplicate()
	shop_state["held_embers"] = SHOP_FIXTURE_EMBERS
	shop_state["unbanked_embers"] = SHOP_FIXTURE_EMBERS
	await _load(shop_state)
	var shop: Control = _scene.find_child("ScavengerShopView", true, false) as Control
	await _capture("09_shop", shop != null and shop.is_visible_in_tree(), "Existing scavenger stock fixture, live shop")
	await _load(base)
	_scene.call("_open_character_overlay", "skills")
	await create_timer(PRESENTATION_WAIT_SECONDS).timeout
	await _capture("23_skill_tree", (_scene.get("_upgrade_scrim") as Control).visible and str(_scene.get("_progression_overlay_mode")) == "skills", "Production skill tree and definitions")
	_scene.call("_close_card_upgrade_overlay")
	_scene.call("_open_character_overlay", "equipment")
	await create_timer(PRESENTATION_WAIT_SECONDS).timeout
	await _capture("24_character", (_scene.get("_upgrade_scrim") as Control).visible and str(_scene.get("_progression_overlay_mode")) == "equipment", "Production character inventory")
	_scene.call("_close_card_upgrade_overlay")
	var campfire: Dictionary = _room_fixture(engine, base, "campfire")
	campfire["mode"] = "campfire"
	await _load(campfire)
	await _capture("25_campfire", str((_scene.get("_run_state") as Dictionary).get("mode")) == "campfire", "Production Ember Hearth choices")
	var pre_battle: Dictionary = engine.move_to_pre_battle(base.duplicate(true), engine.available_moves(base)[0])
	await _load(pre_battle)
	await create_timer(PRESENTATION_WAIT_SECONDS).timeout
	await _capture("26_pre_battle", (_scene.get("_pre_battle_scrim") as Control).visible, "Production pre-battle report")
	await _load(combat_run)
	_scene.call("_open_menu_overlay")
	await _capture("27_pause", (_scene.get("_menu_dialog") as Control).visible, "Production pause menu")
	_scene.call("_close_menu_overlay")
	await _load(base)
	_scene.call("_open_grimoire_overlay")
	_scene.call("_on_grimoire_entry_pressed", "keyword:block")
	await _capture("16_grimoire", (_scene.get("_grimoire_scrim") as Control).visible, "Production Block entry")
	_scene.call("_close_grimoire_overlay")
	var recap := Recap.new()
	_viewport.add_child(recap)
	recap.present(Recap.build_model(combat_run, Store.default_data(), "defeat", 0))
	recap.seek_presentation(recap.presentation_duration())
	await _capture("11_run_end", recap.is_visible_in_tree(), "Production recap at completed presentation")
	recap.queue_free()
	_scene.queue_free()
	await process_frame
	_scene = null
	Store.save_data(ChronicleFixture.seeded_profile())
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	_viewport.add_child(menu)
	await _settle()
	await _capture("20_main_menu", menu.get_node("MenuColumn").visible, "Production main menu")
	menu.call("_on_settings_button_pressed")
	var settings_panel: Control = menu.get_node("SettingsPanel") as Control
	await _capture("12_settings", settings_panel.visible, "Production settings at 100% scale")
	settings_panel.call("_show_restore_confirmation")
	await _capture("18_confirmation", (settings_panel.get("_confirmation_panel") as Control).visible, "Restore settings confirmation; no destructive action is taken")
	menu.call("_on_settings_back_button_pressed")
	var chronicle := preload("res://scripts/chronicle_panel.gd").new()
	_viewport.add_child(chronicle)
	chronicle.open(ChronicleFixture.seeded_profile(), false)
	await _capture("10_chronicle", chronicle.is_visible_in_tree(), "Existing Chronicle seeded profile; no fabricated production copy")
	chronicle.open(Store.default_data(), false)
	await _capture("19_empty_chronicle", chronicle.is_visible_in_tree(), "Production empty Chronicle")
	chronicle.queue_free()
	menu.queue_free()
	await process_frame

func _load(state: Dictionary, close_dialogue: bool = true) -> void:
	_clear_tooltip()
	_scene.call("_load_run_state", state.duplicate(true))
	await _settle()
	if close_dialogue:
		_scene.call("_close_dialogue")
	await _settle()

func _combat_fixture(engine: RefCounted, base: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	for coord: Vector2i in engine.available_moves(base):
		var candidate: Dictionary = engine.move_to_room(base.duplicate(true), coord)
		if str(candidate.get("mode", "")) == "combat":
			state = candidate
			break
	if state.is_empty():
		_expect(false, "Seed has reachable combat")
		return base
	var combat: Dictionary = state["combat_state"]
	(combat["deck"] as Dictionary)["hand"] = PROOF_HAND.duplicate()
	combat["relics"] = PROOF_RELICS.duplicate()
	state["relics"] = PROOF_RELICS.duplicate()
	combat["current_actor"] = {"kind": "player", "key": "player"}
	var enemy: Dictionary = (combat["enemies"] as Array)[0]
	enemy["bleed"] = PROOF_STATUS_STACKS
	# Pin one authored intent so this fixture also works when the generated
	# opening intent is a wait/empty declaration. No action values are edited.
	for intent: Dictionary in Data.enemy_def(str(enemy["type"])).get("intents", []):
		if not (intent.get("actions", []) as Array).is_empty():
			enemy["intent"] = intent.duplicate(true)
			break
	return state

func _room_fixture(engine: RefCounted, base: Dictionary, kind: String) -> Dictionary:
	var state: Dictionary = base.duplicate(true)
	for key: String in (state["rooms"] as Dictionary):
		var room: Dictionary = state["rooms"][key]
		if str(room.get("type", "")) != kind: continue
		room["revealed"] = true
		room["visited"] = true
		room["cleared"] = true
		state["current_room"] = room["coord"]
		state["current_room_layout"] = engine.call("_display_layout_for_room", int(state["seed"]), room, Vector2i(1, 0))
		state["mode"] = "room"
		state["combat_state"] = {}
		state["pending_reward"] = {}
		state["pending_relics"] = []
		return state
	_expect(false, "Seed contains room type " + kind)
	return state

func _first_card(node: Node) -> Control:
	if node is Card and (node as Control).is_visible_in_tree(): return node as Control
	for child: Node in node.get_children():
		var found: Control = _first_card(child)
		if found != null: return found
	return null

func _pointer(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	_viewport.push_input(event, true)
	await _settle()

func _show_tooltip(panel: Control) -> void:
	_clear_tooltip()
	if panel == null: return
	_tooltip = panel
	# Native tooltip popups live outside the SubViewport. Embed the unmodified
	# production tooltip panel for the fixed-size proof camera instead.
	panel.z_index = TOOLTIP_Z_INDEX
	_viewport.add_child(panel)
	panel.position = TOOLTIP_POSITION
	call_deferred("_fit_tooltip")

func _fit_tooltip() -> void:
	if not is_instance_valid(_tooltip): return
	_tooltip.position = Vector2(minf(TOOLTIP_POSITION.x, SIZE.x - _tooltip.size.x - TOOLTIP_SAFE_MARGIN), minf(TOOLTIP_POSITION.y, SIZE.y - _tooltip.size.y - TOOLTIP_SAFE_MARGIN))

func _clear_tooltip() -> void:
	if is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame

func _capture(id: String, semantic_ok: bool, detail: String) -> void:
	_expect(CAPTURES.has(id), "Capture has a declared id: " + id)
	for previous: Dictionary in _observations:
		_expect(str(previous["id"]) != id, "Capture id is unique: " + id)
	_expect(semantic_ok, id + ": " + detail)
	await _settle()
	var observation: Dictionary = {"id": id, "semantic_ok": semantic_ok, "detail": detail, "texts": []}
	_collect_text(_viewport, observation.texts)
	_observations.append(observation)
	if not _headless:
		await RenderingServer.frame_post_draw
		var capture: Image = _viewport.get_texture().get_image()
		_expect(capture != null and capture.get_size() == SIZE, id + " is 1920x1080")
		if capture != null:
			_expect(capture.save_png(OUTPUT.path_join(id + ".png")) == OK, id + " saves")

func _collect_text(node: Node, rows: Array) -> void:
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Window and not (node as Window).visible:
		return
	if node is Label or node is RichTextLabel or node is Button:
		var value: String = str(node.get("text"))
		if not value.is_empty():
			# Identical copy can have several source occurrences. Preserve every
			# candidate; do not guess the source of dynamic or expanded markup.
			rows.append({"node": str(node.get_path()), "text": value,
				"inventory_ids": _inventory_ids_by_text.get(value, []),
				"inventory_match": "verbatim candidates" if _inventory_ids_by_text.has(value) else "dynamic, case/markup transformed, or unmatched"})
	for child: Node in node.get_children():
		_collect_text(child, rows)

func _load_inventory_index() -> void:
	var path: String = "res://spec/peer_benchmark/staged/text/inventory.json"
	_expect(FileAccess.file_exists(path), "Inventory exists for capture-to-copy mapping")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "Inventory parses for capture-to-copy mapping")
	if not parsed is Dictionary:
		return
	for record: Dictionary in parsed.get("strings", []):
		var text: String = str(record.get("text", ""))
		if not _inventory_ids_by_text.has(text):
			_inventory_ids_by_text[text] = []
		(_inventory_ids_by_text[text] as Array).append(str(record.get("id", "")))
