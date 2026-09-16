extends "res://tests/scavenger_glowup_probe.gd"
## Fixed 30fps native presentation samples, after real RunScene trades.
## The production effects are sampled on their own elapsed clock, never rebuilt.
func _capture_states() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_scene)
	await _settle()
	_scene.call("_load_run_state", _scavenger_state(RunEngine.new()))
	await create_timer(0.7).timeout
	_shop = _scene.get("_scavenger_shop_view") as Control
	_shop.set_process(false)
	var effects: Control = _shop.get("_purchase_effects") as Control
	var effect: Control
	var effect_start: int = 0
	var frame_dir: String = ProjectSettings.globalize_path(GLOW_OUTPUT.path_join("frames"))
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var selected: Control = _offer_source(_shop, "grave_mortar", false)
	_shop.call("_select_item", "grave_mortar", false, selected)
	for index: int in range(165):
		if index == 45:
			(_shop.get("_detail_action") as Button).pressed.emit()
			effect = effects.get_child(effects.get_child_count() - 1) as Control
			effect.set_process(false)
			effect_start = index
		if index == 88:
			_shop.call("_set_pack_mode", true)
			_shop.call("_set_pack_filter", "gear")
			_shop.call("_select_item", "ward_kite", true, _offer_source(_shop, "ward_kite", true))
		if index == 110:
			(_shop.get("_detail_action") as Button).pressed.emit()
			effect = effects.get_child(effects.get_child_count() - 1) as Control
			effect.set_process(false)
			effect_start = index
		if is_instance_valid(effect):
			var time: float = float(index - effect_start) / 30.0
			if time >= 0.94:
				effect.queue_free()
				effect = null
			else:
				effect.set("_elapsed", time)
				effect.call("_update_pose")
				effect.queue_redraw()
		(_shop.get("_portrait") as Node).call("apply_pose", "idle", fposmod(float(index) / 75.0, 1.0))
		await process_frame
		await RenderingServer.frame_post_draw
		_viewport.get_texture().get_image().save_png(frame_dir.path_join("frame_%04d.png" % index))
	await _save("motion_end.png")
	var manifest := FileAccess.open(GLOW_OUTPUT.path_join("timing.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"fps":30,"frames":165,"duration":5.5,"resolution":[1920,1080],"ui_scale":1.0,"sampling":"Native RunScene plus production idle/trade clock samples","purchase_frame":45,"sale_frame":110}))
	manifest.close()
	_scene.queue_free()
	await process_frame
