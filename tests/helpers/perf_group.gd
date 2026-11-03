extends RefCounted

## Speed guards are opt-in; deterministic clocks and functional checks stay on.
static func enabled() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	return args.has("--perf-checks") or args.has("--perf")
