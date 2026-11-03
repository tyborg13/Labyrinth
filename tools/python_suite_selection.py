"""Explicit input groups, conservative Git changes and import-safe selection."""
from __future__ import annotations

import fnmatch
import json
import os
from pathlib import Path
import subprocess

GROUP_TABLE = 'tools/python_suite_groups.json'


def load_groups(root, modules=None):
    path = Path(root) / GROUP_TABLE
    try:
        table = json.loads(path.read_text())
        groups = table['groups']
        if table['version'] != 1 or not isinstance(groups, dict) or 'default' not in groups:
            raise ValueError('expected version 1 groups including default')
        owners = {}
        for name, declaration in groups.items():
            if not isinstance(declaration, dict):
                raise ValueError(f'invalid group {name}')
            names, triggers = declaration['modules'], declaration.get('triggers', [])
            if (not isinstance(names, list) or any(not isinstance(m, str) for m in names) or
                    not isinstance(triggers, list) or
                    any(not isinstance(p, str) or not p or p.startswith('/') for p in triggers) or
                    (name != 'default' and not triggers and not declaration.get('on_demand', False))):
                raise ValueError(f'invalid modules/trigger globs for {name}')
            for module in names:
                if module in owners:
                    raise ValueError(f'{module} belongs to both {owners[module]} and {name}')
                owners[module] = name
        if modules is not None:
            missing, extra = set(modules) - owners.keys(), owners.keys() - set(modules)
            if missing or extra:
                raise ValueError(f'group inventory differs from resources: missing={sorted(missing)}, '
                                 f'unknown={sorted(extra)}')
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError(f'Input group table {path}: {error}') from error
    return groups, owners


def changed_files(root, reference):
    """Compare a commit to the working tree, including index and untracked paths.

    Disabling rename detection retains both sides of a move. NUL records avoid
    Git quoting ambiguities for spaces, non-ASCII filenames and newlines.
    """
    def git(*args):
        return subprocess.run(['git', *args], cwd=root, check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    try:
        commit = git('rev-parse', '--verify', '--end-of-options', reference + '^{commit}').strip().decode('ascii')
        tracked = git('diff', '--no-ext-diff', '--no-renames', '--ignore-submodules=none',
                      '--name-only', '-z', commit, '--')
        untracked = git('ls-files', '--others', '--exclude-standard', '-z')
        return sorted({os.fsdecode(p) for p in (tracked + untracked).split(b'\0') if p})
    except (OSError, subprocess.SubprocessError, UnicodeError) as error:
        detail = os.fsdecode(error.stderr).strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        raise ValueError(f'cannot compute changes from {reference!r}: {detail}') from error


def select_groups(root, groups, rows, *, changed_since=None, all_groups=False, perf=False, on_demand=None):
    owners = {module: name for name, entry in groups.items() for module in entry['modules']}
    available = {name: entry for name, entry in groups.items()
                 if not entry.get('on_demand', False)}
    if on_demand is not None:
        requested = set(on_demand)
        demand = {name for name, entry in groups.items() if entry.get('on_demand', False)}
        unknown = requested - demand - {'all'}
        if unknown:
            raise ValueError('Unknown on-demand groups: ' + ', '.join(sorted(unknown)))
        available = {name: entry for name, entry in groups.items()
                     if name in demand and ('all' in requested or name in requested)}
    paths, fallback = None, None
    if on_demand is not None or perf or all_groups or changed_since is None:
        reason = 'performance discovery (unchanged)' if perf else (
            'explicit --all-groups' if all_groups else 'no change filter; run everything')
        reasons = dict.fromkeys(available, 'explicit --on-demand' if on_demand is not None else reason)
    else:
        try:
            paths = changed_files(root, changed_since)
        except ValueError as error:
            fallback = str(error)
            reasons = dict.fromkeys(available, 'fallback: ' + fallback)
        else:
            reasons = {'default': 'always run'}
            for name, entry in available.items():
                match = next((p for p in paths if any(fnmatch.fnmatchcase(p, glob)
                                                     for glob in entry.get('triggers', []))), None)
                if name != 'default' and match is not None:
                    reasons[name] = 'changed file: ' + match
    # Selecting only one side of a test import would either weaken discovery
    # or violate the origin guard. Promote the complete dependency group, and
    # keep package load_tests/initializers with their descendants as before.
    dependencies = {row['module']: set(row.get('imports', [])) for row in rows}
    for module in owners:
        package = module.rpartition('.')[0]
        if package in owners:
            dependencies.setdefault(module, set()).add(package)
            dependencies.setdefault(package, set()).add(module)
    while True:
        additions = {}
        for module in sorted(dependencies):
            if owners[module] not in reasons:
                continue
            for dependency in sorted(dependencies[module]):
                name = owners[dependency]
                if on_demand is None and groups[name].get('on_demand', False):
                    raise ValueError(f'Pass module {module} imports on-demand module {dependency}')
                if name not in reasons and name not in additions:
                    additions[name] = f'import dependency: {module} -> {dependency}'
        if not additions:
            break
        reasons.update(additions)
    return dict(selected_groups=[name for name in groups if name in reasons],
                reasons={name: reasons[name] for name in groups if name in reasons},
                changed_since=changed_since, changed_files=paths, fallback=fallback)


def group_timings(results, rows):
    """Measured module costs per input group, distinct from suite wall time."""
    owners = {row['module']: row['input_group'] for row in rows}
    totals = {}
    for result in results:
        shard_costs = {}
        for module, seconds in result['modules'].items():
            group = owners[module]
            record = totals.setdefault(group, dict(modules=0, module_seconds=0., max_shard_seconds=0.))
            record['modules'] += 1
            record['module_seconds'] += seconds
            shard_costs[group] = shard_costs.get(group, 0.) + seconds
        for group, seconds in shard_costs.items():
            totals[group]['max_shard_seconds'] = max(totals[group]['max_shard_seconds'], seconds)
    return totals
