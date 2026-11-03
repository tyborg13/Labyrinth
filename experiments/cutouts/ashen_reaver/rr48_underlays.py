"""Record required covered-edge paint without manufacturing any texels."""
import numpy as np
from PIL import Image
from rr48_build import CASE,ASSETS,VIEWS
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.tucks import required_tuck
from maquette_motion.features import source_pixels

def record_tucks():
 anatomy=read_json(CASE/'anatomy.json');joins=anatomy['seam_joins']
 names=read_json(CASE/'layouts/front.json')['source_labels']
 anatomy['tucks']={'base_px':3,'pieces':{n:{'depth_px':3,'covers':sorted({b if a==n else a for a,b in joins if n in (a,b)}),'mode':'radial'} for n in names}}
 write_json(CASE/'anatomy.json',anatomy);build=read_json(CASE/'proof/build.json')
 for view in VIEWS:
  layout=read_json(CASE/f'layouts/{view}.json');visible={p['name']:source_pixels(CASE,p) for p in layout['parts']}
  records=[]
  for name,policy in anatomy['tucks']['pieces'].items():
   mask=required_tuck(name,visible,layout['joints'],anatomy['tucks'])
   path=CASE/f'tucks/{view}_{name}.png';path.parent.mkdir(exist_ok=True);Image.fromarray(mask.astype('uint8')*255).save(path)
   records.append({'piece':name,'minimum_px':3,'cover':policy['covers'],'required_mask':str(path.relative_to(CASE)),'required_pixels':int(mask.sum()),'missing_pixels':int(mask.sum()),'status':f'TODO_DESIGN_underlay_{view}_{name}'})
  build['views'][view]['tucks']=records
 build.update(build['views']['front'])
 write_json(CASE/'proof/build.json',build)
 path=CASE/'inputs.json';inputs=read_json(path);inputs['design_placeholders']['TODO_DESIGN_held_follow_reference_frame']='The literal source-space grip displacement includes root travel, leaving the falchion tilted at move end; the binding 35 degree limit is enforced. Director must clarify whether displacement should instead be measured relative to the moving root.';inputs['design_placeholders']['TODO_DESIGN_falchion_death_floor_pose']='Supplied terminal -80 degree target does not lie flat for the approved painted blade; fixed floor-contact pivot leaves some painted texels below the floor. No replacement angle, paint or motion was invented; director correction needed.';inputs['design_placeholders']['TODO_DESIGN_idle_free_fist_stationary']='Idle note says the free fist stays still, while binding spec and torso parenting carry the free arm with the upper-body bob; implemented supplied hierarchy/channels pending director clarification.';inputs['design_placeholders']['TODO_DESIGN_joint_budget_underlays']='Painted no-tear excursion budgets remain unmeasurable until director underlays/tucks arrive; angular spec clamps are recorded, target reach is reported separately.';write_json(path,inputs)
 print('RR48 TUCK REQUESTS: recorded 3 px requirements; missing paint remains transparent')

if __name__=='__main__':record_tucks()
