extends SceneTree
## Resolve a saved audit decision on copies, with per-action widened-harm receipts.
## --save-dir <repro> [--tile x,y]. Reuses production committed transitions.
const Observer = preload("res://tools/atk13/observed_engine.gd")
const Production = preload("res://scripts/hero_facing_combat.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")

func _arg(name: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _resolve(engine: RefCounted, basis: Dictionary) -> Dictionary:
	var state: Dictionary = basis.duplicate(true)
	var tile: String = _arg("--tile")
	if not tile.is_empty():
		state = engine.apply_player_movement(state, Vector2i(int(tile.get_slice(",", 0)), int(tile.get_slice(",", 1))))
		Committed.accept(engine, state)
		if not bool(state.get("last_player_movement", {}).get("resolved", false)):
			push_error("Requested destination did not resolve")
			quit(1)
	return Committed.advance_to_player(engine, Committed.finish_player_activation(engine, state))["state"]

func _run() -> void:
	var value: Variant = str_to_var(FileAccess.get_file_as_string(_arg("--save-dir").path_join("combat_state.txt")))
	if not value is Dictionary:
		push_error("Missing saved combat snapshot")
		quit(1)
		return
	var observer := Observer.new()
	observer.observing = true
	var result: Dictionary = _resolve(observer, value)
	observer.observing = false
	var reference: Dictionary = _resolve(Production.new(), value)
	var same: bool = result == reference
	print("ATK13 REPLAY RECEIPTS " + JSON.stringify(observer.receipts))
	print("ATK13 REPLAY: %s turn=%d hero=%s destination=%s" % ["PASS" if same else "FAIL", int(value.get("turn", 0)), str(value["player"]["pos"]), _arg("--tile")])
	if not same: push_error("Observer changed production replay")
	quit(0 if same else 1)
