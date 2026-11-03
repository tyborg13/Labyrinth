#!/usr/bin/env python3
"""Validate explicit pass/on-demand registries; unit-local tests need no pass slot."""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROGRAM_MANIFEST = 'tests/headless_test_programs.json'
WINDOWED_MANIFEST = 'tests/windowed_test_allowlist.json'


def audit(root: Path = ROOT) -> tuple[list[dict], list[str]]:
    rows, errors, seen = [], [], set()

    def register(path, classification, evidence):
        if (not isinstance(path, str) or not path.startswith('tests/') or
                '..' in Path(path).parts or not (root / path).is_file()):
            errors.append(f'Registry points at missing or invalid file: {path}')
        if path in seen:
            errors.append(f'Duplicate test registration: {path}')
        seen.add(path)
        rows.append(dict(path=path, classification=classification, evidence=evidence))

    for entry in json.loads((root / PROGRAM_MANIFEST).read_text()):
        category = 'on demand: ' + entry['group'] if entry.get('on_demand') else 'pass'
        register(entry['path'], category, PROGRAM_MANIFEST)
    for path, reason in json.loads((root / WINDOWED_MANIFEST).read_text()).items():
        if not isinstance(reason, str) or not reason.strip():
            errors.append(f'Missing windowed reason: {path}')
        register(path, 'windowed on demand', reason)
    groups = json.loads((root / 'tools/python_suite_groups.json').read_text())['groups']
    resources = json.loads((root / 'tools/python_suite_resources.json').read_text())['modules']
    modules = []
    for name, entry in groups.items():
        for module in entry['modules']:
            modules.append(module)
            path = 'tests/' + module.replace('.', '/') + '.py'
            if not (root / path).is_file() and (root / path.removesuffix('.py') / '__init__.py').is_file():
                path = path.removesuffix('.py') + '/__init__.py'
            register(path, 'on demand: ' + name if entry.get('on_demand') else 'pass',
                     'tools/python_suite_groups.json')
    if set(modules) != set(resources):
        errors.append('Python group/resource inventories differ')
    return rows, errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--json', type=Path)
    parser.add_argument('--markdown', type=Path)
    args = parser.parse_args(argv)
    try:
        rows, errors = audit(args.project.resolve())
    except (OSError, ValueError, KeyError, TypeError) as error:
        rows, errors = [], [str(error)]
    if args.json:
        args.json.write_text(json.dumps(dict(tests=rows, errors=errors), indent=2) + '\n')
    if args.markdown:
        args.markdown.write_text('| Script | Classification | Evidence |\n|---|---|---|\n' + ''.join(
            f'| `{row["path"]}` | {row["classification"]} | {row["evidence"]} |\n' for row in rows))
    for error in errors:
        print(error)
    counts = Counter(row['classification'] for row in rows)
    print('TEST REGISTRATION AUDIT: %s (%d entries; %s)' % (
        'FAIL' if errors else 'PASS', len(rows), ', '.join(f'{key}={value}' for key, value in sorted(counts.items()))))
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
