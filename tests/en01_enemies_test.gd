extends SceneTree

const Suite = preload("res://tests/suites/en01_enemies_suite.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Combat = preload("res://scripts/combat_engine.gd")
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(Callable(self, "_expect"))
	_smoke_draw_branches.call_deferred()

# Dummy renderer execution catches draw-path/type errors. It creates no PNGs
# and does not establish visual acceptance or replace the windowed probe.
func _smoke_draw_branches() -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	root.add_child(board)
	board._load_assets()
	var engine := Combat.new()
	var buried: Dictionary = engine.resolve_enemy_turn_with_steps(Suite.fixture(), 0)["state"]
	board.set_combat_state(buried)
	var render_grub: Dictionary = board._visible_units().filter(func(unit: Dictionary) -> bool: return str(unit.get("type", "")) == "burrow_grub")[0]
	_expect(bool(render_grub.get("burrowed", false)), "Resolved Burrow reaches the body and HUD render dictionary")
	for _frame: int in range(3): await process_frame
	var rising: Dictionary = buried.duplicate(true)
	rising["enemies"][0]["burrowed"] = false
	rising["enemies"][0]["pos"] = Suite.FIXTURE_HERO_TILE
	board.set_combat_state(rising, [], [], Vector2i(-1, -1), "", "", {}, {}, {"en01_erupt": {"actor_key": "enemy_1", "progress": 0.5}, "en01_erupt_dust": {"actor_key": "enemy_1", "tile": Suite.FIXTURE_HERO_TILE, "progress": 0.5}})
	for _frame: int in range(3): await process_frame
	var ticks: Dictionary = Suite.fixture(["ember_tick", "ember_tick"])
	ticks["enemies"][0]["kindled_bonus"] = 2
	board.set("_hover_tile", ticks["enemies"][0]["pos"])
	board.set_combat_state(ticks)
	var render_tick: Dictionary = board._visible_units().filter(func(unit: Dictionary) -> bool: return str(unit.get("key", "")) == "enemy_1")[0]
	_expect(int(render_tick.get("kindled_bonus", 0)) == 2, "Resolved Kindle reaches the glow renderer")
	for _frame: int in range(3): await process_frame
	var after: Dictionary = engine._damage_enemy(ticks.duplicate(true), 0, 6)
	board.set_combat_state(after, [], [], Vector2i(-1, -1), "", "", {}, {}, {"en01_burst": after["death_burst_events"][0], "en01_burst_progress": 0.5})
	for _frame: int in range(3): await process_frame
	board.queue_free()
	await process_frame
	print("EN01 HEADLESS DRAW BRANCHES: executed; no renderer capture")
	for failure: String in _failures: push_error(failure)
	print("EN01 ENEMIES TEST RESULT: PASS" if _failures.is_empty() else "EN01 ENEMIES TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
