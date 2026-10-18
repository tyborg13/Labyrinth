"""Read-only native control: overlapping bounds on disjoint parallel triangles."""
import json
from pathlib import Path
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def main(output):
    a = [[0, 0, 0], [2, 0, 2], [0, 2, 0]]
    b = [[.2, .2, .3], [1.2, .2, 1.3], [.2, 1.2, .3]]
    first = BVHTree.FromPolygons([Vector(p) for p in a], [[0, 1, 2]])
    second = BVHTree.FromPolygons([Vector(p) for p in b], [[0, 1, 2]])
    overlaps = first.overlap(second)
    result = {'parallel_disjoint_triangles': True, 'bvh_overlap_pairs': overlaps}
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('BVH_DISJOINT_CONTROL: ' + json.dumps(result))


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1])
