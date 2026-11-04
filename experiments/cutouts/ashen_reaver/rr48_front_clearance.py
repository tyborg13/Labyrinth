"""Pre-occlusion painted arm/helm proof for the director's front wind-ups."""
import argparse
from pathlib import Path
import numpy as np
from rr48_build import CASE
from rr48_front_windup import CONSTRAINTS
from cutout_pipeline.cases import read_json, write_json

ATTACKS = ('rake','sweep','fall')
SERIALIZED_TOLERANCE_PX = .001


def frame_clearance(row, layers, motion):
    if row['view']!='front' or row['clip'] not in ATTACKS or row['phase']>motion['clips'][row['clip']]['contact']:
        return None
    masks={name:np.zeros(layers[0][1].shape[:2],bool) for name in ('arm','helm','blade')}
    for part,image,_ in layers:
        logical=part.get('logical_part',part['name'].removeprefix('hidden_'))
        group='arm' if logical in ('arm_far','hand_far') else 'helm' if logical=='head' else 'blade' if logical=='falchion' else None
        if group:masks[group]|=image[...,3]>0
    hand=row['bones']['hand_far']['global'][4:];shoulder=row['bones']['upper_far']['global'][4:]
    limit=shoulder[0]-CONSTRAINTS['hand_outside_shoulder_px']
    result={k:row[k] for k in ('view','clip','frame','phase')}
    result.update(hand_x=hand[0],shoulder_x=shoulder[0],hand_limit_x=limit,
                  inward_violation_px=max(0.,hand[0]-limit),
                  arm_helm_overlap_px=int((masks['arm']&masks['helm']).sum()),
                  blade_helm_overlap_px=int((masks['blade']&masks['helm']).sum()),
                  hand_below_shoulder_px=hand[1]-shoulder[1])
    failures=[]
    if result['inward_violation_px']>SERIALIZED_TOLERANCE_PX:failures.append('hand_inward')
    if result['arm_helm_overlap_px']:failures.append('arm_helm_overlap')
    if row['clip'] in ('sweep','fall') and result['blade_helm_overlap_px']:failures.append('blade_helm_overlap')
    result['failures']=failures
    return result


def summarize(records):
    rows=[r for r in records if r is not None]
    failures=[r for r in rows if r['failures']]
    return {'ok':not failures,'native_pixels':False,'frames':rows,'failures':failures,
            'max_inward_violation_px':max((r['inward_violation_px'] for r in rows),default=0),
            'max_arm_helm_overlap_px':max((r['arm_helm_overlap_px'] for r in rows),default=0),
            'max_blade_helm_overlap_px':max((r['blade_helm_overlap_px'] for r in rows if r['clip'] in ('sweep','fall')),default=0),
            'method':'Every painted far-arm/gauntlet layer against head+hidden_head, before draw-order occlusion; native-origin calibrated CPU raster'}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--sweep',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    sweep=read_json(args.sweep);report=summarize([r.get('front_clearance') for r in sweep['frames']]);write_json(args.output,report)
    print('RR57 FRONT WINDUP:', 'PASS' if report['ok'] else 'FAIL',f"({len(report['frames'])} frames; hand violation {report['max_inward_violation_px']:.6f} px; arm/helm overlap {report['max_arm_helm_overlap_px']} px; blade/helm overlap {report['max_blade_helm_overlap_px']} px)")
    raise SystemExit(0 if report['ok'] else 1)
