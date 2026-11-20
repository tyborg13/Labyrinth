extends "res://tools/qa103/proof.gd"
## Capture the production board and assert its paint inputs before each PNG.

const Cases = preload("res://tools/red04/followup_repros.gd")
const Fixture = preload("res://tools/brd01/fixture.gd")
const Pointer = preload("res://tools/qa103/encounters.gd")
const Context = preload("res://scripts/targeted_tile_context.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const BOOT_FRAMES: int = 300
const INPUT_FRAMES: int = 12
const SNARE_STRIKE_TILE := Cases.SNARE_WALK + Vector2i.DOWN * 2
const SNARE_STRIKE_ID: int = 4
const SNARE_STRIKE_TIME: int = 1

func exercise() -> void:
	await _shadow_step()
	await _snare_walk()
	await _frozen_claw()
	await _prismatic_instinct()
	await _slagmaster()

func _mount(state: Dictionary) -> Control:
	var run: Dictionary = Fixture.Run.new().set_combat_state(Fixture.encounter("combat"), state)
	# The proof swaps in battles with their own Health caps. The enclosing
	# checkpoint must agree with the battle before Continue can load it.
	run["player_max_hp"] = state["player"]["max_hp"]
	var scene: Control = Fixture.mount(self, root, run, 1.0)
	check(scene != null, "Mount the combat fixture")
	if scene == null: return null
	for frame: int in range(BOOT_FRAMES):
		if scene._dialogue_active: scene._close_dialogue()
		if Fixture.ready_for_input(scene): break
		await process_frame
	var ready: bool = Fixture.ready_for_input(scene)
	check(ready, "Combat is ready for input (%s)" % state.get("room_name", "fixture"))
	if not ready:
		await _remove(scene)
		return null
	check(is_equal_approx(Typography.ui_scale(scene), 1.0), "UI scale remains 100%")
	return scene

func _hover(scene: Control, tile: Vector2i) -> void:
	var board: Control = scene.board_view
	var point: Vector2 = board.get_global_transform_with_canvas() * Vector2(board.world_position_for_tile(tile))
	Pointer.motion(root, point)
	await frames(INPUT_FRAMES)
	check(scene._hovered_board_tile == tile, "Pointer reached tile %s" % tile)

func _remove(scene: Control) -> void:
	scene.queue_free()
	await process_frame

func _shadow_step() -> void:
	var state: Dictionary = Cases.mortar_state()
	state["deck"]["hand"] = ["shadow_step"]
	var scene: Control = await _mount(state)
	if scene == null: return
	await scene._on_card_pressed(0)
	var board: Control = scene.board_view
	for tile: Vector2i in [Cases.NEAR, Cases.FAR]:
		await _hover(scene, tile)
		check(scene._pending_target_tiles.has(tile) and scene._combat_state["player"]["pos"] == Cases.HERO, "Shadow Step remains uncommitted")
		var marks: Dictionary = Cases.Lob.floor_marks(board)
		var centers: Array = marks.keys().filter(func(mark: Vector2i) -> bool: return marks[mark]["center"])
		var center_ok: bool = centers == [Cases.NEAR] if tile == Cases.NEAR else marks.is_empty()
		var lifted: Dictionary = Cases.Slices.threat_paint(board, tile, {}, PackedVector2Array(), true)
		check(center_ok and (lifted.is_empty() if tile == Cases.FAR else lifted.get("hero", false)), "Lob floor and marker use the legal aim")
		await capture("shadow-step-in-range" if tile == Cases.NEAR else "shadow-step-out-of-range")
	await _remove(scene)

func _snare_walk() -> void:
	var state: Dictionary = Cases.Snare.battle("earth")
	var strike: Dictionary = Cases.Tiles.enemy("arc_thrall", SNARE_STRIKE_ID, SNARE_STRIKE_TILE, "arc_bolt")
	state["enemies"].append(strike)
	state = Cases.Tiles.Combat.new()._initialize_initiative_queue(state)
	for queued: Dictionary in state["turn_queue"]:
		if int(queued.get("enemy_id", -1)) == SNARE_STRIKE_ID: queued["time"] = SNARE_STRIKE_TIME
	var scene: Control = await _mount(state)
	if scene == null: return
	scene._begin_player_movement_selection()
	await frames(INPUT_FRAMES)
	await _hover(scene, Cases.SNARE_WALK)
	var board: Control = scene.board_view
	var marker: Node2D = board._targeted_tile_threat
	var floor: Dictionary = Cases.Slices.threat_paint(board, Cases.SNARE_WALK, {})
	check(scene._player_movement_target_tiles.has(Cases.SNARE_WALK), "The Snare destination is a legal Walk target")
	var pressure: Dictionary = board.presentation.get("snare_pressure_preview", {})
	check(not pressure.is_empty() and not pressure["tiles"].has(Cases.SNARE_WALK), "The Walk target is outside Snare pressure")
	var lifted: Dictionary = marker._paint if marker != null else {}
	check(floor.get("hero", false) and not lifted.is_empty() and not lifted["hero"],
		"The floor pulses and the lifted Snare marker stays steady (floor %s, lift %s)" % [floor.get("hero"), lifted.get("hero")])
	await capture("snare-walk-marker")
	await _remove(scene)

func _frozen_claw() -> void:
	var state: Dictionary = Cases.Boss.fixture("tharokh")
	var engine := Cases.Tiles.Combat.new()
	Cases.Boss.declare(engine, state, "worldspine_claw")
	var enemy: Dictionary = state["enemies"][0]
	enemy["freeze"] = 1
	var saved: Array[Vector2i] = Cases.Boss.Areas.announced_tiles(enemy, engine, state)
	var floor: Array[Vector2i] = Cases.Boss.Areas.announced_tiles(enemy, null, state)
	var targets: Array[Vector2i]
	targets.assign(saved.filter(func(tile: Vector2i) -> bool: return not floor.has(tile)))
	check(not targets.is_empty(), "Frozen Tharokh retains a saved-approach tile outside current reach")
	if targets.is_empty(): return
	var scene: Control = await _mount(state)
	if scene == null: return
	var board: Control = scene.board_view
	var tile: Vector2i = targets[0]
	scene._begin_player_movement_selection()
	var context: Dictionary = Context.build(scene, {"action": {"type": "move"}, "target_tiles": targets})
	board.set_targeted_tile_context(context, tile)
	var marker: Node2D = board._targeted_tile_threat
	check(marker != null and not marker.visible and Cases.Slices.threat_paint(board, tile, {}).is_empty(), "Unreachable saved-approach tile has clear red paint on both layers")
	check(Cases.Boss.same(board._floor_threat_coverage["alphas"].keys(), floor), "Floor warning follows Tharokh's current footprint")
	await capture("frozen-tharokh-marker")
	await _remove(scene)

func _prismatic_instinct() -> void:
	var state: Dictionary = Cases.fire_state()
	var scene: Control = await _mount(state)
	if scene == null: return
	_enable_fixture_skills(scene, state["skill_ids"])
	scene._pass_preview_summary()
	await frames(INPUT_FRAMES)
	var board: Control = scene.board_view
	check(board._floor_threat_coverage["alphas"].has(Cases.HERO), "Enemy Fire paints red contact at rest")
	await capture("prismatic-fire-contact")
	scene._begin_surface_skill_selection(Cases.SKILL)
	scene._choose_surface_skill_kind("ice")
	await _hover(scene, Cases.HERO)
	var summary: Dictionary = scene._pass_preview_summary()
	await frames(INPUT_FRAMES)
	check(not summary.is_empty() and summary["hero_red_contacts"].is_empty() and not board._floor_threat_coverage["alphas"].has(Cases.HERO), "Exact Ice summary clears the old Fire contact")
	check(Cases.Ground.element_at(scene._combat_state, Cases.HERO) == "fire" and Cases.Ground.element_at(scene._surface_preview_cache.get("state", {}), Cases.HERO) == "ice", "Preview shows Ice and committed ground remains Fire")
	await capture("prismatic-ice-preview")
	await _remove(scene)

func _enable_fixture_skills(scene: Control, ids: Array) -> void:
	# The loading path takes skill ownership from the profile. Give this
	# battle its fixture skill through the existing live-state test boundary.
	var battle: Dictionary = scene._combat_state.duplicate(true)
	battle["skill_ids"] = ids
	scene._combat_state = battle
	scene._run_state = scene._run_engine.set_combat_state(scene._run_state, battle)
	scene._mark_combat_preview_state_changed()
	scene._refresh_ui()

func _slagmaster() -> void:
	var state: Dictionary = Cases.mortar_state(true, Cases.NEAR_CAPTAIN)
	state["objective"]["command"] = preload("res://scripts/special_encounter_library.gd").definition("warband")["captain"]["command"]
	state["deck"]["hand"] = ["dull_bolt"]
	var scene: Control = await _mount(state)
	if scene == null: return
	await scene._on_card_pressed(0)
	var board: Control = scene.board_view
	var marks: Dictionary = Cases.Lob.marks(board)
	check(not marks.is_empty() and is_same(marks, Cases.Lob.floor_marks(board)), "Slagmaster floor and marker share the committed lookup")
	var targets: Array = marks.keys()
	if not targets.is_empty():
		var context: Dictionary = Context.build(scene, {"action": {"type": "ranged"}, "target_tiles": targets})
		board.set_targeted_tile_context(context, targets[0])
		check(board._targeted_tile_threat.visible and is_same(marks, Cases.Lob.marks(board)), "Hovering the cross preserves its committed lookup and outlines the tile")
		await capture("slagmaster-cross-marker")
	await _remove(scene)
