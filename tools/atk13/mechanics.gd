extends SceneTree
## Focused proof of facts, not assertions changing existing game expectations.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const EngineScript = preload("res://scripts/hero_facing_combat.gd")
const Typed = preload("res://scripts/typed_arrays.gd")
const FixtureHero := Vector2i(4, 5)
const FixtureCantor := Vector2i(4, 4)
const FixtureHealth: int = 9999
var assertions: int = 0
var failures: Array[String]
var results: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _arg(name: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _expect(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)

func _basis(source: Dictionary) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	state["player"]["pos"] = FixtureHero
	state["player"]["hp"] = FixtureHealth
	state["player"]["max_hp"] = FixtureHealth
	for field: String in ["block", "stoneskin", "shock", "freeze"]: state["player"][field] = 0
	state["surfaces"] = {}
	state["surface_events"] = []
	state["terrain"] = []
	state["traps"] = []
	var cantor: Dictionary = state["enemies"][0].duplicate(true)
	cantor["pos"] = FixtureCantor
	cantor["hp"] = 66
	cantor["max_hp"] = 66
	for field: String in ["block", "stoneskin", "shock", "freeze"]: cantor[field] = 0
	state["enemies"] = [cantor]
	state["battlefield_rule"] = Rules.instance_for("storm_cantor", int(cantor["id"]))
	return state

func _run() -> void:
	var source: Variant = str_to_var(FileAccess.get_file_as_string(_arg("--state")))
	_expect(source is Dictionary, "read real audit snapshot")
	if not source is Dictionary:
		quit(1)
		return
	var engine: RefCounted = EngineScript.new()
	var direct: Dictionary = _basis(source)
	Surface.place(direct, FixtureHero, "electrified")
	direct["turn"] = int(direct["turn"]) + 1 # cross real fuel-eligibility boundary
	var direct_after: Dictionary = Rules.fire(engine, direct.duplicate(true))
	_expect(int(direct_after["player"]["hp"]) == FixtureHealth - 3 and int(direct_after["player"]["shock"]) == 1, "Peal primary strike deals 3 AND Shock 1")
	results.append({"case": "direct", "after_hero": direct_after["player"]})
	var chain: Dictionary = _basis(source)
	Surface.place(chain, FixtureCantor, "electrified")
	chain["turn"] = int(chain["turn"]) + 1
	var projection: Dictionary = Rules.forecast(engine, chain)
	var chain_after: Dictionary = Rules.fire(engine, chain.duplicate(true))
	_expect(not Surface.has_surface(chain, FixtureHero, "electrified") and int(chain_after["player"]["hp"]) == FixtureHealth - 3 and int(chain_after["player"]["shock"]) == 1, "Peal Chain hits and Shocks hero on plain floor")
	_expect(not (projection["tiles"]["strike"] as Array).has(FixtureHero), "rule tile forecast omits off-field Chain hero tile")
	_expect((projection["hits"] as Array).any(func(hit: Dictionary) -> bool: return hit.get("actor_key") == "player"), "rule hit forecast retains Chain hero loss")
	results.append({"case": "chain", "projection": projection, "after_hero": chain_after["player"]})
	var arc: Dictionary = _basis(source)
	Surface.place(arc, FixtureHero, "electrified")
	var action: Dictionary = preload("res://scripts/game_data.gd").enemy_def("lightning_wisp")["intents"][2]["actions"][1]
	var arc_after: Dictionary = engine._resolve_board_attack(arc, action, FixtureHero, "enemy", int(arc["enemies"][0]["id"]), {}, Typed.vector2i([FixtureHero]))
	_expect(int(arc_after["player"]["shock"]) == 1, "conducted Capacitor Arc applies its conditional Shock")
	var plain: Dictionary = _basis(source)
	var plain_after: Dictionary = engine._resolve_board_attack(plain, action, FixtureHero, "enemy", int(plain["enemies"][0]["id"]), {}, Typed.vector2i([FixtureHero]))
	_expect(int(plain_after["player"].get("shock", 0)) == 0, "unassisted Capacitor Arc does not Shock")
	results.append({"case": "arc", "assisted_hero": arc_after["player"], "plain_hero": plain_after["player"]})
	# Existing asset decoding is inspection, not art creation or rendering.
	var format = preload("res://scripts/tooltip_loop_format.gd")
	var file := FileAccess.open("res://assets/tooltip_loops/lightning_strikes.tlw", FileAccess.READ)
	var info: Dictionary = format.header(file)
	_expect(not info.is_empty(), "approved Lightning Strikes loop decodes")
	var out: String = _arg("--output-dir")
	DirAccess.make_dir_recursive_absolute(out)
	if not info.is_empty():
		for sample: int in [0, int(info["count"]) / 2, int(info["count"]) - 1]:
			var picture: Image = format.read_frame(file, info, sample)
			_expect(picture != null and picture.save_png(out.path_join("approved-loop-%d.png" % sample)) == OK, "inspect approved loop frame")
	var report := FileAccess.open(out.path_join("mechanics.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"synthetic_fixture_from": _arg("--state"), "results": results, "failures": failures}, "  "))
	report.close()
	for failure: String in failures: push_error(failure)
	print("ATK13 MECHANICS: %s (%d assertions)" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
