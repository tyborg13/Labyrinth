extends SceneTree
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Asset = preload("res://scripts/asset_loader.gd")
const OUTPUT: String = "user://probes/dragon_rewards"
var scene: Node
var canvas: SubViewport
var failed: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Store.set_storage_path("user://dragon_reward_probe_profile.json")
	Store.set_run_storage_path("user://dragon_reward_probe_run.save")
	Settings.set_storage_path("user://dragon_reward_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var engine := Run.new()
	var combat := Combat.new()
	for id: String in Bosses.BOSS_RELICS:
		var options := {"dragon_id":id, "dragon_depth":24 if id == "noctyrax" else 4, "dragon_case":"reward"}
		var state: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), Store.default_data()), options)
		state["pending_reward"]["intro_pending"] = false
		await _load(state)
		await _capture("reward_%s" % id)
		var panel: Control = scene.find_child("DragonMilestoneReward", true, false)
		var rules: RichTextLabel = scene.find_child("DragonRewardRules", true, false)
		expect(panel != null and panel.is_visible_in_tree(), "Milestone panel exists for %s" % id)
		if panel != null: expect(Rect2(Vector2.ZERO, Vector2(1920,1080)).encloses(panel.get_global_rect()), "Milestone stays within viewport")
		if rules != null: expect(rules.get_content_height() <= rules.size.y + 1, "Relic rules are not clipped")
		var button: Button = scene.find_child("DragonRewardContinue", true, false)
		expect(button != null and button.is_visible_in_tree(), "Continue is visible")
		if button != null:
			button.pressed.emit()
			while bool(scene.get("_relic_claim_in_progress")): await process_frame
			expect(str((scene.get("_run_state") as Dictionary).get("mode", "")) == ("victory" if id == "noctyrax" else "room"), "Continue reaches intended destination")
	var profile: Dictionary = Store.default_data()
	profile["moltshards"] = 2
	profile[Store.EMACIATED_AWAKENING_SEEN_KEY] = true
	profile["embers"] = 100
	profile["run_counter"] = 9
	profile["contextual_combat_tutorial"] = {"completed":true, "dismissed":true}
	var entrance: Dictionary = engine.create_new_run(2926, profile)
	Store.save_data(profile)
	Store.save_run_state(entrance)
	scene.set("_progression", profile)
	await _load(entrance)
	scene.call("_show_emaciated_services")
	await _capture("entrance_trade_funded")
	scene.call("_exchange_moltshard_at_entrance")
	await process_frame
	expect(int((scene.get("_progression") as Dictionary)["moltshards"]) == 1 and engine.held_embers(scene.get("_run_state")) == 350, "Trade credits live entrance wallet")
	await _capture("entrance_trade_complete")
	scene.call("_close_dialogue")
	scene.call("_open_level_up_overlay", "emaciated_man")
	await _capture("entrance_level_up")
	expect(int((scene.get("_progression") as Dictionary)["level"]) == 2 and engine.held_embers(scene.get("_run_state")) == 170, "Entrance level spends cost and leaves service available")
	scene.call("_on_progression_overlay_close_pressed")
	await process_frame
	expect(bool(scene.get("_dialogue_active")), "Closing Skills returns to the service")
	scene.call("_close_dialogue")
	scene.call("_refresh_ui")
	await process_frame
	await process_frame
	scene.call("_close_large_map")
	await _capture("entrance_service_reopen")
	expect(not (scene.get("_large_map_scrim") as Control).visible, "Reopen proof shows the entrance after closing its map")
	var service_choices: Control = scene.get("_context_choice_bar")
	expect(service_choices.is_visible_in_tree() and service_choices.get_child_count() == 2, "Entrance separates Speak from Awaken Power")
	var npc_tile: Vector2i = scene.call("_emaciated_service_tile")
	var npc_candidate: Dictionary = scene.call("_controller_candidate_for_tile", npc_tile)
	expect(str(npc_candidate.get("kind", "")) == "npc" and (scene.call("_controller_board_tiles") as Array).has(npc_tile), "Controller can navigate to the entrance service NPC")
	scene.set("_controller_focus_candidate", npc_candidate)
	scene.call("_controller_activate_current")
	await process_frame
	expect(bool(scene.get("_dialogue_active")), "Controller activation speaks to the NPC")
	scene.call("_close_dialogue")
	# Fresh live-HUD proofs for the two layering fixes.
	for id: String in ["zekarion", "noctyrax"]:
		var options := {"dragon_id":id, "dragon_depth":24 if id == "noctyrax" else 4}
		var state: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), Store.default_data()), options)
		if id == "zekarion":
			for _phase: int in range(3): state["combat_state"] = combat.resolve_enemy_turn_with_steps(state["combat_state"],0)["state"]
		await _load(state)
		scene.call("_set_show_all_enemy_intents", true)
		await _capture("hud_%s" % id)
		var board: Control = scene.get("board_view")
		var boss_rect: Rect2 = (scene.get("_boss_health_overlay") as Control).get_global_rect()
		for entry: Dictionary in board.get("_hud_layout_entries_cache"):
			var layout: Dictionary = entry.get("layout", {}) as Dictionary
			for rect: Rect2 in layout.get("line_rects", []):
				var global_rect: Rect2 = board.get_global_transform_with_canvas() * rect
				expect(not boss_rect.intersects(global_rect), "Expanded enemy intent clears the boss health bar")
				expect(global_rect.end.y < float(scene.call("_hand_visual_top")), "Expanded enemy intent clears the card hand")
	await _grimoire_rules(engine)
	await _contact_sheet()
	print("DRAGON REWARD PROOF: ", "PASS" if failed == 0 else "FAIL")
	canvas.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _load(state: Dictionary) -> void:
	Store.save_data(state["progression"])
	Store.save_run_state(state)
	scene.set("_progression", state["progression"])
	scene.call("_load_run_state", state)
	await process_frame
	await process_frame
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(0.25).timeout

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	expect(image.get_size() == Vector2i(1920,1080), "Native proof size")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = "%s/%s.png" % [OUTPUT, label]
	expect(image.save_png(path) == OK, "PNG saved")
	print(ProjectSettings.globalize_path(path))

func _grimoire_rules(engine: RefCounted) -> void:
	var grimoire = preload("res://scripts/grimoire_library.gd")
	var entries: Array[String] = ["combat:hollow_gale", "enemy:vaeloryx", "combat:boss_eclipse"]
	var state: Dictionary = engine.create_new_run(2926, Store.default_data())
	state[grimoire.UNLOCKED_KEY] = entries.duplicate()
	state[grimoire.UNREAD_KEY] = []
	state["progression"][grimoire.UNLOCKED_KEY] = entries.duplicate()
	state["progression"][grimoire.UNREAD_KEY] = []
	await _load(state)
	scene.call("_close_large_map")
	scene.call("_open_grimoire_overlay")
	for entry_id: String in entries:
		scene.call("_on_grimoire_entry_pressed", entry_id)
		await process_frame
		await process_frame
		var title: Label = scene.get("_grimoire_detail_title")
		var body: RichTextLabel = scene.get("_grimoire_detail_body")
		expect(title.text == str(grimoire.entry_def(entry_id)["title"]), "Requested dragon rules page is displayed")
		expect(body.is_visible_in_tree() and body.get_content_height() <= body.size.y + 1, "Dragon rules text is visible without clipping")
		await _capture("grimoire_%s" % entry_id.replace(":", "_"))
	scene.call("_close_grimoire_overlay")

func _contact_sheet() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color("211c27")
	overlay.size = Vector2(1920,1080)
	var layer := CanvasLayer.new()
	layer.layer = 100
	canvas.add_child(layer)
	layer.add_child(overlay)
	var index: int = 0
	for id: String in Bosses.BOSS_RELICS:
		var relic: Dictionary = Data.relic_def(Bosses.relic_for_boss(id))
		var column: int = index % 3
		var row: int = index / 3
		var pos := Vector2(260 + 600 * column, 220 + 400 * row)
		for pixels: int in [96, 32]:
			var icon := TextureRect.new()
			icon.texture = Asset.load_texture(relic["icon_path"])
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size = Vector2(pixels,pixels)
			icon.position = pos + Vector2(150 if pixels == 32 else 0,0)
			overlay.add_child(icon)
		var label := Label.new()
		label.text = "%s\n96 px / 32 px" % relic["name"]
		label.position = pos + Vector2(-25,120)
		label.add_theme_font_size_override("font_size", 26)
		overlay.add_child(label)
		index += 1
	await _capture("relic_contact_sheet")

func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
