"""Rest-pose cloth/iron containment probes, using supplied actual surfaces."""
import numpy as np
from .contact import triangles,inside


def inspect(points,faces,epsilon):
    vertices=np.asarray(points['shoulder_mantle'])
    samples=np.vstack((vertices,np.array([vertices[face].mean(0) for face in faces['shoulder_mantle']])))
    counts={}
    for side in ('near','far'):
        for name in ('upper_plate_'+side,'fore_plate_'+side,'elbow_cop_'+side):
            mesh=triangles(points[name],faces[name]);lo=mesh.min((0,1));hi=mesh.max((0,1))
            candidates=samples[np.all((samples>lo)&(samples<hi),axis=1)]
            counts[name]=sum(inside(point,mesh,epsilon) for point in candidates)
    return {'passed':not any(counts.values()),'samples':len(samples),'inside_samples_by_arm_mesh':counts,
        'scope':'All opened mantle skin vertices and face centres against the six retained iron arm solids.'}
