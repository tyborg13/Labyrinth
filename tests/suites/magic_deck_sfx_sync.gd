extends RefCounted

const Run = preload("res://scripts/run_engine.gd")
const Fixture = preload("res://tests/suites/magic_deck_suite.gd")

# Exercise the live saved-removal call site in every sound-sync clock profile.
# Keep all existing measured-audio and call-site assertions intact.
static func run(h: SceneTree) -> void:
	var engine := Run.new()
	for source: String in ["scavenger", "campfire"]:
		var state: Dictionary = Fixture.shop_fixture(engine)
		if source == "campfire": state["mode"] = "campfire"
		h.clock.observing = false
		h.scene.call("_load_run_state", state)
		h.scene.call("_close_dialogue")
		h.scene.set("_animation_lock", false)
		h.scene.set("_merchant_trade_animation_active", false)
		h.scene.call("_open_magic_purge", source)
		var modal: Control = h.scene.get("_magic_purge_overlay")
		if modal == null:
			h.failures.append("Sound-sync fixture could not open Purge: " + source)
			continue
		modal.call("select_card", "pale_spark")
		h._begin("input/magic_purge/" + source)
		h._invoke("_confirm_magic_purge", ["pale_spark", source])
		var exhausts: Array = h.events.filter(func(event: Dictionary) -> bool: return event["cue"] == "card.exhaust" and event["result"] == "played")
		if exhausts.size() != 1 or (h.scene.get("_run_state") as Dictionary).get("attuned_magic_cards", []).count("pale_spark") != 1:
			h.failures.append("Saved Purge must remove one copy and play Exhaust once: " + source)
		h._finish(h._state())
