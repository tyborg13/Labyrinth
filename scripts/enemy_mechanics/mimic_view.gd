extends RefCounted

const Rules = preload("res://scripts/enemy_mechanics/mimic.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

static func rows(board: Control, unit: Dictionary, intent: Dictionary) -> Array:
	if not Rules.handles_intent(intent): return []
	var engine = preload("res://scripts/combat_engine.gd").new()
	var index: int = engine._enemy_index_for_id(board.combat_state, int(unit.get("id", -1)))
	var current: Dictionary = engine.enemy_intent_plan(board.combat_state, index) if index >= 0 else {}
	var attack: Dictionary = current.get("attack_action", (intent["actions"][0] as Dictionary).get("copy", {}))
	if not bool(current.get("copy_reachable", true)): return [Icons.tokens_for_action(attack)]
	if attack.is_empty(): return []
	var tooltip: String = "Mirror: it copies the last attack you played — %s: %d damage." % [str(intent.get("mirror_card_name", "")), int(attack["damage"])]
	var row: Array = Icons.tokens_for_action(attack)
	for token: Dictionary in row:
		token["tooltip"] = tooltip
		if str(token.get("icon", "")) == str(attack["type"]): token["icon"] = attack.get("_copied_icon", token["icon"])
	return [row]

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	if step.has("move_step"):
		await scene._animate_move_step(state, step["move_step"])
		state.merge(step["move_after"].duplicate(true), true)
	var effect: Dictionary = step.duplicate(true)
	# Enemy presentation uses the existing attack renderer and cue families.
	scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_step(step))
	await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, scene.ATTACK_FRAME_SECONDS, func(frame: int) -> void:
		scene._render_board_state(state, {"effect": effect, "effect_progress": float(frame - 1) / float(scene.ATTACK_FRAMES)}, true)
	)
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})
	await scene._animate_floating_text_presentation(state, {"floating_texts": scene._floating_texts_for_target_losses(step.get("target_losses", []))})

static func display_intent(board: Control, unit: Dictionary, intent: Dictionary) -> Dictionary:
	if not Rules.handles_intent(intent): return intent
	var engine = preload("res://scripts/combat_engine.gd").new()
	var index: int = engine._enemy_index_for_id(board.combat_state, int(unit.get("id", -1)))
	if index < 0: return intent
	var result: Dictionary = intent.duplicate(true)
	var current: Dictionary = engine.enemy_intent_plan(board.combat_state, index)
	result["name"] = "Mirror: %s" % str(intent.get("mirror_card_name", "")) if bool(current.get("copy_reachable", false)) else "Shade Bolt"
	return result

static func presentation_for(state: Dictionary, original: Dictionary) -> Dictionary:
	var effect: Dictionary = original.get("effect", {})
	if not effect.is_empty() and not bool(effect.get("preview", false)): return original
	var result: Dictionary = original
	var engine = preload("res://scripts/combat_engine.gd").new()
	for index: int in range(state.get("enemies", []).size()):
		var enemy: Dictionary = state["enemies"][index]
		if not Rules.handles_intent(enemy.get("intent", {})) or int(enemy.get("hp", 0)) <= 0 or not engine.is_enemy_visible_to_player(state, enemy): continue
		if result == original: result = original.duplicate(true)
		var threat: Dictionary = engine.enemy_threat_tiles(state, index)
		threat["enemy_key"] = engine._enemy_key(enemy)
		var previews: Array = result.get("enemy_threat_previews", []).duplicate(true)
		previews = previews.filter(func(entry: Dictionary) -> bool: return str(entry.get("enemy_key", "")) != str(threat["enemy_key"]))
		previews.append(threat)
		result["enemy_threat_previews"] = previews
		if int(enemy.get("freeze", 0)) > 0: continue
		var context: Dictionary = engine.enemy_intent_plan(state, index, {}, bool(enemy.get("immobilize", false)), int(enemy.get("shock", 0)) > 0)
		var after: Dictionary = Rules.resolve(engine, state.duplicate(true), index, enemy["intent"]["actions"][0], context, [])
		var damage: Dictionary = result.get("damage_preview", {}).duplicate(true)
		for loss: Dictionary in engine._actor_target_losses(state, after):
			if damage.has(loss["key"]): continue
			var target: Dictionary = after["player"] if str(loss["key"]) == "player" else engine._surface_actor(after, "illusion", int(loss["id"]))
			damage[loss["key"]] = {"hp": int(target["hp"]), "damage": int(loss["hp_loss"]), "lethal": int(target["hp"]) <= 0}
		result["damage_preview"] = damage
	return result
