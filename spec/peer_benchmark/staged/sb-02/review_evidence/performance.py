from pathlib import Path
import subprocess,json,re
out=Path('/private/tmp/sb01-final-review')
template=(out/'movement.gd').read_text()
reports={}
for label,rev in [('parent','03e6d5013'),('base','codex/peer-benchmark'),('candidate',None)]:
 paths=[]
 try:
  probe=Path('tests/_sb01_review_movement.gd')
  assert not probe.exists(); paths.append(probe)
  text=template
  if rev:
   board=Path('tests/_sb01_review_historical_board.gd'); assert not board.exists(); paths.append(board)
   src=subprocess.check_output(['git','show',rev+':scripts/combat_board_view.gd'],text=True).replace('class_name CombatBoardView','')
   if label=='parent':
    cache=Path('tests/_sb01_review_historical_cache.gd'); assert not cache.exists(); paths.append(cache)
    plates=Path('tests/_sb01_review_historical_plates.gd'); assert not plates.exists(); paths.append(plates)
    cache.write_text(subprocess.check_output(['git','show',rev+':scripts/board_status_layout_cache.gd'],text=True).replace('res://scripts/board_status_plates.gd','res://'+str(plates)))
    plates.write_text(subprocess.check_output(['git','show',rev+':scripts/board_status_plates.gd'],text=True))
    src=src.replace('res://scripts/board_status_layout_cache.gd','res://'+str(cache)).replace('res://scripts/board_status_plates.gd','res://'+str(plates))
   board.write_text(src)
   text=text.replace('res://scripts/combat_board_view.gd','res://'+str(board))
  probe.write_text(text)
  reports[label]=[]
  for repeat in range(2):
   r=subprocess.run(['python3','tools/godot_task_runner.py','--task-id','sb-01-review','--stream','--','godot','--headless','--path','.','--script',str(probe)],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
   (out/('movement_'+label+'_'+str(repeat)+'.log')).write_text(r.stdout)
   if r.returncode: raise RuntimeError(label+': '+r.stdout[-2000:])
   report=json.loads(re.search(r'^MOVE_CPU (.+)$',r.stdout,re.M)[1]); reports[label].append(report)
   print(label,repeat,report['p50_us'],report['p95_us'],flush=True)
 finally:
  for p in paths:
   if p.exists():p.unlink()
(out/'movement_comparison.json').write_text(json.dumps(reports,indent=2)+'\n')
