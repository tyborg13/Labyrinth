extends "res://tools/qa102/hud_replay.gd"
## Assert the production HUD rows against the resolved phase of QA-101 saves.

const REPRO_ROOM: String = "Quiet Hall"
const REPRO_TURN: int = 2
const REPRO_WALK := Vector2i(1, 6)
const REPRO_LOSSES: Dictionary = {"pass": 15, "move": 13}

func _sample_decision(entry: Dictionary, output: String, native: bool) -> Array[Dictionary]:
	var receipts: Array[Dictionary] = await super._sample_decision(entry, output, native)
	if entry["kind"] != "campaign": _check(not receipts.is_empty(), "restored checkpoint: " + str(entry["save"]))
	if receipts.is_empty(): return receipts
	var source: Dictionary = _read_source(entry)
	var roster: Dictionary = {}
	for enemy: Dictionary in source["combat_state"]["enemies"]:
		roster["enemy_%d" % int(enemy["id"])] = true
	for receipt: Dictionary in receipts:
		var arrivals: Dictionary = {}
		for activation: Dictionary in receipt["actual"]["activations"]:
			var actor: String = str(activation["actor"])
			if actor.begins_with("enemy_") and not roster.has(actor): arrivals[actor] = true
		var has_clock: bool = false
		var health_row: String = ""
		for row: Array in receipt["pass_rows"]:
			for part: Dictionary in row:
				if part["icon"] == "turn_clock" and part["text"] == "?": has_clock = true
				if part["icon"] == "health": health_row = part["text"]
		var kind: String = receipt["kind"]
		var repro: bool = bool(entry.get("repro", false))
		var expected_clock: bool = not arrivals.is_empty() and _arg("--expect-arrival") == "yes"
		var label: String = "seed=%d %s" % [int(source["seed"]), kind]
		if repro:
			_check(receipt["room"] == REPRO_ROOM and int(receipt["turn"]) == REPRO_TURN, label + ": Quiet Hall turn 2")
			_check(roster.size() == 3 and arrivals.size() == 1, label + ": one arrival acts after a three-foe board")
			_check(receipt["pass_active"], label + ": forecast panel is active")
			_check(kind != "move" or receipt["resolved_destination"] == REPRO_WALK, label + ": Walk resolves at (1, 6)")
			_check(health_row == "−%d" % REPRO_LOSSES[kind], label + ": displayed Health loss " + health_row)
		if _arg("--expect-arrival") != "observe":
			_check(has_clock == expected_clock, label + ": turn-clock '?'")
			_check(bool(receipt["summary"].get("new_arrival_before_player", false)) == expected_clock, label + ": arrival summary flag")
		print("QA102 HUD %s room=%s turn=%d health=%s turn_clock=%s present=%s arrivals=%s" % [
			label, receipt["room"], receipt["turn"], health_row, has_clock, roster.keys(), arrivals.keys(),
		])
	return receipts
