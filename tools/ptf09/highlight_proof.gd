extends SceneTree

const Audit = preload("res://tests/suites/card_targeting_audit_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Context = preload("res://scripts/targeted_tile_context.gd")
const Host = preload("res://tools/ptf09/proof_host.gd")
const Board = preload("res://tools/ptf09/proof_board.gd")
const Highlight = preload("res://scripts/targeted_tile_highlight.gd")
const ShortcutFixture = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const FOE := Vector2i(3, 4)
const EMPTY := Vector2i(2, 3)
const FIXTURE_SEED: int = 20261110
const SHORTCUT_FOE := Vector2i(4, 4)
const INTENT_RECT := Rect2(20, 20, 100, 100)
var checks: int = 0
var failures: Array[String]
var scene: Node
var combat := Combat.new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(_draw_boundary)
	call_deferred("_run")

func _run() -> void:
	root.size = SIZE
	root.content_scale_size = SIZE
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Host)
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
	board.set_script(Board)
	root.add_child(scene)
	await _settle()
	_install("dull_bolt")
	_hover(FOE)
	_check(_overlay() == null or not _overlay().visible, "idle has no highlight")
	await _card("dull_bolt", FOE, "attack", "card")
	_check(is_equal_approx(Highlight.pulse_alpha_at(0.0, false), 0.85) and is_equal_approx(Highlight.pulse_alpha_at(0.7, false), 1.0) and is_equal_approx(Highlight.pulse_alpha_at(1.4, false), 0.85), "director pulse is 85%-100%-85% over 1.4 seconds")
	_check(is_equal_approx(Highlight.pulse_alpha_at(0.7, true), 1.0), "reduced motion keeps full alpha")
	await _slot_lifecycle(board)
	await _card("sidestep_slash", SHORTCUT_FOE, "attack", "move+attack shortcut")
	_install("dull_bolt")
	scene.call("_begin_player_movement_selection")
	scene.call("_refresh_stage_view")
	var moves: Array = scene.get("_player_movement_target_tiles")
	_check(not moves.is_empty(), "movement fixture has a legal destination")
	if not moves.is_empty(): await _commit_case(moves[0], "move", "hero movement")
	for illusion_id: int in [-1, 7]:
		_install("dull_bolt")
		if illusion_id >= 0:
			var state: Dictionary = scene.get("_combat_state")
			state["illusions"] = [{"id": illusion_id, "pos": Vector2i(2, 5), "hp": 1, "max_hp": 1}]
			scene.call("_mark_combat_preview_state_changed")
		scene.call("_begin_guardian_utility_selection", "move", illusion_id)
		scene.call("_refresh_stage_view")
		moves = scene.get("_player_movement_target_tiles")
		_check(not moves.is_empty(), "utility fixture has a legal destination")
		if not moves.is_empty(): await _commit_case(moves[0], "move", "guardian" if illusion_id < 0 else "illusion")
	_install("dull_bolt")
	# A real relocation origin selection needs no committed skill spend.
	var aim: RefCounted = scene.get("_surface_aim")
	aim.begin("confluence", true)
	aim.choose("elemental")
	scene.call("_refresh_surface_skill_selection")
	var surfaces: Array = scene.get("_surface_skill_tiles")
	_check(not surfaces.is_empty(), "surface fixture has a selectable origin")
	if not surfaces.is_empty(): await _commit_case(surfaces[0], "valid", "surface aim")
	_install("dull_bolt")
	await scene.call("_on_card_pressed", 0)
	scene.call("_refresh_stage_view")
	_hover(Vector2i(0, 0))
	_assert_overlay(Vector2i(0, 0), "invalid", "invalid tile")
	_check(is_equal_approx(_overlay().modulate.a, scene.call("_action_context_target_color", "invalid").a * 0.7), "invalid tone is 70% alpha")
	var old_zoom: float = board.get("_navigation_zoom")
	board.call("set_navigation_zoom", old_zoom * 0.9)
	_check(_overlay().position.is_equal_approx(board.call("world_position_for_tile", Vector2i(0, 0))), "zoom keeps the border on its floor tile")
	_check(is_equal_approx(_overlay().get("_zoom"), board.get("_navigation_zoom")), "border dimensions scale with navigation zoom")
	var settings: Dictionary = scene.get("_settings")
	settings["reduced_motion"] = true
	scene.set("_settings", settings)
	scene.call("_refresh_stage_view")
	_check(not _overlay().is_processing() and is_equal_approx(_overlay().self_modulate.a, 1.0), "reduced motion holds full alpha without processing")
	# All four palette cases use exactly the existing action-context colors.
	for tone: String in ["valid", "move", "attack"]:
		var context: Dictionary = Context.build(scene, {"action": {"type": "move" if tone == "move" else "ranged" if tone == "attack" else "surface"}, "target_tiles": [EMPTY]})
		context["shortcuts"] = {}
		board.call("set_targeted_tile_context", context, EMPTY)
		_assert_overlay(EMPTY, tone, "tone " + tone)
	var animation: Dictionary = (board.get("presentation") as Dictionary).duplicate(false)
	animation["board_targeting"] = false
	board.call("set_combat_state", board.get("combat_state"), [], [], Vector2i(-1, -1), "", "", {}, {}, animation)
	_check(not _overlay().visible and not _overlay().is_processing(), "non-targeting animation submission clears the retained border")
	_install("dull_bolt")
	await scene.call("_on_card_pressed", 0)
	scene.call("_refresh_stage_view")
	var router: Node = root.get_node_or_null("InputRouter")
	_check(router != null, "controller proof has production input router")
	if router != null:
		router.call("set_forced_state_for_test", "controller", "steam_deck")
		scene.set("_controller_region", "board")
		scene.call("_controller_set_board_tile", FOE)
		_assert_overlay(FOE, "attack", "controller focus immediate")
		await scene.call("_controller_activate_current")
		_check(scene.get("committed_tile") == FOE, "controller commits the highlighted focus tile")
		router.call("set_forced_state_for_test", "pointer", "steam_deck")
	# Put the pointer inside an intent icon that overlaps this floor-tile click.
	_install("dull_bolt")
	await scene.call("_on_card_pressed", 0)
	scene.call("_refresh_stage_view")
	scene.set("_focused_intent_enemy_id", 1)
	scene.set("proof_pointer", INTENT_RECT.get_center())
	board.set("proof_intent_rect", INTENT_RECT)
	_hover(FOE)
	await scene.call("_on_board_tile_clicked", FOE)
	_check(scene.get("committed_tile") == FOE and int(scene.get("commits")) == 1, "intent icon cannot swallow a targeting click")
	_install("dull_bolt")
	scene.set("_focused_intent_enemy_id", 1)
	await scene.call("_on_board_tile_clicked", FOE)
	_check(int(scene.get("_focused_intent_enemy_id")) == 1 and int(scene.get("commits")) == 0, "idle intent icon keeps its inspection early return")
	scene.call("_refresh_stage_view")
	_check(not _overlay().visible, "cancelled/idle state clears the highlight")
	scene.queue_free()
	await _settle()
	for failure: String in failures: push_error(failure)
	print("PTF09 HIGHLIGHT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _card(id: String, tile: Vector2i, tone: String, label: String) -> void:
	_install(id)
	await scene.call("_on_card_pressed", 0)
	scene.call("_refresh_stage_view")
	await _commit_case(tile, tone, label)

func _commit_case(tile: Vector2i, tone: String, label: String) -> void:
	_hover(tile)
	_assert_overlay(tile, tone, label)
	await scene.call("_on_board_tile_clicked", tile)
	_check(scene.get("committed_tile") == tile and int(scene.get("commits")) == 1, label + ": click dispatch commits exactly the highlighted tile")

func _install(id: String) -> void:
	(scene.get("_surface_aim") as RefCounted).cancel()
	var state: Dictionary = ShortcutFixture._combat_state(combat, id, SHORTCUT_FOE, FIXTURE_SEED) if id == "sidestep_slash" else Audit.state_for(combat, id)
	Audit._install(scene, state)
	scene.set("committed_tile", Vector2i(-1, -1))
	scene.set("_hovered_board_tile", Vector2i(-1, -1))
	scene.call("_refresh_stage_view")

func _hover(tile: Vector2i) -> void:
	scene.call("_on_board_tile_hovered", tile)
	_check(scene.get("_hovered_board_tile") == tile, "hover plumbing retains floor tile " + str(tile))

func _overlay() -> Node2D:
	return (scene.get("board_view") as Control).get("_targeted_tile_highlight")

func _assert_overlay(tile: Vector2i, tone: String, label: String) -> void:
	var overlay: Node2D = _overlay()
	_check(overlay != null and overlay.visible and overlay.get("tile") == tile, label + ": border follows committed hover immediately")
	if overlay == null: return
	_check(overlay.get("tone") == tone, label + ": " + tone + " tone")
	var color: Color = scene.call("_action_context_target_color", tone)
	if tone == "invalid": color.a *= 0.7
	_check(overlay.modulate.is_equal_approx(color), label + ": existing action palette")
	var board: Control = scene.get("board_view")
	_assert_slot(board, label)
	_check((board.get_parent() as CanvasLayer).layer < (scene.get_node("UiLayer") as CanvasLayer).layer, label + ": below cards/hand UI")

func _assert_slot(board: Control, label: String) -> void:
	var border: Node2D = board.get("_targeted_tile_highlight")
	_check(border.z_as_relative and border.z_index == 0, label + ": ordinary relative Z zero")
	_check(border.get_index() == (board.get("_action_floor_render_layer") as Node).get_index() + 1, label + ": directly after action floor")
	for layer: Node in board.get("_scene_render_layers"):
		_check(border.get_index() < layer.get_index(), label + ": below " + str(layer.name))
	_check(board.call("_scene_render_layers_match", board.call("_rendered_tiles_in_draw_order")), label + ": exact retained indices match")

func _slot_lifecycle(board: Control) -> void:
	var original: Dictionary = Audit.state_for(combat, "dull_bolt")
	var shown: Dictionary = {"reduced_motion": true, "board_targeting": true}
	board.call("set_combat_state", original, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	var changed: Dictionary = original.duplicate(true)
	changed["enemies"][0]["pos"] = Vector2i(3, 5)
	board.call("set_combat_state", changed, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	board.call("_sync_scene_render_layers")
	_assert_slot(board, "unit moved/re-sync")
	var initial_count: int = (board.call("_rendered_tiles_in_draw_order") as Array).size()
	var row: Array = (changed["grid"][1] as Array).duplicate()
	(changed["grid"] as Array).append(row)
	board.call("set_combat_state", changed, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	_check((board.call("_rendered_tiles_in_draw_order") as Array).size() > initial_count, "tile-set addition really changes rendered layer set")
	_assert_slot(board, "tile set added")
	board.call("set_combat_state", original, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	_check((board.call("_rendered_tiles_in_draw_order") as Array).size() == initial_count, "tile-set removal restores layer set")
	_assert_slot(board, "tile set removed")
	var reframed: Dictionary = shown.duplicate(false)
	reframed["board_fit_rect"] = Rect2(100, 120, 1300, 640)
	board.call("set_combat_state", original, [], [], Vector2i(-1, -1), "", "", {}, {}, reframed)
	board.call("_sync_scene_render_layers")
	_assert_slot(board, "framing changed")
	var placements: int = board.get("slot_placements")
	for frame: int in range(10): board.call("_process_board_frame", 1.0 / 30.0)
	_check(int(board.get("slot_placements")) == placements, "slot logic adds no work to ten board process ticks")
	board.call("set_combat_state", original, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	await process_frame

func _settle() -> void:
	for frame: int in range(4): await process_frame

func _draw_boundary() -> void:
	RenderingServer.frame_post_draw.emit()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
