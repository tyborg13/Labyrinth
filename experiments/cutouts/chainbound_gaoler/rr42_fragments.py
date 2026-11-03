"""Director feedback 1: rest-contact ownership, without repainting fragments."""
import numpy as np
from rr42_underlay import BASE_CASE,CASE
from cutout_pipeline.cases import read_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components,dilate

SPECK_LIMIT_PX=6  # Director decision, not tuning.


def plan(view):
    layout=read_json(BASE_CASE/f'layouts/{view}.json')
    images={p['name']:source_pixels(BASE_CASE,p) for p in layout['parts'] if not p.get('hidden_material')}
    result=[]
    for name,image in images.items():
        labels,groups=components(image[...,3]>0,8)
        for label,count in groups[1:]:
            mask=labels==label;rim=dilate(mask,1)&~mask
            contacts={other:int((rim&(paint[...,3]>0)).sum()) for other,paint in images.items()
                      if other!=name and (rim&(paint[...,3]>0)).any()}
            target=None;reason='isolated speck under 6 px' if count<SPECK_LIMIT_PX else 'no rest contact'
            if count>=SPECK_LIMIT_PX and contacts:
                # A dangling boot edge follows the touching foot; cloth follows
                # the touching coat. The remaining fragments follow the largest
                # shared rest boundary. Lexical ordering only resolves equal
                # boundary counts and is recorded for audit.
                feet={n:c for n,c in contacts.items() if n.startswith('foot_')}
                coats={n:c for n,c in contacts.items() if n.startswith('coat_')}
                candidates=feet or coats or contacts
                target=sorted(candidates,key=lambda n:(-candidates[n],n))[0]
                reason='touching foot' if feet else 'touching coat' if coats else 'largest shared rest boundary'
            yy,xx=np.nonzero(mask)
            result.append({'view':view,'source':name,'target':target,'decision':'re-own' if target else 'clear',
                'reason':reason,'source_pixels':int(count),'bbox':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],
                'contacts':contacts,'texels':[[int(x),int(y)] for y,x in zip(yy,xx)]})
    result += [r for r in read_json(CASE.parent/'rr42_feedback1_fragments.json')['fragments'] if r['view']==view]
    return result


def apply(view,images):
    rows=plan(view)
    # Read every fragment from the immutable baseline before moving any of it.
    originals={n:image.copy() for n,image in images.items()}
    for row in rows:
        xx,yy=np.asarray(row['texels']).T
        images[row['source']][yy,xx]=0
        if row['target']:
            if np.any(images[row['target']][yy,xx,3]):raise ValueError('Rest fragment ownership overlaps visible paint')
            images[row['target']][yy,xx]=originals[row['source']][yy,xx]
    return rows
