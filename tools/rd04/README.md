# rd-04 — current owner proof (feedback 2)

rd-08 feedback 1 supersedes enemy tooltip content: the multi-tile proof now
asserts no enemy popup under both settings while keeping the dragon plate and
unfurled intent. Historical full-tooltip descriptions below predate that change.

Changes remain uncommitted. No native/windowed command or full suite was run by the worker. The director's earlier native logs are retained at `/private/tmp/labyrinth_codex/rd-04/own_stills.log` and `own_movie.log`.

## Native failure and code fixes

The old headless proof called the scene's tile callback directly; it skipped GUI hit testing and the board's duplicate-event cache. The scene could clear its hovered tile during mode cancellation or a rail exit while the board retained the previous tile. Re-entering that same tile then returned early without emitting `tile_hovered`, leaving isolation and rail/alpha owners stale. This reproduced on the new ordinary fixture's rail → chip path: ten failures with `scene=(-1,-1)` and the board still caching the enemy tile. The same assertions passed after the ownership fix.

Production fixes:

- Preview cancellation retires both scene and board pointer caches.
- `hover_owner_tile` is input-only presentation metadata. A repeated board tile re-emits hover if the scene owner was retired; invalid sentinels are treated equivalently. Unchanged, synchronized hover still coalesces. The metadata adds no paint invalidation.
- Turn gating uses the committed combat actor, rather than a hypothetical preview actor. The proof checks both a projected enemy actor during a real player turn and an actual enemy turn.

Native input also differed from the old harness's synthetic events: `push_input` did not move the OS cursor used by viewport mouse-position queries. The owned fixture adapter now warps the native cursor to the injected event position; headless and native proof both dispatch through the viewport. Pointer aiming waits for deferred layout before computing its screen point. No expected isolation set or alpha assertion was relaxed.

## Movie timeout fix

The old movie ran the complete interaction matrix, 120 idle frames and every crowded-dragon footprint before starting its 90-frame sweep. The timed-out run wrote 457 setup PNGs and never reported sweep completion. It was not a 90-frame capture.

`movie_capture.gd` is now separate: **8 setup frames + 90 sweep frames**, with no card tests, idle redraw sample, boss loop or tooltip waits. It prints readiness and progress every 30 sweep frames. Both engine and presentation clock receive fixed 30 fps. The finalizer removes setup frames and checks 90 consecutive native frame/clock samples. Headless `--check-only` proves bounded control flow and real pointer routing, not native write speed or pixels.

## Real-game cases

All three saves use the shared inspection generator's persistence/state contract and the stock `tools/inspection_fixture_verify.gd` verifier. No roster, position, intent, terrain or combat-number overrides are used.

| Case | Certified scene |
|---|---|
| overlap | Seed 7262034; Section I; Depth 3; fight 4; room `(3,-1)`. Five ordinary foes: two Roc Fledglings, Warden, Harrier, Crawler. One overlapped empty danger tile `(4,4)` within three tiles of the hero. |
| zekarion | Same run's real Depth 16 dragon arena; one Zekarion plus its production Lightning Wisps; hero included, four units total. |
| vyraketh | Same run's real Depth 12 dragon arena; one Vyraketh plus its production Cinder Droplet; hero included, three units total. |

The overlap selector traverses generated connections through the existing route-resolution helper, uses production encounter selection, and may advance two ordinary pass activations to select an actual combat moment. Boss cases use the existing `dragon` scenario at the seed's actual depth and may advance scheduled turns until the open-space condition holds. Every case checks at least three units **including the hero** have no tall prop directly in front. Craghide-in-a-crowd is removed.

## Exact owner commands — unrun by worker

Each native probe uses `LABYRINTH_CEL_LOOK=all`, `--rendering-method mobile`, `--rendering-driver metal`, Metal-only fallback and **`--timeout 300`**. The launcher uses the task-local Godot runner and rejects any engine log containing `Cel look variant unavailable` without suppressing or rewriting that log.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh fixture
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh stills
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh movie
```

`stills` launches **three separate processes**, one per case. They can also run individually:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh stills-overlap
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh stills-zekarion
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all tools/rd04/proof_for_owner.sh stills-vyraketh
```

New evidence root: `/private/tmp/labyrinth_codex/rd-04/feedback2/`.

- `stills/overlap/01_nothing_hovered.png`, `02_enemy_hovered.png`, `03_overlap_hovered.png`, `04_rail_hovered.png`, `06_reverse_lookup_both_rail_slots_lit.png`.
- `stills/zekarion/05_back_footprint_zekarion.png`.
- `stills/vyraketh/05_back_footprint_vyraketh.png`.
- `clip/frames/sweep_000.png` … `sweep_089.png`, with `clip/movie_manifest.json`.
- Separate native manifests `native-overlap.json`, `native-zekarion.json`, `native-vyraketh.json`, `native-movie.json`.

Capture contracts are separate for each scene. Existing old crowded captures are not reused. Native validation and judging remain for the owner.

## Headless commands

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id rd-04 --stream -- godot --headless --path . --script tools/rd04/threat_isolation_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id rd-04 --stream -- godot --headless --path . --script tools/rd04/threat_isolation_proof.gd -- --case zekarion --fixture-manifest /private/tmp/labyrinth_codex/rd-04/feedback2/zekarion.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id rd-04 --stream -- godot --headless --path . --script tools/rd04/threat_isolation_proof.gd -- --case vyraketh --fixture-manifest /private/tmp/labyrinth_codex/rd-04/feedback2/vyraketh.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-04 && python3 tools/godot_task_runner.py --task-id rd-04 --stream -- godot --headless --path . --script tools/rd04/movie_capture.gd -- --check-only --output-dir /private/tmp/labyrinth_codex/rd-04/feedback2/movie-check
```

## Chosen defaults / remaining work

Only test defaults were chosen: seed search starts at 7262026 with 256 attempts; generated routes have a 32-step bound; ordinary inspection moments allow two pass activations; real boss cases allow four; overlap distance is at most three Manhattan tiles from the hero. The selected seed and actual cases are recorded in `feedback2/cases.json`. Setup uses 8 movie frames and 20 proof settle frames, 0.7-second tooltip waits, and a 0.16-second rail-return wait. These do not change production tuning, camera, art or UI scale.

The 300-second probe timeout, 90-frame/30-fps sweep, 1920×1080, 100% UI scale, gold rail edge and 0.12-second easing come from the director. No TODO_DESIGN placeholder remains. Native write time under 60 seconds and fresh rendered proof remain unmeasured in this sandbox.
