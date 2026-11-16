extends "res://tests/pre_battle_fixture.gd"
const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
func _initialize() -> void:
	_setup()
	call_deferred("_run")
func _run() -> void:
	var state: Dictionary = Boons.choose(RunEngine.new(), Fixture.state(), "")
	ProgressionStore.save_data(Fixture.profile())
	var scene: Node = await _instance(state)
	scene.call("_close_large_map")
	await _settle()
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
	var manager: Node = board.get("_occlusion_silhouettes")
	var rows: Array = []
	for key: String in manager.team.bodies:
		var body: Control = manager.team.bodies[key]
		rows.append({"key":key,"visible":body.is_visible_in_tree(),"kind":body.get("_render_layer_kind"),"ops":body.get("_render_slice_ops"),"draws":body.get("_dynamic_draw_count"),"actor":body.get("_unit_outline_actor"),"children":body.get_child_count(),"parent":str(body.get_parent().get_path()),"rect":str(board.call("_unit_texture_draw_rect",body.get("_unit_outline_actor"),board.call("_unit_center",body.get("_unit_outline_actor"))))})
	print("ROUND1 BODIES ",JSON.stringify(rows))
	print("ROUND1 FIT ", JSON.stringify({"size":str(board.size),"width":board.call("_tile_width"),"origin":str(board.get("_board_layout_cache_origin")),"available":str(board.call("_board_layout_available_rect")),"exclusions":str(board.call("_board_layout_exclusions")),"body_bounds":str(board.get("_room_framing").body_bounds),"zoom":board.get("_navigation_zoom"),"mode":board.presentation.get("board_framing_mode"),"fit":str(board.presentation.get("board_fit_rect")),"legacy":str(board.presentation.get("board_legacy_fit_rect"))}))
	print("ROUND1 UNITS ",JSON.stringify(board.call("_visible_units")))
	print("ROUND1 LAYERS ",JSON.stringify((board.get("_scene_render_layers_by_tile") as Dictionary).keys()))
	scene.call("_speak_to_emaciated_man")
	scene.call("_complete_current_dialogue_line")
	await _settle()
	var portrait: TextureRect = scene.get("_dialogue_portrait")
	var atlas: AtlasTexture = portrait.texture
	print("ROUND1 PORTRAIT ",JSON.stringify({"texture_size":str(atlas.get_size()),"atlas_size":str(atlas.atlas.get_size()),"region":str(atlas.region),"image_size":str(atlas.get_image().get_size()),"alpha_bounds":str(atlas.get_image().get_used_rect()),"control_size":str(portrait.size),"material":str(portrait.material),"use_parent_material":portrait.use_parent_material}))
	scene.queue_free()
	await process_frame
	quit()
