extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const PileView = preload("res://scripts/pile_dialog_view.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Socket = preload("res://scripts/ui_socket.gd")
const TEST_COPY_COUNTS: Array = [1, 2, 3, 12]
const TEST_LAYOUT_FRAMES: int = 2

static func assert_count_cases(host: Node, scope: Node, expect: Callable) -> void:
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
	var badge := cell.get_node_or_null("PileCopyCount") as Label
	expect.call((badge != null) == (count > 1), "Copy badge exists only for duplicate cards")
	if badge == null: return
	expect.call(badge.text == "×%d" % count, "Duplicate badge shows the exact ×N count")
	expect.call(badge.size == Vector2(52, 52), "Duplicate medallion is exactly 52x52px")
	expect.call(badge.get_rect().get_center().is_equal_approx(cell.size - Vector2(6, 6)), "Duplicate badge is centred 6px inside the top card's bottom-right corner, independently of stack layers (%s on %s)" % [badge.get_rect(), cell.size])
	expect.call(badge.get_theme_font("font") == Typography.ui_font() and badge.get_theme_font_size("font_size") == 22, "Duplicate count uses the 22px UI font")
	expect.call(badge.get_theme_color("font_color") == Palette.GOLD_BRIGHT and badge.get_theme_color("font_outline_color") == Palette.TEXT_OUTLINE and badge.get_theme_constant("outline_size") == 3, "Duplicate count uses gold with a 3px text outline")
	expect.call(badge.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and badge.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Duplicate count is centred in the ring")
	expect.call(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE and badge.focus_mode == Control.FOCUS_NONE and badge.z_index > 20, "Badge draws over the lifted top card without taking input")
	var face: Control = badge.get_node_or_null("Medallion") as Control
	expect.call(face != null, "Duplicate badge has the painted medallion face")
	if face != null:
		expect.call(face.size == badge.size and face.show_behind_parent and face.mouse_filter == Control.MOUSE_FILTER_IGNORE and not face.is_processing(), "Static medallion fills the badge behind its text and ignores input")
		var ring := face.get_node_or_null("Ring") as TextureRect
		expect.call(ring != null, "Medallion uses the socket's full-colour texture control")
		if ring != null:
			var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Socket.GEOMETRY_PATH)) as Dictionary
			var native_size := Vector2(float(geometry["size"][0]), float(geometry["size"][1]))
			var expected_size: Vector2 = native_size * minf(face.size.x / native_size.x, face.size.y / native_size.y)
			expect.call(ring.size.is_equal_approx(expected_size) and ring.position.is_equal_approx((face.size - expected_size) * 0.5), "Medallion preserves the native aspect and centre from its geometry")
			expect.call(face.modulate == Color.WHITE and face.self_modulate == Color.WHITE and ring.modulate == Color.WHITE and ring.self_modulate == Color.WHITE and ring.material == null, "Medallion ring has no tint or darkening material")
			var actual: Image = ring.texture.get_image()
			var source: Image = Assets.load_texture(Socket.RING_PATH).get_image()
			if source.is_compressed(): source.decompress()
			actual.clear_mipmaps()
			source.clear_mipmaps()
			expect.call(actual.get_size() == source.get_size() and actual.get_data() == source.get_data(), "Medallion retains the source texture's full-colour pixels")

static func viewport_failures(modal: Node) -> Array[String]:
	var failures: Array[String]
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	var grid := modal.find_child("MagicPurgeRows", true, false) as Control
	if scroll == null or grid == null: return failures
	var viewport: Rect2 = scroll.get_global_rect()
	if scroll.get_v_scroll_bar().visible: viewport.size.x -= scroll.get_v_scroll_bar().size.x
	if scroll.get_h_scroll_bar().visible: viewport.size.y -= scroll.get_h_scroll_bar().size.y
	for cell: Control in grid.get_children():
		var badge := cell.get_node_or_null("PileCopyCount") as Label
		# Overflow rows outside the visible card viewport are intentionally
		# scrolled away. Every badge on an on-screen card must fit in full.
		if badge == null or not cell.get_global_rect().intersects(viewport): continue
		if not viewport.encloses(badge.get_global_rect()):
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
