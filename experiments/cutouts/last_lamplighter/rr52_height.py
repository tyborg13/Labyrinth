"""Measure drawn rest heights using the real production board's scale query."""
import subprocess
import os
import sys
from PIL import Image
from rr52_build import ROOT,CASE,ASSETS
from cutout_pipeline.cases import read_json,write_json

PROBE='''extends SceneTree
func _initialize() -> void:
 preload("res://scripts/parallel_runtime.gd").apply_from_environment()
 _run.call_deferred()
func _run() -> void:
 var scales: Dictionary = await preload("res://experiments/cutouts/last_lamplighter/rr52/probes/board_scales.gd").measure(self)
 FileAccess.open("res://experiments/cutouts/last_lamplighter/rr52/proof/board_scales.json", FileAccess.WRITE).store_string(JSON.stringify(scales))
 print("RR52 BOARD SCALE QUERY: PASS (production geometry; no pixels)")
 quit()
'''


def run():
    script=CASE/'proof/height_probe.gd';script.write_text(PROBE)
    subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-52','--stream','--','godot','--headless','--path','.', '--script',str(script.relative_to(ROOT))],cwd=ROOT,check=True,env=dict(os.environ,LABYRINTH_CEL_LOOK="off"))
    scales=read_json(CASE/'proof/board_scales.json');rows={}
    for view in ('front','rear'):
        hero=ROOT/f'assets/units/protagonist_cutout/{view}/{view}_assembled_rest_v9.png';lamp=ASSETS/f'humanoid_v2/{view}/rest.png'
        def height(path):
            with Image.open(path) as image:bounds=image.convert('RGBA').getchannel('A').getbbox()
            return bounds[3]-bounds[1]
        h=height(hero)*scales['protagonist'];l=height(lamp)*scales['last_lamplighter'];rows[view]={'lamplighter_drawn_px':l,'hero_drawn_px':h,'ratio':l/h,'director_target_ratio':{'front':1.08,'rear':1.155}[view]}
    result={'views':rows,'art_scale':read_json(ROOT/'data/enemies.json')['last_lamplighter']['art_scale'],'native_pixels':False,'source':'production board scale query times treated rest alpha height; actual board judgment pending'}
    write_json(CASE/'proof/drawn_height.json',result)
    for v,r in rows.items():print(f'RR52 DRAWN HEIGHT {v}: {r["lamplighter_drawn_px"]:.3f}px; hero {r["hero_drawn_px"]:.3f}px; ratio {r["ratio"]:.6f}; target~{r["director_target_ratio"]}')

if __name__=='__main__':run()
