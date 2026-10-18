"""Hash-validated fit/leg coverage and a shared native-scale roster review sheet.

Inspection-only composition of approved references and genuine native captures.
No drawing, generated artwork, scaling of clay cells, or fit-score stand-ins.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

from .compile_recipe import compile_recipe, PROJECT
from .curate_delivery import sha, write
from .delivery_validation import validate_delivery
from .solid_fit import silhouette_fit

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


def inspect_figure(folder):
    folder=Path(folder)
    spec=compile_recipe(json.loads((folder/'measurements.json').read_text()))
    validate_delivery(spec,folder/'delivery')
    from .solid_fit import compute_fit
    return compute_fit(folder)


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
    contacts=['| Foot | Front distance (source px) | Rear distance (source px) | Native minimum z (m) | Ground error (m) |',
              '|---|---:|---:|---:|---:|']
    for (report,_),folder in zip(results,folders):
        if not report.get('contacts'):continue
        native=json.loads((folder/'delivery/build_report.json').read_text())['geometry_details']['native_contacts']['feet']
        for name,foot in report['contacts']['feet'].items():
            v=foot['views'];actual=native[name]
            contacts.append(f"| {name} | {v['front']['distance_px']:.6f} | {v['rear']['distance_px']:.6f} | {actual['minimum_z']:.6f} | {actual['ground_error_m']:.6f} |")
    if len(contacts)>2:
        (output/'contact_table.md').write_text('Limits: 2 source px / 0.05 m; plane and exact projections are bound in fit_report.json; no lifted-foot exceptions.\n\n'+'\n'.join(contacts)+'\n')

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
