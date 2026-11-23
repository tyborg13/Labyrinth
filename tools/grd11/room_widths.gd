extends SceneTree
## Measure settled production RunScene framing along one entry route per room.

const Fixture = preload("res://tools/grd11/fight_fixture.gd")
const Gallery = preload("res://tools/grd01/fixtures.gd")
const Sizes = preload("res://tools/grd11/size_proof.gd")
const Sheet = preload("res://scripts/board_ground_fx_sheet.gd")
const Runner = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const RESOLUTIONS := [Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const SEEDS: PackedInt32Array = [1, 2, 3]
const DEPTH_LIMIT: int = 12
const FIRST_ENTRY := Vector2i.ZERO
const HUD_SETTLE_LIMIT: int = 24
const SCENE_SETTLE_FRAMES: int = 12

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() in [1, 2] and args[0].is_absolute_path())
	var path: String = args[0]
	var selected: String = args[1] if args.size() == 2 else ""
	assert(selected.is_empty() or selected in ["1280x800", "1920x1080", "2560x1440", "3840x2160"])
	assert(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK)
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_csv_line(PackedStringArray(["resolution", "run_seed", "depth", "room_x", "room_y", "room_type",
		"entry_x", "entry_y", "tile_px", "cell_px", "sheet", "drawn_tile_px", "ratio"]))
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sheet.DATA_PATH))
	var sheet_tile_widths := PackedInt32Array()
	for info: Dictionary in input["sizes"]:
		sheet_tile_widths.append(int(info["tile_cells"][0]))
	OS.set_environment("LABYRINTH_GROUND_FX", "off")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://grd11_census_settings.json")
	assert(Settings.save_settings(settings))
	Store.set_storage_path("user://grd11_census_progress.json")
	Store.set_run_storage_path("user://grd11_census_run.save")
	var cases: Array[Dictionary] = _generate_rooms()
	assert(not cases.is_empty())
	var total_outside: int = 0
	var total: int = 0
	for size: Vector2i in RESOLUTIONS:
		var resolution: String = "%dx%d" % [size.x, size.y]
		if not selected.is_empty() and resolution != selected:
			continue
		var view: SubViewport = Gallery.make_view(size, Sizes.logical_size(size), Viewport.MSAA_DISABLED)
		root.add_child(view)
		var scene: Control = Fixture.Run.instantiate()
		view.add_child(scene)
		for frame: int in SCENE_SETTLE_FRAMES:
			await process_frame
		assert(Sizes.Pixel.viewport_pixels(view).is_equal_approx(Vector2(size)))
		var minimum: float = INF
		var maximum: float = -INF
		var outside: int = 0
		for sample: Dictionary in cases:
			Fixture._present(scene, sample["state"].duplicate(true))
			await _settle_hud(scene)
			var board: Control = scene.get("board_view")
			board.call("reset_navigation")
			var tile_px: float = Sizes.physical_tile_width(board)
			var choice: Vector2i = Sizes.Pixel.choose_sheet_size(tile_px, size.y, sheet_tile_widths)
			var drawn: int = sheet_tile_widths[choice.y] * choice.x
			var ratio: float = drawn / tile_px
			var coord: Vector2i = sample["coord"]
			var entry: Vector2i = sample["entry"]
			output.store_csv_line(PackedStringArray([resolution, str(sample["seed"]), str(sample["depth"]),
				str(coord.x), str(coord.y), sample["type"], str(entry.x), str(entry.y), "%.6f" % tile_px,
				str(choice.x), input["sizes"][choice.y]["atlas"], str(drawn), "%.8f" % ratio]))
			minimum = minf(minimum, ratio)
			maximum = maxf(maximum, ratio)
			outside += int(ratio < Sizes.MIN_RATIO or ratio > Sizes.MAX_RATIO)
		total_outside += outside
		total += cases.size()
		print("GRD-11 ROOM WIDTHS %s: %d rooms, min %.6f, max %.6f, %d outside tolerance" %
			[resolution, cases.size(), minimum, maximum, outside])
		for frame: int in SCENE_SETTLE_FRAMES:
			await process_frame
		view.free()
		await process_frame
	output.close()
	print(path)
	print("GRD-11 WIDTH CENSUS: %s (%d measurements)" % ["PASS" if total_outside == 0 else "FAIL", total])
	quit(0 if total_outside == 0 else 1)

func _settle_hud(scene: Control) -> void:
	# Just after entry, the desktop hand has no fit budget yet. Wait for the
	# production deferred sort before taking the settled board's tile width.
	for frame: int in HUD_SETTLE_LIMIT:
		await process_frame
		if frame > 0 and int(scene.get("_hand_layout_pending_revision")) < 0:
			scene.call("_freeze_board_hud_budget")
			return
	assert(false, "RunScene HUD layout did not settle")

func _generate_rooms() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for seed_value: int in SEEDS:
		var engine := Runner.new()
		var progression: Dictionary = Store.default_data()
		for prompt: String in Fixture.Tutorial.prompt_ids():
			progression = Fixture.Tutorial.resolve_progression(progression, prompt)
		var run_state: Dictionary = engine.create_new_run(seed_value, progression)
		var rooms: Dictionary = run_state["rooms"]
		var start: Vector2i = run_state["current_room"]
		var reachable: Array[Vector2i]
		reachable.append(start)
		var entry_by_room: Dictionary = {start: FIRST_ENTRY}
		var cursor: int = 0
		while cursor < reachable.size():
			var coord: Vector2i = reachable[cursor]
			cursor += 1
			var raw: Dictionary = engine.room_metadata(run_state, coord)
			for link: Dictionary in raw.get("connections", []):
				var to: Vector2i = link["coord"]
				if entry_by_room.has(to) or not rooms.has(engine._room_key(to)):
					continue
				var next: Dictionary = engine.room_metadata(run_state, to)
				if int(next.get("depth", 0)) > DEPTH_LIMIT:
					continue
				entry_by_room[to] = link["door_dir"]
				reachable.append(to)
			result.append(_make_case(engine, run_state, raw, entry_by_room[coord]))
		assert(reachable.size() > 1)
	return result

func _make_case(engine: RefCounted, run_state: Dictionary, metadata: Dictionary, entry: Vector2i) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	var room: Dictionary = metadata.duplicate(true)
	state["current_room"] = room["coord"]
	if room["type"] == "mystery":
		Graph.resolve_mystery(state, room)
	var is_fight: bool = room["type"] in ["combat", "special", "guardian", "boss"]
	var layout: Dictionary
	if is_fight:
		# Give generated rooms their first eligible fight number at this depth.
		room["fight_number"] = 1 + 2 * clampi((int(room["depth"]) - 1) % 4, 0, 2)
		layout = engine._combat_layout_for_room(room, entry, state)
		var combat := Fixture.Combat.new()
		state["combat_state"] = combat.create_combat(state["seed"], layout, engine._player_snapshot(state))
		state["combat_state"]["current_actor"] = {"kind": "player", "key": "player"}
		state["mode"] = "combat"
	else:
		layout = engine._display_layout_for_room(state["seed"], room, entry)
		state["combat_state"] = {}
		state["mode"] = "room"
	state["current_room_layout"] = layout
	assert(not layout.is_empty())
	return {"state": state, "seed": state["seed"], "coord": room["coord"], "depth": room["depth"],
		"type": room["type"], "entry": entry}
