"""Reject imports of another shard's audited test source before execution."""
from contextlib import contextmanager
from importlib.util import source_from_cache, spec_from_loader
from pathlib import Path
import sys


class SuiteImportGuard:
    def __init__(self, root, start, suite_modules, assigned):
        base = Path(root) / start
        self.files = {}
        for name in suite_modules:
            path = base / (name.replace('.', '/') + '.py')
            if not path.is_file():
                path = base / name.replace('.', '/') / '__init__.py'
            self.files[path.resolve()] = name
        self.allowed = {path for path, name in self.files.items() if name in assigned}
        for name in assigned:
            parts = name.split('.')
            for length in range(1, len(parts)):
                self.allowed.add((base.joinpath(*parts[:length]) / '__init__.py').resolve())
        self.owner = '<discovery>'
        self.violations = []

    def __enter__(self):
        sys.meta_path.insert(0, self)
        return self

    def __exit__(self, *_):
        if self in sys.meta_path:
            sys.meta_path.remove(self)

    @contextmanager
    def loading(self, owner):
        previous = self.owner
        self.owner = owner
        try:
            yield
        finally:
            self.owner = previous

    def importer(self):
        # Helpers and importlib can sit between the importing test and Python's
        # finder. Attribute the edge to the nearest audited test frame.
        frame = sys._getframe(1)
        try:
            while frame is not None:
                name = self.files.get(Path(frame.f_code.co_filename).resolve())
                if name:
                    return name
                frame = frame.f_back
        finally:
            del frame
        return self.owner

    def require_clean(self):
        if self.violations:
            # Discovery/load_tests and test code may catch ImportError. Such a
            # catch must not turn a violated ownership rule into a passing shard.
            raise ImportError(self.violations[0])

    @staticmethod
    def execution_lookup():
        # importlib.util.find_spec must retain its None result for optional
        # dependency probes. An execution lookup instead needs to finish the
        # failed import here, rather than resolve twice outside the guard.
        frame = sys._getframe(2)
        try:
            return (frame.f_code.co_name == '_find_spec' and frame.f_back is not None and
                    frame.f_globals.get('__name__') in ('_frozen_importlib', 'importlib._bootstrap') and
                    frame.f_back.f_code.co_name == '_find_and_load_unlocked')
        finally:
            del frame

    def find_spec(self, fullname, path=None, target=None):
        # Delegate in the existing finder order, without recursing through this
        # guard. Inspect the resulting spec before importlib executes its loader.
        for finder in tuple(sys.meta_path):
            if finder is self:
                continue
            if hasattr(finder, 'find_spec'):
                spec = finder.find_spec(fullname, path, target)
            else:
                loader = finder.find_module(fullname, path)
                spec = spec_from_loader(fullname, loader) if loader else None
            if spec is None:
                continue
            if spec.origin not in (None, 'built-in', 'frozen'):
                origin = Path(spec.origin)
                if origin.suffix == '.pyc':
                    try:
                        origin = Path(source_from_cache(str(origin)))
                    except ValueError:
                        origin = origin.with_suffix('.py')
                origin = origin.resolve()
                imported = self.files.get(origin)
                if imported and origin not in self.allowed:
                    message = (f'test module {self.importer()} imports test module {imported}, '
                               'which runs in another shard; declare the dependency in '
                               'tools/python_suite_resources.json')
                    self.violations.append(message)
                    print('IMPORT OWNERSHIP VIOLATION: ' + message, flush=True)
                    raise ImportError(message, name=fullname)
            return spec
        if self.execution_lookup():
            raise ModuleNotFoundError(f"No module named {fullname!r}", name=fullname)
        return None
