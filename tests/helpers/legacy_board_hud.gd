extends RefCounted
## Pins the "Board health bars: Always" setting for tests whose contracts
## describe the classic board HUD (health plates and free-placed intent chips at
## rest). The player default is "On hover and aim" (owner, 2026-11-12); that
## mode is proven by tools/rd07 and tools/rd08.
## Call it after ParallelRuntime.apply_from_environment(), so the settings file
## lands in the test's own user directory and scenes that reload settings keep it.

const SettingsStore = preload("res://scripts/settings_store.gd")

static func pin_always() -> void:
	var pinned: Dictionary = SettingsStore.default_settings()
	pinned["board_health_bars"] = SettingsStore.BOARD_HEALTH_ALWAYS
	SettingsStore.save_settings(pinned)
	SettingsStore.apply_settings(pinned, null, false)
