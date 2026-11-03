"""Read local Python import edges without importing test modules in the parent."""
import ast
from importlib.util import resolve_name
from pathlib import Path
import tokenize


def import_names(tree, package):
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            yield from (alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            name = node.module or ''
            if node.level:
                try:
                    name = resolve_name('.' * node.level + name, package)
                except (ImportError, ValueError):
                    continue  # unittest reports invalid relative imports.
            yield name
            yield from (name + '.' + alias.name for alias in node.names)


def local_sources(name, root, start):
    # Match the project/tests/tools import roots used by the suite. Qualified
    # helpers under spec/ are reached from root. Parent initializers count too.
    for base in (root, root / start, root / 'tools'):
        parts = name.split('.')
        for length in range(1, len(parts) + 1):
            package = '.'.join(parts[:length])
            path = base.joinpath(*parts[:length]) / '__init__.py'
            if path.is_file() and path.resolve().is_relative_to(root):
                yield path.resolve(), package
        path = base.joinpath(*parts).with_suffix('.py')
        if path.is_file() and path.resolve().is_relative_to(root):
            yield path.resolve(), name.rpartition('.')[0]


def imported_test_modules(tree, module, package, modules, start, root=None, trees=None, sources=None):
    """Conservative test dependencies, including those reached through helpers.

    Function-local imports count as well as initialization imports: they still
    need to stay with their consumer when its tests execute. Parsed helper ASTs
    are shared within one audit; no module-level code runs here.
    """
    dependencies, visited = set(), set()
    pending = [(tree, package)]
    root = Path(root).resolve() if root is not None else None
    trees = {} if trees is None else trees
    sources = {} if sources is None else sources
    while pending:
        current, package = pending.pop()
        for original in import_names(current, package):
            name = original.removeprefix(start.replace('/', '.') + '.')
            while name:
                if name in modules and name != module:
                    dependencies.add(name)
                    break
                name = name.rpartition('.')[0]
            if root is None or not original or '*' in original:
                continue
            if original not in sources:
                sources[original] = tuple(local_sources(original, root, start))
            for path, helper_package in sources[original]:
                if path in visited:
                    continue
                visited.add(path)
                if path not in trees:
                    try:
                        with tokenize.open(path) as source:
                            trees[path] = ast.parse(source.read(), filename=str(path))
                    except (OSError, SyntaxError, UnicodeError, ValueError) as error:
                        raise ValueError(f'Cannot parse Python source {path}: {error}') from error
                pending.append((trees[path], helper_package))
    return sorted(dependencies)
