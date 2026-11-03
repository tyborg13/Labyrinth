extends SceneTree
## Production fire Warband fixture, native camera and complete HUD. No renderer
## access in --check-only mode; the owner runs captures through visual_probe_runner.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const LobView = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Bot = preload("res://tools/encounter_bot.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/enc03_lob"
const MAX_PROOF_TURNS: int = 12
const MAX_PHASE_ACTIVATIONS: int = 100
const SETTLE_FRAMES: int = 8
const CAPTION_TEST_FADE_ALPHA: float = 0.5
var failures: Array[String]
var captures: Array[Dictionary]
var check_only: bool = false
var before: bool = false
var canvas: SubViewport
const Playback = preload("res://tests/enc04_lob_playback.gd")
const ScrimRenderer = preload("res://tests/enc04_scrim_renderer.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	check_only = check_only or OS.get_cmdline_user_args().has("--check-only")
	before = OS.get_cmdline_user_args().has("--before")
	if not check_only and DisplayServer.get_name() == "headless":
		push_error("ENC03 proof needs a window server; use visual_probe_runner --no-headless")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://enc03-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://enc03-profile.json")
	Store.set_run_storage_path("user://enc03-run.save")
	Store.save_data(Store.default_data())
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var run_engine := Run.new()
	var engine := Combat.new()
	var policy := Bot.Policy.new()
	policy.engine = engine
	var run: Dictionary = Fixture.build(run_engine, engine, run_engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": "fire", "warband_tier": 2, "warband_case": "pre_battle"})
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await _settle()
	scene.call("_load_run_state", run)
	scene.call("_close_dialogue")
	await _settle()
	await _capture("pre_battle")
	run = run_engine.begin_pre_battle_combat(run)
	_expect(run.get("mode") == "combat", "Production pre-battle starts the fire Warband")
	var battle: Dictionary = run["combat_state"]
	var found: Dictionary = {}
	for turn_index: int in range(MAX_PROOF_TURNS):
		await _observe(scene, run, battle, found)
		if found.size() == 2 or not engine.combat_outcome(battle).is_empty(): break
		# The existing policy selects legal cards, approach and dodge. No health,
		# positions, intent choices, camera, roster or combat rules are staged.
		for decision: int in range(Bot.MAX_DECISIONS_PER_TURN):
			var selected: Dictionary = policy.choose(battle)
			if selected.is_empty(): break
			battle = selected["state"]
			await _observe(scene, run, battle, found)
			if found.size() == 2 or not engine.combat_outcome(battle).is_empty(): break
		if found.size() == 2 or not engine.combat_outcome(battle).is_empty(): break
		battle = policy.best_dodge(battle)["state"]
		battle = engine.finish_player_activation(battle)
		for activation: int in range(MAX_PHASE_ACTIVATIONS):
			await _observe(scene, run, battle, found)
			if found.size() == 2 or not engine.combat_outcome(battle).is_empty(): break
			var advanced: Dictionary = engine.advance_one_activation_with_steps(battle)
			battle = advanced["state"]
			if bool(advanced["complete"]): break
	_expect(found.has("aiming") and found.has("landing"), "Real fixture reaches both lob turns before combat ends")
	if not before:
		await _check_caption_lifecycle(scene)
		await preload("res://tests/enc04_adjacent_playback.gd").run(scene, run, _expect)
	if not check_only:
		var file := FileAccess.open(OUTPUT.path_join("captures.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"phase": "before" if before else "after", "size": [1920, 1080], "ui_scale": 1.0, "seed": Fixture.FIXTURE_SEED, "captures": captures, "failures": failures}, "\t"))
	var empty_cards: Array[String]
	scene.set("_pile_dialog_pool_warm_cards", empty_cards)
	await _settle()
	scene.queue_free()
	await process_frame
	canvas.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("ENC03 LOB PROBE: %s (%d states; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", captures.size(), failures.size()])
	print("ENC03 CAPTURES: " + ProjectSettings.globalize_path(OUTPUT))
	quit(0 if failures.is_empty() else 1)

func _observe(scene: Control, run: Dictionary, battle: Dictionary, found: Dictionary) -> void:
	var captain: Dictionary = battle["enemies"][0]
	var intent: Dictionary = captain.get("intent", {})
	var id: String = str(intent.get("id", ""))
	var label: String = "aiming" if id == "lob_slag" else "landing" if id == "slag_lands" else ""
	if label.is_empty() or found.has(label) or not engine_visible(battle, captain): return
	if not Lob.available(Combat.new(), battle, captain, intent): return
	var display: Dictionary = run.duplicate(true)
	display["combat_state"] = battle.duplicate(true)
	scene.call("_load_run_state", display)
	scene.call("_close_dialogue")
	scene.call("_set_show_all_enemy_intents", true)
	scene.call("_on_board_tile_hovered", captain["pos"])
	for reduced: bool in [false, true]:
		if before and reduced: continue
		scene.call("_load_run_state", display)
		scene.call("_close_dialogue")
		scene.call("_set_show_all_enemy_intents", true)
		scene.call("_on_board_tile_hovered", captain["pos"])
		await _settle()
		var proof_label: String = label + ("_reduced" if reduced else "")
		await Playback.run(scene, battle, reduced, _expect, func() -> void:
			await _inspect_live_caption(scene, battle, captain, intent, proof_label))
	found[label] = true

func _inspect_live_caption(scene: Control, battle: Dictionary, captain: Dictionary, intent: Dictionary, label: String) -> void:
	await _settle()
	var board: Control = scene.get("board_view")
	var rows: Array = board.call("_intent_rows_for_unit", captain, intent)
	var text: String = Icons.plain_text_for_rows(rows)
	var mark_count: int = LobView.marks(board).size()
	var banner: Label = scene.get("action_banner")
	var hud: Control = board.get("_hud_render_layer")
	var diagnostics: Dictionary = {"banner_rect": banner.get_global_rect(), "banner_z": banner.z_index, "hud_z": hud.z_index, "banner_canvas": str(banner.get_canvas()), "hud_canvas": str(hud.get_canvas()), "ui_layer": scene.get_node("UiLayer").layer, "board_layer": scene.get_node("BoardUnderlay").layer}
	for entry: Dictionary in board.get("_hud_layout_entries_cache"):
		if str(entry.get("actor_key", "")) != "enemy_%d" % int(captain["id"]): continue
		var unit: Dictionary = captain.duplicate(false)
		var crest: Rect2 = board.call("_leader_marker_rect", unit, entry["health_rect"], entry.get("layout", {}).get("intent_rect", Rect2()))
		var screen_crest: Rect2 = board.get_global_transform_with_canvas() * crest
		diagnostics["crest_rect"] = screen_crest
		diagnostics["overlap"] = screen_crest.intersects(banner.get_global_rect())
	print("ENC03 DRAW ORDER: ", diagnostics)
	if not before:
		_expect(int(diagnostics["ui_layer"]) > int(diagnostics["board_layer"]), "Action caption canvas draws after retained board HUD, status, intent and lob overlays")
		if label.begins_with("aiming"): _expect(bool(diagnostics.get("overlap", false)), "Real fire Warband fixture reproduces caption/leader crest screen-rect overlap")
		_check_caption_scrim(banner, diagnostics)
		if not check_only:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
			await ScrimRenderer.check(self, banner, diagnostics, OUTPUT.path_join("after_%s_scrim_1920x1080.png" % label), _expect)
		var resolved: Dictionary = Lob.presentation_action(Combat.new(), battle, captain, intent["actions"][0])
		_expect(rows.size() == 1 and rows[0].size() == 1 and Icons.token_value_text(rows[0][0]) == str(int(resolved["center_damage"])), "Live lob HUD has only lob and actual scaled centre damage")
		var order: String = preload("res://scripts/warband_combat_rules.gd").order_line(battle.get("objective", {}))
		var expected_tooltip: String = Icons.lob_text(resolved) + ("\n" + order if not order.is_empty() else "")
		_expect(board.call("enemy_intent_tooltip", "enemy_%d" % int(captain["id"])) == expected_tooltip, "Live captain tooltip matches the approved sentence with scaled values and its separate order")
		_expect(mark_count > 0, "Landing danger tiles exist on " + label)
	print("ENC03 LIVE HUD: %s turn%d depth%d text='%s' marks=%d" % [label, battle["turn"], battle["room_depth"], text, mark_count])
	await _capture(label, {"turn": battle["turn"], "depth": battle["room_depth"], "intent": intent, "rows_text": text, "callout_text": banner.text, "draw_order": diagnostics, "marks": mark_count, "captain": captain["pos"], "hero": battle["player"]["pos"]})

func _check_caption_scrim(banner: Label, diagnostics: Dictionary) -> void:
	var scrim: Control = banner.get_node_or_null("ActionCaptionScrim")
	_expect(scrim != null, "Every action caption rests on the shared soft HUD scrim")
	if scrim == null: return
	_expect(scrim.show_behind_parent and scrim.get_canvas() == banner.get_canvas(), "Caption scrim draws directly behind its text on the same canvas")
	_expect(scrim.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Caption scrim preserves board input")
	var text_rect: Rect2 = scrim.call("caption_text_rect")
	var extent: Rect2 = scrim.call("caption_scrim_rect")
	_expect(extent == text_rect.grow_individual(48.0, 10.0, 48.0, 10.0), "Caption scrim has the approved text-relative extent")
	var overlap: Rect2 = (diagnostics.get("crest_rect", Rect2()) as Rect2).intersection(banner.get_global_rect())
	if not overlap.has_area(): return
	# Retain geometry checks alongside the separate renderer coverage guard.
	# Every patch touching the intersection must stay dense.
	var local_overlap: Rect2 = scrim.get_global_transform_with_canvas().affine_inverse() * overlap
	var covered_area: float = 0.0
	var minimum_alpha: float = 1.0
	for patch: Dictionary in scrim.call("caption_patches"):
		var patch_rect: Rect2 = patch["rect"]
		var covered: Rect2 = patch_rect.intersection(local_overlap)
		if not covered.has_area(): continue
		covered_area += covered.get_area()
		for colour: Color in patch["colours"]:
			minimum_alpha = minf(minimum_alpha, colour.a)
	_expect(is_equal_approx(covered_area, local_overlap.get_area()) and minimum_alpha >= 0.85 - 0.000001, "Live crest/caption intersection is fully covered at >= 0.85 scrim alpha behind the text")
	diagnostics["scrim_overlap_min_alpha"] = minimum_alpha
	diagnostics["scrim_covered_area"] = covered_area
	print("ENC03 CAPTION SCRIM: overlap area=%.3f min_alpha=%.2f" % [covered_area, minimum_alpha])

func _check_caption_lifecycle(scene: Control) -> void:
	var banner: Label = scene.get("action_banner")
	var scrim: Control = banner.get_node_or_null("ActionCaptionScrim")
	if scrim == null: return
	var settings: Dictionary = scene.get("_settings")
	var original: Dictionary = settings.duplicate(true)
	var failures_before: int = failures.size()
	for reduced: bool in [false, true]:
		settings["reduced_motion"] = reduced
		scene.set("_settings", settings)
		_expect(bool(scene.call("_reduced_motion_enabled")) == reduced, "Lifecycle check uses the real Reduced Motion setting")
		# Exercise a real non-lob adapter through the same locked dispatcher.
		var display: Dictionary = scene.get("_run_state").duplicate(true)
		var battle: Dictionary = display["combat_state"]
		battle["enemies"][0]["intent"] = preload("res://tests/suites/en04_enemies_suite.gd").intent("slag_mortar", "brace")
		scene.call("_load_run_state", display)
		scene.call("_close_dialogue")
		await Playback.run(scene, battle, reduced, _expect, func() -> void:
			_expect(scrim.is_visible_in_tree() and scrim.get_parent() == banner, "Non-lob caption shares its scrim lifetime (Reduced Motion=%s)" % reduced)
			_expect(not scrim.is_processing() and not scrim.is_physics_processing(), "Scrim has no independent fade or motion clock")
			banner.modulate.a = CAPTION_TEST_FADE_ALPHA
			_expect(scrim.modulate.a == 1.0 and scrim.get_parent().modulate.a == CAPTION_TEST_FADE_ALPHA, "Caption opacity is inherited once, without an independent fade")
			banner.modulate.a = 1.0)
		# Loading a run uses the production caption teardown path.
		scene.call("_load_run_state", display)
		_expect(not scrim.is_visible_in_tree(), "Loading a run hides its caption and scrim in the same update")

	scene.set("_settings", original)
	print("ENC03 CAPTION LIFECYCLE: %s (shared non-lob caption; normal and Reduced Motion)" % ["PASS" if failures.size() == failures_before else "FAIL"])

func engine_visible(battle: Dictionary, captain: Dictionary) -> bool:
	return Combat.new().is_enemy_visible_to_player(battle, captain)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _capture(label: String, metadata: Dictionary = {}) -> void:
	var name: String = "%s_%s_1920x1080.png" % ["before" if before else "after", label]
	captures.append({"file": name, "state": metadata})
	if check_only: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_expect(image.get_size() == SIZE and is_equal_approx(root.content_scale_factor, 1.0), "Native capture at 1920x1080 / 100%")
	_expect(image.save_png(OUTPUT.path_join(name)) == OK, "Save " + name)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
