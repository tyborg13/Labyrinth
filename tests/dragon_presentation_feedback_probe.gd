extends SceneTree

# Staged production animation witnesses, never evidence of encounter difficulty.
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Profile = preload("res://scripts/dragon_presentation.gd")
const Feedback = preload("res://scripts/combat_outcome_feedback.gd")
const OUTPUT: String = "user://probes/dragon_presentation_feedback"
const REQUIRED_ACTIONS: Dictionary = {
	"kindle_ground":["cinder_marks"],"cinderfall":["aoe"],"crownfire":["detonate_cinders"],"cinder_maw":["melee"],
	"stonewake":["raise_terrain","melee"],"worldspine_claw":["aoe"],"faultline":["terrain_burst"],"bedrock_breath":["aoe"],
	"skyhook":["ranged"],"razor_dive":["aoe"],"hollow_gale":["aoe"],"eye_of_storm":["aoe"],
	"crystal_mantle":["frost_armor","aoe"],"whiteout_lance":["aoe"],"rime_talon":["melee"],"shatterstorm":["aoe"],
	"skybreak":["lightning_strikes"],"storm_claw":["ranged"],"tempest_breath":["aoe"],"call_wisps":["ranged","summon"],
	"night_coil":["aoe"],"last_eclipse":["umbra_eclipse","summon"],"void_claw":["melee"],"starless_breath":["aoe"]}
var scene: Node
var canvas: SubViewport
var failures: Array[String]
var captured: Dictionary = {}
var witnesses: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://presentation_profile.json")
	Store.set_run_storage_path("user://presentation_run.save")
	Settings.set_storage_path("user://presentation_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var engine := Run.new()
	var combat := Combat.new()
	if OS.get_cmdline_user_args().has("--legacy-refuge-addendum"):
		await _legacy_refuge_addendum(engine,combat)
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--thar-order-addendum"):
		await _thar_order_addendum(engine,combat)
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--fan-addendum"):
		await _fan_addendum(engine,combat,settings)
		await _finish()
		return
	for boss_id: String in Profile.TYPES:
		var options: Dictionary = {"dragon_id":boss_id,"dragon_depth":24 if boss_id=="noctyrax" else 4}
		var original: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),Store.default_data()),options)
		await _idle_views(original,boss_id,settings)
		if boss_id == "zekarion": await _idle_views(original,"lightning_wisp",settings)
		var battle: Dictionary = original["combat_state"].duplicate(true)
		# This is an animation study: reset life between actions, retaining the
		# real resolver's targets, surfaces, movement and multi-action sequence.
		for phase: int in range(4):
			battle["player"]["hp"] = 24
			battle["player"]["max_hp"] = 24
			var intent_id: String = str(battle["enemies"][0]["intent"]["id"])
			# Stage both branches of multi-action intents: stand in Stonewake's
			# live melee reach, and leave a replacement slot for helper summons.
			if intent_id == "stonewake": battle["player"]["pos"] = Vector2i(3,4)
			if intent_id in ["call_wisps","last_eclipse"]:
				for helper: Dictionary in battle["enemies"]:
					if str(helper.get("type","")) != boss_id:
						helper["hp"] = 0
						break
			var run: Dictionary = original.duplicate(true)
			run["combat_state"] = battle.duplicate(true)
			await _load(run)
			await _capture(boss_id+"_"+intent_id+"_intent")
			var result: Dictionary = combat.resolve_enemy_turn_with_steps(battle,0)
			await _animate_capture(battle.duplicate(true),result["steps"],boss_id+"_"+intent_id)
			_expect_stages(boss_id+"_"+intent_id,REQUIRED_ACTIONS[intent_id])
			battle = result["state"].duplicate(true)
			# Reduced motion renders the same complete-area impact from the same
			# immutable step, without a travelling projectile or pose animation.
			for raw: Dictionary in result["steps"]:
				var effect: Dictionary = raw.duplicate(true)
				effect["enemy_type"] = boss_id
				if not effect.has("intent_id"): effect["intent_id"] = intent_id
				if not Profile.area_fx(effect): continue
				var reduced: Dictionary = settings.duplicate(true)
				reduced["reduced_motion"] = true
				scene.set("_settings",reduced)
				scene.call("_render_board_state",battle,{"effect":effect,"effect_progress":.62},true)
				await _capture(boss_id+"_"+intent_id+"_reduced")
				scene.set("_settings",settings)
				break
			if intent_id in ["stonewake","crystal_mantle","call_wisps","last_eclipse"]:
				await _reduced_playback_witness(run,boss_id,intent_id,settings)
		if boss_id == "iskaldra": await _mantle_witness(original,combat)
		if boss_id == "noctyrax": await _brazier_witness(original)
	await _empty_breath_witness(engine,combat)
	await _finish()

func _finish() -> void:
	var file := FileAccess.open(OUTPUT.path_join("witnesses.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"witnesses":witnesses},"  "))
	print("DRAGON PRESENTATION FEEDBACK: ","PASS" if failures.is_empty() else "FAIL",failures)
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _load(run: Dictionary) -> void:
	scene.call("_load_run_state",run)
	await process_frame
	await process_frame
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	scene.call("_set_show_all_enemy_intents",true)
	await create_timer(.12).timeout

func _idle_views(run: Dictionary, boss_id: String, settings: Dictionary) -> void:
	await _load(run)
	var source: Dictionary = run["combat_state"]
	var board: Node = scene.get("board_view")
	for reduced: bool in [false,true]:
		var mode: Dictionary = settings.duplicate(true)
		mode["reduced_motion"] = reduced
		scene.set("_settings",mode)
		for view: String in ["front","rear"]:
			var state: Dictionary = source.duplicate(true)
			var actors: Array[Dictionary]
			for enemy: Dictionary in state["enemies"]:
				var enemy_type: String = str(enemy["type"])
				if enemy_type != boss_id: continue
				actors.append(enemy)
				# One actual Wisp is sufficient to prove this shared renderer's
				# two views; the other helpers retain their natural facing.
				if boss_id == "lightning_wisp": break
			var player_tile: Vector2i = _idle_player_tile(state,actors,view)
			_expect(player_tile.x>=0,"Legal "+view+" viewing tile for "+boss_id)
			state["player"]["pos"] = player_tile
			scene.call("_render_board_state",state,{},true)
			await create_timer(.10).timeout
			for actor: Dictionary in actors:
				var snapshot: Dictionary = board.call(str(actor["type"])+"_animation_snapshot","enemy_%d" % int(actor["id"]))
				_expect(snapshot.get("facing","")==view,"Production idle facing "+str(actor["type"])+" / "+view)
				_expect(bool(snapshot.get("active",false)),"Visible production idle actor "+str(actor["type"])+" / "+view)
				_expect(snapshot.get("clip","")==("rest" if reduced else "idle"),"Production idle/reduced clip "+str(actor["type"]))
				witnesses.append({"image":boss_id+"_idle_"+view+("_reduced" if reduced else ""),"actor_type":actor["type"],"actor_id":actor["id"],"player_tile":player_tile,"snapshot":snapshot})
			await _capture(boss_id+"_idle_"+view+("_reduced" if reduced else ""))
	scene.set("_settings",settings)

func _idle_player_tile(state: Dictionary, actors: Array[Dictionary], view: String) -> Vector2i:
	var engine := Combat.new()
	var blocked: Dictionary = engine._player_blocking_tiles(state)
	var best := Vector2i(-1,-1)
	var score: int = 999999
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()):
			var tile := Vector2i(x,y)
			if blocked.has(tile) or not preload("res://scripts/path_utils.gd").is_passable(state["grid"],tile): continue
			state["player"]["pos"] = tile
			var matches: bool = true
			var distance: int = 0
			for actor: Dictionary in actors:
				var footprint: Vector2i = (scene.get("board_view") as Node).call("_resolved_unit_footprint",actor)
				var delta: Vector2i = tile*2-((actor["pos"] as Vector2i)*2+footprint-Vector2i.ONE)
				if preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(delta)["facing"] != view: matches = false
				if not engine.is_enemy_visible_to_player(state,actor): matches = false
				distance += absi(delta.x)+absi(delta.y)
			if matches and distance < score: best = tile; score = distance
	return best

func _expect_stages(prefix: String, actions: Array) -> void:
	for action: String in actions:
		for stage: String in ["prepare","release","impact"]:
			_expect(captured.has(prefix+"_"+action+"_"+stage),"Required semantic animation witness: "+prefix+" / "+action+" / "+stage)

func _animate_capture(state: Dictionary, steps: Array, prefix: String, expected: Dictionary = {}) -> void:
	var done: Dictionary = {"done":false}
	var images: Array[Dictionary]
	_play(state,steps,done)
	while not bool(done["done"]):
		await RenderingServer.frame_post_draw
		var board: Node = scene.get("board_view")
		var shown: Dictionary = board.get("presentation")
		var effect: Dictionary = shown.get("effect",{})
		if Profile.profile(effect).is_empty(): continue
		var progress: float = float(shown.get("effect_progress",-1))
		var action: String = str(effect.get("action_type",effect.get("kind","")))
		for sample: Dictionary in [{"name":"prepare","p":.20},{"name":"release","p":.40},{"name":"impact","p":.64}]:
			var key: String = prefix+"_"+action+"_"+str(sample["name"])
			if captured.has(key) or progress < float(sample["p"]) or progress > float(sample["p"])+.17: continue
			captured[key] = true
			_expect_banner_clear()
			var witness: Dictionary = {"image":key,"profile":Profile.profile(effect),"progress":progress,"tiles":Profile.tiles(effect).size(),"losses":effect.get("target_losses",[])}
			if not expected.is_empty():
				var actor_key: String = str(effect.get("actor_key",""))
				var motion: Dictionary = (shown.get("vyraketh_motion",{}) as Dictionary).get(actor_key,{})
				var snapshot: Dictionary = board.call("vyraketh_animation_snapshot",actor_key)
				var held: Vector2i = expected["direction"]
				var facing: Dictionary = preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(held)
				_expect(effect.get("action_direction",Vector2i.ZERO)==held and motion.get("direction",Vector2i.ZERO)==held,"Fan step and production motion retain the held direction: "+key)
				_expect(snapshot.get("clip","")=="cinderfall" and snapshot.get("facing","")==facing["facing"] and snapshot.get("mirrored",false)==facing["mirrored"],"Fan uses the expected active breath pose: "+key)
				_expect(_same_tiles(Profile.tiles(effect),expected["tiles"]),"Full fan survives every animation phase: "+key)
				witness["action_direction"] = held
				witness["motion"] = motion
				witness["snapshot"] = snapshot
			witnesses.append(witness)
			# Pull the completed frame immediately, then encode after the timed
			# action. PNG compression must not skip the next capture boundary.
			images.append({"name":key,"image":canvas.get_texture().get_image()})
	for capture: Dictionary in images: _save_image(capture["name"],capture["image"])

func _play(state: Dictionary, steps: Array, done: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps",state,steps)
	done["done"] = true

func _expect_banner_clear() -> void:
	var banner: Control = scene.get("action_banner")
	var boss_bar: Control = scene.get("_boss_health_overlay")
	if banner.visible and boss_bar.visible:
		_expect(not banner.get_global_rect().intersects(boss_bar.get_global_rect()),"Action banner clears persistent boss health/status overlay")

func _reduced_playback_witness(run: Dictionary, boss_id: String, intent_id: String, settings: Dictionary) -> void:
	# Exercise the actual Pass handler and its complete commit path. A directly
	# rendered still cannot prove that both sub-actions survive reduced motion.
	var combat := Combat.new()
	var playback_run: Dictionary = run.duplicate(true)
	var playback_state: Dictionary = playback_run["combat_state"]
	# The preceding isolated resolver study leaves current_actor on the boss.
	# Restore the fixture's player control without changing the declared intent,
	# queued actors, life, terrain or surfaces; subsequent turns use production.
	playback_state["current_actor"] = combat._player_actor_entry(int(playback_state.get("initiative_clock",0)),int(playback_state.get("activation_seq",0)))
	await _load(playback_run)
	var reduced: Dictionary = settings.duplicate(true)
	reduced["reduced_motion"] = true
	scene.set("_settings",reduced)
	var prefix: String = boss_id+"_"+intent_id
	var required: Array = REQUIRED_ACTIONS[intent_id]
	var seen: Dictionary = {}
	var checked_fields: Array[String]
	checked_fields.append_array(["player","enemies","terrain","traps","surfaces","guardian_braziers","umbra","turn_queue","initiative_clock"])
	for activation: int in range(4):
		var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
		var expected: Dictionary = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(before))["state"]
		_expect(expected.has("turn_queue"),"Reduced witness compares the actual scheduled actor queue: "+prefix)
		var images: Array[Dictionary]
		_expect(combat.is_player_turn(before),"Reduced witness starts on a real player activation: "+prefix)
		scene.call("_on_pass_turn_pressed")
		_expect(bool(scene.get("_animation_lock")),"Reduced witness enters the actual Pass lifecycle: "+prefix)
		var deadline: int = Time.get_ticks_msec()+15000
		while bool(scene.get("_animation_lock")) and Time.get_ticks_msec()<deadline:
			await RenderingServer.frame_post_draw
			var board: Node = scene.get("board_view")
			var shown: Dictionary = board.get("presentation")
			var effect: Dictionary = shown.get("effect",{})
			if str(effect.get("enemy_type",""))!=boss_id or str(effect.get("intent_id",""))!=intent_id: continue
			var action: String = str(effect.get("action_type",effect.get("kind","")))
			if not required.has(action) or seen.has(action) or Profile.profile(effect).is_empty(): continue
			seen[action] = true
			var key: String = prefix+"_"+action+"_reduced_playback"
			var snapshot: Dictionary = board.call(boss_id+"_animation_snapshot",str(effect.get("actor_key","")))
			_expect(bool(shown.get("reduced_motion",false)) and snapshot.get("clip","")=="rest","Actual reduced playback uses a still rig: "+key)
			_expect_banner_clear()
			images.append({"name":key,"image":canvas.get_texture().get_image()})
			witnesses.append({"image":key,"playback":"actual_pass","profile":Profile.profile(effect),"snapshot":snapshot,"tiles":Profile.tiles(effect).size()})
		_expect(not bool(scene.get("_animation_lock")),"Reduced Pass completes: "+prefix)
		if bool(scene.get("_animation_lock")):
			quit(1)
			return
		var after: Dictionary = scene.get("_combat_state")
		for field: String in checked_fields:
			_expect(after.get(field)==expected.get(field),"Reduced Pass preserves engine "+field+": "+prefix)
		for capture: Dictionary in images: _save_image(capture["name"],capture["image"])
		witnesses.append({"playback":"actual_pass","intent":prefix,"activation":activation,"checked_fields":checked_fields,"expected_hp":expected["player"]["hp"],"actual_hp":after["player"]["hp"],"expected_clock":expected.get("initiative_clock"),"actual_clock":after.get("initiative_clock")})
		if seen.size()==required.size(): break
	for action: String in required:
		_expect(seen.has(action),"Actual reduced Pass shows sub-action "+prefix+" / "+action)
	scene.set("_settings",settings)

func _mantle_witness(original: Dictionary, combat: RefCounted) -> void:
	var run: Dictionary = original.duplicate(true)
	var before: Dictionary = run["combat_state"]
	before["enemies"][0]["frost_armor"] = 2
	before["enemies"][0]["dragon_cycle"] = 2
	combat._assign_enemy_intent(before,0,RandomNumberGenerator.new())
	await _load(run)
	await _capture("iskaldra_mantle_2")
	var after: Dictionary = combat._damage_enemy(before.duplicate(true),0,7)
	var events: Array = scene.call("_surface_events_between",before,after)
	var texts: Array = scene.call("_player_action_floating_texts",before,after)
	scene.call("_render_board_state",after,{"surface_feedback_events":Feedback.prepare(events),"surface_feedback_progress":.35,"floating_texts":texts,"show_all_enemy_intents":true},true)
	await _capture("iskaldra_mantle_break_2_to_1")
	var cells: Dictionary = scene.get("_boss_status_cells")
	_expect((cells["frost_armor"]["label"] as Label).text=="Mantle 1","Boss health overlay updates when only Mantle changes")
	var rows: Array = (scene.get("board_view") as Node).call("_intent_rows_for_unit",after["enemies"][0],after["enemies"][0]["intent"])
	_expect(preload("res://scripts/action_icon_library.gd").plain_text_for_rows(rows).contains("Ring 1–2"),"Shatterstorm shrinks after a Mantle break")

func _brazier_witness(original: Dictionary) -> void:
	var run: Dictionary = original.duplicate(true)
	run["combat_state"]["guardian_braziers"][0]["lit"] = false
	await _load(run)
	await _capture("noctyrax_dark_brazier_relight_action")

func _legacy_refuge_addendum(engine: RefCounted, combat: RefCounted) -> void:
	var options: Dictionary = {"dragon_id":"noctyrax","dragon_depth":24}
	var original: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),Store.default_data()),options)
	var board: Node = scene.get("board_view")
	var icons = preload("res://scripts/action_icon_library.gd")
	for variant: String in ["current_coil","legacy_eclipse","legacy_coil"]:
		var run: Dictionary = original.duplicate(true)
		var state: Dictionary = run["combat_state"]
		var brazier: Dictionary = state["guardian_braziers"][0]
		state["player"]["pos"] = brazier["pos"]
		if variant=="legacy_eclipse":
			state["enemies"][0]["intent"] = {"id":"last_eclipse","name":"Last Eclipse","time":6,"actions":[{"type":"umbra_eclipse","damage":8,"element":"shadow","duration":2,"snuff_brazier":true,"brazier_id":brazier["id"]}]}
		elif variant=="legacy_coil":
			state["enemies"][0]["intent"]["restore_braziers"] = true
			for action: Dictionary in state["enemies"][0]["intent"]["actions"]:
				action.erase("snuff_brazier")
				action.erase("brazier_id")
			for refuge: Dictionary in state["guardian_braziers"]: refuge["lit"] = false
		# Match the persisted warning contract, including Variant restoration.
		run = bytes_to_var(var_to_bytes(run))
		await _load(run)
		var markers: Array = board.call("_noctyrax_brazier_markers")
		var actor: Dictionary = run["combat_state"]["enemies"][0]
		var rows: Array = board.call("_intent_rows_for_unit",actor,actor["intent"])
		var text: String = icons.plain_text_for_rows(rows)
		_expect(markers.size()==2,"Both refuge markers remain visible: "+variant)
		for marker: Dictionary in markers:
			if bool(marker["threatened"]):
				var expected: String = "Use another Light" if variant=="legacy_eclipse" else "Relight after Night Coil"
				_expect(marker["detail"]==expected,"Marked refuge explains its actual warning: "+variant)
				_expect(not str(marker["tooltip"]).contains("Last Procession"),"Dragon refuge never uses Guardian recovery copy")
			elif variant=="legacy_coil":
				_expect(marker["detail"]=="Relights after Night Coil","Legacy Coil retains its automatic recovery promise")
		if variant=="legacy_eclipse":
			_expect(text.contains("Snuff before hit"),"Legacy Eclipse intent explains immediate snuff")
			_expect(icons.brazier_rule_tooltip(actor["intent"]["actions"][0]).contains("before this Eclipse"),"Legacy Eclipse tooltip describes the saved action")
			_expect(combat.enemy_threat_tiles(run["combat_state"],0)["attack"].has(brazier["pos"]),"Legacy snuffed refuge remains mechanically unsafe")
		elif variant=="legacy_coil": _expect(text.contains("Braziers relight afterward"),"Legacy Coil intent retains its promised relight")
		witnesses.append({"image":"noctyrax_refuge_"+variant,"markers":markers,"intent_text":text})
		await _capture("noctyrax_refuge_"+variant)

func _thar_order_addendum(engine: RefCounted, combat: RefCounted) -> void:
	# Production depth-eight room and authored terrain. This staged sequence
	# witnesses overlapping warnings and FX, not difficulty or player strategy.
	var options: Dictionary = {"dragon_id":"tharokh","dragon_depth":8}
	var run: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),Store.default_data()),options)
	var state: Dictionary = run["combat_state"]
	state["player"]["pos"] = Vector2i(3,4)
	_expect(state["enemies"][0]["intent"]["id"]=="stonewake","Thar order witness starts with Stonewake")
	state = combat.resolve_enemy_turn_with_steps(state,0)["state"]
	_expect(state["enemies"][0]["intent"]["id"]=="worldspine_claw","Stonewake advances to Claw")
	state["player"]["pos"] = Vector2i(1,3)
	state = combat.resolve_enemy_turn_with_steps(state,0)["state"]
	_expect(state["enemies"][0]["intent"]["id"]=="bedrock_breath","Claw advances to Bedrock before Faultline")
	_expect(not combat._dragon_spires(state).is_empty(),"Spires survive into the Bedrock warning")
	# Move to a legal nearby observer after declaration; the held lane must
	# remain aimed west while both the surviving obstacles and Rubble are shown.
	state["player"]["pos"] = Vector2i(1,2)
	_expect(not combat._player_blocking_tiles(state).has(state["player"]["pos"]),"Thar overlap observer has a legal free tile")
	for intent_id: String in ["bedrock_breath","faultline"]:
		_expect(state["enemies"][0]["intent"]["id"]==intent_id,"Current authored Thar order: "+intent_id)
		run["combat_state"] = state
		await _load(run)
		var prefix: String = "tharokh_order_"+intent_id
		await _capture(prefix+"_intent")
		var spires: Array = combat._dragon_spire_tiles(state)
		var rubble: Array = preload("res://scripts/board_surface_rules.gd").tiles(state,"rubble")
		_expect(not spires.is_empty(),"Spires remain available for counterplay: "+intent_id)
		if intent_id=="faultline": _expect(not rubble.is_empty(),"Bedrock Rubble remains during Faultline warning")
		witnesses.append({"image":prefix+"_intent","intent_id":intent_id,"spires":spires,"rubble":rubble,"threat_tiles":combat.enemy_threat_tiles(state,0)["attack"]})
		var result: Dictionary = combat.resolve_enemy_turn_with_steps(state,0)
		await _animate_capture(state.duplicate(true),result["steps"],prefix)
		_expect_stages(prefix,REQUIRED_ACTIONS[intent_id])
		state = result["state"]
	_expect(combat._dragon_spires(state).is_empty(),"Faultline consumes all remaining spires")
	_expect(state["enemies"][0]["intent"]["id"]=="stonewake","Faultline completes the cycle")
	run["combat_state"] = state
	await _load(run)
	await _capture("tharokh_order_after_faultline")

func _fan_addendum(engine: RefCounted, combat: RefCounted, settings: Dictionary) -> void:
	# Narrow geometry/presentation study: remove breakable cover and put the 2x2
	# body one column east so the complete authored fan fits the real room grid.
	# Keep normal Fringe visibility; no fake damage, Light or vision is added.
	var options: Dictionary = {"dragon_id":"vyraketh","dragon_depth":4}
	var run: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),Store.default_data()),options)
	var state: Dictionary = run["combat_state"]
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["enemies"][0]["pos"] = Vector2i(5,3)
	state["enemies"][0]["dragon_cycle"] = 0
	state["player"]["pos"] = Vector2i(3,3)
	combat._assign_enemy_intent(state,0,RandomNumberGenerator.new())
	var actor: Dictionary = state["enemies"][0]
	var intent: Dictionary = actor["intent"]
	var action: Dictionary = intent["actions"][0]
	var declared: Array = action["declared_tiles"]
	var full_fan: Array[Vector2i]
	for y: int in range(2,6):
		full_fan.append(Vector2i(4,y))
		full_fan.append(Vector2i(3,y))
	for y: int in range(1,7): full_fan.append(Vector2i(2,y))
	_expect(str(intent["id"])=="cinderfall" and int(action.get("pattern_min_flank",0))==1,"Fan addendum uses current authored Cinder Breath shoulders")
	_expect(action.get("declared_direction",Vector2i.ZERO)==Vector2i.LEFT,"Shoulder fixture declares a left-facing breath")
	_expect(_same_tiles(declared,full_fan),"Declared Cinder Breath is the complete 4/4/6 fan")
	_expect(declared.has(Vector2i(4,2)) and declared.has(Vector2i(4,5)),"Both first-row shoulder cells are threatened")
	_expect(not declared.has(Vector2i(5,2)) and not declared.has(Vector2i(5,5)),"Close lateral cells beside the body remain outside the fan")
	# Declare from the cardinal front first; a diagonal declaration may legally
	# choose the other cardinal axis. Enter the new shoulder without redeclaring.
	state["player"]["pos"] = Vector2i(4,5)
	await _load(run)
	var board: Node = scene.get("board_view")
	var rows: Array = board.call("_intent_rows_for_unit",actor,intent)
	var miniature: Array = []
	for row: Array in rows:
		for token: Dictionary in row:
			if str(token.get("kind",""))=="aoe_pattern": miniature=token.get("pattern",[])
	var miniature_tiles: Array[Vector2i]
	for cell: Array in miniature: miniature_tiles.append(Vector2i(5+int(cell[1]),4-int(cell[0])))
	_expect(_same_tiles(miniature_tiles,full_fan),"Live intent miniature matches all fourteen footprint-relative cells")
	await _capture("vyraketh_fan_shoulders_intent")
	# This is a safe cell outside the newly widened first row. Moving there must
	# not redeclare the fan, and all fourteen cells stay within normal visibility.
	state["player"]["pos"] = Vector2i(3,6)
	_expect(not combat._player_blocking_tiles(state).has(state["player"]["pos"]) and preload("res://scripts/path_utils.gd").is_passable(state["grid"],state["player"]["pos"]),"Miss observer stands on a legal unoccupied tile")
	var visible: int = 0
	for tile: Vector2i in declared:
		if combat.is_tile_visible_to_player(state,tile): visible += 1
	_expect(visible==14 and not declared.has(state["player"]["pos"]),"Safe observer sees all fourteen fan cells")
	_expect(_same_tiles(combat.enemy_intent_plan(state,0)["projected_attack"],full_fan),"Escaping the shoulder does not retarget the committed warning")
	await _load(run)
	await _capture("vyraketh_fan_escaped_intent")
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state,0)
	var breath: Dictionary = {}
	for step: Dictionary in result["steps"]:
		if str(step.get("kind",""))=="aoe": breath=step.duplicate(true); break
	_expect(not breath.is_empty() and _same_tiles(breath.get("tiles",[]),full_fan),"Missed breath retains the whole widened animation area")
	_expect((breath.get("target_losses",[]) as Array).is_empty() and int(result["state"]["player"]["hp"])==int(state["player"]["hp"]),"Missed widened breath causes no player damage")
	witnesses.append({"image":"vyraketh_fan_shoulders_intent","pattern_min_flank":action.get("pattern_min_flank"),"declared_tiles":declared,"miniature":miniature,"first_row_shoulders":[Vector2i(4,2),Vector2i(4,5)],"safe_player_tile":state["player"]["pos"],"visible_tiles":visible,"player_hp_unchanged":int(result["state"]["player"]["hp"])==int(state["player"]["hp"])})
	await _animate_capture(state.duplicate(true),result["steps"],"vyraketh_fan_miss",{"direction":Vector2i.LEFT,"tiles":full_fan})
	_expect_stages("vyraketh_fan_miss",["aoe"])
	var reduced: Dictionary = settings.duplicate(true)
	reduced["reduced_motion"] = true
	scene.set("_settings",reduced)
	breath["enemy_type"] = "vyraketh"
	breath["intent_id"] = "cinderfall"
	scene.call("_render_board_state",result["state"],{"effect":breath,"effect_progress":.64},true)
	await _capture("vyraketh_fan_miss_reduced")
	var snapshot: Dictionary = board.call("vyraketh_animation_snapshot",str(breath.get("actor_key","")))
	_expect(snapshot.get("clip","")=="rest","Widened fan reduced-motion still keeps the rig at rest")
	witnesses.append({"image":"vyraketh_fan_miss_reduced","tiles":breath.get("tiles",[]),"snapshot":snapshot})
	scene.set("_settings",settings)

func _same_tiles(actual: Array, expected: Array) -> bool:
	if actual.size()!=expected.size(): return false
	for tile: Vector2i in expected:
		if not actual.has(tile): return false
	return true

func _empty_breath_witness(engine: RefCounted, combat: RefCounted) -> void:
	var options: Dictionary = {"dragon_id":"vyraketh","dragon_depth":4}
	var run: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),Store.default_data()),options)
	var state: Dictionary = run["combat_state"]
	state["enemies"][0]["dragon_cycle"] = 0
	combat._assign_enemy_intent(state,0,RandomNumberGenerator.new())
	var declared: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"]
	var blocked: Dictionary = combat._player_blocking_tiles(state)
	var best := Vector2i(-1,-1)
	var most_visible: int = -1
	var nearest: int = 999999
	var initial_player: Vector2i = state["player"]["pos"]
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()):
			var tile := Vector2i(x,y)
			if blocked.has(tile) or declared.has(tile) or not preload("res://scripts/path_utils.gd").is_passable(state["grid"],tile): continue
			state["player"]["pos"] = tile
			var visible: int = 0
			for target: Vector2i in declared:
				if combat.is_tile_visible_to_player(state,target): visible += 1
			var distance: int = absi(tile.x-initial_player.x)+absi(tile.y-initial_player.y)
			if visible > most_visible or (visible==most_visible and distance<nearest):
				best = tile
				most_visible = visible
				nearest = distance
	_expect(best.x>=0 and most_visible>0,"Empty breath has a legal safe observer and visible impact tiles")
	state["player"]["pos"] = best
	await _load(run)
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state,0)
	_expect(int(result["state"]["player"]["hp"])==int(state["player"]["hp"]),"Empty breath leaves the safe observer unharmed")
	witnesses.append({"image":"vyraketh_empty_breath_aoe_impact","player_tile":best,"visible_tiles":most_visible,"declared_tiles":declared.size(),"player_hp_unchanged":int(result["state"]["player"]["hp"])==int(state["player"]["hp"])})
	var empty: bool = false
	for step: Dictionary in result["steps"]:
		if str(step.get("kind","")) == "aoe" and not (step.get("tiles",[]) as Array).is_empty() and (step.get("target_losses",[]) as Array).is_empty(): empty = true
	_expect(empty,"Empty committed breath retains a full animation step")
	await _animate_capture(state.duplicate(true),result["steps"],"vyraketh_empty_breath")
	_expect_stages("vyraketh_empty_breath",["aoe"])

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_save_image(name,image)

func _save_image(name: String, image: Image) -> void:
	_expect(image.get_size()==Vector2i(1920,1080),"Required native proof size")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = OUTPUT.path_join(name+".png")
	_expect(image.save_png(path)==OK,"Capture saved: "+name)
	print(ProjectSettings.globalize_path(path))

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
