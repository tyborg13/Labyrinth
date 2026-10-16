extends RefCounted

const Run = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")

# Proof-only fixture values; production card definitions remain authoritative.
const CRATE_TILE := Vector2i(3, 3)
const TRAP_TILE := Vector2i(2, 4)
const ILLUSION_TILE := Vector2i(3, 4)
const PULL_START := Vector2i(5, 3)
const SURFACE_TILE := Vector2i(3, 2)
const CRATE_HP: int = 2
const ILLUSION_HP: int = 2
const PULL_HP: int = 100
const PULL_TRAP_DAMAGE: int = 200
const PULL_LIGHT_RADIUS: int = 2
const PULL_LIGHT_DURATION: int = 3
const FOLLOWUP_ACTION: Dictionary = {"type": "ranged", "damage": 1, "range": 4}
const FOLLOWUP_TARGET := Vector2i(4, 3)
const DETONATE_ACTION: Dictionary = {"type": "detonate", "damage": 60, "range": 4}

static func fixture() -> Dictionary:
	var state: Dictionary = Base.fixture(Combat.new())
	state["terrain"] = [{"id": "ux05_crate", "kind": "wooden_crate", "pos": CRATE_TILE, "hp": CRATE_HP, "max_hp": CRATE_HP}]
	state["traps"] = [{"id": "ux05_trap", "pos": TRAP_TILE, "element": "fire", "damage": CRATE_HP}]
	state["illusions"] = [{"id": 1, "pos": ILLUSION_TILE, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}]
	return state

static func run(expect: Callable) -> void:
	preload("res://tests/suites/destruction_preview_privacy_suite.gd").run(expect)
	var scene := Run.new()
	var combat := Combat.new()
	var before: Dictionary = fixture()
	var snapshot: Dictionary = before.duplicate(true)
	scene.set("_combat_state", before)
	var actions: Array = Data.card_def("whirlwind_slash").get("actions", [])
	var confirmation: Dictionary = scene.call("_card_preview_from_state", "whirlwind_slash", before, actions, 0)
	var after: Dictionary = confirmation["state"]
	expect.call(bool(confirmation.get("complete", false)) and int(after["terrain"][0]["hp"]) == 0, "Whirlwind Slash regression must reach confirmation with a destroyed 2-HP crate")
	_check_crate(scene, before, after, expect, "Whirlwind Slash confirmation")
	expect.call((after.get("traps", []) as Array).is_empty(), "Whirlwind Slash regression must consume its triggered trap")
	var shown: Dictionary = scene.call("_combat_preview_display_state", after)
	expect.call((shown.get("traps", []) as Array).size() == 1, "Triggered trap stays drawn at its committed position")
	var losses: Dictionary = scene.call("_damage_preview_between_states", before, after)
	expect.call(bool((losses.get("trap_ux05_trap", {}) as Dictionary).get("lethal", false)), "Consumed trap receives a death mark")

	var consumed: Dictionary = combat.apply_player_action(before, Data.card_def("shattered_reflection")["actions"][0], ILLUSION_TILE)
	shown = scene.call("_combat_preview_display_state", consumed)
	losses = scene.call("_damage_preview_between_states", before, consumed)
	var board := Board.new()
	board.set("combat_state", shown)
	board.set("presentation", {"damage_preview": losses})
	var illusions: Array = []
	for unit: Dictionary in board.call("_build_visible_units"):
		if str(unit.get("role", "")) == "illusion": illusions.append(unit)
	expect.call(illusions.size() == 1 and bool(board.call("_unit_is_preview_lethal", illusions[0])), "Consumed illusion stays visible with the enemy death mark")
	if not illusions.is_empty():
		expect.call(int(board.call("_health_bar_fill_hp", illusions[0], losses.get("illusion_1", {}))) == 0, "Consumed illusion shows an empty HP bar")

	var pull_before: Dictionary = pull_fixture()
	scene.set("_combat_state", pull_before)
	var pulled: Dictionary = combat.apply_player_action(pull_before, Data.card_def("vacuum_line")["actions"][0], PULL_START)
	expect.call(int(pulled["enemies"][0]["hp"]) == 0 and pulled["enemies"][0]["pos"] != PULL_START, "Lethal pull regression must travel before dying on its destination trap")
	var force: Dictionary = {}
	scene.call("_append_forced_displacement_preview", force, pull_before, pulled)
	var ghosts: Array = force.get("preview_units", [])
	expect.call(ghosts.size() == 1, "Lethal pull keeps its destination ghost")
	board.set("combat_state", scene.call("_combat_preview_display_state", pulled))
	force["damage_preview"] = scene.call("_damage_preview_between_states", pull_before, pulled)
	board.set("presentation", force)
	var marked: int = 0
	for unit: Dictionary in board.call("_build_visible_units"):
		if bool(board.call("_unit_is_preview_lethal", unit)): marked += 1
	expect.call(marked == 2, "Lethal pull marks both the original and destination ghost")
	shown = scene.call("_combat_preview_display_state", pulled)
	expect.call(shown["enemies"][0]["pos"] == PULL_START, "Lethal pull retains the original at its committed position")

	scene.set("_combat_state", before)
	var two_actions: Array = actions.duplicate(true)
	two_actions.append(FOLLOWUP_ACTION)
	var intermediate: Dictionary = scene.call("_card_preview_from_state", "whirlwind_slash", before, two_actions, 0)
	expect.call(int(intermediate.get("action_index", -1)) == 1 and not bool(intermediate.get("complete", true)), "Two-action regression must stop at the second choice")
	_check_crate(scene, before, intermediate["state"], expect, "Intermediate two-action preview")
	expect.call(before == snapshot, "Preview adapters and simulation leave committed state unchanged")

	Ground.place(before, SURFACE_TILE, "fire")
	expect.call(Ground.has_surface(before, SURFACE_TILE, "fire"), "Surface regression starts with committed Fire")
	var detonated: Dictionary = combat.apply_player_action(before, DETONATE_ACTION, SURFACE_TILE)
	shown = scene.call("_combat_preview_display_state", detonated)
	expect.call(not Ground.has_surface(detonated, SURFACE_TILE, "fire") and Ground.has_surface(shown, SURFACE_TILE, "fire"), "Consumed Fire remains drawn until resolution")
	Ground.place(detonated, SURFACE_TILE, "ice")
	shown = scene.call("_combat_preview_display_state", detonated)
	expect.call(Ground.has_surface(shown, SURFACE_TILE, "fire"), "A later surface replacement cannot hide consumed committed Fire")

	# Removed objects and lifetime terrain also need markers, even without HP.
	var removed: Dictionary = before.duplicate(true)
	removed["terrain"] = []
	_check_crate(scene, before, removed, expect, "Removed terrain")
	before["terrain"].append({"id": "ux05_ice", "kind": "ice_pillar", "pos": Vector2i(3, 5), "rounds_left": 1})
	scene.set("_combat_state", before)
	shown = scene.call("_combat_preview_display_state", removed)
	losses = scene.call("_damage_preview_between_states", before, removed)
	board.set("combat_state", shown)
	board.set("presentation", {"damage_preview": losses})
	var ice: Dictionary = (shown.get("terrain", []) as Array)[1] if (shown.get("terrain", []) as Array).size() > 1 else {}
	expect.call(Ground.terrain_is_live(ice) and bool((losses.get("terrain_ux05_ice", {}) as Dictionary).get("lethal", false)), "Removed lifetime terrain retains its body and death mark without adding a health bar")
	expect.call(not bool(board.call("_should_show_terrain_health_bar", ice)), "Lifetime terrain has no invented HP bar")
	_check_privacy(scene, expect)
	expect.call(snapshot == fixture(), "Preview regression fixture remains deterministic")
	board.free()
	scene.free()

static func pull_fixture() -> Dictionary:
	var state: Dictionary = fixture()
	state["terrain"] = []
	state["illusions"] = []
	state["enemies"][0]["pos"] = PULL_START
	state["enemies"][0]["hp"] = PULL_HP
	state["enemies"][0]["max_hp"] = PULL_HP
	state["umbra"]["light_sources"] = [{"pos": PULL_START, "radius": PULL_LIGHT_RADIUS, "duration": PULL_LIGHT_DURATION}]
	state["traps"] = [{"id": "ux05_pull_trap", "pos": Vector2i(4, 3), "element": "fire", "damage": PULL_TRAP_DAMAGE}]
	return state

static func _check_crate(scene: Node, before: Dictionary, after: Dictionary, expect: Callable, label: String) -> void:
	var shown: Dictionary = scene.call("_combat_preview_display_state", after)
	var losses: Dictionary = scene.call("_damage_preview_between_states", before, after)
	var terrain: Array = shown.get("terrain", [])
	expect.call(not terrain.is_empty() and Ground.terrain_is_live(terrain[0]) and terrain[0]["pos"] == CRATE_TILE, label + " retains the committed crate body")
	var board := Board.new()
	board.set("combat_state", shown)
	board.set("presentation", {"damage_preview": losses})
	var loss: Dictionary = losses.get("terrain_ux05_crate", {})
	expect.call(bool(loss.get("lethal", false)) and int(board.call("_health_bar_fill_hp", before["terrain"][0], loss)) == 0, label + " has a lethal empty-bar forecast")
	if not terrain.is_empty():
		expect.call(bool(board.call("_should_show_terrain_health_bar", terrain[0])), label + " keeps its HP bar visible")
	board.free()

static func _check_privacy(scene: Node, expect: Callable) -> void:
	var before: Dictionary = fixture()
	before["umbra"]["stage"] = "heart"
	before["traps"].append({"id": "hidden", "pos": Vector2i(8, 6), "element": "fire", "damage": 30})
	scene.set("_combat_state", before)
	var after: Dictionary = before.duplicate(true)
	after["traps"] = []
	var losses: Dictionary = scene.call("_sanitize_damage_preview_for_umbra_information", before, scene.call("_damage_preview_between_states", before, after))
	expect.call(not losses.has("trap_hidden"), "Limited Umbra never exposes hidden trap consumption")
	var presentation: Dictionary = {}
	if scene.has_method("_append_preview_trap_triggers"):
		scene.call("_append_preview_trap_triggers", presentation, before, after)
	var highlighted: Array = presentation.get("trap_trigger_previews", [])
	expect.call(highlighted.size() == 1 and highlighted[0].get("id") == "ux05_trap", "Limited Umbra highlights only currently visible triggered traps")
	before = pull_fixture()
	before["umbra"]["stage"] = "heart"
	scene.set("_combat_state", before)
	after = before.duplicate(true)
	after["enemies"][0]["hp"] = 0
	after["enemies"][0]["pos"] = Vector2i(8, 3)
	presentation = {}
	scene.call("_append_forced_displacement_preview", presentation, before, after)
	expect.call((presentation.get("preview_units", []) as Array).is_empty(), "Lethal destination ghosts never reveal an unseen destination")
