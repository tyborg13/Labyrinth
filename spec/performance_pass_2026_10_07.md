# Current-master performance integration — 7 October 2026

The bounded performance branch has been integrated with current `origin/master`, preserving the new visible equipment, weapon carry/grip work, board pixel density, and CPU texture-source changes. Repeated native measurements still show substantial reductions in the largest UI and travel spikes. Combat timing remains close to baseline with mixed action tails. The branch retains longer New Run loading, extra memory, and slower later Skills switches; it does not remove every hitch.

This report supersedes the baseline comparison in the [6 October checkpoint](performance_pass_2026_10_06.md). That report describes the retained implementation and its ownership, invalidation, lifecycle, and persistence boundaries. The measurements below compare against the newer master and are authoritative for this integration.

## Integration and source binding

- Baseline: fetched `origin/master`, `b792d218c281181eb2fa20aa853bdad1ca242305`, also the current local master; unchanged at the final pre-publication fetch.
- Measured candidate runtime: `37b38c822bd7e87eced91a048af5ba2860b6380f` on `codex/isolate-card-completion-stalls`. The report/proof commit changes documentation only.
- Merge commit `f492937a9d089e9c1beff4ef67506476ff8e5d2d` resolves the overlapping combat-board roster change by retaining performance attribution and the new equipment-sensitive protagonist/illusion synchronization.
- Commit `2d499cb0a` updates the frozen floor-cache reference with all upstream rendering changes while preserving its original cache algorithms and typed-array helpers. Native pixel equivalence therefore compares current-master visuals, rather than the older protagonist/floor rendering.
- Integration exposed stale visible equipment in the retained Character portrait. The final runtime commit refreshes the portrait's gear before presenting the retained rig. The regression test failed four gear-signature cases before the fix, then passed 19 cases headless and with exact native canvas pixels. Retention and fresh construction now agree after equipment swaps and tab/lifecycle changes.

The [source binding](proofs/performance-2026-10-07/final-source-binding.json) records 5,141 runtime, test, tool, and native-wrapper bindings. All were checked after the final capture restored the candidate. Each accepted process also verifies its own before/after runtime hashes. For baseline runs, the capture script temporarily restores every changed tracked production runtime file to `b792d218`; the corrected harness and reference tests remain identical in both conditions. New helpers remain present but baseline scripts do not invoke them. A `finally` block restores the exact candidate bytes. Git metadata remains the candidate branch HEAD during this source swap; it is not a fabricated baseline commit.

## Native conditions and accepted protocol

Godot 4.6.1 runs on macOS with the Apple M5 Pro, Metal/mobile renderer, production visuals, an actual window and viewport of 1920×1080, 100% UI scale, normal CPU profile, production capped hand, motion enabled, Dummy audio, and public menu entry. Jobs run serially in the foreground with isolated user data through the Godot task and visual-probe runners. No quality, effect density, animation, or rendering resolution is reduced.

The four accepted ALL captures run in baseline/candidate/candidate/baseline order, each executing the same 123 routed phases. The first attempt at the second candidate lost foreground focus, failed its semantic/focus contract, and reached the existing timeout. It is excluded entirely. Only that candidate and the remaining baseline were rerun; timeouts, focus requirements, and workload coverage were unchanged. The accepted retry and all other accepted probes use Metal on their first renderer attempt. Compression and report analysis take place after captures finish.

A separate matched baseline/candidate pair runs the complete runtime workload with `LABYRINTH_RUNTIME_PERF_FOCUSED=0`: all seven cards, six abilities, movement, three enemy rounds, three compositions, three Umbra stages, the interaction matrix, and synthetic Blink preview/target sweep. The optional private live-save Blink lane is unconfigured on both builds. These results do not claim to measure a personal save.

Every accepted performance report has matching semantic outcomes, correct native geometry/scale, zero focus-loss observations, zero behavior gaps, zero unexpected engine errors, zero orphan nodes, and stable runtime sources. All three enemy-round digests match their references and each other. Percentiles use nearest rank over raw completed-draw intervals, and pooled groups count each leaf sample once. Preparation and arrival frames remain inside the relevant workload windows; synchronous handlers are reported separately.

GPU timing is unavailable. Memory values below are Godot static heap, not OS RSS or VRAM. The render-texture monitor returns an invalid INT64_MAX sentinel and is discarded. No Windows, Steam Deck, or Proton performance or memory-headroom conclusion is claimed.

## Repeated ALL measurements

Exact per-phase intervals, means, medians, p95, p99, maxima, threshold counts, handlers, and validity checks are in the [ALL measurements](proofs/performance-2026-10-07/final-all-measurements.json). Startup is separate from the pooled 123 interaction phases.

| ALL metric | Baseline runs | Candidate runs |
| --- | ---: | ---: |
| Measured frames | 3,272 / 3,271 | 3,283 / 3,289 |
| Mean interval | 8.795 / 8.795 ms | 8.642 / 8.613 ms |
| Median | 8.336 / 8.338 ms | 8.336 / 8.336 ms |
| p95 | 9.173 / 9.105 ms | 9.363 / 9.289 ms |
| p99 | 26.345 / 27.937 ms | 24.194 / 23.499 ms |
| Maximum | 164.245 / 162.948 ms | 57.980 / 55.579 ms |
| Frames over 16.67 ms | 66 / 65 | 52 / 50 |
| Frames over 20 ms | 53 / 52 | 40 / 40 |
| Frames over 33.33 ms | 20 / 20 | 17 / 17 |

The largest interval falls by about 65%, while >33.33 ms counts fall by 15%. Median timing is unchanged and p95 rises slightly. This supports retaining the large-spike reductions, not a claim that every phase is faster.

| Phase | Baseline maximum range (ms) | Candidate maximum range (ms) |
| --- | ---: | ---: |
| Character open | 49.355–53.109 | 26.539–26.781 |
| First Skills switch | 64.934–65.148 | 35.826–36.432 |
| Later Skills switch, skills_4 | 22.260–30.274 | 36.731–40.146 |
| Later Skills switch, skills_10 | 30.801–31.319 | 39.443–43.219 |
| Later Skills switch, skills_16 | 29.860–31.425 | 39.098–40.415 |
| Reward reroll | 44.664–48.435 | 21.688–22.563 |
| Grimoire open | 17.703–18.744 | 12.336–12.707 |
| Equip weapon | 78.274–79.348 | 53.511–53.723 |
| Enter combat room | 87.813–88.117 | 55.579–57.009 |
| Begin combat | 132.349–136.679 | 39.534–40.443 |
| Enter campfire | 162.948–164.245 | 35.027–35.126 |
| Campfire Strength | 64.157–68.013 | 46.309–46.322 |
| Enter Scavenger | 103.225–103.779 | 54.485–57.980 |
| Enter treasure | 40.087–43.443 | 39.159–42.410 |

Later Skills switches are repeatable local regressions. The skills_10 synchronous handler changes 9.654–10.131 → 20.726–21.979 ms; skills_4 and skills_16 also take about 20–21 ms. First Skills improves from 42.771–43.729 → 15.299–15.394 ms. Source inspection suggests some freeing cost moves from Equipment→Magic to Magic→Skills; parked dialogs disable processing and their hidden cutout canvases do not continually redraw. This is an inference, not a measured causal breakdown. In the first accepted pair, total synchronous handlers for each of the two repeated tab cycles rise about 3.5 ms, so it is not simply cost-free rescheduling. The initial tab cycle improves overall.

Combat-arrival p95 increases 9.153–9.220 → 11.767–11.861 ms despite a much lower worst frame. Equipment close p95 increases 8.519–8.530 → 13.677–15.337 ms. Treasure arrival remains mixed. These moderate tails are retained and disclosed.

Public New Run worst interval improves 435.032–444.863 → 34.685–35.728 ms, with >33.33 ms frames dropping 3 → 1 in both repeats. Completion becomes longer: 2.776–2.850 → 3.717–3.926 seconds, about 0.94–1.08 seconds extra. Menu creation still spikes at 185.342–185.352 ms, compared with 187.267–188.936 ms on current master.

Final static heap rises from 423.06–423.12 to 484.73–484.82 MiB, approximately **61.7 MiB more**. This is retained preparation/UI memory, not a memory optimization claim.

## Complete combat pair

The [runtime measurements](proofs/performance-2026-10-07/final-runtime-measurements.json) preserve every lane and raw source/semantic validity checks. Timing below is milliseconds; these results come from one pair and do not establish repeatable small-tail gains.

| Group | Median base → candidate | p95 | p99 | Maximum | >16.67 ms | >20 ms | >33.33 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Settled idle, 150 frames each | 8.364 → 8.348 | 8.608 → 8.596 | 8.695 → 8.738 | 8.713 → 8.914 | 0 → 0 | 0 → 0 | 0 → 0 |
| Seven cards, 1,415 → 1,414 frames | 8.339 → 8.334 | 11.111 → 11.202 | 21.296 → 22.348 | 30.385 → 34.592 | 38 → 35 | 21 → 21 | 0 → 1 |
| Six abilities, 296 → 290 frames | 8.339 → 8.356 | 20.039 → 17.710 | 27.815 → 28.181 | 35.326 → 29.718 | 15 → 18 | 15 → 14 | 1 → 0 |
| Three enemy rounds, 5,470 → 5,475 frames | 8.371 → 8.361 | 11.573 → 11.686 | 16.523 → 16.849 | 35.740 → 35.370 | 50 → 57 | 15 → 18 | 1 → 1 |

Pooled card/ability/enemy means are 8.641→8.652, 9.152→9.241, and 8.590→8.602 ms. One candidate Threaded Path frame exceeds 33.33 ms. Local p95 increases exceed 5% for cold interaction (9.575→13.252 ms), Carry the Guard (12.956→16.276 ms), and Encore (20.510→22.671 ms). The small ability lanes have 24 and 65/64 samples respectively. Other action tails are mixed, and no general steady-combat FPS improvement is claimed.

Final static heap changes 397.78 → 440.77 MiB (**+42.98 MiB**) and final nodes 5,571 → 6,293. Reinstalling the same fixture leaves exactly the same final node count on each build, with zero orphans. Retention is bounded in these measured cases; target-hardware headroom remains unmeasured.

## Verification and real-renderer inspection

The [proof manifest](proofs/performance-2026-10-07/manifest.json) identifies the accepted reports, logs, source hashes, reproduction scripts, and inspected images. Gzip artifacts include original-content and archive SHA-256 hashes. The failed focus attempt and the initial sandbox-limited Python attempt are excluded from acceptance proof. The explicitly labeled pre-fix gear failure is a regression reproducer, not a passing test.

- Full Godot suite passes against the final runtime. Its deliberate progression-acknowledgment error is enumerated; the existing ObjectDB-at-exit warning remains. Accepted native reports require zero unexpected errors and zero orphans.
- All 26 focused suites pass, covering owned factories/assets, encounter/hand/card preparation, travel/equipment and scene handoffs, retained Character views, Grimoire/map/shop reuse, reward flows, analytics, draw/hand flow, and save/recovery. The save/resume fixture's six deliberate fault diagnostics are explicitly enumerated.
- All eight native suites pass: floor cache 102 cases / 156,916 checks; shadows 276 / 981; prepared unit canvas 32 / 672; shop glyphs 8 / 3,024; objective glyphs 26 / 12,630; deferred skill/run analytics 79 / 105 checks; retained Character loadout 19 cases. Floor, portrait, shadow, canvas, and typography tests retain exact reference pixels. The skill analytics suite's four deliberate I/O errors are enumerated.
- Upstream integration checks pass: 41 Python board-density tests and three gear-asset tests, plus the visible-gear tests included in the full Godot suite. Windows-safe typed-array assignments remain in the changed tests/reference; an actual Windows runtime is unavailable.

Fresh 1920×1080, 100% images were inspected for [pre-battle](proofs/performance-2026-10-07/images/final-all-candidate-0/all_surface_pre_battle.png), [gear after an equipment swap](proofs/performance-2026-10-07/images/final-all-candidate-0/all_surface_equipment_after_swap.png), [combat after Begin](proofs/performance-2026-10-07/images/final-all-candidate-0/all_surface_combat_begun.png), [dense idle](proofs/performance-2026-10-07/images/final-runtime-candidate/dense_idle.png), [live fire](proofs/performance-2026-10-07/images/final-runtime-candidate/live_fire_impact.png), and [post-trap hand](proofs/performance-2026-10-07/images/final-runtime-candidate/ranged_trap_hand.png). Floor/shadow/canvas fixtures, shop glyphs, and objective intro/settled HUD were also inspected. The new board density and visible gear remain present; ordering, shadows, effects, controls, and authored typography look sound.

## Publication and inspection fixture

The user's 7 October instruction authorizes integration, conflict resolution, fresh measurements, and landing on master if the result remains satisfactory. The retained repeatable large-spike improvements, passing behavior/visual proof, and disclosed memory/loading/local-tail costs support publication of this bounded branch. Final publication still uses separate peer signoff and the task helper's exact-HEAD authorization.

After that signoff, regenerate and verify the pre-battle fixture with the standard two-process wrapper:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/isolate-card-completion-stalls
python3 tools/inspection_fixture.py --task-id isolate-card-completion-stalls --run-id isolate-card-completion-stalls-master-integration-inspection --scenario pre_battle --seed 84217 --min-enemies 3 --equipment-inventory iron_cleaver,ward_kite --held-embers 720 --summary 'Inspect current-master performance integration: visible gear, character tabs, Start and travel.'
```

Add --launch to that command to open the isolated fixture, then choose Continue to inspect Gear/Magic/Skills, equipment swaps, Start, card actions, Pass, and travel. The fixture uses isolated saves and Steam disabled. After publication/cleanup, run from the primary checkout and supply a new run ID if further inspection is desired.

Remaining measured hitches include menu creation (~185 ms), equipment changes (~54 ms), combat/Scavenger arrival (~56–58 ms), Begin (~40 ms), campfire Strength (~46 ms), and later Skills switches (~37–43 ms). Occasional combat frames around 35 ms remain. This integration concludes the authorized checkpoint; it does not resume broad optimization or claim all hitches removed.
