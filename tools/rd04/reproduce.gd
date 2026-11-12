extends SceneTree

const Fixture = preload("res://tools/rd04/real_fixture.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const DEFAULT_MANIFEST: String = "/private/tmp/labyrinth_codex/rd-04/feedback2/overlap.json"
const SETTLE_FRAMES: int = 20
var scene: Node
var board: Control

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	Fixture.install_save(args[args.find("--fixture-manifest") + 1] if args.has("--fixture-manifest") else DEFAULT_MANIFEST)
	var canvas := Fixture.make_canvas(self)
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://tools/rd04/baseline.tscn").instantiate()
	canvas.add_child(scene)
	await _settle()
	board = scene.get("board_view")
	if scene.get("_combat_state") == null:
		quit(1)
		return
	var enemies: Array = scene.get("_combat_state")["enemies"]
	var enemy: Dictionary = enemies[0]
	var tile: Vector2i = enemy["pos"]
	var key := "enemy_%d" % int(enemy["id"])
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("key", "")) != key: continue
		board.call("_update_hover_at", (board.call("_unit_draw_rect", unit) as Rect2).get_center())
		await _record("board body centre")
		break
	board.call("_update_hover_at", board.call("_tile_center", tile))
	await _record("board footprint")
	for slot: Control in scene.get("_turn_order_bar").get_children():
		if str(slot.get_meta("turn_order_actor_key", "")) != "enemy:" + key: continue
		slot.mouse_entered.emit()
		await _record("rail portrait")
		slot.mouse_exited.emit()
		break
	scene.call("_on_board_tile_hovered", Vector2i(-1, -1))
	await _settle()
	for badge: Dictionary in Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])):
		if str(badge["key"]) != key: continue
		board.call("_update_hover_at", (badge["rect"] as Rect2).get_center())
		await _record("intent chip (floor hit test; no chip identity)")
		break
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	scene.set("_controller_region", "board")
	scene.call("_controller_set_board_tile", tile)
	await _record("controller board focus")
	for candidate: Dictionary in enemies:
		var details: Array = []
		for footprint_tile: Vector2i in scene.call("_enemy_footprint_tiles", candidate):
			details.append({"tile": str(footprint_tile), "content": board.controller_tooltip_for_tile(footprint_tile)})
		print("RD04 BEFORE MULTI %s: %s" % [candidate["type"], JSON.stringify(details)])
	print("RD04 BEFORE CAUSE: floor-only pointer hit test; tile-effects cache has no enemy entry; _get_tooltip returns the first registered leader region before floor fallback")
	quit()

func _record(label: String) -> void:
	await _settle()
	var alphas: Dictionary = {}
	for threat: Dictionary in board.presentation.get("threats_at_rest", {}).get("threats", []): alphas[threat["key"]] = threat["alpha"]
	print("RD04 BEFORE %s: alphas=%s detail_previews=%d hover=%s" % [label, JSON.stringify(alphas), board.presentation.get("enemy_threat_previews", []).size(), scene.get("_hovered_board_tile")])

func _settle() -> void:
	for frame in range(SETTLE_FRAMES): await process_frame
