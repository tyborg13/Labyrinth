"""Dense sculpted folds on a measured cloth rest, without a cloth solver.

The rest is the fitted garment, including its rounded crown and opening. This
adds continuous nonuniform folds, an uneven torn hem and a closed inner skin.
"""
import numpy as np

FABRIC_DEFAULTS = {'row_samples': 8, 'epsilon': 1e-9}


def sculpt(rows, closed, config):
    source = np.asarray(rows, float)
    dense = []
    for i,(a,b) in enumerate(zip(source,source[1:])):
        before,after=source[max(0,i-1)],source[min(len(source)-1,i+2)]
        for t in np.linspace(0,1,FABRIC_DEFAULTS['row_samples'],endpoint=False):
            dense.append((2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*(b-before)/2+(-2*t**3+3*t*t)*b+(t**3-t*t)*(after-a)/2)
    dense=np.asarray(dense+[source[-1]])
    n,m=dense.shape[:2]
    for i,row in enumerate(dense):
        t=i/(n-1); centre=row.mean(0)
        for j,p in enumerate(row):
            u=j/(m if closed else m-1)
            phase=u*np.pi*2
            radial=p-centre;radial[2]=0
            length=np.linalg.norm(radial)
            wave=np.sin(phase*config['folds']+.6*np.sin(t*5+phase*3))
            amplitude=config['depth_m']*(.25+.75*t)
            if length>FABRIC_DEFAULTS['epsilon']:
                p+=radial/length*amplitude*wave
            p[2]-=t**8*config['rag_m']*(.5+.5*np.cos(phase*config['tears']+.8*np.sin(phase*7)))
    vertices=dense.reshape(-1,3)
    # Finite-difference surface normals provide genuine thickness round folds.
    normals=[];faces=[]
    for i in range(n):
        for j in range(m):
            side=dense[i,(j+1)%m if closed else min(j+1,m-1)]-dense[i,(j-1)%m if closed else max(j-1,0)]
            along=dense[min(i+1,n-1),j]-dense[max(i-1,0),j]
            normal=np.cross(side,along);normal/=max(np.linalg.norm(normal),FABRIC_DEFAULTS['epsilon']);normals.append(normal)
    count=len(vertices)
    vertices=np.vstack([vertices,vertices-np.array(normals)*config['thick_m']])
    for i in range(n-1):
        for j in range(m if closed else m-1):
            k=(j+1)%m;a=i*m+j;b=i*m+k;c=(i+1)*m+k;d=(i+1)*m+j
            faces.extend([[a,b,c,d],[d+count,c+count,b+count,a+count]])
    # Sew every boundary to its inner skin; the opening remains a real hole.
    edges={}
    for face in faces[::2]:
        for a,b in zip(face,face[1:]+face[:1]):
            edge=tuple(sorted((a,b)));edges[edge]=edges.get(edge,0)+1
    faces.extend([[a,b,b+count,a+count] for (a,b),num in edges.items() if num==1])
    return vertices.tolist(),faces
