# Legacy entry point; all geometry and rendering now use the shared builder.
# FRONT_YAW=0 Blender -b --factory-startup -P gust_shrike.py -- OUT_DIR
import json
import math
import os
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from spec.art_identity.maquettes.humanoid import render
from spec.art_identity.maquettes.shrike_spec import legacy_shrike

out = Path(sys.argv[sys.argv.index('--') + 1])
# Preserve the historical default; committed mq2 captures explicitly used 0.
spec = legacy_shrike(float(os.environ.get('FRONT_YAW', '135')))
render(spec, str(out))
transforms = {}
for view, yaw in [('front', spec['front_yaw']), ('rear', spec['front_yaw'] + 180)]:
    a = math.radians(yaw)
    matrix = np.array([[math.cos(a), -math.sin(a), 0, 0], [math.sin(a), math.cos(a), 0, 0],
                       [0, 0, 1, 0], [0, 0, 0, 1]])
    transforms[view] = {'object_to_world': matrix.tolist(), 'target': spec['target'],
                        'azimuth_deg': 45, 'elevation_deg': 30, 'ortho_scale': spec['ortho_scale'], 'distance': 20}
spec['view_transforms'] = transforms
for name, value in [('spec.json', spec), ('view_transforms.json', transforms)]:
    (out / name).write_text(json.dumps(value, indent=2) + '\n')
