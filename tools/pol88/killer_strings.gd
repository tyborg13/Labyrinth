extends SceneTree

const Score = preload("res://scripts/run_score_rules.gd")
const Chronicle = preload("res://scripts/chronicle_rules.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const DRAGON_DAMAGE: int = 20
const CONTROL_DAMAGE: int = 7
const DRAGONS := [
	["iskaldra", "Iskaldra", "Rime Tyrant", "rime_talon", "Rime Talon"],
	["tharokh", "Tharokh", "Worldspine", "worldspine_claw", "Worldspine Claw"],
	["vyraketh", "Vyraketh", "Cinder Crown", "cinder_maw", "Cinder Maw"],
	["vaeloryx", "Vaeloryx", "Hollow Gale", "razor_dive", "Razor Dive"],
	["noctyrax", "Noctyrax", "Last Eclipse", "void_claw", "Void Claw"],
	["zekarion", "Zekarion", "Raging Tempest", "storm_claw", "Storm Lash"],
]
const CONTROLS := [
	["ash_hound", "", "an Ash Hound"],
	["rimejaw", "", "a Rimejaw"],
	["rime_spitter", "recover", "a Rime Spitter's Frost Spit"],
]
const HISTORICAL_TEXT: String = "Felled by an Iskaldra, the Rime Tyrant"

var _failures: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var release: bool = OS.get_cmdline_user_args().has("--release")
	for dragon: Array in DRAGONS:
		var full_name: String = "%s, the %s" % [dragon[1], dragon[2]]
		var intent_subject: String = "%s's %s" % [dragon[1], dragon[4]]
		if release:
			full_name = ("an " if dragon[0] == "iskaldra" else "a ") + full_name
			intent_subject = "%s's %s" % [full_name, dragon[4]]
		_check_surfaces(dragon[0], "", DRAGON_DAMAGE, full_name)
		_check_surfaces(dragon[0], dragon[3], DRAGON_DAMAGE, intent_subject)
	for control: Array in CONTROLS:
		_check_surfaces(control[0], control[1], CONTROL_DAMAGE, control[2])
	var record := {"outcome": "defeat", "killer_text": HISTORICAL_TEXT}
	_check("stored Chronicle killer", Chronicle.display_killer_text(record), HISTORICAL_TEXT)
	_check("original record", str(record["killer_text"]), HISTORICAL_TEXT)
	var prefix: String = "POL88 RELEASE" if release else "POL88"
	print("%s %s" % [prefix, "PASS" if _failures == 0 else "FAIL (%d mismatches)" % _failures])
	quit(0 if _failures == 0 else 1)

func _check_surfaces(enemy_type: String, intent_id: String, damage: int, subject: String) -> void:
	var killer := {"enemy_type": enemy_type, "damage": damage}
	if not intent_id.is_empty():
		killer["intent_id"] = intent_id
	var expected: String = "Felled by %s" % subject
	var context: String = "%s / %s" % [enemy_type, "no intent" if intent_id.is_empty() else intent_id]
	_check("recap / " + context, Score.cause_text(killer, "defeat", 0), "%s, %d damage." % [expected, damage])
	_check("Chronicle / " + context, Chronicle.killer_text(killer, "defeat"), expected)

func _check(label: String, actual: String, expected: String) -> void:
	var matches: bool = actual == expected
	if not matches:
		_failures += 1
	print("%s | actual: %s | expected: %s | %s" % [label, actual, expected, "OK" if matches else "MISMATCH"])
