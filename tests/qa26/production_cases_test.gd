extends SceneTree

const Cases = preload("res://tests/qa26/production_cases.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const PROOF_ENEMY_TILE := Vector2i(4, 4)
const PROOF_HERO_TILE := Vector2i(4, 6)
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for type: String in Action.Presentation.CREATURES:
		var authored: Dictionary = Action.data_for(type)
		var original: Dictionary = authored.duplicate(true)
		var expected: Dictionary = Cases.data_for(type, authored)
		var unplayed: Dictionary = Cases.unplayed_for(type)
		_expect(authored == original, type + ": protected source stays intact")
		for clip: String in authored["clips"]:
			if unplayed.has(clip):
				_expect(not expected["clips"].has(clip), type + ": no synthetic production " + clip)
			else:
				_expect(expected["clips"][clip] == authored["clips"][clip], type + ": live clip unchanged: " + clip)
		if type not in ["ember_hoarder", "slag_mortar", "hollow_mimic"]:
			_expect(expected == authored and unplayed.is_empty(), type + ": expectations unchanged")
		else:
			for clip: String in expected["clips"]:
				if clip in ["idle", "hit", "death"] or (type == "slag_mortar" and clip == "move"): continue
				var selector: String = Cases.selector_for(type, clip, str(expected["clips"][clip]["intents"][0]))
				var fields: PackedStringArray = selector.split(":")
				_expect(_has_action(type, fields[0], fields[1]), type + ": live fixture exists: " + selector)
	_expect(not _has_verb("ember_hoarder", "melee"), "Hoarder has no bite; expectation must be revisited if melee returns")
	_expect(not _has_verb("slag_mortar", "move_away") and not _has_verb("slag_mortar", "move_toward"), "Mortar has no live locomotion intent")
	_expect(not _has_verb("hollow_mimic", "block") and not _has_verb("hollow_mimic", "mirror_last_attack"), "Mimic has no live Block/Mirror action")
	_expect(_has_action("ember_tick", "scuttle", "melee") and Cases.data_for("ember_tick", Action.data_for("ember_tick"))["clips"].has("bite"), "Tick bite stays covered")
	_expect(Action.clip_for({"intent_id": "echo", "action_type": "ranged"}, {"type": "hollow_mimic"}) == "bolt", "Echo routes to the existing bolt clip")
	# The board's move dispatch owns this route independently of Tick's old
	# scuttle selector. Resolve the actual Scurry and Recede definitions.
	for type: String in ["ember_hoarder", "slag_mortar", "hollow_mimic"]:
		var intent: String = "scurry" if type == "ember_hoarder" else "brace" if type == "slag_mortar" else "recede"
		var actors: Array[Dictionary]
		actors.append(Fixtures.enemy(type, 1, PROOF_ENEMY_TILE, intent))
		var state: Dictionary = Fixtures.state(actors, PROOF_HERO_TILE)
		if type == "slag_mortar": state = Cases.mortar_retreat_state(state)
		var result: Dictionary = Combat.new().resolve_enemy_turn_with_steps(state, 0, true, false)
		var steps: Array = result["steps"]
		_expect(steps.any(func(step: Dictionary) -> bool: return str(step.get("kind", "")) == "move" and (step.get("path", []) as Array).size() > 1), type + ": real enemy turn submits a moving path")
		_expect(not steps.any(func(step: Dictionary) -> bool: return str(step.get("kind", "")) in (["melee", "summon"] if type == "slag_mortar" else ["melee", "block", "summon"])), type + ": turn does not synthesize retired actions")
	for failure: String in failures: push_error(failure)
	print("QA26 PRODUCTION CASES: %s (%d checks; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _has_action(type: String, intent: String, verb: String) -> bool:
	for item: Dictionary in Data.enemy_def(type)["intents"]:
		if item["id"] == intent:
			return (item["actions"] as Array).any(func(action: Dictionary) -> bool: return action["type"] == verb)
	return false

func _has_verb(type: String, verb: String) -> bool:
	for item: Dictionary in Data.enemy_def(type)["intents"]:
		if _has_action(type, str(item["id"]), verb): return true
	return false

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
