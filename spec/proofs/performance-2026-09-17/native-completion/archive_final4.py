import gzip,hashlib,json,re,subprocess
from pathlib import Path
scratch=Path('/tmp/labyrinth-perf-2026-09-17')
repo=Path('/Users/borgerding/workspace/Labyrinth.worktrees/thorough-steam-deck-performance-pass-across-varied-gameplay-and-animatio')
dest=repo/'spec/proofs/performance-2026-09-17/native-completion'
production={str(p.relative_to(repo)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((repo/'scripts').rglob('*.gd'))}
labels=['full','tail-a','tail-b','reduced','reduced-repeat','early','middle']
reports=[]
for p in sorted(scratch.glob('sept18-final4-*candidate*.json')):
 if p.name.endswith('-sources.json'):continue
 report=json.loads(p.read_text());source=json.loads(p.with_name(p.stem+'-sources.json').read_text())
 assert all(source['files'].get(k)==v for k,v in production.items()),p
 assert report['environment']['git']['revision']==source['head'],p
 result=next(iter(report['benchmarks'].values()))['result']
 assert result['probe_unfocused_observations']==0 and not result.get('semantic_errors'),p
 reports.append(p.name)
assert len(reports)==7,reports
for name in ['visual','regression','surface-query']:
 source=json.loads((scratch/('sept18-final4-'+name+'-sources.json')).read_text())
 assert source['source_invariant']
 assert all(source['files'].get(k)==v for k,v in production.items()),name
analysis=json.loads((scratch/'sept18-final4-analysis.json').read_text())
assert list(analysis['pairs'])==labels
assert 'TEST RESULT: PASS' in (scratch/'sept18-final4-run_tests.log').read_text()
dest.mkdir(parents=True,exist_ok=True)
artifacts=[]

def archive(source,classification='accepted',relative=None,compressed=None):
 source=Path(source);data=source.read_bytes();name=relative or source.name
 if compressed is None:compressed=source.suffix=='.log' or (source.suffix=='.json' and '-sources' not in source.name and 'analysis' not in source.name)
 if compressed:name+='.gz'
 output=dest/name;output.parent.mkdir(parents=True,exist_ok=True)
 output.write_bytes(gzip.compress(data,mtime=0) if compressed else data)
 artifacts.append({'path':name,'classification':classification,'source_file':source.name,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'uncompressed_sha256':hashlib.sha256(data).hexdigest()})

for p in sorted(scratch.glob('sept18-final4-*')):
 archive(p, 'rejected-oracle-correction' if p.name == 'sept18-final4-surface-query.log' else ('superseded-test-assertion-wording' if p.name == 'sept18-final4-surface-query-verified.log' else 'accepted'))
for name in ['run_final4_native.py','run_final4_regressions.py','run_final4_reduced_repeat.py','run_final4_visual.py','run_final4_surface_query.py','analyze_final4.py','archive_final4.py','write_final4_report.py']:
 archive(scratch/name)
for prefix in ['sept18-route-enemy-','sept18-hand-final-actions-','sept18-proxy-actions-','sept18-prismatic-isolate-']:
 for p in sorted(scratch.glob(prefix+'*')):archive(p,'component-diagnostic',relative='components/'+p.name)
for prefix in ['sept18-final2-','sept18-final3-']:
 for p in sorted(scratch.glob(prefix+'*')):archive(p,'superseded-pre-review-diagnostic',relative='superseded/'+p.name)
for name in ['sept18-spell-submission-diagnostic.log','sept18-fire-actions-base.json','sept18-fire-actions-candidate.json','sept18-fire-v2-actions-candidate.json']:
 p=scratch/name
 if p.exists():archive(p,'rejected-experiment-diagnostic',relative='experiments/'+name)
for group,logname in [('geometry','sept18-final4-geometry.log'),('hand','sept18-final4-hand.log'),('draw-flow','sept18-final4-draw-flow.log')]:
 content=(scratch/logname).read_text()
 images=re.findall(r'^  (/private/tmp/[^\n]+?\.png) ',content,re.M)
 assert images,logname
 if group=='geometry':assert len(images)==32
 for p in images:archive(p,relative='images/'+group+'/'+Path(p).name,compressed=False)
for label in ['full-candidate','reduced-candidate','early-candidate','middle-candidate']:
 result=next(iter(json.loads((scratch/('sept18-final4-'+label+'.json')).read_text())['benchmarks'].values()))['result']
 paths=result['action_visual_proof']['captured_paths'];assert paths,label
 for index,p in enumerate(paths):archive(p,relative='images/combat/'+label+'-'+str(index)+'.png',compressed=False)
 if label == 'full-candidate':
  for name in ['dense_idle.png','wildfire_halo_preview.png','ranged_trap_hand.png']:
   archive(Path(paths[0]).parent/name,relative='images/combat/'+name,compressed=False)
 profile=label.split('-')[0]
 if profile in ('early','middle'):
  p=Path(paths[0]).parent/(profile+'_idle.png')
  archive(p,relative='images/combat/'+profile+'-idle.png',compressed=False)
manifest={
 'status':'Final source-bound native comparisons and correctness/visual verification complete. Local unpublished candidate; see accompanying report for remaining frame tails.',
 'baseline_commit':'365dc25bd28385a80e20b7925f96a115024b3f7f',
 'production_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
 'production_sha256':production,
 'measurement_contract':{
  'host':'Apple M5 Pro, macOS 26.3.1 arm64, Godot 4.6.1',
  'renderer':'Metal/mobile, production 4xMSAA, native foreground 1920x1080, 100% UI scale',
  'pairs':labels,
  'source_guards':'The fourteen final4 runs record all recursive scripts/**/*.gd, tracked Godot scenes/resources/shaders, project.godot and the named benchmark/runner files before and after execution. Binary assets are not hashed by this snapshot; none changed in this phase. Candidate raw reports retain pre-commit HEAD 365dc25 and dirty status; this manifest verifies their complete runtime GDScript hashes against production_commit. Harness/configuration equality is checked for each pair.',
  'source_guards_visual_regression':'Native geometry, draw-flow and hand lifecycle plus the full/focused Godot suite have before/after recursive scripts and tests hashes equal to the committed runtime. The additional actual surface-ability call-site test was added after the full suite and has its own verified run and source guard; production files remained identical.',
  'unavailable_counters':['viewport GPU time (all zero)','render_texture_memory_bytes (signed-64 maximum sentinel)'],
  'limit':'Mac results do not establish Steam Deck FPS. See report for non-improving tails and remaining hitches.'},
 'excluded_runs':{
  'final3':'Twelve valid native runs revealed a repeated Prismatic transition spike; full-suite cleanup failures were corrected and surface-query preparation added. Superseded by final4.',
  'final2':'Six completed preliminary runs precede review fixes; next run stopped intentionally for those fixes. None used as final4 acceptance. Retained separately as diagnostics.',
  'fire_pose_experiments':'Exact-pixel caching experiments did not show useful measured combat improvement and were reverted. One v2 baseline lost foreground and was stopped/excluded.',
  'surface_query_initial_oracle':'The first call-site test omitted existing analytics cursor staging from its expected state. Corrected the oracle using the established complete enemy-round approach; all three cases then matched every state key and the persisted result.',
  'other_component_runs':'Earlier route, hand and proxy pairs explain attribution. Their source snapshots identify different intermediate builds; they do not stand in for final build frame timings.'},
 'artifacts':artifacts}
(dest/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Archived',len(artifacts),'artifacts;',sum(p.stat().st_size for p in dest.rglob('*') if p.is_file()),'bytes')
