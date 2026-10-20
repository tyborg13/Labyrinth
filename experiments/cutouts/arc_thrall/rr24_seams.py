"""Thrall-only source-air and rendered head/collar ownership policies.

Native callers supply GPU-isolated surfaces; headless callers supply CPU
diagnostic surfaces. Both use the immutable allowed-paint/tuck masks for
source classification, never the possibly damaged current texture alpha.
"""
import numpy as np
from PIL import Image

from rr24_build import CASE, PROJECT, read_json, digest
from tools.humanoid_cutout.anatomy import load, owner_ids
from tools.humanoid_cutout.cpu_pose import sprite_transform
from tools.humanoid_cutout.silhouette_gates import joint_holes, posed_owners
from maquette_motion.pixels import PROOF_DEFAULTS
from maquette_motion.silhouette import holes, dilate

POLICY_NAME = 'approved_source_air_between_skirt_and_legs'


def head_ownership(layers):
    """Compare rendered visible head/body ownership, allowing all contact.

    Covered neck continuations stay covered, as in the source painting. The
    head's actual visible paint must win every head/collar overlap. Checking
    the whole torso is stronger than checking only its collar pixels.
    """
    head = next(row for row in layers if row[0]['name'] == 'head')
    body = next(row for row in layers if row[0]['name'] == 'torso')
    contact = (head[1][...,3] > 0) & (body[1][...,3] > 0)
    owned = np.zeros(contact.shape, dtype=np.uint8)
    for part,image,_ in sorted((head,body),key=lambda row:row[0]['z_index']):
        owned[image[...,3] > 0] = 1 if part['name'] == 'head' else 2
    covered = contact & (owned != 1)
    ys,xs = np.nonzero(contact)
    return {'ok':not covered.any(), 'contact_pixels':int(contact.sum()),
        'collar_over_head_pixels':int(covered.sum()),
        'contact_bounds':([int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1] if len(xs) else None)}


class SkirtAirPolicy:
    def __init__(self, case, layout):
        self.case, self.layout = case, layout
        policy = read_json(case / 'rr24_policy.json')
        for relative,expected in policy.get('implementation_sha256',{}).items():
            if digest(PROJECT/relative)!=expected:
                raise ValueError('Stale Thrall policy implementation binding: '+relative)
        if policy['seams']['policy'] != POLICY_NAME:
            raise ValueError('Explicit Thrall skirt-air policy required')
        self.ids = owner_ids(load(case)['ownership'])
        self.skirt = set(policy['seams']['skirt_owners'])
        self.legs = set(policy['seams']['leg_owners'])
        self.allowed = {}
        for part in layout['parts']:
            record = layout['proof_layers'][part['name']]
            image = np.asarray(Image.open(case / record['mask']).convert('RGBA'))
            self.allowed[part['name']] = image[...,0] > 0

    @staticmethod
    def sample(mask, uv):
        x,y = uv.T
        inside = (x>=0)&(y>=0)&(x<mask.shape[1])&(y<mask.shape[0])
        result = np.zeros(len(uv),dtype=bool)
        result[inside] = mask[y[inside],x[inside]]
        return result

    def classify(self, pocket, pose, maps, allowed_layers=None):
        """Every inverse fragment of every piece must be outside paint/tuck."""
        ys,xs = np.nonzero(pocket)
        blocked = np.zeros(len(xs),dtype=bool)
        lookup = np.full(pocket.shape,-1,dtype=np.int32)
        lookup[ys,xs] = np.arange(len(xs))
        points = np.column_stack((xs+.5-PROOF_DEFAULTS['source_offset'],
                                  ys+.5-PROOF_DEFAULTS['source_offset']))
        traces = {}
        for part in self.layout['parts']:
            name = part['name']; mask = self.allowed[name]
            if pose['clip']=='move' and name in self.layout.get('gait_continuations',{}):
                mask = mask.copy()
                for x,y,_,_ in self.layout['gait_continuations'][name]['texels']: mask[y,x] = True
            if allowed_layers is not None:
                painted = allowed_layers[name][ys,xs]
                blocked |= painted
                traces[name] = {'painted_or_tuck_fragments':int(painted.sum()),
                               'source_evidence':'GPU transport of immutable allowed-paint/tuck mask'}
                continue
            if name in maps:
                mapping = maps[name]
                index = lookup[mapping.pixels[:,1],mapping.pixels[:,0]]
                keep = index >= 0
                indices, uv = index[keep], mapping.texels[keep]
            else:
                inverse = np.linalg.inv(sprite_transform(self.layout,pose,part))
                local = points @ inverse[:2,:2].T + inverse[:2,2]
                uv = np.rint(local.astype(np.float32)-.5).astype(int)
                indices = np.arange(len(xs))
            painted = self.sample(mask,uv)
            blocked[indices[painted]] = True
            if painted.any() or part['logical_part'] in ('loincloth','leg_near','leg_far'):
                traces[name] = {'painted_or_tuck_fragments':int(painted.sum()),
                               'source_points':(uv + part['offset']).tolist()}
        return blocked, traces

    def report(self, occupied, owners, seam, references, pose, maps, allowed_layers=None):
        strict = joint_holes(occupied,seam,owners,references,pocket_details=True)
        strict_by_box = {tuple(row['bbox']):row for row in strict}
        failures, passed = [], []
        for pocket in holes(occupied):
            ys,xs = np.nonzero(pocket)
            box = [int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
            rim = owners[dilate(pocket,1)&occupied]
            surrounding = {name for name,value in self.ids.items() if value in rim}
            eligible = (bool(surrounding & self.skirt) and bool(surrounding & self.legs)
                        and surrounding <= self.skirt | self.legs)
            scoped_surface = bool(surrounding) and surrounding <= self.skirt | self.legs
            if eligible or scoped_surface:
                blocked,traces = self.classify(pocket,pose,maps,allowed_layers)
                record = {'bbox':box,'pixel_count':len(xs),'painted_or_tuck_pixels':int(blocked.sum()),
                    'surrounding_pieces':sorted(surrounding),'checked_pieces':len(self.layout['parts']),
                    'source':traces}
                if eligible and not blocked.any(): passed.append(record)
                elif blocked.any(): failures.append(record)
                elif tuple(box) in strict_by_box: failures.append(record)
            elif tuple(box) in strict_by_box:
                failures.append(strict_by_box[tuple(box)])
        return {'failures':failures,'air_pockets':passed}


def frame_report(model,pose,policy=None,source_overrides=None):
    layers,maps = model.layers(pose,source_overrides)
    owners = posed_owners(
        layers,model.layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'],load(model.case)['ownership'])
    seams = np.logical_or.reduce(model.masks(pose,model.layout['proof_joint_seams'],maps))
    references = model.masks(pose,model.layout['proof_rest_holes'],maps)
    if policy is None: policy = SkirtAirPolicy(model.case,model.layout)
    result = policy.report(owners>0,owners,seams,references,pose,maps)
    return layers,owners,seams,references,result
