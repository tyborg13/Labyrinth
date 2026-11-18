extends "res://tools/atk13/capture.gd"
## Native owner proof: rest, a real Updraft aimed at the source, then impact.
## Only the debug hand is supplied; all card numbers and rendering are production.
const Areas = preload("res://scripts/boss_area_rules.gd")
const ForecastPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const Truth = preload("res://tools/atk13/area01/capture_truth.gd")
const PROOF_CONTACT_PROGRESS: float = preload("res://scripts/dragon_presentation.gd").CONTACT
const PROOF_PUSH_CARD: String = "updraft"
const PROOF_PLAYBACK_FRAMES: int = 2400
const PROOF_CROP_PADDING: float = 8.0
const PROOF_NORMAL_BASE_HEALTH: int = preload("res://scripts/run_engine.gd").BASE_MAX_HP
func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	var out: String = _arg("--out")
	var full_turn: bool = _arg("--verify-full-turn", "false") == "true"
	var semantic: bool = _arg("--semantic", "false") == "true"
	_check(semantic or DisplayServer.get_name() != "headless", "native captures require a real renderer")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	_check(DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK, "copy audited profile")
	_check(DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK, "copy audited run")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.msaa_2d = root.msaa_2d
	container.add_child(canvas)
	root.set_meta("labyrinth_resume_saved_run", true)
	native_scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(native_scene)
	for frame: int in range(PROOF_BOOT_FRAMES): await process_frame
	var state: Dictionary = (native_scene.get("_combat_state") as Dictionary).duplicate(true)
	var engine: RefCounted = native_scene.get("_combat_engine")
	var index: int = -1
	for i: int in range(state.get("enemies", []).size()):
		var enemy: Dictionary = state["enemies"][i]
		if str(enemy["type"]) == _arg("--enemy") and str(enemy.get("intent", {}).get("id", "")) == _arg("--intent"): index = i; break
	_check(index >= 0, "audited source has requested announced move")
	if index < 0: quit(1); return
	var enemy: Dictionary = state["enemies"][index]
	var id: int = int(enemy["id"])
	var origin: Vector2i = enemy["pos"]
	var card_index: int = (state["deck"]["hand"] as Array).size()
	state["deck"]["hand"].append(PROOF_PUSH_CARD)
	state["cards_played_this_turn"] = 0
	var run: Dictionary = (native_scene.get("_run_state") as Dictionary).duplicate(true)
	var normal_max: int = preload("res://scripts/depth_rules.gd").start_max_hp(run, PROOF_NORMAL_BASE_HEALTH)
	state["player"]["hp"] = normal_max
	state["player"]["max_hp"] = normal_max
	run["player_hp"] = normal_max
	run["player_max_hp"] = normal_max
	# Refresh only the debug fixture's cached hero Health, not any held tile,
	# route or target. Avoid carrying the audit's high-Health witness in proof.
	for actor: Dictionary in state.get("enemies",[]):
		var target_snapshot: Dictionary = actor.get("intent",{}).get("committed_plan",{}).get("target",{})
		if str(target_snapshot.get("kind","")) == "player": target_snapshot["hp"] = normal_max
	run["combat_state"] = state
	native_scene.call("_load_run_state",run)
	_motion(PROOF_PARK_POINTER)
	for frame: int in range(PROOF_LAYOUT_FRAMES): await process_frame
	var rest_summary: Dictionary = native_scene.call("_pass_preview_summary")
	native_scene.call("_on_board_tile_hovered", enemy["pos"])
	native_scene.call("_refresh_stage_view")
	var board: Control = native_scene.get("board_view")
	var shown: Array[Vector2i] = _area_red(board, id)
	_check(not shown.is_empty(), "announced area is red at rest")
	var report: Dictionary = {"enemy":_arg("--enemy"),"intent":_arg("--intent"),"origin":origin,"shown":shown,"proof_card":PROOF_PUSH_CARD,"viewport":[1920,1080],"ui_scale":1.0,"headless_semantics_only":semantic}
	report["origin_basis"] = (enemy["intent"]["actions"] as Array).filter(func(action: Dictionary) -> bool: return Areas.held(action)).map(func(action: Dictionary) -> String: return str(action.get("area_origin_basis",Areas.FIXED_KIND)))
	report["normal_max_hp"] = normal_max
	report["rest_health"] = _health()
	_check(canvas.size == SIZE and is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(native_scene), 1.0),
		"1920×1080 viewport and 100% UI scale")
	var unit: Dictionary = _proof_unit(board, id)
	_check(not unit.is_empty(), "production render unit is present")
	var pointer_layout: Dictionary = _proof_layout(board, unit)
	_check_intent(board, id, enemy["intent"]["name"], pointer_layout)
	native_scene.set("_focused_intent_enemy_id", id)
	native_scene.call("_on_board_tile_hovered", Vector2i(-1, -1))
	native_scene.call("_refresh_stage_view")
	var controller_layout: Dictionary = _proof_layout(board, unit)
	_check(controller_layout["rows"] == pointer_layout["rows"] and controller_layout["intent_name"] == pointer_layout["intent_name"],
		"pointer and controller inspection use the same announced move content")
	report["tooltip_rows"] = controller_layout["rows"]
	report["tooltip_title"] = controller_layout["intent_name"]
	report["rest_repeats"] = _repeat_chip(board, id)
	_check(preload("res://scripts/threat_tiles.gd").zone_tags(board.get("presentation").get("threats_at_rest", {}).get("threats", [])).is_empty(),
		"rest has no floor order tags")
	if full_turn:
		var pass_button: Button = native_scene.find_child("PassPreviewChip", true, false) as Button
		pass_button.grab_focus()
		native_scene.call("_refresh_selected_card_forecast")
		await create_timer(ForecastPanel.FADE_SECONDS).timeout
		_check_intent(board, id, enemy["intent"]["name"], _proof_layout(board, _proof_unit(board, id)))
		report["rest_truth"] = _check_full_turn(board, id, state, rest_summary, pass_button)
	var layout: Dictionary = _proof_layout(board, unit)
	var bounds: Rect2 = board.get_global_transform_with_canvas() * Rect2(layout["intent_rect"])
	var crop: Rect2i = Rect2i(bounds.grow(PROOF_CROP_PADDING)).intersection(Rect2i(Vector2i.ZERO,SIZE))
	report["tooltip_crop_rect"] = crop
	_check(crop.size.x >= 32 and crop.size.y >= 32,"tooltip crop has real layout bounds")
	if _arg("--single","false") == "true":
		_check(report["rest_repeats"] == 1, "single-activation native proof really acts once")
		if not semantic:
			await _picture(out.get_basename()+"_rest.png")
			await RenderingServer.frame_post_draw
			var crop_dir: String = out.get_base_dir().path_join("crops")
			DirAccess.make_dir_recursive_absolute(crop_dir)
			_check(canvas.get_texture().get_image().get_region(crop).save_png(crop_dir.path_join(out.get_file().get_basename()+"_tooltip.png")) == OK,"save unscaled native tooltip crop")
		await _finish_semantic(out,report,semantic)
		return
	if not semantic: await _picture(out.get_basename()+"_rest.png")
	if full_turn:
		var pass_button: Button = native_scene.find_child("PassPreviewChip", true, false) as Button
		pass_button.release_focus()
	native_scene.set("_focused_intent_enemy_id",-1)
	var preview: Dictionary = native_scene.call("_card_preview_for_index",card_index)
	_check(bool(preview.get("playable",false)) and not bool(preview.get("complete",true)), "production push card enters targeting")
	await native_scene.call("_begin_card_preview", card_index, preview)
	var target: Vector2i = Vector2i(-1,-1)
	for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
		if (native_scene.get("_pending_target_tiles") as Array).has(tile): target = tile; break
	_check(target.x >= 0, "audited source is a legal Updraft target")
	if target.x < 0: await _finish_semantic(out,report,semantic); return
	_motion(board.get_global_transform_with_canvas() * Vector2(board.call("world_position_for_tile",target)))
	if semantic: native_scene.call("_on_board_tile_hovered",target)
	for frame: int in range(PROOF_LAYOUT_FRAMES): await process_frame
	native_scene.call("_refresh_stage_view")
	_check(native_scene.get("_hovered_board_tile") == target, "pointer aims at the source")
	var forecast: Dictionary = native_scene.call("_pass_preview_source_state")
	var forecast_index: int = engine._enemy_index_for_id(forecast,id)
	var moved: Dictionary = forecast["enemies"][forecast_index]
	var aimed: Array[Vector2i] = _area_red(board,id)
	report["aimed_summary"] = native_scene.call("_pass_preview_summary")
	native_scene.call("_refresh_stage_view")
	aimed = _area_red(board, id)
	var aimed_layout: Dictionary = _proof_layout(board, _proof_unit(board, id))
	_check_intent(board, id, enemy["intent"]["name"], aimed_layout)
	report["aimed_tooltip_title"] = aimed_layout["intent_name"]
	report["aimed_repeats"] = _repeat_chip(board, id)
	if full_turn:
		var pass_button: Button = native_scene.find_child("PassPreviewChip", true, false) as Button
		native_scene.call("_refresh_selected_card_forecast")
		await create_timer(ForecastPanel.FADE_SECONDS).timeout
		report["aimed_truth"] = _check_full_turn(board, id, native_scene.call("_pass_preview_confirmed_hover_state", target), report["aimed_summary"], pass_button)
	var expected: Array[Vector2i] = Areas.announced_tiles(moved,engine,forecast)
	var record: Dictionary = report["aimed_summary"].get("relative_red_areas",{}).get("enemy_%d" % id,{})
	if not record.is_empty() and record.get("signature",[]) == Areas.forecast_signature(moved.get("intent",{})): expected.assign(record["tiles"])
	_check(preload("res://tests/suites/boss_area_rules_suite.gd").same(aimed,expected), "aimed red equals production predicted stamp")
	_check(moved["pos"] != origin, "the real push predicts source displacement")
	var relative: bool = false
	for action: Dictionary in enemy["intent"]["actions"]:
		if Areas.relative(action): relative = true
	_check(not preload("res://tests/suites/boss_area_rules_suite.gd").same(aimed,shown) if relative else preload("res://tests/suites/boss_area_rules_suite.gd").same(aimed,shown), "relative red slides; fixed red stays put")
	var marked: Array[Vector2i] = preload("res://scripts/boss_area_marks.gd").tiles(state,enemy)
	_check(marked.is_empty() if relative else preload("res://tests/suites/boss_area_rules_suite.gd").same(marked,shown), "only fixed area carries the existing Marked tile treatment")
	report["aimed_health"] = _health()
	_check(preload("res://scripts/threat_tiles.gd").zone_tags(board.get("presentation").get("threats_at_rest",{}).get("threats",[])).is_empty(),"aimed red has no order tags")
	report.merge({"relative":relative,"aimed":aimed,"forecast_source":moved["pos"],"marked_tiles":marked,"target":target})
	if not semantic: await _picture(out.get_basename()+"_aimed.png")
	if full_turn:
		await _finish_semantic(out, report, semantic)
		return
	# Start the real card coroutine without awaiting its whole playback, so an
	# immediate boss activation cannot pass the contact capture unnoticed.
	native_scene.call("_on_board_tile_clicked",target)
	var captured: bool = false
	var passed: bool = false
	for frame: int in range(PROOF_PLAYBACK_FRAMES):
		await process_frame
		_check(int((native_scene.get("_combat_state") as Dictionary).get("player",{}).get("hp",0)) > 0,"proof hero survives playback frame")
		if not bool(native_scene.get("_animation_lock")) and int(native_scene.get("_selected_card_index")) < 0 and not passed:
			passed = true
			native_scene.call("_on_pass_turn_pressed")
		var effect: Dictionary = (board.get("presentation") as Dictionary).get("effect", {})
		if str(effect.get("actor_key", "")) != "enemy_%d" % id or str(effect.get("intent_id", "")) != _arg("--intent") or not effect.has("area_shown_tiles"): continue
		if float(board.get("presentation").get("effect_progress",0.0)) < PROOF_CONTACT_PROGRESS: continue
		report["strike"] = effect.duplicate(true)
		report["strike_health"] = _health()
		var strike_board: Dictionary = state.duplicate(true)
		for field: String in effect.get("guardian_board_after", {}): strike_board[field] = effect["guardian_board_after"][field]
		strike_board["enemies"][engine._enemy_index_for_id(strike_board,id)]["pos"] = effect["from"]
		var strike_expected: Array[Vector2i]
		for action: Dictionary in enemy["intent"]["actions"]:
			if Areas.held(action): strike_expected.append_array(Areas.strike_tiles(engine,strike_board,action))
		_check(preload("res://tests/suites/boss_area_rules_suite.gd").same(effect.get("tiles",[]), strike_expected), "native playback strikes its translated stamp or fixed marks")
		if not semantic: await _picture(out.get_basename()+"_strike.png")
		captured = true
		break
	_check(captured, "playback reaches requested area strike")
	await _finish_semantic(out,report,semantic)

func _proof_unit(board: Control, id: int) -> Dictionary:
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("key", "")) == "enemy_%d" % id: return unit
	return {}

func _proof_layout(board: Control, unit: Dictionary) -> Dictionary:
	if unit.is_empty(): return {"rows": [], "intent_name": "", "intent_rect": Rect2()}
	var method: String = "_boss_intent_layout" if bool(unit.get("boss_bar", false)) else "_enemy_hud_layout"
	return board.call(method, unit, board.call("_unit_center", unit), [], preload("res://scripts/ui_typography.gd").ui_font())

func _check_intent(board: Control, id: int, title: String, layout: Dictionary) -> void:
	_check(layout["intent_name"] == title, "expanded tooltip is titled with the announced move")
	_check(not (layout["rows"] as Array).is_empty(), "expanded tooltip has announced action rows")
	for row: Array in layout["rows"]:
		for token: Dictionary in row:
			_check(not token.has("activation_title"), "expanded tooltip has no later activation titles")
			var text: String = str(token.get("value", ""))
			_check(not text.begins_with("Moves with ") and text != "Fixed direction", "expanded tooltip omits relative movement labels")
	_check(not str(board.call("enemy_intent_tooltip", "enemy_%d" % id)).contains("shifts this red"), "expanded tooltip omits relative hover text")

func _repeat_chip(board: Control, id: int) -> int:
	for badge: Dictionary in board.get("presentation").get("threats_at_rest", {}).get("badges", []):
		if str(badge.get("key", "")) == "enemy_%d" % id: return int(badge.get("repeats", 0))
	return 0

func _check_full_turn(board: Control, id: int, state: Dictionary, summary: Dictionary, pass_button: Button) -> Dictionary:
	var proof: Dictionary = Truth.check(state, "enemy_%d" % id, summary, pass_button)
	_check(_repeat_chip(board, id) == 2, "Tharokh's intent chip shows ×2")
	_check(proof["intents"] == ["bedrock_breath", "faultline"], "committed turn executes Bedrock Breath and then Faultline")
	_check(proof["shown_loss"] == proof["actual_loss"], "shown Health loss matches the whole committed turn")
	_check(proof["health_row"], "visible Pass panel contains the matching Health row")
	_check(proof["boss_loss"].get("faultline", 0) > 0, "Faultline contributes to total Health loss")
	var drawn: Array[Vector2i]
	for threat: Dictionary in board.get("presentation").get("threats_at_rest", {}).get("threats", []):
		if threat.get("key", "") == "enemy_%d" % id: drawn.append_array(threat["tiles"])
	proof["drawn_red"] = drawn
	var strike: Array = proof["strike"]
	var inert: Array = proof["inert"]
	proof["announced_strike_mismatches"] = 0 if preload("res://tests/suites/boss_area_rules_suite.gd").same(drawn.filter(func(tile: Vector2i) -> bool: return not inert.has(tile)), strike) else 1
	var extra: Array = drawn.filter(func(tile: Vector2i) -> bool: return not strike.has(tile) and not inert.has(tile))
	proof["red_drawn_for_unannounced_move"] = extra.size()
	_check(proof["announced_strike_mismatches"] == 0, "only the announced Bedrock Breath footprint is red")
	_check(proof["red_drawn_for_unannounced_move"] == 0, "no red is drawn for an unannounced move")
	return proof

func _health() -> Dictionary:
	var player: Dictionary = native_scene.get("_combat_state").get("player",{})
	_check(int(player.get("hp",0)) > 0 and int(player.get("hp",0)) <= int(player.get("max_hp",0)),"proof Health is alive and within normal max")
	return {"hp":player.get("hp"),"max_hp":player.get("max_hp")}

func _area_red(board: Control, id: int) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for threat: Dictionary in board.get("presentation").get("threats_at_rest",{}).get("threats",[]):
		if str(threat.get("key","")) == "enemy_%d" % id and bool(threat.get("area_announced",false)): result.append_array(threat["tiles"])
	return result

func _finish_semantic(out: String, report: Dictionary, semantic: bool) -> void:
	report["failures"] = failures
	var file := FileAccess.open(out.get_basename()+".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	for failure: String in failures: print("FAIL: "+failure)
	if not semantic: print(out.get_base_dir())
	if _arg("--verify-full-turn", "false") == "true" and report.has("aimed_truth"):
		for view: String in ["rest", "aimed"]:
			var proof: Dictionary = report[view + "_truth"]
			print("AREA04 %s: announced strike mismatches=%d; red drawn for an unannounced move=%d; Health forecast=%d; realized=%d" % [
				view, proof["announced_strike_mismatches"], proof["red_drawn_for_unannounced_move"], proof["shown_loss"], proof["actual_loss"]])
	native_scene.queue_free()
	for frame: int in range(PROOF_LAYOUT_FRAMES): await process_frame
	print("AREA01 CAPTURE %s semantic=%s" % ["PASS" if failures.is_empty() else "FAIL", semantic])
	quit(0 if failures.is_empty() else 1)
