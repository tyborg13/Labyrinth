# perf-146 feedback 2

The quit watchdog starts with an eight-second save deadline and switches to the existing cleanup deadline after the save barrier returns. Its mutex protects the deadline only. The indefinitely stalled temporary-write probe exited in 8.050 seconds and left the live checkpoint byte-identical. The next launch resumed that checkpoint. The 4.5-second write still completed byte for byte and resumed on relaunch.

The title, covered boot, and Windows backup rotation use the shared checkpoint validator. Both a seedless demo record and a wrong-build live checkpoint preserved the valid backup through an interrupted rotation. Each offered Continue, required replacement confirmation, and resumed the backup. The unavailable-live probe deferred reads and writes, preserved both files, and resumed the newer live run after access returned. The macOS probe denied read permission. The Windows proof driver uses an exclusive Win32 file handle.

The demo cutoff remains authoritative. An earlier legal backup cannot bypass a live checkpoint past that cutoff.

## Save and resume proof

`PERF146 RESUME MODES: 12/12 passed`. Every case exercised the title's Continue action and covered boot. The event choices and escape cases wrote the checkpoint in a separate process and then relaunched.

| Saved mode | Observed after Continue |
| --- | --- |
| `room` | Same room |
| `pre_battle` | Same pre-battle room |
| `combat` | Same combat room |
| `reward` | Same reward room |
| `campfire` | Same Ember Hearth |
| `treasure` | Same treasure room |
| `graftwright` | Same Graftwright |
| `event` | Same room and choices page |
| `event` with a resolved choice | Same room and result page |
| `escape` | Reached the saved destination with the claimed card intact |
| `victory` with an heirloom pending | Same victory checkpoint |
| `defeat` with an heirloom pending | Same defeat checkpoint |

Embrace writes the profile and clears the active run. Terminal recovery handles completed victory and defeat once heirloom selection is settled.

## Report-only review findings

**Review 3 — Clear order.** Delete and verify removal of the recovery file and temporary file before deleting the live checkpoint. Return and propagate a failed clear through abandon and terminal-save handling so the caller can retry while the live checkpoint is still available. A synced deletion receipt keyed to the checkpoint generation would let recovery reject an older backup returned by Steam Cloud.

**Review 4 — Profile before checkpoint.** Put the New Run profile delta and an idempotency receipt in the replacement checkpoint. Use checkpoint promotion as the commit point, then apply the delta to the profile and record the receipt. On restart, retry any promoted delta whose receipt is absent from the profile. This ordering preserves the old run counter and Ember recovery marker when promotion fails.

**Review 6 — Profile recovery in Steam Cloud.** Add an exact `progression.json.backup` Auto-Cloud rule for the demo with the same account directory and platform overrides as `progression.json`. Verify a first launch on a clean install with only the backup and no active run, then confirm a successful profile save restores the live filename and retires the backup. Steamworks App Admin controls the deployed rules.

## Regression receipts

The logs for this round are in `output/perf-146/feedback-2/`.

- `PERF146 PROOF: 5/5 expected outcomes` for the previous repros, `4/4 expected outcomes` for the new fault cases, and `PERF146 crash-between-renames: PASS`.
- `PERF144 REVIEW: 7/7 passed`. `PERF145 PROOF: 14/14 expected outcomes` normal and `5/5 expected outcomes` background.
- `PERF142 STRESS: PASS cold_runs=50 seed_mismatches=10 paint_in_flight_cancels=10 graph_in_flight_cancels=10 retries_while_reaping=20 max_cover_free_usec=7408 press_lifecycle_checks=6` normal.
- `PERF142 STRESS: PASS cold_runs=50 seed_mismatches=10 paint_in_flight_cancels=10 graph_in_flight_cancels=9 retries_while_reaping=20 max_cover_free_usec=86257 press_lifecycle_checks=6` background.
- `PERF03 CHECKPOINT CRASH SAFETY: PASS (3 transaction boundaries)`. The title resume/input, committed-save matrix, demo boundary, application shutdown, and shutdown reentrancy checks passed.
- `TYPED ARRAY SCAN: 54 scripts; 0 new; 4 pre-existing`. UI identity ran 25 tests and returned `OK`. The process-launch grep found zero additions under `scripts/`.
- `EXPORT_SMOKE_LOADED scripts=746 scenes=9`. `EXPORT_SMOKE RESULT: PASS (115.04 seconds)` for Steam macOS.

## Native proof

The new windowed captures and the Windows share-lock execution remain open. The capture command produces each mode's `title.png` and `resumed.png` at 1920×1080 and 100% UI scale. The proof reuses seed 83, a 120 FPS cap, and a 30-second in-game deadline. The stalled-write proof runner has a 45-second outer timeout. The Windows driver polls the lock handshake every 10 ms.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-146 && python3 tools/perf_142/perf146_proof.py --case resume-modes --display macos --output output/perf-146/feedback-2/windowed
```

On Windows, run `tools/perf_142/perf146_proof.py --case unavailable-live` with a fresh `--output` directory to exercise the native file-sharing error.
