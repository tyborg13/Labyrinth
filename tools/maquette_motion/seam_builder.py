"""Incremental seam adoption preserves already derived ownership and bleed."""
from pathlib import Path
import subprocess
import sys
import shutil
import tempfile
from cutout_pipeline.cases import CutoutError, baseline, digest, read_json, write_json
from maquette_motion import joint_seams, seam_pose, silhouette, hidden_material


def sample(case, task_id):
    path = case / 'proof/continuity_samples.json'
    command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', task_id, '--stream', '--',
               'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/pixel_samples.gd',
               '--', '--case', str(case.resolve()), '--output', str(path.resolve())]
    result = subprocess.run(command, cwd=Path(__file__).resolve().parents[2], capture_output=True, text=True)
    if result.returncode:
        raise CutoutError('Seam sampler failed: ' + result.stdout + result.stderr)
    return read_json(path)


def seal(case, samples):
    import maquette_cutout
    poses = silhouette.pose_report(case, samples)
    seams = seam_pose.report(case, samples)
    material = hidden_material.report(case, samples)
    definition = read_json(case / 'seams.json')
    design = list(definition['TODO_DESIGN'])
    for row in poses['poses']:
        if row['islands']:
            design.append(dict(row, name=f'TODO_DESIGN_detached_{row["view"]}_{row["clip"]}_{row["frame"]:04d}'))
    parts = silhouette.part_report(case)
    definition_errors = joint_seams.definition_errors(case, samples)
    for error in parts['errors']:
        design.append({'name': 'TODO_DESIGN_seam_connectivity', 'reason': error})
    rest = maquette_cutout.rest_identity(case)
    if not rest['ok']:
        raise CutoutError('Seam underlays changed approved rest RGBA')
    proof = read_json(case / 'proof/continuity.json')
    proof.pop('backing', None)
    for superseded in ('feedback7', 'feedback8'):
        proof.pop(superseded, None)
    proof.update(poses=seam_pose.summary(poses), seams=seam_pose.summary(seams), TODO_DESIGN=design, part_gate=parts,
                 exposed_hidden=seam_pose.summary(material),
                 ok=poses['ok'] and seams['ok'] and parts['ok'] and material['ok'] and not design and not definition_errors)
    proof['feedback12'] = {'authority': 'Director feedback 12', 'blocking_scope': material['blocking_scope'],
                           'approved_painted_exposures': 'Informational; exact original source texel provenance required'}
    if (case / 'support_derivation.json').exists():
        support = read_json(case / 'support_derivation.json')
        proof['feedback11'] = {'authority': 'Director feedback 11', 'derivation': 'support_derivation.json',
                               'supersedes': 'Cumulative margin-search support and historical bleed envelope',
                               'painted_sources_unchanged': True}
        proof['supports'] = support['parts']
    proof['feedback9'] = {'method': 'Capped, connected per-joint seams; seam metrics report-only; all pre-existing paint retained',
                          'samples': 'proof/continuity_samples.json',
                          'samples_sha256': digest(case / 'proof/continuity_samples.json'), 'rest_identity': rest}
    write_json(case / 'proof/continuity.json', proof)
    index = read_json(case / 'hidden_fills/index.json')
    for view in ('front', 'rear'):
        index['protected_inputs'][f'layouts/{view}.json'] = digest(case / f'layouts/{view}.json')
    index['continuity'].pop('backing_tool_sha256', None)
    index['continuity']['joint_seams_tool_sha256'] = digest(Path(__file__).with_name('joint_seams.py'))
    write_json(case / 'hidden_fills/index.json', index)
    derivation = read_json(case / 'proof/feature_derivation.json')
    derivation.update(tool_sha256=digest(Path(__file__).parents[1] / 'maquette_cutout_polish.py'),
                      adapter_sha256=digest(Path(__file__).with_name('feature_builder.py')))
    write_json(case / 'proof/feature_derivation.json', derivation)
    baseline(case)
    return {'ok': proof['ok'],
            'errors': parts['errors'] + definition_errors + poses['errors'] + seams['errors'] + material['errors'],
            'rest_identity': rest, 'parts': parts, 'silhouette': poses, 'seams': seams, 'exposed_hidden': material,
            'pose_accepted': proof['ok'], 'TODO_DESIGN': design,
            'joint_overlap_margin_px': proof['joint_overlap_margin_px']}


def derive(case, task_id):
    with tempfile.TemporaryDirectory(dir=case.parent, prefix='rr05-seams-') as temporary:
        work = Path(temporary) / 'case'
        shutil.copytree(case, work)
        samples = sample(work, task_id)
        joint_seams.install(work, samples)
        result = seal(work, sample(work, task_id))
        # Adopt only after both headless samplers and exact rest validation.
        # Existing material PNGs, features and motion are never rewritten.
        for folder in ('backing', 'seams'):
            shutil.rmtree(case / folder, ignore_errors=True)
        (case / 'backing.json').unlink(missing_ok=True)
        shutil.copytree(work / 'seams', case / 'seams')
        for relative in ('seams.json', 'cutout.json', 'baseline.sha256.json', 'layouts/front.json',
                         'layouts/rear.json', 'proof/continuity.json', 'proof/continuity_samples.json',
                         'proof/feature_derivation.json', 'hidden_fills/index.json'):
            shutil.copyfile(work / relative, case / relative)
    return result
