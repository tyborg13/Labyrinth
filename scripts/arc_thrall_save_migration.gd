extends RefCounted
## Read compatibility is limited to live combat and its continuation snapshots.
const Data = preload("res://scripts/game_data.gd")
const HISTORY_FIELDS: PackedStringArray = ["analytics", "analytics_context", "analytics_events", "progression_analytics_outbox", "completed_run_results", "last_run_result", "log", "history", "surface_events", "elemental_source", "rubble_source"]
const SNAPSHOT_FIELDS: PackedStringArray = ["state", "before", "before_state", "move_after", "en03_after", "en06_after", "reaction_after", "trace_state_after", "blink_after", "after"]

static func migrate(run: Dictionary) -> void:
	if _is_snapshot(run):
		_walk_combat(run, run)
		return
	if _is_snapshot(run.get("combat_state")): _walk_combat(run["combat_state"], run["combat_state"])
	for checkpoint: Variant in run.get("pending_combat_checkpoints", []):
		if checkpoint is Dictionary and _is_snapshot(checkpoint.get("state")): _walk_combat(checkpoint, checkpoint["state"])

static func _is_snapshot(value: Variant) -> bool:
	return value is Dictionary and value.get("enemies") is Array and value.get("player") is Dictionary

static func _is_thrall(actor: Dictionary) -> bool:
	return str(actor.get("type", "")) == "arc_thrall"

static func _snapshot_context(snapshot: Dictionary, parent: Dictionary) -> Dictionary:
	# Partial presentation snapshots carry their roster but inherit encounter depth/rules.
	var context: Dictionary = parent.duplicate(false)
	context.merge(snapshot, true)
	return context

static func _walk_combat(value: Variant, battle: Dictionary) -> void:
	if value is Array:
		for child: Variant in value: _walk_combat(child, battle)
	elif value is Dictionary:
		if _is_snapshot(value):
			battle = _snapshot_context(value, battle)
			for enemy: Dictionary in value["enemies"]:
				if _is_thrall(enemy): _migrate_intent(enemy.get("intent", {}), battle, enemy)
		else:
			# A continuation/step may own a different roster from its parent.
			for key: String in SNAPSHOT_FIELDS:
				if _is_snapshot(value.get(key)):
					battle = _snapshot_context(value[key], battle)
					break
		var actor: Dictionary = _step_actor(value, battle)
		if _is_thrall(actor): _migrate_step(value, battle, actor)
		for key: Variant in value:
			if str(key) not in HISTORY_FIELDS and not str(key).ends_with("_history") and str(key) != "intent": _walk_combat(value[key], battle)

static func _step_actor(step: Dictionary, battle: Dictionary) -> Dictionary:
	var key: String = str(step.get("actor_key", ""))
	var id: int = -1
	if key.begins_with("enemy_") and key.trim_prefix("enemy_").is_valid_int(): id = int(key.trim_prefix("enemy_"))
	elif key.is_empty(): id = int(step.get("enemy_id", -1))
	for enemy: Dictionary in battle.get("enemies", []):
		if int(enemy.get("id", -2)) == id: return enemy
	return {}

static func _migrate_intent(intent: Dictionary, battle: Dictionary, actor: Dictionary) -> void:
	if str(intent.get("id", "")) == "tether" and intent.has("actions"):
		intent.clear()
		intent.merge(_current_intent(battle, actor), true)
	else:
		for action: Dictionary in intent.get("actions", []):
			if str(action.get("type", "")) == "tether_beam" or str(action.get("pattern", "")) == "line_between_thralls": _migrate_step(action, battle, actor)

static func _migrate_step(step: Dictionary, battle: Dictionary, actor: Dictionary) -> void:
	var retired: bool = str(step.get("type", "")) == "tether_beam" or str(step.get("action_type", "")) == "tether_beam" or str(step.get("kind", "")) == "tether_beam" or str(step.get("pattern", "")) == "line_between_thralls" or (str(step.get("action_type", "")) == "lightning_strikes" and step.has("en03_after"))
	if retired:
		if step.has("type"): step.merge(_current_intent(battle, actor)["actions"][1], true)
		if step.has("kind") or step.has("action_type"):
			step["kind"] = "ranged"
			step["action_type"] = "ranged"
		step["element"] = "lightning"
		step["label"] = "Arc Bolt"
		step["intent_id"] = "arc_bolt"
		step.erase("pattern")
	if str(step.get("intent_id", "")) == "tether": step["intent_id"] = "arc_bolt"
	step.erase("tether_plan")
	if step.get("intent") is Dictionary: _migrate_intent(step["intent"], battle, actor)

static func _current_intent(battle: Dictionary, actor: Dictionary) -> Dictionary:
	# Runtime loading keeps the save store outside the combat preload graph.
	var engine: RefCounted = load("res://scripts/combat_engine.gd").new()
	return engine._scale_enemy_intent(Data.enemy_def("arc_thrall")["intents"][0], int(battle.get("room_depth", 1)), battle, actor)
