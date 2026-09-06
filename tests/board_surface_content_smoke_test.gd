extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/board_surface_rules.gd")
const Fixture = preload("res://tests/suites/board_surface_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	var engine: Combat = Combat.new()
	var intent_count: int = 0
	for id: String in GameData.enemies():
		for raw: Dictionary in GameData.enemy_def(id).get("intents", []):
			var state: Dictionary = Fixture.fixture(engine)
			var enemy: Dictionary = state["enemies"][0]
			enemy["type"] = id
			enemy.erase("footprint")
			enemy = engine._normalized_enemy(enemy)
			state["enemies"][0] = enemy
			for tile: Vector2i in [Vector2i(4,3),Vector2i(5,3),Vector2i(4,4),Vector2i(5,4)]:
				Rules.place(state,tile,"rubble")
			for tile: Vector2i in [Vector2i(3,3),Vector2i(3,4),Vector2i(3,5)]:
				Rules.place(state,tile,"electrified")
			Rules.place(state,Vector2i(4,5),"ice")
			Rules.place(state,Vector2i(5,5),"fire")
			enemy["intent"] = engine._surface_prepare_enemy_intent(state,enemy,engine._scale_enemy_intent(raw,1))
			state["enemies"][0] = enemy
			var before: Dictionary = state.duplicate(true)
			engine.enemy_intent_plan(state,0)
			var result: Dictionary = engine.resolve_enemy_turn_with_steps(state,0)
			if state != before or not (result.get("state",{}) as Dictionary).has("surfaces"):
				failures.append("Enemy intent ownership/rules failure: %s/%s" % [id,raw.get("id","")])
			intent_count += 1
	var card_count: int = 0
	var action_count: int = 0
	for id: String in GameData.cards():
		var state: Dictionary = Fixture.fixture(engine)
		state["deck"]["hand"] = [id]
		for tile: Vector2i in [Vector2i(2,3),Vector2i(4,3),Vector2i(3,3)]:
			Rules.place(state,tile,"rubble")
			Rules.place(state,tile,"fire")
		for action: Dictionary in engine.card_play_actions(id,state):
			var target: Vector2i = state["player"]["pos"]
			if engine.player_action_needs_target(action):
				var legal: Array[Vector2i] = engine.valid_targets_for_player_action(state,action)
				if legal.is_empty():
					continue
				target = legal.front()
			var before: Dictionary = state.duplicate(true)
			var preview: Dictionary = engine.resolve_player_action_for_presentation(state,action,target)
			var actual: Dictionary = engine.apply_player_action(state,action,target)
			if actual != preview.get("state",{}) or state != before:
				failures.append("Card preview/ownership mismatch: %s/%s" % [id,action.get("type","")])
			state = actual
			action_count += 1
		card_count += 1
	for message: String in failures:
		push_error(message)
	print("BOARD SURFACE CONTENT SMOKE: cards=",card_count," actions=",action_count," intents=",intent_count," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
