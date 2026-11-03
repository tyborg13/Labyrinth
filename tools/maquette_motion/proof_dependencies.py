"""Source-only provenance discovery; never import or execute inspected code."""
import ast
from pathlib import Path


def python_import_closure(project, entrypoints):
    """Follow local absolute/relative imports, including function-local imports.

    Search the same project/tools roots as the verdict CLIs. Third-party and
    standard-library modules are outside the repository's source certificate.
    """
    project = Path(project)
    roots = (project / 'tools', project)

    def resolve(module):
        for root in roots:
            base = root.joinpath(*module.split('.'))
            for path in (base.with_suffix('.py'), base / '__init__.py'):
                if path.is_file():
                    return path
        return None

    pending = [project / path for path in entrypoints]
    visited = set()
    while pending:
        path = pending.pop()
        relative = path.relative_to(project).as_posix()
        if relative in visited:
            continue
        visited.add(relative)
        root = next(root for root in roots if path.is_relative_to(root))
        parts = list(path.relative_to(root).with_suffix('').parts)
        package = parts[:-1]
        for size in range(1, len(package) + 1):
            initializer = root.joinpath(*package[:size], '__init__.py')
            if initializer.is_file():
                pending.append(initializer)
        for node in ast.walk(ast.parse(path.read_text(), filename=str(path))):
            modules = []
            if isinstance(node, ast.Import):
                modules = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom):
                prefix = package[:len(package) - node.level + 1] if node.level else []
                if node.module:
                    prefix += node.module.split('.')
                module = '.'.join(prefix)
                modules = [module] + ['.'.join((*prefix, alias.name)) for alias in node.names
                                      if alias.name != '*']
            for module in modules:
                dependency = resolve(module) if module else None
                if dependency is not None:
                    pending.append(dependency)
    return visited


def layout_resource_bindings(case, project, read_json, digest):
    """Walk renderer-consumed JSON, independent of texture field names.

    Rigs resolve layout paths against the case directory (not layouts/).
    Existing files in nested dictionaries/arrays include meshes, continuations,
    glow variants and future resource declarations. Source-first textures bind
    their source bytes, not generated import-cache payloads.
    """
    case, project = Path(case).resolve(), Path(project).resolve()
    pending = [read_json(case / path) for path in
               ('layouts/front.json', 'layouts/rear.json', 'compiled_motion.json')]
    result = {}
    while pending:
        value = pending.pop()
        if isinstance(value, dict):
            pending.extend(value.values())
        elif isinstance(value, list):
            pending.extend(value)
        elif isinstance(value, str) and not value.startswith('TODO_DESIGN_'):
            path = project / value.removeprefix('res://') if value.startswith('res://') else case / value
            path = path.resolve()
            if path.is_file():
                key = path.relative_to(case).as_posix() if path.is_relative_to(case) else 'resource:' + value
                result[key] = digest(path)
    return result
