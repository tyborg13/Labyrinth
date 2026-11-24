extends SceneTree

# Focused ports of txt-40 (237537e42) last_door_section_map and
# deferred_natural_repeat. The assertions express the promised behavior.
const Skills = preload("res://tests/suites/skill_run_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Events = preload("res://scripts/event_rules.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")

const SEED: int = Skills.SEED
const FIRST_REWARD := Vector2i(1, 0)
const OVERLAP_SEARCH_DEPTH: int = 2
const LETHAL_DAMAGE: int = 100
const VICTORY_HEALTH: int = 80
const RELEASE_SAVE: String = "res://.godot/gfix52/release-section.save"

var _run_engine := RunEngine.new()
var _combat_engine := Combat.new()
var _failures: int


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_last_door(args.has("--write-release-save"))
	_deferred_natural_repeat()
	_deferred_event_natural_repeat()
	if args.has("--load-release-save"):
		_load_release_save()
	print("GFIX-52 WITNESSES: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(int(_failures != 0))


func _last_door(write_release_save: bool) -> void:
	var start: Dictionary = Skills._new_run(_run_engine, ["last_door"])
	var origin: Vector2i = start["current_room"]
	var first: Vector2i = _run_engine.available_moves(start).front()
	var fight: Dictionary = _run_engine.begin_pre_battle_combat(_run_engine.move_to_pre_battle(start, first))
	var ready: bool = _run_engine.run_skill_is_ready(fight, "last_door")
	var predecessor: Vector2i = fight["skill_state"]["previous_room"]
	var reverse_link: bool = not _run_engine._connection_to_room(_run_engine.room_metadata(fight, first), predecessor).is_empty()
	if write_release_save:
		ProgressionStore.set_run_storage_path(RELEASE_SAVE)
		var saved: bool = ProgressionStore.save_run_state(fight)
		observe("release_section_save", saved, "%s (%d bytes)" % [RELEASE_SAVE, FileAccess.get_size(RELEASE_SAVE)])
	var result: Dictionary = _lose(fight)
	observe("last_door_section_map", ready and predecessor == origin and not reverse_link
		and _run_engine.room_metadata(fight, first)["type"] == "combat"
		and result["current_room"] == origin and result["mode"] == "room" and result["player_hp"] == 1,
		"ready=%s fight=%s previous=%s reverse_link=%s mode=%s current=%s Health=%d" %
		[ready, first, predecessor, reverse_link, result["mode"], result["current_room"], result["player_hp"]])


func _load_release_save() -> void:
	ProgressionStore.set_run_storage_path(RELEASE_SAVE)
	var saved: Dictionary = ProgressionStore.load_checkpoint_for_resume()
	if saved.is_empty():
		observe("load_release_section_save", false, "No release save at %s" % RELEASE_SAVE)
		return
	var fight: Dictionary = _run_engine.repair_loaded_run_state(saved)
	var ready: bool = _run_engine.run_skill_is_ready(fight, "last_door")
	var previous: Vector2i = fight["skill_state"]["previous_room"]
	var result: Dictionary = _lose(fight)
	observe("load_release_section_save", SectionMapGraph.enabled(fight) and fight["mode"] == "combat"
		and fight["current_room"] != previous and ready and result["mode"] == "room"
		and result["current_room"] == previous and result["player_hp"] == 1,
		"revision=%s resumed=%s current=%s previous=%s ready=%s after_loss=%s returned=%s Health=%d" %
		[fight["section_map_layout_revision"], fight["mode"], fight["current_room"], previous, ready,
			result["mode"], result["current_room"], result["player_hp"]])


func _lose(fight: Dictionary) -> Dictionary:
	var combat: Dictionary = fight["combat_state"].duplicate(true)
	combat["defiance_remaining"] = 0
	return _run_engine.finish_combat(fight, _combat_engine._damage_player(combat, LETHAL_DAMAGE, true))


func _deferred_natural_repeat() -> void:
	var progression: Dictionary = Skills._new_run(_run_engine, ["deferred_choice", "salvager"])["progression"]
	var start: Dictionary = _run_engine.create_new_run(SEED, progression, false)
	var first_reward: Dictionary = _reward_at(start, FIRST_REWARD)
	var offered: Array = first_reward["pending_reward"]["cards"]
	for lane: int in range(-OVERLAP_SEARCH_DEPTH, OVERLAP_SEARCH_DEPTH + 1):
		var coord := Vector2i(OVERLAP_SEARCH_DEPTH, lane)
		var baseline: Dictionary = _reward_at(_run_engine.skip_reward_for_heal(first_reward), coord)
		var natural: Array = baseline["pending_reward"].get("cards", [])
		for card: String in natural:
			# A natural hit in the replacement slot can yield the same final
			# offer after replacement. Witness a hit in another slot.
			if not offered.has(card) or card == natural.back():
				continue
			var actual: Dictionary = _reward_at(_run_engine.skip_reward_for_heal(first_reward, card), coord)
			var after: Array = actual["pending_reward"]["cards"]
			var pending: String = actual["skill_state"]["pending_card"]
			var has_replacement: bool = after.any(func(id: String) -> bool: return not natural.has(id))
			observe("deferred_natural_repeat", after.size() == 3 and after.count(card) == 1 and has_replacement and pending.is_empty(),
				"saved=%s natural=%s deferred=%s pending='%s'" % [card, natural, after, pending])
			return
	observe("deferred_natural_repeat", false, "Fixture search found no overlapping offers.")


func _deferred_event_natural_repeat() -> void:
	var state: Dictionary = Skills._deferred_event_state(_run_engine)
	var choice: String = Skills.DEFERRED_EVENT_CHOICE
	var baseline: Dictionary = _run_engine.resolve_map_event(state, choice)
	var natural: Array = baseline["event_state"]["outcomes"][0]["cards"]
	var saved: String = natural.front()
	state["skill_state"]["pending_card"] = saved
	var preview: Array = Events.preview_choice(state, choice)[0]["cards"]
	var result: Dictionary = _run_engine.resolve_map_event(state, choice)
	var generated: Array = result["event_state"]["outcomes"][0]["cards"]
	var reward: Dictionary = _run_engine.resolve_map_event(result, "continue")
	var actual: Array = reward["pending_reward"]["cards"]
	var pending: String = reward["skill_state"]["pending_card"]
	observe("deferred_event_natural_repeat", generated.size() == natural.size() and not generated.has(saved)
		and actual.size() == natural.size() and actual.count(saved) == 1 and actual == preview and pending.is_empty(),
		"event=%s saved=%s natural=%s generated=%s preview=%s reward=%s pending='%s'" %
		[Skills.DEFERRED_EVENT_ID, saved, natural, generated, preview, actual, pending])


func _reward_at(state: Dictionary, coord: Vector2i) -> Dictionary:
	var room: Dictionary = _run_engine.room_metadata(state, coord)
	room.merge({"type": "combat", "element": "fire", "cleared": false, "revealed": true,
		"sealed": false, "npcs": [], "merchant_kind": ""}, true)
	state["rooms"][_run_engine._room_key(coord)] = room
	state["current_room"] = coord
	state["mode"] = "pre_battle"
	var fight: Dictionary = _run_engine.begin_pre_battle_combat(state)
	var combat: Dictionary = fight["combat_state"]
	combat["objective"] = {"type": Objectives.KILL_ALL}
	combat["player"]["hp"] = VICTORY_HEALTH
	for index: int in range(combat["enemies"].size()):
		var enemy: Dictionary = combat["enemies"][index]
		combat = _combat_engine._damage_enemy(combat, index, enemy["hp"] + LETHAL_DAMAGE, false, true)
	return _run_engine.finish_combat(fight, combat)


func observe(id: String, ok: bool, observation: String) -> void:
	_failures += int(not ok)
	print("GFIX-52 %s | %s | %s" % [id, "PASS" if ok else "FAIL", observation])
