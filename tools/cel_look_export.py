"""Verify generated cel bytes inside a real exported pack with Godot."""
import os
import json
from pathlib import Path
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
PACK_PROBE = '''extends SceneTree
func _initialize() -> void:
    var expected_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[1]))
    if not ProjectSettings.load_resource_pack(OS.get_cmdline_user_args()[0]):
        push_error("CEL_PACK mount failed")
        quit(1)
        return
    var manifest_path: String = "res://cel_look_variants/manifest.json"
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) if FileAccess.file_exists(manifest_path) else null
    if not manifest is Dictionary or manifest.get("variants", {}).is_empty():
        print("CEL_PACK_STALE missing/invalid manifest; re-export with tools/export_game.py before uploading.")
        quit(1)
        return
    for key: String in ["stamp", "files", "variants"]:
        if manifest.get(key) != expected_manifest.get(key):
            print("CEL_PACK_STALE %s differs from current inputs; re-export with tools/export_game.py before uploading." % key)
            quit(1)
            return
    var failures: int = 0
    for relative: String in manifest["variants"].values():
        var path: String = "res://cel_look_variants/" + relative
        if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != manifest["sha256"].get(relative):
            push_error("CEL_PACK missing/damaged " + relative)
            failures += 1
    if FileAccess.file_exists("res://cel_look_variants/report.json"):
        push_error("CEL_PACK report must not ship")
        failures += 1
    if failures == 0:
        # Load the actual exported runtime only after mounting, so its static
        # manifest and default mode come from this pack, not the source tree.
        var cel: Script = load("res://scripts/cel_look.gd")
        var assets: Script = load("res://scripts/asset_loader.gd")
        if cel.get("mode") != "all":
            push_error("CEL_PACK default mode must be all")
            failures += 1
        for scope: String in ["actors", "all"]:
            for source: String in manifest["files"]:
                if manifest["files"][source] != scope: continue
                var expected := Image.new()
                var error: Error = expected.load_png_from_buffer(FileAccess.get_file_as_bytes("res://cel_look_variants/" + manifest["variants"][source]))
                var texture: Texture2D = assets.load_texture_source_first("res://" + source)
                if error != OK or texture == null or texture.get_image().get_data() != expected.get_data():
                    push_error("CEL_PACK runtime pixel mismatch " + source)
                    failures += 1
                break
    print("CEL_PACK_TEST paths=%d failures=%d" % [manifest["variants"].size(), failures])
    quit(1 if failures else 0)
'''


def current_expected_manifest():
    from cel_look import settings
    from cel_look_inventory import inventory
    from cel_look_state import expected_manifest
    entries, _ = inventory(PROJECT)
    return expected_manifest(PROJECT, entries, settings())


def verify_pack(pack: Path, task_id: str, godot: str = 'godot', *, expected=None) -> int:
    # Always derive the upload expectation from current inputs, not from the
    # pack or an old local output cache. Explicit expectations are test fixtures.
    expected = current_expected_manifest() if expected is None else expected
    with tempfile.TemporaryDirectory(prefix='cel-pack-') as directory:
        project = Path(directory)
        (project / 'project.godot').write_text('config_version=5\n')
        script = project / 'probe.gd'
        expected_path = project / 'expected.json'
        expected_path.write_text(json.dumps(expected))
        environment = os.environ.copy()
        # The pack's launch default must be exercised, despite the test runner.
        # The bootstrap unsets the runner's source-art default before loading it.
        script.write_text(PACK_PROBE.replace('func _initialize() -> void:\n',
                          'func _initialize() -> void:\n    OS.unset_environment("LABYRINTH_CEL_LOOK")\n'))
        result = subprocess.run([
            sys.executable, str(PROJECT / 'tools/godot_task_runner.py'),
            '--project', str(project), '--task-id', task_id, '--stream', '--',
            godot, '--headless', '--path', str(project), '--script', str(script),
            '--', str(pack.resolve()), str(expected_path),
        ], env=environment, capture_output=True, text=True)
        stale = next((line for line in result.stdout.splitlines() if line.startswith('CEL_PACK_STALE ')), None)
        if stale:
            print(stale, flush=True)
        else:
            print(result.stdout + result.stderr, end='', flush=True)
        return result.returncode


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack', type=Path)
    parser.add_argument('--task-id', required=True)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    raise SystemExit(verify_pack(args.pack, args.task_id, args.godot))
