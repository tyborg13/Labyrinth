extends SceneTree
## Staged production presentation proof, not a tactical playtest.
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Profile = preload("res://scripts/dragon_presentation.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const OUTPUT: String = "user://probes/dragon_pressure_presentation"
var scene: Node
var canvas: SubViewport
var settings: Dictionary
var failures: Array[String]
var witnesses: Array[Dictionary]
var captured: Dictionary = {}
var impact_effects: Dictionary = {}
var impact_states: Dictionary = {}
var source_hashes: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	source_hashes = _source_hashes()
	Store.set_storage_path("user://pressure_presentation_profile.json")
	Store.set_run_storage_path("user://pressure_presentation_run.save")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://pressure_presentation_events")
	Settings.set_storage_path("user://pressure_presentation_settings.json")
	settings = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(preload("res://tests/fixtures/dragon_exchange_run_scene.gd"))
	canvas.add_child(scene)
	await process_frame
	await preload("res://tests/suites/dragon_exchange_presentation_suite.gd").run(self,scene,_expect,_capture)
	await _noctyrax()
	await _coil_tooltip()
	_expect(source_hashes==_source_hashes(),"Named presentation inputs stay unchanged through capture")
	var file := FileAccess.open(OUTPUT.path_join("witnesses.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"witnesses":witnesses,"source_hashes":source_hashes},"  "))
	print("DRAGON PRESSURE PRESENTATION: ","PASS" if failures.is_empty() else "FAIL",failures)
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _noctyrax() -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var options: Dictionary = {"dragon_id":"noctyrax","dragon_depth":24}
	var run: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),Store.default_data()),options)
	var state: Dictionary = run["combat_state"].duplicate(true)
	for turn: int in range(4):
		state["player"]["hp"] = 24
		state["player"]["max_hp"] = 24
		var intent: String = str(state["enemies"][0]["intent"]["id"])
		run["combat_state"] = state.duplicate(true)
		scene.set("_progression",run["progression"])
		scene.call("_load_run_state",run)
		scene.call("_close_dialogue")
		scene.call("_close_large_map")
		scene.set("_settings",settings)
		await process_frame
		var result: Dictionary = combat.resolve_enemy_turn_with_steps(state,0)
		await _play_capture(state.duplicate(true),result["steps"],intent)
		for action_key: String in impact_effects:
			if not action_key.begins_with(intent+"_"): continue
			# Replay the exact complete-area effect observed in normal playback,
			# not an auxiliary snuff/prepare step sharing the same intent id.
			var effect: Dictionary = impact_effects[action_key].duplicate(true)
			_expect(not Profile.tiles(effect).is_empty(),action_key+" reduced proof retains the actual impact area")
			var reduced: Dictionary = settings.duplicate(true)
			reduced["reduced_motion"] = true
			scene.set("_settings",reduced)
			scene.call("_render_board_state",impact_states[action_key],{"effect":effect,"effect_progress":.62},true)
			await _capture(action_key+"_reduced")
			var board: Node = scene.get("board_view")
			var snapshot: Dictionary = board.call("noctyrax_animation_snapshot",str(effect["actor_key"]))
			_expect(snapshot.get("clip","")=="rest",action_key+" reduced rig stays still")
			witnesses.append({"image":action_key+"_reduced","tiles":Profile.tiles(effect),"reduced_motion":true,"snapshot":snapshot})
		state = result["state"].duplicate(true)
	for action_key: String in ["night_coil_aoe_line","last_eclipse_umbra_eclipse","last_eclipse_aoe_refuge","void_claw_aoe_refuge","starless_breath_aoe_fan","starless_breath_aoe_refuge"]:
		for stage: String in ["release","impact","dissipate"]:
			_expect(captured.has(action_key+"_"+stage),"Each primary/secondary area action is rendered: "+action_key+" / "+stage)

	_expect(captured.has("starless_breath_aoe_fan_stream"),"Starless breath includes a late-travel sample before contact")

func _play_capture(state: Dictionary, steps: Array, intent: String) -> void:
	var done: Dictionary = {"done":false}
	var images: Array[Dictionary]
	_play(state,steps,done)
	while not bool(done["done"]):
		await RenderingServer.frame_post_draw
		var shown: Dictionary = (scene.get("board_view") as Node).get("presentation")
		var effect: Dictionary = shown.get("effect",{})
		if not Profile.area_fx(effect) or Profile.tiles(effect).is_empty(): continue
		var shape: String = str(effect.get("committed_shape",""))
		var action_key: String = intent+"_"+str(effect.get("action_type",effect.get("kind","")))+("_"+shape if not shape.is_empty() else "")
		if shape=="refuge": _expect(Profile.profile(effect).get("geometry","")=="ground","Refuge sweep is ground shadow, without a claw or source ray")
		var p: float = float(shown.get("effect_progress",-1.0))
		for sample: Dictionary in [{"name":"release","p":.40},{"name":"stream","p":.48},{"name":"impact","p":.62},{"name":"dissipate","p":.84}]:
			if sample["name"]=="stream" and Profile.profile(effect).get("geometry","")!="breath": continue
			var key: String = action_key+"_"+str(sample["name"])
			var latest: float = Profile.CONTACT if sample["name"]=="stream" else float(sample["p"])+.15
			if captured.has(key) or p<float(sample["p"]) or p>=latest: continue
			captured[key] = true
			var board: Node = scene.get("board_view")
			if str(sample["name"])=="impact":
				impact_effects[action_key] = effect.duplicate(true)
				impact_states[action_key] = (board.get("combat_state") as Dictionary).duplicate(true)
			var marker_rects: Array[Rect2]
			var hud: Control = board.get("_hud_render_layer")
			# Read actual retained draw registrations, not a fresh layout solve:
			# a logically clear next layout can still leave stale pixels on screen.
			for region: Dictionary in hud.get("_tooltip_regions"):
				var tooltip: String = str(region.get("tooltip",""))
				if not tooltip.contains("brazier") and not tooltip.contains("Eclipse"): continue
				var global_rect: Rect2 = hud.get_global_transform_with_canvas()*(region["rect"] as Rect2)
				marker_rects.append(global_rect)
				_expect(not global_rect.intersects((scene.get("action_banner") as Control).get_global_rect()),key+" brazier labels clear the action banner")
			_expect(marker_rects.size()>=2,key+" inspects actual drawn brazier regions")
			images.append({"name":key,"image":canvas.get_texture().get_image()})
			var source_tile: Vector2i = effect.get("from",Vector2i(-1,-1))
			var origin_visible: bool = board.call("_board_tile_is_visible_to_player",source_tile)
			var source_point: Vector2 = board.call("_dragon_spell_source",str(effect.get("actor_key","")),Vector2.ZERO)
			witnesses.append({"image":key,"progress":p,"profile":Profile.profile(effect),"tiles":Profile.tiles(effect),"effect":effect.duplicate(true),"origin_visible":origin_visible,"source_visible":origin_visible and not bool(effect.get("umbra_action_clipped",false)),"source_point":source_point,"brazier_rects":marker_rects,"action_banner_rect":(scene.get("action_banner") as Control).get_global_rect()})
	for frame: Dictionary in images: _save(frame["name"],frame["image"])

func _play(state: Dictionary, steps: Array, done: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps",state,steps)
	done["done"] = true

func _coil_tooltip() -> void:
	var state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	state["relics"] = ["stormroad_coil"]
	scene.call("_load_run_state",state)
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await process_frame
	var badge: Control
	for child: Node in (scene.get("_relic_icon_grid") as Control).get_children():
		if child.get_meta("relic_id","")=="stormroad_coil": badge = child
	_expect(badge != null,"Coil badge exists")
	if badge == null: return
	var tooltip: Control = badge.call("_make_custom_tooltip",badge.tooltip_text)
	var layer := CanvasLayer.new()
	layer.layer = 100
	canvas.add_child(layer)
	layer.add_child(tooltip)
	tooltip.position = Vector2(620,140)
	await _capture("stormroad_coil_short_rules")
	layer.queue_free()

func _capture(name: String) -> void:
	if name in ["exchange_normal","exchange_reduced","exchange_ack_retry_success"]:
		# A fixed timer plus PNG/readback scheduling can sample the late fade.
		# Observe the production receipt after drawing, without pausing its clock.
		var receipt: Control = scene.find_child("MoltShardExchangeFeedback",true,false)
		var deadline: int = Time.get_ticks_msec()+1200
		await RenderingServer.frame_post_draw
		while is_instance_valid(receipt) and float(receipt.get("phase")) < .16 and Time.get_ticks_msec()<deadline:
			await RenderingServer.frame_post_draw
		_expect(is_instance_valid(receipt),name+" receipt exists at the plateau")
		if not is_instance_valid(receipt): return
		var phase: float = float(receipt.get("phase"))
		_expect(phase>=.16 and phase<=.70 and receipt.modulate.a>.98,name+" captures the real readable plateau")
		witnesses.append({"image":name,"receipt_phase":phase,"receipt_opacity":receipt.modulate.a,"reduced_motion":receipt.get("reduced")})
		_save(name,canvas.get_texture().get_image())
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_save(name,canvas.get_texture().get_image())

func _save(name: String, image: Image) -> void:
	_expect(image.get_size()==Vector2i(1920,1080),"Native 1920×1080 capture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = OUTPUT.path_join(name+".png")
	_expect(image.save_png(path)==OK,"Saved "+name)
	print(ProjectSettings.globalize_path(path))

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["scripts/dragon_shadow_fx.gd","scripts/elemental_spell_fx.gd","scripts/elemental_spell_sprite_batch.gd","scripts/dragon_spell_presentation.gd","scripts/dragon_presentation.gd","scripts/molt_exchange_feedback.gd","scripts/combat_board_view.gd","scripts/run_scene.gd","scripts/dragon_pressure_fields.gd","scripts/combat_engine.gd","data/enemies.json","data/relics.json","tests/dragon_pressure_presentation_probe.gd","tests/suites/dragon_exchange_presentation_suite.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result
