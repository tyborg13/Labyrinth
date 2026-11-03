"""mq27 inputs/registration adapters; reuse rr12, rr07 and rr05 unchanged."""
from contextlib import ExitStack, contextmanager
from pathlib import Path
import sys
from unittest.mock import patch

CASE = Path(__file__).resolve().parent
PROJECT = CASE.parents[3]
sys.path.insert(0, str(CASE.parent))
import rr12_inputs as inputs
import rr12_prepare as prepare
import rr12_build as build
import rr12_geometry as geometry
import rr12_gates as gates
import rr12_contract as contract
import rr12_release as release
import rr12_bounds as bounds
from rr12_inputs import read_json, write_json, digest, CutoutError, Image, np

CREATURE = 'burrow_grub'
DELIVERY = PROJECT / 'spec/art_identity/maquettes/burrow_grub/v2/delivery'
PROOF_DEFAULTS = {'input_columns': 6, 'input_cell_px': 255, 'input_label_px': 24,
                  'outside_crop_zoom': 4, 'outside_crop_margin_px': 3,
                  'sampler_timeout_seconds': 300}


def case_for(creature):
    if creature != CREATURE:
        raise CutoutError('mq27 owns Burrow Grub only')
    return CASE


def job_for(creature, view):
    case_for(creature)
    return PROJECT / ('spec/art_identity/jobs/burrow_grub/mq27_' + view)


def audit(creature):
    case_for(creature)
    spec = read_json(DELIVERY / 'source_spec.json')
    packing = read_json(DELIVERY / 'capture_packing.json')['images']
    capture = read_json(DELIVERY / 'capture_report.json')
    names = ['joints_px.json'] + [f'{v}_{k}.png' for v in inputs.VIEWS
        for k in ('parts', 'clay', *('solo_' + p for p in spec['labels']))]
    hashes = {}
    for name in names:
        path = DELIVERY / name
        hashes[name] = digest(path)
        if name.endswith('.png'):
            if hashes[name] != packing[name]['packed_sha256']:
                raise CutoutError('mq27 capture changed: ' + name)
            with Image.open(path) as image:
                if image.size != (1024, 1024):
                    raise CutoutError('mq27 capture dimensions: ' + name)
    joints = read_json(DELIVERY / 'joints_px.json')
    errors = {v: max(float(np.linalg.norm(np.subtract(inputs.projected(spec, p, v), joints[v][n])))
                    for n, p in spec['joints'].items()) for v in inputs.VIEWS}
    if max(errors.values()) > inputs.PROOF_DEFAULTS['registration_joint_tolerance_px']:
        raise CutoutError('mq27 source camera differs: ' + str(errors))
    for v in inputs.VIEWS:
        if inputs.pixel_digest(Image.open(job_for(creature, v) / 'processed.png')) != read_json(job_for(creature, v) / 'processed.json')['pixel_sha256']:
            raise CutoutError('mq27 approved paint differs: ' + v)
    return {'ok': True, 'creature': creature, 'files': hashes,
            'source_spec_sha256': digest(DELIVERY / 'source_spec.json'),
            'capture_report_sha256': digest(DELIVERY / 'capture_report.json'),
            'director_sha256': digest(inputs.DIRECTOR), 'joint_max_error_px': errors,
            'missing': [], 'blender_invocations': 0}


def feature_mask(paint, selection, view):
    """Trace the existing lip inside the head, never generate painted pixels."""
    if view == 'rear':
        return np.zeros(paint.shape[:2], dtype=bool), np.zeros(paint.shape[:2], dtype=bool)
    from PIL import ImageDraw, ImageFilter
    mask = Image.new('L', (255, 255))
    polygon = [(28,183),(39,181),(49,186),(57,197),(62,210),(61,223),
               (55,236),(45,241),(33,238),(23,229),(17,218),(14,204),
               (17,193)]
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    seed = (np.asarray(mask) > 0) & (paint[..., 3] > 0)
    rim = np.asarray(Image.fromarray(seed.astype('uint8') * 255).filter(ImageFilter.MaxFilter(3))) > 0
    return prepare.filled(rim) & (paint[..., 3] > 0), seed


def sample(case, kind='pixel_samples'):
    import subprocess
    target = case / ('proof/' + ('continuity_samples' if kind == 'pixel_samples' else 'motion_samples') + '.json')
    script = 'tests/maquette_cutout/pixel_samples.gd' if kind == 'pixel_samples' else 'tests/maquette_cutout/samples.gd'
    command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-55', '--stream', '--',
               'godot', '--headless', '--path', '.', '--script', script,
               '--', '--case', str(case), '--output', str(target)]
    result = subprocess.run(command, cwd=PROJECT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    target.with_suffix('.log').write_text(result.stdout)
    if result.returncode:
        raise CutoutError('mq27 sampler failed: ' + result.stdout[-5000:])
    print(result.stdout.strip().splitlines()[-1], flush=True)
    return read_json(target)


@contextmanager
def adapters():
    """Only this case is redirected; protected director bytes stay untouched."""
    original_copy = prepare.copy_protected
    original_underlays = build.continuity.underlays
    original_expected = contract.expected
    original_read = prepare.read_json
    original_donors = build.builder.fill_donors
    original_connected = build.connected_hidden_seed
    original_components = build.silhouette.components

    def connected(case, view, part, original):
        # A diagonal-only hidden seed can rasterize as a detached texel after
        # rotation. Retain four-connected hidden support on visible material;
        # the rr12 rule still preserves the largest fully occluded seed.
        with patch.object(build.silhouette, 'components', lambda mask: original_components(mask, 4)):
            return original_connected(case, view, part, original)

    def donors(request, names, views, cross_view_enabled):
        result = original_donors(request, names, views, cross_view_enabled)
        paint, owners, _ = views[request['view']]
        own = owners == names.index(request['part'])
        if not result[2].any() and own.any():
            # A tiny stub may have <40 own texels and be fully occluded in the
            # paired view. Reuse that exact owner's RGB, as the paired-view
            # fallback already does for the reverse view; no foreign donor.
            return [request['part']], paint[..., :3], own, None
        return result

    def staged_read(path):
        if Path(path) == DELIVERY.parent / 'measurements.json':
            path = DELIVERY / 'source_spec.json'
        return original_read(path)

    def copy(source, target):
        if target == CASE / 'source/measurements.json':
            source = DELIVERY / 'source_spec.json'
        original_copy(source, target)

    def expected(case):
        # rr12's independent oracle assumed legs on rings 1/2/3. mq27's native
        # anatomy attaches the same labels to 1/3/5; only this validation input
        # is remapped. Director tracks and their signed oracle stay unchanged.
        original_read = contract.read_json
        recipe = original_read(case / 'rig_recipe.json')
        native = {b['name']: b for b in original_read(case / 'source/spec.json')['armature']['bones']}
        for name, bone in native.items():
            if name.startswith('leg_') and recipe['joints'][name]['parent'] != bone['parent']:
                raise CutoutError('mq27 leg parent differs from native ring: ' + name)
        def read(path):
            value = original_read(path)
            if Path(path) == case / 'rig_recipe.json':
                import copy as copying
                value = copying.deepcopy(value)
                for side in ('near', 'far'):
                    for index in range(1, 4):
                        value['joints'][f'leg_{side}_{index}']['parent'] = f'seg_{index}'
            return value
        with patch.object(contract, 'read_json', read):
            result = original_expected(case)
        result['parents'] = {n: j['parent'] for n, j in read_json(case / 'rig_recipe.json')['joints'].items()}
        return result

    def underlays(case, margin):
        # rr53: the immutable hidden seed is authoritative outside paint too.
        # rr05 still derives its covered support bands. Restore outside seed
        # pixels instead of letting its rest-alpha intersection erase them.
        from maquette_motion.support_seeds import approved
        from maquette_motion.features import source_pixels
        seeds = {(v, p['name']): approved(case, v, p) for v in inputs.VIEWS
                 for p in read_json(case / f'layouts/{v}.json')['parts'] if p.get('hidden_material')}
        result = original_underlays(case, margin)
        for view in inputs.VIEWS:
            layout = read_json(case / f'layouts/{view}.json')
            for part in layout['parts']:
                seed = seeds.get((view, part['name']))
                if seed is None: continue
                image = source_pixels(case, part)
                image[seed[..., 3] > 0] = seed[seed[..., 3] > 0]
                build.continuity.store(case, part, image)
            write_json(case / f'layouts/{view}.json', layout)
        return result

    with ExitStack() as stack:
        for module in (inputs, prepare, release):
            if hasattr(module, 'job_for'): stack.enter_context(patch.object(module, 'job_for', job_for))
        for module in (prepare, build, release, gates, bounds):
            stack.enter_context(patch.object(module, 'case_for', case_for))
        stack.enter_context(patch.object(prepare, 'audit', audit))
        stack.enter_context(patch.object(prepare, 'read_json', staged_read))
        stack.enter_context(patch.object(prepare, 'delivery_for', lambda _: DELIVERY))
        stack.enter_context(patch.object(prepare, 'compile_recipe', lambda _: read_json(DELIVERY / 'source_spec.json')))
        stack.enter_context(patch.object(prepare, 'copy_protected', copy))
        stack.enter_context(patch.object(prepare, 'feature_mask', feature_mask))
        stack.enter_context(patch.object(build, 'sample', sample))
        stack.enter_context(patch.object(build, 'connected_hidden_seed', connected))
        stack.enter_context(patch.object(build.builder, 'fill_donors', donors))
        stack.enter_context(patch.object(build.continuity, 'underlays', underlays))
        stack.enter_context(patch.object(gates, 'expected', expected))
        yield
