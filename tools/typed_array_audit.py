#!/usr/bin/env python3
"""On-demand Windows typed-array audit; no imports or execution of shipped code.

Run: python3 tools/typed_array_audit.py [--json /tmp/audit.json]
Exit 1 means review candidates exist, not that every candidate is a runtime bug.
Only scripts/**/*.gd and assets/**/*.gd are scanned (including excluded owners).

This is a conservative token scan, not a GDScript compiler. It follows declared
and inferred locals, members, preloads, class names and function signatures.
Dynamic receivers/indexes/Variant values remain review candidates; native methods
and inherited methods without source signatures may also need manual review.
It does not prove dataflow through dictionaries, dynamic call()/Callable dispatch,
or arbitrary alias mutation. Comments and strings are never scanned as code.

Godot 4.6.1 probes (qa-19): direct literals in declarations, defaults, returns and
arguments are contextually typed and pass locally, but are project-rule findings.
Untyped Array transfers fail at runtime, including mixed ternaries, map(), plain
Array call arguments/returns, and dictionary defaults. duplicate/filter/slice
preserve the receiver's element type: a typed receiver is safe. Typed constants
also pass locally; the rule still applies. Array(values, TYPE_*, class, script)
is a typed built-in constructor, usable even in constants and parameter defaults.
Reproduce the individual probes with --runtime-probes /tmp/probes --task-id qa-19.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import asdict, dataclass, field
import json
import os
from pathlib import Path
import subprocess
import sys

from gdscript_test_calls import tokenize

ROOT = Path(__file__).resolve().parents[1]
PROBE_TIMEOUT_SECONDS = 20
ARRAY_METHODS = {'duplicate', 'filter', 'slice'}
PLAIN_METHODS = {'map', 'keys', 'values', 'get_stack'}


def joined(tokens):
    return ''.join(t.value for t in tokens)


def top_indices(tokens, values):
    depth = 0
    for i, t in enumerate(tokens):
        if t.kind == "string": continue
        if depth == 0 and t.value in values:
            yield i
        if t.value in ('(', '[', '{'):
            depth += 1
        elif t.value in (')', ']', '}'):
            depth -= 1


def split(tokens, delimiter=','):
    result, start = [], 0
    for i in top_indices(tokens, {delimiter}):
        result.append(tokens[start:i])
        start = i + 1
    result.append(tokens[start:])
    return result


def statements(tokens):
    """Logical lines, respecting nested literals, lambdas and continuations."""
    result, start, depth = [], 0, 0
    for i, t in enumerate(tokens):
        if i > start and depth == 0 and t.line > tokens[i-1].line and tokens[i-1].value != '\\':
            result.append(tokens[start:i])
            start = i
        if t.kind == 'string': continue
        if t.value == ';' and depth == 0:
            result.append(tokens[start:i])
            start = i + 1
        if t.value in ('(', '[', '{'):
            depth += 1
        elif t.value in (')', ']', '}'):
            depth -= 1
    if start < len(tokens):
        result.append(tokens[start:])
    return [s for s in result if s]


@dataclass
class Function:
    name: str
    line: int
    end: int
    params: list
    returns: str


@dataclass
class Script:
    path: str
    source: str
    lines: list = field(default_factory=list)
    funcs: list = field(default_factory=list)
    aliases: dict = field(default_factory=dict)
    declarations: list = field(default_factory=list)
    class_name: str = ''
    parent: str = ''
    owners: dict = field(default_factory=dict)
    names: dict = field(default_factory=dict)

    def owner(self, line):
        return self.owners.get(line)


def declaration(tokens):
    """(name, annotation, initializer), for declarations or parameter entries."""
    if not tokens:
        return '', '', []
    if tokens[0].value in ('var', 'const'):
        tokens = tokens[1:]
    if not tokens:
        return '', '', []
    eq = next(iter(top_indices(tokens, {'='})), len(tokens))
    colon = next(iter(top_indices(tokens[:eq], {':'})), eq)
    return tokens[0].value, joined(tokens[colon+1:eq]), tokens[eq+1:]


def read_script(path, source):
    s = Script(path, source, statements(tokenize(source)))
    for n, ts in enumerate(s.lines):
        vals = [t.value for t in ts]
        if vals[:1] == ['class_name']:
            s.class_name = vals[1]
        if vals[:1] == ['extends']:
            s.parent = vals[1].removeprefix('res://')
        if 'func' in vals[:2]:
            i = vals.index('func')
            if i+2 >= len(ts) or vals[i+2] != '(':
                continue
            depth, closing = 1, i+3
            while closing < len(ts):
                if ts[closing].kind == 'string':
                    closing += 1
                    continue
                if vals[closing] == '(': depth += 1
                if vals[closing] == ')': depth -= 1
                if depth == 0: break
                closing += 1
            colon = next(iter(top_indices(ts[closing+1:], {':'})), len(ts)) + closing+1
            ret = joined(ts[closing+1:colon]).removeprefix('->')
            end = len(source.splitlines())
            for later in s.lines[n+1:]:
                if later[0].column <= ts[0].column:
                    end = later[0].line - 1
                    break
            f = Function(vals[i+1], ts[0].line, end,
                         [declaration(p) for p in split(ts[i+3:closing]) if p], ret)
            s.funcs.append(f)
        for i, t in enumerate(ts[:-1]):
            if t.kind != 'name' or t.value not in ('var', 'const'):
                continue
            # Ignore nested lambda locals here; they still get assignments scanned.
            tail = ts[i:]
            # A local inside a multiline lambda belongs to its own logical line.
            local_lines = statements(tail)
            name, typ, expr = declaration(local_lines[0] if local_lines else tail)
            s.declarations.append((t.line, t.column, name, typ, expr, t.value))
            if len(expr) >= 4 and expr[0].value in ('preload', 'load') and expr[2].kind == 'string':
                s.aliases[name] = expr[2].value.removeprefix('res://')
    for f in s.funcs:
        for line in range(f.line, f.end + 1):
            s.owners[line] = f
    for d in s.declarations:
        s.names.setdefault(d[2], []).append(d)
    return s


@dataclass(frozen=True)
class Hit:
    file: str
    line: int
    pattern: str
    context: str
    target: str
    expression: str
    owner: str


def owner_label(path, function):
    if path == 'scripts/guardian_combat_rules.gd' or path.startswith('scripts/maquette_cutout_runtime/') or path.startswith('assets/units/storm_cantor_cutout/'):
        return 'excluded'
    if path == 'scripts/run_scene.gd' and ('hover' in function):
        return 'excluded-hover-review'
    if path == 'scripts/combat_engine.gd' and any(x in function for x in ('committed', 'commit_plan')):
        return 'excluded-committed-review'
    if path.startswith('assets/'):
        return 'report-only-assets'
    return 'qa-19'


class Audit:
    def __init__(self, scripts):
        self.scripts = {s.path: s for s in scripts}
        self.classes = {s.class_name: s for s in scripts if s.class_name}
        self.by_method = {}
        for s in scripts:
            for f in s.funcs:
                self.by_method.setdefault(f.name, []).append((s, f))

    def signature(self, s, f, callee, line, *, candidate=False):
        name = joined(callee)
        if len(callee) >= 6 and callee[0].value in ('preload', 'load') and callee[2].kind == 'string' and callee[4].value == '.':
            target = self.scripts.get(callee[2].value.removeprefix('res://'))
            return self.method(target, callee[5].value) if target else None
        if '.' in name:
            receiver, method = name.rsplit('.', 1)
            target = self.scripts.get(s.aliases.get(receiver, '')) or self.classes.get(receiver)
            if receiver == 'self': target = s
            if not target:
                typ = self.symbol(s, f, receiver, line, set())
                target = self.classes.get(typ) or self.scripts.get(typ)
            if target:
                return self.method(target, method)
            matches = self.by_method.get(method, [])
            # Unique names are candidates, never a proof of a dynamic receiver type.
            return matches[0] if candidate and len(matches) == 1 else None
        return self.method(s, name)

    def method(self, s, name):
        for f in s.funcs:
            if f.name == name:
                return s, f
        parent = self.scripts.get(s.parent) or self.classes.get(s.parent)
        return self.method(parent, name) if parent and parent != s else None

    def symbol(self, s, f, name, line, seen):
        key = (s.path, f.line if f else 0, name)
        if key in seen: return 'Variant'
        seen = seen | {key}
        if f:
            for param, typ, _ in f.params:
                if param == name: return typ or 'Variant'
        candidates = [d for d in s.names.get(name, []) if
                      (s.owner(d[0]) is None or (s.owner(d[0]) == f and d[0] <= line))]
        if not candidates: return 'Variant'
        d = max(candidates, key=lambda d: (s.owner(d[0]) == f, d[0]))
        return d[3] or self.type_of(s, s.owner(d[0]), d[4], d[0], seen)

    def type_of(self, s, f, ts, line, seen=None):
        seen = seen or set()
        ts = [t for t in ts if t.value != '\\']
        if not ts: return 'Variant'
        # Peel a complete enclosing parenthesis pair only.
        if ts[0].value == '(' and self.close(ts, 0) == len(ts)-1:
            return self.type_of(s, f, ts[1:-1], line, seen)
        branches = list(top_indices(ts, {'if', 'else'}))
        if len(branches) == 2:
            a = self.type_of(s, f, ts[:branches[0]], line, seen)
            b = self.type_of(s, f, ts[branches[1]+1:], line, seen)
            return a if a == b else 'Variant'
        casts = list(top_indices(ts, {'as'}))
        if casts: return joined(ts[casts[-1]+1:])
        if ts[0].value == '[' and self.close(ts, 0) == len(ts)-1: return 'Array'
        if ts[-1].value == ')':
            # Match the final call, allowing e.g. untyped().duplicate().
            opening = self.open(ts, len(ts)-1)
            callee = ts[:opening]
            if not callee: return 'Variant'
            method = callee[-1].value
            if len(callee) >= 2 and callee[-2].value == '.':
                if method in ARRAY_METHODS:
                    return self.type_of(s, f, callee[:-2], line, seen)
                if method in PLAIN_METHODS: return 'Array'
                if method == 'get': return 'Variant'
            if joined(callee) == 'Array':
                args = split(ts[opening+1:-1])
                types = {'TYPE_INT': 'int', 'TYPE_FLOAT': 'float', 'TYPE_STRING_NAME': 'StringName', 'TYPE_STRING': 'String', 'TYPE_DICTIONARY': 'Dictionary',
                         'TYPE_VECTOR2I': 'Vector2i', 'TYPE_VECTOR2': 'Vector2', 'TYPE_RECT2': 'Rect2'}
                if len(args) == 4:
                    element = types.get(joined(args[1]), '')
                    if joined(args[1]) == 'TYPE_OBJECT' and args[2]: element = args[2][0].value
                    if element: return f'Array[{element}]'
                return 'Array'
            if method == 'new' and len(callee) == 3 and callee[0].value in s.aliases:
                return s.aliases[callee[0].value]
            sig = self.signature(s, f, callee, line)
            if sig: return sig[1].returns or 'Variant'
            native = {'get_children': 'Array[Node]', 'find_children': 'Array[Node]',
                      'opaque_to_polygons': 'Array[PackedVector2Array]', 'search_all': 'Array[RegExMatch]',
                      'Input.get_connected_joypads': 'Array[int]'}
            if joined(callee) in native: return native[joined(callee)]
            if method in native: return native[method]
            if joined(callee) in {f'Geometry2D.{n}' for n in ('offset_polyline', 'merge_polygons', 'clip_polygons', 'offset_polygon', 'intersect_polygons')}:
                return 'Array[PackedVector2Array]'
            return 'Variant'
        if len(ts) == 1:
            return self.symbol(s, f, ts[0].value, line, seen)
        if len(ts) == 3 and ts[1].value == '.':
            target = self.scripts.get(s.aliases.get(ts[0].value, '')) or self.classes.get(ts[0].value)
            if not target:
                receiver_type = self.symbol(s, f, ts[0].value, line, seen)
                target = self.classes.get(receiver_type) or self.scripts.get(receiver_type)
            if target: return self.symbol(target, None, ts[2].value, line, seen)
            if ts[0].value == 'self': return self.symbol(s, f, ts[2].value, line, seen)
        return 'Variant'

    @staticmethod
    def close(ts, i):
        depth = 0
        for j in range(i, len(ts)):
            if ts[j].kind == 'string': continue
            if ts[j].value in ('(', '[', '{'): depth += 1
            if ts[j].value in (')', ']', '}'): depth -= 1
            if depth == 0: return j
        return len(ts)

    @staticmethod
    def open(ts, i):
        depth = 0
        for j in range(i, -1, -1):
            if ts[j].kind == 'string': continue
            if ts[j].value in (')', ']', '}'): depth += 1
            if ts[j].value in ('(', '[', '{'): depth -= 1
            if depth == 0: return j
        return 0

    def pattern(self, s, f, expr, line):
        ts = [t for t in expr if t.value != '\\']
        if not ts: return ''
        if ts[0].value == '(' and self.close(ts, 0) == len(ts)-1:
            return self.pattern(s, f, ts[1:-1], line)
        branches = list(top_indices(ts, {'if', 'else'}))
        if len(branches) == 2:
            a, b = ts[:branches[0]], ts[branches[1]+1:]
            if self.pattern(s, f, a, line) or self.pattern(s, f, b, line): return 'conditional'
            return ''
        if ts[0].value == '[' and self.close(ts, 0) == len(ts)-1: return 'literal'
        typ = self.type_of(s, f, ts, line)
        if typ.startswith('Array['): return ''
        if any(t.value == 'get' for t in ts) and any(t.value == '[' for t in ts): return 'dictionary-get'
        if any(t.value == 'map' for t in ts): return 'map'
        if any(t.value in ARRAY_METHODS for t in ts): return 'untyped-transform'
        return 'untyped-source' if typ == 'Array' or typ.startswith('Packed') else 'unresolved-source'

    def run(self):
        hits = []
        def add(s, f, expr, context, target, line=None):
            if not expr: return
            line = line or expr[0].line
            pattern = self.pattern(s, f, expr, line)
            if pattern:
                hits.append(Hit(s.path, line, pattern, context, target, joined(expr),
                                owner_label(s.path, f.name if f else '')))
        for s in self.scripts.values():
            for line, _, name, typ, expr, kind in s.declarations:
                if typ.startswith('Array['): add(s, s.owner(line), expr, kind, name, line)
            for f in s.funcs:
                for name, typ, expr in f.params:
                    if typ.startswith('Array['): add(s, f, expr, 'parameter-default', name)
            for ts in s.lines:
                f = s.owner(ts[0].line)
                # Reassignments (including inline if/else bodies).
                for i in top_indices(ts, {'='}):
                    lhs = ts[:i]
                    if any(t.value in ('var', 'const', 'func') for t in lhs): continue
                    colon = list(top_indices(lhs, {':'}))
                    if colon: lhs = lhs[colon[-1]+1:]
                    name = joined(lhs)
                    typ = self.type_of(s, f, lhs, ts[0].line)
                    if typ.startswith('Array['): add(s, f, ts[i+1:], 'assignment', name)
                if f and f.returns.startswith('Array['):
                    for i, t in enumerate(ts):
                        if t.value == 'return' and i in set(top_indices(ts, {'return'})) and not any(v.value == 'func' for v in ts[:i]):
                            add(s, f, ts[i+1:], 'return', f.name)
                # Walk all nested calls; a literal inside an untyped helper is safe.
                for i, t in enumerate(ts):
                    if t.kind == 'string' or t.value != '(' or i == 0 or ts[i-1].kind != 'name': continue
                    if i >= 2 and ts[i-2].value == 'func': continue
                    start = i-1
                    while start >= 2 and ts[start-1].value == '.' and ts[start-2].kind == 'name': start -= 2
                    sig = self.signature(s, f, ts[start:i], t.line, candidate=True)
                    if not sig: continue
                    end = self.close(ts, i)
                    for arg, param in zip(split(ts[i+1:end]), sig[1].params):
                        if param[1].startswith('Array['):
                            add(s, f, arg, 'argument', joined(ts[start:i]) + ':' + param[0])
        return sorted(set(hits), key=lambda h: (h.file, h.line, h.context, h.target))


PROBE_COMMON = 'extends SceneTree\nfunc _initialize():\n\tprobe()\n\tquit()\nfunc plain() -> Array:\n\treturn [1]\nfunc typed() -> Array[int]:\n\tvar a: Array[int]\n\ta.assign([1])\n\treturn a\nfunc accept(a: Array[int]):\n\tprint("ACCEPTED ", a)\n'
PROBE_CASES = {'argument_conditional': ('func probe():\n'
                          '\taccept([1] if OS.has_feature("macos") else typed())\n'
                          '\tprint("OK")\n',
                          True),
 'argument_literal': ('func probe():\n\taccept([1])\n\tprint("OK")\n', False),
 'argument_plain': ('func probe():\n\taccept(plain())\n\tprint("OK")\n', True),
 'assign_control': ('func probe():\n\tvar a: Array[int]\n\ta.assign(plain())\n\tprint("OK ", a)\n', False),
 'conditional_literal': ('func probe():\n'
                         '\tvar a: Array[int] = [1] if OS.has_feature("macos") else typed()\n'
                         '\tprint("OK ", a)\n',
                         True),
 'conditional_typed': ('func probe():\n'
                       '\tvar a: Array[int] = typed() if OS.has_feature("macos") else typed()\n'
                       '\tprint("OK ", a)\n',
                       False),
 'conditional_unselected': ('func probe():\n'
                            '\tvar a: Array[int] = typed() if OS.has_feature("macos") else [1]\n'
                            '\tprint("OK ", a)\n',
                            False),
 'constructor': ('func probe():\n\tvar a: Array[int] = Array[int]([1])\n\tprint("OK ", a)\n', True),
 'dictionary_get': ('func probe():\n'
                    '\tvar d: Dictionary = {}\n'
                    '\tvar a: Array[int] = d.get("a", [])\n'
                    '\tprint("OK ", a)\n',
                    True),
 'dictionary_typed': ('func probe():\n'
                      '\tvar d: Dictionary = {"a": typed()}\n'
                      '\tvar a: Array[int] = d.get("a", [])\n'
                      '\tprint("OK ", a)\n',
                      False),
 'duplicate_typed': ('func probe():\n\tvar a: Array[int] = typed().duplicate()\n\tprint("OK ", a)\n', False),
 'filter_typed': ('func probe():\n'
                  '\tvar a: Array[int] = typed().filter(func(v): return v == 1)\n'
                  '\tprint("OK ", a)\n',
                  False),
 'filter_untyped': ('func probe():\n'
                    '\tvar a: Array[int] = plain().filter(func(v): return v == 1)\n'
                    '\tprint("OK ", a)\n',
                    True),
 'literal_const': ('const C: Array[int] = [1]\nfunc probe():\n\tprint("OK ", C)\n', False),
 'literal_empty': ('func probe():\n\tvar a: Array[int] = []\n\tprint("OK ", a)\n', False),
 'literal_local': ('func probe():\n\tvar a: Array[int] = [1]\n\tprint("OK ", a)\n', False),
 'literal_member': ('var member: Array[int] = [1]\nfunc probe():\n\tprint("OK ", member)\n', False),
 'literal_reassign': ('func probe():\n\tvar a: Array[int]\n\ta = [1]\n\tprint("OK ", a)\n', False),
 'map_typed': ('func probe():\n\tvar a: Array[int] = typed().map(func(v): return v)\n\tprint("OK ", a)\n',
               True),
 'parameter_constructor': ('func defaults(a: Array[int] = Array([], TYPE_INT, "", null)):\n'
                           '\tprint("OK ", a)\n'
                           'func probe():\n'
                           '\tdefaults()\n',
                           False),
 'parameter_default': ('func defaults(a: Array[int] = []):\n\tprint("OK ", a)\nfunc probe():\n\tdefaults()\n',
                       False),
 'plain_call': ('func probe():\n\tvar a: Array[int] = plain()\n\tprint("OK ", a)\n', True),
 'plain_duplicate': ('func probe():\n'
                     '\tvar source: Array = [1]\n'
                     '\tvar a: Array[int] = source.duplicate()\n'
                     '\tprint("OK ", a)\n',
                     True),
 'plain_source': ('func probe():\n'
                  '\tvar source: Array = [1]\n'
                  '\tvar a: Array[int] = source\n'
                  '\tprint("OK ", a)\n',
                  True),
 'return_conditional': ('func produce() -> Array[int]:\n'
                        '\treturn [1] if OS.has_feature("macos") else typed()\n'
                        'func probe():\n'
                        '\tprint("OK ", produce())\n',
                        True),
 'return_literal': ('func produce() -> Array[int]:\n\treturn [1]\nfunc probe():\n\tprint("OK ", produce())\n',
                    False),
 'return_plain': ('func produce() -> Array[int]:\n'
                  '\treturn plain()\n'
                  'func probe():\n'
                  '\tprint("OK ", produce())\n',
                  True),
 'slice_typed': ('func probe():\n\tvar a: Array[int] = typed().slice(0)\n\tprint("OK ", a)\n', False),
 'slice_untyped': ('func probe():\n\tvar a: Array[int] = plain().slice(0)\n\tprint("OK ", a)\n', True),
 'typed_constructor': ('var member: Array[int] = Array([1], TYPE_INT, "", null)\n'
                       'func probe():\n'
                       '\tvar a: Array[int] = Array([1], TYPE_INT, "", null)\n'
                       '\tprint("OK ", a, member)\n',
                       False)}


PROBE_CASES.update({
    'const_constructor': ('const C: Array[int] = Array([1], TYPE_INT, "", null)\n'
                          'func probe():\n\tassert(C.is_typed() and C.is_read_only() and C == [1])\n\tprint("OK")\n', False),
    'const_string_name': ('const C: Array[StringName] = Array([&"accept"], TYPE_STRING_NAME, "", null)\n'
                         'func probe():\n\tassert(C.get_typed_builtin() == TYPE_STRING_NAME and C.is_read_only())\n\tprint("OK")\n', False),
    'parameter_dictionary': ('func defaults(a: Array[Dictionary] = Array([], TYPE_DICTIONARY, "", null)):\n'
                             '\tassert(a.is_empty() and a.get_typed_builtin() == TYPE_DICTIONARY)\n'
                             '\ta.append({"v": 1})\nfunc probe():\n\tdefaults()\n\tdefaults()\n\tprint("OK")\n', False),
    'parameter_texture': ('func defaults(a: Array[Texture2D] = Array([], TYPE_OBJECT, "Texture2D", null)):\n'
                         '\tassert(a.is_empty() and a.get_typed_class_name() == &"Texture2D")\n'
                         'func probe():\n\tdefaults()\n\tprint("OK")\n', False),
    'parameter_vector': ('func defaults(a: Array[Vector2i] = Array([], TYPE_VECTOR2I, "", null)):\n'
                        '\tassert(a.is_empty() and a.get_typed_builtin() == TYPE_VECTOR2I)\n'
                        'func probe():\n\tdefaults()\n\tprint("OK")\n', False),
})


def runtime_probes(directory, task_id, selected=None):
    directory = directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="typed-array-probes"\n')
    rows = []
    for name, (source, expected_error) in PROBE_CASES.items():
        if selected and name not in selected: continue
        script = directory / (name + '.gd')
        script.write_text(PROBE_COMMON + source)
        command = [sys.executable, str(ROOT / 'tools/godot_task_runner.py'), '--task-id', task_id,
                   '--timeout', str(PROBE_TIMEOUT_SECONDS), '--stream', '--', 'godot', '--headless',
                   '--path', str(directory), '--script', str(script)]
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                env={**os.environ, 'LABYRINTH_CEL_LOOK': 'off'})
        (directory / (name + '.log')).write_text(result.stdout)
        errors = [line for line in result.stdout.splitlines() if 'SCRIPT ERROR:' in line]
        observed_error = bool(errors)
        passed = (observed_error == expected_error and
                  ((result.returncode == 1) if expected_error else (result.returncode == 0 and 'OK' in result.stdout)))
        row = dict(case=name, expected_error=expected_error, errors=errors,
                   returncode=result.returncode, passed=passed)
        rows.append(row)
        print(f'RUNTIME {name}: {"ERROR" if observed_error else "PASS"}; expectation {"PASS" if passed else "FAIL"}', flush=True)
    (directory / 'results.json').write_text(json.dumps(rows, indent=2) + '\n')
    print(f'RUNTIME PROBES: {sum(r["passed"] for r in rows)}/{len(rows)} expectations passed')
    return int(not all(r['passed'] for r in rows))


def self_test():
    source = 'extends RefCounted\n# var comment: Array[int] = []\nvar text = "( [ func return []"\nvar member: Array[int] = []\nvar later: Array[int]\nfunc plain() -> Array:\n return [1]\nfunc typed(values: Array) -> Array[int]:\n var result: Array[int]\n result.assign(values)\n return result\nfunc accept(values: Array[int] = []):\n pass\nfunc good() -> Array[int]:\n var a: Array[int] = typed([])\n var b: Array[int] = a.duplicate()\n var c: Array[int] = b.filter(func(v): return v > 0)\n var d: Array[int] = c.slice(0)\n var e: Array[int] = Array([], TYPE_INT, "", null)\n accept(a)\n return d\nfunc bad(source: Array, test: bool) -> Array[int]:\n var a: Array[int] = []\n var b: Array[int] = source\n var c: Array[int] = plain()\n var d: Array[int] = source.duplicate()\n var e: Array[int] = source.filter(func(v): return v > 0)\n var g: Array[int] = source.slice(0)\n var h: Array[int] = typed([]).map(func(v): return v)\n var j: Array[int] = {}.get("key", [])\n var k: Array[int] = [1] if test else a\n later = []\n accept([])\n accept(source)\n return plain()\nfunc bare_return() -> Array[int]:\n return []\nfunc lambda_case():\n var callback = func():\n  var nested: Array[int] = []\n  return true\n'
    hits = Audit([read_script('scripts/fixture.gd', source)]).run()
    observed = Counter((h.pattern, h.context) for h in hits)
    expected = Counter({('literal', 'var'): 3, ('literal', 'parameter-default'): 1,
                        ('literal', 'assignment'): 1, ('literal', 'argument'): 1,
                        ('literal', 'return'): 1, ('untyped-source', 'var'): 2,
                        ('untyped-source', 'argument'): 1, ('untyped-source', 'return'): 1,
                        ('untyped-transform', 'var'): 3, ('map', 'var'): 1,
                        ('dictionary-get', 'var'): 1, ('conditional', 'var'): 1})
    assert observed == expected, (observed, expected, hits)
    print(f'SELF TEST: PASS; {len(hits)} expected candidates; typed transfers/helpers/comments/strings ignored')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--json', type=Path, help='write all candidates and totals')
    parser.add_argument('--self-test', action='store_true', help='run on-demand scanner regression fixtures')
    parser.add_argument('--runtime-probes', type=Path, help='write and run individual headless engine cases here')
    parser.add_argument('--task-id', default='qa-19', help='runtime probe isolation id')
    parser.add_argument('--runtime-case', action='append', choices=sorted(PROBE_CASES), help='limit runtime probes to named cases')
    args = parser.parse_args()
    if args.self_test: return self_test()
    if args.runtime_probes: return runtime_probes(args.runtime_probes, args.task_id, args.runtime_case)
    scripts = [read_script(str(p.relative_to(args.root)), p.read_text())
               for base in ('scripts', 'assets') for p in sorted((args.root/base).rglob('*.gd'))]
    hits = Audit(scripts).run()
    counts = dict(sorted(Counter(h.pattern for h in hits).items()))
    for h in hits:
        print(f'{h.file}:{h.line}: {h.pattern} [{h.context} {h.target}; {h.owner}] {h.expression}')
    print(f'TYPED ARRAY AUDIT: {len(scripts)} scripts; {len(hits)} review candidates')
    print('PATTERNS: ' + json.dumps(counts, sort_keys=True))
    if args.json:
        args.json.write_text(json.dumps(dict(scripts=len(scripts), totals=counts,
                                             hits=[asdict(h) for h in hits]), indent=2) + '\n')
    return int(bool(hits))


if __name__ == '__main__':
    sys.exit(main())
