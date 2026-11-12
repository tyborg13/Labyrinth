extends "res://tools/rd03/capture.gd"

func _run() -> void:
	Fixture.install_save("/private/tmp/labyrinth_codex/rd-03/combat.json")
	canvas = Fixture.make_canvas(self)
	if OS.get_environment("RD03_BASELINE") == "1":
		root.set_meta("labyrinth_resume_saved_run", true)
		scene = load("res://scenes/run_scene.tscn").instantiate()
		scene.set_script(load("res://tools/rd03/_baseline_run_scene.gd"))
		scene.get_node("BoardUnderlay/CombatBoard").set_script(load("res://tools/rd03/_baseline_combat_board_view.gd"))
		canvas.add_child(scene)
	else: scene = Fixture.resume(self, canvas)
	await _settle()
	_dump("idle")
	await _select("dull_bolt")
	Fixture.pointer(self, scene.get("board_view"), scene.get("board_view").call("world_position_for_tile", _first_enemy()))
	await _settle()
	_dump("aiming")
	print("RD03 DIAGNOSTICS: PASS")
	quit()

func _dump(label: String) -> void:
	var board: Control = scene.get("board_view")
	var state: Dictionary = scene.get("_combat_state")
	print("RD03 DIAGNOSTIC ", label, " GRID ", state.grid)
	print("OBSTRUCTION SNAPSHOT ", board.get("_foreground_obstruction_entries_cache"))
	print("RD03 DIAGNOSTIC ", label, " PLAYER ", state.player.pos, " TERRAIN ", state.get("terrain", []))
	for unit: Dictionary in board.call("_visible_units"):
		print("UNIT ", unit.key, " tile=", unit.pos, " hud=", board.get("_hud_health_rects_cache").get(unit.key), " rect=", board.call("_unit_draw_rect", unit))
	var grid: Array = state.grid
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			if grid[y][x] != "pillar": continue
			var tile := Vector2i(x, y)
			var texture: Texture2D = board.get("_prop_textures").get("pillar")
			var rect: Rect2 = board.call("_prop_draw_rect", texture, board.call("_prop_rect_for_tile", tile))
			print("PILLAR ", tile, " alpha=", board.call("_foreground_blocker_tint", "pillar", tile, rect, board.get("_foreground_obstruction_entries_cache")).a)
	for entry: Dictionary in board.call("_health_bar_draw_entries", board.call("_visible_units")):
		if entry.terrain: print("TERRAIN BAR ", entry)
