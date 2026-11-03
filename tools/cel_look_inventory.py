"""Read-only character/board inventory; painted backdrops stay original."""
from pathlib import Path
import json

PROP_NAMES = {
    'column_torch_left', 'column_torch_right', 'campfire_bonfire', 'relic_chest',
    'wooden_box', 'wooden_crate', 'powder_keg', 'blacksmith_forge', 'scavenger_stall',
    'dragon_spire', 'ember_cache', 'healing_vial', 'rusty_shield',
    # Director-approved standing objects; recovery badges explicitly opt out.
    'arcanist_table', 'bramble_thicket', 'crag_outcrop', 'raised_cover',
    'watch_brazier_dark', 'watch_brazier_lit',
    'dropped_embers',
}
GROUND_NAMES = {'stone', 'moss', 'ember'}


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)


def resolve(project, base, value):
    return project / value[6:] if value.startswith('res://') else base / value


def classify_prop(path):
    """Explicit approved scope only. Return scope/category and review reason."""
    if path.suffix != '.png':
        return 'off', 'metadata', 'Godot import metadata; original'
    stem = path.stem
    if stem in GROUND_NAMES or stem.endswith('_floor'):
        # Owner, 2026-10-30: the filtered floor reads too muddy; floors and ground decals stay original.
        return 'off', 'ground', 'Board ground or ground decal; original (owner: too muddy with the filter)'
    if 'backgrounds' in path.parts:
        return 'off', 'backdrops', 'Painted backdrop behind the board; original'
    if 'biomes' in path.parts or 'placeholders' in path.parts:
        if 'floor' in stem:
            return 'off', 'floors', 'Board floor; original (owner: too muddy with the filter)'
        return 'all', 'board_structure', 'Board pillar, wall, door, light or obstacle overlay'
    if 'traps' in path.parts:
        return 'all', 'traps', 'Board trap and its idle/activation frames'
    base = stem.removesuffix('_idle').removesuffix('_destroy')
    if base in PROP_NAMES or 'relic_chest_hinge_v1' in path.parts:
        return 'all', 'props', 'Approved standing board prop/pickup or its frames'
    return 'off', 'undecided', 'TODO_DESIGN_cel_scope_' + path.name.replace('.', '_')


def tileable(path):
    """Floor surfaces use wrap boundaries, never an image-edge clamp."""
    return path.stem in GROUND_NAMES or 'floor' in path.stem


def inventory(project):
    project = Path(project)
    assignments = {}
    classifications = []
    identities = {}
    for registry in ['data/enemies.json', 'data/npcs.json']:
        if (project / registry).exists():
            for identity, data in json.loads((project / registry).read_text()).items():
                for key in ['art_path', 'art_rear_path']:
                    if data.get(key):
                        stem = Path(data[key]).stem.removesuffix('_rear')
                        identities.setdefault(stem, identity)
    def add(path, rest, facing, category, scope='actors'):
        rel = path.relative_to(project).as_posix()
        assignments[rel] = {'path': rel, 'rest': rest.relative_to(project).as_posix(),
                            'facing': facing, 'category': category, 'scope': scope}
    for root in sorted((project / 'assets/units').glob('*')):
        if root.suffix == '.png':
            facing = 'rear' if root.stem.endswith('_rear') else 'front'
            add(root, root, root.stem.removesuffix('_rear') + '/' + facing, 'legacy_actors')
            continue
        if not root.is_dir():
            continue
        cases = sorted(root.glob('*')) if root.name == 'guardians' else [root]
        for case in cases:
            if not case.is_dir():
                continue
            name = case.name.removesuffix('_cutout')
            layouts = sorted([*case.rglob('front.json'), *case.rglob('rear.json')])
            sources = {}
            referenced = {}
            for layout in layouts:
                data = json.loads(layout.read_text())
                facing = layout.stem
                base = layout.parent
                rest = resolve(project, base, data.get('rest_source', facing + '/rest.png'))
                if not rest.exists() and (base / 'rest.png').exists():
                    rest = base / 'rest.png'
                if not rest.exists():
                    rest = project / ('assets/art/npcs/' + name + '.png')
                if not rest.exists():
                    raise ValueError(f'No assembled rest for {layout}')
                sources[(base, facing)] = rest
                for value in strings(data):
                    if value.endswith('.png'):
                        path = resolve(project, base, value)
                        if path.exists():
                            referenced.setdefault(path, []).append((rest, name + '/' + facing))
            for path in sorted(case.rglob('*.png')):
                if 'gear' in path.relative_to(case).parts or path.name.startswith('gear_rest'):
                    add(path, path, name + '/gear', 'hero_gear')
                    continue
                refs = referenced.get(path, [])
                # Authored shared source files use the same rest (e.g. the
                # Capacitor's glow levels); flag genuinely competing palettes.
                if len({r.read_bytes() for r, _f in refs}) > 1:
                    classifications.append({'path': path.relative_to(project).as_posix(), 'scope': 'off',
                        'category': 'ambiguous_facing', 'reason': 'TODO_DESIGN_cel_palette_' + path.name.replace('.', '_'),
                        'models': sorted(str(r.relative_to(project)) for r, _ in refs)})
                    continue
                if refs:
                    rest, facing = refs[0]
                else:
                    candidates = [(base, f, r) for (base, f), r in sources.items()
                                  if path.is_relative_to(base) and f in path.relative_to(base).parts]
                    if candidates:
                        base, f, rest = max(candidates, key=lambda item: len(item[0].parts))
                        facing = name + '/' + f
                    else:
                        # Non-facing paint/underlay files belong to the only
                        # layout, or to the front when rear uses the same rest.
                        front = [(b, f, r) for (b, f), r in sources.items() if f == 'front' and path.is_relative_to(b)]
                        if not front:
                            raise ValueError(f'No facing for {path}')
                        _, f, rest = max(front, key=lambda item: len(item[0].parts))
                        facing = name + '/' + f
                add(path, rest, facing, 'guardian_rigs' if root.name == 'guardians' else 'rigs')
    # Director: the painted turn-order portraits are character art too (owner: cel everywhere the characters are).
    for directory, category in [('assets/art/enemies', 'enemy_images'), ('assets/art/npcs', 'npc_bodies'),
                                ('assets/placeholders/units', 'legacy_fallbacks'), ('assets/art/portraits', 'portraits')]:
        for path in sorted((project / directory).glob('*.png')):
            stem = path.stem.removesuffix('_idle').removesuffix('_death')
            base = path.with_name(stem + '.png')
            # Rear sheets use their rear still; otherwise the actor's base.
            if not base.exists():
                base = path.with_name(stem.removesuffix('_rear') + '.png')
            if not base.exists():
                base = path
            facing = 'rear' if stem.endswith('_rear') else 'front'
            identity = identities.get(stem.removesuffix('_rear'), stem.removesuffix('_rear'))
            add(path, base, identity + '/' + facing, category)
    for directory in ['assets/art/tiles', 'assets/art/traps', 'assets/art/props', 'assets/props',
                      'assets/placeholders/tiles', 'assets/art/biomes', 'assets/art/backgrounds']:
        for path in sorted((project / directory).rglob('*')):
            if not path.is_file():
                continue
            scope, category, reason = classify_prop(path)
            if directory == 'assets/props' and path.suffix == '.png' and path.stem not in PROP_NAMES:
                scope, category, reason = 'off', 'undecided', 'TODO_DESIGN_cel_scope_' + path.name.replace('.', '_')
            classifications.append({'path': path.relative_to(project).as_posix(), 'scope': scope,
                                    'category': category, 'reason': reason})
            if scope == 'all':
                stem = path.stem
                for suffix in ('_idle', '_destroy', '_activation'):
                    stem = stem.removesuffix(suffix)
                base = path.with_name(stem + '.png')
                # A prop/trap fits itself; its atlas uses that prop's base fit,
                # just like an actor atlas, rather than fitting each sheet.
                # Board surfaces/structures each fit themselves. Keep existing
                # prop/trap frame sheets on their prop's palette.
                rest = base if category in ('props', 'traps') and base.exists() else path
                add(path, rest, stem, category, scope)
                assignments[path.relative_to(project).as_posix()]['tileable'] = tileable(path)
    return sorted(assignments.values(), key=lambda e: e['path']), classifications
