extends RefCounted

const Team = preload("res://scripts/board_unit_team_outlines.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const TEST_BLINK_OFFSET := Vector2(80, 40)
const TEST_DEATH_PROGRESS: float = 0.9

static func run(board: Control, overlay: Node2D, expect: Callable) -> void:
	var team: RefCounted = overlay.get("team")
	var entries: Dictionary = team.get("entries")
	var bodies: Dictionary = team.get("bodies")
	overlay._process(0.15)
	for unit: Dictionary in board.call("_visible_units"):
		var key: String = str(unit.get("key", ""))
		var wanted: bool = Team.eligible(board, unit)
		expect.call(entries.has(key) == wanted, "Team rim presence follows living visible units: " + key)
		if not wanted: continue
		var sprite: Sprite2D = entries[key]["sprite"]
		var body: Control = bodies[key]
		var tile: Vector2i = board.call("_effective_unit_tile", unit)
		expect.call(sprite.get_parent() == body and body.get_parent() == board.get("_scene_render_layers_by_tile")[tile], "Team rim shares original body's tile depth slot")
		expect.call(body.get("_render_layer_kind") == Team.KIND and body.z_index == 0 and sprite.z_index == 0, "No depth override on normal team rim")
		var draw: Dictionary = Sources.drawing(board, {"kind": "unit", "tile": tile, "data": unit})
		var body_draw: Dictionary = Sources.drawing(body, {"kind": "unit", "tile": tile, "data": unit})
		expect.call(body_draw == draw, "Original body canvas and rim share authoritative draw geometry and pose")
		expect.call(sprite.texture == draw["texture"] and sprite.position == draw["rect"].get_center(), "Normal rim follows exact current pose and drawn placement")
		expect.call(sprite.material.get_shader_parameter("rim_color") == Team.color_for(unit), "80% palette team colour, independent of body tint")
		if overlay.get("entries").has(key):
			expect.call(not sprite.visible and is_equal_approx(entries[key]["xray_alpha"], 0.85), "Full x-ray wins; normal rim is suppressed")
		else: expect.call(sprite.visible, "Uncovered unit keeps normal team rim")
	for key: String in entries: expect.call(bodies.has(key) and not key.contains(":"), "No props or tactical objects in normal team pass")
	# All per-unit canvases precede subsequent scene-tile occluders, preserving
	# painter coverage; even units sharing a tile retain their former order.
	var ordered: Dictionary = {}
	for unit: Dictionary in board.call("_visible_units"):
		var key: String = unit.get("key", "")
		if not bodies.has(key): continue
		var tile: Vector2i = board.call("_effective_unit_tile", unit)
		var body: Control = bodies[key]
		expect.call(body.get_index() == int(ordered.get(tile, 0)), "Units within one tile keep exact painter order")
		ordered[tile] = body.get_index() + 1
		for other: Node in board.get("_scene_render_layers"):
			var other_tile: Vector2i = other.get("_render_layer_tile")
			if board.call("_tile_draws_before", tile, other_tile): expect.call(body.get_parent().get_index() < other.get_index(), "Foreground tile covers both body and normal rim")
	for role: String in ["player", "ally", "summon", "illusion", "enemy"]:
		var unit: Dictionary = {"role": role, "shock": 99, "chilled": true, "block": 4}
		expect.call(Team.color_for(unit) == Color(Palette.DANGER if role == "enemy" else Palette.ALLY, 0.80), "Team colour ignores status/flash fields: " + role)
	for mask: float in [0.0, 0.25, 0.5, 1.0]:
		for fade: float in [0.0, 0.25, 0.5, 1.0]:
			var xray: float = 0.85 * fade
			var residual: float = Team.residual_alpha(0.80, xray, mask)
			var combined: float = xray * mask + residual * (1.0 - xray * mask)
			expect.call(is_equal_approx(combined, maxf(0.80, xray) * mask), "No alpha stacking anywhere during x-ray fades")
	board.call("set_unit_outline_alpha_multiplier", "player", 0.5)
	expect.call(is_equal_approx(team.get("entries")["player"]["base_alpha"], 0.40), "Aim integration hook halves normal outline alpha")
	if overlay.get("entries").has("player"):
		expect.call(is_equal_approx(overlay.get("entries")["player"]["sprite"].material.get_shader_parameter("rim_color").a, 0.425), "Aim hook also halves x-ray alpha")
	board.call("set_unit_outline_alpha_multiplier", "player", 1.0)
	var state: Dictionary = board.get("combat_state").duplicate(true)
	var shown: Dictionary = board.get("presentation").duplicate(true)
	var unrevealed: Dictionary = shown.duplicate(true)
	unrevealed["umbra_visible_tiles"] = []
	_submit(board, state, unrevealed)
	overlay.sync_coverage()
	expect.call(team.get("entries").is_empty() and overlay.get("entries").is_empty(), "Neither pass reveals units on unrevealed tiles")
	_submit(board, state, shown)
	overlay.sync_coverage()
	var moved: Dictionary = shown.duplicate(true)
	var player: Dictionary
	for unit: Dictionary in board.call("_visible_units"):
		if unit.get("key") == "player": player = unit
	moved["unit_world_positions"] = {"player": board.call("_unit_center", player) + TEST_BLINK_OFFSET}
	_submit(board, state, moved)
	overlay.sync_coverage()
	var entry: Dictionary = team.get("entries")["player"]
	var actual: Dictionary = Sources.drawing(board, {"kind": "unit", "data": entry["unit"], "tile": entry["tile"]})
	expect.call(entry["sprite"].position == actual["rect"].get_center(), "Blink/teleport rim follows sprite origin override")
	_submit(board, state, shown)
	overlay.sync_coverage()
	# Death fades only continue an outline already associated with a living
	# actor. No outline is created for a newly introduced dead/hidden actor.
	var dying: Dictionary
	for unit: Dictionary in board.call("_visible_units"):
		if unit.get("key") == "player": dying = unit.duplicate(true)
	var death_state: Dictionary = state.duplicate(true)
	death_state["player"]["hp"] = 0
	var death_shown: Dictionary = shown.duplicate(true)
	dying["death_animation"] = true
	dying["death_progress"] = TEST_DEATH_PROGRESS
	death_shown["death_animation_units"] = [dying.duplicate(true)]
	_submit(board, death_state, death_shown)
	overlay.sync_coverage()
	expect.call(team.get("entries").has("player"), "Existing living rim continues into death fade")
	if team.get("entries").has("player"):
		var expected_alpha: float = 0.80 * float(board.call("_health_bar_owner_alpha", team.get("entries")["player"]["unit"]))
		expect.call(is_equal_approx(team.get("entries")["player"]["base_alpha"], expected_alpha), "Death outline uses production owner fade")
	dying["death_progress"] = 1.0
	death_shown["death_animation_units"] = [dying.duplicate(true)]
	_submit(board, death_state, death_shown)
	overlay.sync_coverage()
	expect.call(not team.get("entries").has("player") or not team.get("entries")["player"]["sprite"].visible, "Terminal death has no visible rim")
	_submit(board, state, shown)
	overlay.sync_coverage()
	overlay.set_tool_enabled(false)
	for item: Dictionary in team.get("entries").values(): expect.call(not item["sprite"].visible, "Tool off disables every normal outline")
	for body: Control in team.get("bodies").values(): expect.call(not body.visible, "Baseline tool off restores original body pass")
	overlay.set_tool_enabled(true)
	overlay.sync_coverage()
	overlay._process(0.15)

static func _submit(board: Control, state: Dictionary, shown: Dictionary) -> void:
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
