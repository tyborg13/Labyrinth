extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const PileView = preload("res://scripts/pile_dialog_view.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Socket = preload("res://scripts/ui_socket.gd")
const Sources = preload("res://tests/sfx_sync_sources.gd")
const TEST_COPY_COUNTS: Array = [1, 2, 3, 9, 10, 12, 99, 100, 1234]
const TEST_LAYOUT_FRAMES: int = 2
# Override only the painter. The inherited production _draw must delegate to
# it with the real renderer callable; no CanvasItem draw is needed headless.
const DISC_DRAW_SPY: String = """
class DiscDrawSpy extends CopyCountFace:
	var painters: Array[Callable]
	func paint_disc(paint_circle: Callable) -> void:
		painters.append(paint_circle)
"""

class DiscRecorder extends RefCounted:
	var circles: Array[Dictionary]
	func draw_circle(center: Vector2, radius: float, color: Color) -> void:
		circles.append({"center": center, "radius": radius, "color": color})

static func assert_count_cases(host: Node, scope: Node, expect: Callable) -> void:
	assert_disc_draw(FileAccess.get_file_as_string("res://scripts/pile_dialog_view.gd"), expect)
	var cells := Control.new()
	scope.add_child(cells)
	for count: int in TEST_COPY_COUNTS:
		cells.add_child(PileView.card_cell(host, "pale_spark", count, func(_id: String) -> void: pass))
	for _frame: int in range(TEST_LAYOUT_FRAMES): await scope.get_tree().process_frame
	for index: int in range(TEST_COPY_COUNTS.size()):
		var cell: Control = cells.get_child(index)
		assert_badge(cell, TEST_COPY_COUNTS[index], expect)
		var layers: int = 0
		for child: Node in cell.get_children():
			if str(child.name).begins_with("PileStackLayer"): layers += 1
		expect.call(layers == mini(TEST_COPY_COUNTS[index], 3) - 1, "Count badge does not alter the three-layer stack limit")
	cells.queue_free()
	for _frame: int in range(TEST_LAYOUT_FRAMES): await scope.get_tree().process_frame

static func assert_badge(cell: Control, count: int, expect: Callable) -> void:
	var badge := cell.get_node_or_null("PileCopyCount") as Control
	expect.call((badge != null) == (count > 1), "Copy badge exists only for duplicate cards")
	if badge == null: return
	var text: Label = badge.get_node("Text")
	var expected_size: int = 16 if count >= 100 else 18 if count >= 10 else 22
	expect.call(text.text == ("×99+" if count >= 100 else "×%d" % count), "Duplicate badge shows the director's count band")
	expect.call(badge.size == Vector2(52, 52), "Duplicate medallion is exactly 52x52px")
	expect.call(badge.get_rect().get_center().is_equal_approx(cell.size - Vector2(6, 6)), "Duplicate badge is centred 6px inside the top card's bottom-right corner, independently of stack layers (%s on %s)" % [badge.get_rect(), cell.size])
	expect.call(text.get_theme_font("font") == Typography.ui_font() and text.get_theme_font_size("font_size") == expected_size, "Duplicate count uses the director's 22/18/16px UI font band")
	expect.call(text.get_theme_color("font_color") == Palette.GOLD_BRIGHT and text.get_theme_color("font_outline_color") == Palette.TEXT_OUTLINE and text.get_theme_constant("outline_size") == 3, "Duplicate count uses gold with a 3px text outline")
	expect.call(text.size == Vector2(52, 52) and text.position == Vector2.ZERO and text.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and text.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Duplicate text is centred separately in the fixed ring host")
	var measured: Vector2 = text.get_theme_font("font").get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, expected_size)
	expect.call(measured.x + 6 <= text.size.x and measured.y + 6 <= text.size.y, "Every count band fits with its 3px outline")
	expect.call(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE and badge.focus_mode == Control.FOCUS_NONE and badge.z_index > 20, "Badge draws over the lifted top card without taking input")
	var face: Control = badge.get_node_or_null("Medallion") as Control
	expect.call(face != null, "Duplicate badge has the painted medallion face")
	if face != null:
		expect.call(face.size == badge.size and face.get_index() < text.get_index() and face.mouse_filter == Control.MOUSE_FILTER_IGNORE and not face.is_processing(), "Static medallion fills the fixed badge behind its text and ignores input")
		assert_disc_paint(face, expect)
		var ring := face.get_node_or_null("Ring") as TextureRect
		expect.call(ring != null, "Medallion uses the socket's full-colour texture control")
		if ring != null:
			var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Socket.GEOMETRY_PATH)) as Dictionary
			var native_size := Vector2(float(geometry["size"][0]), float(geometry["size"][1]))
			var expected_ring_size: Vector2 = native_size * minf(face.size.x / native_size.x, face.size.y / native_size.y)
			expect.call(ring.size.is_equal_approx(expected_ring_size) and ring.position.is_equal_approx((face.size - expected_ring_size) * 0.5), "Medallion preserves the native aspect and centre from its geometry")
			expect.call(face.modulate == Color.WHITE and face.self_modulate == Color.WHITE and ring.modulate == Color.WHITE and ring.self_modulate == Color.WHITE and ring.material == null, "Medallion ring has no tint or darkening material")
			var actual: Image = ring.texture.get_image()
			var source: Image = Assets.load_texture(Socket.RING_PATH).get_image()
			if source.is_compressed(): source.decompress()
			actual.clear_mipmaps()
			source.clear_mipmaps()
			expect.call(actual.get_size() == source.get_size() and actual.get_data() == source.get_data(), "Medallion retains the source texture's full-colour pixels")

static func assert_disc_paint(face: Control, expect: Callable) -> void:
	var recorder := DiscRecorder.new()
	face.call("paint_disc", recorder.draw_circle)
	expect.call(recorder.circles.size() == 1, "Medallion paints exactly one centre disc")
	if recorder.circles.size() != 1: return
	var circle: Dictionary = recorder.circles[0]
	expect.call((circle["color"] as Color).is_equal_approx(Color(Palette.INK_0, 0.92)), "Medallion centre disc paints INK_0 at alpha 0.92")
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Socket.GEOMETRY_PATH)) as Dictionary
	var ring: Control = face.get_node("Ring")
	var scale: float = ring.size.x / float(geometry["size"][0])
	var center := Vector2(float(geometry["center"][0]), float(geometry["center"][1]))
	expect.call((circle["center"] as Vector2).is_equal_approx(ring.position + center * scale) and is_equal_approx(float(circle["radius"]), float(geometry["inner_radius"]) * scale), "Painted disc stays centred inside the ring's inner radius")

static func assert_disc_draw(source: String, expect: Callable) -> void:
	var instrumented: GDScript = Sources.compile_script("scripts/pile_disc_draw_spy_%s.gd" % source.sha256_text(), source + DISC_DRAW_SPY)
	expect.call(instrumented != null, "Disc draw spy compiles against the production badge")
	if instrumented == null: return
	var spy_script: GDScript = instrumented.get_script_constant_map()["DiscDrawSpy"]
	var spy: Control = spy_script.new()
	spy.call("_draw")
	var painters: Array = spy.get("painters")
	expect.call(painters.size() == 1, "Medallion _draw delegates once to the checked disc painter")
	if painters.size() == 1:
		var painter: Callable = painters[0]
		expect.call(painter.is_valid() and painter.get_object() == spy and painter.get_method() == &"draw_circle", "Medallion _draw supplies its real draw_circle callable")
	spy.free()

static func viewport_failures(modal: Node) -> Array[String]:
	var failures: Array[String]
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	var grid := modal.find_child("MagicPurgeRows", true, false) as Control
	if scroll == null or grid == null: return failures
	var viewport: Rect2 = scroll.get_global_rect()
	if scroll.get_v_scroll_bar().visible: viewport.size.x -= scroll.get_v_scroll_bar().size.x
	if scroll.get_h_scroll_bar().visible: viewport.size.y -= scroll.get_h_scroll_bar().size.y
	for cell: Control in grid.get_children():
		var badge := cell.get_node_or_null("PileCopyCount") as Control
		# Hidden page artwork has empty visible bounds. For every drawn badge,
		# inspect its own bounds even when its parent card is wholly offscreen.
		if badge == null or not badge.is_visible_in_tree(): continue
		if badge.get_global_rect().intersects(viewport) and not viewport.encloses(badge.get_global_rect()):
			failures.append("%s clips badge %s outside visible viewport %s" % [badge.get_path(), badge.get_global_rect(), viewport])
	return failures

static func assert_viewport_mutations(modal: Control, expect: Callable) -> void:
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	var original_size: Vector2 = scroll.size
	var original_mode: ScrollContainer.ScrollMode = scroll.vertical_scroll_mode
	# Disabled scrolling includes the whole content height in the control's
	# minimum, preventing a real clipping mutation. Temporarily allow scrolling
	# so the viewport can shrink without reflowing the already laid-out cards.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	for edge: String in ["bottom", "right"]:
		scroll.size = original_size - (Vector2(0, 24) if edge == "bottom" else Vector2(24, 0))
		var caught: Array[String] = viewport_failures(modal)
		scroll.size = original_size
		expect.call(not caught.is_empty(), "Badge viewport regression catches clipping at the " + edge)
		print("PURGE BADGE VIEWPORT MUTATION (%s): %s" % [edge, "KILLED" if not caught.is_empty() else "SURVIVED"])
	scroll.vertical_scroll_mode = original_mode
	for failure: String in viewport_failures(modal): expect.call(false, "Restored badge viewport: " + failure)
