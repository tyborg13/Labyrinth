"""rr-20 may change Mimic only; later Seer/Thrall units own their own evidence."""
import hashlib
import json
from unit_preservation import changed_paths, read_bytes

# Integration imported by rr-20's final merge, including authorized gait-01
# changes to prior figures. Compare its tree with rr-20's signed-off tree.
BASELINE_COMMIT = '73e076bfb10a6a97eb23954e59954aaf318cb181'
UNIT_HEAD = '901d327897650870b05f9208e2d028df8ad6efdf'
PRIOR_PREFIXES = ('assets/units/', 'experiments/cutouts/')
OWNED_PREFIXES = ('assets/units/hollow_mimic_cutout/', 'experiments/cutouts/hollow_mimic/')


def prior_figure(name):
    return name.startswith(PRIOR_PREFIXES) and not name.startswith(OWNED_PREFIXES)


def protected_changes(project, baseline=BASELINE_COMMIT, end=UNIT_HEAD):
    return [name for name in changed_paths(project, baseline, end)
            if prior_figure(name)]


def own_input_errors(project, end=UNIT_HEAD):
    """rr-20's own approved inputs are pins at its signed-off unit head.

    mq-11 and rr-29 deliberately replace these inputs later. Reading today's
    tree here would make an older unit veto those explicitly authorized units.
    """
    inventory = json.loads(read_bytes(project,end,
        'experiments/cutouts/hollow_mimic/rr20/protected_inputs.json'))
    return ['Protected/baseline bytes changed: '+name for name,expected in inventory.items()
        if not prior_figure(name) and hashlib.sha256(read_bytes(project,end,name)).hexdigest()!=expected]
