extends "res://tests/guardian_ui_probe.gd"

## Actual RunScene initiative/action playback, with timed native captures.
## Extra HP and vision are confined to this art-observation fixture, allowing
## every helper and complete recovery to remain visible across three passes.
var gameplay: Array[Dictionary] = []
var display: TextureRect
var observed: Dictionary = {}

func _interactions(engine: RefCounted, combat: RefCounted) -> void:
	# Present the captured viewport in the native window throughout playback.
	# An empty root window can be throttled by macOS while the offscreen UI idles.
	display=TextureRect.new()
	display.texture=canvas.get_texture()
	display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	await super._interactions(engine,combat)
	var settings: Dictionary = scene.get("_settings")
	settings["reduced_motion"]=false
	scene.set("_settings",settings)
	for info: Dictionary in Guardians.DEFINITIONS.values():
		var state: Dictionary = Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":info["id"],"guardian_case":"encounter"})
		state["combat_state"]["umbra"]["vision_bonus"]=12
		state["combat_state"]["player"]["hp"]=999
		state["combat_state"]["player"]["max_hp"]=999
		state["player_hp"]=999
		state["player_max_hp"]=999

		await _load(state)
		for activation: int in range(4):
			if activation<2: await _play_guard_card(str(info["id"]),activation)
			var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
			var expected: Dictionary = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(before))["state"]
			scene.call("_on_pass_turn_pressed")
			await _record_runtime(str(info["id"])+"_%d"%activation)
			var after: Dictionary = scene.get("_combat_state")
			_check(after["player"]["hp"]==expected["player"]["hp"],"native playback applies damage once: "+str(info["id"]))
			_check(combat.is_player_turn(after),"native playback returns player input: "+str(info["id"]))
			_check_hand_visible(str(info["id"])+" after draw "+str(activation))
	for id: String in preload("res://scripts/guardian_cutout/renderer.gd").ACTOR_IDS:
		_check(observed.has(id) and (observed[id].has("strike") or observed[id].has("cast") or observed[id].has("brace")),"native enemy attacks use authored action motion "+id)
	var file := FileAccess.open("user://probes/guardian_ui/gameplay.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"clips":gameplay,"observed_actions":observed,"fixture_only":{"health":999,"vision_bonus":12},"size":[1920,1080],"ui_scale":1.0},"\t"))

func _record_runtime(label: String) -> void:
	var started: int = Time.get_ticks_usec()
	var next_capture: int = started
	var finish: int = 0
	var samples: Array[Dictionary] = []
	var images: Array[PackedByteArray] = []
	var board: Node = scene.get("board_view")
	while Time.get_ticks_usec()-started<45000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if bool(scene.get("_animation_lock")):
			finish=0
		elif finish==0:
			finish=now
		if now>=next_capture:
			next_capture=now+33333
			var poses: Dictionary = {}
			for enemy: Dictionary in (scene.get("_combat_state") as Dictionary).get("enemies",[]):
				var key: String = "enemy_%s"%enemy["id"]
				var snapshot: Dictionary = board.call("guardian_animation_snapshot",key)
				if snapshot.is_empty():continue
				var expected_art: String = str(enemy["type"])+"_cutout_v02"
				if str(snapshot.get("art",""))!=expected_art:
					var mismatch: String = "Retained renderer shows %s for %s"%[snapshot.get("art",""),expected_art]
					if not failures.has(mismatch):failures.append(mismatch)
				poses[key]=snapshot
				if bool(snapshot.get("active",false)) and str(snapshot.get("clip","idle")) not in ["idle","rest"]:
					var id: String = enemy["type"]
					if not observed.has(id):observed[id]={}
					observed[id][snapshot["clip"]]=true
			await RenderingServer.frame_post_draw
			images.append(canvas.get_texture().get_image().save_jpg_to_buffer(.93))
			samples.append({"seconds":float(now-started)/1000000.0,"poses":poses})
		if finish>0 and now-finish>180000:break
	_check(not bool(scene.get("_animation_lock")),"bounded complete playback "+label)
	var directory: String = "user://probes/guardian_ui/gameplay/"+label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for index: int in range(images.size()):
		var frame := FileAccess.open(directory.path_join("frame_%04d.jpg"%index),FileAccess.WRITE)
		frame.store_buffer(images[index])
	if not images.is_empty():
		var midpoint := Image.new()
		midpoint.load_jpg_from_buffer(images[images.size()/2])
		midpoint.save_png("user://probes/guardian_ui/runtime_"+label+".png")
	gameplay.append({"label":label,"samples":samples,"duration_seconds":float(Time.get_ticks_usec()-started)/1000000.0})

func _check_hand_visible(label: String) -> void:
	var hand: Array = (scene.get("_combat_state") as Dictionary)["deck"]["hand"]
	_check(not hand.is_empty(),label+" retains deck hand")
	_check((scene.get("hand_box") as Control).is_visible_in_tree(),label+" restores the live hand container")
	_check(not bool(scene.get("_locked_hand_cache_active")),label+" releases the frozen hand cache")
	for index: int in range(hand.size()):
		var widget: Control = scene.call("_hand_card_control",index)
		_check(is_instance_valid(widget) and widget.is_visible_in_tree() and widget.modulate.a>=.5,label+" renders live card "+str(index))

func _play_guard_card(id: String, activation: int) -> void:
	var state: Dictionary = scene.get("_combat_state")
	var hand: Array = state["deck"]["hand"]
	var chosen: int = -1
	for card: String in ["stone_plate","basalt_guard","patch_up","guarded_step"]:
		if hand.has(card) and bool((scene.call("_card_play_options_for_index",hand.find(card)) as Dictionary).get("printed_playable",false)):
			chosen=hand.find(card)
			break
	if chosen<0: return
	await scene.call("_on_card_pressed",chosen)
	if bool(scene.call("_pending_card_requires_confirmation")):
		scene.call("_on_confirm_card_play_pressed")
	else:
		var targets: Array = (scene.call("_active_card_preview") as Dictionary).get("target_tiles",[])
		if not targets.is_empty(): scene.call("_on_board_tile_clicked",targets[0])
	await _record_runtime(id+"_card_"+str(activation))
	_check(int(scene.get("_selected_card_index"))<0,"single card confirmation completed "+id)
	_check_hand_visible(id+" after card play")
