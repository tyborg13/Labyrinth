extends "res://tools/inspection_fixture.gd"
## Same fixture and contact markers for both source trees. Uses the actual
## resolver and RunScene playback at a fixed presentation clock.

const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")
const Maquette = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const CANVAS := Vector2i(1920, 1080)
const SINK := Vector2i(64, 64)
const CROP := Vector2i(640, 480)
const HERO := Vector2i(4, 4)
const ADJACENT := Vector2i(4, 3)
const FAR := Vector2i(4, 2)
const TRAP := Vector2i(5, 4)
const BRAMBLE := Vector2i(3, 4)
const FPS: int = 60
const REEL_SECONDS: int = 5
const FIRST_FRAME_LIMIT: int = 360
const TAKE_LIMIT: int = 900
const SETTLE_FRAMES: int = 12
const HERO_HP: int = 80
const CRAWLER_HP: int = 35
const FULL_BLOCK: int = 12
const BRAMBLE_HP: int = 3
const REEL_EXCHANGES: int = 3
const STAB: String = "quick_stab"
const SNAP: Array[int] = [0, 2, 4, 8, 14, 22]
const PLAYER_CARDS: Dictionary = {
	"strike": STAB, "block": STAB, "push_wall": "haft_shove", "push_unit": "haft_shove",
	"pull_prop": "yank", "trap": "guarded_step", "hurl_spear": "hurl_spear", "recording": STAB,
}
const ENEMY_CASES: Dictionary = {
	"bite": ["crawler", "skitter_strike"], "surgeon": ["grave_surgeon", "saw_jab"],
	"dive": ["burrow_grub", "burrow"], "erupt": ["burrow_grub", "erupt"],
	"shadow": ["veilbound_acolyte", "closing_shade"],
}

var _plan: bool
var _variant: String
var _viewport: SubViewport
var _run: Node
var _output: String
var _take_id: String
var _action_done: bool
var _complete_frame: int = -1
var _started_frame: int
var _center: Vector2i
var _expected_tiles: Array[Vector2i]

class PlanFrame extends Node:
	signal presented

	func _process(_delta: float) -> void:
		presented.emit()

class FixedPacing extends CombatPacing:
	func _sync_clock() -> void:
		_clock_usec += _movie_clock.advance(Engine.get_process_frames(), 1.0 / FPS, Engine.time_scale, is_inside_tree() and get_tree().paused)

var _plan_frame: PlanFrame

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run_take")

func _arg(key: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _run_take() -> void:
	_take_id = _arg("--case")
	_output = _arg("--out")
	_variant = _arg("--variant")
	_plan = OS.get_cmdline_user_args().has("--plan")
	if (_take_id not in ["ice_break", "bramble"] and not PLAYER_CARDS.has(_take_id) and not ENEMY_CASES.has(_take_id)) or _output.is_empty():
		_fail("FX-17 requires a known case and output directory.")
		return
	if _plan:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
		_plan_frame = PlanFrame.new()
		_plan_frame.process_priority = 1000
		root.add_child(_plan_frame)
	else:
		if DisplayServer.get_name() == "headless" or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
			_fail("FX-17 native proof requires the real renderer with cel look on.")
			return
		if Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS:
			_fail("FX-17 requires a fixed 60 fps MovieWriter clock.")
			return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	var fixture: Dictionary = _fixture()
	if fixture.is_empty() or _failed: return
	if not await _start(fixture):
		_fail("FX-17 RunScene failed to present with its full-size combat HUD.")
		return
	var evidence: Dictionary = await _capture(fixture["run"]["combat_state"])
	if _failed: return
	var report: String = _output.path_join("take.json")
	var file: FileAccess = FileAccess.open(report, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write " + report)
		return
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print("FX-17 %s %s %s" % ["PLAN" if _plan else "NATIVE", JSON.stringify(evidence), report])
	_viewport.queue_free()
	await process_frame
	quit(0)

func _coord(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

func _fixture() -> Dictionary:
	var target: Vector2i = FAR if _take_id in ["pull_prop", "hurl_spear", "erupt"] else ADJACENT
	var enemy: Array = ENEMY_CASES.get(_take_id, ["crawler", "skitter_strike"])
	var card: String = PLAYER_CARDS.get(_take_id, STAB)
	_options = {
		"scenario": "combat", "seed": DEFAULT_SEED, "hand": card, "draw": "%s,%s,%s" % [STAB, STAB, STAB],
		"player_hp": HERO_HP, "player_max_hp": HERO_HP, "player_position": _coord(HERO),
		"enemy_types": enemy[0], "enemy_intents": enemy[1], "enemy_positions": _coord(target),
		"umbra_stage": "clear",
	}
	if _take_id == "push_unit":
		_options["enemy_types"] = "crawler,crawler"
		_options["enemy_intents"] = "skitter_strike,skitter_strike"
		_options["enemy_positions"] += "," + _coord(FAR)
	if _take_id == "trap":
		_options["trap_elements"] = "ice"
		_options["trap_positions"] = _coord(TRAP)
	var progression: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = _build_run_state("combat", progression)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	state["terrain"] = []
	for foe: Dictionary in state["enemies"]:
		foe["hp"] = GameData.fixed_point_amount(CRAWLER_HP)
		foe["max_hp"] = foe["hp"]
	match _take_id:
		"block":
			state["enemies"][0]["block"] = GameData.fixed_point_amount(FULL_BLOCK)
		"push_wall":
			state["grid"][FAR.y][FAR.x] = "wall"
		"pull_prop":
			Terrain.raise_outcrop(_combat_engine, state, ADJACENT, GameData.fixed_point_amount(CRAWLER_HP), {}, {"kind": "wooden_crate", "blocks_sight": false})
		"ice_break":
			BoardSurfaceRules.place(state, TRAP, "ice")
		"erupt":
			state["enemies"][0].merge({"burrowed": true, "erupt_tile": HERO}, true)
	_center = target
	match _take_id:
		"bite", "surgeon", "erupt", "shadow": _center = HERO
		"ice_break", "trap": _center = TRAP
		"bramble": _center = BRAMBLE
	_expected_tiles.assign([_center, FAR] if _take_id == "push_unit" else [_center])
	return {"run": run, "profile": progression}

func _start(fixture: Dictionary) -> bool:
	if not ProgressionStore.save_data(fixture["profile"]) or not ProgressionStore.save_run_state(fixture["run"]): return false
	root.size = SINK
	root.content_scale_size = SINK
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = CANVAS
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _plan else SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_run = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	if _plan:
		_run._combat_pacing.free()
		_run._combat_pacing = FixedPacing.new()
		_run._combat_pacing.install(_run)
	_viewport.add_child(_run)
	_run._close_dialogue()
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2.ONE
	_viewport.push_input(pointer, true)
	for frame: int in FIRST_FRAME_LIMIT:
		await process_frame
		var moving: Tween = _run._board_centering_tween
		if _run.initial_presentation_is_ready() and (moving == null or not moving.is_running()): break
	for frame: int in SETTLE_FRAMES: await process_frame
	return _run._run_state.get("mode") == "combat" and _run.hand_scroll.is_visible_in_tree() and is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(_run), 1.0)

func _play(state: Dictionary) -> void:
	_started_frame = Engine.get_process_frames()
	if PLAYER_CARDS.has(_take_id):
		var card: String = PLAYER_CARDS[_take_id]
		var at: Vector2i = FAR if _take_id in ["hurl_spear", "pull_prop"] else TRAP if _take_id == "trap" else ADJACENT
		for exchange: int in REEL_EXCHANGES if _take_id == "recording" else 1:
			state = await _play_card(state, card, at)
			if _take_id == "recording": state = await _enemy_action(state)
	elif ENEMY_CASES.has(_take_id):
		await _enemy_action(state)
	elif _take_id == "ice_break":
		var after: Dictionary = state.duplicate(true)
		BoardSurfaceRules.remove(after, _center, "ice", "fx17_fixture")
		if _variant == "after": _run._resolved_contact_bursts.begin(state)
		await _run._animate_surface_change(state, after)
	elif _take_id == "bramble":
		# Archived bramble data still travels through RunScene's compatibility
		# entry point. Current Thornwall resolves as an Upheaval outcrop.
		var after: Dictionary = state.duplicate(true)
		Terrain.raise_outcrop(_combat_engine, after, _center, GameData.fixed_point_amount(BRAMBLE_HP), {}, {"kind": "bramble", "rounds_left": 1})
		var tiles: Array[Vector2i] = [_center]
		var steps: Array[Dictionary] = [{"kind": "surface", "en04_mechanic": "grow_bramble", "tiles": tiles, "en04_state_after": after}]
		await _run._animate_enemy_phase_steps(state, steps)
	_complete_frame = Engine.get_process_frames() - _started_frame
	_action_done = true

func _play_card(state: Dictionary, card: String, tile: Vector2i) -> Dictionary:
	var action: Dictionary = GameData.card_def(card)["actions"][0]
	var resolved: Dictionary = _combat_engine.resolve_player_action_for_presentation(state, action, tile)
	var after: Dictionary = resolved["state"]
	_run._combat_pacing.begin_card()
	await _run._animate_player_action_step(state, after, card, action, tile, resolved["chain_hits"])
	_run._combat_pacing.end_scope()
	return after

func _enemy_action(state: Dictionary) -> Dictionary:
	var enemy: Dictionary = state["enemies"][0]
	var action: Dictionary = {}
	for entry: Dictionary in enemy["intent"]["actions"]:
		if entry.get("type", "") in ["melee", "ranged", "burrow", "erupt"]: action = entry
	if action.is_empty():
		_fail("Missing attack action in " + str(enemy["intent"]))
		return state
	var context: Dictionary = {}
	var after: Dictionary = _combat_engine._resolve_enemy_action(state.duplicate(true), 0, action, null, {}, preload("res://scripts/typed_arrays.gd").dictionaries([]), context)
	var step: Dictionary = _combat_engine._enemy_action_step(state, after, 0, action, context)
	if step.is_empty():
		_fail("Resolver emitted no action for " + _take_id)
		return state
	var steps: Array[Dictionary] = [step]
	_run._combat_pacing.begin_enemies()
	await _run._animate_enemy_phase_steps(state, steps)
	_run._combat_pacing.end_scope()
	return after

func _is_contact(shown: Dictionary) -> bool:
	match _take_id:
		"dive":
			for motion: Dictionary in shown.get("burrow_grub_motion", {}).values():
				if float(motion.get("phase", 0.0)) >= float(Maquette.data_for("burrow_grub")["clips"]["burrow"].get("contact", 1.0)): return true
			return false
		"bramble": return shown.get("effect", {}).get("en04_mechanic") == "grow_bramble"
		"ice_break", "trap", "pull_prop", "push_unit", "push_wall":
			var kind: String = "surface_removed" if _take_id == "ice_break" else "trap_triggered" if _take_id == "trap" else "force_collision"
			for event: Dictionary in shown.get("surface_feedback_events", []):
				if event.get("kind") == kind:
					_center = event.get("anchor", event["tile"]) if kind == "force_collision" else event["tile"]
					_expected_tiles[0] = _center
					return true
			return false
	for entry: Dictionary in shown.get("floating_texts", []):
		if str(entry.get("reaction", "")) in ["hit", "block"] and float(entry.get("alpha", 1.0)) > 0.0:
			return true
	return false

func _capture(state: Dictionary) -> Dictionary:
	var board: Control = _run.board_view
	var strip: Image
	var raw: FileAccess
	if not _plan:
		strip = Image.create_empty(CROP.x * SNAP.size(), CROP.y, false, Image.FORMAT_RGB8)
		if _take_id == "recording":
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Cannot open proof movie stream.")
				return {}
	var contact_frame: int = -1
	var snap_index: int = 0
	var crop: Rect2i
	var sampled_tiles: Array[Vector2i]
	var contact_rows: Dictionary
	var saw_legacy_decal: bool
	_play(state.duplicate(true))
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else: await RenderingServer.frame_post_draw
		if contact_frame == -1 and _is_contact(board.presentation):
			contact_frame = frame
			var center: Vector2 = board.get_global_transform_with_canvas() * board.world_position_for_tile(_center)
			crop = Rect2i((Vector2i(center.round()) - CROP / 2).clamp(Vector2i.ZERO, CANVAS - CROP), CROP)
			if board._tile_bursts != null:
				for stamp: Node2D in board._tile_bursts._stamps:
					if stamp.front: continue
					if not sampled_tiles.has(stamp.tile): sampled_tiles.append(stamp.tile)
					var tile_key: String = _coord(stamp.tile)
					if not contact_rows.has(tile_key): contact_rows[tile_key] = []
					contact_rows[tile_key].append(stamp.sample.y)
		if contact_frame >= 0 and not _action_done:
			for decal: Dictionary in board.presentation.get("impact_decals", []):
				if _expected_tiles.has(decal.get("tile")): saw_legacy_decal = true
		var sample: bool = contact_frame >= 0 and snap_index < SNAP.size() and frame == contact_frame + SNAP[snap_index]
		var record: bool = raw != null and frame < FPS * REEL_SECONDS
		if not _plan and (sample or record):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CANVAS:
				_fail("FX-17 expected a 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if record: raw.store_buffer(image.get_data())
			if sample:
				strip.blit_rect(image, crop, Vector2i(snap_index * CROP.x, 0))
				if snap_index == 0 and not _save(image, "contact.png"): return {}
		if sample: snap_index += 1
		if _failed: return {}
		if _action_done and snap_index == SNAP.size() and (_take_id != "recording" or frame >= FPS * REEL_SECONDS - 1): break
		if _action_done and contact_frame < 0: break
	if raw != null: raw.close()
	if contact_frame < 0 or snap_index != SNAP.size() or not _action_done:
		_fail("FX-17 %s did not reach contact, all samples, and settled action (frame %d, samples %d, done %s)." % [_take_id, contact_frame, snap_index, _action_done])
		return {}
	var expected_burst: bool = _variant == "after" and _take_id != "shadow"
	if _variant == "after":
		for tile_key: String in contact_rows:
			if contact_rows[tile_key].size() != 1:
				_fail("FX-17 %s submitted more than one rear stamp for %s." % [_take_id, tile_key])
				return {}
	if expected_burst:
		if saw_legacy_decal:
			_fail("FX-17 %s submitted a legacy decal on the contact tile." % _take_id)
			return {}
		for tile: Vector2i in _expected_tiles:
			if not sampled_tiles.has(tile):
				_fail("FX-17 %s missing expected contact stamp on %s at %d, saw %s." % [_take_id, tile, contact_frame, sampled_tiles])
				return {}
	elif _take_id == "shadow" and not sampled_tiles.is_empty():
		_fail("FX-17 shadow unexpectedly stamped the tile.")
		return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	var tiles: Array[String]
	for tile: Vector2i in sampled_tiles: tiles.append(_coord(tile))
	return {"case": _take_id, "variant": _variant, "contact_frame": contact_frame, "action_frames": _complete_frame,
		"center": _coord(_center), "crop": str(crop), "stamped": tiles, "contact_rows": contact_rows,
		"legacy_decal": saw_legacy_decal, "snap_frames": SNAP}

func _save(image: Image, name: String) -> bool:
	var path: String = _output.path_join(name)
	if image.save_png(path) != OK:
		_fail("Cannot write " + path)
		return false
	print(path)
	return true
