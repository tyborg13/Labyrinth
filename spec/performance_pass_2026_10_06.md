# Remaining hitch performance pass — 6 October 2026

> Publication rerun: [7 October current-master integration and measurements](performance_pass_2026_10_07.md) supersede the baseline comparison in this historical checkpoint.

This is the bounded checkpoint requested by the user after the current in-flight changes. It retains measured reductions in repeated construction, transition preparation, UI rebuilds, and first-use font work. It does **not** remove every hitch. The final comparison and remaining work below use complete playable workload windows, including preparation and arrival frames.

## Source and conditions

- Baseline: fetched `origin/master`, `1eeead41087e11e64609f266e33508d0357efe25`, unchanged at final fetch.
- Candidate: `codex/isolate-card-completion-stalls` in its isolated task worktree.
- Native captures: Godot 4.6.1 on macOS, Metal/mobile renderer, production visual settings, actual window and viewport 1920×1080 at 100% UI scale, normal CPU profile, production capped hand, motion enabled, public menu entry. Jobs run serially in the foreground.
- The ALL surface workload runs in baseline/candidate/candidate/baseline order. The complete combat workload additionally runs as a matched baseline/candidate pair. Reports retain raw completed-draw intervals, tail percentiles, threshold counts, semantics, focus, geometry, nodes, and heap metrics.
- Baseline captures temporarily restore every changed tracked production runtime file to the baseline revision in the same worktree. The new harness and reference tests are identical in both conditions. Each process has an isolated user-data directory. New helper files remain present but the baseline production scripts do not reference them. A `finally` block restores exact candidate bytes.
- Measurements are bound to source hashes. Git metadata names the branch HEAD at capture time; a source-swapped baseline is not represented as a fabricated baseline commit. The manifest distinguishes source contents from Git metadata.
- GPU timing was unavailable. Heap values are Godot static heap, not OS RSS or VRAM. These are Mac measurements; no Steam Deck, Windows, or Proton performance conclusion is claimed.

## Retained implementation

### Owned preparation at existing presentation boundaries

Menu entry settles its loading canvas, prepares textures and CPU assets, and builds the initial UI in bounded work between presented frames while loading still owns input. Encounter preparation owns its run snapshot, combat cursor/RNG, textures, renderer data, opening hand, and pre-battle view. The synchronous original factory remains the fallback whenever preparation is incomplete, invalid, or cancelled. Complete state and mutable definition snapshots must match before adoption; changed equipment, HP, room, entry tile, tutorial state, or definitions invalidate a future. Independent cursors cannot share partial state or advance each other's RNG.

Equipment alternatives and reward rerolls likewise prepare private results and original controls. The authoritative action still commits its normal state, RNG, events, audio, and save. No gameplay result is installed early. Hidden shop and pre-battle controls retain their original constructors and final native hierarchy, with generation and lifecycle guards; native glyph preparation uses the actual visible text, font, size, outline, shadow outline, language, and oversampling.

Preparation may reduce a synchronous action while retaining other spikes in its complete window. It is not accepted as hitch removal merely because the final handler becomes cheaper.

### Reuse complete UI inputs and controls

Character Gear/Magic/deck/inventory/header/loadout surfaces and known Grimoire search rows retain original controls when their complete input keys and valid hierarchy permit reuse. Changed groups use the original constructors. Hidden views retain independent bindings; focus is released when a surface is parked, tab scroll behavior follows the original new-view behavior, and mutable input snapshots are owned. Section map and shop rows use the same conservative fallback on structural or input changes. Skill-link geometry is cached independently of skill state and presentation.

Card playability, previews, and shortcut results are prepared from owned state and catalog inputs, then adopted only when still current. Foreground callers keep ordinary copying and synchronous fallbacks. Noncombat travel avoids building a discarded private pre-battle state while still executing the canonical room transition and its events, loot, stock, and recovery rules.

### Preserve board rendering while avoiding duplicate work

Static floor caching compares the complete owned pixel inputs before deciding whether a rebake is needed. Logical state changes still propagate visibility, Umbra, effects, and HUD updates. A separate resolved-geometry comparison can preserve shadow geometry when the actual board transforms, dimensions, ordered tiles, zoom, pan, and origin are unchanged. Dynamic assets skip fanout only for identical resource/container bindings and a verified current layer hierarchy; equal-content replacement dictionaries still propagate. Layer order and structure are checked before reuse.

Shadow triangulation and prepared unit canvases retain the original geometry and draw behavior. Frozen reference implementations and native images test in-place mutations, geometry changes, missing/reordered layers, cache disable/reenable, visibility, texture replacement, and independent ownership. No resolution, effect density, authored animation, lighting, or quality setting is reduced.

### Font preparation and final objective change

The final in-flight change prepares the objective intro's fitted title/kicker sizes and strokes, the settled HUD sizes, and the space/ellipsis glyphs that native Labels shape. It also prepares text metrics at the retained label's current size before assignment. The visible labels, font parameters, fit algorithm, travel, crossfade, and reduced-motion behavior remain unchanged. Opening visibility uses the same limited-Umbra enemy set as the locked live HUD.

The accepted objective proof covers 26 native cases and 12,630 checks, exact pixels across objectives, intermediate font sizes, shadows, intro/settled positions, long-title fitting, reduced motion, empty objectives, cancellation, combat changes, detach, and free. Private font RIDs prevent the reference from warming the candidate. Native first drawing adds zero missing size/stroke/glyph cache entries. The final complete-branch comparisons below include this preparation. Begin still hitches.

### Lifecycle and durable analytics

Departed runs release their hidden tree in bounded cleanup after leaving the scene, disconnecting outside receivers and preserving scene ownership. Usable-title readiness can precede the last cleanup slices; the earlier title-return metric does not measure complete draining and is not a total-cleanup speedup claim here. Deferred run-stream analytics coalesce after a rendered frame while retaining the complete synchronous outbox-save → append-only JSONL → cursor-save transaction. Gameplay checkpoints still precede UI refresh. Held presentation, lifecycle/storage changes, explicit Save & Quit, window close, and append/save failures retain their durability boundaries. First-HUD attribution owns its original context so a following action cannot reattribute an earlier event.

The changed scheduling and persistence rules are documented in [analytics](analytics.md) and [save persistence](save_persistence.md). No save-schema fields or combat/balance rules are changed.

## Final measurements

The four ALL captures each execute the same 123 routed phases. Every report has identical semantic results, no observed behavior gaps, zero unfocused observations, zero orphan nodes, correct geometry/scale, and stable source hashes before/after. These are repeated complete interaction windows; startup is reported separately. Exact per-phase medians, p95, p99, maxima, counts, and handler durations are in [ALL measurements](proofs/performance-2026-10-06/final-all-measurements.json).

| ALL interaction metric | Baseline runs | Candidate runs |
| --- | ---: | ---: |
| Measured frames | 3,266 / 3,273 | 3,287 / 3,290 |
| Median interval | 8.324 / 8.328 ms | 8.327 / 8.326 ms |
| p95 | 8.828 / 8.725 ms | 9.102 / 9.149 ms |
| p99 | 24.812 / 23.461 ms | 20.797 / 20.513 ms |
| Maximum | 160.549 / 163.905 ms | 42.795 / 42.445 ms |
| Frames over 16.67 ms | 60 / 62 | 47 / 51 |
| Frames over 33.33 ms | 16 / 14 | 5 / 5 |

The median is unchanged and the smaller tail rises slightly, while the largest spikes and >33.33 ms counts improve. This is not evidence that every interaction is faster. The following maxima show both repeatability and the residual cost; all values are milliseconds.

| Phase | Baseline maximum range | Candidate maximum range |
| --- | ---: | ---: |
| Character open | 45.568–50.377 | 26.088–26.300 |
| First Skills switch | 58.787–60.433 | 32.609–33.758 |
| Later Skills switch (cycle 1, skills_10) | 23.429–24.984 | 32.151–33.692 |
| Reward reroll | 43.567–45.248 | 22.061–22.686 |
| Recover health and save | 51.402–53.382 | 22.353–23.016 |
| Equip weapon | 65.735–69.430 | 30.165–30.354 |
| Enter combat room | 87.087–88.313 | 40.088–40.625 |
| Begin combat | 136.878–140.404 | 42.445–42.795 |
| Enter campfire | 160.549–163.905 | 36.021–38.083 |
| Campfire Strength | 55.918–56.483 | 28.049–29.818 |
| Enter Scavenger | 101.232–103.172 | 38.692–38.748 |
| Enter treasure | 37.034–41.229 | 24.382–27.100 |

The later Skills switch is a repeatable local regression: its synchronous handler changes 7.716–8.981 → 17.187–17.809 ms. Grimoire open handlers improve slightly while their rendered maxima rise 14.577–15.307 → 20.580–21.555 ms. Combat-arrival p95 increases from 8.630–8.767 to 11.707–11.863 ms even as its worst frame falls substantially. The checkpoint retains these disclosed moderate-tail costs alongside the larger reductions.

Public New Run loading also trades completion time for fewer large frames: worst interval 443.829–448.921 → 32.419–38.841 ms, but completion 2.708–2.759 → 3.617–3.709 s. Startup menu creation still has 188.529–193.162 ms spikes. Loading and menu timing include their own full captured windows; report sorting is outside completion timestamps.

Retained preparation increases final Godot static heap in the ALL workload from about 417.0 to 485.0 MiB, approximately **68.0 MiB more**. The complete combat pair changes 398.17 → 440.86 MiB (+42.69 MiB) and 5,531 → 6,253 settled nodes. Reinstalling the same fixture leaves exactly the same final node count on each build; both finish with zero orphans. This demonstrates bounded retention in the measured cases, not target-hardware memory headroom. The render-texture monitor returns an invalid INT64_MAX sentinel and is discarded; no VRAM gain is claimed.

The separate complete runtime pair enables all seven cards, six abilities, movement, three enemy rounds, three compositions, three Umbra stages, Blink target sweep, and the interaction matrix. All enemy-round state digests match the reference and each other. The optional private live-save Blink lane was not configured; the pair does not claim to measure the user's personal save. [Runtime measurements](proofs/performance-2026-10-06/final-runtime-measurements.json) retain the full lane breakdown.

| Sampled combat group | Median base → candidate | p95 | p99 | Maximum | >16.67 ms | >33.33 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Settled idle | 8.363 → 8.336 | 8.600 → 8.579 | 8.651 → 8.668 | 8.681 → 8.838 | 0 → 0 | 0 → 0 |
| Seven card actions, 1,417 → 1,420 frames | 8.339 → 8.325 | 9.855 → 10.938 | 22.718 → 22.743 | 31.320 → 29.787 | 35 → 33 | 0 → 0 |
| Six abilities, 294 → 289 frames | 8.346 → 8.337 | 17.043 → 19.957 | 28.286 → 28.207 | 33.551 → 30.961 | 15 → 19 | 1 → 0 |
| Three enemy rounds, 5,456 → 5,475 frames | 8.351 → 8.344 | 11.540 → 11.355 | 16.502 → 16.662 | 35.668 → 35.366 | 50 → 54 | 1 → 1 |

These combat results are mixed and come from one pair. Threaded Path p95 rises 8.741 → 11.091 ms; small maxima and threshold-count changes are not established repeatable gains. No general steady-combat FPS improvement is claimed. The repeated ALL reductions are the strongest performance result of this checkpoint.

## Verification and inspection

The [proof manifest](proofs/performance-2026-10-06/manifest.json) identifies source bindings and accepted artifacts. Raw reports/logs are retained as gzip files, with original-content SHA-256 hashes. The final measured runtime revision is `f3760e48da6eca56d81cb13c8229e9691db3f23c`; the later report/proof commit changes documentation only.

Validation includes the full Godot suite and all 26 focused tests: owned combat factories and CPU assets, encounter/hand/card-preview preparation, travel/equipment handoff, prepared pre-battle/rewards, noncombat transitions, character retention, Grimoire/map/shop reuse, skill geometry, draw/hand flow, and committed save/recovery boundaries. The full suite predates only fixture/harness-only commits; production runtime bytes are identical. Corrected native captures exercise the final harness.

Fresh native quality proofs have exact pixels and zero orphan nodes: floor cache 102 cases / 156,916 checks; shadows 276 / 981; prepared unit canvases 32 / 672; shop glyphs 8 / 3,024; objective glyphs 26 / 12,630. Native combat/run analytics tests pass 79 / 105 checks. Their deliberate fault-injection diagnostics are explicitly enumerated, with zero unexpected errors. Failed headless/screenshot-wrapper attempts and the stale victory-fixture runs are excluded from accepted proof.

Inspected 1920×1080 images cover [pre-battle](proofs/performance-2026-10-06/images/final-all-candidate-0/all_surface_pre_battle.png), [equipped Gear](proofs/performance-2026-10-06/images/final-all-candidate-0/all_surface_equipment_after_swap.png), [combat after Begin](proofs/performance-2026-10-06/images/final-all-candidate-0/all_surface_combat_begun.png), [shop glyphs](proofs/performance-2026-10-06/images/final-native-prepared_shop_glyph_equivalence_test/prepared_shop_glyph_actual.png), [live fire](proofs/performance-2026-10-06/images/final-runtime-candidate/live_fire_impact.png), and [the post-trap hand](proofs/performance-2026-10-06/images/final-runtime-candidate/ranged_trap_hand.png). Floor/shadow/canvas fixtures and the objective intro/settled HUD were also inspected; authored content, ordering, lighting, controls, and typography remain intact.

The full Godot suite passes. Its deliberate progression-acknowledgment failure test emits the expected error, and the existing ObjectDB-at-exit warning remains; accepted native quality and performance reports require zero unexpected engine errors and zero orphan nodes. The suite now checks the current adopted character dialog after tab changes, and lightweight board test fixtures remain valid without optional preparation methods. An unchanged save/resume fixture failed five victory assertions on both baseline and candidate because a boss kill now enters the dragon reward. The fixture now executes the canonical reward Continue action and asserts actual victory before testing the same terminal persistence boundaries; both builds pass without weakening an assertion.

Windows typed-array compatibility was audited: new typed assignments use typed helpers/temporaries; frozen reference initializers are adapted without changing their algorithms. An actual Windows runtime was unavailable.

## Remaining work

Remaining measured hitches include menu creation (~189–193 ms), combat Begin (~42–43 ms), combat arrival (~40–41 ms), campfire/Scavenger arrival (~36–39 ms), and occasional Skills transitions (~33–34 ms). Smaller action/ability tails and the later Skills handler need further work if this pass is resumed. Extra retained memory and longer loading remain explicit tradeoffs. This checkpoint stops new optimization work for user inspection.

The inspection command regenerates and verifies a task-local pre-battle save before launching. Choose **Continue**, inspect Gear/Magic/Skills, swap equipment, then press Start and exercise cards, Pass, and travel. It uses the actual main app with isolated saves and Steam disabled.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/isolate-card-completion-stalls
python3 tools/inspection_fixture.py --task-id isolate-card-completion-stalls --run-id isolate-card-completion-stalls-wrap-inspection --launch --scenario pre_battle --seed 84217 --min-enemies 3 --equipment-inventory iron_cleaver,ward_kite --held-embers 720 --summary 'Inspect the wrapped performance pass: character tabs, equipment, combat Start and travel.'
```

For native reproduction, use an unlocked foreground display and serial jobs. The archived capture script records the exact local source-swapping protocol, settings and commands. Each raw report also contains its complete command/environment and before/after source hashes. Use the same current harness on a clean baseline and candidate; do not compare older harnesses with report work inside sampled windows. The full runtime pair uses `LABYRINTH_RUNTIME_PERF_FOCUSED=0`; the ALL workload uses `LABYRINTH_RUNTIME_PERF_ALL_SURFACES_ONLY=1`. All launches use the task/visual runners.

Publication is pending user inspection and explicit approval. No push, merge, or worktree cleanup is included in this checkpoint.
