extends RefCounted
## Single-use graph preparation owned by the loading cover or booting run.

const Assets = preload("res://scripts/asset_loader.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const SEED_MASK: int = 0x7fffffff
const SEED_OVERRIDE := &"labyrinth_performance_probe_seed"
static var _hitch_trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"

# Only the last automatic seed is needed to keep successive presses distinct,
# including within the same second or after a wall-clock adjustment.
static var _last_automatic_seed: int = -1
static var _last_installed_seed: Variant

class Preparation extends RefCounted:
	var seed: int
	var depth: int
	var graph: Dictionary
	var pending: bool = true
	var cancellation := Assets.PreparationCancellation.new()

	func matches(requested_seed: int, requested_depth: int) -> bool:
		return not cancellation.is_cancelled() and seed == requested_seed and depth == requested_depth

	func cancel() -> void:
		cancellation.cancel()

static func explicit_seed(root: Window) -> Variant:
	return root.get_meta(SEED_OVERRIDE) if root.has_meta(SEED_OVERRIDE) else null

static func sample_automatic_seed(previous_seed: Variant = null) -> int:
	var sampled: int = int(Time.get_unix_time_from_system()) & SEED_MASK
	var seed: int = maxi(sampled, _last_automatic_seed + 1) & SEED_MASK
	while seed == previous_seed or seed == _last_installed_seed:
		seed = (seed + 1) & SEED_MASK
	_last_automatic_seed = seed
	return seed

static func remember_installed_seed(seed: int) -> void:
	_last_installed_seed = seed

static func resolve_seed(root: Window, automatic_seed: int) -> int:
	var explicit: Variant = explicit_seed(root)
	return int(explicit) if explicit != null else automatic_seed

static func start_for(root: Window, seed: int, depth: int, present: Callable) -> Preparation:
	var job := Preparation.new()
	job.seed = seed
	job.depth = depth
	_prepare.call_deferred(root, job, present)
	return job

static func _prepare(root: Window, job: Preparation, present: Callable) -> void:
	if not is_instance_valid(root) or job.cancellation.is_cancelled(): return
	var _hitch_span: RefCounted
	if _hitch_trace_enabled:
		_hitch_span = root.get_node("PerformanceTelemetry").hitch_phase("startup:run_initial_preparation:start_graph")
	var inputs: Dictionary = Graph.generation_inputs(job.depth)
	_hitch_span = null
	var cancelled: Callable = job.cancellation.is_cancelled
	var active: Callable = _active.bind(job)
	var value: Variant = await Assets.prepare_cpu_value_for(
		root, _generate.bind(job.seed, inputs, cancelled), present, active, job.cancellation, &"InitialRunGraphDrain"
	)
	if job.cancellation.is_cancelled(): return
	if value is Dictionary: job.graph = value
	job.pending = false

static func _active(job: Preparation) -> bool:
	return not job.cancellation.is_cancelled()

static func _generate(seed: int, inputs: Dictionary, cancelled: Callable) -> Dictionary:
	var graph: Dictionary = {"seed": seed}
	if not Graph.initialize_prepared(graph, inputs, cancelled): return {}
	graph.erase("seed")
	return graph
