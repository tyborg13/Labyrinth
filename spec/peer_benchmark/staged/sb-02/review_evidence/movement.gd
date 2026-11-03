extends SceneTree
const Board = preload("res://scripts/combat_board_view.gd")
const TF = preload("res://tests/suites/threats_at_rest_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
func _initialize() -> void:
 preload("res://scripts/parallel_runtime.gd").apply_from_environment()
 call_deferred("_run")
func _run() -> void:
 root.size=Vector2i(1920,1080)
 var board := Board.new()
 board.size=Vector2(1920,1080)
 root.add_child(board)
 await process_frame
 var state: Dictionary=TF.staged_state(Combat.new())
 var enemies: Array[Dictionary]
 for y: int in range(3):
  for x: int in range(4):
   if Vector2i(x+2,y+2)==Vector2i(4,4):continue
   enemies.append({"id":1+x+y*4,"type":"crawler","pos":Vector2i(x+2,y+2),"hp":24,"max_hp":30,"block":8,"stoneskin":3,"immobilize":true,"bleed":3,"expose":2,"frost_armor":3,"intent":Data.enemy_def("crawler")["intents"][0]})
 state["enemies"]=enemies
 var p: Dictionary={"reduced_motion":true}
 board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},p)
 var units: Array[Dictionary]=board._hud_layout_units()
 var center: Vector2=board._unit_center(units[1])
 var samples: Array[int]
 var builds: Array[int]
 board.set_submission_performance_instrumentation_enabled(true)
 for i: int in range(120):
  var positions: Dictionary={"enemy_1":center+Vector2(float(i)*0.123,0)}
  var pres: Dictionary={"reduced_motion":true,"unit_world_positions":positions}
  var t: int=Time.get_ticks_usec()
  board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},pres)
  var cost: int=Time.get_ticks_usec()-t
  if i>=20: samples.append(cost)
 samples.sort()
 print("MOVE_CPU ",JSON.stringify({"n":samples.size(),"p50_us":samples[50],"p95_us":samples[95],"max_us":samples.back(),"phases":board.submission_performance_instrumentation_snapshot()}))
 board.queue_free()
 await process_frame
 quit()
