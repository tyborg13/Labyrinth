extends "res://tools/board_surface_playtest.gd"

## Single-encounter regression using the maintained legal-card/walk policy.
## Every committed action and event passes through the ordinary manual harness.
const GuardianInspection = preload("res://tools/guardian_inspection.gd")
var guardian_id: String = "ashen_reaver"
var approach: String = "clear_helpers"
var test_section: int = -1

func _start_new_run(seed: int) -> void:
	super._start_new_run(seed)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()-1):
		match args[index]:
			"--guardian-id": guardian_id=args[index+1]
			"--approach": approach=args[index+1]
			"--section": test_section=int(args[index+1])
	assert(approach in ["clear_helpers","focus_guardian","control"])
	if test_section>=0:
		for room: Dictionary in _run_state["rooms"].values():
			if str(room.get("guardian_id",""))==guardian_id:
				room["depth"]=test_section*4+2
				room["section_index"]=test_section
				room["umbra_section_index"]=test_section
	_run_state = GuardianInspection.build(_run_engine,_combat_engine,_run_state,{"guardian_id":guardian_id,"guardian_case":"encounter","attuned_magic":"controlled"})
	_sync_combat_state_from_run()
	_attach_new_combat_analytics({},"guardian_inspection")
	_append_note("Guardian %s; approach %s; section %d. Setup uses normal health and scaling, six %s spells and iron-cleaver/ward-kite equipment. The policy has no future knowledge of shuffled cards.\n" % [guardian_id,approach,test_section,build])

func _value(state: Dictionary) -> float:
	var result: float = super._value(state)
	for enemy: Dictionary in state.get("enemies",[]):
		if int(enemy.get("hp",0))<=0: continue
		if approach=="focus_guardian" and str(enemy["type"])==guardian_id: result-=float(enemy["hp"])*.55
		if approach=="control": result+=minf(2,float(enemy.get("freeze",0)))*2.0+minf(2,float(enemy.get("shock",0)))
	return result

func _repl() -> void:
	while decisions<250 and rounds<30 and str(_run_state.get("mode",""))=="combat" and end_reason.is_empty():
		decisions+=1
		_fight()
		_save_session()
	if end_reason.is_empty(): end_reason="guardian_victory" if str(_run_state.get("mode",""))=="treasure" else str(_run_state.get("mode","")) if str(_run_state.get("mode",""))!="combat" else "bounded_stalemate"
	var summary: Dictionary = {"guardian_id":guardian_id,"seed":_run_state.get("seed",0),"build":build,"approach":approach,"section":test_section,"endpoint":end_reason,"decisions":decisions,"activations":rounds,"hp":_run_state.get("player_hp",0),"cards_played":played,"surface_events":counters,"policy":"board_surface_playtest v1 with declared target preference; no optimality or win-rate claim"}
	var file := FileAccess.open(str(_options["output_dir"]).path_join("policy_summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t"))
	_append_note("Endpoint: %s\n" % JSON.stringify(summary))
	print("GUARDIAN POLICY: ",JSON.stringify(summary))
	_print_analytics_summary()
