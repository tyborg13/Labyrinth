extends RefCounted

const HitStop = preload("res://scripts/combat_hit_stop.gd")
const Pacing = preload("res://scripts/combat_pacing.gd")
const Settings = preload("res://scripts/settings_store.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const FloatingSuite = preload("res://tests/suites/floating_combat_text_suite.gd")
const MotionSuite = preload("res://tests/suites/combat_motion_timing_suite.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const PROOF_DIR: String = "res://output/feel-01"
const REAL_WAIT_TOLERANCE_MS: int = 80
const REAL_WAIT_TIMEOUT_MS: int = 2000
const HEAVY_INTEGRATION_DAMAGE: int = 12
const HEAVY_OBSERVATION_MS: int = 125
const CARD_RESOLUTION_TIMEOUT_MS: int = 6000
const CLEANUP_FRAMES: int = 20
const NO_ENEMY_FIXTURE_TIME: int = 1000
const VICTORY_FIXTURE_ENEMY_HP: int = 1
const VICTORY_FIXTURE_ENEMY_TILE: Vector2i = Vector2i(3, 4)
const PROOF_CONTRACT: Dictionary = {
	"min_images": 8, "expected_sizes": ["1920x1080"],
	"required_images": [
		{"pattern": "*heavy_hit_minus_1.png", "width": 1920, "height": 1080},
		{"pattern": "*heavy_hit_0.png", "width": 1920, "height": 1080},
		{"pattern": "*heavy_hit_plus_1.png", "width": 1920, "height": 1080},
		{"pattern": "*heavy_hit_plus_4.png", "width": 1920, "height": 1080},
		{"pattern": "*heavy_hit_plus_8.png", "width": 1920, "height": 1080},
		{"pattern": "*heavy_hit_post_stop_peak.png", "width": 1920, "height": 1080, "regions": [{"rect": [36,62,1848,676], "min_luma_range": 50, "min_luma_stdev": 3}]},
		{"pattern": "*combat_speed_settings.png", "width": 1920, "height": 1080},
		{"pattern": "*reduced_motion_hit.png", "width": 1920, "height": 1080}
	]
}

class VictoryFixture:
	extends "res://scripts/run_scene.gd"
	var victory_scale: float = -1.0
	func _play_post_combat_victory(_state: Dictionary) -> void:
		victory_scale = Engine.time_scale

class FixtureOwner:
	extends Node
	var _settings: Dictionary = Settings.default_settings()
	var _run_state: Dictionary = {"mode": "combat"}
	var _animation_lock: bool = true
	var _drag_card_index: int = -1
	var modal: bool = false
	var pacing: Node
	var rendered: Dictionary = {}
	var render_count: int = 0
	var planning: Dictionary = {"planning": true}
	func _controller_modal_visible() -> bool:
		return modal
	func _render_board_state(state: Dictionary, presentation: Dictionary, _stable: bool) -> void:
		rendered = state
		render_count += 1
		if pacing != null: pacing.decorate(state, presentation)
	func _refresh_stage_view() -> void:
		rendered = planning
	func _animation_actor_unit(state: Dictionary, key: String) -> Dictionary:
		return state.get(key, {}) as Dictionary

static func run(tree: SceneTree, expect: Callable) -> void:
	_test_tables(expect)
	_test_merge_and_restore(expect)
	_test_settings(expect)
	FloatingSuite.run(expect)
	await _test_real_stop(tree, expect)
	await _test_scope_less_stop(tree, expect)
	await _test_overlay_refresh(tree, expect)
	await _test_scopes(tree, expect)
	await _test_run_scene(tree, expect)
	await _test_card_victory(tree, expect)
	write_proof_contract()

static func write_proof_contract() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_DIR))
	var file: FileAccess = FileAccess.open(PROOF_DIR + "/proof-contract.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(PROOF_CONTRACT, "\t"))

static func _test_tables(expect: Callable) -> void:
	for row: Array in [[0,35.0,2.0], [1,40.0,2.0], [3,40.0,2.0], [4,65.0,3.5], [7,65.0,3.5], [8,85.0,5.0], [11,85.0,5.0], [12,110.0,6.5], [40,110.0,6.5]]:
		var damage: int = int(row[0])
		for killed: bool in [false, true]:
			for hero: bool in [false, true]:
				for reduced: bool in [false, true]:
					var duration: float = maxf(float(row[1]), 100.0) if killed else float(row[1])
					if hero: duration += 20.0
					if reduced: duration *= 0.5
					expect.call(is_equal_approx(HitStop.duration_ms(damage, killed, hero, reduced), duration), "Hit-stop table damage=%d kill=%s hero=%s reduced=%s" % [damage,killed,hero,reduced])
				var amplitude: float = (6.5 if killed else float(row[2])) + (1.5 if hero else 0.0)
				expect.call(is_equal_approx(Pacing.shake_pixels(damage,killed,hero),amplitude), "Shake table damage=%d kill=%s hero=%s" % [damage,killed,hero])
				expect.call(is_equal_approx(Pacing.shake_seconds(amplitude),0.18+0.02*amplitude), "Shake duration tracks largest amplitude")
	expect.call(is_equal_approx(Pacing.flash_opacity(0.0),0.85) and is_equal_approx(Pacing.flash_opacity(0.0,true),0.60), "White flash peaks at the approved opacity")
	expect.call(is_equal_approx(Pacing.flash_opacity(0.14),0.0), "White flash fades over 140 ms")
	expect.call(Pacing.unit_shake_strength({"impact_actor_keys":["player"],"impact_progress":0.25,"impact_strength":1.0,"combat_feel_flash":{"player":0.6}},"player")==0.75,"Existing body jitter remains independent of white-flash opacity/timing")
	print("COMBAT FEEL TABLES: duration/shake/block/kill/hero/reduced/flash checked")

static func _test_merge_and_restore(expect: Callable) -> void:
	var stop: Node = HitStop.new()
	Engine.time_scale = 0.5
	stop.request(1,false,false,false,true,1000000)
	stop.request(12,false,false,false,true,1020000)
	expect.call(stop.first_hit_usec == 1000000 and stop.duration_usec == 110000, "Merged stop keeps first timestamp and largest duration")
	stop.poll(1109999)
	expect.call(stop.active and Engine.time_scale == 0.0, "Largest merged duration remains frozen")
	stop.poll(1110000)
	expect.call(not stop.active and Engine.time_scale == 0.5, "Stop restores an external director scale")
	stop.request(3,false,false,false,true,1120000)
	expect.call(not stop.active and stop.first_hit_usec == 1000000, "A hit at the 120 ms boundary never starts a fresh stop")
	stop.request(3,false,false,false,true,1120001)
	expect.call(stop.active and stop.first_hit_usec == 1120001, "A hit outside the merge window starts a new stop")
	stop.cancel()
	expect.call(Engine.time_scale == 0.5, "Cancel restores the previous scale")
	stop.request(0,false,false,false,false,1500000)
	expect.call(not stop.active and Engine.time_scale == 0.5, "Ineligible hits do not stop time")
	stop.restore_scale = func() -> float: return 2.0
	stop.request(0,false,false,false,true,2000000)
	stop.poll(2035000)
	expect.call(Engine.time_scale == 2.0, "Stop restores the current speed rather than a stale snapshot")
	# A late larger member uses only the remaining time from the original hit.
	stop.request(1,false,false,false,true,3000000)
	stop.poll(3040000)
	stop.request(8,false,false,false,true,3060000)
	expect.call(stop.first_hit_usec == 3000000 and stop.duration_usec == 85000, "Late merge retains the first origin")
	stop.poll(3085000)
	expect.call(Engine.time_scale == 2.0, "Late merge restores speed at the original-origin deadline")
	stop.free()
	Engine.time_scale = 1.0
	print("COMBAT FEEL MERGE: first-origin/largest/120ms/late/cancel/restore checked")

static func _test_settings(expect: Callable) -> void:
	expect.call(Settings.default_settings()["combat_speed"] == "normal", "Combat speed defaults to Normal")
	for row: Array in [["normal",1.0],["fast",1.5],["fastest",2.0]]:
		var settings: Dictionary = Settings.default_settings()
		settings["combat_speed"] = row[0]
		expect.call(Settings.save_settings(settings), "Combat speed saves")
		var loaded: Dictionary = Settings.load_settings()
		expect.call(loaded["combat_speed"] == row[0] and is_equal_approx(Settings.combat_speed_scale(loaded),float(row[1])), "Combat speed mapping and persistence %s" % row[0])
	expect.call(Settings.normalize_settings({})["combat_speed"] == "normal", "Old settings receive the Normal default")
	expect.call(Settings.normalize_settings({"combat_speed":"invalid"})["combat_speed"] == "normal", "Unknown speed normalizes safely")
	Settings.save_settings(Settings.default_settings())
	print("COMBAT FEEL SETTINGS: Normal=1/Fast=1.5/Fastest=2 persistence checked")

static func _test_real_stop(tree: SceneTree, expect: Callable) -> void:
	var stop: Node = HitStop.new()
	tree.root.add_child(stop)
	var started: int = Time.get_ticks_msec()
	stop.request(12,false,true)
	while stop.active and Time.get_ticks_msec() - started < REAL_WAIT_TIMEOUT_MS:
		await tree.process_frame
	var elapsed: int = Time.get_ticks_msec() - started
	expect.call(not stop.active and elapsed >= 130 and elapsed <= 130+REAL_WAIT_TOLERANCE_MS, "Stop lasts 130 real ms at a zero Engine scale")
	stop.request(12)
	stop.free()
	expect.call(Engine.time_scale == 1.0, "Scene exit during a stop restores time")
	print("COMBAT FEEL REAL STOP: observed=%dms expected=130ms restored=%s" % [elapsed,Engine.time_scale])

static func _test_scope_less_stop(tree: SceneTree, expect: Callable) -> void:
	var owner := FixtureOwner.new()
	tree.root.add_child(owner)
	var pacing: Node = Pacing.new()
	pacing.install(owner)
	owner._settings["combat_speed"] = "fastest"
	pacing.hit_stop.request(12, false, true)
	expect.call(pacing.hit_stop.active and Engine.time_scale == 0.0, "Scope-less hit-stop starts at zero")
	pacing.begin_card()
	await _wait_real(tree, HEAVY_OBSERVATION_MS + REAL_WAIT_TOLERANCE_MS)
	expect.call(not pacing.hit_stop.active and Engine.time_scale == 2.0, "Card begun inside scope-less stop restores selected combat speed")
	pacing.end_scope()
	expect.call(Engine.time_scale == 1.0, "Scope-less stop/card overlap ends at 1.0")
	owner.free()
	expect.call(Engine.time_scale == 1.0, "Freeing scope-less stop owner leaves scale 1.0")
	Engine.time_scale = 1.0
	var stop: Node = HitStop.new()
	stop.restore_scale = func() -> float: return 0.0
	stop.request(1)
	stop.cancel()
	expect.call(Engine.time_scale == 1.0, "Hit-stop never restores a nonpositive callback scale")
	stop.free()
	Engine.time_scale = 1.0

static func _test_overlay_refresh(tree: SceneTree, expect: Callable) -> void:
	var owner := FixtureOwner.new()
	tree.root.add_child(owner)
	var pacing: Node = Pacing.new()
	pacing.install(owner)
	owner.pacing = pacing
	pacing.begin_enemies()
	var shown: Dictionary = {"animation": true}
	var popup: Dictionary = preload("res://scripts/floating_combat_text.gd").damage_entry(Vector2i(3, 4), "-3", Color.WHITE)
	var presentation: Dictionary = {"floating_texts": FloatingText.animate_entries([popup], 0.0, false)}
	owner._render_board_state(shown, presentation, true)
	var renders: int = owner.render_count
	pacing._process(0.0)
	pacing._refresh_overlays()
	expect.call(owner.render_count == renders, "Overlay refresh skips a frame already submitted by the scene")
	await pacing.finish_enemies()
	owner._refresh_stage_view()
	await _wait_real(tree, int(FloatingText.ANIMATION_DURATION_SECONDS * 1000.0) + REAL_WAIT_TOLERANCE_MS)
	expect.call(owner.rendered == owner.planning, "Finished enemy overlays cannot overwrite or retain an animation over planning")
	expect.call((pacing.get("_popups") as Dictionary).is_empty(), "Scope end clears retained overlays")
	owner.free()

static func _test_scopes(tree: SceneTree, expect: Callable) -> void:
	var owner: Node = FixtureOwner.new()
	tree.root.add_child(owner)
	var pacing: Node = Pacing.new()
	pacing.install(owner)
	var caption: String = "Tunnel Crawler: Skitter Strike"
	owner._settings["combat_speed"] = "fast"
	pacing.begin_enemies()
	expect.call(Engine.time_scale == 1.5, "Enemies use the selected speed")
	pacing.set("_caption",caption)
	pacing.set("_caption_prefix","Tunnel Crawler")
	expect.call(pacing.caption_text("Tunnel Crawler: Move") == caption,"The intent caption survives immediate movement/strike submissions without a caption wait")
	expect.call(pacing.caption_text("SURVIVE: REINFORCEMENTS") == "SURVIVE: REINFORCEMENTS","Global feedback keeps its own existing copy")
	var start: int = pacing.presentation_usec()
	pacing.hit_stop.request(12)
	await _wait_real(tree,120)
	expect.call(not pacing.hit_stop.active and Engine.time_scale == 1.5, "Hit-stop restores Fast")
	expect.call(pacing.presentation_usec()-start < 45000, "The presentation clock freezes during a stop")
	owner._settings["combat_speed"] = "fastest"
	pacing.hit_stop.request(12)
	await _wait_real(tree,135)
	expect.call(Engine.time_scale == 2.0, "A changed setting during stop restores the current speed")
	owner.modal = true
	await tree.process_frame
	await tree.process_frame
	expect.call(Engine.time_scale == 1.0, "Menus run at normal scale")
	owner.modal = false
	await tree.process_frame
	pacing.end_scope()
	expect.call(Engine.time_scale == 1.0, "Enemy scope returns planning to normal time")
	Engine.time_scale = 0.5
	pacing.begin_card()
	expect.call(Engine.time_scale == 1.0, "Fastest multiplies director slow motion")
	pacing.hit_stop.request(12)
	pacing.end_scope()
	expect.call(Engine.time_scale == 0.5 and not pacing.hit_stop.active, "Ending combat mid-stop restores director time")
	Engine.time_scale = 1.0
	owner._settings["combat_speed"] = "fast"
	pacing.begin_card()
	pacing.hit_stop.request(12)
	Engine.time_scale = 0.25
	await tree.process_frame
	await tree.process_frame
	expect.call(Engine.time_scale == 0.0,"A director scale change during a stop keeps the freeze")
	pacing.end_scope()
	expect.call(Engine.time_scale == 0.25,"A director change during stop becomes the restored base")
	Engine.time_scale = 1.0
	var terrain_popup: Dictionary = preload("res://scripts/floating_combat_text.gd").damage_entry(Vector2i(3,4),"-3",Color.WHITE)
	var terrain_presentation: Dictionary = {"floating_texts":preload("res://scripts/floating_combat_text.gd").animate_entries([terrain_popup],0.0,false)}
	pacing.decorate({},terrain_presentation)
	pacing.present_hits(terrain_presentation)
	expect.call(pacing.hit_stop.active and pacing.hit_stop.duration_usec == 40000,"Explicit terrain HP damage uses the damage stop table without inventing an actor reaction")
	pacing.end_scope()
	owner._animation_lock = false
	pacing.begin_card()
	await tree.process_frame
	expect.call(Engine.time_scale == 1.0, "Interactive hands cannot retain a speed scope")
	Engine.time_scale = 0.5
	pacing.end_scope()
	expect.call(Engine.time_scale == 0.5,"An unowned planning scale survives cleanup")
	Engine.time_scale = 1.0
	owner._animation_lock = true
	owner._drag_card_index = 1
	expect.call(not pacing._presentation_allowed(), "Drag/aim cannot trigger a stop")
	owner._drag_card_index = -1
	tree.paused = true
	expect.call(not pacing.hit_stop.request(12), "Paused games reject stops")
	tree.paused = false
	owner.free()
	Engine.time_scale = 1.0
	print("COMBAT FEEL SCOPES: clock/menu/drag/pause/director/card/end checked")

static func _test_card_victory(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	instance.set_script(VictoryFixture)
	tree.root.add_child(instance)
	await tree.process_frame
	MotionSuite._install_fixture(instance, true)
	var state: Dictionary = instance.get("_combat_state")
	state["deck"]["hand"] = ["quick_stab"]
	state["enemies"][0]["pos"] = VICTORY_FIXTURE_ENEMY_TILE
	state["enemies"][0]["hp"] = VICTORY_FIXTURE_ENEMY_HP
	instance.get("_settings")["combat_speed"] = "fastest"
	instance.get("_run_state")["combat_state"] = state
	instance.call("_refresh_ui")
	instance.call("_on_card_pressed", 0)
	instance.call("_on_board_tile_clicked", VICTORY_FIXTURE_ENEMY_TILE)
	var render_boundary: Callable = func() -> void: RenderingServer.frame_post_draw.emit()
	if DisplayServer.get_name() == "headless": tree.process_frame.connect(render_boundary)
	var deadline: int = Time.get_ticks_msec() + CARD_RESOLUTION_TIMEOUT_MS
	while bool(instance.get("_animation_lock")) and Time.get_ticks_msec() < deadline: await tree.process_frame
	if tree.process_frame.is_connected(render_boundary): tree.process_frame.disconnect(render_boundary)
	expect.call(instance.victory_scale == 1.0, "Fastest card killing blow starts the production victory beat at 1.0")
	instance.queue_free()
	for frame: int in range(CLEANUP_FRAMES): await tree.process_frame

static func _test_run_scene(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	MotionSuite._install_fixture(instance,false)
	var settings: Dictionary = instance.get("_settings") as Dictionary
	settings["combat_speed"] = "fastest"
	var before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	instance.call("_on_card_pressed",0)
	instance.call("_on_board_tile_clicked",(before["player"] as Dictionary)["pos"])
	var saw_speed: bool = false
	var deadline: int = Time.get_ticks_msec()+CARD_RESOLUTION_TIMEOUT_MS
	while bool(instance.get("_animation_lock")) and Time.get_ticks_msec()<deadline:
		saw_speed = saw_speed or is_equal_approx(Engine.time_scale,2.0)
		await tree.process_frame
	expect.call(saw_speed and not bool(instance.get("_animation_lock")), "Committed card resolution uses Fastest until the hand unlocks")
	expect.call(Engine.time_scale == 1.0, "A real card returns planning to 1.0")
	var engine: RefCounted = CombatEngine.new()
	var expected: Dictionary = engine.prepare_player_card(before,0)
	var actions: Array = engine.card_play_actions("stone_plate",expected)
	for action: Dictionary in actions:
		expected = engine.resolve_player_action_for_presentation(expected,action,(before["player"] as Dictionary)["pos"] if engine.player_action_needs_target(action) else Vector2i(-1,-1))["state"]
	expected = engine.finish_player_card(expected,0,engine.card_plays_spent_for_actions(actions),{"play_mode":"play"})
	expect.call(instance.get("_combat_state") == expected, "Card presentation preserves the complete resolver state/RNG")
	# Exercise the production board trigger, not only the duration functions.
	settings["combat_speed"] = "normal"
	instance.set("_animation_lock",true)
	var pacing: Node = instance.get("_combat_pacing")
	pacing.begin_card()
	var damaged: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	(damaged["enemies"] as Array)[0]["hp"] = int((damaged["enemies"] as Array)[0]["hp"])-HEAVY_INTEGRATION_DAMAGE
	var popup: Dictionary = preload("res://scripts/floating_combat_text.gd").damage_entry((damaged["enemies"] as Array)[0]["pos"],"-12",Color.WHITE,{"reaction_actor_key":"enemy_1","reaction":"hit"})
	var observed_peak: Dictionary = {"opacity":0.0}
	pacing.hit_stop.stop_ended.connect(func() -> void:
		observed_peak["opacity"] = float((instance.get("board_view") as Node).call("_unit_impact_strength",{"key":"enemy_1"}))
	,CONNECT_ONE_SHOT)
	instance.call("_render_board_state",damaged,{"impact_actor_keys":["enemy_1"],"floating_texts":preload("res://scripts/floating_combat_text.gd").animate_entries([popup],0.0,false)})
	expect.call(pacing.hit_stop.active,"Floating damage spawns trigger the owned hit-stop")
	expect.call(float((instance.get("board_view") as Node).call("_unit_impact_strength",{"key":"enemy_1"})) == 0.0,"White flash remains absent during freeze")
	await _wait_real(tree,HEAVY_OBSERVATION_MS)
	expect.call(is_equal_approx(float(observed_peak["opacity"]),0.85),"The first submitted frame after stop has 85% enemy white flash")
	expect.call(Engine.time_scale == 1.0,"Production stop restores Normal")
	# Retained popups keep the library base and expire across actor hand-offs.
	var retained: Dictionary = (pacing.get("_popups") as Dictionary).values()[0]
	expect.call(int((retained["entry"] as Dictionary)["font_size"]) == preload("res://scripts/floating_combat_text.gd").DAMAGE_BASE_FONT_SIZE,"Retained numbers do not reanimate the already peak-sized glyph")
	await _wait_real(tree,500)
	expect.call((pacing.get("_popups") as Dictionary).is_empty(),"Damage numbers retire at their original lifetime")
	pacing.begin_enemies()
	var ground_before: Dictionary = damaged.duplicate(true)
	var ground_after: Dictionary = ground_before.duplicate(true)
	preload("res://scripts/board_surface_rules.gd").place(ground_after,Vector2i(3,4),"ice")
	expect.call(pacing.overlap_surface(ground_before,ground_after,{}),"Enemy ground feedback starts without blocking the next actor")
	var ground_shown: Dictionary = (instance.get("board_view") as Node).get("combat_state") as Dictionary
	expect.call(ground_shown.get("surfaces",{}) == ground_after.get("surfaces",{}),"Overlapping ground is committed on its first displayed frame")
	expect.call(not pacing._surface_dependency({"to":Vector2i(5,4)}),"An unrelated next actor need not wait for a surface spawn")
	expect.call(pacing._surface_dependency({"to":Vector2i(3,4)}),"A target on the spawning surface retains its dependency")
	await _wait_real(tree,400)
	expect.call((pacing.get("_surfaces") as Array).is_empty(),"Normal ground keeps its existing 0.36 s duration")
	var lethal: Dictionary = ground_after.duplicate(true)
	(lethal["enemies"] as Array)[0]["hp"] = 0
	expect.call(pacing.overlap_defeats(ground_after,lethal,true),"Enemy death dissolve overlaps the next pre-action")
	expect.call(not pacing._death_dependency({"actor_key":"enemy_2","to":Vector2i(2,4)}),"An independent actor does not wait for a dissolve")
	expect.call(pacing._death_dependency({"actor_key":"enemy_1"}),"The dying actor retains its dissolve dependency")
	await pacing.finish_enemies()
	pacing.end_scope()
	instance.set("_animation_lock",false)
	var panel: Node = instance.get("_settings_panel")
	var option: OptionButton = panel.find_child("CombatSpeedOption",true,false) as OptionButton
	expect.call(option != null and option.item_count == 3 and option.focus_mode == Control.FOCUS_ALL, "Combat speed uses the native keyboard/controller option control")
	if option != null:
		instance.call("_open_menu_overlay")
		instance.call("_open_settings_overlay")
		for _frame: int in range(3): await tree.process_frame
		option.grab_focus()
		for _frame: int in range(3): await tree.process_frame
		var parent: Node = option.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		expect.call(option.has_focus() and (parent as ScrollContainer).get_global_rect().intersects(option.get_global_rect()),"Keyboard/controller focus reveals the Combat speed row")
		option.item_selected.emit(1)
		expect.call(Settings.load_settings()["combat_speed"] == "fast", "The actual row persists Fast")
	instance.call("_close_menu_overlay")
	var hero_again: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	for entry: Dictionary in hero_again.get("turn_queue",[]):
		if str(entry.get("kind","")) == "enemy": entry["time"] = NO_ENEMY_FIXTURE_TIME
	var scheduled: Dictionary = engine.finish_player_activation(hero_again)
	expect.call(not engine.enemy_acts_before_next_player_turn(scheduled),"Back-to-back hero fixture selects no enemy")
	var next_run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	next_run["combat_state"] = hero_again
	instance.set("_run_state",next_run)
	instance.set("_combat_state",hero_again)
	var fast_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	fast_settings["combat_speed"] = "fastest"
	instance.set("_settings",fast_settings)
	instance.call("_refresh_ui")
	instance.call("_on_pass_turn_pressed")
	var incorrectly_sped_up: bool = Engine.time_scale > 1.0
	deadline = Time.get_ticks_msec()+CARD_RESOLUTION_TIMEOUT_MS
	while bool(instance.get("_animation_lock")) and Time.get_ticks_msec()<deadline:
		await tree.process_frame
		if DisplayServer.get_name()=="headless": RenderingServer.frame_post_draw.emit()
		incorrectly_sped_up = incorrectly_sped_up or Engine.time_scale > 1.0
	expect.call(not bool(instance.get("_animation_lock")) and not incorrectly_sped_up,"Back-to-back hero hand-offs stay at 1.0 even at Fastest")
	for _frame: int in range(CLEANUP_FRAMES): await tree.process_frame
	instance.call("_close_menu_overlay")
	instance.queue_free()
	await tree.process_frame
	print("COMBAT FEEL INTEGRATION: committed card/state/RNG/settings row checked")

static func _wait_real(tree: SceneTree, milliseconds: int) -> void:
	var deadline: int = Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline:
		await tree.process_frame
