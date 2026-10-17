"""Isolate whether approved HEAD already reorders cloth faces on a cache hit."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(source, spec_path, output, cache, candidate_report):
    from spec.art_identity.maquettes.blender import cloth as module
    from spec.art_identity.maquettes.blender.build import build
    from spec.art_identity.maquettes.blender.contract import DEFAULT_BUNDLE
    namespace = {'__file__': source, '__package__': module.__package__, '__name__': module.__name__}
    exec(compile(Path(source).read_text(), source, 'exec'), namespace)
    module.cloth = namespace['cloth']
    _, report = build(json.loads(Path(spec_path).read_text()), output, Path(DEFAULT_BUNDLE).expanduser(), cache)
    other = json.loads(Path(candidate_report).read_text())
    identical = report['mesh_hashes'] == other['mesh_hashes']
    assert identical, 'Current code differs from HEAD cache replay'
    print('HEAD_CACHE_REPLAY_COMPARISON: PASS; mesh_hashes_identical=true')


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])
