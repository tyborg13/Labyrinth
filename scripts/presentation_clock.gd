extends RefCounted
## Movie-only frame time. Live callers retain their original wall-clock reads.

const DEFAULT_MOVIE_FPS: int = 60
const MOVIE_TICK_PROCESS_PRIORITY: int = -1000
# Movie capture arguments/configuration are immutable for this process. Read
# them at startup; neither a mutable time scale nor startup jitter defines FPS.
static var _movie_fps: int = _read_movie_fps() if not Engine.get_write_movie_path().is_empty() else 0
static var _frame: int = -1
static var _scaled_usec: float = 1.0
static var _unscaled_usec: float = 1.0
static var _ticker: Node
var _last_frame: int = -1

static func release_shutdown_callables() -> void:
	if is_instance_valid(_ticker):
		_ticker.set_process(false)
		_ticker.set("sync", Callable())
	_ticker = null

class MovieTicker:
	extends Node
	var sync: Callable
	func _process(_delta: float) -> void:
		sync.call()

func advance(frame: int, unscaled_delta: float, scale: float, paused: bool = false) -> float:
	if frame == _last_frame: return 0.0
	var initialized: bool = _last_frame >= 0
	_last_frame = frame
	return unscaled_delta * scale * 1000000.0 if initialized and not paused else 0.0

static func ticks_usec(scaled: bool = true) -> int:
	if Engine.get_write_movie_path().is_empty(): return Time.get_ticks_usec()
	_sync_movie_frame()
	return int(_scaled_usec if scaled else _unscaled_usec)

static func ticks_msec(scaled: bool = true) -> int:
	if Engine.get_write_movie_path().is_empty(): return Time.get_ticks_msec()
	return ticks_usec(scaled) / 1000

static func _fixed_fps_in(arguments: PackedStringArray) -> int:
	var fps: int = 0
	for index: int in range(arguments.size() - 1):
		if arguments[index] == "--fixed-fps": fps = arguments[index + 1].to_int()
	return fps

static func _read_movie_fps() -> int:
	var fps: int = _fixed_fps_in(OS.get_cmdline_args())
	# Some engine builds consume the engine option before exposing arguments.
	if fps <= 0: fps = _fixed_fps_in(OS.get_cmdline_user_args())
	if fps <= 0: fps = int(ProjectSettings.get_setting("editor/movie_writer/fps", DEFAULT_MOVIE_FPS))
	return maxi(1, fps)

static func _sync_movie_frame() -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _frame: return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null: return
	if _ticker == null:
		_ticker = MovieTicker.new()
		_ticker.name = "MoviePresentationClock"
		_ticker.process_mode = Node.PROCESS_MODE_ALWAYS
		_ticker.process_priority = MOVIE_TICK_PROCESS_PRIORITY
		_ticker.sync = _sync_movie_frame
		tree.root.add_child.call_deferred(_ticker)
	var delta: float = 1.0 / float(_movie_fps)
	var scale: float = Engine.time_scale
	if _frame >= 0:
		_scaled_usec += delta * scale * 1000000.0
		_unscaled_usec += delta * 1000000.0
	_frame = frame
