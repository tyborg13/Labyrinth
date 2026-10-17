#!/usr/bin/env python3
"""Measure/fix maquette proportions with the same meshes Blender renders.

See spec/art_identity/maquettes/FITTING.md. V1 uses the numerical rasteriser;
v2 uses Blender's CPU-rendered ownership silhouettes.
"""
import argparse
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from spec.art_identity.maquettes.compatibility import baseline_report, compare, compare_renders, read_spec
from spec.art_identity.maquettes.fitting import FIT_DEFAULTS, fit_spec, measure
from spec.art_identity.maquettes.raster import rasterise
from spec.art_identity.maquettes.shrike_spec import legacy_shrike


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def render_preview(spec, output):
    joints = {}
    for view in ('front', 'rear'):
        raster = rasterise(spec, view)
        Image.fromarray(raster.rgba(spec)).save(output / f'{view}_parts.png')
        Image.fromarray(raster.silhouette.astype(np.uint8) * 255).save(output / f'{view}_silhouette.png')
        for part, mask in raster.masks.items():
            solo = np.zeros((*mask.shape, 4), dtype=np.uint8)
            solo[mask] = 255
            Image.fromarray(solo).save(output / f'{view}_solo_{part}.png')
        joints[view] = raster.joints
    write_json(output / 'joints_px.json', joints)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('measure', 'fit', 'raster', 'compare'):
        p = sub.add_parser(name)
        p.add_argument('--spec', type=Path, required=True)
        p.add_argument('--out', type=Path, required=True)
        p.add_argument('--blender', help='Compatibility option; the director bridge selects the v2 executable')
        p.add_argument('--bundle', type=Path, help='Approved .blend under bridge-allowed roots; omit for the host cache')
        if name == 'measure':
            p.add_argument('--renders', type=Path, help='Existing v2 build/capture with matching spec hash')
        if name in ('measure', 'fit'):
            p.add_argument('--source', type=Path, required=True)
        if name == 'measure':
            p.add_argument('--require-gate', action='store_true')
        if name == 'compare':
            p.add_argument('--baseline', type=Path, required=True, help='Folder with Blender front/rear_parts.png')
            p.add_argument('--candidate', type=Path, help='Compare old/new Blender solo renders instead of raster/Blender')
            p.add_argument('--require-gate', action='store_true')
    p = sub.add_parser('compat')
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--require-gate', action='store_true')
    p = sub.add_parser('shrike-spec')
    p.add_argument('--out', type=Path, required=True)
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    if args.command == 'shrike-spec':
        write_json(args.out / 'spec.json', legacy_shrike())
        return 0
    if args.command == 'compat':
        report = baseline_report()
        write_json(args.out / 'compatibility_report.json', report)
        passed = True
        for name, views in report.items():
            for view in ('front', 'rear'):
                entry = views[view]
                solo = entry['minimum_solo_iou']
                error = entry['max_joint_error_px']
                good = entry['minimum_part_silhouette_iou'] >= 0.98 and (error is None or error <= 1)
                passed &= good
                print(f"{name} {view}: min visible IoU={entry['minimum_visible_iou']:.6f}; min solo IoU={solo}; joint error={error}; {'PASS' if good else 'FAIL'}")
        return 1 if args.require_gate and not passed else 0
    spec = read_spec(args.spec)
    renderer = None
    if spec.get('version') == 2:
        from spec.art_identity.maquettes.blender.backend import BlenderRenderer, DEFAULT_BLENDER, load_render
        renderer = BlenderRenderer(args.out / 'blender', args.blender or DEFAULT_BLENDER, args.bundle)
    if args.command == 'compare':
        if renderer and not args.candidate:
            raise ValueError('Spec v2 comparison requires --candidate Blender captures')
        joints = args.baseline / 'joints_px.json'
        report = compare_renders(spec, args.baseline, args.candidate) if args.candidate else compare(spec, {view: args.baseline / f'{view}_parts.png' for view in ('front', 'rear')}, read_spec(joints) if joints.exists() else None, args.baseline)
        write_json(args.out / 'comparison_report.json', report)
        passed = all(v['minimum_part_silhouette_iou'] >= 0.98 and (v['max_joint_error_px'] is None or v['max_joint_error_px'] <= 1) for v in report.values())
        print('MAQUETTE_COMPARE: ' + ('PASS' if passed else 'FAIL'))
        return 1 if args.require_gate and not passed else 0
    if args.command == 'raster':
        if renderer:
            from shutil import copy2
            folder = renderer.capture(spec, silhouettes=False)
            for path in folder.glob('*.png'):
                copy2(path, args.out / path.name)
            for name in ('joints_px.json', 'build_report.json'):
                copy2(folder / name, args.out / name)
        else:
            render_preview(spec, args.out)
        print('MAQUETTE_RASTER: PASS')
        return 0
    source = Image.open(args.source)
    if args.command == 'fit':
        spec = fit_spec(spec, source, renderer=renderer)
        destination = args.out / 'spec_fit.json'
        if destination.resolve() == args.spec.resolve():
            raise ValueError('Refusing to overwrite the input specification')
        write_json(destination, spec)
    raster = load_render(spec, args.renders) if renderer and getattr(args, 'renders', None) else None
    report, overlay = measure(spec, source, raster=raster, renderer=renderer)
    report['inputs'] = {'spec': str(args.spec), 'source': str(args.source)}
    report['algorithm_defaults'] = FIT_DEFAULTS
    write_json(args.out / 'fit_report.json', report)
    overlay.save(args.out / 'fit_overlay.png')
    print(f"MAQUETTE_FIT: {'PASS' if report['passed'] else 'FAIL'}; IoU={report['iou']:.6f}; median band error={report['median_band_error']:.6f}; max band error={report['max_band_error']:.6f}; conflicting bands={report['conflicting_bands']}")
    return 1 if getattr(args, 'require_gate', False) and not report['passed'] else 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError) as error:
        print('MAQUETTE_FIT_ERROR: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
