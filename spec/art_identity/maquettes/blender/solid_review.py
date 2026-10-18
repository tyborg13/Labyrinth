"""Hash-validated fit/leg coverage and a shared native-scale roster review sheet.

Inspection-only composition of approved references and genuine native captures.
No drawing, generated artwork, scaling of clay cells, or fit-score stand-ins.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from .backend import load_render
from .compile_recipe import compile_recipe, PROJECT
from .contract import digest
from .curate_delivery import sha, write
from .delivery_validation import validate_delivery
from .fit_delivery import overlay_parts, registered_parts
from ..fitting import frame, keyed_mask, normalise_points, warp_mask, FIT_DEFAULTS
from .pixel_coverage import part_coverage

REVIEW_DEFAULTS = {'cell_size': 768, 'capture_size': 1024, 'caption_height': 28, 'padding': 4,
                   'background': (24,24,24,255), 'caption_colour': 'white',
                   'overlay_opacity': .4, 'sheet_columns': 4,
                   'sheet_format': 'WEBP', 'sheet_quality': 100, 'sheet_method': 6,
                   'front_crop_scale': 2, 'front_crop_padding': 16}
BATCH_A = ('hoarfrost_seer','gale_herald','arc_thrall','gloam_stalker')
LANCER_REFERENCE = 'gloam_stalker/delivery/reference/lancer_r3'


def save_review_sheet(sheet,path):
    sheet.save(path,format=REVIEW_DEFAULTS['sheet_format'],lossless=True,exact=True,
               quality=REVIEW_DEFAULTS['sheet_quality'],method=REVIEW_DEFAULTS['sheet_method'])
    expected=sheet.convert('RGBA').tobytes()
    with Image.open(path) as decoded:
        actual=decoded.convert('RGBA').tobytes()
    if actual!=expected:raise ValueError('Lossless contact sheet changed an RGBA pixel')
    return {'format':'lossless WebP','rgba_identical':True,'size':list(sheet.size),
            'rgba_sha256':hashlib.sha256(expected).hexdigest(),'file_sha256':sha(path)}


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


def inspect_figure(folder):
    folder = Path(folder)
    recipe = json.loads((folder/'measurements.json').read_text())
    spec = compile_recipe(recipe)
    capture = folder/'delivery'
    validate_delivery(spec,capture)
    if spec['ortho_scale'] != 2.4:
        raise ValueError('Clay comparison requires Lancer native scale')
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
        overlays.append(overlay_parts(source,registered_parts(parts,report,source.size),REVIEW_DEFAULTS['overlay_opacity']))
        views[view] = report
    overlay = Image.new('RGBA',(sum(p.width for p in overlays),max(p.height for p in overlays)))
    x = 0
    for image in overlays:
        overlay.paste(image,(x,0));x+=image.width
    overlay.save(capture/'fit_overlay.png',optimize=True)
    result = {'id':spec['id'],'spec_hash':digest(spec),'passed':all(v['passed'] for v in views.values()),'views':views}
    write(capture/'fit_report.json',result)
    return result,overlay


def front_crop(folder):
    folder=Path(folder)
    source=folder/'delivery/front_clay.png'
    with Image.open(source) as native:
        native=native.convert('RGBA')
        bounds=native.getchannel('A').getbbox()
        if not bounds:raise ValueError('Cannot crop an empty native clay')
        padding=REVIEW_DEFAULTS['front_crop_padding']
        x0,y0,x1,y1=bounds
        bounds=[max(0,x0-padding),max(0,y0-padding),min(native.width,x1+padding),min(native.height,y1+padding)]
        crop=native.crop(bounds)
        scale=REVIEW_DEFAULTS['front_crop_scale']
        crop=crop.resize((crop.width*scale,crop.height*scale),Image.Resampling.NEAREST)
    output=folder/'delivery/review'
    output.mkdir(exist_ok=True)
    encoding=save_review_sheet(crop,output/'front_clay_2x.webp')
    write(output/'front_clay_2x.json',dict(encoding,native_clay_sha256=sha(source),
          source_bounds_px=bounds,scale=scale,resampling='nearest; native pixels only'))
    return encoding


def review(folders, output):
    folders,output = [Path(p).resolve() for p in folders],Path(output).resolve()
    results = [inspect_figure(p) for p in folders]
    for folder in folders:front_crop(folder)
    output.mkdir(parents=True,exist_ok=True)
    table = ['| Figure | Front IoU ≥0.70 | Rear IoU ≥0.65 | Fit and all parts |',
             '|---|---:|---:|---|']
    coverage_rows = []
    for (report,_),folder in zip(results,folders):
        views = report['views']
        table.append(f"| {folder.name} | {views['front']['iou']:.6f} | {views['rear']['iou']:.6f} | {'PASS' if report['passed'] else 'FAIL'} |")
        for view,fit in views.items():
            for name,v in fit['per_part_coverage'].items():
                coverage_rows.append([folder.name,view,name,v['visible_pixels'],v['solo_pixels'],v['visible_fraction_of_solo'],v['pure_owner_pixels'],v['clipped_at_canvas'],v['explicit_occlusion'] or ''])
    (output/'fit_table.md').write_text('\n'.join(table)+'\n')
    with (output/'per_part_coverage.csv').open('w',newline='') as handle:
        writer=csv.writer(handle)
        writer.writerow(['figure','view','part','visible_pixels','solo_pixels','visible_fraction_of_solo','pure_owner_pixels','clipped_at_canvas','explicit_occlusion'])
        writer.writerows(coverage_rows)
    # Eight figures, two views each: equal 75% proof cells, four columns. The three
    # front/rear fit overlays form the final row at their source pixel size.
    figures = [(p.name,p/'delivery') for p in folders]
    figures += [('Lancer',PROJECT/'spec/art_identity/maquettes'/LANCER_REFERENCE)]
    figures += [(name,PROJECT/'spec/art_identity/maquettes'/name/'delivery') for name in BATCH_A]
    size,header,columns = (REVIEW_DEFAULTS[k] for k in ('cell_size','caption_height','sheet_columns'))
    cells = [(name,capture,view) for view in ('front','rear') for name,capture in figures]
    rows = (len(cells)+columns-1)//columns
    overlay_height = max(image.height for _,image in results)
    overlay_rows = (len(results)+columns-1)//columns
    sheet = Image.new('RGBA',(columns*size,rows*(size+header)+overlay_rows*(overlay_height+header)),REVIEW_DEFAULTS['background'])
    draw = ImageDraw.Draw(sheet)
    references = {}
    for index,(name,capture,view) in enumerate(cells):
        path = capture/(view+'_clay.png')
        image = Image.open(path).convert('RGBA')
        native_size=REVIEW_DEFAULTS['capture_size']
        if image.size != (native_size,native_size):raise ValueError('Clay comparison requires native 1024 captures')
        image=image.resize((size,size),Image.Resampling.BOX)
        x,y = (index%columns)*size,(index//columns)*(size+header)
        draw.text((x+4,y+4),name+' / '+view+' / 75% sheet / 2.4 m camera',fill=REVIEW_DEFAULTS['caption_colour'])
        sheet.alpha_composite(image,(x,y+header))
        references[str(path.relative_to(PROJECT))] = sha(path)
    for index,((_,overlay),folder) in enumerate(zip(results,folders)):
        x,y = (index%columns)*size,rows*(size+header)+(index//columns)*(overlay_height+header)
        draw.text((x+4,y+4),folder.name+' / fit / front + rear',fill=REVIEW_DEFAULTS['caption_colour'])
        sheet.alpha_composite(overlay,(x,y+header))
    encoding=save_review_sheet(sheet,output/'roster_contact_sheet.webp')
    encoding.update(native_capture_size=REVIEW_DEFAULTS['capture_size'],
                    common_display_scale=size/REVIEW_DEFAULTS['capture_size'],resampling='BOX; every figure uses the same scale')
    write(output/'review_sheet_encoding.json',encoding)
    write(output/'review_inputs.json',references)
    passed=all(r['passed'] for r,_ in results)
    print('\n'.join(table))
    print('SOLID_ROSTER_REVIEW: '+('PASS' if passed else 'FAIL'))
    return passed


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folders',nargs='+',type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    return 0 if review(args.folders,args.out) else 1


if __name__=='__main__':raise SystemExit(main())
