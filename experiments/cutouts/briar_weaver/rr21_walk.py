"""Adopt director walk data while retaining approved rest, paint and other clips."""
from rr21_case import CASE, ASSETS, DIRECTOR
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.recompile import rebuild


def adopt():
    anatomy = read_json(CASE / 'anatomy.json')
    anatomy.pop('leg_roles', None)
    anatomy['planted_bones'] = ['foot_near', 'foot_far']
    write_json(CASE / 'anatomy.json', anatomy)
    for view in ('front', 'rear'):
        for folder, name in ((CASE / 'layouts', view), (ASSETS / 'humanoid_v2', view), (ASSETS, view)):
            path = folder / (name + '.json')
            layout = read_json(path)
            layout.pop('leg_roles', None)
            layout['planted_bones'] = anatomy['planted_bones']
            layout['gait_leg_scale_max'] = read_json(DIRECTOR)['briar_weaver']['clips']['move']['gait']['leg_scale_max']
            write_json(path, layout)
    rebuild(CASE, DIRECTOR, ASSETS / 'humanoid_v2')


if __name__ == '__main__': adopt()
