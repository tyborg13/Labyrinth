"""Opt-in native policy; all other native/source/component guards stay active."""
from rr48_feedback3_cpu import model
from rr48_feedback3_policy import DirectorPolicy,temporal
from rr48_joint_budget import pose_layers
from cutout_pipeline.cases import read_json,write_json

class NativeDirectorPolicy:
 def __init__(self,case,layout):
  self.case=case;self.model=model(case,layout['facing']);self.policy=DirectorPolicy(self.model)
  self.rows={(r['view'],r['clip'],r['frame']):r for r in read_json(case/'proof/raster_samples.json')['samples']}
  self.motion=read_json(case/'compiled_motion.json');self.air=[]

 def row(self,pose):return self.rows[pose['view'],pose['clip'],pose['frame']]

 def metrics(self,layers,pose,metric):
  row=self.row(pose);_,maps=pose_layers(self.model,row,self.motion)
  # Exact source-coordinate UV candidates only; this never changes dark slabs.
  value=self.policy.metrics(layers,row,maps,native=True)
  return dict(metric,exposed_outline_pixels=value['exposed_outline_pixels'])

 def space(self,occupied,pose):
  space=self.policy.space(occupied,self.row(pose));self.air+=space['air_pockets']
  # Small holes are deferred until every consecutive frame is known.
  return dict(space,failures=[r for r in space['failures'] if r['pixel_count']>4])

 def finish(self):
  failures,accepted=temporal(self.policy.pockets)
  write_json(self.case/f'proof/logs/native_director_{self.model.layout["facing"]}.json',{'outline':self.policy.outline_records,'natural_negative_space':self.air,'remaining_tears':failures,'accepted_short_tears':accepted,'native_pixels':True})
  return [f'{r["view"]}/{r["clip"]}/{r["frame"]}: persistent director-underlay hole {r["bbox"]} ({r["pixel_count"]} px)' for r in failures if r['pixel_count']<=4]
