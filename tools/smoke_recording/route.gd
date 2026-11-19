extends SceneTree
## Capture-only driver. Scene state is observed, and recorded actions enter through input events.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Demo = preload("res://scripts/demo_build.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Timing = preload("res://tools/smoke_recording/timing.gd")
const RouteInput = preload("res://tools/smoke_recording/route_input.gd")

const SIZE := Vector2i(1920, 1080)
const FPS: int = 30
const CHAPTER_PROGRESS: String = "chapter-progress.txt"
const FIXTURE_SEED: int = 1
const ACTION_TIMEOUT_FRAMES: int = 3600
const STARTUP_TIMEOUT_FRAMES: int = 10800
const LAYOUT_FRAMES: int = 6
const OPENING_FIGHT := Vector2i(1, 1)
const FIRST_EVENT := Vector2i(-1, -1)
const CRAGHIDE := Vector2i(2, 2)
const TO_THAROKH: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(-2, 2), Vector2i(-2, -1), Vector2i(3, -1),
	Vector2i(3, 3), Vector2i(-1, 3), Vector2i(4, 0),
]
const CHOREOGRAPHY_WATCHDOG_SECONDS: float = 300.0
const POINTER_AWAY := Vector2(960, 96)
const CHAPTERS := ["Main menu and map", "Normal fight", "Rewards and event", "Craghide and Tharokh", "Return to menu"]
# The brief specifies short reading holds and an overall duration range, with
# individual dwell times left open for the director.
const TODO_DESIGN_READING_HOLD_SECONDS: float = -1.0
const UI_SCALE: float = 1.0

var driver: RefCounted
var combat: RefCounted
var scene: Node
var output: String
var dry_run: bool
var failed: bool = false
var chapters: Array[Dictionary]
var witnesses: Array[String]
var timing: RefCounted
var upheaval_seen: bool = false
var stills_saved: Dictionary = {}
var finishing: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Runtime.apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--dry-run": dry_run = true
	if not require(not output.is_empty() and DirAccess.dir_exists_absolute(output), "Existing output directory required"): return
	if not require(Demo.is_demo() and Cel.mode == "all" and not Cel._files.is_empty(), "Demo and installed cel look required"): return
	if not require(dry_run == (DisplayServer.get_name() == "headless"), "Dry run requires headless, capture requires native renderer"): return
	if not dry_run and not require(not Engine.get_write_movie_path().is_empty(), "Movie Maker required"): return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.set_meta("labyrinth_performance_probe_seed", FIXTURE_SEED)
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = UI_SCALE
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	if not require(Settings.save_settings(settings), "Write capture settings to isolated profile"): return
	# A returning player has completed the guided fight. This leaves the new
	# descent's starter kit, progression level, Health and encounter rolls intact.
	if not require(Store.save_data(Tutorial.complete_tutorial(Store.default_data())), "Write returning-player tutorial receipt"): return
	driver = RouteInput.new(self, not dry_run)
	root.notify_mouse_entered()
	if dry_run: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	create_timer(CHOREOGRAPHY_WATCHDOG_SECONDS).timeout.connect(func() -> void: require(false, "Route watchdog expired"))
	timing = Timing.new(self, output)
	if not require(change_scene_to_file("res://scenes/main_menu.tscn") == OK, "Load production main menu"): return
	await frames(LAYOUT_FRAMES)
	chapter(0)
	await hold()
	await click_named(current_scene, "StartButton")
	if failed: return
	if not await until(func() -> bool: return is_instance_valid(current_scene) and current_scene.name == "RunScene", "Enter real run", STARTUP_TIMEOUT_FRAMES): return
	scene = current_scene
	if not require(run_state().get("seed") == FIXTURE_SEED and run_state().get("build_kind") == "demo", "Seeded demo New Run"): return
	await frames(LAYOUT_FRAMES)
	await settle_narration()
	var map := await open_map()
	if map == null: return
	var destinations: Array = map.call("available_destinations")
	if not require(destinations.size() >= 2 and destinations.has(OPENING_FIGHT), "Two opening map nodes and the routed fight"): return
	for coord: Vector2i in [destinations[0], destinations[1]]:
		var node: Control = map.get("node_buttons").get(coord)
		if not require(driver.usable(node), "Visible map node %s" % str(coord)): return
		driver.motion(driver.point(node))
		await hold()
		if not require(map.get("selected_coord") == coord and is_instance_valid(map.get("_preview")), "Map hover preview for %s" % str(coord)): return
		witness("map_hover %s" % str(coord))
	await still(0)
	chapter(1)
	await enter_room(OPENING_FIGHT)
	if failed: return
	await begin_battle()
	if failed: return
	combat = load("res://tools/smoke_recording/route_combat.gd").new(self)
	await combat.opening()
	if failed: return
	await combat.finish_fight()
	if failed: return
	if not require(mode() == "reward", "Ordinary combat reached its reward (mode=%s)" % mode()): return
	chapter(2)
	await claim_reward(true)
	if failed: return
	await enter_room(FIRST_EVENT)
	if failed: return
	await resolve_event(true)
	if failed: return
	chapter(3)
	await enter_room(CRAGHIDE)
	if failed: return
	await begin_battle()
	if failed: return
	if not require(enemy_present("craghide") and battle().get("battlefield_rule", {}).get("rule") == "upheaval", "Craghide with live Upheaval"): return
	process_frame.connect(observe_upheaval)
	await combat.finish_fight()
	process_frame.disconnect(observe_upheaval)
	if failed: return
	if not require(upheaval_seen, "Craghide reached a production Upheaval playback beat"): return
	await resolve_surface()
	if failed: return
	for destination: Vector2i in TO_THAROKH:
		await enter_room(destination)
		if failed: return
		if destination == TO_THAROKH.back(): break
		await resolve_surface()
		if failed: return
	await begin_battle()
	if failed: return
	if not require(enemy_present("tharokh"), "Live Tharokh fight"): return
	var first_turn: int = int(battle()["turn"])
	await hold()
	for step: int in range(1, 3):
		await combat.finish_fight(first_turn + step)
		if not require(mode() == "combat" and combat_ready() and int(battle()["turn"]) >= first_turn + step, "Tharokh opening turn %d completed" % step): return
		witness("tharokh_opening_turn %d hp=%d" % [step, int(battle()["player"]["hp"])])
		await hold()
	chapter(4)
	await click_named(scene, "MenuButton")
	if failed: return
	var menu: Control = scene.get("_menu_dialog")
	var save_quit := func() -> Button:
		if not driver.usable(menu): return null
		for button: Button in menu.find_children("*", "Button", true, false):
			if button.text == "Save and Quit" and driver.usable(button): return button
		return null
	if not await until(func() -> bool: return save_quit.call() != null, "Save and Quit in the game menu"): return
	await driver.click(driver.point(save_quit.call()))
	if not await until(func() -> bool: return is_instance_valid(current_scene) and current_scene.name == "MainMenu", "Return to main menu"): return
	witness("returned_to_menu")
	await hold()
	await still(4)
	await frames(LAYOUT_FRAMES)
	if not require(dry_run or stills_saved.size() == CHAPTERS.size(), "Every chapter has a native still"): return
	finish()

func frames(count: int) -> void:
	for _frame: int in range(count):
		await process_frame

func hold() -> void:
	# When a per-beat duration is absent, use the game's standard dialogue rate
	# for a short card line. The dry run only waits for interaction readiness.
	var seconds: float = TODO_DESIGN_READING_HOLD_SECONDS
	if seconds < 0.0: seconds = 60.0 / Settings.STANDARD_DIALOGUE_CHARACTERS_PER_SECOND
	await frames(roundi(seconds * FPS) if not dry_run else LAYOUT_FRAMES)

func beat() -> void:
	await frames(roundi(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)) * FPS) if not dry_run else LAYOUT_FRAMES)

func until(predicate: Callable, detail: String, budget: int = ACTION_TIMEOUT_FRAMES) -> bool:
	for _frame: int in range(budget):
		if failed: return false
		if predicate.call(): return true
		await process_frame
	var phase: Variant = current_scene.get("phase") if current_scene != null else null
	return require(false, detail + " timed out in " + str(current_scene) + " phase=" + str(phase))

func require(condition: bool, detail: String) -> bool:
	if not condition and not failed:
		failed = true
		push_error("CAP09 ROUTE: " + detail)
		finish()
	return condition

func chapter(index: int) -> void:
	chapters.append({"title": CHAPTERS[index], "frame": 0 if index == 0 else frame_count()})
	var status: String = "CHAPTER %d %s" % [index + 1, CHAPTERS[index]]
	print("CAP09 " + status)
	if not dry_run:
		var file := FileAccess.open(output.path_join(CHAPTER_PROGRESS), FileAccess.WRITE)
		if file != null:
			file.store_line(status)
			file.close()

func witness(detail: String) -> void:
	witnesses.append(detail)
	print("CAP09 WITNESS ", detail)

func frame_count() -> int:
	return Engine.get_process_frames() if dry_run else Engine.get_frames_drawn()

func still(index: int) -> void:
	if dry_run: return
	await RenderingServer.frame_post_draw
	var path: String = output.path_join("chapter-%d.png" % (index + 1))
	if require(root.get_texture().get_image().save_png(path) == OK, "Save renderer still"):
		stills_saved[index] = path
		print(path)

func finish() -> void:
	if finishing: return
	finishing = true
	if timing != null and not timing.finish(output):
		failed = true
		push_error("CAP09 ROUTE: could not write frame cohort receipt")
	var file := FileAccess.open(output.path_join("route.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"dry_run": dry_run, "failed": failed, "chapters": chapters, "witnesses": witnesses,
			"seed": FIXTURE_SEED, "fps": FPS, "end_frame": frame_count(),
			"ui_scale": root.content_scale_factor, "resolution": [root.size.x, root.size.y],
		}, "\t"))
		file.close()
	elif not failed:
		failed = true
		push_error("CAP09 ROUTE: could not write route.json")
	print("CAP09 ROUTE: %s (%d chapters, %d witnesses)" % ["FAIL" if failed else "PASS", chapters.size(), witnesses.size()])
	combat = null
	preload("res://scripts/presentation_clock.gd").release_shutdown_callables()
	quit(1 if failed else 0)

func run_state() -> Dictionary:
	return scene.get("_run_state")

func battle() -> Dictionary:
	return scene.get("_combat_state")

func hand() -> Array:
	return battle().get("deck", {}).get("hand", [])

func mode() -> String:
	return str(run_state().get("mode", ""))

func click_named(parent: Node, node_name: String) -> void:
	var target: Control = parent.find_child(node_name, true, false) as Control
	if require(driver.usable(target), "Input target " + node_name):
		await driver.click(driver.point(target))

func settle_narration() -> void:
	while not failed and bool(scene.get("_dialogue_active")):
		var overlay: Control = scene.get("_dialogue_overlay")
		var choices: Control = scene.get("_dialogue_choice_bar")
		if bool(scene.get("_dialogue_text_complete")) and choices != null and choices.is_visible_in_tree() and choices.get_child_count() > 0:
			var button: Control = choices.get_child(0) as Control
			if not require(driver.usable(button), "Dialogue continuation button"): return
			await driver.click(driver.point(button))
		else:
			await driver.click(overlay.get_global_transform_with_canvas() * Vector2(16, 16))
		await frames(LAYOUT_FRAMES)

func open_map() -> Control:
	var scrim: Control = scene.get("_large_map_scrim")
	if not scrim.visible:
		var button: Control = scene.get("_section_map_hud_button")
		if not require(driver.usable(button), "Visible map button in %s" % mode()): return null
		await driver.click(driver.point(button))
	if not await until(func() -> bool: return scrim.visible, "Map opened"): return null
	await frames(LAYOUT_FRAMES)
	return scene.get("_large_map_view")

func enter_room(destination: Vector2i) -> void:
	if run_state().get("current_room") == destination: return
	var map := await open_map()
	if map == null: return
	var node: Control = map.get("node_buttons").get(destination)
	if not require(driver.usable(node) and bool(map.call("can_activate_room", destination)), "Available route node %s from %s" % [str(destination), str(run_state().get("current_room"))]): return
	var destinations: Array[Vector2i] = [destination]
	var rects: Dictionary = map.call("selectable_room_global_rects", destinations)
	if not require(rects.has(destination), "On-screen route node %s" % str(destination)): return
	await driver.click((rects[destination] as Rect2).get_center())
	await until(func() -> bool: return run_state().get("current_room") == destination, "Travel to %s" % str(destination))
	await frames(LAYOUT_FRAMES)

func begin_battle() -> void:
	if not await until(func() -> bool: return mode() == "pre_battle" and scene.get("_pre_battle_scrim").visible, "Pre-battle panel"): return
	await frames(LAYOUT_FRAMES)
	await click_named(scene, "PreBattleStartButton")
	await until(combat_ready, "Opening hand")
	if failed: return
	witness("combat_started %s hp=%s hand=%s" % [str(run_state().get("current_room")), str(battle().get("player", {}).get("hp")), str(hand())])

func combat_ready() -> bool:
	return (
		mode() == "combat" and not bool(scene.get("_animation_lock"))
		and not bool(scene.get("_opening_hand_draw_in_progress"))
		and not bool(scene.get("_dialogue_active")) and not hand().is_empty()
		and scene.get("_combat_engine").call("is_player_turn", battle())
	)

func claim_reward(inspect: bool) -> void:
	var reward_row := func() -> Control: return scene.find_child("RewardCardRow", true, false) as Control
	if not await until(func() -> bool:
		return (mode() == "reward" and not bool(scene.get("_animation_lock"))
			and not bool(scene.get("_reward_reveal_pending")) and driver.usable(reward_row.call())),
		"Visible reward card row"): return
	var row: Control = reward_row.call()
	if inspect:
		var expected: Array = run_state().get("pending_reward", {}).get("cards", [])
		if not require(not expected.is_empty() and row.get_child_count() == expected.size(), "All choices in the real reward row"): return
		for slot: Control in row.get_children():
			var card: Control = slot.get_node("CardScaleFrame").get_child(0) as Control
			driver.motion(driver.point(card))
			if not await until(func() -> bool: return combat.tooltip_owned(card), "Reward card tooltip"): return
			witness("reward_card_hover " + str(slot.get_meta("reward_card_id")))
			await hold()
	var recover: Control = scene.find_child("RewardRecoverButton", true, false) as Control
	if driver.usable(recover):
		await driver.click(driver.point(recover))
	else:
		await driver.click(driver.point(row.get_child(0).get_node("CardScaleFrame").get_child(0)))
	await until(func() -> bool: return mode() not in ["reward", "escape"] and not bool(scene.get("_animation_lock")), "Reward selection returned to travel")

func resolve_event(inspect: bool) -> void:
	if not await until(func() -> bool:
		var view: Control = scene.get("_event_view")
		return mode() == "event" and driver.usable(view) and not bool(view.get("_busy")) and not view.get("choices").is_empty(),
		"Live event choices"): return
	var view: Control = scene.get("_event_view")
	var choices: Array = view.get("choices")
	var chosen: Button
	var preview = preload("res://scripts/event_reward_preview.gd")
	for choice: Button in choices:
		if not driver.usable(choice) or not bool(choice.get("available")): continue
		if chosen == null: chosen = choice
		if not inspect or preview.first_concrete(view.call("cached_preview_lines", choice.get("choice_id"))).is_empty(): continue
		chosen = choice
		var index: int = choices.find(choice)
		driver.motion(driver.point(choice))
		if not await until(func() -> bool:
			return int(view.get("_pointer_choice")) == index and not view.get("hover_preview").get("current_line").is_empty(),
			"Concrete hovered event reward"): return
		witness("event_reward_hover " + str(choice.get("choice_id")))
		await hold()
		await still(2)
		break
	if not require(chosen != null and (not inspect or witnesses.back().begins_with("event_reward_hover ")), "Available event choice and requested preview"): return
	await driver.click(driver.point(chosen))
	if not await until(func() -> bool: return mode() != "event" or driver.usable(view.get("continue_button")), "Event result"): return
	if mode() == "event":
		var continue_button: Button = view.get("continue_button")
		await until(func() -> bool: return not bool(view.get("_busy")), "Event result input unlocked")
		if failed: return
		await driver.click(driver.point(continue_button))
		await until(func() -> bool: return mode() != "event", "Event closed")
	if not failed and mode() in ["reward", "treasure"]:
		await resolve_surface()

func enemy_present(id: String) -> bool:
	return (battle().get("enemies", []) as Array).any(
		func(enemy: Dictionary) -> bool: return enemy.get("type") == id and int(enemy.get("hp", 0)) > 0)

func observe_upheaval() -> void:
	if upheaval_seen or not is_instance_valid(scene): return
	var board: Control = scene.get("board_view")
	var presentation: Dictionary = board.get("presentation")
	if presentation.get("battlefield_rule_caption", {}).get("rule") != "upheaval": return
	upheaval_seen = true
	witness("craghide_upheaval_playback frame=%d" % frame_count())
	await still(3)

func resolve_surface() -> void:
	await settle_narration()
	if failed: return
	match mode():
		"pre_battle":
			await begin_battle()
			if failed: return
			await combat.finish_fight()
			if failed: return
			await resolve_surface()
		"reward":
			await claim_reward(false)
		"event":
			await resolve_event(false)
		"campfire":
			await take_room_choice("choice_id", "linger", "Campfire Linger")
			await until(func() -> bool: return mode() == "room" and not bool(scene.get("_animation_lock")), "Leave campfire after recovery")
		"treasure":
			var offers: Array = run_state().get("pending_relics", [])
			if not require(not offers.is_empty(), "Production relic reward"): return
			await take_room_choice("relic_id", str(offers[0]), "Claim relic")
			await until(func() -> bool: return mode() == "room" and not bool(scene.call("_treasure_presentation_busy")), "Relic claimed")
		"room":
			if bool(scene.get("_merchant_shop_open")):
				await until(func() -> bool: return driver.usable(scene.find_child("ScavengerLeaveButton", true, false)), "Open scavenger shop can be left")
				if failed: return
				await click_named(scene, "ScavengerLeaveButton")
		_:
			require(false, "Unexpected travel surface " + mode())

func take_room_choice(key: String, value: String, detail: String) -> void:
	var option := func() -> Control:
		if bool(scene.get("_animation_lock")) or bool(scene.call("_treasure_presentation_busy")): return null
		var choices: Control = scene.get("_relic_choice_bar")
		for child: Control in choices.get_children():
			if driver.usable(child) and child.get_meta(key, "") == value and (key != "choice_id" or child.get_meta("choice_revealed", false)):
				return child
		return null
	if not await until(func() -> bool: return option.call() != null, detail): return
	await driver.click(driver.point(option.call()))
