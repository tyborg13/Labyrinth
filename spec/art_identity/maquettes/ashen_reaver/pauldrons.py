"""Three rounded shell lames around each shoulder/upper-arm axis."""
import math
import numpy as np
from spec.art_identity.maquettes.blender.closed_loft import loft
from .forms import shell,TOPOLOGY

SHELL_NUMERICS={'meridian_samples':13,'rim_samples':9,'wall_samples':5}


def dome(identifier,part,joint,centre,radius,height,thick):
    """Closed hollow dome with a rolled hem and true outer/inner poles."""
    count=TOPOLOGY['ring_samples'];r=thick/2;vertices=[];faces=[]
    angles=np.linspace(0,math.pi/2,SHELL_NUMERICS['meridian_samples'])[:-1]
    def surface(inner):
        first=len(vertices);R=radius-thick if inner else radius
        h=height-r-thick if inner else height-r
        for angle in angles:
            for theta in np.linspace(0,2*math.pi,count,endpoint=False):
                vertices.append((np.asarray(centre)+[R*math.cos(angle)*math.cos(theta),
                    R*math.cos(angle)*math.sin(theta),r+h*math.sin(angle)]).tolist())
        for row in range(len(angles)-1):
            for k in range(count):
                a=first+row*count+k;b=first+row*count+(k+1)%count
                face=[a,b,b+count,a+count];faces.append(list(reversed(face)) if inner else face)
        pole=len(vertices);vertices.append((np.asarray(centre)+[0,0,height-thick if inner else height]).tolist())
        a=first+(len(angles)-1)*count
        for k in range(count):
            face=[a+k,a+(k+1)%count,pole];faces.append(list(reversed(face)) if inner else face)
        return first
    outside=surface(False);inside=surface(True)
    previous=inside
    # Inner hem to outer hem through a rounded lower semicircle. Its minimum
    # Z is exactly the shoulder plane, never a horizontal disc cap.
    for angle in np.linspace(math.pi,2*math.pi,SHELL_NUMERICS['rim_samples'])[1:-1]:
        start=len(vertices);rad=radius-r+r*math.cos(angle);z=r+r*math.sin(angle)
        for theta in np.linspace(0,2*math.pi,count,endpoint=False):
            vertices.append((np.asarray(centre)+[rad*math.cos(theta),rad*math.sin(theta),z]).tolist())
        for k in range(count):faces.append([previous+k,previous+(k+1)%count,start+(k+1)%count,start+k])
        previous=start
    for k in range(count):faces.append([previous+k,previous+(k+1)%count,outside+(k+1)%count,outside+k])
    return shell(identifier,part,joint,vertices,faces)


def band(identifier,part,joint,shoulder,axis,z_low,z_high,radius,arm_radius,thick,drop,lift):
    r=thick/2
    def outer(z):
        fraction=np.clip((z-(shoulder[2]-drop))/drop,0,1)
        return arm_radius+thick+fraction*(radius-4*thick-arm_radius-thick)+lift
    def centre(z):
        dz=min(0,z-shoulder[2]);point=shoulder+axis*(dz/axis[2]);point[2]=z
        return point
    rings=[]
    def station(z,rad):rings.append([*centre(z),rad,rad])
    lo,hi=z_low+r,z_high-r
    for z in np.linspace(lo,hi,SHELL_NUMERICS['wall_samples']):station(z,outer(z))
    mid=outer(hi)-r
    for a in np.linspace(0,math.pi,SHELL_NUMERICS['rim_samples'])[1:]:station(hi+r*math.sin(a),mid+r*math.cos(a))
    for z in np.linspace(hi,lo,SHELL_NUMERICS['wall_samples'])[1:]:station(z,outer(z)-thick)
    mid=outer(lo)-r
    for a in np.linspace(math.pi,2*math.pi,SHELL_NUMERICS['rim_samples'])[1:-1]:station(lo+r*math.sin(a),mid+r*math.cos(a))
    v,f,flat=loft({'sections':rings,'samples':TOPOLOGY['ring_samples'],'periodic':True})
    return shell(identifier,part,joint,v,f,flat)


def build_pauldrons(spec,side,u,calipers):
    design=spec['director_feedback2']['pauldrons'];H=spec['mq16']['height_m']
    shoulder=np.asarray(spec['joints']['shoulder_'+side]);elbow=np.asarray(spec['joints']['elbow_'+side])
    axis=elbow-shoulder;axis/=np.linalg.norm(axis)
    drop=design['bottom_below_shoulder_over_H']*H
    overlap=design['overlap_fraction'];height=drop/(2*(1-overlap))
    radius=calipers['pauldron_radius_px']*u;thick=calipers['pauldron_shell_thickness_px']*u
    part='pauldron_'+side;joint='shoulder_'+side
    parts=[dome(part+'_0',part,joint,shoulder,radius,height,thick)]
    for layer in (1,2):
        top=shoulder[2]+height-layer*(1-overlap)*height;bottom=top-height
        parts.append(band(part+'_'+str(layer),part,joint,shoulder,axis,bottom,top,radius,
                          calipers['upper_arm_radius_px']*u,thick,drop,2*thick if layer==1 else 0))
    spec['pieces'].extend(parts)
    spec['mq16'].setdefault('pauldrons',{})[side]={'ids':[p['id'] for p in parts],
        'wall_rings':{p['id']:len(p['vertices'])//TOPOLOGY['ring_samples'] for p in parts[1:]},
        'ring_samples':TOPOLOGY['ring_samples'],'lame_height_m':height,'shell_thickness_m':thick}
