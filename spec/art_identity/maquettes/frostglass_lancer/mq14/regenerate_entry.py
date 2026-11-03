"""Bridge entry: import only the copied input project, then build from source."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True


def main(clean_project, output):
    sys.path.insert(0, str(Path(clean_project).resolve()))
    from spec.art_identity.maquettes.blender.build import main as build
    output = Path(output)
    return build([str(output / 'spec_native.json'), str(output), '--build-only'])


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))
