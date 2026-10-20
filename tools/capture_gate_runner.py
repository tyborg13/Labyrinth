#!/usr/bin/env python3
"""Run unchanged canonical case gates with private proof records.

A private case copy preserves every source byte and relative input binding.
Only its proof directory is writable by the case gate. In particular, the
sampler and the gate never replace the design owner's committed records.
"""
import argparse
import importlib.util
from pathlib import Path
import shutil
import sys

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT), str(PROJECT / 'tools')]
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.production_gates import production_errors
from capture_production import combined
from humanoid_cutout.capture_equivalence import json_bytes


def prepare_case(case, output, samples):
    private = output / 'gate_case' / case.name
    if private.exists():
        shutil.rmtree(private)
    shutil.copytree(case, private, ignore=shutil.ignore_patterns('proof', '__pycache__'))
    proof = private / 'proof'
    proof.mkdir()
    shutil.copyfile(case / 'proof/build.json', proof / 'build.json')
    shutil.copyfile(samples, proof / 'samples.json')
    return private


def run(case, output, samples, native, script):
    output.mkdir(parents=True, exist_ok=True)
    private = prepare_case(case, output, samples)
    # Gates may write diagnostics beside frames.json. Link the immutable
    # capture into a private directory so historical evidence is never edited.
    gate_input = private / 'proof/gate_input'
    gate_input.mkdir()
    for path in native.iterdir():
        if path.name != 'source_space_pockets.json':
            (gate_input / path.name).symlink_to(path.resolve(), target_is_directory=path.is_dir())
    sys.path.insert(0, str(script.parent))
    spec = importlib.util.spec_from_file_location('capture_case_gate', script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.CASE = private
    if case.name == 'rr10':
        sys.argv = [str(script), '--native', str(gate_input)]
        code = module.main()
    else:
        code = int(not module.run(gate_input)['ok'])
    for relative in ('native_gates.json', 'logs/native_gates_full.json'):
        source = private / 'proof' / relative
        if source.is_file():
            destination = output / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
    for relative in ('native_failures', 'seam_cpu/native_failures'):
        source = private / 'proof' / relative
        if source.is_dir():
            shutil.copytree(source, output / relative, dirs_exist_ok=True)
    diagnostics = gate_input / 'source_space_pockets.json'
    destination = native / diagnostics.name
    if diagnostics.is_file():
        if destination.exists():
            if json_bytes(destination, ()) != json_bytes(diagnostics, ()):
                raise ValueError('Re-evaluated pocket JSON differs: ' + str(destination))
        else:
            shutil.copyfile(diagnostics, destination)
    shutil.rmtree(private.parent)
    # Do not replace the process outcome with an inferred successful result.
    read_json(output / 'native_gates.json')
    return code


def run_production(case, output, native):
    errors = production_errors(case, combined(case, native), read_json(case / 'compiled_motion.json'))
    write_json(output / 'production_gates.json', {'ok': not errors, 'errors': errors})
    print('CAPTURE PRODUCTION GATES: %s (%d errors; %s)' % ('FAIL' if errors else 'PASS', len(errors), native))
    return int(bool(errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('case', 'output', 'native'):
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ('samples', 'script'):
        parser.add_argument('--' + name, type=Path)
    parser.add_argument('--production', action='store_true')
    args = parser.parse_args()
    if args.production:
        return run_production(args.case, args.output, args.native)
    if not args.samples or not args.script: parser.error('native gates need --samples and --script')
    return run(args.case, args.output, args.samples, args.native, args.script)


if __name__ == '__main__':
    raise SystemExit(main())
