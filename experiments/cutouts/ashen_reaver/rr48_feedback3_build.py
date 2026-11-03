"""Feedback-3 source supply and approved targets on the unified runtime."""
from rr48_build import CASE,ASSETS,ROOT,VIEWS
from rr48_feedback2 import apply as build_source
from rr48_feedback2_source import ROUND1
from rr48_feedback1 import motion_policy
from rr48_motion import clamp_limits
from rr48_budget_search import apply_recorded
from rr48_build import DIRECTOR
from humanoid_cutout.compiler import compile_motion
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.promotion import promote

def apply():
 build_source();layouts={}
 for view in VIEWS:
  layout=read_json(CASE/f'layouts/{view}.json')
  layout['held_follow_reference_frames']={'move':'body'}
  layout['held_items']['falchion'].update(follow_reference_bone='pelvis',follow_hand_joint=True,follow_zero_at_end=True,follow_limit_deg=35.0)
  layouts[view]=layout
  write_json(CASE/f'layouts/{view}.json',layout)
 projection=read_json(ROUND1/'compiled_motion.json')['projection']
 data=apply_recorded(motion_policy(clamp_limits(compile_motion(DIRECTOR,'ashen_reaver',layouts,projection)),layouts))
 write_json(CASE/'compiled_motion.json',data)
 anatomy=read_json(CASE/'anatomy.json');anatomy['integration']['owner_approval']='reaver-paint-3; rr-48 feedback 3 director instructions; native proof pending';write_json(CASE/'anatomy.json',anatomy)
 promote(ROOT,CASE,ASSETS/'humanoid_v2',layouts)
 print('RR48 FEEDBACK 3 BUILD: full director receiver domains; approved 14/9 degree pendulums; unified body-frame follow')

if __name__=='__main__':apply()
