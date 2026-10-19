extends SceneTree
## Compile mutations in memory; never edit production source for this check.
const Regressions = preload("res://tests/suites/combat_pacing_regression_suite.gd")
const ActionPacing = preload("res://tests/suites/combat_action_pacing_suite.gd")
const ActionClocks = preload("res://tests/suites/combat_enemy_action_clock_suite.gd")
var _failures: Array[String]
var _caught: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var source: String = FileAccess.get_file_as_string("res://scripts/combat_pacing.gd").replace("class_name CombatPacing", "")
	var mutations: Array = [
		["restore_0.20_cap", "\n\treturn authored\n", "\n\treturn minf(authored,maxf(_initial_elapsed,0.20)) if enemies_active else authored\n", "Full authored feedback"],
		["drop_lead_in", "if not debug_baseline and activation_has_action(actor, activation_steps):", "if false:", "0.25 s lead"],
		["wait_on_move_only", "if not debug_baseline and activation_has_action(actor, activation_steps):", "if not debug_baseline:", "Move-only turn adds no lead"],
		["remove_heal_action", "\"heal\", ", "", "Ally support receives one caption lead"],
		["restore_action_scale_1.0", "ENEMY_ACTION_SPEED_SCALE: float = 0.80", "ENEMY_ACTION_SPEED_SCALE: float = 1.0", "Enemy action uses 0.80"],
		["slow_movement", "_scope == \"enemies\" and _enemy_action_active", "_scope == \"enemies\"", "Movement uses combat speed"],
		["stretch_lead", "if kind == \"intent\":", "if kind == \"intent\":\n\t\t_set_enemy_action_active(true)", "Caption lead uses combat speed"],
		["stretch_settle", "\n\t\t_set_enemy_action_active(false)\n", "\n\t\t_set_enemy_action_active(true)\n", "Settle uses combat speed"]
	]
	for mutation: Array in mutations:
		_caught.clear()
		var script := GDScript.new()
		if source.count(str(mutation[1])) != 1:
			_failures.append("Mutation anchor must occur exactly once: "+str(mutation[0]))
			continue
		script.source_code = source.replace(str(mutation[1]),str(mutation[2]))
		if script.reload() != OK:
			_failures.append("Mutation must compile: "+str(mutation[0]))
			continue
		if str(mutation[0]) == "restore_0.20_cap": Regressions._test_feedback_duration(Callable(self,"_expect_mutant"),script)
		elif str(mutation[0]) == "remove_heal_action": await ActionPacing.ally_support(self,Callable(self,"_expect_mutant"),script)
		elif str(mutation[0]) == "slow_movement": await preload("res://tests/suites/combat_enemy_action_clock_suite.gd").action_clocks(self,Callable(self,"_expect_mutant"),script)
		else: await Regressions._action_waits(self,Callable(self,"_expect_mutant"),script)
		var rejected: bool = false
		for message: String in _caught:
			if message.contains(str(mutation[3])): rejected = true
		if not rejected: _failures.append("Mutation survived its behavioral check: "+str(mutation[0]))
		print("COMBAT PACING MUTATION %s: %s (%d assertions)" % [mutation[0],"REJECTED" if rejected else "SURVIVED",_caught.size()])
	await _remove_path_movement_guards()
	for failure: String in _failures: push_error(failure)
	print("COMBAT PACING MUTATION TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _expect_mutant(condition: bool, message: String) -> void:
	if not condition: _caught.append(message)

func _remove_path_movement_guards() -> void:
	# Mutate the actual production method in memory, preserving all routing and
	# the semantic presentation observer. The aligned Dive never entered it.
	var source: String = FileAccess.get_file_as_string("res://scripts/run_scene.gd")
	var start: int = source.find("\nfunc _animate_actor_along_path(")
	var end: int = source.find("\nfunc ",start+1)
	if start < 0 or end < 0:
		_failures.append("Mutation cannot locate the production path animation method")
		return
	var method: String = source.substr(start,end-start)
	for anchor: String in ["\tvar resume_action: bool = _combat_pacing.begin_movement(actor_key)\n", "\t_combat_pacing.end_movement(resume_action)\n"]:
		if method.count(anchor) != 1:
			_failures.append("Path movement mutation anchor must occur exactly once: "+anchor)
			return
		method = method.replace(anchor,"")
	var script := GDScript.new()
	script.source_code = 'extends "res://tests/helpers/combat_action_clock_scene.gd"\n'+method
	if script.reload() != OK:
		_failures.append("Path movement guard mutation must compile")
		return
	_caught.clear()
	await ActionClocks.unaligned_dive(self,Callable(self,"_expect_mutant"),script)
	var rejected: bool = _caught.any(func(message: String) -> bool: return message.contains("Unaligned Dive approach uses combat speed"))
	if not rejected: _failures.append("Mutation survived its behavioral check: remove_path_movement_guards")
	print("COMBAT PACING MUTATION remove_path_movement_guards: %s (%d assertions)" % ["REJECTED" if rejected else "SURVIVED",_caught.size()])
