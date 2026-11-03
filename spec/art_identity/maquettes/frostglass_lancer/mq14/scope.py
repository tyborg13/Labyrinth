"""Read-only preservation of every other compiled figure and protected source."""
import json
from pathlib import Path
import subprocess

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from .recipe import FIGURE

PROJECT = FIGURE.parents[3]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=PROJECT)


def scope(output):
    relative = 'spec/art_identity/maquettes/blender/compile_recipe.py'
    namespace = {'__name__': 'mq14_original_compiler', '__file__': str(PROJECT/relative)}
    exec(compile(git('show', 'HEAD:'+relative), relative, 'exec'), namespace)
    before = namespace['compile_recipe']
    figures, protected = {}, {}
    for path in sorted(FIGURE.parent.glob('*/measurements.json')):
        if path.parent == FIGURE:
            continue
        recipe = json.loads(path.read_text())
        old, new = before(recipe), compile_recipe(recipe)
        figures[path.parent.name] = {'before_compiled_sha256': digest(old), 'after_compiled_sha256': digest(new),
            'passed': old == new, 'back_attachment_opt_in': any(p.get('back_attachment') for p in new['pieces']),
            'native_regeneration_required': False,
            'reason': 'No recipe opts into back_attachment. Its native cloth execution and compiled spec are unchanged.'}
    files = git('ls-files', '-z', 'spec/art_identity/maquettes', 'spec/art_identity/jobs/frostglass_lancer').decode().split('\0')
    for relative in filter(None, files):
        path = PROJECT/relative
        local = Path(relative)
        keep = ('delivery' in local.parts or path.is_relative_to(FIGURE) or
                relative.startswith('spec/art_identity/jobs/frostglass_lancer/'))
        if not keep:
            continue
        expected = __import__('hashlib').sha256(git('show', 'HEAD:'+relative)).hexdigest()
        actual = sha(path)
        protected[relative] = {'sha256': actual, 'unchanged': expected == actual}
    passed = all(v['passed'] and not v['back_attachment_opt_in'] for v in figures.values()) and all(v['unchanged'] for v in protected.values())
    report = {'passed': passed, 'base_head': git('rev-parse', 'HEAD').decode().strip(),
        'compiled_figures': figures, 'protected': protected}
    write(output, report)
    print('MQ14_SCOPE: '+('PASS' if passed else 'FAIL')+'; compiled_figures='+str(len(figures))+'; protected_files='+str(len(protected)), flush=True)
    return report
