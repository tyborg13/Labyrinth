extends SceneTree
const Metrics = preload("res://tools/fight_soak_metrics.gd")
func _initialize() -> void:
	var stable: Array[Dictionary]
	for round_index: int in range(20):
		stable.append({"round": round_index + 1, "nodes": 3000 + round_index % 2 * 5, "objects": 10000 + round_index % 2 * 10, "orphans": 0})
	assert(Metrics.plateau_errors(stable).is_empty(), "Finite presentation variation is allowed")
	var leaking: Array[Dictionary] = stable.duplicate(true)
	for row: Dictionary in leaking: row["nodes"] += int(row["round"]) * 10
	assert(not Metrics.plateau_errors(leaking).is_empty(), "A growing late floor fails even within the range bound")
	leaking = stable.duplicate(true)
	leaking[4]["orphans"] = 3
	assert(not Metrics.plateau_errors(leaking).is_empty(), "Every round enforces the orphan bound")
	assert(not Metrics.plateau_errors(stable.slice(1)).is_empty(), "A short soak cannot pass")
	var replay: Array[Dictionary]
	for index: int in range(21):
		replay.append({"round": index + 1, "turn": index % 7 + 1, "nodes": 3000 + index % 7 * 150, "objects": 10000 + index % 7 * 200, "orphans": 0})
	assert(Metrics.replay_plateau_errors(replay).is_empty(), "Periodic hand shapes plateau at matching fixture turns")
	for row: Dictionary in replay: row["nodes"] += int(row["round"]) * 10
	assert(not Metrics.replay_plateau_errors(replay).is_empty(), "Matching-turn growth cannot hide inside a wide periodic envelope")
	print("FIGHT SOAK METRICS: PASS (plateau, growth, orphan and duration guards)")
	quit()
