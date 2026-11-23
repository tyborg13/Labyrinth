extends SceneTree

const Split = preload("res://scripts/enemy_mechanics/split_trait_text.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Fixture = preload("res://tests/suites/en01_enemies_suite.gd")
const Live = preload("res://tests/suites/movement_undo_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const SETTLE_FRAMES: int = 12
const HOVER_SECONDS: float = 1.5
const KEYWORD_PROOF_POSITION := Vector2(1400, 500)
const OUTPUT: String = "/private/tmp/labyrinth_codex/spl-01/captures"
var canvas: SubViewport
var scene: Node
var failures: Array[String]
var checks: int = 0
var semantic_only: bool

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	semantic_only = DisplayServer.get_name() == "headless"
	if OS.get_cmdline_user_args().has("--suite-check"):
		await preload("res://tests/suites/pre_battle_ui_suite.gd").run(_expect)
		_finish("SPL01 PRE-BATTLE SUITE")
		return
	Live.prepare_storage()
	root.size = SIZE
	root.content_scale_size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.gui_embed_subwindows = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await Live.settle(self)
	_expect(preload("res://scripts/settings_store.gd").load_settings()["ui_scale"] == UI_SCALE, "100% UI scale")
	_expect(preload("res://scripts/cel_look.gd").mode == "all", "Cel look enabled")
	var state: Dictionary = Fixture.fixture(["cinder_ooze"])
	Live.install(scene, state)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var board: Control = scene.get("board_view")
	var unit: Dictionary = state["enemies"][0]
	var token: Dictionary = Split.trait_token(unit)
	_expect(token.get("value") == "Splits 2", "Trait count comes from death_spawn")
	_expect(token.get("tooltip") == "When this enemy dies, this enemy splits into 2 Cinder Droplets within 1 tile.", "Exact contextual rules and pluralised data name")
	_expect(Glossary.lookup("split").get("id") == "splits", "Singular alias resolves")
	_expect(Glossary.definition("splits") == "When this enemy dies, this enemy splits into smaller enemies on adjacent tiles.", "Exact glossary definition")
	_expect(Icons.icon_texture("splits") != null, "Approved icon loads")
	var tags: Array = preload("res://scripts/pre_battle_threat_tags.gd").build("cinder_ooze", unit)
	var moves: Array = preload("res://scripts/pre_battle_threat_tags.gd").from_intents(Data.enemy_def("cinder_ooze")["intents"])
	_expect(tags.slice(0, moves.size()) == moves and tags.back().get("text") == "Splits 2", "All move tags retained before Splits")
	var rows: Array = board.call("_intent_rows_for_unit", unit, unit["intent"])
	var move_rows: Array = board.call("_move_rows_for_unit", unit, unit["intent"])
	_expect(rows.slice(0, move_rows.size()) == move_rows, "Details retains every real move row")
	_expect(rows[move_rows.size()][0].get("icon") == "splits", "Details adds the Splits token")
	var badges: Array = board.call("_unit_status_badges", unit)
	_expect(badges.any(func(b: Dictionary) -> bool: return b.get("icon") == "splits" and b.get("count") == 2), "Live board status plate includes Splits 2")
	var dead: Dictionary = unit.duplicate(true)
	dead["hp"] = 0
	_expect(Split.badges(dead).is_empty(), "No living trait badge after death")
	_expect(Split.trait_token({"type": "crawler"}).is_empty(), "Other enemies do not gain Splits")
	await _capture("board_status_plate")

	# Use the actual pre-battle screen, replacing only its debug preview state.
	var preview: Dictionary = scene.get("_run_state").duplicate(true)
	preview["combat_state"] = state.duplicate(true)
	scene.set("_pre_battle_preview_run_state", preview)
	scene.call("_rebuild_pre_battle_overlay")
	scene.get("_pre_battle_scrim").visible = true
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var panel: Control = scene.get("_pre_battle_panel")
	var source: Control = panel.find_child("PreBattleEnemyFlow", true, false).get_child(0)
	var split_tag: Control
	for tag: Control in source.find_child("PreBattleMoveTags", true, false).get_children():
		if tag.get_meta("icon_key", "") == "splits": split_tag = tag
	_expect(split_tag != null and split_tag.is_visible_in_tree(), "Splits tag visible in production lineup")
	var inspection: Control = scene.call("_build_pre_battle_enemy_inspection_panel", unit)
	canvas.add_child(inspection)
	_expect(inspection.find_child("EnemySplitTraitTitle", true, false).text == "Splits 2", "Production inspection has Splits trait")
	_expect(inspection.find_child("PreBattleKnownMoves", true, false).get_child_count() == Data.enemy_def("cinder_ooze")["intents"].size(), "Production inspection retains all known moves")
	inspection.queue_free()
	await process_frame
	if not semantic_only and split_tag != null:
		canvas.notify_mouse_entered()
		root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
		_motion(Vector2.ZERO)
		await process_frame
		_motion(split_tag.get_global_rect().get_center())
		await create_timer(HOVER_SECONDS).timeout
		_expect(_inspection_popup(canvas) != null, "Hovering Splits opens real inspection popup")
	await _capture("pre_battle_splits_hover")
	_motion(Vector2.ZERO)
	await process_frame
	scene.call("_close_pre_battle_preview")
	# Exercise the shipped keyword tooltip constructor, with canonical copy/icon.
	var keyword: Control = preload("res://scripts/inline_icon_text.gd").glossary_panel(Icons.tooltip("splits"))
	canvas.add_child(keyword)
	keyword.position = KEYWORD_PROOF_POSITION
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_expect(keyword.is_visible_in_tree(), "Splits keyword tooltip visible")
	await _capture("splits_keyword_tooltip")
	_finish("SPL01 SEMANTICS" if semantic_only else "SPL01 CAPTURE")

func _motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	canvas.push_input(motion, true)

func _inspection_popup(parent: Node) -> Window:
	for child: Node in parent.get_children(true):
		if child is Window and child.visible and child.find_child("PreBattleEnemyInspection", true, false) != null: return child
		var found: Window = _inspection_popup(child)
		if found != null: return found
	return null

func _capture(label: String) -> void:
	if semantic_only: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var path: String = OUTPUT.path_join(label + ".png")
	_expect(canvas.get_texture().get_image().save_png(path) == OK, "Saved " + label)
	print("SPL01 CAPTURE: " + path)

func _finish(label: String) -> void:
	for failure: String in failures: push_error(failure)
	print("%s: %s (%d checks, %d failures)" % [label, "PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
