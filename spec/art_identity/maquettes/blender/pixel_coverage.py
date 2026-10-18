"""Independent part-colour presence inside each unoccluded native solo mask.

Nearest-colour ownership at antialiased boundaries can include neighbouring
pixels outside a part's solo. Keep that raw count, but use the intersection
for coverage fractions and require genuine flat part-colour pixels too.
"""
import numpy as np

COVERAGE_DEFAULTS={'alpha_threshold':128,'srgb_channel_tolerance':1}


def part_coverage(spec,raster,rgba):
    pixels=np.asarray(rgba).astype(int)
    results={}
    for index,name in enumerate(raster.names):
        solo=raster.masks[name]
        visible=raster.owners==index
        inside=visible&solo
        linear=np.array(spec['labels'][name])
        colour=np.rint(np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)*255)
        pure=(abs(pixels[:,:,:3]-colour).max(-1)<=COVERAGE_DEFAULTS['srgb_channel_tolerance'])&(pixels[:,:,3]>=COVERAGE_DEFAULTS['alpha_threshold'])&solo
        results[name]={'visible_pixels':int(inside.sum()),'solo_pixels':int(solo.sum()),
            'visible_fraction_of_solo':int(inside.sum())/max(1,int(solo.sum())),
            'depth_tested_owner_pixels':int(visible.sum()),'pure_owner_pixels':int(pure.sum()),
            'clipped_at_canvas':bool(solo[0].any() or solo[-1].any() or solo[:,0].any() or solo[:,-1].any())}
    return results
