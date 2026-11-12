"""Run the silhouette code in a headless release template, using the cel wrapper.

Only a disposable copy's main scene changes. No product export setting changes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from export_smoke import STAGING_EXCLUDES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--task-id', default='rd-02')
    parser.add_argument('--use-provided-cel', action='store_true', help='Use approved existing variants without generating art.')
    parser.add_argument('--reuse', action='store_true', help='Refresh only product scripts in an existing owned staging copy.')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    staged = output / 'project'
    if staged.exists() and not args.reuse:
        parser.error('use a fresh output directory; existing staged project is preserved')
    if args.use_provided_cel:
        assert (ROOT / 'cel_look_variants/manifest.json').is_file(), 'Approved cel variants are required'
    else:
        code = subprocess.run([sys.executable, 'tools/cel_look.py', 'build', '--if-stale'], cwd=ROOT).returncode
        if code:
            return code

    def ignore(directory, names):
        excluded = STAGING_EXCLUDES if Path(directory) == ROOT else set()
        return (set(excluded) | {'.DS_Store', '__pycache__'}).intersection(names)

    if args.reuse:
        assert (staged / '__rd02__/main.tscn').is_file(), 'Not an rd02 staging copy'
        shutil.copytree(ROOT / 'scripts', staged / 'scripts', dirs_exist_ok=True)
    else:
        shutil.copytree(ROOT, staged, ignore=ignore)
    probe = staged / '__rd02__'
    probe.mkdir(exist_ok=True)
    code = subprocess.run([sys.executable, "tools/godot_task_runner.py", "--task-id", args.task_id, "--stream",
        "--", "godot", "--headless", "--path", ".", "--script", "tools/rd02/write_release_fixture.gd",
        "--", "--output", str(probe / "fixture.tres")], cwd=ROOT).returncode
    if code:
        return code
    shutil.copy2(ROOT / 'tools/rd02/release_probe.gd', probe / 'release_probe.gd')
    (probe / 'main.tscn').write_text('[gd_scene load_steps=3 format=3]\n'
        '[ext_resource type="Script" path="res://__rd02__/release_probe.gd" id="1"]\n'
        '[ext_resource type="Resource" path="res://__rd02__/fixture.tres" id="2"]\n'
        '[node name="RD02ReleaseProbe" type="Node"]\nscript = ExtResource("1")\nmetadata/fixture = ExtResource("2")\n')
    config = staged / 'project.godot'
    text, count = re.subn(r'^run/main_scene=.*$', 'run/main_scene="res://__rd02__/main.tscn"', config.read_text(), flags=re.M)
    assert count == 1
    config.write_text(text)
    source_hashes = {name: hashlib.sha256((staged / name).read_bytes()).hexdigest() for name in [
        'scripts/board_unit_team_outlines.gd', 'scripts/board_occlusion_alpha.gd', 'scripts/combat_board_view.gd', 'scripts/board_occlusion_sources.gd',
        'scripts/board_occlusion_silhouettes.gd', 'scripts/board_occlusion_silhouettes.gdshader']}
    (output / 'source-hashes.json').write_text(json.dumps(source_hashes, indent=2) + '\n')
    app = output / 'RD02.app'
    exporter = 'tools/rd08/export_provided.py' if args.use_provided_cel else 'tools/export_game.py'
    code = subprocess.run([sys.executable, exporter, '--task-id', args.task_id,
                           '--preset', 'Steam macOS', '--project', str(staged), '--output', str(app)], cwd=ROOT).returncode
    if code:
        return code
    binary, = (app / 'Contents/MacOS').iterdir()
    code = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', args.task_id,
                           '--project', str(output), '--stream', '--', str(binary), '--headless',
                           '--audio-driver', 'Dummy'], cwd=ROOT).returncode
    return code


if __name__ == '__main__':
    raise SystemExit(main())
