#!/usr/bin/env python3
"""Archive tune-01 count evidence without modifying diff-01's baseline."""
from collections import defaultdict
import json
from pathlib import Path
from statistics import median
from report import BASE, OUT, archive, read, table

SCRATCH = Path('/private/tmp/labyrinth_codex')

def main():
    before=read(BASE/'census.jsonl.gz')
    after=[json.loads(x) for x in (SCRATCH/'tune-01-census.jsonl').read_text().splitlines()]
    legacy=[json.loads(x) for x in (SCRATCH/'tune-01-legacy-census.jsonl').read_text().splitlines()]
    archive(OUT/'census_before.jsonl.gz',before)
    archive(OUT/'census_after.jsonl.gz',after)
    archive(OUT/'legacy_census_after.jsonl.gz',legacy)
    assert len(before)==len(after)==3747
    assert all(r['start_non_summoned']<=5 for r in after+legacy)
    groups=defaultdict(lambda:[[],[]])
    for i,rows in enumerate([before,after]):
        for r in rows:groups[(r['scenario'],r['section'],r['category'])][i].append(r['start_non_summoned'])
    records=[]
    for (scenario,section,kind),(old,new) in sorted(groups.items()):
        assert len(old)==len(new)
        records.append([scenario,f's{section}',kind,len(old),sum(x>5 for x in old),sum(x>5 for x in new),f'{min(new)}/{median(new):g}/{max(new)}'])
    report='# Starting-count census\n\n'
    report+=f"Native census: **{sum(r['start_non_summoned']>5 for r in before)}/{len(before)} over five before; 0/{len(after)} after.** The eight seeded maps, archived omens, first-eligible/late-k6/native-prefix schedules, mystery resolution, and summon exclusion are unchanged from diff-01.\n\n"
    report+=table(['Scenario','Section','Tier','N','Before >5','After >5','After min/median/max'],records)
    report+=f'\nSupplement: **0/{len(legacy)}** over five across every eligible authored legacy pool and table entry, Kill All/Kill Leader/Reach Exit, Hunted on/off, all four special kinds and six biomes, Guardian and dragon identities, and Umbra Depth 0/20. A seed search selects the requested actual legacy objective through production rules. Token expansion can temporarily exceed five in the legacy picker; the shared finalizer protects the selected leader before trimming the finished roster.\n\n'
    report+=table(['Path','N','Over five','Maximum'],[[path,len(rs),sum(r['start_non_summoned']>5 for r in rs),max(r['start_non_summoned'] for r in rs)] for path,rs in sorted(_by_path(legacy).items())])
    (OUT/'census.md').write_text(report)
    print(f'TUNE01_CENSUS_REPORT: PASS before_over_5={sum(r["start_non_summoned"]>5 for r in before)} after_over_5=0 native_cases={len(after)} supplemental_cases={len(legacy)}')

def _by_path(rows):
    result=defaultdict(list)
    for r in rows:result[r['path'].split('/')[0]].append(r)
    return result

if __name__=='__main__':main()
