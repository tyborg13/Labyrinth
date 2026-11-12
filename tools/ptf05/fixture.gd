extends RefCounted
const Base = preload("res://tools/ptf05/proof_base.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const ShortcutFixture = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const Audit = preload("res://tests/suites/card_targeting_audit_suite.gd")
const SEED: int = 1105
const ENEMY_FAR := Vector2i(6, 4)
const ENEMY_NEAR := Vector2i(4, 4)
const CRATE := Vector2i(3, 4)
const DARK_TILE := Vector2i(5, 4)
const FAR_MOVE := Vector2i(2, 7)
const FLOOR := Vector2i(3, 4)
const REASONS := {"out_of_range": "Out of range", "line_of_sight": "No line of sight", "dark": "Can't see there", "too_far": "Too far", "blocked": "Blocked", "invalid": "Not a valid target", "surface": "Out of range"}
const CASES := ["out_of_range", "line_of_sight", "dark", "too_far", "blocked", "invalid", "surface", "floor_hover", "strike", "reach", "maul_floor_strike"]

static func card_for(id: String) -> String:
	match id:
		"line_of_sight": return "pale_spark"
		"maul_floor_strike": return "tectonic_maul"
		"dark": return "shadow_step"
		"floor_hover", "strike": return "sidestep_slash"
	return "dull_bolt"

static func tile_for(id: String) -> Vector2i:
	match id:
		"out_of_range": return ENEMY_FAR
		"line_of_sight": return ENEMY_NEAR
		"dark": return DARK_TILE
		"too_far": return FAR_MOVE
		"blocked": return CRATE
		"strike": return Base.ENEMY_TILE
		"surface": return ENEMY_FAR + Vector2i.RIGHT
	return FLOOR

static func state(id: String) -> Dictionary:
	var engine := Combat.new()
	var result: Dictionary = ShortcutFixture._combat_state(engine, card_for(id), ENEMY_FAR if id == "out_of_range" else ENEMY_NEAR if id == "line_of_sight" else Base.ENEMY_TILE, SEED)
	result["umbra"] = {"stage": "clear", "radius": 2, "turns": 0}
	result["current_actor"] = {"kind": "player", "key": "player"}
	result["player_movement_remaining"] = 2
	result["terrain"] = []
	if id in ["out_of_range", "line_of_sight"]:
		var spare: Dictionary = result["enemies"][0].duplicate(true)
		spare["id"] = 2
		spare["pos"] = Vector2i(1, 4)
		result["enemies"].append(spare)
	if id in ["line_of_sight", "blocked"]:
		result["terrain"] = [{"id": "proof_crate", "kind": "wooden_crate", "pos": CRATE, "hp": 3, "max_hp": 3, "blocks_sight": true}]
	if id == "dark": result["umbra"] = {"stage": "heart", "radius": 1, "turns": 0}
	return result

static func install(scene: Node, id: String) -> void:
	# Retire the actual prompt/choices as well as the selection model.
	if scene.get("_surface_aim").active(): scene.call("_cancel_surface_skill_selection")
	var feedback = scene.call("_click_feedback")
	feedback.reason_started_usec = -1
	feedback._update_labels()
	if bool(scene.get("_player_movement_selected")): scene.call("_cancel_player_movement_selection", false)
	Audit._install(scene, state(id))
	scene.call("_refresh_ui")
	var dialogue: Control = scene.get("_dialogue_overlay")
	if dialogue != null: dialogue.hide()

static func select(scene: Node, id: String) -> void:
	if id in ["too_far", "blocked"]:
		scene.call("_begin_player_movement_selection")
	elif id == "surface":
		scene.get("_surface_aim").begin("proof_surface", false)
		scene.call("_refresh_surface_skill_selection")
	else:
		await scene.call("_on_card_pressed", 0)
