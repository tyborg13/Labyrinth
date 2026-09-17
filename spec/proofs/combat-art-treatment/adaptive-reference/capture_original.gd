extends "res://tests/combat_lighting_variants_probe.gd"
## Real generated density examples plus synthetic shader-only overlap assertions.
## --baseline records the pre-rebalance renderer without the new bounds gate.

const Treatment = preload("res://scripts/combat_art_treatment.gd")

class LightSwatch extends Node2D:
	var texture: Texture2D
	func _init() -> void:
		var pixels := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		pixels.fill(Color(0.35, 0.35, 0.35, 1.0))
		texture = ImageTexture.create_from_image(pixels)
	func _draw() -> void:
		Treatment.draw_rect(self, texture, Rect2(0, 0, 256, 128), Color.WHITE, Treatment.FLOOR)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://density_progression.json")
	ProgressionStore.set_run_storage_path("user://density_run.save")
	SettingsStore.set_storage_path("user://density_settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = VIEWPORT_SIZE
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var view := SubViewport.new()
	view.size = VIEWPORT_SIZE
	view.msaa_2d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.disable_3d = true
	root.add_child(view)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(instance)
	await _settle()
	var rooms: Dictionary = _find_density_rooms()
	_expect(rooms.has(2) and rooms.has(4), "Find natural two- and four-column combats")
	var captures: Array[Dictionary]
	for count: int in [2, 4]:
		if not rooms.has(count):
			continue
		var saved: Dictionary = rooms[count]
		instance.call("_load_run_state", saved)
		instance.call("_close_dialogue")
		instance.set("_settings", settings)
		instance.call("_refresh_ui")
		await _settle()
		_freeze(instance)
		var board: Control = instance.get_node("BoardUnderlay/CombatBoard")
		var state: Dictionary = board.get("combat_state")
		var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
		presentation["ambient_time_seconds"] = 1.25
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		var issues: Array[String] = _scenario_issues(saved, state, board)
		_expect(issues.is_empty(), "Real generated density encounter: " + str(issues))
		_expect(int((board.call("art_treatment_snapshot") as Dictionary)["light_count"]) == count, "Only real columns provide light")
		var first: Image
		for look: String in LightingProfiles.ids():
			board.call("set_art_treatment_preset", look)
			var filename: String = "%02d_columns_%s.png" % [count, look]
			await _capture(view, filename)
			var frame: Image = view.get_texture().get_image()
			if first == null:
				first = frame
			else:
				_expect(_difference(first, frame, Rect2i(0, 80, 290, 540)) == 0.0, "Density tuning preserves backdrop")
				_expect(_difference(first, frame, Rect2i(440, 790, 965, 260)) == 0.0, "Density tuning preserves cards")
			var values: Dictionary = LightingProfiles.definition(look)
			var tint: Vector3 = values["tint"]
			values["tint"] = [tint.x, tint.y, tint.z]
			captures.append({"image": filename, "profile": look, "values": values, "seed": saved["seed"], "room": str(saved["current_room"]), "name": saved["current_room_layout"]["name"], "columns": count, "issues": issues})
		print("DENSITY ROOM: ", JSON.stringify(captures[-1]))
	var samples: Dictionary = await _verify_overlap()
	var file := FileAccess.open(OUTPUT_DIR.path_join("density-capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "size": [1920, 1080], "ui_scale": 1.0, "baseline": OS.get_cmdline_user_args().has("--baseline"), "captures": captures, "shader_samples": samples, "passed": _errors.is_empty()}, "\t"))
	view.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print("LIGHTING DENSITY PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _find_density_rooms() -> Dictionary:
	var result: Dictionary = {}
	var engine := RunEngine.new()
	for seed_value: int in range(62001, 62301):
		var fresh: Dictionary = engine.create_new_run(seed_value, ProgressionStore.default_data())
		var coord := Vector2i(1, 1)
		var room: Dictionary = engine.room_metadata(fresh, coord).duplicate(true)
		if str(room.get("type", "")) != "combat":
			continue
		# Same production-layout recipe as inspection_fixture.gd. Never convert
		# a merchant room or invent columns, units, positions, loot or terrain.
		room["revealed"] = true
		room["visited"] = true
		room["cleared"] = false
		fresh["rooms"]["1,1"] = room
		fresh["current_room"] = coord
		var layout: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i(1, 0), fresh)
		var state: Dictionary = CombatEngine.new().create_combat(seed_value, layout, engine.call("_player_snapshot", fresh))
		fresh["current_room_layout"] = layout
		fresh["combat_state"] = state
		fresh["mode"] = "combat"
		if (state.get("enemies", []) as Array).size() != 3:
			continue
		var count: int = 0
		for row: Array in state.get("grid", []):
			count += row.count("pillar")
		if count in [2, 4] and not result.has(count):
			result[count] = fresh
		if result.size() == 2:
			break
	return result

func _verify_overlap() -> Dictionary:
	var view := SubViewport.new()
	view.size = Vector2i(256, 128)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var swatch := LightSwatch.new()
	var treatment := Treatment.new()
	swatch.material = treatment.material
	view.add_child(swatch)
	var samples: Dictionary = {}
	for look: String in ["warm", "balanced"]:
		treatment.set_preset(look)
		var colors: Array[Color]
		var rgb: Array
		for count: int in [0, 1, 2, 4, 24]:
			var sources: Array[Dictionary]
			for index: int in range(count):
				sources.append({"point": Vector2(128, 64), "radius": 300.0, "color": Color(1.0, 0.68, 0.36, 0.8)})
			treatment.configure(sources, "", true)
			await _settle()
			await RenderingServer.frame_post_draw
			var color: Color = view.get_texture().get_image().get_pixel(128, 64)
			colors.append(color)
			rgb.append([color.r, color.g, color.b])
		# Real GPU output checks: local lighting survives, distant lights cannot
		# dim a nearby source, and overlapping lights cannot flood neutral art.
		var distant: Array[Dictionary]
		distant.append({"point": Vector2(128, 64), "radius": 300.0, "color": Color(1.0, 0.68, 0.36, 0.8)})
		for index: int in range(23):
			distant.append({"point": Vector2(10000 + index * 100, 64), "radius": 300.0})
		treatment.configure(distant, "", true)
		await _settle()
		await RenderingServer.frame_post_draw
		var far: Color = view.get_texture().get_image().get_pixel(128, 64)
		_expect(far.is_equal_approx(colors[1]), "Distant lights do not dim an isolated nearby torch")
		_expect(colors[1].r - colors[0].r > 0.035, "A single local source remains visibly present")
		if not OS.get_cmdline_user_args().has("--baseline"):
			for index: int in range(1, colors.size()):
				var added: Color = colors[index] - colors[0]
				_expect(added.r - added.b < 0.10 and added.r < 0.14, "Every tested overlap count keeps colored energy bounded")
				_expect(added.r > added.g and added.g > added.b, "Accumulation preserves the firelight hue without channel clipping")
			_expect((colors[3].r - colors[3].b) - (colors[1].r - colors[1].b) < 0.035, "One to four overlapping lights stays a restrained accent")
		samples[look] = {"source_counts": [0, 1, 2, 4, 24], "rgb": rgb, "one_plus_23_distant": [far.r, far.g, far.b]}
	print("DENSITY SHADER SAMPLES: ", JSON.stringify(samples))
	view.queue_free()
	return samples
