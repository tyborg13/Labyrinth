"""Read-only anatomy registration evidence for the approved bundle."""
import json
from pathlib import Path
import sys

import bpy


def main(output):
    bundle = Path('~/.cache/labyrinth/blender_human_base_meshes_v1.4.1/extracted/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend').expanduser()
    with bpy.data.libraries.load(str(bundle), link=False) as (source, target):
        names = list(source.objects)
        collections = list(source.collections)
        target.objects = list(source.objects)
    result = {'collections': collections, 'objects': [
        {'name': o.name, 'type': o.type, 'parent': o.parent.name if o.parent else None,
         'matrix': [list(r) for r in o.matrix_world],
         'vertices': [list(v.co) for v in o.data.vertices] if o.type == 'MESH' and 'realistic' in o.name.lower() else [],
         'modifiers': [m.type for m in o.modifiers]} for o in target.objects]}
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(result))
    print('ASSET_INSPECTION: PASS; objects=' + str(len(target.objects)))


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1])
