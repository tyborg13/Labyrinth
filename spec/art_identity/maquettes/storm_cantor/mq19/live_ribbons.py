"""Measure ribbons from live skin faces and root-to-tip boundary connectivity.

Only the solid-cloth/root registration is used. Declared strip tips, strip
indices and ribbon rows never supply geometry or counts to this observer.
"""
from collections import Counter,defaultdict,deque
import numpy as np

MEASUREMENT_DEFAULTS={'minimum_segment_squared_length_m2':1e-30}

def edge_key(a,b):return tuple(sorted((a,b)))


def measure(spec,mid,faces):
    layout=spec['mq19']['cloak_layout'];H=spec['mq19']['gauge_H_m'];count=layout['paired_vertices']
    solid={i for row in layout['solid_grid_indices'] for i in row if i>=0}
    root_us=dict(zip(layout['root_indices'],layout['root_us']))
    surface=[f for f in faces if all(0<=i<count for i in f)]
    edges=Counter(edge_key(a,b) for f in surface for a,b in zip(f,f[1:]+f[:1]))
    lower=[f for f in surface if any(i not in solid for i in f)]
    owners=defaultdict(list)
    for k,face in enumerate(lower):
        for a,b in zip(face,face[1:]+face[:1]):owners[edge_key(a,b)].append(k)
    neighbours=defaultdict(set)
    for pair in owners.values():
        for k in pair:neighbours[k].update(pair)
    unseen=set(range(len(lower)));rows=[];detached=0
    while unseen:
        seed=unseen.pop();component={seed};pending=[seed]
        while pending:
            for k in neighbours[pending.pop()]&unseen:
                unseen.remove(k);component.add(k);pending.append(k)
        local=Counter();adjacency=defaultdict(set)
        for k in component:
            f=lower[k]
            for a,b in zip(f,f[1:]+f[:1]):
                local[edge_key(a,b)]+=1;adjacency[a].add(b);adjacency[b].add(a)
        root_edges=[(a,b) for a,b in local if a in root_us and b in root_us]
        roots=sorted({i for edge in root_edges for i in edge},key=root_us.get)
        if len(roots)<2:
            detached+=1;continue
        # The root chain and every measured cross-row are on this single live
        # surface. Orphaned vertices cannot enter the BFS or the boundary.
        distance={i:0 for i in roots};pending=deque(roots)
        while pending:
            a=pending.popleft()
            for b in adjacency[a]:
                if b not in distance:distance[b]=distance[a]+1;pending.append(b)
        rim={i for edge,n in local.items() if n==1 for i in edge}
        lower_rim=list(rim-set(roots))
        if not lower_rim:
            detached+=1;continue
        tip=min(lower_rim,key=lambda i:mid[i,2]);root_points=mid[roots]
        # Locate the tip's root station by its live horizontal projection onto
        # the root polyline. No authored tip_u/length/index participates.
        a=root_points[:-1,:2];delta=np.diff(root_points[:,:2],axis=0)
        blend=np.clip(np.sum((mid[tip,:2]-a)*delta,axis=1)/np.maximum(np.sum(delta*delta,axis=1),MEASUREMENT_DEFAULTS['minimum_segment_squared_length_m2']),0,1)
        segment=int(np.argmin(np.linalg.norm(a+blend[:,None]*delta-mid[tip,:2],axis=1)))
        root_z=float(root_points[segment,2]+blend[segment]*(root_points[segment+1,2]-root_points[segment,2]))
        depth=max(distance.values());lower_half=[i for i,d in distance.items() if d>=depth/2]
        flat=mid[lower_half];centre=flat.mean(0)
        if len(flat)>=3:
            _,_,vectors=np.linalg.svd(flat-centre,full_matrices=False)
            error=float(np.max(abs(np.einsum('nj,j->n',flat-centre,vectors[-1])))/H)
        else:error=float('inf')
        live_rows=[[i for i,d in distance.items() if d==r] for r in range(depth+1)]
        rows.append({'tip_index':int(tip),'root_indices':roots,'live_rows':live_rows,
            'root_u':float(np.mean([root_us[i] for i in roots])),
            'width_over_H':float(np.linalg.norm(np.diff(root_points,axis=0),axis=1).sum()/H),
            'length_over_H':float((root_z-mid[tip,2])/H),'tip_z_over_H':float(mid[tip,2]/H),
            'lower_half_plane_error_over_H':error,
            'root_edges_shared':len(root_edges)==len(roots)-1 and all(edges[e]==2 for e in root_edges),
            'continuous_rows':bool(depth>0 and all(live_rows) and len(distance)==len(adjacency)
                and all(any(distance[b]==d-1 for b in adjacency[i]) for i,d in distance.items() if d))})
    rows.sort(key=lambda r:r['root_u'])
    return {'ribbons':rows,'detached_surfaces':detached,
        'live_vertex_count':len({i for f in surface for i in f}),
        'ignored_orphan_vertices':len(mid)-len({i for f in surface for i in f})}
