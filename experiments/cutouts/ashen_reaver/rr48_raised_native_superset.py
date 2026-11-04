"""Fail closed unless fresh CPU findings cover every native attack finding.

Run after rr48_proof.sh native on the director's windowed renderer. A CPU-only
run cannot certify this result or supply a native-clean joint budget.
"""
import argparse
from collections import defaultdict
from pathlib import Path
import numpy as np
from rr48_build import VIEWS
from rr48_feedback3_cpu import model, frame, box, contains
from rr48_raised_motion import TARGETS
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import bindings, clean_metrics
from humanoid_cutout.native_frames import load_frame
from maquette_motion.silhouette import holes
from maquette_motion.material_palette import outline_class, rules
from rr48_front_clearance import frame_clearance


def covers(cpu, native):
    missing = []
    for pocket in native['holes']:
        if not any(contains(p['bbox'], pocket['bbox']) and p['pixel_count'] >= pocket['pixel_count'] for p in cpu['holes']):
            missing.append({'kind': 'hole', 'native': pocket, 'cpu': cpu['holes']})
    for outline in native['outline']:
        if not any(p['part'] == outline['part'] and contains(p['bbox'], outline['bbox']) and p['n'] >= outline['n'] for p in cpu['outline']):
            missing.append({'kind': 'outline', 'native': outline, 'cpu': cpu['outline']})
    return missing


def audit(case, capture):
    manifest = read_json(capture/'frames.json'); samples = read_json(case/'proof/raster_samples.json')
    bound = bindings(case)
    if not manifest.get('native_pixels') or manifest.get('size') != [1920,1080] or manifest.get('ui_scale') != 1:
        raise ValueError('Fresh 1920x1080 / 100% native proof required')
    if manifest.get('inputs') != bound or samples.get('inputs') != bound or samples.get('compiled_sha256') != digest(case/'compiled_motion.json'):
        raise ValueError('Stale CPU/native inputs')
    motion = read_json(case/'compiled_motion.json')
    rows = {(r['view'],r['clip'],r['frame']): r for r in samples['samples'] if r['clip'] in TARGETS}
    native = defaultdict(list)
    for row in manifest['pieces']:
        if row['clip'] in TARGETS: native[row['view'],row['clip'],row['frame']].append(row)
    if set(rows) != set(native): raise ValueError('Incomplete native/CPU attack frame coverage')
    missing = []; coverage = []; front_findings = []; front_frames = []
    with for_case(case):
        for view in VIEWS:
            m = model(case, view); definition = rules(case, view)
            for key, row in rows.items():
                if key[0] != view: continue
                records = native[key]; parts = {p['name']: p for p in m.layout['parts']}
                if {r['name'] for r in records} != set(parts): raise ValueError('Incomplete native layers: '+str(key))
                layers = [(parts[r['name']], np.asarray(load_frame(capture/r['file']).convert('RGBA')),
                           np.asarray(load_frame(capture/r['checks']).convert('RGBA'))) for r in records]
                occupied = np.zeros(layers[0][1].shape[:2], bool); outline = []
                for p, im, checks in sorted(layers, key=lambda r:r[0]['z_index'], reverse=True):
                    alpha = im[...,3] > 0
                    dark = alpha & ~occupied & (checks[...,1]>0) & outline_class(im, definition)
                    if dark.any(): outline.append({'part':p['name'], 'n':int(dark.sum()), 'bbox':box(dark)})
                    occupied |= alpha
                observed = {'holes':[{'bbox':box(mask), 'pixel_count':int(mask.sum())} for mask in holes(occupied)], 'outline':outline}
                cpu, cpu_layers, _ = frame(m, row, motion)
                cpu_occupied = np.logical_or.reduce([im[...,3]>0 for _,im,_ in cpu_layers])
                # Persistent 1 px holes can fail the temporal gate, too.
                cpu['holes'] = [{'bbox':box(mask),'pixel_count':int(mask.sum())} for mask in holes(cpu_occupied)]
                findings = covers(cpu, observed)
                guard=frame_clearance(row,layers,motion)
                if guard:
                    front_frames.append(guard)
                    if guard['failures']:front_findings.append(guard)
                    cpu_guard=frame_clearance(row,cpu_layers,motion)
                    for field in ('arm_helm_overlap_px','blade_helm_overlap_px'):
                        if guard[field]>cpu_guard[field]:findings.append({'kind':field,'native':guard[field],'cpu':cpu_guard[field]})
                native_metric = clean_metrics(layers, definition); cpu_metric = clean_metrics(cpu_layers, definition)
                for name in ('dark_slab_blocks',):
                    if cpu_metric[name] < native_metric[name]: findings.append({'kind':name,'native':native_metric[name],'cpu':cpu_metric[name]})
                missing.extend(dict(view=view, clip=key[1], frame=key[2], **f) for f in findings)
                coverage.append({'view':view,'clip':key[1],'frame':key[2], 'native_pockets':len(observed['holes']),
                                 'native_outline_records':len(outline), 'misses':len(findings)})
    if bindings(case) != bound: raise ValueError('Inputs changed during CPU/native audit')
    return {'ok':not missing and not front_findings,'native_pixels':True,'coverage':coverage,'missing':missing,'inputs':bound,
            'front_windup_frames':front_frames,'front_windup_findings':front_findings,
            'native_manifest_sha256':digest(capture/'frames.json'),'raster_samples_sha256':digest(case/'proof/raster_samples.json'),
            'rule':'Every raw native cavity, continuation-outline record and dark slab must be covered by CPU before accepting a native-clean budget.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',type=Path,required=True); parser.add_argument('--native',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True); args = parser.parse_args()
    report = audit(args.case,args.native); write_json(args.output,report)
    print('RR57 CPU SUPERSET NATIVE:', 'PASS' if report['ok'] else 'FAIL', len(report['coverage']), 'frames;',len(report['missing']),'misses;',len(report['front_windup_findings']),'front wind-up failures')
    raise SystemExit(0 if report['ok'] else 1)
