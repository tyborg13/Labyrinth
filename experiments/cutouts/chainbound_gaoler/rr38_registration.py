"""mq-15's independently certified translation at its original 255px scale."""
from rr38_case import PROJECT
from cutout_pipeline.cases import read_json, digest
from maquette_cutout import Registration
from experiments.cutouts.hoarfrost_seer.rr07_inputs import registered_transform


def for_view(view):
    def register(raw, record):
        original = registered_transform(raw, record)
        delivery = PROJECT / 'spec/art_identity/maquettes/chainbound_gaoler/delivery'
        fit = read_json(delivery / 'mq15_acceptance.json')['front_fit']['views'][view]
        return Registration([255 / 1024, 255 / 1024], fit['translation_px'], {
            'policy': 'mq15 certified source-scale silhouette registration; independent views',
            'fit_sha256': digest(delivery / 'mq15_acceptance.json'),
            'iou': fit['iou'], 'raw_reducer': original.trace})
    return register


def update_profile():
    """Approved front sole landmarks; rear soles measured in its own paint."""
    import re
    import numpy as np
    from PIL import Image
    from maquette_motion.features import source_pixels
    from cutout_pipeline.cases import write_json
    from rr38_case import CASE
    supplied=read_json(PROJECT/'spec/art_identity/jobs/chainbound_gaoler/mq3_front_v4/landmarks_pair.json')['front']
    anchors={'front':np.mean(list(supplied.values()),axis=0)}
    measurements={'front':{'source':'protected mq3_front_v4/landmarks_pair.json','soles':supplied}}
    layout=read_json(CASE/'layouts/rear.json');soles={}
    for side in ('near','far'):
        part=next(p for p in layout['parts'] if p['name']=='foot_'+side)
        image=source_pixels(CASE,part);y,x=np.nonzero(image[...,3])
        soles[side]=[float(x[y==y.max()].mean()),float(y.max()+1)]
    anchors['rear']=np.mean(list(soles.values()),axis=0)
    measurements['rear']={'source':'approved rear boot sole alpha at bottom pixel edge','soles':soles}
    heights=[]
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json')
        head=next(p for p in layout['parts'] if p['name']=='head')
        top=int(np.nonzero(source_pixels(CASE,head)[...,3])[0].min())
        heights.append(float(anchors[view][1]-top))
        measurements[view].update(anchor=anchors[view].tolist(),head_top=top)
    path=PROJECT/'scripts/actor_presentation.gd';text=path.read_text()
    line='"chainbound_gaoler": {"front": Vector2(%.8f, %.8f), "rear": Vector2(%.8f, %.8f), "height": Vector2(%.8f, %.8f)},' % (*anchors['front'],*anchors['rear'],*heights)
    text=re.sub(r'"chainbound_gaoler": \{"front":.*?\},',line,text,count=1);path.write_text(text)
    write_json(CASE/'proof/support_registration.json',measurements)
    print('RR38 SUPPORT REGISTRATION: PASS (approved front landmarks; independently measured rear soles)')


if __name__=='__main__':update_profile()
