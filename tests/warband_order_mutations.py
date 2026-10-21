#!/usr/bin/env python3
"""Opt-in spx-04 mutants. Restore each exact source in finally; use task runner."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = Path('/private/tmp/spx04-order-mutations')
MUTATIONS = (
('captain_scope', 'scripts/warband_combat_rules.gd', '\tif not active(state) or not bool(enemy.get("is_leader", false)) or int(enemy.get("hp", 0)) <= 0: return false\n\tvar leader: Dictionary = captain(state)\n\treturn int(leader.get("id", -1)) == int(enemy.get("id", -2)) and str(order_for_objective(state["objective"]).get("id", "")) == id', '\treturn str(order_for_objective(state.get("objective", {})).get("id", "")) == id', 'Order never granted to follower'),
    ('thorn_length', 'scripts/enemy_mechanics/bramble.gd', 'range(-2, 3)', 'range(-1, 2)', 'Thornmother telegraphs five tiles'),
    ('barrage_second_mark', 'scripts/enemy_mechanics/lob.gd', 'result.append(tile)\n\t\t\tbreak', 'pass\n\t\t\tbreak', 'Slagmaster preview exposes both'),
    ('wind_expiry', 'scripts/enemy_mechanics/wind.gd', 'if not persistent(engine, state, value): state["wind"]["rounds_left"]', 'if true: state["wind"]["rounds_left"]', 'Stormcaller wind does not expire'),
    ('ice_length', 'scripts/enemy_mechanics/icefall.gd', 'range(-2, 3)', 'range(-1, 2)', 'Oracle telegraphs five-tile'),
    ('charge_threshold', 'scripts/enemy_mechanics/capacitor.gd', 'return 2 if thralls >= 2 else MAX_CHARGE', 'return MAX_CHARGE', 'Dynamo previews Arc Burst'),
    ('prior_hidden', 'scripts/enemy_mechanics/veil.gd', 'if not prior_follower(state, enemy) or engine._enemy_distance_to_tile', 'if true or not prior_follower(state, enemy) or engine._enemy_distance_to_tile', 'Prior preview hides distant follower'),
    ('prior_dark_reveal', 'scripts/enemy_mechanics/veil.gd', 'and rules.broken(state)', 'and false', 'Prior death reveals living followers before break removal, even in Eclipse'),
    ('prior_reveal', 'scripts/warband_combat_rules.gd', 'follower["veiled"] = false', 'follower["veiled"] = true', 'Prior break clears native veil'),
    ('ordinary_golden', 'scripts/enemy_mechanics/bramble.gd', 'var front := hero - Vector2i(signi(delta.x), signi(delta.y))', 'var front := hero', 'Ordinary mechanic golden: earth'),
)

FEEDBACK_MUTATIONS = (
    ('thornwall_board', 'scripts/enemy_mechanics/bramble_view.gd', 'if str(threat.get("projected_attack_action", {}).get("type", "")) != "grow_bramble": return original', 'if true: return original', 'Live board marked-intent preview equals grown Thornwall tiles'),
    ('held_wind_copy', 'scripts/enemy_mechanics/wind_view.gd', '"Wind · held" if held', '"Wind · 2" if held', 'Live Stormcaller chip has approved held title'),
    ('thorn_center_player', 'scripts/enemy_mechanics/bramble.gd', 'player_distance < nearest_player', 'player_distance > nearest_player', 'Thornwall equal-distance center prefers player'),
    ('thorn_center_captain', 'scripts/enemy_mechanics/bramble.gd', 'captain_distance < nearest_captain', 'captain_distance > nearest_captain', 'Thornwall equal-distance center prefers captain'),
    ('diagonal_axis', 'scripts/warband_combat_rules.gd', 'var direction: Vector2i = engine._cardinal_direction(delta)', 'var direction: Vector2i = Vector2i(0, signi(delta.y)) if absi(delta.x) == absi(delta.y) else engine._cardinal_direction(delta)', 'Order axis projects dominant cardinal with x on exact diagonals'),
)
PROBE_MUTATIONS = {'thornwall_board', 'held_wind_copy'}

def run(name, probe=False):
    script = 'tests/warband_orders_probe.gd' if probe else 'tests/warband_orders_test.gd'
    command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'spx-04', '--stream', '--', 'godot', '--headless', '--path', '.', '--script', script]
    if probe:
        command.extend(['--', '--check-only'])
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (LOG_DIR / (name + '.log')).write_text(result.stdout)
    return result

def main():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    mutations = FEEDBACK_MUTATIONS if '--feedback-only' in sys.argv[1:] else MUTATIONS + FEEDBACK_MUTATIONS
    for probe in (False, True):
        control = run('probe_control_before' if probe else 'control_before', probe)
        if control.returncode:
            print(control.stdout)
            raise SystemExit('Mutation control failed')
    killed = 0
    for name, relative, old, new, evidence in mutations:
        path = ROOT / relative
        original = path.read_bytes()
        source = original.decode()
        if source.count(old) != 1:
            raise SystemExit('Mutation anchor must be unique: ' + name)
        try:
            path.write_text(source.replace(old, new, 1))
            result = run(name, name in PROBE_MUTATIONS)
            ok = result.returncode != 0 and evidence in result.stdout and 'SCRIPT ERROR:' not in result.stdout
            print('SPX04 MUTATION %s: %s' % (name, 'KILLED' if ok else 'SURVIVED/INVALID'), flush=True)
            if not ok:
                print(result.stdout)
                raise SystemExit(1)
            killed += 1
        finally:
            path.write_bytes(original)
    for probe in (False, True):
        final = run('probe_control_after' if probe else 'control_after', probe)
        if final.returncode:
            print(final.stdout)
            raise SystemExit('Restored control failed')
    print('SPX04 MUTATION RESULT: PASS (%d/%d killed; controls pass; exact sources restored)' % (killed, len(mutations)))

if __name__ == '__main__':
    main()
