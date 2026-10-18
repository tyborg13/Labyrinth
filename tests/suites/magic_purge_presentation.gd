extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const List = preload("res://scripts/magic_deck_list.gd")
const Overlay = preload("res://scripts/magic_purge_overlay.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Halo = preload("res://scripts/magic_purge_halo.gd")
const HALO_TEST_MASK_SIZE := Vector2i(12, 10)
const HALO_TEST_RADIUS: int = 4
const HALO_TEST_BODY := Rect2i(2, 2, 8, 6)
const EXTRA_SPELLS: Array = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "stone_plate", "gust_step", "root_snare", "static_lash"]
# Debug-only fixtures deliberately cover one, two and overflowing rows.
const SMALL_IDENTITIES: int = 4
const OVERFLOW_IDENTITIES: int = 20
const FIT_EPSILON: float = 1.0
const TEARDOWN_FRAMES: int = 2

static func unique_cards(count: int) -> Array:
	var ids: Array = Data.cards().keys()
	ids.sort()
	var result: Array = []
	for id: String in ids:
		if Data.magic_card_is_purgeable(id): result.append(id)
		if result.size() == count: break
	return result

static func text_fit_failures(root: Node) -> Array[String]:
	var failures: Array[String]
	_walk_text(root, failures)
	return failures

static func _walk_text(node: Node, failures: Array[String]) -> void:
	if node is Control and not (node as Control).is_visible_in_tree(): return
	if node is Label:
		var label := node as Label
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		# Shape the entire string independently of the Label's trimming/ellipsis
		# and maximum-line settings, so those cannot hide an overflow from us.
		var paragraph := TextParagraph.new()
		paragraph.add_string(label.text, font, font_size)
		paragraph.break_flags = TextServer.BREAK_MANDATORY
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			paragraph.width = label.size.x
			paragraph.break_flags |= TextServer.BREAK_WORD_BOUND
			if label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART: paragraph.break_flags |= TextServer.BREAK_ADAPTIVE
		var measured: Vector2 = paragraph.get_size()
		measured.y += maxi(0, paragraph.get_line_count() - 1) * label.get_theme_constant("line_spacing")
		if measured.x > label.size.x + FIT_EPSILON or measured.y > label.size.y + FIT_EPSILON or label.get_visible_line_count() < paragraph.get_line_count():
			failures.append("%s clips Label %s (%s in %s)" % [node.get_path(), label.text, measured, label.size])
		var parent: Control = label.get_parent() as Control
		if parent != null and (parent is Button or parent.name == "MagicPurgePrice") and not parent.get_global_rect().grow(FIT_EPSILON).encloses(label.get_global_rect()):
			failures.append("%s places Label outside its button/chip" % node.get_path())
	elif node is Button:
		var button := node as Button
		if not button.text.is_empty():
			var font: Font = button.get_theme_font("font")
			var text_size: Vector2 = font.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
			var style: StyleBox = button.get_theme_stylebox("normal")
			var content: Vector2 = button.size - style.get_minimum_size()
			if text_size.x > content.x + FIT_EPSILON or text_size.y > content.y + FIT_EPSILON:
				failures.append("%s clips Button %s (%s in %s)" % [node.get_path(), button.text, text_size, content])
	for child: Node in node.get_children(): _walk_text(child, failures)

static func assert_grid(modal: Control, cards: Array, expect: Callable) -> void:
	expect.call(modal.find_child("MagicPurgeScroll", true, false).modulate == Color.WHITE and modal.find_child("MagicPurgeHeader", true, false).modulate == Color.WHITE, "Approved grid contents retain their original modulation")
	var entries: Array[Dictionary] = List.entries(cards)
	var panel: Control = modal.find_child("MagicPurgePanel", true, false)
	expect.call(panel.size == Overlay.dialog_size_for(entries.size()), "Purge dialog uses the brief's exact width and height: %s" % panel.size)
	expect.call(panel.get_global_rect().get_center().is_equal_approx(Vector2(960, 540)), "Purge dialog stays centred")
	var grid: Control = modal.find_child("MagicPurgeRows", true, false)
	expect.call(grid.get_child_count() == entries.size(), "One real card per sorted identity")
	var columns: int = mini(entries.size(), Overlay.MAX_COLUMNS)
	for index: int in range(entries.size()):
		var cell: Control = grid.get_child(index)
		expect.call(cell.get("card_id") == entries[index]["card_id"] and cell.size == Vector2(196, 276), "Grid preserves Character ordering and 196x276 cells")
		var count: int = int(entries[index]["count"])
		expect.call(int(cell.get_meta("magic_copy_count")) == count and cell.get("widget").card_id == entries[index]["card_id"], "Grid shows the owned card and duplicate count")
		var layer_count: int = 0
		for child: Node in cell.get_children():
			if str(child.name).begins_with("PileStackLayer"): layer_count += 1
		expect.call(layer_count == mini(count, 3) - 1, "Duplicates use at most three stack layers")
		if count > 1: expect.call(cell.get_node("PileCopyCount").text == "×%d" % count, "Duplicate count uses ×N")
		if index % columns > 0:
			var previous: Control = grid.get_child(index - 1)
			expect.call(is_equal_approx(cell.position.x - previous.position.x, 212.0), "Grid horizontal gap is exactly 16px")
		var row_start: int = (index / columns) * columns
		var row_count: int = mini(columns, entries.size() - row_start)
		var row_width: float = row_count * 196.0 + (row_count - 1) * 16.0
		expect.call(row_width <= grid.size.x + FIT_EPSILON, "Every column fits beside the scrollbar")
		var first: Control = grid.get_child(row_start)
		expect.call(is_equal_approx(first.position.x, (grid.size.x - row_width) * 0.5), "Each partial row is centred")
		if index >= columns:
			expect.call(is_equal_approx(cell.position.y, float(index / columns) * 296.0), "Grid vertical gap is exactly 20px")
	var scrim: ColorRect = modal.find_child("MagicPurgeBackdrop", true, false)
	expect.call(scrim.color == Color(0.02, 0.02, 0.02, 0.72) and scrim.get_global_rect() == Rect2(0, 0, 1920, 1080), "Purge has the exact full-screen scrim")

static func assert_confirmation(modal: Control, paid: bool, affordable: bool, held: int, expect: Callable) -> void:
	var panel: Control = modal.find_child("MagicPurgePanel", true, false)
	expect.call(panel.is_visible_in_tree() and panel.modulate == Color.WHITE and panel.get_parent().modulate == Color.WHITE, "Confirmation keeps the panel and frame fully modulated")
	expect.call(is_equal_approx((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a, 1.0), "Opaque confirmation backing blocks all shop/Campfire show-through")
	expect.call(modal.find_child("MagicPurgeScroll", true, false).modulate == Color(1, 1, 1, 0.30), "Only the grid dims to 30%")
	expect.call(modal.find_child("MagicPurgeHeader", true, false).modulate == Color(1, 1, 1, 0.60), "Only the header dims to 60%")
	var slot: Control = modal.find_child("MagicPurgeConfirmCardSlot", true, false)
	expect.call(slot.size == Vector2(250, 352) and slot.get_global_rect().get_center().is_equal_approx(Vector2(960, 500)), "Confirmation card is full size at the authored centre")
	expect.call(modal.find_child("MagicPurgeConfirmCard", true, false).get("card_id") == modal.get("pending_card_id"), "Confirmation shows the selected spell")
	var halo: TextureRect = modal.find_child("MagicPurgeCrimsonGlow", true, false)
	expect.call(halo.get_global_rect() == slot.get_global_rect().grow(56.0), "Halo has exactly 56px outward space")
	expect.call(halo.self_modulate == Color(Palette.DANGER, 0.30) and not halo.is_processing(), "Crimson halo has a static 30% peak, including reduced motion")
	var halo_image: Image = halo.texture.get_image()
	expect.call(is_zero_approx(halo_image.get_pixel(halo_image.get_width() / 2, halo_image.get_height() / 2).a), "No halo fill is drawn under the card body")
	var heading: Label = modal.find_child("PurgeConfirmationQuestion", true, false)
	expect.call(heading.text == "Purge this spell?" and is_equal_approx(slot.global_position.y - heading.get_global_rect().end.y, 24.0), "Heading sits 24px above the card")
	var back: Button = modal.find_child("CancelMagicPurge", true, false)
	var purge: Button = modal.find_child("ConfirmMagicPurge", true, false)
	expect.call(back.text == "Back" and back.has_focus(), "Back is the safe default focus")
	expect.call(purge.text == ("Purge for 50 Embers" if paid else "Purge") and purge.disabled == not affordable, "Confirmation uses the exact price copy and affordability")
	expect.call(purge.get_meta("button_variant") == "destructive" and back.get_meta("button_variant") == "standard", "Confirmation uses shared destructive and standard buttons")
	expect.call(is_equal_approx(back.global_position.x - purge.get_global_rect().end.x, 16.0) and back.size.y == 52 and purge.size.y == 52, "Buttons have a 16px gap and 52px height")
	expect.call(is_equal_approx(purge.global_position.y - slot.get_global_rect().end.y, 28.0), "Buttons sit 28px below the card")
	var wallet: Label = modal.find_child("MagicPurgeHeldEmbers", true, false)
	expect.call(wallet.is_visible_in_tree() == (paid and not affordable), "Only unaffordable paid purges show wallet copy")
	if wallet.visible:
		expect.call(wallet.text == "You have %d Embers." % held and is_equal_approx(wallet.global_position.y - back.get_global_rect().end.y, 12.0), "Wallet line uses the exact copy and 12px gap")
	var price: Control = modal.find_child("MagicPurgePrice", true, false)
	expect.call((price != null) == paid, "Only Scavenger has the price chip")
	if paid:
		expect.call(price.get_node("Value").text == "50" and price.get_node("Caption").text == "PRICE", "Header chip shows price and caption")
		expect.call(price.get_node("Value").get_theme_color("font_color") == (Palette.GOLD_BRIGHT if affordable else Palette.DANGER), "Unaffordable chip value uses danger")

static func halo_checks(expect: Callable) -> void:
	# Independently brute-force distances on a small notched silhouette, checking
	# the whole feather against the production linear-time transform.
	var mask := Image.create(HALO_TEST_MASK_SIZE.x, HALO_TEST_MASK_SIZE.y, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	mask.fill_rect(HALO_TEST_BODY, Color.WHITE)
	mask.set_pixelv(HALO_TEST_BODY.position, Color.TRANSPARENT)
	var occupied: Array[Vector2i]
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			if mask.get_pixel(x, y).a >= 0.5: occupied.append(Vector2i(x, y))
	var halo: Image = Halo.feather_image(mask, HALO_TEST_RADIUS)
	var maximum_error: float = 0.0
	for y: int in range(halo.get_height()):
		for x: int in range(halo.get_width()):
			var point := Vector2i(x - HALO_TEST_RADIUS, y - HALO_TEST_RADIUS)
			var distance: float = INF
			for site: Vector2i in occupied: distance = minf(distance, Vector2(point).distance_to(Vector2(site)))
			var expected: float = 0.0 if occupied.has(point) else 1.0 - smoothstep(0.0, float(HALO_TEST_RADIUS), maxf(0.0, distance - 0.5))
			maximum_error = maxf(maximum_error, absf(expected - halo.get_pixel(x, y).a))
	expect.call(maximum_error <= 1.0 / 255.0, "Halo follows the notched silhouette, leaves its body clear and feathers to zero at the radius (max error %.5f)" % maximum_error)
	expect.call(halo.get_pixelv(HALO_TEST_BODY.position + Vector2i(HALO_TEST_RADIUS, HALO_TEST_RADIUS - 1)).a > halo.get_pixelv(HALO_TEST_BODY.position + Vector2i(HALO_TEST_RADIUS, HALO_TEST_RADIUS - 2)).a, "Halo falls outward instead of forming a filled red block")
