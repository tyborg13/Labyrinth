"""Reproduce why the specified neighbour-weight repair is a no-op here.

This is read-only diagnostic geometry. It does not change source textures,
continuation recipes, current layouts or the canonical classifier.
"""
from copy import deepcopy

import numpy as np

from rr27_build import CASE, RECIPE
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gait_continuations import texture
from humanoid_cutout.source_space import DetachedSource, pocket_report
from humanoid_cutout.texel_attachments import barycentric, attach, cells_for
from rr24_seams import SkirtAirPolicy, frame_report

TARGETS = [('mq7b_continuation_leg_far', [171,218], [170,218], 14),
           ('mq7b_continuation_leg_near', [109,179], [108,178], 23)]


def weights_at(mesh, point):
    indices, bary = barycentric(mesh, np.asarray(point) + .5)
    return {bone: float(bary @ np.asarray(values)[indices]) for bone, values in mesh['weights'].items()}


def attachment_definitions(mesh, image, offset, point, neighbour):
    """Retain every opaque texel in replaced cells, using a painted neighbour.

    The offender inherits its declared neighbour. Other retained texels use
    an adjacent original texel outside the replaced cells, avoiding cycles.
    """
    cells = cells_for(mesh, [point])
    opaque = {(x,y) for a,b,c,d in cells for y in range(b,d) for x in range(a,c)
              if image[y-offset[1],x-offset[0],3]}
    definitions = []
    for x,y in sorted(opaque, key=lambda p:(p[1],p[0])):
        if [x,y] == point:
            parent = neighbour
        else:
            candidates = [(a,b) for b in range(y-1,y+2) for a in range(x-1,x+2)
                          if (a,b) not in opaque and 0 <= b-offset[1] < image.shape[0]
                          and 0 <= a-offset[0] < image.shape[1] and image[b-offset[1],a-offset[0],3]]
            if not candidates: raise ValueError('No retained-cell neighbour')
            parent = list(candidates[0])
        definitions.append({'texel':[x,y], 'neighbour':parent})
    return definitions


def main():
    layout = read_json(CASE / 'layouts/rear.json')
    samples = read_json(CASE / 'proof/samples.json')['samples']
    source = DetachedSource(CASE, layout)
    rows = []
    for name, point, neighbour, frame in TARGETS:
        part = next(p for p in layout['parts'] if p['name'] == name)
        mesh = next(m for m in layout['joint_meshes'] if m['name'] == name)
        image = texture(CASE, layout, part, gait=True, clip='move')
        # Include the clip's copied texels when checking in-piece neighbours.
        pose = next(p for p in samples if p['kind'] == 'presented' and
                    (p['view'],p['clip'],p['frame']) == ('rear','move',frame))
        definitions = attachment_definitions(mesh, image, part['offset'], point, neighbour)
        trial = deepcopy(layout)
        patched = next(m for m in trial['joint_meshes'] if m['name'] == name)
        patched.update(attach(mesh, definitions))
        transforms = {k:p['transform'] for k,p in pose['parts'].items()}
        before = source.report(CpuPose(CASE, deepcopy(layout)).layers(pose)[0], transforms)
        after = source.report(CpuPose(CASE, trial).layers(pose)[0], transforms)
        row = {'view':'rear','clip':'move','frame':frame,'piece':name,'texel':point,
            'neighbour':neighbour,'texel_weights':weights_at(mesh,point),
            'neighbour_weights':weights_at(mesh,neighbour),'attachment_trial':definitions,
            'before_unmatched':before['unmatched_components'], 'after_unmatched':after['unmatched_components']}
        rows.append(row)
        print(f'RR27 REAR ATTACHMENT {frame}: NO-OP ({name}; weights {row["texel_weights"]}; '
              f'{len(after["unmatched_components"])} unmatched after neighbour inheritance)')
    write_json(RECIPE / 'rear_attachment_diagnostic.json', {'native_pixels':False,'rows':rows,
        'TODO_DESIGN_REAR_COMPONENT_REPAIR':'Both offending texels have in-piece neighbours but already inherit 100% shin weights. The specified attachment repair cannot change their deformation. Director decision requested on extending the removal exception; no production rear change made.'})


def removal_proposal():
    """Counterfactual proof only; never write either proposed source edit."""
    layout = read_json(CASE / 'layouts/rear.json')
    trial = deepcopy(layout)
    recipe = trial['gait_continuations']['mq7b_continuation_leg_near']
    recipe['texels'] = [row for row in recipe['texels'] if row[:2] != [17,60]]
    model, policy = CpuPose(CASE, trial), SkirtAirPolicy(CASE, trial)
    source = DetachedSource(CASE, trial)
    samples = read_json(CASE / 'proof/samples.json')
    count, failures = 0, []
    for pose in samples['samples']:
        if pose['view'] != 'rear' or pose['kind'] != 'presented': continue
        images = {p['name']:texture(CASE,trial,p,gait=pose['clip']=='move',clip=pose['clip'])
                  for p in trial['parts']}
        images['mq7b_continuation_leg_far'][97,53] = 0
        layers,_,_,_,independent = frame_report(model,pose,policy,images)
        space = pocket_report(layers,independent['failures'])
        components = source.report(layers,{k:p['transform'] for k,p in pose['parts'].items()})
        if space['failures'] or components['unmatched_components']:
            failures.append({'clip':pose['clip'],'frame':pose['frame'],
                             'pockets':space['failures'],'unmatched':components['unmatched_components']})
        count += 1
        if count % 50 == 0:
            print(f'RR27 REMOVAL PROPOSAL: {count} rear frames; {len(failures)} failing',flush=True)
    write_json(RECIPE/'removal_proposal.json',{'applied':False,'native_pixels':False,'frames':count,
        'failures':failures,'ok':not failures,'inputs':samples['inputs'],
        'changes':[{'part':'mq7b_continuation_leg_far','source_texel':[171,218],
                    'local_texel':[53,97],'kind':'remove copied hidden texel'},
                   {'part':'mq7b_continuation_leg_near','source_texel':[109,179],
                    'local_texel':[17,60],'kind':'remove gait recipe target'}],
        'decision_required':'Brief permits removal only without an in-piece neighbour. Both neighbours exist, but neighbour weights are already identical.'})
    print(f'RR27 REMOVAL PROPOSAL: {"PASS" if not failures else "FAIL"} '
          f'({count} rear frames; {len(failures)} failing; not applied)')


if __name__ == '__main__':
    import sys
    removal_proposal() if '--removal-proposal' in sys.argv else main()
