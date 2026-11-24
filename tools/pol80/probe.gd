extends "res://tools/inspection_fixture.gd"
## Same production routes and exact capture viewport on the candidate and the working tree.

const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const TileTooltips = preload("res://scripts/board_tile_tooltip.gd")
const DeathBurst = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const EnemyFixture = preload("res://tests/suites/en01_enemies_suite.gd")
const Text = preload("res://scripts/inline_icon_text.gd")
const Panels = preload("res://tools/pol80/panels.gd")
const STAGE := Vector2i(1920, 1080)
const FIXTURE_SEED := 919042
const WAIT_SECONDS := 25.0
const WINDOW_MARGIN := Vector2i(64, 96)
const POINTER_REST := Vector2(32, 110)
const KEG_TILE := Vector2i(5, 4)
const KEG_HEALTH := 3
const KEG_DAMAGE := 6
const PROOF_RELIC := "Basalt Kiln"
const PATTERN_DRAW_TIMEOUT := 2.0
const BURST_ARTICLE := "keyword:burst"
const BURST_CARDS := ["discharge", "shatter"]
const BURST_RELICS := ["basalt_calendar", "black_sun_dial", "ashen_brand", "crowncoal_heart"]

var viewport: SubViewport
var scene: Control
var profile: Dictionary
var output: String
var dry: bool
var before: bool
var text_rows: Array[Dictionary]
var panel_rows: Array[Dictionary]
var frames: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_index: int = args.find("--out")
	output = args[out_index + 1] if out_index >= 0 and out_index + 1 < args.size() else ""
	dry = args.has("--dry-run")
	before = args.has("--before")
	if not check(output.is_absolute_path() and dry == (DisplayServer.get_name() == "headless") and preload("res://scripts/cel_look.gd").mode == "all", "Expected absolute output, matching renderer and Cel Look all"): return
	ProgressionStore.set_storage_path(output.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(output.path_join("run.save"))
	Settings.set_storage_path(output.path_join("settings.json"))
	preload("res://scripts/analytics_store.gd").set_storage_dir(output.path_join("analytics"))
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = STAGE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_factor = 1.0
	if dry:
		root.size = STAGE
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		var usable: Vector2i = DisplayServer.screen_get_usable_rect().size - WINDOW_MARGIN
		var fit: float = minf(1.0, minf(float(usable.x) / STAGE.x, float(usable.y) / STAGE.y))
		root.size = Vector2i(Vector2(STAGE) * fit)
	var container := SubViewportContainer.new()
	container.size = Vector2(STAGE)
	root.add_child(container)
	viewport = SubViewport.new()
	viewport.size = STAGE
	viewport.msaa_2d = root.msaa_2d
	viewport.gui_embed_subwindows = true
	container.add_child(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if dry else SubViewport.UPDATE_ALWAYS
	viewport.notify_mouse_entered()
	profile = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids():
		profile = Tutorial.resolve_progression(profile, prompt)
	if not await _burst_surfaces(): return
	if not await Panels.run(self): return
	await close_scene()
	var file := FileAccess.open(output.path_join("observations.json"), FileAccess.WRITE)
	if not check(file != null, "Could not save observations"): return
	file.store_string(JSON.stringify({"text": text_rows, "panels": panel_rows, "frames": frames}, "\t") + "\n")
	print("POL-80 %s %s PASS (%d Burst routes, %d panel samples, %d frames)" % [
		"before" if before else "after", "headless" if dry else "native",
		text_rows.size(), panel_rows.size(), frames.size()])
	quit()

func _burst_surfaces() -> bool:
	for id: String in BURST_CARDS:
		var state: Dictionary = run_fixture("combat", {"hand": id, "attuned_magic": id})
		state["relics"] = BURST_RELICS.duplicate()
		if not await resume(Grimoire.unlock_entries(state, [BURST_ARTICLE])["state"]): return false
		var card: CardWidget = scene._hand_card_control(0)
		if not check(card != null and card.card_id == id, "Expected " + id + " in the production hand"): return false
		scene._on_card_hover_started(0)
		await settle()
		var stack: Control = scene._card_focus_tooltip_stack
		if not check(stack.is_visible_in_tree() and stack._follow_target == card, "Expected live hover stack for " + id): return false
		if not await _stack_burst("hover_" + id, stack): return false
		if not await capture("hover_" + id): return false
	scene._on_card_hover_ended(0)
	for badge: Control in scene._relic_icon_grid.get_children():
		if not badge.has_meta("glossary_relic"): continue
		var relic: Dictionary = badge.get_meta("glossary_relic")
		if not BURST_RELICS.any(func(id: String) -> bool: return GameData.relic_def(id).get("name") == relic.get("name")): continue
		badge.mouse_entered.emit()
		await settle()
		if not await _stack_burst("relic_" + str(relic["name"]).to_snake_case().replace(" ", "_"), scene._card_focus_tooltip_stack): return false
		if relic["name"] == PROOF_RELIC and not await capture("relic_burst"): return false
		badge.mouse_exited.emit()
	scene._on_grimoire_button_pressed()
	scene._on_grimoire_entry_pressed(BURST_ARTICLE)
	await settle()
	var grimoire: Control = scene._grimoire_scrim
	var article: String = grimoire._grimoire_body_text(Grimoire.entry_def(BURST_ARTICLE))
	if not check(grimoire._grimoire_detail_body.is_visible_in_tree(), "Expected the live Grimoire Burst page"): return false
	if not await record_text("grimoire_burst", article, article, grimoire._grimoire_detail_body): return false
	if not await capture("grimoire_burst"): return false
	scene._close_grimoire_overlay()
	await settle()

	var battle: Dictionary = EnemyFixture.fixture(["ember_tick"])
	battle["terrain"] = [{"kind": "powder_keg", "pos": KEG_TILE, "hp": KEG_HEALTH, "max_hp": KEG_HEALTH, "burst_damage": KEG_DAMAGE}]
	var combat: Dictionary = new_run()
	combat["mode"] = "combat"
	combat["combat_state"] = battle
	combat["current_room_layout"] = {"grid": battle["grid"]}
	scene._load_run_state(combat)
	scene._close_dialogue()
	await settle()
	var board: Control = scene.board_view
	var enemy: Dictionary = scene._combat_state["enemies"][0]
	var key: String = "enemy_%d" % int(enemy["id"])
	board._update_hover_at(board.world_position_for_tile(enemy["pos"]))
	scene._on_enemy_intent_toggle_toggled(true)
	await settle()
	var trait_token: Dictionary = DeathBurst.trait_token(enemy)
	var intent: String = board.enemy_intent_tooltip(key)
	var detail: String = str(trait_token.get("display_tooltip", ""))
	if not check(not detail.is_empty() and intent.contains(detail), "Expected Burst in Ember Tick Details"): return false
	var enemy_panel: Control = board._make_custom_tooltip("Burst\n" + intent)
	viewport.add_child(enemy_panel)
	await settle()
	if not await record_text("ember_tick_details", str(trait_token["tooltip"]), detail, _rich_pattern(enemy_panel)): return false
	enemy_panel.free()
	# The board's passive mouse hover and focused tile inspection use the same builder.
	var keg_tooltip: String = board._get_tooltip(board.world_position_for_tile(KEG_TILE))
	var entries: Array[Dictionary] = TileTooltips.decode(keg_tooltip)
	if not check(not entries.is_empty() and entries[0]["title"] == "Powder Keg", "Expected a live keg terrain tooltip"): return false
	var keg: Dictionary = entries[0]
	var tile_panel: Control = board._make_custom_tooltip(keg_tooltip)
	viewport.add_child(tile_panel)
	await settle()
	if not await record_text("powder_keg_terrain", str(keg["description"]), str(keg["display_description"]), _rich_pattern(tile_panel)): return false
	tile_panel.free()
	return true

func _stack_burst(id: String, stack: Control) -> bool:
	for entry: Dictionary in stack._entries:
		if entry.get("icon") != "burst": continue
		var key: String = str(entry.get("semantic_key", ""))
		var panels: Array = stack._panel_host.get_children() if is_instance_valid(stack._panel_host) else stack.get_children()
		for panel: Control in panels:
			if panel.get_meta("semantic_key", "") != key: continue
			var raw: String = entry["description"]
			return await record_text(id, raw, str(entry.get("display_description", raw)), _rich_pattern(panel), panel)
	return check(false, "Did not find the Burst entry for " + id)

func _rich_pattern(host: Node) -> RichTextLabel:
	for child: Node in host.find_children("*", "RichTextLabel", true, false):
		if int(child.get_meta("inline_pattern_count", 0)) > 0: return child as RichTextLabel
	return null

func record_text(id: String, raw: String, markup: String, label: RichTextLabel, panel: Control = null) -> bool:
	var expanded: String = Text.Patterns.display_rules(markup)
	var tokens: Array[RegExMatch] = Text.Patterns.matches(expanded)
	var row: Dictionary = {"id": id, "raw": raw, "markup": expanded, "plain": Text.plain_text(expanded), "images": []}
	if panel != null: row["panel_rect"] = str(panel.get_global_rect())
	if before and tokens.is_empty() and id == "relic_crowncoal_heart":
		text_rows.append(row)
		print("POL-80 BURST " + JSON.stringify(row))
		return true
	if not check(not tokens.is_empty() and label != null and label.get_meta("inline_pattern_count", 0) == tokens.size(), "Expected the cross image in " + id): return false
	row["rendered_label"] = label.get_parsed_text()
	row["label_rect"] = str(label.get_global_rect())
	for token: RegExMatch in tokens:
		var texture: Texture2D = Text.Patterns.texture(token, float(label.get_meta("inline_icon_size")))
		var image_row: Dictionary = {"token": token.get_string(), "size": str(texture.get_size()), "class": texture.get_class()}
		if not dry:
			var painted := Rect2i()
			var deadline: int = Time.get_ticks_msec() + roundi(PATTERN_DRAW_TIMEOUT * 1000.0)
			while true:
				await RenderingServer.frame_post_draw
				var image: Image = texture.get_image()
				painted = image.get_used_rect() if image != null and not image.is_empty() else Rect2i()
				if painted.has_area() or Time.get_ticks_msec() >= deadline: break
			image_row["painted"] = str(painted)
			if not before and not check(painted.has_area(), "Expected painted pattern pixels in " + id): return false
		row["images"].append(image_row)
	text_rows.append(row)
	print("POL-80 BURST " + JSON.stringify(row))
	return true

func check(condition: bool, why: String) -> bool:
	if not condition: _fail("POL-80: " + why)
	return condition

func new_run() -> Dictionary:
	return _run_engine.create_new_run(FIXTURE_SEED, profile)

func run_fixture(scenario: String, options: Dictionary = {}) -> Dictionary:
	_options = {"seed": FIXTURE_SEED}
	_options.merge(options, true)
	return _build_run_state(scenario, profile)

func resume(state: Dictionary) -> bool:
	await close_scene()
	ProgressionStore.clear_saved_run()
	if not check(not state.is_empty() and ProgressionStore.save_data(state["progression"]) and ProgressionStore.save_run_state(state), "Could not save resume fixture"): return false
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	if before:
		var painter: Control = scene.board_view._effects_render_layer
		painter.draw.connect(func() -> void: painter.set_meta("pol80_painted_title", painter.status_text_local_bounds()))
	var motion := InputEventMouseMotion.new()
	motion.position = POINTER_REST
	motion.global_position = POINTER_REST
	viewport.push_input(motion, true)
	if not check(await wait_for(scene.initial_presentation_is_ready), "RunScene did not finish its initial presentation"): return false
	if scene._dialogue_active: scene._close_dialogue()
	await settle()
	return check(viewport.size == STAGE and is_equal_approx(Typography.ui_scale(scene), 1.0), "Expected exact 1920x1080 at 100%")

func close_scene() -> void:
	if not is_instance_valid(scene): return
	scene.queue_free()
	await process_frame
	await process_frame
	scene = null

func wait_for(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + roundi(WAIT_SECONDS * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() >= deadline: return false
		await process_frame
	return true

func settle(seconds: float = 0.0) -> void:
	if seconds > 0.0: await create_timer(seconds, true, false, true).timeout
	await process_frame
	await process_frame

func capture(id: String) -> bool:
	frames.append(id)
	if dry: return true
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var path: String = output.path_join(id + ".png")
	if not check(image != null and image.get_size() == STAGE and image.save_png(path) == OK, "Could not save " + path): return false
	print(path)
	return true

func press_text(host: Control, words: String) -> bool:
	for button: Button in host.find_children("*", "Button", true, false):
		if button.text == words and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			return true
	return check(false, "Missing enabled button " + words)

func shown(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree()
