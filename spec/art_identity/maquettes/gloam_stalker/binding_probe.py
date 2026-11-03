"""Bridge-only saved-body digest proof and a temporary in-memory hood mutation."""
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
BINDING_PROBE_DEFAULTS = {'vertex_delta_m': .001}


def main(spec_path, build, output):
    from spec.art_identity.maquettes.gloam_stalker.saved_body import load, verify_geometry
    spec, report, objects, combined = load(spec_path, build)
    hood = next(o for o in objects if o.name == 'hood_render')
    vertex = hood.data.vertices[0]
    original = vertex.co.copy()
    vertex.co.x += BINDING_PROBE_DEFAULTS['vertex_delta_m']
    caught = False
    try:
        verify_geometry(objects, report)
    except ValueError:
        caught = True
    finally:
        vertex.co = original
    restored = verify_geometry(objects, report) == combined
    result = {'passed': caught and restored, 'spec_hash': report['spec_hash'],
              'native_mesh_hash': combined, 'loaded_geometry_verified': True,
              'moved_hood_vertex_rejected': caught, 'geometry_restored': restored,
              'probe_defaults': BINDING_PROBE_DEFAULTS}
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('MQ13_SAVED_BODY_BINDING: ' + ('PASS' if result['passed'] else 'FAIL') +
          '; moved_hood_vertex_rejected=' + str(caught) + '; geometry_restored=' + str(restored))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))
