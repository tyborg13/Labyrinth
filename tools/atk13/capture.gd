extends "res://tools/atk06/capture.gd"
## Native production cel panels from an audit save. --view:
## intent / portrait / prebattle / rule / rule_loop / text (headless export).
## No synthetic move is substituted. The requested intent must exist in the save.
const Presentation = preload("res://tools/atk13/presentation.gd")
const PROOF_PANEL_POSITION := Vector2(72, 80)
const PROOF_TOOLTIP_POSITION := Vector2(980, 260)
const PROOF_BOOT_FRAMES: int = 90
const PROOF_SETTLE_SECONDS: float = 1.2
const PROOF_PARK_POINTER := Vector2(960, 4)
const PROOF_LAYOUT_FRAMES: int = 12
const PROOF_LOOP_SAMPLES: int = 3
const PROOF_LOOP_INTERVAL: float = 0.7
const PROOF_PLAYBACK_FRAME_LIMIT: int = 1800
const PROOF_PEAK_PLAYBACK_FRAME_LIMIT: int = 7200
const PROOF_PLAYBACK_CAPTURE_LIMIT: int = 60
const PROOF_CONTACT_SAMPLE_PROGRESS: float = 0.5
var native_scene: Node
var mounted_panels: Array[Control]

func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	var out: String = _arg("--out")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	_check(DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK, "copy profile")
	_check(DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK, "copy audited save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = _arg("--reduced-motion", "false") == "true"
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(canvas)
	root.set_meta("labyrinth_resume_saved_run", true)
	native_scene = load("res://scenes/run_scene.tscn").instantiate()
	_prepare_native_scene()
	canvas.add_child(native_scene)
	for frame: int in range(PROOF_BOOT_FRAMES): await process_frame
	await create_timer(PROOF_SETTLE_SECONDS).timeout
	var state: Dictionary = native_scene.get("_combat_state")
	var expected: Variant = str_to_var(FileAccess.get_file_as_string(save_dir.path_join("combat_state.txt")))
	_check(expected is Dictionary and state.get("enemies") == expected.get("enemies") and state.get("player", {}).get("pos") == expected.get("player", {}).get("pos"), "resume matches audited board")
	_check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(native_scene), 1.0), "100% UI scale")
	var report: Dictionary = Presentation.collect(native_scene, state)
	var view: String = _arg("--view", "text")
	var board: Control = native_scene.get("board_view")
	_motion(PROOF_PARK_POINTER)
	var enemy: Dictionary = {}
	if view in ["intent", "portrait", "prebattle"]:
		for unit: Dictionary in state.get("enemies", []):
			if str(unit["type"]) == _arg("--enemy") and int(unit.get("hp", 0)) > 0 and (view == "prebattle" or str(unit.get("intent", {}).get("id", "")) == _arg("--intent")):
				enemy = unit
				break
		_check(not enemy.is_empty(), "requested live enemy/intent exists")
		if not enemy.is_empty() and view != "prebattle":
			_check((native_scene.get("_combat_engine") as RefCounted).is_enemy_visible_to_player(state, enemy), "requested foe is visible to player")
		if enemy.is_empty():
			await _finish_capture(out, report, view)
			return
	var key: String = "enemy_%d" % int(enemy.get("id", -1))
	if view == "intent":
		_motion(board.get_global_transform_with_canvas() * Vector2(board.call("world_position_for_tile", enemy["pos"])))
		await create_timer(PROOF_SETTLE_SECONDS).timeout
		if DisplayServer.get_name() == "headless":
			native_scene.set("_hovered_board_tile", enemy["pos"])
			native_scene.call("_refresh_stage_view")
		_check(native_scene.get("_hovered_board_tile") == enemy["pos"], "real pointer hovers audited foe")
		report["intent_tooltip"] = board.call("enemy_intent_tooltip", key)
		report["compact_badges"] = (board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("badges", [])
	elif view == "portrait":
		var slot: Control = _portrait_slot(native_scene, key)
		_check(slot != null, "requested foe has visible turn-order portrait")
		if slot != null:
			_motion(slot.get_global_rect().get_center())
			await create_timer(PROOF_SETTLE_SECONDS).timeout
			if DisplayServer.get_name() == "headless": slot.mouse_entered.emit()
			report["portrait_rect"] = str(slot.get_global_rect())
			report["portrait_tooltip"] = slot.tooltip_text
			_check(str(native_scene.get("_turn_order_hovered_enemy_key")) == key, "real pointer hovers rail portrait")
	elif view == "prebattle":
		# Re-enter this exact production room's pre-battle state, then use its
		# production inspection component. Only panel location is proof staging.
		var run: Dictionary = (native_scene.get("_run_state") as Dictionary).duplicate(true)
		run["mode"] = "pre_battle"
		run["combat_state"] = {}
		run["pre_battle_pending"] = true
		run["pre_battle_travel_dir"] = Vector2i.UP
		native_scene.call("_load_run_state", run)
		for frame: int in range(PROOF_LAYOUT_FRAMES): await process_frame
		var panel: Control = native_scene.call("_build_pre_battle_enemy_inspection_panel", enemy, true)
		_mount(panel, PROOF_PANEL_POSITION)
		_check(panel.find_child("PreBattleKnownMoves", true, false) != null, "native pre-battle known moves are present")
		var beat_labels: Array[Node] = panel.find_children("PreBattleRuleBeat", "", true, false)
		report["prebattle_rule_rows"] = beat_labels.map(func(label: Node) -> Array: return label.get_meta("rule_tokens", []))
		if _arg("--enemy") == "storm_cantor": _check(beat_labels.size() == 1, "Peal has its own icon-token rule row in the native panel")
	elif view == "pass":
		var summary: Dictionary = native_scene.call("_pass_preview_summary")
		var chip: Button = native_scene.get("_pass_preview_forecast_chip").get_ref()
		_check(chip != null, "production PASS forecast chip exists")
		if chip != null:
			native_scene.call("_configure_pass_forecast_panel", chip, summary)
			_motion(chip.get_global_rect().get_center())
			if DisplayServer.get_name() == "headless":
				preload("res://scripts/pass_forecast_focus_tooltip.gd").refresh(chip, true)
			report["pass_rows"] = chip.get_meta("forecast_rows", [])
		_check(int(summary.get("status_gains", {}).get("shock", 0)) > 0, "Capacitor Arc forecast names gained Shock")
		report["pass_summary"] = summary
	elif view == "playback":
		var timeline: Array[Dictionary]
		var signature: String = ""
		var captures: int = 0
		native_scene.call("_on_pass_turn_pressed")
		for frame: int in range(PROOF_PEAK_PLAYBACK_FRAME_LIMIT if _arg("--peak-strip", "false") == "true" else PROOF_PLAYBACK_FRAME_LIMIT):
			await process_frame
			var shown: Dictionary = board.get("presentation")
			var banner: Label = native_scene.get("action_banner")
			var effect_progress: float = float(shown.get("effect_progress", 0.0))
			var peak: bool = _strike_peak(shown.get("effect", {}), effect_progress)
			var next_signature: String = str(shown.get("effect", {})) + ":" + banner.text + ":" + str(effect_progress >= PROOF_CONTACT_SAMPLE_PROGRESS) + ":" + str(peak)
			if next_signature != signature:
				signature = next_signature
				timeline.append({"frame": frame, "bolt_peak": peak, "effect_progress": effect_progress, "ticks_usec": Time.get_ticks_usec(), "banner": banner.text, "rule_caption": shown.get("battlefield_rule_caption", {}), "effect": shown.get("effect", {}), "surface_events": shown.get("surface_feedback_events", [])})
				if captures < PROOF_PLAYBACK_CAPTURE_LIMIT and (banner.text.ends_with("Peal") or banner.text == "Lightning Storm"):
					await _picture(out.get_basename() + "_step%d.png" % captures)
					captures += 1
			if frame > PROOF_LAYOUT_FRAMES and not bool(native_scene.get("_animation_lock")): break
		_check(not bool(native_scene.get("_animation_lock")), "native playback reaches next playable turn within proof budget")
		_check(timeline.any(func(entry: Dictionary) -> bool: return entry.get("effect", {}).get("kind") == "lightning_strikes"), "Peal playback submits simultaneous descending bolts")
		_check(timeline.any(func(entry: Dictionary) -> bool: return entry.get("effect", {}).get("kind") == "chain"), "Peal playback submits the resolver's ordered card Chain arcs")
		report["playback_timeline"] = timeline
		if _arg("--peak-strip", "false") == "true": _check(_has_scheduled_peak(timeline), "strip includes the lightning art at peak")
	elif view in ["rule", "rule_loop"]:
		var hud: Control = native_scene.get("_battlefield_rule_hud")
		_check(hud.visible and str(hud.get("rule_id")) == "lightning_storm", "native Lightning Storm HUD is visible")
		_motion(hud.get_global_rect().get_center())
		if view == "rule_loop":
			var panel: Control = hud.call("_make_custom_tooltip", hud.tooltip_text)
			_mount(panel, PROOF_TOOLTIP_POSITION)
			var window: Control = panel.find_child("TooltipLoopWindow", true, false)
			_check(window != null and window.get_meta("tooltip_loop_id", "") == "lightning_strikes", "native rule tooltip owns approved loop")
			report["loop_id"] = "lightning_strikes"
	await create_timer(PROOF_SETTLE_SECONDS).timeout
	for panel: Control in mounted_panels:
		var rect: Rect2 = panel.get_global_rect()
		_check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= SIZE.x and rect.end.y <= SIZE.y, "native panel fits 1920x1080 viewport")
	if view == "rule_loop":
		# Three native frames sample the existing loop; no new media is made.
		for sample: int in range(PROOF_LOOP_SAMPLES):
			await create_timer(PROOF_LOOP_INTERVAL).timeout
			await _picture(out.get_basename() + "_loop%d.png" % sample)
	if view != "text": await _picture(out)
	await _finish_capture(out, report, view)

func _mount(panel: Control, position: Vector2) -> void:
	(native_scene.get("ui_root") as Control).add_child(panel)
	panel.position = position
	panel.reset_size()
	mounted_panels.append(panel)
	panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX

func _portrait_slot(node: Node, key: String) -> Control:
	if node is Control and node.is_visible_in_tree() and str(node.get_meta("turn_order_actor_key", "")) == "enemy:" + key: return node
	for child: Node in node.get_children():
		var found: Control = _portrait_slot(child, key)
		if found != null: return found
	return null

func _picture(out: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture: Image = canvas.get_texture().get_image()
	_check(picture.get_size() == SIZE and picture.save_png(out) == OK, "native 1920x1080 PNG " + out)

func _finish_capture(out: String, report: Dictionary, view: String) -> void:
	report.merge({"view": view, "headless_semantics_only": DisplayServer.get_name() == "headless", "save": _arg("--save-dir"), "size": [1920,1080], "ui_scale": 1.0, "cel": OS.get_environment("LABYRINTH_CEL_LOOK"), "renderer_variant": "before" if _arg("--before", "false") == "true" else "after", "proof_time_scale": Engine.time_scale, "failures": failures})
	var file := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ATK13 CAPTURE %s: %s" % [view, "PASS" if failures.is_empty() else "FAIL"])
	for failure: String in failures: push_error(failure)
	native_scene.queue_free()
	for frame: int in range(PROOF_LAYOUT_FRAMES): await process_frame
	quit(0 if failures.is_empty() else 1)

func _prepare_native_scene() -> void:
	pass

func _strike_peak(effect: Dictionary, progress: float) -> bool:
	if str(effect.get("kind", "")) != "lightning_strikes": return false
	var phase: float = preload("res://scripts/lightning_strike_presentation.gd").impact_progress(effect, progress, _arg("--reduced-motion", "false") == "true")
	return phase >= 0.0 and is_equal_approx(preload("res://scripts/elemental_spell_fx.gd").envelope(phase), 1.0)

func _has_scheduled_peak(timeline: Array[Dictionary]) -> bool:
	return timeline.any(func(entry: Dictionary) -> bool: return bool(entry.get("bolt_peak", false)))
