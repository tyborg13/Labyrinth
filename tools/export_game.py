#!/usr/bin/env python3
"""Release/playtest exports: refresh cel variants, fail closed, export, verify pack."""
import argparse
from configparser import ConfigParser
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

# Export imports must leave the checkout untouched, including Python caches.
sys.dont_write_bytecode = True
from cel_look import build, settings
from cel_look_inventory import inventory
from cel_look_state import OUTPUT_DIRECTORY, status

PROJECT = Path(__file__).resolve().parents[1]
EXPORT_TIMEOUT_SECONDS = 1800  # A fresh platform export imports the complete asset tree.
BUILD_STAMP = 'build_info.tres'
STAGING_EXCLUDES = frozenset({
    '.git', '.godot', '.import', '.steam', '.codex', 'build', 'output',
    'playtest', 'spec', 'tests', 'tmp', 'tools', 'experiments',
})


def expose_templates(home_root):
    """Keep saves/logs isolated while reading the host's installed templates."""
    host = Path.home()
    candidates = [host / 'Library/Application Support/Godot/export_templates',
                  Path(os.environ.get('XDG_DATA_HOME', host / '.local/share')) / 'godot/export_templates',
                  Path(os.environ.get('APPDATA', host / 'AppData/Roaming')) / 'Godot/export_templates']
    source = next((p for p in candidates if p.is_dir()), None)
    if source is not None:
        # The host editor reads its native directory even for cross-platform
        # exports. Copy just that directory when Windows denies symlinks (1314).
        relative = ('AppData/Roaming/Godot/export_templates' if sys.platform == 'win32' else
                    'Library/Application Support/Godot/export_templates' if sys.platform == 'darwin' else
                    'xdg/data/godot/export_templates')
        target = home_root / 'export' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            target.symlink_to(source, target_is_directory=True)
        except OSError:
            shutil.copytree(source, target)


def validate_copy(project, source):
    copied = project / OUTPUT_DIRECTORY
    if (copied / 'manifest.json').read_bytes() != (source / 'manifest.json').read_bytes():
        raise ValueError('Sanitized export has a stale cel manifest')
    manifest = json.loads((source / 'manifest.json').read_text())
    for relative, expected in manifest['sha256'].items():
        path = copied / relative
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError('Sanitized export missing/damaged cel variant: ' + relative)


def prepare_cel_variants(staged, work, sanitized):
    entries, _ = inventory(PROJECT)
    config = settings()
    if sanitized:
        source = PROJECT / OUTPUT_DIRECTORY
        if not status(PROJECT, source, entries, config)[0]:
            source = work / 'cel-cache'
            build(PROJECT, output=source, if_stale=True)
        validate_copy(staged, source)
    else:
        build(staged, if_stale=True)
    current, reason = status(PROJECT, staged / OUTPUT_DIRECTORY, entries, config)
    if not current:
        raise ValueError('Refusing export with stale cel variants: ' + reason)


def write_build_stamp(staged, preset):
    # A source snapshot without .git (release_squash_push.sh) names its commit explicitly.
    revision = os.environ.get('LABYRINTH_BUILD_COMMIT', '').strip()[:9]
    date = os.environ.get('LABYRINTH_BUILD_DATE', '').strip()
    if not (revision and date):
        revision, date = git_revision()
    stamp_preset(staged, preset, revision, date)


def git_revision():
    try:
        revision = subprocess.check_output(['git', 'rev-parse', '--short=9', 'HEAD'],
                                           cwd=PROJECT, text=True, stderr=subprocess.PIPE).strip()
        date = subprocess.check_output(['git', 'log', '-1', '--format=%cs', revision],
                                       cwd=PROJECT, text=True, stderr=subprocess.PIPE).strip()
    except (OSError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, 'stderr', '') or str(exc)
        raise ValueError('Cannot stamp export from Git: ' + detail.strip()) from exc
    return revision, date


def stamp_preset(staged, preset, revision, date):
    config = ConfigParser(interpolation=None)
    config.read(staged / 'export_presets.cfg', encoding='utf-8')
    for section in config.values():
        if section.get('name') == json.dumps(preset):
            demo = 'demo' in [feature.strip() for feature in section.get('custom_features', '').strip('"').split(',')]
            break
    else:
        raise ValueError('Cannot stamp unknown export preset: ' + preset)

    (staged / BUILD_STAMP).write_text(
        '[gd_resource type="Resource" format=3]\n\n[resource]\n'
        f'metadata/commit_hash = {json.dumps(revision)}\n'
        f'metadata/commit_date = {json.dumps(date)}\n'
        f'metadata/demo = {json.dumps(demo)}\n', encoding='utf-8')


def stage_project(project, staged):
    def ignore(directory, names):
        excluded = STAGING_EXCLUDES if Path(directory) == project else set()
        return (excluded | {'.DS_Store', '__pycache__'}).intersection(names)

    shutil.copytree(project, staged, ignore=ignore)


def verify_export(pack, task_id, godot, environment):
    return subprocess.run([sys.executable, str(PROJECT / 'tools/cel_look_export.py'),
                           '--task-id', task_id, '--godot', godot, str(pack)], env=environment).returncode


def export(preset, output, task_id, godot='godot', pack_only=False, project=PROJECT):
    project = project.resolve()
    output = output.resolve()
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    with tempfile.TemporaryDirectory(prefix='labyrinth-export-') as directory:
        work = Path(directory)
        staged = work / 'project'
        stage_project(project, staged)
        prepare_cel_variants(staged, work, project != PROJECT)
        write_build_stamp(staged, preset)
        output.parent.mkdir(parents=True, exist_ok=True)
        home_root = work / 'home'
        expose_templates(home_root)
        command = [sys.executable, str(PROJECT / 'tools/godot_task_runner.py'),
                   '--project', str(staged), '--run-id', 'export', '--godot-home-root', str(home_root),
                   '--timeout', str(EXPORT_TIMEOUT_SECONDS), '--task-id', task_id, '--stream',
                   '--', godot, '--headless', '--path', str(staged),
                   '--export-pack' if pack_only else '--export-release', preset, str(output)]
        code = subprocess.run(command, env=environment).returncode
        if code:
            return code
    if pack_only:
        return verify_export(output, task_id, godot, environment)
    if output.suffix.lower() == '.zip':
        with tempfile.TemporaryDirectory(prefix='cel-macos-pack-') as directory, zipfile.ZipFile(output) as archive:
            packs = [name for name in archive.namelist() if name.endswith('.pck')]
            if len(packs) != 1:
                raise ValueError('Expected one macOS pack in ' + str(output))
            pack = Path(archive.extract(packs[0], directory))
            return verify_export(pack, task_id, godot, environment)
    pack = output / 'Contents/Resources/Escape the Umbra.pck' if output.suffix == '.app' else output.with_suffix('.pck')
    if output.suffix == '.app':
        packs = list((output / 'Contents/Resources').glob('*.pck'))
        if len(packs) != 1:
            raise ValueError('Expected one macOS app pack')
        pack = packs[0]
    # Embedded Windows/Linux packs are mountable by Godot as executable files.
    return verify_export(pack if pack.exists() else output, task_id, godot, environment)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preset', required=True, choices=[
        'Steam macOS', 'Steam Windows', 'Steam Linux',
        'Steam Demo macOS', 'Steam Demo Windows', 'Steam Demo Linux'])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--task-id', required=True)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', type=Path, default=PROJECT, help='Optional sanitized copy of this project.')
    parser.add_argument('--pack-only', action='store_true')
    args = parser.parse_args(argv)
    try:
        return export(args.preset, args.output, args.task_id, args.godot, args.pack_only, args.project)
    except (OSError, ValueError) as exc:
        parser.exit(1, f'Export failed: {exc}\n')


if __name__ == '__main__':
    raise SystemExit(main())
