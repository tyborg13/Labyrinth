"""Freeze this worktree; adapt perf55/perf57 drivers without modifying originals."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path('/Users/borgerding/workspace/Labyrinth.worktrees/perf-65')
BASE = Path('/private/tmp/labyrinth_codex/perf-65')
TOOLS = BASE / 'tools'
P55 = Path('/private/tmp/labyrinth_codex/perf-55/tools')
P57 = Path('/private/tmp/labyrinth_codex/perf-57/tools')
PROBE = 'preload("/private/tmp/labyrinth_codex/perf-65/tools/whole_probe.gd")'
FOLDERS = ['assets', 'addons', 'data', 'fonts', 'scenes', 'scripts', 'shaders', 'themes', 'tools', 'tests', '.godot', 'project.godot']


def clone(source, target):
    subprocess.run(['cp', '-cR', str(source), str(target)], check=True)


def wrap_persistence(project):
    p = project / 'scripts/run_persistence.gd'
    s = p.read_text()
    signature = 'static func persist(scene: Node, run_state: Dictionary, hold_for_animation: bool, boundary: String) -> Dictionary:'
    assert s.count(signature) == 1
    wrapper = f'''{signature}
\t{PROBE}.begin()
\tvar result: Dictionary = _perf65_original_persist(scene, run_state, hold_for_animation, boundary)
\t{PROBE}.finish_boundary(boundary, str(run_state.get("mode", "")), bool(result.get("saved", false)))
\treturn result

'''
    p.write_text(s.replace(signature, wrapper + signature.replace('func persist(', 'func _perf65_original_persist(')))
    p = project / 'scripts/progression_store.gd'
    s = p.read_text()
    signature = 'static func save_run_state(run_state: Dictionary) -> bool:'
    wrapper = f'''{signature}
\tif {PROBE}.depth > 0: return _perf65_original_save_run_state(run_state)
\t{PROBE}.begin()
\tvar saved: bool = _perf65_original_save_run_state(run_state)
\t{PROBE}.finish_boundary("direct_save", str(run_state.get("mode", "")), saved)
\treturn saved

'''
    assert s.count(signature) == 1
    p.write_text(s.replace(signature, wrapper + signature.replace('func save_run_state(', 'func _perf65_original_save_run_state(')))


def identity_seams(project):
    # Pin process-specific inputs before serialization; never normalize bytes.
    p = project / 'scripts/run_score_rules.gd'
    s = p.read_text().replace('now_usec: int = Time.get_ticks_usec()', f'now_usec: int = {PROBE}.FIXTURE_WALL_USEC')
    p.write_text(s)
    p = project / 'scripts/analytics_store.gd'
    s = p.read_text()
    start = s.index('static func _random_id(')
    end = s.index('static func _timestamp_utc_iso()', start)
    s = s[:start] + f'static func _random_id(prefix: String) -> String:\n\treturn {PROBE}.fixture_id(prefix)\n\n' + s[end:]
    start = s.index('static func _timestamp_utc_iso()')
    end = s.index('static func _utc_date_string()', start)
    s = s[:start] + f'static func _timestamp_utc_iso() -> String:\n\treturn {PROBE}.FIXTURE_TIMESTAMP\n\n' + s[end:]
    start = s.index('static func _utc_date_string()')
    end = s.index('static func _sanitize_variant(', start)
    s = s[:start] + 'static func _utc_date_string() -> String:\n\treturn "2026-11-05"\n\n' + s[end:]
    p.write_text(s)
    p = project / 'scripts/run_scene.gd'
    s = p.read_text()
    start = s.index('func _analytics_random_id(')
    end = s.index('func _analytics_context_from_states(', start)
    s = s[:start] + f'func _analytics_random_id(prefix: String) -> String:\n\treturn {PROBE}.fixture_id(prefix)\n\n' + s[end:]
    p.write_text(s)
    # Use perf57's advancing presentation-clock seam for deterministic replay.
    p = project / 'scripts/presentation_clock.gd'
    s = p.read_text()
    clock = 'preload("res://tests/helpers/presentation_test_clock.gd").now_usec'
    p.write_text(s.replace('Time.get_ticks_usec()', clock).replace('Time.get_ticks_msec()', f'({clock} / 1000)'))


def main():
    provenance = {'base_head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  'original_drivers': {}, 'projects': {}, 'clock_fixture_usec': 42000000,
                  'identity_policy': 'raw byte compare after join; deterministic wall-clock and generated identity inputs; no stripped fields',
                  'driver_policy': 'perf55 three sections; normal maximum HP, room-entry heal, private lethal floor 1; 8x simulation, fixed 120 Hz'}
    for folder, names in [(P55,['hunt.gd','hunt-base.gd','policy.gd','trace.gd']),
                           (P57,['hunt_identity.gd','snapshot.gd','whole_session.py','prepare_whole_identity.py','report_whole.py'])]:
        for name in names:
            p = folder/name
            provenance['original_drivers'][str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
    for name in ['hunt-base.gd','policy.gd','trace.gd']:
        (TOOLS/name).write_text((P55/name).read_text())
    (TOOLS/'snapshot.gd').write_text((P57/'snapshot.gd').read_text())
    for source, name in [(P55/'hunt.gd','hunt.gd'), (P57/'hunt_identity.gd','hunt_identity.gd')]:
        s = source.read_text().replace('perf-55','perf-65').replace('perf-57','perf-65').replace('PERF55','PERF65').replace('PERF57','PERF65')
        anchor = '\trecording = false\n'
        assert s.count(anchor) == 1
        s = s.replace('\tsuper._finish(outcome)\n', f'\tawait super._finish(outcome)\n\t{PROBE}.finish(frame_rows.size())\n')
        (TOOLS/name).write_text(s)
    for side in ['before','after']:
        project = BASE / ('whole-' + side)
        if project.exists(): raise SystemExit('Refusing to overwrite ' + str(project))
        if side == 'before':
            project.mkdir()
            for name in FOLDERS: clone(ROOT/name, project/name)
        else: clone(BASE/'whole-before', project)
        for name in ['run_persistence.gd','progression_store.gd']:
            raw = (subprocess.check_output(['git','show','HEAD:scripts/'+name],cwd=ROOT,text=True)
                   if side == 'before' else (ROOT/'scripts'/name).read_text())
            (project/'scripts'/name).write_text(raw)
        p = project/'scripts/combat_engine.gd'; s=p.read_text()
        old = 'player["hp"] = maxi(0, int(player.get("hp", 0)) - remaining)'
        if old in s:
            assert s.count(old) == 1
            p.write_text(s.replace(old, 'player["hp"] = maxi(1, int(player.get("hp", 0)) - remaining) # inherited perf55 proof-only lethal floor'))
        wrap_persistence(project)
        provenance['projects'][side] = str(project)
        identity = BASE/('whole-identity-'+side)
        clone(project, identity)
        identity_seams(identity)
    (BASE/'whole-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
    print('PERF65 WHOLE PREPARE: PASS (4 frozen projects; inherited drivers; isolated oracle seams)')


if __name__ == '__main__': main()
