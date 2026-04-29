extends Control

const RunScene = preload("res://scenes/run_scene.tscn")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const FRAME_RATE: float = 30.0
const TITLE_SEED: int = 126044

var _run_scene: Control
var _run_engine = RunEngineScript.new()
var _overlay_layer: CanvasLayer
var _scrim: ColorRect
var _text_band: ColorRect
var _callout: Label
var _subline: Label
var _title: Label
var _timeline_done: bool = false

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	ProgressionStore.set_storage_path("user://trailer_progression.json")
	ProgressionStore.set_run_storage_path("user://trailer_current_run.save")
	ProgressionStore.clear_saved_run()
	_build_game_layer()
	_build_overlay()
	call_deferred("_run_timeline")

func _process(_delta: float) -> void:
	if _timeline_done:
		get_tree().quit()

func _build_game_layer() -> void:
	_run_scene = RunScene.instantiate()
	_run_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_run_scene)

func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100
	add_child(_overlay_layer)
	
	_scrim = ColorRect.new()
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(0.02, 0.01, 0.0, 0.0)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_scrim)
	
	_text_band = ColorRect.new()
	_text_band.name = "TextBand"
	_text_band.anchor_left = 0.0
	_text_band.anchor_top = 0.04
	_text_band.anchor_right = 1.0
	_text_band.anchor_bottom = 0.31
	_text_band.color = Color(0.0, 0.0, 0.0, 0.46)
	_text_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_band.visible = false
	_overlay_layer.add_child(_text_band)
	
	_title = _make_label(96, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.offset_top = -80.0
	_title.offset_bottom = 80.0
	_title.text = "LABYRINTH OF ASH"
	_overlay_layer.add_child(_title)
	
	_callout = _make_label(48, HORIZONTAL_ALIGNMENT_CENTER)
	_callout.anchor_left = 0.0
	_callout.anchor_top = 0.09
	_callout.anchor_right = 1.0
	_callout.anchor_bottom = 0.20
	_callout.offset_left = 96.0
	_callout.offset_right = -96.0
	_overlay_layer.add_child(_callout)
	
	_subline = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_subline.anchor_left = 0.0
	_subline.anchor_top = 0.20
	_subline.anchor_right = 1.0
	_subline.anchor_bottom = 0.28
	_subline.offset_left = 150.0
	_subline.offset_right = -150.0
	_subline.add_theme_color_override("font_color", Color("f0c978"))
	_overlay_layer.add_child(_subline)

func _make_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff4dc"))
	label.add_theme_color_override("font_outline_color", Color("180d08"))
	label.add_theme_constant_override("outline_size", 10 if font_size >= 50 else 5)
	return label

func _run_timeline() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_seed_showcase_run()
	_set_title(true)
	_set_callout("", "")
	await _fade_scrim(0.82, 0.18, 0.6)
	await _hold(1.1)
	_set_title(false)
	_set_callout("EXPLORE A SHIFTING MAZE", "Each door commits the route. Each room rewrites the run.", "upper")
	await _fade_scrim(0.18, 0.0, 0.45)
	await _hold(1.8)
	await _enter_first_combat()
	_set_callout("POSITION BEFORE YOU STRIKE", "Cards are movement, attacks, blocks, and desperate escapes.", "lower_gap")
	await _hold(1.0)
	await _show_card_preview()
	await _hold(1.0)
	_set_callout("PLAY THE HAND YOU'RE DEALT", "Chain movement and attacks before the room bites back.", "lower_gap")
	await _auto_play_cards(4)
	_set_callout("SURVIVE. ADAPT. CLAIM EMBERS.", "Win rewards, bind magicks, and push deeper toward the heart.", "upper")
	await _force_reward_showcase()
	await _hold(2.1)
	_set_title(true)
	_title.text = "LABYRINTH OF ASH"
	_set_callout("COMING FROM THE DEPTHS", "")
	await _fade_scrim(0.0, 0.76, 0.65)
	await _hold(1.4)
	_timeline_done = true

func _seed_showcase_run() -> void:
	var progression := ProgressionStore.default_data()
	progression["embers"] = 18
	progression["card_upgrades_unlocked"] = true
	var state: Dictionary = _run_engine.create_new_run(TITLE_SEED, progression)
	state["unbanked_embers"] = 7
	_run_scene._load_run_state(state)
	_run_scene._close_dialogue()

func _enter_first_combat() -> void:
	var destination := _first_room_of_type("combat")
	if destination == Vector2i(999, 999):
		var moves: Array[Vector2i] = _run_engine.available_moves(_run_scene._run_state)
		if moves.is_empty():
			return
		destination = moves[0]
	await _run_scene._on_map_view_room_selected(destination)
	await _wait_for_animation()
	await _ensure_combat_hand()

func _first_room_of_type(room_type: String) -> Vector2i:
	var moves: Array[Vector2i] = _run_engine.available_moves(_run_scene._run_state)
	for coord: Vector2i in moves:
		var room: Dictionary = _run_engine.room_metadata(_run_scene._run_state, coord)
		if str(room.get("type", "combat")) == room_type:
			return coord
	for coord: Vector2i in moves:
		var room: Dictionary = _run_engine.room_metadata(_run_scene._run_state, coord)
		if str(room.get("type", "combat")) not in ["campfire", "treasure", "start"]:
			return coord
	return Vector2i(999, 999)

func _ensure_combat_hand() -> void:
	if str(_run_scene._run_state.get("mode", "")) != "combat":
		return
	var deck: Dictionary = (_run_scene._combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash", "quick_stab", "bone_dart", "brace", "shadow_step"]
	deck["draw"] = ["lantern_shot", "guarded_step", "ember_jab", "patch_up"]
	deck["discard"] = []
	_run_scene._combat_state["deck"] = deck
	_run_scene._combat_state["cards_played_this_turn"] = 0
	_run_scene._run_state = _run_engine.set_combat_state(_run_scene._run_state, _run_scene._combat_state)
	_run_scene._refresh_ui()

func _show_card_preview() -> void:
	if str(_run_scene._run_state.get("mode", "")) != "combat":
		return
	for index: int in range(((_run_scene._combat_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size()):
		var preview: Dictionary = _run_scene._card_preview_for_index(index)
		if bool(preview.get("playable", false)):
			_run_scene._on_card_hover_started(index)
			var targets: Array[Vector2i] = _run_scene._vector2i_array(preview.get("target_tiles", []))
			if not targets.is_empty():
				_run_scene._on_board_tile_hovered(targets[0])
			return

func _auto_play_cards(max_cards: int) -> void:
	for _step: int in range(max_cards):
		if str(_run_scene._run_state.get("mode", "")) != "combat":
			return
		await _wait_for_animation()
		var index := _best_playable_card_index()
		if index < 0:
			await _run_scene._on_pass_turn_pressed()
			await _wait_for_animation()
			continue
		await _run_scene._on_card_pressed(index)
		await _resolve_selected_card_targets()
		await _wait_for_animation()
		await _hold(0.12)

func _best_playable_card_index() -> int:
	var hand: Array = (_run_scene._combat_state.get("deck", {}) as Dictionary).get("hand", [])
	var fallback := -1
	for index: int in range(hand.size()):
		var preview: Dictionary = _run_scene._card_preview_for_index(index)
		if not bool(preview.get("playable", false)):
			continue
		if fallback < 0:
			fallback = index
		var action: Dictionary = preview.get("action", {})
		if str(action.get("type", "")) in ["melee", "ranged", "aoe", "push", "pull"]:
			return index
	return fallback

func _resolve_selected_card_targets() -> void:
	var guard := 0
	while _run_scene._selected_card_index >= 0 and guard < 5:
		guard += 1
		var targets: Array[Vector2i] = _run_scene._pending_target_tiles
		if targets.is_empty():
			await _hold(0.1)
			continue
		var target := _best_target_tile(targets)
		_run_scene._on_board_tile_hovered(target)
		await _hold(0.16)
		await _run_scene._on_board_tile_clicked(target)
		await _wait_for_animation()

func _best_target_tile(targets: Array[Vector2i]) -> Vector2i:
	for target: Vector2i in targets:
		for enemy_var: Variant in _run_scene._combat_state.get("enemies", []):
			var enemy: Dictionary = enemy_var
			if int(enemy.get("hp", 0)) > 0 and enemy.get("pos", Vector2i(-99, -99)) == target:
				return target
	return targets[0]

func _force_reward_showcase() -> void:
	var state: Dictionary = _run_scene._run_state.duplicate(true)
	state["mode"] = "reward"
	state["pending_reward"] = {
		"cards": ["cinderburst", "threaded_path", "rallying_breath"],
		"heal_amount": 6,
		"ember_amount": 9
	}
	state["unbanked_embers"] = 16
	state["combat_state"] = {}
	_run_scene._load_run_state(state)
	await _hold(0.3)

func _set_title(visible: bool) -> void:
	_title.visible = visible

func _set_callout(headline: String, detail: String, placement: String = "upper") -> void:
	_place_callout(placement)
	_callout.text = headline
	_subline.text = detail

func _place_callout(placement: String) -> void:
	match placement:
		"lower_gap":
			_callout.anchor_top = 0.60
			_callout.anchor_bottom = 0.68
			_subline.anchor_top = 0.68
			_subline.anchor_bottom = 0.725
		_:
			_callout.anchor_top = 0.055
			_callout.anchor_bottom = 0.145
			_subline.anchor_top = 0.145
			_subline.anchor_bottom = 0.205

func _fade_scrim(from_alpha: float, to_alpha: float, seconds: float) -> void:
	var frames := maxi(1, int(seconds * FRAME_RATE))
	for frame: int in range(frames):
		var t := float(frame + 1) / float(frames)
		_scrim.color = Color(0.02, 0.01, 0.0, lerpf(from_alpha, to_alpha, t))
		await get_tree().process_frame

func _hold(seconds: float) -> void:
	var frames := maxi(1, int(seconds * FRAME_RATE))
	for _frame: int in range(frames):
		await get_tree().process_frame

func _wait_for_animation() -> void:
	while bool(_run_scene._animation_lock):
		await get_tree().process_frame
