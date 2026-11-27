extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Path = preload("res://scripts/path_utils.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Prompt = preload("res://scripts/contextual_combat_prompt.gd")
const Run = preload("res://scripts/run_engine.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const FIXTURE_SEED: int = 90211
const MAX_ROOM_ENTRIES: int = 8
const ATTACK_CARD: String = "skybolt"
const LIGHT_CARD: String = "glowstone_ward"

var _combat := Combat.new()
var _run := Run.new()

func _initialize() -> void:
	_run_witness.call_deferred()

func _run_witness() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_witness_counter()
	var passed: bool = _witness_rules(_first_umbra_fight())
	print("TUT-02 UMBRA TRUTH WITNESS: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)

func _witness_counter() -> void:
	var definition: Dictionary = Tutorial.phase_definition(Tutorial.PHASE_FLOOR_LOOT)
	definition.erase("lesson")
	definition.erase("lesson_total")
	var prompt := Prompt.new()
	root.add_child(prompt)
	prompt.configure(definition)
	var label: Label = prompt.get("_progress_label")
	print("TUT-02 COUNTER WITNESS: omitted lesson fields, visible=%s, text=%s" % [label.is_visible_in_tree(), label.text])
	prompt.free()

func _first_umbra_fight() -> Dictionary:
	var profile: Dictionary = Tutorial.complete_tutorial(Progression.default_data())
	var state: Dictionary = _run.create_new_run(FIXTURE_SEED, profile)
	for _entry: int in range(MAX_ROOM_ENTRIES):
		var moves: Array[Vector2i] = _run.available_moves(state)
		if moves.is_empty():
			break
		state = _run.move_to_pre_battle(state, moves[0])
		if state["mode"] == Run.MODE_PRE_BATTLE:
			state = _run.begin_pre_battle_combat(state)
		var fight: Dictionary = state["combat_state"]
		print("TUT-02 ROUTE: seed=%d room=%s mode=%s stage=%s" % [FIXTURE_SEED, state["current_room"], state["mode"], _combat.effective_umbra_stage(fight)])
		if state["mode"] == "combat":
			if _combat.effective_umbra_stage(fight) != Combat.UMBRA_STAGE_CLEAR:
				return fight
			# Skip the earlier, clear fight's combat actions while retaining the
			# normal reward, room transitions, encounter generation and Umbra.
			for enemy: Dictionary in fight["enemies"]:
				enemy["hp"] = 0
			state = _run.finish_combat(state, fight)
		if state["mode"] == "reward":
			state = _run.skip_reward_for_heal(state)
		if state["mode"] == "campfire":
			state = _run.leave_campfire(state)
		if state["mode"] != "room":
			break
	return {}

func _unlit_distant_enemy(fight: Dictionary) -> int:
	var player: Vector2i = fight["player"]["pos"]
	var radius: int = _combat.effective_umbra_radius(fight)
	var enemies: Array = fight["enemies"]
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		var tile: Vector2i = enemy["pos"]
		if enemy["hp"] > 0 and Path.manhattan(player, tile) > radius and not _combat._light_source_covers_tile(fight, tile):
			return index
	return -1

func _witness_rules(fight: Dictionary) -> bool:
	if fight.is_empty() or not _combat.is_player_turn(fight):
		printerr("TUT-02 FIXTURE: expected a generated Umbra fight at a player turn")
		return false
	if _unlit_distant_enemy(fight) < 0:
		for destination: Vector2i in _combat.player_movement_targets(fight):
			var moved: Dictionary = _combat.apply_player_movement(fight, destination)
			if _unlit_distant_enemy(moved) >= 0:
				print("TUT-02 FIXTURE WALK: from=%s to=%s" % [fight["player"]["pos"], moved["player"]["pos"]])
				fight = moved
				break
	var player: Vector2i = fight["player"]["pos"]
	var light: Dictionary = _combat.card_play_actions(LIGHT_CARD, fight)[0]
	if _combat.valid_targets_for_player_action(fight, light).has(player):
		fight = _combat.apply_player_action(fight, light, player)
	var attack: Dictionary = _combat.card_play_actions(ATTACK_CARD, fight)[0]
	var targets: Array[Vector2i] = _combat.valid_targets_for_player_action(fight, attack)
	var sources: Array[Dictionary] = _combat.effective_light_sources(fight)
	var radius: int = _combat.effective_umbra_radius(fight)
	var index: int = _unlit_distant_enemy(fight)
	if index < 0:
		printerr("TUT-02 FIXTURE: generated fight has no living enemy outside both personal sight and all Light")
		return false
	var enemy: Dictionary = fight["enemies"][index]
	var tile: Vector2i = enemy["pos"]
	var darkened: bool = _combat.umbra_shadow_tiles(fight).has(tile)
	var hidden: bool = not _combat.is_enemy_visible_to_player(fight, enemy)
	var threat: Dictionary = _combat.enemy_threat_tiles(fight, index)
	var intent: Dictionary = enemy.get("intent", {})
	var intent_hidden: bool = not intent.is_empty()
	for key: String in ["move", "attack", "projected_path", "projected_attack"]:
		intent_hidden = intent_hidden and threat.get(key, []).is_empty()
	var targetable: bool = targets.has(tile)
	print('TUT-02 TRUTH 1: "Enemies on dark tiles are hidden" enemy=%s tile=%s distance=%d personal_radius=%d light_sources=%d darkened=%s hidden=%s' % [enemy["type"], tile, Path.manhattan(player, tile), radius, sources.size(), darkened, hidden])
	print('TUT-02 TRUTH 2: "you can\'t target them or see their intents." enemy=%s card=%s targetable=%s intent=%s displayed=%s' % [enemy["type"], Data.card_def(ATTACK_CARD)["name"], targetable, intent.get("id", ""), not intent_hidden])
	return darkened and hidden and not targetable and intent_hidden
