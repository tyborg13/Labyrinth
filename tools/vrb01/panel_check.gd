extends SceneTree

const Cards = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Hover = preload("res://scripts/card_keyword_hover.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const PoolFixture = preload("res://tests/suites/card_pool_overhaul_suite.gd")
const RelicCopy = preload("res://tests/suites/inline_icon_description_suite.gd")
const CARD_IDS: Array = [
	"spike_mantle", "capacitor", "charged_orb", "headlong", "shadow_gate", "sworn_oath",
	"whetstone", "galvanize", "hourglass_sand", "spur_spark", "static_rush", "stolen_moment",
]
var _checks: int
var _failures: int

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: String in CARD_IDS:
		var card: Dictionary = Cards.card_def(id)
		var entries: Array[Dictionary] = Hover.entries_for_card(id, Icons.rows_for_card(card))
		var descriptions: Array = entries.map(func(entry: Dictionary) -> String: return "%s [%s]" % [entry["title"], entry["icon"]])
		print("PANELS %s: %s" % [id, ", ".join(descriptions)])
		_expect(entries.all(func(entry: Dictionary) -> bool: return entry["icon"] not in Icons.CONTEXTUAL_ART), id + " sentence omits retired panels")
		for key: String in Icons.CONTEXTUAL_ART:
			_expect(not Grimoire.entry_ids_for_card_def(card).has("keyword:" + key), id + " omits retired discovery links")
	for key: String in Icons.CONTEXTUAL_ART:
		_expect(Grimoire.entry_def("keyword:" + key).is_empty(), key + " has no Grimoire page")
	_expect(Grimoire.entry_def("keyword:time")["body"].has("A card always costs at least 1 Time."), "The Grimoire Time page states the floor")
	PoolFixture._test_wave23_grimoire_unlocks(_expect)
	PoolFixture._test_wave4_hand_rows_roles_and_grimoire(_expect)
	RelicCopy.run(_expect)
	print("VRB01 PANEL AND GRIMOIRE CHECKS: %d checks, %d failures" % [_checks, _failures])
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
