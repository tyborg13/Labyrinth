#!/usr/bin/env python3
"""Classify enc-04/int-06 snapshot differences without changing the oracle."""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
from pathlib import Path


def differences(before, after, path=""):
    if isinstance(before, dict) and isinstance(after, dict):
        for key in sorted(before.keys() | after.keys()):
            field = f"{path}/{key}"
            if key not in before or key not in after:
                yield {"field": field, "before": before.get(key), "after": after.get(key)}
            else:
                yield from differences(before[key], after[key], field)
    elif isinstance(before, list) and isinstance(after, list) and len(before)==len(after):
        for index, (old, new) in enumerate(zip(before, after)):
            yield from differences(old, new, f"{path}/{index}")
    elif before != after:
        yield {"field": path, "before": before, "after": after}


def audit(snapshots: dict) -> dict:
    if not snapshots["int06_prior_matches_frozen"]:
        raise ValueError("enc-04/int-06 failed to reconstruct the frozen hashes")
    changed = []
    room_count = guardian_count = pending_count = 0
    for seed, current in snapshots["after"]["snapshots"].items():
        # Exact reconstruction proven against every frozen hash by int-06:
        # pre-enc-03 Slag for seed 421, and no sum-01 zero pending counter.
        prior = snapshots["before" if seed=="421" else "after"]["snapshots"][seed]
        if prior["map"] != current["map"] or prior["rooms"] != current["rooms"]:
            raise ValueError(f"Unexplained map/layout difference: seed {seed}")
        old_states = copy.deepcopy(prior["combat"])
        for state in old_states:
            if state.pop("pending_summon_card_plays",None)!=0:
                raise ValueError("Expected the exact zero counter audited by int-06")
        for index, room in enumerate(current["rooms"]):
            room_count += 1
            guardian_count += room["type"]=="guardian"
            fields = []
            for offset in (0,1):
                old, new = old_states[2*index+offset], current["combat"][2*index+offset]
                for change in differences(old,new):
                    field = change["field"]
                    if field=="/pending_summon_card_plays" and change["before"] is None and change["after"]==0:
                        reason = "sum-01: additive zero pending Card Play counter"
                        pending_count += 1
                    elif field.startswith("/enemies/"):
                        actor = new["enemies"][int(field.split("/")[2])]
                        if actor["type"]!="slag_mortar" or not (
                            (field.endswith("/min_range") and (change["before"],change["after"])==(3,2)) or
                            (field.endswith("/intent/weight") and (change["before"],change["after"])==(3,4))):
                            raise ValueError(f"Unexplained actor field: {seed} {index} {change}")
                        reason = "enc-03/enc-04: approved Slag Mortar Lob min_range/weight"
                    else:
                        raise ValueError(f"Unexplained field: {seed} {index} {change}")
                    fields.append({"snapshot":offset,"explanation":reason,**change})
            if fields:
                changed.append({"seed":int(seed),"room_index":index,"type":room["type"],
                                "coord":room["coord"],"roster":[e["type"] for e in room["enemies"]],"changes":fields})
    return {"int06_prior_matches_frozen":True,"rooms":room_count,"guardian_rooms":guardian_count,
            "zero_counter_fields":pending_count,"changed_rooms":changed,"guardian_only":bool(changed) and all(r["type"]=="guardian" for r in changed),
            "repinned":False,"decision":"No Guardian-only renewal is authorized by this evidence. Preserve the fixture; int-06 owns these integration differences."}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshots",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    report=audit(json.loads(args.snapshots.read_text()))
    fixture=Path(__file__).resolve().parents[1]/"tests/fixtures/encounter_measurement_golden.json"
    report["frozen_fixture_sha256"]=hashlib.sha256(fixture.read_bytes()).hexdigest()
    report["source_snapshots_sha256"]=hashlib.sha256(args.snapshots.read_bytes()).hexdigest()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+"\n")
    print(f'BOS03 GOLDEN AUDIT: PASS ({report["rooms"]} rooms; {report["guardian_rooms"]} Guardian rooms; all differing fields classified; repinned=false)')


if __name__=="__main__": main()
