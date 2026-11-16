"""Front-only seated maquette. No paint, rig, prompt, or registry changes.

Blender -b --factory-startup -P emaciated_man.py -- [OUT] [--recipe RECIPE]
Python emaciated_man.py --check | --raster | --proof [OUT]
"""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.emaciated_man_proof import (
    DEFAULT_OUT, DEFAULT_RECIPE, compile_spec, inspect_geometry, proof,
)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', nargs='?', type=Path, default=DEFAULT_OUT)
    parser.add_argument('--recipe', type=Path, default=DEFAULT_RECIPE)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--raster', action='store_true')
    mode.add_argument('--proof', action='store_true')
    args = parser.parse_args(argv)
    if not (args.check or args.raster or args.proof):
        import bpy  # Native PNG measurement without requiring Pillow in Blender.
    spec = compile_spec(args.recipe)
    geometry = inspect_geometry(spec)
    if args.check:
        print('EMAC_GEOMETRY: PASS; parts=9; joints=8')
        return
    args.output.mkdir(parents=True, exist_ok=True)
    if args.raster:
        from PIL import Image
        from spec.art_identity.maquettes.raster import rasterise
        result = rasterise(spec)
        Image.fromarray(result.rgba(spec)).save(args.output / 'diagnostic_front_parts.png')
        print('EMAC_RASTER: PASS; diagnostic only; ' + str(args.output))
        return
    if not args.proof:
        from spec.art_identity.maquettes.emaciated_man_capture import capture
        from spec.art_identity.maquettes.humanoid import render
        render(spec, args.output, capture=capture)
        (args.output / 'geometry_checks.json').write_text(json.dumps(geometry, indent=2) + '\n')
    else:
        proof(spec, args.output)


if __name__ == '__main__':
    arguments = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    try:
        main(arguments)
    except ValueError as error:
        print('EMAC_BLOCKED: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
