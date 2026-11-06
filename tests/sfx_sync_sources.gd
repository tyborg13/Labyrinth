extends RefCounted

# In-memory instrumentation only. No generated .gd/.uid files and no checkout
# switching: a baseline revision can run beside the current full test suite.
static var _compiled: Dictionary = {}

const SOURCE_PATHS: Array = ["scripts/card_empower_controller.gd", "tests/suites/empower_sfx_sync_cases.gd", "scripts/sfx_sync_rules.gd", "scripts/sfx_peak_alignment.gd", "scripts/run_scene.gd", "scripts/sfx_bank.gd", "scripts/sfx_cue_router.gd", "scripts/enemy_arrival_sfx.gd", "data/sfx_cues.json",
	"tests/sfx_sync_audio_lengths.gd", "tests/sfx_sync_harness.gd", "tests/sfx_sync_clock.gd", "tests/sfx_sync_pacing.gd", "tests/sfx_sync_sources.gd", "tests/sfx_sync_support.gd", "tests/sfx_sync_visuals.gd", "tests/sfx_sync_coverage.gd", "tests/suites/magic_deck_sfx_sync.gd",
	"tests/sfx_sync_cutout_contacts.gd", "tests/fixtures/cutout_contact_sfx_coverage.json", "scripts/maquette_cutout_runtime/contact_actions.gd", "scripts/maquette_cutout_runtime/action.gd",
	"scripts/ember_hearth_presentation.gd", "scripts/dragon_arrival.gd", "scripts/meteorfall_landing_view.gd"]

static func read_source(path: String, supplied: Dictionary) -> String:
	return str(supplied.get(path, FileAccess.get_file_as_string("res://" + path)))

static func compile_script(path: String, source: String) -> GDScript:
	var key: String = path + source.sha256_text()
	if _compiled.has(key): return _compiled[key]
	var script := GDScript.new()
	script.resource_path = "res://tests/sfx_sync_instrumented_" + path.get_file()
	# Keep the line in place, but do not register a second global class name.
	var lines: PackedStringArray = source.split("\n")
	for index: int in range(lines.size()):
		if lines[index].begins_with("class_name "): lines[index] = "# " + lines[index]
	script.source_code = "\n".join(lines)
	if script.reload() != OK: return null
	_compiled[key] = script
	return script

static func bank(supplied: Dictionary) -> GDScript:
	var source: String = read_source("scripts/sfx_bank.gd", supplied)
	source = source.replace("cue_id = Attacks.CUE_ALIASES.get", "opts = opts.duplicate(); opts[\"sync_stack\"] = get_stack(); cue_id = Attacks.CUE_ALIASES.get")
	source = source.replace("seed_value: int = -1", "seed_value: int = 410")
	source = source.replace('slot["due"] = now_ms() + delay_ms', 'slot["sync_stack"] = get_stack(); slot["due"] = now_ms() + delay_ms')
	source = source.replace("cue_requested.emit(", 'scheduled_stack = opts.get("sync_stack", []); cue_requested.emit(')
	if supplied.has("cue_data_path"):
		source = source.replace('"res://data/sfx_cues.json"', JSON.stringify(supplied["cue_data_path"]))
	source += "\nvar scheduled_stack: Array = []\n"
	return compile_script("scripts/sfx_bank.gd", source)

# External presentation helpers use the same injected providers as RunScene.
# Keep their action, sound and animation logic verbatim (pol-10 / pol-27).
static func presentation_helper(path: String, supplied: Dictionary) -> GDScript:
	var source: String = read_source(path, supplied)
	source = source.replace("func emphasize(_host: Node", "func emphasize(host: Node")
	source = source.replace("Time.get_ticks_msec()", 'int(host.get("_sfx_sync_clock").usec / 1000)')
	source = source.replace("host.get_tree().create_timer(", 'host.get("_sfx_sync_clock").create_timer(')
	source = source.replace("host.get_process_delta_time()", 'host.get("_sfx_sync_clock").frame_delta_seconds')
	return compile_script(path, source)

static func hashes(supplied: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCE_PATHS:
		result[path] = read_source(path, supplied).sha256_text()
	return result
