"""Keep mq-06's cross-figure byte pins scoped to its original audit snapshot."""
import hashlib

from tools.unit_preservation import read_bytes

UNIT_HEAD = '57d2abd813cb2912b32b37d3efc931e6a9f197ac'
OTHER_FIGURE_PREFIXES = tuple('spec/art_identity/maquettes/' + name + '/' for name in
    ('arc_thrall', 'gale_herald', 'gloam_stalker', 'frostglass_lancer',
     'chainbound_gaoler', 'lightning_wisp', 'shale_bloomer'))
OTHER_FIGURE_FILES = tuple('spec/art_identity/maquettes/' + name for name in
    ('gust_shrike.py', 'gust_shrike_prompt_front.md', 'gust_shrike_prompt_rear.md', 'shrike_spec.py'))


def other_figure(name):
    return name.startswith(OTHER_FIGURE_PREFIXES) or name in OTHER_FIGURE_FILES


def protected_hash_changes(project, pins, end=UNIT_HEAD):
    changed = []
    for name, expected in pins.items():
        # Own Seer inputs and shared tooling retain their original live guard.
        revision = end if other_figure(name) else None
        try:
            actual = hashlib.sha256(read_bytes(project, revision, name)).hexdigest()
        except FileNotFoundError:
            actual = None
        if actual != expected:
            changed.append(name)
    return changed
