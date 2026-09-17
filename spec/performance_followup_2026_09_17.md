# Combat hitch investigation — follow-up, 17 September 2026

This continues the [initial performance pass](performance_pass_2026_09_17.md), using its reviewed `c17c2106e9f16a587a371753be055814bcd77162` checkpoint as the baseline. The first checkpoint's remaining combat spikes were not treated as an acceptable finish.

**Current status: CPU optimization and semantic proof are complete; final native frame-pacing and visual validation still require an unlocked display.** The latest source has not yet been accepted as a smooth rendered result. The figures below are measured CPU work on the Mac, not rendered frame intervals or Steam Deck FPS.

## Work removed

- Profile reads no longer migrate and copy unrelated history, discovery records, and analytics queues. Skill selection repair has a bounded 64-entry cache keyed by the complete normalized selection, preference order, and target count; returned arrays remain owned. Cache clear and definition replacement invalidate it. Current-schema outbox reads retain normalization/ownership; old schemas retain migration.
- Combat checkpoints avoid copying the old combat snapshot immediately before replacing it. Equipment, magic, item, and deck repair share the already-owned working snapshot instead of recursively copying the complete run at each helper. Public helpers still return independent snapshots. Disk writes, readback, recovery, and analytics durability transactions are unchanged.
- Rules queries avoid repeated normalized skill arrays, relic string-key allocations, presentation-only light contributor construction, whole-board visibility enumeration for one tile, and full movement-target enumeration when the HUD only needs availability.
- Analytics context/draw batches copy the owned output fields they need; consecutive draw events reuse the same unchanged base context. Event contents, ordering, ownership, append calls, outbox staging, and acknowledgements remain unchanged.
- Push/pull targeting rejects out-of-range or occluded enemies before checking force directions. A one-step direction query now uses the same collision/footprint predicate without cloning the complete combat history. Complete ordered target lists and acceptance predicates are preserved.
- The next hand's flags and display modifiers are prepared one card per process frame during the existing card animation. No caller waits for this job. Only ready entries from an exactly equal complete combat state can be adopted; incomplete entries use the ordinary synchronous path. Interactive previews retain their complete target lists. Generation changes, run loads, and scene exit cancel scratch work. The supplied committed information state is threaded through recursive preview calculations, so warming cannot borrow the live animation's Umbra information.

The last change still requires rendered validation: each individual query is synchronous. Its measured slices are much smaller after fixing the knockback hotspot, but CPU measurements alone cannot establish animation smoothness.

## Matched CPU measurements

Apple M5 Pro, macOS 26.3.1 arm64, Godot 4.6.1. Serial runs used identical harnesses and seven-card hands. Normal-motion pairs ran candidate/base and then base/candidate; a separate pair exercised reduced motion. Detailed section instrumentation was enabled on both builds. The [raw reports, source hashes, and analysis](proofs/performance-2026-09-17/followup/manifest.json) are retained. Each measured source hash is explicit because the candidate was uncommitted at capture time.

Largest union of instrumented CPU intervals within a process frame, in milliseconds. These are **not frame-delivery measurements** and exclude uninstrumented engine/GPU work.

| Action | Baseline, two runs | Candidate, two runs |
| --- | ---: | ---: |
| Gust Step | 37.75, 40.09 | 16.69, 18.11 |
| Shadow Step | 61.16, 56.74 | 27.55, 24.18 |
| Wildfire Halo | 46.04, 41.81 | 17.69, 18.41 |

Reduced-motion CPU peaks change 35.11 → 17.00 ms, 57.48 → 26.68 ms, and 40.12 → 17.40 ms respectively. Every candidate action prepared and adopted all six remaining hand entries. Source state changed as expected and input was available on action completion in both builds. These checks do not substitute for native animation duration and frame-tail comparisons.

Repeated synchronous microbenchmark medians, in microseconds:

| Operation | Baseline range | Candidate range |
| --- | ---: | ---: |
| Seven-card flags, ordinary board | 3,553–3,603 | 1,921–1,959 |
| Seven-card flags, crowded board | 13,678–13,861 | 4,011–4,097 |
| Seven-card flags, surface board | 4,321–4,364 | 2,181–2,207 |
| Seven-card flags, Heart of Umbra | 4,207–4,208 | 2,382–2,458 |
| Checkpoint snapshot synchronization, four boards | 1,347–1,465 | 247–280 |
| Analytics context, four boards | 1,247–1,992 | 89–275 |
| Profile normalization, four boards | 3,058–3,192 | 37–44 |

The checkpoint row measures in-memory synchronization, **not filesystem save latency**. The profile row measures repeated normalization of an unchanged skill selection after warmup; it is not a cold-cache guarantee.

## Varied card-cost sweep

The matrix covers all 159 authored cards in seven-card hands across nine board/status states and two loadout/progression profiles: **2,862 cases per run**, with a warmup and three recorded queries per case. States include ordinary and blocked boards, crowded enemies, Heart of Umbra, Frozen, Shocked, Immobilized, and surface/relic interactions before and after skill use. Both builds return identical flags and display digests for every case; queries leave their source state unchanged.

The largest case median falls from 10.24–10.26 ms to 2.296–2.320 ms across the two pairs. The largest individual samples fall from 10.399–10.440 ms to 2.326–2.355 ms. This exposed and then verified the crowded-board knockback improvement instead of assuming a single overloaded scene represented all workloads.

Individual case medians occasionally rose over 5% by a few microseconds: 2 cases in one pair and 29 in the other. No case exceeded that threshold in both pairs. Raw samples and the intersection analysis are retained; these small non-repeating differences are not described as improvements.

## Correctness and lifecycle proof

- Full Godot rules suite passes, including every authored card's ordinary full preview versus the isolated committed-information summary across the nine fixture families.
- 7,347 checkpoint ownership, visibility, light, display, movement-meter, and discovery comparisons pass against frozen original implementations. Edges include Open Sky's conditional True Sight, weighted Winter Spur ice movement, ragged boards, malformed optional values, source mutation, and consumption of a first-attack display modifier.
- 6,260 push/pull comparisons pass against the exact original target/direction functions: ordered targets, accepted-limit filtering, large footprints, dead enemies, walls, terrain, illusions, surfaces, direction coercion, sideways force, and input immutability.
- Skill/profile equivalence covers legacy schemas, levels, selection repair, cache ownership, bounded capacity, clearing, and replacement definitions.
- 44 hand-preparation lifecycle checks pass: exact/partial adoption, full interactive previews, stale HP/hand/Umbra/skill/RNG rejection, replacement jobs, cancellation, detach/reattach, and freeing with a suspended job.
- 42 analytics-context/synchronization comparisons pass, preserving nested event ownership and complete ordered payloads. Surface batch/partial-append recovery, save/resume failure injection, card draw/hand flow, and board surface presentation pass.
- Thirteen Python performance-tool checks pass. Reports reject mismatched instrumentation modes and hand compositions; reduced-motion metadata is also part of the comparison contract.

The save/resume test deliberately triggers failed writes and corrupt input; its associated error logs are expected assertions of preserved recovery. The existing full-suite ObjectDB-at-exit warning is unchanged from baseline.

## Remaining validation

The display locked again during the follow-up. Locked/unfocused native attempts are excluded; headless CPU results are not substituted for renderer proof. Before accepting this follow-up, run matched foreground 1920×1080/100% native matrices, repeat the worst card/ability cases in both orders, include reduced motion, compare whole-action durations and tails, inspect fresh screenshots, and complete exact-HEAD peer review and a refreshed verified inspection fixture.

Instrumentation now includes per-frame deferred-layout/CardWidget attribution, initial hand-preparation normalization, warm-slice maxima, and actual adoption counts. The native benchmark also supports a lower-section-instrumentation mode, with matching mode required in both builds. Board/render counters remain active in that mode.

```sh
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/performance_pass.py run --task-id combat-cpu --benchmark combat_boundary_cpu --benchmark combat_action_cpu --benchmark card_query_cpu --output /tmp/combat-cpu.json
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/performance_pass.py run --task-id combat-native --native --benchmark runtime_frame --timeout 300 --output /tmp/combat-native.json
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 LABYRINTH_RUNTIME_PERF_REDUCED_MOTION=1 python3 tools/performance_pass.py run --task-id combat-reduced --native --benchmark runtime_frame --timeout 300 --output /tmp/combat-reduced.json
```
