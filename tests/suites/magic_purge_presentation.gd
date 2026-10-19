extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const List = preload("res://scripts/magic_deck_list.gd")
const Overlay = preload("res://scripts/magic_purge_overlay.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Halo = preload("res://scripts/magic_purge_halo.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const BadgeChecks = preload("res://tests/helpers/pile_copy_badge_checks.gd")
const HALO_TEST_MASK_SIZE := Vector2i(12, 10)
const HALO_TEST_RADIUS: int = 4
const HALO_TEST_BODY := Rect2i(2, 2, 8, 6)
const EXTRA_SPELLS: Array = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "stone_plate", "gust_step", "root_snare", "static_lash"]
# Debug-only fixtures deliberately cover one, two and overflowing rows.
const SMALL_IDENTITIES: int = 4
const OVERFLOW_IDENTITIES: int = 20
const FIT_EPSILON: float = 1.0
const TEARDOWN_FRAMES: int = 2
const CLIPPED_SERVICE_LABEL_WIDTH: float = 1.0

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
	failures.append_array(BadgeChecks.viewport_failures(root))
	return failures

static func service_label_clipping_failures(service: Button) -> Array[String]:
	# Mutate the real nested label while leaving the native Button text/size
	# unchanged. Restore synchronously so this cannot affect accepted captures.
	var label: Label = service.get("_label")
	return label_clipping_failures(service, label)

static func label_clipping_failures(scope: Node, label: Label) -> Array[String]:
	var original_wrap: TextServer.AutowrapMode = label.autowrap_mode
	var original_clip: bool = label.clip_text
	var original_rect: Rect2 = label.get_rect()
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size.x = CLIPPED_SERVICE_LABEL_WIDTH
	var failures: Array[String] = text_fit_failures(scope)
	label.autowrap_mode = original_wrap
	label.clip_text = original_clip
	# Reflow at the restored width before restoring height: Label otherwise
	# clamps the height against its cached one-pixel wrapped minimum.
	label.size.x = original_rect.size.x
	label.get_line_count()
	label.get_minimum_size()
	label.size = original_rect.size
	label.position = original_rect.position
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
		# The count medallion intentionally straddles the card corner. Its own
		# text fit and exact attachment are checked separately from button copy.
		if parent != null and ((parent is Button and label.name != "PileCopyCount") or parent.name == "MagicPurgePrice") and not parent.get_global_rect().grow(FIT_EPSILON).encloses(label.get_global_rect()):
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
	var card_width: float = grid.size.x - 24.0
	var rows: int = ceili(float(entries.size()) / Overlay.MAX_COLUMNS)
	expect.call(grid.custom_minimum_size.y == rows * 276.0 + maxi(0, rows - 1) * 20.0 + 24.0, "Purge grid reserves exactly 24px below its card rows")
	assert_heading(modal, cards.size(), expect)
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
		BadgeChecks.assert_badge(cell, count, expect)
		if index % columns > 0:
			var previous: Control = grid.get_child(index - 1)
			expect.call(is_equal_approx(cell.position.x - previous.position.x, 212.0), "Grid horizontal gap is exactly 16px")
		var row_start: int = (index / columns) * columns
		var row_count: int = mini(columns, entries.size() - row_start)
		var row_width: float = row_count * 196.0 + (row_count - 1) * 16.0
		expect.call(row_width <= card_width + FIT_EPSILON, "Every column fits beside the scrollbar and 24px badge padding")
		var first: Control = grid.get_child(row_start)
		expect.call(is_equal_approx(first.position.x, (card_width - row_width) * 0.5), "Each partial row is centred before the 24px right badge padding")
		if index >= columns:
			expect.call(is_equal_approx(cell.position.y, float(index / columns) * 296.0), "Grid vertical gap is exactly 20px")
	for failure: String in BadgeChecks.viewport_failures(modal): expect.call(false, failure)
	var scrim: ColorRect = modal.find_child("MagicPurgeBackdrop", true, false)
	expect.call(scrim.color == Color(0.02, 0.02, 0.02, 0.72) and scrim.get_global_rect() == Rect2(0, 0, 1920, 1080), "Purge has the exact full-screen scrim")

static func assert_heading(modal: Control, spell_count: int, expect: Callable) -> void:
	var header: Control = modal.find_child("MagicPurgeHeader", true, false)
	var heading: Control = modal.find_child("MagicPurgeHeading", true, false)
	var title: Label = heading.get_node("Title")
	var count: Label = heading.get_node("Count")
	expect.call(header.size.y == 72.0, "Purge header row is exactly 72px")
	expect.call(title.text == "PURGE A SPELL" and title.get_theme_font_size("font_size") == 24 and title.get_theme_font("font") == Typography.eyebrow_font(), "Purge title uses 24px letter-spaced UI caps")
	expect.call(title.get_theme_color("font_color") == Palette.GOLD_BRIGHT and title.get_theme_color("font_outline_color") == Palette.TEXT_OUTLINE and title.get_theme_constant("outline_size") == 3, "Purge title retains the approved gold and 3px outline")
	expect.call(count.text == "%d spells" % spell_count and count.get_theme_font_size("font_size") == 18 and count.get_theme_color("font_color") == Palette.TEXT_2, "Purge count uses 18px secondary copy")
	expect.call(heading.get_global_rect().encloses(title.get_global_rect()) and heading.get_global_rect().encloses(count.get_global_rect()), "Larger title and count fit inside the unchanged heading slot")

static func assert_polish_text_fit_mutations(modal: Control, expect: Callable) -> void:
	var heading: Control = modal.find_child("MagicPurgeHeading", true, false)
	for label: Label in [heading.get_node("Title"), heading.get_node("Count"), modal.find_child("PileCopyCount", true, false)]:
		expect.call(label != null, "Polish text-fit fixture includes title, count and duplicate badge")
		if label == null: continue
		var label_path: String = str(label.get_path())
		var caught: Array[String] = label_clipping_failures(modal, label)
		var killed: bool = caught.any(func(value: String) -> bool: return value.begins_with(label_path + " clips Label "))
		expect.call(killed, "Text-fit regression detects clipping in " + label_path)
		print("PURGE POLISH TEXT FIT MUTATION (%s): %s" % [label.name, "KILLED" if killed else "SURVIVED"])
	for failure: String in text_fit_failures(modal): expect.call(false, "Restored polish text fit: " + failure)

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
