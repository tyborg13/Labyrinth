#!/usr/bin/env python3
"""Inventory tracked Godot UID declarations and textual references."""

from __future__ import annotations

import argparse
from collections import defaultdict
from dataclasses import dataclass
import os
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[2]
DECLARATION_SUFFIXES = {'.import', '.uid', '.tscn', '.tres'}
REFERENCE_SUFFIXES = {'.tscn', '.tres', '.gd', '.cfg'}
TEXT_RESOURCE_SUFFIXES = {'.tscn', '.tres'}
UID = rb'uid://[a-z0-9]+'
UID_REFERENCE = re.compile(UID)
IMPORT_UID = re.compile(rb'^[ \t]*uid[ \t]*=[ \t]*"(' + UID + rb')"', re.M)
RESOURCE_HEADER = re.compile(rb'^[ \t]*\[gd_(?:scene|resource)\s')
EXT_RESOURCE = re.compile(rb'^[ \t]*\[ext_resource\s')
QUOTED_ATTRIBUTE = re.compile(rb'([a-z_]+)\s*=\s*"((?:[^"\\]|\\.)*)"')


@dataclass(frozen=True)
class Location:
    path: str
    line: int
    target: str = ''

    def __str__(self) -> str:
        label = f'{self.path}:{self.line}'
        return f'{label} -> {self.target}' if self.target else label


def scan(root: Path) -> tuple[dict[str, list[Location]], dict[str, list[Location]]]:
    files = subprocess.check_output(
        ['git', 'ls-files', '--deduplicate', '-z', '--',
         *(f'*{suffix}' for suffix in sorted(DECLARATION_SUFFIXES | REFERENCE_SUFFIXES)),
         'data/*.json'], cwd=root,
    )
    declarations = defaultdict(list)
    references = defaultdict(list)
    for path in sorted(os.fsdecode(name) for name in files.split(b'\0') if name):
        suffix = Path(path).suffix
        source = (root / path).read_bytes().removeprefix(b'\xef\xbb\xbf')
        if suffix == '.import':
            for match in IMPORT_UID.finditer(source):
                line = source.count(b'\n', 0, match.start()) + 1
                declarations[match[1].decode()].append(Location(path, line))
            continue
        if suffix == '.uid':
            uid = source.strip()
            if UID_REFERENCE.fullmatch(uid):
                declarations[uid.decode()].append(Location(path, 1))
            continue
        if b'uid://' not in source:
            continue
        for line_number, line in enumerate(source.splitlines(), 1):
            matches = UID_REFERENCE.finditer(line)
            declaration = None
            target = ''
            ext_uid = None
            if suffix in TEXT_RESOURCE_SUFFIXES:
                if RESOURCE_HEADER.match(line):
                    declaration = next((attr for attr in QUOTED_ATTRIBUTE.finditer(line)
                                        if attr[1] == b'uid'), None)
                elif EXT_RESOURCE.match(line):
                    attributes = {attr[1]: attr for attr in QUOTED_ATTRIBUTE.finditer(line)}
                    ext_uid = attributes.get(b'uid')
                    if b'path' in attributes:
                        target = os.fsdecode(attributes[b'path'][2])
            for match in matches:
                uid = match[0].decode()
                if declaration and match.span() == declaration.span(2):
                    declarations[uid].append(Location(path, line_number))
                else:
                    ext_target = target if ext_uid and match.span() == ext_uid.span(2) else ''
                    references[uid].append(Location(path, line_number, ext_target))
    return declarations, references


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', action='store_true', help='show all declarations and references')
    args = parser.parse_args()
    declarations, references = scan(ROOT)
    duplicates = {uid for uid, locations in declarations.items()
                  if len({location.path for location in locations}) > 1}
    display = declarations.keys() | references.keys() if args.inventory else duplicates
    for uid in sorted(display):
        print(uid + (' (duplicate)' if uid in duplicates else ''))
        for declaration in declarations.get(uid, ()):
            print(f'  declares {declaration}')
        uses = references.get(uid, ())
        for reference in uses:
            print(f'  references {reference}')
        if not uses:
            print('  references: none')
    print(f'UID census: {sum(map(len, declarations.values()))} declarations, '
          f'{sum(map(len, references.values()))} references, {len(duplicates)} duplicate UIDs.')
    return 1 if duplicates else 0


if __name__ == '__main__':
    raise SystemExit(main())
