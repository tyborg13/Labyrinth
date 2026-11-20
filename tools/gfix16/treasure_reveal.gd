extends SceneTree
## Exercise the production treasure reveal from the last Scavenger stop.

const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const Glossary = preload("res://scripts/glossary.gd")
const DESKTOP := Vector2i(1920, 1080)
const DECK := Vector2i(1280, 800)
const STUDY := Vector2i(1920, 1920)
const DESKTOP_UI_SCALE: float = 1.0
const DECK_UI_SCALE: float = 1.15
const SEED: int = 101009
const SCAVENGER := Vector2i(6, -3)
const TREASURE := Vector2i(6, 2)
const SECTION: int = 1
const RELIC: String = "siege_ram_totem"
# Owned relics and offer order from the qa-115 decision-645 checkpoint.
const OWNED_RELICS := ["widow_thread", "waxen_effigy", "winters_hour"]
const EXPECTED_OFFERS := [RELIC, "sunlit_edge", "millstone_fob"]
const TURNS_BEFORE_TRAVEL: int = 16
const DEADLINE_MSEC: int = 20000
const SETTLE_FRAMES: int = 4
const CAPTURE_DIR: String = "user://gfix16-treasure"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var headless: bool = DisplayServer.get_name() == "headless"
	if headless and not args.has("--logic-only"):
		_fail("Native capture requires a renderer")
		return
	var deck: bool = args.has("--deck")
	var physical: Vector2i = DECK if deck else DESKTOP
	if args.has("--study"): physical = STUDY
	var ui_scale: float = DECK_UI_SCALE if deck else DESKTOP_UI_SCALE
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = ui_scale
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)

	# Mirror the main Window's expand aspect policy in a fixed capture target.
	var expand: float = maxf(float(DESKTOP.x) / physical.x, float(DESKTOP.y) / physical.y)
	var viewport := SubViewport.new()
	viewport.size = physical
	viewport.size_2d_override = Vector2i((Vector2(physical) * expand / ui_scale).round())
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	Settings.inherit_edge_smoothing(viewport, root)

	var engine := Run.new()
	var progression: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(Store.default_data())
	var state: Dictionary = engine.create_new_run(SEED, progression)
	var origin: Dictionary = engine.room_metadata(state, SCAVENGER)
	var target: Dictionary = engine.room_metadata(state, TREASURE)
	if origin.get("type") != "scavenger" or target.get("type") != "treasure" or target.get("section_index") != SECTION:
		_fail("Seed no longer generates the QA route")
		return
	origin["visited"] = true
	origin["cleared"] = true
	state["rooms"]["6,-3"] = origin
	state["current_room"] = SCAVENGER
	state["current_room_layout"] = engine.call("_display_layout_for_room", SEED, origin, Vector2i.RIGHT)
	state["relics"] = OWNED_RELICS.duplicate()
	state["turns_spent"] = TURNS_BEFORE_TRAVEL
	if not Store.save_run_state(state):
		_fail("Could not save the Scavenger fixture")
		return
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	var deadline: int = Time.get_ticks_msec() + DEADLINE_MSEC
	while not scene.initial_presentation_is_ready() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not scene.initial_presentation_is_ready():
		_fail("Scavenger scene did not finish loading")
		return
	scene.call("_close_dialogue")
	scene.set("_treasure_reveal_navigation", true)
	await scene.call("_on_large_map_room_selected", TREASURE)
	var offers: Array = scene._run_state.get("pending_relics", [])
	if offers != EXPECTED_OFFERS:
		_fail("Unexpected treasure offers: " + str(offers))
		return

	var stack: Control = scene.get("_card_focus_tooltip_stack")
	var choice: Control
	while Time.get_ticks_msec() < deadline:
		choice = scene.find_child("RelicChoice_" + RELIC, true, false) as Control
		if choice != null and stack.visible and stack._follow_target == choice: break
		await process_frame
	if choice == null or not stack.visible or stack._follow_target != choice:
		_fail("Reveal did not focus the Siege Ram Totem glossary")
		return
	var ok: bool = _fits(scene, stack, choice, physical, "first_focus")
	if not headless:
		ok = await _capture(viewport, physical, "first_focus") and ok
	for frame: int in range(SETTLE_FRAMES): await process_frame
	ok = _fits(scene, stack, choice, physical, "settled") and ok
	if not headless:
		ok = await _capture(viewport, physical, "settled") and ok
	print("GFIX16 TREASURE REVEAL %dx%d @ %d%%: %s" % [physical.x, physical.y, roundi(ui_scale * 100.0), "PASS" if ok else "FAIL"])
	viewport.queue_free()
	await process_frame
	Shutdown.request(self, "gfix16_treasure_probe", 0 if ok else 1)

func _fits(scene: Node, stack: Control, owner: Control, physical: Vector2i, phase: String) -> bool:
	var visible_rect: Rect2 = stack.get_viewport().get_visible_rect()
	var bounds: Rect2 = stack.get_global_rect()
	var owner_rect: Rect2 = Stack._visual_global_rect(owner)
	var bar: Control = scene.get("top_bar")
	var banner: Control = scene.get("_relic_choice_banner")
	var row: Control = scene.get("_relic_choice_bar")
	print("GFIX16 TREASURE %dx%d %s: viewport=%s stack=%s owner=%s above=%s overflow=%s" % [
		physical.x, physical.y, phase, visible_rect, bounds, owner_rect,
		stack.get_meta("glossary_choice_above", false), stack.get_meta("glossary_choice_overflow", false)])
	var panels: Array[Node] = stack.find_children("CardFocusTooltip_*", "PanelContainer", true, false)
	var description: String = owner.get_meta("glossary_relic")["description"]
	var expected_icons: Array[String]
	for id: String in Glossary.ids_in_text(description, Glossary.MAX_RELIC_PANELS):
		expected_icons.append(str(Glossary.lookup(id)["icon"]))
	if stack.entry_icon_keys() != expected_icons or panels.is_empty() or not visible_rect.encloses(bounds): return false
	for panel: Node in panels:
		var rect: Rect2 = (panel as Control).get_global_rect()
		if not visible_rect.encloses(rect) or rect.intersects(owner_rect): return false
		if rect.intersects(Stack._visual_global_rect(bar)) or rect.intersects(Stack._visual_global_rect(banner)): return false
		for sibling: Node in row.get_children():
			if sibling != owner and sibling is Control and sibling.has_meta("glossary_relic"):
				if rect.intersects(Stack._visual_global_rect(sibling)): return false
	return true

func _capture(viewport: SubViewport, physical: Vector2i, phase: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.get_size() != physical: return false
	var name: String = "treasure_%s_%dx%d.png" % [phase, physical.x, physical.y]
	var path: String = ProjectSettings.globalize_path(CAPTURE_DIR.path_join(name))
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK or image.save_png(path) != OK: return false
	print(path)
	return true

func _fail(message: String) -> void:
	push_error("GFIX16 TREASURE: " + message)
	Shutdown.request(self, "gfix16_treasure_probe", 1)
