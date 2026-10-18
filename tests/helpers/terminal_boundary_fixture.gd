extends RefCounted

const Rules = preload("res://scripts/opening_boon_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const LEAVE_NOTHING: String = ""

static func finish_prompt(scene: Node, expect: Callable) -> void:
	var state: Dictionary = scene.call("_committed_run_state")
	if not Rules.heirloom_prompt_pending(state): return
	expect.call(Store.has_saved_run(), "A terminal heirloom prompt remains resumable until an explicit choice")
	var saved: Dictionary = Store.load_saved_run()
	expect.call(saved.get("mode", "") == state.get("mode", "") and Rules.heirloom_prompt_pending(saved) and Run.run_result_id(saved) == Run.run_result_id(state), "The prompt saves the terminal checkpoint rather than an older resumable combat")
	var chosen: Dictionary = Rules.leave_heirloom(state, LEAVE_NOTHING)
	expect.call(not Rules.heirloom_prompt_pending(chosen), "Leave nothing completes the terminal heirloom choice")
	var result: Dictionary = scene.call("_persist_run_state_snapshot", chosen, false, "heirloom_left")
	expect.call(bool(result.get("saved", false)), "The terminal heirloom choice commits before clearing the run")
	scene.set("_run_state", result.get("state", chosen))
