extends "res://tools/run_hunt.gd"
## QA-only in-memory bank observer. Production scripts and assets stay on disk.
const Sources = preload("res://tests/sfx_sync_sources.gd")
const Tap = preload("res://tools/qa111/tap.gd")

var instrumented_scene: GDScript
var instrumented_bank: GDScript
var tap := Tap.new()

func _enter_scene(resume: bool) -> void:
	if instrumented_scene == null:
		var source: String = Sources.read_source("scripts/run_scene.gd", {})
		source = _hook(source, 'const SfxBankScript = preload("res://scripts/sfx_bank.gd")', 'var SfxBankScript: Script')
		source = _hook(source, '_sfx_bank.name = "SfxBank"', '_sfx_bank.name = "SfxBank"; _sfx_bank.set_meta("qa111_tap", get_meta("qa111_tap"))')
		instrumented_scene = Sources.compile_script("scripts/run_scene.gd", source)
		source = Sources.read_source("scripts/sfx_bank.gd", {})
		source = _hook(source, 'cue_id = Attacks.CUE_ALIASES.get', 'opts = opts.duplicate(); opts["qa111_id"] = get_meta("qa111_tap").requested(self, cue_id, get_stack()); cue_id = Attacks.CUE_ALIASES.get')
		source = _hook(source, 'cue_requested.emit(cue_id, result)', 'get_meta("qa111_tap").resolved(self, cue_id, result, opts); cue_requested.emit(cue_id, result)')
		source = _hook(source, 'player.stop()\n\tplayer.stream = resource', 'get_meta("qa111_tap").stop_voice(player); player.stop()\n\tplayer.stream = resource')
		source = _hook(source, 'active_loop_id = ""\n\tfor index:', 'get_meta("qa111_tap").fade_loop(self); active_loop_id = ""\n\tfor index:')
		instrumented_bank = Sources.compile_script("scripts/sfx_bank.gd", source)
		tap.file = FileAccess.open(output.path_join("sfx.jsonl"), FileAccess.WRITE)
	if instrumented_scene == null or instrumented_bank == null or tap.file == null:
		push_error("qa-111: could not start the SFX tap")
		finished = true
		quit(1)
		return
	if resume: root.set_meta("labyrinth_resume_saved_run", true)
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	scene.get("_combat_pacing").free()
	scene.set_script(instrumented_scene)
	scene.set("SfxBankScript", instrumented_bank)
	scene.set_meta("qa111_tap", tap)
	tap.scene = scene
	root.add_child(scene)
	current_scene = scene
	settle_frames = SETTLE_FRAMES

func _hook(source: String, needle: String, replacement: String) -> String:
	assert(source.count(needle) == 1, "qa-111: SFX tap hook drifted: " + needle)
	return source.replace(needle, replacement)

func _record(action: Dictionary) -> void:
	super._record(action)
	tap.decision = decision

func _finish(outcome: String) -> void:
	tap.file.flush()
	await super._finish(outcome)
