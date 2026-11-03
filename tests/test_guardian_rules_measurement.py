"""Guardian ablation report keeps matched samples, real counters and band flags."""
import contextlib
import copy
import gzip
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
import guardian_rules_measurement as measurement
import guardian_tuning as tuning
import guardian_golden_audit as golden_audit

LADDER_TEST_COUNT = 100
LADDER_TEST_RECORD = {"turns": 1, "hp_lost": 0, "objective": "kill_leader",
                      "biome": "ice", "turn_cap_reached": False}
TIER_TEST_ORDER = (2, 1, 3)
# Historical audit target, retained when int-06 later renews the live fixture.
ROUND1_GOLDEN_SHA256 = "f3ffaf1b742b4e487a57fcee63703a394bdf8fb3aa8f5efd1cbf256547c8f76b"


class GuardianRulesMeasurementTests(unittest.TestCase):
    def write_groups(self, output):
        for guardian in measurement.GUARDIANS:
            for variant in measurement.VARIANTS:
                records = [{"seed":1,"tier":tier,"section_index":0,"coord":{"x":tier,"y":0},
                            "travel_dir":{"x":0,"y":1},"won":tier!=3,"turns":tier+1,"hp_lost":tier*2,
                            "objective":"kill_leader","turn_cap_reached":False,"biome":"fire",
                            "metrics":{key:tier for key in measurement.METRICS}} for tier in (1,2,3)]
                with gzip.open(output/f"{guardian}-{variant}.json.gz","wt") as stream:
                    json.dump({"results":records},stream)

    def test_report_totals_distributions_and_band_flags(self):
        with tempfile.TemporaryDirectory() as tmp:
            output=Path(tmp)
            self.write_groups(output)
            with contextlib.redirect_stdout(io.StringIO()): measurement.report(output)
            result=json.loads((output/"summary.json").read_text())
            self.assertEqual(len(result["groups"]),18)
            for row in result["groups"]:
                self.assertEqual(row["n"],3)
                self.assertEqual(row["tiers"],{"1":1,"2":1,"3":1})
                self.assertTrue(row["outside_band"])
                self.assertEqual(row["turns"]["median"],3)
                self.assertEqual(row["metrics"]["summons"],{"total":6,"n":3,"median":2,"p10":1,"p90":3})
            self.assertIn("OUTSIDE",(output/"report.md").read_text())

    def test_report_rejects_unmatched_room_samples(self):
        with tempfile.TemporaryDirectory() as tmp:
            output=Path(tmp)
            self.write_groups(output)
            path=output/"ashen_reaver-after.json.gz"
            raw=measurement.read_report(path)
            raw["results"][0]["coord"]["x"]+=1
            with gzip.open(path,"wt") as stream: json.dump(raw,stream)
            with self.assertRaisesRegex(AssertionError,"Unmatched ablation"):
                measurement.report(output)

    def test_before_snapshot_is_complete_and_exactly_scoped(self):
        raw=json.loads((ROOT/"tests/fixtures/bos_03_before_enemies.json").read_text())
        self.assertEqual(len(raw),14)
        self.assertTrue(set(measurement.GUARDIANS)<=raw.keys())
        self.assertEqual(raw["storm_cantor"]["base_initiative"],20)
        self.assertEqual(raw["gallows_roc"]["base_initiative"],20)
        self.assertEqual(raw["lightning_wisp"]["encounter_base_initiative"],{"guardian":19})

    def test_ladder_stops_at_first_inclusive_band_or_keeps_last(self):
        def row(rung, wins):
            records = [{**LADDER_TEST_RECORD, "won": index < wins,
                        "metrics": dict.fromkeys(measurement.METRICS, 0)}
                       for index in range(LADDER_TEST_COUNT)]
            return tuning.summarize_rung("rimejaw", rung, "test fixture", records)
        for wins in (35, 65):
            rows = [row(1, 34), row(2, wins), row(3, 50)]
            self.assertEqual(tuning.first_accepted(rows), 2)
        self.assertEqual(tuning.first_accepted([row(1, 66), row(2, 34)]), 2)
        with self.assertRaisesRegex(ValueError, "at least one"):
            tuning.first_accepted([])

    def test_tier_merge_matches_samples_defaults_and_original_order(self):
        records = [{"seed": tier, "tier": tier, "section_index": tier - 1,
                    "coord": {"x": tier, "y": 1}, "travel_dir": {"x": 0, "y": 1}}
                   for tier in TIER_TEST_ORDER]
        reference = {"defaults": {"policy_version": 2}, "decks": {"1": ["fixture"]}, "results": records}
        reports = [{**reference, "results": [record]} for record in reversed(records)]
        self.assertEqual(tuning.merge_tiers(reports, reference)["results"], records)
        for invalid in (reports[:-1], reports + reports[:1]):
            with self.assertRaisesRegex(ValueError, "matched samples"):
                tuning.merge_tiers(invalid, reference)
        for key in ("defaults", "decks"):
            invalid = [{**reports[0], key: {}}, *reports[1:]]
            with self.assertRaisesRegex(ValueError, "unchanged policy"):
                tuning.merge_tiers(invalid, reference)

    def test_tuned_report_records_chosen_rungs_without_relabelling_baselines(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            self.write_groups(output)
            chosen = {"rimejaw": 2, "storm_cantor": 4, "last_lamplighter": 5}
            with contextlib.redirect_stdout(io.StringIO()):
                measurement.report(output, tuning=chosen)
            self.assertEqual(json.loads((output/"summary.json").read_text())["chosen_rungs"], chosen)
            report = (output/"report.md").read_text()
            self.assertIn("retained from accepted round 0", report)
            self.assertNotIn("No tuning was performed", report)

    def test_checked_in_ladders_are_matched_ordered_and_recompute(self):
        plan = json.loads(tuning.PLAN.read_text())
        evidence = json.loads((tuning.OUTPUT/"ladders.json").read_text())
        self.assertEqual(evidence["plan_sha256"], hashlib.sha256(tuning.PLAN.read_bytes()).hexdigest())
        self.assertEqual(set(evidence["ladders"]), set(plan))
        for guardian, ladder in evidence["ladders"].items():
            reference = measurement.read_report(tuning.BASELINE/f"{guardian}-after.json.gz")
            measured = ladder["rows"][1:]
            self.assertEqual([row["rung"] for row in measured], list(range(1, len(measured)+1)))
            self.assertFalse(any(row["inside_band"] for row in measured[:-1]))
            self.assertEqual(ladder["chosen_rung"], tuning.first_accepted(measured))
            self.assertTrue(ladder["inside_band"] or len(measured)==len(plan[guardian]))
            for row in measured:
                raw = measurement.read_report(tuning.OUTPUT/f'{guardian}-r{row["rung"]}.json.gz')
                self.assertEqual(len(raw["results"]), 90)
                self.assertEqual([sum(r["tier"]==tier for r in raw["results"]) for tier in (1,2,3)], [30]*3)
                self.assertEqual(tuning.merge_tiers([raw], reference)["results"], raw["results"])
                self.assertEqual(tuning.summarize_rung(guardian,row["rung"],row["label"],raw["results"]), row)
            chosen = tuning.OUTPUT/f'{guardian}-r{ladder["chosen_rung"]}.json.gz'
            self.assertEqual(chosen.read_bytes(), (tuning.OUTPUT/f"{guardian}-after.json.gz").read_bytes())
        for guardian in measurement.GUARDIANS:
            for variant in measurement.VARIANTS:
                if variant!="after" or guardian not in plan:
                    name = f"{guardian}-{variant}.json.gz"
                    self.assertEqual((tuning.OUTPUT/name).read_bytes(), (tuning.BASELINE/name).read_bytes())

    def test_production_contains_only_the_chosen_cumulative_rungs(self):
        baseline = json.loads((ROOT/"tests/fixtures/bos_03_round0_tuning_base.json").read_text())
        expected = copy.deepcopy(baseline["enemies"])
        rule = baseline["storm_cantor_rule"]
        plan = json.loads(tuning.PLAN.read_text())
        ladders = json.loads((tuning.OUTPUT/"ladders.json").read_text())["ladders"]
        for guardian, ladder in ladders.items():
            for change in plan[guardian][:ladder["chosen_rung"]]:
                expected[guardian].update(change.get("fields",{}))
                for intent in expected[guardian]["intents"]:
                    actions = change.get("intents",{}).get(intent["id"],{})
                    for action in intent["actions"]:
                        action.update(actions.get(action["type"],{}))
                for helper, fields in change.get("helper_fields",{}).items():
                    expected[helper].update(fields)
                if "rule" in change:
                    rule["dials"].update(change["rule"].get("dials",{}))
                    rule["sentence"] = change["rule"].get("sentence",rule["sentence"])
        extensions = json.loads(tuning.EXTENSION_PLAN.read_text())
        selected = json.loads((tuning.EXTENSION_OUTPUT/"ladders.json").read_text())["ladders"]
        for guardian, ladder in selected.items():
            for change in extensions[guardian]["rungs"][:ladder["chosen_rung"]-extensions[guardian]["start_rung"]]:
                expected[guardian].update(change.get("fields",{}))
                for intent in expected[guardian]["intents"]:
                    for action in intent["actions"]:
                        action.update(change.get("intents",{}).get(intent["id"],{}).get(action["type"],{}))
                if "rule" in change:
                    rule["dials"].update(change["rule"].get("dials",{}))
                    rule["sentence"]=change["rule"].get("sentence",rule["sentence"])
        actual = json.loads((ROOT/"data/enemies.json").read_text())
        final_plan = json.loads(tuning.FINAL_PLAN.read_text())
        final_ladders = json.loads((tuning.FINAL_OUTPUT/"ladders.json").read_text())["ladders"]
        for guardian, ladder in final_ladders.items():
            entry = final_plan[guardian]
            changes = entry["repairs"] + entry["rungs"][:ladder["chosen_rung"]-entry["start_rung"]]
            for change in changes:
                expected[guardian].update(change.get("fields",{}))
                for intent in expected[guardian]["intents"]:
                    for action in intent["actions"]:
                        action.update(change.get("intents",{}).get(intent["id"],{}).get(action["type"],{}))
                for helper, fields in change.get("helper_fields",{}).items():
                    for key, value in fields.items():
                        self.assertEqual(actual[helper][key], value)
                if "rule" in change:
                    rule["dials"].update(change["rule"].get("dials",{}))
                    rule["sentence"]=change["rule"].get("sentence",rule["sentence"])
        # spx-08 (owner approval last-light-v2) appends the Wick Shade's Snuff; it is never offered in Guardian arenas.
        expected["wick_shade"]["intents"].append({"id": "snuff", "name": "Snuff", "time": 4, "weight": 2, "actions": [{"type": "move_toward", "range": 2, "snuff_brazier": True}]})
        self.assertEqual({key:actual[key] for key in expected}, expected)
        self.assertEqual(json.loads((ROOT/"data/battlefield_rules.json").read_text())["instances"]["storm_cantor"], rule)
        tender = actual["bell_tender"]
        self.assertEqual(tender["intents"][1]["actions"][1]["damage"], 3)
        if final_ladders["storm_cantor"]["chosen_rung"]<12:
            self.assertNotIn("guardian_intent_action_overrides",tender)

    def test_extended_ladders_stop_in_order_and_keep_rimejaw_decided(self):
        plan=json.loads(tuning.EXTENSION_PLAN.read_text())
        evidence=json.loads((tuning.EXTENSION_OUTPUT/"ladders.json").read_text())
        self.assertEqual(evidence["plan_sha256"],hashlib.sha256(tuning.EXTENSION_PLAN.read_bytes()).hexdigest())
        self.assertEqual(set(evidence["ladders"]),set(plan))
        for guardian,ladder in evidence["ladders"].items():
            reference=measurement.read_report(tuning.OUTPUT/f"{guardian}-after.json.gz")
            measured=ladder["rows"][1:]
            start=plan[guardian]["start_rung"]
            self.assertEqual([row["rung"] for row in ladder["rows"]],list(range(start,start+len(measured)+1)))
            self.assertFalse(any(row["inside_band"] for row in measured[:-1]))
            self.assertEqual(ladder["chosen_rung"],tuning.first_accepted(measured))
            self.assertTrue(ladder["inside_band"] or len(measured)==len(plan[guardian]["rungs"]))
            for row in measured:
                raw=measurement.read_report(tuning.EXTENSION_OUTPUT/f'{guardian}-r{row["rung"]}.json.gz')
                self.assertEqual(len(raw["results"]),90)
                self.assertEqual([sum(r["tier"]==tier for r in raw["results"]) for tier in (1,2,3)],[30]*3)
                self.assertEqual(tuning.merge_tiers([raw],reference)["results"],raw["results"])
                self.assertEqual(tuning.summarize_rung(guardian,row["rung"],row["label"],raw["results"]),row)
            self.assertEqual((tuning.EXTENSION_OUTPUT/f'{guardian}-r{ladder["chosen_rung"]}.json.gz').read_bytes(),(tuning.EXTENSION_OUTPUT/f"{guardian}-after.json.gz").read_bytes())
        for guardian in measurement.GUARDIANS:
            for variant in measurement.VARIANTS:
                if variant!="after" or guardian not in plan:
                    name=f"{guardian}-{variant}.json.gz"
                    self.assertEqual((tuning.EXTENSION_OUTPUT/name).read_bytes(),(tuning.OUTPUT/name).read_bytes())

    def test_golden_audit_classifies_every_field_and_rejects_unexplained_changes(self):
        room={"type":"combat","coord":{},"enemies":[]}
        current={"map":{},"rooms":[room],"combat":[{"pending_summon_card_plays":0} for _ in range(2)]}
        snapshots={"int06_prior_matches_frozen":True,"after":{"snapshots":{"1":current}}}
        self.assertFalse(golden_audit.audit(snapshots)["repinned"])
        current["combat"]=[{"pending_summon_card_plays":1} for _ in range(2)]
        with self.assertRaisesRegex(ValueError,"exact zero counter"):
            golden_audit.audit(snapshots)
        old={"map":{},"rooms":[room],"combat":[{"pending_summon_card_plays":0,"hp":1} for _ in range(2)]}
        new={"map":{},"rooms":[room],"combat":[{"pending_summon_card_plays":0,"hp":2} for _ in range(2)]}
        snapshots={"int06_prior_matches_frozen":True,"before":{"snapshots":{"421":old}},"after":{"snapshots":{"421":new}}}
        with self.assertRaisesRegex(ValueError,"Unexplained field"):
            golden_audit.audit(snapshots)

    def test_final_ladder_preserves_samples_and_decided_guardians(self):
        plan=json.loads(tuning.FINAL_PLAN.read_text())
        evidence=json.loads((tuning.FINAL_OUTPUT/"ladders.json").read_text())
        self.assertEqual(evidence["plan_sha256"],hashlib.sha256(tuning.FINAL_PLAN.read_bytes()).hexdigest())
        self.assertEqual(set(evidence["ladders"]),{"storm_cantor"})
        ladder=evidence["ladders"]["storm_cantor"]
        measured=ladder["rows"][1:]
        self.assertEqual([row["rung"] for row in measured],list(range(9,9+len(measured))))
        self.assertFalse(any(row["inside_band"] for row in measured[:-1]))
        self.assertEqual(ladder["chosen_rung"],tuning.first_accepted(measured))
        self.assertTrue(ladder["inside_band"] or len(measured)==len(plan["storm_cantor"]["rungs"]))
        reference=measurement.read_report(tuning.EXTENSION_OUTPUT/"storm_cantor-after.json.gz")
        for row in measured:
            raw=measurement.read_report(tuning.FINAL_OUTPUT/f'storm_cantor-r{row["rung"]}.json.gz')
            self.assertEqual(len(raw["results"]),90)
            self.assertEqual([sum(r["tier"]==tier for r in raw["results"]) for tier in (1,2,3)],[30]*3)
            self.assertEqual(tuning.merge_tiers([raw],reference)["results"],raw["results"])
            self.assertEqual(tuning.summarize_rung("storm_cantor",row["rung"],row["label"],raw["results"]),row)
        self.assertEqual((tuning.FINAL_OUTPUT/f'storm_cantor-r{ladder["chosen_rung"]}.json.gz').read_bytes(),(tuning.FINAL_OUTPUT/"storm_cantor-after.json.gz").read_bytes())
        for guardian in measurement.GUARDIANS:
            for variant in measurement.VARIANTS:
                if variant!="after" or guardian!="storm_cantor":
                    name=f"{guardian}-{variant}.json.gz"
                    self.assertEqual((tuning.FINAL_OUTPUT/name).read_bytes(),(tuning.EXTENSION_OUTPUT/name).read_bytes())



if __name__ == "__main__": unittest.main()
