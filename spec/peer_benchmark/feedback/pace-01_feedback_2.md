# pace-01 feedback 2 — SFX sync regression at merge

The director merged e89afbda7 into integration and ran the full Godot suite: `suites/sfx_sync_0_program` fails
deterministically (twice in isolation too):

```
ERROR: request_counts shrank: spikes / 1.5x / fatigue|fatigue
SFX SYNC HARNESS RESULT: FAIL (1571 observations, 1 failures)
```

The check is `tests/sfx_sync_coverage.gd` ~line 112 against `spec/peer_benchmark/staged/sfx/sync_baseline.json`: under
the `spikes` frame profile at 1.5× combat speed, the `fatigue` cue is requested fewer times than the baseline. Integration
has been reset to before the merge; your branch is unchanged.

1. **Find the root cause first** and state it with evidence (the SFX sync trace before vs after your change, same profile
   and speed). Either:
   - a fatigue cue is genuinely lost or skipped by the new awaited `after_step`/settle/lead path (a real bug): fix it so
     every fatigue event still requests its cue at every speed and frame profile; or
   - the same fatigue events still play but fewer fall inside the scenario's capture window because the round is now
     longer: then the scenario must still cover them (extend or re-time the scenario window), not shrink the baseline.
   - Don't lower any baseline count unless you prove the event itself no longer occurs in the game, and say so.
2. Run the complete SFX sync harness at all profiles and speeds (`suites/sfx_sync_0_program` … `_2_program` through
   `tools/program_suite_runner.py --suite …`), plus the combat feel, pacing regression and mutation tests.
3. No full suites; the director re-runs them at merge.
