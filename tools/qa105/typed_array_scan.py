#!/usr/bin/env python3
"""Find Windows typed-array boundary hazards in GDScript.

  python3 tools/qa105/typed_array_scan.py --calibrate
  python3 tools/qa105/typed_array_scan.py --base 55f157e04
  python3 tools/qa105/typed_array_scan.py --base b1e4c3f4b --ref codex/perf-140 --merge-base

Without --ref, scan the working tree. With --base, inspect all eligible lines in
changed scripts but report only new findings by default. --all-findings also
prints findings already present at the base. --merge-base compares against
every best common ancestor and reports findings new relative to all of them.

This is a static review tool. It follows declared/inferred types and resolvable
script calls. Unknown Variant values, dynamic dispatch, and dictionary/cache
provenance may need manual review. Array.assign() converts elements into its
receiver's existing type and returns void. It does not type an untyped receiver.
A typed loop variable checks each element independently of the iterable's Array
metadata. There is no established Windows-only loop boundary here, so this tool
does not flag typed iteration merely because the iterable is untyped.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict
from difflib import SequenceMatcher
import json
from pathlib import Path
import re
import subprocess
import sys

TOOLS = Path(__file__).resolve().parents[1]
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))

from typed_array_audit import Audit, Hit, joined, read_script, split, top_indices

CALIBRATION_COMMIT = '55f157e04'
CALIBRATION_COUNT = 52
PRESERVING_METHODS = {'duplicate', 'filter', 'slice'}
ARRAY = 'Array'
UNKNOWN = 'Variant'


def typed(array_type):
    return array_type.startswith('Array[')


def array(array_type):
    return array_type == ARRAY or typed(array_type)


def conditional(tokens):
    indexes = top_indices(tokens, {'if', 'else'})
    first = next(indexes, None)
    if first is None or tokens[first].value != 'if':
        return None
    depth = 1
    for index in indexes:
        depth += 1 if tokens[index].value == 'if' else -1
        if depth == 0:
            return tokens[:first], tokens[index + 1:]
    return None


def trim(tokens):
    tokens = [token for token in tokens if token.value != '\\']
    while tokens and tokens[0].value == '(' and Audit.close(tokens, 0) == len(tokens) - 1:
        tokens = tokens[1:-1]
    return tokens


def call_parts(tokens):
    if not tokens or tokens[-1].kind == 'string' or tokens[-1].value != ')':
        return [], []
    opening = Audit.open(tokens, len(tokens) - 1)
    return tokens[:opening], split(tokens[opening + 1:-1])


def concatenation(tokens):
    # '+' binds below multiplication and above comparisons. Avoid treating the
    # rightmost call of an arbitrary scalar expression as its entire type.
    operands = split(tokens, '+')
    if len(operands) > 1 and all(operands):
        return operands
    return []


class TypedArrayScan(Audit):
    def signature(self, script, function, callee, line, *, candidate=False):
        # A project-wide unique method name cannot establish the receiver type.
        if joined(callee).startswith('super.'):
            parent = self.scripts.get(script.parent) or self.classes.get(script.parent)
            return self.method(parent, callee[-1].value) if parent else None
        if len(callee) == 3 and callee[1].value == '.':
            receiver_type = self.symbol(script, function, callee[0].value, line, set())
            target = self.scripts.get(script.aliases.get(receiver_type, ''))
            if target:
                return self.method(target, callee[-1].value)
        return super().signature(script, function, callee, line)

    def type_of(self, script, function, tokens, line, seen=None):
        tokens = trim(tokens)
        branches = conditional(tokens)
        if branches:
            left, right = (self.type_of(script, function, part, line, seen) for part in branches)
            if left == right:
                return left
            return ARRAY if array(left) and array(right) else UNKNOWN
        operands = concatenation(tokens)
        if operands:
            types = [self.type_of(script, function, part, line, seen) for part in operands]
            if all(array(kind) for kind in types):
                return types[0] if all(kind == types[0] for kind in types) else ARRAY
            return UNKNOWN
        callee, args = call_parts(tokens)
        name = joined(callee)
        if tokens and tokens[0].value == '{' and self.close(tokens, 0) == len(tokens) - 1:
            return 'Dictionary'
        casts = list(top_indices(tokens, {'as'}))
        if casts and joined(tokens[casts[-1] + 1:]) == ARRAY:
            # An upcast does not strip runtime element metadata.
            return self.type_of(script, function, tokens[:casts[-1]], line, seen)
        if name == 'Array' and len(args) == 4:
            return ARRAY if joined(args[1]) in {'0', 'TYPE_NIL'} else 'Array[constructor]'
        if name == 'range':
            return ARRAY
        if len(callee) >= 3 and callee[-2].value == '.':
            method = callee[-1].value
            # Resolve user-defined methods before applying built-in heuristics.
            signature = self.signature(script, function, callee, line)
            if signature:
                return signature[1].returns or UNKNOWN
            receiver_type = self.type_of(script, function, callee[:-2], line, seen)
            if method in PRESERVING_METHODS:
                return receiver_type if array(receiver_type) else UNKNOWN
            if method == 'map' and array(receiver_type):
                return ARRAY
            if method in {'keys', 'values'} and receiver_type == 'Dictionary':
                return ARRAY
            if method == 'get' and receiver_type.startswith('Dictionary') and len(args) == 2:
                # The fallback can be taken. The primary value may be typed.
                return ARRAY if self.type_of(script, function, args[1], line, seen) == ARRAY else UNKNOWN
            if method in {'map', 'keys', 'values', 'get_stack'}:
                return UNKNOWN
        return super().type_of(script, function, tokens, line, seen)

    def pattern(self, script, function, expr, line):
        tokens = trim(expr)
        if not tokens:
            return ''
        branches = conditional(tokens)
        if branches:
            return 'conditional' if any(self.pattern(script, function, part, line) for part in branches) else ''
        if tokens[0].kind != 'string' and tokens[0].value == '[' and self.close(tokens, 0) == len(tokens) - 1:
            return 'literal'
        callee, args = call_parts(tokens)
        if len(callee) >= 3 and callee[-2].value == '.':
            method = callee[-1].value
            receiver = callee[:-2]
            receiver_type = self.type_of(script, function, receiver, line)
            if method == 'assign' and array(receiver_type):
                return 'assign-returns-void'
            if method == 'get' and (receiver_type.startswith('Dictionary') or receiver[0].value == '{'):
                if len(args) == 2 and self.pattern(script, function, args[1], line):
                    return 'dictionary-array-fallback'
        kind = self.type_of(script, function, tokens, line)
        if kind != ARRAY:
            return ''
        if callee and callee[-1].value in PRESERVING_METHODS:
            return 'untyped-' + callee[-1].value
        return 'untyped-source'

    def extra_arguments(self, script, function, statement, index):
        if index < 2 or index + 1 >= len(statement):
            return
        if statement[index - 1].value != '.' or statement[index + 1].value != '(':
            return
        token = statement[index]
        receiver = operand_left(statement, index - 1)
        args = split(statement[index + 2:self.close(statement, index + 1)])
        if not receiver or not args[0]:
            return
        if token.value == 'assign':
            kind = self.type_of(script, function, receiver, token.line)
            if array(kind) and len(args) == 1 and definitely_non_array(args[0]):
                yield args[0], 'assign-non-array', joined(receiver) + '.assign'
            return
        method = args[0]
        if len(method) == 2 and method[0].value == '&':
            method = method[1:]
        if len(method) != 1 or method[0].kind != 'string':
            return
        callee = receiver + statement[index - 1:index] + method
        signature = self.signature(script, function, callee, token.line)
        if signature:
            for value, (param, kind, _) in zip(args[1:], signature[1].params):
                if typed(kind) and value:
                    pattern = self.pattern(script, function, value, value[0].line)
                    if pattern:
                        yield value, pattern, joined(callee) + ':' + param

    def mixed_concat(self, script, function, statement, index):
        # The result can escape through a Variant or plain Array.
        left = operand_left(statement, index)
        offset = index + 1
        if offset < len(statement) and statement[offset].value == '=':
            offset += 1
        right = operand_right(statement, offset)
        if left and right:
            line = statement[index].line
            kinds = [self.type_of(script, function, side, line) for side in (left, right)]
            if ARRAY in kinds and any(typed(kind) for kind in kinds):
                return joined(left) + ' + ' + joined(right)
        return ''

    def run(self, paths=None):
        hits = super().run(paths)
        for path in sorted(paths if paths is not None else self.scripts):
            script = self.scripts[path]
            for statement in script.lines:
                function = script.owner(statement[0].line)
                owner = function.name if function else ''
                for index, token in enumerate(statement):
                    if token.kind == 'string':
                        continue
                    if token.value in {'assign', 'call'}:
                        for value, pattern, target in self.extra_arguments(script, function, statement, index):
                            hits.append(Hit(path, value[0].line, pattern, 'argument', target, joined(value), owner))
                    elif token.value == '+':
                        expression = self.mixed_concat(script, function, statement, index)
                        if expression:
                            hits.append(Hit(path, token.line, 'mixed-array-concat', 'operator', '+', expression, owner))
        return sorted(set(hits), key=lambda hit: (hit.file, hit.line, hit.context, hit.target,
                                                 hit.pattern, hit.expression))


OPERAND_BREAKS = {',', ':', '=', '+', '-', '*', '/', '%', '<', '>', '!', 'and', 'or', 'if', 'else', 'return', 'in', ';'}


def definitely_non_array(tokens):
    tokens = trim(tokens)
    if not tokens:
        return False
    if tokens[0].value == '{' and Audit.close(tokens, 0) == len(tokens) - 1:
        return True
    return len(tokens) == 1 and (tokens[0].kind == 'string' or tokens[0].value in {'null', 'true', 'false'})


def operand_left(tokens, end):
    start = end
    while start:
        token = tokens[start - 1]
        if token.kind != 'string':
            if token.value in OPERAND_BREAKS or token.value in ('(', '[', '{'):
                break
            if token.value in (')', ']', '}'):
                start = Audit.open(tokens, start - 1)
                continue
        start -= 1
    return tokens[start:end]


def operand_right(tokens, start):
    end = start
    while end < len(tokens):
        token = tokens[end]
        if token.kind != 'string':
            if token.value in OPERAND_BREAKS or token.value in (')', ']', '}'):
                break
            if token.value in ('(', '[', '{'):
                end = Audit.close(tokens, end) + 1
                continue
        end += 1
    return tokens[start:end]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def revision_sources(ref):
    entries = []
    for item in git('ls-tree', '-rz', ref).split(b'\0'):
        if item.endswith(b'.gd'):
            meta, path = item.split(b'\t', 1)
            entries.append((meta.split()[2], path.decode()))
    request = b''.join(oid + b'\n' for oid, _ in entries)
    batch = subprocess.run(['git', 'cat-file', '--batch'], cwd=ROOT, input=request,
                           stdout=subprocess.PIPE, check=True).stdout
    sources = {}
    cursor = 0
    for _, path in entries:
        header_end = batch.index(b'\n', cursor)
        size = int(batch[cursor:header_end].split()[-1])
        cursor = header_end + 1
        sources[path] = batch[cursor:cursor + size].decode('utf-8-sig')
        cursor += size + 1
    return sources


def working_sources():
    paths = git('ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', '*.gd')
    return {name: (ROOT / name).read_text(encoding='utf-8-sig')
            for name in dict.fromkeys(paths.decode().split('\0'))
            if name and (ROOT / name).is_file()}


def scan(sources, paths):
    # Keep unchanged scripts in the resolver, including inherited signatures.
    # Audit.run visits only the requested paths.
    return TypedArrayScan(read_script(path, source) for path, source in sources.items()).run(paths)


def hit_key(hit, line):
    return hit.file, line, hit.pattern, hit.context, hit.target, hit.expression


def old_findings(hits, baseline, current, paths):
    previous = {hit_key(hit, hit.line) for hit in scan(baseline, paths & baseline.keys())}
    line_maps = {}
    for path in paths & baseline.keys():
        old_lines = baseline[path].splitlines()
        new_lines = current[path].splitlines()
        matches = SequenceMatcher(None, old_lines, new_lines, autojunk=False).get_matching_blocks()
        line_maps[path] = {new + offset + 1: old + offset + 1
                           for old, new, size in matches for offset in range(size)}
    return {hit for hit in hits
            if hit_key(hit, line_maps.get(hit.file, {}).get(hit.line)) in previous}


def calibrate():
    parent = CALIBRATION_COMMIT + '^'
    patch = git('diff', '--no-renames', '--unified=0', parent, CALIBRATION_COMMIT, '--', '*.gd').decode()
    expected = set()
    path, line = '', 0
    for row in patch.splitlines():
        if row.startswith('--- a/'):
            path = row[6:]
        elif row.startswith('@@'):
            line = int(re.match(r'@@ -(\d+)', row)[1])
        elif row.startswith('-'):
            if row[1:].strip() != ']':  # Closing lines of multiline literals.
                expected.add((path, line))
            line += 1
    hits = scan(revision_sources(parent), {path for path, _ in expected})
    observed = {(hit.file, hit.line) for hit in hits if hit.pattern == 'literal'}
    missing = sorted(expected - observed)
    for file, line in missing:
        print(f'{file}:{line}: missed qa-95 boundary')
    print(f'QA-95 CALIBRATION: {len(expected & observed)}/{CALIBRATION_COUNT} historical fixes flagged')
    return int(bool(missing) or len(expected) != CALIBRATION_COUNT)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--ref', help='scan this Git revision instead of the working tree')
    parser.add_argument('--base', help='limit to scripts changed from this revision')
    parser.add_argument('--merge-base', action='store_true', help='compare against best common ancestors')
    parser.add_argument('--all-findings', action='store_true', help='include pre-existing findings')
    parser.add_argument('--json', type=Path, help='write finding details and comparison metadata')
    parser.add_argument('--calibrate', action='store_true', help='verify coverage of the 52 qa-95 changes')
    args = parser.parse_args()
    if args.calibrate:
        return calibrate()
    if args.merge_base and not args.base:
        parser.error('--merge-base requires --base')
    bases = ([args.base] if not args.merge_base else
             git('merge-base', '--all', args.base, args.ref or 'HEAD').decode().split()) if args.base else []
    current = revision_sources(args.ref) if args.ref else working_sources()
    baselines = [revision_sources(base) for base in bases]
    paths = {path for path, source in current.items()
             if not baselines or any(baseline.get(path) != source for baseline in baselines)}
    hits = scan(current, paths)
    inherited = set().union(*(old_findings(hits, base, current, paths) for base in baselines))
    findings = []
    for hit in hits:
        if hit in inherited and not args.all_findings:
            continue
        status = 'pre-existing' if hit in inherited else 'new'
        findings.append({**asdict(hit), 'status': status})
        print(f'{hit.file}:{hit.line}: {status} {hit.pattern} [{hit.context} {hit.target}] {hit.expression}')
    print(f'TYPED ARRAY SCAN: {len(paths)} scripts; {len(hits) - len(inherited)} new; {len(inherited)} pre-existing')
    if args.json:
        args.json.write_text(json.dumps(dict(ref=args.ref, bases=bases, scripts=len(paths),
                                             findings=findings), indent=2) + '\n')
    return int(bool(findings))


if __name__ == '__main__':
    sys.exit(main())
