extends Control

const DemoRules = preload("res://scripts/demo_rules.gd")
const UiQuietLink = preload("res://scripts/ui_quiet_link.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const COLUMN_WIDTH: float = 780.0
const PLATE_GAP: float = 16.0
const HEADING_SIZE: int = 30
const BODY_SIZE: int = 20
const WISHLIST_SIZE: int = 22
# Tests can substitute an absent feature to exercise the exported-build path.
const TEST_OVERRIDE_FEATURE: String = "editor"

# Test seams keep URL activation testable without opening an external program.
static var shell_open: Callable = OS.shell_open
static var store_page_override_for_test: Callable

static func release_shutdown_callables() -> void:
	shell_open = Callable()
	store_page_override_for_test = Callable()

var kind: String
var links: Array[Button]
var plates: Array[Button]
var wishlist_plate: Button
var _original_neighbors: Dictionary = {}

static func activate(action: String) -> void:
	if action == "wishlist":
		if OS.has_feature(TEST_OVERRIDE_FEATURE) and store_page_override_for_test.is_valid():
			store_page_override_for_test.call()
		else:
			Engine.get_main_loop().root.get_node("SteamService").open_store_page()
	else:
		var url: String = str(DemoRules.config().get("%s_url" % action, ""))
		if not url.is_empty():
			if OS.has_feature(TEST_OVERRIDE_FEATURE) and shell_open.is_valid():
				shell_open.call(url)
			else:
				OS.shell_open(url)

static func make_link(action: String) -> UiQuietLink:
	var link := UiQuietLink.new()
	link.name = "Demo%sLink" % action.capitalize()
	link.text = link_text(action)
	link.pressed.connect(activate.bind(action))
	link.size = link.get_combined_minimum_size()
	return link

static func link_text(action: String) -> String:
	return "%s ›" % str(DemoRules.config()["text"][action]).to_upper()

static func glyph_preparation_jobs(oversampling: float) -> Array[Dictionary]:
	var jobs: Array[Dictionary]
	var copy: Dictionary = DemoRules.config()["text"]
	var glyphs = preload("res://scripts/ui_glyph_preparation.gd")
	jobs.append_array(glyphs.text_jobs(str(copy["end_title"]), UiTypography.ui_font(), HEADING_SIZE, 0, 0, oversampling))
	for key: String in ["end_body", "links_line"]:
		jobs.append_array(glyphs.text_jobs(str(copy[key]), UiTypography.text_font(), BODY_SIZE, 0, 0, oversampling))
	jobs.append_array(glyphs.text_jobs(str(copy["wishlist"]), UiTypography.ui_font(), WISHLIST_SIZE, 0, 0, oversampling))
	for action: String in ["wishlist", "discord", "feedback"]:
		jobs.append_array(glyphs.text_jobs(link_text(action), UiQuietLink.spaced_font(4), UiQuietLink.FONT_SIZE, 0, 0, oversampling))
	return jobs

func configure(panel_kind: String, chronicle: Button, rise: Button, menu: Button, rule: Control) -> void:
	kind = panel_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	plates.assign([rise, menu])
	for button: Button in [chronicle, rise, menu]:
		_original_neighbors[button] = [button.focus_neighbor_left, button.focus_neighbor_right, button.focus_neighbor_top, button.focus_neighbor_bottom]
	var copy: Dictionary = DemoRules.config()["text"]
	var top: float = chronicle.position.y + chronicle.size.y
	var links_y: float
	if kind == "full":
		top += 26.0
		var demo_rule := rule.duplicate() as Control
		demo_rule.name = "DemoRule"
		demo_rule.position = Vector2(0, top)
		demo_rule.size = Vector2(560, 14)
		add_child(demo_rule)
		add_child(_label("DemoHeading", str(copy["end_title"]), UiTypography.ui_font(), HEADING_SIZE, Palette.TEXT, Rect2(0, top + 24, 780, 40)))
		var body := _label("DemoBody", str(copy["end_body"]), UiTypography.text_font(), BODY_SIZE, Palette.TEXT_2, Rect2(0, top + 66, 760, 56), true)
		add_child(body)
		links_y = body.position.y + body.size.y + 14.0
		wishlist_plate = Button.new()
		wishlist_plate.name = "WishlistButton"
		wishlist_plate.text = str(copy["wishlist"])
		wishlist_plate.add_theme_font_override("font", UiTypography.ui_font())
		wishlist_plate.add_theme_font_size_override("font_size", WISHLIST_SIZE)
		wishlist_plate.pressed.connect(activate.bind("wishlist"))
		rise.get_parent().add_child(wishlist_plate)
		var skin := UiSkin.new()
		skin.apply_button_stylebox_overrides(wishlist_plate, UiSkin.VARIANT_LARGE)
		skin.apply_button_text_overrides(wishlist_plate)
		var width: float = (COLUMN_WIDTH - 2.0 * PLATE_GAP) / 3.0
		wishlist_plate.custom_minimum_size = Vector2(width, width / 3.25)
		wishlist_plate.size = wishlist_plate.custom_minimum_size
		plates.push_front(wishlist_plate)
	else:
		top += 30.0
		add_child(_label("DemoLinksLine", str(copy["links_line"]), UiTypography.text_font(), BODY_SIZE, Palette.TEXT_2, Rect2(0, top, 780, 30)))
		links_y = top + 40.0
	var x: float = 0.0
	var actions: Array[String] = TypedArrays.strings(["discord", "feedback"])
	if kind == "links":
		actions.push_front("wishlist")
	for action: String in actions:
		if action == "feedback" and str(DemoRules.config()["feedback_url"]).is_empty():
			continue
		var link := make_link(action)
		link.owner_manages_selection = true
		link.position = Vector2(x, links_y)
		add_child(link)
		links.append(link)
		x += link.size.x + (32.0 if kind == "full" else 24.0)
	wire_focus(chronicle)

func wire_focus(chronicle: Button) -> void:
	for index: int in range(plates.size()):
		var plate: Button = plates[index]
		plate.focus_neighbor_left = plate.get_path_to(plates[posmod(index - 1, plates.size())])
		plate.focus_neighbor_right = plate.get_path_to(plates[(index + 1) % plates.size()])
		plate.focus_neighbor_top = plate.get_path_to(links[0])
		plate.focus_neighbor_bottom = plate.get_path_to(plate)
	for index: int in range(links.size()):
		var link: Button = links[index]
		link.focus_neighbor_left = link.get_path_to(links[posmod(index - 1, links.size())])
		link.focus_neighbor_right = link.get_path_to(links[(index + 1) % links.size()])
		link.focus_neighbor_top = link.get_path_to(chronicle)
	chronicle.focus_neighbor_bottom = chronicle.get_path_to(links[0])
	set_return_plate(primary_plate())

func set_return_plate(plate: Button) -> void:
	for link: Button in links:
		link.focus_neighbor_bottom = link.get_path_to(plate)

# Default focus is never Wishlist (qa-87 F10: an Enter after the click-to-continue
# lines opened the Steam page). It is Rise Again, as on the links-only recap.
func primary_plate() -> Button:
	for plate: Button in plates:
		if plate != wishlist_plate: return plate
	return plates[0]

func layout_plates(factor: float) -> void:
	var width: float = (COLUMN_WIDTH - 2.0 * PLATE_GAP) / 3.0
	for index: int in range(plates.size()):
		plates[index].position = Vector2(1010.0 + index * (width + PLATE_GAP), 952.0) * factor
		plates[index].scale = Vector2.ONE * factor

func dispose() -> void:
	for button: Button in _original_neighbors:
		var neighbors: Array = _original_neighbors[button]
		button.focus_neighbor_left = neighbors[0]
		button.focus_neighbor_right = neighbors[1]
		button.focus_neighbor_top = neighbors[2]
		button.focus_neighbor_bottom = neighbors[3]
	if wishlist_plate != null:
		wishlist_plate.get_parent().remove_child(wishlist_plate)
		wishlist_plate.queue_free()
	get_parent().remove_child(self)
	queue_free()

func _label(node_name: String, copy: String, font: Font, font_size: int, ink: Color, rect: Rect2, wrap: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name
	# Wrapping and its width come before the text, or the label keeps the one-line width.
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(rect.size.x, 0)
	label.text = copy
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
