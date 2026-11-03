"""Director constraints added in feedback 3; no authored values invented."""
from rr48_build import DIRECTOR
from cutout_pipeline.cases import read_json

def walk_arm_errors(data):
 approved=read_json(DIRECTOR)['ashen_reaver']['clips']['move']['gait']['arm_swing']
 actual=data['clips']['move']['gait']['arm_swing'];errors=[]
 for side in ('near','far'):
  if actual[side]['upper_deg']!=approved[side]['upper_deg']:errors.append('Walk '+side+' arm is below the approved full excursion')
 return errors
