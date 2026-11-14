extends SceneTree
## atk-01 minimal reproduction: replay one saved decision point headlessly.
##   godot --headless --path . --script res://tools/atk01/repro.gd -- <combat_state.txt> [tile x,y]
## Prints the at-rest danger flags, then the forecast cursor and the committed
## resolution activation by activation (hero and actor positions, losses).
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const INVALID := Vector2i(-1, -1)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var state: Dictionary = str_to_var(FileAccess.get_file_as_string(args[0]))
	var engine: RefCounted = preload("res://scripts/combat_engine.gd").new()
	var tile: Vector2i = INVALID
	if args.size() > 1:
		var parts: PackedStringArray = args[1].split(",")
		tile = Vector2i(int(parts[0]), int(parts[1]))
	print("hero ", state["player"]["pos"], " hp ", state["player"]["hp"], " block ", state["player"].get("block", 0), " turn ", state.get("turn"), " rule ", state.get("battlefield_rule", {}).get("rule", ""))
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: print("  enemy_%d %s at %s hp %d intent %s" % [enemy["id"], enemy["type"], enemy["pos"], enemy["hp"], JSON.stringify(enemy.get("intent", {}).get("actions", []))])
	var rest: Dictionary = Badges.build(engine, state, state)
	for badge: Dictionary in rest["badges"]:
		print("  flag %s danger=%s acting=%s cancelled=%s order=%s" % [badge["key"], badge["danger"], badge["acting"], badge["cancelled"], badge["order"]])
	for threat: Dictionary in rest["threats"]:
		print("  threat %s attack_tiles=%s" % [threat["key"], threat["tiles"]])
	var source: Dictionary = state
	if tile.x >= 0:
		source = engine.surface_preview_for_player_action(state, engine.player_movement_action(state), tile, true)["state"]
	print("FORECAST")
	var scheduled: Dictionary = engine.finish_player_activation(source)
	var cursor: Dictionary = engine.begin_revealed_enemy_actions_preview(scheduled, true)
	while not bool(cursor.get("complete", false)):
		var before: Dictionary = _snap(cursor["state"])
		var peek: Dictionary = engine._pop_next_actor(cursor["state"].duplicate(true)).get("entry", {})
		engine.advance_revealed_enemy_actions_preview(cursor)
		_print_slice(peek, before, _snap(cursor["state"]))
	print("  steps with player losses:")
	for step: Dictionary in cursor["steps"]:
		for loss: Dictionary in step.get("target_losses", []):
			if str(loss.get("key", "")) == "player": print("    %s %s %s hp-%d block-%d" % [step.get("kind", ""), step.get("actor_key", ""), step.get("action_type", ""), loss.get("hp_loss", 0), loss.get("block_loss", 0)])
	print("ACTUAL")
	var phase: Dictionary = state
	if tile.x >= 0:
		phase = engine.apply_player_movement(state, tile)
		Committed.accept(engine, phase)
	phase = Committed.finish_player_activation(engine, phase)
	for safety: int in range(100):
		if not engine.combat_outcome(phase).is_empty(): break
		var before: Dictionary = _snap(phase)
		var peek: Dictionary = engine._pop_next_actor(phase.duplicate(true)).get("entry", {})
		var slice: Dictionary = Committed.advance_one_activation(engine, phase, false)
		phase = slice["state"]
		_print_slice(peek, before, _snap(phase))
		for step: Dictionary in slice.get("steps", []):
			for loss: Dictionary in step.get("target_losses", []):
				if str(loss.get("key", "")) == "player": print("    %s %s %s hp-%d block-%d" % [step.get("kind", ""), step.get("actor_key", ""), step.get("action_type", ""), loss.get("hp_loss", 0), loss.get("block_loss", 0)])
		if bool(slice.get("complete", false)): break
	quit()

func _snap(state: Dictionary) -> Dictionary:
	var units: Dictionary = {"player": [state["player"]["pos"], int(state["player"]["hp"]), int(state["player"].get("block", 0))]}
	var rule: Dictionary = state.get("battlefield_rule", {})
	if not rule.is_empty(): units["rule"] = [str(rule.get("rule", "")), bool(rule.get("half_health_switched", false)), str(rule.get("dials", {}))]
	for enemy: Dictionary in state.get("enemies", []):
		units["enemy_%d" % int(enemy["id"])] = [enemy["pos"], int(enemy.get("hp", 0)), str(enemy.get("intent", {}).get("id", ""))]
	return units

func _print_slice(entry: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var label: String = "turn_start" if entry.is_empty() or str(entry.get("kind", "")) == "player" else "enemy_%d" % int(entry.get("enemy_id", -1))
	var changes: Array = []
	for key: String in after:
		if before.get(key) != after[key]: changes.append("%s %s->%s" % [key, before.get(key), after[key]])
	print("  slice %s: %s" % [label, "; ".join(changes)])
