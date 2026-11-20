extends RefCounted
## Load maintained fixtures between cases. After installation only joypad input
## may open, act on, or close a surface.
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const Tour = preload("res://tools/hitch_census/tour.gd")
const Stops = preload("res://tools/hitch_census/combat_stops.gd")
const Guide = preload("res://scripts/contextual_combat_tutorial.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Events = preload("res://scripts/event_rules.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const GraftFixture = preload("res://tests/suites/graftwright_suite.gd")
const Sweep = preload("res://tests/controller_screen_sweep.gd")
const LayoutSweep = preload("res://tools/qa107/layout_sweep.gd")
const RulesSweep = preload("res://tools/ui33/layout_sweep.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Geometry = preload("res://tools/qa107/layout_geometry.gd")
const Gate = preload("res://tools/hitch_census/demo/gate.gd")
const FIXTURE_SEED: int = 83
const UNLOCKED_DEPTH: int = 3
const SHOP_BUDGET: int = 720
const SETTLE_S: float = 0.65
const EVENT_WAIT_S: float = 0.28
const TOOLTIP_READING_S: float = 1.0
const SURVEY_FIXTURE_SEEDS := [7, 2, 421, 11, 23, 47]
const REPLAY_FILTER_ENV: String = "QA117_FILTER"
const TRANSITION_TIMEOUT_S: float = 16.0
const EVENT_NAVIGATION_LIMIT: int = 5
const COMBAT_READ_S: float = 0.45
const STOCK := {"equipment_inventory": "ward_kite,iron_cleaver,boiled_leather,glassbone_cuirass",
	"magic_inventory": "spark_dart,frostbolt", "attuned_magic": "pale_spark", "item_inventory": "crimson_draught,nail_bomb",
	"held_embers": SHOP_BUDGET}
const HAND_STATE: String = "hand"
const REWARD_HEALTH_MISSING: int = 1
const GRAFT_DONOR: String = "patched_cloak"
const GRAFT_RECIPIENT: String = "undertaker_plate"
const GRAFT_CARD_INDEX: int = 1
const GRAFT_RITUAL_WAIT_S: float = 3.5

var h
var driver
var sweep: SceneTree
var fixture_builder: SceneTree

func _init(host) -> void:
	h = host
	driver = h.driver

func run(matrix: String) -> void:
	fixture_builder = Fixtures.new()
	sweep = Sweep.new()
	match matrix:
		"events": await event_matrix(false)
		"reveal-events": await event_matrix(true)
		"rules": await rule_matrix()
		"tour": await tour()
		_: h.fail("Unknown matrix: " + matrix)
	fixture_builder.free()
	sweep.free()

func scene() -> Node: return h.current_scene

func install(state: Dictionary, reuse: bool = false) -> bool:
	if state.is_empty():
		h.log_event("fixture_error", {"message": fixture_builder.census_error})
		return false
	var current: Node = scene()
	if not reuse or current == null or not current.scene_file_path.ends_with("run_scene.tscn"):
		await enter("res://scenes/run_scene.tscn")
	var run: Node = scene()
	run.set("_progression", state["progression"])
	run.call("_load_run_state", state)
	run.call("_close_dialogue")
	await settle()
	h.log_event("fixture", {"mode": state.get("mode"), "room": str(state.get("current_room")), "seed": state.get("seed")})
	return true

func enter(path: String) -> void:
	h.change_scene_to_file(path)
	await h.scene_changed
	driver.scene = scene()
	h.failure = ""
	await h.frames(h.BOOT_FRAMES)

func settle() -> void:
	await h.hold(SETTLE_S)
	var deadline: int = Time.get_ticks_msec() + int(TRANSITION_TIMEOUT_S * 1000)
	while not h.finished and not Gate.ready(scene()) and Time.get_ticks_msec() < deadline:
		await h.process_frame
	await h.frames(h.BOOT_FRAMES)
	driver.scene = scene()

func checkpoint(name: String, inventory: bool = true) -> void:
	if h.finished: return
	await h.sample(name)
	if h.finished or not inventory: return
	var scope: Control = h.audit.scope(scene())
	var focus: Control = h.root.gui_get_focus_owner()
	var targets: Array[Control] = sweep._controls(scope)
	var paths: Dictionary
	var no_dpad_path: Array[String]
	for target: Control in targets:
		var key: String = Geometry.path(target, scene())
		if focus == target:
			paths[key] = []
			continue
		if focus != null and (scope == focus or scope.is_ancestor_of(focus)):
			var inputs: Array = sweep._route(scope, focus, target)
			if not inputs.is_empty():
				paths[key] = inputs
				continue
		no_dpad_path.append(key)
	var tooltip_sources: Array[Dictionary]
	for candidate: Dictionary in h.audit.hover._candidates(scene(), h.root, scope).values():
		var owner: Control = candidate["owner"].get_ref()
		tooltip_sources.append({"path": candidate["path"], "trigger": candidate["trigger"],
			"focusable": owner != null and owner.focus_mode == Control.FOCUS_ALL})
	h.log_event("inventory", {"state": name, "targets": targets.size(), "dpad_model_paths": paths,
		"no_dpad_model_path": no_dpad_path, "pointer_candidates": tooltip_sources})

func press(button: int) -> bool:
	if h.finished: return false
	var sent: bool = await driver.pad.button(button)
	await settle()
	return sent

func action(target: Control) -> bool:
	if h.finished or not is_instance_valid(target): return false
	var focused: bool = await driver.control(target)
	h.failure = ""
	return focused and await press(JOY_BUTTON_A)

func named(parent: Node, node_name: String) -> Control:
	return parent.find_child(node_name, true, false) as Control if is_instance_valid(parent) else null

func caption(parent: Node, text: String) -> Control:
	if not is_instance_valid(parent): return null
	for node: Node in parent.find_children("*", "Button", true, false):
		if node.text.strip_edges().nocasecmp_to(text) == 0 and not node.disabled and node.is_visible_in_tree(): return node
	return null

func back(label: String, closed: Callable) -> void:
	if await press(JOY_BUTTON_B):
		h.log_event("back", {"state": label, "passed": bool(closed.call())})
		await checkpoint(label + "/after-b", false)

func tour() -> void:
	var profile: Dictionary = Guide.complete_tutorial(Store.default_data())
	profile[Store.UMBRA_DEPTH_UNLOCKED_KEY] = UNLOCKED_DEPTH
	Store.save_data(profile)
	await enter("res://scenes/main_menu.tscn")
	await driver.pad.pulse(Vector2.DOWN)
	await checkpoint("title-menu")
	if await action(scene().get("start_button")):
		await checkpoint("new-run")
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		await checkpoint("new-run/depth-next")
		await back("new-run", func() -> bool: return not is_instance_valid(scene().get("_new_descent_panel")))
	if await action(scene().get("chronicle_button")):
		await checkpoint("chronicle/empty")
		await back("chronicle/empty", func() -> bool: return not shown("_chronicle"))
	if await action(scene().get("settings_button")):
		await settings("title-settings", "settings_panel")
	for name: String in Tour.SCENARIOS + Stops.CASES.keys():
		if h.finished: return
		var state: Dictionary = GraftFixture.fixture(FIXTURE_SEED) if name == "graftwright" else fixture_builder.make(name, FIXTURE_SEED, STOCK)
		if not await install(state): continue
		await checkpoint("tour/" + name)
		if h.finished: return
		match name:
			"start": await toolbar()
			"pre_battle":
				if await action(driver.match_text(driver.controls(scene().get("_pre_battle_scrim")), ["start", "begin", "fight"])):
					await checkpoint("tour/pre_battle/entered")
			"combat": await combat()
			"reward", "treasure", "campfire": await room_choices(name)
			"scavenger": await shop(name)
			"graftwright": await graft()
			"defeat", "victory": await recap(name)
			_:
				if Stops.CASES.has(name): await play_stop(name)

	if h.finished: return
	var reward: Dictionary = fixture_builder.make("reward", FIXTURE_SEED)
	if not reward.is_empty():
		reward["player_hp"] = int(reward["player_max_hp"]) - REWARD_HEALTH_MISSING
		if await install(reward): await checkpoint("tour/reward-hurt")

func shown(field: String) -> bool:
	return h.audit.painted(scene().get(field))

func settings(label: String, field: String) -> void:
	var settings_panel: Control = scene().get(field)
	await checkpoint(label)
	if await action(caption(settings_panel, "Restore Defaults")):
		await checkpoint(label + "/restore")
		await back(label + "/restore", func() -> bool: return not h.audit.painted(settings_panel.get("_confirmation_panel")))
	await back(label, func() -> bool: return not shown(field))

func toolbar() -> void:
	if shown("_large_map_scrim"): await press(JOY_BUTTON_B)
	await press(JOY_BUTTON_BACK)
	await checkpoint("map")
	if shown("_large_map_scrim"):
		await press(JOY_BUTTON_DPAD_RIGHT)
		await checkpoint("map/route-node")
		await back("map", func() -> bool: return not shown("_large_map_scrim"))
	if await action(scene().get("loadout_button")):
		for tab: int in range(3):
			await checkpoint("character/" + str(scene().get("_progression_overlay_mode")))
			await press(JOY_BUTTON_RIGHT_SHOULDER)
		await back("character", func() -> bool: return not shown("_upgrade_scrim"))
	if await action(scene().get("grimoire_button")):
		await checkpoint("grimoire")
		var search: Control = scene().get("_grimoire_search_input")
		if h.root.gui_get_focus_owner() == search and await press(JOY_BUTTON_A):
			await h.hold(TOOLTIP_READING_S)
			await checkpoint("grimoire/search-after-a")
		await press(JOY_BUTTON_DPAD_DOWN)
		await checkpoint("grimoire/next")
		await back("grimoire", func() -> bool: return not shown("_grimoire_scrim"))
	if await press(JOY_BUTTON_START) and shown("_menu_scrim"):
		await checkpoint("pause")
		if await action(caption(scene().get("_menu_scrim"), "Settings")):
			await settings("pause/settings", "_settings_panel")
		await back("pause", func() -> bool: return not shown("_menu_scrim"))
	var saved: Dictionary = scene().get("_run_state")
	if await press(JOY_BUTTON_START) and await action(caption(scene().get("_menu_scrim"), "Save and Quit")):
		await driver.wait_ready()
		await checkpoint("continue/title")
		if await action(scene().get("continue_button")):
			await driver.wait_ready()
			await checkpoint("continue/resumed")
			var resumed: Dictionary = scene().get("_run_state")
			h.log_event("continue", {"seed": resumed.get("seed"), "room": str(resumed.get("current_room")),
				"passed": saved.get("seed") == resumed.get("seed") and saved.get("current_room") == resumed.get("current_room") and saved.get("player_hp") == resumed.get("player_hp")})

func combat() -> void:
	if str(scene().get("_controller_region")) != HAND_STATE or not scene().get("_controller_hand_focused"):
		await press(JOY_BUTTON_X)
	await checkpoint("combat/hand")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	await checkpoint("combat/card-tooltip")
	if await press(JOY_BUTTON_A):
		await checkpoint("combat/selected")
		await back("combat/selected", func() -> bool: return int(scene().get("_selected_card_index")) < 0 and not bool(scene().call("_controller_card_mode_active")))
	var battle: Dictionary = scene().get("_combat_state")
	if battle.get("enemies", []).is_empty(): return
	for enemy: Dictionary in battle["enemies"]:
		if not scene().get("board_view").call("_board_tile_is_visible_to_player", enemy["pos"]): continue
		if await driver.board(enemy["pos"]):
			await h.hold(COMBAT_READ_S)
			await checkpoint("combat/enemy-tooltip")
		h.failure = ""
		break
	var toggle: Control = scene().get("_enemy_intent_toggle_button")
	var before: bool = scene().get("_show_all_enemy_intents")
	if await action(toggle):
		h.log_event("activation", {"target": "EnemyIntentToggle", "passed": before != scene().get("_show_all_enemy_intents")})
		await checkpoint("combat/details")
	h.failure = ""
	await press(JOY_BUTTON_Y)
	await checkpoint("combat/pass-turn")

func play_stop(name: String) -> void:
	var before: Dictionary = Stops.witness(scene(), name)
	for round_index: int in range(Stops.ROUND_COUNT):
		if h.finished or not await press(JOY_BUTTON_Y): return
		var after: Dictionary = Stops.witness(scene(), name)
		h.log_event("playback", {"state": name, "round": round_index + 1, "before": before, "after": after})
		await checkpoint("tour/%s/pass-%d" % [name, round_index + 1], false)
		if not after["ready"] or after["turn"] <= before["turn"]: return
		before = after

func room_choices(name: String) -> void:
	var scope: Control = h.audit.scope(scene())
	for button: Control in driver.controls(scope):
		if not button.has_meta("choice_id") and str(button.get("card_id")).is_empty(): continue
		if await driver.control(button):
			await h.hold(COMBAT_READ_S)
			var id: String = str(button.get_meta("choice_id", button.get("card_id")))
			await checkpoint("tour/%s/focused-%s" % [name, id], false)
		h.failure = ""
		if h.finished or not is_instance_valid(scope): return
	if await press(JOY_BUTTON_A):
		await checkpoint("tour/" + name + "/after-a")

func shop(name: String) -> void:
	var view: Control = scene().get("_scavenger_shop_view")
	if not h.audit.painted(view): return
	if await action(view.get("_mode_buy")):
		await checkpoint("tour/" + name + "/buy")
		var sources: Dictionary = view.get("_offer_sources")
		for key: String in sources:
			if key.begins_with("buy:") and await action(sources[key]):
				await checkpoint("tour/" + name + "/detail")
				break
	if await action(view.get("_mode_sell")):
		await checkpoint("tour/" + name + "/sell")
	var purge: Control = named(view, "ScavengerPurge")
	if await action(purge):
		await checkpoint("tour/" + name + "/purge")
		await press(JOY_BUTTON_A)
		await checkpoint("tour/" + name + "/purge-confirmation")
		await back("tour/" + name + "/purge-confirmation", func() -> bool:
			var overlay: Control = scene().get("_magic_purge_overlay")
			return is_instance_valid(overlay) and not h.audit.painted(overlay.get("_confirmation")))
		await back("tour/" + name + "/purge", func() -> bool: return not is_instance_valid(scene().get("_magic_purge_overlay")))
	await back("tour/" + name, func() -> bool: return not shown("_scavenger_shop_view"))

func graft() -> void:
	var view: Control = scene().get("_graftwright_view")
	if await action(named(view, "GraftBrowse")):
		await checkpoint("graftwright/browse")
		if await action(named(view, "ChooseSacrifice")):
			await checkpoint("graftwright/donor-picker")
			await back("graftwright/donor-picker", func() -> bool: return str(view.get("_picker_role")).is_empty())
		if await action(named(view, "ChooseRecipient")):
			await checkpoint("graftwright/recipient-picker")
			await back("graftwright/recipient-picker", func() -> bool: return str(view.get("_picker_role")).is_empty())
		await graft_ritual(view)
	await back("graftwright", func() -> bool: return not shown("_graftwright_view"))

func graft_ritual(view: Control) -> void:
	if not await action(named(view, "ChooseRecipient")) or not await action(named(view, "Pick_" + GRAFT_RECIPIENT)): return
	if not await action(named(view, "ChooseSacrifice")) or not await action(named(view, "Pick_" + GRAFT_DONOR)): return
	await checkpoint("graftwright/pair")
	var card: Control = named(view, "SourceCard_%d" % GRAFT_CARD_INDEX)
	if not await driver.control(card):
		h.failure = ""
		return
	if await press(JOY_BUTTON_Y) and h.audit.painted(view.get("_inspection")):
		await checkpoint("graftwright/inspect")
		await back("graftwright/inspect", func() -> bool: return not is_instance_valid(view.get("_inspection")))
	if not await action(card) or not await action(named(view, "TargetCard_%d" % GRAFT_CARD_INDEX)): return
	await checkpoint("graftwright/commit-ready")
	if await action(named(view, "GraftCommit")):
		await h.hold(GRAFT_RITUAL_WAIT_S)
		await checkpoint("graftwright/committed")
		var record: Dictionary = scene().get("_run_state").get("equipment_grafts", {}).get(GRAFT_RECIPIENT, {})
		h.log_event("activation", {"target": "GraftCommit", "passed": record.get("source") == GRAFT_DONOR, "record": record})

func recap(name: String) -> void:
	var overlay: Control = scene().get("_run_end_recap")
	if not h.audit.painted(overlay): return
	await h.hold(float(overlay.call("presentation_duration")))
	await checkpoint("recap/" + name)
	await back("recap/" + name, func() -> bool: return scene().scene_file_path.ends_with("main_menu.tscn"))
	if scene().scene_file_path.ends_with("main_menu.tscn") and await action(scene().get("chronicle_button")):
		await checkpoint("chronicle/recorded-" + name)
		await back("chronicle/recorded-" + name, func() -> bool: return not shown("_chronicle"))

func event_matrix(reveal_only: bool) -> void:
	await enter("res://scenes/main_menu.tscn")
	await driver.pad.pulse(Vector2.DOWN)
	var base: Dictionary = fixture_builder.make("start", FIXTURE_SEED)
	var filter: String = OS.get_environment(REPLAY_FILTER_ENV)
	for id: String in Data.events():
		for choice: Dictionary in Data.event_def(id)["choices"]:
			if h.finished: return
			var choice_id: String = choice["id"]
			if reveal_only and not (choice.get("effects", []) as Array).any(func(effect: Dictionary) -> bool: return effect.get("type") == "reveal"):
				continue
			var label: String = "event/" + id + "/" + choice_id
			if not filter.is_empty() and filter != label: continue
			var state: Dictionary = EventFixture.fixture(id, true, base)
			if Events.choice_block_reason(state, id, choice_id) == "Nothing new to reveal.":
				state = reveal_fixture(state, id, choice_id)
			if not await install(state, true): continue
			var view: Control = scene().get("_event_view")
			if not h.audit.painted(view):
				h.log_event("event_choice", {"state": label, "status": "fixture missing event"})
				continue
			if not Events.choice_available(state, id, choice_id):
				h.log_event("event_choice", {"state": label, "status": "fixture choice blocked", "reason": Events.choice_block_reason(state, id, choice_id)})
				continue
			var located: bool = false
			for step: int in range(EVENT_NAVIGATION_LIMIT):
				var focus: Control = h.root.gui_get_focus_owner()
				if focus != null and str(focus.get("choice_id")) == choice_id:
					located = true
					break
				await driver.pad.button(JOY_BUTTON_DPAD_DOWN)
			await h.hold(EVENT_WAIT_S)
			await checkpoint(label + "/choice", false)
			if h.finished: return
			if located: await press(JOY_BUTTON_A)
			var result: Dictionary = scene().get("_run_state").get("event_state", {})
			var passed: bool = result.get("page") == "result" and result.get("choice_id") == choice_id
			h.log_event("event_choice", {"state": label, "status": "resolved" if passed else "activation failed", "fit": view.call("fit_report")})
			if passed:
				await checkpoint(label + "/result", false)
				await back(label + "/result", func() -> bool: return scene().get("_run_state").get("mode") != "event")

func reveal_fixture(first: Dictionary, event_id: String, choice_id: String) -> Dictionary:
	var engine := Run.new()
	for seed_value: int in SURVEY_FIXTURE_SEEDS:
		var state: Dictionary = EventFixture.fixture(event_id, true, fixture_builder.make("start", seed_value))
		for room: Dictionary in state["rooms"].values():
			var kind: String = str(room.get("type"))
			if kind != "event" and (kind != "mystery" or room.get("mystery_type") != "event"): continue
			if room.get("cleared", false): continue
			var coord: Vector2i = room["coord"]
			state["current_room"] = coord
			if not Events.choice_available(state, event_id, choice_id): continue
			room["event_id"] = event_id
			room["visited"] = true
			room["revealed"] = true
			room["scouted"] = true
			state["current_room_layout"] = engine._display_layout_for_room(seed_value, room, Vector2i.RIGHT)
			return state
	return first

func rule_matrix() -> void:
	await enter("res://scenes/main_menu.tscn")
	await driver.pad.pulse(Vector2.DOWN)
	var builder := RulesSweep.new()
	var rule_fixtures := LayoutSweep.Fixtures.new()
	builder.run_seed = FIXTURE_SEED
	var filter: String = OS.get_environment(REPLAY_FILTER_ENV)
	var keys: Array[String]
	keys.assign(["reach_exit"])
	for id: String in Rules.data()["instances"]:
		keys.append(id)
		if Rules.data()["instances"][id].has("at_half_health"): keys.append(id + "/half_health")
	for tier: int in [1, 2, 3]: keys.append("ember_hoarder/%d" % tier)
	for key: String in keys:
		if h.finished: break
		if not filter.is_empty() and filter != "rule/" + key: continue
		var id: String = key.get_slice("/", 0)
		var variant: String = key.get_slice("/", 1)
		var state: Dictionary = builder._build_fixture(rule_fixtures, id, variant)
		if state.is_empty() and id == "reach_exit":
			state = fixture_builder.make("snare", FIXTURE_SEED, {"snare_biome": "earth", "snare_tier": builder.SPECIAL_TIER})
		if state.is_empty():
			h.log_event("fixture_error", {"state": key, "message": rule_fixtures.census_error})
			continue
		var battle: Dictionary = state["combat_state"]
		if variant == "half_health": builder._switch_half_health(battle)
		if id == "gale_herald":
			var call: Dictionary = Data.enemy_def(id)["intents"][0]["actions"][0]
			Rules.install_call(Combat.new(), battle, 0, call)
		if not await install(state): continue
		await press(JOY_BUTTON_DPAD_UP)
		var label: String = "rule/" + key
		await checkpoint(label, false)
		if h.finished: break
		var hud: Control = scene().get("_battlefield_rule_hud")
		var sentence: Control = named(hud, "RuleSentence")
		if sentence != null:
			h.log_event("rule_fit", {"state": label, "visible": h.audit.painted(sentence), "text": Geometry.text_data(sentence),
				"rect": Geometry.rect_data(Geometry.bounds(sentence, h.root))})
	rule_fixtures.free()
	builder.free()
