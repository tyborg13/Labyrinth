"""Bind the eight other measured figure deliveries and compiled inputs."""
import hashlib
import json
from pathlib import Path
import subprocess

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from .shoulder_workflow import ROOT


def scope():
    before_path = ROOT / 'gale_herald/proof/mq12_scope_before.json'
    destination = ROOT / 'gale_herald/r2/validation/scope.json'
    before = json.loads(before_path.read_text()) if before_path.exists() else None
    previous = json.loads(destination.read_text()) if before is None else {}
    names = sorted(before) if before is not None else previous['figures']
    after = {}
    for name in names:
        folder = ROOT / name
        files = {str(p.relative_to(ROOT)): sha(p) for p in sorted((folder / 'delivery').rglob('*')) if p.is_file()}
        recipe = folder / 'measurements.json'
        if recipe.is_file():
            files[str(recipe.relative_to(ROOT))] = sha(recipe)
            files['compiled_spec_hash'] = digest(compile_recipe(json.loads(recipe.read_text())))
        after[name] = files
    expected = digest(before) if before is not None else previous['before_sha256']
    worktree = ROOT.parents[2]
    paths = subprocess.check_output(['git', 'diff', 'HEAD', '--name-only', '--',
                                    'spec/art_identity/maquettes'], cwd=worktree, text=True).splitlines()
    foreign = [p for p in paths if Path(p).parts[3] not in ('gale_herald', 'gloam_stalker', 'blender')]
    lancer = ROOT / 'frostglass_lancer/spec_r3.json'
    original = subprocess.check_output(['git', 'show', 'HEAD:spec/art_identity/maquettes/frostglass_lancer/spec_r3.json'], cwd=worktree)
    lancer_before = hashlib.sha256(original).hexdigest()
    result = {'passed': expected == digest(after) and not foreign and lancer_before == sha(lancer), 'figures': names,
              'before_sha256': expected, 'after_sha256': digest(after),
              'changed_figures': [name for name in names if before[name] != after[name]] if before is not None else
                                ([] if expected == digest(after) else ['input_inventory_digest_changed']),
              'other_tracked_maquette_paths_changed': foreign,
              'frostglass_lancer_spec_r3': {'head_sha256': lancer_before, 'current_sha256': sha(lancer)}}
    write(destination, result)
    if not result['passed']:
        raise ValueError('Other figures changed: ' + str(result['changed_figures']))

