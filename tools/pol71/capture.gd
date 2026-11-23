extends SceneTree

const Geometry = preload("capture_geometry.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Forecast = preload("res://scripts/combat_hud_forecast.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")

const VIEW_SIZE := Vector2i(1920, 1080)
const CROP_SIZE := Vector2i(320, 192)
const CROP_SCALE: int = 2
const UI_SCALE: float = 1.0
const FPS: int = 60
const STRIP_LAST_FRAME: int = 48
const STRIP_INTERVAL: int = 2
const EXPOSE_STRIP_INTERVAL: int = 4
const SETTLE_FRAMES: int = 8
const WAIT_MSEC: int = 20000
const SEED: int = 9811
const ROOM_SIZE: int = 9
const HERO_TILE := Vector2i(3, 4)
const FOE_TILE := Vector2i(5, 4)
const GROUND_TILE := Vector2i(7, 4)
const HEALTH: int = 30
const DIVERGENT_PREVIEW_INCREMENT: int = 1
const DIVERGENT_SEED: int = SEED + 1
const AREA_PUSH_CARD: String = "bottled_gale"
const AREA_PUSH_FOE := Vector2i(4, 4)
const SECOND_FIRE_TILE := Vector2i(6, 4)
const NEIGHBORS: Dictionary = {"north": Vector2i.UP, "east": Vector2i.RIGHT, "south": Vector2i.DOWN, "west": Vector2i.LEFT}
const BUFFS: Dictionary = {"whetstone": ["next_attack", "+4"], "hourglass_sand": ["quicken", "+4"], "undertaker_stand": ["retaliate", "+5"]}

var scene: Control
var viewport: SubViewport
var output: String
var dry_run: bool
var settings: Dictionary
var results: Dictionary = {"cases": {}, "adjacency": {}, "size": [1920, 1080], "ui_scale": UI_SCALE}
var failures: int
var cues: Array[Dictionary]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	dry_run = args.has("--dry-run")
	if not _check(not args.is_empty() and dry_run == (DisplayServer.get_name() == "headless"), "Output path and matching renderer required"):
		quit(1)
		return
	output = args[0]
	if not _check(not Runtime.apply_from_environment().is_empty() and preload("res://scripts/cel_look.gd").mode == "all", "Isolated Cel Look run"):
		quit(1)
		return
	Engine.max_fps = FPS
	if dry_run:
		process_frame.connect(func() -> void: RenderingServer.force_draw(false))
	settings = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.content_scale_factor = 1.0
	viewport = SubViewport.new()
	viewport.name = "ProofViewport"
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	Settings.inherit_edge_smoothing(viewport, root)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await _settle()
	scene._close_dialogue()
	if is_instance_valid(scene._large_map_scrim) and scene._large_map_scrim.visible: scene._close_large_map()
	scene._settings = settings.duplicate(true)
	_check(scene.get_viewport_rect().size == Vector2(VIEW_SIZE) and scene._settings["ui_scale"] == UI_SCALE, "Exact SubViewport layout and 100% UI scale")
	scene._ensure_sfx_bank()
	scene._sfx_bank.cue_requested.connect(func(cue: String, result: String) -> void:
		cues.append({"cue": cue, "result": result, "frame": Engine.get_process_frames()}))
	if not dry_run: Input.warp_mouse(Vector2(1, 1))
	if dry_run:
		for card: String in BUFFS:
			await _play(card, card, BUFFS[card][0], "", FOE_TILE)
		await _play("push_fire", "crosswind", "", "fire", FOE_TILE)
		await _play("push_fire_collision", "crosswind", "", "fire", FOE_TILE + Vector2i.RIGHT)
		await _play("area_push_fire", AREA_PUSH_CARD, "", "fire", AREA_PUSH_FOE)
		await _play("push_ice", "crosswind", "", "ice", FOE_TILE)
	else:
		await _play("undertaker_stand", "undertaker_stand", BUFFS["undertaker_stand"][0], "", FOE_TILE)
	await _play("push_ice_disagreement", "crosswind", "", "ice", FOE_TILE)
	if dry_run: await _rest_and_adjacency()
	scene.queue_free()
	await _settle()
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if _check(receipt != null, "Proof receipt opens"):
		receipt.store_string(JSON.stringify(results, "\t"))
	print("POL71 gameplay proof: %d failures" % failures)
	quit(int(failures > 0))


func _install(card: String, foe: Vector2i, surface: String = "", statuses: bool = false, enemy_type: String = "crawler", seed: int = SEED) -> void:
	var grid: Array
	for y: int in range(ROOM_SIZE):
		var row: Array
		for x: int in range(ROOM_SIZE):
			row.append("wall" if x == 0 or y == 0 or x == ROOM_SIZE - 1 or y == ROOM_SIZE - 1 else "stone")
		grid.append(row)
	var enemy: Dictionary = GameData.enemy_def(enemy_type)
	var room: Dictionary = {"name": "Cinder Crossing", "coord": Vector2i.ZERO, "type": "combat", "grid": grid, "player_start": HERO_TILE,
		"enemies": [{"id": 1, "type": enemy_type, "pos": foe, "hp": enemy["max_hp"], "max_hp": enemy["max_hp"], "block": 0}],
		"terrain": [], "traps": [], "loot": []}
	var cards: Array[String] = [card, "quick_stab"]
	var combat: Dictionary = Combat.new().create_combat(seed, room, {"hp": HEALTH, "max_hp": HEALTH, "deck_cards": cards, "relics": [], "hand_size": cards.size()})
	combat["deck"]["hand"] = cards.duplicate()
	combat["deck"]["draw"] = []
	combat["deck"]["discard"] = []
	combat["deck"]["burned"] = []
	combat["card_play_bonus_this_turn"] = cards.size()
	combat["current_actor"] = {"kind": "player", "key": "player"}
	if not surface.is_empty(): Surfaces.place(combat, GROUND_TILE, surface)
	if statuses:
		Retaliate.gain(combat, {"amount": 3})
		Tempo.gain_quicken(combat, {"amount": 2})
	var run: Dictionary = scene._run_state.duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = room["coord"]
	run["current_room_layout"] = room
	run["combat_state"] = combat
	scene._run_state = run
	scene._sync_combat_state_from_run()
	scene._animation_lock = false
	scene._reset_card_resolution()
	scene._refresh_ui()


func _play(name: String, card: String, icon: String, surface: String, foe: Vector2i) -> void:
	var divergent: bool = name == "push_ice_disagreement"
	_install(card, foe, surface, false, "crawler", DIVERGENT_SEED if divergent else SEED)
	if card == AREA_PUSH_CARD:
		Surfaces.place(scene._combat_state, SECOND_FIRE_TILE, "fire")
		scene._mark_combat_preview_state_changed()
		scene._refresh_stage_view()
	await _settle()
	scene._on_card_pressed(0)
	await _settle()
	var expose_frames: Array[Dictionary]
	if card == "crosswind":
		scene._on_board_tile_hovered(foe)
		await _settle()
	if divergent:
		_submit_divergent_preview()
		for hover_frame: int in range(-SETTLE_FRAMES, 0):
			await RenderingServer.frame_post_draw
			expose_frames.append(_expose_sample(hover_frame, _hud_values()))
	if not _check(scene._selected_card_index == 0 and (scene._pending_target_tiles.has(foe) if card == "crosswind" else scene._pending_card_requires_confirmation()), name + " reaches real confirmation"):
		return
	var before: Dictionary = _rule_values(scene._combat_state)
	var shown_before: Dictionary = _hud_values()
	if name == "undertaker_stand":
		_check(int(shown_before["player"]["block"]) > int(before["player"]["block"]), "Block preview is visible before confirm")
		_check(shown_before["player"]["badges"].has("retaliate"), "Retaliate preview is visible before confirm")
	if name.begins_with("push_ice"):
		_check(int(shown_before["enemy_1"]["expose"]) > int(before["enemy_1"]["expose"]), "Enemy Expose preview is visible before confirm")
	var initial_sequence: int = int(scene._combat_state.get("surface_event_sequence", 0))
	var strip: Dictionary = {}
	var expose_strip: Dictionary = {}
	var delivery_frame: int = -1
	var delivery_image: Image
	var delivery_center: Vector2
	var hud: Array[Dictionary]
	var peaks: Dictionary = {}
	var first_seen: Dictionary = {}
	var last_view: Dictionary = {}
	cues.clear()
	await process_frame
	var started: int = Time.get_ticks_msec()
	var confirm_frame: int = Engine.get_process_frames()
	var frame: int = -1
	var commit: Dictionary = {}
	scene.set_runtime_performance_instrumentation_enabled(true)
	# Card-play audio is requested synchronously after commit and before card
	# flight. Subtract the ordinary lock refresh from the stage count there.
	var play_cue: String = "legacy:" + str(scene.CARD_PLAY_SFX_ENTRY["path"])
	var observe_commit: Callable = func(cue: String, _result: String) -> void:
		if cue != play_cue or not commit.is_empty(): return
		var counts: Dictionary = scene._runtime_performance_counts
		commit["engine_frame"] = Engine.get_process_frames()
		commit["lock_refreshes"] = int(counts.get("animation_lock_ui_stage_total", 0))
		commit["extra_refreshes"] = int(counts.get("stage_total", 0)) - int(commit["lock_refreshes"])
		commit["values"] = _hud_values()
	scene._sfx_bank.cue_requested.connect(observe_commit)
	if card == "crosswind":
		scene._on_board_tile_clicked(foe)
	else:
		scene._on_confirm_card_play_pressed()
	while Time.get_ticks_msec() - started < WAIT_MSEC:
		await RenderingServer.frame_post_draw
		frame += 1
		if not commit.is_empty() and scene._runtime_performance_instrumentation_enabled:
			scene.set_runtime_performance_instrumentation_enabled(false)
		var now: Dictionary = _hud_values()
		if now != last_view:
			hud.append({"frame": frame, "ms": Time.get_ticks_msec() - started, "values": now})
			last_view = now
		if divergent and delivery_frame < 0:
			var sample: Dictionary = _expose_sample(frame, now)
			expose_frames.append(sample)
			if frame % EXPOSE_STRIP_INTERVAL == 0:
				expose_strip[frame] = {"image": _image(), "center": _actor_hud_center("enemy_1")}
			if not sample["forecast"] and sample["value"] != before["enemy_1"]["expose"]:
				delivery_frame = frame
				delivery_image = _image()
				delivery_center = _actor_hud_center("enemy_1")
		if name == "undertaker_stand" and frame >= 0 and frame <= STRIP_LAST_FRAME and frame % STRIP_INTERVAL == 0 and not strip.has(frame):
			strip[frame] = _image()
		var board: Control = scene.board_view
		for popup: Dictionary in board._floating_text_screen_layout(board.get_theme_default_font()):
			var entry: Dictionary = popup["entry"]
			var kind: String = str(entry.get("icon", ""))
			var tag: String = ""
			if not icon.is_empty() and kind == icon:
				tag = "peak"
			elif surface == "fire" and entry.get("reaction_actor_key") == "enemy_1" and entry.get("kind") == "damage":
				tag = "fire_peak" if kind == "surface_fire" else "push_peak"
			if tag.is_empty(): continue
			if not first_seen.has(tag): first_seen[tag] = frame
			var peak_size: float = float(entry["font_size"]) * float(entry["font_scale"])
			if peak_size <= float(peaks.get(tag, {}).get("font_px", 0.0)): continue
			peaks[tag] = {"font_px": peak_size,
				"icon": kind, "text": entry.get("text"), "frame": frame, "birth": first_seen[tag], "progress": entry.get("animation_progress")}
		if not scene._animation_lock and scene._selected_card_index < 0 and (name != "undertaker_stand" or frame >= STRIP_LAST_FRAME): break
	_check(not scene._animation_lock and scene._selected_card_index < 0, name + " completes")
	_check(commit.get("lock_refreshes", 0) == 1, name + " observed the commit's one normal lock refresh")
	scene._sfx_bank.cue_requested.disconnect(observe_commit)
	if scene._runtime_performance_instrumentation_enabled:
		scene.set_runtime_performance_instrumentation_enabled(false)
	var final: Dictionary = _rule_values(scene._combat_state)
	_check(not (scene._combat_state["deck"]["hand"] as Array).has(card), name + " commits the real card")
	if not icon.is_empty():
		_check(peaks.get("peak", {}).get("text") == BUFFS[card][1], name + " produces the exact existing buff label")
	if surface == "fire":
		_check(int(final["enemy_1"]["hp"]) < int(before["enemy_1"]["hp"]), name + " deals actual Health damage")
	var events: Array = (scene._combat_state.get("surface_events", []) as Array).filter(
		func(event: Dictionary) -> bool: return int(event.get("sequence", 0)) > initial_sequence and event.get("kind") in ["surface_damage", "force_collision", "status_applied"])
	var sound_cues: Array = []
	for cue: Dictionary in cues:
		if str(cue["cue"]).begins_with("surface.") or str(cue["cue"]).begins_with("spell.") or str(cue["cue"]).begins_with("push."):
			sound_cues.append(cue.merged({"frame": int(cue["frame"]) - confirm_frame}, true))
	if name == "undertaker_stand":
		_check(strip.size() == STRIP_LAST_FRAME / STRIP_INTERVAL + 1, "Block strip includes every second frame from 0 through 48")
		var center: Vector2 = _hero_hud_center()
		for sample_frame: int in strip:
			_save_pair("block_confirm_%02d" % sample_frame, strip[sample_frame], center)
	if divergent:
		_check(delivery_frame >= 0, "Divergent Expose reached delivery")
		for sample_frame: int in expose_strip:
			var shot: Dictionary = expose_strip[sample_frame]
			_save_pair("expose_divergent_%02d" % sample_frame, shot["image"], shot["center"])
		_save_pair("expose_divergent_delivery", delivery_image, delivery_center)
	results["cases"][name] = {"before": before, "final": final, "preview": shown_before, "hud_transitions": hud,
		"peaks": peaks, "cues": sound_cues, "events": events, "commit": commit,
		"expose_frames": expose_frames, "expose_strip_frames": expose_strip.keys(), "delivery_frame": delivery_frame}
	print("POL71 %s: %s" % [name, JSON.stringify({"final": final, "peaks": peaks, "cues": sound_cues, "hud_transitions": hud})])


func _hud_values() -> Dictionary:
	var board: Control = scene.board_view
	var values: Dictionary = {}
	for source: Dictionary in board._visible_units():
		var unit: Dictionary = Forecast.unit(source, board.presentation)
		var key: String = unit["key"]
		if key not in ["player", "enemy_1"]: continue
		var health: Rect2 = board._hud_health_rects_cache.get(key, Rect2())
		var layout: Dictionary = board._status_plate_layout.resolve(board, unit, health)
		var statuses: Dictionary = {}
		for badge: Dictionary in layout["statuses"]:
			statuses[badge["icon"]] = {
				"label": badge["label"], "forecast": bool(badge.get("predicted", false)) or bool(badge.get("hud_forecast", false)),
				"popping": board.status_pop_tracker.progress(key, badge["icon"]) >= 0.0,
			}
		var expose: int = str(statuses.get("expose", {}).get("label", "")).replace("→ ", "").to_int()
		var block: int = 0
		for defense: Dictionary in layout["defenses"]:
			if defense["icon"] == "block": block = str(defense["label"]).to_int()
		values[key] = {"block": block, "expose": expose, "badges": statuses}
	return values


func _expose_sample(frame: int, values: Dictionary) -> Dictionary:
	var unit: Dictionary = values["enemy_1"]
	var badge: Dictionary = unit["badges"].get("expose", {})
	return {"frame": frame, "engine_frame": Engine.get_process_frames(), "value": unit["expose"],
		"label": badge.get("label", ""), "forecast": badge.get("forecast", false)}


func _submit_divergent_preview() -> void:
	var board: Control = scene.board_view
	# Change only the submitted preview and let the real renderer paint it.
	var shown: Dictionary = board.presentation.duplicate(true)
	shown["surface_status_preview"]["enemy_1"]["expose"] += DIVERGENT_PREVIEW_INCREMENT
	board.set_combat_state(board.combat_state, board.move_tiles, board.attack_tiles,
		board.selected_tile, board.status_label, board.status_detail, board.exit_tiles, board.exit_icon_ids, shown)


func _rule_values(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in Forecast.actors(state):
		var actor: Dictionary = Forecast.actors(state)[key]
		var row: Dictionary = {}
		for field: String in ["hp", "block", "stoneskin", "expose", "shock", "immobilize", "frost_armor"]:
			row[field] = actor.get(field, false if field == "immobilize" else 0)
		result[key] = row
	result["retaliate"] = state.get(Retaliate.STATE_KEY, {}).duplicate(true)
	result["quicken"] = Tempo.quicken_pending(state)
	result["next_attack"] = Tempo.next_attack_buffs(state).duplicate(true)
	return result


func _rest_and_adjacency() -> void:
	_install("whetstone", FOE_TILE, "", true, "warden")
	await _settle()
	results["rest"] = {"geometry": "1920x1080 SubViewport", "controls": Geometry.controls(viewport, scene), "plates": Geometry.plates(scene.board_view)}
	for direction: String in NEIGHBORS:
		_install("whetstone", HERO_TILE + NEIGHBORS[direction], "", true, "warden")
		await _settle()
		var geometry: Dictionary = Geometry.plates(scene.board_view)
		_check(geometry.get("chips", {}).has("retaliate") and geometry.get("chips", {}).has("quicken"), direction + " has two actual hero statuses")
		_check(not is_zero_approx(float(geometry.get("intent_chip", [0, 0, 0, 0])[2])), direction + " has a visible Warden intent chip")
		results["adjacency"][direction] = geometry
		print("POL71 %s: %s" % [direction, JSON.stringify(geometry)])


func _hero_hud_center() -> Vector2:
	return _actor_hud_center("player")


func _actor_hud_center(key: String) -> Vector2:
	var board: Control = scene.board_view
	var frame: Rect2 = board._hud_health_rects_cache.get(key, Rect2())
	return board.get_global_transform_with_canvas() * frame.get_center()


func _image() -> Image:
	return null if dry_run else viewport.get_texture().get_image()


func _save_pair(name: String, image: Image, center: Vector2) -> void:
	if dry_run: return
	if not _check(image != null and image.get_size() == VIEW_SIZE, name + " exact SubViewport frame"): return
	var full_path: String = output.path_join(name + ".png")
	if _check(image.save_png(full_path) == OK, name + " full frame saved"): print(full_path)
	var corner: Vector2i = (Vector2i(center.round()) - CROP_SIZE / 2).clamp(Vector2i.ZERO, VIEW_SIZE - CROP_SIZE)
	var crop: Image = image.get_region(Rect2i(corner, CROP_SIZE))
	crop.resize(CROP_SIZE.x * CROP_SCALE, CROP_SIZE.y * CROP_SCALE, Image.INTERPOLATE_NEAREST)
	var crop_path: String = output.path_join(name + "_2x.png")
	if _check(crop.save_png(crop_path) == OK, name + " 2x crop saved"): print(crop_path)


func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await RenderingServer.frame_post_draw


func _check(condition: bool, context: String) -> bool:
	if not condition:
		failures += 1
		push_error("POL71: " + context)
	return condition
