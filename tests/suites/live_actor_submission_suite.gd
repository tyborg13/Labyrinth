extends RefCounted

## Texture2D's real draw virtual records which texture the CanvasItem submits.
## This works with the dummy renderer too, without trusting wrapper metadata.
const LiveActor = preload("res://scripts/live_actor_presentation.gd")
const Crawler = preload("res://scripts/crawler_cutout/renderer.gd")
const PROCESS_FRAMES: int = 3

class DrawWitness extends Texture2D:
	var rects: Array[Rect2]
	func _get_width() -> int: return int(Crawler.SOURCE_SIZE.x)
	func _get_height() -> int: return int(Crawler.SOURCE_SIZE.y)
	func _has_alpha() -> bool: return true
	func _draw_rect(_item: RID, rect: Rect2, _tile: bool, _modulate: Color, _transpose: bool) -> void:
		rects.append(rect)
	func _draw_rect_region(_item: RID, rect: Rect2, _source: Rect2, _modulate: Color, _transpose: bool, _clip: bool) -> void:
		rects.append(rect)

class RendererWitness extends Node:
	const SOURCE_SIZE := Crawler.SOURCE_SIZE
	const SOURCE_OFFSET := Crawler.SOURCE_OFFSET
	const CANVAS_SIZE := Crawler.CANVAS_SIZE
	var submitted := DrawWitness.new()
	func texture() -> Texture2D: return submitted
	func present(_motion: Dictionary, _reduce: bool, _active: bool) -> void: pass

static func run(expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var stage := Control.new()
	tree.root.add_child(stage)
	var still := TextureRect.new()
	var still_texture := DrawWitness.new()
	still.texture = still_texture
	stage.add_child(still)
	var live := LiveActor.new()
	live.configure("crawler", still, 0, 1)
	stage.add_child(live)
	live.renderer.free()
	var witness := RendererWitness.new()
	live.renderer = witness
	live.add_child(witness)
	live.size = Crawler.SOURCE_SIZE
	live.queue_redraw()
	for frame: int in range(PROCESS_FRAMES): await tree.process_frame
	expect.call(not witness.submitted.rects.is_empty(), "CanvasItem submits the renderer texture, not the source still")
	expect.call(still_texture.rects.is_empty(), "Cutout presentation never submits the static source texture")
	if not witness.submitted.rects.is_empty():
		expect.call(witness.submitted.rects.back() == Rect2(-Crawler.SOURCE_OFFSET, Vector2(Crawler.CANVAS_SIZE)), "Submitted live canvas preserves board padding and registration")
	stage.free()
