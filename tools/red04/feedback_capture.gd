extends "res://tools/red04/followup_capture.gd"
## The same live stage checks run headlessly before the native PNGs.

const Review = preload("res://tools/red04/review_repros.gd")

func exercise() -> void:
	await _cold_ice()
	await _frozen_walk()
	await _gust_stay()

func _cold_ice() -> void:
	var state: Dictionary = Cases.fire_state()
	var scene: Control = await _mount(state)
	if scene == null: return
	_enable_fixture_skills(scene, state["skill_ids"])
	scene._pass_preview_summary()
	await frames(INPUT_FRAMES)
	var board: Control = scene.board_view
	check(not Cases.Slices.threat_paint(board, Cases.HERO, {}).is_empty(), "Committed enemy Fire paints a contact")
	scene._begin_surface_skill_selection(Cases.SKILL)
	scene._choose_surface_skill_kind("ice")
	# Model a pending result that never supplies a usable summary. The real
	# surface preview and stage renderer still run on the normal hover path.
	var key: String = scene._pass_preview_key(Cases.HERO)
	scene._pass_preview_cache[key] = {}
	await _hover(scene, Cases.HERO)
	check(scene._pass_preview_key(Cases.HERO) == key and scene._pass_preview_cache.get(key, {}).is_empty(), "Exact Ice summary remains unavailable")
	check(Cases.Ground.element_at(scene._surface_preview_cache.get("state", {}), Cases.HERO) == "ice", "Ice preview is visible on the hero tile")
	check(_red_clear(board, Cases.HERO), "Both paint layers are clear while the Ice summary is unavailable")
	await capture("cold-ice-contact")
	scene._cancel_surface_skill_selection()
	await frames(INPUT_FRAMES)
	check(not Cases.Slices.threat_paint(board, Cases.HERO, {}).is_empty(), "Leaving the Ice hover restores committed Fire paint")
	await _remove(scene)

func _frozen_walk() -> void:
	var scene: Control = await _mount(Review.frozen_state())
	if scene == null: return
	var target: Vector2i = Review.frozen_walk_target(scene._combat_engine, scene._combat_state)
	check(target.x >= 0, "Fixture has a legal Walk on Tharokh's saved approach")
	if target.x < 0:
		await _remove(scene)
		return
	scene._begin_player_movement_selection()
	await frames(INPUT_FRAMES)
	await _hover(scene, target)
	var board: Control = scene.board_view
	check(scene._player_movement_target_tiles.has(target) and board._targeted_tile_highlight.visible and board._targeted_tile_highlight.tile == target, "Walk marker targets the saved-only tile")
	check(not board._targeted_tile_threat.visible and _red_clear(board, target), "Unreachable Claw leaves the Walk floor and marker clear")
	var held: Array = board.presentation["threats_at_rest"]["threats"]
	check(held.any(func(row: Dictionary) -> bool: return row.get("area_announced", false) and row["tiles"].has(target)), "The saved tile remains in the held footprint display")
	await capture("frozen-claw-walk")
	await _remove(scene)

func _gust_stay() -> void:
	var scene: Control = await _mount(Review.gust_state())
	if scene == null: return
	var board: Control = scene.board_view
	check(Cases.Lob.floor_marks(board).has(Cases.HERO), "The Mortar has an announced cross at rest")
	await scene._on_card_pressed(0)
	await _hover(scene, Cases.HERO)
	check(scene._pending_target_tiles.has(Cases.HERO), "Gust Step offers Stay")
	# Install the resolved Stay boundary, then drive the live pull hover.
	Review.prepare_stay_pull(scene)
	scene._refresh_card_preview_ui()
	await _hover(scene, Review.PULL_TARGET)
	var preview: Dictionary = scene._enemy_intent_preview_state(scene._board_display_state())
	var enemies: Array = preview["enemies"]
	check(scene._pending_action_index == 1 and preview["player"]["pos"] == Cases.HERO, "Stay leaves the hero in place and aims the pull")
	check(enemies.size() == 1 and int(enemies[0]["hp"]) == 0 and int(scene._combat_state["enemies"][0]["hp"]) == Review.LETHAL_MORTAR_HP, "The hovered pull has a lethal Mortar preview")
	check(Cases.Lob.floor_marks(board).is_empty() and _red_clear(board, Cases.HERO), "The old Lob cross is clear in both paint layers")
	await capture("gust-step-stay-lethal-lob")
	await _remove(scene)

func _red_clear(board: Control, tile: Vector2i) -> bool:
	return Cases.Slices.threat_paint(board, tile, {}).is_empty() and Cases.Slices.threat_paint(board, tile, {}, PackedVector2Array(), true).is_empty()
