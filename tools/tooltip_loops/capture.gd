extends SceneTree
## Director proof: real tooltip ownership at 1920x1080, plus cold opening costs.
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Cache = preload("res://scripts/tooltip_loop_cache.gd")
const Format = preload("res://scripts/tooltip_loop_format.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const OUT: String = "/private/tmp/labyrinth_codex/tip-02/capture"
const SAMPLE_FRAMES: int = 60 # Debug timing sample count per cold open.
const READY_FRAME_LIMIT: int = 300 # Debug IO/readiness timeout.
const HOVER_WAIT_SECONDS: float = 1.5
const HOVER_ROUTE_ATTEMPTS: int = 3
const ROUTE_PROOF_RECT := Rect2(20, 20, 32, 32) # Headless hit-test fixture only.
const CLEAR_POINTER := Vector2(960, 20)
const OPEN_BUDGET_USEC: int = 4000
const OUTER_POPUP_SETTLE_FRAMES: int = 8
const OUTER_POPUP_PROOF_WIDTHS: Array = [282.0, 420.0, 564.0]
const VIGNETTE_PROOF_SIZE := Vector2i(9, 9)
const PIXEL_ROUNDING_TOLERANCE: float = 0.5
const RESIDENT_BUDGET: int = 12 * 1024 * 1024
var viewport: SubViewport
var failures: Array[String]
var _opening_active: bool = false
var _opening_max: int = 0
var _opening_previous: int = 0
var hover_routes: Array[Dictionary]
var measurements: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(_sample_opening_frame)
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--semantics-only"):
		await _semantics()
		_finish("SEMANTICS"); return
	if DisplayServer.get_name() == "headless":
		push_error("TIP01 renderer capture requires the design owner's window server"); quit(1); return
	root.size = Playback.SIZE
	root.content_scale_size = Playback.SIZE
	viewport = Playback.canvas(self)
	viewport.gui_embed_subwindows = true
	viewport.notify_mouse_entered()
	DirAccess.make_dir_recursive_absolute(OUT)
	_expect(Registry.entries()[0]["id"] == "burst_ember_tick", "Fresh-process measurement opens Burst first")
	_expect(Cache.resident_stream_count() == 0, "No stream is warmed before the first opening measurement")
	var first_loop_open: bool = true
	for row: Dictionary in Registry.entries():
		if not FileAccess.file_exists(row["asset_path"]):
			failures.append("Record first: missing " + str(row["asset_path"])); continue
		var proof_file := FileAccess.open(row["asset_path"], FileAccess.READ)
		var proof_header: Dictionary = Format.header(proof_file)
		_expect(not proof_header.is_empty() and not bool(proof_header.get("legacy_raw", false)), "Native proof requires freshly compressed assets: " + str(row["id"]))
		var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(row["asset_path"]) + ".json"))
		_expect(not bool(provenance.get("requires_native_rerecord", true)), "Native proof requires re-recorded footage: " + str(row["id"]))
		_expect(provenance.get("speed", "normal") == row.get("speed", "normal"), "Native proof recording speed matches registry: " + str(row["id"]))
		var fixture: Dictionary = Fixture.build(row["id"])
		var scene: Node = await Playback.instance(self, viewport, fixture, false)
		if row["source_match"].get("kind") == "enemy": await _prepare_enemy_inspection(scene)
		# Measure quiet board frames before opening the cold stream.
		var baseline: int = await _frame_max(SAMPLE_FRAMES)
		_opening_active = true
		_opening_max = 0
		_opening_previous = Time.get_ticks_usec()
		var before: int = Time.get_ticks_usec()
		var panel: Control = await _open(scene, row)
		var open_usec: int = Time.get_ticks_usec() - before
		if panel == null:
			_opening_active = false
			failures.append("Context tooltip failed to open: " + str(row["id"]))
			scene.queue_free(); await process_frame; continue
		var window: Control = panel.find_child("TooltipLoopWindow", true, false) as Control
		if window == null:
			failures.append("Source context did not attach its loop: " + str(row["id"]))
		else:
			await _frame_max(SAMPLE_FRAMES)
			_opening_active = false
			var opened_max: int = _opening_max
			var cache: Node = Cache.shared()
			var rate: float = await _playback_rate(window)
			_expect(rate >= 20.0, "At least 20 fps observed playback: " + str(row["id"]))
			var bound: int = cache.resident_bound_bytes() / maxi(1, cache.streams.size())
			var added: int = maxi(0, opened_max - baseline)
			measurements.append({"id": row["id"], "baseline_max_frame_usec": baseline, "open_max_frame_usec": opened_max, "added_frame_usec": added, "tooltip_open_route_usec": open_usec, "acquire_max_usec": cache.acquire_max_usec, "upload_max_usec": cache.upload_max_usec, "worker_decode_max_usec": cache.decode_max_usec, "decode_strategy": "worker decode, one texture upload per tick", "resident_bound_bytes_per_loop": bound, "observed_playback_fps": rate, "first_loop_open_in_process": first_loop_open, "vignette_processing": "baked into recorded RGB", "runtime_warmup": "none", "tooltip_build_usec": panel.get_meta("tooltip_loop_build_usec", -1), "loop_ready_usec": window.ready_usec, "stream_lease_usec": window.lease_usec})
			_expect(added <= OPEN_BUDGET_USEC and cache.acquire_max_usec <= OPEN_BUDGET_USEC and cache.upload_max_usec <= OPEN_BUDGET_USEC, "Opening adds no frame over 4 ms: " + str(row["id"]))
			_expect(bound <= RESIDENT_BUDGET, "At most 12 MB resident per loop")
			for moment: String in ["start", "middle", "end"]:
				var info: Dictionary = cache.header(window.asset_path)
				var duration: float = float(info.get("count", 0)) / 30.0
				window.proof_seconds = 0.0 if moment == "start" else duration * 0.5 if moment == "middle" else duration + 0.3
				await _wait_frame(window, mini(int(window.proof_seconds * 30.0), int(info.get("count", 1)) - 1))
				await _capture("%s_%s" % [row["id"], moment])
			window.reduced_motion = true
			window.proof_seconds = -1.0
			await _wait_frame(window, int(cache.header(window.asset_path).get("count", 1)) - 1)
			await _capture(str(row["id"]) + "_reduced_motion")
		first_loop_open = false
		if row["source_match"].get("kind") == "enemy": await _capture_pre_battle(scene, fixture, row)
		scene.queue_free()
		await process_frame
	# Negative context uses a real Seer with its real Icefall intent.
	var seer: Dictionary = _seer_fixture()
	var scene: Node = await Playback.instance(self, viewport, seer, false)
	var panel: Control = await _open(scene, {"id": "marked_hoarfrost_seer", "source_match": {"kind": "enemy", "id": "hoarfrost_seer"}, "term": "marked"})
	_expect(panel != null and panel.find_child("TooltipLoopWindow", true, false) == null, "Hoarfrost Seer Marked stays text-only")
	if panel != null: await _capture("marked_hoarfrost_seer_text_only")
	scene.queue_free()
	await process_frame
	await create_timer(10.1, true, false, true).timeout
	_expect(Cache.shared().streams.is_empty(), "All streams freed ten seconds after close")
	FileAccess.open(OUT.path_join("measurements.json"), FileAccess.WRITE).store_string(JSON.stringify({"measurements": measurements, "hover_routes": hover_routes, "failures": failures, "display": DisplayServer.get_name(), "engine": Engine.get_version_info()}, "\t"))
	_finish("CAPTURE")

func _seer_fixture() -> Dictionary:
	var fixture: Dictionary = Fixture.build("marked_burrow_grub")
	fixture["id"] = "hoarfrost_seer"
	var enemy: Dictionary = fixture["state"]["enemies"][0]
	enemy["type"] = "hoarfrost_seer"
	for intent: Dictionary in preload("res://scripts/game_data.gd").enemy_def("hoarfrost_seer")["intents"]:
		if (intent.get("actions", []) as Array).any(func(action: Dictionary) -> bool: return str(action.get("type", "")).begins_with("icefall_")):
			enemy["intent"] = intent.duplicate(true); break
	return fixture

func _capture_pre_battle(scene: Node, fixture: Dictionary, row: Dictionary) -> void:
	var run: Dictionary = fixture["run"].duplicate(true)
	run["mode"] = preload("res://scripts/run_engine.gd").MODE_PRE_BATTLE
	scene.set("_run_state", run)
	var engine: RefCounted = scene.get("_run_engine")
	# Reuse the real pre-battle factory contract with this exact recorded encounter.
	scene.set("_prepared_pre_battle_factory", {"input": run.duplicate(true), "definitions": engine.call("_pre_battle_definitions"), "layout": fixture["layout"], "combat_state": fixture["state"]})
	_expect(bool(scene.call("_show_pre_battle_preview")), "Recorded encounter opens in the real pre-battle screen")
	for frame: int in range(12): await process_frame
	var panel: Control = scene.get("_pre_battle_panel")
	var foe: Control
	for candidate: Node in panel.find_children("PreBattleEnemyCard", "Button", true, false):
		if candidate.get("enemy").get("type", "") == row["source_match"]["id"]:
			foe = candidate; break
	if foe == null:
		failures.append("Pre-battle source foe missing: " + str(row["id"])); return
	var motion := InputEventMouseMotion.new()
	motion.position = foe.get_global_rect().get_center()
	motion.global_position = motion.position
	viewport.push_input(motion, true)
	await create_timer(1.2).timeout
	var popup: Control = _tooltip(foe)
	var window: Control = popup.find_child("TooltipLoopWindow", true, false) if popup != null else null
	_expect(window != null, "Real outer pre-battle hover popup owns its loop")
	if window == null: return
	window.proof_seconds = 0.0
	await _wait_frame(window, 0)
	_assert_outer_window(window, "Rendered outer popup")
	await _capture(str(row["id"]) + "_pre_battle_outer")

func _open(scene: Node, row: Dictionary) -> Control:
	if row["term"] == "chain":
		# The hand's real keyword column; its entry factory is also kw-cards.
		var stack: Control = scene.get("_card_focus_tooltip_stack")
		scene.call("_show_card_focus_tooltips", 0)
		await process_frame
		return stack
	if not bool(scene.get("_show_all_enemy_intents")): await _prepare_enemy_inspection(scene)
	var board: Control = scene.get("board_view")
	await _pointer(CLEAR_POINTER)
	for attempt: int in range(HOVER_ROUTE_ATTEMPTS):
		for frame: int in range(OUTER_POPUP_SETTLE_FRAMES): await process_frame
		var candidates: Array[Dictionary] = _enemy_hover_candidates(board, row)
		for candidate: Dictionary in candidates:
			var local_point: Vector2 = (candidate["rect"] as Rect2).get_center()
			await _pointer(board.get_global_transform_with_canvas() * local_point)
			var game_text: String = board.call("_get_tooltip", local_point)
			var source: Dictionary = Context.board_source(board, game_text)
			var owns_hover: bool = viewport.gui_get_hovered_control() == board
			var matches_source: bool = source.get("id", "") == row["source_match"]["id"]
			if not owns_hover or not matches_source or not preload("res://scripts/glossary.gd").ids_in_text(game_text).has(row["term"]): continue
			await create_timer(HOVER_WAIT_SECONDS, true, false, true).timeout
			var popup: Control = _tooltip(board)
			if popup != null:
				hover_routes.append({"id": row["id"], "source_canvas": candidate["canvas"], "routed_hud": candidate["routed_hud"], "game_text": game_text, "native_popup": true})
				return popup
			await _pointer(CLEAR_POINTER)
	var hovered: Control = viewport.gui_get_hovered_control()
	var diagnostic: Dictionary = {"id": row["id"], "native_popup": false, "candidate_count": _enemy_hover_candidates(board, row).size(), "source_count": Context.tooltip_sources(board).size(), "routed_hud_count": board._aim_focus.canvases.size(), "gui_hovered": str(hovered.get_path()) if hovered != null else "", "board_pointer": str(board._last_pointer_position), "game_text": board.call("_get_tooltip", board._last_pointer_position), "tooltips_enabled": board._tooltips_enabled}
	hover_routes.append(diagnostic)
	print("TIP01 HOVER ROUTE: " + JSON.stringify(diagnostic))
	return null

func _prepare_enemy_inspection(scene: Node) -> void:
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null: router.call("set_forced_state_for_test", "pointer", "xbox")
	scene.call("_set_show_all_enemy_intents", true)
	for frame: int in range(READY_FRAME_LIMIT):
		var centering: Tween = scene.get("_board_centering_tween")
		if centering == null or not centering.is_valid() or not centering.is_running(): break
		await process_frame
	for frame: int in range(OUTER_POPUP_SETTLE_FRAMES): await process_frame

func _enemy_hover_candidates(board: Control, row: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for layer: Control in Context.tooltip_sources(board):
		for region: Dictionary in layer._tooltip_regions:
			if region.get("loop_source", {}).get("id", "") != row["source_match"]["id"]: continue
			if not preload("res://scripts/glossary.gd").ids_in_text(str(region.get("tooltip", ""))).has(row["term"]): continue
			result.append({"rect": region["rect"], "canvas": str(layer.get_path()), "routed_hud": layer.has_meta("rd03_canvas")})
	return result

func _pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame

func _tooltip(node: Node) -> Control:
	for child: Node in node.get_children(true):
		if child is Control and (child.has_meta("tooltip_surface") or child.name == "PreBattleEnemyInspection") and child.is_visible_in_tree(): return child
		var found: Control = _tooltip(child)
		if found != null: return found
	return null

func _wait_frame(window: Control, index: int) -> void:
	for frame: int in range(READY_FRAME_LIMIT):
		await process_frame
		if int(window.displayed_frame) == index:
			await create_timer(0.14).timeout
			return
	failures.append("Stream did not present frame %d" % index)

func _playback_rate(window: Control) -> float:
	window._elapsed = 0.0
	var started: int = Time.get_ticks_usec()
	var previous: int = int(window.displayed_frame)
	var changes: int = 0
	while Time.get_ticks_usec() - started < 1000000:
		await process_frame
		if int(window.displayed_frame) != previous:
			changes += 1
			previous = int(window.displayed_frame)
	return float(changes) * 1000000.0 / float(Time.get_ticks_usec() - started)

func _sample_opening_frame() -> void:
	if not _opening_active: return
	var now: int = Time.get_ticks_usec()
	_opening_max = maxi(_opening_max, now - _opening_previous)
	_opening_previous = now

func _frame_max(count: int) -> int:
	var maximum: int = 0
	var previous: int = Time.get_ticks_usec()
	for frame: int in range(count):
		await process_frame
		var now: int = Time.get_ticks_usec()
		maximum = maxi(maximum, now - previous)
		previous = now
	return maximum

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = viewport.get_texture().get_image()
	_expect(picture != null and picture.get_size() == Playback.SIZE, "Real 1920x1080 renderer capture")
	if picture == null: return
	var path: String = OUT.path_join(label + "_1920x1080.png")
	_expect(picture.save_png(path) == OK, "Save " + label)
	print(path)

func _semantics() -> void:
	_expect(Fixture.BIOMES.get("chain_card") == "zekarion", "Chain defaults to Zekarion floor and light")
	var recorder = preload("res://tools/tooltip_loops/record.gd")
	_expect(recorder.action_frame_limit("fast") == 165 and recorder.action_frame_limit("normal") == 126 and recorder.action_frame_limit() == 126, "Fast actions cap at 5.5 seconds; normal actions at 4.2 seconds")
	_expect(Registry.entries()[1].get("speed") == "fast" and Registry.entries()[0].get("speed", "normal") == "normal" and Registry.entries()[2].get("speed", "normal") == "normal", "Only Burrow records at the player fast setting")
	_expect(Registry.entries().size() == 3, "Exactly three registered recordings")
	_expect(Registry.find("marked", Context.enemy("hoarfrost_seer")).is_empty(), "Seer cannot borrow Grub recording")
	_expect(Registry.find("marked", {}).is_empty() and Registry.find("chain", {}).is_empty(), "No anonymous/global matching")
	_expect(Registry.find("burrow", Context.enemy("burrow_grub")).get("id") == "marked_burrow_grub", "Burrow alias resolves by source")
	_expect(Registry.find("erupt", Context.enemy("burrow_grub")).get("id") == "marked_burrow_grub", "Erupt alias resolves by source")
	_expect(Registry.find("burst", Context.enemy("frost_tick")).is_empty(), "Other burst sources keep text only")
	_expect(Registry.find("chain", {"kind": "hero_card"}).get("id") == "chain_card", "Every hero Chain card matches")
	_expect(Context.term_in(Icons.tooltip("marked"), Context.enemy("burrow_grub")) == "marked", "Canonical tooltip identifies Marked")
	_expect(Context.term_in(Icons.tooltip("burst"), Context.enemy("ember_tick")) == "burst", "Canonical tooltip identifies Bursts")
	for entry: Dictionary in Registry.entries():
		var packed_file := FileAccess.open(entry["asset_path"], FileAccess.READ)
		_expect(packed_file != null, "Registered asset exists: " + str(entry["id"]))
		if packed_file == null: continue
		var packed_header: Dictionary = Format.header(packed_file)
		_expect(not packed_header.is_empty(), "Registered asset index validates: " + str(entry["id"]))
		if packed_header.is_empty(): continue
		for index: int in range(int(packed_header["count"])):
			_expect(Format.read_frame(packed_file, packed_header, index) != null, "Godot decodes actual frame %s:%d" % [entry["id"], index])
	await _routed_hover_semantics()
	var image := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var background: Color = preload("res://scripts/ui_palette.gd").INK_0
	image.fill(background)
	_expect(recorder.background_is_settled(image, Rect2i(0, 0, 8, 8), background), "Settled background readback passes")
	image.fill(Color.GRAY)
	_expect(not recorder.background_is_settled(image, Rect2i(0, 0, 8, 8), background), "Grey studio clear frame is rejected")
	_expect(is_zero_approx(recorder.vignette_alpha(Vector2.ONE * 0.5)) and is_equal_approx(recorder.vignette_alpha(Vector2.ZERO), 0.45), "Offline vignette preserves zero-centre/45-percent-corner curve")
	var picture := Image.create(VIGNETTE_PROOF_SIZE.x, VIGNETTE_PROOF_SIZE.y, false, Image.FORMAT_RGB8)
	var source: Color = preload("res://scripts/ui_palette.gd").TEXT
	picture.fill(source)
	recorder.bake_vignette(picture)
	_expect(picture.get_pixel(4, 4).is_equal_approx(source), "Offline vignette preserves the centre colour")
	var corner: Color = picture.get_pixel(0, 0)
	var expected: Color = source.lerp(preload("res://scripts/ui_palette.gd").INK_0, recorder.vignette_alpha(Vector2.ONE * 0.5 / Vector2(VIGNETTE_PROOF_SIZE)))
	_expect(absf(corner.r - expected.r) <= 1.0 / 255.0 and absf(corner.g - expected.g) <= 1.0 / 255.0 and absf(corner.b - expected.b) <= 1.0 / 255.0, "Offline RGB blend matches the removed shader curve")

	# A two-frame numerical fixture exercises the actual streaming/lifecycle code.
	# It is isolated test input, never a replacement for recorded renderer proof.
	var path: String = "user://tip02-stream.tlw"
	var picture_fixture := Image.create(282, 168, false, Image.FORMAT_RGB8)
	var bytes := PackedByteArray()
	bytes.resize(282 * 168 * 3)
	bytes.fill(17) # Debug fixture byte, no product visual.
	picture_fixture.set_data(282, 168, false, Image.FORMAT_RGB8, bytes)
	var encoded: PackedByteArray = picture_fixture.save_webp_to_buffer(false)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("TLW2".to_ascii_buffer())
	for value: int in [282, 168, 30, 2, 44, encoded.size(), 0, 44, encoded.size(), 0]: file.store_32(value)
	file.store_buffer(encoded)
	file.close()
	file = FileAccess.open(path, FileAccess.READ)
	var fixture_header: Dictionary = Format.header(file)
	_expect(not fixture_header.is_empty(), "Compressed fixture index validates")
	var decoded: Image = Format.read_frame(file, fixture_header, 0)
	decoded.convert(Image.FORMAT_RGB8)
	_expect(decoded.get_data() == bytes, "Godot WebP decode preserves fixture RGB exactly")
	file.close()
	var row: Dictionary = Registry.entries()[2]
	var original: String = row["asset_path"]
	row["asset_path"] = path
	var panel: Control = preload("res://scripts/ui_tooltip_panel.gd").make_icon_lines(Icons.icon_texture("chain"), Icons.label("chain"), PackedStringArray([Icons.description("chain")]), "chain", {"kind": "hero_card"})
	root.add_child(panel)
	var window: Control = panel.find_child("TooltipLoopWindow", true, false)
	_expect(window != null and window.custom_minimum_size == Vector2(282, 168) and window.window_rect().size == Vector2(282, 168), "Non-pre-battle loop stays 282x168")
	if window != null:
		_expect(window.material == null and window.get_child_count() == 0, "Runtime loop has no custom shader or overlay setup")
		window.proof_seconds = 0.0
		for frame: int in range(READY_FRAME_LIMIT):
			await process_frame
			if window.displayed_frame == 0: break
		_expect(window.displayed_frame == 0, "Cold open starts at first frame")
		window.reduced_motion = true
		for frame: int in range(READY_FRAME_LIMIT):
			await process_frame
			if window.displayed_frame == 1: break
		_expect(window.displayed_frame == 1, "Reduced motion presents final frame")
		_expect(Cache.shared().resident_bound_bytes() < RESIDENT_BUDGET, "Conservative stream memory bound below 12 MB")
		panel.hide()
		_expect(Cache.shared().streams[path]["users"] == 0, "Hidden tooltip relinquishes its stream")
		panel.show()
		_expect(window._elapsed == 0.0, "Reopen restarts playback")
	panel.queue_free()
	await process_frame
	row["asset_path"] = original
	await _outer_popup_semantics(path)
	await create_timer(10.1, true, false, true).timeout
	_expect(Cache.shared().streams.is_empty(), "Real-time cache expires ten seconds after last close")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _routed_hover_semantics() -> void:
	viewport = Playback.canvas(self)
	for id: String in ["burst_ember_tick", "marked_burrow_grub", "hoarfrost_seer"]:
		var fixture: Dictionary = _seer_fixture() if id == "hoarfrost_seer" else Fixture.build(id)
		var scene: Node = await Playback.instance(self, viewport, fixture, false)
		var board: Control = scene.get("board_view")
		scene.call("_set_show_all_enemy_intents", true)
		var enemy: Dictionary = fixture["state"]["enemies"][0]
		var source: Dictionary = Context.enemy(str(enemy["type"]))
		var term: String = "burst" if id == "burst_ember_tick" else "marked"
		var row: Dictionary = {"term": term, "source_match": source}
		# Dummy rendering cannot populate native draw registrations. Reproduce
		# the real per-actor routing boundary using the production board script,
		# registration, native hit-test and custom tooltip builder.
		var routed := preload("res://scripts/combat_board_view.gd").new()
		routed.name = "TooltipRouteProof"
		routed._is_dynamic_render_layer = true
		routed._is_layer_slice_canvas = true
		routed.set_meta("rd03_canvas", true)
		board.add_child(routed)
		routed._tooltip_loop_source = source
		routed._register_tooltip(ROUTE_PROOF_RECT, Icons.tooltip(term))
		board._aim_focus.canvases["tooltip_route_proof"] = {"canvas": routed, "unit": enemy, "hud": true}
		_expect(not board._retained_render_layers().has(routed), "Reproduces HUD canvas omitted by the old capture route")
		var candidates: Array[Dictionary] = _enemy_hover_candidates(board, row)
		_expect(candidates.size() == 1 and bool(candidates[0]["routed_hud"]), "Capture finds the same per-actor region as the game: " + id)
		board._last_pointer_position = ROUTE_PROOF_RECT.get_center()
		var game_text: String = board._get_tooltip(board._last_pointer_position)
		_expect(game_text == Icons.tooltip(term), "Game native hit-test opens the intended term: " + id)
		_expect(Context.board_source(board, game_text) == source, "Native term keeps its exact enemy source: " + id)
		var panel: Control = board._make_custom_tooltip(game_text)
		var window: Control = panel.find_child("TooltipLoopWindow", true, false) if panel != null else null
		_expect(panel != null and (window == null if id == "hoarfrost_seer" else window != null), "Game tooltip builder preserves source-specific loop/Seer exclusion: " + id)
		if panel != null: panel.free()
		routed.hide()
		_expect(_enemy_hover_candidates(board, row).is_empty(), "Capture excludes hidden routed canvases")
		scene.queue_free()
		await process_frame
	# Separately exercise the recorder mask for all three real fixture scenes.
	for id: String in ["burst_ember_tick", "marked_burrow_grub", "chain_card"]:
		var fixture: Dictionary = Fixture.build(id)
		var scene: Node = await Playback.instance(self, viewport, fixture, true)
		_expect(not bool(scene.get("board_view").presentation.get("board_backdrop_visible", true)), "Frame zero receives the dark-background paint contract: " + id)
		scene.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame

func _outer_popup_semantics(path: String) -> void:
	var inspection = preload("res://scripts/pre_battle_inspection_view.gd")
	var host: Node = preload("res://scenes/run_scene.tscn").instantiate()
	var row: Dictionary = Registry.entries()[0]
	var original: String = row["asset_path"]
	var enemy: Dictionary = Fixture.build("burst_ember_tick")["state"]["enemies"][0]
	var text_only: Control = inspection.build(host, enemy)
	var expected_text: String = _popup_text(text_only)
	text_only.free()
	row["asset_path"] = path
	var popup: Control = inspection.build(host, enemy)
	root.add_child(popup)
	for frame: int in range(OUTER_POPUP_SETTLE_FRAMES): await process_frame
	var window: Control = popup.find_child("TooltipLoopWindow", true, false)
	_expect(window != null, "Existing outer foe-hover popup contains the recording")
	if window != null:
		var header_host: Control = window.get_parent()
		var original_header: Control = header_host.get_child(1)
		_expect(header_host.get_child(0) == window and header_host.get_parent().get_child(0) == header_host, "Loop precedes the unchanged popup header and text")
		_assert_outer_window(window, "Outer popup")
		_expect(is_equal_approx(original_header.position.y - window.get_rect().end.y, 10.0), "Outer popup retains exactly ten pixels below the loop: window=%s header=%s separation=%d" % [window.get_rect(), original_header.get_rect(), header_host.get_theme_constant("separation")])
		# Debug layout widths exercise both the reference size and proportional scaling.
		for width: float in OUTER_POPUP_PROOF_WIDTHS:
			window.size.x = width
			_assert_outer_window(window, "Proof width %.0f" % width)
			_expect(is_equal_approx(window.custom_minimum_size.y, roundf(minf(width, 420.0) * 3.0 / 5.0)), "Capped minimum height at proof width %.0f" % width)
	_expect(_popup_text(popup) == expected_text, "Outer popup preserves every existing text label")
	var pinned: Control = inspection.build(host, enemy, true)
	_expect(pinned.find_child("TooltipLoopWindow", true, false) == null, "Pinned inspector and its nested native term popups remain unchanged")
	pinned.free()
	_expect(Context.outer_popup_window(Context.enemy("hoarfrost_seer")) == null, "Seer outer popup stays text-only")
	popup.queue_free()
	host.free()
	await process_frame
	row["asset_path"] = original

func _assert_outer_window(window: Control, context: String) -> void:
	var rect: Rect2 = window.window_rect()
	var width: float = minf(window.size.x, 420.0)
	_expect(is_equal_approx(rect.size.x, width) and rect.size.x <= 420.0, context + " caps visible width at 420")
	_expect(absf(rect.size.y - width * 3.0 / 5.0) <= PIXEL_ROUNDING_TOLERANCE and rect.size.y <= 252.0, context + " uses 5:3 up to 420x252")
	_expect(is_equal_approx(rect.get_center().x, window.size.x * 0.5), context + " centres the window in the content width")

func _popup_text(node: Node) -> String:
	var text: String = node.text if node is Label or node is RichTextLabel else ""
	for child: Node in node.get_children():
		var child_text: String = _popup_text(child)
		if not child_text.is_empty(): text += ("\n" if not text.is_empty() else "") + child_text
	return text

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish(kind: String) -> void:
	for failure: String in failures: push_error(failure)
	print("TIP01 TOOLTIP %s: %s (%d failures)" % [kind, "PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
