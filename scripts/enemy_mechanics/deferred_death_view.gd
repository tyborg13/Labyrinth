extends RefCounted

const Ownership = preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd")

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var before: Dictionary = state.duplicate(true)
	scene._apply_animation_step(state, step)
	if bool(step.get("cascade_bookkeeping", false)):
		scene._render_board_state(state, {})
		return
	var presentation: Dictionary = {"floating_texts": Ownership.floating_texts(scene, step), "impact_actor_keys": step.get("impact_actor_keys", [])}
	if str(step["action_type"]) == "death_burst" and not bool(step.get("cascade_continuation", false)):
		# Reuse the production burst effect and sound at its actual source tile.
		presentation["en01_burst"] = step["cascade"]
		presentation["en01_burst_progress"] = 0.0
		scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_action({"type": "aoe", "element": "fire"}))
	await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, presentation))
	await scene._animate_turn_order_alongside_defeats(before, state)

# Hidden cascades retain only visible affected tiles. Never submit the concealed
# source, its identity or its snapshots to ribbon/smoke presentation.
static func decorate_hidden_feedback(scene: Control, state: Dictionary, step: Dictionary, presentation: Dictionary) -> void:
	if str(step.get("action_type", "")) != "death_burst" or not step.has("cascade") or bool(step.get("cascade_continuation", false)) or bool(step.get("cascade_bookkeeping", false)):
		return
	var visible_tiles: Array[Vector2i] = scene._visible_umbra_action_tiles(state, step["cascade"].get("tiles", []))
	if visible_tiles.is_empty(): return
	presentation["en01_burst"] = {"tile": Vector2i(-1, -1), "tiles": visible_tiles}
	presentation["en01_burst_progress"] = 0.0
