extends SceneTree
const Store = preload("res://scripts/progression_store.gd")
const Dialogue = preload("res://scripts/dialogue_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
var failed: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_storage_path("user://awakening_profile.json")
	var profile: Dictionary = Store.default_data()
	var dialogue := Dialogue.new()
	var engine := Run.new()
	var room := {"coord":Vector2i.ZERO,"npcs":[{"id":"emaciated_man"}]}
	expect(not Store.emaciated_awakening_is_due(profile) and not Store.emaciated_services_unlocked(profile), "New profiles have no premature dragon service")
	var entrance: Dictionary = engine.create_new_run(7241, profile)
	expect(engine.can_speak_to_emaciated_man(entrance) and not engine.can_use_emaciated_services(entrance), "Speak is available before awakening")
	var narrative: Dictionary = dialogue.build_room_dialogue(room, entrance, profile)
	expect(narrative["lines"].size() == 3 and not _has_service(narrative), "Ordinary Speak is narrative only")
	profile = Store.add_moltshard_for_award(profile, "first-dragon:first_boss_moltshard")
	profile["moltshards"] = 0
	expect(Store.emaciated_awakening_is_due(profile), "Spent Shard still unlocks introduction through the durable dragon receipt")
	narrative = dialogue.build_room_dialogue(room, entrance, profile)
	expect(bool(narrative.get("marks_emaciated_awakening_seen", false)) and not _has_service(narrative), "First dragon produces ordinary awakening dialogue without offers")
	var unlocked: Dictionary = Store.mark_emaciated_awakening_seen(profile)
	expect(Store.emaciated_services_unlocked(unlocked) and not Store.emaciated_awakening_is_due(unlocked), "Acknowledgment permanently unlocks separate service")
	expect(Store.mark_emaciated_awakening_seen(unlocked) == unlocked, "Repeated acknowledgment is idempotent")
	expect(int(unlocked["progression_revision"]) == int(profile["progression_revision"]) + 1, "Unlock advances progression revision for profile/run recovery")
	expect(Store.save_data(unlocked) and Store.emaciated_services_unlocked(Store.load_data()), "Unlock survives profile reload")
	entrance = engine.reconcile_progression_revision(entrance, unlocked)
	expect(engine.can_use_emaciated_services(entrance), "Profile-first unlock repairs interrupted run save")
	narrative = dialogue.build_room_dialogue(room, entrance, unlocked)
	expect(not _has_service(narrative) and not bool(narrative.get("marks_emaciated_awakening_seen", false)), "Repeat Speak never appends services")
	profile = Store.default_data()
	profile["run_bests"] = {"bosses_defeated":1}
	expect(Store.emaciated_awakening_is_due(profile), "Legacy boss records receive introduction")
	profile = Store.default_data()
	profile["moltshards"] = 1
	expect(Store.emaciated_awakening_is_due(profile), "Legacy Shard holders receive introduction")
	var offer: Dictionary = dialogue.emaciated_service_dialogue(unlocked)
	expect(bool(offer["lines"][0]["options"][0]["disabled"]) and not bool(offer["lines"][0]["options"][2].get("disabled",false)), "Separate service exposes empty-wallet restriction and usable Leave")
	print("Dragon reward feedback logic: ", "PASS" if failed == 0 else "FAIL")
	quit(1 if failed else 0)
func _has_service(dialogue: Dictionary) -> bool:
	for line: Dictionary in dialogue.get("lines", []):
		if bool(line.get("service",false)) or not (line.get("options",[]) as Array).is_empty(): return true
	return false
func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
