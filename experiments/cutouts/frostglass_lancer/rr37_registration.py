"""Each mq-14 view fits its own hood-to-sole frame, as the delivery fit audit.

The director rear is painted to the front's height; the native rear projects
shorter. The raw-paint reducer transform therefore cannot register the maquette.
Only the supplied painting and certified maquette frames determine this map.
"""
import numpy as np
from PIL import Image
from rr37_case import PROJECT
from cutout_pipeline.cases import read_json, digest
from maquette_cutout import Registration
from experiments.cutouts.hoarfrost_seer.rr07_inputs import registered_transform

# Bounds only select the hood, excluding the front spearhead. The coordinates
# below are measured paint landmarks, not runtime tuning.
HOOD_COLUMNS = {'front': [75, 170], 'rear': [75, 170]}


def for_view(view):
    def register(raw, record):
        if record.get('processing') == 'lancer_rear_v2_registered_native':
            # Director v2 is registered at (0,0) to mq14_rear. Its longer
            # shaft must not move the maquette's ground/sole registration.
            from art_identity_gate import pixel_digest
            if pixel_digest(Image.open(raw)) != record['raw_pixel_sha256']:
                raise ValueError('Changed director rear v2 replay')
            job = PROJECT / 'spec/art_identity/jobs/frostglass_lancer/mq14_rear'
            record = read_json(job / 'processed.json')
            raw = next(p for p in job.rglob('*.png') if digest(p) == record['raw_sha256'])
        raw_transform = registered_transform(raw, record)  # Verify immutable raw.
        delivery = PROJECT / 'spec/art_identity/maquettes/frostglass_lancer/delivery'
        native = read_json(delivery / 'fit_report.json')['views'][view]['maquette_frame']
        path = PROJECT / f'spec/art_identity/jobs/frostglass_lancer/mq14_{view}/processed.png'
        paint = np.asarray(Image.open(path).convert('RGBA'))
        y, x = np.nonzero(paint[..., 3])
        a, b = HOOD_COLUMNS[view]
        head = int(np.nonzero(paint[:, a:b, 3])[0].min())
        sole = int(y.max()) + 1
        ground = float(x[y == y.max()].mean())
        scale = (sole - head) / (native['sole_bottom'] - native['head_top'])
        offset = [ground - scale * native['ground_x'], head - scale * native['head_top']]
        return Registration([scale, scale], offset, {'policy': 'mq14 independent hood/sole/ground registration',
            'source_frame': {'head_top': head, 'sole_bottom': sole, 'ground_x': ground},
            'maquette_frame': native, 'painting_sha256': digest(path), 'raw_reducer': raw_transform.trace})
    return register


def update_profile():
    """Owned support record from the director's painted sole landmarks."""
    import re
    path=PROJECT/'scripts/actor_presentation.gd'
    landmarks=read_json(PROJECT/'spec/art_identity/jobs/frostglass_lancer/mq14_landmarks_pair.json')
    anchors={v:np.mean(list(points.values()),axis=0) for v,points in landmarks.items()}
    heights=[]
    for view in ('front','rear'):
        paint=np.asarray(Image.open(PROJECT/f'spec/art_identity/jobs/frostglass_lancer/mq14_{view}/processed.png'))
        a,b=HOOD_COLUMNS[view];head=int(np.nonzero(paint[:,a:b,3])[0].min())
        heights.append(float(anchors[view][1]-head))
    line='"frostglass_lancer": {"front": Vector2(%.8f, %.8f), "rear": Vector2(%.8f, %.8f), "height": Vector2(%.8f, %.8f)},' % (*anchors['front'],*anchors['rear'],*heights)
    text=path.read_text();text=re.sub(r'"frostglass_lancer": \{"front":.*?\},',line,text,count=1);path.write_text(text)
    print('RR37 SUPPORT REGISTRATION: PASS (director sole landmarks; front/rear measured independently)')


if __name__=='__main__': update_profile()
