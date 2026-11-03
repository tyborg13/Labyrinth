extends Node
## Drive only registered production tweens, preserving their real tracks,
## parallelism, delays, callbacks and coroutine completion boundaries.
const STEP_SECONDS: float = 0.01
static var active_driver: Node
var observed: Array[Tween]
var completed_seconds: float = 0.0
var _previous_driver: Node

func _ready() -> void:
	_previous_driver = active_driver
	active_driver = self

static func track(tween: Tween) -> void:
	assert(is_instance_valid(active_driver), "Install the test tween clock first")
	active_driver.observed.append(tween)
	tween.pause()

static func sequence_script(original: Script) -> GDScript:
	var script := GDScript.new()
	var source: String = preload("res://tests/helpers/presentation_test_clock.gd").source_for(original).replace("class_name PostCombatRewardSequence", "")
	var lines := source.split("\n")
	for index: int in range(lines.size()):
		if "var " in lines[index] and ": Tween = " in lines[index]:
			var variable: String = lines[index].strip_edges().split(":")[0].trim_prefix("var ")
			# pol-15 (8169b3dbb) also creates tweens inside the HUD loop.
			var indentation: String = lines[index].left(lines[index].find("var "))
			lines[index] += '\n' + indentation + 'preload("res://tests/helpers/presentation_tween_driver.gd").track(' + variable + ')'
	script.source_code = "\n".join(lines).replace("overlay.get_tree().create_timer(", 'preload("res://tests/helpers/presentation_test_clock.gd").timer(overlay.get_tree(), ')
	assert(script.reload() == OK, "Observed production sequence compiles")
	return script

func _process(_delta: float) -> void:
	# A finished callback may resume its caller inside custom_step. Publish the
	# supplied delta first so that caller includes the terminal tick.
	for tween: Tween in observed.duplicate():
		if not tween.is_valid(): continue
		completed_seconds += STEP_SECONDS
		if not tween.custom_step(STEP_SECONDS): tween.kill()

func _exit_tree() -> void:
	if active_driver == self:
		active_driver = _previous_driver if is_instance_valid(_previous_driver) else null
