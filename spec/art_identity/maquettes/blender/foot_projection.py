"""Source-pixel contact distances using the same registration as the fit gate."""
import numpy as np
from ..raster import project

# Director-specified acceptance tolerances, not renderer sampling defaults.
FOOT_LIMITS={'source_distance_px':2.,'ground_tolerance_m':.05}


def source_points(spec,points,view,fit):
    source,native=fit['source_frame'],fit['maquette_frame']
    factor=(native['sole_bottom']-native['head_top'])/(source['sole_bottom']-source['head_top'])
    pixels=project(spec,points,view)[:,:2]
    return (pixels-[native['ground_x'],native['head_top']])/factor+[source['ground_x'],source['head_top']]


def report(spec,views,sources):
    from ..fitting import keyed_mask
    contract=spec['foot_contacts']
    pieces={p['id']:p for p in spec['pieces']}
    feet={}
    for name in contract['pieces']:
        point=pieces[name]['path'][-1]
        distance=abs(point[2]-contract['plane_z'])
        entry={'point_m':point,'ground_error_m':distance,'views':{},'passed':distance<=FOOT_LIMITS['ground_tolerance_m']}
        for view,image in sources.items():
            pixel=source_points(spec,[point],view,views[view])[0]
            y,x=np.nonzero(keyed_mask(image))
            nearest=float(np.sqrt(((np.column_stack([x+.5,y+.5])-pixel)**2).sum(1).min()))
            passed=nearest<=FOOT_LIMITS['source_distance_px']
            entry['views'][view]={'source_px':pixel.tolist(),'distance_px':nearest,'passed':passed}
            entry['passed'] &= passed
        feet[name]=entry
    return {'plane_z':contract['plane_z'],'limits':FOOT_LIMITS,'feet':feet,'passed':all(f['passed'] for f in feet.values())}
