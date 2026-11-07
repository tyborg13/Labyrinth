"""Stage a private source/resource snapshot. No product file or asset is edited."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path('/private/tmp/labyrinth_codex/sd-12')
SOURCE = Path('/Users/borgerding/workspace/Labyrinth.worktrees/sd-12')
PREVIOUS = Path('/private/tmp/labyrinth_codex/sd-10')
PROJECT = ROOT / 'project'
DIRECTORIES = ('assets', 'addons', 'data', 'fonts', 'scenes', 'scripts', 'shaders', 'themes', 'tools', 'tests', 'spec')
BORROWED_TOOLS = ('gpu_screens.gd', 'gpu_metrics.gd', 'reference_native_steady.gd', 'trace.gd', 'native_ambient.gd')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if PROJECT.exists():
        raise SystemExit('Refusing to replace frozen project: ' + str(PROJECT))
    PROJECT.mkdir()
    for name in (*DIRECTORIES, 'project.godot'):
        subprocess.run(['cp', '-cR', str(SOURCE / name), str(PROJECT / name)], check=True)
    (PROJECT / '.godot').mkdir()
    subprocess.run(['cp', '-cR', str(PREVIOUS / 'project/.godot/imported'), str(PROJECT / '.godot/imported')], check=True)
    for name in ('global_script_class_cache.cfg', 'uid_cache.bin'):
        shutil.copy2(PREVIOUS / 'project/.godot' / name, PROJECT / '.godot' / name)
    subprocess.run(['cp', '-cR', str(PREVIOUS / 'project/cel_look_variants'), str(PROJECT / 'cel_look_variants')], check=True)
    borrowed = {}
    for name in BORROWED_TOOLS:
        original = PREVIOUS / 'tools' / name
        borrowed[name] = digest(original)
        (ROOT / 'tools' / name).write_text(original.read_text().replace(str(PREVIOUS / 'tools'), str(ROOT / 'tools')))
    hashes = {str(p.relative_to(SOURCE)): digest(p) for directory in DIRECTORIES for p in (SOURCE / directory).rglob('*') if p.is_file()}
    hashes['project.godot'] = digest(SOURCE / 'project.godot')
    provenance = {
        'source': str(SOURCE), 'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=SOURCE, text=True).strip(),
        'branch': subprocess.check_output(['git', 'branch', '--show-current'], cwd=SOURCE, text=True).strip(),
        'status_before': subprocess.check_output(['git', 'status', '--porcelain=v1'], cwd=SOURCE, text=True),
        'source_hashes': hashes, 'borrowed_tools_sha256': borrowed,
        'cache_source': str(PREVIOUS / 'project'), 'resource_policy': 'APFS private clones of existing imports and approved cel pack; no asset generation',
    }
    (ROOT / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    (ROOT / 'contract.json').write_text(json.dumps({
        'task': 'sd-12', 'risk_tier': 'low', 'owned': 'proof tooling outside the checkout only',
        'acceptance': [
            'Scratch-only ablations; Vulkan mobile 1280x800 / 115%, cel all, >600 frames per native arm; repeated baselines',
            'Dragon idle/action, Character Gear/Magic/Skills, standard fight idle; every requested layer and individual rig',
            'Marginal main GPU median/p95 versus repeat noise, top five per state with source/scaling attribution',
            'Top-three invisible options with evidence-based savings bounds; no product fixes',
        ],
        'proof': 'Headless parser/fixture/ablation/schema verification; native commands prepared, no tests or GUI runs',
        'inspection': 'Not applicable: measurement only; no playable or product change',
        'workflow': 'Design owner owns preflight, commits, review, inspection, publication; worker performs no Git writes or peer review',
    }, indent=2) + '\n')
    print('SD-12 PREPARE: PASS source_files=%d borrowed_tools=%d product_changes=0' % (len(hashes), len(borrowed)))


if __name__ == '__main__':
    main()
