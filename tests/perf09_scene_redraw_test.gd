extends "res://tools/inspection_fixture.gd"
## Count-only default-suite guard. Production canvases draw through the dummy
## renderer. Explicit animation samples remove wall-clock/cadence dependence.
const Board = preload("res://scripts/combat_board_view.gd")
const Dirty = preload("res://scripts/board_scene_dirty_tiles.gd")
const ACTION_SAMPLES: int = 12
const MAX_LOCAL_ACTION_SCENE_DRAWS: int = 48
const MAX_HOVER_SCENE_DRAWS: int = 8
const SETTLE_FRAMES: int = 3
const PREVIEW_HP_LOSS: int = 1
const TARGET_TERRAIN_TILE := Vector2i(3, 3)
const ATLAS_SOURCE_SIZE: int = 64
const ATLAS_REGION_SIZE: int = 32

class CommandSink extends Control:
	var emitted: Array = []
	func _submit_prop_command(command: Array) -> void: emitted.append(command)
var errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_options = {"seed": DEFAULT_SEED, "scenario": "warband", "warband_biome": "earth", "warband_tier": 2, "warband_case": "encounter", "hero_facing": "persist"}
	var run: Dictionary = _build_run_state("warband", _build_progression())
	var state: Dictionary = run["combat_state"]
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	root.add_child(board)
	board.set_process(false)
	board.set_combat_state(state)
	await _settle()
	board.reset_render_instrumentation()
	var actor: Dictionary = {}
	for enemy: Dictionary in state["enemies"]:
		if str(enemy.get("type", "")) == "briar_weaver": actor = enemy
	_expect(not actor.is_empty(), "Real earth Warband includes its Briar Weaver")
	var key: String = "enemy_%d" % int(actor.get("id", -1))
	for sample: int in range(ACTION_SAMPLES):
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {
			"briar_weaver_motion": {key: {"clip": "idle", "phase": float(sample) / ACTION_SAMPLES}},
			"effect_frame_count": ACTION_SAMPLES, "maquette_explicit_clip": true, "harrier_travel_variant": "walk", "umbra_reveal_actor_on_visible_tiles": true})
		await _settle()
	var action: Dictionary = board.render_instrumentation_snapshot()
	var action_draws: int = int(action["layer_draw_counts"].get("scene_tile", 0))
	_expect(action_draws <= MAX_LOCAL_ACTION_SCENE_DRAWS, "Enemy action redraws <=48 scene layers, independent of board area")
	_expect(int(action["full_dynamic_redraw_count"]) == 0, "Maquette animation metadata never invalidates the full board")
	# A changed preview affects only its path owners. Repeated identical target
	# submissions must retain them rather than recompute/repaint every frame.
	var path: Array[Vector2i]
	path.assign([state["player"]["pos"], state["player"]["pos"] + Vector2i(1, 0)])
	board.set_combat_state(state)
	await _settle()
	board.set_submission_performance_instrumentation_enabled(true)
	board.reset_render_instrumentation()
	var preview_enemy: Dictionary = state["enemies"][0]
	var damage_preview: Dictionary = {"enemy_%d" % int(preview_enemy["id"]): {
		"hp": maxi(0, int(preview_enemy["hp"]) - PREVIEW_HP_LOSS), "hp_loss": PREVIEW_HP_LOSS, "lethal": false}}
	var hover_events: Array[Vector2i]
	board.tile_hovered.connect(func(tile: Vector2i) -> void: hover_events.append(tile))
	for sample: int in range(ACTION_SAMPLES):
		var motion := InputEventMouseMotion.new()
		motion.position = board._tile_center(path.back())
		board._gui_input(motion)
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"path_tiles": path, "expand_enemy_intents": true, "damage_preview": damage_preview})
		await _settle()
	_expect(hover_events.size() == 1, "Repeated pointer motion at one target schedules one preview computation")
	_expect(board._path_draw_cache.build_records.size() == 1, "Hover path geometry computes once across all depth tiles and frames")
	var hover: Dictionary = board.render_instrumentation_snapshot()
	var hover_draws: int = int(hover["layer_draw_counts"].get("scene_tile", 0))
	_expect(hover_draws <= MAX_HOVER_SCENE_DRAWS, "One hovered target redraws <=8 scene layers across 12 frames")
	_expect(int(hover["full_dynamic_redraw_count"]) == 0, "Local hover never invalidates the full board")
	var old: Array = [{"id": "a", "pos": Vector2i(2, 2), "hp": 3}, {"id": "b", "pos": Vector2i(3, 3), "hp": 4}]
	var next: Array = old.duplicate(true)
	next[0]["hp"] = 2
	_expect(Dirty.entries(old, next, "pos") == {Vector2i(2, 2): true}, "One terrain mutation dirties only its tile")
	next.remove_at(0)
	_expect(Dirty.entries(old, next, "pos") == {Vector2i(2, 2): true}, "Removed terrain clears only its old tile")
	var growth: Dictionary = {"effect": {"en04_mechanic": "grow_bramble", "tiles": [Vector2i(4, 4)]}}
	_expect(Dirty.bramble(growth) == {Vector2i(4, 4): true}, "Bramble progress owns only its growing tiles")
	_expect(Dirty.bramble({"effect": {"kind": "melee"}}).is_empty(), "Unrelated attacks never repaint idle bramble")
	_expect(Dirty.surfaces({"2,2": {"rubble": true}}, {"2,2": {"rubble": true}, "3,3": {"rubble": true}}) == {Vector2i(3, 3): true}, "New rubble dirties only its local surface tile")
	await _terrain_target_membership(board, state, damage_preview)
	_atlas_mutations()
	board.free()
	for error: String in errors: push_error(error)
	print("PERF09 REDRAW GUARD: %s (enemy action %d/%d; hover %d/%d; full-board invalidations %d/%d)" % ["PASS" if errors.is_empty() else "FAIL", action_draws, MAX_LOCAL_ACTION_SCENE_DRAWS, hover_draws, MAX_HOVER_SCENE_DRAWS, int(action["full_dynamic_redraw_count"]), int(hover["full_dynamic_redraw_count"])])
	quit(0 if errors.is_empty() else 1)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _terrain_target_membership(board: Control, state: Dictionary, preview: Dictionary) -> void:
	var fixture: Dictionary = state.duplicate(true)
	fixture["terrain"] = [{"id": "target_outcrop", "kind": "crag_outcrop", "pos": TARGET_TERRAIN_TILE, "hp": 3, "max_hp": 3}]
	board.set_combat_state(fixture)
	await _settle()
	for selected: bool in [true, false]:
		board.reset_render_instrumentation()
		var targets: Array[Vector2i]
		if selected: targets.append(TARGET_TERRAIN_TILE)
		board.set_combat_state(fixture, [], targets, Vector2i(-1, -1), "", "", {}, {}, {"damage_preview": preview if selected else {}})
		await _settle()
		var counts: Dictionary = board.render_instrumentation_snapshot()["scene_tile_draw_counts"]
		_expect(int(counts.get("3,3", 0)) > 0, "Attack target select/cancel redraws terrain independently of unit-only previews: " + str(selected))
		_expect(board._should_show_terrain_health_bar(fixture["terrain"][0]) == selected, "Full-health terrain bar follows target membership")
	print("PERF09 TARGET MEMBERSHIP: select/cancel owning canvases checked")

func _atlas_mutations() -> void:
	var cache := preload("res://scripts/board_prop_command_cache.gd").new()
	var sink := CommandSink.new()
	var source := GradientTexture2D.new()
	source.width = ATLAS_SOURCE_SIZE
	source.height = ATLAS_SOURCE_SIZE
	var replacement := GradientTexture2D.new()
	replacement.width = ATLAS_SOURCE_SIZE
	replacement.height = ATLAS_SOURCE_SIZE
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(0, 0, ATLAS_REGION_SIZE, ATLAS_REGION_SIZE)
	var rect := Rect2(0, 0, ATLAS_REGION_SIZE, ATLAS_REGION_SIZE)
	var build: Callable = func() -> void: cache.world(atlas, rect, Color.WHITE, 3, Rect2(), true)
	cache.paint(sink, "atlas", [atlas, rect], build)
	for mutation: String in ["warm", "region", "margin", "underlying"]:
		match mutation:
			"region": atlas.region.position.x = ATLAS_REGION_SIZE
			"margin": atlas.margin.position.x = 1
			"underlying": atlas.atlas = replacement
		var hits: int = cache.hits
		sink.emitted.clear()
		cache.paint(sink, "atlas", [atlas, rect], build)
		var cached: Array = sink.emitted.duplicate(true)
		_expect(cache.hits == hits + (1 if mutation == "warm" else 0), "Atlas value snapshot detects " + mutation)
		cache.enabled = false
		sink.emitted.clear()
		cache.paint(sink, "atlas", [atlas, rect], build)
		_expect(cached == sink.emitted, "Cached atlas commands match fresh commands after " + mutation)
		cache.enabled = true
	sink.free()
	print("PERF09 ATLAS CACHE: warm reuse; region, margin, underlying identity match fresh commands")
