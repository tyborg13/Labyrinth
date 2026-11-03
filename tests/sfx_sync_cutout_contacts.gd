extends RefCounted

const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Data = preload("res://scripts/game_data.gd")
const MotionFixture = preload("res://tests/suites/combat_motion_timing_suite.gd")
const TYPE: String = "gale_herald"
const ACTOR_KEY: String = "enemy_1"
const CONTACT_SOURCE: String = "res://scripts/maquette_cutout_runtime/contact_actions.gd"
const FIXTURE_PUSH_DELTA := Vector2i.LEFT

static func run(h: SceneTree) -> void:
	# The protected integration assigns push.slide to call_the_wind, not
	# gust_bolt. Exercise both real selectors without changing their cue data.
	for intent_id: String in ["gust_bolt", "call_the_wind"]:
		MotionFixture._install_fixture(h.scene, false)
		h._begin("enemy/cutout_contact/" + TYPE + "/" + intent_id)
		var before: Dictionary = h._state()
		var actor: Dictionary = before["enemies"][0]
		actor["type"] = TYPE
		for intent: Dictionary in Data.enemy_def(TYPE)["intents"]:
			if str(intent["id"]) == intent_id: actor["intent"] = intent.duplicate(true)
		var push: bool = intent_id == "call_the_wind"
		var step: Dictionary = {"kind": "push" if push else "ranged", "action_type": "call_wind" if push else "ranged",
			"intent_id": intent_id, "actor_key": ACTOR_KEY, "actor_name": Data.enemy_def(TYPE)["name"],
			"from": actor["pos"], "to": before["player"]["pos"], "element": "air"}
		if push: step["player_to"] = before["player"]["pos"] + FIXTURE_PUSH_DELTA
		var clip: String = Action.clip_for(step, actor)
		if clip != intent_id or Action.playback_adapter(step, actor) == null:
			h.failures.append("Cutout contact fixture must select its production adapter: " + h.scenario)
			continue
		var contact: float = float(Action.data_for(TYPE)["clips"][clip]["contact"])
		var original: Dictionary = before.duplicate(true)
		h._invoke("_animate_enemy_phase_steps", [before, [step]])
		var frames: Array = h.clock.frames.filter(func(frame: Dictionary) -> bool:
			return str(frame["shown"].get(TYPE + "_motion", {}).get(ACTOR_KEY, {}).get("clip", "")) == clip)
		var contacts: Array = frames.filter(func(frame: Dictionary) -> bool:
			return float(frame["shown"][TYPE + "_motion"][ACTOR_KEY]["phase"]) >= contact)
		if frames.is_empty() or contacts.is_empty() or frames[0] == contacts[0]:
			h.failures.append("Cutout contact fixture must show wind-up and contact: " + h.scenario)
		var requests: Array = h.events.filter(func(event: Dictionary) -> bool: return event["cue"] == "push.slide")
		if push:
			if requests.size() != 1 or requests.filter(func(event: Dictionary) -> bool: return event["result"] == "played").size() != 1:
				h.failures.append("Cutout push contact must request and play push.slide exactly once: " + h.scenario)
			for event: Dictionary in requests:
				if contacts.is_empty() or float(event["play_ms"]) != float(contacts[0]["time_ms"]):
					h.failures.append("Cutout push cue must play on the first contact frame: " + h.scenario)
				if not event["stack"].any(func(frame: Dictionary) -> bool: return frame["source"] == CONTACT_SOURCE):
					h.failures.append("Cutout push cue must originate in contact_actions.gd: " + h.scenario)
			if not contacts.is_empty() and contacts[0]["state"]["player"]["pos"] != step["player_to"]:
				h.failures.append("Cutout push displacement must appear at contact: " + h.scenario)
		else:
			if not Action.contact_cue_for(step, actor).is_empty() or not requests.is_empty():
				h.failures.append("Gust Bolt preserves its protected contact-cue declaration: " + h.scenario)
		print("SFX SYNC CUTOUT CONTACT: %s / %sx / %s: %d push requests, %d contact submissions" % [h.frame_profile, h.combat_scale, intent_id, requests.size(), contacts.size()])
		h._finish(original)
