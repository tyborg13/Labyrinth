extends SceneTree

# Windowed proof at the required native size. --check-only constructs the exact
# same combat states and copy witnesses without touching the window server.
const Fixture = preload("res://tests/helpers/marked_fixture.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Contract = preload("res://tests/suites/mrk01_marked_suite.gd")
const Proof = preload("res://tests/helpers/txt08_combat_proof.gd")
const MarkedStrike = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const WarbandRules = preload("res://scripts/warband_combat_rules.gd")
const Facing = preload("res://scripts/hero_facing_state.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const LoopContext = preload("res://scripts/tooltip_loop_context.gd")
const LoopCapture = preload("res://tools/txt13/clip_capture.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const OUTPUT_DIR: String = "user://mrk01_marked_probe"
const VIEWPORT_SIZE := Proof.VIEWPORT_SIZE
const CAPTURE_SEED: int = 20261012
# Debug-only tooltip position; production panel, copy and typography are reused.
const PROOF_TOOLTIP_POSITION := Vector2(48, 160)
const EXPECTED_COMBAT_CASES: int = 9
const TXT08_EXPECTED_CASES: int = 4
const CAP07_EXPECTED_CASES: int = 2
const TXT09_EXPECTED_CASES: int = 4
const FADE_PROOF_DIRECTION := Vector2i.RIGHT
const FADE_TOOLTIP: String = "Blinks behind you, then Ambushes next turn."
# txt-13 approved move copy and diagram order are recorded in tools/txt13/shape_words.md.
const BARRAGE_TOOLTIP: String = "@pattern(cross:hero) @pattern(cross) On your tile and 2 tiles away. Next turn they take the hit and become Fire."
const BARRAGE_ROW: Array = ["aoe_pattern", "aoe_pattern", "marked", "aoe", "surface_fire"]
const BARRAGE_DAMAGE_INDEX: int = 3
const BARRAGE_LOOP_ID: String = "lob_slagmaster_barrage"
const HUNTED_TOOLTIP: String = "Each normal combat gets one more enemy, up to 5; if it can't, its enemies get +20% Health."
const PROOF_SHUTDOWN_DRAIN_SECONDS: float = 0.5
var _engine := Combat.new()
var _failed: bool = false
var _check_only: bool = false
var _txt08_only: bool = false
var _cap07_only: bool = false
var _txt09_only: bool = false
var _canvas: SubViewport
var _capture_dir: String = OUTPUT_DIR
var _witnesses: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_cap07_only = OS.get_cmdline_user_args().has("--cap07-only")
	_txt09_only = OS.get_cmdline_user_args().has("--txt09-only")
	_txt08_only = _cap07_only or _txt09_only or OS.get_cmdline_user_args().has("--txt08-only")
	_check_only = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--check-only")
	if _check_only:
		for key: String in Contract.MOVE_COPY:
			if preload("res://scripts/action_icon_library.gd").description(key) != Contract.MOVE_COPY[key]: _failed = true
		if Grimoire.entry_def("keyword:marked").is_empty(): _failed = true
	_capture_dir = OUTPUT_DIR.path_join(str(int(Time.get_unix_time_from_system())))
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Store.set_storage_path("user://mrk01-probe-profile.json")
	Store.set_run_storage_path("user://mrk01-probe-run.save")
	var profile: Dictionary = Store.default_data()
	profile["ui_scale"] = 1.0
	Store.save_data(profile)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	_capture.call_deferred()

func _cases() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for type: String in Contract.MARK_IDS:
		var state: Dictionary = Fixture.fixture(_engine, type, CAPTURE_SEED)
		state["enemies"][0]["intent"] = Fixture.intent(type, Contract.MARK_IDS[type])
		result.append({"name": type + "_01_aim", "state": state.duplicate(true)})
		state = _engine.resolve_enemy_turn_with_steps(state, 0)["state"]
		result.append({"name": type + "_02_marked", "state": state.duplicate(true)})
		state = _engine.resolve_enemy_turn_with_steps(state, 0)["state"]
		result.append({"name": type + "_03_after", "state": state.duplicate(true)})
	if not _txt08_only: return result
	var affected: Array[Dictionary]
	for case: Dictionary in result:
		match str(case["name"]):
			"slag_mortar_01_aim": case["expected_tooltip"] = Contract.MOVE_COPY["lob"]
			"burrow_grub_02_marked": case["expected_tooltip"] = Contract.MOVE_COPY["erupt"]
			_: continue
		affected.append(case)
	affected.append_array(_cap07_cases())
	return affected

func _cap07_cases() -> Array[Dictionary]:
	var fade: Dictionary = Proof.fade_run(Store.default_data())
	var barrage: Dictionary = Proof.barrage_run(Store.default_data())
	fade["combat_state"][Facing.KEY] = Facing.direction(FADE_PROOF_DIRECTION, Facing.FRONT)
	return TypedArrays.dictionaries([
		{"name": "gloam_stalker_fade", "run": fade, "expected_tooltip": FADE_TOOLTIP},
		{"name": "slagmaster_barrage", "run": barrage, "expected_tooltip": BARRAGE_TOOLTIP},
	])

func _txt09_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = _cap07_cases()
	var engine := Run.new()
	var base: Dictionary = engine.create_new_run(CAPTURE_SEED, Store.default_data())
	var erupt: Dictionary = Fixture.fixture(_engine, "burrow_grub", CAPTURE_SEED, engine._player_snapshot(base))
	erupt["enemies"][0]["intent"] = Fixture.intent("burrow_grub", "burrow")
	erupt = _engine.resolve_enemy_turn_with_steps(erupt, 0)["state"]
	cases.append({"name": "erupt_move", "run": _marked_run(erupt), "expected_tooltip": Contract.MOVE_COPY["erupt"]})
	var hunted: Dictionary = Omens.add(base, "hunted")
	for room: Dictionary in hunted["rooms"].values():
		if room.get("type") != "combat": continue
		hunted["current_room"] = room["coord"]
		hunted["mode"] = "pre_battle"
		break
	hunted = engine.begin_pre_battle_combat(hunted)
	cases.append({"name": "hunted_bane", "run": hunted})
	return cases

func _capture() -> void:
	await process_frame
	_canvas = Proof.viewport(self)
	var scene: Control = RUN_SCENE.instantiate()
	_canvas.add_child(scene)
	await Proof.settle(self)
	var cases: Array[Dictionary]
	var expected_count: int
	if _txt09_only:
		cases = _txt09_cases()
		expected_count = TXT09_EXPECTED_CASES
	elif _cap07_only:
		cases = _cap07_cases()
		expected_count = CAP07_EXPECTED_CASES
	else:
		cases = _cases()
		expected_count = TXT08_EXPECTED_CASES if _txt08_only else EXPECTED_COMBAT_CASES
	_expect(cases.size() == expected_count, "Probe has the expected set of combat cases")
	for case: Dictionary in cases:
		var name: String = case["name"]
		var run: Dictionary = case.get("run", {})
		if run.is_empty():
			run = _marked_run(case["state"])
		scene._load_run_state(run)
		scene._close_dialogue()
		await Proof.settle(self)
		if name == "hunted_bane":
			await _capture_hunted(scene, run, name)
			continue
		var board: Control = scene.board_view
		var battle: Dictionary = board.combat_state
		var enemy: Dictionary = battle["enemies"][0]
		var actor_key: String = "enemy_%d" % int(enemy["id"])
		if case.has("run"):
			scene._on_board_tile_clicked(enemy["pos"])
			await process_frame
			await process_frame
			_expect(int(scene.get("_focused_intent_enemy_id")) == int(enemy["id"]), name + " opens the enemy intent inspection")
		var tip: String = board.enemy_intent_tooltip(actor_key)
		var move_row: Array = []
		var is_barrage: bool = name == "slagmaster_barrage"
		if case.has("expected_tooltip"):
			_expect(tip == case["expected_tooltip"], "Unexpected tooltip for %s: %s" % [name, tip])
		_expect(is_equal_approx(Typography.ui_scale(scene), 1.0), "Proof uses 100% UI scale")
		if case.has("run"):
			Proof.check_fight(scene, run, name, _expect)
			var intent_rect: Rect2 = board.enemy_intent_visual_global_rect(actor_key)
			_expect(intent_rect.has_area() and _canvas.get_visible_rect().encloses(intent_rect), name + " enemy intent is in frame")
			if is_barrage:
				var forecast: Dictionary = MarkedStrike.aiming_forecast(_engine, battle, enemy)
				var centers: Array = forecast.get("centers", [])
				var tiles: Array = forecast.get("tiles", [])
				_expect(centers.size() == 2 and centers[0] == battle["player"]["pos"] and tiles.size() == Proof.FULL_BARRAGE_TILE_COUNT, "Slagmaster forecasts two full crosses, including the hero's tile")
				var landing: Dictionary = MarkedStrike.landing_action(_engine, battle, enemy)
				move_row = _check_move_row(board, actor_key, BARRAGE_ROW, {BARRAGE_DAMAGE_INDEX: str(landing["center_damage"])})
				var diagrams: Array = move_row.map(func(token: Dictionary) -> String: return str(token.get("diagram_markup", "")))
				_expect(diagrams.slice(0, 2) == ["@pattern(cross:hero)", "@pattern(cross)"], "Slagmaster shows the hero-centered diagram before the second cross")
				if move_row.size() > BARRAGE_DAMAGE_INDEX:
					var damage_detail: String = "%d in each center, %d around them." % [landing["center_damage"], landing["arm_damage"]]
					_expect(move_row[BARRAGE_DAMAGE_INDEX].get("tooltip") == damage_detail, "Slagmaster damage detail uses both resolved numbers")
				var order: String = WarbandRules.order_line(battle["objective"]).trim_prefix("Order: ")
				_expect(not order.is_empty() and Proof.contains_label(scene.get("_battlefield_rule_hud"), order, _canvas.get_visible_rect()), "Slagmaster Order is visible on the separate battlefield panel")
			elif name == "erupt_move":
				var damage: int = int(enemy["intent"]["actions"][0]["damage"])
				_check_move_row(board, actor_key, ["erupt", "push", "surface_rubble", "expose"], {0: str(damage), 1: "1", 3: "2"})
			elif name == "gloam_stalker_fade":
				var hero: Vector2i = battle["player"]["pos"]
				var behind: Vector2i = hero - FADE_PROOF_DIRECTION
				var engine: RefCounted = scene.get("_combat_engine")
				var shown: Dictionary = board.presentation.get("protagonist_motion", {}).get(Facing.KEY, {})
				_expect(Facing.valid(shown) and Facing.tile_direction(shown) == FADE_PROOF_DIRECTION, "Fade hero sprite faces away from the Stalker")
				_expect((enemy["pos"] as Vector2i).y == hero.y and (enemy["pos"] as Vector2i).x < behind.x, "Fade proof places the Stalker behind a free preferred tile")
				_expect(engine.enemy_intent_plan(battle, 0)["destination"] == behind, "Fade plans to use the free tile behind the hero")
		if is_barrage and _txt08_only and not _cap07_only and not _txt09_only and not _check_only and not _failed:
			await Proof.capture(scene, _capture_dir.path_join("slagmaster_barrage_move_row.png"), _expect)
		var panel: Control
		var loop: Control
		if is_barrage:
			# Build the same source-aware panel as the production move-title hover.
			var title: String = board._intent_display_name(enemy["intent"])
			panel = LoopContext.panel_for_text(title + "\n" + tip, LoopContext.enemy_unit(enemy))
			loop = panel.find_child("TooltipLoopWindow", true, false) as Control if panel != null else null
			_expect(loop != null and loop.get_meta("tooltip_loop_id", "") == BARRAGE_LOOP_ID, "Slagmaster tooltip uses its approved barrage loop")
		else:
			panel = board._make_custom_tooltip(tip)
		if panel != null:
			# The root canvas is under the opaque board backdrop; use the UI canvas.
			scene.ui_root.add_child(panel)
			panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
			panel.position = PROOF_TOOLTIP_POSITION
		await process_frame
		await process_frame
		if case.has("expected_tooltip"):
			var approved_line: String = str(case["expected_tooltip"]).get_slice("\n", 0)
			_expect(panel != null and Proof.contains_tooltip_line(panel, approved_line, _canvas.get_visible_rect()), "Tooltip sentence is visible for " + name)
		var witness: Dictionary = {"case": name, "tooltip": tip, "ui_scale": Typography.ui_scale(scene), "intent": enemy["intent"]["id"]}
		if is_barrage:
			witness["move_row"] = Proof.move_row_witness(move_row)
			print("TXT08 SLAGMASTER MOVE ROW: " + JSON.stringify(witness["move_row"]))
		_witnesses.append(witness)
		if not _check_only:
			if loop != null and not _failed:
				_expect(await LoopCapture.seek_middle(self, loop) >= 0.0, "Slagmaster tooltip displays its barrage loop before capture")
			if case.has("run"):
				if not _failed:
					await Proof.capture(scene, _capture_dir.path_join(name + ".png"), _expect)
			else:
				await _save_image(name)
		if panel != null:
			panel.queue_free()
			await process_frame
	if not _txt08_only: await _capture_marked_grimoire(scene)
	var witness_file := FileAccess.open(_capture_dir.path_join("witnesses.json"), FileAccess.WRITE)
	witness_file.store_string(JSON.stringify(_witnesses, "\t") + "\n")
	witness_file.close()
	print("MRK01 WITNESSES: " + ProjectSettings.globalize_path(_capture_dir.path_join("witnesses.json")))
	# Let the production turn-order refresh finish before destroying its owner.
	await create_timer(PROOF_SHUTDOWN_DRAIN_SECONDS).timeout
	await process_frame
	_canvas.queue_free()
	await process_frame
	if _txt09_only: print("TXT09 COMBAT PROBE: %s (%d captures or headless witnesses)" % ["FAIL" if _failed else "PASS", _witnesses.size()])
	elif _txt08_only: print("TXT08 ENEMY TOOLTIP PROBE: %s (%d captures or headless witnesses)" % ["FAIL" if _failed else "PASS", _witnesses.size()])
	elif _check_only: print("MRK01 MARKED PROBE CONTRACT: %s (9 combat states, Marked grimoire, 1920x1080, UI scale 100%%; no PNGs)" % ["FAIL" if _failed else "PASS"])
	else: print("MRK01 MARKED PROBE: %s" % ["FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _check_move_row(board: Control, actor_key: String, expected_icons: Array, numbers: Dictionary) -> Array:
	for unit: Dictionary in board._visible_units():
		if unit.get("key") != actor_key: continue
		var rows: Array = board._enemy_intent_rows_for_display(unit, unit["intent"])
		var row: Array = rows.front() if not rows.is_empty() else []
		var icons: Array = row.map(func(token: Dictionary) -> String: return token["icon"])
		_expect(icons == expected_icons, "Expanded move row shows the approved tokens in order")
		for index: int in numbers:
			_expect(index < row.size() and Icons.token_value_text(row[index]) == numbers[index], "Expanded move row uses the resolved number for " + str(expected_icons[index]))
		return row
	_expect(false, "No visible unit for move row " + actor_key)
	return []

func _capture_hunted(scene: Control, run: Dictionary, name: String) -> void:
	Proof.check_fight(scene, run, name, _expect)
	_expect(run.get("combat_state", {}).get("room_type") == "combat", "Hunted is shown in a normal fight")
	var manager: RefCounted = scene.get("_omen_badges")
	var badge: Control = manager.badges.get("hunted")
	_expect(badge != null, "Production Hunted badge is present")
	if badge == null: return
	badge.grab_focus()
	await process_frame
	await process_frame
	var panel: Control = badge.get("_focus_tooltip")
	_expect(panel != null and Proof.contains_label(panel, HUNTED_TOOLTIP + "\n%d fights left" % int(badge.get("entry")["fights_left"]), _canvas.get_visible_rect()), "Hunted focus tooltip shows the exact cap rule")
	_witnesses.append({"case": name, "tooltip": HUNTED_TOOLTIP, "ui_scale": Typography.ui_scale(scene)})
	if not _check_only and not _failed:
		await Proof.capture(scene, _capture_dir.path_join(name + ".png"), _expect)
	badge.release_focus()

func _marked_run(combat: Dictionary) -> Dictionary:
	var run: Dictionary = Run.new().create_new_run(CAPTURE_SEED, Store.default_data())
	var coord := Vector2i(1, 0)
	var layout: Dictionary = {"name": "Mrk01 Proof", "coord": coord, "depth": 2, "type": "combat", "element": "none", "grid": combat["grid"], "player_start": combat["player"]["pos"], "enemies": combat["enemies"], "terrain": combat.get("terrain", []), "traps": combat.get("traps", []), "loot": []}
	run["rooms"]["1,0"] = {"coord": coord, "depth": 2, "type": "combat", "element": "none", "revealed": true, "visited": true, "connections": [], "npcs": []}
	run.merge({"mode": "combat", "current_room": coord, "current_room_layout": layout, "combat_state": combat, "notice": ""}, true)
	run[Grimoire.UNLOCKED_KEY] = Grimoire.ordered_entry_ids(["keyword:marked"])
	return run

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _capture_marked_grimoire(scene: Control) -> void:
	scene._open_grimoire_overlay()
	scene._on_grimoire_entry_pressed("keyword:marked")
	await process_frame
	await process_frame
	var title: Label = scene.get("_grimoire_detail_title")
	var body: RichTextLabel = scene.get("_grimoire_detail_body")
	# InlineIconText appends the body, so .text stays empty; compare what is shown.
	if title.text != "Marked" or body.get_parsed_text().strip_edges() != Contract.MARKED_DEFINITION or body.get_content_height() > body.size.y + 1.0: _failed = true
	_witnesses.append({"case": "marked_grimoire", "title": title.text, "body": body.get_parsed_text(), "body_height": body.get_content_height(), "available_height": body.size.y})
	await _save_image("marked_grimoire")
	scene._close_grimoire_overlay()

func _save_image(name: String) -> void:
	if _check_only:
		await process_frame
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var captured: Image = _canvas.get_texture().get_image()
	var path: String = _capture_dir.path_join(name + ".png")
	if captured.get_size() != VIEWPORT_SIZE or captured.save_png(path) != OK:
		_failed = true
		push_error("MRK01 capture failed: " + path)
	else: print("MRK01 CAPTURE: " + ProjectSettings.globalize_path(path))
