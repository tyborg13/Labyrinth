"""Classify exact approved paint separately from procedural continuation ink."""
import numpy as np
from PIL import Image
from rr44_exposure import supplied
from rr44_authority import accepted
from cutout_pipeline.cases import digest,read_json
from maquette_motion.features import source_pixels
from humanoid_cutout.painted_caps import masks as cap_masks
from humanoid_cutout.native_defects import packed


def certificates(case,layout):
    underlay,_,underlay_masks=supplied(layout['facing'],case=case)
    caps=cap_masks(case,layout);result={}
    for part in layout['parts']:
        name=part['name'];image=source_pixels(case,part)
        if not part.get('hidden_material'):mask=image[...,3]>0
        else:
            mask=underlay_masks.get(name,np.zeros((255,255),bool))&np.all(image==underlay,axis=-1)&(image[...,3]>0)
            mask |= accepted(layout['facing'],name,image)
            mask |= caps.get(name,np.zeros((255,255),bool))
        result[name]=mask
    return result


def checks(case,layout):
    masks=certificates(case,layout)
    for part in layout['parts']:
        name=part['name'];record=layout['proof_layers'][name];path=case/record['mask']
        image=np.asarray(Image.open(path).convert('RGBA')).copy();x,y=record['mask_offset'];h,w=image.shape[:2]
        image[masks[name][y:y+h,x:x+w],1]=0
        Image.fromarray(image).save(path)


def surface(surface):
    masks=certificates(surface.model.case,surface.model.layout)
    surface.painted=masks
    for name,mask in masks.items():
        surface.bad_source[name][mask]=False
        source=source_pixels(surface.model.case,surface.parts[name])
        surface.part_palettes[name]=np.union1d(surface.part_palettes[name],packed(source)[mask])
    # Effective r1 continuations were approved at the same registered UVs.
    # Material diagnostics recognise their exact colours; the independent
    # painted-exposure gate still checks UV, RGBA and clip, not this palette.
    from rr44_continuations import records
    for name in surface.parts:
        colours=[p['rgba'] for row in records(surface.model.layout['facing'],name) for p in row['texels']]
        if colours:surface.part_palettes[name]=np.union1d(surface.part_palettes[name],packed(np.asarray(colours,np.uint8)))
    # A transported tuck-domain mask used to demand hypothetical paint in
    # source-transparent cells. Bind support to the independent frozen r1
    # source, never to the alpha of the texture currently under test.
    from rr44_case import STAGED
    path=STAGED/'feedback2_domain_calibration.json'
    if digest(path)!='c5dd60c091b653a8c6fb43f52bf30732f72f9c64bee5b75f1f5dd3277b711ef6':raise ValueError('Changed domain calibration fixture')
    expected={}
    for row in read_json(path)['regions']:
        if row['view']!=surface.model.layout['facing']:continue
        mask=np.zeros((255,255),bool)
        for x,y in row['painted_source_texels']:mask[y,x]=True
        expected[row['part']]=mask
    # Ownership repairs retire old source support, rather than demanding the
    # same texel from both the old moving limb and its new body/boot owner.
    view=surface.model.layout['facing']
    authority_mask=np.asarray(Image.open(surface.model.case/f'uncovered/{view}_paint_authority.png').convert('L'))>0
    _,_,receiving=supplied(view,case=surface.model.case)
    from rr44_partition import RECEIVERS
    for logical in RECEIVERS:
        name='hidden_'+logical
        expected.setdefault(name,np.zeros((255,255),bool))[authority_mask]=False
        expected[name] |= receiving.get(name,np.zeros((255,255),bool))
    for name,points in surface.model.layout.get('retired_backing_texels',{}).items():
        for x,y in points:expected.setdefault(name,np.zeros((255,255),bool))[y,x]=False
    for name,mask in cap_masks(surface.model.case,surface.model.layout).items():expected.setdefault(name,np.zeros((255,255),bool))[:] |= mask
    for logical,domain in surface.domains.items():
        name='hidden_'+logical
        surface.domains[logical]=domain&expected.get(name,np.zeros((255,255),bool))
    return surface
