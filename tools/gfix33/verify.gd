extends "res://tools/inspection_fixture.gd"
## Exercise the same combat submission in headless geometry and native capture.

const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT := "/private/tmp/labyrinth_codex/gfix-33/round1"
const SEED := 83
const HERO := Vector2i(4, 4)
const HERO_BLOCK := 4
const HERO_BLEED := 2
const HERO_RETALIATE := 3
const ENEMY_BLEED := 2
const UI_SCALE := 1.0
const READY_FRAMES := 120
const SETTLE_FRAMES := 8
const FOES := ["warden", "harrier", "vyraketh"]
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const CROWD_TILES: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 4), Vector2i(3, 4), Vector2i(4, 5)]
var _canvas: SubViewport

func _initialize() -> void:
	Fixture.Parallel.apply_from_environment()
	call_deferred("_sweep")

func _sweep() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var before: bool = args.has("--before")
	var native: bool = args.has("--native")
	var dry_run: bool = args.has("--dry-run")
	var phase: String = "before" if before else "after"
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	if native and (DisplayServer.get_name() == "headless" or OS.get_environment("LABYRINTH_CEL_LOOK") != "all"):
		_fail("Native capture requires a windowed renderer and LABYRINTH_CEL_LOOK=all.")
		return
	var baseline: Dictionary
	if not before:
		var path: String = OUTPUT.path_join("before/geometry.json" if native else "before.json")
		if not FileAccess.file_exists(path):
			_fail("Missing baseline sweep: " + path)
			return
		baseline = JSON.parse_string(FileAccess.get_file_as_string(path))
	var settings: Dictionary = Fixture.Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = true
	settings["display_mode"] = Fixture.Settings.DISPLAY_WINDOWED
	settings["board_health_bars"] = Fixture.Settings.BOARD_HEALTH_ALWAYS
	Fixture.Settings.save_settings(settings)
	root.size = Fixture.SIZE
	root.content_scale_size = Fixture.SIZE
	_canvas = SubViewport.new()
	_canvas.size = Fixture.SIZE
	_canvas.msaa_2d = root.msaa_2d
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS if native else SubViewport.UPDATE_DISABLED
	root.add_child(_canvas)
	var profile: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var rows: Dictionary = {}
	var regressions: Array[String]
	var placements: Array[Dictionary]
	for foe: String in FOES:
		for delta: Vector2i in NEIGHBORS:
			for crowded: bool in [false, true]:
				placements.append({"foe": foe, "delta": delta, "crowded": crowded, "id": _label(foe, delta, crowded)})
	if native or dry_run:
		var worst: Array = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT.path_join("capture_placements.json")))
		var selected: Array[Dictionary]
		selected.assign(placements.filter(func(item: Dictionary) -> bool: return worst.has(item["id"])))
		placements = selected
	for placement: Dictionary in placements:
		var key: String = placement["id"]
		var row: Dictionary = await _inspect(placement, profile, phase, native, dry_run)
		if _failed: return
		rows[key] = row
		if not before: regressions.append_array(_verify_change(key, baseline[key], row))
		print("GFIX33 %s %s: hero-status=%d hero-HUD=%d enemy-enemy=%d under hero=%s" % [
			phase, key, row["hero_status"], row["hero_hud"], row["enemy_enemy"], row["under_hero"]])
		for move: Dictionary in row["moves"]:
			print("  %s %s moved %.3f px (dx=%.3f, dy=%.3f)" % [
				move["actor"], move["piece"], move["distance"], move["dx"], move["dy"]])
	if not native and not dry_run:
		_write_json(OUTPUT.path_join(phase + ".json"), rows)
	elif native:
		_write_json(OUTPUT.path_join(phase).path_join("geometry.json"), rows)
	if _failed: return
	for regression: String in regressions: printerr(regression)
	var status_total: int = 0
	var hero_total: int = 0
	var enemy_total: int = 0
	var under_total: int = 0
	var distances: Array[float]
	for row: Dictionary in rows.values():
		status_total += int(row["hero_status"])
		hero_total += int(row["hero_hud"])
		enemy_total += int(row["enemy_enemy"])
		under_total += (row["under_hero"] as Array).size()
		for move: Dictionary in row["moves"]: distances.append(move["distance"])
	distances.sort()
	var median: float = 0.0
	var largest: float = 0.0
	if not distances.is_empty():
		var middle: int = distances.size() / 2
		median = distances[middle] if distances.size() % 2 else (distances[middle - 1] + distances[middle]) * 0.5
		largest = distances.back()
	print("GFIX33 %s %s: %s (%d placements, %d hero-status, %d hero-HUD, %d under hero, %d enemy-enemy overlaps)" % [
		phase.to_upper(), "DRY RUN" if dry_run else "NATIVE" if native else "SWEEP",
		"PASS" if regressions.is_empty() else "FAIL", rows.size(), status_total, hero_total, under_total, enemy_total])
	print("GFIX33 %s DISPLACEMENT: %d moves, max %.3f px, median %.3f px" % [phase.to_upper(), distances.size(), largest, median])
	_canvas.queue_free()
	await process_frame
	quit(0 if regressions.is_empty() else 1)

func _inspect(placement: Dictionary, profile: Dictionary, phase: String, native: bool, dry_run: bool) -> Dictionary:
	var key: String = placement["id"]
	var delta: Vector2i = placement["delta"]
	var foe: String = placement["foe"]
	var origin: Vector2i = HERO + delta
	if foe == "vyraketh":
		# The nearest corner of the authored 2×2 footprint, not its origin,
		# sits on the neighbor tile when the dragon is north or west.
		origin -= Vector2i(int(delta.x < 0), int(delta.y < 0))
	var types: Array[String]
	types.append(foe)
	var tiles: Array[String]
	tiles.append(_coord(origin))
	if placement["crowded"]:
		var footprint := Rect2i(origin, Vector2i(2, 2) if foe == "vyraketh" else Vector2i.ONE)
		for tile: Vector2i in CROWD_TILES:
			if footprint.has_point(tile): continue
			types.append("crawler" if types.size() == 1 else "grave_surgeon")
			tiles.append(_coord(tile))
			if types.size() == 3: break
	_options = {"scenario": "combat", "seed": SEED, "player_position": _coord(HERO),
		"enemy_types": ",".join(types), "enemy_positions": ",".join(tiles), "umbra_stage": "clear"}
	var run: Dictionary = _build_run_state("combat", profile)
	if _failed or run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	state.erase("battlefield_rule")
	state["player"]["block"] = HERO_BLOCK
	state["player"]["bleed"] = HERO_BLEED
	RetaliateRules.gain(state, {"amount": HERO_RETALIATE})
	for enemy: Dictionary in state["enemies"]: enemy["bleed"] = ENEMY_BLEED
	if not Fixture.Store.save_data(profile) or not Fixture.Store.save_run_state(run):
		_fail("Could not save fixture " + key)
		return {}
	var scene: Node = Fixture.resume(self, _canvas)
	scene.call("_close_dialogue")
	for frame: int in READY_FRAMES:
		await process_frame
		var tween: Tween = scene.get("_board_centering_tween")
		if scene.call("initial_presentation_is_ready") and (tween == null or not tween.is_running()): break
	for frame: int in SETTLE_FRAMES: await process_frame
	var board: Control = scene.get("board_view")
	var units: Dictionary = board.call("_units_by_key", board.call("_hud_layout_units"))
	if _canvas.size != Fixture.SIZE or not is_equal_approx(Typography.ui_scale(scene), UI_SCALE) or units.size() != types.size() + 1:
		_fail("Wrong viewport, UI scale or combat roster for " + key)
		return {}
	if not (board.call("_unit_footprint_tiles", units["enemy_1"]) as Array).has(HERO + delta):
		_fail("Target footprint misses neighbor tile for " + key)
		return {}
	var row: Dictionary = _measure(board, units)
	for status: String in ["block", "retaliate"]:  # Bleed is retired on the candidate line (retired_combat_status_migration)
		if not row["hero_rects"].has(status):
			_fail("Missing hero plate %s for %s" % [status, key])
			return {}
	if native or dry_run:
		var path: String = OUTPUT.path_join(phase).path_join(key + "_1920x1080.png")
		if native:
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			await RenderingServer.frame_post_draw
			var image: Image = _canvas.get_texture().get_image()
			if image == null or image.get_size() != Fixture.SIZE or image.save_png(path) != OK:
				_fail("Could not save exact-size image: " + path)
				return {}
		print("GFIX33 %s %s" % ["WOULD CAPTURE" if dry_run else "CAPTURE", path])
		if native: print(path)
	scene.queue_free()
	await process_frame
	return row

func _measure(board: Control, units: Dictionary) -> Dictionary:
	var rects: Dictionary = {}
	var moves: Array[Dictionary]
	var group_offsets: Dictionary = {}
	var chip_offsets: Dictionary = {}
	var hero_status_z: int = 0
	var hero_bar_z: int = 0
	var enemy_z: Dictionary = {}
	# Use the live retained painters to distinguish fallback from a covered hero.
	for record: Dictionary in board._aim_focus.canvases.values():
		if not record.get("hud", false) or record.get("top", false): continue
		var canvas: Control = record["canvas"]
		if not is_instance_valid(canvas) or not canvas.is_visible_in_tree() or canvas._render_slice_ops.is_empty(): continue
		var actor: String = record["unit"]["key"]
		var method: String = canvas._render_slice_ops[0][0]
		if actor != "player":
			enemy_z[actor] = maxi(int(enemy_z.get(actor, 0)), canvas.z_index)
		elif method == "_draw_health_bar_entry": hero_bar_z = canvas.z_index
		elif method == "_draw_unit_hud_details": hero_status_z = canvas.z_index
	var scale: Vector2 = board.get_global_transform_with_canvas().get_scale()
	var half_tile: float = board._tile_width() * 0.5
	for key: String in units:
		var unit: Dictionary = units[key]
		var frame: Rect2 = Badges.health_rect(board, unit)
		var entries: Dictionary = {"bar": frame}
		if not unit.get("boss_bar", false):
			var group: Dictionary = board._status_plate_layout.resolve(board, unit, frame)
			if key != "player":
				var base: Dictionary = board._status_plate_layout.base_group(key)
				var offset: Vector2 = frame.position - (base["frame"] as Rect2).position
				group_offsets[key] = offset
				if offset != Vector2.ZERO:
					moves.append(_displacement(key, "group", offset, scale, half_tile, frame.size.y + Badges.MEDALLION_DIAMETER))
			for field: String in ["defenses", "statuses"]:
				for entry: Dictionary in group[field]: entries[entry["icon"]] = entry["rect"]
			for pip: Rect2 in group["pip_rects"]: entries["pip%d" % entries.size()] = pip
		rects[key] = entries
	for entry: Dictionary in board._hud_layout_entries_cache:
		var key: String = entry["actor_key"]
		var layout: Dictionary = entry.get("layout", {})
		for line: Rect2 in layout.get("line_rects", []): rects[key]["intent%d" % rects[key].size()] = line
		var crest: Rect2 = board._leader_marker_rect(units[key], rects[key]["bar"], layout.get("intent_rect", Rect2()))
		if crest.has_area(): rects[key]["crest"] = crest
	for badge: Dictionary in Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])):
		var key: String = badge["key"]
		var chip: Rect2 = badge["rect"]
		rects[key]["chip"] = chip
		var offset: Vector2 = badge.get("hero_clearance_offset", Vector2.ZERO)
		chip_offsets[key] = offset
		if offset != Vector2.ZERO:
			moves.append(_displacement(key, "chip", offset, scale, half_tile, (rects[key]["bar"] as Rect2).size.y + chip.size.y))
		var disc: Rect2 = badge["order_rect"]
		if disc.has_area():
			rects[key]["disc"] = disc
			var natural: Rect2 = Badges.order_rect(Badges._fixed_order_anchor_rect(board, units[key]), str(badge["order"]), Typography.ui_font())
			var group_offset: Vector2 = group_offsets.get(key, Vector2.ZERO)
			if not (natural.position + group_offset).is_equal_approx(disc.position):
				_fail("Order disc detached from group " + key)
	if not rects["enemy_1"].has("chip"): _fail("Target enemy has no intent chip")
	var hero: Dictionary = rects["player"]
	var hero_hits: Array[String]
	var under_hero: Array[String]
	var status_hits: int = 0
	var enemy_hits: Dictionary = {}
	var enemies: Array = rects.keys()
	enemies.erase("player")
	enemies.sort()
	for i: int in range(enemies.size()):
		var key: String = enemies[i]
		var theirs: Dictionary = rects[key]
		for a: String in hero:
			for b: String in theirs:
				if not (hero[a] as Rect2).intersects(theirs[b], false): continue
				var hit: String = "%s / %s:%s" % [a, key, b]
				var offset: Vector2 = chip_offsets.get(key, Vector2.ZERO) if b == "chip" else group_offsets.get(key, Vector2.ZERO)
				var hero_z: int = hero_bar_z if a == "bar" else hero_status_z
				if offset == Vector2.ZERO and enemy_z.has(key) and hero_z > int(enemy_z[key]):
					under_hero.append(hit)
				else:
					hero_hits.append(hit)
					if a != "bar": status_hits += 1
		for j: int in range(i + 1, enemies.size()):
			var other: String = enemies[j]
			var hit_count: int = 0
			for a: Rect2 in theirs.values():
				for b: Rect2 in rects[other].values():
					if a.intersects(b, false): hit_count += 1
			enemy_hits[key + "/" + other] = hit_count
	var enemy_total: int = 0
	for hits: int in enemy_hits.values(): enemy_total += hits
	var hero_rects: Dictionary = {}
	for part: String in hero:
		var rect: Rect2 = board.get_global_transform_with_canvas() * (hero[part] as Rect2)
		hero_rects[part] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return {"hero_hits": hero_hits, "hero_status": status_hits, "hero_hud": hero_hits.size(),
		"enemy_enemy": enemy_total, "enemy_pairs": enemy_hits, "hero_rects": hero_rects,
		"under_hero": under_hero, "moves": moves}

func _displacement(actor: String, piece: String, offset: Vector2, scale: Vector2, half_tile: float, row_height: float) -> Dictionary:
	var pixels: Vector2 = offset * scale
	return {"actor": actor, "piece": piece, "dx": pixels.x, "dy": pixels.y, "distance": pixels.length(),
		"half_tile": half_tile * scale.x, "row_height": row_height * scale.y}

func _verify_change(key: String, before: Dictionary, after: Dictionary) -> Array[String]:
	var failures: Array[String]
	if not _same_hero_rects(before["hero_rects"], after["hero_rects"]):
		failures.append("%s moved the hero HUD" % key)
	if after["hero_hud"] != 0:
		failures.append("%s still crosses hero HUD: %s" % [key, after["hero_hits"]])
	for move: Dictionary in after["moves"]:
		if (absf(move["dx"]) > move["half_tile"] and not is_equal_approx(absf(move["dx"]), move["half_tile"])) or move["dy"] > 0.0 or (-float(move["dy"]) > move["row_height"] and not is_equal_approx(-float(move["dy"]), move["row_height"])):
			failures.append("%s displaced a HUD out of bounds: %s" % [key, move])
	for pair: String in after["enemy_pairs"]:
		if after["enemy_pairs"][pair] <= before["enemy_pairs"][pair]: continue
		failures.append("%s increased enemy HUD overlap for %s: %s -> %s" % [
			key, pair, before["enemy_pairs"][pair], after["enemy_pairs"][pair]])
	return failures

func _same_hero_rects(before: Dictionary, after: Dictionary) -> bool:
	if before.size() != after.size(): return false
	for key: String in after:
		if not before.has(key): return false
		var a: Array = before[key]
		var b: Array = after[key]
		if Rect2(a[0], a[1], a[2], a[3]) != Rect2(b[0], b[1], b[2], b[3]): return false
	return true

func _write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write " + path)
		return
	file.store_string(JSON.stringify(data, "\t") + "\n")

func _label(foe: String, delta: Vector2i, crowded: bool) -> String:
	var side: String = ["nw", "n", "ne", "w", "e", "sw", "s", "se"][NEIGHBORS.find(delta)]
	return "%s_%s_%s" % [foe, side, "crowded" if crowded else "solo"]

func _coord(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]
