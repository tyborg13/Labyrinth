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
 var engine := Run.new()
 var run: Dictionary = Warband.build(engine,Combat.new(),engine.create_new_run(83,Store.default_data()),{"warband_biome":"air","warband_tier":2})
 var mixed: Dictionary = TF.staged_state(Combat.new())
 var enemies: Array[Dictionary]
 var roster: Array = ["crawler", "burrow_grub", "gale_herald", "gust_shrike", "storm_capacitor", "veilbound_acolyte", "glacial_mirror", "ember_tick"]
 var positions: Array = [Vector2i(3,3),Vector2i(4,3),Vector2i(5,3),Vector2i(3,4),Vector2i(5,4),Vector2i(3,5),Vector2i(4,5),Vector2i(5,5)]
 for i: int in range(roster.size()):
  var enemy: Dictionary = Fixtures._foe(roster[i],i+1,positions[i])
  enemy.merge({"burrowed":i==1,"charge":2,"veiled":i==5,"is_leader":i==0})
  enemies.append(enemy)
 mixed["enemies"] = enemies
 mixed["illusions"] = [{"id":1,"pos":Vector2i(2,4),"hp":3,"max_hp":3,"block":4,"stoneskin":3,"chilled":true,"source_name":"Ball Lightning","on_damaged":{"damage":4,"element":"lightning","shock":1}}]
 Fixtures._decorate(mixed)
 # First match the committed crowded fixture exactly in an isolated board.
 var board := Board.new()
 board.size = Vector2(1920,1080)
 root.add_child(board)
 var rest: Dictionary = Badges.build(Combat.new(),mixed,mixed)
 board.set_combat_state(mixed,[],[],Vector2i(-1,-1),"","",{},{},{"threats_at_rest":rest,"reduced_motion":true})
 _report(board,"exact_sweep")
 board.queue_free()
 await process_frame
 for mode: String in ["warband_air", "mixed"]:
  if mode=="mixed":run["combat_state"] = mixed
  else:Fixtures._decorate(run["combat_state"])
  var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
  root.add_child(scene)
  await process_frame
  scene.call("_load_run_state",run)
  if bool(scene.get("_dialogue_active")):scene.call("_close_dialogue")
  for i: int in range(8): await process_frame
  board = scene.get("board_view")
  _report(board,"live_"+mode)
  for index: int in range((board.combat_state.get("deck",{}).get("hand",[]) as Array).size()):
   var card: Control=scene.call("_hand_card_control",index)
   if card==null:continue
   var card_rect: Rect2=scene.call("_control_visual_global_rect",card)
   print("HAND_RECT ",mode," ",card_rect)
   for unit: Dictionary in board._hud_layout_units():
    var group: Dictionary=board._status_plate_layout.resolve(board,unit,board._unit_health_bar_rect(unit,board._unit_center(unit)))
    for piece: Rect2 in group["group_rects"]:
     if card_rect.intersects(board._visual_rect_to_global(piece),false):print("HAND_OVERLAP ",mode," ",unit["key"]," ",piece)

  for unit: Dictionary in board._hud_layout_units():
   if unit.get("role")!="enemy":continue
   board.set_controller_focus_tile(unit["pos"])
   board._rebuild_hud_health_rects_cache()
   var focus_rect: Rect2 = board.enemy_intent_visual_global_rect(unit["key"])
   var entry: Dictionary = {}
   for candidate: Dictionary in board._hud_layout_entries_cache:
    if candidate["actor_key"]==unit["key"]:entry=candidate
   print("FOCUS_REPRO ",JSON.stringify({"case":mode,"key":unit["key"],"rect":str(focus_rect),"expected":str(board._visual_rect_to_global(entry.get("layout",{}).get("intent_rect",Rect2())))}))
  board.set_controller_focus_tile(Vector2i(-1,-1))
  for i: int in range(2): await process_frame
  for unit: Dictionary in board._hud_layout_units():
   var group: Dictionary = board._status_plate_layout.resolve(board,unit,board._unit_health_bar_rect(unit,board._unit_center(unit)))
   var entries: Array = group["defenses"].duplicate()
   entries.append_array(group["statuses"])
   for entry: Dictionary in entries:
    var rect: Rect2=entry["rect"]
    var actual: String=board._get_tooltip(rect.get_center())
    print("TOOLTIP_REPRO ",JSON.stringify({"case":mode,"key":unit["key"],"icon":entry["icon"],"rect":str(rect),"matches":actual==entry["tooltip"],"actual":actual,"expected":entry["tooltip"]}))
  scene.queue_free()
  await process_frame
 quit()
func _report(board: Control,label: String) -> void:
 var vp: Rect2=board._enemy_hud_viewport_bounds()
 print("LIVE_VIEWPORT ",label," ",vp," obstacles=",board.presentation.get("hud_obstacle_global_rects",[]))
 for unit: Dictionary in board._hud_layout_units():
  if unit.get("boss_bar",false):continue
  var anchor: Rect2=board._unit_health_bar_rect(unit,board._unit_center(unit))
  var group: Dictionary=board._status_plate_layout.resolve(board,unit,anchor)
  var outside: Array[String]
  var on_other: Array[String]
  for piece: Rect2 in group["group_rects"]:
   if not vp.encloses(piece):outside.append(str(piece))
  for other: Dictionary in board._hud_layout_units():
   if unit["key"]==other["key"]:continue
   if (group["frame"] as Rect2).intersects(board._enemy_hud_actor_clear_rect(other,board._unit_center(other)),false):on_other.append(other["key"])
  print("LIVE_PLACEMENT ",JSON.stringify({"case":label,"key":unit["key"],"tile":str(unit["pos"]),"placed_tile":str(board._tile_at_point((group["frame"] as Rect2).get_center())),"center":str(board._unit_center(unit)),"anchor":str(anchor),"placed":str(group["frame"]),"offset":str(group["offset"]),"outside":outside,"on_other_art":on_other}))
