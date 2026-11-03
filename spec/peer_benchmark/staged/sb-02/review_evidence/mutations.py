from pathlib import Path
import subprocess,json
out=Path('/private/tmp/sb01-final-review')
p=Path('scripts/board_status_layout_cache.gd'); original=p.read_bytes(); source=original.decode()
mutations=[('no_freeze',lambda s:s.replace('unit.get("freeze", 0),','')),
 ('no_keywords',lambda s:s.replace('unit.get("keyword_badges", []),','')),
 ('no_truesight',lambda s:s.replace('presentation.get("umbra_truesight_activations", 0), presentation.get("umbra_truesight_conditional", false),','')),
 ('no_defenses',lambda s:s.replace('unit.get("block", 0), unit.get("stoneskin", 0),','').replace('preview.get("block", unit.get("block", 0))','preview.get("block", 0)').replace('preview.get("stoneskin", unit.get("stoneskin", 0))','preview.get("stoneskin", 0)')),
 ('no_group_avoidance',lambda s:s.replace('Groups.offset_for(pieces, obstacles)','Vector2.ZERO')),
 ('no_neighbour_key',lambda s:s.replace('group_obstacles.get(key, []), unit.get("is_leader", false)]','unit.get("is_leader", false)]'))]
results=[]
for name, mutate in mutations:
 try:
  mutant=mutate(source); assert mutant!=source
  p.write_text(mutant)
  r=subprocess.run(['python3','tools/godot_task_runner.py','--task-id','sb-01-review','--stream','--','godot','--headless','--path','.','--script','tests/board_status_plates_test.gd'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  (out/('mutant_'+name+'.log')).write_text(r.stdout)
  result={'name':name,'caught':r.returncode!=0,'exit':r.returncode,'parse_error':any(x in r.stdout for x in ['Parse Error:','Compile Error:','SCRIPT ERROR:']),'summary':[x for x in r.stdout.splitlines() if 'TEST RESULT:' in x]}
  results.append(result); print(json.dumps(result),flush=True)
 finally:
  p.write_bytes(original); assert p.read_bytes()==original
 (out/'mutations.json').write_text(json.dumps(results,indent=2)+'\n')
# Threat collision fixes ablated independently.
p=Path('scripts/intent_badges.gd'); original=p.read_bytes(); source=original.decode()
for name,old,new in [('no_intent_obstacles','for line: Rect2 in layout.get("line_rects", []): hud_rects.append(line)','pass # omit intent obstacle'),('no_crest_obstacles','if crest.has_area(): hud_rects.append(crest)','pass # omit crest obstacle')]:
 try:
  assert source.count(old)==1; p.write_text(source.replace(old,new))
  r=subprocess.run(['python3','tools/godot_task_runner.py','--task-id','sb-01-review','--stream','--','godot','--headless','--path','.','--script','tests/board_status_plates_test.gd'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  (out/('mutant_'+name+'.log')).write_text(r.stdout)
  result={'name':name,'caught':r.returncode!=0,'exit':r.returncode,'parse_error':any(x in r.stdout for x in ['Parse Error:','Compile Error:','SCRIPT ERROR:']),'summary':[x for x in r.stdout.splitlines() if 'TEST RESULT:' in x]}
  results.append(result); print(json.dumps(result),flush=True)
 finally:
  p.write_bytes(original); assert p.read_bytes()==original
 (out/'mutations.json').write_text(json.dumps(results,indent=2)+'\n')
