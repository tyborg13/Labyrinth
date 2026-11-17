extends "res://tools/atk13/capture.gd"
# Debug-only headless sampling clock. Native production timing stays unchanged.
const PROOF_HEADLESS_TIME_SCALE: float = 16.0
const PROOF_HEADLESS_MAX_FPS: int = 120
const PROOF_STRIP_TIME_SCALE: float = 0.5
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.time_scale = PROOF_HEADLESS_TIME_SCALE
		Engine.max_fps = PROOF_HEADLESS_MAX_FPS
	super._initialize()
	if _arg("--peak-strip", "false") == "true": Engine.time_scale = PROOF_STRIP_TIME_SCALE

# Controlled proof positions/Health only; all rule dials and assets stay authored.
const PROOF_BOSS_ANCHOR := Vector2i(4, 4)
const PROOF_HERO_TILE := Vector2i(3, 4)
const PROOF_CHAIN_TILE := Vector2i(2, 4)
const PROOF_HERO_HEALTH: int = 50
const PROOF_BOSS_SEED: int = 7262026
const PROOF_BOSS_DEPTH: int = 4
const PROOF_CHAIN_ACTOR_ID_OFFSET: int = 1
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Playback = preload("res://scripts/battlefield_rules/playback.gd")
var probe_done: bool = false
var proof_peaks: Array[Dictionary]

func _run() -> void:
	var scenario: String = _arg("--case")
	if scenario.is_empty():
		await super._run()
		return
	# Keep controlled contact/hold proofs at the native presentation clock.
	# The fast inherited headless clock can skip the short bolt/arc samples.
	Engine.time_scale = PROOF_STRIP_TIME_SCALE if _arg("--peak-strip", "false") == "true" else 1.0
	var out: String = _arg("--out")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Store.set_storage_path("user://atk14_f1_profile.json")
	Store.set_run_storage_path("user://atk14_f1_run.save")
	Settings.set_storage_path("user://atk14_f1_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = _arg("--reduced-motion", "false") == "true"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(canvas)
	native_scene = load("res://scenes/run_scene.tscn").instantiate()
	_prepare_native_scene()
	canvas.add_child(native_scene)
	for frame: int in range(PROOF_BOOT_FRAMES): await process_frame
	var engine: RefCounted = native_scene.get("_combat_engine")
	var run: Dictionary = _beat_fixture(engine, scenario)
	native_scene.set("_progression", run["progression"].duplicate(true))
	native_scene.call("_load_run_state", run)
	native_scene.call("_close_dialogue")
	native_scene.call("_close_large_map")
	for frame: int in range(PROOF_LAYOUT_FRAMES): await process_frame
	var before: Dictionary = (native_scene.get("_combat_state") as Dictionary).duplicate(true)
	var steps: Array[Dictionary]
	var after: Dictionary
	if scenario == "skybreak":
		var source_index: int = engine._enemy_index_for_id(before, int(before["battlefield_rule"]["source"]["id"]))
		var turn: Dictionary = preload("res://scripts/battlefield_rules/committed.gd").enemy_turn(engine, before, source_index)
		steps.assign(turn["steps"])
		after = turn["state"]
	else: after = Rules.fire(engine, before.duplicate(true), steps)
	_check(steps.any(func(step: Dictionary) -> bool: return step.get("kind") == "lightning_strikes") if scenario == "skybreak" else steps.size() == 1, "real production action/beat step")
	var expected: Array[Dictionary] = preload("res://scripts/battlefield_rules/hit_playback.gd").losses(engine, before, after)
	var source_id: int = int(before["battlefield_rule"]["source"]["id"])
	var source_key: String = "enemy_%d" % source_id
	var chain_losses: Array[Dictionary]
	if scenario != "skybreak":
		for stage: Dictionary in preload("res://scripts/battlefield_rules/hit_playback.gd").stages(engine, steps[0]):
			if str(stage["effect"]["kind"]) == "chain": chain_losses.append_array(stage["losses"])
	if scenario == "zekarion":
		_check(expected.size() == 3, "Zekarion, hero primary and Wisp Chain losses are all present")
		_check(int(engine._surface_actor(before, "enemy", source_id)["hp"]) - int(engine._surface_actor(after, "enemy", source_id)["hp"]) == 5, "authored Lightning Storm deals self-strike 5")
	var source: Dictionary = engine._surface_actor(before, "enemy", source_id)
	native_scene.call("_set_action_banner", "%s: %s" % [engine._enemy_display_name(source), str(source.get("intent", {}).get("name", ""))])
	await _picture(out.get_basename() + "_source.png")
	native_scene.set("_animation_lock", true)
	var timeline: Array[Dictionary]
	var shown_numbers: Dictionary = {}
	var signature: String = ""
	var captures: int = 0
	var start: int = native_scene.get("_combat_pacing").presentation_usec()
	_play_beat(before.duplicate(true), steps, after)
	var board: Control = native_scene.get("board_view")
	for frame: int in range(PROOF_PEAK_PLAYBACK_FRAME_LIMIT if _arg("--peak-strip", "false") == "true" else PROOF_PLAYBACK_FRAME_LIMIT):
		var shown: Dictionary = board.get("presentation")
		var displayed: Dictionary = board.get("combat_state")
		var label: Label = native_scene.get("action_banner")
		var icon: Control = label.get_node_or_null("BattlefieldRuleCaptionIcon")
		var texts: Array = shown.get("floating_texts", [])
		for text: Dictionary in texts:
			var key: String = str(text.get("reaction_actor_key", ""))
			if not key.is_empty():
				var ids: Dictionary = shown_numbers.get(key, {})
				ids[str(text.get("screen_layout_id", ""))] = str(text.get("text", ""))
				shown_numbers[key] = ids
		var bar: Control = native_scene.get("_boss_health_bar")
		var hp: int = int(engine._surface_actor(displayed, "enemy", source_id).get("hp", -1))
		var entry: Dictionary = {"frame": frame, "caption": label.text, "effect": shown.get("effect", {}), "progress": shown.get("effect_progress", 0.0), "contact": shown.get("rule_contact", false), "losses": shown.get("rule_losses", []), "numbers": texts, "source_hp": hp, "boss_bar_hp": bar.get("value") if bar != null else -1, "caption_icon": str(icon.get_rect()) if icon != null else "", "bolt_peak": _strike_peak(shown.get("effect", {}), float(shown.get("effect_progress", 0.0)))}
		var next: String = str([entry["effect"], entry["contact"], hp, icon != null, float(entry["progress"]) >= PROOF_CONTACT_SAMPLE_PROGRESS, entry["bolt_peak"]])
		if signature != next:
			signature = next
			timeline.append(entry)
			if captures < PROOF_PLAYBACK_CAPTURE_LIMIT:
				await _picture(out.get_basename() + "_step%d.png" % captures)
				captures += 1
		if icon != null:
			_check(icon.size == Vector2.ONE * Playback.CAPTION_ICON_SIZE, "caption icon is 28 px")
			var width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size("font_size")).x
			_check(is_equal_approx((label.size.x - width) * 0.5 - icon.get_rect().end.x, Playback.CAPTION_ICON_GAP), "caption icon ends 8 px before first centred glyph")
		if scenario == "zekarion" and bool(entry["contact"]) and str(entry["effect"].get("kind", "")) == "lightning_strikes":
			_check(hp == int(engine._surface_actor(after, "enemy", source_id)["hp"]), "Zekarion Health drains at bolt contact")
			_check(int(entry["boss_bar_hp"]) == hp, "boss bar uses contact Health immediately")
			for loss: Dictionary in chain_losses:
				_check(engine._surface_actor(displayed, loss["kind"], int(loss.get("id", -1))).get("hp") == engine._surface_actor(before, loss["kind"], int(loss.get("id", -1))).get("hp"), "Chain victim Health remains intact during primary bolts")
		if bool(entry["contact"]) and str(entry["effect"].get("kind", "")) == "chain":
			for loss: Dictionary in entry["losses"]:
				_check(texts.any(func(text: Dictionary) -> bool: return str(text.get("reaction_actor_key", "")) == str(loss["key"])), "Chain number appears on the same contact frame as its loss")
		if probe_done: break
		await process_frame
	_check(probe_done, "beat playback completes within proof budget")
	if scenario == "zekarion":
		_check(timeline.any(func(entry: Dictionary) -> bool: return bool(entry["contact"]) and entry["effect"].get("kind") == "lightning_strikes"), "observed the primary contact frame")
		_check(timeline.any(func(entry: Dictionary) -> bool: return bool(entry["contact"]) and entry["effect"].get("kind") == "chain"), "observed the Chain contact frame")
		for loss: Dictionary in expected:
			var numbers: Dictionary = shown_numbers.get(str(loss["key"]), {})
			_check(numbers.size() == 1 and numbers.values().has("-%d" % int(loss["hp_loss"])), "one correctly styled loss popup per struck unit: " + str(loss["key"]))
		_check(timeline.any(func(entry: Dictionary) -> bool: return entry["caption"] == "Lightning Storm" and entry["source_hp"] < int(source["hp"]) and not (entry["numbers"] as Array).is_empty()), "self-strike has both its number and named rule cause")
	elif scenario == "caption_only":
		_check(native_scene.get("_combat_pacing").presentation_usec() - start >= int(Playback.CAPTION_ONLY_HOLD_SECONDS * 1000000.0), "caption-only beat holds at least 0.6 presentation seconds")
		_check(timeline.any(func(entry: Dictionary) -> bool: return not str(entry["caption_icon"]).is_empty()), "caption-only beat has its rule icon")
	if _arg("--peak-strip", "false") == "true" and scenario != "caption_only": _check(not proof_peaks.is_empty(), "strip observes the bolt at peak")
	native_scene.set("_animation_lock", false)
	await _picture(out)
	var report: Dictionary = {"scenario": scenario, "controlled_fixture": true, "timeline": timeline, "expected_losses": expected, "observed_numbers": shown_numbers, "source_key": source_key, "elapsed_presentation_seconds": float(native_scene.get("_combat_pacing").presentation_usec() - start) / 1000000.0}
	print("ATK14 RULE PLAYBACK %s: %s" % [scenario, "PASS" if failures.is_empty() else "FAIL"])
	await _finish_capture(out, report, scenario)

func _play_beat(displayed: Dictionary, steps: Array[Dictionary], after: Dictionary) -> void:
	await native_scene.call("_animate_enemy_phase_steps", displayed, steps, after)
	probe_done = true

func _beat_fixture(engine: RefCounted, scenario: String) -> Dictionary:
	var factory: Script = preload("res://tools/dragon_boss_inspection.gd")
	var owner := preload("res://scripts/run_engine.gd").new()
	var options: Dictionary = {"seed": PROOF_BOSS_SEED, "dragon_id": "zekarion" if scenario in ["zekarion", "skybreak"] else "iskaldra", "dragon_depth": PROOF_BOSS_DEPTH, "dragon_build": "balanced"}
	var seed: int = factory.seed_for_options(options)
	var run: Dictionary = factory.build(owner, engine, owner.create_new_run(seed, Store.default_data()), options)
	var state: Dictionary = run["combat_state"]
	state["surfaces"] = {}
	state["terrain"] = []
	state["traps"] = []
	state.erase("umbra")
	state["player"]["hp"] = PROOF_HERO_HEALTH
	state["player"]["max_hp"] = PROOF_HERO_HEALTH
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	if scenario == "zekarion":
		state["player"]["pos"] = PROOF_HERO_TILE
		var boss: Dictionary = engine._surface_actor(state, "enemy", int(state["battlefield_rule"]["source"]["id"])).duplicate(true)
		boss["pos"] = PROOF_BOSS_ANCHOR
		for intent: Dictionary in preload("res://scripts/game_data.gd").enemy_def("zekarion")["intents"]:
			if str(intent["id"]) == str(state["battlefield_rule"]["cadence"]["intent"]): boss["intent"] = intent.duplicate(true)
		# A controlled Chain recipient, independent of either branch's authored
		# starting-helper count. Its art, Health and intent use the current catalog.
		var definition: Dictionary = preload("res://scripts/game_data.gd").enemy_def("lightning_wisp")
		var wisp: Dictionary = {"id": int(boss["id"]) + PROOF_CHAIN_ACTOR_ID_OFFSET, "type": "lightning_wisp", "pos": PROOF_CHAIN_TILE, "hp": int(definition["max_hp"]), "max_hp": int(definition["max_hp"]), "intent": definition["intents"][0].duplicate(true)}
		state["enemies"] = [boss, wisp]
		preload("res://scripts/board_surface_rules.gd").place(state, PROOF_BOSS_ANCHOR, "electrified")
		preload("res://scripts/board_surface_rules.gd").place(state, PROOF_HERO_TILE, "electrified")
		state["turn"] = int(state["turn"]) + 1
	return run

func _prepare_native_scene() -> void:
	if _arg("--peak-strip", "false") == "true":
		native_scene.set_script(preload("res://tools/atk14/peak_scene.gd"))
		native_scene.set("proof_owner", self)
	if _arg("--before", "false") == "true":
		var board: Node = native_scene.get_node("BoardUnderlay/CombatBoard")
		board.set_script(preload("res://tools/atk14/f2_before_board.gd"))

func _capture_peak(frame: int, count: int) -> void:
	var board: Control = native_scene.get("board_view")
	var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	var state: Dictionary = (board.get("combat_state") as Dictionary).duplicate(true)
	var base: String = _arg("--out").get_basename() + "_peak%d" % proof_peaks.size()
	var tiles: Array[Dictionary]
	var xform: Transform2D = board.get_global_transform_with_canvas()
	for tile: Vector2i in preload("res://scripts/dragon_presentation.gd").tiles(shown["effect"]):
		if not board.call("_board_tile_is_visible_to_player", tile): continue
		var polygon: Array
		for point: Vector2 in board.call("_tile_polygon", tile):
			var screen: Vector2 = xform * point
			polygon.append([screen.x, screen.y])
		tiles.append({"tile": [tile.x, tile.y], "polygon": polygon})
	var actors: Array[Dictionary]
	for unit: Dictionary in board.call("_visible_units"):
		if not tiles.any(func(entry: Dictionary) -> bool: return Vector2i(entry["tile"][0], entry["tile"][1]) == unit.get("pos")): continue
		var rect: Rect2 = xform * (board.call("_unit_draw_rect", unit) as Rect2)
		actors.append({"key": unit.get("key", ""), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	var entry: Dictionary = {"image": base + ".png", "clear_image": base + "_clear.png", "frame": frame, "frame_count": count,
		"effect_progress": shown.get("effect_progress"), "tiles": tiles, "actors": actors,
		"presentation_usec": native_scene.get("_combat_pacing").presentation_usec(), "effect": shown.get("effect")}
	_check(_strike_peak(shown.get("effect", {}), float(shown.get("effect_progress", 0.0))), "scheduled pose uses the canonical peak phase")
	proof_peaks.append(entry)
	# Freeze the actual submitted pose through both renderer readbacks. This is
	# proof-only: the next live callback resumes with exactly its original state.
	var was_paused: bool = paused
	paused = true
	await _picture(base + ".png")
	var clear: Dictionary = shown.duplicate(true)
	clear.erase("effect")
	clear.erase("impact_decals")
	native_scene.call("_render_board_state", state, clear)
	await _picture(base + "_clear.png")
	native_scene.call("_render_board_state", state, shown)
	native_scene.get("_combat_pacing").presentation_usec()
	paused = was_paused

func _finish_capture(out: String, report: Dictionary, view: String) -> void:
	report["deterministic_peaks"] = proof_peaks
	await super._finish_capture(out, report, view)

func _has_scheduled_peak(_timeline: Array[Dictionary]) -> bool:
	return not proof_peaks.is_empty()
