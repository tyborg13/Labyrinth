#!/usr/bin/env python3
"""Run the standard release smoke with a probe for both Reaver texture UIDs."""

from pathlib import Path
import re
import sys
import time


ROOT = Path(__file__).resolve().parents[2]
LOGS = ROOT / 'output/gfix46/export'
PRESET = 'Steam macOS'
SUMMARY = '\tprint("EXPORT_SMOKE_LOADED '
UID_WARNING = re.compile(r'\b(?:duplicate\b.*\buid\b|uid\b.*\bduplicate\b|'
                         r'(?:invalid|unrecognized) uid\b|uid\b.*already exists)|'
                         r'\bWARNING:.*\buid\b', re.I)

REAVER_PROBE = '''
func _check_reaver_textures() -> int:
	var textures: Dictionary = {
		"uid://dhbcy5jpnld0c": "res://assets/placeholders/units/player_reaver_idle.png",
		"uid://ntbi2w113m2l": "res://assets/placeholders/units/player_reaver_anime_idle.png",
	}
	var failed: int = 0
	for uid: String in textures:
		var path: String = textures[uid]
		var id: int = ResourceUID.text_to_id(uid)
		if not ResourceUID.has_id(id) or ResourceUID.get_id_path(id) != path:
			push_error("EXPORT_SMOKE UID mapping mismatch: %s -> %s" % [uid, path])
			failed += 1
			continue
		var by_path := ResourceLoader.load(path) as Texture2D
		var by_uid := ResourceLoader.load(uid) as Texture2D
		if by_path == null or by_uid == null or by_uid.resource_path != path:
			push_error("EXPORT_SMOKE texture load mismatch: %s -> %s" % [uid, path])
			failed += 1
			continue
		print("GFIX46_TEXTURE_LOADED %s -> %s (%dx%d)" % [uid, path, by_uid.get_width(), by_uid.get_height()])
	return failed
'''


def main() -> int:
    sys.path.insert(0, str(ROOT / 'tools'))
    import export_smoke

    started = time.monotonic()
    passed = False
    try:
        LOGS.mkdir(parents=True, exist_ok=True)
        if export_smoke.PACK_PROBE.count(SUMMARY) != 1:
            raise ValueError('Could not locate the release smoke summary')
        export_smoke.TASK_ID = 'gfix-46'
        export_smoke.PACK_PROBE = export_smoke.PACK_PROBE.replace(
            SUMMARY, '\tfailures += _check_reaver_textures()\n' + SUMMARY,
        ) + REAVER_PROBE
        passed = export_smoke.smoke(ROOT, PRESET, LOGS)
        if passed:
            for filename in ('export.log', 'launch.log'):
                for line in (LOGS / filename).read_text(errors='replace').splitlines():
                    if line.startswith('GFIX46_TEXTURE_LOADED '):
                        print(line)
                    if UID_WARNING.search(line):
                        print(f'GFIX46_UID_WARNING {filename}: {line}')
                        passed = False
    except (OSError, ValueError) as error:
        print(f'GFIX46_EXPORT_SMOKE error: {error}', file=sys.stderr)
    print('GFIX46_EXPORT_SMOKE RESULT: %s (%.2f seconds)' % (
        'PASS' if passed else 'FAIL', time.monotonic() - started,
    ))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
