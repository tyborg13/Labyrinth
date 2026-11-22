extends SceneTree
## Seeded, headless audit. Writes evidence only to an explicit output directory.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const EngineFixture = preload("res://tools/qa122/audit_engine.gd")
const Fx = preload("res://tools/qa122/fixture.gd")
const Cards = preload("res://tools/qa122/cards.gd")
const Enemies = preload("res://tools/qa122/enemies.gd")
const Rewards = preload("res://tools/qa122/rewards.gd")
const Battlefields = preload("res://tools/qa122/battlefields.gd")
const Status = preload("res://tools/qa122/status.gd")

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage: audit.gd -- ABSOLUTE_OUTPUT_DIRECTORY cards|enemies|events|omens|relics|battlefields|status|all [catalog id]")
		quit(2)
		return
	var output: String = args[0]
	var family: String = args[1]
	var filter: String = args[2] if args.size() > 2 else ""
	var families: Array = ["cards", "enemies", "events", "omens", "relics", "battlefields", "status"]
	if not output.is_absolute_path() or (family != "all" and not families.has(family)):
		printerr("QA122 requires an absolute output directory and a known family.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("QA122 could not create " + output)
		quit(2)
		return
	var engine := EngineFixture.new()
	for key: String in families:
		if family not in ["all", key]: continue
		var rows: Array = []
		match key:
			"cards": rows = Cards.catalog(engine, filter)
			"enemies": rows = Enemies.catalog(engine, filter)
			"events": rows = Rewards.events(filter)
			"omens": rows = Rewards.omen_catalog(engine, filter)
			"relics": rows = Rewards.relics(engine, filter)
			"battlefields": rows = Battlefields.catalog(engine, filter)
			"status": rows = Status.catalog(engine, filter)
		if not _write(output, key, rows):
			quit(1)
			return
	quit()

func _write(output: String, key: String, rows: Array) -> bool:
	var path: String = output.path_join(key + ".jsonl")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null or rows.is_empty():
		printerr("QA122 missing evidence for " + path)
		return false
	for row: Dictionary in rows:
		file.store_line(JSON.stringify(Fx.json_safe(row)))
	var ok: bool = file.get_error() == OK
	file.close()
	if ok: print("QA122 %s: %d receipts -> %s" % [key, rows.size(), path])
	return ok
