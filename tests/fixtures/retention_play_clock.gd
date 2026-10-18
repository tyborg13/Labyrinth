extends "res://scripts/run_score_rules.gd"

# Retention compares entire authoritative dictionaries, including run_seconds.
# Keep the real sampling/commit implementation but freeze its external clock:
# opening an unread tab persists at separate wall times in the two scenes.
const RETENTION_CLOCK_USEC: int = 1000000

func sample_play_time(state: Dictionary, active: bool, _now_usec: int = RETENTION_CLOCK_USEC) -> void:
	super.sample_play_time(state, active, RETENTION_CLOCK_USEC)
