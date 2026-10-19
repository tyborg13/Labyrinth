"""Source-only component cleanup from the existing cutout-workflow contract."""
import numpy as np
from maquette_motion.silhouette import components
from maquette_motion.continuity import adjacent_counts

# Existing workflow's complete-mask cleanup threshold. Visible paint is moved,
# never erased or recoloured; simultaneous decisions use the original owners.
COMPONENT_THRESHOLD_PX = 12


def clean(visible):
    names=list(visible)
    shape=next(iter(visible.values())).shape[:2]
    owners=np.full(shape,-1,dtype=int)
    for index,name in enumerate(names): owners[visible[name][...,3]>0]=index
    transfers=[]
    for index,name in enumerate(names):
        labels,groups=components(owners==index)
        for label,size in groups[1:]:
            if size>=COMPONENT_THRESHOLD_PX: continue
            mask=labels==label
            contacts=adjacent_counts(mask,owners,len(names));contacts[index]=0
            if not contacts.max(): continue
            destination=int(contacts.argmax())
            ys,xs=np.nonzero(mask)
            transfers.append({'from':name,'to':names[destination],'pixels':int(size),
                              'points':np.column_stack((xs,ys)).tolist()})
    for transfer in transfers:
        xs,ys=np.asarray(transfer['points']).T
        visible[transfer['to']][ys,xs]=visible[transfer['from']][ys,xs]
        visible[transfer['from']][ys,xs]=0
    return transfers
