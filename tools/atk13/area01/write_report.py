#!/usr/bin/env python3
"""Feedback-1 empirical handoff; incomplete ladders are never reported as passed."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[3]
DEST = Path(__file__).resolve().parent
OUT = Path('/private/tmp/labyrinth_codex/area-01/feedback1')
BOSSES = ('tharokh','vyraketh','vaeloryx','iskaldra','zekarion','noctyrax','ashen_reaver','rimejaw','storm_cantor','gallows_roc','craghide','last_lamplighter')
PREFIXES = ('AREA01 RULES RESULT:', 'AREA01 EXISTING SUITES RESULT:', 'GUARDIAN RULES TEST RESULT:', 'THREATS AT REST TEST RESULT:', 'ATK03 FOCUSED RESULT:', 'ATK04 FOCUSED RESULT:', 'DRAGON WALLET ACK TEST:', 'DRAGON TROPHY FEEDBACK:', 'Dragon committed patterns passed.', 'Dragon feedback mechanics passed.', 'Dragon rewards, gifts, wallet recovery and relic hooks passed.', 'Dragon reward feedback logic:')
EXCLUDED_RESULT_FIELDS = ('won','turns','turn_cap_reached','search_capped')
def read(path): return json.loads(path.read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def cohort(path):
    if not path.exists(): return []
    records = []
    for line in path.read_text().splitlines():
        try: records.append(json.loads(line))
        except json.JSONDecodeError: break
    return records

def main():
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument('--allow-partial', action='store_true')
    args=parser.parse_args()
    reports=[read(OUT/name/'report.json') for name in ('cursor-truth','cursor-helpers')]
    moves=defaultdict(Counter); seeds=defaultdict(set); stamps=defaultdict(Counter)
    totals=Counter()
    for report in reports:
        totals.update(report['totals'])
        for key,values in report['moves'].items():
            seeds[key].update(values['seeds'])
            moves[key].update({k:v for k,v in values.items() if k!='seeds'})
        for key,values in report['stamp_checks'].items(): stamps[key].update(values)
    expected=set(read(DEST/'round0_results.json')['truth']['moves'])
    assert set(moves)==expected and len(moves)==27
    assert all(len(seeds[k])>=2 for k in moves)
    error_fields=('tile_mismatches','red_omissions','stamp_shape_mismatches','rest_strike_mismatches')
    assert not any(v[k] for v in moves.values() for k in error_fields)
    assert not any(v[k] for v in stamps.values() for k in ('forecast_mismatches','strike_mismatches','oracle_mismatches'))
    assert not any(v['undisclosed_end_to_end_forecast_mismatches'] for v in stamps.values())
    assert not totals['oracle_mismatches'] and not totals['ui_replica_mismatches'] and not totals['grub_marked_hit_mismatches']
    kinds=defaultdict(Counter)
    for key,values in moves.items():
        kind='relative' if values['relative_to_source'] else 'fixed'
        kinds[kind]['moves']+=1; kinds[kind].update(values)
        kinds[kind].update(stamps[key])
    assert kinds['relative']['moves']==19 and kinds['fixed']['moves']==8
    disclosures=read(OUT/'cursor-force-disclosure.json')
    source_disagreements=sum(v['source_prediction_disagreements'] for v in stamps.values())
    assert len(disclosures)==len(read(OUT/'cursor-force-cases.json')) and all(r['disclosed'] for r in disclosures)
    end_to_end=sum(v['end_to_end_forecast_mismatches'] for v in stamps.values())
    followups=reports[0]['followup_action_forecast_matrices_11_10_01_00']
    assert len(followups)==5 and all(v[1]==0 and v[2]==0 for v in followups.values())
    checks=read(OUT/'cursor-checks/results.json')
    assert len(checks)==12 and all(row['exit']==0 for row in checks)
    check_lines=[]
    for row in checks:
        lines=[line for line in Path(row['log']).read_text().splitlines() if line.startswith(PREFIXES)]
        assert lines and 'FAIL' not in lines[-1], row['log']
        check_lines.append({'script':row['script'],'result':lines[-1],'log':row['log']})
    captures=[]
    for name in ('tharokh-bedrock_breath','zekarion-skybreak'):
        result=read(OUT/'cursor-capture-components'/f'{name}.json')
        assert not result['failures'] and result['headless_semantics_only']
        captures.append(result)
    legacy_resume=read(OUT/'cursor-legacy-resume-10/tharokh-bedrock_breath.json')
    assert not legacy_resume['failures'] and legacy_resume['origin_basis']==['stored_announcement']
    assert 'OK' in (OUT/'cursor-ui-lint.log').read_text()
    assert 'EN01 ENEMIES TEST RESULT: PASS' in (OUT/'en01-test-final.log').read_text()
    assert 'MRK01 MARKED TEST: PASS' in (OUT/'marked-test.log').read_text()
    assert 'Ran 6 tests' in (OUT/'python-dragon-measurement.log').read_text() and 'OK' in (OUT/'python-dragon-measurement.log').read_text()
    guardian_python=(OUT/'python-guardian-measurement.log').read_text()
    assert 'Ran 11 tests' in guardian_python and 'FAILED (failures=1)' in guardian_python and 'test_production_contains_only_the_chosen_cumulative_rungs' in guardian_python
    difficulty=[]; complete=True
    for boss in BOSSES:
        paths=[OUT/'release/before'/f'{boss}.jsonl',OUT/'round0/before'/f'{boss}.jsonl',OUT/'round0/after'/f'{boss}.jsonl']
        records=[cohort(path) for path in paths]
        finished=all(len(rows)==64 for rows in records)
        complete=complete and finished
        if finished:
            metadata=[[{k:v for k,v in row.items() if k not in EXCLUDED_RESULT_FIELDS} for row in rows] for rows in records]
            assert metadata[0]==metadata[1]==metadata[2],boss
            wins=[sum(row['won'] for row in rows) for rows in records]
            difficulty.append({'boss':boss,'N':64,'release_wins':wins[0],'round0_wins':wins[1],'current_wins':wins[2],'delta_release_pp':(wins[2]-wins[0])*100/64,'delta_round0_pp':(wins[2]-wins[1])*100/64})
        else:
            assert args.allow_partial, f'Incomplete ladder {boss}: {[len(rows) for rows in records]}'
            difficulty.append({'boss':boss,'pending_counts':[len(rows) for rows in records]})
    phase_results=[]
    for name,phase in (('release-measure.log','before'),('round0-measure.log','before'),('current-measure.log','after')):
        result_line=f'AREA01 DIFFICULTY PASS phase={phase} bosses=12 N=64'
        if complete: assert result_line in (OUT/name).read_text(),name
        if result_line in (OUT/name).read_text(): phase_results.append({'log':str(OUT/name),'result':result_line})
    assert not subprocess.check_output(['git','diff','--name-only','--','data','assets','scripts/battlefield_rules'],cwd=ROOT,text=True).strip()
    files=subprocess.check_output(['git','diff','--name-only'],cwd=ROOT,text=True).splitlines()
    files+=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()
    files=sorted({p for p in files if p not in ['tools/atk13/area01/results.json','tools/atk13/area01/results.md'] and (ROOT/p).is_file()})
    input_hashes=[{p.name:sha(p) for p in sorted((OUT/name/'inputs').glob('*.bin'))} for name in ('release','round0')]
    assert input_hashes[0] and input_hashes[0]==input_hashes[1]
    result={'release_head':read(DEST/'round0_results.json')['base_head'],'base_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'uncommitted':True,'ladder_complete':complete,
            'strict_all_alternatives_area_forecast_equality':end_to_end==0,
            'moves':{k:{**dict(v),'seeds':sorted(seeds[k])} for k,v in sorted(moves.items())},'kinds':{k:dict(v) for k,v in kinds.items()},'stamp_checks':{k:dict(v) for k,v in stamps.items()},'totals':dict(totals),'force_disclosure':disclosures,'followup_matrices_11_10_01_00':followups,'difficulty':difficulty,'difficulty_phase_results':phase_results,'checks':check_lines,
            'native_proof':'Owner-run; headless semantics only','source_sha256':{p:sha(ROOT/p) for p in files},
            'protected_data_sha256':{str(p.relative_to(ROOT)):sha(p) for p in sorted((ROOT/'data').glob('*.json'))},'policy_sha256':sha(ROOT/'tools/encounter_bot.gd'),'matched_constructor_inputs_sha256':input_hashes[0]}
    (DEST/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    lines=['# area-01 feedback 1: observed results','',f"Round-0 base `{result['base_head']}` plus uncommitted feedback-1 changes. Release baseline `{result['release_head']}`. No commit, peer review, windowed run or publication.",'',
        'Requirements 1–4 are implemented as described in [README.md](README.md). Strict all-alternatives source prediction equality retains the disclosed unseen-ground limit below. Native inspection remains with the owner.', '',
        '**Ladder:** '+('all three N=64 cohorts complete for all twelve bosses.' if complete else 'INCOMPLETE; pending counts below are not win-rate results.'),'',
        '## Truth audit','',f"27 moves, two seeds each; {sum(v['walked_executions'] for v in moves.values())} continued-walk area executions; {totals['alternatives']} PASS/movement alternatives. All strike-tile, independent stamp-shape, at-rest strike and red-omission mismatches are zero.",'',
        '| Kind | Moves | Walked | Alternative strikes | At-rest/no-shift checks | Natural shifts | Push/pull attempts | Effective displacements | Force strike checks | Geometry errors | End-to-end forecast differences (undisclosed) |','|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|']
    for kind in ('relative','fixed'):
        v=kinds[kind];lines.append(f"| {kind} | {v['moves']} | {v['walked_executions']} | {v['executed_alternatives']} | {v['no_displacement_checks']} | {v['natural_displacement_checks']} | {v['updraft_checks']+v['yank_checks']} | {v['displaced_checks']} | {v['strike_checks']} | 0 | {v['end_to_end_forecast_mismatches']} (0) |")
    lines+=['','| Move | Kind | Walked | Alternative strikes | Announced at turn start | No shift / natural shifts | Updraft / Yank | Effective displacements | Force strike checks | Geometry errors | Forecast differences (undisclosed) | Seeds |','|---|---|---:|---:|---:|---|---|---:|---:|---:|---|---|']
    for key,v in sorted(moves.items()):
        s=stamps[key];kind='relative' if v['relative_to_source'] else 'fixed'
        lines.append(f"| {key} | {kind} | {v['walked_executions']} | {v['executed_alternatives']} | {v['announced_at_turn_start']} | {v['no_displacement_checks']} / {v['natural_displacement_checks']} | {s['updraft_checks']} / {s['yank_checks']} | {s['displaced_checks']} | {s['strike_checks']} | 0 | {s['end_to_end_forecast_mismatches']} (0) | {', '.join(sorted(seeds[key]))} |")
    lines+=['',f"Fixed Grub landing: {totals['grub_marked_landings']} alternative executions, {totals['walked_grub_marked_landings']} continued-walk executions, zero off-mark direct-hit receipts. Controlled rules also prove blocked-mark damage and preserved adjacent pushes.",'',
        'Counts refer to executed actions, not every warning being guaranteed to fire. Alternatives are counterfactuals from natural fights, not independent played encounters. Roc is Anchored; zero effective pushes preserve that rule. Its synthetic source-position rules fixtures are not reported as natural push successes.', '',
        '## Forecast','',f"{sum(v['updraft_checks']+v['yank_checks'] for v in stamps.values())} legal push/pull action branches: zero stamp-versus-predicted-source mismatches and zero strike-versus-actual-source mismatches. The existing cursor supplies the first announced relative cast's resolved anchor, covering known future route interruptions without a second forecast. {end_to_end} end-to-end warning-versus-strike differences remain, all with existing uncertainty disclosed. {source_disagreements} raw-action immediate source-position predictions disagree. The {len(disclosures)} flagged cases were replayed through real card aiming: all disclose uncertainty ({sum(r['flags']['unseen_ground_crossed'] for r in disclosures)} disclose unseen ground). No undisclosed end-to-end disagreement was observed. Strict equality across every alternative is therefore not established. See README for the saved reproduction and `feedback1/cursor-force-disclosure.json` for all cases.",'',
        'Follow-up cells: told+hit / told+no-hit / not-told+hit / not-told+no-hit. All five separate action rows agree in this round, including disclosed alternatives.','', '| Follow-up | Matrix |','|---|---|']
    for key,values in followups.items():lines.append(f"| {key} | {' / '.join(map(str,values))} |")
    lines+=['','## Difficulty','', 'Same original policy v2, matched constructor/loadout/RNG cells, N=64 per boss per cohort. Conditional entry win rates, with the existing full-Health reset; not 64 distinct loadouts or a whole-run escape rate. Release means the pre-area local-master snapshot identified above. No authored number changed.','',
        '| Boss | Release wins / 64 | Round 0 wins / 64 | Feedback 1 wins / 64 | Change vs release (pp) | Change vs round 0 (pp) |','|---|---:|---:|---:|---:|---:|']
    for row in difficulty:
        if 'pending_counts' in row:lines.append(f"| {row['boss']} | pending {row['pending_counts'][0]}/64 | pending {row['pending_counts'][1]}/64 | pending {row['pending_counts'][2]}/64 | — | — |")
        else:lines.append(f"| {row['boss']} | {row['release_wins']} | {row['round0_wins']} | {row['current_wins']} | {row['delta_release_pp']:+.4f} | {row['delta_round0_pp']:+.4f} |")
    lines+=['','Raw cohorts and exact launch commands: `/private/tmp/labyrinth_codex/area-01/feedback1/{release,round0}/`. The snapshots were taken before implementation; subsequent UI cursor receipts and legacy-save restoration do not alter the policy or fresh-fight constructor targeting. Original natural ladder inputs and Cantor recovery limitations are documented in README.','', '## Checks actually run','']
    for row in phase_results:lines.append(f"- `{row['result']}` — `{row['log']}`.")
    for row in check_lines:lines.append(f"- `{row['result']}` — `{row['log']}`.")
    lines+=['','- `MRK01 MARKED TEST: PASS (69 checks, 0 failures)` — `feedback1/marked-test.log`.', '- `EN01 ENEMIES TEST RESULT: PASS` — `feedback1/en01-test-final.log`; its headless draw branch emits an existing Dummy-renderer texture error, not native capture proof.', '- UI lint: `Ran 25 tests` / `OK` — `feedback1/cursor-ui-lint.log`.', f'- `AREA01 FORCE DISCLOSURE PASS cases={len(disclosures)}` — `feedback1/cursor-force-disclosure.log` (Dummy-renderer cleanup errors are retained in this diagnostic log).', '- `AREA01 CAPTURE COMPONENTS PASS (2 cases; headless semantics only)` — `feedback1/cursor-capture-components.log`.', '- Resource audit only: `ISOLATION AUDIT: 56 modules`; `feedback1/python-audit/isolation-audit.md`. No new Python test module; no full Python/GDScript suite run.', '- Focused Python Dragon measurement: `Ran 6 tests` / `OK` — `feedback1/python-dragon-measurement.log`.', '- Focused Python Guardian measurement: `Ran 11 tests` / `FAILED (failures=1)` — `feedback1/python-guardian-measurement.log`. This is the unchanged round-0 baseline fixture failure at line 186 (expected art_scale 1.15 versus unchanged master 1.03); assertion and data remain untouched.','',
        'Actual round-0 save resume: `AREA01 CAPTURE PASS semantic=true`, `origin_basis: stored_announcement` — `feedback1/cursor-legacy-resume-10.log`. An earlier selected save loaded successfully but had no legal Updraft target; that component attempt failed before push playback.','',
        'All relative-save origin cases, round-0 migration, nullable checkpoints, fixed fuel, Erupt, Marked keyword/tile detail and Windows-safe typed arrays are covered by focused rules checks.','',
        '## Owner proof and remaining limits','', 'Exact native cel commands, three-frame capture paths, the existing Marked treatment and Meteorfall deduplication are in [README.md](README.md#proof-for-the-design-owner). No native pixels or independent visual judgement is claimed. No TODO_DESIGN placeholder was needed. Chosen test/proof defaults are listed in README. Native inspection, full-suite merge checks, commit and peer review remain with the design owner.','']
    (DEST/'results.md').write_text('\n'.join(lines))
    print(f"AREA01 FEEDBACK1 REPORT {'PASS' if complete else 'INCOMPLETE'} moves=27 relative=19 fixed=8 focused_checks=12 complete_bosses={sum('N' in r for r in difficulty)}/12")
if __name__=='__main__':main()
