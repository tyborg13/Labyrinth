extends SceneTree

const OWN_SOURCES = [
	"res://assets/units/storm_capacitor_cutout/front/rest.png",
	"res://assets/units/storm_capacitor_cutout/rear/rest.png",
]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.has("--baseline") or args.find("--baseline") + 1 >= args.size():
		push_error("Use -- --baseline PATH (unit_shadow_cache.res containing both Capacitor records)")
		quit(1)
		return
	var baseline: Resource = load(args[args.find("--baseline") + 1])
	if baseline == null:
		push_error("Cannot load requested shadow baseline")
		quit(1)
		return
	var current: Resource = load("res://assets/generated/unit_shadow_cache.res")
	var errors: Array[String]
	# Other units legitimately refresh their shadows after rr-17. Require the
	# Capacitor's two records explicitly, so an older baseline cannot pass empty.
	for path: String in OWN_SOURCES:
		if not baseline.entries.has(path) or not baseline.source_sha256.has(path):
			errors.append("Missing Capacitor shadow baseline: " + path)
			continue
		if current.entries.get(path) != baseline.entries[path]:
			errors.append("Capacitor shadow changed: " + path)
		if current.source_sha256.get(path) != baseline.source_sha256[path]:
			errors.append("Capacitor shadow source changed: " + path)
	for error: String in errors: push_error(error)
	print("RR17 SHADOW PRESERVATION: %s (%d Capacitor records unchanged)" % ["PASS" if errors.is_empty() else "FAIL", OWN_SOURCES.size()])
	quit(0 if errors.is_empty() else 1)
