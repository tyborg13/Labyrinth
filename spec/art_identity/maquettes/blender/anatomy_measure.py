"""Read source anatomy bounds from an existing native build, through the bridge."""
import json
from pathlib import Path
import sys
import bpy


def main(paths):
    for path in paths:
        bpy.ops.wm.open_mainfile(filepath=str(Path(path).resolve()))
        obj = bpy.data.objects['posed_body']
        owners = json.loads(obj['face_owners'])
        result = {}
        for owner in sorted(set(owners)):
            indices = sorted({i for p, label in zip(obj.data.polygons, owners) if label == owner for i in p.vertices})
            points = [obj.matrix_world @ obj.data.vertices[i].co for i in indices]
            result[owner] = {'minimum': [min(p[a] for p in points) for a in range(3)],
                             'maximum': [max(p[a] for p in points) for a in range(3)]}
        print('ANATOMY_MEASURE: ' + json.dumps({'path': str(path), 'bounds': result}), flush=True)


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:])
