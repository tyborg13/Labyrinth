"""Native production-spec build/replay regression using untouched raw hashes."""
import json
from pathlib import Path
import sys
import uuid
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.build import build, write
from spec.art_identity.maquettes.blender.contract import DEFAULT_BUNDLE, BUILD_DEFAULTS


def main(spec_path, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    spec = json.loads(Path(spec_path).read_text())
    cache = output / 'cache' / uuid.uuid4().hex
    bundle = Path(DEFAULT_BUNDLE).expanduser()
    _, fresh = build(spec, output / 'fresh', bundle, cache)
    _, replay = build(spec, output / 'replay', bundle, cache)
    assert fresh['passed'] and replay['passed'], (fresh['checks'], replay['checks'])
    assert fresh['mesh_hashes'] == replay['mesh_hashes'], {
        name: [value, replay['mesh_hashes'].get(name)] for name, value in fresh['mesh_hashes'].items()
        if value != replay['mesh_hashes'].get(name)}
    assert fresh['combined_mesh_hash'] == replay['combined_mesh_hash']
    write(output / 'cache_replay_report.json', {'passed': True, 'spec_hash': fresh['spec_hash'],
          'cache_revision': BUILD_DEFAULTS['cache_revision'], 'fresh_cache': str(cache),
          'mesh_hashes': fresh['mesh_hashes'], 'combined_mesh_hash': fresh['combined_mesh_hash'],
          'raw_hashes_identical': True, 'mesh_count': len(fresh['mesh_hashes'])})
    print(f"MQ03_CACHE_REPLAY: PASS; raw_hashes_identical=true; meshes={len(fresh['mesh_hashes'])}")


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])
