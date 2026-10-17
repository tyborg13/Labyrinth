extends "res://tests/encounter_tables_test.gd"

## Shared developer-only result transport for the partitioned placement sweep.
## The scheduler supplies a fresh report directory shared only by this full run.
const REPORT_ARGUMENT: String = "--placement-report-directory="
const REPORT_POLL_SECONDS: float = 0.05
const SEED_PARTS: int = 2
var _callback_count: int = 0

func _expect(ok: bool, message: String) -> void:
	_callback_count += 1
	super._expect(ok, message)

func _finish(label: String) -> void:
	print("ENCOUNTER ASSERTIONS: %d" % _callback_count)
	super._finish(label)

func _report_directory() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(REPORT_ARGUMENT):
			return argument.trim_prefix(REPORT_ARGUMENT)
	push_error("Missing placement report directory")
	quit(1)
	return ""

func _run_seed_part(index: int) -> void:
	var directory: String = _report_directory()
	if directory.is_empty(): return
	var span: int = Suite.PLACEMENT_SEEDS / SEED_PARTS
	var statistics: Dictionary = Suite.placement_seed_range(_expect, index * span, (index + 1) * span)
	var path: String = directory.path_join("encounter-placement-%d.json" % index)
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write placement statistics: " + path)
		quit(1)
		return
	file.store_string(JSON.stringify(statistics))
	file.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		push_error("Cannot publish placement statistics: " + path)
		quit(1)
		return
	_finish("Encounter placement part %d" % index)

func _finish_seed_parts() -> void:
	var directory: String = _report_directory()
	if directory.is_empty(): return
	var total: Dictionary = {"generated": 0, "skipped": 0, "largest": 0}
	for index: int in range(SEED_PARTS):
		var path: String = directory.path_join("encounter-placement-%d.json" % index)
		# The unchanged 180-second child cap bounds a missing/failed producer.
		while not FileAccess.file_exists(path):
			await create_timer(REPORT_POLL_SECONDS).timeout
		var statistics: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not statistics is Dictionary:
			push_error("Invalid placement statistics: " + path)
			quit(1)
			return
		total["generated"] += int(statistics["generated"])
		total["skipped"] += int(statistics["skipped"])
		total["largest"] = maxi(int(total["largest"]), int(statistics["largest"]))
	Suite._finish_placement(_expect, total)
	_finish("Encounter placement aggregate")
