"""Reproduce independent-channel proof candidates without touching production.

These are failed/partial experiments, not final clamps. Full-frame pixel gates
and director native judgment remain mandatory before applying any candidate.
"""
import argparse
from pathlib import Path
from rr38_case import CASE
from rr38_limit_search import prepare,sample
from cutout_pipeline.cases import read_json,write_json

CONFIG=CASE.parent/'rr38_feedback3_channel_probes.json'


def build(base,output,clip,frames=None,hip_drop=None):
    output=Path(output).resolve()
    output.relative_to((CASE/'proof').resolve())
    prepare(base,output,clip,1)
    scales=read_json(CONFIG)[clip].copy()
    data=read_json(output/'compiled_motion.json')
    if hip_drop is not None:
        track=next(t for t in data['view_tracks']['front'][clip] if t['source']=='pelvis.lift_px')
        peak=max(abs(k['value']) for k in track['keys'])
        scales['pelvis.lift_px']=hip_drop/peak
    peaks={}
    for view in data['view_tracks']:
        peaks[view]={}
        for track in data['view_tracks'][view][clip]:
            factor=scales.get(track['source'],1)
            if not 0<=factor<=1:raise ValueError('Proof scales must stay between rest and protected target')
            for key in track['keys']:key['value']*=factor
            values=[k['value'] for k in track['keys']]
            peaks[view][track['source']]=[min(values),max(values)]
    write_json(output/'compiled_motion.json',data)
    write_json(output/'channel_scales.json',scales)
    write_json(output/'channel_peaks.json',peaks)
    sample(output,clip,frames)
    print('RR38 INDEPENDENT CHANNEL POSES: WRITTEN (proof only; no acceptance claimed)')
    return output


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--clip',choices=('press','death'),required=True)
    p.add_argument('--frames',help='Comma-separated presented frames; omitted samples the complete clip')
    p.add_argument('--hip-drop',type=float,help='Proof-only hip-drop target, toward rest')
    a=p.parse_args()
    build(a.case.resolve(),a.output,a.clip,None if a.frames is None else [int(f) for f in a.frames.split(',')],a.hip_drop)
