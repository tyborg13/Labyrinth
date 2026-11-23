extends "res://tools/inspection_fixture.gd"
## RunScene input, preview, playback and application-quit/reload probes.

const Base = preload("res://tests/suites/en03_enemies_suite.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
const ReflectView = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const SIZE := Vector2i(1920, 1080)
const SEED: int = 131011
const HERO := Vector2i(4, 4)
const MIRROR := Vector2i(6, 4)
const VICTIM := Vector2i(4, 3)
const KEG := Vector2i(5, 4)
const SURVIVOR := Vector2i(7, 7)
const SETTLE_FRAMES: int = 8
const WATCHDOG_MSEC: int = 12000
const FIXTURE_HP: int = 30
const VICTIM_HP: int = 1
const KEG_HP: int = 1
const KEG_DAMAGE: int = 2
const CASES: Array[String] = ["area", "umbra", "gains", "cancel", "reflect", "save_shot", "save_area"]

var _scene: Node
var _viewport: SubViewport
var _directory: String
var _case: String
var _decision: int = 0
var _failures: Array[String]
var _checks: int = 0
var _playing: bool = false
var _legacy: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_probe")

func _probe() -> void:
	_directory = OS.get_environment("LABYRINTH_QA131_LIVE_OUT")
	_legacy = OS.get_environment("LABYRINTH_QA131_RELEASE") == "1"
	var requested: PackedStringArray = OS.get_cmdline_user_args()
	var cases: Array[String] = CASES.duplicate()
	if not requested.is_empty(): cases.assign(requested)
	if _directory.is_empty():
		push_error("QA131 requires LABYRINTH_QA131_LIVE_OUT")
		quit(2)
		return
	root.content_scale_factor = 1.0
	for label: String in cases:
		_case = label
		_decision = 0
		if not CASES.has(label):
			_check(false, "unknown fixture")
			continue
		if await _open(label):
			match label:
				"area", "umbra", "save_area": await _area(label == "save_area")
				"reflect": await _reflect()
				"gains": await _gains()
				"save_shot": await _save_shot()
				"cancel": await _cancel()
		await _leave()
	for failure: String in _failures: push_error(failure)
	print("QA131 LIVE EFFECTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _open(label: String) -> bool:
	var directory: String = _directory.path_join(label)
	DirAccess.make_dir_recursive_absolute(directory)
	ProgressionStore.set_storage_path(directory.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(directory.path_join("run.save"))
	Settings.set_storage_path(directory.path_join("settings.json"))
	Analytics.set_storage_dir(directory.path_join("analytics"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["combat_speed"] = Settings.COMBAT_FASTEST
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	_options = {"scenario": "combat", "seed": SEED}
	var progression: Dictionary = Tutorial.complete_tutorial(_build_progression())
	var run: Dictionary = _build_run_state("combat", progression)
	if not _check(not run.is_empty(), "base inspection fixture created"): return false
	var enemies: Array = [Base.enemy("crawler", 2, SURVIVOR)]
	var hand: Array[String] = ["tremor", "brace", "crystal_mantle", "hurl_spear"]
	var target_type: String = "glacial_mirror" if label == "reflect" else "crawler"
	var target: Vector2i = MIRROR if label in ["reflect", "save_shot", "cancel"] else VICTIM
	enemies.push_front(Base.enemy(target_type, 1, target))
	if label in ["area", "umbra", "save_area"]:
		enemies[0]["hp"] = VICTIM_HP
	var layout: Dictionary = Base.layout(enemies, HERO)
	layout["coord"] = run["current_room"]
	if label == "umbra": layout["umbra_stage"] = "eclipse"
	if label in ["area", "save_area"]:
		layout["terrain"] = [{"id": "qa131_keg", "kind": "powder_keg", "pos": KEG, "hp": KEG_HP,
			"max_hp": KEG_HP, "burst_damage": KEG_DAMAGE, "owner_kind": "player", "blocks_sight": false}]
	var state: Dictionary = _combat_engine.create_combat(SEED, layout, {
		"hp": FIXTURE_HP, "max_hp": FIXTURE_HP, "deck_cards": hand, "hand_size": hand.size(),
	})
	state["deck"]["hand"] = hand
	state["cards_per_turn"] = hand.size()
	run["combat_state"] = state
	run["current_room_layout"] = layout
	run["player_hp"] = FIXTURE_HP
	run["player_max_hp"] = FIXTURE_HP
	if not _check(ProgressionStore.save_data(progression) and ProgressionStore.save_run_state(run),
			"writes isolated fixture"): return false
	return await _enter()

func _enter() -> bool:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_2d = root.msaa_2d
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while Time.get_ticks_msec() < cutoff:
		if _scene.initial_presentation_is_ready(): break
		await process_frame
	_scene._close_dialogue()
	await _settle()
	return _check(_scene.initial_presentation_is_ready() and _scene._run_state.get("mode") == "combat",
		"production resume opens a ready combat")

func _area(interrupt: bool) -> void:
	var before: Dictionary = _scene._combat_state.duplicate(true)
	var expected_visible: Array[Vector2i] = _combat_engine.umbra_visible_tiles(before)
	if _case == "umbra":
		var offsets: Array = GameData.card_def("tremor")["actions"][0]["pattern"]
		_check(offsets.any(func(offset: Array) -> bool:
			return not expected_visible.has(HERO + Vector2i(offset[0], offset[1]))), "authored area extends into hidden tiles")
	_play("tremor")
	var peak_tiles: Dictionary = {}
	var max_visible_tiles: int = 0
	var contact_frames: Dictionary = {}
	var rows: Dictionary = {}
	var hidden: Dictionary = {}
	var held: Dictionary = {}
	var killed_visible: bool = false
	var started: int = Time.get_ticks_msec()
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while Time.get_ticks_msec() < cutoff:
		held = _held(held)
		var stamps: Array = _stamps("_tile_bursts")
		var visible_now: Dictionary = {}
		for stamp: Node2D in stamps:
			peak_tiles[str(stamp.tile)] = true
			var row: int = int(stamp.sample.y)
			rows[row] = true
			if not contact_frames.has(row): contact_frames[row] = stamp.birth_frame
			if stamp.visible: visible_now[stamp.tile] = true
			if not expected_visible.has(stamp.tile): hidden[str(stamp.tile)] = true
			if stamp.tile == VICTIM and stamp.visible: killed_visible = true
		max_visible_tiles = maxi(max_visible_tiles, visible_now.size())
		if killed_visible and (interrupt or rows.size() >= 4 or _case == "umbra"):
			await _capture("contact")
			if interrupt: break
		if _legacy and interrupt and not held.is_empty() and _scene.board_view.presentation.has("effect"): break
		if not _playing: break
		await process_frame
	var enemies: Array = held.get("enemies", [])
	var killed: bool = not enemies.any(func(enemy: Dictionary) -> bool:
		return enemy.get("id") == 1 and int(enemy.get("hp", 0)) > 0)
	_check(not held.is_empty() and killed, "committed area defeats the 1-Health target")
	_receipt("area", {"tiles": peak_tiles.keys(), "rows": rows.keys(), "hidden": hidden.keys(),
		"killed": killed, "killed_tile_stamp_visible": killed_visible,
		"locked_at_end": _scene._animation_lock, "playing": _playing,
		"elapsed_ms": Time.get_ticks_msec() - started, "max_visible_tiles": max_visible_tiles,
		"contact_frames": contact_frames,
		"presentation_keys": _scene.board_view.presentation.keys() if _playing else []})
	if not _legacy:
		_check(hidden.is_empty(), "area allocates no hidden tile stamp")
		_check(peak_tiles.size() >= 6 if _case != "umbra" else not peak_tiles.is_empty(), "area reaches the visible footprint")
		if _case != "umbra":
			var catalog: Dictionary = load("res://scripts/tile_burst_fx.gd").metadata()
			var authored: Dictionary = catalog["rows"]
			var earth_frame: int = int(contact_frames.get(int(authored["earth_hit_rear"]), -1))
			var impact_frame: int = int(contact_frames.get(int(authored["impact_hit_rear"]), -2))
			_check(earth_frame >= 0 and earth_frame == impact_frame, "Tremor and powder-keg stamps start in the same step")
			if not interrupt: _check(max_visible_tiles >= 6, "at least six tile stamps are concurrently visible")
		_check(killed_visible, "the defeated target receives a visible area stamp")
	if interrupt:
		await _save_resume(held, "tile_burst")
	else:
		_check(not _playing and not _scene._animation_lock, "area playback settles within the real-time watchdog")

func _gains() -> void:
	var rows: Dictionary = {}
	var first_turn: int = int(_scene._combat_state["turn"])
	for card: String in ["brace", "crystal_mantle"]:
		_play(card)
		var card_rows: Dictionary = {}
		var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
		while Time.get_ticks_msec() < cutoff:
			for stamp: Node2D in _stamps("_self_bursts"):
				if stamp.front and stamp.visible: card_rows[int(stamp.sample.y)] = true
			if not card_rows.is_empty(): await _capture(card)
			if not _playing: break
			await process_frame
		rows[card] = card_rows.keys()
		if not _legacy: _check(not card_rows.is_empty(), card + " submits a visible self-gain stamp")
		var player: Dictionary = _scene._combat_state["player"]
		_receipt(card, {"rows": card_rows.keys(), "turn": _scene._combat_state["turn"],
			"block": player.get("block"), "frost_armor": player.get("frost_armor")})
	_check(int(_scene._combat_state["turn"]) == first_turn, "both gains land in the same turn")

func _reflect() -> void:
	var before: Dictionary = _scene._combat_state.duplicate(true)
	if not await _aim("hurl_spear", MIRROR): return
	var predicted: Dictionary = _scene._surface_preview_cache.get("state", {}).duplicate(true)
	_fire(MIRROR)
	var held: Dictionary = {}
	var outbound: bool = false
	var returning: bool = false
	var baked_outbound: bool = false
	var baked_returning: bool = false
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while Time.get_ticks_msec() < cutoff:
		held = _held(held)
		var shown: Dictionary = _scene.board_view.presentation
		var effect: Dictionary = shown.get("effect", {})
		if effect.get("action_type") == "reflected_projectile":
			var timing: Dictionary = ReflectView.projectile_frame(float(shown["effect_progress"]), float(effect["en05_outbound_seconds"]))
			var first_return: bool = not returning and timing["returning"]
			returning = returning or timing["returning"]
			outbound = outbound or not timing["returning"]
			if _in_flight():
				baked_outbound = baked_outbound or not timing["returning"]
				baked_returning = baked_returning or timing["returning"]
			if first_return: await _capture("return")
			if not timing["returning"] and timing["travel"] >= 0.45 and timing["travel"] <= 0.85:
				await _capture("outbound")
		if not _playing: break
		await process_frame
	var bounces: Array = Reflect.bounces_between(before, held)
	_receipt("mirror", {"bounces": bounces, "outbound": outbound, "return": returning, "baked_outbound": baked_outbound, "baked_returning": baked_returning})
	_check(bounces.size() == 1 and outbound and returning, "Mirror resolves one reflected shot and plays both legs")
	_check(not predicted.is_empty() and _health_receipt(predicted) == _health_receipt(held), "hover and held health outcomes agree")
	# Keep the native capture usable as evidence of the observed overlap.
	if DisplayServer.get_name() == "headless":
		_check(not baked_outbound and not baked_returning, "Mirror playback does not also submit an independent retained head")

func _cancel() -> void:
	var before: Dictionary = _scene._combat_state.duplicate(true)
	if not await _aim("hurl_spear", MIRROR): return
	_action("cancel before firing")
	_scene._on_board_cancel_requested()
	await _settle()
	_check(_scene._selected_card_index < 0 and _scene._combat_state["deck"]["hand"] == before["deck"]["hand"],
		"cancel clears aim and preserves hand")
	_check(not _in_flight() and _shot_hits() == 0, "cancel generates no flight or impact")

func _save_shot() -> void:
	if not await _aim("hurl_spear", MIRROR): return
	_fire(MIRROR)
	var held: Dictionary = {}
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while Time.get_ticks_msec() < cutoff:
		held = _held(held)
		if not held.is_empty() and (_in_flight() or (_legacy and _scene.board_view.presentation.has("effect"))): break
		if not _playing: break
		await process_frame
	_check(not held.is_empty() and (_legacy or _in_flight()), "held checkpoint sampled with a shot head in flight")
	await _capture("in_flight")
	await _save_resume(held, "shot")

func _save_resume(held: Dictionary, family: String) -> void:
	if not _check(not held.is_empty(), "a combat checkpoint exists at interruption"): return
	var committed: Dictionary = _combat_receipt(held)
	_receipt("departure", {"family": family, "state": committed, "stamp_count": _stamps("_tile_bursts").size(),
		"shot_head": _in_flight(), "locked": _scene._animation_lock})
	_check(_scene._animation_lock, "application quits during playback")
	await _scene.prepare_application_quit("qa131_in_flight")
	var saved: Dictionary = ProgressionStore.load_saved_run()
	_check(_combat_receipt(saved.get("combat_state", {})) == committed, "disk preserves the held combat state")
	await _leave()
	if not await _enter(): return
	var live: Dictionary = _scene._combat_state
	_check(_combat_receipt(live) == committed, "resume preserves the held combat state")
	var board: Node = _scene.board_view
	var bodies: Dictionary = {}
	for actor: Dictionary in board._visible_units():
		var key: String = str(actor.get("key", ""))
		if key == "player" or key.begins_with("enemy_"):
			bodies[key] = board._unit_hud_anchor_texture(actor) != null
	var expected_bodies: int = 1 + committed["enemies"].size()
	_check(bodies.size() == expected_bodies and not bodies.values().has(false),
		"resumed hero and each surviving enemy have resolved body textures")
	var atlases: Dictionary = {}
	if not _legacy:
		for name: String in ["_tile_bursts", "_self_bursts", "_single_shot_fx"]:
			var fx: RefCounted = board.get(name)
			var ink: ShaderMaterial = fx.get("_ink" if name == "_single_shot_fx" else "ink") if fx != null else null
			atlases[name] = ink != null and ink.get_shader_parameter("atlas") is Texture2D
		_check(not atlases.values().has(false), "all three effects retain a bound atlas after resume")
	var stale: bool = _in_flight() or _shot_hits() > 0 or not _stamps("_tile_bursts").is_empty() or not _stamps("_self_bursts").is_empty()
	_check(not stale, "resume has no stale shot, impact or burst stamp")
	var played: int = Analytics.load_all_events().filter(func(event: Dictionary) -> bool:
		return event.get("event_type") == "card_played").size()
	_receipt("resumed", {"state": _combat_receipt(live), "stale": stale, "body_textures": bodies,
		"bound_atlases": atlases, "card_played": played})
	await _capture("resumed")

func _aim(card: String, tile: Vector2i) -> bool:
	var slot: int = _scene._combat_state["deck"]["hand"].find(card)
	if not _check(slot >= 0, card + " is in the hand"): return false
	_action("select " + card + " and hover " + str(tile))
	await _scene._on_card_pressed(slot)
	_scene._on_board_tile_hovered(tile)
	await _settle()
	return _check(_scene._pending_target_tiles.has(tile), "target is legal")

func _fire(tile: Vector2i) -> void:
	_action("click target " + str(tile))
	_playing = true
	await _scene._on_board_tile_clicked(tile)
	if is_instance_valid(_scene) and _scene._pending_card_requires_confirmation():
		await _scene._on_confirm_card_play_pressed()
	_playing = false

func _play(card: String) -> void:
	var slot: int = _scene._combat_state["deck"]["hand"].find(card)
	if not _check(slot >= 0, card + " is in the hand"): return
	_action("play " + card)
	_playing = true
	await _scene._on_card_pressed(slot)
	if is_instance_valid(_scene) and _scene._pending_card_requires_confirmation():
		await _scene._on_confirm_card_play_pressed()
	_playing = false

func _held(fallback: Dictionary) -> Dictionary:
	var held: Dictionary = _scene._committed_run_state_override.get("combat_state", {})
	return fallback if held.is_empty() else held.duplicate(true)

func _health_receipt(state: Dictionary) -> Dictionary:
	var receipt: Dictionary = _combat_receipt(state)
	return {"hp": receipt["hp"], "enemies": receipt["enemies"]}

func _combat_receipt(state: Dictionary) -> Dictionary:
	var hit_points: Dictionary = {}
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: hit_points[int(enemy["id"])] = enemy["hp"]
	return {"hp": state.get("player", {}).get("hp"), "pos": state.get("player", {}).get("pos"),
		"enemies": hit_points, "turn": state.get("turn"), "hand": state.get("deck", {}).get("hand")}

func _stamps(family: String) -> Array:
	if _legacy: return []
	var fx: RefCounted = _scene.board_view.get(family)
	return fx.get("_stamps") if fx != null else []

func _in_flight() -> bool:
	if _legacy: return false
	var fx: RefCounted = _scene.board_view.get("_single_shot_fx")
	return fx != null and fx.get("_heads").any(func(head: Node2D) -> bool: return head.visible)

func _shot_hits() -> int:
	if _legacy: return 0
	var fx: RefCounted = _scene.board_view.get("_single_shot_fx")
	return fx.get("_hits").filter(func(hit: Node2D) -> bool: return hit.visible).size() if fx != null else 0

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var path: String = _directory.path_join(_case).path_join(label + ".png")
	if FileAccess.file_exists(path): return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_check(frame != null and frame.get_size() == SIZE and frame.save_png(path) == OK, "captured " + label)
	print(path)

func _leave() -> void:
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	await _settle()
	_playing = false

func _settle() -> void:
	for frame: int in SETTLE_FRAMES: await process_frame

func _action(label: String) -> void:
	_decision += 1
	_receipt(label, {})

func _receipt(label: String, info: Dictionary) -> void:
	print("QA131 LIVE " + JSON.stringify({"case": _case, "decision": _decision, "seed": SEED,
		"label": label, "data": info}))

func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition: _failures.append("seed=%d decision=%d %s: %s" % [SEED, _decision, _case, label])
	return condition
