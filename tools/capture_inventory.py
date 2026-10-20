"""Complete Seer/Mortar proof inventory, independent of capture storage codec."""
from collections import Counter
from pathlib import Path
import json
import subprocess

from cutout_pipeline.cases import read_json
from humanoid_cutout.native_frames import stored_path
from humanoid_cutout.capture_equivalence import native_files
from maquette_cutout_review import plan

FPS = 60
IDLE_COMPARISON_SECONDS = 0.84  # Existing native writer's protagonist clock.
IDLE_COMPARISON_LOOPS = 5
GAIT_FRAMES_PER_VIEW = 12
CASES = {'seer': ('hoarfrost_seer', 'rr10'), 'mortar': ('slag_mortar', 'rr22')}


def require_file(path):
    if not path.is_file():
        raise ValueError('Missing artifact: ' + str(path))


def exact_set(actual, expected, root):
    missing, extra = expected - actual, actual - expected
    if missing:
        raise ValueError('Missing artifact: ' + str(root / sorted(missing)[0]))
    if extra:
        raise ValueError('Extra artifact: ' + str(root / sorted(extra)[0]))


def row_set(manifest, field, expected, folder):
    rows = manifest.get(field, [])
    actual = [row['file'] for row in rows]
    exact_set(set(actual), expected, folder)
    duplicates = [path for path, count in Counter(actual).items() if count != 1]
    if duplicates:
        raise ValueError('Duplicate artifact: ' + str(folder / duplicates[0]))


def native_inventory(data, layouts, idle=False):
    views = ['front'] if idle else list(data['view_tracks'])
    files = {'rest_pair.png'} | {view + '_rest.png' for view in views}
    groups = {f'groups/{view}/{group}_rest.png' for view in views for group in layouts[view]['idle_groups']}
    files |= groups
    fields = {key: set() for key in ('frames', 'pairs', 'pieces', 'idle_groups', 'rest_holes', 'joint_seams', 'feature_masks')}
    if idle:
        files |= {f'idle_comparison/frame_{i:04d}.png' for i in range(round(IDLE_COMPARISON_SECONDS * FPS * IDLE_COMPARISON_LOOPS))}
        return files, fields
    for clip, definition in data['clips'].items():
        for frame in range(round(definition['seconds'] * FPS)):
            fields['pairs'].add(f'pair_{clip}/frame_{frame:04d}.png')
            for view in views:
                layout = layouts[view]
                fields['frames'].add(f'{view}_{clip}/pose_{frame:04d}.png')
                for part in layout['parts']:
                    path = f'pieces/{clip}/{frame:04d}/{view}/{part["name"]}.png'
                    fields['pieces'].add(path)
                    files.add(path.removesuffix('.png') + '_checks.png')
                for field, directory, layout_field in (('rest_holes', 'holes', 'proof_rest_holes'),
                        ('joint_seams', 'seams', 'proof_joint_seams'), ('feature_masks', 'features', 'features')):
                    for item in (layout.get(layout_field, []) if field != 'feature_masks' or data['creature'] == 'slag_mortar' else []):
                        fields[field].add(f'{directory}/{clip}/{frame:04d}/{view}/{item["name"]}.png')
                if clip == 'idle':
                    fields['idle_groups'] |= {f'groups/{view}/{group}/frame_{frame:04d}.png' for group in layout['idle_groups']}
    return files | set().union(*fields.values()), fields


def production_counts(case, view):
    # The case's recorded fixed-clock production inventory is authoritative,
    # including recovery/contact samples beyond the authored clip's 60Hz reel.
    relative = 'proof/production_logic.json' if case.name == 'rr10' else (
        'proof/production_logic_rear/logic_frames.json' if view == 'rear' else 'proof/production_logic/logic_frames.json')
    record = read_json(case / relative)
    return Counter(record['stage_counts']) if 'stage_counts' in record else Counter(row['stage'] for row in record['frames'])


def capture_sets():
    return {f'{name}/{kind}' for name in CASES for kind in ('native', 'idle_native', 'production/front')} | {
        'mortar/production/rear', 'mortar/gait_move_native'}


def report_sets():
    return {f'{name}/native_gates.json' for name in CASES} | {
        f'{name}/native/source_space_pockets.json' for name in CASES} | {
        f'{name}/production/{view}/production_gates.json' for name in CASES
        for view in (('front', 'rear') if name == 'mortar' else ('front',))} | {'mortar/logs/native_gates_full.json'}


def exit_sets():
    return {f'{name}/native_gate_exit.json' for name in CASES} | {
        f'{name}/production/{view}/production_gate_exit.json' for name in CASES
        for view in (('front', 'rear') if name == 'mortar' else ('front',))}


def reel_sets():
    return {f'{name}/{mode}.mp4' for name in CASES for mode in ('review', 'idle')}


def video_inventory(path, count):
    result = subprocess.run(['ffprobe', '-v', 'error', '-count_frames', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,r_frame_rate,nb_read_frames', '-of', 'json', str(path)],
        check=True, capture_output=True, text=True)
    streams = json.loads(result.stdout)['streams']
    if (len(streams) != 1 or streams[0].get('width') != 1920 or streams[0].get('height') != 1080 or
            streams[0].get('r_frame_rate') != '60/1' or int(streams[0].get('nb_read_frames', 0)) != count):
        raise ValueError('Decoded reel inventory differs: ' + str(path))


def validate(root, project, *, gate_exits=True, decode_reels=False):
    """Fail closed, including equally missing/extra evidence on both sides."""
    root = Path(root)
    captures, reports, reels = capture_sets(), report_sets(), reel_sets()
    # Private gate cases contain source/build/sample records, never captures.
    exact_set({p.relative_to(root).as_posix() for p in root.rglob('frames.json')},
              {relative + '/frames.json' for relative in captures}, root)
    exact_set({p.relative_to(root).as_posix() for p in root.rglob('*.mp4')}, reels, root)
    actual_reports = {p.relative_to(root).as_posix() for p in root.rglob('*.json')
                      if 'gates' in p.stem or p.name == 'source_space_pockets.json'}
    exact_set(actual_reports, reports, root)
    for relative in reports:
        report = read_json(root / relative)
        if relative.endswith('source_space_pockets.json'):
            valid = isinstance(report, list)
        else:
            valid = isinstance(report, dict) and type(report.get('ok')) is bool and isinstance(report.get('errors'), list)
        if not valid: raise ValueError('Incomplete gate JSON: ' + str(root / relative))
    for name, (creature, number) in CASES.items():
        case = project / 'experiments/cutouts' / creature / number
        data = read_json(case / 'compiled_motion.json')
        layouts = {view: read_json(case / f'layouts/{view}.json') for view in data['view_tracks']}
        for kind in ('native', 'idle_native', 'production/front', *(['production/rear', 'gait_move_native'] if name == 'mortar' else [])):
            folder = root / name / kind
            manifest = read_json(folder / 'frames.json')
            if manifest.get('ok') is not True or manifest.get('errors', []) or not manifest.get('native_pixels'):
                raise ValueError('Capture/manifest error: ' + str(folder / 'frames.json'))
            if manifest.get('size') != [1920, 1080] or manifest.get('ui_scale') != 1:
                raise ValueError('Capture environment differs: ' + str(folder / 'frames.json'))
            if kind in ('native', 'idle_native'):
                expected, fields = native_inventory(data, layouts, kind == 'idle_native')
                for field, paths in fields.items():
                    row_set(manifest, field, paths, folder)
            elif kind == 'gait_move_native':
                expected = {f'{view}_move_{frame:02d}.png' for view in data['view_tracks'] for frame in range(GAIT_FRAMES_PER_VIEW)}
                row_set(manifest, 'frames', expected, folder)
            else:
                rows = manifest['frames']
                if set(row['stage'] for row in rows) != set(data['clips']):
                    raise ValueError('Production clip inventory differs: ' + str(folder / 'frames.json'))
                counts = Counter(row['stage'] for row in rows)
                expected_counts = production_counts(case, kind.split('/')[-1])
                if set(expected_counts) != set(data['clips']) or counts != expected_counts:
                    raise ValueError('Production frame inventory differs: ' + str(folder / 'frames.json') +
                                     '; expected ' + str(dict(expected_counts)) + ', got ' + str(dict(counts)))
                expected = {f'frame_{i:05d}_{row["stage"]}.png' for i, row in enumerate(rows)}
                row_set(manifest, 'frames', expected, folder)
                if any(not r.get('pixels_sha256') for r in rows):
                    raise ValueError('Missing renderer hash: ' + str(folder / 'frames.json'))
                # rr22's separate pre-battle proof is intentionally uncropped.
                if name == 'mortar': expected.add('prebattle_panel.png')
            actual = native_files(folder, manifest)
            # prebattle_panel is deliberately outside the storage index.
            if (folder / 'prebattle_panel.png').is_file(): actual.add('prebattle_panel.png')
            exact_set(actual, expected, folder)
            for logical in sorted(expected):
                require_file(stored_path(folder / logical))
            index = folder / 'native_storage.json'
            if index.is_file():
                for record in read_json(index)['files'].values():
                    if record.get('reference'): require_file(folder / record['reference'])
                payloads = [record['stored_file'] for record in read_json(index)['files'].values()]
                physical = set(payloads)
                if len(physical) != len(payloads):
                    duplicate = next(path for path, count in Counter(payloads).items() if count > 1)
                    raise ValueError('Duplicate artifact: ' + str(folder / duplicate))
                physical |= {record['reference'] for record in read_json(index)['files'].values() if record.get('reference')}
                if name == 'mortar' and kind.startswith('production/'): physical.add('prebattle_panel.png')
                actual_physical = {p.relative_to(folder).as_posix() for p in folder.rglob('*')
                                   if p.suffix in ('.png', '.webp', '.rgba') and 'proof_exports' not in p.relative_to(folder).parts}
                exact_set(actual_physical, physical, folder)
            else:
                actual_physical = {p.relative_to(folder).as_posix() for p in folder.rglob('*')
                                   if p.suffix in ('.png', '.webp', '.rgba') and 'proof_exports' not in p.relative_to(folder).parts}
                exact_set(actual_physical, expected, folder)
        order = list(read_json(case / 'director_motion.json')[data['creature']]['clips'])
        counts = {'idle': round(data['clips']['idle']['seconds'] * FPS * IDLE_COMPARISON_LOOPS),
                  'review': sum(round(data['clips'][clip]['seconds'] * FPS) * loops + (FPS if clip == 'death' else 0)
                                for clip, loops in plan(data, order))}
        for mode, count in counts.items():
            record_path = root / name / (mode + '.json')
            require_file(record_path)
            if read_json(record_path).get('frames') != count:
                raise ValueError('Reel frame inventory differs: ' + str(record_path))
            if decode_reels: video_inventory(root / name / (mode + '.mp4'), count)
        sheet_folder = root / name / 'contact_sheets'
        require_file(sheet_folder / 'manifest.json')
        if read_json(sheet_folder / 'manifest.json').get('frames') != len(data['view_tracks']) * len(data['clips']):
            raise ValueError('Contact sheet inventory differs: ' + str(sheet_folder / 'manifest.json'))
        exact_set({p.name for p in sheet_folder.glob('*.png')},
                  {f'{view}_{clip}_3x.png' for view in data['view_tracks'] for clip in data['clips']}, sheet_folder)
    require_file(root / 'mortar/gait_move_sheet.png')
    require_file(root / 'mortar/gait_move_sheet.json')
    if len(read_json(root / 'mortar/gait_move_sheet.json').get('frames', [])) != GAIT_FRAMES_PER_VIEW * 2:
        raise ValueError('Gait sheet inventory differs: ' + str(root / 'mortar/gait_move_sheet.json'))
    if gate_exits:
        actual_exits = {p.relative_to(root).as_posix() for p in root.rglob('*gate_exit.json')}
        exact_set(actual_exits, exit_sets(), root)
        for relative in exit_sets():
            status = read_json(root / relative)
            report = relative.replace('native_gate_exit.json', 'native_gates.json').replace('production_gate_exit.json', 'production_gates.json')
            gate = read_json(root / report)
            if type(status.get('exit_code')) is not int or (status['exit_code'] == 0) != gate['ok']:
                raise ValueError('Gate process outcome differs from JSON: ' + str(root / relative))
    return captures, reports, reels
