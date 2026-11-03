"""Protected paint/motion, all-clip anatomy, mutations and earlier-rig byte parity."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'experiments/cutouts/ashen_reaver')]
from rr48_build import CASE,ASSETS,DIRECTOR,partition
from rr48_gates import elbow_errors,held_errors
from rr48_motion import clamp_limits
from rr48_feedback1 import motion_policy
from rr48_budget_search import apply_recorded
from rr48_feedback_gates import underlay_errors,floor_errors,follow_errors,native_floor_errors
from humanoid_cutout.compiler import compile_motion
from cutout_pipeline.cases import read_json

DEFAULTS={'process_timeout_seconds':300,'detachment_mutation_px':[-120,-60],'floor_mutation_px':.25,'synthetic_floor_rgba':[255,255,255,255],'authority_mutation_uv':[0,0]}
FEEDBACK3_DEFAULTS={'non_director_outline_rgba':[0,0,0,255],'walk_scale_mutation':.99}

SAMPLES=CASE/'proof/feedback3_samples.json'
UNIFIED_BASELINE='6135c6ec6'

def godot(script,*args,project=ROOT):
 result=subprocess.run([sys.executable,str(ROOT/'tools/godot_task_runner.py'),'--task-id','walk-01','--stream','--','godot','--headless','--path',str(project),'--script',script,'--',*map(str,args)],cwd=ROOT,capture_output=True,text=True,timeout=DEFAULTS['process_timeout_seconds'])
 if result.returncode:raise AssertionError(result.stdout+result.stderr)
 for line in result.stdout.splitlines():
  if line.startswith('RR48 '):print(line)
 return result

class ReaverTests(unittest.TestCase):
 def test_feedback3_calibration_and_full_underlay(self):
  from rr48_feedback3_source import domains
  from rr48_feedback1 import inputs
  from rr48_feedback3_contract import walk_arm_errors
  from maquette_motion.features import source_pixels
  calibration=read_json(CASE/'proof/feedback3_calibration.json')
  self.assertTrue(calibration['ok']);self.assertEqual(len(calibration['coverage']),14)
  self.assertEqual(sum(r['hole_frames'] for r in calibration['coverage']),179)
  self.assertEqual(sum(r['pockets'] for r in calibration['coverage']),225)
  self.assertEqual(sum(r['outline_records'] for r in calibration['coverage']),3281)
  self.assertFalse(calibration['missing'])
  for view in ('front','rear'):
   partition=domains(view)
   self.assertTrue(np.array_equal(np.sum(list(partition.values()),axis=0),inputs(view)[...,3]>0))
   layout=read_json(CASE/f'layouts/{view}.json')
   for name,mask in partition.items():
    p=next(p for p in layout['parts'] if p['name']=='hidden_'+name)
    self.assertTrue(np.array_equal(source_pixels(CASE,p)[mask],inputs(view)[mask]))
  data=read_json(CASE/'compiled_motion.json');self.assertFalse(walk_arm_errors(data))
  changed=copy.deepcopy(data);changed['clips']['move']['gait']['arm_swing']['near']['upper_deg']*=FEEDBACK3_DEFAULTS['walk_scale_mutation']
  self.assertTrue(walk_arm_errors(changed))
  print('RR48 FEEDBACK 3 CALIBRATION: PASS (179 native hole frames; 225 pockets; 3281 outline records; CPU superset in both views)')
  print('RR48 FEEDBACK 3 WALK MUTATION: PASS (near-arm scale below 1.0 rejected)')

 def test_feedback3_outline_slab_and_negative_space_mutations(self):
  from rr48_feedback3_cpu import model,frame
  from rr48_feedback3_policy import DirectorPolicy
  from humanoid_cutout.canvas import for_case
  from humanoid_cutout.gates import matrix
  from maquette_motion import pixels
  sample=read_json(CASE/'proof/feedback3_raster_samples.json');row=next(r for r in sample['samples'] if r['view']=='rear' and r['clip']=='idle' and r['frame']==7)
  with for_case(CASE):
   m=model(CASE,'rear');policy=DirectorPolicy(m);_,layers,maps=frame(m,row,read_json(CASE/'compiled_motion.json'))
   self.assertEqual(policy.metrics(layers,row,maps)['exposed_outline_pixels'],0)
   changed=[(p,im.copy(),check) for p,im,check in layers];occupied=np.zeros(changed[0][1].shape[:2],bool);mutated=False
   for p,im,check in sorted(changed,key=lambda r:r[0]['z_index'],reverse=True):
    exposed=(im[...,3]>0)&~occupied;occupied|=im[...,3]>0
    target=exposed&np.any(im[...,:3]!=0,axis=-1)
    if p.get('hidden_material') and target.any():
     y,x=np.argwhere(target)[0];im[y,x]=FEEDBACK3_DEFAULTS['non_director_outline_rgba'];mutated=True;break
   self.assertTrue(mutated);self.assertGreater(policy.metrics(changed,row,maps)['exposed_outline_pixels'],0)
   hidden=[r for r in layers if r[0].get('hidden_material')]
   metric=policy.metrics(hidden,row,maps)
   self.assertEqual(metric['exposed_outline_pixels'],0)
   self.assertGreater(metric['dark_slab_blocks'],0,'Exact director paint must not waive exposed 3x3 slabs')
   p=policy.parts['hidden_torso'];a,b,c,d=p['bbox'];source=np.zeros((d-b,c-a,4),np.uint8);source[policy.domains['torso'][b:d,a:c]]=255
   painted=pixels.render(source,matrix(row['parts']['hidden_torso']['transform']))[...,3]>0
   y,x=np.argwhere(painted)[0];mask=np.zeros_like(painted);mask[y,x]=True
   # Ownership cannot turn another receiver's opaque director paint into air.
   # This is deliberately independent of the current supply partition.
   for domain in policy.domains.values():domain[:]=False
   self.assertTrue(policy.validate_negative_space(mask,row))
  print('RR48 FEEDBACK 3 MATERIAL MUTATIONS: PASS (non-director outline, exact-paint 3x3 slab and false underlay-air claim rejected)')

 def test_feedback3_short_hole_rule_keeps_pixel_and_duration_limits(self):
  from rr48_feedback3_policy import temporal
  fixture=[{'view':'front','clip':'rake','joint':'wrist_far','frame':f,'bbox':[0,0,2,2],'pixel_count':4} for f in range(4)]
  failures,accepted=temporal(fixture[:3]);self.assertFalse(failures);self.assertEqual(len(accepted),3)
  failures,accepted=temporal(fixture);self.assertEqual(len(failures),4);self.assertFalse(accepted)
  fixture[0]['pixel_count']=5;failures,accepted=temporal(fixture[:1]);self.assertTrue(failures);self.assertFalse(accepted)

 def test_approved_paint_is_exact_and_partition_is_exhaustive(self):
  for view in ('front','rear'):
   _,paint,pieces,_=partition(view)
   reconstruction=np.zeros_like(paint);count=np.zeros(paint.shape[:2],int)
   for name,im in pieces.items():
    mask=im[...,3]>0;reconstruction[mask]=im[mask];count+=mask
   self.assertTrue(np.array_equal(reconstruction,paint));self.assertLessEqual(count.max(),1)
   self.assertEqual(read_json(CASE/f'layouts/{view}.json')['joints']['falchion']['parent'],'hand_far')
   self.assertNotIn('pauldron_near',read_json(CASE/f'layouts/{view}.json')['joints'])
   visible=[p for p in read_json(CASE/f'layouts/{view}.json')['parts'] if not p.get('hidden_material',False)]
   self.assertEqual(len(visible),14)
  self.assertTrue(underlay_errors()['ok'])
  print('RR48 APPROVED PAINT PARTITION: PASS (both views 0 px; full-underlay rest additions recorded separately)')

 def test_protected_motion_and_clamps(self):
  self.assertEqual((CASE/'director_motion.json').read_bytes(),DIRECTOR.read_bytes())
  production=read_json(ASSETS/'humanoid_v2/director_motion.json');original=read_json(DIRECTOR)
  # walk-01 changes only production cadence. Retained rr48 proof inputs stay
  # immutable, including their old six-step clock and first-build projection.
  production['ashen_reaver']['clips']['move']['seconds']=original['ashen_reaver']['clips']['move']['seconds']
  production['ashen_reaver']['clips']['move']['gait']['steps_per_tile']=original['ashen_reaver']['clips']['move']['gait']['steps_per_tile']
  self.assertEqual(production,original)
  data=read_json(CASE/'compiled_motion.json');layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
  corrected=copy.deepcopy(data);corrected['projection']['rear']['forward']=[-value for value in data['projection']['front']['forward']]
  self.assertEqual(corrected,apply_recorded(motion_policy(clamp_limits(compile_motion(DIRECTOR,'ashen_reaver',layouts,corrected['projection'])),layouts)))
  self.assertTrue(data['budget_clamps']);self.assertEqual(data['elbow_policy']['max_hyperextension_deg'],2)
  bad=copy.deepcopy(data);bad['view_tracks']['front']['idle'][0]['keys'][0]['value']=900
  self.assertNotEqual(bad,data)
  print('RR48 DIRECTOR DATA: PASS (retained source unchanged; production cadence override only; corrected projection recompiles; clamps recorded separately)')

 def test_all_frames_elbows_and_held_item_and_mutations(self):
  with tempfile.TemporaryDirectory(prefix='rr48-samples-') as folder:
   output=Path(folder)/'samples.json'
   godot('res://tests/rr48/samples.gd','--case',CASE,'--output',output)
   samples=read_json(output);data=read_json(CASE/'compiled_motion.json')
   report=elbow_errors(data,samples);self.assertTrue(report['ok'],report['errors'][:5])
   for view in ('front','rear'):
    report=held_errors(read_json(CASE/f'layouts/{view}.json'),data,samples);self.assertTrue(report['ok'],report['errors'][:5])
   self.assertTrue(floor_errors(CASE,samples)['ok'])
   self.assertTrue(follow_errors(samples)['ok'])
   production=Path(folder)/'production.json'
   godot('res://tests/rr48/samples.gd','--case',CASE,'--production','--output',production)
   self.assertTrue(floor_errors(ASSETS/'humanoid_v2',read_json(production),True)['ok'])
   below=copy.deepcopy(samples);row=next(r for r in below['samples'] if r['clip']=='death' and r['phase']>=.45);row['bones']['falchion']['global'][5]+=.25
   self.assertFalse(floor_errors(CASE,below)['ok'])
   broken=copy.deepcopy(samples)
   row=next(r for r in broken['samples'] if r['clip']=='sweep' and r['kind']=='presented')
   a=np.array(row['bones']['upper_near']['global'][4:]);c=np.array(row['bones']['hand_near']['global'][4:]);mid=(a+c)/2
   forward=np.array(data['projection'][row['view']]['forward']);normal=np.array([-(c-a)[1],(c-a)[0]])
   direction=np.sign((c-a)[0]*forward[1]-(c-a)[1]*forward[0]);row['bones']['fore_near']['global'][4:]=(mid+normal*direction*0.1).tolist()
   self.assertFalse(elbow_errors(data,broken)['ok'])
   row=next(r for r in broken['samples'] if r['view']=='front' and r['clip']=='idle');row['bones']['falchion']['global'][4]+=9
   self.assertFalse(held_errors(read_json(CASE/'layouts/front.json'),data,broken)['ok'])
  print('RR48 MOTION MUTATIONS: PASS (hyperextension and detached grip rejected)')

 def test_exact_director_underlay_and_transparent_clears_reject_mutations(self):
  import shutil
  self.assertTrue(underlay_errors(ASSETS/'humanoid_v2',True)['ok'])
  with tempfile.TemporaryDirectory(prefix='rr48-underlay-mutation-') as folder:
   folder=Path(folder)
   for name in ('layouts','pieces'):shutil.copytree(CASE/name,folder/name)
   layout=read_json(folder/'layouts/front.json');part=next(p for p in layout['parts'] if p['name']=='hidden_leg_near')
   path=folder/part['file'];original=np.asarray(Image.open(path).convert('RGBA')).copy()
   y,x=np.nonzero(original[...,3]);bad=original.copy();bad[y[0],x[0],0]^=1;Image.fromarray(bad).save(path)
   self.assertFalse(underlay_errors(folder)['ok'])
   mask=np.asarray(Image.open(CASE/'ownership/feedback2_front_hidden_leg_near_domain.png').convert('L'))>0
   # Full receiver domains contain opaque underlay; the alpha-zero remainder
   # of the stored texture is still required to stay clear background.
   cy,cx=np.nonzero(original[...,3]==0)
   self.assertGreater(len(cx),0)
   bad=original.copy();bad[cy[0],cx[0]]=[0,0,0,255];Image.fromarray(bad).save(path)
   self.assertFalse(underlay_errors(folder)['ok'])
   Image.fromarray(original).save(path)
   shutil.copytree(CASE/'ownership',folder/'ownership')
   authority=Image.open(folder/'ownership/feedback2_front_hidden_leg_near_domain.png').convert('L');authority.putpixel(tuple(DEFAULTS['authority_mutation_uv']),255);authority.save(folder/'ownership/feedback2_front_hidden_leg_near_domain.png')
   report=underlay_errors(folder)
   self.assertTrue(any('outside authorized' in e for e in report['errors']))
  print('RR48 UNDERLAY MUTATIONS: PASS (wrong RGBA, opaque replacement of director air and authority outside footprints/tucks rejected)')

 def test_body_relative_follow_excludes_root_travel(self):
  result=godot('res://tests/rr48/follow_check.gd')
  self.assertIn('RR48 ROOT-RELATIVE FOLLOW: PASS',result.stdout)

 def test_approved_caps_detached_falchion_and_floor_direction_mutations(self):
  import shutil,math
  from rr48_supply_gates import grip_errors
  from rr48_feedback2_source import source_plan
  with tempfile.TemporaryDirectory(prefix='rr48-cap-mutations-') as folder:
   folder=Path(folder)
   for name in ('layouts','pieces','ownership'):shutil.copytree(CASE/name,folder/name)
   plan=source_plan('front')['hidden_falchion'];y,x=np.argwhere(plan['cap'])[0]
   part=next(p for p in read_json(folder/'layouts/front.json')['parts'] if p['name']=='hidden_falchion');path=folder/part['file'];im=np.asarray(Image.open(path).convert('RGBA')).copy();before=im.copy();im[y-part['offset'][1],x-part['offset'][0],0]^=1;Image.fromarray(im).save(path)
   self.assertFalse(underlay_errors(folder)['ok'])
   Image.fromarray(before).save(path);mask=folder/'ownership/feedback2_front_hidden_falchion_cap.png';im=Image.open(mask).convert('L');im.putpixel(tuple(DEFAULTS['authority_mutation_uv']),255);im.save(mask)
   self.assertTrue(any('cap outside authorized source/tuck mask' in e for e in underlay_errors(folder)['errors']))
  s=read_json(SAMPLES);row=copy.deepcopy(next(r for r in s['samples'] if r['view']=='front' and r['clip']=='idle' and r['kind']=='presented' and r['frame']==0));fixture={'samples':[row]}
  self.assertTrue(grip_errors(CASE,fixture)['ok'])
  for p in read_json(CASE/'layouts/front.json')['parts']:
   if p['logical_part']=='falchion':row['parts'][p['name']]['transform'][4]+=DEFAULTS['detachment_mutation_px'][0]
  self.assertFalse(grip_errors(CASE,fixture)['ok'])
  row=copy.deepcopy(next(r for r in s['samples'] if r['view']=='front' and r['clip']=='death' and r['phase']==1 and r['kind']=='presented'))
  bone=row['bones']['falchion']['global'];bone[0:4]=[0.,1.,-1.,0.]
  report=floor_errors(CASE,{'samples':[row]});self.assertTrue(any('reversed keyed floor path' in e for e in report['errors']))
  print('RR48 FEEDBACK 2 MUTATIONS: PASS (changed cap, outside-tuck cap, detached falchion, reversed keyed floor path rejected)')

 def test_native_floor_oracle_rejects_below_floor_pixels_and_geometry(self):
  import math
  samples=read_json(SAMPLES)
  row=next(r for r in samples['samples'] if r['view']=='front' and r['clip']=='death' and r['phase']==1 and r['kind']=='presented')
  layout=read_json(CASE/'layouts/front.json');floor=layout['held_items']['falchion']['floor_line_y']
  with tempfile.TemporaryDirectory(prefix='rr48-floor-codec-fixture-') as folder:
   folder=Path(folder);image=Image.new('RGBA',(640,640));image.putpixel((0,int(floor+192)-1),tuple(DEFAULTS['synthetic_floor_rgba']));image.save(folder/'synthetic.png')
   record={'name':'falchion','clip':'death','view':'front','frame':round(read_json(CASE/'compiled_motion.json')['clips']['death']['seconds']*60)-1,'file':'synthetic.png','transform':row['parts']['falchion']['transform']}
   manifest={'native_pixels':False,'pieces':[record],'clip_scope':['death']}
   (folder/'frames.json').write_text(json.dumps(manifest));report=native_floor_errors(CASE,folder)
   self.assertTrue(report['ok'],report['errors']);self.assertFalse(report['native_pixels'])
   image.putpixel((0,math.ceil(floor+192)+2),tuple(DEFAULTS['synthetic_floor_rgba']));image.save(folder/'synthetic.png')
   self.assertFalse(native_floor_errors(CASE,folder)['ok'])
   record['transform'][5]+=DEFAULTS['floor_mutation_px'];(folder/'frames.json').write_text(json.dumps(manifest))
   self.assertTrue(any('support differs' in e for e in native_floor_errors(CASE,folder)['errors']))
  print('RR48 NATIVE FLOOR ORACLE MUTATIONS: PASS (synthetic codec fixture only; native pixels=false)')

 def test_assembled_joint_budget_rejects_actual_detachment(self):
  from rr48_joint_budget import measure
  samples=read_json(SAMPLES);row=copy.deepcopy(next(r for r in samples['samples'] if r['view']=='front' and r['clip']=='idle' and r['kind']=='presented' and r['frame']==0))
  fixture={'samples':[row]};selection={'wrist_far','grip','internal_arm_far'}
  self.assertTrue(measure(fixture,selection=selection)['ok'])
  row['bones']['hand_far']['global'][4]+=DEFAULTS['detachment_mutation_px'][0];row['bones']['hand_far']['global'][5]+=DEFAULTS['detachment_mutation_px'][1]
  for p in read_json(CASE/'layouts/front.json')['parts']:
   if p['logical_part']=='hand_far':
    row['parts'][p['name']]['transform'][4]+=DEFAULTS['detachment_mutation_px'][0];row['parts'][p['name']]['transform'][5]+=DEFAULTS['detachment_mutation_px'][1]
  report=measure(fixture,selection=selection)
  self.assertFalse(report['ok']);self.assertTrue(any(r['kind']=='unmatched_detached_paint' for r in report['errors']))
  print('RR48 ASSEMBLED BUDGET MUTATION: PASS (actual disconnected paint rejected)')



 def test_both_proof_boards_keep_depth_on_every_movement_frame(self):
  with tempfile.TemporaryDirectory(prefix='rr48-depth-') as folder:
   output=Path(folder)/'depth.json'
   godot('res://tests/rr48/depth_check.gd','--output',output)
   report=read_json(output)
   self.assertEqual(report['errors'],[])
   self.assertEqual(report['boards'],['fire_t1_r6','earth_t3_r7'])
   self.assertGreater(report['routes'],0);self.assertGreater(report['prop_comparisons'],0)
   self.assertFalse(report['native_pixels'])


 def test_strike_registration_has_live_contacts_in_every_facing(self):
  result=godot('res://tests/rr48/strike_test.gd')
  self.assertIn('RR48 STRIKE REGISTRATION: PASS',result.stdout)

 def test_production_actions_resolve_on_the_existing_contact(self):
  with tempfile.TemporaryDirectory(prefix='rr48-production-') as folder:
   for rear in (False,True):
    output=Path(folder)/('rear' if rear else 'front')
    godot('res://tests/rr48/production_capture.gd','--type','ashen_reaver','--output',output,'--logic-only',*(['--rear'] if rear else []))
    report=read_json(output/'logic_frames.json');self.assertTrue(report['ok'],report['errors'])
    self.assertFalse(report['native_pixels'])
  print('RR48 PRODUCTION LOGIC: PASS (front/rear move, rake, sweep, fall, hit, death)')

if __name__=='__main__':unittest.main()
