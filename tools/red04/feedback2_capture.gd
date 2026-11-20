extends "res://tools/red04/feedback_capture.gd"
## Exercise the live preview before drawing each native receipt.

func exercise() -> void:
	await _confluence_rubble()
	await _walk_arc_bolt()
	await _mortar_sight()

func _confluence_rubble() -> void:
	var state: Dictionary = Review.confluence_state()
	var scene: Control = await _mount(state)
	if scene == null: return
	_enable_fixture_skills(scene, state["skill_ids"])
	scene._pass_preview_summary()
	await frames(INPUT_FRAMES)
	var board: Control = scene.board_view
	check(not Cases.Slices.threat_paint(board, Cases.HERO, {}).is_empty(), "Enemy Fire paints red over Rubble at rest")
	scene._begin_surface_skill_selection(Review.CONFLUENCE)
	scene._choose_surface_skill_kind("rubble")
	scene._commit_surface_skill_tile(Cases.HERO)
	var target: Vector2i = Review.CONFLUENCE_TARGET
	var key: String = scene._pass_preview_key(target)
	scene._pass_preview_cache[key] = {}
	await _hover(scene, target)
	check(scene._pass_preview_key(target) == key and scene._pass_preview_cache.get(key, {}).is_empty(), "Exact Confluence summary remains unavailable")
	var preview: Dictionary = scene._surface_preview_cache.get("state", {})
	check(Cases.Ground.element_at(preview, Cases.HERO) == "fire" and not Cases.Ground.has_rubble(preview, Cases.HERO)
		and Cases.Ground.has_rubble(preview, target), "Confluence moves Rubble and leaves Fire on the hero tile")
	check(not Cases.Slices.threat_paint(board, Cases.HERO, {}).is_empty(), "The untouched Fire still paints a contact")
	await capture("confluence-rubble-under-fire")
	await _remove(scene)

func _walk_arc_bolt() -> void:
	var scene: Control = await _mount(Review.doomed_thrall_state())
	if scene == null: return
	scene._begin_player_movement_selection()
	await frames(INPUT_FRAMES)
	var tile: Vector2i = Review.THRALL_WALK
	await _hover(scene, tile)
	var summary: Dictionary = scene._pass_preview_summary()
	await frames(INPUT_FRAMES)
	var board: Control = scene.board_view
	var marker: Node2D = board._targeted_tile_threat
	check(scene._player_movement_target_tiles.has(tile) and board._targeted_tile_highlight.visible, "The Arc Bolt tile has a legal Walk marker")
	check(int(scene._combat_state["enemies"][0]["hp"]) == Review.THRALL_HP
		and summary.get("died_first_keys", {}).has(Review.SOURCE), "The present Thrall has one Health and Pass predicts its death before Arc Bolt")
	check(marker != null and marker.visible and marker.tile == tile
		and not Cases.Slices.threat_paint(board, tile, {}).is_empty(), "Both layers still paint the present Arc Bolt on the Walk destination")
	await capture("walk-present-arc-bolt")
	await _remove(scene)

func _mortar_sight() -> void:
	var fixture: Dictionary = Review.sight_mortar_state()
	var scene: Control = await _mount(fixture)
	if scene == null: return
	# Continue can normalize depth against the profile. Install the same battle
	# sight inputs at the live fixture boundary before warming the shared lookup.
	var state: Dictionary = scene._combat_state.duplicate(true)
	for field: String in ["umbra", "umbra_depth", "section_index"]:
		state[field] = fixture[field]
	scene._combat_state = state
	scene._run_state = scene._run_engine.set_combat_state(scene._run_state, state)
	scene._mark_combat_preview_state_changed()
	var modifier: Dictionary = Review.sight_modifier(state)
	var saved: Variant = modifier.get("amount")
	var board: Control = scene.board_view
	var mortar: Dictionary = state["enemies"][0]
	modifier["amount"] = Review.WIDE_SIGHT_DELTA
	scene._refresh_stage_view()
	await frames(INPUT_FRAMES)
	var wide: Dictionary = Cases.Lob.marks(board)
	check(board.presentation.get("visible_enemy_ids", []).has(mortar["id"])
		and wide.has(Cases.HERO) and is_same(wide, Cases.Lob.floor_marks(board)), "Visible Mortar supplies one shared cross")
	modifier["amount"] = Review.NARROW_SIGHT_DELTA
	scene._refresh_stage_view()
	await frames(INPUT_FRAMES)
	var narrow: Dictionary = Cases.Lob.marks(board)
	check(is_same(scene._combat_state, state) and not board.presentation.get("visible_enemy_ids", []).has(mortar["id"]),
		"Sight hides the same Mortar without changing battle state")
	check(narrow.is_empty() and is_same(narrow, Cases.Lob.floor_marks(board)) and _red_clear(board, Cases.HERO),
		"Neither layer paints the cached cross once the aimer is hidden")
	await capture("lob-cross-after-sight-change")
	modifier["amount"] = saved
	await _remove(scene)
