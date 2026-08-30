extends RefCounted

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const GameData = preload("res://scripts/game_data.gd")


static func run(expect: Callable) -> void:
	_test_retained_layers_share_adaptive_framing_offset(expect)


static func _test_retained_layers_share_adaptive_framing_offset(expect: Callable) -> void:
	var board: CombatBoardView = CombatBoardView.new()
	board.size = Vector2(1900.0, 790.0)
	board.call("_create_dynamic_render_layer")
	var combat_presentation := {"board_framing_mode": "combat"}
	var ordinary_state: Dictionary = _state_with_enemy({
		"id": 92,
		"type": "harrier",
		"pos": Vector2i(4, 4),
		"hp": 20,
		"max_hp": 20,
		"intent": {},
	})
	board.set_combat_state(ordinary_state, [], [], Vector2i(-1, -1), "", "", {}, {}, combat_presentation)
	# This suite exercises the view without entering a SceneTree, so explicitly
	# apply the full-rect size that Godot normally propagates from the board.
	for layer_var: Variant in board.call("_retained_render_layers") as Array:
		var unshelved_layer: Control = layer_var as Control
		unshelved_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		unshelved_layer.size = board.size
	board.call("_board_origin")
	var ordinary_offset: float = float(board.get("_board_layout_cache_visual_top_offset"))

	var zekarion_def: Dictionary = GameData.enemy_def("zekarion")
	var footprint_data: Array = zekarion_def.get("footprint", [2, 2]) as Array
	var tall_state: Dictionary = _state_with_enemy({
		"id": 92,
		"type": "zekarion",
		"pos": Vector2i(1, 1),
		"footprint": Vector2i(int(footprint_data[0]), int(footprint_data[1])),
		"hp": int(zekarion_def.get("max_hp", 60)),
		"max_hp": int(zekarion_def.get("max_hp", 60)),
		"intent": {},
	})
	board.set_combat_state(tall_state, [], [], Vector2i(-1, -1), "", "", {}, {}, combat_presentation)
	# Materialize only the authoritative floor layout before the next visual
	# state arrives, matching card-resolution frames that do not draw every
	# retained actor layer between Blink and illusion creation.
	board.call("_board_origin")
	var tall_offset: float = float(board.get("_board_layout_cache_visual_top_offset"))
	expect.call(tall_offset > ordinary_offset, "Tall same-room content should earn adaptive top clearance before the retained-layer transition")

	var blink_state: Dictionary = ordinary_state.duplicate(true)
	(blink_state.get("player", {}) as Dictionary)["pos"] = Vector2i(5, 2)
	blink_state["illusions"] = [
		{"id": 1, "pos": Vector2i(5, 3), "hp": 3, "max_hp": 3},
		{"id": 2, "pos": Vector2i(4, 2), "hp": 2, "max_hp": 2},
	]
	board.set_combat_state(blink_state, [], [], Vector2i(-1, -1), "", "", {}, {}, combat_presentation)
	var parent_origin: Vector2 = board.call("_board_origin") as Vector2
	expect.call(
		is_equal_approx(float(board.get("_board_layout_cache_visual_top_offset")), tall_offset),
		"Blink/illusion presentation should retain the room's earned top clearance"
	)
	var actor_tiles: Array[Vector2i]
	actor_tiles.append(Vector2i(5, 2))
	actor_tiles.append(Vector2i(5, 3))
	actor_tiles.append(Vector2i(4, 2))
	actor_tiles.append(Vector2i(4, 4))
	for layer_var: Variant in board.call("_retained_render_layers") as Array:
		var layer: Control = layer_var as Control
		var layer_label: String = "%s:%s" % [str(layer.get("_render_layer_kind")), str(layer.get("_render_layer_tile"))]
		var layer_origin: Vector2 = layer.call("_board_origin") as Vector2
		expect.call(
			layer_origin.is_equal_approx(parent_origin),
			"Retained layer %s should use the parent floor's authoritative board origin after a same-frame visual transition" % layer_label
		)
		expect.call(
			is_equal_approx(float(layer.get("_board_layout_cache_visual_top_offset")), tall_offset),
			"Retained layer %s should inherit the parent floor's adaptive top clearance" % layer_label
		)
		for tile: Vector2i in actor_tiles:
			var parent_center: Vector2 = board.call("_tile_center", tile) as Vector2
			var layer_center: Vector2 = layer.call("_tile_center", tile) as Vector2
			expect.call(
				layer_center.is_equal_approx(parent_center),
				"Retained layer %s should center actor tile %s on the floor geometry" % [layer_label, tile]
			)
		# A hand-size/viewport change can invalidate a retained layer after the
		# parent has already retained clearance from an earlier animation snapshot.
		layer.call("_invalidate_board_layout_cache", false)
		var rebuilt_origin: Vector2 = layer.call("_board_origin") as Vector2
		expect.call(rebuilt_origin.is_equal_approx(parent_origin), "Rebuilt %s must reuse the floor origin instead of losing its retained top clearance" % layer_label)
		# Full-rect anchors may also settle after the owner's submission.
		layer.size += Vector2(0.0, 1.0)
		expect.call((layer.call("_board_origin") as Vector2).is_equal_approx(parent_origin), "Settling %s anchors must not independently reframe actors" % layer_label)
	board.free()


static func _state_with_enemy(enemy: Dictionary) -> Dictionary:
	return {
		"room_coord": Vector2i(4, 3),
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(2, 6), "hp": 24, "max_hp": 24},
		"enemies": [enemy],
		"illusions": [],
		"npcs": [],
		"terrain": [],
		"loot": [],
		"traps": [],
	}


static func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid
