extends SceneTree

## Resolve real card and enemy actions, then sample the production RunScene
## feedback at fixed points. This same script runs against the base checkout.
const Combat = preload("res://scripts/combat_engine.gd")
const Floats = preload("res://scripts/floating_combat_text.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Elements = preload("res://scripts/element_data.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const CROP_SIZE := Vector2i(640, 480)
const UI_SCALE: float = 1.0
const SEED: int = 70101
const GRID_SIDE: int = 8
const HERO := Vector2i(3, 4)
const FOE := Vector2i(4, 4)
const ILLUSION := Vector2i(3, 3)
const MAX_HEALTH: int = 24
const START_HEALTH: int = 8
const FOE_HEALTH: int = 30
const DEFENSE_HITS: Dictionary = {"stoneskin_loss": 4, "block_loss": 6, "defiance": 20}
const VIEW_WARMUP_FRAMES: int = 8
const CAPTURE_PHASES: Dictionary = {"peak": 0.0, "settle": Floats.DAMAGE_SETTLE_PROGRESS}
const HAND: Array = ["stone_plate", "brace", "last_light", "daybreak", "mirror_charm"]
const DRAW_PILE: Array = ["quick_stab", "whetstone", "throwing_net", "brace"]
const ATTACK_BUFF_PROOF_CARD: String = "whetstone"
const EXPECTED: Dictionary = {
	"stone_plate": ["stoneskin", "+4", "+4 S"],
	"brace": ["block", "+6", "+6"],
	"glass_mending": ["heal", "+3", "+3"],
	"draw_two": ["draw", "+2", "+2 draw"],
	"card_play": ["card_play", "+1", "+1 Card Play"],
	"illusion": ["", "", "+5 illusion"],
	"block_loss": ["block", "−6", "−6 B"],
	"stoneskin_loss": ["stoneskin", "−4", "−4 S"],
	"stagger": ["stagger", "Stagger +3", "Stagger +3"],
	"strength_buff": ["next_attack", "+4", "+4"],
	"defiance": ["defiance", "DEFIANCE +6 · 0 LEFT", "DEFIANCE +6 · 0 LEFT"],
	"light": ["illuminate", "Light 4", "Light 4"],
	"conversion": ["stoneskin", "+6", "+6 S"],
	"no_block": ["", "No Block", "No Block"],
}
const COLORS: Dictionary = {
	"block": "90d9ff", "heal": "9ee27e", "draw": "f1d18b", "card_play": "ffe27a",
}

class ProofScene extends "res://scripts/run_scene.gd":
	var native: bool
	var beat: Callable

	func _ready() -> void:
		if native: super._ready()

	func _render_board_state(state: Dictionary, presentation: Dictionary, stable: bool = false) -> void:
		if native: super._render_board_state(state, presentation, stable)

	func _ensure_sfx_bank() -> void:
		if native:
			super._ensure_sfx_bank()
		elif _sfx_router == null:
			_sfx_router = preload("res://scripts/sfx_cue_router.gd").new(null)

	func _set_action_banner(text: String) -> void:
		if native: super._set_action_banner(text)

	func _animate_floating_text_presentation(state: Dictionary, presentation: Dictionary, _elapsed: float = 0.0, overlap: bool = false, _companion: Dictionary = {}) -> void:
		await beat.call(state, presentation, overlap)

	func _play_timed_animation_frames(count: int, _seconds: float, render_frame: Callable) -> void:
		render_frame.call(count)

	func _animate_turn_order_alongside_defeats(_before: Dictionary, _after: Dictionary, _presentation: Dictionary = {}, _skip_terrain: bool = false, _order_before: Dictionary = {}) -> void:
		pass

	func _animate_board_pickup_acquisitions(_before: Dictionary, _after: Dictionary) -> void:
		pass


var _native: bool
var _base: bool
var _capture_directory: String
var _scene: ProofScene
var _viewport: SubViewport
var _engine := Combat.new()
var _fight: Dictionary
var _case: String
var _checked_cases: Dictionary = {}
var _entries: int
var _captures: int
var _failures: Array[String]
var _old_labels := RegEx.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_native = DisplayServer.get_name() != "headless"
	_base = OS.get_environment("LABYRINTH_FLT01_VARIANT") == "before"
	_capture_directory = OS.get_environment("LABYRINTH_FLT01_OUTPUT")
	_old_labels.compile("[+−]\\d+ [A-Z]\\b")
	_fight = _create_fight()
	if _native:
		_setup_native()
		await _settle()
		_scene.call("_load_run_state", RunEngine.new().create_new_run(SEED, Progression.default_data()))
		_scene.call("_close_dialogue")
		_install_state()
		await _settle()
		_expect(_scene.get_viewport_rect().size == Vector2(VIEWPORT_SIZE), "Viewport must be 1920×1080")
		_expect(_scene._settings["ui_scale"] == UI_SCALE and _scene.get_node("UiLayer/UiRoot").is_visible_in_tree(), "HUD must be visible at 100% scale")
	else:
		_attach_scene(root)

	await _card("stone_plate", {"stoneskin": "stone_plate"})
	await _hit("stoneskin_loss")
	await _card("brace", {"block": "brace"})
	await _hit("block_loss")
	await _card("last_light", {"heal": "glass_mending"})
	await _card("daybreak", {"draw": "draw_two", "card_play": "card_play", "illuminate": "light"}, HERO)
	await _card("mirror_charm", {"illusion": "illusion"}, ILLUSION)
	await _card("throwing_net", {}, FOE)
	await _card(ATTACK_BUFF_PROOF_CARD, {"next_attack": "strength_buff"})
	await _hit("defiance")
	await _card("shrug_off", {"convert_block_to_stoneskin": "no_block"}, Vector2i(-1, -1), true)
	await _card("brace", {})
	await _card("shrug_off", {"convert_block_to_stoneskin": "conversion"}, Vector2i(-1, -1), true)
	for key: String in EXPECTED:
		_expect(int(_checked_cases.get(key, 0)) == 1, "Expected one production beat for " + key)
	if _native:
		_expect(_captures == 22, "Eleven rows must each have two native samples")
		print(_capture_directory)
	for failure: String in _failures: push_error(failure)
	print("FLT-01 FIGHT: %s (%d cases, %d entries, %d native samples, %d failures)" % [
		"PASS" if _failures.is_empty() else "FAIL", _checked_cases.size(), _entries, _captures, _failures.size()
	])
	_scene.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _create_fight() -> Dictionary:
	var grid: Array = []
	for y: int in range(GRID_SIDE):
		var row: Array = []
		for x: int in range(GRID_SIDE):
			row.append("wall" if x in [0, GRID_SIDE - 1] or y in [0, GRID_SIDE - 1] else "stone")
		grid.append(row)
	var room := {
		"name": "Cinder Crossing", "type": "combat", "coord": Vector2i.ZERO, "grid": grid, "player_start": HERO,
		"enemies": [{"id": 1, "type": "crawler", "pos": FOE, "hp": FOE_HEALTH, "max_hp": FOE_HEALTH}],
		"terrain": [], "traps": [], "loot": [],
	}
	var state: Dictionary = _engine.create_combat(SEED, room, {
		"hp": START_HEALTH, "max_hp": MAX_HEALTH, "deck_cards": HAND, "hand_size": HAND.size(),
		"relics": [], "defiance_capacity": 1, "defiance_remaining": 1,
	})
	state["deck"]["hand"] = HAND.duplicate()
	state["deck"]["draw"] = DRAW_PILE.duplicate()
	state["deck"]["discard"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	return {"room": room, "state": state}

func _setup_native() -> void:
	Progression.set_storage_path("user://flt01-progression.json")
	Progression.set_run_storage_path("user://flt01-run.save")
	Settings.set_storage_path("user://flt01-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = false
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	_expect(not _capture_directory.is_empty(), "The native runner provides an output path")
	DirAccess.make_dir_recursive_absolute(_capture_directory)
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var display := TextureRect.new()
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attach_scene(_viewport)

func _attach_scene(parent: Node) -> void:
	var instance: Control = load("res://scenes/run_scene.tscn").instantiate()
	instance.set_script(ProofScene)
	_scene = instance as ProofScene
	_scene.native = _native
	_scene.beat = _observe_beat
	parent.add_child(_scene)

func _install_state() -> void:
	var state: Dictionary = _fight["state"]
	var run: Dictionary = _scene._run_state.duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = _fight["room"]["coord"]
	run["current_room_layout"] = _fight["room"]
	run["combat_state"] = state
	_scene._run_state = run
	_scene._combat_state = state
	_scene._animation_lock = false
	_scene._refresh_ui()

func _card(id: String, named_steps: Dictionary, target: Vector2i = Vector2i(-1, -1), named_only: bool = false) -> void:
	var state: Dictionary = _fight["state"]
	var actions: Array = _engine.card_play_actions(id, state)
	_expect(not actions.is_empty(), id + " has production actions")
	if actions.is_empty(): return
	var index: int = (state["deck"]["hand"] as Array).find(id)
	if index >= 0: state = _engine.prepare_player_card(state, index)
	for action: Dictionary in actions:
		var kind: String = action["type"]
		if named_only and not named_steps.has(kind): continue
		_case = str(named_steps.get(kind, ""))
		var before: Dictionary = state
		var resolved: Dictionary = _engine.resolve_player_action_for_presentation(before, action, target)
		state = resolved["state"]
		_scene._combat_state = state
		await _scene._animate_player_action_step(before, state, id, action, target, resolved["chain_hits"])
		if id == "throwing_net":
			_case = "stagger"
			await _scene._animate_floating_text_presentation(state, {"floating_texts": _scene._stagger_floating_texts(before, state)})
	if index >= 0: state = _engine.finish_player_card(state, index)
	_fight["state"] = state

func _hit(key: String) -> void:
	_case = key
	var state: Dictionary = _fight["state"]
	var attack := {"type": "melee", "range": 1, "damage": DEFENSE_HITS[key], "target": "player"}
	var after: Dictionary = _engine._resolve_enemy_action(state.duplicate(true), 0, attack)
	var step: Dictionary = _engine._enemy_action_step(state, after, 0, attack)
	_scene._combat_state = after
	await _scene._animate_floating_text_presentation(after, {"floating_texts": _scene._floating_texts_for_step(step)})
	_fight["state"] = after
	if key != "defiance":
		_expect(after["player"]["hp"] == state["player"]["hp"], key + " absorbed the full enemy hit")
	else:
		_expect(after["defiance_remaining"] == 0 and _engine.defiance_events(after).size() == 1, "Enemy hit triggers real Defiance")

func _observe_beat(state: Dictionary, presentation: Dictionary, overlap: bool) -> void:
	var entries: Array = presentation.get("floating_texts", [])
	for entry: Dictionary in entries:
		_entries += 1
		if _base: continue
		_check_entry(entry)
	if _case.is_empty() or _checked_cases.has(_case): return
	var expected: Array = EXPECTED[_case]
	var index: int = entries.find_custom(func(entry: Dictionary) -> bool:
		return entry.get("text") == expected[2 if _base else 1] and (_base or str(entry.get("icon", "")) == expected[0])
	)
	if _case == "illusion":
		_expect(overlap and (_base or (entries.is_empty() and presentation.get("hold_floating_effect_beat", false))), "Illusion preserves its timed overlap beat without an entry")
		_expect(state["illusions"].size() == 1 and state["illusions"][0]["hp"] == 5, "Illusion has its real Health")
		if not _base: _expect(index < 0, "Illusion spawn has no matching text")
	elif index < 0:
		return
	elif not _base and str(expected[0]) in ["block", "stoneskin", "heal", "draw", "card_play"]:
		_expect(entries[index].get("resource_kind") == expected[0], _case + " identifies the resource kind")
	_checked_cases[_case] = 1
	if _native and _case not in ["light", "conversion", "no_block"]:
		await _capture_beat(state, presentation, entries, index)

func _check_entry(entry: Dictionary) -> void:
	var text: String = str(entry.get("text", ""))
	var lower: String = text.to_lower()
	_expect(_old_labels.search(text) == null and not ("draw" in lower or "illusion" in lower or "card play" in lower), "No obsolete float text: " + text)
	var kind: String = str(entry.get("resource_kind", ""))
	if kind.is_empty(): return
	_expect(entry.get("kind") == "effect" and entry.get("icon") == kind and Icons.icon_texture(kind) != null, "Resource float uses the card icon: " + kind)
	var color: Color = Elements.accent(Elements.EARTH) if kind == "stoneskin" else Color(COLORS[kind])
	_expect(entry.get("color") == color, "Resource float preserves " + kind + " colour")
	for reduced: bool in [false, true]:
		var animated: Dictionary = Floats.animate_entry(entry, Floats.DAMAGE_SETTLE_PROGRESS, reduced)
		_expect(animated.get("text") == text and animated.get("icon") == kind, "Motion mode keeps identical " + kind + " content")
		if reduced: _expect(animated["motion_offset"] == Vector2.ZERO, "Reduced motion keeps a static popup")

func _capture_beat(state: Dictionary, presentation: Dictionary, entries: Array, index: int) -> void:
	var tile: Vector2i = ILLUSION if _case == "illusion" else entries[index]["tile"]
	var sequence: int = 0
	for previous: int in range(index):
		if entries[previous]["tile"] == tile: sequence += 1
	for phase: String in CAPTURE_PHASES:
		var shown: Dictionary = presentation.duplicate(true)
		var elapsed: float = float(CAPTURE_PHASES[phase]) * Floats.ANIMATION_DURATION_SECONDS + sequence * Floats.STAGGER_SECONDS
		shown["floating_texts"] = Floats.animate_entries(entries, elapsed, false)
		shown["effect_progress"] = CAPTURE_PHASES[phase]
		_scene._render_board_state(state, shown)
		await process_frame
		await RenderingServer.frame_post_draw
		var board: Control = _scene.board_view
		var effects: Control = board.get("_effects_render_layer")
		var layouts: Array = effects.get("_floating_text_last_layout")
		var rendered: bool = layouts.any(func(popup: Dictionary) -> bool:
			return popup["tile"] == tile and popup["entry"]["text"] == EXPECTED[_case][2 if _base else 1]
		)
		_expect(rendered == (index >= 0), _case + " has the expected final renderer layout")
		if _case == "illusion":
			var bars: Dictionary = board.get("_hud_health_rects_cache")
			_expect(bars.keys().any(func(key: String) -> bool: return key.begins_with("illusion_")), "Renderer shows the new Illusion's Health bar")
		var target: Rect2 = board.call("_floating_text_target_rect", tile)
		var center: Vector2 = board.get_global_transform_with_canvas() * target.get_center()
		var top_left: Vector2i = Vector2i((center - Vector2(CROP_SIZE) * 0.5).round()).clamp(Vector2i.ZERO, VIEWPORT_SIZE - CROP_SIZE)
		var image: Image = _viewport.get_texture().get_image()
		var stem: String = _capture_directory.path_join(_case + "_" + phase)
		_expect(image.get_size() == VIEWPORT_SIZE and image.save_png(stem + "_full.png") == OK, "Saved full frame: " + stem)
		_expect(image.get_region(Rect2i(top_left, CROP_SIZE)).save_png(stem + "_crop.png") == OK, "Saved exact crop: " + stem)
		_captures += 1

func _settle() -> void:
	for _frame: int in range(VIEW_WARMUP_FRAMES): await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
