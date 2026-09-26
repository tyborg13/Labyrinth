extends SceneTree
# Real root-Window regression: changing a board cursor during card hover must
# not swallow the press that caused the hover. A SubViewport misses this path.
const Board = preload("res://scripts/combat_board_view.gd")
class InputObserver extends Node:
	var presses: int = 0
	var releases: int = 0
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: presses += 1
			else: releases += 1
var board: Control
var card: Control
var gui_presses: int = 0
var gui_releases: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")
func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.position = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1920,1080)
	board = Board.new()
	root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = Panel.new()
	card.position = Vector2(400,650)
	card.size = Vector2(340,300)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(card)
	card.mouse_entered.connect(_enter_card)
	card.gui_input.connect(_card_input)
	var observer := InputObserver.new()
	root.add_child(observer)
	var label := Label.new()
	label.position = Vector2(60,80)
	label.add_theme_font_size_override("font_size",32)
	root.add_child(label)
	board.set("_hover_tile",Vector2i(1,1))
	board.call("_update_cursor_shape")
	await process_frame
	await process_frame
	# Prime hover outside the card, then let the press itself enter it.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100,200)
	motion.global_position = motion.position
	root.push_input(motion,true)
	await process_frame
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = card.position + card.size * 0.5
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	var passed: bool = observer.presses == 1 and observer.releases == 1 and gui_presses == 1 and gui_releases == 1
	label.text = "Board → card press: %s\nInput %d / %d; GUI %d / %d" % ["PASS" if passed else "FAIL",observer.presses,observer.releases,gui_presses,gui_releases]
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("user://probes/board_cursor_input")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join("board_cursor_input.png"))
	print(label.text)
	quit(0 if passed else 1)
func _enter_card() -> void:
	# The production card hover refresh changes attack targets under the last
	# board hover, causing this same cursor transition inside mouse-enter dispatch.
	board.set("_hover_tile",Vector2i(1,1))
	var targets: Array[Vector2i] = [Vector2i(1,1)]
	board.set("attack_tiles",targets)
	board.call("_update_cursor_shape")
func _card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: gui_presses += 1
		else: gui_releases += 1
