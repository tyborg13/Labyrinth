#!/usr/bin/env python3
"""Run three one-line product faults against both disposable test snapshots."""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from slow_program_benchmark import ROOT, run_one

# Deliberately wrong values exist only in scratch product copies. Neither the
# checkout nor its approved data/assets are changed by this proof.
MUTATIONS = (
    {
        'name': 'event-art-accessor', 'program': 'event_rules_test',
        'path': 'scripts/event_rules.gd',
        'before': 'return "res://assets/art/events/%s.png" % id',
        'after': 'return "res://missing_test05_art/%s.png" % id',
        'assertion': 'Art has one derived accessor and may be missing',
    },
    {
        'name': 'omen-seal-size', 'program': 'event_view_test',
        'path': 'scripts/omen_badges.gd',
        'before': 'custom_minimum_size = Vector2(38, 38)',
        'after': 'custom_minimum_size = Vector2(39, 38)',
        'assertion': 'Seal is 38 px at native scale',
    },
    {
        'name': 'special-ember-payout', 'program': 'special_encounter_test',
        'path': 'scripts/special_encounter_library.gd',
        'before': 'return Omens.ember_drop(combat, multiplied)',
        'after': 'return Omens.ember_drop(combat, multiplied) + 1',
        'assertion': 'Special pays 1.5x starting roster in place of per-kill earnings',
    },
)


def clone_snapshot(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True)
    for item in source.iterdir():
        target = destination / item.name
        if item.name in ('tests', 'scripts'):
            shutil.copytree(item, target)
        else:
            target.symlink_to(item, target_is_directory=item.is_dir())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    directory = output / 'mutations'
    directory.mkdir(exist_ok=True)
    registry = {entry['path']: entry for entry in json.loads((ROOT / 'tests/headless_test_programs.json').read_text())}
    report: dict = {}
    for mutation in MUTATIONS:
        evidence: dict = {}
        for label in ('before', 'after'):
            project = directory / (mutation['name'] + '-' + label)
            clone_snapshot(output / label / 'profiled', project)
            path = project / mutation['path']
            source = path.read_text()
            assert source.count(mutation['before']) == 1, mutation['path']
            changed = source.replace(mutation['before'], mutation['after'])
            assert sum(old != new for old, new in zip(source.splitlines(), changed.splitlines())) == 1
            path.write_text(changed)
            profile_output = directory / (mutation['name'] + '-' + label + '.json')
            user_args = registry['tests/' + mutation['program'] + '.gd'].get('args', []) if label == 'after' else []
            result = run_one(project, mutation['program'], directory / (mutation['name'] + '-' + label + '.log'), profile_output, user_args)
            assert result['exit_code'] != 0, 'One-line fault escaped: ' + mutation['name']
            profile = json.loads(profile_output.read_text())
            assert mutation['assertion'] in profile['failures'], profile['failures']
            evidence[label] = {'run': result, 'failures': sorted(set(profile['failures']))}
        evidence['same_failures'] = evidence['before']['failures'] == evidence['after']['failures']
        assert evidence['same_failures'], evidence
        report[mutation['name']] = {'fault': mutation, 'evidence': evidence}
        (directory / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
        print('MUTATION PRESERVED %s: before and after fail "%s"' % (mutation['name'], mutation['assertion']), flush=True)


if __name__ == '__main__':
    main()
