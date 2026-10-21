extends SceneTree
const TooltipProof = preload("res://tests/suites/empower_seal_tooltip_suite.gd")
const Rules = preload("res://scripts/snare_room_rules.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const RenderProof = preload("res://tests/suites/encounter_tables_suite.gd")
const Fixture = preload("res://tools/snare_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_UI_SCALE: float = 1.0
const OUTPUT: String = "user://probes/spx05/fire_tier2"
const SETTLE_SECONDS: float = 0.25
const READY_TIMEOUT_SECONDS: float = 20.0
const CAPTURE_VISION_BONUS: int = Combat.UMBRA_UNLIMITED_RADIUS
var failures: Array[String]
var captures: Array[Dictionary]
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Snare visual proof requires the native renderer; use tools/visual_probe_runner.py --no-headless")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://spx05-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_UI_SCALE
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	canvas = SubViewport.new()
	canvas.size = PROOF_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.gui_embed_subwindows = true
	root.add_child(canvas)
	canvas.notify_mouse_entered()
	for study: String in ["first_turn", "first_seal", "kept_open", "escape"]: await _case(study)
	var file := FileAccess.open(OUTPUT.path_join("captures.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": PROOF_UI_SCALE, "seed": Fixture.FIXTURE_SEED, "capture_vision_bonus": CAPTURE_VISION_BONUS, "captures": captures, "errors": failures}, "\t"))
	canvas.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("Snare native proof: %d captures, %d failures" % [captures.size(), failures.size()])
	print("Snare captures: " + ProjectSettings.globalize_path(OUTPUT))
	quit(0 if failures.is_empty() else 1)

func _case(study: String) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var state: Dictionary = Fixture.build(engine, combat, engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"snare_biome": "fire", "snare_tier": 2, "snare_case": study})
	var battle: Dictionary = state["combat_state"]
	battle["umbra"]["vision_bonus"] = CAPTURE_VISION_BONUS
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(RenderProof.DrawCheckedBoard)
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await _await_units_drawn(scene.get("board_view"), battle)
	await create_timer(SETTLE_SECONDS).timeout
	var chips: Node = scene.get("board_view").get_node_or_null("SnareSealChips")
	var labels: Array[String]
	if chips != null:
		for chip: Control in chips.get_children():
			if chip.visible:
				labels.append((chip.get_node("Title") as Label).text)
				var plate: Control = chip.get_node("HudPlate/ThemedPanelOrnament")
				_expect(plate.position == Vector2.ZERO and plate.size == chip.size and plate.size.x >= 48 and plate.size.y >= 36, "Native HUD plate occupies a drawable full panel")
	var exits: Array = battle["objective"]["exits"]
	match study:
		"first_turn": _expect(labels == _strings(["Seals · 2", "Seals · 4"]), "Both opening chips")
		"first_seal": _expect(exits[1]["sealed"] and not exits[2]["sealed"] and labels == _strings(["Seals · 2"]), "First seal removes only its chip")
		"kept_open": _expect(exits[1]["kept_open"] and not exits[1]["sealed"] and labels == _strings(["Seals · 2"]), "Killed Sealbinder has no chip and its door remains open")
		"escape": _expect(combat.combat_outcome(battle) == "victory" and combat.snare_escape_context(battle)["doors_open_at_escape"] == 3, "Legal exit step and all-open bonus")
	var facts: Dictionary = {"chips": labels, "exits": exits, "escape": combat.snare_escape_context(battle)}
	await _capture(study, facts)
	if study == "first_turn": await _sealbinder_tooltip(scene, battle, facts)
	if study == "escape": await _escape_reward(scene, engine, state, battle, facts)
	scene.queue_free()
	await process_frame

func _capture(study: String, facts: Dictionary) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_expect(image.get_size() == PROOF_SIZE, "Capture is exactly 1920x1080")
	var path: String = OUTPUT.path_join(study + ".png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_expect(image.save_png(path) == OK, "Capture writes " + path)
	var recorded: Dictionary = facts.duplicate(true)
	recorded.merge({"path": path, "case": study})
	captures.append(recorded)
	print("Snare capture: " + ProjectSettings.globalize_path(path))

func _sealbinder_tooltip(scene: Node, battle: Dictionary, facts: Dictionary) -> void:
	var board: Control = scene.get("board_view")
	var left: Dictionary = {}
	var pointer := Vector2(INF, INF)
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("intent", {}).get("id", "")) != "snare_seal": continue
		var rect: Rect2 = board.call("_unit_draw_rect_for_center", unit, board.call("_unit_center", unit))
		var point: Vector2 = board.get_global_transform_with_canvas() * rect.get_center()
		if point.x < pointer.x:
			pointer = point
			left = unit
	_expect(not left.is_empty(), "Tooltip capture has a left Sealbinder")
	if left.is_empty(): return
	var intent: Dictionary = Rules.seal_intent(battle["objective"], left)
	var expected: String = str(intent["name"]) + "\n" + str(intent["description"])
	await TooltipProof.move_pointer(self, canvas, pointer)
	var popup: Window = await TooltipProof.wait_for_tooltip(self, canvas, expected)
	_expect(canvas.gui_get_hovered_control() == board, "Pointer really hovers the left Sealbinder's board")
	_expect(popup != null, "Actual tooltip shows exact Seal rules and live turns/Embers")
	if popup != null:
		_expect(popup.is_embedded() and canvas.get_embedded_subwindows().has(popup), "Native tooltip is included in the captured viewport")
		var detail: Dictionary = facts.duplicate(true)
		detail.merge({"pointer": pointer, "sealbinder_id": left["id"], "tooltip_lines": TooltipProof.rendered_lines(popup)})
		await _capture("sealbinder_tooltip", detail)
	await TooltipProof.move_pointer(self, canvas, Vector2.ZERO)

func _escape_reward(scene: Node, engine: RefCounted, state: Dictionary, battle: Dictionary, facts: Dictionary) -> void:
	var reward: Dictionary = engine.finish_combat(state, battle)
	_expect(str(reward.get("mode", "")) == "reward", "Escaping resolves to the production reward screen")
	var payout: int = int(reward["pending_reward"]["ember_amount"])
	var bonus: int = int(Specials.definition("umbral_snare")["bonus"]["amount"])
	var open_count: int = int(facts["escape"]["doors_open_at_escape"])
	var base: int = Specials.reward_embers(engine.room_metadata(state, state["current_room"]), battle)
	_expect(payout == base + open_count * bonus, "Reward Ember payout includes every open door")
	scene.call("_load_run_state", reward)
	var deadline: int = Time.get_ticks_msec() + int(READY_TIMEOUT_SECONDS * 1000.0)
	var row: Control = null
	while Time.get_ticks_msec() < deadline:
		row = scene.find_child("RewardCardRow", true, false) as Control
		if not bool(scene.call("_reward_intro_pending")) and not bool(scene.get("_reward_intro_in_progress")) and row != null and row.is_visible_in_tree() and row.get_child_count() == 4: break
		await process_frame
	_expect(row != null and row.is_visible_in_tree() and row.get_child_count() == 4, "Reward capture displays the four special reward cards")
	_expect(not bool(scene.call("_reward_intro_pending")) and not bool(scene.get("_reward_intro_in_progress")), "Reward reveal has resolved before capture")
	await create_timer(SETTLE_SECONDS).timeout
	var stats: Label = scene.get("stats_label")
	var held: int = engine.held_embers(reward)
	_expect(stats.is_visible_in_tree() and stats.text.ends_with("EMBERS %d" % held), "Reward screen shows the actual Ember total")
	var detail: Dictionary = facts.duplicate(true)
	detail.merge({"reward_ember_amount": payout, "held_embers": held, "stats_label": stats.text, "mode": str((scene.get("_run_state") as Dictionary)["mode"])})
	await _capture("escape_reward", detail)

func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: String in values: result.append(value)
	return result

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _await_units_drawn(board: Node, state: Dictionary) -> void:
	var deadline: int = Time.get_ticks_msec() + int(READY_TIMEOUT_SECONDS * 1000.0)
	var errors: Array[String]
	while Time.get_ticks_msec() < deadline:
		errors = RenderProof.renderer_readiness_errors(board, state)
		if errors.is_empty():
			board.drawn_unit_keys.clear()
			board.call("_queue_dynamic_redraw")
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var required: Array[String]
			required.append("player")
			for enemy: Dictionary in state["enemies"]:
				if int(enemy["hp"]) > 0: required.append("enemy_%d" % int(enemy["id"]))
			for key: String in required:
				if not board.drawn_unit_keys.has(key): errors.append(key + " body was not drawn")
			if errors.is_empty(): return
		await process_frame
	_expect(false, "Every native actor must be prepared and drawn: " + "; ".join(errors))
