extends SceneTree
const Fixture = preload("res://tools/ptf09/real_fixture.gd")
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")
func _run() -> void:
	Fixture.install_save("/private/tmp/labyrinth_codex/rd-07/combat.json")
	var canvas: SubViewport = Fixture.make_canvas(self)
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(load("res://tools/rd07/baseline_board.gd"))
	canvas.add_child(scene)
	for frame: int in range(30): await process_frame
	var board: Control = scene.get("board_view")
	for tile: Vector2i in [Vector2i(3, 4), Vector2i(3, 3)]:
		board.call("_update_hover_at", board.call("world_position_for_tile", tile))
		for frame: int in range(4): await process_frame
		var props: Array = []
		for entry: Dictionary in board.call("_health_bar_draw_entries", board.call("_visible_units")):
			if entry.terrain: props.append(entry.unit.get("pos"))
		print("RD07 BASELINE hover=%s prop_bars=%s attack_tiles=%s" % [tile, props, board.get("attack_tiles")])
	quit()
