extends SceneTree
const Board = preload("res://scripts/combat_board_view.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Fixtures = preload("res://tests/suites/board_hud_group_suite.gd")
const TF = preload("res://tests/suites/threats_at_rest_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Warband = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
func _initialize() -> void:
 preload("res://scripts/parallel_runtime.gd").apply_from_environment()
 call_deferred("_run")
func _run() -> void:
 root.size = Vector2i(1920,1080)
 var board := Board.new()
 board.size = Vector2(1920,1080)
 root.add_child(board)
 await process_frame
 var engine := Run.new()
 for biome: String in ["air", "earth", "fire", "ice", "lightning", "shadow"]:
  var run: Dictionary = Warband.build(engine,Combat.new(),engine.create_new_run(83,Store.default_data()),{"warband_biome":biome,"warband_tier":2})
  Fixtures._decorate(run["combat_state"])
  _check(board,run["combat_state"],"warband_"+biome,true)
 var mixed: Dictionary = TF.staged_state(Combat.new())
 var enemies: Array[Dictionary]
 var roster: Array = ["crawler", "burrow_grub", "gale_herald", "gust_shrike", "storm_capacitor", "veilbound_acolyte", "glacial_mirror", "ember_tick"]
 var positions: Array = [Vector2i(3,3),Vector2i(4,3),Vector2i(5,3),Vector2i(3,4),Vector2i(5,4),Vector2i(3,5),Vector2i(4,5),Vector2i(5,5)]
 for i: int in range(roster.size()):
  var enemy: Dictionary = Fixtures._foe(roster[i],i+1,positions[i])
  enemy.merge({"burrowed":i==1,"charge":2,"veiled":i==5,"is_leader":i==0})
  enemies.append(enemy)
 mixed["enemies"] = enemies
 Fixtures._decorate(mixed)
 _check(board,mixed,"mixed",true)
 # Place a legal pair on the lower board rows with the same production statuses.
 for y: int in range(2,7):
  for x: int in range(2,7):
   if Vector2i(x,y)==Vector2i(4,4): continue
   var s: Dictionary = TF.staged_state(Combat.new())
   s["enemies"] = [Fixtures._foe("grave_surgeon",1,Vector2i(x,y))]
   Fixtures._decorate(s)
   _check(board,s,"pair_"+str(Vector2i(x,y)),false)
 board.queue_free()
 await process_frame
 quit()
func _check(board: Control,state: Dictionary,label: String,verbose: bool) -> void:
 var rest: Dictionary = Badges.build(Combat.new(),state,state)
 var presentation: Dictionary = {"threats_at_rest":rest,"reduced_motion":true}
 board.set_combat_state(state,[],[],Vector2i(-1,-1),"","",{},{},presentation)
 var viewport: Rect2 = board._enemy_hud_viewport_bounds()
 for unit: Dictionary in board._hud_layout_units():
  if unit.get("boss_bar",false): continue
  var anchor: Rect2 = board._unit_health_bar_rect(unit,board._unit_center(unit))
  var group: Dictionary = board._status_plate_layout.resolve(board,unit,anchor)
  var outside: Array[String]
  for piece: Rect2 in group["group_rects"]:
   if not viewport.encloses(piece): outside.append(str(piece))
  if verbose or not outside.is_empty():
   print("PLACEMENT_REPRO ",JSON.stringify({"case":label,"key":unit["key"],"tile":str(unit["pos"]),"center":str(board._unit_center(unit)),"anchor":str(anchor),"placed":str(group["frame"]),"offset":str(group["offset"]),"viewport":str(viewport),"outside":outside}))
  var inspection: Rect2 = board.enemy_inspection_visual_global_rect(str(unit["key"]))
  if unit.get("role")=="enemy":
   for entry: Dictionary in group["statuses"]:
    if not inspection.encloses(entry["rect"]):
     print("INSPECTION_REPRO ",JSON.stringify({"case":label,"key":unit["key"],"offset":str(group["offset"]),"inspection":str(inspection),"pill":str(entry["rect"]),"icon":entry["icon"]}))
