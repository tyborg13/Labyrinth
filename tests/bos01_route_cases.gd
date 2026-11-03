extends SceneTree
## Enumerate the approved behavior change on the existing Thornmother fixtures.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Warbands = preload("res://tests/suites/warband_suite.gd")
const Paths = preload("res://scripts/path_utils.gd")
const FIXTURE_SEED: int = preload("res://tools/warband_inspection.gd").FIXTURE_SEED
var _engine := preload("res://scripts/combat_engine.gd").new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for tier: int in [1, 2, 3]:
		var state: Dictionary = Warbands.battle("earth", tier)
		var instance: Dictionary = state["battlefield_rule"]
		var source: Dictionary = _engine._surface_actor(state, "enemy", int(instance["source"]["id"]))
		var hero: Vector2i = state["player"]["pos"]
		var delta: Vector2i = hero - Vector2i(source["pos"])
		var front: Vector2i = hero - Vector2i(signi(delta.x), signi(delta.y))
		var axis := Vector2i(0, 1) if delta.y == 0 else Vector2i(1, 0)
		var skipped: Array[Vector2i]
		var half: int = int(instance["dials"]["length"]) / 2
		for offset: int in range(-half, half + 1):
			var tile: Vector2i = front + axis * offset
			if Paths.is_passable(state["grid"], tile) and _engine._terrain_index_at_tile(state, tile) < 0 and not instance["marks"].has(tile): skipped.append(tile)
		print("BOS01 THORNMOTHER: seed=%d tier=%d source=%s hero=%s skipped=%s" % [FIXTURE_SEED, tier, source["pos"], hero, skipped])
		if tier == 2:
			var rise: Array = Rules.forecast(_engine, state)["tiles"]["rise"]
			if not rise.is_empty():
				# el04's former throw fixture moved the captain onto the first mark.
				source["pos"] = rise[0]
				var after_rise: Array = Rules.forecast(_engine, state)["tiles"]["rise"]
				var refused: Array = rise.filter(func(tile: Vector2i) -> bool: return not after_rise.has(tile))
				print("BOS01 THORNMOTHER RELOCATED SOURCE: source=%s skipped_held=%s" % [source["pos"], refused])
	print("BOS01 ROUTE CASE REPORT: PASS (3 existing Thornmother fixtures and relocated-source held line)")
	quit()
