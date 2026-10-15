extends SceneTree

const Bank = preload("res://scripts/sfx_bank.gd")
const Router = preload("res://scripts/sfx_cue_router.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const CursorFeedback = preload("res://scripts/cursor_feedback.gd")
const ButtonFeedback = preload("res://scripts/ui_button_feedback.gd")
const TEST_VIEWPORT: Vector2i = Vector2i(1920, 1080)
const CAPTURE_DIR: String = "user://sfx_cue_coverage/1920x1080_ui100"
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const TEST_SEED: int = 410
const TEST_START_MS: int = 10000
const TEST_REQUEST_GAP_MS: int = 5000
const REPORT_DIR: String = "user://sfx_cue_coverage"
var bank: Node
var router: RefCounted
var requested: Array[String] = []
var covered: Dictionary = {}
var failures: Array[String] = []
var clock_ms: int = TEST_START_MS

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	bank = Bank.new()
	bank.warm_up(null, {}, TEST_SEED)
	bank.set_test_clock(clock_ms)
	router = Router.new(bank)
	bank.cue_requested.connect(_record)
	_drive()
	await _live_checks()
	_report()
	for failure: String in failures: push_error(failure)
	print("SFX CUE COVERAGE TEST RESULT: %s (%d/%d cues, %d removed, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", covered.size(), bank.data["cues"].size(), bank.data.get("removed", {}).size(), failures.size()])
	bank.free()
	quit(0 if failures.is_empty() else 1)

func _record(cue_id: String, _result: String) -> void:
	requested.append(cue_id)
	covered[cue_id] = true

func _check(expected: Array, label: String) -> void:
	if requested != expected: failures.append("%s: expected %s, requested %s" % [label, expected, requested])
	requested.clear()
	clock_ms += TEST_REQUEST_GAP_MS
	bank.set_test_clock(clock_ms)

func _drive() -> void:
	_check_director_families()
	for weapon: String in ["sword", "maul", "spear"]:
		for amount: int in [5, 6]:
			var action: Dictionary = {"type": "melee", "damage": amount}
			router.begin_player_action(_state(), action, weapon)
			router.hit(action, {"type": "player"}, weapon, {"id": 1, "type": "crawler", "hp": 12}, {"hp": 12 - amount})
			var family: String = "blade" if weapon == "sword" else "blunt" if weapon == "maul" else "pierce"
			var impact: String = "hit." + family + (".heavy" if amount >= 6 else ".light") if family != "pierce" else "hit.pierce"
			_check(["swing.heavy" if amount >= 6 or family == "blunt" else "swing.light", impact], "weapon %s %d" % [weapon, amount])
	router.begin_player_action(_state(), {"kind": "fixture"})
	var claw: Dictionary = {"kind": "melee", "damage": 3}
	router.wind_up(claw, {"type": "crawler"})
	router.hit(claw, {"type": "crawler"}, "", {"type": "player", "hp": 12}, {"hp": 9})
	_check(["swing.light", "hit.claw"], "enemy claws")
	for weapon: String in ["bow", "crossbow"]:
		router.release({"type": "ranged"}, {"type": "player"}, weapon)
		_check(["shot." + weapon], "projectile release " + weapon)
	router.begin_player_action(_state(), {"type": "ranged", "damage": 3})
	router.release({"type": "ranged", "damage": 3})
	router.hit({"type": "ranged", "damage": 3}, {"type": "player"}, "", {"id": 1, "hp": 12}, {"hp": 9})
	_check(["cast.arcane", "hit.arcane"], "neutral spell launch and contact")
	for element: String in ["fire", "ice", "lightning", "earth", "air", "shadow"]:
		var action: Dictionary = {"type": "ranged", "element": element, "damage": 3}
		router.begin_player_action(_state(), action)
		router.hit(action, {"type": "player"}, "", {"id": 1, "hp": 12}, {"hp": 9})
		_check(["spell." + element], "element contact " + element)
	router.begin_player_action(_state(), {"type": "melee", "damage": 5}, "sword")
	requested.clear()
	router.hit({"type": "melee"}, {}, "sword", {"id": 1, "hp": 12, "block": 5}, {"hp": 12, "block": 0})
	_check(["hit.blocked"], "fully blocked replaces impact")
	router.begin_player_action(_state(), {"type": "melee", "damage": 6}, "sword")
	requested.clear()
	router.hit({"type": "melee", "damage": 6}, {}, "sword", {"type": "player", "hp": 12, "block": 1}, {"hp": 7, "block": 0})
	_check(["hit.blade.heavy", "block.break", "hurt.hero"], "block broken and large hero hit")
	router.begin_player_action(_state(), {"type": "melee"}, "sword")
	requested.clear()
	router.hit({"type": "melee"}, {}, "sword", {"id": 1, "hp": 12, "freeze": 1}, {"hp": 9})
	_check(["status.shatter"], "frozen contact replaces impact")
	var death_representatives: Dictionary = {"crawler": "beast", "acolyte": "humanoid", "harrier": "bone", "warden": "stone", "cinder_ooze": "ooze", "lightning_wisp": "spirit", "gallows_roc": "avian", "tharokh": "dragon"}
	for type: String in death_representatives:
		router.death({"id": type, "type": type})
		_check(["death." + death_representatives[type]], "death start " + type)
	router.death({"type": "player"})
	_check(["death.hero"], "hero fall")
	for unit: Dictionary in [{"type": "player"}, {"type": "crawler"}, {"type": "warden"}, {"type": "tharokh"}]:
		var type: String = unit["type"]
		router.walk_start(unit)
		_check(["dragon.wings"] if type == "tharokh" else [], "movement departure " + type)
		router.walk_tile(unit)
		_check(["step.hero"] if type == "player" else ["step.enemy.light"] if type == "crawler" else ["step.enemy.heavy"], "walk cycle tile " + type)
	router.walk_tile({"type": "crawler", "footprint": Vector2i(2, 1)})
	_check(["step.enemy.heavy"], "normalized large footprint selects heavy steps")
	router.begin_enemy_action(_state(), {"kind": "intent", "actor_key": "enemy_9"}, {"id": 9, "type": "vyraketh"})
	_check(["dragon.roar"], "dragon first action")
	# Find a deterministic representative of the director's 30% branch.
	for seed_value: int in range(100):
		var state: Dictionary = _state()
		state["seed"] = seed_value
		router.begin_enemy_action(state, {"kind": "melee", "damage": 2, "actor_key": "enemy_1"}, {"id": 1, "type": "crawler"})
		if requested.has("vocal.beast"):
			_check(["vocal.beast", "swing.light"], "seeded beast vocal wind-up")
			break
		requested.clear()
	# Drive observed result states through the same board presentation callback.
	var before: Dictionary = _state()
	var after: Dictionary = before.duplicate(true)
	after["player"].merge({"block": 3, "stoneskin": 2, "bleed": 1, "freeze": 1, "shock": 1, "stagger": 1}, true)
	router.baseline(before)
	router.presentation(after, {})
	_check(["block.gain", "stoneskin.gain", "status.bleed", "status.freeze", "status.shock", "status.stagger"], "status and defense gains")
	router.blink()
	router.push()
	router.begin_player_action(_state(), {"type": "push"})
	router.hit({"type": "push", "collision": true}, {}, "", {"id": 1, "hp": 12}, {"hp": 10})
	_check(["move.blink", "push.slide", "push.collision"], "blink and push collision")
	router.trap([{"element": "fire"}])
	_check(["trap.trigger"], "trap springs with one designed cue")
	router.outcomes([{"kind": "surface_created", "surface": "fire"}])
	_check(["surface.fire"], "trap element is heard only through its created surface")
	for surface: String in ["fire", "ice", "electrified", "rubble"]:
		router.outcomes([{"kind": "surface_created", "surface": surface}])
		_check(["surface." + ("electric" if surface == "electrified" else surface)], "surface created " + surface)
	router.light()
	router.heal()
	router.illusion_spawn()
	router.illusion_break()
	router.crate(false)
	router.crate(true)
	router.pickup("item")
	router.pickup("equipment")
	router.defiance()
	router.fatigue()
	router.relic_trigger()
	_check(["radiance.light", "heal", "illusion.spawn", "illusion.break", "crate.hit", "crate.break", "pickup.item", "pickup.gear", "defiance", "fatigue", "relic.trigger"], "support and board outcomes")
	router.card_hover()
	router.card_select()
	router.card_invalid()
	router.baseline({"deck": {"cycles": 0, "burned": []}})
	router.deck_transition({"cycles": 1, "burned": ["spark"]})
	router.map_hover()
	router.map_select()
	router.event_choose()
	router.omen("blessing")
	router.omen("bane")
	router.shop_buy()
	router.shop_sell()
	_check(["card.hover", "card.select", "card.invalid", "deck.shuffle", "card.exhaust", "map.hover", "map.select", "event.choose", "omen.blessing", "omen.bane", "shop.buy", "shop.sell"], "committed UI states")
	for biome: String in ["stone", "tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"]:
		router.ambience(biome)
		_check(["ambience." + biome], "biome bed " + biome)
	# Same-frame contacts have one primary; later frames may add two layers.
	var area: Dictionary = {"type": "aoe", "element": "fire", "damage": 3}
	router.begin_player_action(_state(), area)
	for id: int in range(4): router.hit(area, {}, "", {"id": id, "hp": 12}, {"hp": 9})
	_check(["spell.fire"], "one primary for simultaneous area impacts")
	for id: int in range(4, 7):
		bank.set_test_clock(bank.now_ms() + 17)
		router.hit(area, {}, "", {"id": id, "hp": 12}, {"hp": 9})
	_check(["spell.fire", "spell.fire"], "two later contact frames retain the area cap")
	bank.advance(0.1)
	_check([], "area impacts never wait in a stagger queue")
	# The same contact arriving through two hooks merges inside the data window.
	var contact: Dictionary = {"type": "melee", "damage": 3}
	router.begin_player_action(_state(), contact, "sword")
	requested.clear()
	router.hit(contact, {}, "sword", {"id": 1, "hp": 12}, {"hp": 9})
	router.hit(contact, {}, "sword", {"id": 1, "hp": 12}, {"hp": 9})
	_check(["hit.blade.light"], "same target contact merges within 60ms")
	var launch: Dictionary = {"type": "ranged", "damage": 3}
	router.begin_player_action(_state(), launch, "bow")
	router.presentation(_state(), {"effect": {"kind": "ranged"}, "effect_progress": 0.1})
	_check([], "preparation and pre-release samples do not fire a shot")
	router.presentation(_state(), {"effect": {"kind": "ranged"}, "effect_progress": 0.18})
	_check(["shot.bow"], "shot aligns with the authored release sample")
	router.begin_player_action(_state(), {"type": "push"})
	router.outcomes([{"kind": "force_collision", "actor_kind": "enemy", "id": 1}])
	router.hit({"type": "push"}, {}, "", {"id": 1, "hp": 12, "block": 3}, {"hp": 12, "block": 0})
	_check(["hit.blocked"], "fully absorbed collision retains the blocked replacement")
	# Observe resolved board snapshots, not only the moment entry points.
	var observed: Dictionary = _state()
	observed["terrain"] = [{"id": "box", "kind": "box", "hp": 5}]
	observed["illusions"] = []
	router.baseline(observed)
	var changed: Dictionary = observed.duplicate(true)
	changed["player"]["hp"] = 13
	changed["terrain"][0]["hp"] = 3
	changed["illusions"] = [{"id": 1, "hp": 1}]
	router.presentation(changed, {})
	_check(["heal", "crate.hit", "illusion.spawn"], "observed heal, crate damage and illusion creation")
	changed = changed.duplicate(true)
	changed["terrain"][0]["hp"] = 0
	changed["illusions"] = []
	router.presentation(changed, {})
	_check(["crate.break", "illusion.break"], "observed crate and illusion destruction")
	observed = _state()
	observed["relics"] = ["iron_lung"]
	observed["log"] = []
	router.baseline(observed)
	changed = observed.duplicate(true)
	changed["relic_flags"] = {"iron_lung:counter": 1}
	router.presentation(changed, {})
	_check([], "Relic counters do not falsely announce an effect")
	changed["log"] = ["Iron Lung triggers."]
	router.presentation(changed, {})
	_check(["relic.trigger"], "observed explicit relic reward record")
	# Removed Expose remains silent when applied.
	router.status("expose")
	_check([], "removed Expose")

func _check_director_families() -> void:
	var section_families: Dictionary = {
		"burrow_grub": ["claw", "beast"], "ember_tick": ["claw", "beast"],
		"hoarfrost_seer": ["blunt", "humanoid"], "gale_herald": ["blunt", "humanoid"],
		"arc_thrall": ["blunt", "humanoid"], "gloam_stalker": ["blade", "spirit"],
		"briar_weaver": ["claw", "stone"], "slag_mortar": ["blunt", "humanoid"],
		"glacial_mirror": ["blunt", "stone"], "gust_shrike": ["claw", "avian"],
		"storm_capacitor": ["blunt", "stone"], "hollow_mimic": ["blade", "spirit"],
		"bell_tender": ["blunt", "humanoid"], "storm_cantor": ["blunt", "humanoid"]
	}
	for type: String in section_families:
		if router.enemy_family(type) != section_families[type][0] or router.enemy_family(type, true) != section_families[type][1]:
			failures.append("Director enemy families differ: " + type)
		if router.impact_cue({"type": "melee", "element": "fire"}, {"type": type}) != "spell.fire":
			failures.append("Element fails to override physical family: " + type)
	if router.weapon_family("galewhip") != "blade" or router.weapon_family("fixture_unknown_weapon") != "blunt":
		failures.append("Director Galewhip/unknown weapon families differ")
	if router.enemy_family("fixture_unknown_enemy") != "blunt" or router.enemy_family("fixture_unknown_enemy", true) != "humanoid":
		failures.append("Director unknown enemy/death defaults differ")

func _state() -> Dictionary:
	return {"seed": TEST_SEED, "player": {"type": "player", "hp": 12}, "enemies": [], "deck": {"cycles": 0, "burned": []}}

func _report() -> void:
	var lines: PackedStringArray = PackedStringArray(["cue | requested | variants/fallback | source"])
	for cue: String in bank.data["cues"]:
		var state: Dictionary = bank.cues[cue]
		var available: String = "fallback" if state["fallback"] and not (state["streams"] as Array).is_empty() else "variants" if not (state["streams"] as Array).is_empty() else "silent"
		var source: String = str(state["entry"].get("variants_from", "direct"))
		lines.append("%s | %s | %s | %s" % [cue, "yes" if covered.has(cue) else "no", available, source])
		if not covered.has(cue): failures.append("Uncovered trigger: " + cue)
		if available == "silent": failures.append("Director cue has no loaded variants/fallback: " + cue)
	for cue: String in bank.data.get("removed", {}): lines.append("%s | removed | deliberately silent | removed" % cue)
	var report: String = "\n".join(lines)
	print(report)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	var file := FileAccess.open(REPORT_DIR.path_join("coverage.txt"), FileAccess.WRITE)
	file.store_string(report + "\n")
	print("SFX_CUE_COVERAGE_REPORT=" + ProjectSettings.globalize_path(REPORT_DIR.path_join("coverage.txt")))

func _live_checks() -> void:
	var visual: bool = OS.get_cmdline_user_args().has("--visual")
	if visual and DisplayServer.get_name().to_lower() == "headless":
		failures.append("Visual sound proof requires a real renderer")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	Store.set_storage_path("user://sfx_cue_coverage/progression.json")
	Store.set_run_storage_path("user://sfx_cue_coverage/run.save")
	Settings.set_storage_path("user://sfx_cue_coverage/settings.json")
	Store.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	if visual:
		root.mode = Window.MODE_WINDOWED
		root.content_scale_size = TEST_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.size = TEST_VIEWPORT
		Settings.apply_settings(settings, root, false)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.call("_close_dialogue")
	var engine := Combat.new()
	var grid: Array = []
	for y: int in range(7):
		var row: Array[String] = []
		for x: int in range(8): row.append("wall" if x == 0 or y == 0 or x == 7 or y == 6 else "stone")
		grid.append(row)
	var state: Dictionary = engine.create_combat(TEST_SEED, {"grid": grid, "player_start": Vector2i(2, 3), "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(3, 3), "hp": 12, "max_hp": 12}], "coord": Vector2i(1, 0)}, {"hp": 24, "max_hp": 24, "deck_cards": ["quick_stab", "brace", "pale_spark"], "relics": [], "hand_size": 3})
	var run: Dictionary = RunEngine.new().create_new_run(TEST_SEED, Store.default_data())
	run["mode"] = "combat"
	run["current_room"] = Vector2i(1, 0)
	run["combat_state"] = state
	run["equipped_equipment"] = {"weapon": "training_sword"}
	scene.call("_load_run_state", run)
	scene.call("_close_dialogue")
	await process_frame
	var live_bank: Node = scene.get("_sfx_bank")
	var live_router: RefCounted = scene.get("_sfx_router")
	var hand_card: Control = scene.call("_hand_card_control", 0)
	if not CursorFeedback.cue_owns_feedback(hand_card) or not CursorFeedback.cue_owns_feedback(hand_card, true):
		failures.append("Production hand card must own click and focus feedback")
	await _check_shared_feedback(live_router)
	live_bank.cue_requested.connect(_record)
	requested.clear()
	var after: Dictionary = state.duplicate(true)
	after["enemies"][0]["hp"] = 9
	await scene.call("_animate_player_action_step", state, after, "quick_stab", {"type": "melee", "damage": 3}, Vector2i(3, 3))
	_check(["swing.light", "hit.blade.light"], "live scene melee wind-up then rendered contact")
	if visual: await _capture("01_melee_contact")
	var ranged_after: Dictionary = after.duplicate(true)
	ranged_after["enemies"][0]["hp"] -= 3
	await scene.call("_animate_player_action_step", after, ranged_after, "pale_spark", {"type": "ranged", "damage": 3, "range": 3}, Vector2i(3, 3))
	_check(["cast.arcane", "hit.arcane"], "live neutral preparation, launch and contact")
	after = ranged_after

	live_router.baseline(after)
	var healed: Dictionary = after.duplicate(true)
	healed["enemies"][0]["hp"] += 1
	scene.call("_render_board_state", healed, {})
	_check(["heal"], "live board heal submission")
	live_router.baseline(healed)
	var defense: Dictionary = healed.duplicate(true)
	defense["player"]["block"] = 3
	scene.call("_render_board_state", defense, {})
	_check(["block.gain"], "live board defense submission")
	scene.call("_on_card_hover_started", 0)
	_check(["card.hover"], "live pointer/focus hand-card entry")
	scene.call("_card_preview_for_index", 99)
	_check([], "read-only preview queries never request invalid sounds")
	scene.call("_on_card_pressed", 99)
	_check(["card.invalid"], "live unplayable selection")
	# Repeated frames stay quiet.
	scene.call("_render_board_state", defense, {})
	_check([], "same rendered snapshot does not retrigger cues")
	if visual: await _capture("02_defense_result")
	scene.queue_free()
	await process_frame

func _check_shared_feedback(live_router: RefCounted) -> void:
	var feedback: Node = root.get_node("CursorFeedback")
	while bool(feedback.call("is_loading")): await process_frame
	var surface := Control.new()
	root.add_child(surface)
	var map: Button = preload("res://scripts/section_map_node.gd").new()
	map.set("actionable", true)
	surface.add_child(map)
	live_router.bind_map_hover(map)
	var choice: Control = preload("res://scripts/event_view_choice.gd").new()
	choice.focus_mode = Control.FOCUS_ALL
	surface.add_child(choice)
	live_router.bind_map_hover(choice)
	var card := Control.new()
	card.focus_mode = Control.FOCUS_ALL
	card.set_meta(CursorFeedback.CUE_CLICK_META, true)
	card.set_meta(CursorFeedback.CUE_FOCUS_META, true)
	surface.add_child(card)
	for control: Control in [map, choice, card]:
		if not CursorFeedback.cue_owns_feedback(control): failures.append("Dedicated cue must own pointer feedback")
		var before: Dictionary = feedback.call("feedback_counts")
		feedback.call("_begin_pointer_press_with_context", Vector2.ZERO, {"actionable": true, "drag_source": control == card, "cue_click": true})
		feedback.call("_end_pointer_press")
		feedback.call("play_action_confirmation")
		if feedback.call("feedback_counts") != before: failures.append("Dedicated cue must suppress pointer press/release confirmation")
		control.grab_focus()
		feedback.set("_last_valid_gesture_msec", -1000)
		feedback.call("play_action_confirmation")
		if feedback.call("feedback_counts") != before: failures.append("Dedicated cue must suppress keyboard/controller confirmation")
		control.release_focus()
	map.grab_focus()
	await process_frame
	var before: Dictionary = feedback.call("feedback_counts")
	feedback.set("_last_valid_gesture_msec", -1000)
	feedback.call("play_action_confirmation")
	feedback.call("play_focus_feedback", map)
	ButtonFeedback.bind_button(map)
	map.mouse_entered.emit()
	if feedback.call("feedback_counts") != before: failures.append("Map cue must suppress native confirmation and shared hover tick")
	feedback.call("play_focus_feedback", card)
	if feedback.call("feedback_counts") != before: failures.append("Card cue must suppress shared hover tick")
	if CursorFeedback.cue_owns_feedback(choice, true): failures.append("Event choices retain their shared focus tick")
	map.release_focus()
	feedback.set("_last_valid_gesture_msec", -1000)
	feedback.call("play_action_confirmation")
	if int((feedback.call("feedback_counts") as Dictionary)["valid"]) != int(before["valid"]) + 1:
		failures.append("Ordinary actions must retain their shared click")
	surface.queue_free()
	await process_frame

func _capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_viewport().get_texture().get_image()
	if picture == null:
		failures.append("Renderer did not return a capture")
		return
	var backing: Vector2i = picture.get_size()
	if backing.x * TEST_VIEWPORT.y != backing.y * TEST_VIEWPORT.x:
		failures.append("Capture backing must preserve 1920x1080 aspect")
		return
	if backing != TEST_VIEWPORT: picture.resize(TEST_VIEWPORT.x, TEST_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	var path: String = CAPTURE_DIR.path_join(label + ".png")
	if picture.save_png(ProjectSettings.globalize_path(path)) != OK: failures.append("Could not save " + path)
	print("SFX_CAPTURE=" + ProjectSettings.globalize_path(path))
