extends RefCounted
## Test-only observation of real playback calls and claim transactions.
const Sources = preload("res://tests/sfx_sync_sources.gd")
static var source_overrides: Dictionary = {}

static func host() -> Node:
	var source: String = Sources.read_source("scripts/run_scene.gd", source_overrides)
	source = source.replace("_music_player.play()", "_section_test_music_starts += 1; _music_player.play()")
	source = source.replace("func _commit_dragon_reward_continue() -> bool:", "func _commit_dragon_reward_continue() -> bool:\n\t_section_test_claim_calls += 1")
	source = source.replace("func _persist_run_state_snapshot(run_state: Dictionary, hold_for_animation: bool, boundary: String) -> Dictionary:", "func _persist_run_state_snapshot(run_state: Dictionary, hold_for_animation: bool, boundary: String) -> Dictionary:\n\tif boundary == \"section_transition\": _section_test_entry_saves += 1")
	source += "\nvar _section_test_music_starts: int = 0\nvar _section_test_claim_calls: int = 0\nvar _section_test_entry_saves: int = 0\n"
	var script: GDScript = Sources.compile_script("scripts/run_scene.gd", source)
	assert(script != null, "Section-transition observer must compile")
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get("_combat_pacing").free()
	scene.set_script(script)
	return scene
