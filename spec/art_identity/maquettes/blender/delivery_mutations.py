"""Run isolated verifier regressions with each feedback-5 guard removed."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from .curate_delivery import write

MUTATIONS = {
    'failed_reports_accepted': ("""
from spec.art_identity.maquettes.blender import quality_delivery,curate_delivery
quality_delivery.validate_delivery=lambda *a,**k:None
curate_delivery.validate_delivery=lambda *a,**k:None
""", 'DeliveryValidationTests.test_copied_thrall_mutation_exits_nonzero_in_both_delivery_tools'),
    'part_maps_ignored': ("""
from spec.art_identity.maquettes.blender import test_delivery_validation as t
original=t.compare_captures
def broken(*a,**k):
    result=original(*a,**k)
    for view in result.values():view['parts']['passed']=True
    return result
t.compare_captures=broken
""", 'RegenerationRasterTests.test_correct_clays_cannot_mask_missing_or_red_maps'),
    'native_pngs_reencoded': ("""
from spec.art_identity.maquettes.blender import curate_delivery as c
original=c.shutil.copyfile
def broken(source,destination,*a,**k):
    if str(source).endswith('.png'):return c.canonical_png(source,destination,mask='clay' not in str(source))
    return original(source,destination,*a,**k)
c.shutil.copyfile=broken
""", 'DeliveryValidationTests.test_staging_preserves_native_png_bytes_including_stamps'),
    'required_parts_not_rejected': ("""
from spec.art_identity.maquettes.blender import ownership
ownership.require_solos=lambda *a,**k:None
""", 'existing_helper'),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    results = {}
    for name, (mutation, test) in MUTATIONS.items():
        module = 'spec.art_identity.maquettes.blender.test_delivery_validation'
        if test == 'existing_helper':
            module = 'spec.art_identity.maquettes.blender.test_delivery'
            test = 'DeliveryTests.test_required_parts_reject_missing_zero_and_negative_solos'
        if name == 'failed_reports_accepted':
            # The entry-point test launches fresh interpreters. Inject the
            # mutation in each child rather than only patching this process.
            mutation = """
import subprocess
original=subprocess.run
def broken(command,**kwargs):
    if 'unittest' not in command:
        prefix="from spec.art_identity.maquettes.blender import delivery_validation as v;v.validate_delivery=lambda *a,**k:None;"
        if '-m' in command:
            i=command.index('-m');module=command[i+1];argv=command[i+2:]
            code=prefix+"import sys,runpy;sys.argv="+repr([module]+argv)+";runpy.run_module("+repr(module)+",run_name='__main__')"
        else:
            script=command[2];argv=command[3:]
            code=prefix+"import sys,runpy;sys.argv="+repr([script]+argv)+";runpy.run_path("+repr(script)+",run_name='__main__')"
        command=[command[0],'-B','-c',code]
    return original(command,**kwargs)
subprocess.run=broken
"""
        code = mutation + '\nimport unittest\nsuite=unittest.defaultTestLoader.loadTestsFromName(' + repr(module + '.' + test) + ')\n'
        code += 'result=unittest.TextTestRunner(verbosity=2).run(suite)\nraise SystemExit(0 if result.wasSuccessful() else 1)\n'
        result = subprocess.run([sys.executable, '-B', '-c', code], text=True, capture_output=True)
        (args.out / (name + '.log')).write_text(result.stdout + result.stderr)
        # An import/runner error is not evidence that the mutation was caught.
        caught = result.returncode == 1 and 'FAIL:' in result.stderr and 'Ran 1 test' in result.stderr
        results[name] = {'caught': caught, 'test_exit': result.returncode,
                         'regression': module + '.' + test}
    passed = all(r['caught'] for r in results.values())
    write(args.out / 'mutation_results.json', {'passed': passed, 'mutations': results})
    print('DELIVERY_MUTATIONS: ' + ('PASS' if passed else 'FAIL') + '; caught=' +
          str(sum(r['caught'] for r in results.values())) + '; survived=' + str(sum(not r['caught'] for r in results.values())))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
