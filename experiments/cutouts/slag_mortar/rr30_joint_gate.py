"""Director's exposed-cover and new dark-skin-seam CPU gate, rr30 only."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from rr30_cpu import sprite_transform
from maquette_motion import pixels
from maquette_motion.material_palette import luma
from maquette_motion.silhouette import dilate
from rr30_joint_geometry import (COVER_LIMIT_PX, SKIN_PREFIXES, interfaces,
                                distance, material_floor, source_materials, declared_joins)

DISTANCE_EPSILON_PX = 1e-9  # Float roundoff only; not a visual allowance.


def source_transform(layout, pose, part):
    transform = sprite_transform(layout,pose,part).copy()
    transform[:2,2] -= transform[:2,:2] @ part['offset']
    transform[:2,2] += pixels.PROOF_DEFAULTS['source_offset']
    return transform


class JointSurfaceGate:
    def __init__(self, case, layout, source_images=None):
        self.case, self.layout = case, layout
        self.visible, self.definition = source_materials(case,layout)
        if source_images is not None:
            self.visible={p['logical_part']:source_images[p['name']] for p in layout['parts'] if not p['hidden_material']}
        anatomy=read_json(case/'anatomy.json')
        self.interfaces=interfaces(self.visible,declared_joins(anatomy))
        self.parts={p['name']:p for p in layout['parts']}
        self.skin={n:material_floor(image,self.definition) for n,image in self.visible.items()
                   if n.startswith(SKIN_PREFIXES)}
        self.paint=np.asarray(Image.open(case/layout['rest_source']).convert('RGBA'))
        alpha=self.paint[...,3]>0
        self.rest_interior=alpha & ~dilate(~alpha,1,grid_distance=True)
        self.exempt={}
        from maquette_motion.features import source_pixels
        for part in layout['parts']:
            source=source_pixels(case,part) if source_images is None else source_images[part['name']]
            original=np.zeros_like(self.paint)
            exempt=(source[...,3]>0) & np.all(source==self.paint,axis=2)
            original[exempt]=[255,255,255,255]
            self.exempt[part['name']]=original[part['bbox'][1]:part['bbox'][3],part['bbox'][0]:part['bbox'][2]]

    def joint_segments(self, part, pose):
        result=[]
        for row in self.interfaces.values():
            if part['logical_part'] not in row['pieces'] or not row['segments']: continue
            segments=np.asarray(row['segments'],dtype=float)
            for name in row['pieces']:
                transform=source_transform(self.layout,pose,self.parts[name])
                result.append(segments @ transform[:2,:2].T + transform[:2,2])
        return np.concatenate(result) if result else np.empty((0,2,2))

    def frame(self, pose, layers, *, potential_covers=False):
        shape=layers[0][1].shape[:2]
        owner=np.full(shape,-1,dtype=np.int16)
        composite=np.zeros((*shape,4),dtype=np.uint8)
        ordered=sorted(layers,key=lambda row:row[0]['z_index'])
        for index,(_,image,_) in enumerate(ordered):
            selected=image[...,3]>0;owner[selected]=index;composite[selected]=image[selected]
        occupied=composite[...,3]>0
        visible_paint=np.logical_or.reduce([image[...,3]>0 for part,image,_ in ordered if not part['hidden_material']])
        interior=occupied & ~dilate(~occupied,1,grid_distance=True)
        cover_errors=[];dark_errors=[];maximum=0.
        luminance={p['name']:luma(image) for p,image,_ in ordered}
        shown_exempt={}
        for index,(part,image,_) in enumerate(ordered):
            visible=owner==index
            if potential_covers and part['hidden_material']:
                # Calibration checks every underlay which could be revealed
                # after another bad underlay is removed. The acceptance gate
                # still measures only actually visible pixels.
                visible=(image[...,3]>0) & ~visible_paint
            if part['hidden_material'] and visible.any():
                yy,xx=np.nonzero(visible)
                distances=distance(np.column_stack((xx+.5,yy+.5)),self.joint_segments(part,pose))
                maximum=max(maximum,float(distances.max()))
                selected=distances>COVER_LIMIT_PX+DISTANCE_EPSILON_PX
                if selected.any():
                    cover_errors.append(dict(piece=part['name'],pixels=int(selected.sum()),
                        maximum_distance_px=float(distances.max()),
                        destination_pixels=np.column_stack((xx[selected],yy[selected])).tolist()))
        # The original limb paint and its local joint neighbourhood define skin;
        # iron, clothes, head and crucible remain their own materials.
        for name,floor in self.skin.items():
            skin=next(image for part,image,_ in ordered if part['name']==name)
            region=dilate(skin[...,3]>0,int(COVER_LIMIT_PX)) & interior
            for index,(part,image,_) in enumerate(ordered):
                logical=part['logical_part']
                if logical not in self.skin and logical not in ('torso','pelvis'): continue
                selected=region & (owner==index) & (luminance[part['name']]<floor)
                if not selected.any(): continue
                if part['name'] not in shown_exempt:
                    shown_exempt[part['name']]=pixels.render(self.exempt[part['name']],sprite_transform(self.layout,pose,part))[...,3]>0
                shown=shown_exempt[part['name']]
                rejected=selected & ~shown
                if rejected.any():
                    yy,xx=np.nonzero(rejected)
                    dark_errors.append(dict(piece=part['name'],skin_region=name,
                        pixels=int(rejected.sum()),darkest_painted_skin_luma=floor,
                        minimum_luma=float(luminance[part['name']][rejected].min()),
                        destination_pixels=np.column_stack((xx,yy)).tolist()))
        return dict(ok=not(cover_errors or dark_errors),clip=pose['clip'],frame=pose['frame'],
                    maximum_visible_cover_distance_px=maximum,
                    cover_errors=cover_errors,dark_errors=dark_errors)
