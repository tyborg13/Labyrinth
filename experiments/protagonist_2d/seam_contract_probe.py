"""Check seventh-pass garment coverage and preservation of the accepted motion.

Known hollow boot collars must be absent from the rigid shoe paint, and the
trouser cuff must be in front. Pixel/pose checks cannot establish visual quality;
the real-renderer boot, knee and cloak comparisons remain the acceptance proof.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from PIL import Image
from registered_contract_probe import sha, expanded, overlap

HERE = Path(__file__).resolve().parent
BASE = HERE / 'references/pass7/baseline'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pose-matrices', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=HERE/'renders/pass7/seam_validation.json')
    args = parser.parse_args()
    failures, records = [], []
    protected = json.loads((BASE/'baseline.json').read_text())
    for name, expected in protected['protected_sha256'].items():
        if sha(HERE/name) != expected:
            failures.append('Accepted motion, arm, glove or sword art changed: '+name)
    before = json.loads((HERE/'renders/pass6/pose_matrices.json').read_text())
    after = json.loads(args.pose_matrices.read_text())
    for resource, expected in after['input_sha256'].items():
        if sha(HERE.parents[1]/resource.removeprefix('res://')) != expected:
            failures.append('Stale pose matrices: '+resource)
    if len(before['samples']) != len(after['samples']):
        failures.append('Authored pose count changed')
    identical_poses = 0
    for a,b in zip(before['samples'], after['samples']):
        if a['facing'] != b['facing'] or a['clip'] != b['clip'] or a['bones'] != b['bones']:
            failures.append('Existing bone curves changed')
        else:
            identical_poses += 1
    for facing in ['front','rear']:
        suffix = '' if facing == 'front' else '_rear'
        previous = json.loads((BASE/f'cutout_layout{suffix}.json').read_text())
        current = json.loads((HERE/f'cutout_layout{suffix}.json').read_text())
        old = {p['name']:p for p in previous['parts']}
        parts = {p['name']:p for p in current['parts']}
        if previous['joints'] != current['joints']:
            failures.append(facing+': bone registration changed')
        for name in ['head','scarf','torso','hips','pelvis_underlay','arm_r','arm_l','hand_r','hand_l','weapon_r','mantle_near','mantle_far']:
            if old[name] != parts[name]:
                failures.append(facing+': unrelated attachment changed: '+name)
        if previous['joint_meshes'] != current['joint_meshes']:
            failures.append(facing+': sleeve/shoulder deformation changed')
        for side in ['r','l']:
            if not parts['foot_'+side]['z_index'] < parts['shin_'+side]['z_index']:
                failures.append(facing+': boot draws over trouser cuff')
            points,_ = overlap(expanded(parts['shin_'+side]), expanded(parts['foot_'+side]))
            if len(points) < 8:
                failures.append(facing+': calf and boot lack opaque overlap: '+side)
            cover = parts.get('knee_cover_'+side, {})
            if cover.get('bone') != 'shin_'+side or cover.get('equipment_slot') != 'legs':
                failures.append(facing+': knee cover has incorrect attachment')
            records.append({'facing':facing,'joint':'ankle_'+side,'rest_overlap_pixels':len(points), 'foreground':'trouser cuff'})
        # Pixel coordinates identify the opening visible in the pass-six art,
        # independently of the builder's trim limits. Toes/soles are excluded.
        box = (153,190,169,198) if facing == 'front' else (88,181,102,188)
        shoe = expanded(parts['foot_l'])
        remaining = sum(shoe.getpixel((x,y))[3] > 0 for x in range(box[0],box[2]) for y in range(box[1],box[3]))
        if remaining:
            failures.append(facing+': retained pixels in the visibly empty boot collar')
        records.append({'facing':facing,'empty_boot_collar_rect':list(box),'remaining_rigid_boot_pixels':remaining})
        cape = current['cape_mesh']
        if facing == 'front' and previous['cape_mesh'] != cape:
            failures.append('Front cape changed outside the requested rear fix')
        if facing == 'rear':
            if not max(parts[n]['z_index'] for n in ['mantle_near','mantle_far','arm_r','arm_l']) < cape['z_index'] < parts['scarf']['z_index']:
                failures.append('Rear drape does not cover shoulder seams below scarf')
            # Its upper cloth must overlap shoulder-level cloth, not begin at
            # the chest with a second floating neckline.
            shoulder = expanded(parts['mantle_near'])
            points,_ = overlap(shoulder, expanded(cape))
            high = sum(y <= current['joints']['arm_r']['position'][1] for _,y in points)
            if high < 50:
                failures.append('Rear cape lacks shoulder-level painted overlap')
            records.append({'facing':facing,'joint':'cloak_shoulder','overlapping_pixels_at_or_above_shoulder':high})
    report = {'pass':7,'baseline_commit':protected['commit'],'motion_sha256':sha(HERE/'cutout_motion.gd'),
              'pose_input_sha256':after['input_sha256'],
              'identical_existing_bone_poses':identical_poses,'coverage':records,'failures':failures,'passed':not failures,
              'limits':'Coverage and exact preservation support, but cannot replace, visual review of dressed anatomy.'}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    main()
