"""rr-20 may change Mimic only; later Seer/Thrall units own their own evidence."""
from unit_preservation import changed_paths

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
