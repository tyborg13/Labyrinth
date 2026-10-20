extends RefCounted

const Fixtures = preload("res://tests/suites/card_keywords_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")

static func run(h: SceneTree) -> void:
	Fixtures.install_fixtures()
	var settings: Dictionary = Settings.load_settings()
	for reduced: bool in [false, true]:
		var options: Dictionary = settings.duplicate(true)
		options["reduced_motion"] = reduced
		Settings.apply_settings(options, h.root, false)
		for selected: bool in [false, true]:
			var state: Dictionary = Fixtures._state(Combat.new(), ["kwtest_empower_block"])
			state["current_actor"] = {"kind": "player", "key": "player"}
			state.erase("player_turn_restrictions")
			h.scene.call("_cancel_card_selection")
			h.scene.set("_combat_state", state)
			h.scene.get("_run_state")["mode"] = "combat"
			h.scene.get("_run_state")["combat_state"] = state
			h.scene.set("_animation_lock", false)
			h.scene.call("_mark_combat_preview_state_changed")
			h.scene.call("_refresh_ui")
			h.scene.call("_on_card_hover_started", 0)
			if selected: h._invoke("_on_card_pressed", [0])
			for charged: bool in [true, false]:
				h._begin("input/empower/%s/selected=%s/reduced=%s" % ["charge" if charged else "uncharge", selected, reduced])
				h._invoke("_toggle_pending_empower", ["keyboard"])
				if bool(h.scene.call("_hand_card_empowered", 0)) != charged:
					h.failures.append("Empower sync case did not toggle: " + h.scenario)
				var cue: String = "empower.charge" if charged else "empower.uncharge"
				var plays: Array = h.events.filter(func(event: Dictionary) -> bool: return event["cue"] == cue and event["result"] == "played")
				if plays.size() != 1: h.failures.append("Empower sync case must play once: " + h.scenario)
				h._finish(state)
	var blocked: Dictionary = Fixtures._state(Combat.new(), ["kwtest_empower_health"])
	blocked["player"]["hp"] = 2
	h.scene.call("_cancel_card_selection")
	h.scene.set("_combat_state", blocked)
	h.scene.get("_run_state")["combat_state"] = blocked
	h.scene.call("_mark_combat_preview_state_changed")
	h.scene.call("_refresh_ui")
	h.scene.call("_on_card_hover_started", 0)
	h._begin("input/empower/blocked_health")
	h._invoke("_toggle_pending_empower", ["keyboard"])
	if h.events.size() != 1 or h.events[0]["cue"] != "card.invalid" or h.events[0]["result"] != "played":
		h.failures.append("Blocked Empower sync case must play exactly card.invalid")
	if bool(h.scene.call("_hand_card_empowered", 0)):
		h.failures.append("Blocked Empower sync case must remain uncharged")
	h._finish(blocked)
	Settings.apply_settings(settings, h.root, false)
	Fixtures.remove_fixtures()
