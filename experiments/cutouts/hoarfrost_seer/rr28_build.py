"""Replay rr-28's clip-scoped own-piece texel continuations, without repainting."""
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.bone_evidence import SAMPLE_FPS
from humanoid_cutout.gait_continuations import nearest_donors, errors

RIGS = {'seer': ('hoarfrost_seer', 'rr10'), 'mimic': ('hollow_mimic', 'rr20')}
BASE_REVISION = '370ab4b13b298b4a32bc1670f4c36916541850da'


def production_layouts(assets, view):
    return [p for p in (assets / f'{view}.json', assets / f'humanoid_v2/{view}.json') if p.is_file()]


def paths(name):
    unit, version = RIGS[name]
    folder = PROJECT / 'experiments/cutouts' / unit
    return folder / version, PROJECT / 'assets/units' / (unit + '_cutout'), folder / 'rr28'


def clip_evidence_errors(case, layout, definitions):
    """Authorize activation from recorded tear poses, never from `clips` itself."""
    clips = read_json(case / 'compiled_motion.json')['clips']
    view = layout['facing']
    evidence = definitions.get(view, {})
    recipes = layout.get('gait_continuations', {})
    invalid = []
    for name in sorted(set(evidence) | set(recipes)):
        tag = f'{view}.{name}'
        expected = set()
        for row in evidence.get(name, {}).get('source_evidence', []):
            clip, frame = row.get('clip'), row.get('frame')
            if (row.get('view') != view or clip not in clips or clip in ('rest', 'idle')
                    or type(frame) is not int or not 0 <= frame < round(clips[clip]['seconds'] * SAMPLE_FPS)):
                invalid.append(f'{tag}: invalid tear evidence {row.get("view")}/{clip}/{frame}')
                continue
            expected.add(clip)
        # Check the source definition as well as a coherently rebuilt layout.
        for label, record in (('definition', evidence.get(name, {})), ('layout', recipes.get(name, {}))):
            declared = set(record.get('clips', []))
            for clip in sorted(declared - expected):
                invalid.append(f'{tag} {label}: clip {clip} has no recorded tear evidence')
            for clip in sorted(expected - declared):
                invalid.append(f'{tag} {label}: evidenced clip {clip} is missing')
    return invalid


def apply(case, layout, definitions):
    for name, definition in definitions.get(layout['facing'], {}).items():
        part = next(p for p in layout['parts'] if p['name'] == name)
        recipe = nearest_donors(case, layout, part, definition['local_targets'])
        recipe['clips'] = definition['clips']
        layout.setdefault('gait_continuations', {})[name] = recipe
    invalid = errors(case, layout) + clip_evidence_errors(case, layout, definitions)
    if invalid:
        raise ValueError(invalid)
    return layout


def build(name):
    case, assets, recipe = paths(name)
    definitions = read_json(recipe / 'joint_continuations.json')
    # Reject unsupported activation in any view before changing capture inputs.
    layouts = {view: apply(case, read_json(case / f'layouts/{view}.json'), definitions)
               for view in ('front', 'rear') if view in definitions}
    counts = {}
    for view, layout in layouts.items():
        write_json(case / f'layouts/{view}.json', layout)
        # Preserve the production-specific prefixes, fields and geometry.
        for path in production_layouts(assets, view):
            production = read_json(path)
            production['gait_continuations'] = layout['gait_continuations']
            write_json(path, production)
        counts[view] = sum(len(r['texels']) for r in layout['gait_continuations'].values())
    # Only this owned closure changes. Shared density/identity/shadow records
    # and every PNG stay byte-identical; playback copies the treated donors.
    path = assets / 'integration.json'
    integration = read_json(path)
    integration['files'] = {name: digest(assets / name) for name in integration['files']}
    write_json(path, integration)
    print(f'RR28 {name.upper()} CONTINUATIONS: PASS ({counts}; own-piece coordinates only)')


if __name__ == '__main__':
    for name in RIGS:
        build(name)
