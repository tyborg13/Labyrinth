"""Conservative path-sharing audit for Python discovery, before scheduling.

Every module has a checked-in resource declaration, including indirect writers
and temporary-only/read-only modules. Unknown modules fail before scheduling.
Fixed Godot task labels use unique runner HOME/user:// namespaces.
"""
from __future__ import annotations

import ast
import json
from pathlib import Path
import re
import tokenize

from python_suite_imports import imported_test_modules
from python_suite_selection import load_groups

DEFAULT_PATTERN = 'test*.py'  # unittest discover's unchanged default.
RESOURCE_TABLE = 'tools/python_suite_resources.json'
WRITE_CALLS = {'write_text', 'write_bytes', 'write_json', 'save', 'mkdir', 'unlink',
               'rmtree', 'copyfile', 'copytree', 'write', 'rename', 'replace', 'touch', 'open'}
UNKNOWN_MODULE_SECONDS = 1.0  # Scheduling estimate for a previously unseen module.


def discover_modules(root, start='tests', pattern=DEFAULT_PATTERN):
    """Mirror unittest's package recursion without importing tests in the parent."""
    base = Path(root) / start
    result = []
    def walk(directory, prefix=''):
        for path in sorted(directory.iterdir()):
            if path.is_file() and path.match(pattern) and re.fullmatch(r'[_a-zA-Z]\w*\.py', path.name):
                result.append(prefix + path.stem)
            elif path.is_dir() and (path / '__init__.py').is_file():
                # unittest also loads TestCases / load_tests from package
                # initializers, even when __init__.py does not match pattern.
                result.append(prefix + path.name)
                walk(path, prefix + path.name + '.')
    walk(base)
    return result


def audit(root, modules, start='tests'):
    table_path = Path(root) / RESOURCE_TABLE
    try:
        table = json.loads(table_path.read_text())
        declarations, resource_paths = table['modules'], table['resources']
        if table['version'] != 1 or not isinstance(declarations, dict) or not isinstance(resource_paths, dict):
            raise ValueError('expected version 1 resource/module mappings')
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError(f'Isolation resource table {table_path}: {error}') from error
    for module in modules:
        if module not in declarations:
            raise ValueError(f'Unclassified test module {module}: declare written resources in '
                             f'{RESOURCE_TABLE} (use [] only after auditing temporary-only/read-only work)')
    _, input_groups = load_groups(root, declarations)
    rows, helper_trees, helper_sources = [], {}, {}
    for module in modules:
        if module not in declarations:
            raise ValueError(f'Unclassified test module {module}: declare written resources in '
                             f'{RESOURCE_TABLE} (use [] only after auditing temporary-only/read-only work)')
        declaration = declarations[module]
        if isinstance(declaration, dict):
            resources = declaration.get('resources', [])
            declared_imports = declaration.get('imports', [])
            if set(declaration) - {'resources', 'imports'}:
                raise ValueError(f'Invalid declaration fields for {module} in {RESOURCE_TABLE}')
        else:
            resources, declared_imports = declaration, []
        if (not isinstance(resources, list) or any(not isinstance(r, str) or r not in resource_paths
                                                   for r in resources)):
            raise ValueError(f'Invalid written-resource declaration for {module} in {RESOURCE_TABLE}')
        if (not isinstance(declared_imports, list) or
                any(not isinstance(name, str) or name not in modules for name in declared_imports)):
            raise ValueError(f'Invalid import dependency declaration for {module} in {RESOURCE_TABLE}')
        path = Path(root) / start / (module.replace('.', '/') + '.py')
        if not path.is_file():
            path = Path(root) / start / module.replace('.', '/') / '__init__.py'
        path = path.resolve()
        try:
            with tokenize.open(path) as handle:
                source = handle.read()
            tree = ast.parse(source, filename=str(path))
        except (OSError, SyntaxError, UnicodeError, ValueError) as error:
            raise ValueError(f'Cannot parse Python source {path}: {error}') from error
        groups = {'behavior': [], 'perf': []}
        for cls in tree.body:
            if not isinstance(cls, ast.ClassDef):
                continue
            for method in cls.body:
                if isinstance(method, ast.FunctionDef) and method.name.startswith('test'):
                    group = 'perf' if any(isinstance(d, (ast.Name, ast.Attribute)) and
                        ast.unparse(d).split('.')[-1] == 'perf_test' for d in method.decorator_list) else 'behavior'
                    groups[group].append(cls.name + '.' + method.name)
        calls = [(node.lineno, ast.unparse(node.func)) for node in ast.walk(tree)
                 if isinstance(node, ast.Call)]
        writes = [line for line, name in calls if name.split('.')[-1] in WRITE_CALLS]
        literals = [node.value for node in ast.walk(tree)
                    if isinstance(node, ast.Constant) and isinstance(node.value, str)]
        fixed_tmp = sorted({s for s in literals if s.startswith('/private/tmp/')})
        task_names = sorted(set(re.findall(r"--task-id['\"]\s*,\s*['\"]([^'\"]+)", source)))
        paths = [resource_paths[resource] for resource in sorted(resources)]
        static_imports = imported_test_modules(tree, module,
            module if path.name == '__init__.py' else module.rpartition('.')[0],
            set(modules), start, root, helper_trees, helper_sources)
        rows.append(dict(module=module, input_group=input_groups[module], groups=groups,
                         resources=sorted(resources), written_paths=paths,
                         imports=sorted(set(declared_imports) | set(static_imports)),
                         declared_imports=sorted(set(declared_imports)),
                         fixed_tmp_literals=fixed_tmp, isolated_godot_tasks=task_names,
                         write_call_lines=sorted(writes),
                         isolation='explicit shared-resource declaration; same shard for shared paths'
                         if resources else 'explicit temporary-only/read-only declaration; runner HOME unique per invocation'))
    return rows


def balance(modules, timings, rows, shards):
    """LPT scheduling over connected components of shared written paths."""
    if shards < 1:
        raise ValueError('--shards must be positive')
    parent = {name: name for name in modules}
    def find(name):
        while parent[name] != name:
            parent[name] = parent[parent[name]]
            name = parent[name]
        return name
    owners = {}
    # Package initializers and load_tests hooks must execute once, even when
    # their declarations contain no shared writes. Static test dependencies
    # likewise belong to the importing worker, not another discovery shard.
    for name in modules:
        package = name.rpartition('.')[0]
        if package in parent:
            parent[find(name)] = find(package)
    for row in rows:
        for dependency in row.get('imports', []):
            parent[find(row['module'])] = find(dependency)
        for resource in row['resources']:
            if resource in owners:
                parent[find(row['module'])] = find(owners[resource])
            owners[resource] = row['module']
    groups = {}
    for name in modules:
        groups.setdefault(find(name), []).append(name)
    loads, assignments = [0.] * shards, [[] for _ in range(shards)]
    weight = lambda group: sum(timings.get(name, UNKNOWN_MODULE_SECONDS) for name in group)
    for group in sorted(groups.values(), key=lambda g: (-weight(g), g)):
        index = min(range(shards), key=lambda i: (loads[i], i))
        assignments[index].extend(group)
        loads[index] += weight(group)
    return [sorted(names) for names in assignments], loads


def audit_table(rows, assignments):
    owners = {name: index + 1 for index, names in enumerate(assignments) for name in names}
    lines = ['| Module | Input group | Declared shared paths | Imported test modules | Other fixed literals | Godot task names (unique run HOME) | Shard |',
             '|---|---|---|---|---|---|---|']
    for row in rows:
        lines.append('| ' + ' | '.join((row['module'], row['input_group'], '<br>'.join(row['written_paths']) or 'temp-only/read-only',
            ', '.join(row.get('imports', [])) or '—',
            '<br>'.join(row['fixed_tmp_literals']) or '—', ', '.join(row['isolated_godot_tasks']) or '—',
            str(owners.get(row['module'], 'not selected')))) + ' |')
    return '\n'.join(lines) + '\n'
