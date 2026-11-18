#!/usr/bin/env python3
"""Generate the feedback-1 handoff from completed local proof artifacts."""
import hashlib
import json
from pathlib import Path
import subprocess

PROJECT=Path(__file__).resolve().parents[2]
ROOT=Path('/private/tmp/labyrinth_codex/area-02/f1')
IDS=('stormcaller','snare_air','gale_herald','gallows_roc','vaeloryx','thornmother','snare_earth','craghide','tharokh')

def read(path): return json.loads(path.read_text())
def result(name,prefix): return next(line for line in reversed((ROOT/f'{name}.log').read_text().splitlines()) if line.startswith(prefix))

def main():
    truth=read(ROOT/'truth/summary.json'); causes=read(ROOT/'round0-causes.json')
    assert not truth['failures'] and truth['categories']['gust_without_snapshot']==0
    lines=['# area-02 feedback 1','',
      '**Implemented and verified headlessly.** The final natural truth audit has zero unexplained mismatches and zero Gusts blowing without a prior Pass snapshot. Changes remain uncommitted on `codex/area-02`; no peer review, publication, task-queue change or windowed run was performed.','',
      '## Director decisions','',
      '1. Gust retains global live occupants and freezes only direction. No tile footprint was added. The audit checks direction only.','2. A new/reaimed unannounced foes-turn Call saves `awaiting_pass` and invalidates any stale receipt. It emits no blow/event, consumes no finite blow, and waits for a hero turn and its Pass. Its existing field/red/direction presentation remains available immediately. Turn-order projection omits the deferred blow until that hero boundary. Already-announced first Calls and same-direction same-source reinstalls keep their receipt.','3. Upheaval builds its candidate set, then runs the existing route primitives as one ordered marking-time batch with cumulative accepted marks. Firing never rechecks routes. Impassable placement sites and occupants that the existing throw cannot move (including Anchored, multi-tile bodies and no landing) skip their tile. The safety solver tries the full raise first, then exact increasing-cardinality omissions to retain a hero neighbour, keeping existing mark order for ties. Every allowed skip has a categorized playback receipt; the audit saves exception reproductions.','',
      'Protected rule data, balance numbers, boss moves, art, sound and VFX timing are unchanged. The three round-0 TODO_DESIGN items have been removed. Existing unrelated prototype TODOs remain untouched. Analytics documentation and heuristic metadata describe the approved timing; no analytics event type was added.','',
      '## Focused proof','', '```text']
    for name,prefix in [('rules-check','ATK14 RULES RESULT:'),('atk03','ATK03 FOCUSED RESULT:'),('atk04','ATK04 FOCUSED RESULT:'),('threats-at-rest','THREATS AT REST TEST RESULT:'),('headless-upheaval','ATK13 CAPTURE '),('headless-gust','ATK13 CAPTURE '),('safety-audit','AREA02 F1 SAFETY AUDIT:')]:
        line=result(name,prefix); assert 'PASS' in line; lines.append(line)
    assert 'OK' in (ROOT/'ui-identity.log').read_text()
    lines += ['UI identity lint: Ran 25 tests; OK','```','',
      'No full suites ran. New permanent tests are confined to battlefield-rule suites. Existing tests that asserted firing-time route rejection now assert the director-approved marking-time guard. New focused cases cover unannounced first Calls/reaims, receipt invalidation, same-source reinstalls, immediate indicators, global live occupants, all three occupied-raise causes, impassability, and a synthetic minimum one-skip safety valve.','',
      '## Truth audit','',
      f'`AREA02 TRUTH: PASS (26 instances; {sum(v["beats"] for v in truth["coverage"].values())} beats; 0 unexplained mismatches; {truth["cantor_new_tiles_excluded"]} Cantor/Bell Tender exclusion witnesses)`','',
      '| Instance | Fights | Beats | Impassable tiles | Occupied-raise tiles | Safety-valve tiles | Gust without snapshot | Unexplained |','|---|---:|---:|---:|---:|---:|---:|---:|']
    for id in read(PROJECT/'data/battlefield_rules.json')['instances']:
        v=truth['coverage'][id]
        lines.append(f'| {id} | {v["fights"]} | {v["beats"]} | {v["impassable"]} | {v["occupied_raise"]} | {v["safety_valve"]} | {v["gust_without_snapshot"]} | {v["mismatches"]} |')
    c=truth['categories'];lines += ['',f'Totals: {c["impassable"]} impassable, {c["occupied_raise"]} occupied-raise, {c["safety_valve"]} safety-valve skips; 0 unexplained. Counts are tiles, not beats. Natural safety skips were zero. A separate synthetic safety audit proves one classified minimum skip with zero unexplained differences and writes an exact reproduction under `/private/tmp/labyrinth_codex/area-02/f1/repro/synthetic_safety-0-0`. Every natural exception has `pass.txt`, `before.txt`, `after.txt` and `exceptions.json` under `{ROOT}/truth/repro/`. The complete receipts and per-instance commands/exits are under `{ROOT}/truth/`.','',
      '## Round 0 cause classification','',
      'The instrumented round-0 engine reproduced all 50 original mismatch records exactly, including instance, seed, clock and complete expected/actual tile sets. **49 were route-safety beat differences; 1 was occupied-raise.** These represented 52 route-blocked tiles and 1 occupied tile. No original assertion or mismatch was discarded.','',
      '| Instance | Route-safety beat differences | Occupied-raise beat differences |','|---|---:|---:|']
    assert causes['matched_original_50']
    for id,v in causes['per_instance'].items():lines.append(f'| {id} | {v.get("route_safety",0)} | {v.get("occupied_raise",0)} |')
    lines += ['',f'Classifications: `{ROOT}/round0-causes.json`; instrumented receipts: `round0-classification/summary.json`; exact saved boards: `round0-repro/`. Instrumentation lives only in the temporary round-0 audit project. The before difficulty project retains the unmodified round-0 runtime.','',
      '## Difficulty: only Gust and Upheaval','',
      'Natural revision-7 tier-3 fights with unchanged committed policy v2 and decks, N=64 per instance before/after. Completed checkpoint prefixes are validated against seed, tier, section, room coordinate and entrance before resuming. Frozen runtime contracts are checked; all sample keys must match. No other rule’s difficulty fights were rerun and no numbers were tuned. A final Snare sealed-threshold correction changed only the Upheaval helper: all four after Upheaval cells restarted from zero; the unchanged Gust checkpoints were retained. The earlier Gust runtime hash is preserved in `after-gust-contract.json`, and the archived earlier helper is under `after-up-before-sealed-fix/`.','',
      '| Instance | Before wins | After wins | Change | Mean turns before → after | Mean HP lost before → after |','|---|---:|---:|---:|---:|---:|']
    for id in IDS:
        b=read(ROOT/f'ladder/before/{id}.json')['results'];a=read(ROOT/f'ladder/after/{id}.json')['results']
        assert len(b)==len(a)==64
        for stage in ('before','after'):assert read(ROOT/f'ladder/{stage}/{id}.cost.json')['exit']==0
        keys=lambda rows:[(v['seed'],v['tier'],v['section_index'],v['coord'],v['travel_dir']) for v in rows]
        assert keys(a)==keys(b)
        wins=lambda rows:sum(v['won'] for v in rows)
        mean=lambda rows,key:sum(v[key] for v in rows)/len(rows)
        wb,wa=wins(b),wins(a)
        lines.append(f'| {id} | {wb}/64 | {wa}/64 | {(wa-wb)/64*100:+.2f} pp | {mean(b,"turns"):.2f} → {mean(a,"turns"):.2f} | {mean(b,"hp_lost"):.2f} → {mean(a,"hp_lost"):.2f} |')
    for stage in ('before','after'):
        contract=read(ROOT/f'{stage}-contract.json');base=ROOT/f'{stage}-project'
        assert all(hashlib.sha256((base/path).read_bytes()).hexdigest()==digest for path,digest in contract.items())
    lines += ['', 'AREA02 F1 DIFFICULTY: PASS (1152 completed fights; 9 matched instances; N=64 before/after). All final cell processes exited 0. Raw reports, commands and costs: `'+str(ROOT/'ladder')+'`.','',
      '## Proof for the design owner','',
      'No native renderer run was attempted. Headless captures validate production playback semantics only and emit JSON sidecars, not PNGs. Run the original Cantor/Wildfire proof, then the new Upheaval/Gust cases:', '', '```sh',f'cd {PROJECT} && sh tools/area02/native_proof.sh',f'cd {PROJECT} && sh tools/area02/native_feedback1.sh upheaval',f'cd {PROJECT} && sh tools/area02/native_feedback1.sh gust','```','',
      'The added native commands can also be run separately:', '', '```sh',f'cd {PROJECT} && LABYRINTH_TASK_ID=area-02 ATK13_CAPTURE_SCRIPT=res://tools/area02/capture.gd ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/area-02/captures ATK13_PROOF_CONTRACT=tools/area02/upheaval_contract.json sh tools/atk13/native_capture.sh {ROOT}/truth/fixtures/craghide area02 upheaval --case upheaval',f'cd {PROJECT} && LABYRINTH_TASK_ID=area-02 ATK13_CAPTURE_SCRIPT=res://tools/area02/capture.gd ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/area-02/captures ATK13_PROOF_CONTRACT=tools/area02/gust_contract.json sh tools/atk13/native_capture.sh {ROOT}/truth/fixtures/gallows_roc area02 gust --case gust','```','',
      'These use the visual-probe runner with cel look, 1920×1080, 100% UI scale and the existing production presentation. Planned added PNGs: `/private/tmp/labyrinth_codex/area-02/captures/upheaval_pass.png`, `upheaval_rise.png`, `gust_pass.png`, `gust_blow.png`, with `upheaval.manifest.json` and `gust.manifest.json`. Headless sidecars are under `'+str(ROOT/'headless-captures')+'`. No inspection-fixture command was requested; the owner retains fixture packaging and visual inspection.','',
      '## Chosen defaults','',
      'The round-0 natural truth controller is unchanged: 3 fights per instance, tier 3, seed scan from 1, proof Health 9999, maximum 24 hero activations, spent Time 24 (Cantor 96), deterministic movement probability 0.75. Difficulty remains N=64 with the existing 24-Health policy-v2 presets. Collection uses 5 workers and validated checkpoints; the existing runner limits remain 14,400 seconds per ladder cell and 1,800 per truth cell. Synthetic safety/occupancy data use the existing fixed-board fixture and named test fields. Native timing/layout values are reused. No production tuning default was selected.','',
      '## Open issues','',
      'Native pixels/independent visual inspection, commit, peer review, inspection-fixture packaging and publication remain the design owner’s steps. There are no unexplained truth mismatches or unresolved round-0 TODO_DESIGN items.','',
      '## Files in the uncommitted unit','']
    tracked=subprocess.check_output(['git','diff','--name-only'],cwd=PROJECT,text=True).splitlines();new=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=PROJECT,text=True).splitlines()
    out=PROJECT/'tools/area02/FEEDBACK_1.md'
    lines += [f'- `{name}`' for name in sorted(set(tracked+new+['tools/area02/FEEDBACK_1.md']))]
    out.write_text('\n'.join(lines)+'\n')
    previous=PROJECT/'tools/area02/REPORT.md'
    note='**Current status:** [Feedback 1](FEEDBACK_1.md) resolves the round-0 design TODOs and supersedes the open-acceptance status below. This file retains the round-0 evidence.\n\n'
    old=previous.read_text()
    if not old.startswith('**Current status:**'): previous.write_text(note+old)
    print('AREA02 F1 DIFFICULTY: PASS (1152 completed fights; 9 matched instances; N=64 before/after)')
    print('AREA02 F1 HANDOFF: '+str(out))
if __name__=='__main__':main()
