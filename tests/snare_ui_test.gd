extends SceneTree
const Suite = preload("res://tests/suites/snare_suite.gd")
const Rules = preload("res://scripts/snare_room_rules.gd")
const Fixture = preload("res://tools/snare_inspection.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
var failures: Array[String]

class ChipBoard extends "res://scripts/combat_board_view.gd":
	const TEST_DOOR_RECT := Rect2(100, 100, 100, 100)
	var queued_door_tiles: Array[Vector2i]
	func _ready() -> void: pass
	func _queue_scene_render_layer_for_tile(tile: Vector2i) -> void: queued_door_tiles.append(tile)
	func _door_texture_for_tile(_grid: Array, _tile: Vector2i) -> Texture2D: return null
	func _door_rect_for_tile(_tile: Vector2i, _grid: Array = []) -> Rect2: return TEST_DOOR_RECT

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var probe: Script = load("res://tests/snare_probe.gd")
	_expect(probe != null and probe.can_instantiate(), "Native Snare probe parses headless")
	var combat := Combat.new()
	var board := ChipBoard.new()
	root.add_child(board)
	board.combat_state = Suite.battle()
	board.presentation = {"reduced_motion": true}
	board._refresh_snare_chips()
	var holder: Node = board.get_node("SnareSealChips")
	_expect(_chips(holder) == _strings(["Seals · 2", "Seals · 4"]), "Opening chip wording and no icons")
	for chip: Control in holder.get_children():
		_expect(chip.get_child_count() > 0 and chip.mouse_filter == Control.MOUSE_FILTER_IGNORE and chip.focus_mode == Control.FOCUS_NONE, "Chips preserve board pointer and keyboard/controller paths")
		_expect(chip.position.y + chip.size.y == ChipBoard.TEST_DOOR_RECT.position.y, "Chip sits above its own door")
	board.combat_state = combat._damage_enemy(board.combat_state.duplicate(true), 1, 4, true, true, false, false)
	board._refresh_snare_chips()
	_expect(_chips(holder) == _strings(["Seals · 4"]) and not board._snare_door_sealed(board.combat_state["objective"]["exits"][1]["door_tile"]), "Killed binder removes chip without sealing")
	board.combat_state["objective"]["player_turns_completed"] = 4
	board.combat_state["objective"]["enemy_round_pending"] = true
	Rules.end_round(board.combat_state)
	board._refresh_snare_chips()
	_expect(_chips(holder).is_empty() and board._snare_door_sealed(board.combat_state["objective"]["exits"][2]["door_tile"]), "Sealed door has tint state and no chip")
	_expect(board._snare_sealing_threshold(board.combat_state["objective"]["exits"][2]["target_tile"]) and not board._snare_sealing_threshold(board.combat_state["objective"]["exits"][0]["target_tile"]), "Violet threshold tint persists after sealing and excludes the jailer threshold")
	var source: Dictionary = board._combat_submission_cache_source(board.combat_state)
	_expect(source["objective"] == board.combat_state["objective"], "Objective changes invalidate retained combat submissions")
	board._queue_combat_state_change_redraws({"objective": true}, {}, source, {}, {}, {})
	for exit: Dictionary in board.combat_state["objective"]["exits"]:
		_expect(board.queued_door_tiles.has(exit["door_tile"]), "Sealing redraws the actual retained door tile")
	board.combat_state = {}
	board._refresh_snare_chips()
	_expect(_chips(holder).is_empty(), "Chips leave when combat changes")
	board.queue_free()
	var engine := Run.new()
	var fixture_source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	for study: String in Fixture.CASES:
		var state: Dictionary = Fixture.build(engine, combat, fixture_source, {"snare_case": study})
		var battle: Dictionary = state["combat_state"]
		_expect(battle["objective"]["exits"].size() == 3, "Fire tier 2 has both sealing doors: " + study)
		if study == "first_seal": _expect(battle["objective"]["exits"][1]["sealed"], "Fixture reaches real first seal boundary")
		if study == "kept_open": _expect(battle["objective"]["exits"][1]["kept_open"] and not battle["objective"]["exits"][1]["sealed"] and battle["objective"]["sealbinders_killed"] == 1, "Fixture kills binder and passes its deadline")
		if study == "escape": _expect(combat.combat_outcome(battle) == "victory", "Fixture resolves legal exit step")
	await process_frame
	for failure: String in failures: push_error(failure)
	print("Snare UI/fixture suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: String in values: result.append(value)
	return result

func _chips(holder: Node) -> Array[String]:
	var labels: Array[String]
	for chip: Control in holder.get_children():
		if chip.visible: labels.append((chip.get_node("Title") as Label).text)
	return labels

func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)
