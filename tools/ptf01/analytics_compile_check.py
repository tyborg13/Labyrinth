#!/usr/bin/env python3
"""Isolate the base UI signature failure without stashing or changing UI code."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-01/feedback1')
BASE_REF = '7cf181c7e'
HELPER = 'scripts/deferred_choice_surface.gd'


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = subprocess.check_output(['git', 'show', f'{BASE_REF}:{HELPER}'], cwd=ROOT, text=True)
    assert source == (ROOT / HELPER).read_text(), 'UI helper changed from the supplied base'
    original = OUTPUT / 'base_deferred_choice_surface.gd'
    original.write_text(source)
    # Diagnostic source only: bind the parameter to the helper's existing local
    # preload alias. Never modify the production helper or its design values.
    bound = OUTPUT / 'bound_deferred_choice_surface.gd'
    bound.write_text(source.replace('skin: UiSkin', 'skin: SkinLibrary'))
    probe = OUTPUT / 'analytics_compile_isolation.gd'
    probe.write_text('''extends SceneTree
func _initialize() -> void:
	var base := GDScript.new()
	base.source_code = FileAccess.get_file_as_string("%s")
	var base_error: Error = base.reload()
	print("PTF01 BASE UI SIGNATURE: error=", base_error, " analytics_imported=false")
	var bound := GDScript.new()
	bound.source_code = FileAccess.get_file_as_string("%s")
	var bound_error: Error = bound.reload()
	print("PTF01 BOUND UI SIGNATURE: error=", bound_error, " analytics_imported=false")
	print("PTF01 ANALYTICS CAUSE: ", "PASS" if base_error != OK and bound_error == OK else "FAIL")
	quit(0 if base_error != OK and bound_error == OK else 1)
''' % (original, bound))
    print(f'PTF01 BASE UI SOURCE: identical to {BASE_REF}:{HELPER}', flush=True)
    # The task runner correctly reports the intentionally reproduced parser
    # marker as failure even when the diagnostic itself reaches CAUSE: PASS.
    result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'ptf-01',
                             '--stream', '--', 'godot', '--headless', '--path', '.',
                             '--script', str(probe)], cwd=ROOT)
    print(f'PTF01 COMPILE ISOLATION RUNNER: exit={result.returncode} (expected parser failure marker)', flush=True)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
