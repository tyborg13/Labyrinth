import json,sys,subprocess
from pathlib import Path
root=Path('/tmp/labyrinth-perf-2026-09-17')
repo=Path('/Users/borgerding/workspace/Labyrinth.worktrees/thorough-steam-deck-performance-pass-across-varied-gameplay-and-animatio')
sys.path.insert(0,str(repo/'tools'));import performance_pass
pairs=[('full','full-base','full-candidate'),('tail-a','tail-base-a','tail-candidate-a'),('tail-b','tail-base-b','tail-candidate-b'),('reduced','reduced-base','reduced-candidate'),('early','early-base','early-candidate'),('middle','middle-base','middle-candidate')]
out={'pairs':{},'notes':['Native foreground 1920x1080, 100% UI, Metal/mobile 4xMSAA.','GPU timers reported zero and the texture-memory monitor reported an overflow sentinel; treat these counters as unavailable, not measurements.']}
for label,b,c in pairs:
 bp=root/('sept18-accept-'+b+'.json');cp=root/('sept18-accept-'+c+'.json')
 base=json.load(open(bp));cand=json.load(open(cp));bench=next(iter(base['benchmarks']))
 br=base['benchmarks'][bench]['result'];cr=cand['benchmarks'][bench]['result']
 for r in (br,cr):assert r.get('probe_unfocused_observations',0)==0 and not r.get('semantic_errors'),label
 result=subprocess.run(['python3',str(repo/'tools/performance_pass.py'),'compare',str(bp),str(cp)],text=True,capture_output=True)
 assert result.returncode==0,(label,result.stdout,result.stderr)
 (root/('sept18-accept-'+label+'-compare.txt')).write_text(result.stdout)
 semantic={}
 for group,round_result in br.get('enemy_round_matrix',{}).items():
  candidate=cr['enemy_round_matrix'][group]
  semantic[group]={}
  for field in ('reference_digest','reference_step_count','enemy_activations'):
   assert field in round_result and field in candidate,(label,group,field,'absent')
   assert round_result[field]==candidate[field],(label,group,field,'DIFF')
   semantic[group][field]=round_result[field]
 metrics={}
 for category in ('action_matrix','ability_action_matrix','enemy_round_matrix'):
  for action,old in br.get(category,{}).items():
   new=cr[category][action]
   metrics[category+'.'+action]={m:{'base':old['frame_interval_ms'][m],'candidate':new['frame_interval_ms'][m]} for m in ('median','p95','p99','max')}
   for field in ('frames_over_16_67_ms','frames_over_33_33_ms','action_completion_ms','total_ms'):
    if field in old and field in new:metrics[category+'.'+action][field]={'base':old[field],'candidate':new[field]}
 out['pairs'][label]={'baseline':bp.name,'candidate':cp.name,'enemy_semantics':semantic,'metrics':metrics,'memory':{k:{'base':br[k],'candidate':cr[k]} for k in br if 'memory_bytes' in k and k in cr and 0 <= br[k] < 9223372036854775807 and 0 <= cr[k] < 9223372036854775807},'nodes':{k:{'base':br[k],'candidate':cr[k]} for k in ('initial_nodes','final_nodes','repeated_install_nodes','final_orphan_nodes') if k in br and k in cr}}
(root/'sept18-native-acceptance-analysis.json').write_text(json.dumps(out,indent=2)+'\n')
for label,pair in out['pairs'].items():
 print(label)
 for action,m in pair['metrics'].items():print(action,'max',m['max'],'p95',m['p95'],'>16',m.get('frames_over_16_67_ms'))
