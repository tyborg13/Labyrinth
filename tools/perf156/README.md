# perf-156 verification

Round 1 compares against release `52cd3916f`, already merged by `826c63f32`. Both sides use the rebuilt perf-155 imports. The perf-152 archive aggregates five takes. The four section paintings listed as undrawn belong to the tour takes. The archived seed-7 demo and demo-tail loaded only Tharokh’s section painting. Some of the same off-demo dragons had observed draws in the independent tour fixtures. Use matched runtime receipts for the current release comparison.

| Policy | Request boundary |
| --- | --- |
| Map paintings | The current and linked next sections warm under New Run / Continue and section arrival. The demo cutoff excludes its second section. Hidden map updates stop resolving the painting. History can resolve a previous painting when selected. The six approved painting sources match their lossless, unmipped imports byte for byte after conversion to RGBA8. The existing worker decodes the PNG when available and keeps the import fallback for packaged builds. |
| Dragons and guardians | Preserve the actual encounter’s rig, facings and approved textures. Travel and Continue prepare the committed roster before handoff. Dragon and guardian portraits leave the startup manifest and join the encounter manifest. |
| Optional rooms | Campfire, Graftwright, Scavenger, treasure lid and selected event art prepare from destination metadata under travel or Continue. Direct fixture installs retain the synchronous presentation fallback. |
| Reference screens | Grimoire and Chronicle resolve their selected contents on open. The defeat animation and the terminal Continue cover prepare the same killer portrait the recap already uses. |
| Shared art and direct-draw gaps | Card rewards, map icons, HUD assets, trap activation and board derivatives may draw after interaction or sample through another texture. The air-wisp sources are excluded by the existing disabled decorative-gust gate. |

The per-texture report covers the archive's undrawn rows above 1 ms, dragon and guardian pieces, and paths from the matched takes. Categories are `a` later use, `b` route excludes it, `c` reference screen, and `d` retained draw or sampled source. A compound category records two consumers with different boundaries. A zero in a matched column means the loader trace reported no timed request in that scope. Source-based estimates are one-copy bytes from the archive. They cannot be summed into a peak because sources may have nonoverlapping lifetimes.

The deterministic seeds and section cases come from the existing proof fixtures. Probe-only settings are a 1920×1080 window at 100% scale, a 60 FPS cap with native VSync, 12 settle frames, 30 first-visit intervals, and a 20 s handoff watchdog. Real-time frame samples include scopes that directly install a fixture and scopes that exercise Continue or the actual section transition. Fixture installation is labeled separately in the tour and can exercise synchronous fallbacks that the player normally reaches through a cover.

## Round 1 headless comparison

The focused recap test loads a live Guardian encounter via Continue, runs its lethal presentation, applies the normal heirloom decline rule and commits the terminal checkpoint. The first-visit scope starts at recap opening. The round-0 test installed a fresh defeat fixture from the threshold and measured its room, inventory and profile rebuild in the same scope. The trace showed the largest texture delta in that old scope was the Grave Dust Satchel icon (+2.344 ms).

| Recap opening | Frames | Median ms | p95 ms | Maximum ms | Intervals >33 ms | Texture ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Release `52cd3916f` | 30 | 6.889 | 8.735 | 79.824 | 1 | 0.038 |
| Round 1 | 30 | 6.943 | 9.880 | 60.764 | 1 | 0.023 |

The separate `--recap-only --cold-killer` check removed the approved portrait from the loader cache before the lethal transition and verified that the settle beat republished it before reveal. The ordinary settle duration applies to a warm cache.

### Tour attribution

The round-0 fixture-install total rose from 2,741.774 to 3,168.184 ms. The largest positive install deltas were Scavenger (+251.196 ms), Campfire (+223.417), Character (+91.454), Pre-battle (+90.753), Graftwright (+45.639), and Combat (+44.206). Start fell by 229.691 ms. The old and new CSVs give per-install, per-texture durations and request counts. The Godot-cache column describes entry to the recorded span and can differ from the loader’s own cache residency.

- Campfire’s bonfire sheet moved from Start to Campfire (89.434 ms at base Start, 184.574 ms at the candidate’s first Campfire install). Scavenger’s inspection frame moved from Start to Scavenger (45.612 ms at base Start, 104.642 ms at candidate Scavenger). The tour creates a fresh RunScene and injects each state directly. Player travel and Continue use the preparation cover.
- Character incurred a second Zekarion painting load after a previous tour scene released it (0.008 ms base, 91.140 ms round 0 with zero Godot cache hits). A same-run Continue could also have reloaded released art. The candidate now keeps requested paintings, shared visited-room art and the visible resumable encounter’s rigs available across a scene exit. On round 1 the Character reads were 0.006 and 0.003 ms, with one cache hit on the candidate’s one request. The focused first-visit probe also exercises repeat Continue into a later section, Campfire and Scavenger with texture identity checks.
- Pre-battle’s largest increases were Harrier spear (+18.415 ms), Crawler rear leg (+10.308 ms), and Stone Warden front rest and mace (+10.187 and +9.945 ms). Their request counts matched and these paths were outside the round-0 eviction policy. The Start medallion (+61.408 ms), several Graftwright layers, and Lightning Wisp art likewise had equal request counts. These durations do not demonstrate an extra reload.

Round 1’s seed-83 fixture-install total fell from 1,794.013 to 1,619.585 ms (9.7%). Its first visible Start fixture fell from 843.398 to 591.467 ms. The direct Campfire and Scavenger installs still include first-use room art, with representative candidate requests of 85.085 ms for the bonfire sheet, 45.087 ms for the inspection frame, and 44.243 ms for the stall backdrop. Both tour receipts completed with zero errors.

The matched New Run loader trace fell from 1,208.496 to 616.829 ms (49.0%). Five section entries fell from 287.385 to 25.918 ms (91.0%). Including their preceding Continue covers, the same entries fell from 357.035 to 135.244 ms (62.1%). The first-visit checks passed 36 scopes per side, and the post-teardown loader cache fell from 1,731 to 1,076 paths. These headless timings are single-take inclusive loader samples.

Local receipts and tables are under `output/perf-156/r1/`. The combined report includes first-visit frame distributions, matched texture scopes, and the archive classification. Peak and post-teardown renderer bytes, present cadence and pixel identity are native checks. The commands below write native captures to `output/perf-156/r1/native-proof/`.

## Proof for the design owner

The native runner uses the frozen release project beside these receipts and writes to `output/perf-156/r1/native-proof/`. Set `PERF156_NATIVE_OUT` to a fresh absolute directory for another take. Keep the macOS window focused. The renderer, UI scale and fixture order match across each pair.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-156
bash tools/perf156/native.sh pixels
bash tools/perf156/native.sh timing normal
bash tools/perf156/native.sh timing background
bash tools/perf156/native.sh tour normal
bash tools/perf156/native.sh tour background
```

`pixels` runs the 1920×1080, 100% UI captures in separate processes and compares the decoded pixels for both the seed-7 New Run and first-visit images. The first-visit set covers Continue, each later section entry, Grimoire, Chronicle, the defeat recap, all six dragons, all six guardians and five optional rooms. Review animated regions at the captured phase when investigating a pixel difference.

`timing` records the seed-7 New Run, 36 first-visit scopes including the three repeat Continue checks, and renderer memory counters. The background profile uses `taskpolicy -c background`. `tour` records the native seed-83 census using disposable project copies with the census’s exact 1280×800 Deck viewport and 115% UI scale. The commands and runner arguments are in `tools/perf156/native.sh`.
