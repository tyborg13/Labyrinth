"""On-demand headless proof of the existing portrait and pre-battle adapters."""
import subprocess
import os
import sys
from rr52_build import ROOT,CASE

PROBE='''extends SceneTree
const Portrait = preload("res://scripts/maquette_cutout_runtime/portrait.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const TYPE: String = "last_lamplighter"
var errors: Array[String]
var checks: int = 0
func _initialize() -> void:
 preload("res://scripts/parallel_runtime.gd").apply_from_environment()
 _run.call_deferred()
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: errors.append(message)
func _run() -> void:
 var rest: Texture2D = Assets.load_texture_source_first(Portrait.rest_path(TYPE))
 var metrics: Dictionary = preload("res://scripts/pre_battle_foe_layout.gd").metrics(TYPE)
 check(metrics["used"] == Rect2(Assets.texture_used_rect(rest)), "Pre-battle uses the treated production rest")
 check(is_equal_approx(float(metrics["art_scale"]),1.03), "Approved art scale retained")
 for reduced: bool in [false,true]:
  var host := Control.new()
  var portrait := TextureRect.new()
  host.add_child(portrait)
  host.set_meta("turn_order_portrait_texture",rest)
  Portrait.bind(portrait,TYPE,reduced,true)
  root.add_child(host)
  await process_frame
  var renderer: Node = portrait.get_node("MaquettePortraitRenderer")
  check(renderer.rigs.has("front") and renderer.rigs.has("rear"), "Both approved portrait views loaded")
  check(portrait.texture is AtlasTexture and (portrait.texture as AtlasTexture).atlas is ViewportTexture, "Portrait uses the production viewport")
  check(host.get_meta("turn_order_portrait_texture") == portrait.texture, "Defeat shader retains live atlas")
  check(str(portrait.texture.get_meta("asset_source_path")) == Portrait.rest_path(TYPE), "Portrait source registration matches production")
  if reduced:
   var rig: Node2D = renderer.rigs[renderer.facing]
   var before: Dictionary = {}
   for name: String in rig.bones: before[name] = rig.bones[name].transform
   renderer._process(1.0)
   for name: String in rig.bones: check(before[name] == rig.bones[name].transform, "Reduced motion remains still: "+name)
  host.queue_free()
  await process_frame
 for error: String in errors: printerr(error)
 print("RR52 UI ROUTING: %s (%d checks; pre-battle, live portrait, both views, reduced motion)" % ["PASS" if errors.is_empty() else "FAIL",checks])
 quit(0 if errors.is_empty() else 1)
'''

if __name__=='__main__':
    probe=CASE/'proof/ui_routing.gd';probe.write_text(PROBE)
    raise SystemExit(subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-52','--stream','--','godot','--headless','--path','.', '--script',str(probe.relative_to(ROOT))],cwd=ROOT,env=dict(os.environ,LABYRINTH_CEL_LOOK="off")).returncode)
