extends RefCounted

const STAMP_PATH: String = "res://build_info.tres"

static func label_text() -> String:
	if not ResourceLoader.exists(STAMP_PATH):
		return "DEV BUILD"
	var stamp: Resource = ResourceLoader.load(STAMP_PATH)
	if stamp == null:
		return "DEV BUILD"
	var prefix: String = "DEMO BUILD" if bool(stamp.get_meta("demo")) else "BUILD"
	return "%s %s · %s" % [prefix, stamp.get_meta("commit_date"), str(stamp.get_meta("commit_hash")).to_upper()]
