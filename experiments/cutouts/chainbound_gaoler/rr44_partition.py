"""Measured ownership of the supplied lowered arm; no drawing or new colour."""
import numpy as np
from PIL import Image, ImageDraw
from maquette_motion.features import source_pixels

# Traced on the registered approved 255px source. First assign body, then its
# visible far sleeve, rigid glove and held chain. Cowl remains torso-owned.
TRACES = {
    'front': [('arm_far', [(110,85),(112,106),(104,124),(97,134),(79,129),(86,112),(94,102),(99,87)]),
              ('hand_far', [(83,126),(95,125),(103,132),(102,140),(95,151),(80,151),(73,141),(75,132)]),
              ('chain', [(79,148),(100,148),(100,219),(69,219),(69,190),(80,190)])],
    'rear': [('arm_far', [(132,87),(145,88),(155,106),(163,123),(174,141),(162,153),(147,140),(136,121),(126,100)]),
             ('hand_far', [(163,139),(173,139),(183,148),(183,157),(174,165),(162,164),(156,154),(156,146)]),
             ('chain', [(159,164),(187,164),(193,236),(158,236)])]
}


def mask_polygon(points):
    image = Image.new('1',(255,255)); ImageDraw.Draw(image).polygon([tuple(p) for p in points],fill=1)
    return np.asarray(image, bool)


def cut(base, layout, paint, region, *, with_receipt=False):
    names = [p['name'] for p in layout['parts'] if not p.get('hidden_material')]
    old = {n:source_pixels(base,next(p for p in layout['parts'] if p['name']==n)) for n in names}
    owner = np.full((255,255),'',object)
    for name in names: owner[old[name][...,3]>0] = name
    prior_owner=owner.copy()
    # The composite owns removed arm pixels as well as newly revealed body.
    owner[region] = ''
    active = paint[...,3]>0
    owner[(prior_owner=='head') & active]='head'
    # The director region overlaps the helm/cowl at the old raised shoulder.
    # Preserve all unchanged visible semantic ownership there.
    for name in names:
        if name in ('arm_far','hand_far','chain'): continue
        unchanged=(prior_owner==name) & active & np.all(old[name]==paint,axis=-1)
        owner[unchanged]=name
    # rr-42 cleared twelve visible specks which the protected rr-44 painting
    # restores. Their original approved ownership is known: do not attach
    # trouser/tabard pixels to a distant fallback coat when they move.
    from cutout_pipeline.cases import read_json
    historical=base.parent/'rr38'
    original=read_json(historical/f'layouts/{layout["facing"]}.json')
    for part in original['parts']:
        if part.get('hidden_material'): continue
        restored=(owner=='') & active & ~region & (source_pixels(historical,part)[...,3]>0)
        owner[restored]=part['name']
    yy,xx = np.indices(active.shape)
    # Existing silhouettes provide the body/garment boundary. Newly revealed
    # torso is above the belt, the far coat continuation below it.
    owner[(owner=='') & active & (yy<132)] = 'torso'
    owner[(owner=='') & active & (yy>=132)] = 'coat_far'
    for name, polygon in TRACES[layout['facing']]:
        selected = mask_polygon(polygon) & active
        owner[selected] = name
    from rr44_case import CASE
    for row in read_json(CASE.parent/'rr44_feedback1_ownership.json')['transfers']:
        if row['view']!=layout['facing']:continue
        for x,y in row['texels']:
            if owner[y,x]!=row['from']:raise ValueError('Changed native ownership witness')
            owner[y,x]=row['to']
    receipt={}
    if layout['facing']=='rear':
        from rr44_underlay_contacts import apply
        from rr44_case import STAGED
        underlay=np.asarray(Image.open(STAGED/'rear_body_underlay.png').convert('RGBA'))
        receipt=apply(owner,paint,region,underlay)
    from rr44_feedback2_repairs import owners
    owners(owner,layout['facing'])
    images={name:np.where((owner==name)[...,None],paint,0).astype(np.uint8) for name in names}
    return (images,receipt) if with_receipt else images


FOOTPRINTS = {'near_arm': ('arm_near','hand_near'), 'far_arm': ('arm_far','hand_far','chain'),
              'legs': ('leg_near','foot_near','leg_far','foot_far'),
              'coat_near': ('coat_near',), 'coat_far': ('coat_far',), 'tabard': ('tabard',), 'head': ('head',),
              'torso': ('torso',), 'pelvis': ('pelvis',)}
RECEIVERS = ('torso','pelvis','tabard','coat_near','coat_far','leg_near','leg_far')


def backing(visible, underlay, previous, layout):
    footprints = {n:np.logical_or.reduce([visible[p][...,3]>0 for p in pieces]) for n,pieces in FOOTPRINTS.items()}
    # Director underlays describe only arms/chain (+ front legs). Retain the
    # existing painted leg/coat support elsewhere. Do not treat the removed
    # helm or cloth as new design authority: report their exposed backing.
    authority = footprints['near_arm'] | footprints['far_arm']
    if layout['facing']=='front': authority |= footprints['legs']
    # Retiring the old high hold also vacates its source-space footprint.
    # Those body texels must receive the replacement painting too; limiting
    # the replacement to the new lowered silhouette leaves the old backing
    # at the shoulder/neck and along the former hanging chain.
    from rr44_case import BASE
    retired=[source_pixels(BASE,p)[...,3]>0 for p in layout['parts']
             if p['name'] in ('arm_far','hand_far','chain')]
    authority |= np.logical_or.reduce(retired)
    # The rigid waist joint also vacates torso/pelvis paint. Supply its
    # existing three-pixel covered tuck from the director body painting,
    # rather than the inherited procedural continuation. No head/helmet
    # footprint is borrowed as hypothetical neck paint.
    from humanoid_cutout.tucks import required_tuck
    from rr44_case import CASE
    from cutout_pipeline.cases import read_json
    tucks=read_json(CASE/'anatomy.json')['tucks'];waist={}
    for receiver,cover in (('pelvis','torso'),('torso','pelvis')):
        mask=required_tuck(receiver,visible,layout['joints'],tucks)
        waist[receiver]=mask & (visible[cover][...,3]>0) & (underlay[...,3]>0) & ~authority
    authority |= np.logical_or.reduce(list(waist.values()))
    hidden = {n:im.copy() for n,im in previous.items()}
    for name, im in hidden.items():
        logical = name.removeprefix('hidden_')
        if logical in ('arm_far','hand_far','chain'): im[:] = 0
        # A limb keeps its own attachment tuck; the body behind it is supplied
        # by the director. Eliminate all procedural receiving paint there.
        if logical in RECEIVERS: im[authority] = 0
    owner = np.full(authority.shape,'torso',object)
    yy,_ = np.indices(authority.shape)
    owner[yy>=132 if layout['facing']=='front' else yy>=143] = 'coat_far'
    # Existing body-domain overlap order determines the receiving garment.
    for p in sorted(layout['parts'],key=lambda p:p['z_index']):
        if p.get('hidden_material') and p['logical_part'] in RECEIVERS:
            domain = source_pixels(__import__('rr44_case').BASE,p)[...,3]>0
            owner[domain] = p['logical_part']
    # Direct visible ownership takes precedence over an old hidden crop's
    # storage domain when the repaint has revealed that body material.
    for name in RECEIVERS:owner[visible[name][...,3]>0]=name
    for receiver,mask in waist.items():owner[mask]=receiver
    if layout['facing']=='rear':
        # The director identifies this as visible upper back. The historical
        # pelvis storage crop reaches y107; it must not make that back panel
        # follow the hips. Exposure still fails the independent strip gate.
        upper_back=np.zeros(authority.shape,bool);upper_back[63:121,121:143]=True
        owner[authority & upper_back]='torso'
    certificates = {}
    for name in RECEIVERS:
        mask = authority & (owner==name) & (underlay[...,3]>0)
        hidden['hidden_'+name][mask] = underlay[mask]
        certificates['hidden_'+name] = mask
    density_authorities={name:authority.copy() for name in RECEIVERS}
    if layout['facing']=='front':
        # The covered far trouser is itself a moving rest piece. Preserve its
        # original alpha and skinning, but use the supplied paint throughout
        # that existing footprint. The old constant donor becomes exposed
        # when the correctly attached chain moves away from it.
        name='hidden_leg_far'
        footprint=previous[name][...,3]>0
        mask=footprint & ~authority & (underlay[...,3]>0)
        hidden[name][mask]=underlay[mask]
        certificates[name] |= mask
        authority |= mask
        density_authorities['leg_far'] |= mask
    return hidden, footprints, authority, certificates,density_authorities
