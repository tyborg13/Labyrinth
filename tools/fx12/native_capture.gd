extends "res://tools/inspection_fixture.gd"
## Native framebuffer proof on the production RunScene and input/playback paths.

const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Attack = preload("res://scripts/attack_fx_library.gd")
const Fx = preload("res://scripts/tile_burst_fx.gd")
const Paths = preload("res://scripts/path_utils.gd")
const CanvasSize := Vector2i(1920, 1080)
const SinkSize := Vector2i(64, 64)
const CropSize := Vector2i(640, 480)
const Hero := Vector2i(4, 4)
const AimDirection := Vector2i(0, -1)
const WEAPONS: Dictionary = {
	"whirlwind_slash": "training_sword", "spear_thrust": "hunting_spear",
	"sweeping_haft": "hookspine_halberd", "tombsplitter": "grave_greatsword",
	"windlass_volley": "windlass_repeater",
}
const FILLER: String = "quick_stab"
const FILLER_DRAW: String = "quick_stab,quick_stab,quick_stab,quick_stab,quick_stab,quick_stab"
const HERO_HP: int = 30
const FPS: int = 60
const SECONDS: int = 4
const ENEMY_OPENING_TICK: int = 1
const READY_FRAMES: int = 360
const SETTLE_FRAMES: int = 12
const TEARDOWN_FRAMES: int = 420
const RECORDING_CARD_PLAYS: int = 2
const TAKE_LIMIT: int = 900
const SNAP_FRAMES: Array[int] = [0, 2, 4, 8, 14, 22]
const WHIRLWIND_TILE_COUNT: int = 4
const TREMOR_TILE_COUNT: int = 13
const CASES: Dictionary = {
	"whirlwind_slash": ["whirlwind_slash", "adjacent", "aoe"],
	"spear_thrust": ["spear_thrust", "adjacent", "aoe"],
	"sweeping_haft": ["sweeping_haft", "diagonal", "aoe"],
	"tombsplitter": ["tombsplitter", "adjacent", "aoe"],
	"windlass_volley": ["windlass_volley", "ranged", "aoe"],
	"shrapnel_bomb": ["nail_bomb", "ranged", "aoe"],
	"lantern_rain": ["ember_rain", "ranged", "aoe"],
	"tremor": ["tremor", "adjacent", "aoe"],
	"frost_nova": ["frost_nova", "adjacent", "aoe"],
	"thunderclap": ["thunderclap", "adjacent", "aoe"],
	"grave_mortar": ["grave_mortar", "adjacent", "aoe"],
	"cyclone_seal": ["cyclone_seal", "ranged", "aoe"],
	"immolation": ["immolation", "fire", "aoe"],
	"rime_shard": ["rime_shard", "ranged", "aoe"],
	"squall_shot": ["squall_shot", "ranged", "aoe"],
	"volt_surge": ["volt_surge", "ranged", "aoe"],
	"cinder_bloom": ["cinder_bloom", "ranged", "aoe"],
	"consumed_fire_burst": ["immolation", "fire", "detonate"],
	"terrain_burst": ["rockburst", "terrain", "burst_terrain"],
	"illusion_burst": ["shattered_reflection", "illusion", "destroy_illusion"],
	"crushing_step": ["warden:crushing_step", "adjacent", "aoe"],
	"glass_lunge": ["frostglass_lancer:glass_lunge", "ranged", "aoe"],
	"lightning_storm_strike": ["zekarion:skybreak", "ranged", "lightning_strikes"],
	"whirlwind_then_frost": ["whirlwind_slash", "adjacent", "aoe"],
}

var _plan: bool
var _measure: bool
var _record: bool
var _working: bool
var _viewport: SubViewport
var _run: Node
var _output: String
var _aim: Vector2i
var _acting_card: String
var _center := Vector2i(-1, -1)
var _timing_samples := PackedInt32Array()

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_take")

func _arg(key: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _take() -> void:
	var id: String = _arg("--case")
	_output = _arg("--out")
	_plan = OS.get_cmdline_user_args().has("--plan")
	_measure = OS.get_cmdline_user_args().has("--measure")
	_record = id == "whirlwind_then_frost"
	if not CASES.has(id) or _output.is_empty():
		_fail("Provide a known --case and --out.")
		return
	if not _plan and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or preload("res://scripts/presentation_clock.gd")._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all"):
		_fail("Native proof requires the visual probe runner, MovieWriter at 60 fps and cel look all.")
		return
	if _plan:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
		Engine.max_fps = FPS
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	Settings.save_settings(settings)

	var spec: Array = CASES[id]
	var fixture: Dictionary = _fixture(spec)
	if fixture.is_empty(): return
	var row: Dictionary = await _observe(id, spec, fixture)
	if _failed: return
	var file: FileAccess = FileAccess.open(_output.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write take.json.")
		return
	file.store_string(JSON.stringify(row, "\t"))
	print("FX-12 %s %s" % ["PLAN" if _plan else "NATIVE", JSON.stringify(row)])
	for frame: int in TEARDOWN_FRAMES:
		if not _working and not _run._animation_lock: break
		await process_frame
	_viewport.queue_free()
	await process_frame
	quit(0)

func _fixture(spec: Array) -> Dictionary:
	var delivery: PackedStringArray = str(spec[0]).split(":")
	var enemy: String = delivery[0] if delivery.size() == 2 else "crawler"
	var intent: String = delivery[1] if delivery.size() == 2 else ""
	var card: String = delivery[0] if delivery.size() == 1 else FILLER
	var recipe: String = spec[1]
	var distance: int = 1 if recipe in ["adjacent", "diagonal", "fire"] else 2
	var foe: Vector2i = Hero + AimDirection * distance
	if recipe == "diagonal": foe += Vector2i.RIGHT
	if enemy == "zekarion": foe += AimDirection
	_aim = foe
	_options = {
		"scenario": "combat", "seed": DEFAULT_SEED, "hand": card + (",frost_nova" if _record else ""),
		"draw": FILLER_DRAW, "player_hp": HERO_HP, "player_max_hp": HERO_HP,
		"player_position": _coord(Hero), "enemy_types": enemy, "enemy_intents": intent,
		"enemy_positions": _coord(foe), "umbra_stage": "clear",
	}
	if WEAPONS.has(card): _options["equip"] = "weapon=" + WEAPONS[card]
	match recipe:
		"terrain":
			_aim = Hero + AimDirection
			_options["terrain"] = "wooden_crate@" + _coord(_aim)
		"fire":
			_options["surfaces"] = "fire@" + _coord(foe)
	var progression: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = _build_run_state("combat", progression)
	if _failed or run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	if card == "whirlwind_slash":
		# The generated test room can place breakable props in the four arms.
		# Reserve those cells for the one-enemy, three-empty proof.
		state["terrain"] = (state["terrain"] as Array).filter(func(piece: Dictionary) -> bool:
			return Paths.manhattan(Hero, piece.get("pos", Hero)) != 1)
	if _record:
		state["cards_per_turn"] = maxi(int(state["cards_per_turn"]), RECORDING_CARD_PLAYS)
	if recipe == "illusion":
		_aim = foe + Vector2i.RIGHT
		state = _combat_engine._create_illusion(state, _aim, GameData.fixed_point_amount(3))
	if delivery.size() == 2:
		for actor: Dictionary in state["turn_queue"]:
			actor["time"] = ENEMY_OPENING_TICK
	if not Paths.is_passable(state["grid"], Hero) or not Paths.is_passable(state["grid"], _aim):
		_fail("Native fixture tile is outside playable floor.")
		return {}
	run["combat_state"] = state
	return {"run": run, "profile": progression, "card": card if delivery.size() == 1 else ""}

func _coord(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

func _start(fixture: Dictionary) -> bool:
	if not ProgressionStore.save_data(fixture["profile"]) or not ProgressionStore.save_run_state(fixture["run"]):
		return false
	root.size = SinkSize
	root.content_scale_size = SinkSize
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = CanvasSize
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _plan else SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_run = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_run)
	_run._close_dialogue()
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2.ONE
	_viewport.push_input(pointer, true)
	for frame: int in READY_FRAMES:
		await process_frame
		var moving: Tween = _run._board_centering_tween
		if _run.initial_presentation_is_ready() and (moving == null or not moving.is_running()): break
	for frame: int in SETTLE_FRAMES: await process_frame
	return _run._run_state.get("mode") == "combat" and _run.hand_scroll.is_visible_in_tree() and is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(_run), 1.0)

func _play(card: String) -> void:
	_working = true
	_acting_card = card
	if card.is_empty():
		await _run._on_pass_turn_pressed()
	else:
		var index: int = (_run._combat_state["deck"]["hand"] as Array).find(card)
		if _plan and index < 0: print("FX-12 PLAN CARD MISSING ", card, " ", _run._combat_state["deck"]["hand"])
		if index >= 0:
			await _run._on_card_pressed(index)
			if _plan and _run._selected_card_index < 0:
				print("FX-12 PLAN CARD REJECTED ", card, " ", _run._card_play_options_for_index(index).get("play", {}).get("reason", ""))
			for action_index: int in (_run._pending_actions as Array).size() * 2:
				if _run._pending_card_requires_confirmation() or _run._animation_lock: break
				if _run._orientation_pending():
					await _run._on_board_tile_clicked(_run._pending_orientation_target_tile + AimDirection)
					continue
				var candidates: Array[Vector2i]
				candidates.assign(_run._pending_target_tiles)
				if candidates.is_empty(): break
				candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					var da: int = Paths.manhattan(a, _aim)
					var db: int = Paths.manhattan(b, _aim)
					if da != db: return da < db
					return a.y < b.y or (a.y == b.y and a.x < b.x)
				)
				if _plan: print("FX-12 PLAN TARGET ", card, " ", candidates[0])
				await _run._on_board_tile_clicked(candidates[0])
			if _run._pending_card_requires_confirmation(): await _run._on_confirm_card_play_pressed()
	_working = false

func _observe(id: String, spec: Array, fixture: Dictionary) -> Dictionary:
	if not await _start(fixture):
		_fail("RunScene could not resume at 1920x1080 with the combat HUD.")
		return {}
	var board: Control = _run.board_view
	var strip: Image
	if not _plan: strip = Image.create_empty(CropSize.x * SNAP_FRAMES.size(), CropSize.y, false, Image.FORMAT_RGB8)
	var raw: FileAccess
	if _record and not _plan:
		raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
		if raw == null:
			_fail("Cannot open 4-second capture stream.")
			return {}
	var contact: int = -1
	var snap: int = 0
	var second: bool = false
	var second_contact: bool = false
	var has_bursts: bool = false
	var avoid_bursts: bool = id in ["cinder_bloom", "lightning_storm_strike"]
	var crop: Rect2i
	_play(fixture["card"])
	for frame: int in TAKE_LIMIT:
		await process_frame
		if not _plan: await RenderingServer.frame_post_draw
		var shown: Dictionary = board.presentation
		var effect: Dictionary = shown.get("effect", {})
		var layer: Fx = board._tile_bursts
		var stage_contact: bool = _is_contact(effect, shown, spec[2])
		if contact < 0 and stage_contact:
			contact = frame
			has_bursts = layer != null and layer.has_active()
			if not _check_sample_area(id, layer): return {}
			_center = effect.get("center", effect.get("to", _aim))
			var center: Vector2 = board.get_global_transform_with_canvas() * board.world_position_for_tile(_center)
			var corner: Vector2i = Vector2i(center.round()) - CropSize / 2
			crop = Rect2i(corner.clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)
		if _record and contact >= 0 and not second and not _working and not _run._animation_lock:
			second = true
			_play("frost_nova")
		if second and layer != null and layer.has_active() and _acting_card == "frost_nova" and effect.get("element") == "ice" and _is_contact(effect, shown, "aoe"):
			second_contact = true
		var capture_snap: bool = contact >= 0 and snap < SNAP_FRAMES.size() and frame == contact + SNAP_FRAMES[snap]
		if (capture_snap or (_record and frame < FPS * SECONDS)) and not _plan:
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Native framebuffer size differs from 1920x1080.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if _record and frame < FPS * SECONDS: raw.store_buffer(image.get_data())
			if capture_snap:
				strip.blit_rect(image, crop, Vector2i(snap * CropSize.x, 0))
				if snap == 0 and not _save(image, "native-evidence.png"): return {}
		if capture_snap: snap += 1
		if _measure and layer != null and layer.has_active(): _measure_tick(layer)
		var complete: bool = snap == SNAP_FRAMES.size() and (not _record or frame >= FPS * SECONDS - 1)
		if complete: break
		if contact < 0 and frame > SETTLE_FRAMES and not _working and not _run._animation_lock: break
	if raw != null: raw.close()
	if contact < 0 or snap != SNAP_FRAMES.size() or has_bursts == avoid_bursts or (_record and not second_contact):
		_fail("Contact contract failed for %s (contact=%d, samples=%d, bursts=%s, second=%s)." % [id, contact, snap, has_bursts, second_contact])
		return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	if _measure:
		var total: int
		for usec: int in _timing_samples: total += usec
		print("FX-12 WINDOWED CPU Tremor retained tick mean=%.5f ms samples=%d" % [float(total) / maxi(1, _timing_samples.size()) / 1000.0, _timing_samples.size()])
	return {"case": id, "contact_frame": contact, "tile": _coord(_center), "crop": str(crop), "bursts": has_bursts, "second_contact": second_contact}

func _check_sample_area(id: String, layer: Fx) -> bool:
	var expected: int = 0
	match id:
		"whirlwind_slash", "whirlwind_then_frost": expected = WHIRLWIND_TILE_COUNT
		"tremor": expected = TREMOR_TILE_COUNT
	if expected == 0: return true
	var half_count: int = layer._stamps.size() if layer != null else 0
	if half_count != expected * 2:
		_fail("Expected %d tile pairs at %s contact, got %d halves." % [expected, id, half_count])
		return false
	if id == "whirlwind_slash":
		var row: int = Fx.metadata()["rows"]["steel_hit_front"]
		var hits: int = 0
		for stamp: Fx.Stamp in layer._stamps:
			if stamp.sample.y == row: hits += 1
		if hits != 1:
			_fail("Whirlwind fixture needs one struck enemy and three empty tiles, got %d hit tiles." % hits)
			return false
	return true

func _is_contact(effect: Dictionary, shown: Dictionary, expected: String) -> bool:
	var ground: bool = bool(effect.get("ground_burst", false))
	var observed: String = str(effect.get("action_type", effect.get("kind", "")))
	if expected in ["detonate", "burst_terrain", "destroy_illusion"]:
		if not ground: return false
	elif ground or observed != expected:
		return false
	return float(shown.get("effect_progress", -1.0)) + 0.0001 >= Attack.feedback_start_progress(effect)

func _measure_tick(layer: Fx) -> void:
	# Zero delta samples the retained presentation path without altering the take.
	var start: int = Time.get_ticks_usec()
	layer.advance(0.0, -1)
	_timing_samples.append(Time.get_ticks_usec() - start)

func _save(image: Image, name: String) -> bool:
	var path: String = _output.path_join(name)
	if image.save_png(path) != OK:
		_fail("Could not save " + path)
		return false
	print(path)
	return true
