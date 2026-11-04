"""Protected paint/motion, all-clip anatomy, mutations and earlier-rig byte parity."""
import copy
import json
import re
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
FEEDBACK3_NATIVE_FIXTURE={'clip_seconds':.05,'changed_frame':1}
FEEDBACK3_DEFAULTS={'non_director_outline_rgba':[0,0,0,255],'walk_scale_mutation':.99}
FEEDBACK2_DEFAULTS={'diff_fixture_size':(2,2),'diff_fixture_xy':(1,0),'diff_fixture_rgba':(1,2,3,255)}
FEEDBACK1_DEFAULTS={'clearance_mask_size':8,'opaque_alpha':255,'arm_pixel':(1,1),'hand_pixel':(2,2),
 'blade_pixel':(3,3),'clear_helm_pixel':(5,5),'hand_joint':(0,0),'shoulder_joint':(8,12),'inward_hand_x':5}

SAMPLES=CASE/'proof/feedback3_samples.json'
UNIFIED_BASELINE='6135c6ec6'

def godot(script,*args,project=ROOT):
 result=subprocess.run([sys.executable,str(ROOT/'tools/godot_task_runner.py'),'--task-id','rr-57','--stream','--','godot','--headless','--path',str(project),'--script',script,'--',*map(str,args)],cwd=ROOT,capture_output=True,text=True,timeout=DEFAULTS['process_timeout_seconds'])
 if result.returncode:raise AssertionError(result.stdout+result.stderr)
 for line in result.stdout.splitlines():
  if line.startswith('RR48 '):print(line)
 return result

def raw_clip_sections(path,clip):
 text=path.read_text();decoder=json.JSONDecoder();result=[]
 for match in re.finditer('"'+re.escape(clip)+'"\\s*:\\s*',text):
  _,end=decoder.raw_decode(text,match.end())
  result.append(text[match.end():end].encode('utf-8'))
 return result

class ReaverTests(unittest.TestCase):
 def test_rr57_complete_weapon_release_and_donor_provenance(self):
  from rr48_weapon_proof import ownership
  from humanoid_cutout.gait_continuations import texture
  for root,production in ((CASE,False),(ASSETS/'humanoid_v2',True)):
   report=ownership(root,production);self.assertTrue(report['ok'],report['errors'])
   for view in ('front','rear'):
    layout=read_json(root/(view+'.json' if production else 'layouts/'+view+'.json'))
    for part in layout['parts']:
     if 'release_texture' not in part:continue
     held=texture(root,layout,part,clip='death',phase=.299)
     released=texture(root,layout,part,clip='death',phase=.3)
     self.assertTrue(np.array_equal(held,np.asarray(Image.open(root/part['file']).convert('RGBA'))))
     self.assertTrue(np.array_equal(released,np.asarray(Image.open(root/part['release_texture']['file']).convert('RGBA'))))
     checks=texture(root,layout,part,clip='death',phase=.3,checks=True)
     self.assertTrue(np.array_equal(checks[...,3]>0,released[...,3]>0))
     self.assertTrue(np.all(checks[...,1][checks[...,3]>0]==(255 if part.get('hidden_material') else 0)))
    self.assertEqual(next(v for v in report['views'] if v['view']==view)['whole_weapon_components'],1)
  print('RR57 WHOLE WEAPON / DONOR PROVENANCE: PASS (both views; exact source texels; release at 0.3)')

 def test_rr57_native_comparator_lists_every_differing_pixel(self):
  from rr48_weapon_proof import native_diff
  from cutout_pipeline.cases import write_json,digest
  with tempfile.TemporaryDirectory(prefix='rr57-native-diff-') as folder:
   root=Path(folder);before=root/'before';after=root/'after';before.mkdir();after.mkdir()
   image=Image.new('RGBA',FEEDBACK2_DEFAULTS['diff_fixture_size']);image.save(before/'frame.png');image.putpixel(FEEDBACK2_DEFAULTS['diff_fixture_xy'],FEEDBACK2_DEFAULTS['diff_fixture_rgba']);image.save(after/'frame.png')
   for directory in (before,after):write_json(directory/'frames.json',{'frames':[{'view':'front','clip':'idle','frame':0,'phase':0,'file':'frame.png','sha256':digest(directory/'frame.png')}]})
   report=native_diff(before,after,root/'diff.json',native_pixels=False);self.assertFalse(report['ok']);self.assertEqual(report['differing_pixels'],1);self.assertEqual(report['pixels'][0]['xy'],list(FEEDBACK2_DEFAULTS['diff_fixture_xy']));self.assertEqual(report['pixels'][0]['after'],list(FEEDBACK2_DEFAULTS['diff_fixture_rgba']))
  print('RR57 PIXEL DIFF MUTATION: PASS (each differing pixel and RGBA reported)')

 def test_rr57_r3_fills_copy_exact_own_fist_and_preserve_held_paint(self):
  from rr48_weapon_ownership import images_for,repartition
  from rr48_release_fills import fill
  for root,production in ((CASE,False),(ASSETS/'humanoid_v2',True)):
   for view in ('front','rear'):
    layout=read_json(root/(view+'.json' if production else 'layouts/'+view+'.json'));images=images_for(root,layout)
    before,_=repartition(view,images,layout,release_fills=False)
    after,domain,ledger=fill(view,before['hand_far'])
    changed=np.any(after!=before['hand_far'],axis=-1)
    self.assertFalse(np.any(changed&~domain));self.assertTrue(ledger['preserves_existing_opaque'])
    self.assertTrue(ledger['texels'])
    for texel in ledger['texels']:
     x,y=texel['to'];u,v=texel['from']
     self.assertFalse(before['hand_far'][y,x,3]);self.assertTrue(before['hand_far'][v,u,3])
     self.assertEqual(after[y,x].tolist(),before['hand_far'][v,u].tolist())
     if view=='front':self.assertEqual(after[y,x].tolist(),images['hand_far'][v,u].tolist(),'front donor must be uncovered original wrist paint')
    if view=='rear':self.assertEqual(ledger['changed_pixels'],15);self.assertEqual(ledger['widened_pixels'],0)
    else:
     self.assertEqual(ledger['request_bounds'],[110,120,118,129]);self.assertEqual(ledger['filled_domain_bounds'],[110,120,118,132])
  print('RR57 R3 EXACT FILLS: PASS (own texels; domain only; held paint preserved; front mask ends at y=132)')

 def test_rr57_native_grid_preflight_and_pixel_baseline_mutations(self):
  from rr48_native_baseline import capture_errors,compare,HeldBaseline
  from cutout_pipeline.cases import write_json,digest
  from unittest.mock import patch
  motion={'view_tracks':{'front':{}},'clips':{'idle':{'seconds':FEEDBACK3_NATIVE_FIXTURE['clip_seconds'],'loop':True}}}
  with tempfile.TemporaryDirectory(prefix='rr57-grid-') as folder:
   before=Path(folder)/'before';after=Path(folder)/'after'
   for directory in (before,after):
    (directory/'front_idle').mkdir(parents=True);frames=[]
    count=round(motion['clips']['idle']['seconds']*60)
    for f in range(count):
     name=f'front_idle/pose_{f:04d}.png';Image.new('RGBA',FEEDBACK2_DEFAULTS['diff_fixture_size']).save(directory/name)
     frames.append({'view':'front','clip':'idle','frame':f,'phase':f/count,'file':name,'sha256':digest(directory/name)})
    write_json(directory/'frames.json',{'ok':True,'errors':[],'native_pixels':True,'size':[1920,1080],'ui_scale':1,'fps':60,'inputs':{},'frames':frames})
   self.assertFalse(capture_errors(before,motion))
   baseline=HeldBaseline(compare(before,after,motion))
   hole="('front', 'idle', 1): new joint-seam hole larger than 1px"
   pose="('front', 'idle', 1): native frame differs from isolated GPU pieces"
   self.assertEqual(baseline.classify([hole,pose]),[pose]);self.assertEqual(len(baseline.findings),1)
   f=FEEDBACK3_NATIVE_FIXTURE['changed_frame'];name=f'front_idle/pose_{f:04d}.png';image=Image.open(after/name).convert('RGBA');image.putpixel(FEEDBACK2_DEFAULTS['diff_fixture_xy'],FEEDBACK2_DEFAULTS['diff_fixture_rgba']);image.save(after/name)
   manifest=read_json(after/'frames.json');manifest['frames'][f]['sha256']=digest(after/name);write_json(after/'frames.json',manifest)
   changed=HeldBaseline(compare(before,after,motion));self.assertFalse(changed.comparison['ok']);self.assertEqual(changed.classify([hole]),[hole]);self.assertFalse(changed.findings)
   (before/name).unlink()
   with patch('rr48_native_baseline.frame_digest',side_effect=AssertionError('must preflight all files first')):
    errors=capture_errors(before,motion)
   self.assertTrue(any('missing native frame: '+str(before/name)==e for e in errors),errors)
  print('RR57 NATIVE BASELINE MUTATIONS: PASS (missing file named before digest; 0 px seams classified; changed pixels and pose failures stay active)')

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
  # rr-57 carries the already-approved walk-01 clock back to the staged source.
  self.assertEqual(production,original)
  data=read_json(CASE/'compiled_motion.json');layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
  corrected=copy.deepcopy(data);corrected['projection']['rear']['forward']=[-value for value in data['projection']['front']['forward']]
  self.assertEqual(corrected,apply_recorded(motion_policy(clamp_limits(compile_motion(DIRECTOR,'ashen_reaver',layouts,corrected['projection'])),layouts)))
  self.assertTrue(data['budget_clamps']);self.assertEqual(data['elbow_policy']['max_hyperextension_deg'],2)
  bad=copy.deepcopy(data);bad['view_tracks']['front']['idle'][0]['keys'][0]['value']=900
  self.assertNotEqual(bad,data)
  print('RR48 DIRECTOR DATA: PASS (staged/case/production synchronized; walk-01 preserved; corrected projection recompiles; clamps recorded separately)')

 def test_rr57_targets_contacts_and_protected_actions(self):
  from rr48_raised_motion import BASE,TARGETS,compiled
  from rr48_raised_report import measure
  before=read_json(BASE/'baseline_compiled.json');current=read_json(CASE/'compiled_motion.json')
  self.assertEqual(current,compiled())
  self.assertEqual(current,read_json(ASSETS/'humanoid_v2/compiled_motion.json'))
  for clip in ('idle','move','hit','death'):
   self.assertEqual(current['clips'][clip],before['clips'][clip])
   for view in ('front','rear'):self.assertEqual(current['view_tracks'][view][clip],before['view_tracks'][view][clip])
   self.assertEqual(raw_clip_sections(ASSETS/'humanoid_v2/compiled_motion.json',clip),raw_clip_sections(BASE/'baseline_compiled.json',clip))
   self.assertEqual(raw_clip_sections(ASSETS/'humanoid_v2/director_motion.json',clip),raw_clip_sections(BASE/'baseline_director.json',clip))
  source=read_json(DIRECTOR)['ashen_reaver']['clips'];baseline=read_json(BASE/'baseline_director.json')['ashen_reaver']['clips']
  for clip in ('idle','move','hit','death'):self.assertEqual(source[clip],baseline[clip])
  for clip in TARGETS:
   self.assertEqual(current['clips'][clip]['seconds'],before['clips'][clip]['seconds'])
   self.assertEqual(current['clips'][clip]['contact'],before['clips'][clip]['contact'])
  feedback=read_json(BASE/'feedback1_baseline_compiled.json')
  self.assertEqual(current['view_tracks']['rear'],feedback['view_tracks']['rear'])
  self.assertEqual(current['clips'],feedback['clips'])
  self.assertEqual(current['view_tracks']['front']['rake'],feedback['view_tracks']['front']['rake'])
  for clip in TARGETS:
   for old,new in zip(feedback['view_tracks']['front'][clip],current['view_tracks']['front'][clip]):
    contact=current['clips'][clip]['contact']
    self.assertEqual([k for k in old['keys'] if k['at']>=contact],[k for k in new['keys'] if k['at']>=contact])
  with tempfile.TemporaryDirectory(prefix='rr57-exact-') as folder:
   output=Path(folder)/'samples.json';godot('res://tests/rr48/raised_attack_samples.gd','--output',output)
   report=measure(read_json(output));self.assertTrue(report['ok'],report['elbows']['errors'])
   self.assertTrue(all(p['blade_off_vertical_deg']<=(15.001 if p['view']=='front' else 10.001) for p in report['peaks'] if p['clip']=='fall'))
   self.assertTrue(all(p['blade_off_vertical_deg']<=30.01 for p in report['peaks'] if p['clip']=='sweep'))
   self.assertTrue(all(r['status']=='UNREACHABLE_fixed_arm_length' for r in report['sweep_follow']))
   self.assertTrue(all(r['max_pose_diff']==0 for r in report['feedback1_preserved_poses']))
  print('RR57 TARGETS/CONTACT/PRESERVATION: PASS (front/rear exact heights; zero contact/fall-recovery diff; idle/move/hit/death unchanged)')

 def test_rr48_raised_native_superset_rejects_missed_findings(self):
  from rr48_raised_native_superset import covers
  native={'holes':[{'bbox':[1,1,3,3],'pixel_count':4}], 'outline':[{'part':'arm_far','bbox':[4,4,6,6],'n':4}]}
  self.assertFalse(covers(native,native))
  self.assertEqual({r['kind'] for r in covers({'holes':[],'outline':[]},native)},{'hole','outline'})
  print('RR57 NATIVE SUPERSET MUTATION: PASS (missing native pockets and outlines rejected)')

 def test_feedback1_front_clearance_rejects_hidden_overlaps_and_inward_hand(self):
  from rr48_front_clearance import frame_clearance
  size=FEEDBACK1_DEFAULTS['clearance_mask_size']
  def layer(name,point):
   image=np.zeros((size,size,4),np.uint8);image[point[1],point[0],3]=FEEDBACK1_DEFAULTS['opaque_alpha']
   return ({'name':name,'z_index':0},image,np.zeros_like(image))
  row={'view':'front','clip':'fall','frame':0,'phase':.3,'bones':{'hand_far':{'global':[1,0,0,1,*FEEDBACK1_DEFAULTS['hand_joint']]},'upper_far':{'global':[1,0,0,1,*FEEDBACK1_DEFAULTS['shoulder_joint']]}}}
  motion={'clips':{'fall':{'contact':.5}}}
  layers=[layer('arm_far',FEEDBACK1_DEFAULTS['arm_pixel']),layer('hidden_head',FEEDBACK1_DEFAULTS['clear_helm_pixel']),layer('hand_far',FEEDBACK1_DEFAULTS['hand_pixel']),layer('falchion',FEEDBACK1_DEFAULTS['blade_pixel'])]
  self.assertFalse(frame_clearance(row,layers,motion)['failures'])
  layers[1]=layer('hidden_head',FEEDBACK1_DEFAULTS['arm_pixel']);self.assertEqual(frame_clearance(row,layers,motion)['arm_helm_overlap_px'],1)
  layers[1]=layer('head',FEEDBACK1_DEFAULTS['blade_pixel']);self.assertEqual(frame_clearance(row,layers,motion)['blade_helm_overlap_px'],1)
  row['bones']['hand_far']['global'][4]=FEEDBACK1_DEFAULTS['inward_hand_x'];self.assertEqual(frame_clearance(row,layers,motion)['inward_violation_px'],1)
  print('RR57 FRONT CLEARANCE MUTATIONS: PASS (pre-occlusion arm/hidden-helm overlap, blade overlap and inward wrist rejected)')

 def test_all_frames_elbows_and_held_item_and_mutations(self):
  with tempfile.TemporaryDirectory(prefix='rr48-samples-') as folder:
   output=Path(folder)/'samples.json'
   godot('res://tests/rr48/samples.gd','--case',CASE,'--output',output)
   samples=read_json(output);data=read_json(CASE/'compiled_motion.json')
   report=elbow_errors(data,samples);self.assertTrue(report['ok'],report['errors'][:5])
   for row in samples['samples']:
    if row['view']=='front' and row['clip'] in ('rake','sweep','fall') and row['phase']<=data['clips'][row['clip']]['contact']:
     self.assertLessEqual(row['bones']['hand_far']['global'][4],row['bones']['upper_far']['global'][4]-4+.001)
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
