"""Copy the case closure to production; never certify native rests."""
from copy import deepcopy
from pathlib import Path
import shutil

from cutout_pipeline.cases import digest, write_json


def promote(project, case, assets, layouts):
    assets.mkdir(parents=True, exist_ok=True)
    for name in ('compiled_motion.json', 'director_motion.json'):
        shutil.copyfile(case / name, assets / name)
    for view, source in layouts.items():
        layout = deepcopy(source)
        for part in layout['parts'] + layout['joint_meshes']:
            target = assets / view / Path(part['file']).name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(case / part['file'], target)
            part['file'] = str(target.relative_to(assets))
        # Proof/source ownership lives in the editable case. The shipped rig
        # needs only its paint, mesh topology, joints and protected motion.
        for key in ('proof_layers', 'proof_joint_seams', 'proof_rest_holes', 'ownership_overrides', 'features', 'occluded_surfaces', 'covered_surface_masks'):
            layout.pop(key, None)
        rest = assets / view / 'rest.png'
        shutil.copyfile(case / source['rest_source'], rest)
        layout['rest_source'] = str(rest.relative_to(assets))
        layout['rest_source_sha256'] = digest(rest)
        layout['motion_data'] = 'res://' + str(assets.relative_to(project) / 'compiled_motion.json')
        write_json(assets / (view + '.json'), layout)
