extends RefCounted

const Capture = preload("res://tests/fixtures/static_floor_diff_capture.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const PILLAR_TILE := Vector2i(6, 6)
const UNAFFECTED_PILLAR_TILE := Vector2i(2, 2)
const OCCLUDING_HERO_TILE := Vector2i(5, 5)
const BRAZIER: Dictionary = {"kind": "watch_brazier_lit", "tile": Vector2i(5, 4), "width_scale": 0.60, "baseline_scale": 0.36}

static func check_unaffected(board: Control, expect: Callable, phase: String) -> void:
	expect.call(not board.queued_scene_tiles.has(UNAFFECTED_PILLAR_TILE), "Scene prop " + phase + " must not redraw an unaffected pillar")

static func check_already_obstructed(tree: SceneTree, source: Control, expect: Callable) -> void:
	# Independent scene fixture keeps the numbered native cases and their retained
	# histories intact. Submit actor movement before testing only the prop change.
	var view: SubViewport = Capture.fresh_view(tree, source)
	var board: Control = view.get_child(0)
	var state: Dictionary = source.combat_state.duplicate(true)
	state["player"]["pos"] = OCCLUDING_HERO_TILE
	var presentation: Dictionary = source.presentation.duplicate(true)
	presentation["scene_props"] = []
	_submit(board, state, presentation)
	var before: float = _pillar_alpha(board)
	expect.call(before == Board.PILLAR_ACTOR_OBSTRUCTION_TINT.a, "Already-obstructed regression must start at the actor-obstructed alpha")
	board.queued_scene_tiles.clear()
	presentation = presentation.duplicate(true)
	presentation["scene_props"] = [BRAZIER.duplicate(true)]
	_submit(board, state, presentation)
	expect.call(_pillar_alpha(board) == before, "Adding the brazier must preserve the already-obstructed pillar alpha")
	expect.call(not board.queued_scene_tiles.has(PILLAR_TILE), "Scene prop onset must not redraw a pillar already obstructed by the hero")
	check_unaffected(board, expect, "onset behind hero")
	board.queued_scene_tiles.clear()
	presentation = presentation.duplicate(true)
	presentation["scene_props"] = []
	_submit(board, state, presentation)
	expect.call(_pillar_alpha(board) == before, "Removing the brazier must preserve the already-obstructed pillar alpha")
	expect.call(not board.queued_scene_tiles.has(PILLAR_TILE), "Scene prop removal must not redraw a pillar still obstructed by the hero")
	check_unaffected(board, expect, "removal behind hero")
	view.free()

static func _submit(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)

static func _pillar_alpha(board: Control) -> float:
	var texture: Texture2D = board._prop_textures["pillar"]
	var rect: Rect2 = board._prop_draw_rect(texture, board._prop_rect_for_tile(PILLAR_TILE))
	return board._foreground_blocker_tint("pillar", PILLAR_TILE, rect, board._foreground_obstruction_entries(board._visible_units())).a
