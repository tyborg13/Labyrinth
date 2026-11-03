extends RefCounted

# Probe-only sink. Keep interval partitioning, snapshots and JSON outside samples.
static var enabled: bool = false
static var frames: Dictionary = {}
static var events: Dictionary = {}
static var marks: Dictionary = {}

static func mark(kind: String) -> void:
	if not enabled: return
	var frame: int = Engine.get_process_frames()
	if not marks.has(frame): marks[frame] = {}
	marks[frame][kind] = Time.get_ticks_usec()

static func record(phase: String, started: int, ended: int, priority: int = 10) -> void:
	if not enabled or ended <= started: return
	var frame: int = Engine.get_process_frames()
	if not frames.has(frame): frames[frame] = []
	frames[frame].append({"phase": phase, "start_usec": started, "end_usec": ended, "priority": priority})

static func event(kind: String) -> void:
	if not enabled: return
	var frame: int = Engine.get_process_frames()
	if not events.has(frame): events[frame] = {}
	events[frame][kind] = int(events[frame].get(kind, 0)) + 1

static func reset() -> void:
	frames.clear()
	events.clear()
	marks.clear()
