# perf-142 round 2 first map

The title requests the existing run scene after its first unlocked
presentation. After one second of title inactivity it reserves a seed and
starts the graph worker with the main-thread guardian, depth and special-
encounter snapshot documented in [round 1](round1.md). The title hands the
single-use job to the loading cover. Cover removal and title exit cancel the
job through the existing root-owned reaper.

The run checks both seed and depth after resolving the saved profile. An
explicit seed has priority, including one set during the cover. A mismatch
cancels the older job and starts a replacement worker. Automatic seeds
skip reservations and the previous saved seed. The same seed drives the
graph, save and analytics. Reentering the title starts a fresh preparation.

The title also starts the existing CPU and dialogue asset jobs. Optional
audio warmup on the title waits for the scene dependency request to finish.
The cover can take over that job. The alignment-import barrier still runs
before the bank uses the streams. Bank compilation and alignment now share
the existing preparation budget across cover frames. The same bank
configuration and cue order apply to direct and staged startup.

The timing probe records whether the graph was ready before the press. It
stops voices and observes mixer updates after writing the timed take and
receipts.

## Focused checks

The scratch harness in `/private/tmp/labyrinth_codex/perf-142/round2/`
exercises 50 New Runs with cold GameData, cancels each kind of worker ten
times at randomized frames, retries while the old drains are active and
checks the live and saved graph. The seven additional checks cover seed
reservations, title reentry, automatic seeds, changed or removed overrides
and a pinned seed at a changed depth.

- Normal: `PERF142 STRESS: PASS cold_runs=50 seed_mismatches=10 paint_in_flight_cancels=10 graph_in_flight_cancels=10 retries_while_reaping=20 max_cover_free_usec=5776 idle_lifecycle_checks=7`
- Stand-in: `PERF142 STRESS: PASS cold_runs=50 seed_mismatches=10 paint_in_flight_cancels=10 graph_in_flight_cancels=10 retries_while_reaping=20 max_cover_free_usec=12265 idle_lifecycle_checks=7`
- `TEST RESULT: PASS — main menu input and startup transitions`. This focused
  fixture still emits the ObjectDB teardown warning recorded in round 1.
- `TEST RESULT: PASS — main menu resume safety`
- `SFX AUDIO LENGTHS: 85 Godot streams compared with decoded PCM` and
  `SFX SYNC BANK TEST RESULT: PASS (0 failures)`. The fixture exited cleanly.
- `TYPED ARRAY SCAN: 20 scripts; 0 new; 1 pre-existing`. This applies the
  unit sources to a disposable copy of the current release baseline and runs
  `python3 tools/qa105/typed_array_scan.py --base codex/release`. The raw
  worktree comparison against the advanced release branch reports the same
  seven unrelated findings as committed round 1.
- Steam Demo Windows pack: `CEL_PACK_TEST paths=3089 failures=0`. The pack
  command exited 0. Its known sandbox Keychain diagnostic and duplicate
  placeholder asset UID warning also appeared in the round-1 export.
- macOS release template: `EXPORT_SMOKE_LOADED scripts=741 scenes=9` and
  `EXPORT_SMOKE RESULT: PASS (559.03 seconds)`.

## Headless timing and receipts

Godot 4.6.1, demo seed 7, 1920×1080 at 100% UI scale and four seconds of
title idle. The release control is `e5a6d3f53`. The stand-in used macOS
`taskpolicy -c background`. The final takes ran serially after the checks and
exports finished. The graph was ready before the press in both candidate
takes.

| Profile | Press to first interactive map, release → candidate | Max frame, release → candidate | Recorded round-1 max | Fresh round-1 max |
| --- | ---: | ---: | ---: | ---: |
| Normal | 2847.381 → 1143.663 ms | 342.671 → 41.598 ms (−87.9%) | 53.695 ms | 41.325 ms |
| Stand-in | 12257.929 → 11697.183 ms | 1157.517 → 206.870 ms (−82.1%) | 250.407 ms | 205.932 ms |

The candidate beat release on time to first map and beat the recorded
round-1 longest frames in both profiles. Against the fresh round-1
controls, the candidate maxima were 0.273 ms and 0.938 ms higher. Both
candidate maxima fell on the opening dialogue click to the map. Earlier
candidate takes under host load show longer scheduling gaps during the
scene dependency wait. Their raw probes are retained alongside the final
measurements.

Both profiles matched the release live run, save, profile, map destination
and opening paint receipts. The existing comparison excludes the random
analytics ID and the elapsed play clock. All 46 stand-in candidate
intervals over 100 ms have a named phase or wait context.

The exact timing comparisons, each interval over 16 ms, raw probe JSON and
scratch logs are under `/private/tmp/labyrinth_codex/perf-142/round2/`.
See `matched-normal.md`, `matched-background.md` and the two
`matched-vs-round1-*.md` reports. Windowed commands are in [Proof for the
design owner](README.md#proof-for-the-design-owner).

For `spec/peer_benchmark/perf_log.md`

- **perf-142 round 2** (2026-11-19) — Prepare fresh seeded graphs on title idle and slice startup SFX bank work. Demo seed 7 headless press to first map 2847.381 → 1143.663 ms normal, 12257.929 → 11697.183 ms stand-in, receipts match, native proof pending.
