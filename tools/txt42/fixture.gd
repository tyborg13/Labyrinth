extends RefCounted

# Seeded combat and progression setup adapted from txt-40 fixture.gd.

const Base = preload("res://tools/txt24/fixture.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Typed = preload("res://scripts/typed_arrays.gd")

const SEED: int = 73021
const PLAYER := Vector2i(3, 4)
const ENEMY := Vector2i(5, 4)
const HEALTH: int = 80
const EMBERS: int = 10000
const LETHAL_MARGIN: int = 100

var engine := Combat.new()
var run := Run.new()
var verdicts: Dictionary = {}


func observe(id: String, ok: bool, observation: String) -> void:
	verdicts[id] = ok
	print("TXT42 %s | %s | %s" % [id, "PASS" if ok else "FAIL", observation])


func profile(wanted: Array = []) -> Dictionary:
	var data: Dictionary = Profile.set_embers(Profile.default_data(), EMBERS)
	for skill: String in wanted:
		data = _learn(data, skill)
	return data


func _learn(data: Dictionary, skill: String) -> Dictionary:
	if Profile.has_skill(data, skill):
		return data
	for parent: String in Skills.prerequisites(skill):
		data = _learn(data, parent)
	while Profile.selected_skill_ids(data).size() < Skills.minimum_owned(skill):
		var added: bool = false
		for candidate: String in Profile.available_skill_ids(data):
			if Skills.is_keystone(candidate):
				continue
			var next: Dictionary = _spend_point(data, candidate)
			if Profile.has_skill(next, candidate):
				data = next
				added = true
				break
		if not added:
			break
	return _spend_point(data, skill)


func _spend_point(data: Dictionary, skill: String) -> Dictionary:
	if Profile.unspent_skill_points(data) == 0:
		data = Profile.purchase_level(data)
	var result: Dictionary = Profile.learn_skill(data, skill)
	if not Profile.has_skill(result, skill):
		observe("ownership_" + skill, false, "ProgressionStore did not learn the requested skill.")
	return result


func descent() -> Dictionary:
	return run.create_new_run(SEED, profile())


func fight(enemies: Array = []) -> Dictionary:
	var snapshot: Dictionary = run._player_snapshot(descent())
	snapshot.merge({"hp": HEALTH, "max_hp": HEALTH}, true)
	var layout: Dictionary = {
		"grid": Base.grid(), "player_start": PLAYER,
		"enemies": [unit(ENEMY)] if enemies.is_empty() else enemies,
	}
	return engine.create_combat(SEED, layout, snapshot)


func unit(pos: Vector2i, id: int = 0, kind: String = "crawler") -> Dictionary:
	return Base.unit(kind, id, pos)


func action(state: Dictionary, card: String, index: int = 0) -> Dictionary:
	return engine.card_def(card, state)["actions"][index]


func deck(state: Dictionary, hand: Array = [], draw: Array = [], discard: Array = []) -> void:
	state["deck"].merge({"hand": hand, "draw": draw, "discard": discard, "burned": [], "consumed": []}, true)


func tile_distance(start: Vector2i, end: Vector2i) -> int:
	return absi(start.x - end.x) + absi(start.y - end.y)
