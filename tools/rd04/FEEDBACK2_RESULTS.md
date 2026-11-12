# rd-04 feedback 2

The native failure came from hover ownership and input routing, not a different approved alpha value. `RunScene` could retire its hover during preview cancellation or a rail exit while `CombatBoardView` retained the previous tile. The next native pointer event resolving to that same tile was suppressed by the board's duplicate-event check, leaving isolation empty/stale. The previous headless proof bypassed that check by calling the scene callback directly.

On the real ordinary fixture, the unified viewport route reproduced this exact mismatch on rail → chip re-entry: `scene=(-1,-1)`, board still caching the enemy's tile, and ten failed identity/alpha/rail assertions. After the production ownership fix the same assertions passed. The native harness also left the OS cursor distinct from its injected event position, despite production aiming reading viewport mouse position; the owned adapter now warps the native cursor and waits for deferred layout before aiming. No isolation-set or alpha assertion was relaxed.

Production changes are in `scripts/combat_board_view.gd`, `scripts/run_scene.gd`, and `scripts/board_threat_isolation.gd`: synchronized cancellation, input-only `hover_owner_tile` metadata, duplicate suppression only when both owners agree, and committed-turn gating instead of hypothetical-preview actor gating. The metadata has no paint invalidation.

## Movie cause and replacement

The timed-out movie wrote 457 PNGs while still executing the full interaction matrix. The old code placed the sweep after at least 465 setup/test frames (including the 120-frame redraw sample and four crowded-enemy footprint loops). It had not reached a 90-frame-only recording.

`tools/rd04/movie_capture.gd` now has a dedicated path: eight explicit setup frames and 90 sweep frames, with no interaction-matrix, card, idle-sample, tooltip or boss waits. It prints readiness and progress at 30/60/90. Engine and presentation clock both receive fixed 30 fps. The finalizer discards startup frames and validates 90 consecutive native frames. The headless check completes the loop but is explicitly marked `check_only`, which the native finalizer rejects as evidence.

Native write time under 60 seconds is **not measured here**, because native runs remain assigned to the owner. All native probes now use the requested 300-second safety timeout.

## Certified real-game cases

All cases pass the stock inspection verifier. The custom overlap selector subclasses the shared inspection generator and traverses actual generated connections, normal encounter tables, and normal scheduled activations; it does not override enemies, positions, intents, terrain or combat numbers. Boss cases reuse the production `dragon` scenario.

- **Overlap:** seed 7262034, Section I, Depth 3, fight 4, room `(3,-1)`. Authored roster: two Roc Fledglings, Warden, Harrier, Crawler. The proof requires four or five living ordinary foes, no boss bar, one or two empty overlapped danger tiles near the hero, and at least three living visible units in the open including the hero. The selected overlap is `(4,4)`. The body/rail/movie selection prefers a visible ranged or long-route attacker; the current selected actor is the Harrier.
- **Zekarion:** the same seed's actual Depth 16 boss arena, exactly one dragon and its two production Lightning Wisps; four units including hero.
- **Vyraketh:** the same seed's actual Depth 12 boss arena, exactly one dragon and its production Cinder Droplet; three units including hero.
- Craghide-in-a-crowd is removed. Each boss proof verifies the seed/depth sequence, arena identity, open units and full content on every footprint tile.

Case manifests, source verification logs and selected seed are in `/private/tmp/labyrinth_codex/rd-04/feedback2/`. Old crowded native images are not reused.

## Observed checks

| Check | Observed result |
|---|---|
| Natural fixture certification | `RD04 REAL-GAME FIXTURES: PASS (Section I + two real-depth boss arenas)` |
| Overlap isolation, actual viewport input | `RD04 THREAT ISOLATION: PASS (1692 checks, 0 failures)` |
| Zekarion full footprint content | `RD04 THREAT ISOLATION: PASS (187 checks, 0 failures)` |
| Vyraketh full footprint content | `RD04 THREAT ISOLATION: PASS (189 checks, 0 failures)` |
| Held-overlap redraw sample | `RD04 IDLE REDRAWS: frames=120 requests=183 full=0 static=0` |
| Dedicated movie control flow | `RD04 MOVIE CHECK-ONLY: PASS (90 sweep frames; 8 setup frames; no interaction-matrix waits)` |
| Hover equivalence | `RD04 CANDIDATE HOVER: 52316 checks, 0 failures (0 distinct labels)` |
| Rail lifetime on real Zekarion fixture | `RD04 FOCUSED: PASS (810 checks, 0 failures)` |
| UI identity ratchet | `Ran 25 tests in 4.516s` / `OK` |
| Cel-look warning checks | All three cel-look-enabled proof logs and movie check contain no unavailable-variant warning |
| Tooling | Shell syntax, Python compilation and `git diff --check` exit 0 |

Logs: `verified-overlap.log`, `verified-zekarion.log`, `verified-vyraketh.log`, `verified-movie-check.log`, `hover.log`, `rail-boss.log`, `ui.log` under the feedback2 root. No full suite was run.

The unchanged rail lifetime suite was also tried on the five-foe overlap scene. Its uncollapsed-queue expectation produced two assertions: “The final rail contains exactly the surviving entries” and “The final rail keeps survivor order at 9”. That log remains at `rail-natural.log`. No existing assertion was rewritten. The focused rail runner now uses the real Zekarion fixture, whose queue fits that suite's assumption; the overlap proof still checks both attackers' actual rail highlights.

## Updated exact native commands — owner only

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh fixture
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh stills
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh movie
```

`stills` launches separate overlap, Zekarion and Vyraketh processes. All three and the movie explicitly use `--rendering-method mobile --rendering-driver metal --fallback-rendering-driver metal --timeout 300`, through the task runner. The engine-log guard rejects cel-look fallback warnings.

Expected images under `feedback2/stills/`:

- `overlap/01_nothing_hovered.png`, `02_enemy_hovered.png`, `03_overlap_hovered.png`, `04_rail_hovered.png`, `06_reverse_lookup_both_rail_slots_lit.png`.
- `zekarion/05_back_footprint_zekarion.png`.
- `vyraketh/05_back_footprint_vyraketh.png`.

Expected movie deliverable: `feedback2/clip/frames/sweep_000.png` … `sweep_089.png` and `clip/movie_manifest.json`. These new native artifacts have not been generated by the worker. Fresh owner rendering is still required to confirm the native fixes and actual PNG-write time.

## Defaults and ownership

No TODO_DESIGN placeholder remains. Only proof defaults were selected: deterministic seed search (start 7262026, 256 attempts), 32 route steps, two ordinary pass activations/four boss activations, overlap within three Manhattan tiles, eight movie setup frames, 20 proof settle frames, 0.7-second tooltip waits and 0.16-second rail-return wait. The director supplied resolution, scale, movie timing, alpha, rail colour, easing and 300-second probe timeout. Production camera, data, art, tuning, analytics and save schemas were not redesigned.

Files added/updated are confined to the three production hover hooks/helper and `tools/rd04/` (real fixture selector/certifier/adapter, case selector, separate movie script, proof and UID metadata, capture contracts, launchers and documentation). All work remains uncommitted. No peer review, publication or native execution was performed.
