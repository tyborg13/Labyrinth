extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Run = preload("res://scripts/run_engine.gd")
const Events = preload("res://tests/suites/event_view_suite.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Notifications = preload("res://scripts/run_notification_queue.gd")
const Keywords = preload("res://tools/pol60/keyword_layout.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")

const SIZE := Vector2i(1920, 1080)
const COMPACT_SIZE := Vector2i(1280, 800)
const FIXTURE_SEED: int = 127800
const ITEM_ID: String = "mossglass_elixir"
const GEAR_ID: String = "iron_cleaver"
const EVENT_ID: String = "bloodletters_basin"
const DISCOVERY_IDS := ["enemy:warden", "enemy:harrier"]
const SETTLE_FRAMES: int = 5
const READY_FRAMES: int = 360
const FADE_SECONDS: float = 0.32 # Existing normal-motion map reveal.
const PROOF_FPS: int = 60
const STRIP_INTERVAL: int = 4
const STRIP_COLUMNS: int = 2
const STRIP_TILE := Vector2i(960, 360)
const KEYWORD_POSITION := Vector2(760, 290)
const OUTPUT_ROOT: String = "/private/tmp/labyrinth_codex/pol-60"

var viewport: SubViewport
var scene: Node
var before: bool
var dry_run: bool
var compact: bool
var output: String
var failures: int
var map_strip: Image

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	before = args.has("--before")
	dry_run = args.has("--dry-run")
	compact = args.has("--compact-event")
	output = OUTPUT_ROOT.path_join("before" if before else "after")
	if DisplayServer.get_name() == "headless" and not dry_run:
		push_error("POL60 capture requires a native renderer. Use --dry-run for geometry and output paths.")
		quit(1)
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	Settings.set_storage_path("user://pol60_settings.json")
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://pol60_progression.json")
	Store.set_run_storage_path("user://pol60_run.save")
	var state: Dictionary = Run.new().create_new_run(FIXTURE_SEED, Tutorial.complete_tutorial(Store.default_data()))
	state["equipment_inventory"] = [GEAR_ID]
	state["collected_equipment"] = [GEAR_ID]
	state["item_inventory"] = [ITEM_ID]
	_check(Store.save_run_state(state), "Saved the isolated room fixture")
	root.set_meta("labyrinth_resume_saved_run", true)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	viewport = SubViewport.new()
	viewport.size = COMPACT_SIZE if compact else SIZE
	var expand: float = maxf(float(SIZE.x) / viewport.size.x, float(SIZE.y) / viewport.size.y)
	viewport.size_2d_override = Vector2i((Vector2(viewport.size) * expand).round())
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	Settings.inherit_edge_smoothing(viewport, root)
	_check(preload("res://scripts/cel_look.gd").mode == "all", "Cel look is enabled")
	_check(FileAccess.file_exists("res://cel_look_variants/manifest.json"), "Cel look variants are available")
	scene = load("res://scenes/run_scene.tscn").instantiate()
	if not _check(scene.has_method("initial_presentation_is_ready"), "Loaded the production run scene"):
		quit(1)
		return
	viewport.add_child(scene)
	for frame: int in range(READY_FRAMES):
		if scene.call("initial_presentation_is_ready"): break
		await process_frame
	_check(scene.call("initial_presentation_is_ready"), "Run scene completed initial presentation")
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await _settle()
	if not compact:
		await _pack()
		await _map()
		await _keywords()
	await _event(state)
	scene._character_row_preparation_revision += 1
	scene._grimoire_row_preparation_revision += 1
	await _settle()
	scene.queue_free()
	await _settle()
	viewport.queue_free()
	await process_frame
	print("POL60 %s %s: %d failures" % ["headless" if dry_run else "native", "before" if before else "after", failures])
	quit(int(failures > 0))

func _pack() -> void:
	root.get_node("InputRouter").call("set_forced_state_for_test", "controller", "xbox")
	scene.call("_open_character_overlay", "equipment")
	await _settle()
	var gear: Control = scene._equipment_inventory_tiles.get(GEAR_ID)
	var item: Control = scene._item_inventory_tiles.get(0)
	if not _check(gear != null and item != null, "Pack shows the fixture gear and item"):
		scene.call("_close_card_upgrade_overlay")
		return
	var scroll: ScrollContainer = _scroll_ancestor(gear)
	var skin_style: StyleBoxFlat = UiSkin.new().make_button_style(UiSkin.VARIANT_STANDARD, UiSkin.STATE_FOCUS)
	var outset: float = skin_style.expand_margin_left
	if before and gear.get_node("CharacterTileFeedback").get("uses_row_focus") == true:
		scroll.remove_theme_stylebox_override("panel")
		for edge: String in ["left", "right", "top"]:
			(scroll.get_parent() as MarginContainer).remove_theme_constant_override("margin_" + edge)
		for row: Control in [gear, item]:
			row.get_node("CharacterTileFeedback").set("uses_row_focus", false)
		await _settle()
	for row: Control in [item, gear]:
		row.grab_focus()
		await _settle()
		var actions: Control = row.find_child("CharacterPackActions", true, false)
		var feedback: Control = row.get_node("CharacterTileFeedback")
		var row_rect: Rect2 = row.get_global_rect()
		var frame_rect: Rect2 = feedback.get_global_rect() if before else row_rect.grow(outset)
		var eyebrow: Control = row.find_child("RowText", true, false).get_child(0)
		var equip: Control = actions.get_child(0)
		var inspect: Control = actions.get_child(1)
		var fitting: bool = scroll.get_global_rect().encloses(frame_rect)
		var scenario: String = "pack_item_focus" if row == item else "pack_gear_focus"
		print("POL60 %s row=%s frame=%s clip=%s fits=%s eyebrow=%s equip=%s inspect=%s" % [scenario, row_rect, frame_rect, scroll.get_global_rect(), fitting, eyebrow.get_global_rect(), equip.get_global_rect(), inspect.get_global_rect()])
		_check(row.has_focus() and actions.visible and feedback.visible, scenario + " shows focused row actions and feedback")
		_check(fitting, scenario + " frame fits the scroll viewport")
		if before:
			_check(row_rect.encloses(frame_rect) and row_rect != frame_rect, scenario + " release focus is inset")
		else:
			_check(feedback.get("row_focused") == true and frame_rect.encloses(row_rect) and row_rect != frame_rect, scenario + " focus surrounds the row")
		await _capture(scenario)
	scene.call("_close_card_upgrade_overlay")
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	await _settle()

func _map() -> void:
	scene.call("_close_large_map")
	await _settle()
	var title: Label = scene.room_title
	var scrim: ColorRect = scene._large_map_scrim
	var title_text: String = title.text
	var title_rect: Rect2 = title.get_global_rect()
	var title_color: Color = title.get_theme_color("font_color")
	_check(title.is_visible_in_tree() and not title_text.is_empty() and title.self_modulate.a == 1.0, "Map fixture starts over a visible room title")
	scene.call("_open_large_map")
	await _settle()
	_check(scrim.visible and scrim.get_global_rect().encloses(title_rect), "The full map backdrop covers the room title geometry")
	var fade: Tween
	if scrim.has_method("fade_in") and not before:
		fade = scrim.call("fade_in", FADE_SECONDS)
	else:
		title.self_modulate.a = 1.0
		scrim.modulate.a = 0.0
		fade = scrim.create_tween()
		fade.tween_property(scrim, "modulate:a", 1.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.pause()
	var frames: int = ceili(FADE_SECONDS * PROOF_FPS)
	if not dry_run: map_strip = Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for frame: int in range(frames + 1):
		if frame > 0: fade.custom_step(1.0 / PROOF_FPS)
		if frame % STRIP_INTERVAL != 0: continue
		var map_alpha: float = scrim.modulate.a
		var title_alpha: float = title.self_modulate.a
		var expected: float = 1.0 if before else 1.0 - map_alpha
		_check(is_equal_approx(title_alpha, expected), "Room title opacity follows the expected draw path")
		print("POL60 map frame %02d map=%.4f title=%.4f" % [frame, map_alpha, title_alpha])
		await _capture("map_open_%02d" % frame, frame / STRIP_INTERVAL)
	_save_image("map_open_strip", map_strip)
	_check(is_equal_approx(scrim.modulate.a * scrim.color.a, 1.0), "Fully open map has an opaque backdrop")
	await _capture("map_open")
	scene.call("_close_large_map")
	await _settle()
	_check(not scrim.visible and title.is_visible_in_tree() and title.self_modulate.a == 1.0 and title.text == title_text and title.get_global_rect() == title_rect and title.get_theme_color("font_color") == title_color, "Closing the map restores the title's opacity, text, geometry and colour")
	print("POL60 map closed: %s %s alpha=%.1f" % [title.text, title.get_global_rect(), title.self_modulate.a])
	await _capture("map_closed")
	if scrim.has_method("fade_in") and not before:
		scene.call("_open_large_map")
		var interrupted: Tween = scrim.call("fade_in", FADE_SECONDS)
		interrupted.pause()
		interrupted.custom_step(FADE_SECONDS * 0.5)
		scene.call("_close_large_map")
		_check(not interrupted.is_valid() and not scrim.visible and title.self_modulate.a == 1.0, "Closing during the fade restores the title and stops the tween")

func _keywords() -> void:
	for id: String in Keywords.EXAMPLES:
		var panel: Control = Keywords.panel_for(id, Keywords.RELEASE_WIDTH)
		panel.position = KEYWORD_POSITION
		viewport.add_child(panel)
		await _settle()
		await _capture("keyword_" + id)
		panel.queue_free()
		if not before:
			var preview: Control = Keywords.panel_for(id, Keywords.PREVIEW_WIDTH)
			preview.position = KEYWORD_POSITION
			viewport.add_child(preview)
			await _settle()
			await _capture("preview_%d_%s" % [Keywords.PREVIEW_WIDTH, id])
			preview.queue_free()
		await _settle()

func _event(template: Dictionary) -> void:
	var state: Dictionary = Events.fixture(EVENT_ID, false, template)
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	# Unlock on the same frame that RunScene presents the event, before its first draw.
	var added: Array = scene.call("_unlock_grimoire_entries", DISCOVERY_IDS)
	scene.call("_refresh_ui")
	await _settle()
	var view: Control = scene._event_view
	var log_overlay: Control = scene.log_overlay
	var log_label: RichTextLabel = scene.log_label
	var notice: String = Grimoire.notice_for_added_entries(added)
	var queue: Node = scene.get_node_or_null(Notifications.NODE_NAME)
	var queued: bool = false
	if queue != null:
		for entry: Dictionary in queue.queued:
			queued = queued or str(entry["text"]).contains(notice)
	_check(added.size() == DISCOVERY_IDS.size() and log_label.text.contains(notice) and queued, "Production Grimoire unlock enters the notice queue")
	_check(view != null and view.is_visible_in_tree() and not log_overlay.is_visible_in_tree(), "Open event suppresses the notice")
	view.finish_animation_for_test()
	await _settle()
	var log_rect: Rect2 = _screen_rect(log_overlay)
	var overlaps: PackedStringArray = []
	for button: Button in view.choices:
		if button.is_visible_in_tree() and log_rect.intersects(_screen_rect(button)):
			overlaps.append(button.name)
	print("POL60 event %s %s notice=%s queued=%s visible=%s log=%s panel=%s button-overlap=%s" % [EVENT_ID, viewport.size, notice, queued, log_overlay.is_visible_in_tree(), log_rect, _screen_rect(view.panel), overlaps])
	if not compact: await _capture("event_grimoire_notice")

func _screen_rect(control: Control) -> Rect2:
	return viewport.get_stretch_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _scroll_ancestor(control: Control) -> ScrollContainer:
	var parent: Node = control.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	return parent as ScrollContainer

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame

func _capture(name: String, strip_index: int = -1) -> void:
	if dry_run:
		_save_image(name, null)
		return
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if not _check(image != null and image.get_size() == SIZE and viewport.size_2d_override == SIZE and root.content_scale_factor == 1.0, "Native 1920x1080, 100% UI scale"): return
	if strip_index >= 0:
		image.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(strip_index % STRIP_COLUMNS, strip_index / STRIP_COLUMNS)
		map_strip.blit_rect(image, Rect2i(Vector2i.ZERO, STRIP_TILE), cell * STRIP_TILE)
	_save_image(name, image)

func _save_image(name: String, image: Image) -> void:
	var path: String = output.path_join(name + ".png")
	print("POL60 CAPTURE: " + path)
	if dry_run: return
	if _check(DirAccess.make_dir_recursive_absolute(output) == OK and image.save_png(path) == OK, "Saved " + path):
		print(path)

func _check(condition: bool, context: String) -> bool:
	if not condition:
		failures += 1
		push_error(context)
	return condition
