extends RefCounted

const RunScene = preload("res://scripts/run_scene.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")


static func run(expect: Callable) -> void:
	_test_hidden_attack_keeps_only_visible_line(expect)
	_test_hidden_attack_keeps_isolated_visible_pocket(expect)
	_test_hidden_attack_keeps_separate_visible_spans(expect)
	_test_hidden_area_attack_keeps_only_visible_tiles(expect)
	_test_emerging_move_reveals_only_visible_samples(expect)
	_test_hidden_move_crossing_visible_pocket_animates(expect)
	_test_fully_hidden_move_keeps_private_fallback(expect)
	_test_action_fx_remain_below_hud(expect)


static func _test_hidden_attack_keeps_only_visible_line(expect: Callable) -> void:
	var scene := RunScene.new()
	var state: Dictionary = _state()
	var visible_step: Dictionary = scene.call("_visible_umbra_action_step", state, {
		"kind": "ranged",
		"action_type": "ranged",
		"actor_key": "enemy_71",
		"actor_name": "Needle Stalker",
		"from": Vector2i(6, 4),
		"to": Vector2i(2, 4),
		"element": "ice",
		"hidden_by_umbra": true,
		"hp_loss": 3,
	}) as Dictionary
	expect.call(not visible_step.is_empty(), "A hidden ranged attack entering the visible player halo should retain an animation step")
	expect.call(bool(visible_step.get("umbra_action_clipped", false)), "The visible ranged segment should identify itself as Umbra-clipped presentation")
	expect.call(not visible_step.has("hidden_by_umbra"), "The clipped ranged segment should route through the complete authored attack timeline")
	expect.call(str(visible_step.get("actor_name", "")) == "Unknown Presence", "Visible attack motion must not disclose the concealed enemy identity")
	expect.call(visible_step.get("from", Vector2i(-1, -1)) == Vector2i(4, 4), "The projectile should begin on the first visible line tile rather than disclose its concealed source")
	expect.call(visible_step.get("to", Vector2i(-1, -1)) == Vector2i(2, 4), "The clipped projectile should still reach the visible target")
	expect.call(visible_step.get("umbra_original_from", Vector2i(-1, -1)) == Vector2i(6, 4), "The clipped attack should retain its original source only as non-rendered animation metadata")
	var combat_engine: Variant = scene.get("_combat_engine")
	expect.call(not combat_engine.is_tile_visible_to_player(state, Vector2i(5, 4)), "The attack fixture should keep its original source side concealed")
	scene.free()


static func _test_hidden_area_attack_keeps_only_visible_tiles(expect: Callable) -> void:
	var scene := RunScene.new()
	var state: Dictionary = _state()
	var visible_step: Dictionary = scene.call("_visible_umbra_action_step", state, {
		"kind": "aoe",
		"action_type": "aoe",
		"actor_key": "enemy_71",
		"actor_name": "Needle Stalker",
		"from": Vector2i(6, 4),
		"to": Vector2i(3, 4),
		"center": Vector2i(5, 4),
		"tiles": [Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 4), Vector2i(3, 4)],
		"hidden_by_umbra": true,
	}) as Dictionary
	var effect_tiles: Array = visible_step.get("tiles", []) as Array
	expect.call(effect_tiles == [Vector2i(4, 4), Vector2i(3, 4)], "Area attacks should retain every visible footprint tile without exposing concealed tiles")
	expect.call(visible_step.get("center", Vector2i(-1, -1)) == Vector2i(4, 4), "A concealed area center should move to the first visible footprint tile for presentation")
	scene.free()


static func _test_hidden_attack_keeps_isolated_visible_pocket(expect: Callable) -> void:
	var scene := RunScene.new()
	var state: Dictionary = _state()
	(state.get("umbra", {}) as Dictionary)["light_sources"] = [{
		"id": "pocket",
		"pos": Vector2i(7, 2),
		"radius": 0,
		"remaining_activations": 2,
	}]
	var visible_step: Dictionary = scene.call("_visible_umbra_action_step", state, {
		"kind": "ranged",
		"action_type": "ranged",
		"actor_key": "enemy_71",
		"from": Vector2i(7, 4),
		"to": Vector2i(7, 0),
		"hidden_by_umbra": true,
	}) as Dictionary
	var segments: Array = visible_step.get("umbra_visible_line_segments", []) as Array
	expect.call(not visible_step.is_empty(), "A projectile crossing an isolated light pocket should retain a visible animation step")
	expect.call(visible_step.get("from", Vector2i(-1, -1)) == Vector2i(7, 2), "An isolated visible pocket may use one logical tile for its clipped endpoints")
	expect.call(visible_step.get("to", Vector2i(-1, -1)) == Vector2i(7, 2), "The isolated pocket fixture should exercise the formerly collapsed from/to case")
	expect.call(segments.size() == 1, "The isolated light pocket should produce one fractional visible span")
	if segments.size() == 1:
		var segment: Dictionary = segments[0] as Dictionary
		expect.call(float(segment.get("end", 0.0)) > float(segment.get("start", 1.0)), "A one-tile light pocket should retain non-zero projectile travel distance")
		expect.call(segment.has("start_hidden_tile") and segment.has("start_visible_tile"), "An isolated visible span should retain its exact entry edge for texture clipping")
		expect.call(segment.has("end_visible_tile") and segment.has("end_hidden_tile"), "An isolated visible span should retain its exact exit edge for texture clipping")
	var combat_engine: Variant = scene.get("_combat_engine")
	expect.call(not combat_engine.is_tile_visible_to_player(state, Vector2i(7, 4)), "The pocket attack source should remain concealed")
	expect.call(not combat_engine.is_tile_visible_to_player(state, Vector2i(7, 0)), "The pocket attack destination should return to concealment")
	scene.free()


static func _test_hidden_attack_keeps_separate_visible_spans(expect: Callable) -> void:
	var scene := RunScene.new()
	var state: Dictionary = _state()
	(state.get("umbra", {}) as Dictionary)["light_sources"] = [{
		"id": "pocket",
		"pos": Vector2i(6, 4),
		"radius": 0,
		"remaining_activations": 2,
	}]
	var visible_step: Dictionary = scene.call("_visible_umbra_action_step", state, {
		"kind": "ranged",
		"action_type": "ranged",
		"actor_key": "enemy_71",
		"from": Vector2i(7, 4),
		"to": Vector2i(2, 4),
		"hidden_by_umbra": true,
	}) as Dictionary
	var segments: Array = visible_step.get("umbra_visible_line_segments", []) as Array
	expect.call(segments.size() == 2, "A projectile should disappear between a light pocket and the player's separate visible halo")
	if segments.size() == 2:
		var first_segment: Dictionary = segments[0] as Dictionary
		var second_segment: Dictionary = segments[1] as Dictionary
		expect.call(float(first_segment.get("end", 1.0)) < float(second_segment.get("start", 0.0)), "Separated visible spans must retain the intervening hidden travel time")
	scene.free()


static func _test_emerging_move_reveals_only_visible_samples(expect: Callable) -> void:
	var scene := RunScene.new()
	var state: Dictionary = _state()
	var move_step: Dictionary = scene.call("_visible_umbra_action_step", state, {
		"kind": "move",
		"actor_key": "enemy_71",
		"actor_name": "Needle Stalker",
		"from": Vector2i(6, 4),
		"to": Vector2i(4, 4),
		"path": [Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 4)],
		"hidden_by_umbra": true,
		"revealed_after_action": true,
	}) as Dictionary
	expect.call(bool(move_step.get("umbra_reveal_actor_on_visible_tiles", false)), "An emerging move should opt into per-frame Umbra visibility")
	expect.call(not bool(scene.call("_umbra_movement_sample_visible", state, Vector2i(5, 4), Vector2i(4, 4), 0.25)), "The moving enemy should stay hidden while the sampled motion remains on the concealed tile")
	expect.call(bool(scene.call("_umbra_movement_sample_visible", state, Vector2i(5, 4), Vector2i(4, 4), 0.75)), "The moving enemy should become drawable once its sampled motion crosses onto the visible tile")
	var hidden_presentation: Dictionary = {}
	scene.call("_apply_umbra_board_presentation", state, hidden_presentation)
	expect.call(not (hidden_presentation.get("visible_enemy_ids", []) as Array).has(71), "A concealed enemy should remain absent without a visible animation sample")
	var emerging_presentation: Dictionary = {"umbra_action_visible_actor_keys": ["enemy_71"]}
	scene.call("_apply_umbra_board_presentation", state, emerging_presentation)
	expect.call((emerging_presentation.get("visible_enemy_ids", []) as Array).has(71), "A visible movement sample should temporarily admit the moving enemy to board rendering")
	scene.free()


static func _test_fully_hidden_move_keeps_private_fallback(expect: Callable) -> void:
	var scene := RunScene.new()
	var hidden_step: Dictionary = scene.call("_visible_umbra_action_step", _state(), {
		"kind": "move",
		"actor_key": "enemy_71",
		"from": Vector2i(6, 4),
		"to": Vector2i(5, 4),
		"hidden_by_umbra": true,
		"revealed_after_action": false,
	}) as Dictionary
	expect.call(hidden_step.is_empty(), "A move that remains entirely in the Umbra should keep the private result-only presentation")
	scene.free()


static func _test_hidden_move_crossing_visible_pocket_animates(expect: Callable) -> void:
	var scene := RunScene.new()
	var crossing_step: Dictionary = scene.call("_visible_umbra_action_step", _state(), {
		"kind": "move",
		"actor_key": "enemy_71",
		"from": Vector2i(6, 4),
		"to": Vector2i(6, 4),
		"path": [Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)],
		"hidden_by_umbra": true,
		"revealed_after_action": false,
	}) as Dictionary
	expect.call(not crossing_step.is_empty(), "A hidden move crossing a visible pocket should animate even when its destination returns to the Umbra")
	expect.call(bool(crossing_step.get("umbra_reveal_actor_on_visible_tiles", false)), "A crossing move should still opt into per-frame visibility clipping")
	scene.free()


static func _test_action_fx_remain_below_hud(expect: Callable) -> void:
	var board := CombatBoardView.new()
	board.call("_create_dynamic_render_layer")
	var effects: Control = board.get("_effects_render_layer") as Control
	var hud: Control = board.get("_hud_render_layer") as Control
	expect.call(effects.get_index() < hud.get_index(), "Action FX should preserve the standard scene order below combat HUD feedback")
	board.free()


static func _state() -> Dictionary:
	var grid: Array = []
	for _y: int in range(9):
		var row: Array = []
		for _x: int in range(9):
			row.append("floor")
		grid.append(row)
	return {
		"grid": grid,
		"turn": 1,
		"player": {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0},
		"enemies": [{
			"id": 71,
			"type": "crawler",
			"pos": Vector2i(6, 4),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"stoneskin": 0,
			"intent": {},
		}],
		"illusions": [],
		"terrain": [],
		"traps": [],
		"umbra": {"stage": "heart", "stage_reduction": 0, "light_sources": []},
	}
