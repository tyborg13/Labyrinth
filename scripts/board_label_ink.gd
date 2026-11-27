extends RefCounted
## A retained child of the source painter so isolation's inherited modulation
## and the source's transform, visibility and lifetime follow the moved ink.

const INTENT_BADGE_OFFSET := 4
const TILE_DAMAGE_Z := 8
const EXPANDED_INTENT_OFFSET := 8
const CALLOUT_Z := 12
const FLOATING_TEXT_Z := 13

var _numbers: Array
var _next_numbers: Array
var _number_canvas: RID
var _feedback_canvas: RID


func submit_number(font: Font, at: Vector2, text: String, width: float, pixels: int, fill: Color, outline: Color, thickness: float, centered: bool = false) -> void:
	_next_numbers.append([font, at, text, width, pixels, fill, outline, thickness, centered])


func finish_numbers(source: CanvasItem) -> void:
	if _numbers == _next_numbers:
		_next_numbers.clear()
		return
	var pending: Array = _numbers
	_numbers = _next_numbers
	_next_numbers = pending
	_next_numbers.clear()
	if not _number_canvas.is_valid():
		_number_canvas = _new_canvas(source, TILE_DAMAGE_Z)
	else:
		RenderingServer.canvas_item_clear(_number_canvas)
	for number: Array in _numbers:
		_draw_number(number)


func _draw_number(number: Array) -> void:
	var font: Font = number[0]
	var at: Vector2 = number[1]
	var text: String = number[2]
	var width: float = number[3]
	var pixels: int = number[4]
	var thickness: float = number[7]
	var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if number[8] else HORIZONTAL_ALIGNMENT_LEFT
	if number[8]:
		font.draw_string_outline(_number_canvas, at, text, alignment, width, pixels, int(thickness), number[6])
	else:
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2.ONE]:
			font.draw_string(_number_canvas, at + direction * thickness, text, alignment, width, pixels, number[6])
	font.draw_string(_number_canvas, at, text, alignment, width, pixels, number[5])


func feedback_canvas(source: CanvasItem) -> RID:
	if not _feedback_canvas.is_valid():
		_feedback_canvas = _new_canvas(source, FLOATING_TEXT_Z)
	return _feedback_canvas


func clear_feedback() -> void:
	if _feedback_canvas.is_valid(): RenderingServer.canvas_item_clear(_feedback_canvas)


static func _new_canvas(source: CanvasItem, z: int) -> RID:
	var canvas: RID = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(canvas, source.get_canvas_item())
	RenderingServer.canvas_item_set_z_index(canvas, z)
	if source.material != null:
		RenderingServer.canvas_item_set_material(canvas, source.material.get_rid())
	return canvas


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	if _number_canvas.is_valid(): RenderingServer.free_rid(_number_canvas)
	if _feedback_canvas.is_valid(): RenderingServer.free_rid(_feedback_canvas)
