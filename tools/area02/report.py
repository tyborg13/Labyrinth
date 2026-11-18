#!/usr/bin/env python3
"""Build the area-02 implementation handoff from completed, observed proof."""
import argparse
import json
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[2]
PROOF_ROOT = Path('/private/tmp/labyrinth_codex/area-02')
INSTANCES = ('storm_cantor','zekarion','dynamo','snare_lightning','ashen_reaver','rimejaw','gallows_roc','vyraketh','iskaldra','vaeloryx')

def load(path):
    return json.loads(path.read_text())

def result_line(name, prefix):
    return next(line for line in reversed((PROOF_ROOT/f'{name}.log').read_text().splitlines()) if line.startswith(prefix))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=PROJECT/'tools/area02/REPORT.md')
    a=p.parse_args()
    truth=load(PROOF_ROOT/'truth/summary.json')
    lines=['# area-02 implementation handoff','',
      'Changes are uncommitted on `codex/area-02`. No commit, peer review, signoff, publication, task-queue write or windowed run was performed. The design owner retains those phases. Owner data and assets are unchanged.','',
      f'**Open acceptance:** the strict truth audit reports {sum(v["mismatches"] for v in truth["coverage"].values())} differences. The three TODO_DESIGN decisions and native inspection remain open.','',
      '## Numbered requirements','',
      '1. **Implemented, with the design exceptions below:** Pass freezes geometry before activation-end effects; player fuel changes are immediate; occupants/passability remain live. Saved snapshots survive the foes phase and turn-start effects, then release for the next hero turn. Repeated completion does not recapture.','2. **Implemented with open design exceptions:** Storm, Wildfire and Frostbite use frozen tiles; Gust uses its frozen direction; Upheaval retains marks and its existing route/occupied-raise guards; Shadowstep retains live aim. The exact-red audit exposes the guarded-raise and unannounced-new-Call cases below.','3. **Implemented:** the protected owner data is read unchanged: Cantor 4; Zekarion 6/7; all four rule storms Chain 0. Half-Health dials merge, preserving Chain 0. Rows/arcs therefore disappear through the existing shared adapters. Player Chain remains covered by the focused Chain suite. No generic Chain code was deleted because the shared primitive/playback remains used.','4. **Implemented where specified; Gust scope and native pixels pending:** rest red is live all turn, and held geometry survives foes-phase action effects. The board cache gate is updated. Forecasts, hovered boards and lightning playback read the same snapshot. Existing art, timing, sound and input paths are reused. Gust affected-tile scope remains a design TODO.','5. **Implemented:** old hero-turn saves load without a snapshot and acquire one on the next Pass. New foes-turn saves retain exact saved geometry. An old foes-turn save cannot reconstruct previous red, so it uses the live legacy fallback until its next Pass; events use the sentinel `-1`. First announced Calls and reinstalled same-source Gusts retain a Pass receipt.','6. **Implemented:** additive integer `beat_tiles_frozen_at` is recorded in the committed surface event and JSONL adapter. `spec/analytics.md` documents the clock, sentinel, save boundary and compatibility. No historical event is rewritten.','',
      '## Focused checks','', '```text']
    for name,prefix in [('rules-check','ATK14 RULES RESULT:'),('atk03','ATK03 FOCUSED RESULT:'),('atk04','ATK04 FOCUSED RESULT:'),('threats-at-rest','THREATS AT REST TEST RESULT:')]: lines.append(result_line(name,prefix))
    lines += ['UI identity lint: Ran 25 tests; OK','ISOLATION AUDIT: 56 modules','AREA02 CARD SCORES: PASS (309 cards; 0 intrinsic score changes)','```','',
      'The supplied branch initially failed the atk-14 rules check with five stale assertions about the owner\'s new data (two sentences, the half-Health Chain row and two Cantor Damage 3 / Chain 2 assertions). Local master still had the old data. These rule assertions now verify the supplied owner data; unrelated assertions were preserved. One intermediate raw-Upheaval forecast change failed the existing BOS01 ring guard assertion; that change was reverted. No full suite was run.','',
      '## Truth audit','',
      'Natural revision-7 fights, first three samples per instance at tier 3, movement/PASS only, unchanged enemy/rule definitions. Proof Health is elevated and named below. Cantor uses a longer proof activation to include Tender placement before a later Peal in the same phase. Lightning/Ice/Fire compare complete Pass geometry with the primitive arguments at fire, with live impassability; visible red remains filtered by the existing sight policy. Gust compares the accepted direction and actual landing deltas, excluding speculative intent-preview movement. Upheaval compares marks against actual raises and therefore reports blocked-raise differences. Shadowstep is the explicit live-aim exception.','',
      f'**Strict acceptance is not met:** {sum(v["mismatches"] for v in truth["coverage"].values())} mismatches across {sum(v["beats"] for v in truth["coverage"].values())} beats. There are {truth["cantor_new_tiles_excluded"]} Bell Tender post-Pass exclusion witnesses and zero Cantor mismatches.','',
      '| Instance | Fights | Passes | Beats | Nonempty tiles / non-tile beats | Mismatches | Seeds |','|---|---:|---:|---:|---:|---:|---|']
    for id in load(PROJECT/'data/battlefield_rules.json')['instances']:
        v=truth['coverage'][id]
        lines.append(f'| {id} | {v["fights"]} | {v["passes"]} | {v["beats"]} | {v["nonempty_beats"]} | {v["mismatches"]} | '+', '.join(map(str,v['seeds']))+' |')
    lines += ['',f'Raw counts and every mismatch: `{PROOF_ROOT}/truth/summary.json`. Per-instance commands, exits, duration and logs are beside it.','',
      '## Difficulty: matched N=64 before and after','',
      'Both snapshots include the protected owner data commit (Cantor 4, Zekarion 6/7, Chain 0), isolating the runtime snapshot change. These are natural tier-3 rooms, unchanged committed policy v2, default 24 Health, revision 7, the same decks/search limits, and exact seed/coordinate/entrance matching. Means include losses and capped runs. No tuning was performed.','',
      '| Instance | N each | Before wins | After wins | Change | Mean turns before → after | Mean HP lost before → after |','|---|---:|---:|---:|---:|---:|---:|']
    totals=0
    for id in INSTANCES:
        b=load(PROOF_ROOT/f'ladder/before/{id}.json')['results'];c=load(PROOF_ROOT/f'ladder/after/{id}.json')['results']
        assert load(PROOF_ROOT/f'ladder/before/{id}.cost.json')['exit']==0,id
        assert load(PROOF_ROOT/f'ladder/after/{id}.cost.json')['exit']==0,id
        assert len(b)==len(c)==64
        keys=lambda rows:[(r['seed'],r['tier'],r['coord'],r['travel_dir'],r['section_index']) for r in rows]
        assert keys(b)==keys(c),id
        wins=lambda rows:sum(r['won'] for r in rows)
        mean=lambda rows,key:sum(r[key] for r in rows)/len(rows)
        wb,wc=wins(b),wins(c);totals+=len(b)+len(c)
        lines.append(f'| {id} | 64 | {wb}/64 ({wb/64:.1%}) | {wc}/64 ({wc/64:.1%}) | {(wc-wb)/64*100:+.2f} pp | {mean(b,"turns"):.2f} → {mean(c,"turns"):.2f} | {mean(b,"hp_lost"):.2f} → {mean(c,"hp_lost"):.2f} |')
    lines += ['',f'AREA02 DIFFICULTY: PASS ({totals} completed fights; 10 matched instances; N=64 each before/after). Frozen code copies and SHA-256 contracts: `{PROOF_ROOT}/before-project`, `after-project`, `before-contract.json`, `after-contract.json`. Raw reports, commands and costs: `{PROOF_ROOT}/ladder/`.','',
      'The after ladder copy predates only the final first-Call/reinstalled-Gust receipt cache and its cleanup, plus TODO constants and provenance comments. The ten measured fight types do not use Call the Wind; these additions do not change their resolutions. Final focused tests and truth audit use the current worktree. The opt-in provenance scan checks all 640 natural rosters and their declared summons for Call the Wind; the compatibility conclusion is a control-flow inference, not a second final-code ladder.','',
      '## Proof for the design owner','',
      'Headless capture semantics passed for Cantor and Wildfire; they emitted JSON sidecars, not PNGs. Native capture paths below are planned, not observed. The native wrapper uses the visual-probe runner, cel look, Metal/mobile, 1920×1080 and 100% UI scale, with one attempt and per-case proof contracts.','',
      '```sh',f'cd {PROJECT} && sh tools/area02/native_proof.sh','```','',
      f'Expected native images: `{PROOF_ROOT}/captures/cantor_pass.png`, `cantor_tender.png`, `cantor_strike.png`, `wildfire_pass.png`, `wildfire_spread.png`; manifests `cantor.manifest.json` and `wildfire.manifest.json`. Cantor captures the later Peal after the Tender checkpoint in the long natural phase.','',
      'The brief does not request an inspection-fixture command. These capture scripts load audited `run_state.txt` witnesses under an isolated runner HOME; the design owner owns any playable inspection-fixture packaging.','',
      'Reproduce headless proof:', '', '```sh',f'cd {PROJECT} && python3 tools/atk13/rule_audit.py',f'cd {PROJECT} && python3 tools/atk13/rule_ladder.py --label before --project {PROOF_ROOT}/before-project',f'cd {PROJECT} && python3 tools/atk13/rule_ladder.py --label after --project {PROOF_ROOT}/after-project','```','',
      '## TODO_DESIGN and open issues','',
      '- `TODO_DESIGN_GUST_FROZEN_SCOPE`: direction is frozen; global Push scope is preserved. The brief also speaks of frozen-tile occupants, which could imply a different Gust scope. No new red footprint or targeting scope was invented.','- `TODO_DESIGN_GUST_NEW_CALL`: an unannounced Call selected after Pass can install a new rule without a previous announcement. Existing live fallback is preserved in this case; the strict audit fails it. Announced first Calls and reinstallation of a held source are handled.','- `TODO_DESIGN_UPHEAVAL_BLOCKED_MARKS`: existing route-safety and occupied-raise guards can block a frozen mark on otherwise passable floor. The strict audit counts these as mismatches. The owner must decide whether these guards fall under the impassable exception or whether rule behavior should change.','- Real-renderer proof and independent visual inspection remain with the design owner. No publication readiness or peer signoff is claimed.','',
      '## Chosen defaults','',
      '- Truth proof: 3 natural fights per instance, tier 3, seed scan starts at 1, 24 hero activations maximum, proof Health 9999, spent Time 24 (Cantor 96), deterministic movement probability 0.75. These are proof-only settings, not production tuning.','- Difficulty: N=64 and tier-3 policy-v2 ladder, existing 24 Health and deck presets; 3 Python workers; runner timeout 14,400 seconds for 64 full searches. Truth cells use 1,800 seconds; the 640-roster provenance scan uses 600 seconds; default native capture limit remains 300 seconds.','- Capture: native frame ceiling 14,400; headless-only time scale 16 and frame ceiling 1,800. Existing atk-13 boot/layout constants are reused. All native settings remain at production timing.','- Rule fixtures: damage 2 or 5, save path `user://area02-snapshot.save`, tiles `(5,5)`, `(6,5)`, conductor `(3,5)/(4,5)`, proof clock 17; all are named debug fixtures. The analytics no-snapshot sentinel is `-1`.','',
      '## Files changed','']
    tracked=subprocess.check_output(['git','diff','--name-only'],cwd=PROJECT,text=True).splitlines()
    untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=PROJECT,text=True).splitlines()
    for name in sorted(set(tracked+untracked+[str(a.output.relative_to(PROJECT))])): lines.append(f'- `{name}`')
    a.output.write_text('\n'.join(lines)+'\n')
    print(f'AREA02 HANDOFF REPORT: {a.output}')
    print(f'AREA02 DIFFICULTY: PASS ({totals} completed fights; 10 matched instances; N=64 each before/after)')
if __name__=='__main__': main()
