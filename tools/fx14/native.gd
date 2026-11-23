extends SceneTree
## Exact production RunScene samples. No window is opened by --validate-fixture.

const Fixtures = preload("res://tools/fx14/fixtures.gd")
const Shot = preload("res://scripts/shot_fx.gd")
const Attack = preload("res://scripts/attack_fx_library.gd")
const Run = preload("res://scripts/run_scene.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Facing = preload("res://scripts/hero_facing_state.gd")
const ENTRY_SEED: int = 8585
const ROOM_ENTRY_SETTLE_SECONDS: float = 0.95
const VIEW := Vector2i(1920, 1080)
const CROP := Vector2i(640, 480)
const FPS: int = 60
const REEL_SECONDS: int = 4
const OUTPUT: String = "user://fx14-native"
const LABELS := ["release", "travel35", "travel70", "contact", "contact066", "contact166"]
const MOVIE_CASES := ["hurl_spear", "snake_eyes", "icicle_lance"]
const PULL_END := Vector2i(4, 4)
const PULL_PROOF_TAIL_FRACTION: float = 0.40

var _viewport: SubViewport
var _scene: Run
var _board: Control
var _fx: Shot
var _cases: Dictionary
var _state: Dictionary
var _effect: Dictionary
var _id: String
var _elapsed: float
var _contact: float
var _duration: float
var _release: float
var _hit_seen: bool
var _rear_samples: PackedStringArray
var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var headless: bool = "--validate-fixture" in OS.get_cmdline_user_args()
	Progression.set_storage_path("user://fx14-proof-progression.json")
	Progression.set_run_storage_path("user://fx14-proof-run.save")
	Settings.set_storage_path("user://fx14-proof-settings.json")
	Progression.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	if not headless:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		root.size = VIEW
		_expect(Cel.mode == "all" and FileAccess.file_exists("res://cel_look_variants/manifest.json"), "Director proof requires the cel look")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + "/reel"))
		await _verify_shader_pixels()
	_cases = Fixtures.cases()
	await _open_fight()
	if _scene == null or _board == null or _fx == null:
		_finish()
		return
	for id: String in _cases:
		await _install_case(id)
		if headless:
			for seconds: float in _strip_samples():
				_sample(seconds)
			_report_depth_samples()
		else:
			await _save_strip()
	if not headless:
		await _save_reel()
		print(ProjectSettings.globalize_path(OUTPUT))
	_fx = null
	_board = null
	_scene = null
	_viewport.queue_free()
	_viewport = null
	await process_frame
	await process_frame
	_finish()

func _finish() -> void:
	for error: String in _errors:
		push_error(error)
	print("FX-14 NATIVE %s: %s (%d cases, %d failures)" % [
		"FIXTURE" if "--validate-fixture" in OS.get_cmdline_user_args() else "CAPTURE",
		"PASS" if _errors.is_empty() else "FAIL", _cases.size(), _errors.size(),
	])
	quit(0 if _errors.is_empty() else 1)

func _open_fight() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW
	if DisplayServer.get_name() != "headless":
		_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_scene = packed.instantiate() as Run
	_viewport.add_child(_scene)
	await process_frame
	await process_frame
	var engine := RunEngine.new()
	_scene._load_run_state(engine.create_new_run(ENTRY_SEED, Progression.default_data()))
	await process_frame
	await process_frame
	var room := Vector2i.ZERO
	for coord: Vector2i in engine.available_moves(_scene._run_state):
		if engine.room_metadata(_scene._run_state, coord).get("type") == "combat":
			room = coord
			break
	_expect(room != Vector2i.ZERO, "Director fixture finds a combat room")
	if room == Vector2i.ZERO:
		return
	await _scene._on_map_view_room_selected(room)
	if _scene._pre_battle_scrim.visible:
		await _scene._on_pre_battle_start_pressed()
	await create_timer(ROOM_ENTRY_SETTLE_SECONDS).timeout
	await process_frame
	await process_frame
	_scene._close_dialogue()
	_board = _scene.get_node("BoardUnderlay/CombatBoard")
	_board.set_process(false)
	_fx = _board.get("_single_shot_fx")
	_expect(_scene._run_state.get("mode") == "combat" and _scene.hand_scroll.is_visible_in_tree(), "RunScene has a live combat HUD")
	_expect(_viewport.size == VIEW and is_equal_approx(root.content_scale_factor, 1.0), "Proof is 1920×1080 at 100% UI scale")

func _install_case(id: String) -> void:
	_id = id
	_elapsed = 0.0
	_hit_seen = false
	_rear_samples.clear()
	_effect = (_cases[id] as Dictionary).duplicate(false)
	_state = Fixtures.state_for(_effect)
	_scene._run_state["current_room_layout"] = Fixtures.layout_for(_effect)
	_scene._run_state["combat_state"] = _state
	_scene._combat_state = _state
	_scene._hero_facing.reset(_state, Settings.hero_facing_mode(_scene._settings) == "persist")
	var worn: Dictionary = _scene._run_state.get("equipped_equipment", {}).duplicate()
	if id == "dull_bolt_bow":
		worn["weapon"] = Fixtures.BOW
	else:
		worn.erase("weapon")
	_scene._run_state["equipped_equipment"] = worn
	_scene._reset_card_resolution()
	_scene._close_dialogue()
	_scene._refresh_ui()
	_scene._render_board_state(_state, {})
	_fx.advance(1.0)
	if bool(_effect.get("hidden_by_umbra", false)):
		_effect = _scene._visible_umbra_action_step(_state, _effect)
		var segments: Array = _effect.get("umbra_visible_line_segments", [])
		_expect(not segments.is_empty() and float(segments[0]["start"]) > 0.0, "Umbra fixture conceals the launch and exposes the target")
	var expected: String = Shot.resolve(_effect)
	_expect(not expected.is_empty(), id + " uses a director shot")
	if _effect.has("base_card_id"):
		var card: String = _effect["base_card_id"]
		# The strip samples the action clock directly. RunScene normally turns
		# the hero via this same call before publishing the ranged preparation.
		_scene._hero_facing.begin_action(_scene._combat_engine, _state, Fixtures.card_action(card), _effect["to"])
		_scene._begin_action_step_resolution_tracker(card, Fixtures.cards()[card]["actions"], [Fixtures.TARGET], false)
		_effect.erase("base_card_id")
	_expect(not bool(_scene._controller_modal_visible()), id + " has no modal covering combat")
	_release = Shot.release_for(Attack.style_for_effect(_effect))
	_contact = Shot.contact_for(_effect)
	_duration = float(Attack.animation_frame_count(_effect, Run.ATTACK_FRAMES, false)) * Attack.animation_frame_seconds(_effect, Run.ATTACK_FRAME_SECONDS, false)
	await process_frame
	_sample(0.0)
	_expect(_fx._shot_id == expected, id + " resolves through the production board descriptor")

func _sample(seconds: float) -> void:
	_fx.advance(maxf(0.0, seconds - _elapsed))
	_elapsed = seconds
	var t: float = clampf(seconds / _duration, 0.0, 1.0)
	var shown: Dictionary = {"effect": _effect, "effect_progress": t}
	if seconds >= _contact * _duration:
		shown["impact_actor_keys"] = ["player" if _effect.has("enemy_type") else "enemy_1"]
	if _id == "vacuum_line" and t >= _contact:
		# Debug-only body samples exercise the existing presentation seam for
		# motion. The committed displacement in the game remains untouched.
		var fraction: float = clampf((t - _contact) / ((1.0 - _contact) * PULL_PROOF_TAIL_FRACTION), 0.0, 1.0)
		shown["unit_world_positions"] = {"enemy_1": _board._tile_center(Fixtures.TARGET).lerp(_board._tile_center(PULL_END), fraction)}
	_scene._render_board_state(_state, shown)
	if is_equal_approx(t, _release) and _effect.has("protagonist_origin"):
		var target_delta: Vector2i = _effect["to"] - _effect["from"]
		var wanted: Dictionary = Facing.direction(target_delta, Facing.FRONT)
		var renderer: Node = _board._protagonist_renderer
		_expect(renderer.facing == wanted["facing"] and renderer.mirrored == wanted["mirrored"], _id + " faces the target at release")
	if seconds >= _contact * _duration and not _hit_seen:
		_hit_seen = true
		_expect(_fx._hits[0].visible or _fx._hits[1].visible, _id + " emits a visible hit at contact")
	_record_depth_sample(seconds)

func _strip_samples() -> Array[float]:
	var contact_time: float = _contact * _duration
	var samples: Array[float] = [
		_release * _duration, lerpf(_release, _contact, 0.35) * _duration,
		lerpf(_release, _contact, 0.70) * _duration, contact_time, contact_time + 0.066, contact_time + 0.166,
	]
	return samples

func _record_depth_sample(seconds: float) -> void:
	var label: int = _strip_samples().find(seconds)
	if label < 0:
		return
	var rear: PackedStringArray
	for head: Shot.Stamp in _fx._heads:
		if head.visible and head.get_parent() != _fx._above_bodies:
			rear.append("head" if head == _fx._heads[0] else "second head")
	if _fx._links.visible and _fx._links.get_parent() != _fx._above_bodies:
		rear.append("chain")
	if not rear.is_empty():
		_rear_samples.append("%s (%s)" % [LABELS[label], ", ".join(rear)])

func _report_depth_samples() -> void:
	print("FX-14 STRIP DEPTH %s: %s" % [_id, "front only" if _rear_samples.is_empty() else "; ".join(_rear_samples)])

func _save_strip() -> void:
	var from: Vector2i = _effect.get("umbra_original_from", _effect["from"])
	var to: Vector2i = _effect.get("umbra_original_to", _effect["to"])
	var local_center: Vector2 = _board._tile_center(from).lerp(_board._tile_center(to), 0.5)
	var center: Vector2 = _board.get_global_transform_with_canvas() * local_center
	var start := Vector2i(center.round()) - CROP / 2
	start = start.clamp(Vector2i.ZERO, VIEW - CROP)
	var strip := Image.create_empty(CROP.x * LABELS.size(), CROP.y, false, Image.FORMAT_RGBA8)
	var samples: Array[float] = _strip_samples()
	for index: int in samples.size():
		_sample(samples[index])
		var frame: Image = await _drawn_image()
		if frame == null:
			return
		_expect(frame.save_png("%s/%s_%s.png" % [OUTPUT, _id, LABELS[index]]) == OK, "Save native frame for " + _id)
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(start, CROP), Vector2i(index * CROP.x, 0))
	_expect(strip.save_png("%s/%s_strip.png" % [OUTPUT, _id]) == OK, "Save native strip for " + _id)
	_report_depth_samples()

func _save_reel() -> void:
	var segment_frames: int = FPS * REEL_SECONDS / MOVIE_CASES.size()
	var frame_index: int = 0
	for id: String in MOVIE_CASES:
		await _install_case(id)
		for index: int in segment_frames:
			var seconds: float = float(index) / FPS
			var contact_time: float = _contact * _duration
			if _elapsed < contact_time and seconds >= contact_time:
				_sample(contact_time)
			_sample(seconds)
			var image: Image = await _drawn_image()
			if image == null:
				return
			_expect(image.save_png("%s/reel/%04d.png" % [OUTPUT, frame_index]) == OK, "Save movie frame %d" % frame_index)
			frame_index += 1
	_expect(frame_index == FPS * REEL_SECONDS, "The three-case movie is four seconds")

func _drawn_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_expect(frame != null and frame.get_size() == VIEW, "Native screenshot has the exact framebuffer size")
	return frame

func _verify_shader_pixels() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(320, 240)
	stage.transparent_bg = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	var size: Dictionary = Shot.metadata()["sizes"][1]
	var atlas: Image = Shot._read_sheet(size["atlas"]) as Image
	var material := ShaderMaterial.new()
	material.shader = Shot.SHADER
	material.set_shader_parameter("atlas", ImageTexture.create_from_image(atlas))
	material.set_shader_parameter("palette", Shot._palette)
	material.set_shader_parameter("cell_px", 2.0)
	material.set_shader_parameter("warming", false)
	var stamp := Shot.Stamp.new()
	stage.add_child(stamp)
	stamp.material = material
	var center := Vector2(160, 120)
	var frame: Vector3i = Shot.frame_rect(size["shots"]["arrow"], Vector2.RIGHT, 0.0, 0.0)
	for clipped: bool in [false, true]:
		var spans := PackedVector2Array()
		spans.resize(Shot.MAX_VISIBLE_SPANS)
		spans[0] = Vector2(0.48, 0.52)
		material.set_shader_parameter("visible_spans", spans)
		material.set_shader_parameter("visible_span_count", 1)
		stamp.show_frame(center + Vector2(0.37, 0.81), frame, Vector2(2, 2), Vector4(100, 0, 0.5, 0.5), Vector2.ZERO, Shot.SINGLE, 0.0, clipped)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = stage.get_texture().get_image()
		var errors: int = 0
		for y: int in frame.z:
			for x: int in frame.z:
				var index: int = roundi(atlas.get_pixel(frame.x + x, frame.y + y).r * 255.0)
				if clipped and absf(2.0 * x + 1.0 - frame.z) > 2.0:
					index = 0
				var target: Color = Shot._palette[index]
				for fy: int in 2:
					for fx: int in 2:
						var actual: Color = image.get_pixel(int(center.x) - frame.z + x * 2 + fx, int(center.y) - frame.z + y * 2 + fy)
						if actual.to_rgba32() != target.to_rgba32():
							errors += 1
		_expect(errors == 0, "Native shader %s matches the director pixels (%d mismatches)" % ["Umbra clip" if clipped else "frame", errors])
	stage.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
