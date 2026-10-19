"""Whole circumferential layers of curved, torn leaves, in the body frame."""
import math
import numpy as np
from .ridged_shell import layered


def draft(centre, forward, lateral, rows, scale, rim_shape):
    centre=np.array(centre);forward=np.array(forward);lateral=np.array(lateral)
    plates=[]
    for row in rows:
        if 'angles' in row and (len(row['angles']) != len(row['variation']) or
                               not all(math.isfinite(a) for a in row['angles'])):
            raise ValueError('Leaf patch angles must match its finite clump placements')
        for i,variation in enumerate(row['variation']):
            angle=(row['angles'][i] if 'angles' in row else
                   math.tau*(i+row['phase'])/len(row['variation']))
            radial=forward*math.cos(angle)+lateral*math.sin(angle)
            tangent=-forward*math.sin(angle)+lateral*math.cos(angle)
            width=row['width_px']*scale*variation
            start=centre+radial*row['root_radius_px']*scale+[0,0,row['z_px']*scale]
            length=row['length_px']*scale*variation
            def point(x,t):
                return (start+tangent*x*width+radial*row['fall_px']*scale*t+
                        np.array([0,0,-length*t])).tolist()
            rim=[point(x,t) for x,t in rim_shape]
            ridge=np.array(point(0,.43))+radial*row['relief_px']*scale
            plates.append({'rim':rim,'ridge':ridge.tolist(),'thickness':row['thick_px']*scale})
    return layered(plates)
