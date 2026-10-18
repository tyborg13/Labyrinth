"""Recomputed fit evidence bound to approved art, recipe and native capture."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from .backend import load_render
from .compile_recipe import compile_recipe, PROJECT
from .contract import digest
from .capture_manifest import sha256 as sha
from .fit_delivery import overlay_parts, registered_parts
from .pixel_coverage import part_coverage
from ..fitting import frame, keyed_mask, normalise_points, warp_mask, FIT_DEFAULTS

FIT_PROOF_DEFAULTS = {'overlay_opacity': .4}


def silhouette_fit(source, raster, minimum):
    """Batch-A registration, with the brief's silhouette-only acceptance gate.

    Crawlers have no humanoid shoulder/ankle height contract. Whole-body top,
    bottom and ground-contact centroid are observable in the approved alpha.
    """
    source_mask = keyed_mask(source)
    native_mask = raster.silhouette
    source_frame, native_frame = frame(source_mask), frame(native_mask)
    extents = []
    for mask, definition in ((source_mask,source_frame),(native_mask,native_frame)):
        y,x = np.nonzero(mask)
        extents.extend([normalise_points([x.min(),y.min()],definition),
                        normalise_points([x.max()+1,y.max()+1],definition)])
    extents = np.array(extents)
    padding = FIT_DEFAULTS['overlay_padding']/FIT_DEFAULTS['normalised_height']
    bounds = [(extents.min(0)-padding).tolist(),(extents.max(0)+padding).tolist()]
    a,b = [warp_mask(mask, definition, bounds, FIT_DEFAULTS['normalised_height'])
           for mask,definition in ((source_mask,source_frame),(native_mask,native_frame))]
    iou = float((a&b).sum()/(a|b).sum())
    return {'iou':iou,'iou_min':minimum,'passed':iou>=minimum,
            'source_frame':source_frame,'maquette_frame':native_frame,
            'normalisation':'whole silhouette top to bottom; ground-contact centroid aligned'}


def compute_fit(folder,capture=None):
    folder=Path(folder)
    recipe=json.loads((folder/'measurements.json').read_text())
    spec=compile_recipe(recipe)
    capture=Path(capture) if capture else folder/'delivery'
    if spec['ortho_scale']!=2.4:raise ValueError('Clay comparison requires Lancer native scale')
    views, overlays = {}, []
    for view in ('front','rear'):
        path = PROJECT/recipe['sources'][view]
        if sha(path) != recipe['source_sha256'][view]:
            raise ValueError('Protected source artwork changed: '+str(path))
        source = Image.open(path).convert('RGBA')
        raster = load_render(spec,capture,view)
        report = silhouette_fit(source,raster,recipe['fit'][view]['gate']['iou_min'])
        parts = Image.open(capture/(view+'_parts.png')).convert('RGBA')
        coverage = part_coverage(spec,raster,parts)
        for name,values in coverage.items():
            values['explicit_occlusion'] = recipe['occlusions'].get(view,{}).get(name)
        missing = [name for name,v in coverage.items() if not v['solo_pixels'] or v['clipped_at_canvas'] or
                   (not v['pure_owner_pixels'] and not v['explicit_occlusion'])]
        # Leg parts remain explicit rows in coverage; occlusions cannot be
        # inferred from a failed capture or a zero-pixel part.
        report.update(per_part_coverage=coverage,missing_unoccluded_parts=missing)
        report['passed'] &= not missing
        overlays.append(overlay_parts(source,registered_parts(parts,report,source.size),FIT_PROOF_DEFAULTS['overlay_opacity']))
        views[view] = report
    overlay = Image.new('RGBA',(sum(p.width for p in overlays),max(p.height for p in overlays)))
    x = 0
    for image in overlays:
        overlay.paste(image,(x,0));x+=image.width
    result = {'id':spec['id'],'spec_hash':digest(spec),'passed':all(v['passed'] for v in views.values()),'views':views,
              'input_sha256': {'recipe':sha(folder/'measurements.json'),
                  'capture_manifest':sha(capture/'capture_manifest.json'),
                  'native_render_manifest':sha(capture/'native_render_manifest.json'),
                  'sources':recipe['source_sha256']}}
    if spec.get('foot_contacts'):
        from .foot_projection import report
        result['contacts']=report(spec,views,{v:Image.open(PROJECT/recipe['sources'][v]).convert('RGBA') for v in views})
        result['passed'] &= result['contacts']['passed']
    return result,overlay



def write_fit(folder,capture=None):
    capture=Path(capture) if capture else Path(folder)/'delivery'
    result,overlay=compute_fit(folder,capture)
    (capture/'fit_report.json').write_text(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n')
    overlay.save(capture/'fit_overlay.png',optimize=True)
    return result,overlay


def validate_fit(spec,capture):
    folder=PROJECT/'spec/art_identity/maquettes'/Path(spec['source_recipe']).parent
    recipe=json.loads((folder/'measurements.json').read_text())
    if digest(compile_recipe(recipe))!=digest(spec):
        raise ValueError('Fit recipe does not compile to the current spec')
    retained=json.loads((Path(capture)/'fit_report.json').read_text())
    expected,_=compute_fit(folder,capture)
    if not retained.get('passed') or retained!=expected:
        raise ValueError('Failed, stale or non-reproducible fit report')
    for view,minimum in (('front',.70),('rear',.65)):
        result=retained['views'][view]
        if result['iou']<max(minimum,recipe['fit'][view]['gate']['iou_min']):
            raise ValueError('Fit below required IoU: '+view)
    return retained
