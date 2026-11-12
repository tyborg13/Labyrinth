extends SceneTree

const Fixture = preload("res://tools/rd04/real_fixture.gd")
const Cases = preload("res://tools/rd04/proof_case.gd")
const Isolation = preload("res://scripts/board_threat_isolation.gd")
const BoardSettings = preload("res://scripts/settings_store.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/rd-04"
const DEFAULT_MANIFEST: String = OUTPUT + "/feedback2/overlap.json"
const PLATE_SETTLE_SECONDS: float = 0.25
const SETTLE_FRAMES: int = 20
const IDLE_FRAMES: int = 120
const EMBED_TOOLTIPS: bool = true
const TOOLTIP_SETTLE_SECONDS: float = 0.7
const RAIL_RETURN_SETTLE_SECONDS: float = 0.16
var checks: int = 0
var failures: Array[String]
var scene: Node
var board: Control
var canvas: SubViewport
var case_name: String = "overlap"
var capture: bool = false
var samples: Array[Dictionary]
var manifest: String = DEFAULT_MANIFEST
var output_dir: String = OUTPUT

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args := OS.get_cmdline_user_args()
	capture = args.has("--capture")
	if args.has("--clip"):
		push_error("Use tools/rd04/movie_capture.gd: movies must not run the interaction matrix")
		quit(1)
		return
	if args.has("--case"): case_name = args[args.find("--case") + 1]
	if args.has("--fixture-manifest"): manifest = args[args.find("--fixture-manifest") + 1]
	if args.has("--output-dir"): output_dir = args[args.find("--output-dir") + 1]
	else: output_dir = OUTPUT + "/feedback2/proof-" + case_name
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		push_error("Renderer proof belongs to the design owner")
		quit(1)
		return
	var saved: Dictionary = Fixture.install_save(manifest)
	canvas = Fixture.make_canvas(self)
	canvas.gui_embed_subwindows = EMBED_TOOLTIPS
	scene = Fixture.resume(self, canvas)
	await _settle()
	board = scene.get("board_view")
	if scene.get("_combat_state") == null:
		_check(false, "Production combat scene loaded")
		_finish()
		return
	var enemies: Array = scene.get("_combat_state")["enemies"]
	_check(preload("res://tools/rd04/fixture_generator.gd").open_unit_count(scene.get("_combat_state")) >= 3, "At least three units including the hero stand in the open")
	if case_name != "overlap":
		await _boss_proof(saved)
		_finish()
		return
	_check(enemies.filter(func(e: Dictionary) -> bool: return int(e.get("hp", 0)) > 0).size() in [4, 5], "Section I fight contains four or five living ordinary foes")
	_check(int(saved["rooms"][str(saved["current_room"].x) + "," + str(saved["current_room"].y)]["section_index"]) == 0, "Overlap room belongs to Section I")
	for foe: Dictionary in enemies: _check(not bool(preload("res://scripts/game_data.gd").enemy_property(str(foe["type"]), "boss_bar", false)), "Overlap fight has no dragon or boss bar")
	var rest: Dictionary = board.presentation.get("threats_at_rest", {})
	print("RD04 THREATS: ", rest.get("threats", []).map(func(t: Dictionary) -> Dictionary: return {"key": t["key"], "tiles": t["tiles"]}))
	var found: Dictionary = Cases.find(board)
	var enemy: Dictionary = found["enemy"]
	if enemy.is_empty():
		_check(false, "Visible ordinary attacker found")
		_finish()
		return
	var key: String = "enemy_%d" % int(enemy["id"])
	var origin: Vector2i = enemy["pos"]
	await _hover(Vector2i(-1, -1))
	await _still("01_nothing_hovered")
	# Tile dispatch is also exercised directly: rendered body pixels need a native renderer.
	var body_point: Vector2 = board.call("_unit_draw_rect", Isolation.enemy_at_tile(board, origin)).get_center()
	Fixture.pointer(self, board, body_point)
	await _settle()
	_expect_keys([key], "body hover")
	await _still("02_enemy_hovered")
	var slot: Control = _rail_slot(key)
	_check(slot != null, "Real rail portrait exists")
	if slot != null:
		_pointer_global(slot.get_global_rect().get_center())
		await _settle()
		_expect_keys([key], "rail hover")
		await _still("04_rail_hovered")
		slot.mouse_exited.emit()
	await _settle()
	var chip: Dictionary = {}
	for badge: Dictionary in Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])):
		if str(badge["key"]) == key: chip = badge
	_check(not chip.is_empty(), "Real intent chip exists")
	if not chip.is_empty():
		Fixture.pointer(self, board, (chip["rect"] as Rect2).get_center())
		await _settle()
		_expect_keys([key], "intent chip hover")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	scene.set("_controller_region", "board")
	scene.call("_controller_set_board_tile", origin)
	await _settle()
	_expect_keys([key], "controller focus")
	router.call("set_forced_state_for_test", "pointer", "steam_deck")
	var overlap: Vector2i = found["overlap"]
	var empty: Vector2i = found["empty"]
	_check(overlap.x >= 0, "Certified fight has an empty tile threatened by two enemies")
	_check(empty.x >= 0, "Certified fight has empty unthreatened floor")
	if overlap.x >= 0:
		await _hover(overlap)
		var attackers: Array[String] = Isolation.tile_keys(board, overlap)
		_expect_keys(attackers, "reverse tile lookup")
		_check(board.presentation.get("expanded_enemy_actor_keys", []) == attackers, "Both intent chips expand")
		_check(is_equal_approx(Isolation.alpha_for(attackers, attackers), 1.0), "Both attackers remain full")
		var third: Array[String]
		for candidate: Dictionary in enemies:
			var candidate_key := "enemy_%d" % candidate["id"]
			if not attackers.has(candidate_key): third.append(candidate_key)
		_check(is_equal_approx(Isolation.alpha_for(third, attackers), 0.3), "Third attacker drops to thirty percent")
		await _still("03_overlap_hovered")
		_check(_lit_rail_keys() == attackers, "Reverse-lookup still has both attackers’ rail edges lit")
		await _still("06_reverse_lookup_both_rail_slots_lit")
		scene.call("_begin_player_movement_selection")
		await _hover(overlap)
		_expect_keys(attackers, "movement selection reverse lookup")
		await scene.call("_on_cancel_requested")
		_check(scene.get("_hovered_board_tile").x < 0 and board.get("_hover_tile").x < 0, "Movement cancellation retires both hover caches")
		var aimed_index: int = _aimed_card_index()
		_check(aimed_index >= 0, "Natural shuffled hand has an aimed card")
		if aimed_index >= 0: await scene.call("_on_card_pressed", aimed_index)
		await _hover(overlap)
		_expect_keys([], "card aim suppresses reverse lookup")
		await _hover(origin)
		_expect_keys([key], "card aim retains direct enemy isolation")
		await scene.call("_on_cancel_requested")
		await _hover(overlap)
		var before: Dictionary = board.render_instrumentation_snapshot()
		var redraws_before: int = board.get("_render_redraw_request_count")
		for frame in range(IDLE_FRAMES): await process_frame
		var after: Dictionary = board.render_instrumentation_snapshot()
		print("RD04 IDLE REDRAWS: frames=%d requests=%d full=%d static=%d" % [IDLE_FRAMES, int(board.get("_render_redraw_request_count")) - redraws_before, int(after.get("full_dynamic_redraw_count", 0)) - int(before.get("full_dynamic_redraw_count", 0)), int(after.get("static_draw_count", 0)) - int(before.get("static_draw_count", 0))])
		_check(after.get("full_dynamic_redraw_count", 0) == before.get("full_dynamic_redraw_count", 0), "Held threatened tile adds no full board redraw")
		_check(after.get("static_draw_count", 0) == before.get("static_draw_count", 0), "Held threatened tile adds no floor redraw")
	if empty.x >= 0:
		await _hover(empty)
		_expect_keys([], "unthreatened floor clears isolation")
		await create_timer(RAIL_RETURN_SETTLE_SECONDS).timeout
		for rail_slot: Control in scene.get("_turn_order_bar").get_children():
			if not str(rail_slot.get_meta("turn_order_actor_key", "")).begins_with("enemy:"): continue
			var edge: Control = rail_slot.get_meta("perf03_retained_parts", {}).get("edge")
			if edge != null: _check(edge.color.is_equal_approx(edge.get_meta("rd04_rest_color")), "Rail edge returns to rest after 0.12-second fade")
	var objective: Dictionary = preload("res://scripts/combat_objective_rules.gd").definition("kill_leader")
	_check(str(objective.description).contains("marked leader"), "Leader objective still explains the encounter condition outside enemy tooltips")
	var locked_before: bool = scene.get("_animation_lock")
	scene.set("_animation_lock", true)
	_check(Isolation.resolve(scene, scene.get("_combat_state"), origin, rest).is_empty(), "Playback disables isolation")
	scene.set("_animation_lock", locked_before)
	var enemy_turn: Dictionary = scene.get("_combat_state").duplicate(true)
	enemy_turn["current_actor"] = {"kind": "enemy", "enemy_id": enemy["id"]}
	_check(Isolation.resolve(scene, enemy_turn, origin, rest) == [key], "Projected enemy actor does not suppress a committed player-turn hover")
	var committed: Dictionary = scene.get("_combat_state")
	scene.set("_combat_state", enemy_turn)
	_check(Isolation.resolve(scene, enemy_turn, origin, rest).is_empty(), "Enemy turns disable isolation")
	scene.set("_combat_state", committed)
	_check_rail_return(key)
	_finish()

func _aimed_card_index() -> int:
	for index: int in range((scene.get("_combat_state").get("deck", {}).get("hand", []) as Array).size()):
		var preview: Dictionary = scene.call("_card_play_options_for_index", index).get("play", {})
		if bool(preview.get("playable", false)) and str(preview.get("action", {}).get("type", "")) in ["ranged", "melee", "aoe", "push", "pull"]: return index
	return -1

func _boss_proof(saved: Dictionary) -> void:
	var bosses: Array = scene.get("_combat_state")["enemies"].filter(func(e: Dictionary) -> bool: return bool(preload("res://scripts/game_data.gd").enemy_property(str(e["type"]), "boss_bar", false)))
	_check(bosses.size() == 1 and str(bosses[0]["type"]) == case_name, "Real arena contains exactly its one named dragon")
	if bosses.size() != 1: return
	var boss: Dictionary = bosses[0]
	var depth: int = int(saved.get("dragon_inspection", {}).get("depth", 0))
	_check(preload("res://scripts/dragon_boss_library.gd").boss_id_for_depth(int(saved["seed"]), depth) == case_name, "Boss depth matches this real run’s dragon sequence")
	_check(str(saved.get("current_room_layout", {}).get("boss_id", "")) == case_name, "Boss uses its production arena")
	var tiles: Array = scene.call("_enemy_footprint_tiles", boss)
	var boss_key: String = "enemy_%d" % int(boss["id"])
	for setting: String in [BoardSettings.BOARD_HEALTH_ALWAYS, BoardSettings.BOARD_HEALTH_CONTEXTUAL]:
		BoardSettings._applied_board_health_bars = setting
		for tile: Vector2i in tiles:
			await _hover(tile)
			board.plate_visibility.advance(PLATE_SETTLE_SECONDS)
			_check(board.controller_tooltip_for_tile(tile) == board.call("_surface_tooltip_for_tile", tile), "Dragon focus has only independent floor details at " + str(tile))
			var point: Vector2 = board.call("world_position_for_tile", tile)
			_check(board.call("_get_tooltip", point) == board.call("_surface_tooltip_for_tile", tile), "No enemy tooltip on dragon footprint " + str(tile))
			_check(board.plate_visibility.opacity(boss_key) == 1.0 and board.plate_visibility.unfurled(boss_key), "Dragon keeps plate and unfurled intent " + str(tile))
			_expect_keys([boss_key], "Real boss footprint hover without tooltip")
	await _still("05_back_footprint_" + case_name)
	print("RD04 REAL BOSS: ", case_name, " depth=", depth, " units=", scene.get("_combat_state")["enemies"].size() + 1)

func _check_rail_return(key: String) -> void:
	var slot: Control = _rail_slot(key)
	_check(slot != null, "Rail return fixture has a real portrait")
	if slot == null: return
	var edge: Control = slot.get_meta("perf03_retained_parts", {}).get("edge")
	var rest: Color = edge.get_meta("rd04_rest_color")
	var scale_before: Vector2 = slot.scale
	var width_before: float = edge.width
	var children_before: int = edge.get_child_count()
	var selected: Array[String]
	selected.append(key)
	Isolation.update_rail(scene, selected)
	var gold: Color = preload("res://scripts/ui_palette.gd").GOLD_BRIGHT
	_check(edge.color == gold, "Rail entry immediately uses full-alpha GOLD_BRIGHT")
	Isolation.update_rail(scene, [])
	var fade: Tween = edge.get_meta("rd04_rail_tween")
	_check(edge.color == gold and fade.is_running(), "Rail exit starts a fade without snapping")
	fade.custom_step(Isolation.TRANSITION_SECONDS * 0.5)
	_check(edge.color.is_equal_approx(gold.lerp(rest, 0.75)), "Rail return midpoint follows quadratic ease-out")
	Isolation.update_rail(scene, [])
	_check(edge.get_meta("rd04_rail_tween") == fade, "Unchanged isolation does not restart the return tween")
	fade.custom_step(Isolation.TRANSITION_SECONDS * 0.5)
	_check(edge.color.is_equal_approx(rest), "Rail return finishes at exactly 0.12 seconds")
	_check(slot.scale == scale_before and edge.width == width_before and edge.get_child_count() == children_before, "Isolation changes neither rail scale, width nor glow children")
	Isolation.update_rail(scene, board.presentation.get("isolated_enemy_actor_keys", []))

func _pointer_global(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	if DisplayServer.get_name() != "headless": root.warp_mouse(point)
	root.push_input(motion, true)

func _unit_free(tile: Vector2i) -> bool:
	if not Isolation.enemy_at_tile(board, tile).is_empty(): return false
	if scene.get("_combat_state").get("player", {}).get("pos") == tile: return false
	for ally: Dictionary in scene.get("_combat_state").get("allies", []):
		if ally.get("pos") == tile: return false
	return true

func _rail_slot(key: String) -> Control:
	for slot: Control in scene.get("_turn_order_bar").get_children():
		if str(slot.get_meta("turn_order_actor_key", "")).trim_prefix("enemy:") == key: return slot
	return null

func _hover(tile: Vector2i) -> void:
	await _settle()
	Fixture.pointer(self, board, board.call("world_position_for_tile", tile) if tile.x >= 0 else Vector2.ZERO)
	await _settle()

func _settle() -> void:
	for frame in range(SETTLE_FRAMES): await process_frame

func _expect_keys(expected: Array, label: String) -> void:
	print("RD04 INPUT ", label, ": scene=", scene.get("_hovered_board_tile"), " board=", board.get("_hover_tile"), " pointer=", board.get("_last_pointer_position"), " selected=", board.presentation.get("isolated_enemy_actor_keys", []), " moving=", scene.get("_player_movement_selected"), " card=", scene.get("_selected_card_index"))
	_check(board.presentation.get("isolated_enemy_actor_keys", []) == expected, label)
	var owned: int = 0
	for layer: Control in board.call("_retained_render_layers"):
		var owners: Array = layer.get_meta("threat_actor_keys", [])
		if owners.is_empty():
			if layer.has_meta("threat_actor_keys"): _check(is_equal_approx(layer.modulate.a, 1.0), label + ": hero/floor paint remains full strength")
			continue
		owned += 1
		_check(is_equal_approx(float(layer.get_meta("rd04_alpha", 1.0)), Isolation.alpha_for(owners, expected)), label + ": retained owner alpha target")
	_check(owned > 0, label + ": real retained threat canvases exist")
	for key: String in expected:
		var slot: Control = _rail_slot(key)
		_check(slot != null, label + ": selected attacker has a rail slot")
		if slot == null: continue
		var edge: Control = slot.get_meta("perf03_retained_parts", {}).get("edge")
		_check(edge != null and edge.color == preload("res://scripts/ui_palette.gd").GOLD_BRIGHT and is_equal_approx(edge.color.a, 1.0), label + ": selected rail edge is full-alpha gold")

func _still(label: String) -> void:
	if not capture: return
	await create_timer(TOOLTIP_SETTLE_SECONDS).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output_dir)
	_check(canvas.get_texture().get_image().save_png(output_dir.path_join(label + ".png")) == OK, label + ": saved capture")
	print(output_dir.path_join(label + ".png"))
	samples.append({"image": label + ".png", "keys": board.presentation.get("isolated_enemy_actor_keys", []), "lit_rail_keys": _lit_rail_keys()})

func _lit_rail_keys() -> Array[String]:
	var keys: Array[String]
	for slot: Control in scene.get("_turn_order_bar").get_children():
		if not bool(slot.get_meta("threat_isolation_hovered", false)): continue
		var edge: Control = slot.get_meta("perf03_retained_parts", {}).get("edge")
		var key: String = str(slot.get_meta("turn_order_actor_key", "")).trim_prefix("enemy:")
		if edge != null and edge.color == preload("res://scripts/ui_palette.gd").GOLD_BRIGHT and not keys.has(key): keys.append(key)
	keys.sort()
	return keys

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "source": manifest, "samples": samples}, "\t"))
	for failure: String in failures: push_error(failure)
	print("RD04 THREAT ISOLATION: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
