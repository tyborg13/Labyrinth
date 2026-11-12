extends SceneTree

const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Focus = preload("res://scripts/board_aim_focus.gd")
const MANIFEST: String = "/private/tmp/labyrinth_codex/rd-03/feedback1/combat.json"
const IDLE_FRAMES: int = 120
const SETTLE_FRAMES: int = 16
const FADE_WAIT_SECONDS: float = 0.16
const CARDS: Array = ["dull_bolt", "quick_stab", "whirlwind_slash", "ember_rain", "bloody_lunge", "brace"]
var scene: Node
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var manifest: String = args[args.find("--fixture-manifest") + 1] if args.has("--fixture-manifest") else MANIFEST
	Fixture.install_save(manifest)
	scene = Fixture.resume(self, Fixture.make_canvas(self))
	await _settle()
	var board: Control = scene.get("board_view")
	var focus: RefCounted = board.get("_aim_focus")
	_check(not focus.active, "Idle has no dimming")
	var state: Dictionary = scene.get("_combat_state")
	var traps: Array = state.get("traps", [])
	_check(not traps.is_empty(), "Certified save contains a trap")
	var trap_tile: Vector2i = traps[0].pos if not traps.is_empty() else Vector2i(-1, -1)
	_check(not str(board.call("controller_tooltip_for_tile", trap_tile)).is_empty(), "Trap tooltip opens idle")
	var held := Window.new()
	held.theme_type_variation = &"TooltipPanel"
	var stack := VBoxContainer.new()
	stack.set_meta("tile_tooltip_stack", true)
	held.add_child(stack)
	board.add_child(held)
	var unit_popup := Window.new()
	unit_popup.theme_type_variation = &"TooltipPanel"
	unit_popup.add_child(Label.new())
	board.add_child(unit_popup)
	for card: String in CARDS:
		var index: int = scene.call("_combat_hand_cards", state).find(card)
		_check(index >= 0, card + " exists in certified hand")
		if index < 0: continue
		await scene.call("_on_card_pressed", index)
		scene.call("_refresh_stage_view")
		await _settle()
		if card == "dull_bolt":
			_check(not is_instance_valid(held), "Choosing closes an already-held terrain popup")
			_check(is_instance_valid(unit_popup), "Choosing preserves unit popup ownership")
			unit_popup.queue_free()
		var pending: bool = scene.call("_targeted_card_aiming_active")
		_check(focus.active == pending, card + " focus follows actual board step")
		var preview: Dictionary = scene.call("_active_card_preview")
		var expected: Dictionary = _expected_tiles(preview)
		var strong: Array[String]
		var dim: Array[String]
		for unit: Dictionary in board.call("_visible_units"):
			if bool(unit.get("death_animation", false)): continue
			var affected: bool = not pending or str(unit.get("role", "")) == "player"
			for tile: Vector2i in board.call("_unit_footprint_tiles", unit): affected = affected or expected.has(tile)
			_check(focus.full_strength(board, unit) == affected, card + ": affected set " + str(unit.key))
			if affected: strong.append(str(unit.key))
			else: dim.append(str(unit.key))
		_check(str(board.call("controller_tooltip_for_tile", trap_tile)).is_empty() == pending, card + ": trap tooltip follows choosing")
		Fixture.pointer(self, board, board.call("world_position_for_tile", trap_tile))
		await _settle()
		_check(str(board.call("_get_tooltip", board.call("world_position_for_tile", trap_tile))).is_empty() == pending, card + ": prop hover follows choosing")
		await create_timer(FADE_WAIT_SECONDS).timeout
		for record: Dictionary in focus.canvases.values():
			if bool(record.get("top", false)): continue # callout canvas: never dims, topmost
			if not is_instance_valid(record.canvas) or not record.canvas.visible: continue
			var affected: bool = focus.full_strength(board, record.unit)
			var tint: Color = record.canvas.self_modulate
			_check(is_equal_approx(tint.a, 1.0 if affected or not record.hud else Focus.HUD_ALPHA), card + ": retained alpha")
			_check(is_equal_approx(tint.r, 1.0 if affected or record.hud else Focus.SPRITE_RGB), card + ": retained RGB")
		var enemies: Array = state.get("enemies", [])
		if not enemies.is_empty():
			var tile: Vector2i = enemies[0].pos
			board.call("set_targeted_tile", tile)
			for record: Dictionary in focus.canvases.values():
				if bool(record.get("top", false)): continue # callout canvas: never dims, topmost
				if not is_instance_valid(record.canvas) or not record.hud: continue
				var on_tile: bool = board.call("_unit_footprint_tiles", record.unit).has(tile)
				_check(record.canvas.z_index == (2 if on_tile else 1), card + ": focused HUD order")
		var changes: int = focus.changes
		var redraws: int = int(board.get("_full_dynamic_redraw_count"))
		for frame: int in range(IDLE_FRAMES): await process_frame
		_check(focus.changes == changes, card + ": no focus work over 120 idle frames")
		_check(int(board.get("_full_dynamic_redraw_count")) == redraws, card + ": no full redraws over 120 idle frames")
		print("RD03 SET %s: full=%s stepped=%s; idle_full_redraw_delta=%d" % [card, strong, dim, int(board.get("_full_dynamic_redraw_count")) - redraws])
		await scene.call("_on_cancel_requested")
		scene.call("_refresh_stage_view")
		_check(not focus.active, card + ": cancel restores strength")
		_check(not str(board.call("controller_tooltip_for_tile", trap_tile)).is_empty(), card + ": cancel restores trap tooltip")
	await scene.call("_on_card_pressed", scene.call("_combat_hand_cards", state).find("dull_bolt"))
	_check(focus.active, "Playback fixture begins in aiming")
	scene.set("_animation_lock", true)
	scene.call("_refresh_stage_view")
	_check(not focus.active and not focus.choosing, "Playback clears focus and tooltip gate")
	scene.set("_animation_lock", false)
	await scene.call("_on_cancel_requested")
	scene.call("_begin_player_movement_selection")
	scene.call("_refresh_stage_view")
	_check(not focus.active and focus.choosing, "Movement gates tooltips without dimming")
	_check(str(board.call("controller_tooltip_for_tile", trap_tile)).is_empty(), "Movement suppresses trap tooltip")
	await scene.call("_on_cancel_requested")
	var aim: RefCounted = scene.get("_surface_aim")
	aim.begin("confluence", true)
	aim.choose("elemental")
	scene.call("_refresh_stage_view")
	_check(not focus.active and focus.choosing, "Surface aim gates tooltips without dimming")
	for failure: String in failures: push_error(failure)
	print("RD03 AIM FOCUS: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expected_tiles(preview: Dictionary) -> Dictionary:
	var engine: RefCounted = scene.get("_combat_engine")
	var action: Dictionary = preview.get("action", {})
	var state: Dictionary = preview.get("state", {})
	var expected: Dictionary = {}
	var actions: Array = [action]
	if str(action.get("type", "")) == "confirm":
		actions = preview.get("actions", [])
		state = scene.get("_combat_state")
	for step: Dictionary in actions:
		var targets: Array = engine.call("valid_targets_for_player_action", state, step)
		for target: Vector2i in targets:
			if str(step.get("type", "")) in ["aoe", "meteor_marks"]:
				for tile: Vector2i in engine.call("aoe_tiles_for_player_action", state, step, target): expected[tile] = true
			else: expected[target] = true
	if str(action.get("type", "")) in ["move", "blink"]:
		scene.call("_prepare_preview_shortcuts_for_current_action", preview)
		for tile: Vector2i in scene.get("_preview_shortcuts_cache").get("tiles", []): expected[tile] = true
	return expected

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
