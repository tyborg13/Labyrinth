"""On-demand focused mq27 contract and mutation checks. No permanent test registration."""
import copy
import shutil
import tempfile
from prepare import *
from registration import measured_views, rest_overrun
from maquette_motion import pixels, silhouette
from cutout_pipeline.validation import validate


def verify():
    checks = 0
    def check(value, message):
        nonlocal checks
        checks += 1
        if not value: raise AssertionError(message)
    check((CASE/'director_motion.json').read_bytes() == inputs.DIRECTOR.read_bytes(), 'Protected director motion differs')
    check(validate(CASE)['ok'], 'Structural cutout validation')
    check(pixels.rest_identity(CASE)['ok'], 'Exact source rest identity')
    check(silhouette.part_report(CASE)['ok'], 'Connected physical crops')
    for v, result in rest_overrun().items():
        check(result['outside_paint_texels'] == 0, v + ' outside rest texels')
        check(result['different_rgba_pixels'] == 0, v + ' rest RGBA')
    views = measured_views()
    for view in inputs.VIEWS:
        layout = read_json(CASE / f'layouts/{view}.json')
        for side in ('near','far'):
            for i,ring in enumerate((1,3,5),1):
                check(layout['joints'][f'leg_{side}_{i}']['parent'] == f'seg_{ring}', 'Native ring attachment')
        check(views[view]['outside_diamond_columns_source'] == views[view]['mirrored_outside_diamond_columns_source'], 'Mirrored tile coverage')
        check(all(x <= 6.0+1e-8 for x in views[view]['shadow_axial_overrun_px'] + views[view]['shadow_x_overrun_px']), 'Shadow end overrun in axial and canvas coordinates')
        check(views[view]['shadow']['alpha'] == .62, 'Shadow alpha')
    with adapters():
        errors = gates.motion_errors(CASE, CASE/'proof/motion_samples.json')
        check(not errors, 'Independent motion oracle: ' + str(errors[:3]))
        # Mutations operate on a per-test copy; protected inputs never change.
        with tempfile.TemporaryDirectory(prefix='rr55-mutations-') as directory:
            clone = Path(directory)/'mq27'
            shutil.copytree(CASE, clone, ignore=shutil.ignore_patterns('proof','__pycache__'))
            (clone/'proof').mkdir()
            shutil.copyfile(CASE/'proof/motion_samples.json',clone/'proof/motion_samples.json')
            compiled=read_json(clone/'compiled_motion.json')
            mutated=copy.deepcopy(compiled)
            track=next(t for t in mutated['view_tracks']['front']['gnaw'] if any(k['value']!=0 for k in t['keys']))
            for k in track['keys']: k['value'] *= -1
            write_json(clone/'compiled_motion.json',mutated)
            check(any('Compiled authored' in e for e in gates.motion_errors(clone,clone/'proof/motion_samples.json')), 'Signed-channel mutation rejected')
            write_json(clone/'compiled_motion.json',compiled)
            recipe=read_json(clone/'rig_recipe.json')
            recipe['joints']['leg_near_2']['parent']='seg_2'
            write_json(clone/'rig_recipe.json',recipe)
            try:
                gates.motion_errors(clone,clone/'proof/motion_samples.json')
            except CutoutError:
                check(True,'Native-parent mutation rejected')
            else: check(False,'Native-parent mutation was accepted')
    result={'ok':True,'checks':checks,'mutations_rejected':2,'native_pixels':False}
    write_json(CASE/'proof/focused.json',result)
    print('MQ27 FOCUSED: PASS (%d checks; 2/2 motion/parent mutations rejected)'%checks)


if __name__=='__main__': verify()
