extends "res://scripts/run_engine.gd"

func _init() -> void:
	_combat_engine = preload("res://tests/fixtures/combat_creation_reference.gd").new()

func pre_battle_preview_state(run_state: Dictionary, _prepared: Dictionary = {}) -> Dictionary:
	if str(run_state.get("mode", "room")) != MODE_PRE_BATTLE:
		return {}
	var next_state: Dictionary = run_state.duplicate(true)
	var room: Dictionary = room_metadata(next_state, next_state.get("current_room", Vector2i.ZERO))
	if not _room_blocks_exit_reveal(room):
		return {}
	var travel_dir: Vector2i = next_state.get("pre_battle_travel_dir", Vector2i.ZERO)
	var layout: Dictionary = _combat_layout_for_room(room, travel_dir, next_state)
	var combat_state: Dictionary = _combat_engine.create_combat(int(next_state.get("seed", 0)), layout, _player_snapshot(next_state))
	combat_state = GuidedCombatScenario.prepare_for_run(next_state, combat_state)
	next_state["combat_state"] = combat_state
	next_state["mode"] = "combat"
	return next_state


func begin_pre_battle_combat(run_state: Dictionary, _prepared: Dictionary = {}) -> Dictionary:
	if str(run_state.get("mode", "room")) != MODE_PRE_BATTLE:
		return run_state.duplicate(true)
	var next_state: Dictionary = run_state.duplicate(true)
	var room: Dictionary = room_metadata(next_state, next_state.get("current_room", Vector2i.ZERO))
	if not _room_blocks_exit_reveal(room):
		return next_state
	var travel_dir: Vector2i = next_state.get("pre_battle_travel_dir", Vector2i.ZERO)
	var layout: Dictionary = _combat_layout_for_room(room, travel_dir, next_state)
	var combat_state: Dictionary = _combat_engine.create_combat(int(next_state.get("seed", 0)), layout, _player_snapshot(next_state))
	var authored_tutorial: bool = GuidedCombatScenario.should_prepare(next_state, combat_state)
	if _equipment_drop_can_attempt(next_state, room) and not authored_tutorial:
		next_state = _record_equipment_drop_attempt(next_state, layout)
	combat_state = GuidedCombatScenario.prepare_for_run(next_state, combat_state)
	next_state["combat_state"] = combat_state
	next_state["mode"] = "combat"
	_clear_pre_battle_state(next_state)
	return next_state


func _combat_layout_for_room(room: Dictionary, travel_dir: Vector2i, run_state: Dictionary) -> Dictionary:
	var layout_room: Dictionary = room.duplicate(true)
	if _room_has_recovery_marker(room):
		layout_room["type"] = "combat"
		if not ElementData.is_elemental(str(layout_room.get("element", ElementData.NONE))):
			layout_room["element"] = _room_element_for_coord(int(run_state.get("seed", 0)), layout_room.get("coord", Vector2i.ZERO), "combat")
	if str(layout_room.get("type", "combat")) == "combat":
		layout_room[CombatObjectiveRules.ONBOARDING_ROOM_KEY] = not _run_has_completed_combat(run_state)
	var equipment_drop: String = _equipment_drop_for_room(run_state, layout_room)
	if not equipment_drop.is_empty():
		layout_room["equipment_drop"] = equipment_drop
	var layout: Dictionary = _room_generator.generate_room(int(run_state.get("seed", 0)), layout_room, travel_dir)
	layout = _layout_with_recovery_loot(layout, room, run_state)
	if has_run_skill(run_state, "true_bearing") and typeof(run_state.get("pre_battle_start", null)) == TYPE_VECTOR2I:
		var chosen_start: Vector2i = run_state.get("pre_battle_start", Vector2i(-1, -1))
		if _layout_accepts_pre_battle_start(layout, chosen_start):
			layout["player_start"] = chosen_start
	return layout

