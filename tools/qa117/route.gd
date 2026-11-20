extends "res://tools/hitch_census/demo/route.gd"
## Census bot and real input driver, with QA stops and no health overrides.
const Boons = preload("res://scripts/opening_boon_rules.gd")
const BOON_FOCUS_STEPS: int = 3
const RECAP_EXIT_TIMEOUT_S: float = 8.0
var installed_session: bool

func run() -> void:
	await wait_ready()
	if not s.failure.is_empty(): return
	await pad.pulse(Vector2.DOWN)
	await s.sample("title")
	if not await control(scene.get("start_button")): return
	await pad.button(JOY_BUTTON_A)
	while s.failure.is_empty() and not s.finished:
		await wait_ready()
		if not s.failure.is_empty(): return
		await s.sample("route")
		if s.finished: return
		var state: Dictionary = scene.get("_run_state") if scene.get("_run_state") != null else {}
		if visible(scene.get("_run_end_recap")):
			var recap: Control = scene.get("_run_end_recap")
			while float(recap.get("_elapsed")) < float(recap.call("presentation_duration")):
				await s.process_frame
			await s.sample("recap")
			s.log_event("route_end", {"mode": state.get("mode"), "health": state.get("player_hp")})
			await leave_recap()
			return
		if state.is_empty():
			var setup: Control = scene.get("_new_descent_panel")
			if visible(setup):
				await pad.button(JOY_BUTTON_A)
				continue
			s.fail("Run did not open from title")
			return
		if not installed_session:
			var installed_seed: int = int(state.get("seed", -1))
			s.log_event("run_started", {"seed": installed_seed, "health": state.get("player_hp"), "max_health": state.get("player_max_hp")})
			if installed_seed != s.proof_seed:
				s.fail("New Run installed a different seed: %d" % installed_seed)
				return
			installed_session = true
		var flow = scene.get("_opening_boon_flow")
		if flow.active():
			await modal(flow.overlay, state)
			continue
		if bool(scene.get("_dialogue_active")):
			await pad.button(JOY_BUTTON_A)
			continue
		var phase: String = str(scene.get("_guided_tutorial_phase_id"))
		if not phase.is_empty() and bool(scene.call("_guided_tutorial_is_active")):
			if await tutorial(phase): continue
		if visible(scene.get("_pre_battle_scrim")):
			var opening: Control = match_text(controls(scene.get("_pre_battle_scrim")), ["start", "begin", "fight", "enter"])
			if not await control(opening): return
			await pad.button(JOY_BUTTON_A)
			continue
		var scope: Control = scene.call("_controller_focus_scope")
		if scope != scene.get("ui_root") and not bool(scene.call("_controller_custom_room_available")):
			await modal(scope, state)
		elif str(state.get("mode")) == "combat":
			await combat()
		elif str(state.get("mode")) == "reward":
			await reward(state)
		elif str(state.get("mode")) == "room":
			if not map_seen and not Guide.is_active(scene.get("_progression")):
				await show_map()
			elif Boons.pending(state):
				if not await speak():
					s.fail("Opening boon NPC not reached")
			else:
				await travel(state)
		else:
			s.fail("No route handler for " + str(state.get("mode")))

func leave_recap() -> void:
	if s.finished or not await pad.button(JOY_BUTTON_B): return
	var deadline: int = Time.get_ticks_msec() + int(RECAP_EXIT_TIMEOUT_S * 1000000.0)
	while Time.get_ticks_msec() < deadline and not s.finished:
		scene = s.current_scene
		if is_instance_valid(scene) and scene.scene_file_path.ends_with("main_menu.tscn"):
			await s.frames(s.BOOT_FRAMES)
			s.log_event("back", {"state": "recap", "passed": true})
			await s.sample("route/recap-after-b")
			return
		await s.process_frame
	s.log_event("back", {"state": "recap", "passed": false})
	await s.sample("route/recap-after-b")

func show_map() -> void:
	if not await pad.button(JOY_BUTTON_BACK):
		s.fail("View button was not sent on the settled board")
		return
	await wait_ready()
	if not visible(scene.get("_large_map_scrim")):
		s.fail("View button did not open the map")
		return
	await s.mark("section_map")
	await pad.button(JOY_BUTTON_B)
	map_seen = true

func speak() -> bool:
	var tile: Vector2i = scene.call("_emaciated_service_tile")
	var candidate: Dictionary = scene.call("_controller_candidate_for_tile", tile)
	if candidate.get("kind") != "npc" or not await candidate_focus(str(candidate["key"])): return false
	return await pad.button(JOY_BUTTON_A)

func modal(scope: Control, state: Dictionary) -> void:
	var flow = scene.get("_opening_boon_flow")
	if flow.active():
		var decline: Control = flow.overlay.find_child("DeclineOpeningBoon", true, false)
		if decline == null:
			await pad.button(JOY_BUTTON_A)
			return
		await s.mark("opening-boon/offer")
		for index: int in range(BOON_FOCUS_STEPS - 1):
			if s.finished: return
			await pad.button(JOY_BUTTON_DPAD_RIGHT)
			await s.sample("opening-boon/card-%d" % (index + 2))
		var first: Control = flow.overlay.get("_controls")[0]
		if await control(first):
			await pad.button(JOY_BUTTON_A)
			if flow.active() and not flow.overlay.get("_selected").is_empty():
				await s.sample("opening-boon/secondary")
				await pad.button(JOY_BUTTON_DPAD_RIGHT)
				await s.sample("opening-boon/secondary-tooltip")
				await pad.button(JOY_BUTTON_B)
				await s.sample("opening-boon/after-b")
				decline = flow.overlay.find_child("DeclineOpeningBoon", true, false)
		if is_instance_valid(decline) and await control(decline): await pad.button(JOY_BUTTON_A)
		return
	await super.modal(scope, state)

func resolve_card() -> void:
	if int(scene.get("_selected_card_index")) >= 0:
		await s.sample("route/card-targeting")
	await super.resolve_card()

func _measured_bot(method: String, state: Dictionary) -> Dictionary:
	return bot.call(method, state)
