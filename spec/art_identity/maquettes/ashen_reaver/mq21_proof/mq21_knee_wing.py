"""Rounded outside knee fan with two raised cop-centred radial ridges."""
import math
import numpy as np
from ..forms import shell,cord,TOPOLOGY


def build(spec,side,c,u,design):
    H=spec['mq16']['height_m'];knee=np.asarray(spec['joints']['knee_'+side]);sign=1 if side=='near' else -1
    d=design['legs']['knee_wing'];width=d['width_over_H']*H;half_height=d['height_over_H']*H/2
    cop=next(piece for piece in spec['pieces'] if piece['id']=='round_knee_'+side)
    cop_vertices=np.asarray(cop['vertices'])
    cop_radius=float(np.max(sign*(cop_vertices[:,1]-knee[1])))
    cop_depth=c['knee_depth_px']*u
    start=cop_radius+d['outward_projection_over_H']*H-width
    # Reuse the cop's axial depth and the source visor's raised-line width.
    # Samples only tessellate the director's half-ellipse; they do not tune it.
    angles=np.linspace(-math.pi/2,math.pi/2,TOPOLOGY['ring_samples']+1)
    outline=np.array([[start+width*math.cos(a),half_height*math.sin(a)] for a in angles])
    front_x=float(cop_vertices[:,0].max())
    vertices=[[front_x-depth,knee[1]+sign*y,knee[2]+z] for depth in (0,cop_depth) for y,z in outline]
    count=len(outline);faces=[list(reversed(range(count))),list(range(count,2*count))]
    faces.extend([[k,(k+1)%count,(k+1)%count+count,k+count] for k in range(count)])
    spec['pieces'].append(shell('knee_wing_'+side,'shin_'+side,'knee_'+side,vertices,faces))
    ridge_radius=c['visor_width_px']*u/2
    ridge_angles=np.linspace(-math.pi/2,math.pi/2,d['raised_ridges']+2)[1:-1]
    for index,a in enumerate(ridge_angles):
        # Radiate from the original cop centre into the rounded fan, with
        # the ridge cap contained inside its director-specified outer envelope.
        end=[front_x,knee[1]+sign*(start+(width-ridge_radius)*math.cos(a)),
             knee[2]+(half_height-ridge_radius)*math.sin(a)]
        path=[[front_x,knee[1],knee[2]],end]
        spec['pieces'].append(cord('knee_wing_ridge_'+side+'_'+str(index),'shin_'+side,'knee_'+side,path,ridge_radius))
