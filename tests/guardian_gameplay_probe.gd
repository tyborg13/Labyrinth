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
		# Each independent inspection save starts a fresh RunScene, as Continue does.
		# Reusing the prior synthetic card-demo scene retains deleted UI proxies.
		scene.queue_free()
		await process_frame
		scene=load("res://scenes/run_scene.tscn").instantiate()
		canvas.add_child(scene)
		await process_frame
		await _load(state)
		for activation: int in range(3):
			var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
			var expected: Dictionary = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(before))["state"]
			scene.call("_on_pass_turn_pressed")
			await _record_runtime(str(info["id"])+"_%d"%activation)
			var after: Dictionary = scene.get("_combat_state")
			_check(after["player"]["hp"]==expected["player"]["hp"],"native playback applies damage once: "+str(info["id"]))
			_check(combat.is_player_turn(after),"native playback returns player input: "+str(info["id"]))
	for id: String in preload("res://scripts/guardian_cutout/renderer.gd").ACTOR_IDS:
		_check(observed.has(id),"native enemy actions animate "+id)
	var file := FileAccess.open("user://probes/guardian_ui/gameplay.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"clips":gameplay,"observed_actions":observed,"fixture_only":{"health":999,"vision_bonus":12},"size":[1920,1080],"ui_scale":1.0},"\t"))

func _record_runtime(label: String) -> void:
	var started: int = Time.get_ticks_usec()
	var next_capture: int = started
	var finish: int = 0
	var samples: Array[Dictionary] = []
	var images: Array[PackedByteArray] = []
	var board: Node = scene.get("board_view")
	while Time.get_ticks_usec()-started<14000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if not bool(scene.get("_animation_lock")) and finish==0:finish=now
		if now>=next_capture:
			next_capture=now+33333
			var poses: Dictionary = {}
			for enemy: Dictionary in (scene.get("_combat_state") as Dictionary).get("enemies",[]):
				var key: String = "enemy_%s"%enemy["id"]
				var snapshot: Dictionary = board.call("guardian_animation_snapshot",key)
				if snapshot.is_empty():continue
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
