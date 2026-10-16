extends SceneTree

const Probe = preload("res://tools/demo_clips/probe.gd")
const Pointer = preload("res://tools/demo_clips/pointer.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tools/demo_clips/fixture.gd")
var failures: Array[String]

class InputEcho extends Node:
	var position := Vector2(-1, -1)
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion: position = event.position

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(3024, 1701)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var viewport: SubViewport = Probe.create_viewport(root)
	var listener := InputEcho.new()
	viewport.add_child(listener)
	await process_frame
	if viewport.size != Vector2i(1920, 1080): failures.append("probe viewport follows root backing size")
	if listener.get_viewport() != viewport: failures.append("staged node is outside the probe viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(720, 430)
	viewport.push_input(motion, true)
	if listener.position != motion.position: failures.append("hover input did not reach the probe viewport")
	# Exercise Control GUI dispatch and actual tile picking, not just _input.
	# The host backing scale must not be applied to viewport-local event coords.
	var container: Control = viewport.get_parent() as Control
	container.scale = Vector2(3024.0 / 1920.0, 1701.0 / 1080.0)
	var canvas := CanvasLayer.new()
	canvas.offset = Vector2(37, 23)
	viewport.add_child(canvas)
	var board := Board.new()
	board.position = Vector2(59, 31)
	board.size = Vector2(1600, 900)
	board.scale = Vector2(0.9, 0.9)
	canvas.add_child(board)
	var director: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/demo_clips/clips.json"))
	var clip: Dictionary
	for reel: Dictionary in director["reels"]:
		for item: Dictionary in reel["clips"]:
			if item["id"] == "weaver_thornwall": clip = item
	var fixture: Dictionary = Fixture.build(clip, director["defaults"])
	board.set_combat_state(fixture["state"])
	await process_frame
	var tile: Vector2i = fixture["state"]["enemies"][0]["pos"]
	var gui_positions: Array[Vector2]
	board.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion: gui_positions.append(event.position)
	)
	var enemy: Dictionary = fixture["state"]["enemies"][0]
	viewport.notify_mouse_entered()
	for stretch: Vector2 in [Vector2.ONE, Vector2(3024.0 / 1920.0, 1701.0 / 1080.0), Vector2(2, 2)]:
		container.scale = stretch
		viewport.notify_mouse_exited()
		board.call("_clear_hover_for_navigation")
		gui_positions.clear()
		var routed: Dictionary = Pointer.hover_tile(board, tile)
		await process_frame
		if gui_positions.is_empty():
			failures.append("hover reached _input but not production board GUI input at stretch %s" % stretch)
		elif not gui_positions.back().is_equal_approx(routed["board_local_position"]):
			failures.append("viewport/stretch conversion changed the board-local tile centre at %s" % stretch)
		if board.get("_hover_tile") != tile: failures.append("known tile centre did not select the actor at stretch %s" % stretch)
		if (board.call("_enemy_intent_rows_for_display", enemy, enemy["intent"]) as Array).is_empty():
			failures.append("known tile hover did not expand production intent rows at stretch %s" % stretch)
	print("DEMO PROBE VIEWPORT TEST: %s (1920x1080; board tile %s; GUI hover; Retina stretch)" % ["PASS" if failures.is_empty() else "FAIL", tile])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
