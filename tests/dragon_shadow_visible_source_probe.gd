extends "res://tests/dragon_pressure_presentation_probe.gd"
## Five-image addendum to v07's genuinely occluded Starless source.
## Staged setup, not native cadence: direct boss turns establish the held fan;
## a legal adjacent player start uses ordinary movement to relight a brazier,
## then spends its remaining two movement exposing the next fan endpoint.
## Visibility, declared geometry, effects and actor depth remain production-owned.
const Paths = preload("res://scripts/path_utils.gd")

func _run() -> void:
	source_hashes = _source_hashes()
	Store.set_storage_path("user://shadow_source_profile.json")
	Store.set_run_storage_path("user://shadow_source_run.save")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://shadow_source_events")
	Settings.set_storage_path("user://shadow_source_settings.json")
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
	canvas.add_child(scene)
	await process_frame
	await _visible_starless()
	_expect(source_hashes==_source_hashes(),"Named presentation inputs stay unchanged through capture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("witnesses.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"staged_visible_source_addendum","native_play":false,"failures":failures,"witnesses":witnesses,"source_hashes":source_hashes},"  "))
	print("DRAGON SHADOW VISIBLE SOURCE: ","PASS" if failures.is_empty() else "FAIL",failures)
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _visible_starless() -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var options: Dictionary = {"dragon_id":"noctyrax","dragon_depth":24}
	var run: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),Store.default_data()),options)
	var state: Dictionary = run["combat_state"].duplicate(true)
	var player_actor: Dictionary = state["current_actor"].duplicate(true)
	for turn: int in range(3):
		state["player"]["hp"] = 24
		state["player"]["max_hp"] = 24
		state = combat.resolve_enemy_turn_with_steps(state,0)["state"].duplicate(true)
	state["player"]["hp"] = 24
	state["player"]["max_hp"] = 24
	var held: Dictionary = state["enemies"][0]["intent"].duplicate(true)
	_expect(held.get("id","")=="starless_breath","Three real boss resolutions declare Starless Breath")
	var source: Vector2i = state["enemies"][0]["pos"]
	var dark_state: Dictionary = state.duplicate(true)
	_expect(not combat.umbra_visible_tiles(state).has(source),"Preserve v07's original hidden-source condition")
	var start := Vector2i(3,1)
	var destination := Vector2i(3,2)
	var occupied: Dictionary = combat._occupied_actor_tiles(state)
	_expect(Paths.is_passable(state["grid"],start) and not occupied.has(start),"Staged adjacent start is legal clear floor")
	_expect(not bool(state["guardian_braziers"][0]["lit"]) and state["guardian_braziers"][0]["pos"]==destination,"Authored nearby brazier starts unlit")
	state["player"]["pos"] = start
	state["current_actor"] = player_actor
	state["player_movement_remaining"] = combat.player_movement_capacity(state)
	_expect(combat.player_movement_targets(state).has(destination),"Normal movement budget permits the one-step relight")
	var before_move: Dictionary = state.duplicate(true)
	state = combat.apply_player_movement(state,destination)
	var movement: Dictionary = state.get("last_player_movement",{})
	_expect(bool(movement.get("resolved",false)) and int(movement.get("spent",0))==1 and state["player"]["pos"]==destination,"Real movement commits exactly one ordinary step")
	_expect(bool(state["guardian_braziers"][0]["lit"]),"Player arrival actually relights the authored brazier")
	_expect(combat.umbra_visible_tiles(state).has(source),"Actual engine visibility now includes the source")
	_expect(state["enemies"][0]["intent"]==held,"Relighting preserves the complete previously declared intent")
	witnesses.append({"setup":"Three direct boss resolutions; HP restored between setup turns; legal adjacent player start/current actor/normal movement pool staged. One actual movement then relights the authored brazier. No visibility override. Fan action only is played below; not a complete turn/cadence proof.","dark_state":dark_state,"before_movement":before_move,"after_movement":state.duplicate(true),"movement":movement,"held_intent":held,"engine_visible_tiles":combat.umbra_visible_tiles(state)})
	if not failures.is_empty(): return
	# The first receipt correctly exposed only the short rear-side endpoint.
	# Use the remaining normal movement, retaining the lit brazier and held fan.
	var endpoint_view := Vector2i(1,2)
	var before_view_move: Dictionary = state.duplicate(true)
	_expect(combat.player_movement_remaining(state)==2,"Relight leaves exactly two ordinary movement")
	_expect(combat.player_movement_targets(state).has(endpoint_view),"Remaining normal movement legally reaches the endpoint view")
	state = combat.apply_player_movement(state,endpoint_view)
	var view_movement: Dictionary = state.get("last_player_movement",{})
	_expect(bool(view_movement.get("resolved",false)) and int(view_movement.get("spent",0))==2 and state["player"]["pos"]==endpoint_view,"Real movement spends the remaining two steps")
	_expect(combat.player_movement_remaining(state)==0,"Total ordinary movement spent is three")
	var visible: Array[Vector2i] = combat.umbra_visible_tiles(state)
	_expect(bool(state["guardian_braziers"][0]["lit"]) and visible.has(source) and visible.has(Vector2i(1,3)),"Production Light and hero vision expose source and next outer endpoint")
	_expect(state["enemies"][0]["intent"]==held,"Both movement requests preserve the complete held intent")
	witnesses.append({"setup":"Source02 delta: spend the remaining two ordinary movement after real relight; no visibility or depth override.","before_view_movement":before_view_move,"after_view_movement":state.duplicate(true),"movement":view_movement,"held_intent":held,"engine_visible_tiles":visible})
	if not failures.is_empty(): return
	run["combat_state"] = state.duplicate(true)
	scene.set("_progression",run["progression"])
	scene.call("_load_run_state",run)
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	scene.set("_settings",settings)
	await process_frame
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state,0)
	var fan_steps: Array[Dictionary]
	for step: Dictionary in result["steps"]:
		if str(step.get("kind",""))=="intent" or (str(step.get("kind",""))=="aoe" and str(step.get("committed_shape",""))=="fan"):
			fan_steps.append(step.duplicate(true))
	witnesses.append({"resolver_steps":result["steps"],"played_fan_steps":fan_steps})
	await _play_capture(state.duplicate(true),fan_steps,"starless_breath")
	var action_key: String = "starless_breath_aoe_fan"
	for stage: String in ["release","stream","impact","dissipate"]:
		_expect(captured.has(action_key+"_"+stage),"Visible-source fan has "+stage+" pixels")
	for witness: Dictionary in witnesses:
		if str(witness.get("image","")).begins_with(action_key):
			_expect(bool(witness.get("source_visible",false)),"Captured fan retains production source visibility")
	if not impact_effects.has(action_key): return
	var reduced: Dictionary = settings.duplicate(true)
	reduced["reduced_motion"] = true
	scene.set("_settings",reduced)
	var effect: Dictionary = impact_effects[action_key]
	scene.call("_render_board_state",impact_states[action_key],{"effect":effect,"effect_progress":.62},true)
	await _capture(action_key+"_reduced")
	var board: Node = scene.get("board_view")
	var snapshot: Dictionary = board.call("noctyrax_animation_snapshot",str(effect["actor_key"]))
	_expect(snapshot.get("clip","")=="rest","Visible-source reduced rig stays still")
	witnesses.append({"image":action_key+"_reduced","tiles":Profile.tiles(effect),"reduced_motion":true,"snapshot":snapshot})

func _source_hashes() -> Dictionary:
	var result: Dictionary = super._source_hashes()
	result["tests/dragon_shadow_visible_source_probe.gd"] = FileAccess.get_sha256("res://tests/dragon_shadow_visible_source_probe.gd")
	return result
