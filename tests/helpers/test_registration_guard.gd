extends RefCounted

static func run(expect: Callable) -> void:
	var tool: String = ProjectSettings.globalize_path("res://tools/test_registration_audit.py")
	var output: Array
	var code: int = OS.execute("python3", PackedStringArray([tool]), output, true)
	for chunk: String in output: print(chunk)
	expect.call(code == 0, "Every headless test must be registered or explicitly quarantined; see TEST REGISTRATION AUDIT")
