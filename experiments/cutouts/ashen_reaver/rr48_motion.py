"""Binding spec limits applied to compiled channels; never edits director data."""
def clamp_limits(data):
 rows=[]
 for view,clips in data['view_tracks'].items():
  for clip,tracks in clips.items():
   for track in tracks:
    limit=None
    if track['source']=='torso.lean_deg':limit=25 if clip=='death' else 4
    if track['source']=='head.lean_deg':limit=20 if clip=='death' else 6
    if track['source']=='falchion.angle_deg' and clip!='death':limit=35
    if limit is None:continue
    for key in track['keys']:
     target=key['value'];value=max(-limit,min(limit,target))
     if value!=target:
      rows.append({'view':view,'clip':clip,'source':track['source'],'at':key['at'],'target':target,'clamped':value,'budget_note':'Binding humanoid v2 angular budget; no director source rewrite'})
      key['value']=value
 if rows:data['budget_clamps']=rows
 return data
