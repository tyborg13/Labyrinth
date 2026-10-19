"""Compare protected inputs with a pinned integration commit, including commits."""
import hashlib
import subprocess

BASELINE_COMMIT = '521fa8f204f6f3b5d0aca1d09ec2494107c155d9'
PROTECTED_PREFIXES = ('assets/units/', 'assets/art/', 'scripts/', 'experiments/cutouts/',
                      'spec/art_identity/maquettes/', 'spec/art_identity/jobs/',
                      'spec/peer_benchmark/staged/', 'spec/assets/board_pixel_density/sources/')
OWNED_PREFIXES = ('assets/units/glacial_mirror_cutout/', 'experiments/cutouts/glacial_mirror/',
                  'spec/assets/board_pixel_density/sources/assets/units/glacial_mirror_cutout/')
# Only exact director-approved bytes qualify, never arbitrary changes to a path.
# rr-23 has no permission to author motion. These are the integrated gait-01 inputs.
APPROVED_MOTION_SHA256 = {
    'spec/peer_benchmark/staged/rr-11/motion_tracks.json': 'b584128e4b02884a76c1df4b9d7e3c360c59189869fc5aeebfdcfc79e0b7314a',
    'spec/peer_benchmark/staged/rr-18/motion_tracks.json': '31f78bfc141976e1998fbacdffa4ae2b3d6945c4545f8bdffaa774c895643aa2',
}


def protected_changes(project, baseline=BASELINE_COMMIT, approved_motion=None):
    approved = APPROVED_MOTION_SHA256 if approved_motion is None else approved_motion
    changed = subprocess.check_output(['git', 'diff', '--no-renames', '--name-only', '-z', baseline, '--'],
                                      cwd=project).decode().split('\0')
    changed += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '-z'],
                                       cwd=project).decode().split('\0')
    errors = []
    for name in sorted(set(changed)):
        if not name or not name.startswith(PROTECTED_PREFIXES) or name.startswith(OWNED_PREFIXES):
            continue
        path = project/name
        if name in approved and path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == approved[name]:
            continue
        errors.append(name)
    return errors
