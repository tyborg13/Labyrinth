extends SceneTree

## ux-17 proof for Settings > Controls on the real title-screen Settings panel.
## Every case checks the data binding, layout fit, column alignment, live glyph
## family, D-pad navigation and pointer hover. Only a windowed run
## (tools/visual_probe_runner.py) saves the exact-size SubViewport captures;
## --headless-check never captures.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Router = preload("res://scripts/input_router.gd")
const CelLook = preload("res://scripts/cel_look.gd")
const PanelScript = preload("res://scripts/settings_panel.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const PROOF_SIZE := Vector2(1920.0, 1080.0)
const OUTPUT_DEFAULT: String = "/private/tmp/labyrinth_codex/ux-17/captures"
const SETTLE_SECONDS: float = 0.5 # Title entry and panel layout finish.
const HOVER_ROW: String = "cancel"
# scale 1.5 is not a selectable Interface scale (max 1.25); it is forced on the
# viewport as an overflow stress case, as the brief asks for 150%.
const CASES := [
	{"name": "1920x1080_100_pointer", "size": Vector2i(1920, 1080), "scale": 1.0, "modality": "pointer", "family": "xbox"},
	{"name": "1920x1080_100_controller", "size": Vector2i(1920, 1080), "scale": 1.0, "modality": "controller", "family": "xbox"},
	{"name": "1920x1080_150_pointer", "size": Vector2i(1920, 1080), "scale": 1.5, "modality": "pointer", "family": "xbox"},
	{"name": "1920x1080_125_pointer", "size": Vector2i(1920, 1080), "scale": 1.25, "modality": "pointer", "family": "xbox"},
	{"name": "1280x800_deck_controller", "size": Vector2i(1280, 800), "scale": 1.15, "modality": "controller", "family": "steam_deck"},
]

class MenuFixture extends "res://scripts/main_menu.gd":
	var requested_scene: String = ""
	func _change_scene_to_file(path: String, _prepare: Callable = Callable()) -> void: requested_scene = path
	func _on_quit_button_pressed() -> void: requested_scene = "quit"

var _viewport: SubViewport
var _router: Node
var _failed: bool = false
var _headless: bool
var _output: String
var _captures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_headless = OS.get_cmdline_user_args().has("--headless-check") or DisplayServer.get_name() == "headless"
	_output = _arg("--output-dir", OUTPUT_DEFAULT)
	if not _headless:
		_check(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Capture requires the approved cel look")
		_check(CelLook.mode == "all" and not CelLook._files.is_empty(), "Approved cel variants are loaded")
	Store.set_storage_path("user://ux17_progression.json")
	Store.set_run_storage_path("user://ux17_run.save")
	Settings.set_storage_path("user://ux17_settings.json")
	Store.save_data(Store.default_data())
	Store.clear_saved_run()
	Router.ensure_input_map()
	_router = root.get_node("InputRouter")
	_audit_data()
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()

func _run() -> void:
	for case: Dictionary in CASES:
		await _case(case)
	_router.call("clear_forced_state_for_test")
	for path: String in _captures: print(path)
	print("UX17 %s RESULT: %s" % ["HEADLESS" if _headless else "CAPTURE", "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

# Static claims: every controller entry is a real router glyph and every action
# with an InputMap entry has a pad input. Key checks for the layout-aware keys
# (P and 1-9 live in combat_keyboard_shortcuts.gd; Z is the undo InputMap event).
func _audit_data() -> void:
	var entries: Array[Dictionary] = PanelScript.controls_entries()
	_check(entries.size() == 13, "controls.json lists the 13 approved rows (got %d)" % entries.size())
	for entry: Dictionary in entries:
		for action_var: Variant in entry.get("controller", []):
			var action := StringName(str(action_var))
			_check(Router.glyph_label_for_family(action, Router.FAMILY_XBOX) != "?", "%s has a router glyph" % action)
			if InputMap.has_action(action):
				var joypad: bool = false
				for event: InputEvent in InputMap.action_get_events(action):
					joypad = joypad or Router.is_controller_event(event)
				_check(joypad, "%s is bound to a pad input" % action)
		for token: Variant in entry.get("pointer", []):
			_check(token is String or (token is Dictionary and not str((token as Dictionary).get("key", "")).is_empty()), "%s: tokens are phrases or {key}" % entry["id"])
	# Z: the key that types z undoes (AZERTY puts it at the US W position);
	# the US Z position typing w does not. Ctrl/Cmd+Z still undo.
	_check(_key_event(KEY_Z, KEY_W).is_action_pressed(Router.ACTION_UNDO_MOVE), "AZERTY z undoes a walk")
	_check(not _key_event(KEY_W, KEY_Z).is_action_pressed(Router.ACTION_UNDO_MOVE), "AZERTY w at the US Z position does not undo")
	_check(_key_event(KEY_Z, KEY_Z).is_action_pressed(Router.ACTION_UNDO_MOVE), "QWERTY z undoes a walk")
	for modifier: String in ["ctrl", "meta"]:
		var chord: InputEventKey = _key_event(KEY_Z, KEY_W)
		chord.ctrl_pressed = modifier == "ctrl"
		chord.meta_pressed = modifier == "meta"
		_check(chord.is_action_pressed(Router.ACTION_UNDO_MOVE), "%s+z undoes a walk" % modifier)
	_check(_key_event(KEY_ESCAPE, KEY_ESCAPE).is_action_pressed("ui_cancel"), "Esc is ui_cancel")
	var shortcuts: GDScript = preload("res://scripts/combat_keyboard_shortcuts.gd")
	for digit: int in range(9):
		_check(shortcuts.hand_index(_key_event(KEY_1 + digit, KEY_1 + digit)) == digit, "%d picks hand card %d" % [digit + 1, digit + 1])

func _key_event(keycode: int, physical: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode as Key
	key.physical_keycode = physical as Key
	key.pressed = true
	return key

func _case(case: Dictionary) -> void:
	var label: String = str(case["name"])
	var size: Vector2i = case["size"]
	var scale: float = float(case["scale"])
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = Settings.nearest_supported_ui_scale(scale)
	Settings.save_settings(settings)
	_router.call("set_forced_state_for_test", str(case["modality"]), str(case["family"]))
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The production window's logical envelope: expand to the output's aspect,
	# then divide by the Interface scale (window content_scale_factor).
	var fit: float = minf(float(size.x) / PROOF_SIZE.x, float(size.y) / PROOF_SIZE.y)
	if not is_equal_approx(fit * scale, 1.0):
		_viewport.size_2d_override = Vector2i(Vector2(size) / (fit * scale))
		_viewport.size_2d_override_stretch = true
	root.add_child(_viewport)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	menu.set_script(MenuFixture)
	_viewport.add_child(menu)
	await _settle()
	menu.call("_on_settings_button_pressed")
	await _settle()
	var panel: Control = menu.get("settings_panel")
	_check(panel != null and panel.visible, label + ": Settings opens")
	if panel != null and panel.visible:
		await _check_panel(case, panel)
	_viewport.queue_free()
	await process_frame

func _check_panel(case: Dictionary, panel: Control) -> void:
	var label: String = str(case["name"])
	var section: Control = panel.find_child("ControlsSection", true, false)
	_check(section != null, label + ": Controls section exists")
	if section == null: return
	var sections: Node = section.get_parent()
	_check(section.get_index() == sections.get_child_count() - 1 and section.get_index() == 3, label + ": Controls is the fourth section, after Accessibility")
	var header: HBoxContainer = section.get_meta("header")
	_check((header.get_child(0) as Label).text == "CONTROLS", label + ": section title")
	_check((header.get_child(1) as Label).text == "What each key and button does." and not (header.get_child(1) as Label).visible, label + ": subtitle copy, hidden like every section tagline")
	var scroll: ScrollContainer = section.get_parent().get_parent() as ScrollContainer
	_check(scroll != null, label + ": Controls scrolls with the panel")
	var rows: Array[Control] = _control_rows(section)
	var entries: Array[Dictionary] = PanelScript.controls_entries()
	_check(rows.size() == entries.size(), label + ": one row per data entry")
	for index: int in range(mini(rows.size(), entries.size())):
		_check_row(label, rows[index], entries[index], _settings_row(panel, "reduced_motion"))
	var view := Rect2(Vector2.ZERO, Vector2(_viewport.get_visible_rect().size))
	_check(view.grow(0.5).encloses(panel.get_global_rect()), label + ": panel fits the screen %s in %s" % [panel.get_global_rect(), view])
	_check(section.size.x <= scroll.size.x + 0.5, label + ": no horizontal overflow (%.1f > %.1f)" % [section.size.x, scroll.size.x])
	_check_columns(label, section, rows)
	_check_family(label, rows)
	# Scroll to Controls: its top at the top of the scroll view.
	scroll.scroll_vertical = int(section.position.y)
	await _settle()
	if str(case["modality"]) == "controller":
		await _check_navigation(label, panel, scroll, rows)
		scroll.scroll_vertical = int(section.position.y)
		await _settle()
		rows[0].grab_focus()
		await _joy(JOY_BUTTON_DPAD_DOWN)
		_check(_viewport.gui_get_focus_owner() == rows[1] and rows[1].has_focus(true), label + ": D-pad focus is visible on the second row")
	else:
		await _check_hover(label, section, rows, scroll)
	await _capture(label)

func _control_rows(section: Control) -> Array[Control]:
	var result: Array[Control]
	var rows: VBoxContainer = section.get_meta("rows")
	for child: Node in rows.get_children():
		if child is PanelScript.ControlsRow: result.append(child as Control)
	return result

# The existing settings row that holds a control (row > margin > content > control).
func _settings_row(panel: Control, key: String) -> Control:
	return ((panel.get("_controls") as Dictionary)[key] as Control).get_parent().get_parent().get_parent() as Control

func _check_row(label: String, row: Control, entry: Dictionary, existing_row: Control) -> void:
	var context: String = "%s %s" % [label, str(entry.get("id", ""))]
	var content: HBoxContainer = row.get_child(0).get_child(0) as HBoxContainer
	var title: Label = content.get_child(0) as Label
	_check(title.text == str(entry["label"]), context + ": label text")
	_check(title.get_theme_font("font") == PanelScript.UI_FONT and title.get_theme_color("font_color") == Color("f3e7cc"), context + ": label uses the settings row font and colour")
	_check(title.get_theme_font_size("font_size") == Typography.scaled_size(title, Typography.SIZE_BODY_LARGE) or title.get_theme_font_size("font_size") == Typography.SIZE_BODY_LARGE, context + ": label uses the settings row size")
	_check(title.get_minimum_size().x <= title.size.x + 0.5, context + ": label is not clipped")
	_check(row.focus_mode == Control.FOCUS_ALL and row.mouse_filter == existing_row.mouse_filter, context + ": focusable, same mouse filter as the other settings rows")
	_check(row.get_theme_stylebox("panel") is StyleBoxFlat and (row.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == (existing_row.get_theme_stylebox("panel") as StyleBoxFlat).bg_color and row.custom_minimum_size == existing_row.custom_minimum_size, context + ": same row frame as the other settings rows")
	var pointer: HBoxContainer = row.find_child("PointerBindings", true, false)
	var controller: HBoxContainer = row.find_child("ControllerBindings", true, false)
	var tokens: Array = entry.get("pointer", [])
	if tokens.is_empty():
		_check(pointer.get_child_count() == 1 and (pointer.get_child(0) as Label).text == "—", context + ": empty pointer shows —")
	else:
		_check(pointer.get_child_count() == tokens.size(), context + ": one pointer cell child per token")
		for index: int in range(mini(tokens.size(), pointer.get_child_count())):
			var token: Variant = tokens[index]
			var child: Control = pointer.get_child(index)
			if token is Dictionary:
				var key_text: String = str((token as Dictionary)["key"])
				_check(child is PanelScript.ControlsKeycap and str(child.get("key_text")) == key_text, context + ": keycap " + key_text)
				if not child is PanelScript.ControlsKeycap: continue
				_check(str(child.get("family")) == Router.FAMILY_XBOX, context + ": %s keycap keeps the Xbox dark styling" % key_text)
				var label_size: int = int(child.call("_rounded_key_label_size"))
				_check(label_size == Typography.scaled_size(child, 17 if key_text.length() == 1 else 13), context + ": %s label at %d pt" % [key_text, label_size])
				var text_width: float = Typography.ui_font().get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
				_check(child.size.x >= text_width + 4.0 and child.size.x >= 36.0 * Typography.ui_scale(child) - 0.5, context + ": %s keycap fits its label (%.1f for %.1f)" % [key_text, child.size.x, text_width])
			else:
				var phrase: Label = child as Label
				_check(phrase != null and phrase.text == str(token), context + ": phrase " + str(token))
				if phrase != null: _check(phrase.get_theme_font("font") == PanelScript.TEXT_FONT and phrase.get_theme_color("font_color") == PanelScript.MUTED_TEXT, context + ": %s is caption text" % phrase.text)
	var actions: Array = entry.get("controller", [])
	if actions.is_empty():
		_check(controller.get_child_count() == 1 and (controller.get_child(0) as Label).text == "—", context + ": empty controller shows —")
	else:
		_check(controller.get_child_count() == actions.size(), context + ": one badge per action")
		for index: int in range(mini(actions.size(), controller.get_child_count())):
			var glyph: Control = controller.get_child(index)
			_check(glyph is PanelScript.ControlsGlyph and glyph.get("action_name") == StringName(str(actions[index])), context + ": badge " + str(actions[index]))
			var preferred: Vector2 = preload("res://scripts/input_glyph.gd").preferred_size(StringName(str(actions[index]))) * Typography.ui_scale(glyph)
			_check(glyph.size.is_equal_approx(preferred), context + ": badge at InputGlyph.preferred_size (%s vs %s)" % [glyph.size, preferred])
	var row_rect: Rect2 = row.get_global_rect().grow(0.5)
	for cell: Control in [title, pointer, controller]:
		_check(row_rect.encloses(cell.get_global_rect()), context + ": %s inside the row" % cell.name)
	for cell: Control in [pointer, controller]:
		for child: Node in cell.get_children():
			# InputGlyph sizes are fractional; containers round to whole pixels.
			_check(cell.get_global_rect().grow(1.0).encloses((child as Control).get_global_rect()), context + ": %s child inside its column (%s in %s)" % [cell.name, (child as Control).get_global_rect(), cell.get_global_rect()])
	_check(title.get_global_rect().end.x <= pointer.get_global_rect().position.x + 0.5, context + ": label and pointer column do not overlap")

func _check_columns(label: String, section: Control, rows: Array[Control]) -> void:
	var headings: Control = section.find_child("ControlsHeadings", true, false)
	var heading_box: HBoxContainer = headings.get_child(0) as HBoxContainer
	var pointer_heading: Label = heading_box.get_child(0) as Label
	var controller_heading: Label = heading_box.get_child(1) as Label
	_check(pointer_heading.text == "Keyboard and mouse" and controller_heading.text == "Controller", label + ": column headings")
	_check(pointer_heading.get_theme_font("font") == PanelScript.TEXT_FONT and pointer_heading.get_theme_color("font_color") == PanelScript.MUTED_TEXT, label + ": headings use the section caption style")
	for row: Control in rows:
		var pointer: Control = row.find_child("PointerBindings", true, false)
		var controller: Control = row.find_child("ControllerBindings", true, false)
		_check(absf(pointer.get_global_rect().end.x - pointer_heading.get_global_rect().end.x) <= 0.5, label + " %s: pointer column aligns with its heading" % row.name)
		_check(absf(controller.get_global_rect().end.x - controller_heading.get_global_rect().end.x) <= 0.5, label + " %s: controller column aligns with its heading" % row.name)
		_check(absf(pointer.size.x - pointer_heading.size.x) <= 0.5 and absf(controller.size.x - controller_heading.size.x) <= 0.5, label + " %s: column widths match" % row.name)

func _check_family(label: String, rows: Array[Control]) -> void:
	var bumpers: Control = null
	for row: Control in rows:
		for glyph: Node in row.find_children("*", "Control", true, false):
			if glyph is PanelScript.ControlsGlyph and glyph.get("action_name") == Router.ACTION_HAND_BUMPERS: bumpers = glyph
	_check(bumpers != null, label + ": bumper badge exists")
	if bumpers == null: return
	var family: String = str(_router.call("controller_family"))
	_check(str(bumpers.get("family")) == family, label + ": badges follow the router family " + family)
	var other: String = Router.FAMILY_STEAM_DECK if family == Router.FAMILY_XBOX else Router.FAMILY_XBOX
	_router.call("force_family_for_test", other)
	_check(str(bumpers.get("family")) == other, label + ": badges switch live on controller_family_changed")
	_router.call("force_family_for_test", family)
	_check(str(bumpers.get("family")) == family, label + ": badges switch back")

func _check_navigation(label: String, panel: Control, scroll: ScrollContainer, rows: Array[Control]) -> void:
	# Start on the last focusable control of the section above (Accessibility).
	var above: Control = rows[0].get_parent().get_parent().get_parent().get_parent().get_parent().get_child(2)
	var last_above: Control = null
	for node: Node in above.find_children("*", "Control", true, false):
		if (node as Control).focus_mode == Control.FOCUS_ALL and (node as Control).is_visible_in_tree(): last_above = node
	_check(last_above != null, label + ": Accessibility has a focusable control")
	if last_above == null: return
	last_above.grab_focus()
	await _settle()
	var before: Dictionary = Settings.load_settings()
	for index: int in range(rows.size()):
		await _joy(JOY_BUTTON_DPAD_DOWN)
		var focused: Control = _viewport.gui_get_focus_owner()
		_check(focused == rows[index], label + ": D-pad down reaches %s (got %s)" % [rows[index].name, focused.name if focused != null else "nothing"])
		if focused != rows[index]: return
		var view: Rect2 = scroll.get_global_rect().grow(0.5)
		_check(view.encloses(focused.get_global_rect()), label + ": the panel scrolls %s into view" % focused.name)
		_check(focused.has_focus(true), label + ": %s shows its focus ring" % focused.name)
	var last: Control = rows[rows.size() - 1]
	await _joy(JOY_BUTTON_A)
	_check(_viewport.gui_get_focus_owner() == last and panel.visible and Settings.load_settings() == before, label + ": A on a row does nothing")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _joy(JOY_BUTTON_DPAD_LEFT)
	_check(_viewport.gui_get_focus_owner() == last, label + ": left and right stay on the row")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	var footer: Control = _viewport.gui_get_focus_owner()
	_check(footer is Button and not rows.has(footer), label + ": down from the last row reaches the footer")
	for index: int in range(rows.size() - 1, -1, -1):
		await _joy(JOY_BUTTON_DPAD_UP)
		_check(_viewport.gui_get_focus_owner() == rows[index], label + ": D-pad up returns through %s" % rows[index].name)

func _check_hover(label: String, section: Control, rows: Array[Control], scroll: ScrollContainer) -> void:
	var target: Control = section.find_child("Controls_" + HOVER_ROW, true, false)
	_check(target != null, label + ": hover target row exists")
	if target == null: return
	var point: Vector2 = target.get_global_rect().get_center()
	# The wheel over a row still scrolls the panel, as over the other rows.
	var top: int = scroll.scroll_vertical
	for pressed: bool in [true, false]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.position = point
		wheel.global_position = point
		wheel.pressed = pressed
		wheel.factor = 1.0
		_viewport.push_input(wheel, true)
	await _settle()
	_check(scroll.scroll_vertical > top or scroll.scroll_vertical >= int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page), label + ": the wheel over a Controls row scrolls the panel")
	scroll.scroll_vertical = top
	await _settle()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(4.0, 0.0)
	_viewport.push_input(motion, true)
	await _settle()
	_check(not target.has_method("hovered") and not target.has_focus(true), label + ": hover draws nothing on a read-only row")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.global_position = point
	click.pressed = true
	_viewport.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	_viewport.push_input(click, true)
	await _settle()
	_check(not target.has_focus(true), label + ": a click shows no focus ring on a read-only row")

func _capture(label: String) -> void:
	if _headless: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_check(image != null and image.get_size() == _viewport.size, label + ": capture is exactly %s" % _viewport.size)
	if image == null: return
	var path: String = _output.path_join("ux17_%s.png" % label)
	_check(image.save_png(path) == OK, label + ": capture saves")
	_captures.append(path)

func _joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	_viewport.push_input(event, true)
	await process_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	_viewport.push_input(event, true)
	await process_frame
	await process_frame

func _settle() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame
	await process_frame

func _check(condition: bool, message: String) -> void:
	if condition: return
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)

func _arg(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
