extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const MAIN_MENU := "res://scenes/main_menu.tscn"
const OUTPUT_DIR := "user://ux12_settings"
const DESKTOP_RESOLUTION := Vector2i(1920, 1080)
const DECK_RESOLUTION := Vector2i(1280, 800)
const CAPTURE_SETTLE_FRAMES: int = 3

var _failures: int = 0
var _layout_only: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ParallelRuntime.apply_from_environment()
	Settings.set_storage_path("user://ux12_visual_settings.json")
	_layout_only = DisplayServer.get_name() == "headless"
	if not _layout_only:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var menu: Node = null
	menu = await _capture(DESKTOP_RESOLUTION, false, "settings_desktop.png", menu)
	await _capture(DECK_RESOLUTION, true, "settings_deck.png", menu)
	var proof: String = "LAYOUT" if _layout_only else "VISUAL PROBE"
	if not _layout_only:
		print("SETTINGS_QOL_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	print("SETTINGS QOL %s: %s" % [proof, "PASS" if _failures == 0 else "FAIL"])
	Shutdown.request(self, "settings_visual_probe", 0 if _failures == 0 else 1)

func _capture(resolution: Vector2i, deck: bool, filename: String, menu: Node) -> Node:
	OS.set_environment("SteamDeck", "1" if deck else "0")
	if root.mode != Window.MODE_WINDOWED:
		root.mode = Window.MODE_WINDOWED
	# Scene settings apply normally except for native window geometry.
	OS.set_environment("LABYRINTH_PROBE_WINDOW", "1")
	root.size = resolution
	var settings: Dictionary = Settings.default_settings()
	_expect(Settings.save_settings(settings), "Save fixture profile for " + filename)
	Settings.apply_settings(settings, root, false)
	if menu == null:
		var packed: PackedScene = load(MAIN_MENU)
		menu = packed.instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		menu.call("_on_settings_button_pressed")
	else:
		menu.get_node("SettingsPanel").call("open")
	for frame: int in range(CAPTURE_SETTLE_FRAMES):
		await process_frame

	var panel := menu.get_node("SettingsPanel") as Control
	var scroll := panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	var controls: Dictionary = panel.get("_controls")
	var mute: OptionButton = controls["mute_in_background"]
	var interface: HSlider = controls["ui_volume"]["slider"]
	var display_scale: float = 1.15 if deck else 1.0
	_expect(panel.is_visible_in_tree() and panel.get_viewport_rect().encloses(panel.get_global_rect()), "Settings and its footer fit in " + filename)
	_expect(is_equal_approx(root.content_scale_factor, display_scale), "Active UI scale matches " + filename)
	_expect(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scroll.follow_focus, "Existing scroll navigation remains active in " + filename)
	_expect(scroll.get_global_rect().encloses(interface.get_global_rect()) and scroll.get_global_rect().encloses(mute.get_global_rect()), "Both new audio controls are visible in " + filename)
	_expect(interface.value == 1.0 and mute.selected == 0, "New audio controls show authored defaults in " + filename)

	if not _layout_only:
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		_expect(screenshot.get_size() == resolution, "Rendered dimensions match " + filename)
		_expect(screenshot.save_png(OUTPUT_DIR.path_join(filename)) == OK, "Save " + filename)
	return menu

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
