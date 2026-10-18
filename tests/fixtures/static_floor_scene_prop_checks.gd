extends RefCounted

const Capture = preload("res://tests/fixtures/static_floor_diff_capture.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const PILLAR_TILE := Vector2i(6, 6)
const UNAFFECTED_PILLAR_TILE := Vector2i(2, 2)
const OCCLUDING_HERO_TILE := Vector2i(5, 5)
const BRAZIER: Dictionary = {"kind": "watch_brazier_lit", "tile": Vector2i(5, 4), "width_scale": 0.60, "baseline_scale": 0.36}
const MOSS_HERO_TILE := Vector2i(6, 5)
const MOSS_BRAZIER_TILE := Vector2i(5, 5)

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

static func check_moss_obstruction(tree: SceneTree, source: Control, expect: Callable) -> void:
	var view: SubViewport = Capture.fresh_view(tree, source)
	var board: Control = view.get_child(0)
	var state: Dictionary = source.combat_state.duplicate(true)
	state["player"]["pos"] = MOSS_HERO_TILE
	state["moss"]["pillar"] = [PILLAR_TILE]
	var presentation: Dictionary = source.presentation.duplicate(true)
	presentation["scene_props"] = []
	_submit(board, state, presentation)
	var body_before: float = _pillar_alpha(board)
	var moss_before: float = _pillar_moss_alpha(board)
	expect.call(board._tile_has_moss("pillar", PILLAR_TILE) and board._moss_texture_for_surface("pillar", PILLAR_TILE) != null, "Moss regression must draw the pillar overlay")
	expect.call(body_before == Board.PILLAR_ACTOR_OBSTRUCTION_TINT.a, "Moss regression must start with the hero obstructing the body")
	expect.call(moss_before == Color.WHITE.a, "Moss regression must start with unobstructed moss")
	var full_redraws_before: int = board._full_dynamic_redraw_count
	var brazier: Dictionary = BRAZIER.duplicate(true)
	brazier["tile"] = MOSS_BRAZIER_TILE
	board.queued_scene_tiles.clear()
	presentation = presentation.duplicate(true)
	presentation["scene_props"] = [brazier]
	_submit(board, state, presentation)
	expect.call(_pillar_alpha(board) == body_before, "Moss onset must leave the body alpha unchanged")
	expect.call(_pillar_moss_alpha(board) == Board.FOREGROUND_OBSTRUCTION_TINT.a, "Moss onset must change the overlay to object-obstructed alpha")
	expect.call(board.queued_scene_tiles.has(PILLAR_TILE), "Scene prop onset must redraw a pillar whose moss alpha changes")
	check_unaffected(board, expect, "onset against moss")
	board.queued_scene_tiles.clear()
	presentation = presentation.duplicate(true)
	presentation["scene_props"] = []
	_submit(board, state, presentation)
	expect.call(_pillar_alpha(board) == body_before, "Moss removal must leave the body alpha unchanged")
	expect.call(_pillar_moss_alpha(board) == moss_before, "Moss removal must restore the overlay alpha")
	expect.call(board.queued_scene_tiles.has(PILLAR_TILE), "Scene prop removal must redraw a pillar whose moss alpha changes")
	check_unaffected(board, expect, "removal against moss")
	expect.call(board._full_dynamic_redraw_count == full_redraws_before, "Moss regression must exercise selective redraws without a full redraw")
	view.free()

static func _submit(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)

static func _pillar_alpha(board: Control) -> float:
	var texture: Texture2D = board._prop_textures["pillar"]
	var rect: Rect2 = board._prop_draw_rect(texture, board._prop_rect_for_tile(PILLAR_TILE))
	return board._foreground_blocker_tint("pillar", PILLAR_TILE, rect, board._foreground_obstruction_entries(board._visible_units())).a

static func _pillar_moss_alpha(board: Control) -> float:
	var texture: Texture2D = board._prop_textures["pillar"]
	var body_rect: Rect2 = board._prop_draw_rect(texture, board._prop_rect_for_tile(PILLAR_TILE))
	var moss_rect: Rect2 = board._pillar_moss_rect(body_rect)
	return board._foreground_blocker_tint("pillar", PILLAR_TILE, moss_rect, board._foreground_obstruction_entries(board._visible_units())).a
