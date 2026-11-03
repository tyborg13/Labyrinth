"""Run the repo's Python suite exactly as merges do (unittest discover, serial) and record per-test wall time.

Time between one test's stop and the next test's start (setUpClass/setUpModule, imports) is charged to the next
test as `setup_s`, so module totals are complete. Writes JSON after every test so a partial run is usable.
Usage: python3 timed_unittest.py <out.json>   (run from the repo root)
"""
import json
import sys
import time
import unittest

OUT = sys.argv[1]
records = []
state = {"last_stop": time.time(), "t0": 0.0}
started = time.time()


def dump(final=False):
    with open(OUT, "w") as handle:
        json.dump({"final": final, "elapsed_s": time.time() - started, "tests": records}, handle)


class TimedResult(unittest.TextTestResult):
    def startTest(self, test):
        now = time.time()
        state["setup"] = now - state["last_stop"]
        state["t0"] = now
        super().startTest(test)

    def stopTest(self, test):
        now = time.time()
        super().stopTest(test)
        records.append({"id": test.id(), "run_s": round(now - state["t0"], 3), "setup_s": round(state["setup"], 3)})
        state["last_stop"] = now
        dump()

    def _outcome(self, test, outcome):
        records_outcomes[test.id()] = outcome

records_outcomes = {}

suite = unittest.TestLoader().discover("tests", pattern="test_*.py")
runner = unittest.TextTestRunner(resultclass=TimedResult, verbosity=1, stream=sys.stderr)
result = runner.run(suite)
failed = {t.id() for t, _ in result.failures + result.errors}
for record in records:
    record["failed"] = record["id"] in failed
dump(final=True)
print("TIMED SUITE DONE tests=%d failures=%d errors=%d elapsed=%.0fs" % (
    result.testsRun, len(result.failures), len(result.errors), time.time() - started))
