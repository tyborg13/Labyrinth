#!/usr/bin/env python3
"""Prepare a verified local Steam upload folder; never uploads or publishes."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent


def sha256(path: Path) -> str:
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, required=True, help='New folder; existing paths are refused')
    parser.add_argument('--asset-version', required=True, help='New custom-asset filename suffix, for example v2')
    parser.add_argument('--trailer', type=Path, help='Optional reviewed Steam-compatible MP4 to include')
    parser.add_argument('--changed-description-only', action='store_true', help='Include only description media whose current hash differs from the recorded uploaded hash')
    parser.add_argument('--with-resolved-copy', action='store_true', help='Require verified UI references and include final Steam BBCode')
    args = parser.parse_args()
    assert re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', args.asset_version), 'Use a simple asset version, such as v2'
    destination = args.destination.expanduser().resolve()
    assert not destination.exists(), f'Refusing to replace an existing package: {destination}'
    command = [sys.executable, str(ROOT / 'generate-preview.py')]
    if args.with_resolved_copy:
        command.append('--resolve-steam')
    subprocess.run(command, check=True)
    plan = json.loads((ROOT / 'upload-plan.json').read_text())
    refs_path = ROOT / 'steam-asset-refs.json'
    refs = json.loads(refs_path.read_text()) if refs_path.exists() else {}
    entries = []

    def register(source: Path, relative: str, expected: str | None = None, **details: object) -> None:
        actual = sha256(source)
        assert expected is None or actual == expected, f'Stale source file: {source}'
        entries.append({'source': str(source), 'file': relative, 'sha256': actual,
                        'bytes': source.stat().st_size, **details})

    for item in plan['gallery']:
        register(ROOT / item['file'], item['file'], item['sha256'], kind='gallery',
                 order=item['order'], alt_text=item['alt_text'])
    for item in plan['description_asset_uploads']:
        uploaded = refs.get('uploaded_sha256', {}).get(item['placeholder'])
        changed = uploaded != item['sha256']
        if args.changed_description_only and not changed:
            continue
        source = ROOT / item['file']
        name = f'{source.stem}-{args.asset_version}_english{source.suffix}'
        observed = refs.get('mapping', {}).get(item['placeholder'], '')
        group = re.fullmatch(r'(?:\[img\])?\{STEAM_APP_IMAGE\}/extras/([A-Za-z0-9][A-Za-z0-9_.-]*)(?:\[/img\])?', observed)
        if not changed and group:
            # An unchanged asset keeps the already observed upload group name.
            name = f'{group.group(1)}_english{source.suffix}'
        register(source, 'about-assets/' + name, item['sha256'], kind=item['kind'],
                 asset_id=item['id'], placeholder=item['placeholder'],
                 alt_text=item['alt_text'], changed_since_recorded_upload=changed)
    for name in ('copy.json', 'short-description.txt', 'description.md',
                 'description.bbcode.template.txt', 'media-manifest.json',
                 'upload-plan.json', 'README.md', 'WORKFLOW.md'):
        register(ROOT / name, 'reference/' + name, kind='reference')
    if args.with_resolved_copy:
        register(ROOT / 'description.bbcode.txt', 'description.bbcode.txt', kind='resolved_copy')
        register(refs_path, 'reference/steam-asset-refs.json', kind='reference')
    if args.trailer:
        trailer = args.trailer.expanduser().resolve()
        assert trailer.suffix.lower() == '.mp4', 'Include the reviewed compatible MP4, not the archival master'
        register(trailer, 'trailer/' + trailer.name, kind='trailer')
    files = [item['file'] for item in entries]
    assert len(set(files)) == len(files), 'Duplicate output filenames'
    # Validate everything before creating the package. A copy error leaves an
    # incomplete folder without READY.json; it can never look like a final handoff.
    destination.mkdir(parents=True)
    for item in entries:
        output = destination / item['file']
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(item['source'], output)
        assert sha256(output) == item['sha256'], f'Copy verification failed: {output}'
    head = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain'], text=True).strip())
    manifest = {'schema': 1, 'app_id': 4530510, 'asset_version': args.asset_version,
                'store_source_head': head, 'store_source_dirty': dirty,
                'resolved_copy': args.with_resolved_copy,
                'all_copies_verified': True, 'files': entries}
    (destination / 'START-HERE.txt').write_text(
        'Escape the Umbra — Steam upload package\n\n'
        'READY.json binds every copied file to its verified SHA-256.\n'
        'screenshots/: eight native gameplay PNGs, numbered in gallery order.\n'
        'about-assets/: custom section banners and silent loops, with English localization filenames.\n'
        'trailer/: optional reviewed Steam-compatible MP4.\n'
        'reference/WORKFLOW.md: targeted edits, validation and the actual upload workflow.\n\n'
        'Preparation does not upload or publish anything. Use the normal Steamworks controls.\n'
        'Record actual uploaded references and hashes before resolving final BBCode.\n'
        'The September 2026 legacy trailer/gallery drag controls require a manual handoff;\n'
        'the custom description asset file chooser works. Do not bypass browser security blocks.\n')
    (destination / 'READY.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'package': str(destination), 'files': len(entries),
                      'description_assets': sum(e['kind'] in ('image', 'silent_animation') for e in entries),
                      'resolved_copy': args.with_resolved_copy}, indent=2))


if __name__ == '__main__':
    main()
