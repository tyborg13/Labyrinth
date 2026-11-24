extends SceneTree

# pla-03 real-renderer proof: the sentence faces of data/card_faces.json in
# the live run scene, 1920x1080 at 100% UI scale, captured from an exact-size
# SubViewport. Per card: the normal hand card (one-card hand) and its hover
# enlargement. The probe also captures pages at the deck/pile reading size
# (_scaled_card_slot, as the pile, purge and Grimoire views build them).
# Based on the playability mock probe (tools/pla03/mock_faces_v2_probe.gd).
# pla-04 adds the board's Burst previews: an Ember Tick's death Burst under a
# lethal hovered card, Vyraketh's declared Crownfire, and a hovered shot that
# breaks a powder keg next to you.
# pla-06 adds the Ice merge: the simple Ice cards' icon rows (their "on Ice:
# Stagger 6" row), a hovered move onto Ice showing the Expose 2 the hero will
# get, and an enemy that started its turn on Ice (resolved by the engine).
#   hand_<id>.png / hover_<id>.png / deck_grid.png /
#   burst_death_preview.png / burst_crownfire_preview.png / burst_faultline_preview.png /
#   burst_keg_preview.png / rows_<id>.png / ice_move_preview.png / ice_enemy_turn_start.png /
#   empowered_pyroclasm_burst.png / shattered_reflection_range.png
#   + manifest.json
# PLA03_CARDS=id,id limits the sentence faces (and deck grid) to those cards;
# PLA03_SECTIONS=faces,burst,ice,review,light limits the sections (default: all).
# PLA03_FACE_IDS=id,id selects faces in the given order. With no sections set,
# the explicit list runs only the face section.
# Run through tools/visual_probe_runner.py with LABYRINTH_CEL_LOOK=all and
# PLA03_OUT = absolute output dir. PLA03_DRY_RUN=1 runs every step headless
# without frames (a parse and setup check).
# PLA04R3_PROOF_ONLY=1 selects burst and review. PLA04R2_PROOF_ONLY=1 selects review.
# PLA08_PROOF_ONLY=1 captures the v5 Light/Vision faces and two board previews.
# PLA08_BOARD_PROOF_ONLY=1 runs just the two board states for focused validation.
# PLA09_PROOF_ONLY=1 captures the seven non-starter faces in hand, hover and pile.
# MRG11D_PROOF_ONLY=1 captures the rollout review fixes.

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const FaceSpec = preload("res://scripts/card_face_spec.gd")
const GameData = preload("res://scripts/game_data.gd")
const Glossary = preload("res://scripts/glossary.gd")
const BoardTileTooltip = preload("res://scripts/board_tile_tooltip.gd")
const InlineIconText = preload("res://scripts/inline_icon_text.gd")
const PileView = preload("res://scripts/pile_dialog_view.gd")
const LayerRedraws = preload("res://scripts/board_layer_redraws.gd")
const PanelText = preload("res://scripts/card_panel_text.gd")
const BurstRules = preload("res://scripts/burst_rules.gd")

const RESOLUTION := Vector2i(1920, 1080)
const LIGHT_VISION_CARD_IDS: Array = [
	"lantern_shot", "guiding_flare", "dawnstep", "prism_sight", "storm_beacon",
	"glowstone_ward", "daybreak", "threaded_path", "trapdoor", "ember_rain",
	"spark_dart", "spark_focus", "beacon", "blessed_salve", "break_the_veil",
	"censer_swing", "incense_haze", "seekers_mark", "seers_candle", "sun_flash",
	"vigil", "rite_of_noon", "flash_powder", "seek_the_light", "sunpath_stride",
	"shattered_reflection", "icebound_chains",
]
const LIGHT_CENTER := Vector2i(3, 4)
const LIGHT_EDGE_ENEMY := Vector2i(5, 4)
const VISION_HIDDEN_ENEMY := Vector2i(6, 2)
const BURST_REVIEW_TARGET := Vector2i(3, 4)
const BURST_REVIEW_HERO_HP: int = 6
const BURST_REVIEW_ENEMY_HP: int = 30
const ICE_MOVE_TILE := Vector2i(3, 5)
const GRID_COLUMNS: int = 5
const GRID_PAGE_SIZE: int = 10
const GRID_ORIGIN := Vector2(48.0, 40.0)
const GRID_GAP := Vector2(140.0, 160.0)
const SLIP_TARGET := Vector2i(4, 4)
const SLIP_TARGET_HP: int = 14
const SLIP_TARGET_EXPOSE: int = 2
const SLIP_TARGET_BLOCK: int = 6
const PLA09_CARDS: Array = [
	"squall_shot", "tectonic_maul", "worldroot_stride", "frost_circuit",
	"grounding", "skate", "stoke",
]

var _out: String = ""
var _viewport: SubViewport
var _failed: bool = false
var _manifest: Dictionary = {}
var _dry_run: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_out = OS.get_environment("PLA03_OUT")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("user://pla03_faces")
	DirAccess.make_dir_recursive_absolute(_out)
	ProgressionStore.set_storage_path("user://pla03_progression.json")
	ProgressionStore.set_run_storage_path("user://pla03_run.save")
	SettingsStore.set_storage_path("user://pla03_settings.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	_dry_run = OS.get_environment("PLA03_DRY_RUN") == "1"
	if DisplayServer.get_name().to_lower() == "headless" and not _dry_run:
		push_error("sentence face probe needs a real renderer")
		quit(1)
		return
	_viewport = SubViewport.new()
	_viewport.size = RESOLUTION
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	await _configure_window()
	if OS.get_environment("MRG11D_PROOF_ONLY") == "1":
		await _capture_rollout_review()
	elif OS.get_environment("PLA04R3_PROOF_ONLY") == "1":
		await _capture_burst_previews()
		await _capture_burst_review()
	elif OS.get_environment("PLA04R2_PROOF_ONLY") == "1":
		await _capture_burst_review()
	elif OS.get_environment("PLA08_BOARD_PROOF_ONLY") == "1":
		await _capture_light_vision_previews()
	elif OS.get_environment("PLA08_PROOF_ONLY") == "1":
		await _capture_cards(LIGHT_VISION_CARD_IDS, false)
		await _capture_light_vision_previews()
	elif OS.get_environment("PLA09_PROOF_ONLY") == "1":
		await _capture_cards(PLA09_CARDS)
	else:
		var sections: PackedStringArray = OS.get_environment("PLA03_SECTIONS").split(",", false)
		if sections.is_empty() and not OS.get_environment("PLA03_FACE_IDS").is_empty():
			sections = PackedStringArray(["faces"])
		if sections.is_empty() or sections.has("faces"):
			await _capture_cards(_selected_face_ids())
		if sections.is_empty() or sections.has("burst"):
			await _capture_burst_previews()
		if sections.is_empty() or sections.has("ice"):
			await _capture_ice_previews()
		if sections.is_empty() or sections.has("review"):
			await _capture_burst_review()
		if sections.is_empty() or sections.has("light"):
			await _capture_light_vision_previews()
	_manifest["cel_look"] = OS.get_environment("LABYRINTH_CEL_LOOK")
	_manifest["ui_scale"] = 1.0
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

func _selected_face_ids() -> Array:
	var ids: Array = FaceSpec.faces().keys().filter(func(card_id: Variant) -> bool: return not FaceSpec.spec_for(str(card_id)).is_empty())
	var only: String = OS.get_environment("PLA03_CARDS")
	if not only.is_empty():
		var wanted: PackedStringArray = only.split(",")
		ids = ids.filter(func(card_id: Variant) -> bool: return wanted.has(str(card_id)))
	var selected: String = OS.get_environment("PLA03_FACE_IDS")
	if not selected.is_empty():
		ids.clear()
		for id: String in selected.split(",", false):
			if not GameData.cards().has(id):
				push_error("unknown proof card %s" % id)
				_failed = true
			else:
				ids.append(id)
	return ids

func _capture_cards(ids: Array, capture_grid: bool = true) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	_viewport.add_child(instance)
	await _settle()
	for card_id: String in ids:
		await _load_combat(instance, [card_id])
		var widget: CardWidget = _find_widget(instance, card_id)
		if widget == null:
			push_error("no hand widget for %s" % card_id)
			_failed = true
			continue
		var entry: Dictionary = {}
		entry["hand"] = await _shoot_face(widget, "hand_%s" % card_id)
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
		else:
			entry["hover"] = await _shoot_face(widget, "hover_%s" % card_id)
		instance.call("_on_card_hover_ended", 0)
		await _settle()
		_manifest[card_id] = entry
	instance.queue_free()
	await _settle()
	if capture_grid:
		for start: int in range(0, ids.size(), GRID_PAGE_SIZE):
			var label: String = "deck_grid" if start == 0 else "deck_grid_%d" % (start / GRID_PAGE_SIZE + 1)
			await _shoot_deck_grid(packed, ids.slice(start, start + GRID_PAGE_SIZE), label)
	if ids.has("serrated_slip"):
		await _capture_slip_preview(packed)

# Every face at the pile/deck reading size, built the way those views build it.
func _shoot_deck_grid(packed: PackedScene, ids: Array, label: String) -> void:
	var instance: Node = packed.instantiate()
	_viewport.add_child(instance)
	await _settle()
	var layer := Control.new()
	layer.size = Vector2(RESOLUTION)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.07, 0.05)
	backdrop.size = Vector2(RESOLUTION)
	layer.add_child(backdrop)
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	canvas.add_child(layer)
	_viewport.add_child(canvas)
	var card_size: Vector2 = PileView.CARD_SIZE
	var grid: Array = []
	for index: int in range(ids.size()):
		var widget: CardWidget = (load("res://scenes/card_widget.tscn") as PackedScene).instantiate()
		widget.configure(str(ids[index]), false, false, true, false, false, true, GameData.card_def(str(ids[index])))
		var slot: Control = instance.call("_scaled_card_slot", widget, card_size)
		slot.position = GRID_ORIGIN + Vector2(index % GRID_COLUMNS, index / GRID_COLUMNS) * (card_size + GRID_GAP)
		layer.add_child(slot)
		grid.append(widget)
	await _settle()
	await create_timer(0.5).timeout
	var cards: Dictionary = {}
	for widget: CardWidget in grid:
		cards[widget.card_id] = _widget_info(widget)
		_check_face(widget, label)
	_manifest[label] = {"card_size": [card_size.x, card_size.y], "cards": cards}
	await _shoot(label)
	canvas.queue_free()
	instance.queue_free()
	await _settle()

func _shoot_face(widget: CardWidget, shot: String) -> Dictionary:
	await _settle()
	var info: Dictionary = _widget_info(widget)
	_check_face(widget, shot)
	await _shoot(shot)
	return info

func _check_face(widget: CardWidget, shot: String) -> void:
	var spec: Dictionary = FaceSpec.faces().get(widget.card_id, {})
	var row_face: bool = spec.is_empty() or bool(spec.get("simple", false)) or FaceSpec.uses_icon_rows(spec) or spec.has("rows")
	var box: Control = widget.get("_summary_icon_box")
	var plan: Dictionary = widget.sentence_face_plan()
	if (row_face and (not plan.is_empty() or box.get_child_count() == 0)) or (not row_face and not bool(plan.get("fits", false))):
		push_error("%s: %s does not show its fitted face" % [shot, widget.card_id])
		_failed = true
	if widget.card_id == "cyclone_seal":
		var copy := PackedStringArray()
		for line: Dictionary in plan.get("lines", []):
			copy.append(str(line["text"]))
		var sentence: String = " ".join(copy)
		_check_proof(plan.get("under", {}).is_empty() and sentence.contains("in {pat:diamond3}") and sentence.contains("in {pat:neighbors}"), shot + ": Cyclone Seal binds both diagrams inline")

func _capture_light_vision_previews() -> void:
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(instance)
	await _settle()
	var enemies: Array = [
		{"id": 1, "type": "crawler", "pos": LIGHT_EDGE_ENEMY, "hp": 14, "max_hp": 14},
		{"id": 2, "type": "crawler", "pos": VISION_HIDDEN_ENEMY, "hp": 14, "max_hp": 14},
	]
	await _load_combat(instance, ["prism_sight"], enemies, [], false, [], {}, [], false, "clear", LIGHT_CENTER)
	instance.call("_on_turn_order_enemy_hovered", LIGHT_EDGE_ENEMY, "enemy_1")
	await _settle()
	var board: Control = instance.get("board_view")
	var presentation: Dictionary = board.get("presentation")
	var threats: Array = presentation.get("enemy_threat_previews", [])
	var forecast: bool = threats.any(func(threat: Dictionary) -> bool:
		return threat.get("enemy_key") == "enemy_1" and int(threat.get("light_start_expose", 0)) == 2)
	var lit: bool = (presentation.get("umbra_light_sources", []) as Array).any(func(source: Dictionary) -> bool:
		return source.get("pos") == LIGHT_CENTER and int(source.get("remaining_activations", 0)) == -1)
	var board_row: bool = false
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("key", "")) != "enemy_1": continue
		var rows: Array = board.call("_enemy_intent_rows_for_display", unit, unit.get("intent", {}))
		for row: Array in rows:
			if row.any(func(token: Dictionary) -> bool: return token.get("icon") == "expose" and int(token.get("value", 0)) == 2):
				board_row = true
	var order: Array = instance.call("_turn_order_entries_from_state", instance.get("_combat_state"))
	var rail: bool = order.any(func(entry: Dictionary) -> bool:
		return int(entry.get("enemy_id", -1)) == 1 and int(entry.get("light_start_expose", 0)) == 2)
	var paints_in_clear: bool = presentation.get("umbra_stage") == "clear" and LayerRedraws.world_has_paint(presentation)
	_check_proof(forecast and lit and rail and board_row and paints_in_clear, "Light radius and Expose 2 agree in the rail and board forecast, including in a Clear room")
	_manifest["light_expose_preview"] = {"board_expose": forecast, "intent_row": board_row, "lasting_source": lit, "rail_expose": rail, "paints_in_clear": paints_in_clear}
	await _shoot("light_expose_preview")

	instance.call("_on_turn_order_enemy_unhovered", LIGHT_EDGE_ENEMY, "enemy_1")
	await _load_combat(instance, ["prism_sight"], enemies, [], false, [], {}, [], false, "eclipse")
	instance.call("_on_card_hover_started", 0)
	await _settle()
	await create_timer(0.8).timeout
	var widget: CardWidget = _find_widget(instance, "prism_sight")
	var state: Dictionary = instance.get("_combat_state")
	var engine := CombatEngine.new()
	var after: Dictionary = engine._apply_umbra_vision(state.duplicate(true), GameData.card_def("prism_sight")["actions"][0])
	presentation = board.get("presentation")
	var concealed: bool = not (presentation.get("visible_enemy_ids", []) as Array).has(2)
	var reveals_on_play: bool = engine.visible_enemy_ids(after).has(2)
	var ground_unchanged: bool = engine.umbra_visible_tiles(state) == engine.umbra_visible_tiles(after)
	_check_proof(widget != null and widget.get_global_transform_with_canvas().get_scale().x > 1.0 and concealed and reveals_on_play and ground_unchanged,
		"Hover keeps hidden enemies private, and Vision reveals them on play without lighting tiles")
	_manifest["vision_hover_preview"] = {"concealed_before_play": concealed, "revealed_on_play": reveals_on_play, "ground_unchanged": ground_unchanged}
	await _shoot("vision_hover_preview")
	instance.queue_free()
	await _settle()

func _widget_info(widget: CardWidget) -> Dictionary:
	var xform: Transform2D = widget.get_global_transform_with_canvas()
	var origin: Vector2 = xform.origin
	var corner: Vector2 = xform * widget.size
	var plan: Dictionary = widget.sentence_face_plan()
	var lines: Array = []
	for line: Dictionary in plan.get("lines", []):
		lines.append(str(line["text"]))
	return {
		"size": [widget.size.x, widget.size.y],
		"scale": [xform.get_scale().x, xform.get_scale().y],
		"rotation": xform.get_rotation(),
		"origin": [origin.x, origin.y],
		"corner": [corner.x, corner.y],
		"details_rect": _screen_rect(widget.get("details_panel") as Control),
		"art_rect": _screen_rect(widget.get("art_frame") as Control),
		"rows_rect": _screen_rect(widget.get("_summary_icon_box") as Control),
		"face": {"lend": plan.get("lend", null), "text_size": plan.get("text_size", null), "wrap_width": plan.get("wrap_width", null),
			"under_scale": plan.get("under_scale", null), "fits": plan.get("fits", null), "height": plan.get("height", null), "lines": lines},
	}

func _screen_rect(control: Control) -> Array:
	if control == null:
		return []
	var xform: Transform2D = control.get_global_transform_with_canvas()
	var a: Vector2 = xform.origin
	var b: Vector2 = xform * control.size
	return [a.x, a.y, b.x, b.y]

func _capture_slip_preview(packed: PackedScene) -> void:
	var instance: Node = packed.instantiate()
	_viewport.add_child(instance)
	await _settle()
	await _load_combat(instance, ["serrated_slip"], [
		{"id": 1, "type": "crawler", "pos": SLIP_TARGET, "hp": SLIP_TARGET_HP, "max_hp": SLIP_TARGET_HP,
			"block": SLIP_TARGET_BLOCK, "expose": SLIP_TARGET_EXPOSE},
	], [], false)
	await instance._on_card_pressed(0)
	await _settle()
	instance.call("_on_board_tile_hovered", SLIP_TARGET)
	await _settle()
	var board: Node = instance.get("board_view")
	var preview: Dictionary = board.call("_damage_preview_map")
	var loss: Dictionary = preview.get("enemy_1", {})
	var attack: Dictionary = GameData.card_def("serrated_slip")["actions"][1]
	var expected: int = int(attack["damage"]) + int(attack["state_bonus"][0]["damage"]) + SLIP_TARGET_EXPOSE
	if int(loss.get("block_loss", 0)) != SLIP_TARGET_BLOCK or int(loss.get("hp_loss", 0)) != expected - SLIP_TARGET_BLOCK:
		push_error("Serrated Slip's hover forecast did not show the combined %d damage: %s" % [expected, loss])
		_failed = true
	_manifest["serrated_slip_preview"] = {"expected_damage": expected, "loss": loss}
	await _shoot("serrated_slip_preview")
	instance.queue_free()
	await _settle()

# ------------------------------------------------------------- Burst previews

## pla-04: the three non-card Burst previews on the real board.
func _capture_burst_previews() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	_viewport.add_child(instance)
	await _settle()
	# An Ember Tick's death Burst: Pyroclasm hovered on the tick is lethal, so
	# the board shows the cross its Burst hits (a crawler stands in it).
	await _load_combat(instance, ["pyroclasm"], [
		{"id": 1, "type": "ember_tick", "pos": Vector2i(3, 4), "hp": 6, "max_hp": 6, "block": 0},
		{"id": 2, "type": "crawler", "pos": Vector2i(4, 4), "hp": 14, "max_hp": 14, "block": 0},
	], [], false)
	await _shoot_hovered(instance, Vector2i(3, 4), "burst_death_preview")
	# Vyraketh's Crownfire: each marked Fire Bursts in a cross.
	var vyraketh: Dictionary = {"id": 1, "type": "vyraketh", "pos": Vector2i(4, 2), "hp": 52, "max_hp": 52, "block": 0,
		"cinder_tiles": [Vector2i(2, 5), Vector2i(5, 5)], "cinder_detonation_pending": true}
	for intent: Dictionary in GameData.enemy_def("vyraketh").get("intents", []):
		if str(intent.get("id", "")) == "crownfire":
			vyraketh["intent"] = intent.duplicate(true)
	await _load_combat(instance, ["brace"], [vyraketh], [], false, [Vector2i(2, 5), Vector2i(5, 5)])
	await _shoot_hovered(instance, Vector2i(4, 2), "burst_crownfire_preview", false)
	var tharokh: Dictionary = {"id": 1, "type": "tharokh", "pos": Vector2i(4, 2), "hp": 52, "max_hp": 52, "block": 0}
	for intent: Dictionary in GameData.enemy_def("tharokh").get("intents", []):
		if str(intent.get("id", "")) == "faultline":
			tharokh["intent"] = intent.duplicate(true)
	await _load_combat(instance, ["brace"], [tharokh], [
		{"id": "worldspine_probe", "pos": Vector2i(3, 4), "kind": "crag_outcrop", "hp": 4, "max_hp": 4, "owner_kind": "enemy", "owner_id": 1},
	], false)
	await _shoot_hovered(instance, Vector2i(4, 2), "burst_faultline_preview", false)
	# A powder keg next to you: the hovered shot breaks it and its Burst hits you.
	await _load_combat(instance, ["pyroclasm"], [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 14, "max_hp": 14, "block": 0},
	], [{"id": "keg_probe", "pos": Vector2i(3, 4), "kind": "powder_keg", "hp": 3, "max_hp": 3, "burst_damage": 6, "owner_kind": "player", "blocks_sight": false, "surface_on_destroy": ""}], false)
	await _shoot_hovered(instance, Vector2i(3, 4), "burst_keg_preview")
	instance.queue_free()
	await _settle()

func _capture_burst_review() -> void:
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(instance)
	await _settle()
	await _load_combat(instance, ["pyroclasm"], [
		{"id": 1, "type": "crawler", "pos": BURST_REVIEW_TARGET, "hp": BURST_REVIEW_ENEMY_HP, "max_hp": BURST_REVIEW_ENEMY_HP, "block": 0},
	], [], false, [BURST_REVIEW_TARGET], {"hp": BURST_REVIEW_HERO_HP, "relics": ["crown_of_surplus"]})
	await instance._on_card_pressed(0)
	await instance._toggle_pending_empower()
	var hover: Dictionary = await _shoot_hovered(instance, BURST_REVIEW_TARGET, "empowered_pyroclasm_burst", false)
	var preview: Dictionary = hover["damage_preview"]
	_check_proof(preview.get("player", {}).get("lethal", false) and preview.get("player", {}).get("hp_loss", 0) == BURST_REVIEW_HERO_HP, "Empowered Pyroclasm hover shows lethal self-damage")
	var cross: Array[Vector2i] = BurstRules.cross(instance.get("_combat_state"), BURST_REVIEW_TARGET)
	var focus: Array = hover["focus_tiles"]
	_check_proof(cross.size() == 5 and focus.size() == 5 and cross.all(func(tile: Vector2i) -> bool: return focus.has(tile)), "Empowered Pyroclasm hover shows exactly the five Burst tiles")
	await _load_combat(instance, ["shattered_reflection"], [], [], false)
	instance.call("_on_card_hover_started", 0)
	await _settle()
	var widget: CardWidget = _find_widget(instance, "shattered_reflection")
	var chip: Control = widget.find_child("ChipTarget", true, false) if widget != null else null
	var tooltip: String = widget.call("_tooltip_for_icon_at", chip.get_global_rect().get_center()) if chip != null else ""
	_check_proof(tooltip == PanelText.copy("unchanged_choose_a_tile_within_this_range")["tooltip"], "Shattered Reflection's live Range chip uses the tile tooltip")
	instance.call("_show_card_focus_tooltips", 0)
	await _settle()
	_check_proof(instance.get("_card_focus_tooltip_stack").visible, "Shattered Reflection shows its live tooltip stack")
	_manifest["shattered_reflection_range"] = {"tooltip": tooltip}
	await _shoot("shattered_reflection_range")
	instance.queue_free()
	await _settle()

func _capture_rollout_review() -> void:
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(instance)
	await _settle()
	var engine := CombatEngine.new()
	var board: Control = instance.get("board_view")
	for fixture: String in ["frost_heave", "shatter", "icebound_chains", "discharge", "shatter_footprint"]:
		var is_footprint: bool = fixture == "shatter_footprint"
		var card: String = "shatter" if is_footprint else fixture
		var is_chains: bool = card == "icebound_chains"
		var is_discharge: bool = card == "discharge"
		var target := Vector2i(3, 4) if is_discharge else Vector2i(4 if is_chains else 5, 4)
		var enemy_tile := Vector2i(5, 5) if is_discharge else target
		var ground: Dictionary = {"vision_duration": 2, "electrified": [target, target + Vector2i.RIGHT, target + Vector2i.RIGHT * 2]} if is_discharge else {"vision_duration": 2}
		var enemies: Array = [{"id": 1, "type": "crawler", "pos": enemy_tile, "hp": BURST_REVIEW_ENEMY_HP, "max_hp": BURST_REVIEW_ENEMY_HP}]
		var ice: Array = [] if is_discharge else [target]
		var stage: String = "eclipse" if is_chains or is_discharge else "heart"
		if is_footprint:
			ice = [target + Vector2i.DOWN]
			enemies[0]["footprint"] = Vector2i(2, 2)
			stage = "clear"
		await _load_combat(instance, [card], enemies, [], false, [], {}, ice, false, stage, Vector2i(-1, -1), ground)
		var state: Dictionary = instance.get("_combat_state")
		if not is_footprint:
			_check_proof(engine.is_enemy_visible_to_player(state, state["enemies"][0]) and not engine.is_tile_visible_to_player(state, enemy_tile), card + " reveals the enemy on concealed ground")
		await instance._on_card_pressed(0)
		instance.call("_on_board_tile_hovered", target)
		await _settle()
		var expected: int = {"frost_heave": 9, "shatter": 10, "icebound_chains": 5, "discharge": 5}[card]
		var hp_loss: int = int(board.call("_damage_preview_map").get("enemy_1", {}).get("hp_loss", 0))
		_check_proof(hp_loss == expected, "%s hover shows %d damage" % [card, expected])
		if is_footprint:
			var events: Array = board.get("presentation").get("surface_preview_events", [])
			_check_proof(events.any(func(event: Dictionary) -> bool: return event.get("burst_sources") == ice), "Shatter previews the source under the aimed enemy's footprint")
		await _shoot("review_%s_hover" % fixture)
		# A normal last target click auto-plays. Stage its completed prefix
		# directly to capture the confirmation presentation before payment.
		var actions: Array = instance.get("_pending_actions")
		var selected: Dictionary = engine.apply_player_action(instance.get("_preview_combat_state"), actions[0], target)
		var targets: Array[Vector2i] = [target]
		instance.set("_pending_selected_targets", targets)
		instance._load_pending_preview_state(instance._card_preview_from_state(card, selected, actions, 1))
		instance._refresh_card_preview_ui()
		await _settle()
		_check_proof(instance._pending_card_requires_confirmation(), card + " reached confirmation")
		var loss: int = int(board.call("_damage_preview_map").get("enemy_1", {}).get("hp_loss", 0))
		var forecast: Dictionary = instance._pass_preview_source_state()
		var rail_loss: int = BURST_REVIEW_ENEMY_HP - int(engine._surface_actor(forecast, "enemy", 1).get("hp", 0))
		var stagger: int = int(instance._turn_order_stagger_preview_delays().get(1, 0))
		_check_proof(loss == expected and rail_loss == expected and (not is_chains or stagger == 6), card + " confirmation and forecast agree")
		_manifest[fixture] = {"hover_hp_loss": hp_loss, "confirmation_hp_loss": loss, "forecast_hp_loss": rail_loss, "stagger_chip": stagger}
		await _shoot("review_%s_confirm" % fixture)
	for card: String in ["sun_flash", "hoarfrost_ward", "shatter"]:
		var pierce: bool = card == "shatter"
		var expected_block: int = 9 if card == "hoarfrost_ward" else 8
		var player: Dictionary = {"relics": ["sunlit_edge" if pierce else "reinforced_shield"]}
		var ground: Dictionary = {"stoneskin": 1}
		var light: Vector2i = Vector2i(2, 4) if pierce else Vector2i(-1, -1)
		await _load_combat(instance, [card], [], [], false, [], player, [], false, "clear", light, ground)
		var widget: CardWidget = _find_widget(instance, card)
		var shown: bool = false
		if widget != null:
			for row: Array in widget.display_summary_rows():
				shown = shown or row.any(func(token: Dictionary) -> bool:
					return token.get("icon") == "pierce" if pierce else token.get("icon") == "block" and int(token.get("value", 0)) == expected_block)
		_check_proof(shown, card + " shows the active relic on its live face")
		var shot: String = "review_%s_relic" % card
		_manifest[shot] = {"modifier_visible": shown}
		await _shoot(shot)
	instance.queue_free()
	await _settle()

func _check_proof(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error(message)

# ------------------------------------------------------------- Ice previews

## pla-06: simple Ice cards keep icon rows; their rows gain "on Ice: Stagger 6".
func _capture_ice_previews() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	_viewport.add_child(instance)
	await _settle()
	for card_id: String in FaceSpec.faces():
		if not bool((FaceSpec.faces()[card_id] as Dictionary).get("simple", false)):
			continue
		await _load_combat(instance, [card_id])
		var widget: CardWidget = _find_widget(instance, card_id)
		if widget == null:
			push_error("no hand widget for %s" % card_id)
			_failed = true
			continue
		if not widget.sentence_face_plan().is_empty() or widget.display_summary_rows().is_empty():
			push_error("%s must use its icon rows" % card_id)
			_failed = true
		_manifest["rows_" + card_id] = ActionIcons.plain_text_for_rows(widget.display_summary_rows())
		await _shoot("rows_%s" % card_id)
	# A hovered move onto Ice: the hero's plate previews Expose 2.
	await _load_combat(instance, ["flowing_step"], [
		{"id": 1, "type": "crawler", "pos": Vector2i(5, 2), "hp": 14, "max_hp": 14, "block": 0},
	], [], false, [], {}, [ICE_MOVE_TILE])
	var tile_entries: Array[Dictionary] = BoardTileTooltip.entries(instance.get("board_view"), ICE_MOVE_TILE)
	_check_proof(tile_entries.any(func(entry: Dictionary) -> bool: return entry.get("icon") == "surface_ice" and entry.get("description") == Glossary.definition("surface_ice")), "The live Ice tile tooltip uses the approved Expose copy")
	await _shoot_hovered(instance, ICE_MOVE_TILE, "ice_move_preview")
	var predicted: Variant = JSON.parse_string(str((_manifest["ice_move_preview"] as Dictionary).get("status_preview", "{}")))
	if typeof(predicted) != TYPE_DICTIONARY or int(((predicted as Dictionary).get("player", {}) as Dictionary).get("expose", 0)) != 2:
		push_error("the move onto Ice does not preview the hero's Expose 2: %s" % str(predicted))
		_failed = true
	# An enemy that starts its turn on Ice: the engine's turn start Exposes it 2.
	await _load_combat(instance, ["brace"], [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 14, "max_hp": 14, "block": 0},
	], [], false, [], {}, [Vector2i(4, 4)], true)
	var enemy: Dictionary = ((instance.get("_combat_state") as Dictionary).get("enemies", []) as Array)[0] as Dictionary
	_manifest["ice_enemy_turn_start"] = {"expose": int(enemy.get("expose", 0)), "pos": [Vector2i(4, 4).x, Vector2i(4, 4).y]}
	if int(enemy.get("expose", 0)) != 2:
		push_error("the enemy that started its turn on Ice has Expose %d, expected 2" % int(enemy.get("expose", 0)))
		_failed = true
	await _shoot("ice_enemy_turn_start")
	await _check_ice_spill_tooltip(instance)
	instance.queue_free()
	await _settle()

func _check_ice_spill_tooltip(instance: Node) -> void:
	await _load_combat(instance, ["frostbolt"], [], [], true, [], {"relics": ["rimecatcher_vial"]})
	await instance._on_card_pressed(0)
	var commands: Control = instance.get("_action_context_command_bar")
	var copy: String = InlineIconText.plain_text(str(GameData.relic_def("rimecatcher_vial")["description"]))
	for child: Node in commands.get_children():
		if child is Button and (child as Button).text.begins_with("Spill Ice"):
			_check_proof((child as Button).tooltip_text == copy, "The Spill Ice command uses the approved Rimecatcher Vial copy")
			return
	_check_proof(false, "The Ice attack exposes the Spill Ice command")

func _shoot_hovered(instance: Node, tile: Vector2i, shot: String, select_card: bool = true) -> Dictionary:
	if select_card:
		await instance._on_card_pressed(0)
		await _settle()
	instance.call("_on_board_tile_hovered", tile)
	await _settle()
	await create_timer(0.6).timeout
	await _settle()
	var board: Node = instance.get("board_view")
	var preview: Dictionary = board.call("_damage_preview_map") if board != null and board.has_method("_damage_preview_map") else {}
	var presentation: Dictionary = board.get("presentation") if board != null else {}
	var focus: Array = presentation.get("focus_tiles", [])
	var status_preview: Dictionary = presentation.get("surface_status_preview", {})
	_manifest[shot] = {
		"tile": [tile.x, tile.y],
		"damage_preview": JSON.stringify(preview),
		"focus_tiles": focus.size(),
		"status_preview": JSON.stringify(status_preview),
		"attack_tiles": (board.get("attack_tiles") as Array).size() if board != null and board.get("attack_tiles") is Array else -1,
	}
	await _shoot(shot)
	instance.call("_on_board_tile_hovered", Vector2i(-1, -1))
	instance.call("_reset_card_resolution")
	await _settle()
	return {"damage_preview": preview, "focus_tiles": focus}

func _load_combat(instance: Node, hand: Array, enemies: Array = [], terrain: Array = [], face_ground: bool = true, fire: Array = [], player_overrides: Dictionary = {}, ice: Array = [], enemy_turn_start: bool = false, stage: String = "clear", light_center: Vector2i = Vector2i(-1, -1), ground_fixture: Dictionary = {}) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = {
		"name": "Cinder Crossing",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"umbra_stage": stage,
		"player_start": Vector2i(2, 4),
		"enemies": enemies.duplicate(true) if not enemies.is_empty() else [
			{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 14, "max_hp": 14, "block": 0},
			{"id": 2, "type": "crawler", "pos": Vector2i(3, 2), "hp": 14, "max_hp": 14, "block": 0},
			{"id": 3, "type": "crawler", "pos": Vector2i(5, 3), "hp": 14, "max_hp": 14, "block": 0},
		],
		"traps": [],
		"terrain": [],
		"loot": [],
	}
	var combat := CombatEngine.new()
	var player: Dictionary = {
		"hp": 24, "max_hp": 24, "deck_cards": hand.duplicate(), "relics": [], "hand_size": hand.size(), "heal_bonus": 0,
	}
	player.merge(player_overrides, true)
	var combat_state: Dictionary = combat.create_combat(73101, layout, player)
	if light_center.x >= 0:
		combat_state = combat._create_umbra_light_source(combat_state, light_center, {"radius": 2, "silent": true})
	if ground_fixture.has("stoneskin"):
		combat_state["player"]["stoneskin"] = int(ground_fixture["stoneskin"])
	for tile: Vector2i in ground_fixture.get("electrified", []):
		BoardSurfaceRules.place(combat_state, tile, "electrified")
	if ground_fixture.has("vision_duration"):
		combat_state = combat._apply_umbra_vision(combat_state, {"duration": int(ground_fixture["vision_duration"])})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["traps"] = []
	combat_state["terrain"] = terrain.duplicate(true)
	combat_state["log"] = []
	for index: int in range(enemies.size()):
		# create_combat rolls intents; a probe enemy with an authored intent keeps it.
		var authored: Dictionary = enemies[index]
		for key: String in ["intent", "cinder_tiles", "cinder_detonation_pending", "expose", "block", "footprint"]:
			if authored.has(key):
				(combat_state["enemies"][index] as Dictionary)[key] = authored[key].duplicate(true) if typeof(authored[key]) in [TYPE_DICTIONARY, TYPE_ARRAY] else authored[key]
	if face_ground:
		BoardSurfaceRules.place(combat_state, Vector2i(3, 5), "rubble")
		BoardSurfaceRules.place(combat_state, Vector2i(3, 2), "ice")
		for tile: Vector2i in [Vector2i(4, 5), Vector2i(5, 5), Vector2i(5, 4)]:
			BoardSurfaceRules.place(combat_state, tile, "electrified")
	for tile: Vector2i in fire:
		BoardSurfaceRules.place(combat_state, tile, "fire")
	for tile: Vector2i in ice:
		BoardSurfaceRules.place(combat_state, tile, "ice")
	if enemy_turn_start:
		# pla-06: resolve the first enemy's real activation start on its Ice.
		combat_state = combat._resolve_enemy_start_of_turn(combat_state, 0)["state"]
		combat_state["current_actor"] = {"kind": "player", "key": "player"}
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
	run_state["relics"] = player["relics"]
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
	if _dry_run:
		print("DRY SHOT %s" % shot)
		return
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
