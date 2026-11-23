extends SceneTree

## Real Settings and combat scene proof. The headless route performs the same
## layout and input checks without asking a dummy viewport for pixels.
const Keys = preload("res://scripts/key_bindings.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Wording = preload("res://scripts/input_wording.gd")
const CombatProof = preload("res://tools/ux19/combat_proof.gd")
const CelLook = preload("res://scripts/cel_look.gd")

const DESKTOP := Vector2i(1920, 1080)
const DECK := Vector2i(1280, 800)
const UI_SCALE: float = 1.0
const SETTLE_SECONDS: float = 0.5
const FIXTURE_MUSIC_VOLUME: float = 0.32

const CAPTURES := [
	"desktop_controls", "desktop_listening", "desktop_swap", "desktop_unbound",
	"desktop_restore", "desktop_combat_pass_q", "deck_controls",
]

class FakeAzertyDisplay extends RefCounted:
	func get_name() -> String: return "fake_azerty"
	func keyboard_get_keycode_from_physical(key: Key) -> Key:
		if key == KEY_W: return KEY_Z
		if key == KEY_Z: return KEY_W
		if key == KEY_Q: return KEY_A
		if key == KEY_A: return KEY_Q
		return key
	func keyboard_get_label_from_physical(key: Key) -> Key:
		return keyboard_get_keycode_from_physical(key)

var _viewport: SubViewport
var _router: Node
var _output: String
var _settings_path: String
var _headless: bool
var _failures: int
var _checks: int
var _profile: Dictionary

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_output = _arg("--output-dir", "/private/tmp/labyrinth_codex/ux-19/captures")
	_settings_path = _arg("--settings-path", "user://ux19_settings.json")
	Settings.set_storage_path(_settings_path)
	if "--verify-restart" in OS.get_cmdline_user_args():
		var loaded: Dictionary = Settings.apply_settings(Settings.load_settings(), root, false)
		_check(loaded[Keys.SETTING] == CombatProof.REBOUND and Keys.label(Keys.PASS) == "Q", "A new Godot process loads all six saved bindings")
		_finish("RESTART")
		return

	DirAccess.make_dir_recursive_absolute(_output)
	_router = root.get_node("InputRouter")
	Store.set_storage_path("user://ux19_profile.json")
	Store.set_run_storage_path("user://ux19_run.save")
	Store.clear_saved_run()
	_profile = Store.default_data()
	_profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(_profile)
	if not _headless:
		_check(CelLook.mode == "all" and not CelLook._files.is_empty(), "Approved cel look is active")
	await _proof_settings()
	if _headless:
		_proof_storage()
		_proof_layout()
		_proof_grimoire()
	_open_viewport(DESKTOP)
	_router.set_forced_state_for_test("pointer", "xbox")
	var scene: Control = await CombatProof.setup(self, _viewport, _profile, _check)
	var hint: Label = scene.find_child("PassKeyHint", true, false)
	_check(hint != null and hint.visible and hint.text == "Q", "Combat capture shows Q on the Pass face")
	await _capture("desktop_combat_pass_q")
	if _headless: await CombatProof.verify(self, scene, _check)
	await _close_viewport()
	# Preserve the authored defaults in the Deck capture, and restore the
	# persisted rebound settings after the final viewport closes.
	var rebound_settings: Dictionary = Settings.load_settings()
	_save_defaults()
	_open_viewport(DECK)
	_router.set_forced_state_for_test("controller", "steam_deck")
	var deck_panel: Control = await _open_settings()
	_check_settings_size(deck_panel)
	_check(_cap_text(deck_panel, Keys.PASS) == "P", "Deck uses default keycaps at rest")
	await _capture("deck_controls")
	await _close_viewport()
	Settings.save_settings(rebound_settings)
	_router.clear_forced_state_for_test()
	_finish("HEADLESS" if _headless else "NATIVE")

func _proof_settings() -> void:
	_save_defaults()
	_open_viewport(DESKTOP)
	_router.set_forced_state_for_test("pointer", "xbox")
	var panel: Control = await _open_settings()
	_check_settings_size(panel)
	var caps: Dictionary = panel.get("_keycaps")
	var restore: Button = panel.find_child("RestoreDefaultKeys", true, false)
	_check(caps.size() == 6 and restore.disabled, "Exactly six rows are editable and default keys cannot be restored")
	var pass_button: Button = caps[Keys.PASS]
	var pass_row: Control = panel.find_child("Controls_pass", true, false)
	var old_size := pass_button.size
	var row_height: float = pass_row.size.y
	await _capture("desktop_controls")
	pass_button.grab_focus()
	await _key(KEY_SPACE)
	_check(not _listening(panel, Keys.PASS), "Space stays available to bind and does not start listening")

	await _click(pass_button.get_global_rect().get_center())
	_check(_listening(panel, Keys.PASS) and _cap_text(panel, Keys.PASS) == "Press a key", "Click starts listening with the exact label")
	_check(pass_button.size.x > old_size.x and is_equal_approx(pass_row.size.y, row_height), "Listening widens only the keycap")
	_check(pass_button.get_node("MoltenSelection").visible, "Listening shows the molten selection")
	_check_settings_size(panel)
	await _capture("desktop_listening")

	var ignored: Array[Key]
	ignored.assign([KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK])
	for digit: int in range(9):
		ignored.append((KEY_1 + digit) as Key)
		ignored.append((KEY_KP_1 + digit) as Key)
	for key: Key in ignored:
		await _key(key)
		_check(_listening(panel, Keys.PASS) and Keys.physical_key(Keys.PASS) == Keys.defaults()[Keys.PASS], "%s leaves Settings listening" % OS.get_keycode_string(key))
	await _key(KEY_ESCAPE)
	_check(panel.visible and not _listening(panel, Keys.PASS) and _cap_text(panel, Keys.PASS) == "P", "Esc cancels without closing Settings")
	await _listen(panel, Keys.PASS)
	var back: Button = panel.back_button()
	await _click(back.get_global_rect().get_center())
	_check(not _listening(panel, Keys.PASS) and panel.visible, "A click cancels and never activates the clicked Back button")
	await _listen(panel, Keys.PASS)
	await _click(Vector2.ZERO)
	_check(not _listening(panel, Keys.PASS) and panel.visible, "An outside click cancels without closing Settings")
	pass_button.grab_focus()
	await _joy(JOY_BUTTON_A)
	_check(_listening(panel, Keys.PASS), "Controller A starts listening")
	await _joy(JOY_BUTTON_B)
	_check(panel.visible and not _listening(panel, Keys.PASS), "Controller B cancels without closing Settings")

	await _listen(panel, Keys.PASS)
	# The new glyph follows physical E even if the event's logical label differs.
	_viewport.push_input(CombatProof.key_event(Keys.defaults()[Keys.EMPOWER], true, KEY_G), true)
	var empower_button: Button = caps[Keys.EMPOWER]
	_check(Keys.physical_key(Keys.PASS) == Keys.defaults()[Keys.EMPOWER] and Keys.physical_key(Keys.EMPOWER) == Keys.defaults()[Keys.PASS], "Conflicting key swaps both physical bindings")
	_check(_cap_text(panel, Keys.PASS) == "E" and _cap_text(panel, Keys.EMPOWER) == "P", "Both keycaps immediately show the swap")
	var peaked: Array[Button]
	peaked.assign([pass_button, empower_button])
	for button: Button in peaked:
		var pulse: Tween = button.get("_pulse")
		_check(pulse != null and button.get_node("MoltenSelection").visible, "Both swapped keycaps pulse")
		if pulse != null:
			pulse.pause()
			pulse.custom_step(button.PULSE_IN)
	await _settle()
	_check_settings_size(panel)
	await _capture("desktop_swap")
	for button: Button in peaked:
		var pulse: Tween = button.get("_pulse")
		if pulse != null: pulse.play()
	_viewport.push_input(CombatProof.key_event(Keys.defaults()[Keys.EMPOWER], false, KEY_G), true)
	await _settle()
	_check(not pass_button.get_node("MoltenSelection").visible and not empower_button.get_node("MoltenSelection").visible, "Both selection pulses retire after one beat")

	await _listen(panel, Keys.PASS)
	await _key(KEY_BACKSPACE)
	_check(Keys.physical_key(Keys.PASS) == KEY_NONE and _cap_text(panel, Keys.PASS) == "—", "Backspace unbinds and the Controls cap shows an em dash")
	await _capture("desktop_unbound")
	await _listen(panel, Keys.PASS)
	await _key(Keys.defaults()[Keys.PASS])
	_check(Keys.physical_key(Keys.PASS) == Keys.defaults()[Keys.PASS] and Keys.physical_key(Keys.EMPOWER) == KEY_NONE, "Swapping from an unbound action unbinds the other action")
	await _listen(panel, Keys.PASS)
	await _key(KEY_DELETE)
	_check(_cap_text(panel, Keys.PASS) == "—", "Delete also unbinds")

	restore.grab_focus()
	await _key(KEY_ENTER)
	_check(panel.get("_confirmation_panel").visible and panel.get("_confirmation_title").text == "Restore default keys?", "Restore keys opens the shared confirmation with the exact title")
	var cancel: Button = panel.get("_confirmation_cancel")
	var confirm: Button = cancel.get_parent().get_child(cancel.get_index() + 1)
	_check(cancel.text == "Cancel" and confirm.text == "Restore Keys", "Restore keys names its own confirm button")
	await _capture("desktop_restore")
	await _key(KEY_ENTER)
	_check(not panel.get("_confirmation_panel").visible and Keys.physical_key(Keys.PASS) == KEY_NONE, "Confirmation Cancel retains bindings")
	restore.grab_focus()
	await _key(KEY_ENTER)
	confirm.grab_focus()
	await _key(KEY_ENTER)
	var restored: Dictionary = Settings.load_settings()
	_check(restored[Keys.SETTING] == Keys.defaults() and restore.disabled, "Confirm restores all six defaults and disables Restore keys")
	_check(is_equal_approx(restored["music_volume"], FIXTURE_MUSIC_VOLUME), "Restore keys preserves other preferences")

	for action: String in CombatProof.REBOUND:
		await _listen(panel, action)
		await _key(CombatProof.REBOUND[action])
	_check(Settings.load_settings()[Keys.SETTING] == CombatProof.REBOUND, "Six edits write their physical keycodes to settings")
	await _close_viewport()

func _proof_storage() -> void:
	const MALFORMED := "{malformed settings"
	var bad_path := "user://ux19_malformed.json"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string(MALFORMED)
	file.close()
	Settings.set_storage_path(bad_path)
	var fallback: Dictionary = Settings.apply_settings(Settings.load_settings(), root, false)
	_check(fallback[Keys.SETTING] == Keys.defaults() and Keys.physical_key(Keys.PASS) == Keys.defaults()[Keys.PASS], "Unparseable settings load default bindings")
	_check(FileAccess.get_file_as_string(bad_path) == MALFORMED and not FileAccess.file_exists(bad_path + ".tmp"), "Loading unparseable settings writes nothing")
	var locked_path := "user://ux19_unreadable.json"
	var contents: String = JSON.stringify({Keys.SETTING: CombatProof.REBOUND})
	var locked_file := FileAccess.open(locked_path, FileAccess.WRITE)
	locked_file.store_string(contents)
	locked_file.close()
	var original_permissions := FileAccess.get_unix_permissions(locked_path)
	_check(FileAccess.set_unix_permissions(locked_path, 0) == OK and FileAccess.open(locked_path, FileAccess.READ) == null, "Settings fixture denies file reads")
	Settings.set_storage_path(locked_path)
	fallback = Settings.apply_settings(Settings.load_settings(), root, false)
	_check(fallback[Keys.SETTING] == Keys.defaults() and Keys.physical_key(Keys.PASS) == Keys.defaults()[Keys.PASS], "An unreadable settings file gives defaults")
	_check(FileAccess.set_unix_permissions(locked_path, original_permissions) == OK, "Settings fixture restores file permissions")
	_check(FileAccess.get_file_as_string(locked_path) == contents and not FileAccess.file_exists(locked_path + ".tmp"), "Loading unreadable settings writes nothing")
	var normalized: Dictionary = Keys.normalize({Keys.PASS: "81", Keys.HURRY: KEY_7, Keys.MAP: 81.5, Keys.EMPOWER: 0, Keys.ENEMY_INTENTS: 999999})
	var expected: Dictionary = Keys.defaults()
	expected[Keys.EMPOWER] = KEY_NONE
	_check(normalized == expected, "Missing and invalid entries fall back separately and zero remains unbound")
	Settings.set_storage_path(_settings_path)
	Settings.apply_settings(Settings.load_settings(), root, false)

func _proof_layout() -> void:
	var azerty := FakeAzertyDisplay.new()
	var defaults: Dictionary = Keys._layout_defaults(azerty)
	_check(defaults[Keys.UNDO_WALK] == KEY_W, "Default Undo follows the Z position in a simulated AZERTY layout")
	_check(Keys.label(Keys.PASS, azerty) == "A", "Rebound physical Q displays the AZERTY A label")
	_check(Keys.pressed(Keys.PASS, CombatProof.key_event(KEY_Q, true, KEY_A)), "Rebound key matches the physical event even when AZERTY's logical key differs")
	_check(not Keys.pressed(Keys.PASS, CombatProof.key_event(KEY_A, true, KEY_Q)), "Typing the rebound letter at another position does not match")

func _proof_grimoire() -> void:
	var all_entries: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/grimoire.json"))
	var authored: String = JSON.stringify(all_entries)
	var expected := {
		Keys.EMPOWER: ["Charge a card with the seal in the upper right, E, or the controller's right stick.", "upper right, G,", "(or the right stick on a controller)"],
		Keys.ENEMY_INTENTS: ["Press I to see each enemy's full plan.", "Press J", "Select Details on the turn rail"],
		Keys.UNDO_WALK: ["Press Z to undo free Movement before you play a card.", "Press V to undo", "Undo move takes back"],
	}
	for action: String in expected:
		var parts: Array = expected[action]
		_check(parts[0] in authored and parts[1] in Wording.grimoire_body({"body": [parts[0]]}, false), "Grimoire updates the authored %s key sentence" % action)
		var unbound: Dictionary = CombatProof.REBOUND.duplicate()
		unbound[action] = KEY_NONE
		Keys.apply(unbound)
		_check(parts[2] in Wording.grimoire_body({"body": [parts[0]]}, false), "Unbound Grimoire drops the %s key" % action)
		Keys.apply(CombatProof.REBOUND)

func _open_viewport(dimensions: Vector2i) -> void:
	_viewport = SubViewport.new()
	_viewport.size = dimensions
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var fit: float = minf(float(dimensions.x) / DESKTOP.x, float(dimensions.y) / DESKTOP.y)
	if fit != 1.0:
		_viewport.size_2d_override = Vector2i(Vector2(dimensions) / (fit * UI_SCALE))
		_viewport.size_2d_override_stretch = true
	root.add_child(_viewport)

func _close_viewport() -> void:
	_viewport.queue_free()
	await process_frame

func _open_settings() -> Control:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	_viewport.add_child(menu)
	await _settle()
	menu.call("_on_settings_button_pressed")
	await _settle()
	var panel: Control = menu.get("settings_panel")
	var section: Control = panel.find_child("ControlsSection", true, false)
	var scroll: ScrollContainer = section.get_parent().get_parent()
	scroll.scroll_vertical = int(section.position.y)
	await _settle()
	return panel

func _check_settings_size(panel: Control) -> void:
	var section: Control = panel.find_child("ControlsSection", true, false)
	var scroll: ScrollContainer = section.get_parent().get_parent()
	_check(panel.visible and _viewport.get_visible_rect().grow(0.5).encloses(panel.get_global_rect()), "Settings fits inside the exact-size viewport")
	_check(section.size.x <= scroll.size.x + 0.5, "Controls has no horizontal clipping")

func _save_defaults() -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["music_volume"] = FIXTURE_MUSIC_VOLUME
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)

func _listen(panel: Control, action: String) -> void:
	var caps: Dictionary = panel.get("_keycaps")
	(caps[action] as Button).grab_focus()
	await _key(KEY_ENTER)
	_check(_listening(panel, action), "Enter starts listening for " + action)

func _listening(panel: Control, action: String) -> bool:
	return panel.get("_listening_action") == action

func _cap_text(panel: Control, action: String) -> String:
	return panel.get("_keycaps")[action].get_node("Keycap").key_text

func _key(code: Key) -> void:
	await CombatProof.send_key(self, _viewport, code)

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	_viewport.push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		_viewport.push_input(event, true)
		await process_frame

func _joy(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		_viewport.push_input(event, true)
		await process_frame

func _settle() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame

func _capture(label: String) -> void:
	if _headless: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_check(image != null and image.get_size() == _viewport.size, label + " is an exact-size SubViewport image")
	if image == null: return
	var path := _output.path_join(label + ".png")
	_check(image.save_png(path) == OK, label + " saves")
	print(path)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition: return
	_failures += 1
	printerr("UX19 CHECK FAILED: " + message)

func _finish(mode: String) -> void:
	if _headless and mode == "HEADLESS":
		for label: String in CAPTURES:
			print("Planned native capture: " + _output.path_join(label + ".png"))
	print("UX19 %s RESULT: %d passed, %d failed" % [mode, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)

func _arg(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
