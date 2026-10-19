# rr-21 feedback 3 (director): the review stage's direction gate — last round

The director's windowed chain at e05340c42 passes density, rest, native (0 errors), sheets, idle and production (front
and rear move gates, contacts and poses: 0 errors). The `review` stage fails its headless gates:

```text
RR21 FRONT DIRECTION: FAIL (0 positive checks; lash/thornwall required)
RR21 REAR DIRECTION: FAIL (0 positive checks; lash/thornwall required)
RR21 HEADLESS GATES: FAIL (3 errors)
```

1. **Find out why the direction gate sees zero positive checks in the review stage**, when your round 2 headless run
   passed it. The suspect is the compaction: the gate may read the committed compact `samples.json` instead of the
   full per-frame samples in the gitignored outputs, or the review stage may not regenerate them.
   - Fix it so the review stage's direction gate gets real `lash` and `thornwall` evidence in both views.
   - Keep the compact committed records.
   - Add a regression in which a review run that starts from a clean checkout plus fresh captures passes the gate.
2. **Low (rr-21 review):** `tests/test_rr21_walk.py:41` points at an outside file that doesn't exist, so removing the
   path-containment check still passes.
   - Create an outside JSON file with a matching hash and assert it is rejected.
   - Add a symlink case.
3. List the exact windowed `review` command. Focused tests only. This is the last round of this session.
