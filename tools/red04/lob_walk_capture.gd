extends "res://tools/qa103/proof.gd"
## Mount a real RunScene, take the normal movement-selection path, and aim
## a mouse pointer at a legal destination before capturing the floor.

const Fixture = preload("res://tools/brd01/fixture.gd")
const Encounters = preload("res://tools/qa103/encounters.gd")
const Battle = preload("res://tests/helpers/thr01_fixture.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Rules = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Slices = preload("res://scripts/board_layer_slices.gd")
const MORTAR := Vector2i(2, 4)
const HERO := Vector2i(4, 4)
const TARGET := HERO + Vector2i.RIGHT
const PREVIOUS_ARM := HERO + Vector2i.LEFT
const BOOT_FRAMES: int = 300
const INPUT_FRAMES: int = 12

func exercise() -> void:
	var run: Dictionary = Fixture.encounter("combat")
	var state: Dictionary = Battle.state([Battle.enemy("slag_mortar", 1, MORTAR, "lob_slag")], HERO)
	run = Fixture.Run.new().set_combat_state(run, state)
	var scene: Control = Fixture.mount(self, root, run, 1.0)
	check(scene != null, "Mount the Slag Mortar Walk fixture")
	if scene == null: return
	for frame: int in range(BOOT_FRAMES):
		if scene._dialogue_active: scene._close_dialogue()
		if Fixture.ready_for_input(scene): break
		await process_frame
	check(Fixture.ready_for_input(scene), "Combat is ready for Walk input")
	check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0), "UI scale is 100%")
	var board: Control = scene.board_view
	scene._begin_player_movement_selection()
	await frames(INPUT_FRAMES)
	check(scene._player_movement_target_tiles.has(TARGET), "Walk target is legal")
	var board_point: Vector2 = board.get_global_transform_with_canvas() * Vector2(board.world_position_for_tile(TARGET))
	Encounters.motion(root, board_point)
	await frames(INPUT_FRAMES)
	check(scene._hovered_board_tile == TARGET and scene._combat_state["player"]["pos"] == HERO, "Pointer hovers the destination without committing Walk")
	var preview: Dictionary = scene._enemy_intent_preview_state(scene._board_display_state())
	var expected: Dictionary = Rules.aiming_forecast(scene._combat_engine, preview, preview["enemies"][0])
	var marks: Dictionary = Lob.floor_marks(board)
	var centers: Array = marks.keys().filter(func(tile: Vector2i) -> bool: return marks[tile]["center"])
	var old_arm: Dictionary = Slices.threat_paint(board, PREVIOUS_ARM, {})
	var center: Dictionary = Slices.threat_paint(board, TARGET, {})
	check(centers == [TARGET] and centers == expected["centers"], "The preview destination is the only strong center")
	check(marks.size() == (expected["tiles"] as Array).size() and (expected["tiles"] as Array).all(func(tile: Vector2i) -> bool: return marks.has(tile)), "The floor uses the preview plan cross")
	check(old_arm.is_empty() and center.get("hero", false), "The old arm has no red and the new center pulses")
	print("RED05 LOB WALK: hovered=%s centers=%s floor=%s old_arm=%s" % [scene._hovered_board_tile, centers, marks.keys(), not old_arm.is_empty()])
	await capture("slag-mortar-walk")
	scene.queue_free()
	await process_frame
